package grpc

import (
	"context"
	"time"

	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	pb "github.com/yucai/server/internal/proto/transaction/v1"
	"github.com/yucai/server/internal/transaction/application"
	"github.com/yucai/server/internal/transaction/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// TransactionHandler implements the generated TransactionServiceServer.
type TransactionHandler struct {
	pb.UnimplementedTransactionServiceServer
	service *application.Service
}

// NewTransactionHandler creates a new TransactionHandler.
func NewTransactionHandler(service *application.Service) *TransactionHandler {
	return &TransactionHandler{service: service}
}

// RecordTransaction records a new double-entry transaction.
func (h *TransactionHandler) RecordTransaction(ctx context.Context, req *pb.RecordTransactionRequest) (*pb.TransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	date, err := time.Parse("2006-01-02", req.TransactionDate)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid date format, use YYYY-MM-DD")
	}

	// transaction_time is an optional RFC3339 wall-clock time. Empty string
	// means unset; a malformed value is rejected as InvalidArgument.
	transactionTime, err := parseTransactionTime(req.TransactionTime)
	if err != nil {
		return nil, err
	}

	entries := make([]application.EntryInput, len(req.Entries))
	for i, e := range req.Entries {
		accountID, err := uuid.Parse(e.AccountId)
		if err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid account_id in entry %d", i)
		}
		entries[i] = application.EntryInput{
			AccountID:          accountID,
			ChartOfAccountCode: e.ChartOfAccountCode,
			DebitCents:         e.DebitCents,
			CreditCents:        e.CreditCents,
			Note:               e.Note,
		}
	}

	resp, err := h.service.RecordTransaction(ctx, application.RecordTransactionRequest{
		TenantID:        tenantID,
		TransactionDate: date,
		TransactionTime: transactionTime,
		Description:     req.Description,
		Entries:         entries,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TransactionResponse{Transaction: txnToProto(*resp)}, nil
}

// GetTransaction retrieves a transaction by ID.
func (h *TransactionHandler) GetTransaction(ctx context.Context, req *pb.GetTransactionRequest) (*pb.TransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	resp, err := h.service.GetTransaction(ctx, tenantID, id)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TransactionResponse{Transaction: txnToProto(*resp)}, nil
}

// ListTransactions returns a paginated list.
func (h *TransactionHandler) ListTransactions(ctx context.Context, req *pb.ListTransactionsRequest) (*pb.ListTransactionsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	filter := domain.TransactionFilter{}
	if req.AccountId != "" {
		aid, err := uuid.Parse(req.AccountId)
		if err == nil {
			filter.AccountID = &aid
		}
	}
	if req.DateFrom != "" {
		if d, err := time.Parse("2006-01-02", req.DateFrom); err == nil {
			filter.DateFrom = &d
		}
	}
	if req.DateTo != "" {
		if d, err := time.Parse("2006-01-02", req.DateTo); err == nil {
			filter.DateTo = &d
		}
	}

	pageReq := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		pageReq.PageSize = req.Page.PageSize
		pageReq.PageToken = req.Page.PageToken
	}

	result, err := h.service.ListTransactions(ctx, application.ListTransactionsRequest{
		TenantID: tenantID, Filter: filter, PageRequest: pageReq,
	})
	if err != nil {
		return nil, mapError(err)
	}

	txns := make([]*pb.TransactionDTO, len(result.Transactions))
	for i, t := range result.Transactions {
		txns[i] = txnToProto(t)
	}

	return &pb.ListTransactionsResponse{
		Transactions: txns,
		Page:         &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount},
	}, nil
}

