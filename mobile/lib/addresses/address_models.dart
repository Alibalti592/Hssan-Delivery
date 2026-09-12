class SavedAddress {
  SavedAddress({
    required this.id,
    required this.label,
    required this.addressLine,
    required this.instructions,
    required this.isDefault,
  });

  final int id;
  final String label;
  final String addressLine;
  final String? instructions;
  final bool isDefault;

  factory SavedAddress.fromJson(Map<String, dynamic> json) {
    return SavedAddress(
      id: json['id'] as int,
      label: json['label'] as String? ?? '',
      addressLine: json['addressLine'] as String? ?? '',
      instructions: json['instructions'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}
