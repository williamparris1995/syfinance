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
	// math.Round rounds half away from zero. Cover the .5 boundary the
	// previous version of this test missed (it used 3480×7=24360, an exact
	// integer that never exercised rounding).
	// 5 × 1.0 / 2.0 = 2.5 → 3 (positive half rounds up)
	got := ConvertToBase(5, 1.0, 2.0)
	if got != 3 {
		t.Fatalf("positive .5: got %d, want 3", got)
	}
	// -5 × 1.0 / 2.0 = -2.5 → -3 (negative half rounds down — unrealized loss)
	got = ConvertToBase(-5, 1.0, 2.0)
	if got != -3 {
		t.Fatalf("negative .5: got %d, want -3", got)
	}
	// 7 × 1.0 / 2.0 = 3.5 → 4 (confirm boundary is consistent, not a one-off)
	got = ConvertToBase(7, 1.0, 2.0)
	if got != 4 {
		t.Fatalf("positive .5 (3.5): got %d, want 4", got)
	}
}
