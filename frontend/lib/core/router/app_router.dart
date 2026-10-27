import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/session_gate_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/profile_screen.dart';
import '../../features/auth/presentation/account_setup_screen.dart';
import '../../features/auth/presentation/role_picker_screen.dart';
import '../../features/passenger/data/models.dart';
import '../../features/passenger/presentation/home_screen.dart';
import '../../features/passenger/presentation/bookings_screen.dart';
import '../../features/passenger/presentation/nearby_drivers_screen.dart';
import '../../features/passenger/presentation/passenger_controller.dart';
import '../../features/passenger/presentation/ride_request_screen.dart';
import '../../features/passenger/presentation/search_route_screen.dart';
import '../../features/driver/presentation/active_trip_screen.dart';
import '../../features/driver/presentation/complete_ticket_screen.dart';
import '../../features/driver/presentation/dashboard_screen.dart';
import '../../features/driver/presentation/incoming_requests_screen.dart';
import '../../features/driver/presentation/my_route_screen.dart';
import '../../features/driver/presentation/start_journey_screen.dart';
import '../../features/driver/presentation/vehicles_screen.dart';
import '../../features/driver/presentation/fleet_screen.dart';
import '../../features/driver/presentation/fleet_setup_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/presentation/admin_login_screen.dart';
import '../../features/admin/presentation/admin_users_screen.dart';
import '../../features/admin/presentation/admin_user_detail_screen.dart';
import '../../features/admin/presentation/admin_fleets_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SessionGateScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
    GoRoute(
        path: '/account-setup',
        builder: (context, state) => const AccountSetupScreen()),
    GoRoute(
        path: '/choose-role',
        builder: (context, state) => const RolePickerScreen()),
    GoRoute(
        path: '/profile/:role',
        builder: (context, state) =>
            ProfileScreen(role: state.pathParameters['role']!)),

    // Passenger
    GoRoute(
        path: '/passenger/home',
        builder: (context, state) => const PassengerHomeScreen()),
    GoRoute(
        path: '/passenger/bookings',
        builder: (context, state) => const PassengerBookingsScreen()),
    GoRoute(
        path: '/passenger/search',
        builder: (context, state) => const SearchRouteScreen()),
    GoRoute(
        path: '/passenger/nearby-drivers',
        builder: (context, state) => const NearbyDriversScreen()),
    GoRoute(
      path: '/passenger/ride-request',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return RideRequestScreen(
          match: extra['match'] as JourneyMatch,
          form: extra['form'] as SearchFormState,
        );
      },
    ),

    // Driver
    GoRoute(
        path: '/driver/dashboard',
        builder: (context, state) => const DriverDashboardScreen()),
    GoRoute(
        path: '/driver/my-route',
        builder: (context, state) => const MyRouteScreen()),
    GoRoute(
      path: '/driver/start-journey',
      builder: (context, state) =>
          StartJourneyScreen(route: state.extra as Map<String, dynamic>),
    ),
    GoRoute(
        path: '/driver/active-trip',
        builder: (context, state) => const ActiveTripScreen()),
    GoRoute(
        path: '/driver/requests',
        builder: (context, state) => const IncomingRequestsScreen()),
    GoRoute(
      path: '/driver/complete-ticket',
      builder: (context, state) =>
          CompleteTicketScreen(ticket: state.extra as Map<String, dynamic>),
    ),
    GoRoute(
        path: '/driver/vehicles',
        builder: (context, state) => const VehiclesScreen()),
    GoRoute(
        path: '/driver/fleet',
        builder: (context, state) => const FleetScreen()),
    GoRoute(
        path: '/driver/fleet/create',
        builder: (context, state) => const FleetSetupScreen()),
    GoRoute(
        path: '/driver/fleet/edit',
        builder: (context, state) =>
            FleetSetupScreen(fleet: state.extra as Map<String, dynamic>)),

    // Admin
    GoRoute(
        path: '/admin/login',
        builder: (context, state) => const AdminLoginScreen()),
    GoRoute(
        path: '/admin/dashboard',
        builder: (context, state) => const AdminDashboardScreen()),
    GoRoute(
        path: '/admin/users',
        builder: (context, state) =>
            AdminUsersScreen(initialRole: state.uri.queryParameters['role'])),
    GoRoute(
        path: '/admin/users/detail',
        builder: (context, state) =>
            AdminUserDetailScreen(user: state.extra as Map<String, dynamic>)),
    GoRoute(
        path: '/admin/fleets',
        builder: (context, state) => const AdminFleetsScreen()),
  ],
);
