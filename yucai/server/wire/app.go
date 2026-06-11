package wire

import (
	accountgrpc "github.com/yucai/server/internal/account/adapter/driving/grpc"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	budgetgrpc "github.com/yucai/server/internal/budget/adapter/driving/grpc"
	debtgrpc "github.com/yucai/server/internal/debt/adapter/driving/grpc"
	goalgrpc "github.com/yucai/server/internal/goal/adapter/driving/grpc"
	taggrpc "github.com/yucai/server/internal/tag/adapter/driving/grpc"
	tmplgrpc "github.com/yucai/server/internal/template/adapter/driving/grpc"
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
	}
}
