import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../core/location/location_picker_screen.dart';
import '../../passenger/data/models.dart';
import '../../../l10n/app_localizations.dart';
import 'driver_providers.dart';
import 'driver_navigation.dart';

class MyRouteScreen extends ConsumerStatefulWidget {
  const MyRouteScreen({super.key});

  @override
  ConsumerState<MyRouteScreen> createState() => _MyRouteScreenState();
}

class _MyRouteScreenState extends ConsumerState<MyRouteScreen> {
  String _selectedTab = 'active';
  Future<void> _openRouteDrawer([Map<String, dynamic>? route]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * .82,
        child: _NewRouteForm(
            route: route,
            onDone: () {
              Navigator.pop(sheetContext);
              ref.invalidate(savedRoutesProvider);
            }),
      ),
    );
  }

  Future<void> _confirmDeleteRoute(Map<String, dynamic> route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete route?'),
        content: const Text(
            'This removes the saved route and its stops. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep route')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref
          .read(driverRepositoryProvider)
          .deleteRoute(route['id'] as String);
      ref.invalidate(savedRoutesProvider);
      ref.invalidate(activeJourneysProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Route deleted')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete this route.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final routes = ref.watch(savedRoutesProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final canAddRoute = vehicles.valueOrNull?.isNotEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
          title: Text(l10n.myRoute),
          automaticallyImplyLeading: false,
          actions: driverAppBarActions(context)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(children: [
            for (final tab in const [
              ('active', 'Active'),
              ('upcoming', 'Upcoming'),
              ('completed', 'Completed'),
              ('cancelled', 'Cancelled')
            ])
              Padding(
                padding: const EdgeInsets.only(right: 7),
                child: _RouteTab(
                    label: tab.$2,
                    selected: _selectedTab == tab.$1,
                    onTap: () => setState(() => _selectedTab = tab.$1)),
              ),
          ]),
        ),
        Expanded(
            child: routes.when(
          data: (list) =>
              _routesContent(context, list.cast<Map<String, dynamic>>()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.somethingWentWrong)),
        )),
        if (canAddRoute)
          SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6))),
                          onPressed: _openRouteDrawer,
                          child: const Text('Add New Route')))))
        else
          const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text('Add a vehicle first to create a route.')),
      ]),
      bottomNavigationBar: const DriverNavigation(currentIndex: 1),
    );
  }

  Widget _routesContent(
      BuildContext context, List<Map<String, dynamic>> routes) {
    final now = DateTime.now();
    final active = <Map<String, dynamic>>[];
    final upcoming = <Map<String, dynamic>>[];
    for (final route in routes) {
      final time =
          DateTime.tryParse(route['scheduled_at']?.toString() ?? '')?.toLocal();
      if (time != null && !time.isAfter(now)) {
        active.add(route);
      } else {
        upcoming.add(route);
      }
    }
    final visible = _selectedTab == 'active'
        ? active
        : _selectedTab == 'upcoming'
            ? upcoming
            : <Map<String, dynamic>>[];
    return LayoutBuilder(builder: (context, constraints) {
      final contentWidth =
          constraints.maxWidth > 1160 ? 1160.0 : constraints.maxWidth;
      final columns = contentWidth >= 1024
          ? 3
          : contentWidth >= 650
              ? 2
              : 1;
      final cardWidth = (contentWidth - (columns - 1) * 12) / columns;
      return ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          children: [
            const SizedBox(height: 8),
            Center(
                child: SizedBox(
                    width: contentWidth,
                    child: visible.isEmpty
                        ? _EmptyRouteState(tab: _selectedTab)
                        : Wrap(spacing: 12, runSpacing: 8, children: [
                            for (final route in visible)
                              SizedBox(
                                  width: cardWidth,
                                  child: _RouteCard(
                                    route: route,
                                    status: _selectedTab,
                                    onTap: () => _openRouteDrawer(route),
                                    onDelete: () => _confirmDeleteRoute(route),
                                  )),
                          ]))),
          ]);
    });
  }
}

class _RouteTab extends StatelessWidget {
  const _RouteTab(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: .10)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected
                    ? Colors.transparent
                    : Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      );
}

