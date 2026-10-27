-- Dagadi initial schema
-- Design notes for future PostgreSQL migration:
--   * All IDs are TEXT UUIDs (works identically in Postgres) instead of
--     SQLite's AUTOINCREMENT, so no rewrite is needed later.
--   * TIMESTAMP columns store ISO-8601 UTC strings (Postgres accepts these
--     directly when the column type becomes TIMESTAMPTZ).
--   * No SQLite-only pragmas or functions are used in application-facing
--     tables; PRAGMA statements live only in database/db.go.
--   * Money is stored as INTEGER paise/cents to avoid float rounding issues
--     across engines.

PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS users (
    id              TEXT PRIMARY KEY,
    phone           TEXT UNIQUE NOT NULL,
    name            TEXT,
    role            TEXT NOT NULL CHECK (role IN ('passenger','driver','admin')),
    language        TEXT NOT NULL DEFAULT 'en',
    is_active       INTEGER NOT NULL DEFAULT 1,
    deleted_at      TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_users_phone ON users(phone);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);

CREATE TABLE IF NOT EXISTS admin_credentials (
    id              TEXT PRIMARY KEY,
    username        TEXT UNIQUE NOT NULL,
    password_hash   TEXT NOT NULL,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS otp_codes (
    id              TEXT PRIMARY KEY,
    phone           TEXT NOT NULL,
    code            TEXT NOT NULL,
    expires_at      TIMESTAMP NOT NULL,
    consumed        INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_otp_phone ON otp_codes(phone);

CREATE TABLE IF NOT EXISTS driver_profiles (
    id                  TEXT PRIMARY KEY,
    user_id             TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    availability        TEXT NOT NULL DEFAULT 'offline'
                         CHECK (availability IN ('passenger_parcel','parcel_only','offline')),
    visibility_radius_m INTEGER NOT NULL DEFAULT 2000,
    rating_avg          REAL NOT NULL DEFAULT 0,
    rating_count        INTEGER NOT NULL DEFAULT 0,
    documents_verified  INTEGER NOT NULL DEFAULT 0,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS driver_documents (
    id          TEXT PRIMARY KEY,
    driver_id   TEXT NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    doc_type    TEXT NOT NULL,
    file_url    TEXT NOT NULL,
    verified    INTEGER NOT NULL DEFAULT 0,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS fleets (
    id          TEXT PRIMARY KEY,
    owner_id    TEXT NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    name        TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vehicles (
    id              TEXT PRIMARY KEY,
    fleet_id        TEXT REFERENCES fleets(id) ON DELETE SET NULL,
    owner_driver_id TEXT NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    assigned_driver_id TEXT REFERENCES driver_profiles(id) ON DELETE SET NULL,
    registration_no TEXT NOT NULL UNIQUE,
    model           TEXT,
    color           TEXT,
    capacity        INTEGER NOT NULL DEFAULT 4,
    is_active       INTEGER NOT NULL DEFAULT 1,
    deleted_at      TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_vehicles_owner ON vehicles(owner_driver_id);

CREATE TABLE IF NOT EXISTS routes (
    id              TEXT PRIMARY KEY,
    driver_id       TEXT NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    name            TEXT,
    is_saved        INTEGER NOT NULL DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_routes_driver ON routes(driver_id);

-- Ordered stop points for a route (start, intermediate stops, destination)
CREATE TABLE IF NOT EXISTS route_stops (
    id          TEXT PRIMARY KEY,
    route_id    TEXT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    sequence    INTEGER NOT NULL,
    name        TEXT NOT NULL,
    latitude    REAL NOT NULL,
    longitude   REAL NOT NULL,
    UNIQUE(route_id, sequence)
);
CREATE INDEX IF NOT EXISTS idx_route_stops_route ON route_stops(route_id, sequence);

CREATE TABLE IF NOT EXISTS journeys (
    id                  TEXT PRIMARY KEY,
    driver_id           TEXT NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    route_id            TEXT NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
    vehicle_id          TEXT NOT NULL REFERENCES vehicles(id) ON DELETE CASCADE,
    departure_time      TIMESTAMP NOT NULL,
    status              TEXT NOT NULL DEFAULT 'active'
                         CHECK (status IN ('active','completed','cancelled')),
    current_stop_sequence INTEGER NOT NULL DEFAULT 0, -- last stop the driver has crossed
    current_latitude   REAL,
    current_longitude  REAL,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_journeys_driver ON journeys(driver_id);
CREATE INDEX IF NOT EXISTS idx_journeys_status ON journeys(status);

CREATE TABLE IF NOT EXISTS bookings (
    id              TEXT PRIMARY KEY,
    journey_id      TEXT NOT NULL REFERENCES journeys(id) ON DELETE CASCADE,
    passenger_id    TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    booking_type    TEXT NOT NULL CHECK (booking_type IN ('ride','parcel')),
    pickup_name     TEXT NOT NULL,
    pickup_lat      REAL NOT NULL,
    pickup_lng      REAL NOT NULL,
    pickup_sequence INTEGER NOT NULL,
    drop_name       TEXT NOT NULL,
    drop_lat        REAL NOT NULL,
    drop_lng        REAL NOT NULL,
    drop_sequence   INTEGER NOT NULL,
    note            TEXT,
    status          TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','accepted','rejected','cancelled','completed')),
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_bookings_journey ON bookings(journey_id);
CREATE INDEX IF NOT EXISTS idx_bookings_passenger ON bookings(passenger_id);
CREATE INDEX IF NOT EXISTS idx_bookings_status ON bookings(status);

CREATE TABLE IF NOT EXISTS tickets (
    id              TEXT PRIMARY KEY,
    booking_id      TEXT NOT NULL UNIQUE REFERENCES bookings(id) ON DELETE CASCADE,
    driver_id       TEXT NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    fare_paise      INTEGER,
    payment_method  TEXT CHECK (payment_method IN ('cash','upi','other')),
    notes           TEXT,
    status          TEXT NOT NULL DEFAULT 'pending'
                     CHECK (status IN ('pending','completed')),
    completed_at    TIMESTAMP,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_tickets_driver ON tickets(driver_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON tickets(status);

CREATE TABLE IF NOT EXISTS reviews (
    id          TEXT PRIMARY KEY,
    ticket_id   TEXT NOT NULL REFERENCES tickets(id) ON DELETE CASCADE,
    passenger_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    driver_id   TEXT NOT NULL REFERENCES driver_profiles(id) ON DELETE CASCADE,
    rating      INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment     TEXT,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS complaints (
    id          TEXT PRIMARY KEY,
    ticket_id   TEXT REFERENCES tickets(id) ON DELETE SET NULL,
    reported_by TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    against_user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reason      TEXT NOT NULL,
    status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dismissed')),
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notifications (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type        TEXT NOT NULL,
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    data_json   TEXT,
    read_at     TIMESTAMP,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);

CREATE TABLE IF NOT EXISTS fcm_tokens (
    id          TEXT PRIMARY KEY,
    user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token       TEXT NOT NULL UNIQUE,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
