# Plan 08: Category + Currency Modules

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement two foundation modules — Category (hierarchical income/expense classification for transactions and budgets) and Currency (global currency registry with exchange rates). Both are P1 dependencies for the Flutter client and Transaction/Budget features.

**Architecture:** Explicit Architecture with DDD, Hexagonal Ports & Adapters, CQRS. Category is tenant-scoped (TenantMixin); Currency is global (no tenant_id).

**Depends on:** Plan 1 (shared kernel) + Plan 2 (auth)

**Design Specs:**
- [Functional Modules](../specs/2026-06-09-functional-modules-design.md) — Sections 5, 15

---

# Part A: Category Module

## File Structure

```
yucai/
├── proto/category/v1/
│   └── category.proto
│
└── server/internal/category/
    ├── domain/
    │   ├── entity.go                # Category aggregate root
    │   ├── valueobject.go           # CategoryType enum
    │   └── repository.go            # CategoryRepository interface
    │
    ├── application/
    │   ├── service.go               # CategoryApplicationService
    │   └── dto.go                   # DTOs + mappers
    │
    ├── adapter/driven/
    │   └── repository/
    │       └── category_repo.go     # entGo CategoryRepository
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── category_handler.go  # gRPC CategoryService
    │
    └── ent/schema/
        └── category.go              # Category schema + TenantMixin

Modified:
├── server/wire/wire.go, wire_gen.go, app.go, providers.go
└── server/cmd/server/main.go
```

---

## Task A1: Protobuf Category Service Definition

- [ ] **Step 1: Create `proto/category/v1/category.proto`**

```protobuf
syntax = "proto3";
package yucai.category.v1;
option go_package = "github.com/yucai/server/internal/proto/category/v1";

import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

service CategoryService {
  rpc CreateCategory(CreateCategoryRequest) returns (CategoryResponse);
  rpc UpdateCategory(UpdateCategoryRequest) returns (CategoryResponse);
  rpc DeleteCategory(DeleteCategoryRequest) returns (google.protobuf.Empty);
  rpc ListCategories(ListCategoriesRequest) returns (ListCategoriesResponse);
  rpc GetCategory(GetCategoryRequest) returns (CategoryResponse);
}

enum CategoryType {
  CATEGORY_TYPE_UNSPECIFIED = 0;
  CATEGORY_TYPE_INCOME = 1;
  CATEGORY_TYPE_EXPENSE = 2;
}

message CategoryDTO {
  string id = 1;
  string name = 2;
  CategoryType category_type = 3;
  string icon = 4;
  string color = 5;
  string parent_id = 6;
  bool is_system = 7;
  int32 sort_order = 8;
  int64 version = 9;
  google.protobuf.Timestamp created_at = 10;
  google.protobuf.Timestamp updated_at = 11;
}

message CreateCategoryRequest {
  string name = 1;
  CategoryType category_type = 2;
  string icon = 3;
  string color = 4;
  string parent_id = 5;
  int32 sort_order = 6;
}

message UpdateCategoryRequest {
  string id = 1;
  string name = 2;
  string icon = 3;
  string color = 4;
  int32 sort_order = 5;
  int64 version = 6;
}

message DeleteCategoryRequest { string id = 1; }

message GetCategoryRequest { string id = 1; }

message ListCategoriesRequest {
  yucai.common.v1.PageRequest page = 1;
  CategoryType category_type = 2;
  string search = 3;
}

message ListCategoriesResponse {
  repeated CategoryDTO categories = 1;
  yucai.common.v1.PageResponse page = 2;
}

message CategoryResponse { CategoryDTO category = 1; }
```

- [ ] **Step 2: Generate proto stubs** — `cd yucai/proto && buf generate --template buf.gen.go.yaml --path category/v1/category.proto`
- [ ] **Step 3: Verify generated files** — `ls yucai/server/internal/proto/category/v1/`

---

## Task A2: entGo Schema (Category)

- [ ] **Step 1: Create `internal/category/ent/schema/category.go`**

```go
package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
	"time"

	"github.com/yucai/server/internal/ent/schema/mixin"
)

type Category struct {
	ent.Schema
}

func (Category) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (Category) Mixin() []ent.Mixin {
	return []ent.Mixin{mixin.TenantMixin{}}
}

func (Category) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.String("name").NotEmpty(),
		field.String("category_type").Comment("income, expense"),
		field.String("icon").Default("").Comment("Emoji or icon name"),
		field.String("color").Default("#000000").Comment("Hex color"),
		field.UUID("parent_id", uuid.UUID{}).Optional().Nillable(),
		field.Bool("is_system").Default(false),
		field.Int32("sort_order").Default(0),
		field.Int64("version").Default(1),
		field.Time("deleted_at").Optional().Nillable(),
		field.Time("created_at").Default(time.Now).Immutable(),
		field.Time("updated_at").Default(time.Now).UpdateDefault(time.Now),
	}
}

func (Category) Edges() []ent.Edge { return nil }

func (Category) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("tenant_id", "category_type"),
		index.Fields("tenant_id"),
	}
}
```

- [ ] **Step 2: Create `internal/category/ent/generate.go`**

```go
package ent

//go:generate go run -mod=mod entgo.io/ent/cmd/ent generate ./schema
```

- [ ] **Step 3: Generate entGo code** — `cd yucai/server && go generate ./internal/category/ent/generate.go`
- [ ] **Step 4: Verify** — `go build ./internal/category/ent/...`

---

## Task A3: Domain Layer

- [ ] **Step 1: Create `internal/category/domain/valueobject.go`**