class _EmptyRouteState extends StatelessWidget {
  const _EmptyRouteState({required this.tab});
  final String tab;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant)),
        child: Column(children: [
          Icon(
              tab == 'upcoming'
                  ? Icons.schedule_outlined
                  : Icons.route_outlined,
              color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 8),
          Text('No $tab routes yet',
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(
              tab == 'upcoming'
                  ? 'Add a route with a future time to see it here.'
                  : 'Routes will appear here when available.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      );
}

class _RouteCard extends StatelessWidget {
  const _RouteCard(
      {required this.route,
      required this.status,
      required this.onTap,
      required this.onDelete});
  final Map<String, dynamic> route;
  final String status;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final stops = (route['stops'] as List? ?? []).cast<Map<String, dynamic>>();
    final start = stops.isEmpty ? 'Route' : _placeName(stops.first['name']);
    final end = stops.length < 2 ? '' : _placeName(stops.last['name']);
    final via = stops.map((s) => _placeName(s['name'])).join(' · ');
    final time =
        DateTime.tryParse(route['scheduled_at']?.toString() ?? '')?.toLocal();
    final isActive = status == 'active';
    final color = isActive ? Colors.green : Colors.blue;
    final dayTag = _dayTag(time);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 4, 9),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                          color: color.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(isActive ? Icons.circle : Icons.schedule,
                            size: 8, color: color),
                        const SizedBox(width: 3),
                        Text(isActive ? 'LIVE' : 'UPCOMING',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                                color: color))
                      ])),
                  const Spacer(),
                  if (dayTag != null)
                    Text(dayTag,
                        style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 7),
                Text(end.isEmpty ? start : '$start  →  $end',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(via,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 5),
                  Text(
                      time == null
                          ? 'Choose date'
                          : MaterialLocalizations.of(context)
                              .formatMediumDate(time),
                      style: const TextStyle(fontSize: 9)),
                  const SizedBox(width: 16),
                  Icon(Icons.schedule_outlined,
                      size: 12, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 5),
                  Text(
                      time == null
                          ? 'Choose time'
                          : MaterialLocalizations.of(context)
                              .formatTimeOfDay(TimeOfDay.fromDateTime(time)),
                      style: const TextStyle(fontSize: 9)),
                ]),
              ])),
          IconButton(
            tooltip: 'Delete route',
            visualDensity: VisualDensity.compact,
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 19),
          ),
        ]),
      ),
    );
  }

  String _placeName(dynamic raw) {
    final name = raw?.toString().trim() ?? '';
    if (name.isEmpty) return 'Place';
    return name.split(',').first.trim();
  }

  String? _dayTag(DateTime? time) {
    if (time == null) return null;
    final today = DateUtils.dateOnly(DateTime.now());
    final date = DateUtils.dateOnly(time);
    if (date == today) return 'Today';
    if (date == today.add(const Duration(days: 1))) return 'Tomorrow';
    return null;
  }
}

class _StopInput {
  _StopInput();
  LocationSelection? location;
}

class _NewRouteForm extends ConsumerStatefulWidget {
  const _NewRouteForm({required this.onDone, this.route});
  final VoidCallback onDone;
  final Map<String, dynamic>? route;

  @override
  ConsumerState<_NewRouteForm> createState() => _NewRouteFormState();
}

class _NewRouteFormState extends ConsumerState<_NewRouteForm> {
  final _nameController = TextEditingController();
  final List<_StopInput> _stops = [
    _StopInput(),
    _StopInput()
  ]; // start + destination minimum
  bool _saving = false;
  String? _error;
  DateTime _routeTime = DateTime.now();
  int? _mapStopIndex;

