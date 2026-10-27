import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../features/passenger/data/models.dart';

class LocationSelection {
  const LocationSelection({required this.name, required this.point});
  final String name;
  final LatLngPoint point;
}

/// Lets a user search for a place, select a point from the map, or use GPS.
/// Nominatim is used only to turn a typed place name into a coordinate; route
/// matching continues to use the app backend's coordinate-based API.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key, required this.title, this.initial, this.allowMapSelection = true});
  final String title;
  final LocationSelection? initial;
  final bool allowMapSelection;

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _query = TextEditingController();
  final _map = MapController();
  final _dio = Dio();
  LatLng _center = const LatLng(29.3803, 79.4636); // Uttarakhand
  LatLng? _selected;
  String? _selectedName;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _selected = LatLng(initial.point.lat, initial.point.lng);
      _center = _selected!;
      _selectedName = initial.name;
      _query.text = initial.name;
    }
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _pick(LatLng point, {String? name}) {
    setState(() {
      _selected = point;
      _center = point;
      _selectedName = name ?? _query.text.trim();
      _error = null;
    });
    _map.move(point, 15);
  }

  Future<void> _searchPlace() async {
    final query = _query.text.trim();
    if (query.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final response = await _dio.get<List<dynamic>>(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {'q': query, 'format': 'jsonv2', 'limit': 1},
        options: Options(headers: {'User-Agent': 'Dagadi location picker'}),
      );
      final result = response.data?.isNotEmpty == true ? response.data!.first as Map<String, dynamic> : null;
      if (result == null) {
        setState(() => _error = 'Place not found. Try a more specific name or choose it on the map.');
        return;
      }
      _pick(LatLng(double.parse(result['lat'] as String), double.parse(result['lon'] as String)),
          name: result['display_name'] as String);
    } catch (_) {
      setState(() => _error = 'Could not find that place. Check your connection or choose it on the map.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    setState(() { _loading = true; _error = null; });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        throw StateError('Location permission was not granted.');
      }
      final position = await Geolocator.getCurrentPosition();
      _query.text = 'Current location';
      _pick(LatLng(position.latitude, position.longitude), name: 'Current location');
    } catch (e) {
      setState(() => _error = e is StateError ? e.message.toString() : 'Could not get your current location.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _confirm() {
    final point = _selected;
    if (point == null) {
      setState(() => _error = widget.allowMapSelection ? 'Search for a place, tap the map, or use your current location.' : 'Search for a place or use your current location.');
      return;
    }
    Navigator.of(context).pop(LocationSelection(
      name: _selectedName?.isNotEmpty == true ? _selectedName! : 'Pinned location',
      point: LatLngPoint(point.latitude, point.longitude),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: TextField(controller: _query, onSubmitted: (_) => _searchPlace(), decoration: const InputDecoration(labelText: 'Search a place'))),
              IconButton(onPressed: _loading ? null : _searchPlace, icon: const Icon(Icons.search)),
              IconButton(onPressed: _loading ? null : _useCurrentLocation, tooltip: 'Use current location', icon: const Icon(Icons.my_location)),
            ]),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          if (widget.allowMapSelection) Expanded(child: FlutterMap(
            mapController: _map,
            options: MapOptions(initialCenter: _center, initialZoom: 9, onTap: (_, point) => _pick(point, name: 'Pinned location')),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'app.dagadi'),
              if (_selected != null) MarkerLayer(markers: [Marker(point: _selected!, width: 48, height: 48, child: const Icon(Icons.location_pin, color: Colors.red, size: 44))]),
            ],
          )) else const Spacer(),
          Padding(padding: const EdgeInsets.all(16), child: SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _confirm, child: const Text('Use this location')))),
        ]),
      );
}
