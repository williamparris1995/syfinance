package grpc

import (
	"context"
	"time"

	pb "github.com/yucai/server/internal/proto/budget/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/budget/application"
	"github.com/yucai/server/internal/budget/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// BudgetHandler implements the generated BudgetServiceServer.
type BudgetHandler struct {
	pb.UnimplementedBudgetServiceServer
	service *application.Service
}

// NewBudgetHandler creates a new BudgetHandler.
func NewBudgetHandler(service *application.Service) *BudgetHandler {
	return &BudgetHandler{service: service}
}

// CreateBudget creates a new budget.
func (h *BudgetHandler) CreateBudget(ctx context.Context, req *pb.CreateBudgetRequest) (*pb.BudgetResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	items := make([]application.BudgetItemInput, len(req.Items))
	for i, item := range req.Items {
		aid, err := uuid.Parse(item.AccountId)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid account_id in item %d", i)
		}
		items[i] = application.BudgetItemInput{
			AccountID:          aid,
			PlannedAmountCents: item.PlannedAmountCents,
			Notes:              item.Notes,
		}
	}

	resp, err := h.service.CreateBudget(ctx, application.CreateBudgetRequest{
		TenantID:     tenantID,
		Name:         req.Name,
		Month:        req.Month,
		CurrencyCode: req.CurrencyCode,
		Items:        items,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BudgetResponse{Budget: budgetToProto(*resp)}, nil
}

// GetBudget retrieves a budget by ID.
func (h *BudgetHandler) GetBudget(ctx context.Context, req *pb.GetBudgetRequest) (*pb.BudgetDetailResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	resp, err := h.service.GetBudget(ctx, tenantID, id)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BudgetDetailResponse{Budget: detailToProto(*resp)}, nil
}

// GetBudgetByMonth retrieves a budget by month.
func (h *BudgetHandler) GetBudgetByMonth(ctx context.Context, req *pb.GetBudgetByMonthRequest) (*pb.BudgetDetailResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	resp, err := h.service.GetBudgetByMonth(ctx, tenantID, req.Month)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BudgetDetailResponse{Budget: detailToProto(*resp)}, nil
}

// ListBudgets returns a paginated list.
func (h *BudgetHandler) ListBudgets(ctx context.Context, req *pb.ListBudgetsRequest) (*pb.ListBudgetsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	pageReq := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		pageReq.PageSize = req.Page.PageSize
		pageReq.PageToken = req.Page.PageToken
	}

	result, err := h.service.ListBudgets(ctx, application.ListBudgetsRequest{
		TenantID:   tenantID,
		ActiveOnly: req.ActiveOnly,
		Page:       pageReq,
	})
	if err != nil {
		return nil, mapError(err)
	}

	budgets := make([]*pb.BudgetDTO, len(result.Budgets))
	for i, b := range result.Budgets {
		budgets[i] = budgetToProto(b)
	}

	return &pb.ListBudgetsResponse{
		Budgets: budgets,
		Page:    &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount},
	}, nil
}

// DeleteBudget deletes a budget.
func (h *BudgetHandler) DeleteBudget(ctx context.Context, req *pb.DeleteBudgetRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	if err := h.service.DeleteBudget(ctx, tenantID, id); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// AddBudgetItem adds an item to a budget.
func (h *BudgetHandler) AddBudgetItem(ctx context.Context, req *pb.AddBudgetItemRequest) (*pb.BudgetResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	budgetID, _ := uuid.Parse(req.BudgetId)
	accountID, _ := uuid.Parse(req.AccountId)

	resp, err := h.service.AddBudgetItem(ctx, application.AddBudgetItemRequest{
		TenantID:           tenantID,
		BudgetID:           budgetID,
		AccountID:          accountID,
		PlannedAmountCents: req.PlannedAmountCents,
		Notes:              req.Notes,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BudgetResponse{Budget: budgetToProto(*resp)}, nil
}

// RemoveBudgetItem removes an item from a budget.
func (h *BudgetHandler) RemoveBudgetItem(ctx context.Context, req *pb.RemoveBudgetItemRequest) (*pb.BudgetResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	budgetID, _ := uuid.Parse(req.BudgetId)
	itemID, _ := uuid.Parse(req.ItemId)

	resp, err := h.service.RemoveBudgetItem(ctx, application.RemoveBudgetItemRequest{
		TenantID: tenantID,
		BudgetID: budgetID,
		ItemID:   itemID,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BudgetResponse{Budget: budgetToProto(*resp)}, nil
}

// ComputeBudgetActuals recalculates actual spending.
func (h *BudgetHandler) ComputeBudgetActuals(ctx context.Context, req *pb.ComputeActualsRequest) (*pb.BudgetResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	budgetID, _ := uuid.Parse(req.BudgetId)

	resp, err := h.service.ComputeActuals(ctx, application.ComputeActualsRequest{
		TenantID: tenantID,
		BudgetID: budgetID,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BudgetResponse{Budget: budgetToProto(*resp)}, nil
}

// CloneBudgetToMonth clones a budget to a new month.
func (h *BudgetHandler) CloneBudgetToMonth(ctx context.Context, req *pb.CloneBudgetRequest) (*pb.BudgetResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	sourceID, _ := uuid.Parse(req.SourceBudgetId)

	resp, err := h.service.CloneBudgetToMonth(ctx, application.CloneBudgetRequest{
		TenantID:       tenantID,
		SourceBudgetID: sourceID,
		TargetMonth:    req.TargetMonth,
		Name:           req.Name,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BudgetResponse{Budget: budgetToProto(*resp)}, nil
}

func budgetToProto(b application.BudgetDTO) *pb.BudgetDTO {
	return &pb.BudgetDTO{
		Id: b.ID.String(), Name: b.Name, Month: b.Month,
		TotalAmountCents: b.TotalAmountCents, CurrencyCode: b.CurrencyCode,
		IsActive: b.IsActive, Version: b.Version,
		CreatedAt: timestamppb.New(b.CreatedAt), UpdatedAt: timestamppb.New(b.UpdatedAt),
	}
}

func detailToProto(d application.BudgetDetailDTO) *pb.BudgetDetailDTO {
	return &pb.BudgetDetailDTO{
		Budget:              budgetToProto(d.Budget),
		TotalActualCents:    d.TotalActualCents,
		TotalRemainingCents: d.TotalRemainingCents,
		UsagePct:            d.UsagePct,
	}
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
	case contains(msg, "optimistic lock"):
		return status.Error(codes.Aborted, msg)
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

// Ensure time is imported.
var _ = time.Time{}
