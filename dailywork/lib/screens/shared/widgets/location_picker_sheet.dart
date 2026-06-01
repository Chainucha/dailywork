import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'package:dailywork/core/theme/app_theme.dart';
import 'package:dailywork/providers/language_provider.dart';

class PickedLocation {
  final double lat;
  final double lng;
  final String? address;
  const PickedLocation({required this.lat, required this.lng, this.address});
}

class LocationPickerSheet extends ConsumerStatefulWidget {
  const LocationPickerSheet({
    super.key,
    required this.initialLat,
    required this.initialLng,
    this.initialAddress,
    required this.onPicked,
    this.embedded = false,
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final void Function(PickedLocation) onPicked;

  // When embedded inline (e.g. inside a form) the picker stays put and does not
  // close a route on pick, and it hides its own title/outer padding.
  final bool embedded;

  @override
  ConsumerState<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  bool _busy = false;
  String? _error;

  // GPS-resolved default for the map picker. Seeded on open so "Adjust on map"
  // centers near the user instead of the hardcoded Bangalore fallback.
  double? _gpsLat;
  double? _gpsLng;

  // Last point the user picked while embedded — keeps the preview in sync
  // immediately, without waiting for the parent to feed back initialLat/Lng.
  double? _selLat;
  double? _selLng;

  // Drives the inline preview map so it can recenter when GPS resolves.
  final fmap.MapController _mapController = fmap.MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _recenterPreview() {
    try {
      _mapController.move(ll.LatLng(_defaultLat, _defaultLng), 14);
    } catch (_) {
      // Controller not attached yet; initialCenter already covers first frame.
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialLat == null || widget.initialLng == null) {
      _autoCenter();
    }
  }

  // Silently center on the device location if permission is already granted.
  // Does not prompt — the explicit "Use my location" button handles requests.
  Future<void> _autoCenter() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.whileInUse &&
          perm != LocationPermission.always) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() { _gpsLat = pos.latitude; _gpsLng = pos.longitude; });
      _recenterPreview();
    } catch (_) {
      // Leave the fallback default; not a user-facing error.
    }
  }

  double get _defaultLat => _selLat ?? widget.initialLat ?? _gpsLat ?? 12.9716;
  double get _defaultLng => _selLng ?? widget.initialLng ?? _gpsLng ?? 77.5946;

  Future<void> _useGps() async {
    setState(() { _busy = true; _error = null; });
    try {
      final perm = await Geolocator.checkPermission();
      LocationPermission effective = perm;
      if (perm == LocationPermission.denied) {
        effective = await Geolocator.requestPermission();
      }
      if (effective == LocationPermission.denied ||
          effective == LocationPermission.deniedForever) {
        setState(() { _error = 'Location permission denied'; _busy = false; });
        return;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        setState(() {
          _error = 'Location services off — enable GPS (emulator: set a point in Extended Controls)';
          _busy = false;
        });
        return;
      }
      // A live fix can be slow or unavailable (common on emulators with no set
      // location). Cap the wait, then fall back to the last known fix.
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(timeLimit: Duration(seconds: 10)),
        );
      } on TimeoutException {
        pos = await Geolocator.getLastKnownPosition();
      }
      pos ??= await Geolocator.getLastKnownPosition();
      if (pos == null) {
        setState(() {
          _error = 'No GPS fix yet — set a location in the emulator, or use Adjust on map';
          _busy = false;
        });
        return;
      }
      final lat = pos.latitude;
      final lng = pos.longitude;
      widget.onPicked(PickedLocation(lat: lat, lng: lng));
      if (widget.embedded) {
        if (mounted) {
          setState(() {
            _busy = false;
            _selLat = lat;
            _selLng = lng;
          });
        }
        _recenterPreview();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      setState(() { _error = 'Could not read GPS'; _busy = false; });
    }
  }

  Future<void> _adjustOnMap() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(
          initialLat: _defaultLat,
          initialLng: _defaultLng,
        ),
      ),
    );
    if (picked != null) {
      widget.onPicked(picked);
      if (widget.embedded) {
        setState(() { _selLat = picked.lat; _selLng = picked.lng; });
        _recenterPreview();
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Padding(
      padding: EdgeInsets.all(widget.embedded ? 0 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!widget.embedded) ...[
            Text(
              strings['pick_location'] ?? 'Pick location',
              style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
          ],
          // Map preview + actions grouped in one box.
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 180,
                  child: Stack(
                    children: [
                      fmap.FlutterMap(
                        mapController: _mapController,
                        options: fmap.MapOptions(
                          initialCenter: ll.LatLng(_defaultLat, _defaultLng),
                          initialZoom: 14,
                          interactionOptions: const fmap.InteractionOptions(
                            flags: fmap.InteractiveFlag.none,
                          ),
                          onTap: (tapPos, point) => _busy ? null : _adjustOnMap(),
                        ),
                        children: [
                          fmap.TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.dailywork.app',
                          ),
                          fmap.MarkerLayer(markers: [
                            fmap.Marker(
                              point: ll.LatLng(_defaultLat, _defaultLng),
                              width: 40, height: 40,
                              child: const Icon(Icons.location_pin,
                                  color: Colors.red, size: 36),
                            ),
                          ]),
                        ],
                      ),
                      if (_busy)
                        const Positioned.fill(
                          child: ColoredBox(
                            color: Color(0x33000000),
                            child: Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        key: const ValueKey('loc-use-gps'),
                        onPressed: _busy ? null : _useGps,
                        icon: const Icon(Icons.my_location),
                        label: Text(strings['use_my_location'] ?? 'Use my location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accent,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('loc-adjust-map'),
                        onPressed: _busy ? null : _adjustOnMap,
                        icon: const Icon(Icons.map_outlined),
                        label: Text(strings['adjust_on_map'] ?? 'Adjust on map'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}

class _MapPickerScreen extends StatefulWidget {
  const _MapPickerScreen({required this.initialLat, required this.initialLng});

  final double initialLat;
  final double initialLng;

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  late double _lat = widget.initialLat;
  late double _lng = widget.initialLng;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Adjust pin')),
      body: fmap.FlutterMap(
        options: fmap.MapOptions(
          initialCenter: ll.LatLng(_lat, _lng),
          initialZoom: 14,
          onPositionChanged: (pos, _) {
            final c = pos.center;
            setState(() { _lat = c.latitude; _lng = c.longitude; });
          },
        ),
        children: [
          fmap.TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.dailywork.app',
          ),
          fmap.MarkerLayer(markers: [
            fmap.Marker(
              point: ll.LatLng(_lat, _lng),
              width: 40, height: 40,
              child: const Icon(Icons.location_pin, color: Colors.red, size: 36),
            ),
          ]),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).pop(PickedLocation(lat: _lat, lng: _lng)),
        label: const Text('Use this spot'),
        icon: const Icon(Icons.check),
      ),
    );
  }
}
