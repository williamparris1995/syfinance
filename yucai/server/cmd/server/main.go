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

	// Start currency rate-sync scheduler. Performs an immediate SyncRates,
	// then re-syncs at most once per tenant's rate_sync_interval_hours. The
	// scheduler exits when schedCtx is cancelled during shutdown.
	schedCtx, schedCancel := context.WithCancel(context.Background())
	go app.CurrencyScheduler.Start(schedCtx)

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
