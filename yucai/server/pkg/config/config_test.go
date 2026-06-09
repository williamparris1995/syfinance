package config

import (
	"os"
	"testing"
)

func TestLoadFromEnv(t *testing.T) {
	os.Setenv("GRPC_PORT", "9090")
	os.Setenv("DATABASE_URL", "postgresql://user:pass@localhost:5432/testdb")
	os.Setenv("REDIS_URL", "redis://localhost:6379/0")
	os.Setenv("JWT_SECRET", "test-secret")
	os.Setenv("LOG_LEVEL", "debug")
	defer func() {
		os.Unsetenv("GRPC_PORT")
		os.Unsetenv("DATABASE_URL")
		os.Unsetenv("REDIS_URL")
		os.Unsetenv("JWT_SECRET")
		os.Unsetenv("LOG_LEVEL")
	}()

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
	if cfg.JWTSecret != "test-secret" {
		t.Errorf("unexpected JWT_SECRET")
	}
}
