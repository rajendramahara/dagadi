import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'passenger_controller.dart';

class PassengerBookingsScreen extends ConsumerWidget {
  const PassengerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookings = ref.watch(passengerBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My activity')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(passengerBookingsProvider),
        child: bookings.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Center(
              child: Text('Could not load bookings. Pull down to try again.')),
          data: (list) {
            if (list.isEmpty)
              return ListView(children: const [
                SizedBox(height: 180),
                Center(child: Icon(Icons.receipt_long_outlined, size: 42)),
                SizedBox(height: 12),
                Center(child: Text('Your rides and parcels will appear here.'))
              ]);
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                if (index == 0)
                  return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Rides & parcels',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        const Text('Track every request in one place.')
                      ]);
                final booking = list[index - 1] as Map<String, dynamic>;
                final isParcel = booking['booking_type'] == 'parcel';
                final status = (booking['status'] ?? 'pending').toString();
                return Card(
                    child: ListTile(
                  leading: Icon(isParcel
                      ? Icons.local_shipping_outlined
                      : Icons.directions_car_outlined),
                  title: Text(
                      '${booking['pickup_name']} → ${booking['drop_name']}'),
                  subtitle: Text(isParcel ? 'Parcel request' : 'Ride request'),
                  trailing: _StatusChip(status: status),
                ));
              },
            );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accepted = status == 'accepted';
    final rejected = status == 'rejected';
    final color = rejected
        ? scheme.error
        : accepted
            ? Colors.green
            : scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12)),
      child: Text(status[0].toUpperCase() + status.substring(1),
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
