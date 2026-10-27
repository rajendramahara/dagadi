package repository

import (
	"database/sql"
	"time"
)

type AdminRepository interface {
	FindByUsername(username string) (id, passwordHash string, err error)
	UpdateCredentials(username, oldUsername, newPasswordHash string) error
	SeedDefaultIfEmpty(id, username, passwordHash string) error

	CountUsersByRole(role string) (int, error)
	CountUsers() (int, error)
	CountActiveJourneys() (int, error)
	CountActiveJourneysWithGPS(hasGPS bool) (int, error)
	RevenueTodayAllDrivers() (int64, error)
	CountPendingTickets() (int, error)
	CountPendingBookingsByType(bookingType string) (int, error)
	AverageDriverRating() (float64, error)
	CancellationRate() (float64, error)
	TopRoutesByTripCount(limit int) ([]TopRoute, error)
	RecentUserActivity(limit int) ([]UserActivity, error)
	SetUserActive(userID string, active bool) error
	UserDetails(userID string, since time.Time) (*UserDetail, error)
	ListFleets() ([]FleetInfo, error)
}

type UserDetail struct {
	UserActivity
	FleetCount       int   `json:"fleet_count"`
	CompletedTickets int   `json:"completed_tickets"`
	RevenuePaise     int64 `json:"revenue_paise"`
	RideRequests     int   `json:"ride_requests"`
	ParcelRequests   int   `json:"parcel_requests"`
	ReviewCount      int   `json:"review_count"`
}

type FleetInfo struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	OwnerName   string  `json:"owner_name"`
	OwnerPhone  string  `json:"owner_phone"`
	DriverName  *string `json:"driver_name,omitempty"`
	DriverPhone *string `json:"driver_phone,omitempty"`
}

type TopRoute struct {
	RouteName string
	TripCount int
}

type UserActivity struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	Phone        string   `json:"phone"`
	Role         string   `json:"role"`
	Roles        []string `json:"roles"`
	BookingCount int      `json:"booking_count"`
	JourneyCount int      `json:"journey_count"`
	VehicleCount int      `json:"vehicle_count"`
	IsActive     bool     `json:"is_active"`
	LastLoginAt  *string  `json:"last_login_at,omitempty"`
	CreatedAt    string   `json:"created_at"`
}

type sqliteAdminRepo struct{ db *sql.DB }

func NewAdminRepository(db *sql.DB) AdminRepository {
	return &sqliteAdminRepo{db: db}
}

func (r *sqliteAdminRepo) FindByUsername(username string) (string, string, error) {
	row := r.db.QueryRow(`SELECT id, password_hash FROM admin_credentials WHERE username = ?`, username)
	var id, hash string
	if err := row.Scan(&id, &hash); err != nil {
		if err == sql.ErrNoRows {
			return "", "", nil
		}
		return "", "", err
	}
	return id, hash, nil
}

func (r *sqliteAdminRepo) UpdateCredentials(username, oldUsername, newPasswordHash string) error {
	_, err := r.db.Exec(`UPDATE admin_credentials SET username = ?, password_hash = ?, updated_at = CURRENT_TIMESTAMP
		WHERE username = ?`, username, newPasswordHash, oldUsername)
	return err
}

