package wire

import "github.com/yucai/server/pkg/config"

// App holds the wired application dependencies.
type App struct {
	Config *config.Config
}

// NewApp creates the application with wired dependencies.
func NewApp(cfg *config.Config) *App {
	return &App{Config: cfg}
}
