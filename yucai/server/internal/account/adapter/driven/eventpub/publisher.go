package eventpub

import (
	"log/slog"

	"github.com/yucai/server/internal/shared/domain/event"
)

// LoggingPublisher logs domain events synchronously.
// Async/event-driven publishing can be added later.
type LoggingPublisher struct{}

// NewLoggingPublisher creates a new LoggingPublisher.
func NewLoggingPublisher() *LoggingPublisher {
	return &LoggingPublisher{}
}

// Publish logs all domain events at info level.
func (p *LoggingPublisher) Publish(events ...event.DomainEvent) error {
	for _, e := range events {
		slog.Info("domain event published",
			"event_type", e.GetEventType(),
			"aggregate_id", e.GetAggregateID(),
		)
	}
	return nil
}
