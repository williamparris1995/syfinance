package types

import (
	"github.com/shopspring/decimal"
)

// Money represents a monetary amount as integer cents.
// All arithmetic uses integer cents to avoid floating point precision issues.
type Money struct {
	Cents        int64
	CurrencyCode string
}

// NewMoney creates a Money from cents.
func NewMoney(cents int64, currencyCode string) Money {
	return Money{Cents: cents, CurrencyCode: currencyCode}
}

// NewMoneyFromYuan creates a Money from a yuan (dollar) amount.
func NewMoneyFromYuan(yuan float64, currencyCode string) Money {
	d := decimal.NewFromFloat(yuan).Mul(decimal.NewFromInt(100))
	return Money{Cents: d.IntPart(), CurrencyCode: currencyCode}
}

// Add adds two Money values. Returns self unchanged if currencies differ.
func (m Money) Add(other Money) Money {
	if m.CurrencyCode != other.CurrencyCode {
		return m
	}
	return Money{Cents: m.Cents + other.Cents, CurrencyCode: m.CurrencyCode}
}

// Subtract subtracts other from m. Returns self unchanged if currencies differ.
func (m Money) Subtract(other Money) Money {
	if m.CurrencyCode != other.CurrencyCode {
		return m
	}
	return Money{Cents: m.Cents - other.Cents, CurrencyCode: m.CurrencyCode}
}

// ToYuan converts cents to yuan (dollar) amount.
func (m Money) ToYuan() float64 {
	d := decimal.NewFromInt(m.Cents).Div(decimal.NewFromInt(100))
	f, _ := d.Float64()
	return f
}

// IsNegative returns true if cents < 0.
func (m Money) IsNegative() bool {
	return m.Cents < 0
}

// IsZero returns true if cents == 0.
func (m Money) IsZero() bool {
	return m.Cents == 0
}

// SameCurrency checks if two Money values share the same currency.
func (m Money) SameCurrency(other Money) bool {
	return m.CurrencyCode == other.CurrencyCode
}
