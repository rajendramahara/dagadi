import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../data/models.dart';
import 'passenger_controller.dart';

class NearbyDriversScreen extends ConsumerWidget {
  const NearbyDriversScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final results = ref.watch(searchResultsProvider);
    final form = ref.watch(searchFormProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Matching drivers')),
      body: switch (results.status) {
        SearchStatus.loading =>
          const Center(child: CircularProgressIndicator()),
        SearchStatus.error =>
          Center(child: Text(results.error ?? l10n.somethingWentWrong)),
        SearchStatus.empty => Center(
            child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.search_off_outlined, size: 42),
                  const SizedBox(height: 12),
                  Text(l10n.noMatchingDrivers, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  const Text('Try another time or a nearby pickup point.',
                      textAlign: TextAlign.center)
                ]))),
        _ => ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: results.matches.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == 0)
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${results.matches.length} driver${results.matches.length == 1 ? '' : 's'} match your journey',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text('${form.fromName} → ${form.toName}',
                          style: Theme.of(context).textTheme.bodyMedium)
                    ]);
              final m = results.matches[i - 1];
              return _DriverCard(
                match: m,
                onTap: () => context.push('/passenger/ride-request', extra: {
                  'match': m,
                  'form': form,
                }),
              );
            },
          ),
      },
    );
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.match, required this.onTap});
  final JourneyMatch match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final availabilityLabel = switch (match.availability) {
      'parcel_only' => l10n.parcelOnly,
      'offline' => l10n.offline,
      _ => l10n.passengerAndParcel,
    };
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                  radius: 26,
                  child: Text(
                      match.driverName.isNotEmpty ? match.driverName[0] : '?')),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(match.driverName,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('${match.vehicleModel} · ${match.vehicleRegNo}',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                        'Pickup around ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(match.estimatedPickupTime))}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(availabilityLabel,
                          style: Theme.of(context).textTheme.labelSmall),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${match.distanceKm.toStringAsFixed(1)} km',
                      style: Theme.of(context).textTheme.bodyMedium),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      Text(match.driverRating.toStringAsFixed(1)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
