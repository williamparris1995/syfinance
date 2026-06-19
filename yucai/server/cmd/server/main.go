package main

import (
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"

	_ "github.com/jackc/pgx/v5/stdlib" // register "pgx" database/sql driver

	authpb "github.com/yucai/server/internal/proto/auth/v1"
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
	app.GRPCServer.GracefulStop()
}
