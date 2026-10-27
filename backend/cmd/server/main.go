package main

import (
	"log"
	"os"

	"github.com/gofiber/fiber/v2"
	"github.com/gofiber/fiber/v2/middleware/cors"
	"github.com/gofiber/fiber/v2/middleware/limiter"
	"github.com/gofiber/fiber/v2/middleware/logger"

	"dagadi-backend/internal/config"
	"dagadi-backend/internal/database"
	"dagadi-backend/internal/handler"
	"dagadi-backend/internal/middleware"
	"dagadi-backend/internal/repository"
	"dagadi-backend/internal/service"
)

func main() {
	cfg := config.Load()

	db, err := database.Connect(cfg.DBPath)
	if err != nil {
		log.Fatalf("db connect failed: %v", err)
	}
	defer db.Close()

	if err := database.RunMigrations(db); err != nil {
		log.Fatalf("migrations failed: %v", err)
	}

	// --- repositories ---
	userRepo := repository.NewUserRepository(db)
	driverRepo := repository.NewDriverRepository(db)
	routeRepo := repository.NewRouteRepository(db)
	journeyRepo := repository.NewJourneyRepository(db)
	bookingRepo := repository.NewBookingRepository(db)
	ticketRepo := repository.NewTicketRepository(db)
	adminRepo := repository.NewAdminRepository(db)
	reviewRepo := repository.NewReviewRepository(db)

	// --- services ---
	notificationSvc := service.NewNotificationService(db)
	authSvc := service.NewAuthService(cfg, userRepo, driverRepo)
	matchingSvc := service.NewMatchingService(journeyRepo)
	bookingSvc := service.NewBookingService(bookingRepo, ticketRepo, journeyRepo, driverRepo, notificationSvc)
	ticketSvc := service.NewTicketService(ticketRepo, bookingRepo, notificationSvc)
	adminSvc := service.NewAdminService(cfg, adminRepo)

	defaultAdminPassword := os.Getenv("DEFAULT_ADMIN_PASSWORD")
	if defaultAdminPassword == "" {
		defaultAdminPassword = "changeme123"
	}
	if err := adminSvc.EnsureDefaultAdmin("admin", defaultAdminPassword); err != nil {
		log.Fatalf("could not seed default admin: %v", err)
	}

	// --- handlers ---
	authHandler := handler.NewAuthHandler(authSvc)
	driverHandler := handler.NewDriverHandler(driverRepo, routeRepo, journeyRepo)
	passengerHandler := handler.NewPassengerHandler(matchingSvc, bookingSvc, bookingRepo)
	ticketHandler := handler.NewTicketHandler(bookingSvc, ticketSvc, driverRepo, bookingRepo)
	adminHandler := handler.NewAdminHandler(adminSvc)
	reviewHandler := handler.NewReviewHandler(reviewRepo, notificationSvc)
	notificationHandler := handler.NewNotificationHandler(notificationSvc)

	app := fiber.New(fiber.Config{
		ErrorHandler: func(c *fiber.Ctx, err error) error {
			code := fiber.StatusInternalServerError
			if fe, ok := err.(*fiber.Error); ok {
				code = fe.Code
			}
			return c.Status(code).JSON(fiber.Map{"success": false, "error": err.Error()})
		},
	})
	app.Use(logger.New())
	app.Use(cors.New(cors.Config{AllowOrigins: "*", AllowHeaders: "Origin, Content-Type, Accept, Authorization"}))
	app.Use(limiter.New(limiter.Config{Max: 120, Expiration: 60}))

	api := app.Group("/api/v1")

	// --- auth (public, tightly rate-limited against OTP abuse) ---
	auth := api.Group("/auth", limiter.New(limiter.Config{Max: 10, Expiration: 60}))
	auth.Post("/otp/request", authHandler.RequestOTP)
	auth.Post("/otp/verify", authHandler.VerifyOTP)
	auth.Post("/otp/check", authHandler.CheckOTP)
	auth.Post("/refresh", authHandler.Refresh)
	authAuthed := api.Group("/auth", middleware.RequireAuth(cfg.JWTSecret))
	authAuthed.Post("/role", authHandler.SwitchRole)
	authAuthed.Patch("/profile", authHandler.UpdateProfile)

	// --- admin (public login, then role-protected) ---
	adminPublic := api.Group("/admin", limiter.New(limiter.Config{Max: 10, Expiration: 60}))
	adminPublic.Post("/login", adminHandler.Login)
	adminAuthed := api.Group("/admin", middleware.RequireAuth(cfg.JWTSecret), middleware.RequireRole("admin"))
	adminAuthed.Get("/dashboard", adminHandler.Dashboard)
	adminAuthed.Patch("/credentials", adminHandler.UpdateCredentials)
	adminAuthed.Patch("/users/:id/status", adminHandler.SetUserStatus)
	adminAuthed.Get("/users/:id/details", adminHandler.UserDetails)
	adminAuthed.Get("/fleets", adminHandler.Fleets)

	// --- notifications (any authenticated role) ---
	notifications := api.Group("/notifications", middleware.RequireAuth(cfg.JWTSecret))
	notifications.Post("/register-token", notificationHandler.RegisterToken)

	// --- passenger (authenticated) ---
	passenger := api.Group("/passenger", middleware.RequireAuth(cfg.JWTSecret))
	passenger.Post("/search", passengerHandler.SearchDrivers)
	passenger.Post("/requests", passengerHandler.CreateRequest)
	passenger.Get("/bookings", passengerHandler.MyBookings)
	passenger.Post("/reviews", reviewHandler.Create)

	// --- driver (authenticated + role=driver) ---
	driver := api.Group("/driver", middleware.RequireAuth(cfg.JWTSecret), middleware.RequireRole("driver"))
	driver.Post("/vehicles", driverHandler.CreateVehicle)
	driver.Get("/vehicles", driverHandler.ListVehicles)
	driver.Put("/vehicles/:id", driverHandler.UpdateVehicle)
	driver.Get("/profile", driverHandler.Profile)
	driver.Post("/fleets", driverHandler.CreateFleet)
	driver.Get("/fleets", driverHandler.ListFleets)
	driver.Put("/fleets/:id", driverHandler.UpdateFleet)
	driver.Delete("/fleets/:id", driverHandler.DeleteFleet)
	driver.Post("/fleets/assign", driverHandler.AssignDriverToVehicle)
	driver.Post("/fleets/assign-by-phone", driverHandler.AssignDriverByPhone)
	driver.Post("/fleets/assign-driver", driverHandler.AssignDriverToFleet)
	driver.Post("/fleets/add-vehicle", driverHandler.AssignVehicleToFleet)
	driver.Post("/routes", driverHandler.CreateRoute)
	driver.Put("/routes/:id", driverHandler.UpdateRoute)
	driver.Get("/routes/saved", driverHandler.ListSavedRoutes)
	driver.Delete("/routes/:id", driverHandler.DeleteRoute)
	driver.Get("/journeys/active", driverHandler.ActiveJourneys)
	driver.Post("/journeys", driverHandler.StartJourney)
	driver.Post("/journeys/:id/position", driverHandler.UpdatePosition)
	driver.Post("/journeys/:id/advance-stop", driverHandler.AdvanceStop)
	driver.Post("/journeys/:id/complete", driverHandler.CompleteJourney)
	driver.Patch("/availability", driverHandler.UpdateAvailability)
	driver.Patch("/visibility-radius", driverHandler.UpdateVisibilityRadius)
	driver.Get("/requests", ticketHandler.IncomingRequests)
	driver.Post("/bookings/:id/accept", ticketHandler.AcceptBooking)
	driver.Post("/bookings/:id/reject", ticketHandler.RejectBooking)
	driver.Get("/tickets/pending", ticketHandler.PendingTickets)
	driver.Get("/tickets/history", ticketHandler.TicketHistory)
	driver.Post("/tickets/:id/complete", ticketHandler.CompleteTicket)
	driver.Get("/revenue", ticketHandler.RevenueDashboard)

	// public read of a driver's reviews (shown on passenger-side driver cards)
	api.Get("/drivers/:driverId/reviews", reviewHandler.ListForDriver)

	app.Get("/health", func(c *fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok"})
	})

	log.Printf("Dagadi backend listening on :%s (env=%s)", cfg.Port, cfg.Environment)
	if err := app.Listen(":" + cfg.Port); err != nil {
		log.Fatal(err)
	}
}
