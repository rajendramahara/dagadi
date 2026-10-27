CREATE TABLE IF NOT EXISTS user_login_events (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    logged_in_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX IF NOT EXISTS idx_user_login_events_user_time ON user_login_events(user_id, logged_in_at DESC);
