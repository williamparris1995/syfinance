package grpc

import (
	"context"
	"time"

	"github.com/google/uuid"
	accountdomain "github.com/yucai/server/internal/account/domain"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/holding/application"
	"github.com/yucai/server/internal/holding/domain"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	pb "github.com/yucai/server/internal/proto/holding/v1"
	txnApp "github.com/yucai/server/internal/transaction/application"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

type HoldingHandler struct {
	pb.UnimplementedHoldingServiceServer
	service       *application.Service
	accountLookup txnApp.AccountLookup // from_account lookup + balance validation; nil = skip validation + skip cash double-write (test/perf path)
}

func NewHoldingHandler(service *application.Service, accountLookup txnApp.AccountLookup) *HoldingHandler {
	return &HoldingHandler{service: service, accountLookup: accountLookup}
}

func (h *HoldingHandler) CreateSecurity(ctx context.Context, req *pb.CreateSecurityRequest) (*pb.SecurityResponse, error) {
	resp, err := h.service.CreateSecurity(ctx, application.CreateSecurityRequest{
		Symbol: req.Symbol, Name: req.Name,
		SecurityType: protoToSecType(req.SecurityType),
		Exchange:     req.Exchange, CurrencyCode: req.CurrencyCode,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.SecurityResponse{Security: secToProto(*resp)}, nil
}

func (h *HoldingHandler) ListSecurities(ctx context.Context, req *pb.ListSecuritiesRequest) (*pb.ListSecuritiesResponse, error) {
	var st *domain.SecurityType
	if req.SecurityType != pb.SecurityType_SECURITY_TYPE_UNSPECIFIED {
		t := protoToSecType(req.SecurityType)
		st = &t
	}
	page := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		page.PageSize = req.Page.PageSize
		page.PageToken = req.Page.PageToken
	}
	result, err := h.service.ListSecurities(ctx, st, page)
	if err != nil {
		return nil, mapError(err)
	}
	securities := make([]*pb.SecurityDTO, len(result.Securities))
	for i, s := range result.Securities {
		securities[i] = secToProto(s)
	}
	return &pb.ListSecuritiesResponse{Securities: securities, Page: &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount}}, nil
}

func (h *HoldingHandler) UpdateSecurityPrice(ctx context.Context, req *pb.UpdatePriceRequest) (*emptypb.Empty, error) {
	id, _ := uuid.Parse(req.SecurityId)
	if err := h.service.UpdateSecurityPrice(ctx, id, req.PriceCents); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

func (h *HoldingHandler) SearchSecurities(ctx context.Context, req *pb.SearchSecuritiesRequest) (*pb.SearchSecuritiesResponse, error) {
	limit := int(req.Limit)
	if limit <= 0 {
		limit = 20
	}
	dtos, err := h.service.SearchSecurities(ctx, req.Query, limit)
	if err != nil {
		return nil, mapError(err)
	}
	securities := make([]*pb.SecurityDTO, len(dtos))
	for i, s := range dtos {
		securities[i] = secToProto(s)
	}
	return &pb.SearchSecuritiesResponse{Securities: securities}, nil
}

func (h *HoldingHandler) BuyHolding(ctx context.Context, req *pb.HoldingTradeRequest) (*pb.HoldingTransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	fromAccountID, err := uuid.Parse(req.FromAccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid from_account_id")
	}
	holdingAccountID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}
	td, _ := parseDate(req.TradeDate)
	// amount = priceCents × quantity (double-write 金额，与 service AmountCents 一致)。
	amountCents := application.TradeAmountCents(req.PriceCents, req.Quantity)

	fromAcc, holdAcc, err := h.validateTradeFromAccount(ctx, tenantID, fromAccountID, holdingAccountID, amountCents, true /*buy*/)
	if err != nil {
		return nil, err
	}

	resp, err := h.service.BuyHolding(ctx, application.HoldingTradeRequest{
		TenantID: tenantID, AccountID: holdingAccountID,
		SecurityID: parseUUID(req.SecurityId), Quantity: req.Quantity,
		PriceCents: req.PriceCents, FeeCents: req.FeeCents,
		TradeDate: td, Notes: req.Notes,
		CashRecord: buildTradeCashRecord(tenantID, fromAcc, holdAcc, domain.TradeTypeBuy, amountCents),
	})
	if err != nil {
		return nil, mapError(err)
	}

	return &pb.HoldingTransactionResponse{Transaction: tradeToProto(*resp)}, nil
}

func (h *HoldingHandler) SellHolding(ctx context.Context, req *pb.HoldingTradeRequest) (*pb.HoldingTransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	fromAccountID, err := uuid.Parse(req.FromAccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid from_account_id")
	}
	holdingAccountID, err := uuid.Parse(req.AccountId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid account_id")
	}
	td, _ := parseDate(req.TradeDate)
	// amount = priceCents × quantity (double-write 金额，与 service AmountCents 一致)。
	amountCents := application.TradeAmountCents(req.PriceCents, req.Quantity)

	// sell: from 不查余额(现金入账),isBuy=false。
	fromAcc, holdAcc, err := h.validateTradeFromAccount(ctx, tenantID, fromAccountID, holdingAccountID, amountCents, false /*sell*/)
	if err != nil {
		return nil, err
	}

	resp, err := h.service.SellHolding(ctx, application.HoldingTradeRequest{
		TenantID: tenantID, AccountID: holdingAccountID,
		SecurityID: parseUUID(req.SecurityId), Quantity: req.Quantity,
		PriceCents: req.PriceCents, FeeCents: req.FeeCents,
		TradeDate: td, Notes: req.Notes,
		CashRecord: buildTradeCashRecord(tenantID, fromAcc, holdAcc, domain.TradeTypeSell, amountCents),
	})
	if err != nil {
		return nil, mapError(err)
	}

	return &pb.HoldingTransactionResponse{Transaction: tradeToProto(*resp)}, nil
}

func (h *HoldingHandler) RecordDividend(ctx context.Context, req *pb.RecordDividendRequest) (*pb.HoldingTransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	td, _ := parseDate(req.TradeDate)
	resp, err := h.service.RecordDividend(ctx, application.RecordDividendRequest{
		TenantID: tenantID, AccountID: parseUUID(req.AccountId),
		SecurityID: parseUUID(req.SecurityId), Quantity: req.Quantity,
		CashPerShareCents: req.CashPerShareCents, TotalAmountCents: req.TotalAmountCents,
		TradeDate: td, Notes: req.Notes,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.HoldingTransactionResponse{Transaction: tradeToProto(*resp)}, nil
}

func (h *HoldingHandler) RecordSplit(ctx context.Context, req *pb.RecordSplitRequest) (*pb.HoldingTransactionResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	sd, _ := parseDate(req.SplitDate)
	resp, err := h.service.RecordSplit(ctx, application.RecordSplitRequest{
		TenantID: tenantID, AccountID: parseUUID(req.AccountId),
		SecurityID: parseUUID(req.SecurityId), Ratio: req.Ratio,
		SplitDate: sd, Notes: req.Notes,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.HoldingTransactionResponse{Transaction: tradeToProto(*resp)}, nil
}

func (h *HoldingHandler) ListHoldings(ctx context.Context, req *pb.ListHoldingsRequest) (*pb.ListHoldingsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	var acctID *uuid.UUID
	if req.AccountId != "" {
		id := parseUUID(req.AccountId)
		acctID = &id
	}
	page := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		page.PageSize = req.Page.PageSize
		page.PageToken = req.Page.PageToken
	}
	result, err := h.service.ListHoldings(ctx, tenantID, acctID, page)
	if err != nil {
		return nil, mapError(err)
	}
	holdings := make([]*pb.HoldingDTO, len(result.Holdings))
	for i, h := range result.Holdings {
		holdings[i] = holdingToProto(h)
	}
	return &pb.ListHoldingsResponse{Holdings: holdings, Page: &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount}}, nil
}

func (h *HoldingHandler) ListHoldingTransactions(ctx context.Context, req *pb.ListTradesRequest) (*pb.ListTradesResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	var acctID, secID *uuid.UUID
	if req.AccountId != "" {
		id := parseUUID(req.AccountId)
		acctID = &id
	}
	if req.SecurityId != "" {
		id := parseUUID(req.SecurityId)
		secID = &id
	}
	page := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		page.PageSize = req.Page.PageSize
		page.PageToken = req.Page.PageToken
	}
	result, err := h.service.ListHoldingTransactions(ctx, tenantID, acctID, secID, page)
	if err != nil {
		return nil, mapError(err)
	}
	trades := make([]*pb.HoldingTransactionDTO, len(result.Trades))
	for i, tr := range result.Trades {
		trades[i] = tradeToProto(tr)
	}
	return &pb.ListTradesResponse{Trades: trades, Page: &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount}}, nil
}

// SyncPrices triggers a manual price refresh of all securities via the
// application service (which routes to the configured price provider).
// Prices are security master data (tenant-shared), so we authenticate the
// caller but do not filter by tenant.
func (h *HoldingHandler) SyncPrices(ctx context.Context, _ *pb.SyncPricesRequest) (*pb.SyncPricesResponse, error) {
	if _, err := getTenantID(ctx); err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	count, err := h.service.SyncPrices(ctx)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.SyncPricesResponse{
		SyncedCount: int32(count),
		SyncedAt:    timestamppb.Now(),
	}, nil
}

// GetPortfolioPerformance builds the portfolio market-value curve + foot
// (realized/unrealized/total/annualized), optionally with the CSI300 benchmark
// curve. account_id is optional (empty = all accounts under the tenant).
// base_currency (optional) converts all amounts into that currency; empty falls
// back to the tenant base currency (default CNY).
func (h *HoldingHandler) GetPortfolioPerformance(ctx context.Context, req *pb.GetPortfolioPerformanceRequest) (*pb.PortfolioPerformanceResponse, error) {
	tid, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	var acct *uuid.UUID
	if req.GetAccountId() != "" {
		a, err := uuid.Parse(req.GetAccountId())
		if err != nil {
			return nil, status.Error(codes.InvalidArgument, "invalid account_id")
		}
		acct = &a
	}
	perf, err := h.service.GetPortfolioPerformance(ctx, tid, acct, curveRangeName(req.GetRange()), req.GetIncludeBenchmark(), req.GetBaseCurrency())
	if err != nil {
		return nil, mapError(err)
	}
	// AnnualizedPct / RangeAnnualizedPct are *float64 (nil = degraded XIRR).
	// Proto optional (Task 5) accepts the pointer directly — nil round-trips
	// as field-absent across the wire, distinguishing degraded vs 0.0%.
	return &pb.PortfolioPerformanceResponse{
		PortfolioPoints:        curvePointsToProto(perf.PortfolioPoints),
		BenchmarkPoints:        curvePointsToProto(perf.BenchmarkPoints),
		BenchmarkName:          perf.BenchmarkName,
		RealizedCents:          perf.RealizedCents,
		UnrealizedCents:        perf.UnrealizedCents,
		TotalCents:             perf.TotalCents,
		AnnualizedPct:          perf.AnnualizedPct,
		RangeAnnualizedPct:     perf.RangeAnnualizedPct,
		TwrAnnualizedPct:       perf.TwrAnnualizedPct,
		RangeTwrAnnualizedPct:  perf.RangeTwrAnnualizedPct,
		CagrAnnualizedPct:      perf.CagrAnnualizedPct,
		RangeCagrAnnualizedPct: perf.RangeCagrAnnualizedPct,
		// 主指标语义(audit 06 决策 1):本地枚举值序与 pb 对齐,直转。
		PrimaryReturnMetric: pb.ReturnMetric(perf.PrimaryReturnMetric).Enum(),
		CagrScope:           pb.CagrScope(perf.CagrScope).Enum(),
		TotalPct:            perf.TotalPct,
		Currency:            perf.Currency,
	}, nil
}

// GetHoldingPerformance builds a single-holding original-currency price curve
// + foot (realized/unrealized/total). holding_id is required. The holding is
// resolved tenant-scoped: a holding_id owned by another tenant returns NotFound
// (no existence leak) — the tid captured here is threaded through to the repo.
func (h *HoldingHandler) GetHoldingPerformance(ctx context.Context, req *pb.GetHoldingPerformanceRequest) (*pb.HoldingPerformanceResponse, error) {
	tid, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	hid, err := uuid.Parse(req.GetHoldingId())
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid holding_id")
	}
	perf, err := h.service.GetHoldingPerformance(ctx, tid, hid, curveRangeName(req.GetRange()), req.GetBaseCurrency())
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.HoldingPerformanceResponse{
		PricePoints:            curvePointsToProto(perf.PricePoints),
		RealizedCents:          perf.RealizedCents,
		UnrealizedCents:        perf.UnrealizedCents,
		TotalCents:             perf.TotalCents,
		Currency:               perf.Currency,
		AnnualizedPct:          perf.AnnualizedPct,
		RangeAnnualizedPct:     perf.RangeAnnualizedPct,
		TwrAnnualizedPct:       perf.TwrAnnualizedPct,
		CagrAnnualizedPct:      perf.CagrAnnualizedPct,
		RangeCagrAnnualizedPct: perf.RangeCagrAnnualizedPct,
	}, nil
}

