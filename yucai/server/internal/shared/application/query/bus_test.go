package query

import (
	"context"
	"testing"
)

type testQuery struct {
	ID string
}

type testResult struct {
	Name string
}

type testQueryHandler struct{}

func (h *testQueryHandler) Handle(ctx context.Context, q testQuery) (testResult, error) {
	return testResult{Name: "result-for-" + q.ID}, nil
}

func TestQueryBusDispatch(t *testing.T) {
	bus := NewBus()
	handler := &testQueryHandler{}
	Register(bus, handler)

	result, err := Dispatch(context.Background(), bus, testQuery{ID: "abc"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if result.Name != "result-for-abc" {
		t.Errorf("expected result-for-abc, got %s", result.Name)
	}
}
