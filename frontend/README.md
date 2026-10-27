# Dagadi Frontend (Flutter)

## Run locally

```bash
cd frontend
flutter pub get
flutter gen-l10n
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

`10.0.2.2` is the Android emulator's alias for your host machine's
`localhost` where the Go backend runs. On iOS simulator use
`http://localhost:8080`; on a physical device use your machine's LAN IP.

## Architecture (clean architecture, feature-first)

```
lib/
  core/
    theme/        -> Material 3 theme, light + dark (AppTheme)
    network/      -> ApiClient (Dio) with token storage + refresh
    di/           -> Riverpod providers shared across features
    router/        -> go_router route table
  l10n/            -> app_en.arb, app_hi.arb - EVERY string lives here, no hardcoded text
  features/
    auth/
      data/         -> AuthRepository (talks to /auth endpoints)
      presentation/ -> AuthController (state) + LoginScreen + OtpScreen
    passenger/
      data/         -> models (JourneyMatch, LatLngPoint) + PassengerRepository
      presentation/ -> search state controller + Home/Search/NearbyDrivers/RideRequest screens
    driver/
      data/         -> DriverRepository (routes, journeys, tickets, revenue)
      presentation/ -> providers + Dashboard/MyRoute/StartJourney/ActiveTrip/IncomingRequests/CompleteTicket screens
```

State management: **Riverpod** (StateNotifier for mutable flows like auth
and search, FutureProvider.autoDispose for read-only server data like the
revenue dashboard and incoming requests).

## What's real vs. placeholder right now

- All API calls in `data/*_repository.dart` hit the real backend routes
  documented in `backend/README.md` - nothing is mocked.
- Location input (`SearchRouteScreen`, `MyRouteScreen`) currently uses
  plain text fields with example coordinates instead of Google Places
  Autocomplete + map pin-drop, marked with `TODO(maps-integration)`
  comments at the two call sites. Wiring in `google_maps_flutter` +
  Places Autocomplete does not require changing the search/booking flow
  underneath it.
- Firebase (`firebase_core`, `firebase_messaging`, `firebase_auth`) are
  in `pubspec.yaml` but not yet initialized in `main.dart` - needed for
  push notifications and production phone auth (see roadmap).

## Not yet implemented (see project roadmap)
Fleet/vehicle management UI, parcel-specific request UI, reviews screen,
driver document upload, FCM push notification handling, live GPS
tracking map (journey position updates exist on the backend, no map UI
consumes them yet), Admin panel (entirely separate, not started),
offline handling/caching, and widget/unit tests.
