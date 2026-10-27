import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../data/driver_repository.dart';

final driverRepositoryProvider = Provider<DriverRepository>((ref) {
  return DriverRepository(ref.watch(apiClientProvider));
});

final revenueDashboardProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).revenueDashboard();
});

final incomingRequestsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).incomingRequests();
});

final pendingTicketsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).pendingTickets();
});

final savedRoutesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).savedRoutes();
});

final activeJourneysProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).activeJourneys();
});

final vehiclesProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).listVehicles();
});

final fleetsProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).fleets();
});

final driverProfileProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(driverRepositoryProvider).profile();
});