```go
package domain

// CategoryType classifies a category as income or expense.
type CategoryType int

const (
	CategoryTypeIncome CategoryType = iota + 1
	CategoryTypeExpense
)

func (t CategoryType) String() string {
	switch t {
	case CategoryTypeIncome:
		return "income"
	case CategoryTypeExpense:
		return "expense"
	default:
		return "unknown"
	}
}

func ParseCategoryType(s string) CategoryType {
	switch s {
	case "income":
		return CategoryTypeIncome
	case "expense":
		return CategoryTypeExpense
	default:
		return 0
	}
}

// PageRequest is a shared pagination type.
type PageRequest = struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult is a generic paginated response.
type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}
```

- [ ] **Step 2: Create `internal/category/domain/entity.go`**

```go
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
```

- [ ] **Step 3: Create `internal/category/domain/repository.go`**

```go
package domain

import (
	"context"

	"github.com/google/uuid"
)

type CategoryRepository interface {
	Save(ctx context.Context, category *Category) error
	FindByID(ctx context.Context, tenantID, id uuid.UUID) (*Category, error)
	FindAll(ctx context.Context, tenantID uuid.UUID, categoryType *CategoryType, search string, page PageRequest) (*PaginatedResult[Category], error)
	Update(ctx context.Context, category *Category) error
	SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error
}
```

- [ ] **Step 4: Create `internal/category/domain/domain_test.go`**

```go
package domain

import (
	"testing"

	"github.com/google/uuid"
)

func TestNewCategory_Valid(t *testing.T) {
	c, err := NewCategory(uuid.New(), "Food", CategoryTypeExpense, "🍔", "#FF5733", nil, 1)
	if err != nil {
		t.Fatalf("NewCategory failed: %v", err)
	}
	if c.Name != "Food" {
		t.Error("expected name to be set")
	}
	if c.IsSystem {
		t.Error("user category should not be system")
	}
}

func TestNewCategory_EmptyName(t *testing.T) {
	_, err := NewCategory(uuid.New(), "  ", CategoryTypeExpense, "", "", nil, 0)
	if err == nil {
		t.Error("expected error for empty name")
	}
}

func TestNewCategory_NoType(t *testing.T) {
	_, err := NewCategory(uuid.New(), "Test", CategoryType(0), "", "", nil, 0)
	if err == nil {
		t.Error("expected error for unspecified category type")
	}
}

func TestCategory_SoftDelete_SystemRejected(t *testing.T) {
	c := NewSystemCategory(uuid.New(), "Salary", CategoryTypeIncome, "💰", "#00FF00", 0)
	err := c.SoftDelete()
	if err == nil {
		t.Error("expected error deleting system category")
	}
}

func TestCategory_SoftDelete_UserAllowed(t *testing.T) {
	c, _ := NewCategory(uuid.New(), "Coffee", CategoryTypeExpense, "☕", "", nil, 0)
	if err := c.SoftDelete(); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !c.IsDeleted() {
		t.Error("expected category to be deleted")
	}
}

func TestCategory_UpdateName_DeletedRejected(t *testing.T) {
	c, _ := NewCategory(uuid.New(), "Test", CategoryTypeExpense, "", "", nil, 0)
	_ = c.SoftDelete()
	err := c.UpdateName("NewName")
	if err == nil {
		t.Error("expected error updating deleted category")
	}
}

func TestCategoryType_RoundTrip(t *testing.T) {
	types := []CategoryType{CategoryTypeIncome, CategoryTypeExpense}
	for _, ct := range types {
		if ParseCategoryType(ct.String()) != ct {
			t.Errorf("round-trip failed for %v", ct)
		}
	}
}
```

- [ ] **Step 5: Run tests** — `cd yucai/server && go test ./internal/category/domain/...`

---

## Task A4: Application Layer

- [ ] **Step 1: Create `internal/category/application/dto.go`**

```go
package application

import (
	"time"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/category/domain"
)

type CategoryDTO struct {
	ID           uuid.UUID
	TenantID     uuid.UUID
	Name         string
	CategoryType domain.CategoryType
	Icon         string
	Color        string
	ParentID     *uuid.UUID
	IsSystem     bool
	SortOrder    int32
	Version      int64
	CreatedAt    time.Time
}

type CreateCategoryRequest struct {
	Name         string
	CategoryType domain.CategoryType
	Icon         string
	Color        string
	ParentID     *uuid.UUID
	SortOrder    int32
}

type UpdateCategoryRequest struct {
	ID        uuid.UUID
	Name      string
	Icon      string
	Color     string
	SortOrder int32
	Version   int64
}

type ListCategoriesResult struct {
	Categories    []CategoryDTO
	NextPageToken string
	TotalCount    int32
}

func CategoryToDTO(c *domain.Category) CategoryDTO {
	return CategoryDTO{
		ID: c.ID, TenantID: c.TenantID, Name: c.Name,
		CategoryType: c.CategoryType, Icon: c.Icon, Color: c.Color,
		ParentID: c.ParentID, IsSystem: c.IsSystem,
		SortOrder: c.SortOrder, Version: c.Version,
		CreatedAt: c.CreatedAt,
	}
}
```

- [ ] **Step 2: Create `internal/category/application/service.go`**

