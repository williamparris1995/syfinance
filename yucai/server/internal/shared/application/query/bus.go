package query

import (
	"context"
	"fmt"
	"sync"
)

// Handler processes a query of type Q and returns a result of type R.
type Handler[Q any, R any] interface {
	Handle(ctx context.Context, q Q) (R, error)
}

type handlerWrapper struct {
	handler any
}

// Bus dispatches queries to their registered handlers.
type Bus struct {
	mu       sync.RWMutex
	handlers map[string]handlerWrapper
}

func NewBus() *Bus {
	return &Bus{
		handlers: make(map[string]handlerWrapper),
	}
}

func Register[Q any, R any](bus *Bus, h Handler[Q, R]) {
	bus.mu.Lock()
	defer bus.mu.Unlock()
	var zero Q
	name := fmt.Sprintf("%T", zero)
	bus.handlers[name] = handlerWrapper{handler: h}
}

func Dispatch[Q any, R any](bus *Bus, ctx context.Context, q Q) (R, error) {
	bus.mu.RLock()
	defer bus.mu.RUnlock()
	var zero R
	name := fmt.Sprintf("%T", q)
	wrapper, ok := bus.handlers[name]
	if !ok {
		return zero, fmt.Errorf("no handler registered for query %T", q)
	}
	handler, ok := wrapper.handler.(Handler[Q, R])
	if !ok {
		return zero, fmt.Errorf("handler for %T has wrong type", q)
	}
	return handler.Handle(ctx, q)
}
