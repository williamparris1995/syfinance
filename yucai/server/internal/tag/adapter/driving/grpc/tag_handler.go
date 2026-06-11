package grpc

import (
	"context"
	"time"

	pb "github.com/yucai/server/internal/proto/tag/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	authgrpc "github.com/yucai/server/internal/auth/adapter/driving/grpc"
	"github.com/yucai/server/internal/tag/application"
	"github.com/yucai/server/internal/tag/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"
	"google.golang.org/protobuf/types/known/timestamppb"
)

// TagHandler implements the generated TagServiceServer.
type TagHandler struct {
	pb.UnimplementedTagServiceServer
	service *application.Service
}

// NewTagHandler creates a new TagHandler.
func NewTagHandler(service *application.Service) *TagHandler {
	return &TagHandler{service: service}
}

// CreateTag creates a new tag.
func (h *TagHandler) CreateTag(ctx context.Context, req *pb.CreateTagRequest) (*pb.TagResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	resp, err := h.service.CreateTag(ctx, application.CreateTagRequest{
		TenantID: tenantID,
		Name:     req.Name,
		Color:    req.Color,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TagResponse{Tag: tagToProto(*resp)}, nil
}

// UpdateTag updates a tag.
func (h *TagHandler) UpdateTag(ctx context.Context, req *pb.UpdateTagRequest) (*pb.TagResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	resp, err := h.service.UpdateTag(ctx, application.UpdateTagRequest{
		TenantID: tenantID,
		ID:       id,
		Name:     req.Name,
		Color:    req.Color,
		Version:  req.Version,
	})
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.TagResponse{Tag: tagToProto(*resp)}, nil
}

// DeleteTag soft-deletes a tag.
func (h *TagHandler) DeleteTag(ctx context.Context, req *pb.DeleteTagRequest) (*emptypb.Empty, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	id, err := uuid.Parse(req.Id)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid id")
	}

	if err := h.service.DeleteTag(ctx, tenantID, id); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// ListTags returns a paginated list of tags.
func (h *TagHandler) ListTags(ctx context.Context, req *pb.ListTagsRequest) (*pb.ListTagsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}

	pageReq := domain.PageRequest{PageSize: 20}
	if req.Page != nil {
		pageReq.PageSize = req.Page.PageSize
		pageReq.PageToken = req.Page.PageToken
	}

	result, err := h.service.ListTags(ctx, application.ListTagsRequest{
		TenantID: tenantID,
		Search:   req.Search,
		Page:     pageReq,
	})
	if err != nil {
		return nil, mapError(err)
	}

	tags := make([]*pb.TagDTO, len(result.Tags))
	for i, t := range result.Tags {
		tags[i] = tagToProto(t)
	}

	return &pb.ListTagsResponse{
		Tags: tags,
		Page: &commonpb.PageResponse{NextPageToken: result.NextPageToken, TotalCount: result.TotalCount},
	}, nil
}

// AddTagToTransaction associates a tag with a transaction.
func (h *TagHandler) AddTagToTransaction(ctx context.Context, req *pb.TagTransactionRequest) (*emptypb.Empty, error) {
	tagID, _ := uuid.Parse(req.TagId)
	txnID, _ := uuid.Parse(req.TransactionId)

	if err := h.service.AddTagToTransaction(ctx, tagID, txnID); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// RemoveTagFromTransaction removes a tag from a transaction.
func (h *TagHandler) RemoveTagFromTransaction(ctx context.Context, req *pb.TagTransactionRequest) (*emptypb.Empty, error) {
	tagID, _ := uuid.Parse(req.TagId)
	txnID, _ := uuid.Parse(req.TransactionId)

	if err := h.service.RemoveTagFromTransaction(ctx, tagID, txnID); err != nil {
		return nil, mapError(err)
	}
	return &emptypb.Empty{}, nil
}

// GetTransactionTags returns all tags for a transaction.
func (h *TagHandler) GetTransactionTags(ctx context.Context, req *pb.GetTransactionTagsRequest) (*pb.ListTagsResponse, error) {
	tenantID, err := getTenantID(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, err.Error())
	}
	txnID, err := uuid.Parse(req.TransactionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid transaction_id")
	}

	result, err := h.service.GetTransactionTags(ctx, tenantID, txnID)
	if err != nil {
		return nil, mapError(err)
	}

	tags := make([]*pb.TagDTO, len(result.Tags))
	for i, t := range result.Tags {
		tags[i] = tagToProto(t)
	}

	return &pb.ListTagsResponse{Tags: tags}, nil
}

func tagToProto(t application.TagDTO) *pb.TagDTO {
	return &pb.TagDTO{
		Id:        t.ID.String(),
		Name:      t.Name,
		Color:     t.Color,
		Version:   t.Version,
		CreatedAt: timestamppb.New(t.CreatedAt),
		UpdatedAt: timestamppb.New(t.UpdatedAt),
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

var _ = time.Time{}