```go
package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/category/domain"
)

// Service orchestrates category operations.
type Service struct {
	repo domain.CategoryRepository
}

// NewService creates a new category application service.
func NewService(repo domain.CategoryRepository) *Service {
	return &Service{repo: repo}
}

// CreateCategory creates a new user-defined category.
func (s *Service) CreateCategory(ctx context.Context, tenantID uuid.UUID, req CreateCategoryRequest) (*CategoryDTO, error) {
	category, err := domain.NewCategory(tenantID, req.Name, req.CategoryType, req.Icon, req.Color, req.ParentID, req.SortOrder)
	if err != nil {
		return nil, fmt.Errorf("create category: %w", err)
	}
	if err := s.repo.Save(ctx, category); err != nil {
		return nil, fmt.Errorf("save category: %w", err)
	}
	dto := CategoryToDTO(category)
	return &dto, nil
}

// UpdateCategory updates an existing category.
func (s *Service) UpdateCategory(ctx context.Context, tenantID uuid.UUID, req UpdateCategoryRequest) (*CategoryDTO, error) {
	category, err := s.repo.FindByID(ctx, tenantID, req.ID)
	if err != nil {
		return nil, fmt.Errorf("find category: %w", err)
	}
	if category.Version != req.Version {
		return nil, fmt.Errorf("version mismatch: expected %d, got %d", category.Version, req.Version)
	}
	if req.Name != "" {
		if err := category.UpdateName(req.Name); err != nil {
			return nil, fmt.Errorf("update name: %w", err)
		}
	}
	if req.Icon != "" {
		category.UpdateIcon(req.Icon)
	}
	if req.Color != "" {
		category.UpdateColor(req.Color)
	}
	category.UpdateSortOrder(req.SortOrder)

	if err := s.repo.Update(ctx, category); err != nil {
		return nil, fmt.Errorf("update category: %w", err)
	}
	dto := CategoryToDTO(category)
	return &dto, nil
}

// DeleteCategory soft-deletes a category. System categories are rejected.
func (s *Service) DeleteCategory(ctx context.Context, tenantID, id uuid.UUID) error {
	category, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return fmt.Errorf("find category: %w", err)
	}
	if err := category.SoftDelete(); err != nil {
		return fmt.Errorf("soft delete: %w", err)
	}
	if err := s.repo.SoftDelete(ctx, tenantID, id); err != nil {
		return fmt.Errorf("repo soft delete: %w", err)
	}
	return nil
}

// GetCategory retrieves a single category by ID.
func (s *Service) GetCategory(ctx context.Context, tenantID, id uuid.UUID) (*CategoryDTO, error) {
	category, err := s.repo.FindByID(ctx, tenantID, id)
	if err != nil {
		return nil, fmt.Errorf("find category: %w", err)
	}
	dto := CategoryToDTO(category)
	return &dto, nil
}

// ListCategories returns paginated categories with optional type filter and search.
func (s *Service) ListCategories(ctx context.Context, tenantID uuid.UUID, categoryType *domain.CategoryType, search string, page domain.PageRequest) (*ListCategoriesResult, error) {
	result, err := s.repo.FindAll(ctx, tenantID, categoryType, search, page)
	if err != nil {
		return nil, fmt.Errorf("list categories: %w", err)
	}
	dtos := make([]CategoryDTO, len(result.Items))
	for i, c := range result.Items {
		dtos[i] = CategoryToDTO(&c)
	}
	return &ListCategoriesResult{
		Categories:    dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}
```

---

## Task A5: Driven Adapter (Repository)

- [ ] **Step 1: Create `internal/category/adapter/driven/repository/category_repo.go`**

```go
package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/category/domain"
	categoryent "github.com/yucai/server/internal/category/ent"
	"github.com/yucai/server/internal/category/ent/category"
)

// CategoryRepository implements domain.CategoryRepository.
type CategoryRepository struct {
	client *categoryent.Client
}

// NewCategoryRepository creates a new CategoryRepository.
func NewCategoryRepository(client *categoryent.Client) *CategoryRepository {
	return &CategoryRepository{client: client}
}

// Save creates a new category record.
func (r *CategoryRepository) Save(ctx context.Context, c *domain.Category) error {
	create := r.client.Category.Create().
		SetID(c.ID).SetTenantID(c.TenantID).
		SetName(c.Name).SetCategoryType(c.CategoryType.String()).
		SetIcon(c.Icon).SetColor(c.Color).
		SetIsSystem(c.IsSystem).SetSortOrder(c.SortOrder).
		SetVersion(c.Version).
		SetCreatedAt(c.CreatedAt).SetUpdatedAt(c.UpdatedAt)

	if c.ParentID != nil {
		create.SetParentID(*c.ParentID)
	}

	_, err := create.Save(ctx)
	if err != nil {
		return fmt.Errorf("create category: %w", err)
	}
	return nil
}

// FindByID retrieves a non-deleted category by ID within a tenant.
func (r *CategoryRepository) FindByID(ctx context.Context, tenantID, id uuid.UUID) (*domain.Category, error) {
	c, err := r.client.Category.Query().
		Where(category.TenantID(tenantID), category.ID(id), category.DeletedAtIsNil()).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find category by id: %w", err)
	}
	return toDomain(c), nil
}

// FindAll returns paginated categories with optional type filter and name search.
func (r *CategoryRepository) FindAll(ctx context.Context, tenantID uuid.UUID, categoryType *domain.CategoryType, search string, page domain.PageRequest) (*domain.PaginatedResult[domain.Category], error) {
	query := r.client.Category.Query().
		Where(category.TenantID(tenantID), category.DeletedAtIsNil())

	if categoryType != nil {
		query.Where(category.CategoryType(categoryType.String()))
	}
	if search != "" {
		query.Where(category.NameContains(search))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count categories: %w", err)
	}

	ps := int(page.PageSize)
	if ps <= 0 {
		ps = 20
	}
	query.Limit(ps + 1)

	if page.PageToken != "" {
		cursorID, _ := uuid.Parse(page.PageToken)
		query.Where(category.IDGTE(cursorID))
	}

	query.Order(categoryent.Asc(category.FieldSortOrder))

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query categories: %w", err)
	}

	nextToken := ""
	if len(results) > ps {
		nextToken = results[ps-1].ID.String()
		results = results[:ps]
	}

	items := make([]domain.Category, len(results))
	for i, c := range results {
		items[i] = *toDomain(c)
	}

	return &domain.PaginatedResult[domain.Category]{
		Items:         items,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update saves changes to an existing category.
func (r *CategoryRepository) Update(ctx context.Context, c *domain.Category) error {
	update := r.client.Category.UpdateOneID(c.ID).
		SetName(c.Name).SetIcon(c.Icon).SetColor(c.Color).
		SetSortOrder(c.SortOrder).SetVersion(c.Version).SetUpdatedAt(c.UpdatedAt)

	_, err := update.Save(ctx)
	if err != nil {
		return fmt.Errorf("update category: %w", err)
	}
	return nil
}

// SoftDelete sets deleted_at on a category.
func (r *CategoryRepository) SoftDelete(ctx context.Context, tenantID, id uuid.UUID) error {
	_, err := r.client.Category.UpdateOneID(id).
		SetNillableDeletedAt(nowPtr()).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("soft delete category: %w", err)
	}
	return nil
}

func toDomain(c *categoryent.Category) *domain.Category {
	var parentID *uuid.UUID
	if c.ParentID != nil {
		parentID = c.ParentID
	}
	return &domain.Category{
		ID: c.ID, TenantID: c.TenantID, Name: c.Name,
		CategoryType: domain.ParseCategoryType(c.CategoryType),
		Icon: c.Icon, Color: c.Color, ParentID: parentID,
		IsSystem: c.IsSystem, SortOrder: c.SortOrder,
		Version: c.Version, DeletedAt: c.DeletedAt,
		CreatedAt: c.CreatedAt, UpdatedAt: c.UpdatedAt,
	}
}
```

