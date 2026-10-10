import '../orders/order_models.dart' show DeliveryZoneOption;

/// An address the client delivers to (or has a Colis collected from): one
/// saved in their account, or — [id] null — typed for a single order
/// without saving it (see AddressEditorScreen's "Enregistrer" switch).
class SavedAddress {
  SavedAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.instructions,
    required this.isDefault,
    this.zone,
    this.latitude,
    this.longitude,
  });

  final int? id;
  final String label;
  final String addressLine;
  final String? instructions;
  final bool isDefault;

  /// The zone that prices deliveries here, from the pin; null for an
  /// address outside every zone, or saved before pins (checkout then asks
  /// to place it on the map).
  final DeliveryZoneOption? zone;

  /// The pin the client placed on the map; null when only typed.
  final double? latitude;
  final double? longitude;

  bool get isSaved => id != null;

  bool get hasLocation => latitude != null && longitude != null;

  /// What the courier reads: the address plus the door-step hints.
  String get fullText => instructions == null || instructions!.trim().isEmpty
      ? addressLine
      : '$addressLine — ${instructions!.trim()}';

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    final zoneId = json['deliveryZoneId'] as int?;
    return SavedAddress(
      id: json['id'] as int,
      label: json['label'] as String? ?? '',
      addressLine: json['addressLine'] as String? ?? '',
      instructions: json['instructions'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
      zone: zoneId == null
          ? null
          : DeliveryZoneOption(
              id: zoneId,
              name: json['deliveryZoneName'] as String? ?? '',
              fee: json['deliveryZoneFee'] as String? ?? '0.000',
            ),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}

/// The three labels offered as chips when saving an address; anything else
/// is typed under "Autre".
enum AddressLabel {
  home('Maison'),
  work('Travail'),
  other('Autre');

  const AddressLabel(this.text);

  final String text;

  static AddressLabel of(String label) => values.firstWhere(
    (l) => l != other && l.text.toLowerCase() == label.trim().toLowerCase(),
    orElse: () => other,
  );
}
