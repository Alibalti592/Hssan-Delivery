import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../deliveries/deliveries_controller.dart';
import 'courier_location_repository.dart';

/// Reports the courier's current GPS position to the backend while they
/// have at least one active (non-terminal) delivery — see the "last known
/// location, not real-time tracking" caveat on the backend's
/// CourierLocation entity. This only ever runs in the foreground, while the
/// app is open: there is no background service, and Android's background
/// location permissions/configuration are NOT set up, so a courier who
/// backgrounds the app simply stops reporting until they return to it.
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
  }) : _interval = interval,
       _ensurePermission = ensurePermission ?? _defaultEnsurePermission,
       _getPosition = getPosition ?? _defaultGetPosition {
    _deliveries.addListener(_onDeliveriesChanged);
  }

  final CourierLocationRepository _repository;
  final DeliveriesController _deliveries;
  final Duration _interval;
  final Future<bool> Function() _ensurePermission;
  final Future<Position> Function() _getPosition;

  Timer? _timer;
  bool _reporting = false;

  void _onDeliveriesChanged() {
    final shouldReport = _deliveries.active.isNotEmpty;

    if (shouldReport && _timer == null) {
      _reportOnce();
      _timer = Timer.periodic(_interval, (_) => _reportOnce());
    } else if (!shouldReport && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> _reportOnce() async {
    // Avoid overlapping calls if a slow GPS fix outlives the next tick.
    if (_reporting) return;
    _reporting = true;

    try {
      if (!await _ensurePermission()) return;
      final position = await _getPosition();
      await _repository.report(position.latitude, position.longitude);
    } catch (_) {
      // Best-effort only — see class doc.
    } finally {
      _reporting = false;
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
  }
}
