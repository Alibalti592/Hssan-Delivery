/// Tunisian phone numbers: an optional +216/216 country code, optionally
/// separated from the local number by a space or dash, followed by 8 digits
/// (the national mobile/landline length) starting 2-9 — mirrors the
/// backend's App\Validator\PhoneFormat and matches the "+216 22 000 000"
/// hint shown on every phone field in this app.
final RegExp _phonePattern = RegExp(r'^\+?(216)?[ \-]?[2-9](?:[ \-]?\d){7}$');

/// Form-field validator for a required phone number: returns a French error
/// message for an empty or malformed value, or null once it's valid.
String? validatePhone(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) return 'Numéro requis';
  if (!_phonePattern.hasMatch(trimmed)) return 'Numéro de téléphone invalide';
  return null;
}
