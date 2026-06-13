package grpc

import (
	"context"

	pb "github.com/yucai/server/internal/proto/currency/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	"github.com/yucai/server/internal/currency/application"
	"github.com/yucai/server/internal/currency/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// CurrencyHandler implements the generated CurrencyServiceServer interface.
// Currency is global — no tenant_id extraction needed.
type CurrencyHandler struct {
	pb.UnimplementedCurrencyServiceServer
	service *application.Service
}

// NewCurrencyHandler creates a new CurrencyHandler.
func NewCurrencyHandler(service *application.Service) *CurrencyHandler {
	return &CurrencyHandler{service: service}
}

// ListCurrencies returns paginated currencies.
func (h *CurrencyHandler) ListCurrencies(ctx context.Context, req *pb.ListCurrenciesRequest) (*pb.ListCurrenciesResponse, error) {
	page := domain.PageRequest{PageSize: 50}
	if req.Page != nil {
		page.PageSize = req.Page.PageSize
		page.PageToken = req.Page.PageToken
	}

	result, err := h.service.ListCurrencies(ctx, req.ActiveOnly, page)
	if err != nil {
		return nil, mapError(err)
	}

	currencies := make([]*pb.CurrencyDTO, len(result.Currencies))
	for i, c := range result.Currencies {
		currencies[i] = dtoToProto(c)
	}

	return &pb.ListCurrenciesResponse{
		Currencies: currencies,
		Page:       &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount},
	}, nil
}

// AddCurrency creates a new currency.
func (h *CurrencyHandler) AddCurrency(ctx context.Context, req *pb.AddCurrencyRequest) (*pb.CurrencyResponse, error) {
	result, err := h.service.AddCurrency(ctx, application.AddCurrencyRequest{
		Code: req.Code, Name: req.Name, Symbol: req.Symbol,
		ExchangeRate: req.ExchangeRate,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.CurrencyResponse{Currency: dtoToProto(*result)}, nil
}

// UpdateExchangeRate updates a currency's rate.
func (h *CurrencyHandler) UpdateExchangeRate(ctx context.Context, req *pb.UpdateRateRequest) (*pb.CurrencyResponse, error) {
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	result, err := h.service.UpdateExchangeRate(ctx, id, req.ExchangeRate)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.CurrencyResponse{Currency: dtoToProto(*result)}, nil
}

// FetchExchangeRate fetches a rate from the external provider.
func (h *CurrencyHandler) FetchExchangeRate(ctx context.Context, req *pb.FetchRateRequest) (*pb.FetchRateResponse, error) {
	rate, err := h.service.FetchExchangeRate(ctx, req.Code)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.FetchRateResponse{Code: req.Code, ExchangeRate: rate}, nil
}

// --- Helpers ---

func dtoToProto(c application.CurrencyDTO) *pb.CurrencyDTO {
	return &pb.CurrencyDTO{
		Id: c.ID.String(), Code: c.Code, Name: c.Name,
		Symbol: c.Symbol, ExchangeRate: c.ExchangeRate, IsActive: c.IsActive,
	}
}

func mapError(err error) error {
	return status.Errorf(codes.Internal, "currency service error: %v", err)
}
