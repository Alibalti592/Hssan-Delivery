import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Where the courier is, as their app last reported it (every ~20 s while
/// they're on a delivery).
class CourierPosition {
  const CourierPosition(this.point, this.updatedAt);

  final LatLng point;
  final DateTime? updatedAt;

  factory CourierPosition.fromJson(Map<String, dynamic> json) =>
      CourierPosition(
        LatLng(
          (json['latitude'] as num).toDouble(),
          (json['longitude'] as num).toDouble(),
        ),
        json['updatedAt'] is String
            ? DateTime.tryParse(json['updatedAt'] as String)
            : null,
      );

  /// Straight-line distance to [to], in km.
  double distanceKmTo(LatLng to) =>
      const Distance().as(LengthUnit.Meter, point, to) / 1000;
}

/// "1,2 km" / "350 m", the way the client reads it.
String formatDistance(double km) {
  if (km < 1) {
    final meters = (km * 1000 / 50).round() * 50;
    return '${math.max(50, meters)} m';
  }
  return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
}

/// A rough arrival time for a courier on a scooter in town: streets add
/// about 30 % to the straight line, at about 20 km/h. At least a minute.
int estimatedMinutes(double straightLineKm) =>
    math.max(1, (straightLineKm * 1.3 / 20 * 60).ceil());
