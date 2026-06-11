package grpc

import (
	"context"
	"time"

	pb "github.com/yucai/server/internal/proto/template/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/template/application"
	"github.com/yucai/server/internal/template/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// TemplateHandler implements the generated TransactionTemplateServiceServer.
type TemplateHandler struct {
	pb.UnimplementedTransactionTemplateServiceServer
	service *application.Service
}

// NewTemplateHandler creates a new TemplateHandler.
func NewTemplateHandler(service *application.Service) *TemplateHandler {
	return &TemplateHandler{service: service}
}

// CreateTransactionTemplate creates a new template.
func (h *TemplateHandler) CreateTransactionTemplate(ctx context.Context, req *pb.CreateTemplateRequest) (*pb.TemplateResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	sourceID, err := uuid.Parse(req.SourceAccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid source_account_id")
	}
	startDate, err := parseDate(req.StartDate)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid start_date")
	}

	var destID *uuid.UUID
	if req.DestinationAccountId != "" {
		id, _ := uuid.Parse(req.DestinationAccountId)
		destID = &id
	}
	var endDate *time.Time
	if req.EndDate != "" {
		d, _ := parseDate(req.EndDate)
		endDate = &d
	}

	resp, err := h.service.CreateTemplate(ctx, application.CreateTemplateRequest{
		TenantID:            tenantID,
		Name:                req.Name,
		Description:         req.Description,
		AmountCents:         req.AmountCents,
		Direction:           protoToDirection(req.Direction),
		SourceAccountID:      sourceID,
		DestinationAccountID: destID,
		Cycle:               protoToCycle(req.Cycle),
		CycleDays:           req.CycleDays,
		BillingDay:          req.BillingDay,
		StartDate:           startDate,
		EndDate:             endDate,
		AutoRecord:          req.AutoRecord,
		Category:            req.Category,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TemplateResponse{Template: templateToProto(*resp)}, nil
}

// UpdateTransactionTemplate updates a template.
func (h *TemplateHandler) UpdateTransactionTemplate(ctx context.Context, req *pb.UpdateTemplateRequest) (*pb.TemplateResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, _ := uuid.Parse(req.Id)
	var endDate *time.Time
	if req.EndDate != "" {
		d, _ := parseDate(req.EndDate)
		endDate = &d
	}

	resp, err := h.service.UpdateTemplate(ctx, application.UpdateTemplateRequest{
		TenantID:    tenantID,
		ID:          id,
		Name:        req.Name,
		Description: req.Description,
		AmountCents: req.AmountCents,
		Cycle:       protoToCycle(req.Cycle),
		CycleDays:   req.CycleDays,
		EndDate:     endDate,
		AutoRecord:  req.AutoRecord,
		Version:     req.Version,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TemplateResponse{Template: templateToProto(*resp)}, nil
}

// DeleteTransactionTemplate deletes a template.
func (h *TemplateHandler) DeleteTransactionTemplate(ctx context.Context, req *pb.DeleteTemplateRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, _ := uuid.Parse(req.Id)
	if err := h.service.DeleteTemplate(ctx, tenantID, id); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// PauseTransactionTemplate pauses a template.
func (h *TemplateHandler) PauseTransactionTemplate(ctx context.Context, req *pb.PauseTemplateRequest) (*pb.TemplateResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, _ := uuid.Parse(req.Id)
	resp, err := h.service.PauseTemplate(ctx, tenantID, id)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TemplateResponse{Template: templateToProto(*resp)}, nil
}

// ResumeTransactionTemplate resumes a template.
func (h *TemplateHandler) ResumeTransactionTemplate(ctx context.Context, req *pb.ResumeTemplateRequest) (*pb.TemplateResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, _ := uuid.Parse(req.Id)
	resp, err := h.service.ResumeTemplate(ctx, tenantID, id)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TemplateResponse{Template: templateToProto(*resp)}, nil
}

// GetTransactionTemplate retrieves a template.
func (h *TemplateHandler) GetTransactionTemplate(ctx context.Context, req *pb.GetTemplateRequest) (*pb.TemplateResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, _ := uuid.Parse(req.Id)
	resp, err := h.service.GetTemplate(ctx, tenantID, id)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TemplateResponse{Template: templateToProto(*resp)}, nil
}

// ListTransactionTemplates returns paginated templates.
func (h *TemplateHandler) ListTransactionTemplates(ctx context.Context, req *pb.ListTemplatesRequest) (*pb.ListTemplatesResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	pageReq := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		pageReq.PageSize = req.Page.PageSize
		pageReq.PageToken = req.Page.PageToken
	}

	result, err := h.service.ListTemplates(ctx, application.ListTemplatesRequest{
		TenantID: tenantID,
		Page:     pageReq,
	})
	if err != nil {
		return nil, mapError(err)
	}

	templates := make([]*pb.TemplateDTO, len(result.Templates))
	for i, t := range result.Templates {
		templates[i] = templateToProto(t)
	}

	return &pb.ListTemplatesResponse{
		Templates: templates,
		Page:      &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount},
	}, nil
}

func templateToProto(t application.TemplateDTO) *pb.TemplateDTO {
	p := &pb.TemplateDTO{
		Id:              t.ID.String(),
		Name:            t.Name,
		Description:     t.Description,
		AmountCents:     t.AmountCents,
		Direction:       directionToProto(t.Direction),
		SourceAccountId: t.SourceAccountID.String(),
		Cycle:           cycleToProto(t.Cycle),
		CycleDays:       t.CycleDays,
		BillingDay:      t.BillingDay,
		NextDate:        t.NextDate.Format("2006-01-02"),
		StartDate:       t.StartDate.Format("2006-01-02"),
		AutoRecord:      t.AutoRecord,
		Paused:          t.Paused,
		Category:        t.Category,
		Version:         t.Version,
		CreatedAt:       timestamppb.New(t.CreatedAt),
		UpdatedAt:       timestamppb.New(t.UpdatedAt),
	}
	if t.DestinationAccountID != nil {
		p.DestinationAccountId = t.DestinationAccountID.String()
	}
	if t.EndDate != nil {
		p.EndDate = t.EndDate.Format("2006-01-02")
	}
	if t.LastTransactionID != nil {
		p.LastTransactionId = t.LastTransactionID.String()
	}
	return p
}

func protoToDirection(d pb.TemplateDirection) domain.TemplateDirection {
	switch d {
	case pb.TemplateDirection_DIRECTION_EXPENSE:
		return domain.DirectionExpense
	case pb.TemplateDirection_DIRECTION_INCOME:
		return domain.DirectionIncome
	case pb.TemplateDirection_DIRECTION_TRANSFER:
		return domain.DirectionTransfer
	default:
		return domain.DirectionExpense
	}
}

func directionToProto(d domain.TemplateDirection) pb.TemplateDirection {
	switch d {
	case domain.DirectionExpense:
		return pb.TemplateDirection_DIRECTION_EXPENSE
	case domain.DirectionIncome:
		return pb.TemplateDirection_DIRECTION_INCOME
	case domain.DirectionTransfer:
		return pb.TemplateDirection_DIRECTION_TRANSFER
	default:
		return pb.TemplateDirection_DIRECTION_UNSPECIFIED
	}
}

func protoToCycle(c pb.TemplateCycle) domain.TemplateCycle {
	switch c {
	case pb.TemplateCycle_CYCLE_WEEKLY:
		return domain.CycleWeekly
	case pb.TemplateCycle_CYCLE_MONTHLY:
		return domain.CycleMonthly
	case pb.TemplateCycle_CYCLE_YEARLY:
		return domain.CycleYearly
	case pb.TemplateCycle_CYCLE_CUSTOM:
		return domain.CycleCustom
	default:
		return domain.CycleMonthly
	}
}

func cycleToProto(c domain.TemplateCycle) pb.TemplateCycle {
	switch c {
	case domain.CycleWeekly:
		return pb.TemplateCycle_CYCLE_WEEKLY
	case domain.CycleMonthly:
		return pb.TemplateCycle_CYCLE_MONTHLY
	case domain.CycleYearly:
		return pb.TemplateCycle_CYCLE_YEARLY
	case domain.CycleCustom:
		return pb.TemplateCycle_CYCLE_CUSTOM
	default:
		return pb.TemplateCycle_CYCLE_UNSPECIFIED
	}
}

func parseDate(s string) (time.Time, error) { return time.Parse("2006-01-02", s) }

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
