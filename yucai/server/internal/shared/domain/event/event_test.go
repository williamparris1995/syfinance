package event

import (
	"testing"
	"time"
)

type mockEvent struct {
	baseEvent
	AccountID string
}

func TestDomainEventImplementsInterface(t *testing.T) {
	evt := mockEvent{
		baseEvent: baseEvent{
			EventType:   "account.created",
			OccurredAt:  time.Now(),
			AggregateID: "test-id",
		},
		AccountID: "acc-123",
	}
	if evt.EventType != "account.created" {
		t.Errorf("expected account.created, got %s", evt.EventType)
	}
	if evt.AggregateID != "test-id" {
		t.Errorf("expected test-id, got %s", evt.AggregateID)
	}
}
