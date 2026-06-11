package tests

import (
	"context"
	"testing"

	"database/sql"
	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	_ "modernc.org/sqlite"

	"github.com/google/uuid"
	tagrepo "github.com/yucai/server/internal/tag/adapter/driven/repository"
	"github.com/yucai/server/internal/tag/application"
	"github.com/yucai/server/internal/tag/domain"
	tagent "github.com/yucai/server/internal/tag/ent"
)

func setupTagTestDB(t *testing.T) *tagent.Client {
	t.Helper()
	dbName := "tag_ent_" + t.Name()
	db, err := sql.Open("sqlite", "file:"+dbName+"?mode=memory")
	if err != nil {
		t.Fatalf("open sqlite: %v", err)
	}
	t.Cleanup(func() { db.Close() })

	// Set foreign_keys pragma on every connection in the pool
	db.SetMaxOpenConns(1)
	if _, err := db.Exec("PRAGMA foreign_keys = ON"); err != nil {
		t.Fatalf("enable foreign keys: %v", err)
	}

	drv := entsql.OpenDB(dialect.SQLite, db)
	client := tagent.NewClient(tagent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate schema: %v", err)
	}
	t.Cleanup(func() { client.Close() })
	return client
}

func TestTagCRUD(t *testing.T) {
	client := setupTagTestDB(t)
	repo := tagrepo.NewTagRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantID := uuid.New()

	// Create
	resp, err := svc.CreateTag(ctx, application.CreateTagRequest{
		TenantID: tenantID,
		Name:     "Food",
		Color:    "#FF5733",
	})
	if err != nil {
		t.Fatalf("CreateTag failed: %v", err)
	}
	if resp.Version != 1 {
		t.Errorf("expected version 1, got %d", resp.Version)
	}
	tagID := resp.ID

	// Update
	updated, err := svc.UpdateTag(ctx, application.UpdateTagRequest{
		TenantID: tenantID,
		ID:       tagID,
		Name:     "Dining",
		Color:    "#00FF00",
		Version:  1,
	})
	if err != nil {
		t.Fatalf("UpdateTag failed: %v", err)
	}
	if updated.Name != "Dining" {
		t.Errorf("expected Dining, got %s", updated.Name)
	}
	if updated.Version != 2 {
		t.Errorf("expected version 2, got %d", updated.Version)
	}

	// List
	result, err := svc.ListTags(ctx, application.ListTagsRequest{
		TenantID: tenantID,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("ListTags failed: %v", err)
	}
	if len(result.Tags) != 1 {
		t.Errorf("expected 1 tag, got %d", len(result.Tags))
	}

	// Delete
	err = svc.DeleteTag(ctx, tenantID, tagID)
	if err != nil {
		t.Fatalf("DeleteTag failed: %v", err)
	}

	// Verify soft-deleted (list should be empty)
	result2, _ := svc.ListTags(ctx, application.ListTagsRequest{
		TenantID: tenantID,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if len(result2.Tags) != 0 {
		t.Errorf("expected 0 tags after delete, got %d", len(result2.Tags))
	}
}

func TestTagNameUniqueness(t *testing.T) {
	client := setupTagTestDB(t)
	repo := tagrepo.NewTagRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantID := uuid.New()

	_, err := svc.CreateTag(ctx, application.CreateTagRequest{
		TenantID: tenantID, Name: "Food", Color: "#FF5733",
	})
	if err != nil {
		t.Fatalf("first CreateTag failed: %v", err)
	}

	_, err = svc.CreateTag(ctx, application.CreateTagRequest{
		TenantID: tenantID, Name: "Food", Color: "#00FF00",
	})
	if err == nil {
		t.Error("expected error for duplicate tag name within tenant")
	}
}

func TestTagTransactionAssociation(t *testing.T) {
	client := setupTagTestDB(t)
	repo := tagrepo.NewTagRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantID := uuid.New()

	tag1, _ := svc.CreateTag(ctx, application.CreateTagRequest{
		TenantID: tenantID, Name: "Food", Color: "#FF5733",
	})
	tag2, _ := svc.CreateTag(ctx, application.CreateTagRequest{
		TenantID: tenantID, Name: "Work", Color: "#00FF00",
	})
	txnID := uuid.New()

	// Add tags to transaction
	svc.AddTagToTransaction(ctx, tag1.ID, txnID)
	svc.AddTagToTransaction(ctx, tag2.ID, txnID)

	// Get tags for transaction
	result, err := svc.GetTransactionTags(ctx, tenantID, txnID)
	if err != nil {
		t.Fatalf("GetTransactionTags failed: %v", err)
	}
	if len(result.Tags) != 2 {
		t.Errorf("expected 2 tags, got %d", len(result.Tags))
	}

	// Remove one tag
	svc.RemoveTagFromTransaction(ctx, tag1.ID, txnID)

	result2, _ := svc.GetTransactionTags(ctx, tenantID, txnID)
	if len(result2.Tags) != 1 {
		t.Errorf("expected 1 tag after remove, got %d", len(result2.Tags))
	}
	if result2.Tags[0].Name != "Work" {
		t.Errorf("expected Work tag remaining, got %s", result2.Tags[0].Name)
	}
}

func TestTagSearch(t *testing.T) {
	client := setupTagTestDB(t)
	repo := tagrepo.NewTagRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantID := uuid.New()

	svc.CreateTag(ctx, application.CreateTagRequest{TenantID: tenantID, Name: "Food", Color: "#FF5733"})
	svc.CreateTag(ctx, application.CreateTagRequest{TenantID: tenantID, Name: "Transport", Color: "#00FF00"})
	svc.CreateTag(ctx, application.CreateTagRequest{TenantID: tenantID, Name: "Entertainment", Color: "#0000FF"})

	result, err := svc.ListTags(ctx, application.ListTagsRequest{
		TenantID: tenantID,
		Search:   "oo",
		Page:     domain.PageRequest{PageSize: 10},
	})
	if err != nil {
		t.Fatalf("ListTags search failed: %v", err)
	}
	if len(result.Tags) != 1 {
		t.Errorf("expected 1 tag matching 'oo', got %d", len(result.Tags))
	}
	if result.Tags[0].Name != "Food" {
		t.Errorf("expected Food, got %s", result.Tags[0].Name)
	}
}

func TestTagTenantIsolation(t *testing.T) {
	client := setupTagTestDB(t)
	repo := tagrepo.NewTagRepository(client)
	svc := application.NewService(repo)
	ctx := context.Background()
	tenantA := uuid.New()
	tenantB := uuid.New()

	svc.CreateTag(ctx, application.CreateTagRequest{TenantID: tenantA, Name: "Food", Color: "#FF5733"})

	result, _ := svc.ListTags(ctx, application.ListTagsRequest{
		TenantID: tenantB,
		Page:     domain.PageRequest{PageSize: 10},
	})
	if len(result.Tags) != 0 {
		t.Errorf("tenant B should see 0 tags, got %d", len(result.Tags))
	}

	// Same name in different tenant should succeed
	_, err := svc.CreateTag(ctx, application.CreateTagRequest{TenantID: tenantB, Name: "Food", Color: "#FF5733"})
	if err != nil {
		t.Errorf("same name in different tenant should be allowed: %v", err)
	}
}
