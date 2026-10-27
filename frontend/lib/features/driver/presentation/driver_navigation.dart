import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'driver_providers.dart';

/// Persistent workspace navigation for drivers. Profile and Vehicles are
/// top-level tools, so no bottom tab is highlighted while either is open.
class DriverNavigation extends StatelessWidget {
  const DriverNavigation({super.key, this.currentIndex});
  final int? currentIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const items = [
      (Icons.home_outlined, Icons.home, 'Home', '/driver/dashboard'),
      (
        Icons.alt_route_outlined,
        Icons.alt_route,
        'My route',
        '/driver/my-route'
      ),
      (Icons.inbox_outlined, Icons.inbox, 'Requests', '/driver/requests'),
      (
        Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet,
        'Earnings',
        '/driver/active-trip'
      ),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 70,
        decoration: BoxDecoration(
            border: Border(top: BorderSide(color: scheme.outlineVariant))),
        child: Row(
            children: List.generate(items.length, (index) {
          final item = items[index];
          final active = currentIndex == index;
          return Expanded(
              child: InkWell(
            onTap: () => context.go(item.$4),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(active ? item.$2 : item.$1,
                  color: active ? scheme.primary : scheme.onSurfaceVariant),
              const SizedBox(height: 3),
              Text(item.$3,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: active ? scheme.primary : scheme.onSurfaceVariant,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ));
        })),
      ),
    );
  }
}

List<Widget> driverAppBarActions(BuildContext context,
        {bool profileActive = false, bool vehiclesActive = false}) =>
    [
      _DriverProfileIcon(active: profileActive),
      IconButton(
        icon: Icon(Icons.directions_car_outlined,
            color:
                vehiclesActive ? Theme.of(context).colorScheme.primary : null),
        tooltip: 'Vehicles',
        onPressed: () => context.push('/driver/vehicles'),
      ),
    ];

class _DriverProfileIcon extends ConsumerWidget {
  const _DriverProfileIcon({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final routes = ref.watch(savedRoutesProvider);
    final profile = ref.watch(driverProfileProvider);
    final hasRoute = routes.valueOrNull?.isNotEmpty ?? false;
    final availability = profile.valueOrNull?['availability']?.toString();
    final marker = availability == 'parcel_only'
        ? Icons.inventory_2_outlined
        : availability == 'offline'
            ? Icons.do_not_disturb_on_outlined
            : hasRoute
                ? null
                : Icons.home_outlined;
    return IconButton(
      tooltip: 'Profile',
      onPressed: () => context.push('/profile/driver'),
      icon: Stack(clipBehavior: Clip.none, children: [
        Icon(Icons.account_circle_outlined,
            color: active ? scheme.primary : scheme.onSurfaceVariant),
        Positioned(
          right: -4,
          bottom: -4,
          child: marker == null
              ? Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 2)))
              : Icon(marker,
                  size: 14,
                  color: active ? scheme.primary : scheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}
