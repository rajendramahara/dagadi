package utils

import "testing"

func TestHaversineMeters_SamePoint(t *testing.T) {
	d := HaversineMeters(29.6350, 79.6903, 29.6350, 79.6903)
	if d != 0 {
		t.Fatalf("expected 0 distance for identical points, got %f", d)
	}
}

func TestHaversineMeters_KnownDistance(t *testing.T) {
	// Almora to Haldwani, Uttarakhand - roughly 65-70km apart.
	almoraLat, almoraLng := 29.5892, 79.6467
	haldwaniLat, haldwaniLng := 29.2183, 79.5130

	d := HaversineMeters(almoraLat, almoraLng, haldwaniLat, haldwaniLng)
	if d < 40000 || d > 90000 {
		t.Fatalf("expected distance roughly between 40km-90km, got %.0fm", d)
	}
}

func TestGenerateOTP_IsSixDigits(t *testing.T) {
	code, err := GenerateOTP()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(code) != 6 {
		t.Fatalf("expected 6-digit code, got %q", code)
	}
	for _, ch := range code {
		if ch < '0' || ch > '9' {
			t.Fatalf("expected only digits, got %q", code)
		}
	}
}
