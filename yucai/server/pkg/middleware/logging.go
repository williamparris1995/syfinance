package middleware

import (
	"context"
	"log/slog"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/peer"
)

// UnaryLoggingInterceptor logs each unary gRPC call.
func UnaryLoggingInterceptor(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	start := time.Now()
	resp, err := handler(ctx, req)
	duration := time.Since(start)

	p, _ := peer.FromContext(ctx)
	logLevel := slog.LevelInfo
	if err != nil {
		logLevel = slog.LevelError
	}

	slog.Log(ctx, logLevel, "gRPC call completed",
		"method", info.FullMethod,
		"peer", p.Addr.String(),
		"duration_ms", duration.Milliseconds(),
		"error", err,
	)
	return resp, err
}
