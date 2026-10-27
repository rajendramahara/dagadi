# Dagadi Backend (Go + Fiber + SQLite)

## Run locally

```bash
cd backend
cp .env.example .env
go mod tidy
go run ./cmd/server
```

Server starts on `:8080` (configurable via `PORT`). SQLite file is created
automatically at `DB_PATH` with WAL mode + foreign keys enabled, and
migrations run automatically on boot.

In `APP_ENV=development` (default), OTP requests always return
`DEV_FIXED_OTP` (default `123456`) and no SMS is sent — exactly per spec.
Switch to `APP_ENV=production` to require Firebase Phone Auth verification
(wire-up point: `internal/service/auth_service.go`).

## Architecture

```
cmd/server/main.go        -> wiring: config, db, repos, services, handlers, routes
internal/config           -> env-driven config (dev/prod OTP switch lives here only)
internal/database         -> connection + pragma + migration runner (SQLite-specific code lives ONLY here)
internal/models           -> plain domain structs, no persistence or HTTP knowledge
internal/repository       -> one file per aggregate, interface + sqlite impl
                              (swap to Postgres later = new struct implementing same interface)
internal/service          -> business logic: auth, route matching, booking lifecycle, revenue
internal/handler          -> Fiber HTTP handlers, thin - parse, call service, respond
internal/middleware       -> JWT auth + role-based authorization
pkg/utils                 -> jwt, otp, haversine geo distance, response envelope
```

## Migrating to PostgreSQL later

1. All IDs are TEXT UUIDs already (Postgres-native).
2. Timestamps are ISO-8601 strings (works as TIMESTAMPTZ).
3. Only `internal/database/db.go` and the migration file contain
   SQLite-specific syntax (`PRAGMA`, `lower(hex(randomblob(16)))` for OTP
   IDs). Replace those two spots, swap the driver import and `?` → `$1`
   placeholders in the repository layer, and nothing else changes.

## Core API routes

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | /api/v1/auth/otp/request | none | Send/issue OTP |
| POST | /api/v1/auth/otp/verify | none | Verify OTP, create account if new, return JWT |
| POST | /api/v1/auth/refresh | none | Rotate access token |
| POST | /api/v1/passenger/search | passenger | Route-matched driver search |
| POST | /api/v1/passenger/requests | passenger | Create ride/parcel request |
| GET  | /api/v1/passenger/bookings | passenger | List own bookings |
| POST | /api/v1/driver/routes | driver | Create route + stops |
| GET  | /api/v1/driver/routes/saved | driver | List saved routes |
| POST | /api/v1/driver/journeys | driver | Start a journey (go live) |
| POST | /api/v1/driver/journeys/:id/position | driver | Update live GPS position |
| POST | /api/v1/driver/journeys/:id/advance-stop | driver | Mark a stop as crossed |
| POST | /api/v1/driver/journeys/:id/complete | driver | End journey |
| PATCH | /api/v1/driver/availability | driver | passenger_parcel / parcel_only / offline |
| GET  | /api/v1/driver/requests | driver | Incoming pending bookings |
| POST | /api/v1/driver/bookings/:id/accept | driver | Accept -> auto-creates pending ticket |
| POST | /api/v1/driver/bookings/:id/reject | driver | Reject request |
| GET  | /api/v1/driver/tickets/pending | driver | Tickets awaiting completion |
| POST | /api/v1/driver/tickets/:id/complete | driver | Finalize fare -> becomes revenue |
| GET  | /api/v1/driver/revenue | driver | today/week/month/year summary |
| POST | /api/v1/driver/vehicles | driver | Add vehicle |
| POST | /api/v1/driver/fleets | driver | Create fleet |
| POST | /api/v1/driver/fleets/assign | driver | Assign driver to vehicle |

## Not yet implemented (see project roadmap)
Reviews, complaints/reports, FCM push notification dispatch, admin panel
endpoints, PostgreSQL migration scripts, unit tests, rate-limit tuning
per environment, request input sanitization middleware.
