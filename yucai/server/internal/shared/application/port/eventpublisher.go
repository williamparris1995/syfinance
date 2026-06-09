package port

import "github.com/yucai/server/internal/shared/domain/event"

// EventPublisher publishes domain events to subscribers.
type EventPublisher interface {
	Publish(events ...event.DomainEvent) error
}
