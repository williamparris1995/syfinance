//go:build wireinject
// +build wireinject

package wire

import (
	"github.com/google/wire"
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/pkg/logger"
)

// InitializeApp wires all dependencies and returns a ready-to-run App.
func InitializeApp(cfg *config.Config) (*App, error) {
	wire.Build(
		provideLogger,
		NewApp,
	)
	return nil, nil
}

func provideLogger(cfg *config.Config) *logger.Logger {
	logger.Setup(cfg.LogLevel)
	return &logger.Logger{}
}
