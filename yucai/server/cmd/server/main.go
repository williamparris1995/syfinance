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
	authrepo "github.com/yucai/server/internal/auth/adapter/driven/repository"
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
	networthpb "github.com/yucai/server/internal/proto/networth/v1"
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

	// Seed the global securities catalog (idempotent). The per-tenant demo
	// user + sample holdings seeding that used to live here was removed: pure
	// OIDC login no longer supports password-hashed demo users, and a user
	// row without an OIDC identity can never log in. Re-enable via a real
	// OIDC test identity when needed.
	// TODO(auth-oidc): re-introduce demo holdings seed once an OIDC test
	// identity flow exists (see docs/superpowers/specs/auth-oidc-migration).
	seedSecuritiesCatalog(context.Background(), app.HoldingService)

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

	// Start goal progress scheduler. Performs an immediate SyncAllGoals
	// (Σ per-type progress → goal.current_amount + daily snapshot), then
	// re-syncs at most once per tenant's rate_sync_interval_hours. Exits when
	// schedCtx is cancelled during shutdown.
	go app.GoalScheduler.Start(schedCtx)

	// Start debt snapshot scheduler. Performs an immediate SyncAllDebts
	// (Σ remaining/paid per BorrowedOut debt → debt_progress_snapshot), then
	// re-syncs at most once per tenant's rate_sync_interval_hours. The snapshots
	// feed GetReceivablesSummary's month-over-month trend. Exits when schedCtx
	// is cancelled during shutdown.
	go app.DebtScheduler.Start(schedCtx)

	// Start template auto-record scheduler. Performs an immediate pass that
	// records a transaction for every due auto-record template (cross-tenant
	// via repo.FindDue: not paused + NextDate<=today + AutoRecord=true), then
	// re-runs every 24h. No IntervalSource gate — autoRecord is idempotent per
	// day (RecordTransaction advances NextDate past today). Exits when schedCtx
	// is cancelled during shutdown.
	go app.TemplateScheduler.Start(schedCtx)

	// Start auto-backup scheduler. Performs an immediate backup pass that fans
	// out across tenants and, per tenant, creates one auto=true backup when
	// AutoBackup is on and at least AutoBackupIntervalHours have elapsed since
	// that tenant's last backup (unconfigured tenants are skipped — defaults
	// applied in Service.AutoBackupSettings). Re-runs every 1h. Exits when
	// schedCtx is cancelled during shutdown.
	go app.BackupScheduler.Start(schedCtx)

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
	networthpb.RegisterNetWorthServiceServer(app.GRPCServer, app.NetWorthHandler)

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

// seedSecuritiesCatalog seeds the global securities catalog (covering every
// SecurityType) so the investment UI's security picker has data even before any
// tenant creates a holding. Idempotent — SeedSecurities skips existing symbols.
// Safe on every startup.
func seedSecuritiesCatalog(ctx context.Context, holdingService *holdingapp.Service) {
	created, err := holdingService.SeedSecurities(ctx)
	if err != nil {
		slog.Error("holding seed: securities failed", "error", err)
		return
	}
	slog.Info("holding seed: securities completed", "created", created)
}
