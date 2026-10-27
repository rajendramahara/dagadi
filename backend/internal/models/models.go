package models

import "time"

type Role string

const (
	RolePassenger Role = "passenger"
	RoleDriver    Role = "driver"
	RoleAdmin     Role = "admin"
)

type Availability string

const (
	AvailabilityPassengerParcel Availability = "passenger_parcel"
	AvailabilityParcelOnly      Availability = "parcel_only"
	AvailabilityOffline         Availability = "offline"
)

type BookingType string

const (
	BookingRide   BookingType = "ride"
	BookingParcel BookingType = "parcel"
)

type BookingStatus string

const (
	BookingPending   BookingStatus = "pending"
	BookingAccepted  BookingStatus = "accepted"
	BookingRejected  BookingStatus = "rejected"
	BookingCancelled BookingStatus = "cancelled"
	BookingCompleted BookingStatus = "completed"
)

type User struct {
	ID        string     `json:"id"`
	Phone     string     `json:"phone"`
	Name      string     `json:"name"`
	Role      Role       `json:"role"`
	Language  string     `json:"language"`
	IsActive  bool       `json:"is_active"`
	CreatedAt time.Time  `json:"created_at"`
	DeletedAt *time.Time `json:"deleted_at,omitempty"`
}

type DriverProfile struct {
	ID                string       `json:"id"`
	UserID            string       `json:"user_id"`
	Availability      Availability `json:"availability"`
	VisibilityRadiusM int          `json:"visibility_radius_m"`
	RatingAvg         float64      `json:"rating_avg"`
	RatingCount       int          `json:"rating_count"`
	DocumentsVerified bool         `json:"documents_verified"`
}

type Vehicle struct {
	ID               string  `json:"id"`
	FleetID          *string `json:"fleet_id,omitempty"`
	OwnerDriverID    string  `json:"owner_driver_id"`
	AssignedDriverID *string `json:"assigned_driver_id,omitempty"`
	RegistrationNo   string  `json:"registration_no"`
	Model            string  `json:"model"`
	Color            string  `json:"color"`
	Capacity         int     `json:"capacity"`
	IsActive         bool    `json:"is_active"`
}

type Fleet struct {
	ID                  string    `json:"id"`
	OwnerID             string    `json:"owner_id"`
	Name                string    `json:"name"`
	AssignedDriverID    *string   `json:"assigned_driver_id,omitempty"`
	AssignedDriverName  *string   `json:"assigned_driver_name,omitempty"`
	AssignedDriverPhone *string   `json:"assigned_driver_phone,omitempty"`
	CreatedAt           time.Time `json:"created_at"`
}

type RouteStop struct {
	ID        string  `json:"id"`
	RouteID   string  `json:"route_id"`
	Sequence  int     `json:"sequence"`
	Name      string  `json:"name"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type Route struct {
	ID          string      `json:"id"`
	DriverID    string      `json:"driver_id"`
	Name        string      `json:"name"`
	IsSaved     bool        `json:"is_saved"`
	ScheduledAt *time.Time  `json:"scheduled_at,omitempty"`
	Stops       []RouteStop `json:"stops,omitempty"`
}

type JourneyStatus string

const (
	JourneyActive    JourneyStatus = "active"
	JourneyCompleted JourneyStatus = "completed"
	JourneyCancelled JourneyStatus = "cancelled"
)

type Journey struct {
	ID                  string        `json:"id"`
	DriverID            string        `json:"driver_id"`
	RouteID             string        `json:"route_id"`
	VehicleID           string        `json:"vehicle_id"`
	DepartureTime       time.Time     `json:"departure_time"`
	Status              JourneyStatus `json:"status"`
	CurrentStopSequence int           `json:"current_stop_sequence"`
	CurrentLatitude     *float64      `json:"current_latitude,omitempty"`
	CurrentLongitude    *float64      `json:"current_longitude,omitempty"`
}

// JourneyMatch is the shape returned to passengers searching for drivers -
// it merges journey + driver + vehicle + computed distance for display.
type JourneyMatch struct {
	Journey             Journey      `json:"journey"`
	DriverName          string       `json:"driver_name"`
	DriverRating        float64      `json:"driver_rating"`
	VehicleModel        string       `json:"vehicle_model"`
	VehicleRegNo        string       `json:"vehicle_reg_no"`
	Availability        Availability `json:"availability"`
	DistanceMeters      float64      `json:"distance_meters"`
	PickupSequence      int          `json:"pickup_sequence"`
	DropSequence        int          `json:"drop_sequence"`
	EstimatedPickupTime time.Time    `json:"estimated_pickup_time"`
}

type Booking struct {
	ID              string        `json:"id"`
	JourneyID       string        `json:"journey_id"`
	PassengerID     string        `json:"passenger_id"`
	BookingType     BookingType   `json:"booking_type"`
	PickupName      string        `json:"pickup_name"`
	PickupLat       float64       `json:"pickup_lat"`
	PickupLng       float64       `json:"pickup_lng"`
	PickupSequence  int           `json:"pickup_sequence"`
	DropName        string        `json:"drop_name"`
	DropLat         float64       `json:"drop_lat"`
	DropLng         float64       `json:"drop_lng"`
	DropSequence    int           `json:"drop_sequence"`
	Note            string        `json:"note"`
	PassengerCount  int           `json:"passenger_count"`
	ParcelWeightKg  *float64      `json:"parcel_weight_kg,omitempty"`
	ParcelSize      string        `json:"parcel_size,omitempty"`
	ParcelImageData string        `json:"parcel_image_data,omitempty"`
	Status          BookingStatus `json:"status"`
}

type TicketStatus string

const (
	TicketPending   TicketStatus = "pending"
	TicketCompleted TicketStatus = "completed"
)

type Ticket struct {
	ID            string       `json:"id"`
	BookingID     string       `json:"booking_id"`
	DriverID      string       `json:"driver_id"`
	FarePaise     *int64       `json:"fare_paise,omitempty"`
	PaymentMethod *string      `json:"payment_method,omitempty"`
	Notes         string       `json:"notes"`
	Status        TicketStatus `json:"status"`
	CompletedAt   *time.Time   `json:"completed_at,omitempty"`
}

type RevenueSummary struct {
	Period       string `json:"period"` // today | week | month | year
	TripCount    int    `json:"trip_count"`
	ParcelCount  int    `json:"parcel_count"`
	RevenuePaise int64  `json:"revenue_paise"`
}
