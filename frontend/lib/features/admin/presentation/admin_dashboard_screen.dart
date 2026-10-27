import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_login_screen.dart';

final _adminDashboardProvider = FutureProvider.autoDispose(
    (ref) => ref.watch(adminRepositoryProvider).dashboard());

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(_adminDashboardProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Operations'), actions: [
        IconButton(
            onPressed: () => ref.invalidate(_adminDashboardProvider),
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh')
      ]),
      body: dashboard.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(
            child: Text('Could not load operations. Refresh to try again.')),
        data: (data) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(_adminDashboardProvider),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Text('Today at a glance',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text('Live activity and items needing action.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 16),
              SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Overview')),
                    ButtonSegment(value: 1, label: Text('Live tracking')),
                    ButtonSegment(value: 2, label: Text('Attention'))
                  ],
                  selected: {
                    _tab
                  },
                  onSelectionChanged: (value) =>
                      setState(() => _tab = value.first)),
              const SizedBox(height: 20),
              if (_tab == 0) _Overview(data: data),
              if (_tab == 1) _LiveTracking(data: data),
              if (_tab == 2) _Attention(data: data),
            ])),
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) {
    final revenue = ((data['revenue_today_paise'] ?? 0) as int) / 100;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 12, runSpacing: 12, children: [
        _Metric('Total users', '${data['total_users']}', Icons.people_outline,
            onTap: () => context.push('/admin/users')),
        _Metric('Drivers', '${data['total_drivers']}', Icons.drive_eta_outlined,
            onTap: () => context.push('/admin/users?role=driver')),
        _Metric(
            'Live trips', '${data['live_trips']}', Icons.location_searching),
        _Metric('GPS reporting', '${data['gps_reporting_journeys'] ?? 0}',
            Icons.gps_fixed),
        _Metric('GPS missing', '${data['gps_missing_journeys'] ?? 0}',
            Icons.gps_off),
        _Metric('Today’s revenue', '₹${revenue.toStringAsFixed(0)}',
            Icons.account_balance_wallet_outlined),
      ]),
      const SizedBox(height: 24),
      Text('Service quality', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(
          child: Column(children: [
        ListTile(
            leading: const Icon(Icons.star_outline),
            title: const Text('Average driver rating'),
            trailing:
                Text((data['avg_driver_rating'] as num).toStringAsFixed(1))),
        const Divider(height: 1),
        ListTile(
            leading: const Icon(Icons.cancel_outlined),
            title: const Text('Cancellation rate'),
            trailing: Text(
                '${((data['cancellation_rate'] as num) * 100).toStringAsFixed(1)}%'))
      ])),
    ]);
  }
}

class _LiveTracking extends StatelessWidget {
  const _LiveTracking({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  const Icon(Icons.location_searching),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(
                          '${data['live_trips']} live · ${data['gps_reporting_journeys'] ?? 0} reporting GPS · ${data['gps_missing_journeys'] ?? 0} need an update'))
                ]))),
      ]);
}

class _Attention extends StatelessWidget {
  const _Attention({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Items that need follow-up',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _Queue(
            icon: Icons.receipt_long_outlined,
            label: 'Tickets awaiting completion',
            count: data['pending_tickets'] ?? 0,
            detail:
                'These do not count toward revenue until drivers complete them.'),
        _Queue(
            icon: Icons.local_shipping_outlined,
            label: 'Pending parcel requests',
            count: data['pending_parcels'] ?? 0,
            detail:
                'Check whether a suitable driver is available for these routes.'),
      ]);
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value, this.icon, {this.onTap});
  final String label, value;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 160,
      child: Card(
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon),
                        const SizedBox(height: 16),
                        Text(label,
                            style: Theme.of(context).textTheme.labelMedium),
                        Text(value,
                            style: Theme.of(context).textTheme.headlineSmall)
                      ])))));
}

class _Queue extends StatelessWidget {
  const _Queue(
      {required this.icon,
      required this.label,
      required this.count,
      required this.detail});
  final IconData icon;
  final String label, detail;
  final dynamic count;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          subtitle: Text(detail),
          trailing: Text('$count',
              style: Theme.of(context).textTheme.headlineSmall)));
}
