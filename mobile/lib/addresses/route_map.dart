import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
///
/// The courier never jumps: each new position is glided to. With
/// [creepToward], between two positions they also move slowly towards it at
/// a scooter's pace (see [creepTowards]) — the client sees them coming.
class RouteMap extends StatefulWidget {
  const RouteMap({
    this.pickup,
    this.dropOff,
    this.courier,
    this.heading,
    this.creepToward,
    this.height = 180,
    super.key,
  });

  final LatLng? pickup;
  final LatLng? dropOff;
  final LatLng? courier;
  final LatLng? heading;

  /// Where the courier is driving to right now, for the slow move between
  /// two positions; null keeps them where their app last put them.
  final LatLng? creepToward;
  final double height;

  /// Whether there's anything to draw.
  static bool canShow(LatLng? pickup, LatLng? dropOff) =>
      pickup != null || dropOff != null;

  @override
  State<RouteMap> createState() => _RouteMapState();
}

class _RouteMapState extends State<RouteMap>
    with SingleTickerProviderStateMixin {
  final _controller = MapController();
  bool _ready = false;

  /// Where the courier is drawn: [RouteMap.courier], glided and crept.
  final _shown = ValueNotifier<LatLng?>(null);

  /// Frames while the courier moves on screen; muted (no frames) otherwise.
  late final Ticker _ticker = createTicker((_) => _tick());

  /// The time base for the motion; the ticker's own restarts when unmuted.
  final _clock = Stopwatch()..start();

  /// The last real position, and when it arrived.
  LatLng? _fix;
  Duration _fixAt = Duration.zero;

  /// A glide in progress from where the courier was drawn.
  LatLng? _glideFrom;
  Duration? _glideStart;
  Duration _lastPaint = Duration.zero;

  static const _glideFor = Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
    _fix = widget.courier;
    _shown.value = widget.courier;
    _ticker
      ..muted = true
      ..start();
    if (_fix != null) _wake();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shown.dispose();
    super.dispose();
  }

  /// A new position, or a new place to creep to: glide from where the
  /// courier is drawn now.
  void _moved() {
    final now = _clock.elapsed;
    if (widget.courier != _fix) {
      _fix = widget.courier;
      _fixAt = now;
    }
    if (_fix == null) {
      _glideStart = null;
      _shown.value = null;
      _ticker.muted = true;
      return;
    }
    _glideFrom = _shown.value ?? _fix;
    _glideStart = now;
    _wake();
  }

  void _wake() => _ticker.muted = false;

  LatLng? _target(Duration now) {
    final fix = _fix;
    final toward = widget.creepToward;
    if (fix == null) return null;
    return toward == null ? fix : creepTowards(fix, toward, now - _fixAt);
  }

  void _tick() {
    final now = _clock.elapsed;
    final target = _target(now);
    if (target == null) return;
    final glideStart = _glideStart, glideFrom = _glideFrom;
    if (glideStart != null && glideFrom != null) {
      final k = ((now - glideStart).inMilliseconds / _glideFor.inMilliseconds)
          .clamp(0.0, 1.0);
      _shown.value = _lerp(glideFrom, target, Curves.easeInOut.transform(k));
      if (k >= 1) _glideStart = null;
    } else if (now - _lastPaint >= const Duration(milliseconds: 250)) {
      // Creeping is slow: a few frames a second are plenty.
      _shown.value = target;
    } else {
      return;
    }
    _lastPaint = now;
    final creeping = widget.creepToward != null && now - _fixAt <= creepLasts;
    if (_glideStart == null && !creeping) _ticker.muted = true;
  }

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
    if (old.courier != widget.courier ||
        old.creepToward != widget.creepToward) {
      _moved();
    }
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
              ValueListenableBuilder<LatLng?>(
                valueListenable: _shown,
                builder: (context, shown, _) =>
                    PolylineLayer(polylines: _route(pins, shown, heading)),
              ),
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
                ],
              ),
              ValueListenableBuilder<LatLng?>(
                valueListenable: _shown,
                builder: (context, shown, _) => MarkerLayer(
                  markers: [if (shown != null) _courierPin(shown)],
                ),
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

LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
  a.latitude + (b.latitude - a.latitude) * t,
  a.longitude + (b.longitude - a.longitude) * t,
);

/// About 15 km/h in a straight line: the scooter pace estimatedMinutes
/// assumes (20 km/h along streets about 30 % longer than the line).
const creepMetersPerSecond = 20 / 3.6 / 1.3;

/// How long the courier keeps creeping after their last real position:
/// past that, the map stops guessing.
const creepLasts = Duration(seconds: 60);

/// Never shown arriving by guesswork: the creep stops this far short.
const creepStopsShortMeters = 40.0;

/// Where a courier last seen at [from] probably is, [sinceFix] later, riding
/// straight towards [to] at [creepMetersPerSecond] — for at most
/// [creepLasts], and never closer than [creepStopsShortMeters].
LatLng creepTowards(LatLng from, LatLng to, Duration sinceFix) {
  final total = const Distance().as(LengthUnit.Meter, from, to);
  final room = total - creepStopsShortMeters;
  if (room <= 0) return from;
  final seconds =
      sinceFix.inMilliseconds.clamp(0, creepLasts.inMilliseconds) / 1000;
  return _lerp(
    from,
    to,
    math.min(room, seconds * creepMetersPerSecond) / total,
  );
}
