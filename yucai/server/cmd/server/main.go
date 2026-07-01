package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"

	_ "github.com/jackc/pgx/v5/stdlib" // register "pgx" database/sql driver

	authpb "github.com/yucai/server/internal/proto/auth/v1"
	accountapp "github.com/yucai/server/internal/account/application"
	accountdomain "github.com/yucai/server/internal/account/domain"
	authrepo "github.com/yucai/server/internal/auth/adapter/driven/repository"
	authdomain "github.com/yucai/server/internal/auth/domain"
	authpassword "github.com/yucai/server/internal/auth/infrastructure/password"
	accountpb "github.com/yucai/server/internal/proto/account/v1"
	transactionpb "github.com/yucai/server/internal/proto/transaction/v1"
	budgetpb "github.com/yucai/server/internal/proto/budget/v1"
	debtpb "github.com/yucai/server/internal/proto/debt/v1"
	goalpb "github.com/yucai/server/internal/proto/goal/v1"
	tagpb "github.com/yucai/server/internal/proto/tag/v1"
	templatepb "github.com/yucai/server/internal/proto/template/v1"
	holdingapp "github.com/yucai/server/internal/holding/application"
	holdingpb "github.com/yucai/server/internal/proto/holding/v1"
	backuppb "github.com/yucai/server/internal/proto/backup/v1"
	syncpb "github.com/yucai/server/internal/proto/sync/v1"
	currencyapp "github.com/yucai/server/internal/currency/application"
	currencypb "github.com/yucai/server/internal/proto/currency/v1"
	"github.com/yucai/server/pkg/config"
	"github.com/yucai/server/wire"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		slog.Error("failed to load config", "error", err)
		os.Exit(1)
	}

	app, err := wire.InitializeApp(cfg)
	if err != nil {
		slog.Error("failed to initialize app", "error", err)
		os.Exit(1)
	}

	// Backfill preset categories for any tenant created before the seeder was
	// wired into registration (idempotent: tenants with system categories are
	// skipped). Runs once at startup so legacy tenants see the category dropdown.
	seedPresetCategories(context.Background(), app.TenantRepo, app.AccountService)

	// Seed built-in reference currencies (idempotent) so the rate-sync scheduler
	// has active rows to refresh and the client currency dropdown has data even
	// before the first frankfurter fetch succeeds.
	seedCurrencies(context.Background(), app.CurrencyService)

	// Seed sample holding data: securities covering every SecurityType (stock/
	// fund/etf/bond/gold/option) plus per-tenant holdings + buy trades, so the
	// investment UI has data to display. Idempotent — safe on every startup.
	seedHoldingTestData(context.Background(), app.TenantRepo, app.UserRepo, app.AccountService, app.HoldingService)

	// Start currency rate-sync scheduler. Performs an immediate SyncRates,
	// then re-syncs at most once per tenant's rate_sync_interval_hours. The
	// scheduler exits when schedCtx is cancelled during shutdown.
	schedCtx, schedCancel := context.WithCancel(context.Background())
	go app.CurrencyScheduler.Start(schedCtx)

	// Start holding price-sync scheduler. Performs an immediate SyncPrices on
	// start, then refreshes A-share prices at most once per tenant's
	// rate_sync_interval_hours (reuses the same IntervalSource as the currency
	// scheduler). Exits when schedCtx is cancelled during shutdown.
	go app.HoldingScheduler.Start(schedCtx)

	// Start holding snapshot scheduler. Performs an immediate
	// SnapshotAllHoldings (cross-tenant fan-out via the injected TenantLister),
	// then re-snapshots at most once per tenant's rate_sync_interval_hours.
	// Exits when schedCtx is cancelled during shutdown.
	go app.SnapshotScheduler.Start(schedCtx)

	// Start goal progress scheduler. Performs an immediate SyncInvestmentGoals
	// (Σ holding mv → investment goal.current_amount), then re-syncs at most
	// once per tenant's rate_sync_interval_hours. Exits when schedCtx is
	// cancelled during shutdown.
	go app.GoalScheduler.Start(schedCtx)

	// Backfill security price history on first launch (empty-table gate inside
	// BackfillPriceHistory), async so it never blocks startup. Pulls Sina daily
	// K-line for A-share holdings + CSI300 at YEAR depth (1200 bars ≈ 5 years).
	go func() {
		count, err := app.HoldingService.BackfillPriceHistory(context.Background(), "YEAR")
		if err != nil {
			slog.Error("holding backfill failed", "error", err, "operation", "main.backfill")
			return
		}
		if count > 0 {
			slog.Info("holding backfill completed", "count", count, "operation", "main.backfill")
		}
	}()

	// Register gRPC services
	authpb.RegisterAuthServiceServer(app.GRPCServer, app.AuthHandler)
	accountpb.RegisterAccountServiceServer(app.GRPCServer, app.AccountHandler)
	transactionpb.RegisterTransactionServiceServer(app.GRPCServer, app.TransactionHandler)
	budgetpb.RegisterBudgetServiceServer(app.GRPCServer, app.BudgetHandler)
	debtpb.RegisterDebtServiceServer(app.GRPCServer, app.DebtHandler)
	goalpb.RegisterGoalServiceServer(app.GRPCServer, app.GoalHandler)
	tagpb.RegisterTagServiceServer(app.GRPCServer, app.TagHandler)
	templatepb.RegisterTransactionTemplateServiceServer(app.GRPCServer, app.TemplateHandler)
	holdingpb.RegisterHoldingServiceServer(app.GRPCServer, app.HoldingHandler)
	backuppb.RegisterBackupServiceServer(app.GRPCServer, app.BackupHandler)
	syncpb.RegisterSyncServiceServer(app.GRPCServer, app.SyncHandler)
	currencypb.RegisterCurrencyServiceServer(app.GRPCServer, app.CurrencyHandler)

	// Start gRPC server
	addr := fmt.Sprintf(":%s", cfg.GRPCPort)
	lis, err := net.Listen("tcp", addr)
	if err != nil {
		slog.Error("failed to listen", "error", err, "addr", addr)
		os.Exit(1)
	}

	go func() {
		slog.Info("YuCai gRPC server starting", "addr", addr, "log_level", cfg.LogLevel)
		if err := app.GRPCServer.Serve(lis); err != nil {
			slog.Error("gRPC server error", "error", err)
			os.Exit(1)
		}
	}()

	// Wait for shutdown signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	sig := <-sigCh
	slog.Info("shutting down", "signal", sig)
	schedCancel() // stop the rate-sync scheduler before the gRPC server
	app.GRPCServer.GracefulStop()
}

