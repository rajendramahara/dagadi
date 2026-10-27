package service

import (
	"errors"

	"github.com/google/uuid"

	"dagadi-backend/internal/models"
	"dagadi-backend/internal/repository"
)

type BookingService struct {
	bookings repository.BookingRepository
	tickets  repository.TicketRepository
	journeys repository.JourneyRepository
	drivers  repository.DriverRepository
	notifier *NotificationService
}

func NewBookingService(b repository.BookingRepository, t repository.TicketRepository,
	j repository.JourneyRepository, d repository.DriverRepository, n *NotificationService) *BookingService {
	return &BookingService{bookings: b, tickets: t, journeys: j, drivers: d, notifier: n}
}

func (s *BookingService) CreateRequest(passengerID, journeyID string, bookingType models.BookingType,
	pickupName string, pickupLat, pickupLng float64, pickupSeq int,
	dropName string, dropLat, dropLng float64, dropSeq int, note string,
	passengerCount int, parcelWeightKg *float64, parcelSize, parcelImageData string) (*models.Booking, error) {

	journey, err := s.journeys.FindByID(journeyID)
	if err != nil {
		return nil, err
	}
	if journey == nil || journey.Status != models.JourneyActive {
		return nil, errors.New("journey is not available")
	}

	if passengerCount < 1 {
		passengerCount = 1
	}
	b := &models.Booking{
		ID:              uuid.NewString(),
		JourneyID:       journeyID,
		PassengerID:     passengerID,
		BookingType:     bookingType,
		PickupName:      pickupName,
		PickupLat:       pickupLat,
		PickupLng:       pickupLng,
		PickupSequence:  pickupSeq,
		DropName:        dropName,
		DropLat:         dropLat,
		DropLng:         dropLng,
		DropSequence:    dropSeq,
		Note:            note,
		PassengerCount:  passengerCount,
		ParcelWeightKg:  parcelWeightKg,
		ParcelSize:      parcelSize,
		ParcelImageData: parcelImageData,
		Status:          models.BookingPending,
	}
	if err := s.bookings.Create(b); err != nil {
		return nil, err
	}

	if driverUserID, err := s.drivers.GetUserIDByDriverID(journey.DriverID); err == nil {
		title := "New ride request"
		if bookingType == models.BookingParcel {
			title = "New parcel request"
		}
		_ = s.notifier.NotifyEvent(driverUserID, "ride_request", title,
			pickupName+" -> "+dropName, map[string]string{"booking_id": b.ID})
	}
	return b, nil
}

// Accept moves the booking to 'accepted' and automatically creates its
// ticket in 'pending' state - per spec the driver is never forced to
// complete it immediately.
func (s *BookingService) Accept(bookingID, driverID string) (*models.Ticket, error) {
	booking, err := s.bookings.FindByID(bookingID)
	if err != nil {
		return nil, err
	}
	if booking == nil {
		return nil, errors.New("booking not found")
	}
	if booking.Status != models.BookingPending {
		return nil, errors.New("booking is no longer pending")
	}
	if err := s.bookings.UpdateStatus(bookingID, models.BookingAccepted); err != nil {
		return nil, err
	}

	ticket := &models.Ticket{ID: uuid.NewString(), BookingID: bookingID, DriverID: driverID, Status: models.TicketPending}
	if err := s.tickets.Create(ticket); err != nil {
		return nil, err
	}

	eventType := "ride_accepted"
	title := "Ride accepted"
	if booking.BookingType == models.BookingParcel {
		eventType = "parcel_accepted"
		title = "Parcel accepted"
	}
	_ = s.notifier.NotifyEvent(booking.PassengerID, eventType, title,
		"Pickup: "+booking.PickupName, map[string]string{"booking_id": booking.ID})

	return ticket, nil
}

func (s *BookingService) Reject(bookingID string) error {
	booking, err := s.bookings.FindByID(bookingID)
	if err != nil {
		return err
	}
	if booking == nil {
		return errors.New("booking not found")
	}
	if booking.Status != models.BookingPending {
		return errors.New("booking is no longer pending")
	}
	if err := s.bookings.UpdateStatus(bookingID, models.BookingRejected); err != nil {
		return err
	}
	_ = s.notifier.NotifyEvent(booking.PassengerID, "ride_rejected", "Request declined",
		"The driver could not accept your request.", map[string]string{"booking_id": booking.ID})
	return nil
}
