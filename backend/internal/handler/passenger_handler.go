package handler

import (
	"github.com/gofiber/fiber/v2"
	"time"

	"dagadi-backend/internal/models"
	"dagadi-backend/internal/repository"
	"dagadi-backend/internal/service"
	"dagadi-backend/pkg/utils"
)

type PassengerHandler struct {
	matching *service.MatchingService
	bookings *service.BookingService
	repo     repository.BookingRepository
}

func NewPassengerHandler(m *service.MatchingService, b *service.BookingService, repo repository.BookingRepository) *PassengerHandler {
	return &PassengerHandler{matching: m, bookings: b, repo: repo}
}

type searchDriversBody struct {
	PickupLat     float64            `json:"pickup_lat"`
	PickupLng     float64            `json:"pickup_lng"`
	DropLat       float64            `json:"drop_lat"`
	DropLng       float64            `json:"drop_lng"`
	BookingType   models.BookingType `json:"booking_type"`
	RequestedTime string             `json:"requested_time"`
}

func (h *PassengerHandler) SearchDrivers(c *fiber.Ctx) error {
	var body searchDriversBody
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "invalid search payload")
	}
	if body.BookingType == "" {
		body.BookingType = models.BookingRide
	}
	var matches []models.JourneyMatch
	var err error
	if body.RequestedTime != "" {
		requested, parseErr := time.Parse(time.RFC3339, body.RequestedTime)
		if parseErr != nil {
			return utils.Fail(c, fiber.StatusBadRequest, "requested_time must be ISO-8601")
		}
		matches, err = h.matching.FindMatchesForTime(body.PickupLat, body.PickupLng, body.DropLat, body.DropLng, body.BookingType, requested)
	} else {
		matches, err = h.matching.FindMatches(body.PickupLat, body.PickupLng, body.DropLat, body.DropLng, body.BookingType)
	}
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not search drivers")
	}
	return utils.OK(c, matches)
}

type createRequestBody struct {
	JourneyID       string             `json:"journey_id"`
	BookingType     models.BookingType `json:"booking_type"`
	PickupName      string             `json:"pickup_name"`
	PickupLat       float64            `json:"pickup_lat"`
	PickupLng       float64            `json:"pickup_lng"`
	PickupSequence  int                `json:"pickup_sequence"`
	DropName        string             `json:"drop_name"`
	DropLat         float64            `json:"drop_lat"`
	DropLng         float64            `json:"drop_lng"`
	DropSequence    int                `json:"drop_sequence"`
	Note            string             `json:"note"`
	PassengerCount  int                `json:"passenger_count"`
	ParcelWeightKg  *float64           `json:"parcel_weight_kg"`
	ParcelSize      string             `json:"parcel_size"`
	ParcelImageData string             `json:"parcel_image_data"`
}

func (h *PassengerHandler) CreateRequest(c *fiber.Ctx) error {
	passengerID, _ := c.Locals("user_id").(string)
	var body createRequestBody
	if err := c.BodyParser(&body); err != nil || body.JourneyID == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "journey_id is required")
	}
	if body.BookingType == "" {
		body.BookingType = models.BookingRide
	}
	booking, err := h.bookings.CreateRequest(passengerID, body.JourneyID, body.BookingType,
		body.PickupName, body.PickupLat, body.PickupLng, body.PickupSequence,
		body.DropName, body.DropLat, body.DropLng, body.DropSequence, body.Note,
		body.PassengerCount, body.ParcelWeightKg, body.ParcelSize, body.ParcelImageData)
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.Created(c, booking)
}

func (h *PassengerHandler) MyBookings(c *fiber.Ctx) error {
	passengerID, _ := c.Locals("user_id").(string)
	bookings, err := h.repo.ListForPassenger(passengerID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not list bookings")
	}
	return utils.OK(c, bookings)
}
