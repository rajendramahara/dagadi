package utils

import (
	"crypto/rand"
	"fmt"
	"math"
)

// GenerateOTP returns a random 6-digit numeric code. Not used in
// development mode (fixed OTP), only when APP_ENV=production and the
// backend needs to issue its own code prior to Firebase verification,
// or as a fallback channel.
func GenerateOTP() (string, error) {
	b := make([]byte, 4)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	n := (int(b[0])<<24 | int(b[1])<<16 | int(b[2])<<8 | int(b[3])) % 1000000
	if n < 0 {
		n = -n
	}
	return fmt.Sprintf("%06d", n), nil
}

// HaversineMeters returns the great-circle distance between two
// lat/lng points in meters. Used for the "driver inside visibility
// radius" matching rule.
func HaversineMeters(lat1, lng1, lat2, lng2 float64) float64 {
	const earthRadiusM = 6371000.0
	dLat := degToRad(lat2 - lat1)
	dLng := degToRad(lng2 - lng1)
	a := math.Sin(dLat/2)*math.Sin(dLat/2) +
		math.Cos(degToRad(lat1))*math.Cos(degToRad(lat2))*
			math.Sin(dLng/2)*math.Sin(dLng/2)
	c := 2 * math.Atan2(math.Sqrt(a), math.Sqrt(1-a))
	return earthRadiusM * c
}

func degToRad(d float64) float64 {
	return d * math.Pi / 180
}
