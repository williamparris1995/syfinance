package domain

import (
	"fmt"
	"regexp"
	"time"

	"github.com/google/uuid"
)

var hexColorRegex = regexp.MustCompile(`^#[0-9A-Fa-f]{6}$`)

// Tag is a label for categorizing transactions.
type Tag struct {
	ID        uuid.UUID
	TenantID  uuid.UUID
	Name      string
	Color     string
	Version   int64
	DeletedAt *time.Time
	CreatedAt time.Time
	UpdatedAt time.Time
}

// NewTag creates a validated Tag.
func NewTag(tenantID uuid.UUID, name, color string) (*Tag, error) {
	name = trimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("tag name must not be empty")
	}
	if color == "" {
		color = "#000000"
	}
	if !hexColorRegex.MatchString(color) {
		return nil, fmt.Errorf("invalid hex color format, expected #RRGGBB")
	}

	now := time.Now()
	return &Tag{
		ID:        uuid.New(),
		TenantID:  tenantID,
		Name:      name,
		Color:     color,
		Version:   1,
		CreatedAt: now,
		UpdatedAt: now,
	}, nil
}

// UpdateName changes the tag name.
func (t *Tag) UpdateName(name string) error {
	name = trimSpace(name)
	if name == "" {
		return fmt.Errorf("tag name must not be empty")
	}
	t.Name = name
	t.UpdatedAt = time.Now()
	return nil
}

// UpdateColor changes the tag color.
func (t *Tag) UpdateColor(color string) error {
	if !hexColorRegex.MatchString(color) {
		return fmt.Errorf("invalid hex color format, expected #RRGGBB")
	}
	t.Color = color
	t.UpdatedAt = time.Now()
	return nil
}

// SoftDelete marks the tag as deleted.
func (t *Tag) SoftDelete() {
	now := time.Now()
	t.DeletedAt = &now
	t.UpdatedAt = now
}

// IncrementVersion bumps the optimistic lock version.
func (t *Tag) IncrementVersion() {
	t.Version++
	t.UpdatedAt = time.Now()
}

func trimSpace(s string) string {
	result := make([]byte, 0, len(s))
	for i := 0; i < len(s); i++ {
		if s[i] != ' ' && s[i] != '\t' && s[i] != '\n' && s[i] != '\r' {
			result = append(result, s[i])
		}
	}
	return string(result)
}
