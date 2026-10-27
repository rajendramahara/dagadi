package handler

import (
	"github.com/gofiber/fiber/v2"

	"dagadi-backend/internal/repository"
	"dagadi-backend/internal/service"
	"dagadi-backend/pkg/utils"
)

type TicketHandler struct {
	bookingSvc *service.BookingService
	ticketSvc  *service.TicketService
	drivers    repository.DriverRepository
	bookings   repository.BookingRepository
}

func NewTicketHandler(b *service.BookingService, t *service.TicketService, d repository.DriverRepository, br repository.BookingRepository) *TicketHandler {
	return &TicketHandler{bookingSvc: b, ticketSvc: t, drivers: d, bookings: br}
}

func (h *TicketHandler) AcceptBooking(c *fiber.Ctx) error {
	bookingID := c.Params("id")
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	ticket, err := h.bookingSvc.Accept(bookingID, driverID)
	if err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, ticket)
}

func (h *TicketHandler) RejectBooking(c *fiber.Ctx) error {
	bookingID := c.Params("id")
	if err := h.bookingSvc.Reject(bookingID); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, fiber.Map{"rejected": true})
}

func (h *TicketHandler) IncomingRequests(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	bookings, err := h.bookings.ListPendingForDriver(driverID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not list requests")
	}
	return utils.OK(c, bookings)
}

type completeTicketBody struct {
	FarePaise     int64  `json:"fare_paise"`
	PaymentMethod string `json:"payment_method"`
	Notes         string `json:"notes"`
}

// CompleteTicket - "Complete Ticket" button. Only after this call does the
// ride count toward revenue; drivers can leave it pending indefinitely.
func (h *TicketHandler) CompleteTicket(c *fiber.Ctx) error {
	ticketID := c.Params("id")
	var body completeTicketBody
	if err := c.BodyParser(&body); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, "fare_paise and payment_method are required")
	}
	if err := h.ticketSvc.CompleteTicket(ticketID, body.FarePaise, body.PaymentMethod, body.Notes); err != nil {
		return utils.Fail(c, fiber.StatusBadRequest, err.Error())
	}
	return utils.OK(c, fiber.Map{"completed": true})
}

func (h *TicketHandler) PendingTickets(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	tickets, err := h.ticketSvc.PendingForDriver(driverID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not list tickets")
	}
	return utils.OK(c, tickets)
}

func (h *TicketHandler) TicketHistory(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	tickets, err := h.ticketSvc.HistoryForDriver(driverID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not list history")
	}
	return utils.OK(c, tickets)
}

func (h *TicketHandler) RevenueDashboard(c *fiber.Ctx) error {
	driverID, err := currentDriverID(c, h.drivers)
	if err != nil {
		return utils.Fail(c, fiber.StatusNotFound, err.Error())
	}
	summary, err := h.ticketSvc.RevenueDashboard(driverID)
	if err != nil {
		return utils.Fail(c, fiber.StatusInternalServerError, "could not load revenue")
	}
	return utils.OK(c, summary)
}