  @override
  void initState() {
    super.initState();
    final route = widget.route;
    if (route == null) return;
    _nameController.text = route['name']?.toString() ?? '';
    _routeTime =
        DateTime.tryParse(route['scheduled_at']?.toString() ?? '')?.toLocal() ??
            _routeTime;
    final rawStops = route['stops'] as List? ?? [];
    if (rawStops.length >= 2) {
      _stops.clear();
      for (final raw in rawStops) {
        final stop = raw as Map<String, dynamic>;
        final input = _StopInput();
        input.location = LocationSelection(
            name: stop['name']?.toString() ?? 'Place',
            point: LatLngPoint((stop['latitude'] as num).toDouble(),
                (stop['longitude'] as num).toDouble()));
        _stops.add(input);
      }
    }
  }

  void _addStop() =>
      setState(() => _stops.insert(_stops.length - 1, _StopInput()));

  void _removeStop(int index) {
    if (index > 0 && index < _stops.length - 1) {
      setState(() => _stops.removeAt(index));
    }
  }

  Future<void> _chooseStop(_StopInput stop, String title,
      {required bool allowMapSelection}) async {
    final location = await showModalBottomSheet<LocationSelection>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
          height: MediaQuery.of(sheetContext).size.height * .72,
          child: LocationPickerScreen(
              title: title,
              initial: stop.location,
              allowMapSelection: allowMapSelection)),
    );
    if (location != null && mounted) setState(() => stop.location = location);
  }

  void _showMapFor(int stopIndex) {
    setState(
        () => _mapStopIndex = _mapStopIndex == stopIndex ? null : stopIndex);
  }

  void _pickMapPoint(int stopIndex, LatLng point) {
    setState(() {
      _stops[stopIndex].location = LocationSelection(
        name: 'Pinned location',
        point: LatLngPoint(point.latitude, point.longitude),
      );
      _mapStopIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 12, 6),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                      width: 34,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                          child: Text(
                        widget.route == null ? 'Add New Route' : 'Edit Route',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700),
                      )),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ]),
                  ]),
            )),
        Expanded(
            child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._stops.asMap().entries.map((entry) {
                final i = entry.key;
                final stop = entry.value;
                final label = i == 0
                    ? l10n.startPoint
                    : (i == _stops.length - 1
                        ? l10n.destination
                        : 'Place on the way $i');
                final heading = i == 0
                    ? 'Starting point (Pickup)'
                    : i == _stops.length - 1
                        ? 'Destination (Drop)'
                        : 'Via point $i';
                return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(heading,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            if (i > 0 && i < _stops.length - 1)
                              IconButton(
                                  onPressed: () => _removeStop(i),
                                  icon: const Icon(Icons.close, size: 18))
                          ]),
                          InkWell(
                              onTap: () => _chooseStop(stop, label,
                                  allowMapSelection: true),
                              child: Container(
                                width: double.infinity,
                                height: 46,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 13),
                                decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant),
                                    borderRadius: BorderRadius.circular(10)),
                                child: Row(children: [
                                  Icon(Icons.search,
                                      size: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .outline),
                                  const SizedBox(width: 9),
                                  Expanded(
                                      child: Text(
                                          stop.location?.name ??
                                              (i == _stops.length - 1
                                                  ? 'Enter destination'
                                                  : 'Enter starting location'),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: stop.location == null
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .outline
                                                  : null))),
                                ]),
                              )),
                          if (i == 0) ...[
                            Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Row(children: [
                                  Expanded(
                                      child: _RouteActionButton(
                                    onTap: () => _chooseStop(stop, label,
                                        allowMapSelection: true),
                                    icon: Icons.my_location_outlined,
                                    title: 'Use my location',
                                    subtitle: 'Use precise location',
                                  )),
                                  const SizedBox(width: 10),
                                  Expanded(
                                      child: _RouteActionButton(
                                    onTap: () => _showMapFor(i),
                                    icon: Icons.map_outlined,
                                    title: _mapStopIndex == i
                                        ? 'Close map'
                                        : 'Select on map',
                                    subtitle: 'Pick on the map',
                                  )),
                                ])),
                            if (_mapStopIndex == i)
                              _InlineMap(
                                initial: stop.location?.point,
                                onPick: (point) => _pickMapPoint(i, point),
                              ),
                          ],
                        ]));
              }),
              const SizedBox(height: 1),
              const Text('Via points (Optional)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              Text('Add places in the order you will pass through.',
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 8),
              SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(44),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.centerLeft,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      textStyle: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    onPressed: _addStop,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add a via point'),
                  )),
              const SizedBox(height: 17),
              const Text('Date & Time',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _DateTimeTile(
                  icon: Icons.calendar_today_outlined,
                  label: 'Date',
                  value: MaterialLocalizations.of(context)
                      .formatMediumDate(_routeTime),
                  onTap: _pickRouteTime,
                )),
                const SizedBox(width: 12),
                Expanded(
                    child: _DateTimeTile(
                  icon: Icons.schedule_outlined,
                  label: 'Time',
                  value: MaterialLocalizations.of(context)
                      .formatTimeOfDay(TimeOfDay.fromDateTime(_routeTime)),
                  onTap: _pickRouteTime,
                )),
              ]),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(_error!,
                      style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 12),
            ],
          ),
        )),
        SafeArea(
            child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        widget.route == null ? 'Create route' : 'Save changes'),
              )),
        )),
      ],
    );
  }

  Future<void> _submit() async {
    for (final s in _stops) {
      if (s.location == null) {
        setState(() => _error = 'Choose a location for every stop');
        return;
      }
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final stopsPayload = _stops.asMap().entries.map((e) {
        return {
          'sequence': e.key,
          'name': e.value.location!.name,
          'latitude': e.value.location!.point.lat,
          'longitude': e.value.location!.point.lng,
        };
      }).toList();
      final repository = ref.read(driverRepositoryProvider);
      if (widget.route == null) {
        await repository.createRoute(
          name: _nameController.text.trim(),
          isSaved: true,
          stops: stopsPayload,
          scheduledAt: _routeTime,
        );
      } else {
        await repository.updateRoute(
          id: widget.route!['id'] as String,
          name: _nameController.text.trim(),
          stops: stopsPayload,
          scheduledAt: _routeTime,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Route saved. You can edit it anytime.')),
        );
      }
      widget.onDone();
    } catch (e) {
      final response = e is DioException ? e.response?.data : null;
      final message = response is Map &&
              (response['message'] ?? response['error']) is String
          ? (response['message'] ?? response['error']) as String
          : 'Could not save the route. Please try again.';
      setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickRouteTime() async {
    final date = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDate: _routeTime);
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_routeTime));
    if (time != null && mounted) {
      setState(() => _routeTime =
          DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(children: [
            Icon(icon, size: 17, color: Theme.of(context).colorScheme.outline),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(label, style: const TextStyle(fontSize: 10)),
                  const SizedBox(height: 1),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600)),
                ])),
          ]),
        ),
      );
}

