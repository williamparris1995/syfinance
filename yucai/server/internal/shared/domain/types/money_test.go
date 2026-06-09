package types

import (
	"testing"
)

func TestMoneyAdd(t *testing.T) {
	a := Money{Cents: 1000, CurrencyCode: "CNY"}
	b := Money{Cents: 500, CurrencyCode: "CNY"}
	result := a.Add(b)
	if result.Cents != 1500 {
		t.Errorf("expected 1500 cents, got %d", result.Cents)
	}
}

func TestMoneyAddDifferentCurrency(t *testing.T) {
	a := Money{Cents: 1000, CurrencyCode: "CNY"}
	b := Money{Cents: 500, CurrencyCode: "USD"}
	result := a.Add(b)
	if result.Cents != 1000 {
		t.Errorf("adding different currencies should return self unchanged, got %d", result.Cents)
	}
}

func TestMoneySubtract(t *testing.T) {
	a := Money{Cents: 1000, CurrencyCode: "CNY"}
	b := Money{Cents: 300, CurrencyCode: "CNY"}
	result := a.Subtract(b)
	if result.Cents != 700 {
		t.Errorf("expected 700 cents, got %d", result.Cents)
	}
}

func TestMoneyToYuan(t *testing.T) {
	m := Money{Cents: 12345, CurrencyCode: "CNY"}
	if m.ToYuan() != 123.45 {
		t.Errorf("expected 123.45, got %f", m.ToYuan())
	}
}

func TestMoneyFromYuan(t *testing.T) {
	m := NewMoneyFromYuan(123.45, "CNY")
	if m.Cents != 12345 {
		t.Errorf("expected 12345 cents, got %d", m.Cents)
	}
}

func TestMoneyIsNegative(t *testing.T) {
	pos := Money{Cents: 100, CurrencyCode: "CNY"}
	zero := Money{Cents: 0, CurrencyCode: "CNY"}
	neg := Money{Cents: -100, CurrencyCode: "CNY"}
	if pos.IsNegative() {
		t.Error("positive money should not be negative")
	}
	if zero.IsNegative() {
		t.Error("zero money should not be negative")
	}
	if !neg.IsNegative() {
		t.Error("negative money should be negative")
	}
}
