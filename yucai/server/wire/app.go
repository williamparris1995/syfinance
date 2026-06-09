package wire

import (
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/pkg/logger"
)

// App holds the wired application dependencies.
type App struct {
	Config *config.Config
	Logger *logger.Logger
}

// NewApp creates the application with wired dependencies.
func NewApp(cfg *config.Config, log *logger.Logger) *App {
	return &App{Config: cfg, Logger: log}
}
