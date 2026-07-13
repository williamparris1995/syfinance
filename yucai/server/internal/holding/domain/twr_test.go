package domain

import (
	"math"
	"testing"
)

// 手算:3 子区间 HPR 各 1.10 → 累计 (1.1)^3 - 1 = 0.331;末段 1.0 → 33.1% 累计。
// BV 序列:after(t0)=100, before(t1)=110/after=110, before(t2)=121/after=121,
//          before(t3)=133.1/after=133.1, final=133.1。
// subPeriods: [{100,110},{110,121},{121,133.1}], lastAfterCF=133.1, final=133.1
// product = (110/100)*(121/110)*(133.1/121) * (133.1/133.1) = 1.331 → cum 0.331
func TestTWRKnownSequence(t *testing.T) {
	subs := []SubPeriodReturn{
		{BeginValueAfterCF: 100, EndValueBeforeCF: 110},
		{BeginValueAfterCF: 110, EndValueBeforeCF: 121},
		{BeginValueAfterCF: 121, EndValueBeforeCF: 133.1},
	}
	rate, err := TWR(subs, 133.1, 133.1, 365)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// 累计 33.1%,1 年 → 年化 33.1%
	if math.Abs(rate-0.331) > 1e-6 {
		t.Errorf("TWR = %.6f, want 0.331", rate)
	}
}

// 2 年同累计 → 年化 (1.331)^(1/2) - 1 ≈ 0.1547
func TestTWRAnnualizedMultiYear(t *testing.T) {
	subs := []SubPeriodReturn{
		{BeginValueAfterCF: 100, EndValueBeforeCF: 110},
		{BeginValueAfterCF: 110, EndValueBeforeCF: 121},
		{BeginValueAfterCF: 121, EndValueBeforeCF: 133.1},
	}
	rate, err := TWR(subs, 133.1, 133.1, 730) // 2 年
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := math.Pow(1.331, 1.0/2.0) - 1
	if math.Abs(rate-want) > 1e-6 {
		t.Errorf("TWR = %.6f, want %.6f", rate, want)
	}
}

func TestTWRInsufficientPeriods(t *testing.T) {
	_, err := TWR(nil, 100, 100, 365)
	if err != ErrInsufficientPeriods {
		t.Errorf("err = %v, want ErrInsufficientPeriods", err)
	}
}

func TestTWRZeroBeginValue(t *testing.T) {
	_, err := TWR([]SubPeriodReturn{{BeginValueAfterCF: 0, EndValueBeforeCF: 100}}, 100, 100, 365)
	if err != ErrZeroValue {
		t.Errorf("err = %v, want ErrZeroValue", err)
	}
}

// 单日(totalDays < 1)→ 返累计不年化
func TestTWRSingleDayReturnsCumulative(t *testing.T) {
	subs := []SubPeriodReturn{{BeginValueAfterCF: 100, EndValueBeforeCF: 110}}
	rate, err := TWR(subs, 110, 110, 0)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(rate-0.10) > 1e-9 {
		t.Errorf("single-day TWR = %v, want 0.10 cumulative", rate)
	}
}
