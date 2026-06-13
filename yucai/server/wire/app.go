package wire

import (
	accountgrpc "github.com/yucai/server/internal/account/adapter/driving/grpc"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	budgetgrpc "github.com/yucai/server/internal/budget/adapter/driving/grpc"
	debtgrpc "github.com/yucai/server/internal/debt/adapter/driving/grpc"
	goalgrpc "github.com/yucai/server/internal/goal/adapter/driving/grpc"
	taggrpc "github.com/yucai/server/internal/tag/adapter/driving/grpc"
	tmplgrpc "github.com/yucai/server/internal/template/adapter/driving/grpc"
	holdinggrpc "github.com/yucai/server/internal/holding/adapter/driving/grpc"
	backupgrpc "github.com/yucai/server/internal/backup/adapter/driving/grpc"
	syncgrpc "github.com/yucai/server/internal/sync/adapter/driving/grpc"
	categorygrpc "github.com/yucai/server/internal/category/adapter/driving/grpc"
	currencygrpc "github.com/yucai/server/internal/currency/adapter/driving/grpc"
	txngrpc "github.com/yucai/server/internal/transaction/adapter/driving/grpc"
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/pkg/logger"
)

// App holds the wired application dependencies.
type App struct {
	Config             *config.Config
	Logger             *logger.Logger
	GRPCServer         *GRPCServer
	AuthHandler        *authgrpc.AuthHandler
	AccountHandler     *accountgrpc.AccountHandler
	TransactionHandler *txngrpc.TransactionHandler
	BudgetHandler      *budgetgrpc.BudgetHandler
	DebtHandler        *debtgrpc.DebtHandler
	GoalHandler        *goalgrpc.GoalHandler
	TagHandler         *taggrpc.TagHandler
	TemplateHandler    *tmplgrpc.TemplateHandler
	HoldingHandler     *holdinggrpc.HoldingHandler
	BackupHandler      *backupgrpc.BackupHandler
	SyncHandler        *syncgrpc.SyncHandler
	CategoryHandler    *categorygrpc.CategoryHandler
	CurrencyHandler    *currencygrpc.CurrencyHandler
}

// NewApp creates the application with wired dependencies.
func NewApp(
	cfg *config.Config,
	log *logger.Logger,
	srv *GRPCServer,
	authHandler *authgrpc.AuthHandler,
	accountHandler *accountgrpc.AccountHandler,
	transactionHandler *txngrpc.TransactionHandler,
	budgetHandler *budgetgrpc.BudgetHandler,
	debtHandler *debtgrpc.DebtHandler,
	goalHandler *goalgrpc.GoalHandler,
	tagHandler *taggrpc.TagHandler,
	templateHandler *tmplgrpc.TemplateHandler,
	holdingHandler *holdinggrpc.HoldingHandler,
	backupHandler *backupgrpc.BackupHandler,
	syncHandler *syncgrpc.SyncHandler,
	categoryHandler *categorygrpc.CategoryHandler,
	currencyHandler *currencygrpc.CurrencyHandler,
) *App {
	return &App{
		Config:             cfg,
		Logger:             log,
		GRPCServer:         srv,
		AuthHandler:        authHandler,
		AccountHandler:     accountHandler,
		TransactionHandler: transactionHandler,
		BudgetHandler:      budgetHandler,
		DebtHandler:        debtHandler,
		GoalHandler:        goalHandler,
		TagHandler:         tagHandler,
		TemplateHandler:    templateHandler,
		HoldingHandler:     holdingHandler,
		BackupHandler:      backupHandler,
		SyncHandler:        syncHandler,
		CategoryHandler:    categoryHandler,
		CurrencyHandler:    currencyHandler,
	}
}
