import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import 'delivery.dart';
import 'delivery_repository.dart';

class DeliveriesController extends ChangeNotifier {
  DeliveriesController(this._repository);

  final DeliveryRepository _repository;

  List<Delivery> _deliveries = const [];
  bool _loading = false;
  bool _loadedOnce = false;
  String? _error;
  int? _actingOnId;

  List<Delivery> get deliveries => _deliveries;
  bool get loading => _loading;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;
  int? get actingOnId => _actingOnId;

  List<Delivery> get active =>
      _deliveries.where((d) => !d.status.isTerminal).toList(growable: false);
  List<Delivery> get history =>
      _deliveries.where((d) => d.status.isTerminal).toList(growable: false);

  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _deliveries = _sorted(await _repository.listMine());
      _loadedOnce = true;
    } on ApiException catch (e) {
      _error = e.message;
    } on NetworkException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Runs a lifecycle action. Returns an error message, or null on success.
  ///
  /// A decline unassigns the courier, so the delivery is no longer "mine":
  /// it is dropped from the list rather than replaced in place.
  Future<String?> perform(Delivery delivery, DeliveryAction action) async {
    _actingOnId = delivery.id;
    notifyListeners();
    try {
      final updated = await _repository.act(delivery.id, action);
      _deliveries = action == DeliveryAction.decline
          ? _sorted([
              for (final d in _deliveries)
                if (d.id != updated.id) d,
            ])
          : _sorted([
              for (final d in _deliveries)
                if (d.id == updated.id) updated else d,
            ]);
      return null;
    } on ApiException catch (e) {
      return e.message;
    } on NetworkException catch (e) {
      return e.message;
    } finally {
      _actingOnId = null;
      notifyListeners();
    }
  }

  Delivery? byId(int id) {
    for (final d in _deliveries) {
      if (d.id == id) return d;
    }
    return null;
  }

  static List<Delivery> _sorted(List<Delivery> input) {
    final copy = [...input];
    copy.sort((a, b) {
      if (a.status.isTerminal != b.status.isTerminal) {
        return a.status.isTerminal ? 1 : -1;
      }
      final aDate = a.assignedAt ?? DateTime(0);
      final bDate = b.assignedAt ?? DateTime(0);
      return bDate.compareTo(aDate);
    });
    return List.unmodifiable(copy);
  }
}
