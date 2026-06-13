package grpc

import (
	"context"

	pb "github.com/yucai/server/internal/proto/category/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/category/application"
	"github.com/yucai/server/internal/category/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// CategoryHandler implements the generated CategoryServiceServer interface.
type CategoryHandler struct {
	pb.UnimplementedCategoryServiceServer
	service *application.Service
}

// NewCategoryHandler creates a new CategoryHandler.
func NewCategoryHandler(service *application.Service) *CategoryHandler {
	return &CategoryHandler{service: service}
}

// CreateCategory creates a new category.
func (h *CategoryHandler) CreateCategory(ctx context.Context, req *pb.CreateCategoryRequest) (*pb.CategoryResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	var parentID *uuid.UUID
	if req.ParentId != "" {
		pid := parseUUID(req.ParentId)
		parentID = &pid
	}

	result, err := h.service.CreateCategory(ctx, tenantID, application.CreateCategoryRequest{
		Name: req.Name, CategoryType: protoToType(req.CategoryType),
		Icon: req.Icon, Color: req.Color, ParentID: parentID,
		SortOrder: req.SortOrder,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.CategoryResponse{Category: dtoToProto(*result)}, nil
}

// UpdateCategory updates an existing category.
func (h *CategoryHandler) UpdateCategory(ctx context.Context, req *pb.UpdateCategoryRequest) (*pb.CategoryResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	id := parseUUID(req.Id)
	if id == uuid.Nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	result, err := h.service.UpdateCategory(ctx, tenantID, application.UpdateCategoryRequest{
		ID: id, Name: req.Name, Icon: req.Icon, Color: req.Color,
		SortOrder: req.SortOrder, Version: req.Version,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.CategoryResponse{Category: dtoToProto(*result)}, nil
}

// DeleteCategory soft-deletes a category.
func (h *CategoryHandler) DeleteCategory(ctx context.Context, req *pb.DeleteCategoryRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	id := parseUUID(req.Id)
	if id == uuid.Nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	if err := h.service.DeleteCategory(ctx, tenantID, id); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// GetCategory retrieves a single category.
func (h *CategoryHandler) GetCategory(ctx context.Context, req *pb.GetCategoryRequest) (*pb.CategoryResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}
	id := parseUUID(req.Id)
	if id == uuid.Nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	result, err := h.service.GetCategory(ctx, tenantID, id)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.CategoryResponse{Category: dtoToProto(*result)}, nil
}

// ListCategories returns paginated categories.
func (h *CategoryHandler) ListCategories(ctx context.Context, req *pb.ListCategoriesRequest) (*pb.ListCategoriesResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, err
	}

	var ct *domain.CategoryType
	if req.CategoryType != pb.CategoryType_CATEGORY_TYPE_UNSPECIFIED {
		t := protoToType(req.CategoryType)
		ct = &t
	}

	page := domain.PageRequest{PageSize: 50}
	if req.Page != nil {
		page.PageSize = req.Page.PageSize
		page.PageToken = req.Page.PageToken
	}

	result, err := h.service.ListCategories(ctx, tenantID, ct, req.Search, page)
	if err != nil {
		return nil, mapError(err)
	}

	categories := make([]*pb.CategoryDTO, len(result.Categories))
	for i, c := range result.Categories {
		categories[i] = dtoToProto(c)
	}

	return &pb.ListCategoriesResponse{
		Categories: categories,
		Page:       &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount},
	}, nil
}

// --- Helpers ---

func dtoToProto(c application.CategoryDTO) *pb.CategoryDTO {
	dto := &pb.CategoryDTO{
		Id: c.ID.String(), Name: c.Name,
		CategoryType: typeToProto(c.CategoryType),
		Icon: c.Icon, Color: c.Color,
		IsSystem: c.IsSystem, SortOrder: c.SortOrder,
		Version: c.Version, CreatedAt: timestamppb.New(c.CreatedAt),
	}
	if c.ParentID != nil {
		dto.ParentId = c.ParentID.String()
	}
	return dto
}

func protoToType(t pb.CategoryType) domain.CategoryType {
	switch t {
	case pb.CategoryType_CATEGORY_TYPE_INCOME:
		return domain.CategoryTypeIncome
	case pb.CategoryType_CATEGORY_TYPE_EXPENSE:
		return domain.CategoryTypeExpense
	default:
		return 0
	}
}

func typeToProto(t domain.CategoryType) pb.CategoryType {
	switch t {
	case domain.CategoryTypeIncome:
		return pb.CategoryType_CATEGORY_TYPE_INCOME
	case domain.CategoryTypeExpense:
		return pb.CategoryType_CATEGORY_TYPE_EXPENSE
	default:
		return pb.CategoryType_CATEGORY_TYPE_UNSPECIFIED
	}
}

func getTenantID(ctx context.Context) (uuid.UUID, error) {
	_, tenantID, err := authgrpc.GetUserAndTenantIDFromContext(ctx)
	return tenantID, err
}

func parseUUID(s string) uuid.UUID {
	id, _ := uuid.Parse(s)
	return id
}

func mapError(err error) error {
	return status.Errorf(codes.Internal, "category service error: %v", err)
}
