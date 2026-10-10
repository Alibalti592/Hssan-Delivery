import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import 'pin_map.dart';

/// A map of an order's pins: where the courier collects (when the client
/// placed a pin there) and where they drop off, joined by a dashed line.
/// With neither pin — an address that was only typed — it shows nothing.
///
/// With [courier] (the client following their order), the courier shows
/// too, joined to [heading] (the stop they're on their way to), and the map
/// follows them as they move — until the client moves the map themselves;
/// then a button brings it back onto them.
class RouteMap extends StatefulWidget {
  const RouteMap({
    this.pickup,
    this.dropOff,
    this.courier,
    this.heading,
    this.height = 180,
    super.key,
  });

  final LatLng? pickup;
  final LatLng? dropOff;
  final LatLng? courier;
  final LatLng? heading;
  final double height;

  /// Whether there's anything to draw.
  static bool canShow(LatLng? pickup, LatLng? dropOff) =>
      pickup != null || dropOff != null;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap> {
  final _controller = MapController();
  bool _ready = false;

  /// Off once the client pans or zooms; the recenter button turns it back on.
  bool _following = true;

  /// What the camera frames: the courier and where they're heading, or
  /// every pin when there's no courier.
  List<LatLng> get _framed {
    final courier = widget.courier;
    if (courier != null) {
      return [courier, ?widget.heading];
    }
    return [?widget.pickup, ?widget.dropOff];
  }

  @override
  void didUpdateWidget(RouteMap old) {
    super.didUpdateWidget(old);
    if (_following &&
        _ready &&
        (old.courier != widget.courier || old.heading != widget.heading)) {
      _frame();
    }
  }

  void _frame() {
    final points = _framed;
    if (points.isEmpty) return;
    if (points.length == 1) {
      _controller.move(points.single, 16);
      return;
    }
    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(48, 48, 48, 56),
        maxZoom: 17,
      ),
    );
  }

  void _recenter() {
    setState(() => _following = true);
    _frame();
  }

  @override
  Widget build(BuildContext context) {
    final pins = [?widget.pickup, ?widget.dropOff];
    if (pins.isEmpty) return const SizedBox.shrink();
    final framed = _framed;
    final courier = widget.courier;
    final heading = widget.heading;

    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: framed.first,
              initialZoom: 16,
              initialCameraFit: framed.length > 1
                  ? CameraFit.coordinates(
                      coordinates: framed,
                      padding: const EdgeInsets.fromLTRB(48, 48, 48, 56),
                      maxZoom: 17,
                    )
                  : null,
              minZoom: 5,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () => _ready = true,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _following && courier != null) {
                  setState(() => _following = false);
                }
              },
            ),
            children: [
              if (!PinMap.offline)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'tn.hssan.delivery',
                )
              else
                const ColoredBox(color: Color(0xFFE8ECF2)),
              PolylineLayer(
                polylines: [
                  if (pins.length > 1)
                    Polyline(
                      points: pins,
                      strokeWidth: 3,
                      color: navy.withValues(alpha: 0.25),
                      pattern: StrokePattern.dashed(segments: const [10, 8]),
                    ),
                  if (courier != null && heading != null)
                    Polyline(
                      points: [courier, heading],
                      strokeWidth: 4,
                      color: navy,
                      pattern: StrokePattern.dashed(segments: const [8, 6]),
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (widget.pickup != null)
                    _pin(
                      widget.pickup!,
                      successText,
                      'Départ',
                      Icons.inventory_2,
                    ),
                  if (widget.dropOff != null)
                    _pin(widget.dropOff!, navy, 'Arrivée', Icons.home_rounded),
                  if (courier != null) _courierPin(courier),
                ],
              ),
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap', style: TextStyle(fontSize: 10)),
                backgroundColor: Color(0xCCFFFFFF),
              ),
            ],
          ),
          if (courier != null && !_following)
            Positioned(
              right: 12,
              top: 12,
              child: Material(
                color: Colors.white,
                elevation: 3,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: _recenter,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.my_location, size: 16, color: navy),
                        SizedBox(width: 6),
                        Text(
                          'Recentrer',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: navy,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
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

  /// The courier: bigger than the pins, with a soft halo so the eye finds
  /// them first.
  Marker _courierPin(LatLng point) {
    return Marker(
      point: point,
      width: 58,
      height: 58,
      child: Tooltip(
        message: 'Votre livreur',
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: navy.withValues(alpha: 0.12),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: navy,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 8),
              ],
            ),
            child: const Icon(
              Icons.delivery_dining,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
