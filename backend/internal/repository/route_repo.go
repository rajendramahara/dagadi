package repository

import (
	"database/sql"

	"dagadi-backend/internal/models"
)

type RouteRepository interface {
	CreateRoute(r *models.Route) error
	UpdateRoute(r *models.Route) error
	AddStop(s *models.RouteStop) error
	DeleteStops(routeID string) error
	GetRouteWithStops(routeID string) (*models.Route, error)
	ListSavedRoutesByDriver(driverID string) ([]models.Route, error)
	DeleteRoute(routeID, driverID string) error
}

type sqliteRouteRepo struct{ db *sql.DB }

func NewRouteRepository(db *sql.DB) RouteRepository {
	return &sqliteRouteRepo{db: db}
}

func (r *sqliteRouteRepo) CreateRoute(rt *models.Route) error {
	_, err := r.db.Exec(`INSERT INTO routes (id, driver_id, name, is_saved, scheduled_at) VALUES (?, ?, ?, ?, ?)`,
		rt.ID, rt.DriverID, rt.Name, boolToInt(rt.IsSaved), rt.ScheduledAt)
	return err
}

func (r *sqliteRouteRepo) UpdateRoute(rt *models.Route) error {
	result, err := r.db.Exec(`UPDATE routes SET name = ?, scheduled_at = ? WHERE id = ? AND driver_id = ?`,
		rt.Name, rt.ScheduledAt, rt.ID, rt.DriverID)
	if err != nil {
		return err
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if changed == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *sqliteRouteRepo) AddStop(s *models.RouteStop) error {
	_, err := r.db.Exec(`INSERT INTO route_stops (id, route_id, sequence, name, latitude, longitude)
		VALUES (?, ?, ?, ?, ?, ?)`, s.ID, s.RouteID, s.Sequence, s.Name, s.Latitude, s.Longitude)
	return err
}

func (r *sqliteRouteRepo) DeleteStops(routeID string) error {
	_, err := r.db.Exec(`DELETE FROM route_stops WHERE route_id = ?`, routeID)
	return err
}

func (r *sqliteRouteRepo) GetRouteWithStops(routeID string) (*models.Route, error) {
	row := r.db.QueryRow(`SELECT id, driver_id, name, is_saved, scheduled_at FROM routes WHERE id = ?`, routeID)
	var rt models.Route
	var saved int
	var scheduled sql.NullTime
	if err := row.Scan(&rt.ID, &rt.DriverID, &rt.Name, &saved, &scheduled); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	rt.IsSaved = saved == 1
	if scheduled.Valid {
		rt.ScheduledAt = &scheduled.Time
	}

	rows, err := r.db.Query(`SELECT id, route_id, sequence, name, latitude, longitude
		FROM route_stops WHERE route_id = ? ORDER BY sequence ASC`, routeID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var s models.RouteStop
		if err := rows.Scan(&s.ID, &s.RouteID, &s.Sequence, &s.Name, &s.Latitude, &s.Longitude); err != nil {
			return nil, err
		}
		rt.Stops = append(rt.Stops, s)
	}
	return &rt, nil
}

func (r *sqliteRouteRepo) ListSavedRoutesByDriver(driverID string) ([]models.Route, error) {
	rows, err := r.db.Query(`SELECT id FROM routes
		WHERE driver_id = ? AND is_saved = 1`, driverID)
	if err != nil {
		return nil, err
	}
	var ids []string
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	if err := rows.Close(); err != nil {
		return nil, err
	}
	var out []models.Route
	for _, id := range ids {
		route, err := r.GetRouteWithStops(id)
		if err != nil {
			return nil, err
		}
		if route != nil {
			out = append(out, *route)
		}
	}
	return out, nil
}

func (r *sqliteRouteRepo) DeleteRoute(routeID, driverID string) error {
	result, err := r.db.Exec(`DELETE FROM routes WHERE id = ? AND driver_id = ?`, routeID, driverID)
	if err != nil {
		return err
	}
	changed, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if changed == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}
