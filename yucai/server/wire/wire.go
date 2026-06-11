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
		// Infrastructure
		provideLogger,
		provideRedisClient,

		// Auth module
		provideAuthEntClient,
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

		// Account module
		provideAccountEntClient,
		provideAccountRepo,
		provideChartRepo,
		provideAccountService,
		provideAccountHandler,

		// Transaction module
		provideTransactionEntClient,
		provideTransactionRepo,
		provideBalanceUpdater,
		provideTransactionService,
		provideTransactionHandler,

		// Budget module
		provideBudgetEntClient,
		provideBudgetRepo,
		provideBudgetService,
		provideBudgetHandler,

		// Debt module
		provideDebtEntClient,
		provideDebtRepo,
		provideDebtService,
		provideDebtHandler,

		// Goal module
		provideGoalEntClient,
		provideGoalRepo,
		provideGoalService,
		provideGoalHandler,

		// Tag module
		provideTagEntClient,
		provideTagRepo,
		provideTagService,
		provideTagHandler,

		// Template module
		provideTemplateEntClient,
		provideTemplateRepo,
		provideTemplateService,
		provideTemplateHandler,

		// Holding module
		provideHoldingEntClient,
		provideSecurityRepo,
		provideHoldingRepo,
		provideTradeRepo,
		provideHoldingService,
		provideHoldingHandler,

		// gRPC server (must come after all handlers)
		provideGRPCServer,

		NewApp,
	)
	return nil, nil
}
