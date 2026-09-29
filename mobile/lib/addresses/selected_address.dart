import 'package:flutter/foundation.dart';

import 'address_models.dart';
import 'address_repository.dart';

/// The address the client is ordering for right now — what the home
/// screen's "LIVRER À" shows and what checkout, Colis and Factures start
/// from. Starts as their default saved address; picking another one (from
/// the header or any order form) changes it everywhere.
class SelectedAddressController extends ChangeNotifier {
  SelectedAddressController(this._repository);

  final AddressRepository _repository;

  SavedAddress? _current;
  bool _loaded = false;

  SavedAddress? get current => _current;

  bool get isLoaded => _loaded;

  /// Picks the default saved address (or the first one) unless the client
  /// already chose one this session. Safe to call on every home refresh.
  Future<void> load() async {
    final addresses = await _repository.list();
    _loaded = true;
    final current = _current;
    if (current != null && current.isSaved) {
      // Keep the choice, refreshed (it may have been edited or deleted).
      final match = addresses.where((a) => a.id == current.id);
      _current = match.isEmpty ? _defaultOf(addresses) : match.first;
    } else {
      _current ??= _defaultOf(addresses);
    }
    notifyListeners();
  }

  void select(SavedAddress address) {
    _current = address;
    notifyListeners();
  }

  /// Signing out must not carry an address over to the next account.
  void clear() {
    _current = null;
    _loaded = false;
    notifyListeners();
  }

  static SavedAddress? _defaultOf(List<SavedAddress> addresses) {
    if (addresses.isEmpty) return null;
    return addresses.firstWhere(
      (a) => a.isDefault,
      orElse: () => addresses.first,
    );
  }
}
