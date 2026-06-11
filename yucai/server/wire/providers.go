package wire

import (
	"context"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountgrpc "github.com/yucai/server/internal/account/adapter/driving/grpc"
	accountapp "github.com/yucai/server/internal/account/application"
	accountent "github.com/yucai/server/internal/account/ent"
	budgetrepo "github.com/yucai/server/internal/budget/adapter/driven/repository"
	budgetgrpc "github.com/yucai/server/internal/budget/adapter/driving/grpc"
	budgetapp "github.com/yucai/server/internal/budget/application"
	budgetent "github.com/yucai/server/internal/budget/ent"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	debtgrpc "github.com/yucai/server/internal/debt/adapter/driving/grpc"
	debtapp "github.com/yucai/server/internal/debt/application"
	debtent "github.com/yucai/server/internal/debt/ent"
	goalrepo "github.com/yucai/server/internal/goal/adapter/driven/repository"
	goalgrpc "github.com/yucai/server/internal/goal/adapter/driving/grpc"
	goalapp "github.com/yucai/server/internal/goal/application"
	goalent "github.com/yucai/server/internal/goal/ent"
	tagrepo "github.com/yucai/server/internal/tag/adapter/driven/repository"
	taggrpc "github.com/yucai/server/internal/tag/adapter/driving/grpc"
	tagapp "github.com/yucai/server/internal/tag/application"
	tagent "github.com/yucai/server/internal/tag/ent"
	tmplrepo "github.com/yucai/server/internal/template/adapter/driven/repository"
	tmplgrpc "github.com/yucai/server/internal/template/adapter/driving/grpc"
	tmplapp "github.com/yucai/server/internal/template/application"
	tmplent "github.com/yucai/server/internal/template/ent"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	holdinggrpc "github.com/yucai/server/internal/holding/adapter/driving/grpc"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingent "github.com/yucai/server/internal/holding/ent"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txnbalance "github.com/yucai/server/internal/transaction/adapter/driven/balance"
	txngrpc "github.com/yucai/server/internal/transaction/adapter/driving/grpc"
	txnapp "github.com/yucai/server/internal/transaction/application"
	txnent "github.com/yucai/server/internal/transaction/ent"
	authrepo "github.com/yucai/server/internal/auth/adapter/driven/repository"
	"github.com/yucai/server/internal/auth/adapter/driven/session"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	authapp "github.com/yucai/server/internal/auth/application"
	authcmd "github.com/yucai/server/internal/auth/application/command"
	authquery "github.com/yucai/server/internal/auth/application/query"
	authent "github.com/yucai/server/internal/auth/ent"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/pkg/logger"
	"github.com/yucai/server/pkg/middleware"

	entsql "entgo.io/ent/dialect/sql"
	"google.golang.org/grpc"
)

// GRPCServer wraps *grpc.Server for Wire typing.
type GRPCServer struct {
	*grpc.Server
}

// ---- Provider Functions ----

func provideLogger(cfg *config.Config) *logger.Logger {
	logger.Setup(cfg.LogLevel)
	return &logger.Logger{}
}

func provideRedisClient(cfg *config.Config) *redis.Client {
	return redis.NewClient(&redis.Options{Addr: cfg.RedisURL})
}

func provideAuthEntClient(cfg *config.Config) (*authent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return authent.NewClient(authent.Driver(drv)), nil
}

func provideAccountEntClient(cfg *config.Config) (*accountent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return accountent.NewClient(accountent.Driver(drv)), nil
}

func provideTransactionEntClient(cfg *config.Config) (*txnent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return txnent.NewClient(txnent.Driver(drv)), nil
}

func provideTokenService(cfg *config.Config) *authjwt.TokenService {
	return authjwt.NewTokenService(cfg.JWTSecret)
}

// Auth providers
func provideTenantRepo(client *authent.Client) *authrepo.TenantRepository {
	return authrepo.NewTenantRepository(client)
}
func provideUserRepo(client *authent.Client) *authrepo.UserRepository {
	return authrepo.NewUserRepository(client)
}
func provideSessionStore(rdb *redis.Client) *session.RedisSessionStore {
	return session.NewRedisSessionStore(rdb)
}
func provideRegisterHandler(tr *authrepo.TenantRepository, ur *authrepo.UserRepository, ts *authjwt.TokenService) *authcmd.RegisterHandler {
	return authcmd.NewRegisterHandler(tr, ur, ts)
}
func provideLoginHandler(ur *authrepo.UserRepository, ts *authjwt.TokenService) *authcmd.LoginHandler {
	return authcmd.NewLoginHandler(ur, ts)
}
func provideRefreshHandler(ur *authrepo.UserRepository, ts *authjwt.TokenService, ss *session.RedisSessionStore) *authcmd.RefreshHandler {
	return authcmd.NewRefreshHandler(ur, ts, ss)
}
func provideProfileHandler(ur *authrepo.UserRepository) *authquery.GetProfileHandler {
	return authquery.NewGetProfileHandler(ur)
}
func provideAuthService(tr *authrepo.TenantRepository, ur *authrepo.UserRepository, ts *authjwt.TokenService, rh *authcmd.RegisterHandler, lh *authcmd.LoginHandler, fh *authcmd.RefreshHandler, ph *authquery.GetProfileHandler) *authapp.Service {
	return authapp.NewService(tr, ur, ts, rh, lh, fh, ph)
}
func provideAuthHandler(svc *authapp.Service) *authgrpc.AuthHandler {
	return authgrpc.NewAuthHandler(svc)
}

