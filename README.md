# Dagadi

Route-based passenger and parcel connectivity platform (not a taxi
dispatch app) — drivers publish journeys along fixed routes, passengers
and parcels join journeys that match their pickup/destination.

This repo currently contains a **working Phase 1 foundation**: real,
wired code (not UI mockups) implementing the core business rules from
the spec end-to-end. See `backend/README.md` and `frontend/README.md`
for setup instructions specific to each half.

## What's built (Phase 1)

**Backend** (Go + Fiber + SQLite, clean architecture, repository pattern):
- Dev-mode fixed-OTP / prod Firebase-Auth-ready authentication switch
- The full route-matching algorithm: pickup-on-route, destination-after-pickup,
  driver-hasn't-crossed-pickup, inside-visibility-radius, availability-accepts-type
- Ride/parcel request → accept/reject → pending ticket → complete-whenever-convenient
  → revenue-only-from-completed-tickets lifecycle
- Vehicles, fleets, saved routes, live journey position/stop tracking
- JWT auth + role middleware, rate limiting on auth endpoints

**Frontend** (Flutter, clean architecture, Riverpod, Material 3, en/hi localization):
- OTP login with role selection
- Passenger: Home, Search Route, Nearby Drivers (real matches), Ride Request
- Driver: Dashboard (real revenue), My Route (create + list), Start Journey,
  Active Trip, Incoming Requests (accept/reject), Complete Ticket

## Roadmap (suggested build order for next phases)

1. **Driver-side completeness**: fleet/vehicle management screens, document
   upload, parcel-specific request card styling
2. **Passenger-side completeness**: live tracking map screen (backend
   already accepts position updates), reviews, ticket history
3. **Notifications**: Firebase Cloud Messaging wiring on both ends for
   every event listed in the spec (OTP, request/accept/reject, arrival,
   ticket completed, review reminder, admin notices)
4. **Admin panel**: a separate app (Flutter Web or React) covering
   users, drivers, fleets, vehicles, routes, trips, parcels, tickets,
   revenue, reviews, reports/complaints, dashboard analytics, settings
5. **Maps integration**: swap the placeholder lat/lng text fields for
   Google Places Autocomplete + live map pin-drop and route polylines
6. **Hardening for production**: unit tests, input sanitization
   middleware, environment-tuned rate limits, PostgreSQL migration
   scripts, database backup strategy, structured logging/crash
   reporting, CI pipeline

Each phase builds on interfaces already in place (repository pattern on
the backend, feature folders on the frontend) so none of it requires
rewriting Phase 1.
