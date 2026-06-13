package domain

import (
	"testing"
)

func TestNewCurrency_Valid(t *testing.T) {
	c, err := NewCurrency("cny", "Chinese Yuan", "¥", 1.0)
	if err != nil {
		t.Fatalf("NewCurrency failed: %v", err)
	}
	if c.Code != "CNY" {
		t.Errorf("expected uppercase CNY, got %s", c.Code)
	}
}

func TestNewCurrency_InvalidCode(t *testing.T) {
	_, err := NewCurrency("C", "Test", "", 1.0)
	if err == nil {
		t.Error("expected error for short code")
	}
}

func TestNewCurrency_EmptyCode(t *testing.T) {
	_, err := NewCurrency("  ", "Test", "", 1.0)
	if err == nil {
		t.Error("expected error for empty code")
	}
}

func TestNewCurrency_InvalidRate(t *testing.T) {
	_, err := NewCurrency("CNY", "Yuan", "", -1.0)
	if err == nil {
		t.Error("expected error for negative rate")
	}
}

func TestNewCurrency_EmptyName(t *testing.T) {
	_, err := NewCurrency("CNY", "", "", 1.0)
	if err == nil {
		t.Error("expected error for empty name")
	}
}

func TestCurrency_UpdateRate(t *testing.T) {
	c, _ := NewCurrency("CNY", "Yuan", "", 1.0)
	if err := c.UpdateRate(6.5); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if c.ExchangeRate != 6.5 {
		t.Errorf("expected rate 6.5, got %f", c.ExchangeRate)
	}
}

func TestCurrency_DeactivateActivate(t *testing.T) {
	c, _ := NewCurrency("CNY", "Yuan", "", 1.0)
	c.Deactivate()
	if c.IsActive {
		t.Error("expected inactive")
	}
	c.Activate()
	if !c.IsActive {
		t.Error("expected active")
	}
}
