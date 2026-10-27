package service

import (
	"errors"
	"fmt"
	"time"

	"dagadi-backend/internal/models"
	"dagadi-backend/internal/repository"
)

type TicketService struct {
	tickets  repository.TicketRepository
	bookings repository.BookingRepository
	notifier *NotificationService
}

func NewTicketService(t repository.TicketRepository, b repository.BookingRepository, n *NotificationService) *TicketService {
	return &TicketService{tickets: t, bookings: b, notifier: n}
}

// CompleteTicket is the ONLY action that turns a ride into completed
// revenue - per spec, drivers can leave tickets pending for minutes,
// hours, or until the next day, then finalize whenever convenient.
func (s *TicketService) CompleteTicket(ticketID string, farePaise int64, paymentMethod, notes string) error {
	ticket, err := s.tickets.FindByID(ticketID)
	if err != nil {
		return err
	}
	if ticket == nil {
		return errors.New("ticket not found")
	}
	if ticket.Status != models.TicketPending {
		return errors.New("ticket already completed")
	}
	if farePaise < 0 {
		return errors.New("fare must not be negative")
	}
	if err := s.tickets.Complete(ticketID, farePaise, paymentMethod, notes); err != nil {
		return err
	}

	if booking, err := s.bookings.FindByID(ticket.BookingID); err == nil && booking != nil {
		_ = s.notifier.NotifyEvent(booking.PassengerID, "ticket_completed", "Trip completed",
			"Your fare was ₹"+formatPaise(farePaise), map[string]string{"ticket_id": ticketID})
		_ = s.notifier.NotifyEvent(booking.PassengerID, "review_reminder", "How was your trip?",
			"Tap to rate your driver.", map[string]string{"ticket_id": ticketID})
	}
	return nil
}

func formatPaise(paise int64) string {
	return fmt.Sprintf("%.2f", float64(paise)/100)
}

func (s *TicketService) PendingForDriver(driverID string) ([]models.Ticket, error) {
	return s.tickets.ListPendingForDriver(driverID)
}

func (s *TicketService) HistoryForDriver(driverID string) ([]models.Ticket, error) {
	return s.tickets.ListCompletedForDriver(driverID)
}

// RevenueDashboard returns the common driver reporting periods in one call.
func (s *TicketService) RevenueDashboard(driverID string) (map[string]models.RevenueSummary, error) {
	now := time.Now().UTC()
	startOfDay := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	startOfWeek := startOfDay.AddDate(0, 0, -int(now.Weekday()))
	startOfMonth := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	startOfYear := time.Date(now.Year(), 1, 1, 0, 0, 0, 0, time.UTC)

	out := map[string]models.RevenueSummary{}
	periods := map[string]time.Time{
		"today": startOfDay, "week": startOfWeek, "month": startOfMonth, "year": startOfYear,
		"last_3_months": now.AddDate(0, -3, 0),
		"last_6_months": now.AddDate(0, -6, 0),
	}
	for label, since := range periods {
		summary, err := s.tickets.RevenueSince(driverID, since.Format("2006-01-02 15:04:05"))
		if err != nil {
			return nil, err
		}
		summary.Period = label
		out[label] = summary
	}
	return out, nil
}
