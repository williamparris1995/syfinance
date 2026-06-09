package command

import (
	"context"
	"fmt"
	"sync"
)

// Handler processes a command of type T and returns an error.
type Handler[T any] interface {
	Handle(ctx context.Context, cmd T) error
}

// handlerWrapper erases type for internal storage.
type handlerWrapper struct {
	handler any
}

// Bus dispatches commands to their registered handlers.
type Bus struct {
	mu       sync.RWMutex
	handlers map[string]handlerWrapper
}

// NewBus creates a new in-memory command bus.
func NewBus() *Bus {
	return &Bus{
		handlers: make(map[string]handlerWrapper),
	}
}

// Register adds a handler for its command type.
// The handler must implement Handler[T] for some T.
func Register[T any](bus *Bus, h Handler[T]) {
	bus.mu.Lock()
	defer bus.mu.Unlock()
	var zero T
	name := fmt.Sprintf("%T", zero)
	bus.handlers[name] = handlerWrapper{handler: h}
}

// Dispatch sends a command to its registered handler.
func Dispatch[T any](bus *Bus, ctx context.Context, cmd T) error {
	bus.mu.RLock()
	defer bus.mu.RUnlock()
	name := fmt.Sprintf("%T", cmd)
	wrapper, ok := bus.handlers[name]
	if !ok {
		return fmt.Errorf("no handler registered for command %T", cmd)
	}
	handler, ok := wrapper.handler.(Handler[T])
	if !ok {
		return fmt.Errorf("handler for %T has wrong type", cmd)
	}
	return handler.Handle(ctx, cmd)
}
