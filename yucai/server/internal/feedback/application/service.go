package application

import (
	"context"
	"log/slog"

	"github.com/yucai/server/internal/feedback/domain"
)

// Service orchestrates feedback submissions.
type Service struct {
	repo domain.FeedbackRepository
}

// NewService creates a new feedback application service.
func NewService(repo domain.FeedbackRepository) *Service {
	return &Service{repo: repo}
}

// SubmitFeedbackInput is the application-level command for a submission.
// Type is the domain feedback type string (issue/idea/other).
type SubmitFeedbackInput struct {
	Type        string
	Body        string
	Contact     string
	AppVersion  string
	Platform    string
	AccountMode string
	ThemeMode   string
}

// SubmitFeedback validates the input, persists it, and returns the stored
// row's database ID.
func (s *Service) SubmitFeedback(ctx context.Context, in SubmitFeedbackInput) (int64, error) {
	f, err := domain.SubmitFeedback(domain.SubmitFeedbackCommand{
		Type:        domain.FeedbackType(in.Type),
		Body:        in.Body,
		Contact:     in.Contact,
		AppVersion:  in.AppVersion,
		Platform:    in.Platform,
		AccountMode: in.AccountMode,
		ThemeMode:   in.ThemeMode,
	})
	if err != nil {
		return 0, err
	}
	if err := s.repo.Create(ctx, f); err != nil {
		return 0, err
	}
	slog.Info("feedback submitted", "id", f.ID, "type", string(f.Type))
	return f.ID, nil
}
