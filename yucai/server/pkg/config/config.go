package config

import (
	"context"

	"github.com/sethvargo/go-envconfig"
)

// Config holds all server configuration.
type Config struct {
	GRPCPort    string `env:"GRPC_PORT,default=9090"`
	DatabaseURL string `env:"DATABASE_URL,required"`
	RedisURL    string `env:"REDIS_URL,default=redis://localhost:6379/0"`
	JWTSecret   string `env:"JWT_SECRET,required"`
	LogLevel          string `env:"LOG_LEVEL,default=info"`
	BackupDir         string `env:"BACKUP_DIR,default=./backups"`
	OIDCProvidersPath string `env:"OIDC_PROVIDERS_PATH,default=config/oidc_providers.yaml"`
}

// Load reads configuration from environment variables.
func Load() (*Config, error) {
	var cfg Config
	if err := envconfig.Process(context.Background(), &cfg); err != nil {
		return nil, err
	}
	return &cfg, nil
}
