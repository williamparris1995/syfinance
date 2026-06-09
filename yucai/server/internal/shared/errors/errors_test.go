package errors

import (
	"errors"
	"testing"
)

func TestDomainErrorFormat(t *testing.T) {
	err := New("TEST_CODE", "test message")
	got := err.Error()
	expected := "[TEST_CODE] test message"
	if got != expected {
		t.Errorf("expected %q, got %q", expected, got)
	}
}

func TestDomainErrorUnwrap(t *testing.T) {
	inner := errors.New("inner error")
	err := Wrap("WRAP_CODE", "wrapped", inner)
	if !errors.Is(err, inner) {
		t.Error("expected errors.Is to match inner error")
	}
}

func TestPredefinedErrors(t *testing.T) {
	if ErrNotFound.Code != "NOT_FOUND" {
		t.Errorf("expected NOT_FOUND, got %s", ErrNotFound.Code)
	}
	if ErrBalanceViolation.Code != "BALANCE_VIOLATION" {
		t.Errorf("expected BALANCE_VIOLATION, got %s", ErrBalanceViolation.Code)
	}
}