// seedPresetCategories backfills the 10 system category accounts for every
// tenant in the database. It is idempotent: SeedPresetCategories is a no-op for
// tenants that already have system categories, so running it for all tenants on
// every startup is safe.
func seedPresetCategories(ctx context.Context, tenantRepo *authrepo.TenantRepository, accountService *accountapp.Service) {
	tenantIDs, err := tenantRepo.FindAllIDs(ctx)
	if err != nil {
		slog.Error("preset seed: failed to list tenants", "error", err)
		return
	}

	seeded := 0
	for _, id := range tenantIDs {
		if err := accountService.SeedPresetCategories(ctx, id); err != nil {
			slog.Error("preset seed: failed to seed tenant", "tenant_id", id, "error", err)
			continue
		}
		seeded++
	}
	slog.Info("preset seed: completed backfill", "tenant_count", len(tenantIDs), "seeded_or_skipped", seeded)
}

// seedCurrencies ensures the built-in reference currencies (CNY/USD/EUR/GBP/
// HKD/JPY, EUR-base rates) exist. Idempotent: SeedDefaults skips codes already
// present. Runs once at startup, before the rate-sync scheduler, so the
// scheduler's immediate SyncRates has active currencies to refresh.
func seedCurrencies(ctx context.Context, svc *currencyapp.Service) {
	created, err := svc.SeedDefaults(ctx)
	if err != nil {
		slog.Error("currency seed: failed", "error", err)
		return
	}
	slog.Info("currency seed: completed", "created", created)
}