// BackfillPriceHistory manually backfills historical daily K-line for every
// Sina-covered security that does not yet have history for the given range.
// Returns the count of securities whose history was fetched.
func (h *HoldingHandler) BackfillPriceHistory(ctx context.Context, req *pb.BackfillPriceHistoryRequest) (*pb.BackfillPriceHistoryResponse, error) {
	if _, err := getTenantID(ctx); err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	count, err := h.service.BackfillPriceHistory(ctx, curveRangeName(req.GetRange()))
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.BackfillPriceHistoryResponse{BackfilledCount: int32(count)}, nil
}

// curveRangeName maps the proto CurveRange enum to the service's range string.
// UNSPECIFIED/DAY both fall back to "DAY".
func curveRangeName(r pb.CurveRange) string {
	switch r {
	case pb.CurveRange_CURVE_RANGE_MONTH:
		return "MONTH"
	case pb.CurveRange_CURVE_RANGE_YEAR:
		return "YEAR"
	default:
		return "DAY"
	}
}

// curvePointsToProto maps []CurvePointDTO → []*pb.CurvePoint.
func curvePointsToProto(pts []application.CurvePointDTO) []*pb.CurvePoint {
	out := make([]*pb.CurvePoint, 0, len(pts))
	for _, p := range pts {
		out = append(out, &pb.CurvePoint{
			Time:  timestamppb.New(p.Time),
			Value: p.Value,
		})
	}
	return out
}

