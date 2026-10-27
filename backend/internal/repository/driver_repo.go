package repository

import (
	"database/sql"

	"dagadi-backend/internal/models"
)

type DriverRepository interface {
	CreateProfile(p *models.DriverProfile) error
	FindByUserID(userID string) (*models.DriverProfile, error)
	FindByID(id string) (*models.DriverProfile, error)
	UpdateAvailability(driverID string, availability models.Availability) error
	UpdateVisibilityRadius(driverID string, radiusM int) error

	CreateVehicle(v *models.Vehicle) error
	UpdateVehicle(v *models.Vehicle) error
	ListVehiclesByDriver(driverID string) ([]models.Vehicle, error)

	CreateFleet(id, ownerDriverID, name string) error
	UpdateFleet(id, ownerDriverID, name string) error
	ListFleetsByOwner(ownerDriverID string) ([]models.Fleet, error)
	DeleteFleet(id, ownerDriverID string) error
	AssignDriverToFleet(fleetID, driverID, ownerDriverID string) error
	AssignVehicleToFleet(vehicleID, fleetID, ownerDriverID string) error
	AssignDriverToVehicle(vehicleID, driverID string) error
	FindDriverByPhone(phone string) (*models.DriverProfile, error)
	AssignDriverToOwnedVehicle(vehicleID, driverID, ownerDriverID string) error
	GetUserIDByDriverID(driverID string) (string, error)
}

type sqliteDriverRepo struct{ db *sql.DB }

func NewDriverRepository(db *sql.DB) DriverRepository {
	return &sqliteDriverRepo{db: db}
}

func (r *sqliteDriverRepo) CreateProfile(p *models.DriverProfile) error {
	_, err := r.db.Exec(`INSERT INTO driver_profiles (id, user_id, availability, visibility_radius_m)
		VALUES (?, ?, 'offline', 2000)`, p.ID, p.UserID)
	return err
}

func (r *sqliteDriverRepo) FindByUserID(userID string) (*models.DriverProfile, error) {
	row := r.db.QueryRow(`SELECT id, user_id, availability, visibility_radius_m,
		rating_avg, rating_count, documents_verified FROM driver_profiles WHERE user_id = ?`, userID)
	return scanDriver(row)
}

func (r *sqliteDriverRepo) FindByID(id string) (*models.DriverProfile, error) {
	row := r.db.QueryRow(`SELECT id, user_id, availability, visibility_radius_m,
		rating_avg, rating_count, documents_verified FROM driver_profiles WHERE id = ?`, id)
	return scanDriver(row)
}

func scanDriver(row *sql.Row) (*models.DriverProfile, error) {
	var d models.DriverProfile
	var verified int
	err := row.Scan(&d.ID, &d.UserID, &d.Availability, &d.VisibilityRadiusM,
		&d.RatingAvg, &d.RatingCount, &verified)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	d.DocumentsVerified = verified == 1
	return &d, nil
}

func (r *sqliteDriverRepo) UpdateAvailability(driverID string, availability models.Availability) error {
	_, err := r.db.Exec(`UPDATE driver_profiles SET availability = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?`, availability, driverID)
	return err
}

func (r *sqliteDriverRepo) UpdateVisibilityRadius(driverID string, radiusM int) error {
	_, err := r.db.Exec(`UPDATE driver_profiles SET visibility_radius_m = ?, updated_at = CURRENT_TIMESTAMP
		WHERE id = ?`, radiusM, driverID)
	return err
}

