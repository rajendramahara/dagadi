import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_login_screen.dart';

class AdminUserDetailScreen extends ConsumerStatefulWidget {
  const AdminUserDetailScreen({super.key, required this.user});
  final Map<String, dynamic> user;
  @override
  ConsumerState<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends ConsumerState<AdminUserDetailScreen> {
  String _period = 'today';
  int _driverTab = 0;
  @override
  Widget build(BuildContext context) {
    final request = ref.watch(_detailProvider((widget.user['id'] as String, _period)));
    final fleets = ref.watch(_adminFleetsProvider);
    return Scaffold(appBar: AppBar(title: const Text('User activity'), actions: request.maybeWhen(data: (data) => [TextButton(onPressed: () => _changeStatus(data), child: Text(data['is_active'] == true ? 'Disable' : 'Enable'))], orElse: () => [])), body: request.when(loading: () => const Center(child: CircularProgressIndicator()), error: (_, __) => const Center(child: Text('Could not load user activity.')), data: (data) => ListView(padding: const EdgeInsets.all(20), children: [
      Row(children: [Stack(clipBehavior: Clip.none, children: [CircleAvatar(radius: 28, child: Text((data['name'] ?? '?').toString().substring(0, 1).toUpperCase())), if (data['is_active'] != true) const Positioned(right: -4, bottom: -4, child: CircleAvatar(radius: 11, child: Icon(Icons.block, size: 14)))]), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['name'] ?? 'User', style: Theme.of(context).textTheme.titleLarge), Text('${data['phone']} · ${data['role']}'), Text('Joined Dagadi: ${data['created_at']}', style: Theme.of(context).textTheme.bodySmall), Text(data['last_login_at'] == null ? 'No login recorded yet' : 'Last login: ${data['last_login_at']}', style: Theme.of(context).textTheme.bodySmall)]))]),
      const SizedBox(height: 22), DropdownButtonFormField<String>(initialValue: _period, decoration: const InputDecoration(labelText: 'Activity period'), items: const [DropdownMenuItem(value: 'today', child: Text('Today')), DropdownMenuItem(value: 'week', child: Text('This week')), DropdownMenuItem(value: 'month', child: Text('This month')), DropdownMenuItem(value: '3m', child: Text('Last 3 months')), DropdownMenuItem(value: '6m', child: Text('Last 6 months')), DropdownMenuItem(value: 'year', child: Text('This year'))], onChanged: (value) => setState(() => _period = value!)),
      if (data['role'] == 'driver') ...[const SizedBox(height: 20), SegmentedButton<int>(segments: const [ButtonSegment(value: 0, label: Text('Activity')), ButtonSegment(value: 1, label: Text('Fleets'))], selected: {_driverTab}, onSelectionChanged: (value) => setState(() => _driverTab = value.first)), const SizedBox(height: 14)],
      if (data['role'] != 'driver' || _driverTab == 0) ...[Text(data['role'] == 'driver' ? 'Driver activity' : 'Passenger activity', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 10)],
      if (data['role'] == 'driver' && _driverTab == 0) ...[
        Wrap(spacing: 10, runSpacing: 10, children: [_Stat('Journeys', data['journey_count'], Icons.route_outlined), _Stat('Vehicles', data['vehicle_count'], Icons.directions_car_outlined), _Stat('Fleets', data['fleet_count'], Icons.groups_outlined), _Stat('Tickets', data['completed_tickets'], Icons.receipt_long_outlined), _Stat('Earnings', '₹${((data['revenue_paise'] as num) / 100).toStringAsFixed(0)}', Icons.account_balance_wallet_outlined)]),
        const SizedBox(height: 24), Text('Journey progress', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 10), _ActivityBars(data: data, labels: const ['Journeys', 'Tickets']),
      ] else if (data['role'] != 'driver') ...[
        Wrap(spacing: 10, runSpacing: 10, children: [_Stat('Ride requests', data['ride_requests'], Icons.directions_car_outlined), _Stat('Parcel requests', data['parcel_requests'], Icons.local_shipping_outlined), _Stat('Driver reviews', data['review_count'], Icons.star_outline)]),
        const SizedBox(height: 24), Text('Passenger progress', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 10), _ActivityBars(data: data, labels: const ['Bookings', 'Tickets']),
      ],
      if (data['role'] == 'driver' && _driverTab == 1) fleets.when(loading: () => const Center(child: CircularProgressIndicator()), error: (_, __) => const Text('Could not load fleets.'), data: (items) { final own = items.cast<Map<String, dynamic>>().where((fleet) => fleet['owner_phone'] == data['phone']).toList(); return own.isEmpty ? const Card(child: ListTile(leading: Icon(Icons.groups_outlined), title: Text('No fleets created by this driver.'))) : Column(children: own.map((fleet) => Card(child: ListTile(leading: const Icon(Icons.groups_outlined), title: Text(fleet['name']), subtitle: Text('Assigned driver: ${fleet['driver_name'] ?? 'Not assigned'}${fleet['driver_phone'] == null ? '' : ' · ${fleet['driver_phone']}'}')))).toList()); }),
      const SizedBox(height: 18), const Text('Counts in this view are filtered by the selected period.'),
    ])));
  }

  Future<void> _changeStatus(Map<String, dynamic> data) async {
    final nextStatus = data['is_active'] != true;
    if (!nextStatus) {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(icon: const Icon(Icons.block_outlined), title: const Text('Disable this account?'), content: Text('${data['name']} will not be able to log in until an admin enables this account again.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Disable account'))]));
      if (confirmed != true) return;
    }
    await ref.read(adminRepositoryProvider).setUserActive(userId: data['id'] as String, isActive: nextStatus);
    ref.invalidate(_detailProvider((widget.user['id'] as String, _period)));
  }
}

final _detailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, (String, String)>((ref, key) => ref.watch(adminRepositoryProvider).userDetails(key.$1, key.$2));
final _adminFleetsProvider = FutureProvider.autoDispose((ref) => ref.watch(adminRepositoryProvider).fleets());

class _Stat extends StatelessWidget { const _Stat(this.label, this.value, this.icon); final String label; final dynamic value; final IconData icon; @override Widget build(BuildContext context) => SizedBox(width: 154, child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 20), const SizedBox(height: 12), Text('$value', style: Theme.of(context).textTheme.headlineSmall), Text(label, style: Theme.of(context).textTheme.labelMedium)])))); }
class _ActivityBars extends StatelessWidget { const _ActivityBars({required this.data, required this.labels}); final Map<String, dynamic> data; final List<String> labels; @override Widget build(BuildContext context) { final values = <String, num>{for (final label in labels) label: (label == 'Bookings' ? data['booking_count'] : label == 'Journeys' ? data['journey_count'] : data['completed_tickets']) as num}; final max = values.values.fold<num>(1, (a, b) => a > b ? a : b); return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: values.entries.map((entry) => Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [SizedBox(width: 72, child: Text(entry.key)), Expanded(child: LinearProgressIndicator(value: entry.value / max, minHeight: 10, borderRadius: BorderRadius.circular(6))), const SizedBox(width: 10), Text('${entry.value}')]))).toList()))); } }