func secToProto(s application.SecurityDTO) *pb.SecurityDTO {
	return &pb.SecurityDTO{
		Id: s.ID.String(), Symbol: s.Symbol, Name: s.Name,
		SecurityType: secTypeToProto(s.SecurityType), Exchange: s.Exchange,
		CurrencyCode: s.CurrencyCode, CurrentPriceCents: s.CurrentPriceCents,
		CreatedAt: timestamppb.New(s.CreatedAt),
	}
}

func holdingToProto(h application.HoldingDTO) *pb.HoldingDTO {
	return &pb.HoldingDTO{
		Id: h.ID.String(), AccountId: h.AccountID.String(),
		SecurityId: h.SecurityID.String(), SecurityName: h.SecurityName,
		SecuritySymbol: h.SecuritySymbol, Quantity: h.Quantity,
		AvgCostCents: h.AvgCostCents, MarketValueCents: h.MarketValueCents,
		UnrealizedPnlCents: h.UnrealizedPnL, Version: h.Version,
	}
}

func tradeToProto(tr application.HoldingTransactionDTO) *pb.HoldingTransactionDTO {
	return &pb.HoldingTransactionDTO{
		Id: tr.ID.String(), AccountId: tr.AccountID.String(),
		SecurityId: tr.SecurityID.String(), TradeType: tradeTypeToProto(tr.TradeType),
		Quantity: tr.Quantity, PriceCents: tr.PriceCents,
		AmountCents: tr.AmountCents, FeeCents: tr.FeeCents,
		TradeDate: tr.TradeDate.Format("2006-01-02"), Notes: tr.Notes,
		CreatedAt: timestamppb.New(tr.CreatedAt),
	}
}

