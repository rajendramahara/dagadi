import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import 'passenger_controller.dart';

class PassengerHomeScreen extends ConsumerWidget {
  const PassengerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final bookings = ref.watch(passengerBookingsProvider);

    return Scaffold(
      appBar: AppBar(
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l10n.appName),
        Text('Passenger mode active',
            style: Theme.of(context).textTheme.labelSmall)
      ])),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 104),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What do you need today?',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('Choose a service, then tell us where and when.',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: _ModeButton(
                    label: 'Find a ride',
                    icon: Icons.directions_car_outlined,
                    selected:
                        ref.watch(searchFormProvider).bookingType == 'ride',
                    onTap: () => ref
                        .read(searchFormProvider.notifier)
                        .update((s) => s.copyWith(bookingType: 'ride')))),
            const SizedBox(width: 12),
            Expanded(
                child: _ModeButton(
                    label: 'Send a parcel',
                    icon: Icons.local_shipping_outlined,
                    selected:
                        ref.watch(searchFormProvider).bookingType == 'parcel',
                    onTap: () => ref
                        .read(searchFormProvider.notifier)
                        .update((s) => s.copyWith(bookingType: 'parcel')))),
          ]),
          const SizedBox(height: 24),
          bookings.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) {
              final active = items
                  .cast<Map<String, dynamic>?>()
                  .where((b) =>
                      b?['status'] == 'pending' || b?['status'] == 'accepted')
                  .firstOrNull;
              if (active == null) return const SizedBox.shrink();
              return Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.location_searching),
                  title: const Text('Booking in progress'),
                  subtitle:
                      Text('${active['pickup_name']} → ${active['drop_name']}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/passenger/bookings'),
                ),
              );
            },
          ),
          const Spacer(),
          Center(
              child: Text('Your route and time help us find the right driver.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center)),
        ]),
      ),
      bottomSheet: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 8),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(shape: const RoundedRectangleBorder()),
          onPressed: () => context.push('/passenger/search'),
          icon: Icon(ref.watch(searchFormProvider).bookingType == 'parcel'
              ? Icons.local_shipping_outlined
              : Icons.search),
          label: Text(ref.watch(searchFormProvider).bookingType == 'parcel'
              ? 'Find parcel driver'
              : 'Find a ride'),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 1) context.push('/passenger/bookings');
          if (index == 2) _showHelp(context);
          if (index == 3) context.push('/profile/passenger');
        },
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.home_outlined), label: l10n.home),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              label: l10n.bookings),
          const NavigationDestination(
              icon: Icon(Icons.help_outline), label: 'Help'),
          NavigationDestination(
              icon: const Icon(Icons.person_outline), label: l10n.profile),
        ],
      ),
    );
  }
}

void _showHelp(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
        child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How can we help?',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const ListTile(
                leading: Icon(Icons.route_outlined),
                title: Text('No matching journey?'),
                subtitle: Text(
                    'Try a nearby pickup stop or search at another time.')),
            const ListTile(
                leading: Icon(Icons.report_problem_outlined),
                title: Text('Problem with a booking?'),
                subtitle: Text('Open My bookings to check its latest status.')),
          ]),
    )),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton(
      {required this.label,
      required this.icon,
      required this.selected,
      required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? scheme.primary
          : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: selected ? scheme.onPrimary : scheme.onSurface),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      color: selected ? scheme.onPrimary : scheme.onSurface)),
            ],
          ),
        ),
      ),
    );
  }
}
