import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import 'driver_navigation.dart';
import 'driver_providers.dart';

class DriverDashboardScreen extends ConsumerStatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  ConsumerState<DriverDashboardScreen> createState() =>
      _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends ConsumerState<DriverDashboardScreen> {
  String _period = 'today';
  bool _showUpcoming = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final revenue = ref.watch(revenueDashboardProvider);
    final routes = ref.watch(savedRoutesProvider);
    final vehicles = ref.watch(vehiclesProvider);
    final activeJourneys = ref.watch(activeJourneysProvider);

    return Scaffold(
      appBar: AppBar(
          title: const Text('Driver'), actions: driverAppBarActions(context)),
      bottomNavigationBar: const DriverNavigation(currentIndex: 0),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(revenueDashboardProvider);
          ref.invalidate(savedRoutesProvider);
          ref.invalidate(activeJourneysProvider);
        },
        child: ListView(padding: const EdgeInsets.all(16), children: [
          _journeyPanel(context, routes, vehicles, activeJourneys, l10n),
          const SizedBox(height: 22),
          Text('Overview', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          _periodSelector(),
          const SizedBox(height: 12),
          revenue.when(
            loading: () => const SizedBox(
                height: 102, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox.shrink(),
            data: (data) {
              final summary = data[_period] as Map<String, dynamic>? ?? {};
              final trips = summary['trip_count'] ?? 0;
              final parcels = summary['parcel_count'] ?? 0;
              final paise = (summary['revenue_paise'] ?? 0) as int;
              return Row(children: [
                Expanded(
                    child: _Metric(
                        icon: Icons.people_outline,
                        label: 'Requests',
                        value: '$trips',
                        tint: Colors.teal)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Metric(
                        icon: Icons.route_outlined,
                        label: 'Trips',
                        value: '$trips',
                        tint: Colors.orange)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Metric(
                        icon: Icons.inventory_2_outlined,
                        label: 'Parcels',
                        value: '$parcels',
                        tint: Colors.indigo)),
                const SizedBox(width: 8),
                Expanded(
                    child: _Metric(
                        icon: Icons.currency_rupee,
                        label: 'Earnings',
                        value: '₹${paise ~/ 100}',
                        tint: Colors.green)),
              ]);
            },
          ),
          const SizedBox(height: 22),
          Text('Your performance',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(children: const [
            Expanded(
                child: _PerformanceCard(
                    title: 'Earnings',
                    icon: Icons.show_chart,
                    detail: 'Updates as trips are completed')),
            SizedBox(width: 10),
            Expanded(
                child: _PerformanceCard(
                    title: 'Requests',
                    icon: Icons.bar_chart_outlined,
                    detail: 'Track your response')),
          ]),
          const SizedBox(height: 12),
          const _CompletionCard(),
          const SizedBox(height: 22),
          Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: _QuickAction(
                    icon: Icons.location_on_outlined,
                    title: 'Route updates',
                    subtitle: 'Keep stops current',
                    onTap: () => context.push('/driver/my-route'))),
            const SizedBox(width: 10),
            Expanded(
                child: _QuickAction(
                    icon: Icons.inbox_outlined,
                    title: 'Requests',
                    subtitle: 'Check new bookings',
                    onTap: () => context.push('/driver/requests'))),
            const SizedBox(width: 10),
            Expanded(
                child: _QuickAction(
                    icon: Icons.directions_car_outlined,
                    title: 'Vehicle',
                    subtitle: 'Manage vehicle',
                    onTap: () => context.push('/driver/vehicles'))),
          ]),
        ]),
      ),
    );
  }

  Widget _journeyPanel(
      BuildContext context,
      AsyncValue<List<dynamic>> routes,
      AsyncValue<List<dynamic>> vehicles,
      AsyncValue<List<dynamic>> activeJourneys,
      AppLocalizations l10n) {
    final routeList = routes.valueOrNull ?? const <dynamic>[];
    final activeList = activeJourneys.valueOrNull ?? const <dynamic>[];
    final now = DateTime.now();
    final active = activeList.cast<Map<String, dynamic>>().where((journey) {
      final time =
          DateTime.tryParse(journey['departure_time']?.toString() ?? '')
              ?.toLocal();
      return time == null || !time.isAfter(now);
    }).toList();
    final scheduledActive =
        routeList.cast<Map<String, dynamic>>().where((route) {
      final time =
          DateTime.tryParse(route['scheduled_at']?.toString() ?? '')?.toLocal();
      return time != null && !time.isAfter(now);
    }).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text(
                _showUpcoming
                    ? 'Upcoming journeys (${routeList.length})'
                    : 'Active journey',
                style: Theme.of(context).textTheme.titleMedium)),
        TextButton(
          onPressed: () => setState(() => _showUpcoming = !_showUpcoming),
          child: Text(_showUpcoming ? 'Active journey' : 'Upcoming journeys'),
        ),
      ]),
      const SizedBox(height: 6),
      if (_showUpcoming)
        _upcomingList(
            context, routeList, vehicles.valueOrNull ?? const <dynamic>[], l10n)
      else if (active.isNotEmpty)
        _activeJourneyCard(active.first)
      else if (scheduledActive.isNotEmpty)
        _scheduledRouteCard(context, scheduledActive.first,
            vehicles.valueOrNull ?? const <dynamic>[], l10n)
      else
        const Card(
            child: Padding(
                padding: EdgeInsets.all(18),
                child: Row(children: [
                  Icon(Icons.schedule_outlined),
                  SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('No active journey'),
                        Text(
                            'Your route appears here when its departure time begins.'),
                      ])),
                ]))),
    ]);
  }

  Widget _scheduledRouteCard(BuildContext context, Map<String, dynamic> route,
      List<dynamic> vehicles, AppLocalizations l10n) {
    final stops = (route['stops'] as List? ?? []).cast<Map<String, dynamic>>();
    final start = stops.isEmpty ? 'Pickup' : _placeName(stops.first['name']);
    final end =
        stops.length < 2 ? 'Destination' : _placeName(stops.last['name']);
    final via = stops.map((stop) => _placeName(stop['name'])).join(' · ');
    final scheduled =
        DateTime.tryParse(route['scheduled_at']?.toString() ?? '')?.toLocal();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 8, color: Colors.green),
                SizedBox(width: 4),
                Text('ACTIVE',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.green)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(
                scheduled == null
                    ? 'Route time is active'
                    : 'Started at ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(scheduled))}',
                style: Theme.of(context).textTheme.labelSmall),
          ]),
          const SizedBox(height: 10),
          Text('$start  →  $end',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(via,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: vehicles.isEmpty
                    ? null
                    : () => context.push('/driver/start-journey', extra: route),
                icon: const Icon(Icons.navigation_outlined, size: 18),
                label: Text(vehicles.isEmpty
                    ? 'Add a vehicle to start'
                    : l10n.startJourney),
              )),
        ]),
      ),
    );
  }

  String _placeName(dynamic raw) {
    final name = raw?.toString().trim() ?? '';
    return name.isEmpty ? 'Place' : name.split(',').first.trim();
  }

  Widget _activeJourneyCard(Map<String, dynamic> journey) {
    final stops =
        (journey['stops'] as List? ?? []).cast<Map<String, dynamic>>();
    final current = (journey['current_stop_sequence'] as num?)?.toInt() ?? 0;
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: const [
                  Icon(Icons.trip_origin, color: Colors.green, size: 14),
                  SizedBox(width: 7),
                  Text('On the way')
                ]),
                const SizedBox(height: 12),
                ...stops.map((stop) {
                  final passed =
                      ((stop['sequence'] as num?)?.toInt() ?? 0) <= current;
                  return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(children: [
                        Icon(
                            passed
                                ? Icons.check_circle
                                : Icons.radio_button_unchecked,
                            size: 17,
                            color: passed ? Colors.green : null),
                        const SizedBox(width: 10),
                        Text(stop['name']?.toString() ?? 'Stop'),
                      ]));
                }),
              ],
            )));
  }

  Widget _upcomingList(BuildContext context, List<dynamic> routes,
      List<dynamic> vehicles, AppLocalizations l10n) {
    if (routes.isEmpty)
      return Card(
          child: ListTile(
        leading: const Icon(Icons.alt_route_outlined),
        title: const Text('No upcoming journeys'),
        subtitle: const Text('Create a route to plan your next journey.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/driver/my-route'),
      ));
    return Column(
        children: routes.cast<Map<String, dynamic>>().map((route) {
      final stops =
          (route['stops'] as List? ?? []).cast<Map<String, dynamic>>();
      final routeName = stops.isEmpty
          ? (route['name'] ?? 'Saved route').toString()
          : stops.map((stop) => stop['name']).join(' → ');
      final scheduled =
          DateTime.tryParse(route['scheduled_at']?.toString() ?? '')?.toLocal();
      final scheduleText = scheduled == null
          ? 'Set a date and time'
          : '${MaterialLocalizations.of(context).formatMediumDate(scheduled)} · ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(scheduled))}';
      return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Card(
              child: ListTile(
            leading: const Icon(Icons.alt_route_outlined),
            title:
                Text(routeName, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(scheduleText),
            trailing: TextButton(
                onPressed: vehicles.isEmpty
                    ? null
                    : () => context.push('/driver/start-journey', extra: route),
                child: Text(l10n.startJourney)),
          )));
    }).toList());
  }

  Widget _periodSelector() => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final item in const [
          ('today', 'Today'),
          ('week', 'This week'),
          ('month', 'This month'),
          ('last_3_months', 'Last 3 months'),
          ('last_6_months', 'Last 6 months'),
          ('year', 'This year')
        ])
          Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(item.$2),
                selected: _period == item.$1,
                onSelected: (_) => setState(() => _period = item.$1),
              )),
      ]));
}

class _Metric extends StatelessWidget {
  const _Metric(
      {required this.icon,
      required this.label,
      required this.value,
      required this.tint});
  final IconData icon;
  final String label;
  final String value;
  final Color tint;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 17, color: tint),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall),
          ])));
}

class _PerformanceCard extends StatelessWidget {
  const _PerformanceCard(
      {required this.title, required this.icon, required this.detail});
  final String title;
  final IconData icon;
  final String detail;
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(detail, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(value: .64, minHeight: 6)),
          ])));
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard();
  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            SizedBox(
                width: 54,
                height: 54,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(
                      value: .92,
                      strokeWidth: 6,
                      color: Theme.of(context).colorScheme.primary),
                  const Text('92%'),
                ])),
            const SizedBox(width: 16),
            const Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Ride completion'),
                  SizedBox(height: 4),
                  Text(
                      'Keep routes and availability updated for a smoother passenger experience.'),
                ])),
          ])));
}

class _QuickAction extends StatelessWidget {
  const _QuickAction(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon,
                        size: 19, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text(title, style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 3),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ]))));
}
