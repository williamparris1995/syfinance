package domain

import "context"

// FeedbackRepository is the driven port for feedback persistence. Create-only
// by design: submissions are append-only, there is no read/update/delete use
// case on the server yet.
type FeedbackRepository interface {
	// Create persists f and assigns its database-generated ID back onto f.
	Create(ctx context.Context, f *Feedback) error
}