- [ ] **Step 2: Create helper file `internal/category/adapter/driven/repository/helpers.go`**

```go
package repository

import "time"

func nowPtr() *time.Time {
	now := time.Now()
	return &now
}
```

---

## Task A6: gRPC Driving Adapter

- [ ] **Step 1: Create `internal/category/adapter/driving/grpc/category_handler.go`**

```go
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
```

---

## Task A7: Wire Integration + Verification

- [ ] **Step 1: Add Category providers to `wire/providers.go`**

Add imports near the other module imports:
```go
	categoryrepo "github.com/yucai/server/internal/category/adapter/driven/repository"
	categorygrpc "github.com/yucai/server/internal/category/adapter/driving/grpc"
	categoryapp "github.com/yucai/server/internal/category/application"
	categoryent "github.com/yucai/server/internal/category/ent"
```

Add provider functions before `provideGRPCServer`:
```go
// Category providers
func provideCategoryEntClient(cfg *config.Config) (*categoryent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return categoryent.NewClient(categoryent.Driver(drv)), nil
}
func provideCategoryRepo(client *categoryent.Client) *categoryrepo.CategoryRepository {
	return categoryrepo.NewCategoryRepository(client)
}
func provideCategoryService(repo *categoryrepo.CategoryRepository) *categoryapp.Service {
	return categoryapp.NewService(repo)
}
func provideCategoryHandler(svc *categoryapp.Service) *categorygrpc.CategoryHandler {
	return categorygrpc.NewCategoryHandler(svc)
}
```

- [ ] **Step 2: Add `CategoryHandler` to `wire/app.go`**

Add import:
```go
	categorygrpc "github.com/yucai/server/internal/category/adapter/driving/grpc"
```

Add to `App` struct:
```go
	CategoryHandler    *categorygrpc.CategoryHandler
```

Add to `NewApp` params:
```go
	categoryHandler *categorygrpc.CategoryHandler,
```

Add to return struct:
```go
		CategoryHandler:    categoryHandler,
```

- [ ] **Step 3: Add to `wire/wire.go`** — add Category providers before `provideGRPCServer`:
```go
		// Category module
		provideCategoryEntClient,
		provideCategoryRepo,
		provideCategoryService,
		provideCategoryHandler,
```

- [ ] **Step 4: Update `wire/wire_gen.go`**

After the backup client creation, add:
```go
	categoryClient, err := provideCategoryEntClient(cfg)
	if err != nil {
		return nil, err
	}
```

After the Sync module wiring, add:
```go
	// Category module
	categoryRepo := provideCategoryRepo(categoryClient)
	categoryService := provideCategoryService(categoryRepo)
	categoryHandler := provideCategoryHandler(categoryService)
```

Update the `NewApp` call to include `categoryHandler` as the last argument.

- [ ] **Step 5: Register service in `cmd/server/main.go`**

Add import:
```go
	categorypb "github.com/yucai/server/internal/proto/category/v1"
```

Add registration:
```go
	categorypb.RegisterCategoryServiceServer(app.GRPCServer, app.CategoryHandler)
```

- [ ] **Step 6: Verify** — `cd yucai/server && go build ./cmd/server/`

- [ ] **Step 7: Commit** — `feat: implement Category module — hierarchical categories, soft delete, system categories, gRPC CategoryService`

---

# Part B: Currency Module

## File Structure

```
yucai/
├── proto/currency/v1/
│   └── currency.proto
│
└── server/internal/currency/
    ├── domain/
    │   ├── entity.go                # Currency entity (global, no tenant)
    │   ├── repository.go            # CurrencyRepository interface
    │   └── domain_test.go
    │
    ├── application/
    │   ├── service.go               # CurrencyApplicationService
    │   └── dto.go
    │
    ├── adapter/driven/
    │   ├── repository/
    │   │   └── currency_repo.go     # entGo CurrencyRepository
    │   └── exchangerate/
    │       ├── provider.go          # ExchangeRateProvider port
    │       └── mock_provider.go     # Static rate provider (no external API yet)
    │
    ├── adapter/driving/
    │   └── grpc/
    │       └── currency_handler.go  # gRPC CurrencyService
    │
    └── ent/schema/
        └── currency.go              # Global schema (no TenantMixin)
```

---

## Task B1: Protobuf Currency Service Definition

- [ ] **Step 1: Create `proto/currency/v1/currency.proto`**

