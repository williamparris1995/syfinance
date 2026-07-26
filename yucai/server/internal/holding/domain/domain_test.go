package domain

import (
	"math"
	"testing"
)

func TestNewSecurity_Valid(t *testing.T) {
	s, err := NewSecurity("600519.SH", "Kweichow Moutai", SecurityTypeStock, "SHA", "CNY")
	if err != nil {
		t.Fatalf("NewSecurity failed: %v", err)
	}
	if s.Symbol != "600519.SH" {
		t.Errorf("expected 600519.SH, got %s", s.Symbol)
	}
}

func TestNewSecurity_EmptySymbol(t *testing.T) {
	_, err := NewSecurity("", "Test", SecurityTypeStock, "", "CNY")
	if err == nil {
		t.Error("expected error for empty symbol")
	}
}

func TestHolding_ApplyBuy(t *testing.T) {
	h := &Holding{Quantity: 0, AvgCostCents: 0}
	h.ApplyBuy(100, 5000, 0)
	if h.Quantity != 100 {
		t.Errorf("expected 100, got %f", h.Quantity)
	}
	if h.AvgCostCents != 5000 {
		t.Errorf("expected avg cost 5000, got %d", h.AvgCostCents)
	}

	// Second buy at different price
	h.ApplyBuy(100, 6000, 0)
	if math.Abs(h.Quantity-200) > 0.001 {
		t.Errorf("expected 200, got %f", h.Quantity)
	}
	if h.AvgCostCents != 5500 { // (5000*100 + 6000*100) / 200
		t.Errorf("expected avg cost 5500, got %d", h.AvgCostCents)
	}
}

// TestHolding_ApplyBuyWithFee verifies buy fee capitalizes into cost basis:
// new per-share avg = (oldAvg×oldQty + price×qty + fee) / (oldQty + qty).
// 100@5000 c/sh (no fee) → avg 5000; then buy 100@6000 c/sh + 1000 c fee:
// total cost = 5000*100 + 6000*100 + 1000 = 500000+600000+1000 = 1101000;
// qty = 200; avg = 1101000/200 = 5505 c/sh.
func TestHolding_ApplyBuyWithFee(t *testing.T) {
	h := &Holding{Quantity: 0, AvgCostCents: 0}
	h.ApplyBuy(100, 5000, 0)
	h.ApplyBuy(100, 6000, 1000)
	if math.Abs(h.Quantity-200) > 0.001 {
		t.Errorf("expected 200, got %f", h.Quantity)
	}
	if h.AvgCostCents != 5505 {
		t.Errorf("expected avg cost 5505 (fee capitalized), got %d", h.AvgCostCents)
	}
}

// TestHolding_ApplyBuyWithFeeSingleBuy verifies the simple case from the spec:
// one buy 100@1000 c/sh + 500 c fee → lot total 100500, per-sh 1005 c.
func TestHolding_ApplyBuyWithFeeSingleBuy(t *testing.T) {
	h := &Holding{Quantity: 0, AvgCostCents: 0}
	h.ApplyBuy(100, 1000, 500)
	if h.AvgCostCents != 1005 {
		t.Errorf("expected avg cost 1005 (100000+500)/100 rounded, got %d", h.AvgCostCents)
	}
}

func TestHolding_ApplySell(t *testing.T) {
	h := &Holding{Quantity: 200, AvgCostCents: 5000}
	pnl, err := h.ApplySell(100, 6000)
	if err != nil {
		t.Fatalf("ApplySell failed: %v", err)
	}
	if pnl != 100000 { // (6000 - 5000) * 100
		t.Errorf("expected P&L 100000, got %d", pnl)
	}
	if math.Abs(h.Quantity-100) > 0.001 {
		t.Errorf("expected 100 remaining, got %f", h.Quantity)
	}
}

func TestHolding_ApplySell_InsufficientShares(t *testing.T) {
	h := &Holding{Quantity: 50, AvgCostCents: 5000}
	_, err := h.ApplySell(100, 6000)
	if err == nil {
		t.Error("expected error for insufficient shares")
	}
}

func TestHolding_ApplySplit(t *testing.T) {
	h := &Holding{Quantity: 100, AvgCostCents: 5000}
	h.ApplySplit(2.0) // 2:1 split
	if math.Abs(h.Quantity-200) > 0.001 {
		t.Errorf("expected 200 after 2:1 split, got %f", h.Quantity)
	}
	if h.AvgCostCents != 2500 {
		t.Errorf("expected avg cost 2500 after split, got %d", h.AvgCostCents)
	}
}

func TestHolding_MarketValue(t *testing.T) {
	h := &Holding{Quantity: 100, AvgCostCents: 5000}
	mv := h.MarketValue(8000)
	if mv != 800000 { // 8000 * 100
		t.Errorf("expected 800000, got %d", mv)
	}
}

func TestHolding_UnrealizedPnL(t *testing.T) {
	h := &Holding{Quantity: 100, AvgCostCents: 5000}
	pnl := h.UnrealizedPnL(8000)
	if pnl != 300000 { // (8000 - 5000) * 100
		t.Errorf("expected 300000, got %d", pnl)
	}
}

func TestHolding_ApplyDividend(t *testing.T) {
	h := &Holding{Quantity: 100, AvgCostCents: 5000}
	total := h.ApplyDividend(100, 500) // 500 cents per share
	if total != 50000 {
		t.Errorf("expected 50000 dividend, got %d", total)
	}
}

func TestSecurityType_RoundTrip(t *testing.T) {
	types := []SecurityType{SecurityTypeStock, SecurityTypeFund, SecurityTypeETF, SecurityTypeBond, SecurityTypeGold, SecurityTypeOption, SecurityTypeOther}
	for _, st := range types {
		if ParseSecurityType(st.String()) != st {
			t.Errorf("round-trip failed for %v", st)
		}
	}
}

func TestTradeType_RoundTrip(t *testing.T) {
	types := []TradeType{TradeTypeBuy, TradeTypeSell, TradeTypeDividend, TradeTypeSplit}
	for _, tt := range types {
		if ParseTradeType(tt.String()) != tt {
			t.Errorf("round-trip failed for %v", tt)
		}
	}
}
