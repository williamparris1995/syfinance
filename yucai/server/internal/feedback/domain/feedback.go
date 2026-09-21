package domain

import (
	"errors"
	"time"
	"unicode/utf8"
)

// FeedbackType categorizes a feedback submission. Stored as a short string
// (max 8 chars) matching the ent schema column.
type FeedbackType string

const (
	FeedbackTypeIssue FeedbackType = "issue"
	FeedbackTypeIdea  FeedbackType = "idea"
	FeedbackTypeOther FeedbackType = "other"
)

// Length limits for submission fields (runes, not bytes). Diagnostics
// fields share one cap: they are client-supplied free strings surfaced in
// the ops view, so they get a uniform generous bound well below the column
// sizes an abusive payload could otherwise push at the table.
const (
	MaxBodyRunes    = 1000
	MaxContactRunes = 100
	MaxDiagRunes    = 64
)

// Validation sentinel errors. The gRPC edge maps every one of these to
// InvalidArgument; anything else is an unexpected failure.
var (
	ErrInvalidFeedbackType = errors.New("invalid feedback type")
	ErrEmptyFeedbackBody   = errors.New("feedback body must not be empty")
	ErrFeedbackBodyTooLong = errors.New("feedback body exceeds the maximum length")
	ErrContactTooLong      = errors.New("feedback contact exceeds the maximum length")
	ErrDiagTooLong         = errors.New("feedback diagnostics field exceeds the maximum length")
)

// Feedback is a persisted feedback submission. It is intentionally NOT
// tenant-scoped: submissions are anonymous by design (guest mode included),
// so the entity and its table carry no tenant reference.
type Feedback struct {
	ID          int64
	Type        FeedbackType
	Body        string
	Contact     string
	AppVersion  string
	Platform    string
	AccountMode string
	ThemeMode   string
	CreatedAt   time.Time
}

// SubmitFeedbackCommand carries the validated input for a submission.
type SubmitFeedbackCommand struct {
	Type        FeedbackType
	Body        string
	Contact     string
	AppVersion  string
	Platform    string
	AccountMode string
	ThemeMode   string
}

// SubmitFeedback validates the command and returns a ready-to-persist
// Feedback entity (ID assigned by the repository on Create).
func SubmitFeedback(cmd SubmitFeedbackCommand) (*Feedback, error) {
	switch cmd.Type {
	case FeedbackTypeIssue, FeedbackTypeIdea, FeedbackTypeOther:
	default:
		return nil, ErrInvalidFeedbackType
	}
	bodyRunes := utf8.RuneCountInString(cmd.Body)
	if bodyRunes == 0 {
		return nil, ErrEmptyFeedbackBody
	}
	if bodyRunes > MaxBodyRunes {
		return nil, ErrFeedbackBodyTooLong
	}
	if utf8.RuneCountInString(cmd.Contact) > MaxContactRunes {
		return nil, ErrContactTooLong
	}
	// Diagnostics whitelist fields: uniform 64-rune cap each (client free
	// strings; guard against oversized rows before they reach the table).
	for _, d := range [4]string{cmd.AppVersion, cmd.Platform, cmd.AccountMode, cmd.ThemeMode} {
		if utf8.RuneCountInString(d) > MaxDiagRunes {
			return nil, ErrDiagTooLong
		}
	}

	return &Feedback{
		Type:        cmd.Type,
		Body:        cmd.Body,
		Contact:     cmd.Contact,
		AppVersion:  cmd.AppVersion,
		Platform:    cmd.Platform,
		AccountMode: cmd.AccountMode,
		ThemeMode:   cmd.ThemeMode,
		CreatedAt:   time.Now(),
	}, nil
}
