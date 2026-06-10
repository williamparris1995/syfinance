package main

import (
	"fmt"
	"log/slog"
	"net"
	"os"
	"os/signal"
	"syscall"

	authpb "github.com/yucai/server/internal/proto/auth/v1"
	accountpb "github.com/yucai/server/internal/proto/account/v1"
	transactionpb "github.com/yucai/server/internal/proto/transaction/v1"
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