```protobuf
syntax = "proto3";
package yucai.currency.v1;
option go_package = "github.com/yucai/server/internal/proto/currency/v1";

import "common/v1/pagination.proto";
import "google/protobuf/empty.proto";

service CurrencyService {
  rpc ListCurrencies(ListCurrenciesRequest) returns (ListCurrenciesResponse);
  rpc AddCurrency(AddCurrencyRequest) returns (CurrencyResponse);
  rpc UpdateExchangeRate(UpdateRateRequest) returns (CurrencyResponse);
  rpc FetchExchangeRate(FetchRateRequest) returns (FetchRateResponse);
}

message CurrencyDTO {
  string id = 1;
  string code = 2;          // ISO 4217, e.g. "CNY"
  string name = 3;          // e.g. "Chinese Yuan"
  string symbol = 4;        // e.g. "¥"
  double exchange_rate = 5; // Rate to base currency
  bool is_active = 6;
}

message AddCurrencyRequest {
  string code = 1;
  string name = 2;
  string symbol = 3;
  double exchange_rate = 4;
}

message UpdateRateRequest {
  string id = 1;
  double exchange_rate = 2;
}

message FetchRateRequest {
  string code = 1;
}

message FetchRateResponse {
  string code = 1;
  double exchange_rate = 2;
}

message ListCurrenciesRequest {
  yucai.common.v1.PageRequest page = 1;
  bool active_only = 2;
}

message ListCurrenciesResponse {
  repeated CurrencyDTO currencies = 1;
  yucai.common.v1.PageResponse page = 2;
}

message CurrencyResponse { CurrencyDTO currency = 1; }
```

- [ ] **Step 2: Generate proto stubs** — `cd yucai/proto && buf generate --template buf.gen.go.yaml --path currency/v1/currency.proto`
- [ ] **Step 3: Verify** — `ls yucai/server/internal/proto/currency/v1/`

---

## Task B2: entGo Schema (Currency) — Global, no TenantMixin

- [ ] **Step 1: Create `internal/currency/ent/schema/currency.go`**

```go
package schema

import (
	"entgo.io/ent"
	"entgo.io/ent/dialect/entsql"
	entschema "entgo.io/ent/schema"
	"entgo.io/ent/schema/field"
	"entgo.io/ent/schema/index"
	"github.com/google/uuid"
)

// Currency is a global reference table — no TenantMixin.
type Currency struct {
	ent.Schema
}

func (Currency) Annotations() []entschema.Annotation {
	return []entschema.Annotation{entsql.WithComments(true)}
}

func (Currency) Mixin() []ent.Mixin { return nil }

func (Currency) Fields() []ent.Field {
	return []ent.Field{
		field.UUID("id", uuid.UUID{}).Default(uuid.New),
		field.String("code").Unique().Comment("ISO 4217 code, e.g. CNY"),
		field.String("name").NotEmpty(),
		field.String("symbol").Default(""),
		field.Float64("exchange_rate").Default(1.0).Comment("Rate to base currency"),
		field.Bool("is_active").Default(true),
	}
}

func (Currency) Edges() []ent.Edge { return nil }

func (Currency) Indexes() []ent.Index {
	return []ent.Index{
		index.Fields("code"),
	}
}
```

- [ ] **Step 2: Create `internal/currency/ent/generate.go`**

```go
package ent

//go:generate go run -mod=mod entgo.io/ent/cmd/ent generate ./schema
```

- [ ] **Step 3: Generate entGo code** — `cd yucai/server && go generate ./internal/currency/ent/generate.go`
- [ ] **Step 4: Verify** — `go build ./internal/currency/ent/...`

---

## Task B3: Domain Layer

- [ ] **Step 1: Create `internal/currency/domain/entity.go`**

```go
package domain

import (
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Currency is a global reference entity for ISO 4217 currencies.
// No tenant_id — shared across all tenants.
type Currency struct {
	ID           uuid.UUID
	Code         string // ISO 4217, e.g. "CNY"
	Name         string // e.g. "Chinese Yuan"
	Symbol       string // e.g. "¥"
	ExchangeRate float64
	IsActive     bool
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// NewCurrency creates a new currency.
func NewCurrency(code, name, symbol string, exchangeRate float64) (*Currency, error) {
	code = strings.ToUpper(strings.TrimSpace(code))
	if code == "" {
		return nil, fmt.Errorf("currency code must not be empty")
	}
	if len(code) != 3 {
		return nil, fmt.Errorf("currency code must be 3 characters (ISO 4217)")
	}
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("currency name must not be empty")
	}
	if exchangeRate <= 0 {
		return nil, fmt.Errorf("exchange rate must be positive")
	}
	now := time.Now()
	return &Currency{
		ID: uuid.New(), Code: code, Name: name, Symbol: symbol,
		ExchangeRate: exchangeRate, IsActive: true,
		CreatedAt: now, UpdatedAt: now,
	}, nil
}

// UpdateRate updates the exchange rate.
func (c *Currency) UpdateRate(rate float64) error {
	if rate <= 0 {
		return fmt.Errorf("exchange rate must be positive")
	}
	c.ExchangeRate = rate
	c.UpdatedAt = time.Now()
	return nil
}

// Deactivate marks the currency as inactive.
func (c *Currency) Deactivate() {
	c.IsActive = false
	c.UpdatedAt = time.Now()
}

// Activate marks the currency as active.
func (c *Currency) Activate() {
	c.IsActive = true
	c.UpdatedAt = time.Now()
}
```

- [ ] **Step 2: Create `internal/currency/domain/repository.go`**

