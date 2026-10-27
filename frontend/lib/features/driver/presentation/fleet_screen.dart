import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'driver_providers.dart';
import 'driver_navigation.dart';
import 'fleet_setup_screen.dart';

class FleetScreen extends ConsumerWidget {
  const FleetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fleets = ref.watch(fleetsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fleet management'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create fleet',
            onPressed: () => _openCreateFleet(context, ref),
          ),
          ...driverAppBarActions(context),
        ],
      ),
      bottomNavigationBar: const DriverNavigation(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(fleetsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Your fleets', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
                'Create a fleet and assign a Dagadi driver by mobile number. Drivers add their own vehicles.'),
            const SizedBox(height: 16),
            fleets.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Could not load fleets.'),
              data: (fleetList) => fleetList.isEmpty
                  ? const Card(
                      child: ListTile(
                        leading: Icon(Icons.groups_outlined),
                        title: Text('No fleet yet'),
                        subtitle: Text('Use + to create your first fleet.'),
                      ),
                    )
                  : Column(
                      children: fleetList
                          .map((raw) => _FleetCard(
                              fleet: raw as Map<String, dynamic>, ref: ref))
                          .toList()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openCreateFleet(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.of(sheetContext).size.height * .78,
        child: const FleetSetupScreen(embedded: true),
      ),
    );
    ref.invalidate(fleetsProvider);
  }
}

class _FleetCard extends StatelessWidget {
  const _FleetCard({required this.fleet, required this.ref});
  final Map<String, dynamic> fleet;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push('/driver/fleet/edit', extra: fleet),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.groups_outlined)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(fleet['name'].toString(),
                          style: Theme.of(context).textTheme.titleMedium)),
                  const Icon(Icons.edit_outlined, size: 18),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context, ref, fleet),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const SizedBox(height: 2),
              if (fleet['assigned_driver_name'] == null)
                const Text('No driver assigned yet.')
              else
                Row(children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          '${fleet['assigned_driver_name']} · ${fleet['assigned_driver_phone']}')),
                  const Text('Driver assigned'),
                ]),
            ],
          ),
        ),
      ));
}

Future<void> _confirmDelete(
    BuildContext context, WidgetRef ref, Map<String, dynamic> fleet) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_forever_outlined),
      title: const Text('Delete this fleet?'),
      content: Text(
          '“${fleet['name']}” will be removed and its assigned driver will be detached. No driver account or vehicle will be deleted.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep fleet')),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete fleet'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  try {
    await ref.read(driverRepositoryProvider).deleteFleet(fleet['id'] as String);
    ref.invalidate(fleetsProvider);
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this fleet.')));
  }
}
