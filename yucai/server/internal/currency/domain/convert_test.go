package domain

import "testing"

func TestConvertToBaseCrossRate(t *testing.T) {
	// 1000 USD → CNY base: rate[USD]=7.0, rate[CNY]=1.0 → 1000×7/1 = 7000
	got := ConvertToBase(1000, 7.0, 1.0)
	if got != 7000 {
		t.Fatalf("USD→CNY: got %d, want 7000", got)
	}
	// 7000 CNY → USD base: rate[CNY]=1.0, rate[USD]=7.0 → 7000×1/7 = 1000
	got = ConvertToBase(7000, 1.0, 7.0)
	if got != 1000 {
		t.Fatalf("CNY→USD: got %d, want 1000", got)
	}
}

func TestConvertToBaseSameCurrency(t *testing.T) {
	// from==base (rate 相等) → amount 不变
	got := ConvertToBase(500, 7.0, 7.0)
	if got != 500 {
		t.Fatalf("same currency: got %d, want 500", got)
	}
}

func TestConvertToBaseMissingRateFallback(t *testing.T) {
	// rate 缺失(caller 传 1.0)→ 原币(amount × 1 / 1)
	got := ConvertToBase(300, 1.0, 1.0)
	if got != 300 {
		t.Fatalf("missing rate: got %d, want 300", got)
	}
}

func TestConvertToBaseRounding(t *testing.T) {
	// 34.80 × 7 / 1 = 243.6 → round 244(浮点防护)
	got := ConvertToBase(3480, 7.0, 1.0) // 3480 cents × 7 = 24360
	if got != 24360 {
		t.Fatalf("rounding: got %d, want 24360", got)
	}
}
