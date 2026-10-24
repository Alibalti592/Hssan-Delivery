import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';
import 'pin_map.dart';

/// A map of an order's pins: A where the courier collects (when the client
/// placed a pin there) and B where they drop off, joined by a dotted line.
/// With neither pin — an address that was only typed — it shows nothing.
///
/// With [courier] (the client following their order), the courier shows
/// too: the stretch from A already covered in amber, what's left to
/// [heading] (the stop they're on their way to) dotted. The map follows them
/// as they move — until the client moves the map themselves; then a button
/// brings it back onto them. Tiles are softened so the route stands out.
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

  /// What the camera frames: the courier and where they're heading — and,
  /// once past the pickup, the pickup too, so the amber stretch shows whole —
  /// or every pin when there's no courier.
  List<LatLng> get _framed {
    final courier = widget.courier;
    if (courier != null) {
      final pickup = widget.pickup;
      final pastPickup =
          pickup != null && widget.heading != null && widget.heading != pickup;
      return [courier, ?widget.heading, if (pastPickup) pickup];
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
        padding: const EdgeInsets.fromLTRB(56, 56, 56, 84),
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
                      padding: const EdgeInsets.fromLTRB(56, 56, 56, 84),
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
                  tileBuilder: _softTile,
                )
              else
                const ColoredBox(color: Color(0xFFECEEE9)),
              PolylineLayer(polylines: _route(pins, courier, heading)),
              MarkerLayer(
                markers: [
                  if (widget.pickup != null)
                    _letterPin(
                      widget.pickup!,
                      'A',
                      navy,
                      Colors.white,
                      'Départ',
                    ),
                  if (widget.dropOff != null)
                    widget.pickup != null
                        ? _letterPin(
                            widget.dropOff!,
                            'B',
                            trackAmber,
                            navy,
                            'Arrivée',
                          )
                        : _homePin(widget.dropOff!),
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

  /// A to B dotted; once the courier is out, the part of the trip they've
  /// covered in amber and what's left to [heading] dotted in black. With
  /// only a drop-off (the client's own map), an amber dashed line from the
  /// courier to it.
  List<Polyline> _route(List<LatLng> pins, LatLng? courier, LatLng? heading) {
    final pickup = widget.pickup;
    final dotted = StrokePattern.dotted(spacingFactor: 2);
    if (courier == null || heading == null) {
      return [
        if (pins.length > 1)
          Polyline(
            points: pins,
            strokeWidth: 5,
            color: navy.withValues(alpha: 0.3),
            pattern: dotted,
          ),
      ];
    }
    // No pickup on the map (the client's view): the courier's way to them.
    if (pickup == null) {
      return [
        Polyline(
          points: [courier, heading],
          strokeWidth: 6,
          color: trackAmber,
          borderStrokeWidth: 2,
          borderColor: Colors.white,
          pattern: StrokePattern.dashed(segments: const [14, 10]),
        ),
      ];
    }
    final toPickup = heading == pickup;
    return [
      // Still to come after the pickup: A to B, faint.
      if (toPickup && widget.dropOff != null)
        Polyline(
          points: [pickup, widget.dropOff!],
          strokeWidth: 5,
          color: navy.withValues(alpha: 0.18),
          pattern: dotted,
        ),
      // Covered since the pickup.
      if (!toPickup)
        Polyline(
          points: [pickup, courier],
          strokeWidth: 6,
          color: trackAmber,
          borderStrokeWidth: 2,
          borderColor: Colors.white,
        ),
      Polyline(
        points: [courier, heading],
        strokeWidth: 6,
        color: navy.withValues(alpha: 0.45),
        pattern: dotted,
      ),
    ];
  }

  Marker _letterPin(
    LatLng point,
    String letter,
    Color color,
    Color textColor,
    String tooltip,
  ) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Tooltip(
        message: tooltip,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), blurRadius: 6),
            ],
          ),
          child: Text(
            letter,
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  /// The only pin (a bill: the courier comes back to the client's door).
  Marker _homePin(LatLng point) {
    return Marker(
      point: point,
      width: 40,
      height: 40,
      child: Tooltip(
        message: 'Arrivée',
        child: Container(
          decoration: BoxDecoration(
            color: trackAmber,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0x44000000), blurRadius: 6),
            ],
          ),
          child: const Icon(Icons.home_rounded, size: 18, color: navy),
        ),
      ),
    );
  }

  /// The courier: bigger than the pins, black with a white ring and a soft
  /// amber halo, so the eye finds them first.
  Marker _courierPin(LatLng point) {
    return Marker(
      point: point,
      width: 66,
      height: 66,
      child: Tooltip(
        message: 'Votre livreur',
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: trackAmber.withValues(alpha: 0.22),
          ),
          alignment: Alignment.center,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: navy,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 10),
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

/// Softer, lighter map tiles: mostly grey with a hint of their colours, so
/// the amber route and the pins carry the screen.
Widget _softTile(BuildContext context, Widget tile, TileImage image) {
  return ColorFiltered(colorFilter: _soften, child: tile);
}

// Saturation down to 30% (towards each pixel's luminance), then 15% of
// the way to white.
const _soften = ColorFilter.matrix(<double>[
  0.381, 0.426, 0.043, 0, 38, //
  0.127, 0.681, 0.043, 0, 38, //
  0.127, 0.426, 0.298, 0, 38, //
  0, 0, 0, 1, 0, //
]);