// Account providers
func provideAccountRepo(client *accountent.Client) *accountrepo.AccountRepository {
	return accountrepo.NewAccountRepository(client)
}
func provideChartRepo(client *accountent.Client) *accountrepo.ChartRepository {
	return accountrepo.NewChartRepository(client)
}
func provideAccountService(ar *accountrepo.AccountRepository, cr *accountrepo.ChartRepository) *accountapp.Service {
	return accountapp.NewService(ar, cr)
}
func provideAccountHandler(svc *accountapp.Service) *accountgrpc.AccountHandler {
	return accountgrpc.NewAccountHandler(svc)
}

// Transaction providers
func provideTransactionRepo(client *txnent.Client) *txnrepo.TransactionRepository {
	return txnrepo.NewTransactionRepository(client)
}
func provideBalanceUpdater(ar *accountrepo.AccountRepository) *txnbalance.BalanceUpdaterImpl {
	return txnbalance.NewBalanceUpdater(ar)
}
func provideTransactionService(tr *txnrepo.TransactionRepository, bu *txnbalance.BalanceUpdaterImpl) *txnapp.Service {
	return txnapp.NewService(tr, bu)
}
func provideTransactionHandler(svc *txnapp.Service) *txngrpc.TransactionHandler {
	return txngrpc.NewTransactionHandler(svc)
}

// Budget providers
func provideBudgetEntClient(cfg *config.Config) (*budgetent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return budgetent.NewClient(budgetent.Driver(drv)), nil
}
func provideBudgetRepo(client *budgetent.Client) *budgetrepo.BudgetRepository {
	return budgetrepo.NewBudgetRepository(client)
}
func provideBudgetService(repo *budgetrepo.BudgetRepository) *budgetapp.Service {
	return budgetapp.NewService(repo, nil) // entryFunc nil for now, actuals computed via integration
}
func provideBudgetHandler(svc *budgetapp.Service) *budgetgrpc.BudgetHandler {
	return budgetgrpc.NewBudgetHandler(svc)
}

// Debt providers
func provideDebtEntClient(cfg *config.Config) (*debtent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return debtent.NewClient(debtent.Driver(drv)), nil
}
func provideDebtRepo(client *debtent.Client) *debtrepo.DebtRepository {
	return debtrepo.NewDebtRepository(client)
}
func provideDebtService(repo *debtrepo.DebtRepository) *debtapp.Service {
	return debtapp.NewService(repo)
}
func provideDebtHandler(svc *debtapp.Service) *debtgrpc.DebtHandler {
	return debtgrpc.NewDebtHandler(svc)
}

// Goal providers
func provideGoalEntClient(cfg *config.Config) (*goalent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return goalent.NewClient(goalent.Driver(drv)), nil
}
func provideGoalRepo(client *goalent.Client) *goalrepo.GoalRepository {
	return goalrepo.NewGoalRepository(client)
}
func provideGoalService(repo *goalrepo.GoalRepository) *goalapp.Service {
	return goalapp.NewService(repo)
}
func provideGoalHandler(svc *goalapp.Service) *goalgrpc.GoalHandler {
	return goalgrpc.NewGoalHandler(svc)
}

// Tag providers
func provideTagEntClient(cfg *config.Config) (*tagent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return tagent.NewClient(tagent.Driver(drv)), nil
}
func provideTagRepo(client *tagent.Client) *tagrepo.TagRepository {
	return tagrepo.NewTagRepository(client)
}
func provideTagService(repo *tagrepo.TagRepository) *tagapp.Service {
	return tagapp.NewService(repo)
}
func provideTagHandler(svc *tagapp.Service) *taggrpc.TagHandler {
	return taggrpc.NewTagHandler(svc)
}

// Template providers
func provideTemplateEntClient(cfg *config.Config) (*tmplent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return tmplent.NewClient(tmplent.Driver(drv)), nil
}
func provideTemplateRepo(client *tmplent.Client) *tmplrepo.TemplateRepository {
	return tmplrepo.NewTemplateRepository(client)
}
func provideTemplateService(repo *tmplrepo.TemplateRepository) *tmplapp.Service {
	return tmplapp.NewService(repo)
}
func provideTemplateHandler(svc *tmplapp.Service) *tmplgrpc.TemplateHandler {
	return tmplgrpc.NewTemplateHandler(svc)
}

// Holding providers
func provideHoldingEntClient(cfg *config.Config) (*holdingent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return holdingent.NewClient(holdingent.Driver(drv)), nil
}
func provideSecurityRepo(client *holdingent.Client) *holdingsec.SecurityRepository {
	return holdingsec.NewSecurityRepository(client)
}
func provideHoldingRepo(client *holdingent.Client) *holdingsec.HoldingRepository {
	return holdingsec.NewHoldingRepository(client)
}
func provideTradeRepo(client *holdingent.Client) *holdingsec.TradeRepository {
	return holdingsec.NewTradeRepository(client)
}
func provideHoldingService(secRepo *holdingsec.SecurityRepository, hRepo *holdingsec.HoldingRepository, tRepo *holdingsec.TradeRepository) *holdingapp.Service {
	return holdingapp.NewService(secRepo, hRepo, tRepo)
}
func provideHoldingHandler(svc *holdingapp.Service) *holdinggrpc.HoldingHandler {
	return holdinggrpc.NewHoldingHandler(svc)
}

func provideGRPCServer(ts *authjwt.TokenService) *GRPCServer {
	middleware.TokenService = ts
	srv := grpc.NewServer(grpc.UnaryInterceptor(middleware.AuthInterceptor))
	return &GRPCServer{Server: srv}
}

var (
	_ = uuid.New
	_ = context.Background
)
