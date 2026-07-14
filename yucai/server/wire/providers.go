package wire

import (
	"context"
	"fmt"
	"log/slog"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	accountrepo "github.com/yucai/server/internal/account/adapter/driven/repository"
	accountgrpc "github.com/yucai/server/internal/account/adapter/driving/grpc"
	accountapp "github.com/yucai/server/internal/account/application"
	accountent "github.com/yucai/server/internal/account/ent"
	authrepo "github.com/yucai/server/internal/auth/adapter/driven/repository"
	"github.com/yucai/server/internal/auth/adapter/driven/session"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	authapp "github.com/yucai/server/internal/auth/application"
	authcmd "github.com/yucai/server/internal/auth/application/command"
	authdomain "github.com/yucai/server/internal/auth/domain"
	authquery "github.com/yucai/server/internal/auth/application/query"
	authent "github.com/yucai/server/internal/auth/ent"
	authjwt "github.com/yucai/server/internal/auth/infrastructure/jwt"
	backupcloud "github.com/yucai/server/internal/backup/adapter/driven/cloud"
	"github.com/yucai/server/internal/backup/adapter/driven/exporter"
	backuprepo "github.com/yucai/server/internal/backup/adapter/driven/repository"
	backupgrpc "github.com/yucai/server/internal/backup/adapter/driving/grpc"
	backupapp "github.com/yucai/server/internal/backup/application"
	"github.com/yucai/server/internal/backup/domain"
	backupent "github.com/yucai/server/internal/backup/ent"
	budgetrepo "github.com/yucai/server/internal/budget/adapter/driven/repository"
	budgetgrpc "github.com/yucai/server/internal/budget/adapter/driving/grpc"
	budgetapp "github.com/yucai/server/internal/budget/application"
	budgetent "github.com/yucai/server/internal/budget/ent"
	"github.com/yucai/server/internal/currency/adapter/driven/exchangerate"
	currencyrepo "github.com/yucai/server/internal/currency/adapter/driven/repository"
	currencygrpc "github.com/yucai/server/internal/currency/adapter/driving/grpc"
	currencyapp "github.com/yucai/server/internal/currency/application"
	currencydomain "github.com/yucai/server/internal/currency/domain"
	currencyent "github.com/yucai/server/internal/currency/ent"
	"github.com/yucai/server/internal/currency/scheduler"
	networthgrpc "github.com/yucai/server/internal/networth/adapter/driving/grpc"
	networthapp "github.com/yucai/server/internal/networth/application"
	debtrepo "github.com/yucai/server/internal/debt/adapter/driven/repository"
	debtgrpc "github.com/yucai/server/internal/debt/adapter/driving/grpc"
	debtapp "github.com/yucai/server/internal/debt/application"
	debtdomain "github.com/yucai/server/internal/debt/domain"
	debtscheduler "github.com/yucai/server/internal/debt/scheduler"
	debtent "github.com/yucai/server/internal/debt/ent"
	goalrepo "github.com/yucai/server/internal/goal/adapter/driven/repository"
	goalgrpc "github.com/yucai/server/internal/goal/adapter/driving/grpc"
	goalapp "github.com/yucai/server/internal/goal/application"
	goaldomain "github.com/yucai/server/internal/goal/domain"
	goalent "github.com/yucai/server/internal/goal/ent"
	goalscheduler "github.com/yucai/server/internal/goal/scheduler"
	holdingsec "github.com/yucai/server/internal/holding/adapter/driven/repository"
	priceprovider "github.com/yucai/server/internal/holding/adapter/driven/priceprovider"
	holdinggrpc "github.com/yucai/server/internal/holding/adapter/driving/grpc"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingdomain "github.com/yucai/server/internal/holding/domain"
	holdingent "github.com/yucai/server/internal/holding/ent"
	holdingscheduler "github.com/yucai/server/internal/holding/scheduler"
	syncrepo "github.com/yucai/server/internal/sync/adapter/driven/repository"
	syncgrpc "github.com/yucai/server/internal/sync/adapter/driving/grpc"
	syncapp "github.com/yucai/server/internal/sync/application"
	syncent "github.com/yucai/server/internal/sync/ent"
	tagrepo "github.com/yucai/server/internal/tag/adapter/driven/repository"
	taggrpc "github.com/yucai/server/internal/tag/adapter/driving/grpc"
	tagapp "github.com/yucai/server/internal/tag/application"
	tagent "github.com/yucai/server/internal/tag/ent"
	tmplrepo "github.com/yucai/server/internal/template/adapter/driven/repository"
	tmplgrpc "github.com/yucai/server/internal/template/adapter/driving/grpc"
	tmplapp "github.com/yucai/server/internal/template/application"
	tmplent "github.com/yucai/server/internal/template/ent"
	txnbalance "github.com/yucai/server/internal/transaction/adapter/driven/balance"
	txnrepo "github.com/yucai/server/internal/transaction/adapter/driven/repository"
	txngrpc "github.com/yucai/server/internal/transaction/adapter/driving/grpc"
	txnapp "github.com/yucai/server/internal/transaction/application"
	txnent "github.com/yucai/server/internal/transaction/ent"
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/pkg/logger"
	"github.com/yucai/server/pkg/middleware"

	"database/sql"
	"time"
	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
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

func provideRedisClient(cfg *config.Config) (*redis.Client, error) {
	opts, err := redis.ParseURL(cfg.RedisURL)
	if err != nil {
		return nil, fmt.Errorf("parse redis url: %w", err)
	}
	return redis.NewClient(opts), nil
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
func provideRegisterHandler(tr *authrepo.TenantRepository, ur *authrepo.UserRepository, ts *authjwt.TokenService, seeder authcmd.PresetSeeder) *authcmd.RegisterHandler {
	return authcmd.NewRegisterHandler(tr, ur, ts, seeder)
}

// accountPresetSeeder adapts the account application Service to the auth
// command.PresetSeeder port. Lives in wire to avoid auth importing account.
type accountPresetSeeder struct {
	svc *accountapp.Service
}

func (a accountPresetSeeder) SeedTenantPresets(ctx context.Context, tenantID uuid.UUID) error {
	return a.svc.SeedPresetCategories(ctx, tenantID)
}

func providePresetSeeder(svc *accountapp.Service) authcmd.PresetSeeder {
	return accountPresetSeeder{svc: svc}
}
func provideLoginHandler(ur *authrepo.UserRepository, ts *authjwt.TokenService) *authcmd.LoginHandler {
	return authcmd.NewLoginHandler(ur, ts)
}
func provideRefreshHandler(ss *session.RedisSessionStore) *authcmd.RefreshHandler {
	return authcmd.NewRefreshHandler(ss)
}
func provideProfileHandler(ur *authrepo.UserRepository) *authquery.GetProfileHandler {
	return authquery.NewGetProfileHandler(ur)
}
func provideAuthService(tr *authrepo.TenantRepository, ur *authrepo.UserRepository, ts *authjwt.TokenService, ss *session.RedisSessionStore, rh *authcmd.RegisterHandler, lh *authcmd.LoginHandler, fh *authcmd.RefreshHandler, ph *authquery.GetProfileHandler, checker authdomain.CurrencyCodeChecker) *authapp.Service {
	return authapp.NewService(tr, ur, ts, ss, rh, lh, fh, ph, checker)
}

// currencyCodeChecker adapts the currency CurrencyRepository to the auth
// domain.CurrencyCodeChecker port. Lives in wire so auth never imports
// currency (mirrors the accountPresetSeeder pattern above).
type currencyCodeChecker struct {
	repo *currencyrepo.CurrencyRepository
}

func (c currencyCodeChecker) FindByCode(ctx context.Context, code string) (bool, error) {
	_, err := c.repo.FindByCode(ctx, code)
	if err == nil {
		return true, nil
	}
	// ent returns a NotFound error for missing rows; the repo wraps it via %w
	// so IsNotFound still matches through the error chain. Only NotFound means
	// "code not in catalog" — any other (DB) error must propagate so the auth
	// service can surface it as Internal rather than InvalidArgument.
	if currencyent.IsNotFound(err) {
		return false, nil
	}
	return false, fmt.Errorf("check currency code: %w", err)
}

func provideCurrencyCodeChecker(repo *currencyrepo.CurrencyRepository) authdomain.CurrencyCodeChecker {
	return currencyCodeChecker{repo: repo}
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
func provideTransactionRepo(client *txnent.Client, db *sql.DB) *txnrepo.TransactionRepository {
	// Production uses the "postgres" ent dialect (see openEntDriver). The repo's
	// raw TransactionSummary SQL needs to know the dialect to pick the correct
	// placeholder style ($N) and date extraction (timestamptz → text cast).
	return txnrepo.NewTransactionRepository(client, db).SetDialect(txnrepo.DialectPostgres)
}

// provideTransactionDB opens the *sql.DB backing the transaction ent client.
// It is the same physical database as the ent client (same DSN via openEntDriver),
// used by the repo's TransactionSummary raw aggregation query (which cannot be
// expressed through ent without cross-module edges). Wire injects this into the
// repo alongside the ent client.
func provideTransactionDB(cfg *config.Config) (*sql.DB, error) {
	db, err := sql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, fmt.Errorf("open transaction db: %w", err)
	}
	return db, nil
}
func provideBalanceUpdater(ar *accountrepo.AccountRepository) *txnbalance.BalanceUpdaterImpl {
	return txnbalance.NewBalanceUpdater(ar)
}
func provideTransactionService(tr *txnrepo.TransactionRepository, ar *accountrepo.AccountRepository, bu *txnbalance.BalanceUpdaterImpl) *txnapp.Service {
	return txnapp.NewService(tr, ar, bu)
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
// provideBudgetService wires budget's entryFunc to the real transaction
// spending totals. budget application does NOT import transaction (function-
// injection port pattern, mirroring D-currency's networth and D-goal's
// AccountMarketValueSource); wire injects a closure that delegates to
// txnSvc.SpendingByAccount. Before Task 4 entryFunc was nil, so actuals read 0.
func provideBudgetService(repo *budgetrepo.BudgetRepository, txnSvc *txnapp.Service) *budgetapp.Service {
	return budgetapp.NewService(repo, func(ctx context.Context, accountID uuid.UUID, from, to time.Time) (int64, int64, error) {
		return txnSvc.SpendingByAccount(ctx, accountID, from, to)
	})
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
// provideDebtSnapshotRepo builds the debt progress-snapshot repository used by
// GetReceivablesSummary (trend) and the DebtScheduler (SyncAllDebts writes).
// Returns the domain interface (not the concrete repo) so the application
// service depends on the port, not the ent adapter (mirrors holding's
// snapshot-repo split — see Task 4 repo).
func provideDebtSnapshotRepo(client *debtent.Client) debtdomain.DebtSnapshotRepository {
	return debtrepo.NewDebtSnapshotRepository(client)
}
// provideDebtService constructs the debt service and injects the account
// lookup used by SumRemainingByCurrency to resolve each debt's currency from
// its parent account (DebtDetails has no CurrencyCode field). Without this,
// every debt bucket defaults to CNY — D-currency Task 8 wire requirement.
// snapshotRepo is injected so GetReceivablesSummary can compute the
// month-over-month trend and SyncAllDebts can persist snapshots (Task 7).
// *accountrepo.AccountRepository structurally satisfies debtapp.AccountLookup
// (FindByID(ctx, tenantID, id) (*accountdomain.Account, error) — exact match).
func provideDebtService(repo *debtrepo.DebtRepository, accountRepo *accountrepo.AccountRepository, snapshotRepo debtdomain.DebtSnapshotRepository) *debtapp.Service {
	svc := debtapp.NewService(repo)
	svc.SetAccountLookup(accountRepo)
	svc.SetSnapshotRepo(snapshotRepo)
	return svc
}
func provideDebtHandler(svc *debtapp.Service, txnSvc *txnapp.Service, accountLookup txnapp.AccountLookup) *debtgrpc.DebtHandler {
	return debtgrpc.NewDebtHandler(svc, txnSvc, accountLookup)
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
// provideGoalService wires the three goal-progress source ports:
//   - mvSource (Investment goals): *holdingapp.Service structurally implements
//     AccountMarketValueSource.GetAccountsMarketValue.
//   - balSource (Savings goals): *accountapp.Service structurally implements
//     AccountBalanceSource.GetAccountsBalance.
//   - debtSource (DebtPayoff goals): *debtapp.Service structurally implements
//     DebtProgressSource.GetDebtsPaid.
//
// Each is injected via its setter (NewService signature unchanged). Task 6 wires
// all three; Task 8 owns this provider but the signature is final for wire_gen.
func provideGoalService(
	repo *goalrepo.GoalRepository,
	mvSource goaldomain.AccountMarketValueSource,
	balSource goaldomain.AccountBalanceSource,
	debtSource goaldomain.DebtProgressSource,
) *goalapp.Service {
	svc := goalapp.NewService(repo)
	svc.SetAccountMarketValueSource(mvSource)
	svc.SetAccountBalanceSource(balSource)
	svc.SetDebtProgressSource(debtSource)
	return svc
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
	// recorder is nil here for Task 4 (build green); Task 5 wires the real
	// TransactionRecorderAdapter via a provider + wire_gen hand-edit, mirroring
	// the backup server's nil→adapter two-step. CRUD is unaffected; only
	// RecordTransaction requires the recorder (it errors if nil).
	return tmplapp.NewService(repo, nil)
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
func provideHoldingService(
	secRepo *holdingsec.SecurityRepository,
	hRepo *holdingsec.HoldingRepository,
	tRepo *holdingsec.TradeRepository,
	priceRouter priceprovider.Router,
	lotRepo *holdingsec.LotRepository,
	snapshotRepo *holdingsec.SnapshotRepository,
	priceHistoryRepo *holdingsec.PriceHistoryRepository,
	historicalProvider priceprovider.HistoricalProvider,
	holdingRateRepo holdingdomain.RateHistoryRepository,
	tenantLister holdingdomain.TenantLister,
) *holdingapp.Service {
	svc := holdingapp.NewService(secRepo, hRepo, tRepo)
	svc.SetPriceRouter(priceRouter)        // wire 注入价格 router；nil 时 SyncPrices 会 error out
	svc.SetLotRepository(lotRepo)          // FIFO cost lots for realized P&L + cost basis
	svc.SetSnapshotRepository(snapshotRepo) // daily market-value snapshots
	svc.SetPriceHistoryRepository(priceHistoryRepo)
	svc.SetHistoricalProvider(historicalProvider) // Sina K-line for BackfillPriceHistory
	svc.SetRateHistoryRepository(holdingRateRepo) // currency→holding adapter (slice→map)
	svc.SetTenantLister(tenantLister)             // cross-tenant fan-out for SnapshotAllHoldings
	return svc
}
func provideHoldingHandler(svc *holdingapp.Service, txnSvc *txnapp.Service, accountLookup txnapp.AccountLookup) *holdinggrpc.HoldingHandler {
	return holdinggrpc.NewHoldingHandler(svc, txnSvc, accountLookup)
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
func provideBackupService(repo *backuprepo.BackupRepository, localProvider *backupcloud.LocalProvider, ports []domain.TenantDataPort) *backupapp.Service {
	cloudProviders := map[domain.BackupProvider]backupapp.CloudProvider{
		domain.BackupProviderLocal: localProvider,
	}
	return backupapp.NewService(repo, cloudProviders, ports)
}

// provideBackupExporters 聚合各模块 TenantDataPort(Purge 顺序:依赖模块在前,account 最后;
// Service 内 orderedPortsForPurge/Import 再按 Name 排序,这里顺序仅声明)。
func provideBackupExporters(
	account *exporter.AccountExporter,
	transaction *exporter.TransactionExporter,
	debt *exporter.DebtExporter,
	budget *exporter.BudgetExporter,
	goal *exporter.GoalExporter,
	holding *exporter.HoldingExporter,
	template *exporter.TemplateExporter,
	tag *exporter.TagExporter,
) []domain.TenantDataPort {
	return []domain.TenantDataPort{account, transaction, debt, budget, goal, holding, template, tag}
}

func provideAccountExporter(repo *accountrepo.AccountRepository) *exporter.AccountExporter {
	return exporter.NewAccountExporter(repo)
}
func provideTransactionExporter(repo *txnrepo.TransactionRepository) *exporter.TransactionExporter {
	return exporter.NewTransactionExporter(repo)
}
func provideDebtExporter(repo *debtrepo.DebtRepository) *exporter.DebtExporter {
	return exporter.NewDebtExporter(repo)
}
func provideBudgetExporter(repo *budgetrepo.BudgetRepository) *exporter.BudgetExporter {
	return exporter.NewBudgetExporter(repo)
}
func provideGoalExporter(repo *goalrepo.GoalRepository) *exporter.GoalExporter {
	return exporter.NewGoalExporter(repo)
}
func provideHoldingExporter(repo *holdingsec.HoldingRepository, trades *holdingsec.TradeRepository) *exporter.HoldingExporter {
	return exporter.NewHoldingExporter(repo, trades)
}
func provideTemplateExporter(repo *tmplrepo.TemplateRepository) *exporter.TemplateExporter {
	return exporter.NewTemplateExporter(repo)
}
func provideTagExporter(repo *tagrepo.TagRepository) *exporter.TagExporter {
	return exporter.NewTagExporter(repo)
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
func provideExchangeRateProvider() exchangerate.Provider {
	return exchangerate.NewFrankfurterProvider()
}
func provideCurrencyService(repo *currencyrepo.CurrencyRepository, provider exchangerate.Provider, rateHistoryRepo *currencyrepo.RateHistoryRepository) *currencyapp.Service {
	svc := currencyapp.NewService(repo, provider)
	svc.SetRateHistoryRepository(rateHistoryRepo)
	return svc
}
func provideCurrencyHandler(svc *currencyapp.Service) *currencygrpc.CurrencyHandler {
	return currencygrpc.NewCurrencyHandler(svc)
}

// tenantIntervalSource adapts auth TenantRepository to scheduler.IntervalSource.
// It reports the minimum rate_sync_interval_hours across all tenants so the
// scheduler syncs often enough for the most-frequently-syncing tenant.
type tenantIntervalSource struct {
	tr *authrepo.TenantRepository
}

// MinIntervalHours returns the smallest tenant interval, or 8 if no tenants or
// on error (sensible default so rate sync still runs when the table is empty).
func (s tenantIntervalSource) MinIntervalHours(ctx context.Context) int {
	intervals, err := s.tr.FindAllIntervalHours(ctx)
	if err != nil || len(intervals) == 0 {
		return 8
	}
	min := intervals[0]
	for _, h := range intervals[1:] {
		if h < min {
			min = h
		}
	}
	if min <= 0 {
		return 8
	}
	return min
}

func provideIntervalSource(tr *authrepo.TenantRepository) scheduler.IntervalSource {
	return tenantIntervalSource{tr: tr}
}

// provideCurrencyScheduler builds the rate-sync scheduler. *currencyapp.Service
// implements scheduler.RateSyncer via its SyncRates method. tick is 1h in prod.
func provideCurrencyScheduler(svc *currencyapp.Service, src scheduler.IntervalSource) *scheduler.Scheduler {
	return scheduler.NewScheduler(svc, src, 1*time.Hour, nil)
}

// providePriceRouter builds the holding price-provider router: Sina (A-share)
// first, then the Stub fallback (non-covered types → keep old price).
func providePriceRouter() priceprovider.Router {
	return priceprovider.NewCompositeRouter(
		priceprovider.NewSinaProvider(),
		priceprovider.NewStubProvider(),
	)
}

// providePriceScheduler builds the price-sync scheduler. *holdingapp.Service
// implements holdingscheduler.PriceSyncer via its SyncPrices method. tick is 1h
// in prod; reuses the same IntervalSource as the currency scheduler (Go
// structural typing: tenantIntervalSource satisfies both scheduler.IntervalSource
// and holdingscheduler.IntervalSource, both declaring MinIntervalHours(ctx) int).
func providePriceScheduler(svc *holdingapp.Service, src holdingscheduler.IntervalSource) *holdingscheduler.Scheduler {
	return holdingscheduler.NewScheduler(svc, src, 1*time.Hour, nil)
}

// provideLotRepo builds the FIFO cost-lot repository. Used by the holding
// service for lot-aware realized-gain/loss and snapshot cost basis.
func provideLotRepo(client *holdingent.Client) *holdingsec.LotRepository {
	return holdingsec.NewLotRepository(client)
}

// provideSnapshotRepo builds the daily holding market-value snapshot repository.
func provideSnapshotRepo(client *holdingent.Client) *holdingsec.SnapshotRepository {
	return holdingsec.NewSnapshotRepository(client)
}

// providePriceHistoryRepo builds the daily security price-history repository,
// used by BackfillPriceHistory and portfolio-curve assembly.
func providePriceHistoryRepo(client *holdingent.Client) *holdingsec.PriceHistoryRepository {
	return holdingsec.NewPriceHistoryRepository(client)
}

// provideHistoricalProvider builds the daily K-line history provider as a
// HistoricalRouter: SinaProvider first (A-share SSE/SZSE + CSI300), then
// YahooProvider fallback (US/OTC/global non-A-share). Wire injects the router
// into the holding service; BackfillPriceHistory calls FetchHistory which the
// router routes. ErrNoSource from Sina falls through to Yahoo.
func provideHistoricalProvider() priceprovider.HistoricalProvider {
	return priceprovider.NewHistoricalRouter(
		priceprovider.NewSinaProvider(),
		priceprovider.NewYahooProvider(),
	)
}

// provideCurrencyRateHistoryRepo builds the currency rate-history repository.
// Injected into both the currency service (direct) and the holding
// holdingRateAdapter (adapted to a map-returning FindRange).
func provideCurrencyRateHistoryRepo(client *currencyent.Client) *currencyrepo.RateHistoryRepository {
	return currencyrepo.NewRateHistoryRepository(client)
}

// holdingRateAdapter adapts the currency RateHistoryRepository (FindRange returns
// a []domain.RateHistory slice) to the holding domain.RateHistoryRepository port
// (FindRange returns a date→rate map). Holding does not import currency, so the
// adapter lives in wire (mirrors the accountPresetSeeder / currencyCodeChecker
// cross-module pattern). FindRate is signature-compatible and passes through.
type holdingRateAdapter struct{ inner *currencyrepo.RateHistoryRepository }

func (a *holdingRateAdapter) FindRate(ctx context.Context, code string, date time.Time) (float64, error) {
	return a.inner.FindRate(ctx, code, date)
}

func (a *holdingRateAdapter) FindRange(ctx context.Context, code string, from, to time.Time) (map[time.Time]float64, error) {
	rows, err := a.inner.FindRange(ctx, code, from, to)
	if err != nil {
		return nil, err
	}
	m := make(map[time.Time]float64, len(rows))
	for _, r := range rows {
		m[r.RateDate] = r.ExchangeRate
	}
	return m, nil
}

// provideHoldingRateRepo wraps the currency rate-history repo in the slice→map
// adapter so it satisfies holding's domain.RateHistoryRepository.
func provideHoldingRateRepo(inner *currencyrepo.RateHistoryRepository) holdingdomain.RateHistoryRepository {
	return &holdingRateAdapter{inner: inner}
}

// provideSnapshotScheduler builds the daily holding-snapshot scheduler. The
// holding *application.Service implements scheduler.Snapshotter via
// SnapshotAllHoldings (cross-tenant fan-out). tick is 1h in prod.
func provideSnapshotScheduler(svc *holdingapp.Service, src holdingscheduler.IntervalSource) *holdingscheduler.SnapshotScheduler {
	return holdingscheduler.NewSnapshotScheduler(svc, src, 1*time.Hour, nil)
}

// provideGoalScheduler builds the goal progress scheduler. *goalapp.Service
// implements goalscheduler.GoalSyncer via SyncAllGoals (all goal types). The
// *authrepo.TenantRepository structurally satisfies goalscheduler.TenantLister
// (FindAllIDs, C Task 7). For IntervalSource the repo is wrapped in
// tenantIntervalSource (FindAllIntervalHours → MinIntervalHours), reusing the
// same adapter as the currency/price/snapshot schedulers. tick is 1h in prod.
func provideGoalScheduler(svc *goalapp.Service, tenantRepo *authrepo.TenantRepository) *goalscheduler.Scheduler {
	src := tenantIntervalSource{tr: tenantRepo}
	return goalscheduler.NewScheduler(svc, tenantRepo, src, 1*time.Hour, nil)
}

// provideDebtScheduler builds the debt snapshot-sync scheduler (Task 6/7).
// *debtapp.Service implements debtscheduler.DebtSyncer via its SyncAllDebts
// method (Σ remaining/paid per debt → debt_progress_snapshot). The
// *authrepo.TenantRepository structurally satisfies debtscheduler.TenantLister
// (FindAllIDs). For IntervalSource the repo is wrapped in tenantIntervalSource
// (FindAllIntervalHours → MinIntervalHours), reusing the same adapter as the
// currency/price/snapshot/goal schedulers. tick is 1h in prod.
func provideDebtScheduler(svc *debtapp.Service, tenantRepo *authrepo.TenantRepository) *debtscheduler.Scheduler {
	src := tenantIntervalSource{tr: tenantRepo}
	return debtscheduler.NewScheduler(svc, tenantRepo, src, 1*time.Hour, nil)
}

// Networth providers
//
// provideNetWorthService wires the three source ports (account/holding/debt
// application Services — each structurally implements the corresponding networth
// domain port via its Sum*ByCurrency method, D-currency Task 5) plus the
// currency RateHistoryRepository (CNY-base rates for cross-currency conversion).
// *currencyrepo.RateHistoryRepository structurally satisfies
// currencydomain.RateHistoryRepository (FindRate/FindRange/Save — exact match),
// so no adapter is needed (unlike holding, which needs the slice→map adapter).
// log is passed as nil: networth application.Service falls back to slog.Default()
// (already configured by provideLogger via logger.Setup at the top of InitializeApp).
func provideNetWorthService(
	accountSvc *accountapp.Service,
	holdingSvc *holdingapp.Service,
	debtSvc *debtapp.Service,
	rateRepo currencydomain.RateHistoryRepository,
	log *slog.Logger,
) *networthapp.Service {
	return networthapp.NewService(accountSvc, holdingSvc, debtSvc, rateRepo, log)
}

// provideNetWorthHandler wraps the networth application Service in its gRPC
// adapter. Registered on the gRPC server in main.go via
// pb.RegisterNetWorthServiceServer (D-currency Task 6).
func provideNetWorthHandler(svc *networthapp.Service) *networthgrpc.NetWorthHandler {
	return networthgrpc.NewNetWorthHandler(svc)
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
