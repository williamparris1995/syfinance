package domain

import (
	"encoding/json"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestBackupEnvelopeMarshalRoundtrip(t *testing.T) {
	tenantID := uuid.New()
	e := BackupEnvelope{
		Version:   1,
		TenantID:  tenantID,
		CreatedAt: time.Date(2026, 7, 13, 12, 0, 0, 0, time.UTC),
		Modules: map[string]json.RawMessage{
			"account": json.RawMessage(`[{"id":"a1"}]`),
		},
	}
	raw, err := json.Marshal(e)
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	var got BackupEnvelope
	if err := json.Unmarshal(raw, &got); err != nil {
		t.Fatalf("unmarshal: %v", err)
	}
	if got.Version != 1 || got.TenantID != tenantID {
		t.Fatalf("envelope mismatch: %+v", got)
	}
	if string(got.Modules["account"]) != `[{"id":"a1"}]` {
		t.Fatalf("module data mismatch: %s", got.Modules["account"])
	}
}
