package service

import (
	"errors"
	"time"

	"dagadi-backend/internal/config"
	"dagadi-backend/internal/models"
	"dagadi-backend/internal/repository"
	"dagadi-backend/pkg/utils"
)

type AdminService struct {
	cfg   *config.Config
	admin repository.AdminRepository
}

func NewAdminService(cfg *config.Config, admin repository.AdminRepository) *AdminService {
	return &AdminService{cfg: cfg, admin: admin}
}

// EnsureDefaultAdmin seeds a bootstrap admin account (username: admin,
// password: from DEFAULT_ADMIN_PASSWORD or "changeme123") on first boot
// so the panel isn't locked out before Admin Settings can edit it.
func (s *AdminService) EnsureDefaultAdmin(defaultUsername, defaultPassword string) error {
	hash, err := utils.HashPassword(defaultPassword)
	if err != nil {
		return err
	}
	return s.admin.SeedDefaultIfEmpty("admin-default", defaultUsername, hash)
}

func (s *AdminService) Login(username, password string) (string, error) {
	_, hash, err := s.admin.FindByUsername(username)
	if err != nil {
		return "", err
	}
	if hash == "" || !utils.CheckPassword(hash, password) {
		return "", errors.New("invalid admin credentials")
	}
	access, _, err := utils.GenerateTokenPair(s.cfg.JWTSecret, "admin", string(models.RoleAdmin))
	return access, err
}

// UpdateCredentials lets Admin Settings edit the username/password, per spec.
func (s *AdminService) UpdateCredentials(currentUsername, newUsername, newPassword string) error {
	hash, err := utils.HashPassword(newPassword)
	if err != nil {
		return err
	}
	return s.admin.UpdateCredentials(newUsername, currentUsername, hash)
}

func (s *AdminService) SetUserActive(userID string, active bool) error {
	return s.admin.SetUserActive(userID, active)
}

func (s *AdminService) UserDetails(userID, period string) (*repository.UserDetail, error) {
	now := time.Now()
	since := now.AddDate(0, 0, -1)
	switch period {
	case "week":
		since = now.AddDate(0, 0, -7)
	case "month":
		since = now.AddDate(0, -1, 0)
	case "3m":
		since = now.AddDate(0, -3, 0)
	case "6m":
		since = now.AddDate(0, -6, 0)
	case "year":
		since = now.AddDate(-1, 0, 0)
	}
	return s.admin.UserDetails(userID, since)
}

func (s *AdminService) Fleets() ([]repository.FleetInfo, error) { return s.admin.ListFleets() }

type DashboardAnalytics struct {
	TotalUsers           int                       `json:"total_users"`
	GPSReportingJourneys int                       `json:"gps_reporting_journeys"`
	GPSMissingJourneys   int                       `json:"gps_missing_journeys"`
	TotalDrivers         int                       `json:"total_drivers"`
	LiveTrips            int                       `json:"live_trips"`
	RevenueTodayPaise    int64                     `json:"revenue_today_paise"`
	PendingTickets       int                       `json:"pending_tickets"`
	PendingParcels       int                       `json:"pending_parcels"`
	AvgDriverRating      float64                   `json:"avg_driver_rating"`
	CancellationRate     float64                   `json:"cancellation_rate"`
	TopRoutes            []repository.TopRoute     `json:"top_routes"`
	RecentUsers          []repository.UserActivity `json:"recent_users"`
}

func (s *AdminService) Dashboard() (*DashboardAnalytics, error) {
	allUsers, err := s.admin.CountUsers()
	if err != nil {
		return nil, err
	}
	gpsReporting, err := s.admin.CountActiveJourneysWithGPS(true)
	if err != nil {
		return nil, err
	}
	gpsMissing, err := s.admin.CountActiveJourneysWithGPS(false)
	if err != nil {
		return nil, err
	}
	totalDrivers, err := s.admin.CountUsersByRole("driver")
	if err != nil {
		return nil, err
	}
	liveTrips, err := s.admin.CountActiveJourneys()
	if err != nil {
		return nil, err
	}
	revenueToday, err := s.admin.RevenueTodayAllDrivers()
	if err != nil {
		return nil, err
	}
	pendingTickets, err := s.admin.CountPendingTickets()
	if err != nil {
		return nil, err
	}
	pendingParcels, err := s.admin.CountPendingBookingsByType("parcel")
	if err != nil {
		return nil, err
	}
	avgRating, err := s.admin.AverageDriverRating()
	if err != nil {
		return nil, err
	}
	cancellationRate, err := s.admin.CancellationRate()
	if err != nil {
		return nil, err
	}
	topRoutes, err := s.admin.TopRoutesByTripCount(5)
	if err != nil {
		return nil, err
	}
	recentUsers, err := s.admin.RecentUserActivity(20)
	if err != nil {
		return nil, err
	}

	return &DashboardAnalytics{
		TotalUsers: allUsers, TotalDrivers: totalDrivers, LiveTrips: liveTrips, GPSReportingJourneys: gpsReporting, GPSMissingJourneys: gpsMissing,
		RevenueTodayPaise: revenueToday, PendingTickets: pendingTickets, PendingParcels: pendingParcels,
		AvgDriverRating: avgRating, CancellationRate: cancellationRate, TopRoutes: topRoutes, RecentUsers: recentUsers,
	}, nil
}
