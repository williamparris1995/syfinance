package grpc

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/account/application"
	"github.com/yucai/server/internal/account/domain"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	pb "github.com/yucai/server/internal/proto/account/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// Conversion helpers between proto optional scalars and application/domain pointers.

func ts(t *timestamppb.Timestamp) *time.Time {
	if t == nil {
		return nil
	}
	v := t.AsTime()
	return &v
}

func optTs(t *time.Time) *timestamppb.Timestamp {
	if t == nil {
		return nil
	}
	return timestamppb.New(*t)
}

func optStr(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

func i32ToInt(p *int32) *int {
	if p == nil {
		return nil
	}
	v := int(*p)
	return &v
}

func intToI32(p *int) *int32 {
	if p == nil {
		return nil
	}
	v := int32(*p)
	return &v
}

func statusPtr(p *pb.AccountStatus) *domain.AccountStatus {
	if p == nil {
		return nil
	}
	v := protoToAccountStatus(*p)
	return &v
}

// AccountHandler implements the generated AccountServiceServer interface.
type AccountHandler struct {
	pb.UnimplementedAccountServiceServer
	service *application.Service
}

// NewAccountHandler creates a new AccountHandler.
func NewAccountHandler(service *application.Service) *AccountHandler {
	return &AccountHandler{service: service}
}

// CreateAccount handles account creation.
func (h *AccountHandler) CreateAccount(ctx context.Context, req *pb.CreateAccountRequest) (*pb.AccountResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	if req.Name == "" {
		return nil, status.Error(codes.InvalidArgument, "name is required")
	}

	resp, err := h.service.CreateAccount(ctx, application.CreateAccountRequest{
		TenantID:                 tenantID,
		Name:                     req.Name,
		AccountType:              protoToAccountType(req.AccountType),
		Category:                 protoToAccountCategory(req.Category),
		CurrencyCode:             req.CurrencyCode,
		InitialBalanceCents:      req.InitialBalanceCents,
		Ownership:                protoToOwnership(req.Ownership),
		Icon:                     req.Icon,
		Color:                    req.Color,
		ChartCode:                req.ChartCode,
		Institution:              req.Institution,
		CreditLimitCents:         req.CreditLimitCents,
		CardNumberTail:           req.CardNumberTail,
		Notes:                    req.Notes,
		OpeningDate:              ts(req.OpeningDate),
		InterestRate:             req.InterestRate,
		CreditBillingDay:         i32ToInt(req.CreditBillingDay),
		CreditRepaymentDay:       i32ToInt(req.CreditRepaymentDay),
		CreditAnnualFeeCents:     req.CreditAnnualFeeCents,
		InvestCostCents:          req.InvestCostCents,
		InvestMarketValueCents:   req.InvestMarketValueCents,
		InvestReturnYtd:          req.InvestReturnYtd,
		FixedPrincipalCents:      req.FixedPrincipalCents,
		FixedStartDate:           ts(req.FixedStartDate),
		FixedMaturityDate:        ts(req.FixedMaturityDate),
		FixedTermMonths:          i32ToInt(req.FixedTermMonths),
		GoldProductType:          req.GoldProductType,
		GoldQuantity:             req.GoldQuantity,
		GoldBuyPriceCents:        req.GoldBuyPriceCents,
		GoldCurrentPriceCents:    req.GoldCurrentPriceCents,
		EstatePurchasePriceCents: req.EstatePurchasePriceCents,
		EstateCurrentValueCents:  req.EstateCurrentValueCents,
		EstatePurchaseDate:       ts(req.EstatePurchaseDate),
		EstateDepreciationRate:   req.EstateDepreciationRate,
		LoanOriginalCents:        req.LoanOriginalCents,
		LoanRemainingCents:       req.LoanRemainingCents,
		LoanMonthlyCents:         req.LoanMonthlyCents,
		LoanNextPaymentDate:      ts(req.LoanNextPaymentDate),
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.AccountResponse{Account: dtoToProto(*resp)}, nil
}

// GetAccount retrieves a single account.
func (h *AccountHandler) GetAccount(ctx context.Context, req *pb.GetAccountRequest) (*pb.AccountResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	accountID, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account id")
	}

	resp, err := h.service.GetAccount(ctx, tenantID, accountID)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.AccountResponse{Account: dtoToProto(*resp)}, nil
}

// ListAccounts returns a paginated list of accounts.
func (h *AccountHandler) ListAccounts(ctx context.Context, req *pb.ListAccountsRequest) (*pb.ListAccountsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	filter := domain.AccountFilter{}
	if req.AccountType != pb.AccountType_ACCOUNT_TYPE_UNSPECIFIED {
		at := protoToAccountType(req.AccountType)
		filter.AccountType = &at
	}
	if req.Status != pb.AccountStatus_ACCOUNT_STATUS_UNSPECIFIED {
		s := protoToAccountStatus(req.Status)
		filter.Status = &s
	}

	pageReq := domain.PageRequest{PageSize: 200}
	if req.Page != nil {
		pageReq.PageSize = req.Page.PageSize
		pageReq.PageToken = req.Page.PageToken
	}

	result, err := h.service.ListAccounts(ctx, application.ListAccountsRequest{
		TenantID:    tenantID,
		Filter:      filter,
		PageRequest: pageReq,
	})
	if err != nil {
		return nil, mapError(err)
	}

	accounts := make([]*pb.AccountDTO, len(result.Accounts))
	for i, a := range result.Accounts {
		accounts[i] = dtoToProto(a)
	}

	return &pb.ListAccountsResponse{
		Accounts: accounts,
		Page: &commonpb.PageResponse{
			NextPageToken: result.NextPageToken,
			TotalCount:    result.TotalCount,
		},
	}, nil
}

// FindByAccountType returns all non-deleted accounts of a given type for the
// caller's tenant. Powers the transaction-form category dropdown.
func (h *AccountHandler) FindByAccountType(ctx context.Context, req *pb.FindByAccountTypeRequest) (*pb.FindByAccountTypeResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	if req.AccountType == pb.AccountType_ACCOUNT_TYPE_UNSPECIFIED {
		return nil, status.Error(codes.InvalidArgument, "account_type is required")
	}

	accounts, err := h.service.FindByAccountType(ctx, tenantID, protoToAccountType(req.AccountType))
	if err != nil {
		return nil, mapError(err)
	}

	dtos := make([]*pb.AccountDTO, len(accounts))
	for i, a := range accounts {
		dtos[i] = dtoToProto(a)
	}
	return &pb.FindByAccountTypeResponse{Accounts: dtos}, nil
}

// UpdateAccount updates an existing account.
func (h *AccountHandler) UpdateAccount(ctx context.Context, req *pb.UpdateAccountRequest) (*pb.AccountResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	accountID, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account id")
	}

	resp, err := h.service.UpdateAccount(ctx, application.UpdateAccountRequest{
		TenantID:                 tenantID,
		AccountID:                accountID,
		Name:                     req.Name,
		Icon:                     req.Icon,
		Color:                    req.Color,
		ChartCode:                req.ChartCode,
		Institution:              req.Institution,
		CreditLimitCents:         req.CreditLimitCents,
		Status:                   statusPtr(req.Status),
		CardNumberTail:           req.CardNumberTail,
		Notes:                    req.Notes,
		OpeningDate:              ts(req.OpeningDate),
		InterestRate:             req.InterestRate,
		CreditBillingDay:         i32ToInt(req.CreditBillingDay),
		CreditRepaymentDay:       i32ToInt(req.CreditRepaymentDay),
		CreditAnnualFeeCents:     req.CreditAnnualFeeCents,
		InvestCostCents:          req.InvestCostCents,
		InvestMarketValueCents:   req.InvestMarketValueCents,
		InvestReturnYtd:          req.InvestReturnYtd,
		FixedPrincipalCents:      req.FixedPrincipalCents,
		FixedStartDate:           ts(req.FixedStartDate),
		FixedMaturityDate:        ts(req.FixedMaturityDate),
		FixedTermMonths:          i32ToInt(req.FixedTermMonths),
		GoldProductType:          req.GoldProductType,
		GoldQuantity:             req.GoldQuantity,
		GoldBuyPriceCents:        req.GoldBuyPriceCents,
		GoldCurrentPriceCents:    req.GoldCurrentPriceCents,
		EstatePurchasePriceCents: req.EstatePurchasePriceCents,
		EstateCurrentValueCents:  req.EstateCurrentValueCents,
		EstatePurchaseDate:       ts(req.EstatePurchaseDate),
		EstateDepreciationRate:   req.EstateDepreciationRate,
		LoanOriginalCents:        req.LoanOriginalCents,
		LoanRemainingCents:       req.LoanRemainingCents,
		LoanMonthlyCents:         req.LoanMonthlyCents,
		LoanNextPaymentDate:      ts(req.LoanNextPaymentDate),
		Version:                  req.Version,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.AccountResponse{Account: dtoToProto(*resp)}, nil
}

// DeleteAccount soft-deletes an account.
func (h *AccountHandler) DeleteAccount(ctx context.Context, req *pb.DeleteAccountRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	accountID, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account id")
	}

	if err := h.service.DeleteAccount(ctx, tenantID, accountID); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// --- Category CRUD handlers (account-as-category) ---

// CreateCategory creates an Expense/Income category account.
func (h *AccountHandler) CreateCategory(ctx context.Context, req *pb.CreateCategoryRequest) (*pb.AccountResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	if req.Name == "" {
		return nil, status.Error(codes.InvalidArgument, "name is required")
	}
	at := protoToAccountType(req.AccountType)
	if at != domain.AccountTypeExpense && at != domain.AccountTypeIncome {
		return nil, status.Error(codes.InvalidArgument, "account_type must be income or expense")
	}

	var parentID *uuid.UUID
	if req.ParentId != "" {
		pid, err := uuid.Parse(req.ParentId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid parent_id")
		}
		parentID = &pid
	}

	resp, err := h.service.CreateCategory(ctx, application.CreateCategoryRequest{
		TenantID:    tenantID,
		Name:        req.Name,
		Icon:        req.Icon,
		Color:       req.Color,
		AccountType: at,
		ParentID:    parentID,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.AccountResponse{Account: dtoToProto(*resp)}, nil
}

// UpdateCategory edits a category's display fields. Empty optional strings are
// treated as "unchanged" (proto3 optional collapses to value accessors here).
func (h *AccountHandler) UpdateCategory(ctx context.Context, req *pb.UpdateCategoryRequest) (*pb.AccountResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	categoryID, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid category id")
	}

	var parentID *uuid.UUID
	if req.ParentId != nil && *req.ParentId != "" {
		pid, err := uuid.Parse(*req.ParentId)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid parent_id")
		}
		parentID = &pid
	}

	resp, err := h.service.UpdateCategory(ctx, application.UpdateCategoryRequest{
		TenantID:   tenantID,
		CategoryID: categoryID,
		Name:       req.Name,
		Icon:       req.Icon,
		Color:      req.Color,
		ParentID:   parentID,
		Version:    req.Version,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.AccountResponse{Account: dtoToProto(*resp)}, nil
}

// DeleteCategory soft-deletes a category (system categories are rejected).
func (h *AccountHandler) DeleteCategory(ctx context.Context, req *pb.DeleteCategoryRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	categoryID, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid category id")
	}
	if err := h.service.DeleteCategory(ctx, tenantID, categoryID); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// ReorderCategories rewrites sort_order for the given category IDs within a
// tenant + account-type group.
func (h *AccountHandler) ReorderCategories(ctx context.Context, req *pb.ReorderCategoriesRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	at := protoToAccountType(req.AccountType)
	if at != domain.AccountTypeExpense && at != domain.AccountTypeIncome {
		return nil, status.Error(codes.InvalidArgument, "account_type must be income or expense")
	}
	if len(req.OrderedIds) == 0 {
		return nil, status.Error(codes.InvalidArgument, "ordered_ids must not be empty")
	}

	ordered := make([]uuid.UUID, 0, len(req.OrderedIds))
	for _, s := range req.OrderedIds {
		id, err := uuid.Parse(s)
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid category id in ordered_ids")
		}
		ordered = append(ordered, id)
	}

	if err := h.service.ReorderCategories(ctx, application.ReorderCategoriesRequest{
		TenantID:    tenantID,
		AccountType: at,
		OrderedIDs:  ordered,
	}); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

func dtoToProto(a application.AccountDTO) *pb.AccountDTO {
	dto := &pb.AccountDTO{
		Id:                       a.ID.String(),
		Name:                     a.Name,
		AccountType:              accountTypeToProto(a.AccountType),
		Category:                 accountCategoryToProto(a.Category),
		CurrencyCode:             a.CurrencyCode,
		InitialBalanceCents:      a.InitialBalanceCents,
		CurrentBalanceCents:      a.CurrentBalanceCents,
		Ownership:                ownershipToProto(a.Ownership),
		Icon:                     a.Icon,
		Color:                    a.Color,
		ChartCode:                a.ChartCode,
		IsSystem:                 a.IsSystem,
		SortOrder:                int32(a.SortOrder),
		Institution:              a.Institution,
		CreditLimitCents:         a.CreditLimitCents,
		CardNumberTail:           optStr(a.CardNumberTail),
		Notes:                    optStr(a.Notes),
		OpeningDate:              optTs(a.OpeningDate),
		InterestRate:             a.InterestRate,
		CreditBillingDay:         intToI32(a.CreditBillingDay),
		CreditRepaymentDay:       intToI32(a.CreditRepaymentDay),
		CreditAnnualFeeCents:     a.CreditAnnualFeeCents,
		InvestCostCents:          a.InvestCostCents,
		InvestMarketValueCents:   a.InvestMarketValueCents,
		InvestReturnYtd:          a.InvestReturnYtd,
		FixedPrincipalCents:      a.FixedPrincipalCents,
		FixedStartDate:           optTs(a.FixedStartDate),
		FixedMaturityDate:        optTs(a.FixedMaturityDate),
		FixedTermMonths:          intToI32(a.FixedTermMonths),
		GoldProductType:          optStr(a.GoldProductType),
		GoldQuantity:             a.GoldQuantity,
		GoldBuyPriceCents:        a.GoldBuyPriceCents,
		GoldCurrentPriceCents:    a.GoldCurrentPriceCents,
		EstatePurchasePriceCents: a.EstatePurchasePriceCents,
		EstateCurrentValueCents:  a.EstateCurrentValueCents,
		EstatePurchaseDate:       optTs(a.EstatePurchaseDate),
		EstateDepreciationRate:   a.EstateDepreciationRate,
		LoanOriginalCents:        a.LoanOriginalCents,
		LoanRemainingCents:       a.LoanRemainingCents,
		LoanMonthlyCents:         a.LoanMonthlyCents,
		LoanNextPaymentDate:      optTs(a.LoanNextPaymentDate),
		Status:                   accountStatusToProto(a.Status),
		Version:                  a.Version,
		CreatedAt:                timestamppb.New(a.CreatedAt),
		UpdatedAt:                timestamppb.New(a.UpdatedAt),
	}
	if a.ParentID != nil {
		dto.ParentId = a.ParentID.String()
	}
	return dto
}

func protoToAccountType(t pb.AccountType) domain.AccountType {
	switch t {
	case pb.AccountType_ACCOUNT_TYPE_ASSET:
		return domain.AccountTypeAsset
	case pb.AccountType_ACCOUNT_TYPE_LIABILITY:
		return domain.AccountTypeLiability
	case pb.AccountType_ACCOUNT_TYPE_EQUITY:
		return domain.AccountTypeEquity
	case pb.AccountType_ACCOUNT_TYPE_INCOME:
		return domain.AccountTypeIncome
	case pb.AccountType_ACCOUNT_TYPE_EXPENSE:
		return domain.AccountTypeExpense
	default:
		return domain.AccountTypeAsset
	}
}

func accountTypeToProto(t domain.AccountType) pb.AccountType {
	switch t {
	case domain.AccountTypeAsset:
		return pb.AccountType_ACCOUNT_TYPE_ASSET
	case domain.AccountTypeLiability:
		return pb.AccountType_ACCOUNT_TYPE_LIABILITY
	case domain.AccountTypeEquity:
		return pb.AccountType_ACCOUNT_TYPE_EQUITY
	case domain.AccountTypeIncome:
		return pb.AccountType_ACCOUNT_TYPE_INCOME
	case domain.AccountTypeExpense:
		return pb.AccountType_ACCOUNT_TYPE_EXPENSE
	default:
		return pb.AccountType_ACCOUNT_TYPE_UNSPECIFIED
	}
}

func protoToAccountCategory(c pb.AccountCategory) domain.AccountCategory {
	switch c {
	case pb.AccountCategory_ACCOUNT_CATEGORY_CREDIT_CARD:
		return domain.AccountCategoryCreditCard
	case pb.AccountCategory_ACCOUNT_CATEGORY_INVESTMENT:
		return domain.AccountCategoryInvestment
	case pb.AccountCategory_ACCOUNT_CATEGORY_FIXED_DEPOSIT:
		return domain.AccountCategoryFixedDeposit
	case pb.AccountCategory_ACCOUNT_CATEGORY_GOLD_FX:
		return domain.AccountCategoryGoldFx
	case pb.AccountCategory_ACCOUNT_CATEGORY_REAL_ESTATE:
		return domain.AccountCategoryRealEstate
	case pb.AccountCategory_ACCOUNT_CATEGORY_LOAN:
		return domain.AccountCategoryLoan
	case pb.AccountCategory_ACCOUNT_CATEGORY_OTHER_ASSET:
		return domain.AccountCategoryOtherAsset
	case pb.AccountCategory_ACCOUNT_CATEGORY_OTHER_LIABILITY:
		return domain.AccountCategoryOtherLiability
	default:
		return domain.AccountCategorySavings
	}
}

func accountCategoryToProto(c domain.AccountCategory) pb.AccountCategory {
	switch c {
	case domain.AccountCategoryCreditCard:
		return pb.AccountCategory_ACCOUNT_CATEGORY_CREDIT_CARD
	case domain.AccountCategoryInvestment:
		return pb.AccountCategory_ACCOUNT_CATEGORY_INVESTMENT
	case domain.AccountCategoryFixedDeposit:
		return pb.AccountCategory_ACCOUNT_CATEGORY_FIXED_DEPOSIT
	case domain.AccountCategoryGoldFx:
		return pb.AccountCategory_ACCOUNT_CATEGORY_GOLD_FX
	case domain.AccountCategoryRealEstate:
		return pb.AccountCategory_ACCOUNT_CATEGORY_REAL_ESTATE
	case domain.AccountCategoryLoan:
		return pb.AccountCategory_ACCOUNT_CATEGORY_LOAN
	case domain.AccountCategoryOtherAsset:
		return pb.AccountCategory_ACCOUNT_CATEGORY_OTHER_ASSET
	case domain.AccountCategoryOtherLiability:
		return pb.AccountCategory_ACCOUNT_CATEGORY_OTHER_LIABILITY
	default:
		return pb.AccountCategory_ACCOUNT_CATEGORY_SAVINGS
	}
}

func protoToOwnership(o pb.Ownership) domain.Ownership {
	if o == pb.Ownership_OWNERSHIP_JOINT {
		return domain.OwnershipJoint
	}
	return domain.OwnershipPersonal
}

func ownershipToProto(o domain.Ownership) pb.Ownership {
	if o == domain.OwnershipJoint {
		return pb.Ownership_OWNERSHIP_JOINT
	}
	return pb.Ownership_OWNERSHIP_PERSONAL
}

func protoToAccountStatus(s pb.AccountStatus) domain.AccountStatus {
	if s == pb.AccountStatus_ACCOUNT_STATUS_ARCHIVED {
		return domain.AccountStatusArchived
	}
	return domain.AccountStatusActive
}

func accountStatusToProto(s domain.AccountStatus) pb.AccountStatus {
	if s == domain.AccountStatusArchived {
		return pb.AccountStatus_ACCOUNT_STATUS_ARCHIVED
	}
	return pb.AccountStatus_ACCOUNT_STATUS_ACTIVE
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
	case contains(msg, "must not be empty"), contains(msg, "invalid"), contains(msg, "not a category account"):
		return status.Error(codes.InvalidArgument, msg)
	case contains(msg, "optimistic lock"):
		return status.Error(codes.Aborted, msg)
	case contains(msg, "non-zero balance"), contains(msg, "system category"):
		return status.Error(codes.FailedPrecondition, msg)
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
