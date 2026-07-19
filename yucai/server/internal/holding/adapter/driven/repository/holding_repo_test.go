package repository_test

import (
	"context"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/holding/adapter/driven/repository"
	"github.com/yucai/server/internal/holding/domain"
)

// TestSaveOrUpdate_CreateFillsDefaultCreatedAt verifies the adapter fills
// CreatedAt from ent Default(time.Now) when the caller omits it (CreatedAt
// zero) — the production BuyHolding path (service.go:96-100 omits CreatedAt on
// the new-holding struct literal). Without the IsZero fallback, SetCreatedAt
// (zero) overrode ent Default → portfolioCAGR nil for all users (earliest-
// HoldingCreated zero → service.go:1554 guard skip). See spec
// 2026-07-19-holding-createdat-bug-design.md.
func TestSaveOrUpdate_CreateFillsDefaultCreatedAt(t *testing.T) {
	client := setupHoldingTestDB(t) // from testdb_test.go (same package)
	repo := repository.NewHoldingRepository(client)
	ctx := context.Background()

	// seed holding with CreatedAt zero (simulates BuyHolding omit).
	h := &domain.Holding{
		ID:         uuid.New(),
		TenantID:   uuid.New(),
		AccountID:  uuid.New(),
		SecurityID: uuid.New(),
		// CreatedAt zero (simulates BuyHolding service.go:96-100 omit).
	}
	if err := repo.SaveOrUpdate(ctx, h); err != nil {
		t.Fatalf("SaveOrUpdate: %v", err)
	}

	// Read back: CreatedAt must be non-zero (ent Default(time.Now) via IsZero fallback).
	got, err := repo.FindByAccountAndSecurity(ctx, h.TenantID, h.AccountID, h.SecurityID)
	if err != nil || got == nil {
		t.Fatalf("FindByAccountAndSecurity: err=%v got=%v", err, got)
	}
	if got.CreatedAt.IsZero() {
		t.Error("CreatedAt zero after SaveOrUpdate(Create with zero); want ent Default(time.Now) via IsZero fallback")
	}
}