// seedHoldingTestData seeds sample investment data: global securities covering
// every SecurityType, then per-tenant holdings + buy trades attached to each
// tenant's first asset (investment) account. Idempotent — SeedSecurities skips
// existing symbols and SeedSampleHoldings skips tenants that already hold.
func seedHoldingTestData(
	ctx context.Context,
	tenantRepo *authrepo.TenantRepository,
	userRepo *authrepo.UserRepository,
	accountService *accountapp.Service,
	holdingService *holdingapp.Service,
) {
	created, err := holdingService.SeedSecurities(ctx)
	if err != nil {
		slog.Error("holding seed: securities failed", "error", err)
	} else {
		slog.Info("holding seed: securities completed", "created", created)
	}

	// Ensure a test account exists (tenant + user + investment account) so the
	// investment UI has a logged-in user with holdings. Idempotent on email.
	email, derr := seedDemoAccount(ctx, tenantRepo, userRepo, accountService)
	if derr != nil {
		slog.Error("holding seed: test account failed", "error", derr)
		return
	}
	slog.Info("holding seed: test account ready", "email", email)

	// Seed holdings ONLY to the test account (centralized test data; other
	// tenants are expected to be cleared beforehand).
	testUser, err := userRepo.FindByEmailGlobal(ctx, "test@yucai.local")
	if err != nil || testUser == nil {
		slog.Error("holding seed: test user not found after seed", "error", err)
		return
	}
	accounts, err := accountService.FindByAccountType(ctx, testUser.TenantID, accountdomain.AccountTypeAsset)
	if err != nil || len(accounts) == 0 {
		slog.Error("holding seed: test account has no asset account", "tenant_id", testUser.TenantID, "error", err)
		return
	}
	if err := holdingService.SeedSampleHoldings(ctx, testUser.TenantID, accounts[0].ID); err != nil {
		slog.Error("holding seed: test holdings failed", "error", err)
		return
	}
	slog.Info("holding seed: test holdings completed", "tenant_id", testUser.TenantID, "account_id", accounts[0].ID)
}

// seedDemoAccount creates a demo tenant + user (known password) + investment
// account when the DB has no tenants, so the investment UI has a logged-in user
// with holdings. Idempotent on email. Returns the demo email.
func seedDemoAccount(
	ctx context.Context,
	tenantRepo *authrepo.TenantRepository,
	userRepo *authrepo.UserRepository,
	accountService *accountapp.Service,
) (string, error) {
	const email = "test@yucai.local"
	if existing, err := userRepo.FindByEmailGlobal(ctx, email); err == nil && existing != nil {
		return email, nil
	}
	hash, err := authpassword.HashPassword("test1234")
	if err != nil {
		return "", fmt.Errorf("hash demo password: %w", err)
	}
	tenant, err := authdomain.NewTenant("测试家庭", authdomain.TenantTypePersonal)
	if err != nil {
		return "", fmt.Errorf("new demo tenant: %w", err)
	}
	if err := tenantRepo.Save(ctx, tenant); err != nil {
		return "", fmt.Errorf("save demo tenant: %w", err)
	}
	if err := accountService.SeedPresetCategories(ctx, tenant.ID); err != nil {
		return "", fmt.Errorf("seed demo presets: %w", err)
	}
	user, err := authdomain.NewUser(tenant.ID, email, hash, "测试账户")
	if err != nil {
		return "", fmt.Errorf("new demo user: %w", err)
	}
	if err := userRepo.Save(ctx, user); err != nil {
		return "", fmt.Errorf("save demo user: %w", err)
	}
	if _, err := accountService.CreateAccount(ctx, accountapp.CreateAccountRequest{
		TenantID:            tenant.ID,
		Name:                "投资账户",
		AccountType:         accountdomain.AccountTypeAsset,
		Category:            accountdomain.AccountCategoryInvestment,
		CurrencyCode:        "CNY",
		InitialBalanceCents: 10000000,
		Ownership:           accountdomain.OwnershipPersonal,
	}); err != nil {
		return "", fmt.Errorf("create demo investment account: %w", err)
	}
	return email, nil
}
