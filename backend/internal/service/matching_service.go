package service

import (
	"sort"
	"time"

	"dagadi-backend/internal/models"
	"dagadi-backend/internal/repository"
	"dagadi-backend/pkg/utils"
)

// stopMatchToleranceMeters: how close a passenger's tapped pickup/drop
// point must be to a route stop to count as "on that route". Keeps the
// matching simple (stop-to-stop) rather than full polyline snapping,
// which can be swapped in later without changing the service interface.
const stopMatchToleranceMeters = 700.0

type MatchingService struct {
	journeys repository.JourneyRepository
}

func NewMatchingService(journeys repository.JourneyRepository) *MatchingService {
	return &MatchingService{journeys: journeys}
}

// FindMatches implements every rule from the spec:
//  1. Pickup exists on driver's route.
//  2. Destination exists after pickup (sequence order).
//  3. Driver has not yet crossed the pickup point.
//  4. Driver's live position is inside their configured visibility radius
//     of the pickup point (default 2km).
//  5. Driver's availability accepts the requested booking type.
//
// Journeys failing any rule are excluded - never shown as a partial/near match.
func (s *MatchingService) FindMatches(pickupLat, pickupLng, dropLat, dropLng float64, bookingType models.BookingType) ([]models.JourneyMatch, error) {
	return s.findMatches(pickupLat, pickupLng, dropLat, dropLng, bookingType, time.Now().UTC(), false)
}

// FindMatchesForTime predicts arrival at the pickup stop from the driver's
// planned departure and route distance (using a conservative 30 km/h average).
func (s *MatchingService) FindMatchesForTime(pickupLat, pickupLng, dropLat, dropLng float64, bookingType models.BookingType, requested time.Time) ([]models.JourneyMatch, error) {
	return s.findMatches(pickupLat, pickupLng, dropLat, dropLng, bookingType, requested.UTC(), true)
}

func (s *MatchingService) findMatches(pickupLat, pickupLng, dropLat, dropLng float64, bookingType models.BookingType, requested time.Time, scheduled bool) ([]models.JourneyMatch, error) {
	candidates, err := s.journeys.ListActiveCandidates()
	if err != nil {
		return nil, err
	}

	var results []models.JourneyMatch
	for _, c := range candidates {
		if !availabilityAccepts(c.Availability, bookingType) {
			continue
		}

		pickupStop := nearestStopWithin(c.Stops, pickupLat, pickupLng, stopMatchToleranceMeters)
		if pickupStop == nil {
			continue
		}
		dropStop := nearestStopWithin(c.Stops, dropLat, dropLng, stopMatchToleranceMeters)
		if dropStop == nil {
			continue
		}
		if dropStop.Sequence <= pickupStop.Sequence {
			continue // destination must be after pickup
		}
		// CurrentStopSequence is the stop the driver is currently at.  A pickup
		// at that stop is still valid; only earlier stops have been crossed.
		if c.Journey.CurrentStopSequence > pickupStop.Sequence {
			continue // driver already crossed the pickup point
		}

		departure := c.Journey.DepartureTime
		if departure.IsZero() {
			departure = time.Now().UTC()
		}
		estimatedPickup := estimatePickupTime(departure, c.Stops, pickupStop.Sequence)
		if scheduled {
			// A 90-minute window keeps later searches useful without claiming a
			// GPS-precise ETA before a driver has started moving.
			if estimatedPickup.Before(requested.Add(-90*time.Minute)) || estimatedPickup.After(requested.Add(90*time.Minute)) {
				continue
			}
		} else if departure.After(time.Now().UTC()) {
			continue // a future journey should not be offered for "Now"
		}

		// Visibility radius: distance from driver's live position to the
		// pickup point must be within the driver's configured radius.
		if c.Journey.CurrentLatitude == nil || c.Journey.CurrentLongitude == nil {
			if scheduled { // planned journeys have no live GPS position yet
				results = append(results, models.JourneyMatch{Journey: c.Journey, DriverName: c.DriverName, DriverRating: c.DriverRating, VehicleModel: c.VehicleModel, VehicleRegNo: c.VehicleReg, Availability: c.Availability, PickupSequence: pickupStop.Sequence, DropSequence: dropStop.Sequence, EstimatedPickupTime: estimatedPickup})
			}
			continue
		}
		dist := utils.HaversineMeters(*c.Journey.CurrentLatitude, *c.Journey.CurrentLongitude, pickupLat, pickupLng)
		if dist > float64(c.VisibilityM) {
			continue
		}

		results = append(results, models.JourneyMatch{
			Journey:             c.Journey,
			DriverName:          c.DriverName,
			DriverRating:        c.DriverRating,
			VehicleModel:        c.VehicleModel,
			VehicleRegNo:        c.VehicleReg,
			Availability:        c.Availability,
			DistanceMeters:      dist,
			PickupSequence:      pickupStop.Sequence,
			DropSequence:        dropStop.Sequence,
			EstimatedPickupTime: estimatedPickup,
		})
	}

	sort.Slice(results, func(i, j int) bool { return results[i].DistanceMeters < results[j].DistanceMeters })
	return results, nil
}

func estimatePickupTime(departure time.Time, stops []models.RouteStop, pickupSequence int) time.Time {
	var meters float64
	for i := 1; i < len(stops) && stops[i].Sequence <= pickupSequence; i++ {
		meters += utils.HaversineMeters(stops[i-1].Latitude, stops[i-1].Longitude, stops[i].Latitude, stops[i].Longitude)
	}
	// 30 km/h is suitable for the hill routes Dagadi targets; it is an estimate,
	// not live navigation, and is deliberately shown as such in the client.
	return departure.Add(time.Duration(meters / 30000.0 * float64(time.Hour)))
}

func availabilityAccepts(a models.Availability, bookingType models.BookingType) bool {
	switch a {
	case models.AvailabilityPassengerParcel:
		return true
	case models.AvailabilityParcelOnly:
		return bookingType == models.BookingParcel
	default: // offline
		return false
	}
}

func nearestStopWithin(stops []models.RouteStop, lat, lng, toleranceM float64) *models.RouteStop {
	var best *models.RouteStop
	bestDist := toleranceM
	for i := range stops {
		d := utils.HaversineMeters(stops[i].Latitude, stops[i].Longitude, lat, lng)
		if d <= bestDist {
			bestDist = d
			best = &stops[i]
		}
	}
	return best
}
