package handler

import (
	"regexp"
	"strings"
	"time"

	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"dagadi-backend/internal/models"
	"dagadi-backend/internal/repository"
	"dagadi-backend/pkg/utils"
)

var indianRegistrationNumber = regexp.MustCompile(`^[A-Z]{2}[0-9]{2}[A-Z]{2}[0-9]{4}$`)

type DriverHandler struct {
	drivers  repository.DriverRepository
	routes   repository.RouteRepository
	journeys repository.JourneyRepository
}

func NewDriverHandler(d repository.DriverRepository, r repository.RouteRepository, j repository.JourneyRepository) *DriverHandler {
	return &DriverHandler{drivers: d, routes: r, journeys: j}
}

func currentDriverID(c *fiber.Ctx, drivers repository.DriverRepository) (string, error) {
	userID, _ := c.Locals("user_id").(string)
	profile, err := drivers.FindByUserID(userID)
	if err != nil {
		return "", err
	}
	if profile == nil {
		return "", fiber.NewError(fiber.StatusNotFound, "driver profile not found")
	}
	return profile.ID, nil
}

// --- Vehicles ---

type createVehicleBody struct {
	RegistrationNo string `json:"registration_no"`
	Model          string `json:"model"`
	Color          string `json:"color"`
	Capacity       int    `json:"capacity"`
}

func (h *DriverHandler) CreateVehicle(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body createVehicleBody
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "enter a valid registration number, for example UK04TB1343")
	}
	body.RegistrationNo = strings.ToUpper(strings.TrimSpace(body.RegistrationNo))
	if !indianRegistrationNumber.MatchString(body.RegistrationNo) {
		return utils.Fail(c, fiber.StatusBadRequest, "enter a valid registration number, for example UK04TB1343")
	}
	if body.Capacity == 0 {
		body.Capacity = 4
	}
	v := &models.Vehicle{
		ID: uuid.NewString(), OwnerDriverID: driverID, RegistrationNo: body.RegistrationNo,
		Model: body.Model, Color: body.Color, Capacity: body.Capacity, IsActive: true,
	}
	if err := h.drivers.CreateVehicle(v); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not create vehicle")
	}
	return utils.Created(c, v)
}

func (h *DriverHandler) ListVehicles(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	vehicles, err := h.drivers.ListVehiclesByDriver(driverID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not list vehicles")
	}
	return utils.OK(c, vehicles)
}

func (h *DriverHandler) Profile(c *fiber.Ctx) error {
	userID, _ := c.Locals("user_id").(string)
	profile, err := h.drivers.FindByUserID(userID)
	if err != nil || profile == nil {
		return utils.Fail(c, fiber.StatusNotFound, "driver profile not found")
	}
	return utils.OK(c, profile)
}

func (h *DriverHandler) UpdateVehicle(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body createVehicleBody
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "enter a valid registration number, for example UK04TB1343")
	}
	body.RegistrationNo = strings.ToUpper(strings.TrimSpace(body.RegistrationNo))
	if !indianRegistrationNumber.MatchString(body.RegistrationNo) {
		return utils.Fail(c, fiber.StatusBadRequest, "enter a valid registration number, for example UK04TB1343")
	}
	if body.Capacity == 0 {
		body.Capacity = 4
	}
	v := &models.Vehicle{ID: c.Params("id"), OwnerDriverID: driverID, RegistrationNo: body.RegistrationNo, Model: body.Model, Color: body.Color, Capacity: body.Capacity}
	if err := h.drivers.UpdateVehicle(v); err != nil {
		return utils.Fail(c, fiber.StatusNotFound, "vehicle not found")
	}
	return utils.OK(c, v)
}

// --- Fleet ---

type createFleetBody struct {
	Name string `json:"name"`
}

