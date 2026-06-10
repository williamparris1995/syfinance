package wire

import (
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/pkg/logger"
)

// App holds the wired application dependencies.
type App struct {
	Config      *config.Config
	Logger      *logger.Logger
	GRPCServer  *GRPCServer
	AuthHandler *authgrpc.AuthHandler
}

// NewApp creates the application with wired dependencies.
func NewApp(cfg *config.Config, log *logger.Logger, srv *GRPCServer, authHandler *authgrpc.AuthHandler) *App {
	return &App{Config: cfg, Logger: log, GRPCServer: srv, AuthHandler: authHandler}
}
