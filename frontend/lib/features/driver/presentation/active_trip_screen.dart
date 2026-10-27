import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'driver_navigation.dart';
import 'driver_providers.dart';

class ActiveTripScreen extends ConsumerStatefulWidget {
  const ActiveTripScreen({super.key});
  @override
  ConsumerState<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends ConsumerState<ActiveTripScreen> {
  StreamSubscription<Position>? _gps;
  String? _journeyId;
  LatLng? _position;

  @override
  void dispose() {
    _gps?.cancel();
    super.dispose();
  }

  Future<void> _track(String id) async {
    if (_journeyId == id) return;
    _journeyId = id;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied)
      permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;
    await _gps?.cancel();
    _gps = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.high, distanceFilter: 15))
        .listen((p) {
      if (mounted) setState(() => _position = LatLng(p.latitude, p.longitude));
      ref.read(driverRepositoryProvider).updateJourneyPosition(
          journeyId: id, latitude: p.latitude, longitude: p.longitude);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Journey navigation'),
            automaticallyImplyLeading: false,
            actions: driverAppBarActions(context)),
        bottomNavigationBar: const DriverNavigation(currentIndex: 1),
        body: ref.watch(activeJourneysProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(
                  child: Text('Could not load your active journey.')),
              data: (list) {
                if (list.isEmpty)
                  return const Center(
                      child: Text(
                          'Start an active route from Home to see navigation here.'));
                final journey = list.first as Map<String, dynamic>;
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _track(journey['id'] as String));
                return _NavigationMap(
                    journey: journey, driverPosition: _position);
              },
            ),
      );
}

class _NavigationMap extends StatefulWidget {
  const _NavigationMap({required this.journey, this.driverPosition});
  final Map<String, dynamic> journey;
  final LatLng? driverPosition;
  @override
  State<_NavigationMap> createState() => _NavigationMapState();
}

class _NavigationMapState extends State<_NavigationMap> {
  List<LatLng>? _roadPath;
  @override
  void initState() {
    super.initState();
    _loadRoadPath();
  }

  @override
  void didUpdateWidget(covariant _NavigationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.journey['id'] != widget.journey['id']) {
      _roadPath = null;
      _loadRoadPath();
    }
  }

  List<Map<String, dynamic>> get _stops =>
      (widget.journey['stops'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .where((s) => s['latitude'] is num && s['longitude'] is num)
          .toList();
  List<LatLng> get _stopPoints => _stops
      .map((s) => LatLng((s['latitude'] as num).toDouble(),
          (s['longitude'] as num).toDouble()))
      .toList();

  Future<void> _loadRoadPath() async {
    final stops = _stops;
    if (stops.length < 2) return;
    final coords =
        stops.map((s) => '${s['longitude']},${s['latitude']}').join(';');
    try {
      final res = await Dio().get<Map<String, dynamic>>(
          'https://router.project-osrm.org/route/v1/driving/$coords',
          queryParameters: {'overview': 'full', 'geometries': 'geojson'});
      final routes = res.data?['routes'] as List?;
      final geometry = routes?.isNotEmpty == true
          ? (routes!.first as Map)['geometry'] as Map?
          : null;
      final raw = geometry?['coordinates'] as List?;
      final points = raw
              ?.whereType<List>()
              .where((p) => p.length >= 2)
              .map((p) =>
                  LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
              .toList() ??
          const <LatLng>[];
      if (mounted && points.length > 1) setState(() => _roadPath = points);
    } catch (_) {
      // Use the stop-to-stop fallback if a road-routing service is unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final stops = _stops;
    final stopPoints = _stopPoints;
    final path = _roadPath ?? stopPoints;
    final stored = widget.journey['current_latitude'] is num &&
            widget.journey['current_longitude'] is num
        ? LatLng((widget.journey['current_latitude'] as num).toDouble(),
            (widget.journey['current_longitude'] as num).toDouble())
        : null;
    final driver = widget.driverPosition ?? stored;
    final center = _center(path.isEmpty ? stopPoints : path);
    final currentStop =
        (widget.journey['current_stop_sequence'] as num?)?.toInt() ?? 0;
    return Stack(children: [
      FlutterMap(
        key: ValueKey('${widget.journey['id']}-${path.length}'),
        options: MapOptions(initialCenter: center, initialZoom: _zoom(path)),
        children: [
          TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.dagadi'),
          if (path.length > 1)
            PolylineLayer(polylines: [
              Polyline(
                  points: path,
                  strokeWidth: 5,
                  color: Theme.of(context).colorScheme.primary)
            ]),
          MarkerLayer(markers: [
            for (var i = 0; i < stopPoints.length; i++)
              Marker(
                  point: stopPoints[i],
                  width: 36,
                  height: 36,
                  child: Icon(
                      i == 0
                          ? Icons.trip_origin
                          : i == stopPoints.length - 1
                              ? Icons.location_pin
                              : Icons.circle,
                      size: i == stopPoints.length - 1 ? 30 : 16,
                      color: i <= currentStop
                          ? Colors.green
                          : Theme.of(context).colorScheme.primary)),
            if (driver != null)
              Marker(
                  point: driver,
                  width: 48,
                  height: 48,
                  child: Container(
                      decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3)),
                      child: const Icon(Icons.navigation,
                          color: Colors.white, size: 23))),
          ]),
        ],
      ),
      SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(14),
              child: Align(
                  alignment: Alignment.topCenter,
                  child: _Summary(stops: stops, hasGps: driver != null)))),
    ]);
  }

  LatLng _center(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(29.3803, 79.4636);
    return LatLng(
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length,
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length);
  }

  double _zoom(List<LatLng> points) {
    if (points.length < 2) return 14;
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final span = ((lats.reduce((a, b) => a > b ? a : b) -
                        lats.reduce((a, b) => a < b ? a : b))
                    .abs())
                .clamp(0, 99) >
            ((lngs.reduce((a, b) => a > b ? a : b) -
                        lngs.reduce((a, b) => a < b ? a : b))
                    .abs())
                .clamp(0, 99)
        ? (lats.reduce((a, b) => a > b ? a : b) -
                lats.reduce((a, b) => a < b ? a : b))
            .abs()
        : (lngs.reduce((a, b) => a > b ? a : b) -
                lngs.reduce((a, b) => a < b ? a : b))
            .abs();
    return span > 1.2
        ? 7
        : span > .45
            ? 8
            : span > .12
                ? 10
                : 12;
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.stops, required this.hasGps});
  final List<Map<String, dynamic>> stops;
  final bool hasGps;
  @override
  Widget build(BuildContext context) {
    String place(dynamic v) {
      final s = v?.toString().trim() ?? '';
      return s.isEmpty ? 'Place' : s.split(',').first.trim();
    }

    final from = stops.isEmpty ? 'Pickup' : place(stops.first['name']);
    final to = stops.length < 2 ? 'Destination' : place(stops.last['name']);
    return Card(
        child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(children: [
              Icon(hasGps ? Icons.gps_fixed : Icons.gps_not_fixed,
                  size: 18,
                  color: hasGps
                      ? Colors.green
                      : Theme.of(context).colorScheme.outline),
              const SizedBox(width: 9),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('$from  →  $to',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(
                        hasGps
                            ? 'Live location shared'
                            : 'Allow location to share live position',
                        style: Theme.of(context).textTheme.labelSmall)
                  ])),
            ])));
  }
}
