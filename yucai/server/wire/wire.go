//go:build wireinject
// +build wireinject

package wire

import (
	"github.com/google/wire"
	"github.com/yucai/server/pkg/config"
)

// InitializeApp wires all dependencies and returns a ready-to-run App.
func InitializeApp(cfg *config.Config) (*App, error) {
	wire.Build(
		provideLogger,
		provideRedisClient,
		provideEntClient,
		provideTokenService,
		provideTenantRepo,
		provideUserRepo,
		provideSessionStore,
		provideRegisterHandler,
		provideLoginHandler,
		provideRefreshHandler,
		provideProfileHandler,
		provideAuthService,
		provideAuthHandler,
		provideGRPCServer,
		NewApp,
	)
	return nil, nil
}