```go
package domain

import (
	"context"

	"github.com/google/uuid"
)

// PageRequest is a shared pagination type.
type PageRequest = struct {
	PageSize  int32
	PageToken string
}

// PaginatedResult is a generic paginated response.
type PaginatedResult[T any] = struct {
	Items         []T
	NextPageToken string
	TotalCount    int32
}

type CurrencyRepository interface {
	Save(ctx context.Context, currency *Currency) error
	FindByID(ctx context.Context, id uuid.UUID) (*Currency, error)
	FindByCode(ctx context.Context, code string) (*Currency, error)
	FindAll(ctx context.Context, activeOnly bool, page PageRequest) (*PaginatedResult[Currency], error)
	Update(ctx context.Context, currency *Currency) error
}
```

- [ ] **Step 3: Create `internal/currency/domain/domain_test.go`**

```go
package domain

import (
	"testing"
)

func TestNewCurrency_Valid(t *testing.T) {
	c, err := NewCurrency("cny", "Chinese Yuan", "¥", 1.0)
	if err != nil {
		t.Fatalf("NewCurrency failed: %v", err)
	}
	if c.Code != "CNY" {
		t.Errorf("expected uppercase CNY, got %s", c.Code)
	}
}

func TestNewCurrency_InvalidCode(t *testing.T) {
	_, err := NewCurrency("C", "Test", "", 1.0)
	if err == nil {
		t.Error("expected error for short code")
	}
}

func TestNewCurrency_EmptyCode(t *testing.T) {
	_, err := NewCurrency("  ", "Test", "", 1.0)
	if err == nil {
		t.Error("expected error for empty code")
	}
}

func TestNewCurrency_InvalidRate(t *testing.T) {
	_, err := NewCurrency("CNY", "Yuan", "", -1.0)
	if err == nil {
		t.Error("expected error for negative rate")
	}
}

func TestNewCurrency_EmptyName(t *testing.T) {
	_, err := NewCurrency("CNY", "", "", 1.0)
	if err == nil {
		t.Error("expected error for empty name")
	}
}

func TestCurrency_UpdateRate(t *testing.T) {
	c, _ := NewCurrency("CNY", "Yuan", "", 1.0)
	if err := c.UpdateRate(6.5); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if c.ExchangeRate != 6.5 {
		t.Errorf("expected rate 6.5, got %f", c.ExchangeRate)
	}
}

func TestCurrency_DeactivateActivate(t *testing.T) {
	c, _ := NewCurrency("CNY", "Yuan", "", 1.0)
	c.Deactivate()
	if c.IsActive {
		t.Error("expected inactive")
	}
	c.Activate()
	if !c.IsActive {
		t.Error("expected active")
	}
}
```

- [ ] **Step 4: Run tests** — `cd yucai/server && go test ./internal/currency/domain/...`

---

## Task B4: Application Layer + Exchange Rate Provider

- [ ] **Step 1: Create `internal/currency/application/dto.go`**

```go
package application

import (
	"github.com/google/uuid"
	"github.com/yucai/server/internal/currency/domain"
)

type CurrencyDTO struct {
	ID           uuid.UUID
	Code         string
	Name         string
	Symbol       string
	ExchangeRate float64
	IsActive     bool
}

type AddCurrencyRequest struct {
	Code         string
	Name         string
	Symbol       string
	ExchangeRate float64
}

type ListCurrenciesResult struct {
	Currencies    []CurrencyDTO
	NextPageToken string
	TotalCount    int32
}

func CurrencyToDTO(c *domain.Currency) CurrencyDTO {
	return CurrencyDTO{
		ID: c.ID, Code: c.Code, Name: c.Name, Symbol: c.Symbol,
		ExchangeRate: c.ExchangeRate, IsActive: c.IsActive,
	}
}
```

- [ ] **Step 2: Create `internal/currency/adapter/driven/exchangerate/provider.go`** (port interface)

```go
package exchangerate

import "context"

// Provider is the port interface for exchange rate data sources.
type Provider interface {
	// FetchRate retrieves the exchange rate for the given currency code.
	FetchRate(ctx context.Context, code string) (float64, error)
}
```

- [ ] **Step 3: Create `internal/currency/adapter/driven/exchangerate/mock_provider.go`**

```go
package exchangerate

import (
	"context"
	"fmt"
)

// MockProvider returns static exchange rates for development/testing.
// In production, this will be replaced with a real API provider (e.g. exchangerate-api.com).
type MockProvider struct {
	rates map[string]float64
}

// NewMockProvider creates a MockProvider with common currencies.
func NewMockProvider() *MockProvider {
	return &MockProvider{
		rates: map[string]float64{
			"CNY": 1.0,
			"USD": 7.2,
			"EUR": 7.8,
			"JPY": 0.048,
			"GBP": 9.1,
			"HKD": 0.92,
			"SGD": 5.3,
		},
	}
}

// FetchRate returns the mock rate for a currency code.
func (p *MockProvider) FetchRate(ctx context.Context, code string) (float64, error) {
	rate, ok := p.rates[code]
	if !ok {
		return 0, fmt.Errorf("rate not available for currency %s", code)
	}
	return rate, nil
}
```

- [ ] **Step 4: Create `internal/currency/application/service.go`**

