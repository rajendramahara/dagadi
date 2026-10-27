import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';

import '../../../l10n/app_localizations.dart';
import 'driver_providers.dart';
import 'driver_navigation.dart';

class IncomingRequestsScreen extends ConsumerWidget {
  const IncomingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final requests = ref.watch(incomingRequestsProvider);

    return Scaffold(
      appBar: AppBar(
          title: const Text('Requests'),
          automaticallyImplyLeading: false,
          actions: driverAppBarActions(context)),
      body: requests.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.inbox_outlined, size: 42),
                      SizedBox(height: 12),
                      Text('No requests waiting for you.'),
                      SizedBox(height: 4),
                      Text('New ride and parcel requests will appear here.',
                          textAlign: TextAlign.center)
                    ])));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == 0)
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '${list.length} request${list.length == 1 ? '' : 's'} need a response',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      const Text(
                          'Accept only requests you can serve on your route.')
                    ]);
              final b = list[i - 1] as Map<String, dynamic>;
              final isParcel = b['booking_type'] == 'parcel';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                              isParcel
                                  ? Icons.local_shipping_outlined
                                  : Icons.person_outline,
                              size: 18),
                          const SizedBox(width: 6),
                          Text(isParcel ? l10n.parcelRequest : l10n.requestRide,
                              style: Theme.of(context).textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${b['pickup_name']}  →  ${b['drop_name']}',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (!isParcel)
                        Text('${b['passenger_count'] ?? 1} passenger(s)',
                            style: Theme.of(context).textTheme.bodySmall),
                      if (isParcel) ...[
                        Text(
                            'Weight: ${b['parcel_weight_kg'] ?? 'Not specified'} kg · Size: ${b['parcel_size'] ?? 'Not specified'}',
                            style: Theme.of(context).textTheme.bodySmall),
                        if ((b['parcel_image_data'] ?? '')
                            .toString()
                            .isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _showParcelImage(
                                context, b['parcel_image_data'] as String),
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('View parcel photo'),
                          ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await ref
                                    .read(driverRepositoryProvider)
                                    .rejectBooking(b['id'] as String);
                                ref.invalidate(incomingRequestsProvider);
                              },
                              child: Text(l10n.reject),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await ref
                                    .read(driverRepositoryProvider)
                                    .acceptBooking(b['id'] as String);
                                ref.invalidate(incomingRequestsProvider);
                                ref.invalidate(pendingTicketsProvider);
                              },
                              child: Text(l10n.accept),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l10n.somethingWentWrong)),
      ),
      bottomNavigationBar: const DriverNavigation(currentIndex: 2),
    );
  }
}

void _showParcelImage(BuildContext context, String encoded) {
  showDialog<void>(
      context: context,
      builder: (context) => Dialog(
              child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close))),
              Image.memory(base64Decode(encoded), fit: BoxFit.contain),
            ]),
          )));
}
