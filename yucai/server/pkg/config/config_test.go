package config

import (
	"os"
	"strings"
	"testing"
)

// setEnv sets env vars for the duration of t and restores them on cleanup.
// go-envconfig reads at Process time, so we can drive Config.Load deterministically.
func setEnv(t *testing.T, kv map[string]string) {
	t.Helper()
	for k, v := range kv {
		prev, had := os.LookupEnv(k)
		if err := os.Setenv(k, v); err != nil {
			t.Fatalf("setenv %s: %v", k, err)
		}
		t.Cleanup(func() {
			if had {
				_ = os.Setenv(k, prev)
			} else {
				_ = os.Unsetenv(k)
			}
		})
	}
}

func TestLoadFromEnv(t *testing.T) {
	setEnv(t, map[string]string{
		"GRPC_PORT":    "9090",
		"DATABASE_URL": "postgresql://user:pass@localhost:5432/testdb",
		"REDIS_URL":    "redis://localhost:6379/0",
		"JWT_SECRET":   strings.Repeat("a", 32), // ≥32-byte floor
		"LOG_LEVEL":    "debug",
	})

	cfg, err := Load()
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if cfg.GRPCPort != "9090" {
		t.Errorf("expected port 9090, got %s", cfg.GRPCPort)
	}
	if cfg.DatabaseURL != "postgresql://user:pass@localhost:5432/testdb" {
		t.Errorf("unexpected DATABASE_URL: %s", cfg.DatabaseURL)
	}
	if cfg.JWTSecret != strings.Repeat("a", 32) {
		t.Errorf("unexpected JWT_SECRET")
	}
}

// TestLoad_RejectsShortJWTSecret verifies the ≥32-byte floor on JWT_SECRET.
// A short secret enables offline HS256 brute-force, so config.Load must refuse
// to boot — surfacing the failure at startup beats running silently insecure.
func TestLoad_RejectsShortJWTSecret(t *testing.T) {
	setEnv(t, map[string]string{
		"DATABASE_URL": "postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable",
		"JWT_SECRET":   "too-short", // 9 bytes — well under the 32-byte floor
	})
	_, err := Load()
	if err == nil {
		t.Fatal("Load should reject a <32-byte JWT_SECRET")
	}
	if !strings.Contains(err.Error(), "JWT_SECRET") {
		t.Errorf("error should mention JWT_SECRET, got: %v", err)
	}
	if !strings.Contains(err.Error(), "32") {
		t.Errorf("error should mention the 32-byte minimum, got: %v", err)
	}
}

// TestLoad_AppliesDefaultIssuer confirms the JWTIssuer default is applied when
// the env var is unset.
func TestLoad_AppliesDefaultIssuer(t *testing.T) {
	setEnv(t, map[string]string{
		"DATABASE_URL": "postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable",
		"JWT_SECRET":   strings.Repeat("a", 48),
		"JWT_ISSUER":   "", // exercise the default path
	})
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load with strong secret failed: %v", err)
	}
	if cfg.JWTIssuer != defaultJWTIssuer {
		t.Errorf("JWTIssuer default = %q, want %q", cfg.JWTIssuer, defaultJWTIssuer)
	}
}

// TestLoad_31BytesRejected_32BytesAccepted pins the boundary so a future tweak
// to minJWTSecretBytes is intentional, not a drift.
func TestLoad_31BytesRejected_32BytesAccepted(t *testing.T) {
	for _, tc := range []struct {
		name    string
		secret  string
		wantErr bool
	}{
		{"31 bytes", strings.Repeat("k", 31), true},
		{"32 bytes", strings.Repeat("k", 32), false},
	} {
		t.Run(tc.name, func(t *testing.T) {
			setEnv(t, map[string]string{
				"DATABASE_URL": "postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable",
				"JWT_SECRET":   tc.secret,
			})
			_, err := Load()
			if tc.wantErr && err == nil {
				t.Error("expected error, got nil")
			}
			if !tc.wantErr && err != nil {
				t.Errorf("expected no error, got: %v", err)
			}
		})
	}
}