```go
package application

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/currency/adapter/driven/exchangerate"
	"github.com/yucai/server/internal/currency/domain"
)

// Service orchestrates currency operations.
type Service struct {
	repo     domain.CurrencyRepository
	provider exchangerate.Provider
}

// NewService creates a new currency application service.
func NewService(repo domain.CurrencyRepository, provider exchangerate.Provider) *Service {
	return &Service{repo: repo, provider: provider}
}

// AddCurrency creates a new global currency.
func (s *Service) AddCurrency(ctx context.Context, req AddCurrencyRequest) (*CurrencyDTO, error) {
	currency, err := domain.NewCurrency(req.Code, req.Name, req.Symbol, req.ExchangeRate)
	if err != nil {
		return nil, fmt.Errorf("create currency: %w", err)
	}
	if err := s.repo.Save(ctx, currency); err != nil {
		return nil, fmt.Errorf("save currency: %w", err)
	}
	dto := CurrencyToDTO(currency)
	return &dto, nil
}

// UpdateExchangeRate updates the rate of an existing currency.
func (s *Service) UpdateExchangeRate(ctx context.Context, id uuid.UUID, rate float64) (*CurrencyDTO, error) {
	currency, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("find currency: %w", err)
	}
	if err := currency.UpdateRate(rate); err != nil {
		return nil, fmt.Errorf("update rate: %w", err)
	}
	if err := s.repo.Update(ctx, currency); err != nil {
		return nil, fmt.Errorf("update currency: %w", err)
	}
	dto := CurrencyToDTO(currency)
	return &dto, nil
}

// FetchExchangeRate retrieves the current rate from the external provider.
func (s *Service) FetchExchangeRate(ctx context.Context, code string) (float64, error) {
	rate, err := s.provider.FetchRate(ctx, code)
	if err != nil {
		return 0, fmt.Errorf("fetch rate: %w", err)
	}
	return rate, nil
}

// ListCurrencies returns paginated currencies.
func (s *Service) ListCurrencies(ctx context.Context, activeOnly bool, page domain.PageRequest) (*ListCurrenciesResult, error) {
	result, err := s.repo.FindAll(ctx, activeOnly, page)
	if err != nil {
		return nil, fmt.Errorf("list currencies: %w", err)
	}
	dtos := make([]CurrencyDTO, len(result.Items))
	for i, c := range result.Items {
		dtos[i] = CurrencyToDTO(&c)
	}
	return &ListCurrenciesResult{
		Currencies:    dtos,
		NextPageToken: result.NextPageToken,
		TotalCount:    result.TotalCount,
	}, nil
}
```

---

## Task B5: Driven Adapter (Repository)

- [ ] **Step 1: Create `internal/currency/adapter/driven/repository/currency_repo.go`**

```go
package repository

import (
	"context"
	"fmt"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/currency/domain"
	currencyent "github.com/yucai/server/internal/currency/ent"
	"github.com/yucai/server/internal/currency/ent/currency"
)

// CurrencyRepository implements domain.CurrencyRepository.
type CurrencyRepository struct {
	client *currencyent.Client
}

// NewCurrencyRepository creates a new CurrencyRepository.
func NewCurrencyRepository(client *currencyent.Client) *CurrencyRepository {
	return &CurrencyRepository{client: client}
}

// Save creates a new currency record.
func (r *CurrencyRepository) Save(ctx context.Context, c *domain.Currency) error {
	_, err := r.client.Currency.Create().
		SetID(c.ID).SetCode(c.Code).SetName(c.Name).
		SetSymbol(c.Symbol).SetExchangeRate(c.ExchangeRate).
		SetIsActive(c.IsActive).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("create currency: %w", err)
	}
	return nil
}

// FindByID retrieves a currency by ID.
func (r *CurrencyRepository) FindByID(ctx context.Context, id uuid.UUID) (*domain.Currency, error) {
	c, err := r.client.Currency.Query().
		Where(currency.ID(id)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find currency by id: %w", err)
	}
	return toDomain(c), nil
}

// FindByCode retrieves a currency by ISO code.
func (r *CurrencyRepository) FindByCode(ctx context.Context, code string) (*domain.Currency, error) {
	c, err := r.client.Currency.Query().
		Where(currency.Code(code)).
		Only(ctx)
	if err != nil {
		return nil, fmt.Errorf("find currency by code: %w", err)
	}
	return toDomain(c), nil
}

// FindAll returns paginated currencies.
func (r *CurrencyRepository) FindAll(ctx context.Context, activeOnly bool, page domain.PageRequest) (*domain.PaginatedResult[domain.Currency], error) {
	query := r.client.Currency.Query()

	if activeOnly {
		query.Where(currency.IsActive(true))
	}

	total, err := query.Count(ctx)
	if err != nil {
		return nil, fmt.Errorf("count currencies: %w", err)
	}

	ps := int(page.PageSize)
	if ps <= 0 {
		ps = 50
	}
	query.Limit(ps + 1)

	if page.PageToken != "" {
		cursorID, _ := uuid.Parse(page.PageToken)
		query.Where(currency.IDGTE(cursorID))
	}

	results, err := query.All(ctx)
	if err != nil {
		return nil, fmt.Errorf("query currencies: %w", err)
	}

	nextToken := ""
	if len(results) > ps {
		nextToken = results[ps-1].ID.String()
		results = results[:ps]
	}

	items := make([]domain.Currency, len(results))
	for i, c := range results {
		items[i] = *toDomain(c)
	}

	return &domain.PaginatedResult[domain.Currency]{
		Items:         items,
		NextPageToken: nextToken,
		TotalCount:    int32(total),
	}, nil
}

// Update saves changes to an existing currency.
func (r *CurrencyRepository) Update(ctx context.Context, c *domain.Currency) error {
	_, err := r.client.Currency.UpdateOneID(c.ID).
		SetExchangeRate(c.ExchangeRate).
		SetIsActive(c.IsActive).
		Save(ctx)
	if err != nil {
		return fmt.Errorf("update currency: %w", err)
	}
	return nil
}

func toDomain(c *currencyent.Currency) *domain.Currency {
	return &domain.Currency{
		ID: c.ID, Code: c.Code, Name: c.Name, Symbol: c.Symbol,
		ExchangeRate: c.ExchangeRate, IsActive: c.IsActive,
	}
}
```

---

## Task B6: gRPC Driving Adapter

- [ ] **Step 1: Create `internal/currency/adapter/driving/grpc/currency_handler.go`**

