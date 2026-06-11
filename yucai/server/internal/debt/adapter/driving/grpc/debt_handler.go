package grpc

import (
	"context"
	"time"

	pb "github.com/yucai/server/internal/proto/debt/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/debt/application"
	"github.com/yucai/server/internal/debt/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// DebtHandler implements the generated DebtServiceServer.
type DebtHandler struct {
	pb.UnimplementedDebtServiceServer
	service *application.Service
}

// NewDebtHandler creates a new DebtHandler.
func NewDebtHandler(service *application.Service) *DebtHandler {
	return &DebtHandler{service: service}
}

// CreateDebt creates a new debt with amortization schedule.
func (h *DebtHandler) CreateDebt(ctx context.Context, req *pb.CreateDebtRequest) (*pb.DebtResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	accountID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}

	startDate, err := parseDate(req.StartDate)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid start_date")
	}
	dueDate, err := parseDate(req.DueDate)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid due_date")
	}

	resp, err := h.service.CreateDebt(ctx, application.CreateDebtRequest{
		TenantID:            tenantID,
		AccountID:           accountID,
		Counterparty:        req.Counterparty,
		InterestRate:        req.InterestRate,
		AmortizationMethod:  protoToMethod(req.AmortizationMethod),
		StartDate:           startDate,
		DueDate:             dueDate,
		TotalPrincipalCents: req.TotalPrincipalCents,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.DebtResponse{Debt: debtToProto(*resp)}, nil
}

// UpdateDebt updates a debt's mutable fields.
func (h *DebtHandler) UpdateDebt(ctx context.Context, req *pb.UpdateDebtRequest) (*pb.DebtResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	resp, err := h.service.UpdateDebt(ctx, application.UpdateDebtRequest{
		TenantID:     tenantID,
		ID:           id,
		Counterparty: req.Counterparty,
		InterestRate: req.InterestRate,
		Version:      req.Version,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.DebtResponse{Debt: debtToProto(*resp)}, nil
}

// DeleteDebt deletes a debt.
func (h *DebtHandler) DeleteDebt(ctx context.Context, req *pb.DeleteDebtRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	if err := h.service.DeleteDebt(ctx, tenantID, id); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// RecordPayment records a payment for a schedule entry.
func (h *DebtHandler) RecordPayment(ctx context.Context, req *pb.RecordPaymentRequest) (*pb.RecordPaymentResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	debtID, _ := uuid.Parse(req.DebtId)
	entryID, _ := uuid.Parse(req.ScheduleEntryId)
	fromAccountID, _ := uuid.Parse(req.FromAccountId)

	_ = fromAccountID // transaction creation handled here in future

	resp, err := h.service.RecordPayment(ctx, application.RecordPaymentRequest{
		TenantID:        tenantID,
		DebtID:          debtID,
		ScheduleEntryID: entryID,
		FromAccountID:   fromAccountID,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.RecordPaymentResponse{
		TransactionId: resp.TransactionID.String(),
		Entry:         entryToProto(resp.Entry),
	}, nil
}

// GetDebt retrieves a debt with its payment schedule.
func (h *DebtHandler) GetDebt(ctx context.Context, req *pb.GetDebtRequest) (*pb.DebtDetailResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	resp, err := h.service.GetDebt(ctx, tenantID, id)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.DebtDetailResponse{Debt: detailToProto(*resp)}, nil
}

// ListDebts returns a paginated list of debts.
func (h *DebtHandler) ListDebts(ctx context.Context, req *pb.ListDebtsRequest) (*pb.ListDebtsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	pageReq := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		pageReq.PageSize = req.Page.PageSize
		pageReq.PageToken = req.Page.PageToken
	}

	result, err := h.service.ListDebts(ctx, application.ListDebtsRequest{
		TenantID: tenantID,
		Page:     pageReq,
	})
	if err != nil {
		return nil, mapError(err)
	}

	debts := make([]*pb.DebtDTO, len(result.Debts))
	for i, d := range result.Debts {
		debts[i] = debtToProto(d)
	}

	return &pb.ListDebtsResponse{
		Debts: debts,
		Page:  &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount},
	}, nil
}

// GetUpcomingPayments returns payments due within daysAhead.
func (h *DebtHandler) GetUpcomingPayments(ctx context.Context, req *pb.GetUpcomingPaymentsRequest) (*pb.ListDebtsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	daysAhead := int(req.DaysAhead)
	if daysAhead <= 0 {
		daysAhead = 30
	}

	result, err := h.service.GetUpcomingPayments(ctx, tenantID, daysAhead)
	if err != nil {
		return nil, mapError(err)
	}

	// Return entries as a flat list in DebtDTO format for simplicity
	debts := make([]*pb.DebtDTO, 0)
	for _, e := range result.Entries {
		debts = append(debts, &pb.DebtDTO{
			Id:       e.ID.String(),
			AccountId: e.DebtID.String(),
		})
	}

	return &pb.ListDebtsResponse{Debts: debts}, nil
}

func debtToProto(d application.DebtDTO) *pb.DebtDTO {
	return &pb.DebtDTO{
		Id:                  d.ID.String(),
		AccountId:           d.AccountID.String(),
		Counterparty:        d.Counterparty,
		InterestRate:        d.InterestRate,
		AmortizationMethod:  methodToProto(d.AmortizationMethod),
		StartDate:           d.StartDate.Format("2006-01-02"),
		DueDate:             d.DueDate.Format("2006-01-02"),
		TotalPrincipalCents: d.TotalPrincipalCents,
		RemainingPrincipalCents: d.RemainingPrincipal,
		Version:             d.Version,
		CreatedAt:           timestamppb.New(d.CreatedAt),
		UpdatedAt:           timestamppb.New(d.UpdatedAt),
	}
}

func entryToProto(e application.PaymentEntryDTO) *pb.PaymentEntryDTO {
	dto := &pb.PaymentEntryDTO{
		Id:             e.ID.String(),
		PaymentDate:    e.PaymentDate.Format("2006-01-02"),
		PrincipalCents: e.PrincipalCents,
		InterestCents:  e.InterestCents,
		TotalCents:     e.TotalCents,
		Paid:           e.Paid,
		PaidCents:      e.PaidCents,
	}
	if e.TransactionID != nil {
		dto.TransactionId = e.TransactionID.String()
	}
	return dto
}

func detailToProto(d application.DebtDetailDTO) *pb.DebtDetailDTO {
	schedule := make([]*pb.PaymentEntryDTO, len(d.Schedule))
	for i, e := range d.Schedule {
		schedule[i] = entryToProto(e)
	}
	return &pb.DebtDetailDTO{
		Debt:     debtToProto(d.Debt),
		Schedule: schedule,
	}
}

func protoToMethod(m pb.AmortizationMethod) domain.AmortizationMethod {
	switch m {
	case pb.AmortizationMethod_AMORTIZATION_EQUAL_PRINCIPAL_INTEREST:
		return domain.AmortizationEqualPrincipalInterest
	case pb.AmortizationMethod_AMORTIZATION_EQUAL_PRINCIPAL:
		return domain.AmortizationEqualPrincipal
	case pb.AmortizationMethod_AMORTIZATION_LUMP_SUM:
		return domain.AmortizationLumpSum
	default:
		return domain.AmortizationEqualPrincipalInterest
	}
}

func methodToProto(m domain.AmortizationMethod) pb.AmortizationMethod {
	switch m {
	case domain.AmortizationEqualPrincipalInterest:
		return pb.AmortizationMethod_AMORTIZATION_EQUAL_PRINCIPAL_INTEREST
	case domain.AmortizationEqualPrincipal:
		return pb.AmortizationMethod_AMORTIZATION_EQUAL_PRINCIPAL
	case domain.AmortizationLumpSum:
		return pb.AmortizationMethod_AMORTIZATION_LUMP_SUM
	default:
		return pb.AmortizationMethod_AMORTIZATION_UNSPECIFIED
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
