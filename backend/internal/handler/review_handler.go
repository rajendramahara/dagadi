package handler

import (
	"github.com/gofiber/fiber/v2"
	"github.com/google/uuid"

	"dagadi-backend/internal/repository"
	"dagadi-backend/internal/service"
	"dagadi-backend/pkg/utils"
)

type ReviewHandler struct {
	reviews  repository.ReviewRepository
	notifier *service.NotificationService
}

func NewReviewHandler(r repository.ReviewRepository, n *service.NotificationService) *ReviewHandler {
	return &ReviewHandler{reviews: r, notifier: n}
}

type createReviewBody struct {
	TicketID string `json:"ticket_id"`
	DriverID string `json:"driver_id"`
	Rating   int    `json:"rating"`
	Comment  string `json:"comment"`
}

func (h *ReviewHandler) Create(c *fiber.Ctx) error {
	passengerID, _ := c.Locals("user_id").(string)
	var body createReviewBody
	if err := c.BodyParser(&body); err != nil || body.Rating < 1 || body.Rating > 5 {
		return utils.Fail(c, fiber.StatusBadRequest, "rating must be between 1 and 5")
	}
	review := &repository.Review{
		ID: uuid.NewString(), TicketID: body.TicketID, PassengerID: passengerID,
		DriverID: body.DriverID, Rating: body.Rating, Comment: body.Comment,
	}
	if err := h.reviews.Create(review); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not save review")
	}
	return utils.Created(c, review)
}

func (h *ReviewHandler) ListForDriver(c *fiber.Ctx) error {
	driverID := c.Params("driverId")
	reviews, err := h.reviews.ListForDriver(driverID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not list reviews")
	}
	return utils.OK(c, reviews)
}

// NotificationHandler covers FCM token registration for push delivery.
type NotificationHandler struct {
	notifier *service.NotificationService
}

func NewNotificationHandler(n *service.NotificationService) *NotificationHandler {
	return &NotificationHandler{notifier: n}
}

type registerTokenBody struct {
	Token string `json:"token"`
}

func (h *NotificationHandler) RegisterToken(c *fiber.Ctx) error {
	userID, _ := c.Locals("user_id").(string)
	var body registerTokenBody
	if err := c.BodyParser(&body); err != nil || body.Token == "" {
		return utils.Fail(c, fiber.StatusBadRequest, "token is required")
	}
	if err := h.notifier.RegisterToken(userID, body.Token); err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not register token")
	}
	return utils.OK(c, fiber.Map{"registered": true})
}
