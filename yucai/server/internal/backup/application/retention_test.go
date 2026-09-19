package application

// F40 auto-backup retention — application-layer integration tests for the
// keep-newest-30 policy (provider=auto only; manual untouched; restore-freeze
// respected). Backups are seeded directly through the repo + provider fakes
// (bypassing CreateBackup) so tests control CreatedAt and bulk counts, exactly
// how rows arrive from real scheduler runs.

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/yucai/server/internal/backup/domain"
)

// seedBackup inserts one backup record + provider file with an explicit
// CreatedAt. Files are uploaded with a per-backup payload so tests can assert
// the retention path removes the victim FILES (not just rows) via the same
// DeleteBackup pipeline manual deletes use.
func seedBackup(t *testing.T, repo *fakeRepo, prov *fakeProvider, tenantID uuid.UUID, auto bool, createdAt time.Time) *domain.Backup {
	t.Helper()
	b, err := domain.NewBackup(tenantID, domain.BackupProviderLocal, false, auto)
	if err != nil {
		t.Fatalf("NewBackup: %v", err)
	}
	b.CreatedAt = createdAt
	b.UpdatedAt = createdAt
	ctx := context.Background()
	if err := prov.Upload(ctx, b.Filename, []byte("payload:"+b.ID.String())); err != nil {
		t.Fatalf("upload seed file: %v", err)
	}
	if err := repo.Save(ctx, b); err != nil {
		t.Fatalf("save seed record: %v", err)
	}
	return b
}

// TestEnforceAutoBackupRetention_KeepsNewestThirty: 35 auto backups with
// staggered created_at → the 5 OLDEST are deleted (records AND provider
// files); the newest 30 remain.
func TestEnforceAutoBackupRetention_KeepsNewestThirty(t *testing.T) {
	tenantID := uuid.New()
	svc, repo, prov := newTestService(nil)
	base := time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC)
	seeded := make([]*domain.Backup, 0, 35)
	for i := 0; i < 35; i++ {
		seeded = append(seeded, seedBackup(t, repo, prov, tenantID, true, base.Add(time.Duration(i)*time.Minute)))
	}

	deleted, err := svc.EnforceAutoBackupRetention(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("EnforceAutoBackupRetention: %v", err)
	}
	if deleted != 5 {
		t.Fatalf("deleted = %d, want 5 (35 seeded, keep 30)", deleted)
	}

	ctx := context.Background()
	autos, err := repo.FindByAuto(ctx, tenantID, true)
	if err != nil {
		t.Fatalf("FindByAuto: %v", err)
	}
	if len(autos) != 30 {
		t.Fatalf("auto backups remaining = %d, want 30", len(autos))
	}
	// Survivors must be exactly the newest 30 (index 5..34); oldest 5 (0..4)
	// must be gone from both the repo and the provider.
	wantKept := make(map[uuid.UUID]bool)
	for _, b := range seeded[5:] {
		wantKept[b.ID] = true
	}
	for _, b := range autos {
		if !wantKept[b.ID] {
			t.Errorf("survivor %s is not among the newest 30 auto backups", b.ID)
		}
		if _, ok := prov.files[b.Filename]; !ok {
			t.Errorf("kept backup file %s missing from provider", b.Filename)
		}
	}
	for _, b := range seeded[:5] {
		if _, err := repo.FindByID(ctx, tenantID, b.ID); err == nil {
			t.Errorf("oldest auto backup %s still present in repo; want deleted", b.ID)
		}
		if _, ok := prov.files[b.Filename]; ok {
			t.Errorf("deleted auto backup file %s still on provider; want removed", b.Filename)
		}
	}
}