```go
package grpc

import (
	"context"

	pb "github.com/yucai/server/internal/proto/currency/v1"
	commonpb "github.com/yucai/server/internal/proto/common/v1"
	"github.com/google/uuid"
	"github.com/yucai/server/internal/currency/application"
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
	page := application_domainPage(req.Page)

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

// application_domainPage converts proto PageRequest to domain PageRequest.
func application_domainPage(page *commonpb.PageRequest) PageRequest {
	pr := PageRequest{PageSize: 50}
	if page != nil {
		pr.PageSize = page.PageSize
		pr.PageToken = page.PageToken
	}
	return pr
}
```

- [ ] **Step 2: Create helper `internal/currency/adapter/driving/grpc/types.go`**

```go
package grpc

// PageRequest mirrors the domain pagination type to avoid import cycles.
type PageRequest struct {
	PageSize  int32
	PageToken string
}
```

- [ ] **Step 3: Fix the service call** — the domain PageRequest type needs proper conversion. Update `service.go` `ListCurrencies` signature to accept `application` package's own PageRequest alias, or adjust the handler. The simplest fix: in `currency_handler.go`, import the domain package and use `domain.PageRequest` directly.

Replace `application_domainPage` function body to return `domain.PageRequest`:

```go
// application_domainPage converts proto PageRequest to domain PageRequest.
func application_domainPage(page *commonpb.PageRequest) domain.PageRequest {
	pr := domain.PageRequest{PageSize: 50}
	if page != nil {
		pr.PageSize = page.PageSize
		pr.PageToken = page.PageToken
	}
	return pr
}
```

And add import `"github.com/yucai/server/internal/currency/domain"` to the handler, then change the `page := application_domainPage(req.Page)` line to use `domain.PageRequest`.

---

## Task B7: Wire Integration + Verification

- [ ] **Step 1: Add Currency providers to `wire/providers.go`**

Add imports:
```go
	currencyrepo "github.com/yucai/server/internal/currency/adapter/driven/repository"
	"github.com/yucai/server/internal/currency/adapter/driven/exchangerate"
	currencygrpc "github.com/yucai/server/internal/currency/adapter/driving/grpc"
	currencyapp "github.com/yucai/server/internal/currency/application"
	currencyent "github.com/yucai/server/internal/currency/ent"
```

Add provider functions before `provideGRPCServer`:
```go
// Currency providers
func provideCurrencyEntClient(cfg *config.Config) (*currencyent.Client, error) {
	drv, err := entsql.Open("pgx", cfg.DatabaseURL)
	if err != nil {
		return nil, err
	}
	return currencyent.NewClient(currencyent.Driver(drv)), nil
}
func provideCurrencyRepo(client *currencyent.Client) *currencyrepo.CurrencyRepository {
	return currencyrepo.NewCurrencyRepository(client)
}
func provideExchangeRateProvider() *exchangerate.MockProvider {
	return exchangerate.NewMockProvider()
}
func provideCurrencyService(repo *currencyrepo.CurrencyRepository, provider *exchangerate.MockProvider) *currencyapp.Service {
	return currencyapp.NewService(repo, provider)
}
func provideCurrencyHandler(svc *currencyapp.Service) *currencygrpc.CurrencyHandler {
	return currencygrpc.NewCurrencyHandler(svc)
}
```

- [ ] **Step 2: Add `CurrencyHandler` to `wire/app.go`**

Add import:
```go
	currencygrpc "github.com/yucai/server/internal/currency/adapter/driving/grpc"
```

Add to `App` struct:
```go
	CurrencyHandler    *currencygrpc.CurrencyHandler
```

Add to `NewApp` params:
```go
	currencyHandler *currencygrpc.CurrencyHandler,
```

Add to return struct:
```go
		CurrencyHandler:    currencyHandler,
```

- [ ] **Step 3: Add to `wire/wire.go`**:
```go
		// Currency module
		provideCurrencyEntClient,
		provideCurrencyRepo,
		provideExchangeRateProvider,
		provideCurrencyService,
		provideCurrencyHandler,
```

- [ ] **Step 4: Update `wire/wire_gen.go`**

After Category client, add:
```go
	currencyClient, err := provideCurrencyEntClient(cfg)
	if err != nil {
		return nil, err
	}
```

After Category wiring, add:
```go
	// Currency module
	currencyRepo := provideCurrencyRepo(currencyClient)
	exchangeRateProvider := provideExchangeRateProvider()
	currencyService := provideCurrencyService(currencyRepo, exchangeRateProvider)
	currencyHandler := provideCurrencyHandler(currencyService)
```

Update `NewApp` call to include `currencyHandler`.

- [ ] **Step 5: Register service in `cmd/server/main.go`**

Add import:
```go
	currencypb "github.com/yucai/server/internal/proto/currency/v1"
```

Add registration:
```go
	currencypb.RegisterCurrencyServiceServer(app.GRPCServer, app.CurrencyHandler)
```

- [ ] **Step 6: Verify** — `cd yucai/server && go build ./cmd/server/`

- [ ] **Step 7: Run all tests** — `cd yucai/server && go test ./internal/category/... ./internal/currency/...`

- [ ] **Step 8: Commit** — `feat: implement Currency module — global currency registry, exchange rate provider, gRPC CurrencyService`

---

## Self-Review

| Spec Section | Covered by Task |
|---|---|
| Category aggregate root | A3 (domain entity) |
| CategoryType enum (income/expense) | A3 (valueobject) |
| Category hierarchical (parent_id) | A2 (schema), A3 (entity) |
| System categories cannot be deleted | A3 (SoftDelete method) |
| Category soft delete | A3 (SoftDelete), A5 (repo) |
| Category name uniqueness | A2 (index on tenant_id+type — uniqueness optional) |
| Currency global entity | B3 (domain — no tenant) |
| Currency ISO 4217 code UNIQUE | B2 (schema) |
| Currency exchange rate | B3 (entity), B4 (service) |
| External rate provider port | B4 (exchangerate/provider.go) |
| All gRPC services | A6, B6 |
| Wire DI integration | A7, B7 |
