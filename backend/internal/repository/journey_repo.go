package repository

import (
	"database/sql"
	"time"

	"dagadi-backend/internal/models"
)

// JourneyCandidate bundles everything the matching service needs about
// one active journey without N+1 queries: the journey row, its ordered
// stops, and the driver/vehicle info needed for display.
type JourneyCandidate struct {
	Journey      models.Journey
	Stops        []models.RouteStop
	DriverName   string
	DriverRating float64
	Availability models.Availability
	VisibilityM  int
	VehicleModel string
	VehicleReg   string
}

type JourneyRepository interface {
	Create(j *models.Journey) error
	ListActiveCandidates() ([]JourneyCandidate, error)
	ListActiveByDriver(driverID string) ([]JourneyCandidate, error)
	UpdatePosition(journeyID string, lat, lng float64) error
	AdvanceCrossedStop(journeyID string, sequence int) error
	Complete(journeyID string) error
	FindByID(id string) (*models.Journey, error)
}

type sqliteJourneyRepo struct{ db *sql.DB }

func NewJourneyRepository(db *sql.DB) JourneyRepository {
	return &sqliteJourneyRepo{db: db}
}

func (r *sqliteJourneyRepo) Create(j *models.Journey) error {
	_, err := r.db.Exec(`INSERT INTO journeys (id, driver_id, route_id, vehicle_id, departure_time, status)
		VALUES (?, ?, ?, ?, ?, 'active')`, j.ID, j.DriverID, j.RouteID, j.VehicleID, j.DepartureTime)
	return err
}

func (r *sqliteJourneyRepo) FindByID(id string) (*models.Journey, error) {
	row := r.db.QueryRow(`SELECT id, driver_id, route_id, vehicle_id, departure_time, status,
		current_stop_sequence, current_latitude, current_longitude FROM journeys WHERE id = ?`, id)
	var j models.Journey
	if err := row.Scan(&j.ID, &j.DriverID, &j.RouteID, &j.VehicleID, &j.DepartureTime, &j.Status,
		&j.CurrentStopSequence, &j.CurrentLatitude, &j.CurrentLongitude); err != nil {
		if err == sql.ErrNoRows {
			return nil, nil
		}
		return nil, err
	}
	return &j, nil
}

// ListActiveCandidates loads every active journey with its stops and
// driver/vehicle info. Matching (pickup-on-route, radius, availability,
// not-yet-crossed) is applied in the service layer since it is business
// logic, not persistence logic.
func (r *sqliteJourneyRepo) ListActiveCandidates() ([]JourneyCandidate, error) {
	rows, err := r.db.Query(`
		SELECT j.id, j.driver_id, j.route_id, j.vehicle_id, j.departure_time, j.status,
		       j.current_stop_sequence, j.current_latitude, j.current_longitude,
		       u.name, dp.rating_avg, dp.availability, dp.visibility_radius_m,
		       v.model, v.registration_no
		FROM journeys j
		JOIN driver_profiles dp ON dp.id = j.driver_id
		JOIN users u ON u.id = dp.user_id
		JOIN vehicles v ON v.id = j.vehicle_id
		WHERE j.status = 'active' AND dp.availability != 'offline'
	`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var candidates []JourneyCandidate
	journeyIDs := []string{}
	byID := map[string]*JourneyCandidate{}

	for rows.Next() {
		var c JourneyCandidate
		if err := rows.Scan(&c.Journey.ID, &c.Journey.DriverID, &c.Journey.RouteID, &c.Journey.VehicleID,
			&c.Journey.DepartureTime, &c.Journey.Status, &c.Journey.CurrentStopSequence,
			&c.Journey.CurrentLatitude, &c.Journey.CurrentLongitude,
			&c.DriverName, &c.DriverRating, &c.Availability, &c.VisibilityM,
			&c.VehicleModel, &c.VehicleReg); err != nil {
			return nil, err
		}
		candidates = append(candidates, c)
		journeyIDs = append(journeyIDs, c.Journey.RouteID)
	}

	// attach stops per route
	for i := range candidates {
		stopRows, err := r.db.Query(`SELECT id, route_id, sequence, name, latitude, longitude
			FROM route_stops WHERE route_id = ? ORDER BY sequence ASC`, candidates[i].Journey.RouteID)
		if err != nil {
			return nil, err
		}
		for stopRows.Next() {
			var s models.RouteStop
			if err := stopRows.Scan(&s.ID, &s.RouteID, &s.Sequence, &s.Name, &s.Latitude, &s.Longitude); err != nil {
				stopRows.Close()
				return nil, err
			}
			candidates[i].Stops = append(candidates[i].Stops, s)
		}
		stopRows.Close()
		byID[candidates[i].Journey.ID] = &candidates[i]
	}

	return candidates, nil
}

// ListActiveByDriver supplies the driver's own dashboard without exposing
// other drivers' live journeys.
func (r *sqliteJourneyRepo) ListActiveByDriver(driverID string) ([]JourneyCandidate, error) {
	all, err := r.ListActiveCandidates()
	if err != nil {
		return nil, err
	}
	var own []JourneyCandidate
	for _, journey := range all {
		if journey.Journey.DriverID == driverID {
			own = append(own, journey)
		}
	}
	return own, nil
}

func (r *sqliteJourneyRepo) UpdatePosition(journeyID string, lat, lng float64) error {
	_, err := r.db.Exec(`UPDATE journeys SET current_latitude = ?, current_longitude = ?,
		updated_at = CURRENT_TIMESTAMP WHERE id = ?`, lat, lng, journeyID)
	return err
}

func (r *sqliteJourneyRepo) AdvanceCrossedStop(journeyID string, sequence int) error {
	_, err := r.db.Exec(`UPDATE journeys SET current_stop_sequence = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ? AND current_stop_sequence < ?`, sequence, journeyID, sequence)
	return err
}

func (r *sqliteJourneyRepo) Complete(journeyID string) error {
	_, err := r.db.Exec(`UPDATE journeys SET status = 'completed', updated_at = CURRENT_TIMESTAMP
		WHERE id = ?`, journeyID)
	return err
}

var _ = time.Now