func protoToSecType(t pb.SecurityType) domain.SecurityType {
	m := map[pb.SecurityType]domain.SecurityType{
		pb.SecurityType_SECURITY_TYPE_STOCK:  domain.SecurityTypeStock,
		pb.SecurityType_SECURITY_TYPE_FUND:   domain.SecurityTypeFund,
		pb.SecurityType_SECURITY_TYPE_ETF:    domain.SecurityTypeETF,
		pb.SecurityType_SECURITY_TYPE_BOND:   domain.SecurityTypeBond,
		pb.SecurityType_SECURITY_TYPE_GOLD:   domain.SecurityTypeGold,
		pb.SecurityType_SECURITY_TYPE_OPTION: domain.SecurityTypeOption,
		pb.SecurityType_SECURITY_TYPE_OTHER:  domain.SecurityTypeOther,
	}
	if v, ok := m[t]; ok {
		return v
	}
	return domain.SecurityTypeStock
}

func secTypeToProto(t domain.SecurityType) pb.SecurityType {
	m := map[domain.SecurityType]pb.SecurityType{
		domain.SecurityTypeStock:  pb.SecurityType_SECURITY_TYPE_STOCK,
		domain.SecurityTypeFund:   pb.SecurityType_SECURITY_TYPE_FUND,
		domain.SecurityTypeETF:    pb.SecurityType_SECURITY_TYPE_ETF,
		domain.SecurityTypeBond:   pb.SecurityType_SECURITY_TYPE_BOND,
		domain.SecurityTypeGold:   pb.SecurityType_SECURITY_TYPE_GOLD,
		domain.SecurityTypeOption: pb.SecurityType_SECURITY_TYPE_OPTION,
		domain.SecurityTypeOther:  pb.SecurityType_SECURITY_TYPE_OTHER,
	}
	if v, ok := m[t]; ok {
		return v
	}
	return pb.SecurityType_SECURITY_TYPE_UNSPECIFIED
}

