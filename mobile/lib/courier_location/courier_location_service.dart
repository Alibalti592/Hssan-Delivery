import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../deliveries/deliveries_controller.dart';
import '../deliveries/delivery.dart';
import 'courier_location_repository.dart';

/// Reports the courier's current GPS position to the backend while they
/// are on duty — available for new orders ([isOnDuty]) — or have at least
/// one active (non-terminal) delivery, so the admin sees them on the map
/// and can give an order to the nearest one. See the "last known
/// location, not real-time tracking" caveat on the backend's
/// CourierLocation entity. This only ever runs in the foreground, while the
/// app is open: there is no background service, and Android's background
/// location permissions/configuration are NOT set up, so a courier who
/// backgrounds the app simply stops reporting until they return to it.
///
/// It also reports at once when one of their deliveries changes status
/// (accepted, picked up, on the way…), so the client following the order
/// sees the courier where they really are at that moment, not up to one
/// interval earlier.
///
/// Every failure mode here — permission denied, location services off, GPS
/// timeout, offline, a backend error — is swallowed rather than surfaced:
/// this is a best-effort background convenience, never something that
/// should interrupt a courier mid-delivery (mirrors PushNotificationService).
class CourierLocationService {
  CourierLocationService(
    this._repository,
    this._deliveries, {
    Duration interval = const Duration(seconds: 20),
    Future<bool> Function()? ensurePermission,
    Future<Position> Function()? getPosition,
    Listenable? onDuty,
    bool Function()? isOnDuty,
  }) : _interval = interval,
       _ensurePermission = ensurePermission ?? _defaultEnsurePermission,
       _getPosition = getPosition ?? _defaultGetPosition,
       _onDuty = onDuty,
       _isOnDuty = isOnDuty ?? _never {
    _deliveries.addListener(_onDeliveriesChanged);
    _onDuty?.addListener(_onDeliveriesChanged);
  }

  static bool _never() => false;

  final CourierLocationRepository _repository;
  final DeliveriesController _deliveries;
  final Duration _interval;
  final Future<bool> Function() _ensurePermission;
  final Future<Position> Function() _getPosition;

  /// Notifies when [_isOnDuty] may have changed (the signed-in account).
  final Listenable? _onDuty;
  final bool Function() _isOnDuty;

  Timer? _timer;
  bool _reporting = false;

  /// A status change arrived mid-report: report once more after it.
  bool _again = false;

  /// Each active delivery's status, as of the last change seen.
  Map<int, DeliveryStatus> _statuses = const {};

  void _onDeliveriesChanged() {
    final active = _deliveries.active;
    final shouldReport = _isOnDuty() || active.isNotEmpty;
    final statuses = {for (final d in active) d.id: d.status};
    final statusChanged = statuses.entries.any(
      (e) => _statuses.containsKey(e.key) && _statuses[e.key] != e.value,
    );
    _statuses = statuses;

    if (shouldReport && _timer == null) {
      _reportOnce();
      _timer = Timer.periodic(_interval, (_) => _reportOnce());
    } else if (!shouldReport && _timer != null) {
      _timer?.cancel();
      _timer = null;
    } else if (shouldReport && statusChanged) {
      _reportOnce(urgent: true);
    }
  }

  Future<void> _reportOnce({bool urgent = false}) async {
    // Avoid overlapping calls if a slow GPS fix outlives the next tick; a
    // status change during one gets its own report right after.
    if (_reporting) {
      if (urgent) _again = true;
      return;
    }
    _reporting = true;

    try {
      if (!await _ensurePermission()) return;
      final position = await _getPosition();
      await _repository.report(position.latitude, position.longitude);
    } catch (_) {
      // Best-effort only — see class doc.
    } finally {
      _reporting = false;
      if (_again) {
        _again = false;
        unawaited(_reportOnce());
      }
    }
  }

  static Future<bool> _defaultEnsurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<Position> _defaultGetPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      ),
    );
  }

  void dispose() {
    _timer?.cancel();
    _deliveries.removeListener(_onDeliveriesChanged);
    _onDuty?.removeListener(_onDeliveriesChanged);
  }
}
