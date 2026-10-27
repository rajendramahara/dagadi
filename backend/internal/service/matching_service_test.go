package service

import (
	"testing"

	"dagadi-backend/internal/models"
	"dagadi-backend/internal/repository"
)

// fakeJourneyRepo lets us test the matching algorithm in isolation from
// SQLite - it implements repository.JourneyRepository with canned data.
type fakeJourneyRepo struct {
	candidates []repository.JourneyCandidate
}

func (f *fakeJourneyRepo) Create(j *models.Journey) error                   { return nil }
func (f *fakeJourneyRepo) FindByID(id string) (*models.Journey, error)      { return nil, nil }
func (f *fakeJourneyRepo) UpdatePosition(id string, lat, lng float64) error { return nil }
func (f *fakeJourneyRepo) AdvanceCrossedStop(id string, sequence int) error { return nil }
func (f *fakeJourneyRepo) Complete(id string) error                         { return nil }
func (f *fakeJourneyRepo) ListActiveCandidates() ([]repository.JourneyCandidate, error) {
	return f.candidates, nil
}
func (f *fakeJourneyRepo) ListActiveByDriver(driverID string) ([]repository.JourneyCandidate, error) {
	var own []repository.JourneyCandidate
	for _, candidate := range f.candidates {
		if candidate.Journey.DriverID == driverID {
			own = append(own, candidate)
		}
	}
	return own, nil
}

func baseCandidate() repository.JourneyCandidate {
	lat0, lng0 := 29.6350, 79.6903 // Gangolihat-ish
	lat1, lng1 := 29.5892, 79.6467 // Sheraghat-ish
	lat2, lng2 := 29.2183, 79.5130 // Haldwani-ish

	driverLat, driverLng := lat0, lng0 // driver currently at stop 0

	return repository.JourneyCandidate{
		Journey: models.Journey{
			ID:                  "journey-1",
			DriverID:            "driver-1",
			RouteID:             "route-1",
			CurrentStopSequence: 0,
			CurrentLatitude:     &driverLat,
			CurrentLongitude:    &driverLng,
		},
		Stops: []models.RouteStop{
			{Sequence: 0, Name: "Start", Latitude: lat0, Longitude: lng0},
			{Sequence: 1, Name: "Mid", Latitude: lat1, Longitude: lng1},
			{Sequence: 2, Name: "End", Latitude: lat2, Longitude: lng2},
		},
		DriverName:   "Test Driver",
		Availability: models.AvailabilityPassengerParcel,
		VisibilityM:  2000,
		VehicleModel: "Test Vehicle",
		VehicleReg:   "UK-01-0001",
	}
}

func TestFindMatches_HappyPath(t *testing.T) {
	c := baseCandidate()
	repo := &fakeJourneyRepo{candidates: []repository.JourneyCandidate{c}}
	svc := NewMatchingService(repo)

	matches, err := svc.FindMatches(29.6350, 79.6903, 29.2183, 79.5130, models.BookingRide)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(matches) != 1 {
		t.Fatalf("expected 1 match, got %d", len(matches))
	}
}

func TestFindMatches_ExcludesIfDriverAlreadyCrossedPickup(t *testing.T) {
	c := baseCandidate()
	c.Journey.CurrentStopSequence = 1 // already past the pickup stop (sequence 0)
	repo := &fakeJourneyRepo{candidates: []repository.JourneyCandidate{c}}
	svc := NewMatchingService(repo)

	matches, err := svc.FindMatches(29.6350, 79.6903, 29.2183, 79.5130, models.BookingRide)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(matches) != 0 {
		t.Fatalf("expected 0 matches once driver crossed pickup, got %d", len(matches))
	}
}

func TestFindMatches_ExcludesParcelOnlyForRideRequest(t *testing.T) {
	c := baseCandidate()
	c.Availability = models.AvailabilityParcelOnly
	repo := &fakeJourneyRepo{candidates: []repository.JourneyCandidate{c}}
	svc := NewMatchingService(repo)

	matches, err := svc.FindMatches(29.6350, 79.6903, 29.2183, 79.5130, models.BookingRide)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(matches) != 0 {
		t.Fatalf("expected parcel_only driver excluded from ride search, got %d", len(matches))
	}

	parcelMatches, err := svc.FindMatches(29.6350, 79.6903, 29.2183, 79.5130, models.BookingParcel)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(parcelMatches) != 1 {
		t.Fatalf("expected parcel_only driver included in parcel search, got %d", len(parcelMatches))
	}
}

func TestFindMatches_ExcludesDestinationBeforePickup(t *testing.T) {
	c := baseCandidate()
	repo := &fakeJourneyRepo{candidates: []repository.JourneyCandidate{c}}
	svc := NewMatchingService(repo)

	// pickup = End (seq 2), drop = Start (seq 0) -> destination not after pickup
	matches, err := svc.FindMatches(29.2183, 79.5130, 29.6350, 79.6903, models.BookingRide)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(matches) != 0 {
		t.Fatalf("expected 0 matches when destination precedes pickup, got %d", len(matches))
	}
}

func TestFindMatches_ExcludesOutsideVisibilityRadius(t *testing.T) {
	c := baseCandidate()
	farLat, farLng := 30.5, 80.5 // far from the pickup point
	c.Journey.CurrentLatitude = &farLat
	c.Journey.CurrentLongitude = &farLng
	repo := &fakeJourneyRepo{candidates: []repository.JourneyCandidate{c}}
	svc := NewMatchingService(repo)

	matches, err := svc.FindMatches(29.6350, 79.6903, 29.2183, 79.5130, models.BookingRide)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(matches) != 0 {
		t.Fatalf("expected 0 matches when driver is outside visibility radius, got %d", len(matches))
	}
}
