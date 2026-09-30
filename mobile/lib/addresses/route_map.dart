import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import 'pin_map.dart';

/// A map of an order's pins: where the courier collects (when the client
/// placed a pin there) and where they drop off, joined by a dashed line.
/// With neither pin — an address that was only typed — it shows nothing.
class RouteMap extends StatelessWidget {
  const RouteMap({this.pickup, this.dropOff, this.height = 180, super.key});

  final LatLng? pickup;
  final LatLng? dropOff;
  final double height;

  /// Whether there's anything to draw.
  static bool canShow(LatLng? pickup, LatLng? dropOff) =>
      pickup != null || dropOff != null;

  @override
  Widget build(BuildContext context) {
    final points = [?pickup, ?dropOff];
    if (points.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: height,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: points.first,
          initialZoom: 16,
          initialCameraFit: points.length > 1
              ? CameraFit.coordinates(
                  coordinates: points,
                  padding: const EdgeInsets.fromLTRB(40, 40, 40, 48),
                  maxZoom: 17,
                )
              : null,
          minZoom: 5,
          maxZoom: 19,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
          ),
        ),
        children: [
          if (!PinMap.offline)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'tn.hssan.delivery',
            )
          else
            const ColoredBox(color: Color(0xFFE8ECF2)),
          if (points.length > 1)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  strokeWidth: 3,
                  color: navy.withValues(alpha: 0.6),
                  pattern: StrokePattern.dashed(segments: const [10, 8]),
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              if (pickup != null)
                _pin(pickup!, successText, 'Départ', Icons.inventory_2),
              if (dropOff != null)
                _pin(dropOff!, navy, 'Arrivée', Icons.home_rounded),
            ],
          ),
          const SimpleAttributionWidget(
            source: Text('OpenStreetMap', style: TextStyle(fontSize: 10)),
            backgroundColor: Color(0xCCFFFFFF),
          ),
        ],
      ),
    );
  }

  Marker _pin(LatLng point, Color color, String tooltip, IconData icon) {
    return Marker(
      point: point,
      width: 36,
      height: 36,
      child: Tooltip(
        message: tooltip,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), blurRadius: 6),
            ],
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
