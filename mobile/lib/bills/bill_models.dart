/// What a courier does at a provider's counter — mirrors the backend's
/// BillProviderKind: pay a bill (STEG, SONEDE...) or send a mandat on the
/// client's behalf (IZI, Wafa Cash).
enum BillProviderKind {
  bill('BILL'),
  transfer('TRANSFER');

  const BillProviderKind(this.wire);

  final String wire;

  static BillProviderKind fromWire(String? value) =>
      value == 'TRANSFER' ? transfer : bill;
}

/// One of the choices on the Factures screen, managed from the admin
/// dashboard (logo included).
class BillProvider {
  const BillProvider({
    required this.id,
    required this.name,
    required this.kind,
    this.logoUrl,
  });

  final int id;
  final String name;
  final BillProviderKind kind;

  /// Relative to the API (see AppConfig.resolvePhotoUrl); null until the
  /// admin uploads one — BillProviderLogo then shows the name instead.
  final String? logoUrl;

  bool get isTransfer => kind == BillProviderKind.transfer;

  factory BillProvider.fromJson(Map<String, dynamic> json) {
    return BillProvider(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      kind: BillProviderKind.fromWire(json['kind'] as String?),
      logoUrl: json['logoUrl'] as String?,
    );
  }
}

/// The Factures part of an order (the backend's BillSummary), as both the
/// client and the courier see it. A mandat's receiver is on the order
/// itself (recipientName/recipientPhone).
class BillInfo {
  const BillInfo({
    required this.provider,
    required this.amount,
    this.reference,
    this.photoUrl,
  });

  final BillProvider provider;

  /// Cash paid at the counter, e.g. "85.500".
  final String amount;

  /// The bill's reference number; null for a mandat.
  final String? reference;

  /// Relative API path to the bill photo, which needs the bearer token to
  /// load (see ApiClient.authHeaders); null when none was attached.
  final String? photoUrl;

  bool get isTransfer => provider.isTransfer;

  static BillInfo? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return BillInfo(
      provider: BillProvider(
        id: json['providerId'] as int? ?? 0,
        name: json['providerName'] as String? ?? '',
        kind: BillProviderKind.fromWire(json['providerKind'] as String?),
        logoUrl: json['providerLogoUrl'] as String?,
      ),
      amount: json['amount'] as String? ?? '0.000',
      reference: json['reference'] as String?,
      photoUrl: json['photoUrl'] as String?,
    );
  }
}
