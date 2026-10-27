import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'admin_login_screen.dart';

final _adminUsersProvider = FutureProvider.autoDispose((ref) async {
  final dashboard = await ref.watch(adminRepositoryProvider).dashboard();
  return ((dashboard['recent_users'] as List?) ?? [])
      .cast<Map<String, dynamic>>();
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key, this.initialRole});
  final String? initialRole;
  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _search = TextEditingController();
  late String _role;
  String _period = 'today';
  bool _showDisabled = false;
  @override
  void initState() {
    super.initState();
    _role = widget.initialRole ?? 'all';
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(_adminUsersProvider);
    return Scaffold(
        appBar: AppBar(
            title: Text(_role == 'driver'
                ? 'Drivers'
                : _role == 'passenger'
                    ? 'Passengers'
                    : 'All Users')),
        body: Column(children: [
          Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'Search name or mobile number')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: ChoiceChip(
                          label: const Text('All'),
                          selected: _role == 'all',
                          onSelected: (_) => setState(() => _role = 'all'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: ChoiceChip(
                          label: const Text('Passengers'),
                          selected: _role == 'passenger',
                          onSelected: (_) =>
                              setState(() => _role = 'passenger'))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: ChoiceChip(
                          label: const Text('Drivers'),
                          selected: _role == 'driver',
                          onSelected: (_) => setState(() => _role = 'driver')))
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                    initialValue: _period,
                    decoration:
                        const InputDecoration(labelText: 'Activity period'),
                    items: const [
                      DropdownMenuItem(value: 'today', child: Text('Today')),
                      DropdownMenuItem(value: 'week', child: Text('This week')),
                      DropdownMenuItem(
                          value: 'month', child: Text('This month')),
                      DropdownMenuItem(
                          value: '3m', child: Text('Last 3 months')),
                      DropdownMenuItem(
                          value: '6m', child: Text('Last 6 months')),
                      DropdownMenuItem(value: 'year', child: Text('This year'))
                    ],
                    onChanged: (value) => setState(() => _period = value!)),
                CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _showDisabled,
                    onChanged: (value) =>
                        setState(() => _showDisabled = value ?? false),
                    title: const Text('Show disabled users'),
                    controlAffinity: ListTileControlAffinity.leading),
                const SizedBox(height: 8),
                const Text(
                    'Activity includes bookings, journeys, and owned vehicles.',
                    textAlign: TextAlign.left),
              ])),
          Expanded(
              child: users.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) =>
                      const Center(child: Text('Could not load users')),
                  data: (items) {
                    final query = _search.text.trim().toLowerCase();
                    final filtered = items.where((u) {
                      final roles = ((u['roles'] as List?) ?? [u['role']])
                          .map((role) => role.toString())
                          .toList();
                      final matchesRole =
                          _role == 'all' || roles.contains(_role);
                      final matchesStatus = _showDisabled
                          ? u['is_active'] != true
                          : u['is_active'] == true;
                      final searchable =
                          '${u['name']} ${u['phone']}'.toLowerCase();
                      return matchesRole &&
                          matchesStatus &&
                          (query.isEmpty || searchable.contains(query));
                    }).toList();
                    if (filtered.isEmpty) {
                      return const Center(
                          child: Text('No users match these filters.'));
                    }
                    return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final user = filtered[index];
                          final active = user['is_active'] == true;
                          final roles =
                              ((user['roles'] as List?) ?? [user['role']])
                                  .map((role) => role.toString())
                                  .toList();
                          return Card(
                              child: ListTile(
                                  leading:
                                      Stack(clipBehavior: Clip.none, children: [
                                    CircleAvatar(
                                        child: Text((user['name'] ?? '?')
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase())),
                                    if (!active)
                                      const Positioned(
                                          right: -5,
                                          bottom: -5,
                                          child: CircleAvatar(
                                              radius: 11,
                                              child:
                                                  Icon(Icons.block, size: 14)))
                                  ]),
                                  title: Text('${user['name']}'),
                                  subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('${user['phone']}'),
                                        const SizedBox(height: 5),
                                        Wrap(
                                            spacing: 5,
                                            children: roles
                                                .map((role) => Chip(
                                                    label: Text(role == 'driver'
                                                        ? 'Driver'
                                                        : 'Passenger'),
                                                    visualDensity:
                                                        VisualDensity.compact))
                                                .toList())
                                      ]),
                                  isThreeLine: true,
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => context.push(
                                      '/admin/users/detail',
                                      extra: user)));
                        });
                  })),
        ]));
  }
}
