package repository

import (
	"database/sql"

	"dagadi-backend/internal/models"
)

type BookingRepository interface {
	Create(b *models.Booking) error
	FindByID(id string) (*models.Booking, error)
	UpdateStatus(id string, status models.BookingStatus) error
	ListPendingForDriver(driverID string) ([]models.Booking, error)
	ListForPassenger(passengerID string) ([]models.Booking, error)
}

type sqliteBookingRepo struct{ db *sql.DB }

func NewBookingRepository(db *sql.DB) BookingRepository {
	return &sqliteBookingRepo{db: db}
}

func (r *sqliteBookingRepo) Create(b *models.Booking) error {
	_, err := r.db.Exec(`INSERT INTO bookings (id, journey_id, passenger_id, booking_type,
		pickup_name, pickup_lat, pickup_lng, pickup_sequence,
		drop_name, drop_lat, drop_lng, drop_sequence, note, passenger_count, parcel_weight_kg, parcel_size, parcel_image_data, status)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
		b.ID, b.JourneyID, b.PassengerID, b.BookingType,
		b.PickupName, b.PickupLat, b.PickupLng, b.PickupSequence,
		b.DropName, b.DropLat, b.DropLng, b.DropSequence, b.Note, b.PassengerCount, b.ParcelWeightKg, b.ParcelSize, b.ParcelImageData)
	return err
}

func (r *sqliteBookingRepo) FindByID(id string) (*models.Booking, error) {
	row := r.db.QueryRow(`SELECT id, journey_id, passenger_id, booking_type, pickup_name,
		pickup_lat, pickup_lng, pickup_sequence, drop_name, drop_lat, drop_lng, drop_sequence,
		note, passenger_count, parcel_weight_kg, parcel_size, parcel_image_data, status FROM bookings WHERE id = ?`, id)
	return scanBooking(row)
}

func scanBooking(row *sql.Row) (*models.Booking, error) {
	var b models.Booking
	err := row.Scan(&b.ID, &b.JourneyID, &b.PassengerID, &b.BookingType, &b.PickupName,
		&b.PickupLat, &b.PickupLng, &b.PickupSequence, &b.DropName, &b.DropLat, &b.DropLng,
		&b.DropSequence, &b.Note, &b.PassengerCount, &b.ParcelWeightKg, &b.ParcelSize, &b.ParcelImageData, &b.Status)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &b, nil
}

func (r *sqliteBookingRepo) UpdateStatus(id string, status models.BookingStatus) error {
	_, err := r.db.Exec(`UPDATE bookings SET status = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?`,
		status, id)
	return err
}

func (r *sqliteBookingRepo) ListPendingForDriver(driverID string) ([]models.Booking, error) {
	rows, err := r.db.Query(`SELECT b.id, b.journey_id, b.passenger_id, b.booking_type, b.pickup_name,
		b.pickup_lat, b.pickup_lng, b.pickup_sequence, b.drop_name, b.drop_lat, b.drop_lng,
		b.drop_sequence, b.note, b.passenger_count, b.parcel_weight_kg, b.parcel_size, b.parcel_image_data, b.status
		FROM bookings b JOIN journeys j ON j.id = b.journey_id
		WHERE j.driver_id = ? AND b.status = 'pending'`, driverID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanBookings(rows)
}

func (r *sqliteBookingRepo) ListForPassenger(passengerID string) ([]models.Booking, error) {
	rows, err := r.db.Query(`SELECT id, journey_id, passenger_id, booking_type, pickup_name,
		pickup_lat, pickup_lng, pickup_sequence, drop_name, drop_lat, drop_lng, drop_sequence,
		note, passenger_count, parcel_weight_kg, parcel_size, parcel_image_data, status FROM bookings WHERE passenger_id = ? ORDER BY created_at DESC`, passengerID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanBookings(rows)
}

func scanBookings(rows *sql.Rows) ([]models.Booking, error) {
	var out []models.Booking
	for rows.Next() {
		var b models.Booking
		if err := rows.Scan(&b.ID, &b.JourneyID, &b.PassengerID, &b.BookingType, &b.PickupName,
			&b.PickupLat, &b.PickupLng, &b.PickupSequence, &b.DropName, &b.DropLat, &b.DropLng,
			&b.DropSequence, &b.Note, &b.PassengerCount, &b.ParcelWeightKg, &b.ParcelSize, &b.ParcelImageData, &b.Status); err != nil {
			return nil, err
		}
		out = append(out, b)
	}
	return out, nil
}
