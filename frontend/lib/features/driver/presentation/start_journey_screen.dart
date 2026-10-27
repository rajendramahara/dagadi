import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

import '../../../l10n/app_localizations.dart';
import 'driver_providers.dart';
import 'driver_navigation.dart';

class StartJourneyScreen extends ConsumerStatefulWidget {
  const StartJourneyScreen({required this.route, super.key});
  final Map<String, dynamic> route;

  @override
  ConsumerState<StartJourneyScreen> createState() => _StartJourneyScreenState();
}

class _StartJourneyScreenState extends ConsumerState<StartJourneyScreen> {
  String? _selectedVehicleId;
  DateTime _departureTime = DateTime.now();
  bool _starting = false;
  String? _error;

  Future<void> _chooseDepartureTime() async {
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 90)),
        initialDate: _departureTime);
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_departureTime));
    if (time != null && mounted)
      setState(() => _departureTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final stops = (widget.route['stops'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.startJourney),
          automaticallyImplyLeading: false,
          actions: driverAppBarActions(context)),
      bottomNavigationBar: const DriverNavigation(currentIndex: 1),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stops.map((s) => s['name']).join('  →  '),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
                onPressed: () => _openNavigation(stops),
                icon: const Icon(Icons.navigation_outlined),
                label: const Text('Open route in Google Maps')),
            const SizedBox(height: 20),
            Text('Departure time',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _chooseDepartureTime,
              icon: const Icon(Icons.schedule),
              label: Text(
                  '${MaterialLocalizations.of(context).formatMediumDate(_departureTime)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(_departureTime))}'),
            ),
            const SizedBox(height: 20),
            Text('Select vehicle',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            vehiclesAsync.when(
              data: (vehicles) {
                if (vehicles.isEmpty) {
                  return const Text('Add a vehicle first from your profile.');
                }
                if (vehicles.length == 1) {
                  final vehicle = vehicles.first as Map<String, dynamic>;
                  if (_selectedVehicleId == null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _selectedVehicleId == null) {
                        setState(
                            () => _selectedVehicleId = vehicle['id'] as String);
                      }
                    });
                  }
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.directions_car_outlined),
                    title: Text(
                        vehicle['registration_no']?.toString() ?? 'Vehicle'),
                    subtitle: const Text('Selected automatically'),
                  );
                }
                return RadioGroup<String>(
                  groupValue: _selectedVehicleId,
                  onChanged: (val) => setState(() => _selectedVehicleId = val),
                  child: Column(
                    children: vehicles.map((v) {
                      final vehicle = v as Map<String, dynamic>;
                      return RadioListTile<String>(
                        value: vehicle['id'] as String,
                        title: Text(
                            '${vehicle['model']} · ${vehicle['registration_no']}'),
                      );
                    }).toList(),
                  ),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text(l10n.somethingWentWrong),
            ),
            if (_error != null)
              Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const Spacer(),
            ElevatedButton(
              onPressed:
                  (_starting || _selectedVehicleId == null) ? null : _start,
              child: _starting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(l10n.startJourney),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final journey = await ref.read(driverRepositoryProvider).startJourney(
            routeId: widget.route['id'] as String,
            vehicleId: _selectedVehicleId!,
            departureTime: _departureTime,
          );
      await _recordCurrentPosition(journey['id'] as String);
      await ref
          .read(driverRepositoryProvider)
          .updateAvailability('passenger_parcel');
      if (mounted) context.go('/driver/active-trip');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _recordCurrentPosition(String journeyId) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      await ref.read(driverRepositoryProvider).updateJourneyPosition(
            journeyId: journeyId,
            latitude: position.latitude,
            longitude: position.longitude,
          );
    } catch (_) {
      // A journey still starts if GPS is unavailable; the driver can retry
      // location access from the device browser/app settings.
    }
  }

  Future<void> _openNavigation(List stops) async {
    if (stops.length < 2) return;
    final origin = '${stops.first['latitude']},${stops.first['longitude']}';
    final destination = '${stops.last['latitude']},${stops.last['longitude']}';
    final waypoints = stops
        .sublist(1, stops.length - 1)
        .map((stop) => '${stop['latitude']},${stop['longitude']}')
        .join('|');
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving${waypoints.isEmpty ? '' : '&waypoints=${Uri.encodeComponent(waypoints)}'}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
