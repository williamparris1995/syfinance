package domain

import (
	"testing"

	"github.com/google/uuid"
)

func TestNewSyncDevice_Valid(t *testing.T) {
	d, err := NewSyncDevice(uuid.New(), "iPhone 15")
	if err != nil {
		t.Fatalf("NewSyncDevice failed: %v", err)
	}
	if d.DeviceName != "iPhone 15" {
		t.Error("expected device name to be set")
	}
	if d.LastSyncVersion != 0 {
		t.Error("expected initial version to be 0")
	}
}

func TestNewSyncDevice_EmptyName(t *testing.T) {
	_, err := NewSyncDevice(uuid.New(), "")
	if err == nil {
		t.Error("expected error for empty device name")
	}
}

func TestSyncDevice_UpdateSyncVersion(t *testing.T) {
	d, _ := NewSyncDevice(uuid.New(), "TestDevice")
	d.UpdateSyncVersion(42)
	if d.LastSyncVersion != 42 {
		t.Errorf("expected version 42, got %d", d.LastSyncVersion)
	}
	if d.LastSyncAt.IsZero() {
		t.Error("expected LastSyncAt to be set")
	}
}

func TestSyncOperation_RoundTrip(t *testing.T) {
	ops := []SyncOperation{SyncOperationCreate, SyncOperationUpdate, SyncOperationDelete}
	for _, op := range ops {
		if ParseSyncOperation(op.String()) != op {
			t.Errorf("round-trip failed for %v", op)
		}
	}
}

func TestConflictResolution_RoundTrip(t *testing.T) {
	resolutions := []ConflictResolution{ConflictResolutionServerWins, ConflictResolutionClientWins, ConflictResolutionMerged}
	for _, r := range resolutions {
		if ParseConflictResolution(r.String()) != r {
			t.Errorf("round-trip failed for %v", r)
		}
	}
}

func TestSyncConflict_Resolve(t *testing.T) {
	c := NewSyncConflict(uuid.New(), "account", uuid.New(), "update_update", []byte("server"), []byte("client"))
	if !c.IsPending() {
		t.Error("expected conflict to be pending initially")
	}
	c.Resolve(ConflictResolutionServerWins)
	if c.IsPending() {
		t.Error("expected conflict to be resolved")
	}
	if c.ResolvedAt == nil {
		t.Error("expected ResolvedAt to be set")
	}
}
