package repository

import (
	"database/sql"
)

type Review struct {
	ID          string  `json:"id"`
	TicketID    string  `json:"ticket_id"`
	PassengerID string  `json:"passenger_id"`
	DriverID    string  `json:"driver_id"`
	Rating      int     `json:"rating"`
	Comment     string  `json:"comment"`
}

type ReviewRepository interface {
	Create(r *Review) error
	ListForDriver(driverID string) ([]Review, error)
}

type sqliteReviewRepo struct{ db *sql.DB }

func NewReviewRepository(db *sql.DB) ReviewRepository {
	return &sqliteReviewRepo{db: db}
}

// Create inserts the review and recomputes the driver's running rating
// average/count in the same transaction, so driver_profiles.rating_avg
// (used by the matching/search results) is always current.
func (r *sqliteReviewRepo) Create(rv *Review) error {
	tx, err := r.db.Begin()
	if err != nil {
		return err
	}
	if _, err := tx.Exec(`INSERT INTO reviews (id, ticket_id, passenger_id, driver_id, rating, comment)
		VALUES (?, ?, ?, ?, ?, ?)`, rv.ID, rv.TicketID, rv.PassengerID, rv.DriverID, rv.Rating, rv.Comment); err != nil {
		tx.Rollback()
		return err
	}
	if _, err := tx.Exec(`UPDATE driver_profiles SET
		rating_count = rating_count + 1,
		rating_avg = ((rating_avg * rating_count) + ?) / (rating_count + 1)
		WHERE id = ?`, rv.Rating, rv.DriverID); err != nil {
		tx.Rollback()
		return err
	}
	return tx.Commit()
}

func (r *sqliteReviewRepo) ListForDriver(driverID string) ([]Review, error) {
	rows, err := r.db.Query(`SELECT id, ticket_id, passenger_id, driver_id, rating, comment
		FROM reviews WHERE driver_id = ? ORDER BY created_at DESC`, driverID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []Review
	for rows.Next() {
		var rv Review
		if err := rows.Scan(&rv.ID, &rv.TicketID, &rv.PassengerID, &rv.DriverID, &rv.Rating, &rv.Comment); err != nil {
			return nil, err
		}
		out = append(out, rv)
	}
	return out, nil
}
