package repository

import (
	"context"
	"fmt"

	"github.com/yucai/server/internal/feedback/domain"
	feedbackent "github.com/yucai/server/internal/feedback/ent"
)

// FeedbackRepository implements domain.FeedbackRepository.
type FeedbackRepository struct {
	client *feedbackent.Client
}

// NewFeedbackRepository creates a new FeedbackRepository.
func NewFeedbackRepository(client *feedbackent.Client) *FeedbackRepository {
	return &FeedbackRepository{client: client}
}

// Create persists the feedback row and writes the database-assigned
// auto-increment ID back onto the entity.
func (r *FeedbackRepository) Create(ctx context.Context, f *domain.Feedback) error {
	row, err := r.client.Feedback.Create().
		SetType(string(f.Type)).
		SetBody(f.Body).
		SetContact(f.Contact).
		SetAppVersion(f.AppVersion).
		SetPlatform(f.Platform).
		SetAccountMode(f.AccountMode).
		SetThemeMode(f.ThemeMode).
		SetCreatedAt(f.CreatedAt).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("create feedback: %w", err)
	}
	f.ID = int64(row.ID)
	return nil
}
