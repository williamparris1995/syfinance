package middleware

import (
	"context"
	"log/slog"
	"time"

	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
)

// firstMD returns the first value for a metadata key, or "" if absent.
func firstMD(md metadata.MD, key string) string {
	if md == nil {
		return ""
	}
	if vals := md.Get(key); len(vals) > 0 {
		return vals[0]
	}
	return ""
}

// UnaryLoggingInterceptor logs each unary gRPC call, including client identity
// headers so two different Flutter clients (or multiple instances) can be
// distinguished in the server log.
//
// Client-distinguishing headers (sent by Flutter clients on every call):
//   x-client-id   : per-install UUID (unique per app instance)
//   x-app-name    : client app name (e.g. "yucai_client")
//   x-app-version : client app version
//
// Chained OUTSIDE AuthInterceptor so auth-rejected calls are logged too.
func UnaryLoggingInterceptor(ctx context.Context, req any, info *grpc.UnaryServerInfo, handler grpc.UnaryHandler) (any, error) {
	start := time.Now()
	md, _ := metadata.FromIncomingContext(ctx)
	clientID := firstMD(md, "x-client-id")
	appName := firstMD(md, "x-app-name")
	appVer := firstMD(md, "x-app-version")

	resp, err := handler(ctx, req)
	duration := time.Since(start)

	p, _ := peer.FromContext(ctx)
	peerAddr := ""
	if p != nil {
		peerAddr = p.Addr.String()
	}

	code := codes.OK
	if err != nil {
		if s, ok := status.FromError(err); ok {
			code = s.Code()
		}
	}

	logLevel := slog.LevelInfo
	if err != nil {
		logLevel = slog.LevelError
	}
	slog.Log(ctx, logLevel, "gRPC call completed",
		"method", info.FullMethod,
		"client_id", clientID,
		"app", appName,
		"app_version", appVer,
		"peer", peerAddr,
		"duration_ms", duration.Milliseconds(),
		"status", code.String(),
		"error", err,
	)
	return resp, err
}