func (h *DriverHandler) CreateFleet(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body createFleetBody
	if err := c.BodyParser(&body); err != nil || body.Name == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "name is required")
	}
	id := uuid.NewString()
	if err := h.drivers.CreateFleet(id, driverID, body.Name); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not create fleet")
	}
	return utils.Created(c, fiber.Map{"id": id, "name": body.Name})
}

func (h *DriverHandler) UpdateFleet(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body createFleetBody
	if err := c.BodyParser(&body); err != nil || strings.TrimSpace(body.Name) == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "name is required")
	}
	if err := h.drivers.UpdateFleet(c.Params("id"), driverID, strings.TrimSpace(body.Name)); err != nil {
		return utils.Fail(c, fiber.StatusNotFound, "fleet not found")
	}
	return utils.OK(c, fiber.Map{"updated": true})
}

func (h *DriverHandler) ListFleets(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	fleets, err := h.drivers.ListFleetsByOwner(driverID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not list fleets")
	}
	return utils.OK(c, fleets)
}

func (h *DriverHandler) DeleteFleet(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	if err := h.drivers.DeleteFleet(c.Params("id"), driverID); err != nil {
		return utils.Fail(c, fiber.StatusNotFound, "fleet not found")
	}
	return utils.OK(c, fiber.Map{"deleted": true})
}

type assignDriverBody struct {
	VehicleID string `json:"vehicle_id"`
	DriverID  string `json:"driver_id"`
}

type assignDriverByPhoneBody struct {
	VehicleID string `json:"vehicle_id"`
	Phone     string `json:"phone"`
}

func (h *DriverHandler) AssignDriverToVehicle(c *fiber.Ctx) error {
	var body assignDriverBody
	if err := c.BodyParser(&body); err != nil || body.VehicleID == "" || body.DriverID == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "vehicle_id and driver_id are required")
	}
	if err := h.drivers.AssignDriverToVehicle(body.VehicleID, body.DriverID); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not assign driver")
	}
	return utils.OK(c, fiber.Map{"assigned": true})
}

func (h *DriverHandler) AssignDriverByPhone(c *fiber.Ctx) error {
	ownerID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body assignDriverByPhoneBody
	if err := c.BodyParser(&body); err != nil || body.VehicleID == "" || body.Phone == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "vehicle_id and phone are required")
	}
	driver, err := h.drivers.FindDriverByPhone(body.Phone)
	if err != nil || driver == nil {
		return utils.Fail(c, fiber.StatusNotFound, "no driver account found for this mobile number")
	}
	if err := h.drivers.AssignDriverToOwnedVehicle(body.VehicleID, driver.ID, ownerID); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "vehicle could not be assigned")
	}
	return utils.OK(c, fiber.Map{"assigned": true})
}

type assignDriverToFleetBody struct {
	FleetID string `json:"fleet_id"`
	Phone   string `json:"phone"`
}

func (h *DriverHandler) AssignDriverToFleet(c *fiber.Ctx) error {
	ownerID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body assignDriverToFleetBody
	if err := c.BodyParser(&body); err != nil || body.FleetID == "" || body.Phone == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "fleet_id and phone are required")
	}
	driver, err := h.drivers.FindDriverByPhone(body.Phone)
	if err != nil || driver == nil {
		return utils.Fail(c, fiber.StatusNotFound, "no driver account found for this mobile number")
	}
	if err := h.drivers.AssignDriverToFleet(body.FleetID, driver.ID, ownerID); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "driver could not be assigned to this fleet")
	}
	return utils.OK(c, fiber.Map{"assigned": true})
}

type assignVehicleToFleetBody struct {
	VehicleID string `json:"vehicle_id"`
	FleetID   string `json:"fleet_id"`
}

func (h *DriverHandler) AssignVehicleToFleet(c *fiber.Ctx) error {
	ownerID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body assignVehicleToFleetBody
	if err := c.BodyParser(&body); err != nil || body.VehicleID == "" || body.FleetID == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "vehicle_id and fleet_id are required")
	}
	if err := h.drivers.AssignVehicleToFleet(body.VehicleID, body.FleetID, ownerID); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "vehicle could not be added to this fleet")
	}
	return utils.OK(c, fiber.Map{"assigned": true})
}

