package event

import (
	"time"
)

// DomainEvent is the interface all domain events must satisfy.
type DomainEvent interface {
	GetEventType() string
	GetOccurredAt() time.Time
	GetAggregateID() string
}

// baseEvent provides default fields for domain events.
// Embed in concrete event structs.
type baseEvent struct {
	EventType   string    `json:"event_type"`
	OccurredAt  time.Time `json:"occurred_at"`
	AggregateID string    `json:"aggregate_id"`
}

func (e baseEvent) GetEventType() string    { return e.EventType }
func (e baseEvent) GetOccurredAt() time.Time { return e.OccurredAt }
func (e baseEvent) GetAggregateID() string   { return e.AggregateID }
