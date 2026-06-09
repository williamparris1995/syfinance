package command

import (
	"context"
	"testing"
)

type testCommand struct {
	Name string
}

type testCommandHandler struct {
	Received testCommand
}

func (h *testCommandHandler) Handle(ctx context.Context, cmd testCommand) error {
	h.Received = cmd
	return nil
}

func TestCommandBusDispatch(t *testing.T) {
	bus := NewBus()
	handler := &testCommandHandler{}
	Register(bus, handler)

	cmd := testCommand{Name: "create_account"}
	err := Dispatch(context.Background(), bus, cmd)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if handler.Received.Name != "create_account" {
		t.Errorf("handler did not receive command, got: %s", handler.Received.Name)
	}
}