// --- Routes ---

type createRouteBody struct {
	Name        string     `json:"name"`
	IsSaved     bool       `json:"is_saved"`
	ScheduledAt *time.Time `json:"scheduled_at"`
	Stops       []struct {
		Sequence  int     `json:"sequence"`
		Name      string  `json:"name"`
		Latitude  float64 `json:"latitude"`
		Longitude float64 `json:"longitude"`
	} `json:"stops"`
}

func (h *DriverHandler) CreateRoute(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body createRouteBody
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "route date and time are not valid")
	}
	if len(body.Stops) < 2 {
		return utils.Fail(c, fiber.StatusBadRequest, "at least a start and destination stop are required")
	}
	route := &models.Route{ID: uuid.NewString(), DriverID: driverID, Name: body.Name, IsSaved: body.IsSaved, ScheduledAt: body.ScheduledAt}
	if err := h.routes.CreateRoute(route); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not create route")
	}
	for _, st := range body.Stops {
		stop := &models.RouteStop{
			ID: uuid.NewString(), RouteID: route.ID, Sequence: st.Sequence, Name: st.Name,
			Latitude: st.Latitude, Longitude: st.Longitude,
		}
		if err := h.routes.AddStop(stop); err != nil {
			return utils.Fail(c, fiber.StatusInternalServerError, "could not add stop")
		}
	}
	full, err := h.routes.GetRouteWithStops(route.ID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not load route")
	}
	return utils.Created(c, full)
}

func (h *DriverHandler) UpdateRoute(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body createRouteBody
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "route date and time are not valid")
	}
	if len(body.Stops) < 2 {
		return utils.Fail(c, fiber.StatusBadRequest, "at least a start and destination stop are required")
	}
	route := &models.Route{ID: c.Params("id"), DriverID: driverID, Name: body.Name, IsSaved: true, ScheduledAt: body.ScheduledAt}
	if err := h.routes.UpdateRoute(route); err != nil {
		return utils.Fail(c, fiber.StatusNotFound, "route not found")
	}
	if err := h.routes.DeleteStops(route.ID); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not update route stops")
	}
	for _, st := range body.Stops {
		stop := &models.RouteStop{ID: uuid.NewString(), RouteID: route.ID, Sequence: st.Sequence, Name: st.Name, Latitude: st.Latitude, Longitude: st.Longitude}
		if err := h.routes.AddStop(stop); err != nil {
			return utils.Fail(c, fiber.StatusInternalServerError, "could not update route stops")
		}
	}
	full, err := h.routes.GetRouteWithStops(route.ID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not load route")
	}
	return utils.OK(c, full)
}

func (h *DriverHandler) ListSavedRoutes(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	routes, err := h.routes.ListSavedRoutesByDriver(driverID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not list routes")
	}
	return utils.OK(c, routes)
}

func (h *DriverHandler) DeleteRoute(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	if err := h.routes.DeleteRoute(c.Params("id"), driverID); err != nil {
		return utils.Fail(c, fiber.StatusNotFound, "route not found")
	}
	return utils.OK(c, fiber.Map{"deleted": true})
}

// --- Journeys ---

type startJourneyBody struct {
	RouteID       string    `json:"route_id"`
	VehicleID     string    `json:"vehicle_id"`
	DepartureTime time.Time `json:"departure_time"`
}

func (h *DriverHandler) StartJourney(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body startJourneyBody
	if err := c.BodyParser(&body); err != nil || body.RouteID == "" || body.VehicleID == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "route_id and vehicle_id are required")
	}
	if body.DepartureTime.IsZero() {
		body.DepartureTime = time.Now()
	}
	journey := &models.Journey{
		ID: uuid.NewString(), DriverID: driverID, RouteID: body.RouteID, VehicleID: body.VehicleID,
		DepartureTime: body.DepartureTime, Status: models.JourneyActive,
	}
	if err := h.journeys.Create(journey); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not start journey")
	}
	// default availability to passenger_parcel when a journey starts
	_ = h.drivers.UpdateAvailability(driverID, models.AvailabilityPassengerParcel)
	return utils.Created(c, journey)
}

