package wire

import (
	accountapp "github.com/yucai/server/internal/account/application"
	accountgrpc "github.com/yucai/server/internal/account/adapter/driving/grpc"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	authrepo "github.com/yucai/server/internal/auth/adapter/driven/repository"
	budgetgrpc "github.com/yucai/server/internal/budget/adapter/driving/grpc"
	debtgrpc "github.com/yucai/server/internal/debt/adapter/driving/grpc"
	goalgrpc "github.com/yucai/server/internal/goal/adapter/driving/grpc"
	taggrpc "github.com/yucai/server/internal/tag/adapter/driving/grpc"
	tmplgrpc "github.com/yucai/server/internal/template/adapter/driving/grpc"
	holdinggrpc "github.com/yucai/server/internal/holding/adapter/driving/grpc"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingscheduler "github.com/yucai/server/internal/holding/scheduler"
	backupgrpc "github.com/yucai/server/internal/backup/adapter/driving/grpc"
	syncgrpc "github.com/yucai/server/internal/sync/adapter/driving/grpc"
	currencygrpc "github.com/yucai/server/internal/currency/adapter/driving/grpc"
	currencyapp "github.com/yucai/server/internal/currency/application"
	"github.com/yucai/server/internal/currency/scheduler"
	txngrpc "github.com/yucai/server/internal/transaction/adapter/driving/grpc"
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/pkg/logger"
)

// App holds the wired application dependencies.
type App struct {
	Config             *config.Config
	Logger             *logger.Logger
	GRPCServer         *GRPCServer
	TenantRepo         *authrepo.TenantRepository
	UserRepo           *authrepo.UserRepository
	AccountService     *accountapp.Service
	AuthHandler        *authgrpc.AuthHandler
	AccountHandler     *accountgrpc.AccountHandler
	TransactionHandler *txngrpc.TransactionHandler
	BudgetHandler      *budgetgrpc.BudgetHandler
	DebtHandler        *debtgrpc.DebtHandler
	GoalHandler        *goalgrpc.GoalHandler
	TagHandler         *taggrpc.TagHandler
	TemplateHandler    *tmplgrpc.TemplateHandler
	HoldingHandler     *holdinggrpc.HoldingHandler
	HoldingService     *holdingapp.Service
	BackupHandler      *backupgrpc.BackupHandler
	SyncHandler        *syncgrpc.SyncHandler
	CurrencyHandler    *currencygrpc.CurrencyHandler
	CurrencyScheduler  *scheduler.Scheduler
	CurrencyService    *currencyapp.Service
	HoldingScheduler   *holdingscheduler.Scheduler
}

// NewApp creates the application with wired dependencies.
func NewApp(
	cfg *config.Config,
	log *logger.Logger,
	srv *GRPCServer,
	tenantRepo *authrepo.TenantRepository,
	userRepo *authrepo.UserRepository,
	accountService *accountapp.Service,
	authHandler *authgrpc.AuthHandler,
	accountHandler *accountgrpc.AccountHandler,
	transactionHandler *txngrpc.TransactionHandler,
	budgetHandler *budgetgrpc.BudgetHandler,
	debtHandler *debtgrpc.DebtHandler,
	goalHandler *goalgrpc.GoalHandler,
	tagHandler *taggrpc.TagHandler,
	templateHandler *tmplgrpc.TemplateHandler,
	holdingHandler *holdinggrpc.HoldingHandler,
	holdingService *holdingapp.Service,
	backupHandler *backupgrpc.BackupHandler,
	syncHandler *syncgrpc.SyncHandler,
	currencyHandler *currencygrpc.CurrencyHandler,
	currencyScheduler *scheduler.Scheduler,
	currencyService *currencyapp.Service,
	holdingScheduler *holdingscheduler.Scheduler,
) *App {
	return &App{
		Config:             cfg,
		Logger:             log,
		GRPCServer:         srv,
		TenantRepo:         tenantRepo,
		UserRepo:           userRepo,
		AccountService:     accountService,
		AuthHandler:        authHandler,
		AccountHandler:     accountHandler,
		TransactionHandler: transactionHandler,
		BudgetHandler:      budgetHandler,
		DebtHandler:        debtHandler,
		GoalHandler:        goalHandler,
		TagHandler:         tagHandler,
		TemplateHandler:    templateHandler,
		HoldingHandler:     holdingHandler,
		HoldingService:     holdingService,
		BackupHandler:      backupHandler,
		SyncHandler:        syncHandler,
		CurrencyHandler:    currencyHandler,
		CurrencyScheduler:  currencyScheduler,
		CurrencyService:    currencyService,
		HoldingScheduler:   holdingScheduler,
	}
}