func (r *sqliteDriverRepo) CreateVehicle(v *models.Vehicle) error {
	_, err := r.db.Exec(`INSERT INTO vehicles (id, fleet_id, owner_driver_id, assigned_driver_id,
		registration_no, model, color, capacity) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
		v.ID, v.FleetID, v.OwnerDriverID, v.AssignedDriverID, v.RegistrationNo, v.Model, v.Color, v.Capacity)
	return err
}

func (r *sqliteDriverRepo) UpdateVehicle(v *models.Vehicle) error {
	result, err := r.db.Exec(`UPDATE vehicles SET registration_no = ?, model = ?, color = ?, capacity = ?
		WHERE id = ? AND owner_driver_id = ? AND deleted_at IS NULL`,
		v.RegistrationNo, v.Model, v.Color, v.Capacity, v.ID, v.OwnerDriverID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *sqliteDriverRepo) ListVehiclesByDriver(driverID string) ([]models.Vehicle, error) {
	rows, err := r.db.Query(`SELECT id, fleet_id, owner_driver_id, assigned_driver_id,
		registration_no, model, color, capacity, is_active FROM vehicles
		WHERE owner_driver_id = ? AND deleted_at IS NULL`, driverID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []models.Vehicle
	for rows.Next() {
		var v models.Vehicle
		var active int
		if err := rows.Scan(&v.ID, &v.FleetID, &v.OwnerDriverID, &v.AssignedDriverID,
			&v.RegistrationNo, &v.Model, &v.Color, &v.Capacity, &active); err != nil {
			return nil, err
		}
		v.IsActive = active == 1
		out = append(out, v)
	}
	return out, nil
}

func (r *sqliteDriverRepo) CreateFleet(id, ownerDriverID, name string) error {
	_, err := r.db.Exec(`INSERT INTO fleets (id, owner_id, name) VALUES (?, ?, ?)`, id, ownerDriverID, name)
	return err
}

func (r *sqliteDriverRepo) UpdateFleet(id, ownerDriverID, name string) error {
	result, err := r.db.Exec(`UPDATE fleets SET name = ? WHERE id = ? AND owner_id = ?`, name, id, ownerDriverID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *sqliteDriverRepo) ListFleetsByOwner(ownerDriverID string) ([]models.Fleet, error) {
	rows, err := r.db.Query(`SELECT f.id, f.owner_id, f.name, f.created_at, a.driver_id, u.name, u.phone
		FROM fleets f
		LEFT JOIN fleet_driver_assignments a ON a.fleet_id = f.id
		LEFT JOIN driver_profiles d ON d.id = a.driver_id
		LEFT JOIN users u ON u.id = d.user_id
		WHERE f.owner_id = ? ORDER BY f.created_at DESC`, ownerDriverID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var fleets []models.Fleet
	for rows.Next() {
		var f models.Fleet
		if err := rows.Scan(&f.ID, &f.OwnerID, &f.Name, &f.CreatedAt, &f.AssignedDriverID, &f.AssignedDriverName, &f.AssignedDriverPhone); err != nil {
			return nil, err
		}
		fleets = append(fleets, f)
	}
	return fleets, rows.Err()
}

func (r *sqliteDriverRepo) AssignDriverToFleet(fleetID, driverID, ownerDriverID string) error {
	result, err := r.db.Exec(`INSERT INTO fleet_driver_assignments (fleet_id, driver_id)
		SELECT ?, ? WHERE EXISTS (SELECT 1 FROM fleets WHERE id = ? AND owner_id = ?)
		ON CONFLICT(fleet_id) DO UPDATE SET driver_id = excluded.driver_id, assigned_at = CURRENT_TIMESTAMP`, fleetID, driverID, fleetID, ownerDriverID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *sqliteDriverRepo) DeleteFleet(id, ownerDriverID string) error {
	result, err := r.db.Exec(`DELETE FROM fleets WHERE id = ? AND owner_id = ?`, id, ownerDriverID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *sqliteDriverRepo) AssignVehicleToFleet(vehicleID, fleetID, ownerDriverID string) error {
	result, err := r.db.Exec(`UPDATE vehicles SET fleet_id = ? WHERE id = ? AND owner_driver_id = ?
		AND EXISTS (SELECT 1 FROM fleets WHERE id = ? AND owner_id = ?)`, fleetID, vehicleID, ownerDriverID, fleetID, ownerDriverID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *sqliteDriverRepo) AssignDriverToVehicle(vehicleID, driverID string) error {
	_, err := r.db.Exec(`UPDATE vehicles SET assigned_driver_id = ? WHERE id = ?`, driverID, vehicleID)
	return err
}

func (r *sqliteDriverRepo) FindDriverByPhone(phone string) (*models.DriverProfile, error) {
	row := r.db.QueryRow(`SELECT d.id, d.user_id, d.availability, d.visibility_radius_m, d.rating_avg, d.rating_count, d.documents_verified FROM driver_profiles d JOIN users u ON u.id = d.user_id WHERE u.phone = ? AND u.deleted_at IS NULL`, phone)
	return scanDriver(row)
}

func (r *sqliteDriverRepo) AssignDriverToOwnedVehicle(vehicleID, driverID, ownerDriverID string) error {
	result, err := r.db.Exec(`UPDATE vehicles SET assigned_driver_id = ? WHERE id = ? AND owner_driver_id = ?`, driverID, vehicleID, ownerDriverID)
	if err != nil {
		return err
	}
	if affected, _ := result.RowsAffected(); affected == 0 {
		return sql.ErrNoRows
	}
	return nil
}

func (r *sqliteDriverRepo) GetUserIDByDriverID(driverID string) (string, error) {
	row := r.db.QueryRow(`SELECT user_id FROM driver_profiles WHERE id = ?`, driverID)
	var userID string
	err := row.Scan(&userID)
	return userID, err
}
