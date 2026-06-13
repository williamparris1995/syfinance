package domain

import (
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Category is the aggregate root for income/expense classification.
type Category struct {
	ID           uuid.UUID
	TenantID     uuid.UUID
	Name         string
	CategoryType CategoryType
	Icon         string
	Color        string
	ParentID     *uuid.UUID
	IsSystem     bool
	SortOrder    int32
	Version      int64
	DeletedAt    *time.Time
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// NewCategory creates a new user-defined (non-system) category.
func NewCategory(tenantID uuid.UUID, name string, categoryType CategoryType, icon, color string, parentID *uuid.UUID, sortOrder int32) (*Category, error) {
	if categoryType == 0 {
		return nil, fmt.Errorf("category type must be specified")
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("name must not be empty")
	}
	now := time.Now()
	return &Category{
		ID:           uuid.New(),
		TenantID:     tenantID,
		Name:         name,
		CategoryType: categoryType,
		Icon:         icon,
		Color:        color,
		ParentID:     parentID,
		IsSystem:     false,
		SortOrder:    sortOrder,
		Version:      1,
		CreatedAt:    now,
		UpdatedAt:    now,
	}, nil
}

// NewSystemCategory creates a system category that cannot be deleted.
func NewSystemCategory(tenantID uuid.UUID, name string, categoryType CategoryType, icon, color string, sortOrder int32) *Category {
	c, _ := NewCategory(tenantID, name, categoryType, icon, color, nil, sortOrder)
	c.IsSystem = true
	return c
}

// UpdateName updates the category name.
func (c *Category) UpdateName(name string) error {
	if c.IsDeleted() {
		return fmt.Errorf("cannot update deleted category")
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return fmt.Errorf("name must not be empty")
	}
	c.Name = name
	c.IncrementVersion()
	return nil
}

// UpdateIcon updates the category icon.
func (c *Category) UpdateIcon(icon string) {
	c.Icon = icon
	c.IncrementVersion()
}

// UpdateColor updates the category color.
func (c *Category) UpdateColor(color string) {
	c.Color = color
	c.IncrementVersion()
}

// UpdateSortOrder updates the display sort order.
func (c *Category) UpdateSortOrder(order int32) {
	c.SortOrder = order
	c.IncrementVersion()
}

// SoftDelete marks the category as deleted. System categories cannot be deleted.
func (c *Category) SoftDelete() error {
	if c.IsSystem {
		return fmt.Errorf("system categories cannot be deleted")
	}
	if c.IsDeleted() {
		return fmt.Errorf("category already deleted")
	}
	now := time.Now()
	c.DeletedAt = &now
	c.IncrementVersion()
	return nil
}

// IsDeleted returns true if the category has been soft-deleted.
func (c *Category) IsDeleted() bool {
	return c.DeletedAt != nil
}

// IncrementVersion bumps the optimistic lock version.
func (c *Category) IncrementVersion() {
	c.Version++
	c.UpdatedAt = time.Now()
}
