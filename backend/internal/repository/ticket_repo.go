package repository

import (
	"database/sql"

	"dagadi-backend/internal/models"
)

type TicketRepository interface {
	Create(t *models.Ticket) error
	FindByID(id string) (*models.Ticket, error)
	Complete(id string, farePaise int64, paymentMethod, notes string) error
	ListPendingForDriver(driverID string) ([]models.Ticket, error)
	ListCompletedForDriver(driverID string) ([]models.Ticket, error)
	// RevenueSince sums completed tickets for a driver from a given SQL
	// datetime boundary. Passing "" sums all time.
	RevenueSince(driverID string, sinceISO string) (models.RevenueSummary, error)
}

type sqliteTicketRepo struct{ db *sql.DB }

func NewTicketRepository(db *sql.DB) TicketRepository {
	return &sqliteTicketRepo{db: db}
}

func (r *sqliteTicketRepo) Create(t *models.Ticket) error {
	_, err := r.db.Exec(`INSERT INTO tickets (id, booking_id, driver_id, status)
		VALUES (?, ?, ?, 'pending')`, t.ID, t.BookingID, t.DriverID)
	return err
}

func (r *sqliteTicketRepo) FindByID(id string) (*models.Ticket, error) {
	row := r.db.QueryRow(`SELECT id, booking_id, driver_id, fare_paise, payment_method, notes,
		status, completed_at FROM tickets WHERE id = ?`, id)
	var t models.Ticket
	err := row.Scan(&t.ID, &t.BookingID, &t.DriverID, &t.FarePaise, &t.PaymentMethod, &t.Notes,
		&t.Status, &t.CompletedAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &t, nil
}

// Complete is called when the driver taps "Complete Ticket". This is the
// ONLY place a booking becomes revenue-counted - per spec, revenue must
// only be calculated from completed tickets, never from acceptance alone.
func (r *sqliteTicketRepo) Complete(id string, farePaise int64, paymentMethod, notes string) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	if _, err := tx.Exec(`UPDATE tickets SET fare_paise = ?, payment_method = ?, notes = ?,
		status = 'completed', completed_at = CURRENT_TIMESTAMP WHERE id = ? AND status = 'pending'`,
		farePaise, paymentMethod, notes, id); err != nil {
		tx.Rollback()
		return err
	}
	// also mark the underlying booking completed
	if _, err := tx.Exec(`UPDATE bookings SET status = 'completed', updated_at = CURRENT_TIMESTAMP
		WHERE id = (SELECT booking_id FROM tickets WHERE id = ?)`, id); err != nil {
		tx.Rollback()
		return err
	}
	return tx.Commit()
}

func (r *sqliteTicketRepo) ListPendingForDriver(driverID string) ([]models.Ticket, error) {
	return r.listByDriverStatus(driverID, "pending")
}

func (r *sqliteTicketRepo) ListCompletedForDriver(driverID string) ([]models.Ticket, error) {
	return r.listByDriverStatus(driverID, "completed")
}

func (r *sqliteTicketRepo) listByDriverStatus(driverID, status string) ([]models.Ticket, error) {
	rows, err := r.db.Query(`SELECT id, booking_id, driver_id, fare_paise, payment_method, notes,
		status, completed_at FROM tickets WHERE driver_id = ? AND status = ?
		ORDER BY created_at DESC`, driverID, status)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []models.Ticket
	for rows.Next() {
		var t models.Ticket
		if err := rows.Scan(&t.ID, &t.BookingID, &t.DriverID, &t.FarePaise, &t.PaymentMethod,
			&t.Notes, &t.Status, &t.CompletedAt); err != nil {
			return nil, err
		}
		out = append(out, t)
	}
	return out, nil
}

func (r *sqliteTicketRepo) RevenueSince(driverID string, sinceISO string) (models.RevenueSummary, error) {
	query := `SELECT
			COUNT(CASE WHEN b.booking_type = 'ride' THEN 1 END) as trip_count,
			COUNT(CASE WHEN b.booking_type = 'parcel' THEN 1 END) as parcel_count,
			COALESCE(SUM(t.fare_paise), 0) as revenue
		FROM tickets t
		JOIN bookings b ON b.id = t.booking_id
		WHERE t.driver_id = ? AND t.status = 'completed'`
	args := []interface{}{driverID}
	if sinceISO != "" {
		query += ` AND t.completed_at >= ?`
		args = append(args, sinceISO)
	}
	row := r.db.QueryRow(query, args...)
	var s models.RevenueSummary
	if err := row.Scan(&s.TripCount, &s.ParcelCount, &s.RevenuePaise); err != nil {
		return s, err
	}
	return s, nil
}