func tradeTypeToProto(t domain.TradeType) pb.TradeType {
	m := map[domain.TradeType]pb.TradeType{
		domain.TradeTypeBuy:      pb.TradeType_TRADE_TYPE_BUY,
		domain.TradeTypeSell:     pb.TradeType_TRADE_TYPE_SELL,
		domain.TradeTypeDividend: pb.TradeType_TRADE_TYPE_DIVIDEND,
		domain.TradeTypeSplit:    pb.TradeType_TRADE_TYPE_SPLIT,
	}
	if v, ok := m[t]; ok {
		return v
	}
	return pb.TradeType_TRADE_TYPE_UNSPECIFIED
}

func parseDate(s string) (time.Time, error) { return time.Parse("2006-01-02", s) }
func parseUUID(s string) uuid.UUID          { id, _ := uuid.Parse(s); return id }

func getTenantID(ctx context.Context) (uuid.UUID, error) {
	_, tenantID, err := authgrpc.GetUserAndTenantIDFromContext(ctx)
	return tenantID, err
}

func mapError(err error) error {
	msg := err.Error()
	if contains(msg, "not found") {
		return status.Error(codes.NotFound, msg)
	}
	if contains(msg, "invalid") || contains(msg, "must") {
		return status.Error(codes.InvalidArgument, msg)
	}
	if contains(msg, "cannot sell") {
		return status.Error(codes.FailedPrecondition, msg)
	}
	return status.Error(codes.Internal, msg)
}

func contains(s, sub string) bool {
	for i := 0; i <= len(s)-len(sub); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}

