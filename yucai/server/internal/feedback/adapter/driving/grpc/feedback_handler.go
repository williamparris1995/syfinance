package grpc

import (
	"context"
	"errors"
	"net"

	pb "github.com/yucai/server/internal/proto/feedback/v1"
	"github.com/yucai/server/internal/feedback/application"
	"github.com/yucai/server/internal/feedback/domain"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/peer"
	"google.golang.org/grpc/status"
)

// FeedbackHandler implements the generated FeedbackServiceServer interface.
type FeedbackHandler struct {
	pb.UnimplementedFeedbackServiceServer
	service *application.Service
	limiter *FeedbackRateLimiter
}

// NewFeedbackHandler creates a new FeedbackHandler. The limiter bounds
// anonymous abuse (per-IP token bucket) before any work is done.
func NewFeedbackHandler(service *application.Service, limiter *FeedbackRateLimiter) *FeedbackHandler {
	return &FeedbackHandler{service: service, limiter: limiter}
}

// SubmitFeedback accepts an anonymous feedback submission. The rate limit is
// enforced BEFORE validation so junk traffic cannot bypass the cap, and the
// per-IP key comes from the gRPC peer address.
func (h *FeedbackHandler) SubmitFeedback(ctx context.Context, req *pb.SubmitFeedbackRequest) (*pb.SubmitFeedbackResponse, error) {
	if !h.limiter.Allow(peerIPFromContext(ctx)) {
		return nil, status.Error(codes.ResourceExhausted, "feedback rate limit exceeded, retry later")
	}

	in := application.SubmitFeedbackInput{Body: req.Body, Contact: req.Contact}
	if req.Diagnostics != nil {
		in.AppVersion = req.Diagnostics.AppVersion
		in.Platform = req.Diagnostics.Platform
		in.AccountMode = req.Diagnostics.AccountMode
		in.ThemeMode = req.Diagnostics.ThemeMode
	}
	feedbackType, err := protoToDomainType(req.Type)
	if err != nil {
		return nil, err
	}
	in.Type = string(feedbackType)

	id, err := h.service.SubmitFeedback(ctx, in)
	if err != nil {
		return nil, mapError(err)
	}
	return &pb.SubmitFeedbackResponse{Id: id}, nil
}

// --- Helpers ---

// protoToDomainType maps the proto enum to the domain type string. An
// unspecified/unknown value is rejected here so the domain never sees it.
func protoToDomainType(t pb.FeedbackType) (domain.FeedbackType, error) {
	switch t {
	case pb.FeedbackType_ISSUE:
		return domain.FeedbackTypeIssue, nil
	case pb.FeedbackType_IDEA:
		return domain.FeedbackTypeIdea, nil
	case pb.FeedbackType_OTHER:
		return domain.FeedbackTypeOther, nil
	default:
		return "", status.Error(codes.InvalidArgument, domain.ErrInvalidFeedbackType.Error())
	}
}

// peerIPFromContext extracts the caller IP from the gRPC peer. Falls back to
// a shared "unknown" key when the peer is absent (in-process calls) — such
// callers then share one bucket, which is the safe direction (over-limit,
// never under-limit).
func peerIPFromContext(ctx context.Context) string {
	p, ok := peer.FromContext(ctx)
	if !ok || p.Addr == nil {
		return "unknown"
	}
	host, _, err := net.SplitHostPort(p.Addr.String())
	if err != nil {
		return p.Addr.String()
	}
	return host
}

func mapError(err error) error {
	switch {
	case errors.Is(err, domain.ErrInvalidFeedbackType),
		errors.Is(err, domain.ErrEmptyFeedbackBody),
		errors.Is(err, domain.ErrFeedbackBodyTooLong),
		errors.Is(err, domain.ErrContactTooLong),
		errors.Is(err, domain.ErrDiagTooLong):
		return status.Error(codes.InvalidArgument, err.Error())
	default:
		return status.Errorf(codes.Internal, "feedback service error: %v", err)
	}
}