type updatePositionBody struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

func (h *DriverHandler) UpdatePosition(c *fiber.Ctx) error {
	journeyID := c.Params("id")
	var body updatePositionBody
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "latitude and longitude are required")
	}
	if err := h.journeys.UpdatePosition(journeyID, body.Latitude, body.Longitude); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not update position")
	}
	return utils.OK(c, fiber.Map{"updated": true})
}

type advanceStopBody struct {
	Sequence int `json:"sequence"`
}

func (h *DriverHandler) AdvanceStop(c *fiber.Ctx) error {
	journeyID := c.Params("id")
	var body advanceStopBody
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "sequence is required")
	}
	if err := h.journeys.AdvanceCrossedStop(journeyID, body.Sequence); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not advance stop")
	}
	return utils.OK(c, fiber.Map{"advanced": true})
}

func (h *DriverHandler) CompleteJourney(c *fiber.Ctx) error {
	journeyID := c.Params("id")
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	if err := h.journeys.Complete(journeyID); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not complete journey")
	}
	_ = h.drivers.UpdateAvailability(driverID, models.AvailabilityOffline)
	return utils.OK(c, fiber.Map{"completed": true})
}

type availabilityBody struct {
	Availability models.Availability `json:"availability"`
}

func (h *DriverHandler) UpdateAvailability(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body availabilityBody
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "availability is required")
	}
	if body.Availability != models.AvailabilityPassengerParcel &&
		body.Availability != models.AvailabilityParcelOnly &&
		body.Availability != models.AvailabilityOffline {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid availability status")
	}
	routes, routeErr := h.routes.ListSavedRoutesByDriver(driverID)
	if routeErr != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not check saved routes")
	}
	if len(routes) == 0 {
		return utils.Fail(c, fiber.StatusBadRequest, "create a route before changing driver status")
	}
	if err := h.drivers.UpdateAvailability(driverID, body.Availability); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not update availability")
	}
	return utils.OK(c, fiber.Map{"availability": body.Availability})
}

func (h *DriverHandler) ActiveJourneys(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	journeys, err := h.journeys.ListActiveByDriver(driverID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not load active journeys")
	}
	data := make([]fiber.Map, 0, len(journeys))
	for _, item := range journeys {
		stops := make([]fiber.Map, 0, len(item.Stops))
		for _, stop := range item.Stops {
			stops = append(stops, fiber.Map{
				"name": stop.Name, "sequence": stop.Sequence,
				"latitude": stop.Latitude, "longitude": stop.Longitude,
			})
		}
		data = append(data, fiber.Map{
			"id":                    item.Journey.ID,
			"departure_time":        item.Journey.DepartureTime,
			"current_stop_sequence": item.Journey.CurrentStopSequence,
			"current_latitude":      item.Journey.CurrentLatitude,
			"current_longitude":     item.Journey.CurrentLongitude,
			"stops":                 stops,
		})
	}
	return utils.OK(c, data)
}

type visibilityRadiusBody struct {
	RadiusMeters int `json:"radius_meters"`
}

func (h *DriverHandler) UpdateVisibilityRadius(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	var body visibilityRadiusBody
	if err := c.BodyParser(&body); err != nil || body.RadiusMeters <= 0 {
		return utils.Fail(c, fiber.StatusBadRequest, "radius_meters must be positive")
	}
	if err := h.drivers.UpdateVisibilityRadius(driverID, body.RadiusMeters); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not update radius")
	}
	return utils.OK(c, fiber.Map{"radius_meters": body.RadiusMeters})
}
