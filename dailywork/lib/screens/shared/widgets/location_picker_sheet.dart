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
  });

  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;
  final void Function(PickedLocation) onPicked;

  @override
  ConsumerState<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends ConsumerState<LocationPickerSheet> {
  bool _busy = false;
  String? _error;

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
      final pos = await Geolocator.getCurrentPosition();
      widget.onPicked(PickedLocation(lat: pos.latitude, lng: pos.longitude));
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      setState(() { _error = 'Could not read GPS'; _busy = false; });
    }
  }

  Future<void> _adjustOnMap() async {
    final picked = await Navigator.of(context).push<PickedLocation>(
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(
          initialLat: widget.initialLat ?? 12.9716,
          initialLng: widget.initialLng ?? 77.5946,
        ),
      ),
    );
    if (picked != null) {
      widget.onPicked(picked);
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _typeAddress() async {
    final ctrl = TextEditingController(text: widget.initialAddress ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Type address'),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Use')),
        ],
      ),
    );
    if (result == null || result.trim().isEmpty) return;
    widget.onPicked(PickedLocation(
      lat: widget.initialLat ?? 12.9716,
      lng: widget.initialLng ?? 77.5946,
      address: result.trim(),
    ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(stringsProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            strings['pick_location'] ?? 'Pick location',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            key: const ValueKey('loc-use-gps'),
            onPressed: _busy ? null : _useGps,
            icon: const Icon(Icons.my_location),
            label: Text(strings['use_my_location'] ?? 'Use my location'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accent, foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('loc-adjust-map'),
            onPressed: _busy ? null : _adjustOnMap,
            icon: const Icon(Icons.map_outlined),
            label: Text(strings['adjust_on_map'] ?? 'Adjust on map'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('loc-type-address'),
            onPressed: _busy ? null : _typeAddress,
            icon: const Icon(Icons.edit_outlined),
            label: Text(strings['type_address'] ?? 'Type address'),
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
