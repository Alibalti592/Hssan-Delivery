import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

/// Where the map opens when there is no pin yet and no GPS fix: Bizerte,
/// where the delivery zones are.
const defaultMapCenter = LatLng(37.2744, 9.8739);

/// An OpenStreetMap map with a pin fixed at its centre: the client drags
/// the map until the pin sits on their door, and [onMoved] reports where it
/// points. "Ma position" jumps to the phone's GPS fix.
class PinMap extends StatefulWidget {
  const PinMap({
    required this.initial,
    required this.onMoved,
    this.locateOnStart = false,
    this.height = 280,
    super.key,
  });

  final LatLng initial;
  final ValueChanged<LatLng> onMoved;

  /// Jump to the GPS fix as soon as the map opens (a new address).
  final bool locateOnStart;
  final double height;

  /// For widget tests, which have neither map tiles nor a GPS.
  static bool offline = false;

  @override
  State<PinMap> createState() => _PinMapState();
}

class _PinMapState extends State<PinMap> {
  final _controller = MapController();
  bool _locating = false;
  bool _dragging = false;

  @override
  void initState() {
    super.initState();
    if (widget.locateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _locate(quiet: true));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _locate({bool quiet = false}) async {
    setState(() => _locating = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final position = await _currentPosition();
      if (!mounted) return;
      if (position == null) {
        if (!quiet) {
          messenger?.showSnackBar(
            const SnackBar(
              content: Text(
                'Activez la localisation pour trouver votre position.',
              ),
            ),
          );
        }
        return;
      }
      final point = LatLng(position.latitude, position.longitude);
      _controller.move(point, 17);
      widget.onMoved(point);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  static Future<Position?> _currentPosition() async {
    if (PinMap.offline) return null;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on Exception {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 16,
              minZoom: 5,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && !_dragging) {
                  setState(() => _dragging = true);
                }
                widget.onMoved(camera.center);
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd) {
                  if (_dragging) setState(() => _dragging = false);
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
              const SimpleAttributionWidget(
                source: Text('OpenStreetMap'),
                backgroundColor: Color(0xCCFFFFFF),
              ),
            ],
          ),
          // The pin's tip marks the map centre; it lifts while dragging.
          IgnorePointer(
            child: Center(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 150),
                offset: Offset(0, _dragging ? -0.62 : -0.5),
                child: const Icon(Icons.location_on, size: 46, color: navy),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: navy,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Color(0x22000000), blurRadius: 6),
                ],
              ),
              child: const Text(
                'Déplacez la carte pour placer le repère',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 28,
            child: FloatingActionButton.small(
              heroTag: null,
              tooltip: 'Ma position',
              backgroundColor: Colors.white,
              foregroundColor: navy,
              onPressed: _locating ? null : () => _locate(),
              child: _locating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
