package grpc

import (
	"context"

	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/networth/application"
	pb "github.com/yucai/server/internal/proto/networth/v1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// NetWorthHandler implements the generated NetWorthServiceServer.
//
// It is a thin adapter over application.Service: it resolves the tenant_id
// from the auth context, forwards the (optional) base_currency, and maps the
// domain GetNetWorthResult into the proto response. The service is
// best-effort (failing source ports are logged and skipped internally), so
// GetNetWorth normally returns no error unless the caller is unauthenticated.
type NetWorthHandler struct {
	pb.UnimplementedNetWorthServiceServer
	service *application.Service
}

// NewNetWorthHandler creates a new NetWorthHandler.
func NewNetWorthHandler(service *application.Service) *NetWorthHandler {
	return &NetWorthHandler{service: service}
}

// GetNetWorth returns the tenant's aggregated net worth (assets − liabilities),
// 折算 to base_currency (empty/CNY → CNY).
func (h *NetWorthHandler) GetNetWorth(ctx context.Context, req *pb.GetNetWorthRequest) (*pb.GetNetWorthResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	res, err := h.service.GetNetWorth(ctx, tenantID, req.GetBaseCurrency())
	if err != nil {
		return nil, mapError(err)
	}

	return &pb.GetNetWorthResponse{
		TotalAssetsCents:      res.TotalAssetsCents,
		TotalLiabilitiesCents: res.TotalLiabilitiesCents,
		NetWorthCents:         res.NetWorthCents,
		Currency:              res.Currency,
	}, nil
}

func getTenantID(ctx context.Context) (uuid.UUID, error) {
	_, tenantID, err := authgrpc.GetUserAndTenantIDFromContext(ctx)
	return tenantID, err
}

func mapError(err error) error {
	msg := err.Error()
	switch {
	case contains(msg, "not found"):
		return status.Error(codes.NotFound, msg)
	case contains(msg, "invalid"), contains(msg, "must"):
		return status.Error(codes.InvalidArgument, msg)
	default:
		return status.Error(codes.Internal, msg)
	}
}

func contains(s, sub string) bool {
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}