// UpdateTransaction updates an existing transaction.
func (h *TransactionHandler) UpdateTransaction(ctx context.Context, req *pb.UpdateTransactionRequest) (*pb.TransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}
	date, err := time.Parse("2006-01-02", req.TransactionDate)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid date")
	}

	entries := make([]application.EntryInput, len(req.Entries))
	for i, e := range req.Entries {
		aid, _ := uuid.Parse(e.AccountId)
		entries[i] = application.EntryInput{
			AccountID: aid, ChartOfAccountCode: e.ChartOfAccountCode,
			DebitCents: e.DebitCents, CreditCents: e.CreditCents, Note: e.Note,
		}
	}

	resp, err := h.service.UpdateTransaction(ctx, application.UpdateTransactionRequest{
		TenantID: tenantID, TransactionID: id, TransactionDate: date,
		Description: req.Description, Entries: entries, Version: req.Version,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TransactionResponse{Transaction: txnToProto(*resp)}, nil
}

// DeleteTransaction soft-deletes a transaction.
func (h *TransactionHandler) DeleteTransaction(ctx context.Context, req *pb.DeleteTransactionRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}
	if err := h.service.DeleteTransaction(ctx, tenantID, id); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// SimpleIncome creates an income transaction.
func (h *TransactionHandler) SimpleIncome(ctx context.Context, req *pb.SimpleIncomeRequest) (*pb.TransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	date, _ := time.Parse("2006-01-02", req.TransactionDate)
	transactionTime, err := parseTransactionTime(req.TransactionTime)
	if err != nil {
		return nil, err
	}
	assetID, _ := uuid.Parse(req.AssetAccountId)
	incomeID, _ := uuid.Parse(req.IncomeAccountId)

	resp, err := h.service.SimpleIncome(ctx, application.SimpleIncomeRequest{
		TenantID: tenantID, TransactionDate: date, TransactionTime: transactionTime, Description: req.Description,
		AssetAccountID: assetID, IncomeAccountID: incomeID, AmountCents: req.AmountCents, Note: req.Note,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TransactionResponse{Transaction: txnToProto(*resp)}, nil
}

// SimpleExpense creates an expense transaction.
func (h *TransactionHandler) SimpleExpense(ctx context.Context, req *pb.SimpleExpenseRequest) (*pb.TransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	date, _ := time.Parse("2006-01-02", req.TransactionDate)
	transactionTime, err := parseTransactionTime(req.TransactionTime)
	if err != nil {
		return nil, err
	}
	expenseID, _ := uuid.Parse(req.ExpenseAccountId)
	assetID, _ := uuid.Parse(req.AssetAccountId)

	resp, err := h.service.SimpleExpense(ctx, application.SimpleExpenseRequest{
		TenantID: tenantID, TransactionDate: date, TransactionTime: transactionTime, Description: req.Description,
		ExpenseAccountID: expenseID, AssetAccountID: assetID, AmountCents: req.AmountCents, Note: req.Note,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TransactionResponse{Transaction: txnToProto(*resp)}, nil
}

// SimpleTransfer creates a transfer transaction.
func (h *TransactionHandler) SimpleTransfer(ctx context.Context, req *pb.SimpleTransferRequest) (*pb.TransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	date, _ := time.Parse("2006-01-02", req.TransactionDate)
	transactionTime, err := parseTransactionTime(req.TransactionTime)
	if err != nil {
		return nil, err
	}
	fromID, _ := uuid.Parse(req.FromAccountId)
	toID, _ := uuid.Parse(req.ToAccountId)

	resp, err := h.service.SimpleTransfer(ctx, application.SimpleTransferRequest{
		TenantID: tenantID, TransactionDate: date, TransactionTime: transactionTime, Description: req.Description,
		FromAccountID: fromID, ToAccountID: toID, AmountCents: req.AmountCents, Note: req.Note,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TransactionResponse{Transaction: txnToProto(*resp)}, nil
}

// TransactionSummary returns the monthly income/expense summary, optionally
// scoped to a single account.
func (h *TransactionHandler) TransactionSummary(ctx context.Context, req *pb.TransactionSummaryRequest) (*pb.TransactionSummaryResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	if req.Month < 1 || req.Month > 12 {
		return nil, status.Error(codes.InvalidArgument, "month must be 1-12")
	}
	if req.Year < 1 {
		return nil, status.Error(codes.InvalidArgument, "invalid year")
	}

	var accountID *uuid.UUID
	if req.AccountId != "" {
		aid, err := uuid.Parse(req.AccountId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid account_id")
		}
		accountID = &aid
	}

	summary, err := h.service.TransactionSummary(ctx, tenantID, int(req.Year), int(req.Month), accountID)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TransactionSummaryResponse{Summary: summaryToProto(summary)}, nil
}

func summaryToProto(s application.MonthlySummaryDTO) *pb.MonthlySummary {
	byDay := make([]*pb.DailyItem, len(s.ByDay))
	for i, d := range s.ByDay {
		cats := make([]*pb.CategoryItem, len(d.ByCategory))
		for j, c := range d.ByCategory {
			cats[j] = &pb.CategoryItem{
				AccountId:   c.AccountID.String(),
				Name:        c.Name,
				AccountType: c.AccountType,
				Amount:      c.Amount,
			}
		}
		byDay[i] = &pb.DailyItem{
			Date:        d.Date.Format("2006-01-02"),
			TotalIncome: d.TotalIncome,
			ByCategory:  cats,
		}
	}
	return &pb.MonthlySummary{
		IncomeCents:   s.IncomeCents,
		ExpenseCents:  s.ExpenseCents,
		NetCents:      s.NetCents,
		DailyAvgCents: s.DailyAvgCents,
		ByDay:         byDay,
	}
}

func txnToProto(t application.TransactionDTO) *pb.TransactionDTO {
	entries := make([]*pb.EntryDTO, len(t.Entries))
	for i, e := range t.Entries {
		entries[i] = &pb.EntryDTO{
			Id: e.ID.String(), AccountId: e.AccountID.String(),
			ChartOfAccountCode: e.ChartOfAccountCode, DebitCents: e.DebitCents,
			CreditCents: e.CreditCents, Note: e.Note,
		}
	}
	// transaction_time: RFC3339 when set, empty (proto3 default, omitted) when nil.
	var transactionTime string
	if t.TransactionTime != nil {
		transactionTime = t.TransactionTime.Format(time.RFC3339)
	}
	return &pb.TransactionDTO{
		Id: t.ID.String(), TransactionDate: t.TransactionDate.Format("2006-01-02"),
		Description: t.Description, Entries: entries, Version: t.Version,
		CreatedAt: timestamppb.New(t.CreatedAt), UpdatedAt: timestamppb.New(t.UpdatedAt),
		TransactionTime: transactionTime,
	}
}

func getTenantID(ctx context.Context) (uuid.UUID, error) {
	_, tenantID, err := authgrpc.GetUserAndTenantIDFromContext(ctx)
	return tenantID, err
}

// parseTransactionTime parses the optional RFC3339 wall-clock time carried by
// the record/simple RPCs. An empty string means "unset" → nil (no default).
// A malformed value is rejected as InvalidArgument. Shared by RecordTransaction
// and the SimpleIncome/Expense/Transfer handlers.
func parseTransactionTime(s string) (*time.Time, error) {
	if s == "" {
		return nil, nil
	}
	tt, err := time.Parse(time.RFC3339, s)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid transaction_time format, use RFC3339")
	}
	return &tt, nil
}

func mapError(err error) error {
	msg := err.Error()
	switch {
	case contains(msg, "not found"):
		return status.Error(codes.NotFound, msg)
	case contains(msg, "must have"), contains(msg, "violation"), contains(msg, "invalid"):
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
