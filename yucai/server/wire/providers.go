package wire

import (
	"context"
	"fmt"

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
	backuprepo "github.com/yucai/server/internal/backup/adapter/driven/repository"
	backupcloud "github.com/yucai/server/internal/backup/adapter/driven/cloud"
	backupgrpc "github.com/yucai/server/internal/backup/adapter/driving/grpc"
	backupapp "github.com/yucai/server/internal/backup/application"
	backupent "github.com/yucai/server/internal/backup/ent"
	"github.com/yucai/server/internal/backup/domain"
	syncrepo "github.com/yucai/server/internal/sync/adapter/driven/repository"
	syncgrpc "github.com/yucai/server/internal/sync/adapter/driving/grpc"
	syncapp "github.com/yucai/server/internal/sync/application"
	syncent "github.com/yucai/server/internal/sync/ent"
	categoryrepo "github.com/yucai/server/internal/category/adapter/driven/repository"
	categorygrpc "github.com/yucai/server/internal/category/adapter/driving/grpc"
	categoryapp "github.com/yucai/server/internal/category/application"
	categoryent "github.com/yucai/server/internal/category/ent"
	currencyrepo "github.com/yucai/server/internal/currency/adapter/driven/repository"
	"github.com/yucai/server/internal/currency/adapter/driven/exchangerate"
	currencygrpc "github.com/yucai/server/internal/currency/adapter/driving/grpc"
	currencyapp "github.com/yucai/server/internal/currency/application"
	currencyent "github.com/yucai/server/internal/currency/ent"
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
	"entgo.io/ent/dialect"
	"database/sql"
	"google.golang.org/grpc"
)

// GRPCServer wraps *grpc.Server for Wire typing.
type GRPCServer struct {
	*grpc.Server
}

// openEntDriver opens a pgx-backed *sql.DB and wraps it as an ent driver with
// the "postgres" dialect (ent migrate needs the postgres dialect; the underlying
// database/sql driver name is "pgx" via github.com/jackc/pgx/v5/stdlib).
func openEntDriver(cfg *config.Config) (*entsql.Driver, error) {
	db, err := sql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return entsql.OpenDB(dialect.Postgres, db), nil
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
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := authent.NewClient(authent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate auth schema: %w", err)
	}
	return client, nil
}

func provideAccountEntClient(cfg *config.Config) (*accountent.Client, error) {
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := accountent.NewClient(accountent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate account schema: %w", err)
	}
	return client, nil
}

func provideTransactionEntClient(cfg *config.Config) (*txnent.Client, error) {
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := txnent.NewClient(txnent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate transaction schema: %w", err)
	}
	return client, nil
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
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := budgetent.NewClient(budgetent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate budget schema: %w", err)
	}
	return client, nil
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
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := debtent.NewClient(debtent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate debt schema: %w", err)
	}
	return client, nil
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
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := goalent.NewClient(goalent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate goal schema: %w", err)
	}
	return client, nil
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
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := tagent.NewClient(tagent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate tag schema: %w", err)
	}
	return client, nil
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
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := tmplent.NewClient(tmplent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate template schema: %w", err)
	}
	return client, nil
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
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := holdingent.NewClient(holdingent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate holding schema: %w", err)
	}
	return client, nil
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

// Backup providers
func provideBackupEntClient(cfg *config.Config) (*backupent.Client, error) {
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := backupent.NewClient(backupent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate backup schema: %w", err)
	}
	return client, nil
}
func provideBackupRepo(client *backupent.Client) *backuprepo.BackupRepository {
	return backuprepo.NewBackupRepository(client)
}
func provideLocalCloudProvider(cfg *config.Config) *backupcloud.LocalProvider {
	return backupcloud.NewLocalProvider(cfg.BackupDir)
}
func provideBackupService(repo *backuprepo.BackupRepository, localProvider *backupcloud.LocalProvider) *backupapp.Service {
	cloudProviders := map[domain.BackupProvider]backupapp.CloudProvider{
		domain.BackupProviderLocal: localProvider,
	}
	return backupapp.NewService(repo, cloudProviders)
}
func provideBackupHandler(svc *backupapp.Service) *backupgrpc.BackupHandler {
	return backupgrpc.NewBackupHandler(svc)
}

// Sync providers
func provideSyncEntClient(cfg *config.Config) (*syncent.Client, error) {
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := syncent.NewClient(syncent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate sync schema: %w", err)
	}
	return client, nil
}
func provideSyncLogRepo(client *syncent.Client) *syncrepo.SyncLogRepository {
	return syncrepo.NewSyncLogRepository(client)
}
func provideSyncDeviceRepo(client *syncent.Client) *syncrepo.SyncDeviceRepository {
	return syncrepo.NewSyncDeviceRepository(client)
}
func provideSyncConflictRepo(client *syncent.Client) *syncrepo.SyncConflictRepository {
	return syncrepo.NewSyncConflictRepository(client)
}
func provideConflictResolver() *syncapp.ConflictResolver {
	return syncapp.NewConflictResolver()
}
func provideSyncService(
	logRepo *syncrepo.SyncLogRepository,
	deviceRepo *syncrepo.SyncDeviceRepository,
	conflictRepo *syncrepo.SyncConflictRepository,
	resolver *syncapp.ConflictResolver,
) *syncapp.Service {
	return syncapp.NewService(logRepo, deviceRepo, conflictRepo, resolver)
}
func provideSyncHandler(svc *syncapp.Service) *syncgrpc.SyncHandler {
	return syncgrpc.NewSyncHandler(svc)
}

// Category providers
func provideCategoryEntClient(cfg *config.Config) (*categoryent.Client, error) {
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := categoryent.NewClient(categoryent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate category schema: %w", err)
	}
	return client, nil
}
func provideCategoryRepo(client *categoryent.Client) *categoryrepo.CategoryRepository {
	return categoryrepo.NewCategoryRepository(client)
}
func provideCategoryService(repo *categoryrepo.CategoryRepository) *categoryapp.Service {
	return categoryapp.NewService(repo)
}
func provideCategoryHandler(svc *categoryapp.Service) *categorygrpc.CategoryHandler {
	return categorygrpc.NewCategoryHandler(svc)
}

// Currency providers
func provideCurrencyEntClient(cfg *config.Config) (*currencyent.Client, error) {
	drv, err := openEntDriver(cfg)
	if err != nil {
		return nil, err
	}
	client := currencyent.NewClient(currencyent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		return nil, fmt.Errorf("migrate currency schema: %w", err)
	}
	return client, nil
}
func provideCurrencyRepo(client *currencyent.Client) *currencyrepo.CurrencyRepository {
	return currencyrepo.NewCurrencyRepository(client)
}
func provideExchangeRateProvider() *exchangerate.MockProvider {
	return exchangerate.NewMockProvider()
}
func provideCurrencyService(repo *currencyrepo.CurrencyRepository, provider *exchangerate.MockProvider) *currencyapp.Service {
	return currencyapp.NewService(repo, provider)
}
func provideCurrencyHandler(svc *currencyapp.Service) *currencygrpc.CurrencyHandler {
	return currencygrpc.NewCurrencyHandler(svc)
}

func provideGRPCServer(ts *authjwt.TokenService) *GRPCServer {
	middleware.TokenService = ts
	// Logging is OUTERMOST (logs even auth-rejected calls), auth is inner.
	srv := grpc.NewServer(grpc.ChainUnaryInterceptor(
		middleware.UnaryLoggingInterceptor,
		middleware.AuthInterceptor,
	))
	return &GRPCServer{Server: srv}
}

var (
	_ = uuid.New
	_ = context.Background
)