func (r *sqliteAdminRepo) SetUserActive(userID string, active bool) error {
	result, err := r.db.Exec(`UPDATE users SET is_active = ? WHERE id = ? AND deleted_at IS NULL`, active, userID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *sqliteAdminRepo) UserDetails(userID string, since time.Time) (*UserDetail, error) {
	from := since.Format("2006-01-02 15:04:05")
	row := r.db.QueryRow(`SELECT u.id, u.name, u.phone, u.role, u.is_active, u.created_at, (SELECT MAX(logged_in_at) FROM user_login_events e WHERE e.user_id = u.id),
		(SELECT COUNT(*) FROM bookings b WHERE b.passenger_id = u.id AND b.created_at >= ?),
		(SELECT COUNT(*) FROM journeys j JOIN driver_profiles d ON d.id = j.driver_id WHERE d.user_id = u.id AND j.departure_time >= ?),
		(SELECT COUNT(*) FROM vehicles v JOIN driver_profiles d ON d.id = v.owner_driver_id WHERE d.user_id = u.id AND v.created_at >= ?),
		(SELECT COUNT(*) FROM fleets f JOIN driver_profiles d ON d.id = f.owner_id WHERE d.user_id = u.id AND f.created_at >= ?),
		(SELECT COUNT(*) FROM tickets t JOIN bookings b ON b.id = t.booking_id JOIN journeys j ON j.id = b.journey_id JOIN driver_profiles d ON d.id = j.driver_id WHERE d.user_id = u.id AND t.status = 'completed' AND t.completed_at >= ?),
		(SELECT COALESCE(SUM(t.fare_paise), 0) FROM tickets t JOIN bookings b ON b.id = t.booking_id JOIN journeys j ON j.id = b.journey_id JOIN driver_profiles d ON d.id = j.driver_id WHERE d.user_id = u.id AND t.status = 'completed' AND t.completed_at >= ?),
		(SELECT COUNT(*) FROM bookings b WHERE b.passenger_id = u.id AND b.booking_type = 'ride' AND b.created_at >= ?),
		(SELECT COUNT(*) FROM bookings b WHERE b.passenger_id = u.id AND b.booking_type = 'parcel' AND b.created_at >= ?),
		(SELECT COUNT(*) FROM reviews r WHERE r.passenger_id = u.id AND r.created_at >= ?)
		FROM users u WHERE u.id = ? AND u.deleted_at IS NULL`, from, from, from, from, from, from, from, from, from, userID)
	var detail UserDetail
	var lastLogin sql.NullString
	if err := row.Scan(&detail.ID, &detail.Name, &detail.Phone, &detail.Role, &detail.IsActive, &detail.CreatedAt, &lastLogin, &detail.BookingCount, &detail.JourneyCount, &detail.VehicleCount, &detail.FleetCount, &detail.CompletedTickets, &detail.RevenuePaise, &detail.RideRequests, &detail.ParcelRequests, &detail.ReviewCount); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	if lastLogin.Valid {
		detail.LastLoginAt = &lastLogin.String
	}
	return &detail, nil
}

func (r *sqliteAdminRepo) ListFleets() ([]FleetInfo, error) {
	rows, err := r.db.Query(`SELECT f.id, f.name, owner.name, owner.phone, assigned.name, assigned.phone FROM fleets f JOIN driver_profiles od ON od.id = f.owner_id JOIN users owner ON owner.id = od.user_id LEFT JOIN fleet_driver_assignments a ON a.fleet_id = f.id LEFT JOIN driver_profiles ad ON ad.id = a.driver_id LEFT JOIN users assigned ON assigned.id = ad.user_id ORDER BY f.created_at DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []FleetInfo
	for rows.Next() {
		var f FleetInfo
		if err := rows.Scan(&f.ID, &f.Name, &f.OwnerName, &f.OwnerPhone, &f.DriverName, &f.DriverPhone); err != nil {
			return nil, err
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// SeedDefaultIfEmpty inserts a bootstrap admin account on first boot only.
func (r *sqliteAdminRepo) SeedDefaultIfEmpty(id, username, passwordHash string) error {
	row := r.db.QueryRow(`SELECT COUNT(*) FROM admin_credentials`)
	var count int
	if err := row.Scan(&count); err != nil {
		return err
	}
	if count > 0 {
		return nil
	}
	_, err := r.db.Exec(`INSERT INTO admin_credentials (id, username, password_hash) VALUES (?, ?, ?)`,
		id, username, passwordHash)
	return err
}

func (r *sqliteAdminRepo) CountUsersByRole(role string) (int, error) {
	query := `SELECT COUNT(*) FROM users WHERE is_active = 1 AND deleted_at IS NULL`
	if role == "driver" {
		query += ` AND EXISTS (SELECT 1 FROM driver_profiles d WHERE d.user_id = users.id)`
	}
	var n int
	return n, r.db.QueryRow(query).Scan(&n)
}

func (r *sqliteAdminRepo) CountUsers() (int, error) {
	row := r.db.QueryRow(`SELECT COUNT(*) FROM users WHERE deleted_at IS NULL`)
	var n int
	return n, row.Scan(&n)
}

func (r *sqliteAdminRepo) CountActiveJourneys() (int, error) {
	row := r.db.QueryRow(`SELECT COUNT(*) FROM journeys WHERE status = 'active'`)
	var n int
	return n, row.Scan(&n)
}

func (r *sqliteAdminRepo) CountActiveJourneysWithGPS(hasGPS bool) (int, error) {
	condition := "current_latitude IS NULL OR current_longitude IS NULL"
	if hasGPS {
		condition = "current_latitude IS NOT NULL AND current_longitude IS NOT NULL"
	}
	row := r.db.QueryRow(`SELECT COUNT(*) FROM journeys WHERE status = 'active' AND ` + condition)
	var n int
	return n, row.Scan(&n)
}

func (r *sqliteAdminRepo) RevenueTodayAllDrivers() (int64, error) {
	row := r.db.QueryRow(`SELECT COALESCE(SUM(fare_paise), 0) FROM tickets
		WHERE status = 'completed' AND date(completed_at) = date('now')`)
	var n int64
	return n, row.Scan(&n)
}

func (r *sqliteAdminRepo) CountPendingTickets() (int, error) {
	row := r.db.QueryRow(`SELECT COUNT(*) FROM tickets WHERE status = 'pending'`)
	var n int
	return n, row.Scan(&n)
}

func (r *sqliteAdminRepo) CountPendingBookingsByType(bookingType string) (int, error) {
	row := r.db.QueryRow(`SELECT COUNT(*) FROM bookings WHERE booking_type = ? AND status = 'pending'`, bookingType)
	var n int
	return n, row.Scan(&n)
}

func (r *sqliteAdminRepo) AverageDriverRating() (float64, error) {
	row := r.db.QueryRow(`SELECT COALESCE(AVG(rating_avg), 0) FROM driver_profiles WHERE rating_count > 0`)
	var avg float64
	return avg, row.Scan(&avg)
}

func (r *sqliteAdminRepo) CancellationRate() (float64, error) {
	row := r.db.QueryRow(`SELECT
		CAST(COUNT(CASE WHEN status = 'cancelled' THEN 1 END) AS REAL) /
		NULLIF(COUNT(*), 0) FROM bookings`)
	var rate sql.NullFloat64
	if err := row.Scan(&rate); err != nil {
		return 0, err
	}
	return rate.Float64, nil
}

func (r *sqliteAdminRepo) TopRoutesByTripCount(limit int) ([]TopRoute, error) {
	rows, err := r.db.Query(`
		SELECT rs_start.name || ' -> ' || rs_end.name AS route_name, COUNT(*) AS trips
		FROM bookings b
		JOIN journeys j ON j.id = b.journey_id
		JOIN routes r ON r.id = j.route_id
		JOIN route_stops rs_start ON rs_start.route_id = r.id AND rs_start.sequence = 0
		JOIN route_stops rs_end ON rs_end.route_id = r.id
			AND rs_end.sequence = (SELECT MAX(sequence) FROM route_stops WHERE route_id = r.id)
		WHERE b.status = 'completed'
		GROUP BY r.id
		ORDER BY trips DESC
		LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []TopRoute
	for rows.Next() {
		var t TopRoute
		if err := rows.Scan(&t.RouteName, &t.TripCount); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, nil
}

func (r *sqliteAdminRepo) RecentUserActivity(limit int) ([]UserActivity, error) {
	rows, err := r.db.Query(`SELECT u.id, u.name, u.phone, u.role, EXISTS(SELECT 1 FROM driver_profiles d WHERE d.user_id = u.id), u.is_active, u.created_at, (SELECT MAX(logged_in_at) FROM user_login_events e WHERE e.user_id = u.id),
		(SELECT COUNT(*) FROM bookings b WHERE b.passenger_id = u.id),
		(SELECT COUNT(*) FROM journeys j JOIN driver_profiles d ON d.id = j.driver_id WHERE d.user_id = u.id),
		(SELECT COUNT(*) FROM vehicles v JOIN driver_profiles d ON d.id = v.owner_driver_id WHERE d.user_id = u.id)
		FROM users u WHERE u.deleted_at IS NULL ORDER BY u.created_at DESC LIMIT ?`, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var users []UserActivity
	for rows.Next() {
		var u UserActivity
		var hasDriver bool
		var lastLogin sql.NullString
		if err := rows.Scan(&u.ID, &u.Name, &u.Phone, &u.Role, &hasDriver, &u.IsActive, &u.CreatedAt, &lastLogin, &u.BookingCount, &u.JourneyCount, &u.VehicleCount); err != nil {
			return nil, err
		}
		if lastLogin.Valid {
			u.LastLoginAt = &lastLogin.String
		}
		u.Roles = []string{"passenger"}
		if hasDriver {
			u.Roles = append(u.Roles, "driver")
		}
		users = append(users, u)
	}
	return users, rows.Err()
}