// validateTradeFromAccount reads the from_account + holding account and enforces
// the holding-trade invariants BEFORE the trade is recorded, so an invalid
// from_account fails fast. Returns both fetched accounts so the caller can build
// the cash-side double-entry pair without a redundant lookup.
//
//  1. from_account must exist (NotFound).
//  2. from_account must be asset (InvalidArgument).
//  3. from_account must differ from holding account (InvalidArgument — no self).
//  4. from + holding accounts share currency (InvalidArgument).
//  5. buy: from balance >= amount (FailedPrecondition). sell: 不查余额(现金入账)。
//
// When h.accountLookup is nil the validation is skipped and the returned
// accounts are both nil — the caller then leaves CashRecord unset so the
// service-side cash double-write is skipped (test/perf path).
func (h *HoldingHandler) validateTradeFromAccount(ctx context.Context, tenantID, fromAccountID, holdingAccountID uuid.UUID, amountCents int64, isBuy bool) (*accountdomain.Account, *accountdomain.Account, error) {
	if h.accountLookup == nil {
		return nil, nil, nil
	}
	fromAcc, err := h.accountLookup.FindByID(ctx, tenantID, fromAccountID)
	if err != nil {
		return nil, nil, status.Error(codes.NotFound, "from_account not found: "+err.Error())
	}
	if fromAcc.AccountType != accountdomain.AccountTypeAsset {
		return nil, nil, status.Error(codes.InvalidArgument, "from_account must be asset")
	}
	if fromAccountID == holdingAccountID {
		return nil, nil, status.Error(codes.InvalidArgument, "from_account must differ from holding account")
	}
	holdAcc, err := h.accountLookup.FindByID(ctx, tenantID, holdingAccountID)
	if err != nil {
		return nil, nil, status.Error(codes.NotFound, "holding account not found: "+err.Error())
	}
	if fromAcc.CurrencyCode != holdAcc.CurrencyCode {
		return nil, nil, status.Error(codes.InvalidArgument, "cross-currency, manual handling required")
	}
	if isBuy && fromAcc.CurrentBalanceCents < amountCents {
		return nil, nil, status.Error(codes.FailedPrecondition, "from_account balance insufficient")
	}
	return fromAcc, holdAcc, nil
}

// buildTradeCashRecord constructs the holding service's cash-side record request
// for a buy or sell, or returns nil when either account is missing (the
// accountLookup-skipped path — preserves the legacy "no cash double-write"
// behavior for tests/perf harnesses that wire NewHoldingHandler with nil
// accountLookup). The service enlists this record inside its sqltx.WithTx so
// the cash legs and the trade commit or roll back together (D2 atomicity).
func buildTradeCashRecord(tenantID uuid.UUID, fromAcc, holdAcc *accountdomain.Account, tradeType domain.TradeType, amountCents int64) *domain.TradeCashRecordRequest {
	if fromAcc == nil || holdAcc == nil {
		return nil
	}
	return &domain.TradeCashRecordRequest{
		TenantID:        tenantID,
		TransactionDate: time.Now(),
		Description:     "Holding trade double-write",
		Entries:         buildTradeEntries(tradeType, *fromAcc, *holdAcc, amountCents),
	}
}

// buildTradeEntries constructs the buy/sell double-entry pair for a holding trade.
// amountCents is the trade AmountCents (priceCents × quantity).
//
//	buy:  credit from_account (cash −)   + debit  holding.account (investment +)
//	sell: debit  from_account (cash +)   + credit holding.account (investment −)
//
// Each entry carries the account's ChartOfAccountCode so the transaction
// service can persist and route it correctly.
func buildTradeEntries(tradeType domain.TradeType, fromAcc, holdingAcc accountdomain.Account, amountCents int64) []domain.TradeCashEntry {
	if tradeType == domain.TradeTypeSell {
		return []domain.TradeCashEntry{
			{AccountID: fromAcc.ID, ChartOfAccountCode: fromAcc.ChartCode, DebitCents: amountCents},
			{AccountID: holdingAcc.ID, ChartOfAccountCode: holdingAcc.ChartCode, CreditCents: amountCents},
		}
	}
	// Buy (and default).
	return []domain.TradeCashEntry{
		{AccountID: fromAcc.ID, ChartOfAccountCode: fromAcc.ChartCode, CreditCents: amountCents},
		{AccountID: holdingAcc.ID, ChartOfAccountCode: holdingAcc.ChartCode, DebitCents: amountCents},
	}
}

var _ = time.Time{}
