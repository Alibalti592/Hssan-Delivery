import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Turns a point on the map into a written address ("12 Rue de Marseille,
/// Bizerte"), so placing the pin fills the address in.
///
/// Uses OpenStreetMap's Nominatim, like the map tiles: free, but one lookup
/// at a time and only once the pin settles, as its usage policy asks.
class ReverseGeocoder {
  ReverseGeocoder({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// The one the app uses; widget tests swap in a fake.
  static ReverseGeocoder instance = ReverseGeocoder();

  /// The address at [point], or null when there is none or the lookup
  /// fails (no network): the client then types it, as before.
  Future<String?> addressAt(LatLng point) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'jsonv2',
      'lat': point.latitude.toStringAsFixed(6),
      'lon': point.longitude.toStringAsFixed(6),
      'zoom': '18',
      'addressdetails': '1',
      'accept-language': 'fr',
    });
    try {
      final response = await _client
          .get(
            uri,
            // Nominatim asks apps to identify themselves; browsers don't let
            // a page set this header, and send the page's address instead.
            headers: kIsWeb
                ? const {}
                : const {'User-Agent': 'HssanDelivery/1.0 (tn.hssan.delivery)'},
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json is Map<String, dynamic> ? formatAddress(json) : null;
    } on Exception {
      return null;
    }
  }

  /// "number street, neighbourhood, town" from a Nominatim result, leaving
  /// out what it doesn't know.
  @visibleForTesting
  static String? formatAddress(Map<String, dynamic> result) {
    final address = result['address'];
    if (address is! Map<String, dynamic>) return null;
    String? pick(List<String> keys) {
      for (final key in keys) {
        final value = address[key];
        if (value is String && value.trim().isNotEmpty) return value.trim();
      }
      return null;
    }

    final road = pick(['road', 'pedestrian', 'footway', 'residential']);
    final number = pick(['house_number']);
    final street = road == null
        ? null
        : number == null
        ? road
        : '$number $road';
    final area = pick(['neighbourhood', 'suburb', 'quarter', 'hamlet']);
    final town = pick(['city', 'town', 'village', 'municipality']);

    final parts = <String>[];
    for (final part in [street, area, town]) {
      if (part != null && !parts.contains(part)) parts.add(part);
    }
    if (parts.isNotEmpty) return parts.join(', ');

    // Nothing structured: the first few parts of the full name.
    final name = result['display_name'];
    if (name is! String || name.trim().isEmpty) return null;
    return name.split(',').map((s) => s.trim()).take(3).join(', ');
  }
}