// TestEnforceAutoBackupRetention_ManualUntouchedWhenAutoOverflows: 35 auto +
// 5 manual → auto trimmed to the newest 30; the 5 manual backups (records and
// files) untouched. The keep-30 budget scopes to provider=auto ONLY — a
// mixed-budget implementation (counting manual toward 30) would keep only 25
// auto here and fail.
func TestEnforceAutoBackupRetention_ManualUntouchedWhenAutoOverflows(t *testing.T) {
	tenantID := uuid.New()
	svc, repo, prov := newTestService(nil)
	base := time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC)
	var autoSeeded, manualSeeded []*domain.Backup
	for i := 0; i < 35; i++ {
		autoSeeded = append(autoSeeded, seedBackup(t, repo, prov, tenantID, true, base.Add(time.Duration(i)*time.Minute)))
	}
	for i := 0; i < 5; i++ {
		manualSeeded = append(manualSeeded, seedBackup(t, repo, prov, tenantID, false, base.Add(time.Duration(100+i)*time.Minute)))
	}

	deleted, err := svc.EnforceAutoBackupRetention(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("EnforceAutoBackupRetention: %v", err)
	}
	if deleted != 5 {
		t.Fatalf("deleted = %d, want 5 (only the 5 oldest AUTO; manual never counted)", deleted)
	}

	ctx := context.Background()
	autos, err := repo.FindByAuto(ctx, tenantID, true)
	if err != nil {
		t.Fatalf("FindByAuto(auto): %v", err)
	}
	if len(autos) != 30 {
		t.Fatalf("auto backups remaining = %d, want 30", len(autos))
	}
	newestAuto := make(map[uuid.UUID]bool)
	for _, b := range autoSeeded[5:] {
		newestAuto[b.ID] = true
	}
	for _, b := range autos {
		if !newestAuto[b.ID] {
			t.Errorf("auto survivor %s is not among the newest 30 auto backups", b.ID)
		}
	}
	// All 5 manual backups fully intact — records AND files.
	for _, b := range manualSeeded {
		if _, err := repo.FindByID(ctx, tenantID, b.ID); err != nil {
			t.Errorf("manual backup %s deleted; manual backups must never be trimmed", b.ID)
		}
		if _, ok := prov.files[b.Filename]; !ok {
			t.Errorf("manual backup file %s removed from provider; want untouched", b.Filename)
		}
	}
}

// TestEnforceAutoBackupRetention_UnderLimitKeepsAll: 10 auto + 5 manual
// (both below the keep-30 threshold) → nothing deleted, every record and file
// stays exactly as seeded.
func TestEnforceAutoBackupRetention_UnderLimitKeepsAll(t *testing.T) {
	tenantID := uuid.New()
	svc, repo, prov := newTestService(nil)
	base := time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC)
	var all []*domain.Backup
	for i := 0; i < 10; i++ {
		all = append(all, seedBackup(t, repo, prov, tenantID, true, base.Add(time.Duration(i)*time.Minute)))
	}
	for i := 0; i < 5; i++ {
		all = append(all, seedBackup(t, repo, prov, tenantID, false, base.Add(time.Duration(50+i)*time.Minute)))
	}

	deleted, err := svc.EnforceAutoBackupRetention(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("EnforceAutoBackupRetention: %v", err)
	}
	if deleted != 0 {
		t.Fatalf("deleted = %d, want 0 (under the keep-30 limit nothing is trimmed)", deleted)
	}
	ctx := context.Background()
	for _, b := range all {
		if _, err := repo.FindByID(ctx, tenantID, b.ID); err != nil {
			t.Errorf("backup %s (auto=%v) missing after pass; want retained", b.ID, b.Auto)
		}
		if _, ok := prov.files[b.Filename]; !ok {
			t.Errorf("file %s (auto=%v) missing from provider; want retained", b.Filename, b.Auto)
		}
	}
}

// TestEnforceAutoBackupRetention_RestoreFrozenSkips: while a restore freeze is
// held on the tenant (D12), the trim is skipped entirely — no deletion may
// race an in-progress restore (the scheduler pass gate plus this service-level
// check make the invariant hold for ANY caller).
func TestEnforceAutoBackupRetention_RestoreFrozenSkips(t *testing.T) {
	tenantID := uuid.New()
	svc, repo, prov := newTestService(nil)
	base := time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC)
	for i := 0; i < 35; i++ {
		seedBackup(t, repo, prov, tenantID, true, base.Add(time.Duration(i)*time.Minute))
	}

	release := svc.freeze.Acquire(tenantID)
	defer release()

	deleted, err := svc.EnforceAutoBackupRetention(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("EnforceAutoBackupRetention under freeze: %v", err)
	}
	if deleted != 0 {
		t.Fatalf("deleted = %d under restore freeze, want 0 (trim must skip frozen tenants)", deleted)
	}
	autos, err := repo.FindByAuto(context.Background(), tenantID, true)
	if err != nil {
		t.Fatalf("FindByAuto: %v", err)
	}
	if len(autos) != 35 {
		t.Fatalf("auto backups remaining = %d under freeze, want 35 (nothing trimmed)", len(autos))
	}
}
