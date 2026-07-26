package config

import (
	"context"
	"fmt"

	"github.com/sethvargo/go-envconfig"
)

// JWT token defaults. The JWT issuer identifies this御财 server — Parser enforces
// it on every access token so tokens minted for a different audience/issuer are
// rejected. JWTAudience is constant ("yucai"); JWTIssuer is configurable so a
// multi-instance deploy can pin a specific issuer if needed.
const (
	JWTAudience       = "yucai"
	defaultJWTIssuer  = "yucai-server"
	minJWTSecretBytes = 32 // HS256 offline-brute-force floor (≈128 bits)
)

// Config holds all server configuration.
type Config struct {
	GRPCPort    string `env:"GRPC_PORT,default=9090"`
	DatabaseURL string `env:"DATABASE_URL,required"`
	RedisURL    string `env:"REDIS_URL,default=redis://localhost:6379/0"`
	JWTSecret   string `env:"JWT_SECRET,required"`
	// JWTIssuer is the iss claim stamped on every access token and enforced
	// by ParseAccessToken. Defaults to "yucai-server".
	JWTIssuer         string `env:"JWT_ISSUER,default=yucai-server"`
	LogLevel          string `env:"LOG_LEVEL,default=info"`
	BackupDir         string `env:"BACKUP_DIR,default=./backups"`
	OIDCProvidersPath string `env:"OIDC_PROVIDERS_PATH,default=config/oidc_providers.yaml"`
}

// Load reads configuration from environment variables and validates the
// security-critical invariants that envconfig can't express on its own.
//
// JWT_SECRET strength: HS256's security collapses entirely if the secret is
// short enough to brute-force offline (a stolen token + a 6-char secret is
// cracked in seconds). Rejecting <32 bytes at startup prevents a misconfigured
// deployment from ever running in that state.
func Load() (*Config, error) {
	var cfg Config
	if err := envconfig.Process(context.Background(), &cfg); err != nil {
		return nil, err
	}
	if len(cfg.JWTSecret) < minJWTSecretBytes {
		return nil, fmt.Errorf(
			"JWT_SECRET must be at least %d bytes for HS256 security (got %d) — "+
				"generate one with `openssl rand -base64 48`",
			minJWTSecretBytes, len(cfg.JWTSecret),
		)
	}
	if cfg.JWTIssuer == "" {
		cfg.JWTIssuer = defaultJWTIssuer
	}
	return &cfg, nil
}