class _RouteActionButton extends StatelessWidget {
  const _RouteActionButton({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            border:
                Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Container(
              width: 27,
              height: 27,
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon,
                  size: 16, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 7),
            Expanded(
                child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9,
                        color: Theme.of(context).colorScheme.outline)),
              ],
            )),
          ]),
        ),
      );
}

class _InlineMap extends StatelessWidget {
  const _InlineMap({this.initial, required this.onPick});
  final LatLngPoint? initial;
  final ValueChanged<LatLng> onPick;

  @override
  Widget build(BuildContext context) {
    final center = initial == null
        ? const LatLng(29.3803, 79.4636)
        : LatLng(initial!.lat, initial!.lng);
    return Container(
      height: 190,
      margin: const EdgeInsets.only(top: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Stack(children: [
        FlutterMap(
          key: ValueKey('${center.latitude}-${center.longitude}'),
          options: MapOptions(
            initialCenter: center,
            initialZoom: initial == null ? 8 : 14,
            onTap: (_, point) => onPick(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'app.dagadi',
            ),
            if (initial != null)
              MarkerLayer(markers: [
                Marker(
                  point: center,
                  width: 42,
                  height: 42,
                  child: Icon(Icons.location_pin,
                      size: 38, color: Theme.of(context).colorScheme.primary),
                )
              ]),
          ],
        ),
        const Positioned(
          left: 10,
          bottom: 8,
          child: IgnorePointer(
              child: Chip(label: Text('Tap the map to pin pickup'))),
        ),
      ]),
    );
  }
}
