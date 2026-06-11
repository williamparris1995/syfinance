package grpc

import (
	"context"
	"time"

	pb "github.com/yucai/server/internal/proto/goal/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/goal/application"
	"github.com/yucai/server/internal/goal/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// GoalHandler implements the generated GoalServiceServer.
type GoalHandler struct {
	pb.UnimplementedGoalServiceServer
	service *application.Service
}

// NewGoalHandler creates a new GoalHandler.
func NewGoalHandler(service *application.Service) *GoalHandler {
	return &GoalHandler{service: service}
}

// CreateGoal creates a new goal.
func (h *GoalHandler) CreateGoal(ctx context.Context, req *pb.CreateGoalRequest) (*pb.GoalResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	var deadline *time.Time
	if req.Deadline != "" {
		d, err := parseDate(req.Deadline)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid deadline")
		}
		deadline = &d
	}

	var linkedAccountID *uuid.UUID
	if req.LinkedAccountId != "" {
		aid, err := uuid.Parse(req.LinkedAccountId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid linked_account_id")
		}
		linkedAccountID = &aid
	}

	resp, err := h.service.CreateGoal(ctx, application.CreateGoalRequest{
		TenantID:          tenantID,
		Name:              req.Name,
		GoalType:          protoToGoalType(req.GoalType),
		TargetAmountCents: req.TargetAmountCents,
		CurrencyCode:      req.CurrencyCode,
		Deadline:          deadline,
		LinkedAccountID:   linkedAccountID,
		Notes:             req.Notes,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.GoalResponse{Goal: goalToProto(*resp)}, nil
}

// UpdateGoal updates a goal.
func (h *GoalHandler) UpdateGoal(ctx context.Context, req *pb.UpdateGoalRequest) (*pb.GoalResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	var deadline *time.Time
	if req.Deadline != "" {
		d, err := parseDate(req.Deadline)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid deadline")
		}
		deadline = &d
	}

	resp, err := h.service.UpdateGoal(ctx, application.UpdateGoalRequest{
		TenantID:          tenantID,
		ID:                id,
		Name:              req.Name,
		TargetAmountCents: req.TargetAmountCents,
		Deadline:          deadline,
		Notes:             req.Notes,
		Version:           req.Version,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.GoalResponse{Goal: goalToProto(*resp)}, nil
}

// UpdateGoalProgress adds progress to a goal.
func (h *GoalHandler) UpdateGoalProgress(ctx context.Context, req *pb.UpdateProgressRequest) (*pb.GoalResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, _ := uuid.Parse(req.Id)

	resp, err := h.service.UpdateGoalProgress(ctx, application.UpdateProgressRequest{
		TenantID:    tenantID,
		ID:          id,
		AmountCents: req.AmountCents,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.GoalResponse{Goal: goalToProto(*resp)}, nil
}

// CompleteGoal marks a goal as completed.
func (h *GoalHandler) CompleteGoal(ctx context.Context, req *pb.CompleteGoalRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	if err := h.service.CompleteGoal(ctx, tenantID, id); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// DeleteGoal deletes a goal.
func (h *GoalHandler) DeleteGoal(ctx context.Context, req *pb.DeleteGoalRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	if err := h.service.DeleteGoal(ctx, tenantID, id); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// SyncGoalProgress syncs progress from a linked account.
func (h *GoalHandler) SyncGoalProgress(ctx context.Context, req *pb.SyncGoalProgressRequest) (*pb.GoalResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, _ := uuid.Parse(req.Id)

	// Stub: pass 0 as current balance; real impl would fetch from AccountService
	resp, err := h.service.SyncGoalProgress(ctx, tenantID, id, 0)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.GoalResponse{Goal: goalToProto(*resp)}, nil
}

// GetGoal retrieves a goal by ID.
func (h *GoalHandler) GetGoal(ctx context.Context, req *pb.GetGoalRequest) (*pb.GoalDetailResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	resp, err := h.service.GetGoal(ctx, tenantID, id)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.GoalDetailResponse{Goal: goalToProto(*resp)}, nil
}

// ListGoals returns a paginated list of goals.
func (h *GoalHandler) ListGoals(ctx context.Context, req *pb.ListGoalsRequest) (*pb.ListGoalsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	pageReq := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		pageReq.PageSize = req.Page.PageSize
		pageReq.PageToken = req.Page.PageToken
	}

	var completed *bool
	// In proto3, we can't distinguish "not set" from "false"
	// We treat false as "filter active", absence as "all"
	// For simplicity, pass nil (all) unless explicitly set
	_ = completed

	result, err := h.service.ListGoals(ctx, application.ListGoalsRequest{
		TenantID:  tenantID,
		Completed: completed,
		Page:      pageReq,
	})
	if err != nil {
		return nil, mapError(err)
	}

	goals := make([]*pb.GoalDTO, len(result.Goals))
	for i, g := range result.Goals {
		goals[i] = goalToProto(g)
	}

	return &pb.ListGoalsResponse{
		Goals: goals,
		Page:  &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount},
	}, nil
}

func goalToProto(g application.GoalDTO) *pb.GoalDTO {
	p := &pb.GoalDTO{
		Id:                 g.ID.String(),
		Name:               g.Name,
		GoalType:           goalTypeToProto(g.GoalType),
		TargetAmountCents:  g.TargetAmountCents,
		CurrentAmountCents: g.CurrentAmountCents,
		CurrencyCode:       g.CurrencyCode,
		Notes:              g.Notes,
		IsCompleted:        g.IsCompleted,
		ProgressPct:        g.ProgressPct,
		RemainingCents:     g.RemainingCents,
		Version:            g.Version,
		CreatedAt:          timestamppb.New(g.CreatedAt),
		UpdatedAt:          timestamppb.New(g.UpdatedAt),
	}
	if g.Deadline != nil {
		p.Deadline = timestamppb.New(*g.Deadline)
	}
	if g.LinkedAccountID != nil {
		p.LinkedAccountId = g.LinkedAccountID.String()
	}
	if g.CompletedAt != nil {
		p.CompletedAt = timestamppb.New(*g.CompletedAt)
	}
	return p
}

func protoToGoalType(gt pb.GoalType) domain.GoalType {
	switch gt {
	case pb.GoalType_GOAL_TYPE_SAVINGS:
		return domain.GoalTypeSavings
	case pb.GoalType_GOAL_TYPE_DEBT_PAYOFF:
		return domain.GoalTypeDebtPayoff
	case pb.GoalType_GOAL_TYPE_INVESTMENT:
		return domain.GoalTypeInvestment
	default:
		return domain.GoalTypeSavings
	}
}

func goalTypeToProto(gt domain.GoalType) pb.GoalType {
	switch gt {
	case domain.GoalTypeSavings:
		return pb.GoalType_GOAL_TYPE_SAVINGS
	case domain.GoalTypeDebtPayoff:
		return pb.GoalType_GOAL_TYPE_DEBT_PAYOFF
	case domain.GoalTypeInvestment:
		return pb.GoalType_GOAL_TYPE_INVESTMENT
	default:
		return pb.GoalType_GOAL_TYPE_UNSPECIFIED
	}
}

func parseDate(s string) (time.Time, error) {
	return time.Parse("2006-01-02", s)
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

var _ = time.Time{}
