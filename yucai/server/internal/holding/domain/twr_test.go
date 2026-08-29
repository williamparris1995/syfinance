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
// (旧 TWR() 组合壳移除后,组合语义 = CumulativeTWR + AnnualizeTWR,同生产调用方。)
func TestTWRKnownSequence(t *testing.T) {
	subs := []SubPeriodReturn{
		{BeginValueAfterCF: 100, EndValueBeforeCF: 110},
		{BeginValueAfterCF: 110, EndValueBeforeCF: 121},
		{BeginValueAfterCF: 121, EndValueBeforeCF: 133.1},
	}
	cum, err := CumulativeTWR(subs, 133.1, 133.1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	rate, err := AnnualizeTWR(cum, 365)
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
	cum, err := CumulativeTWR(subs, 133.1, 133.1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	rate, err := AnnualizeTWR(cum, 730) // 2 年
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := math.Pow(1.331, 1.0/2.0) - 1
	if math.Abs(rate-want) > 1e-6 {
		t.Errorf("TWR = %.6f, want %.6f", rate, want)
	}
}

func TestTWRInsufficientPeriods(t *testing.T) {
	_, err := CumulativeTWR(nil, 100, 100)
	if err != ErrInsufficientPeriods {
		t.Errorf("err = %v, want ErrInsufficientPeriods", err)
	}
}

func TestTWRZeroBeginValue(t *testing.T) {
	_, err := CumulativeTWR([]SubPeriodReturn{{BeginValueAfterCF: 0, EndValueBeforeCF: 100}}, 100, 100)
	if err != ErrZeroValue {
		t.Errorf("err = %v, want ErrZeroValue", err)
	}
}

// 单日(totalDays < 1)→ 返累计不年化
func TestTWRSingleDayReturnsCumulative(t *testing.T) {
	subs := []SubPeriodReturn{{BeginValueAfterCF: 100, EndValueBeforeCF: 110}}
	cum, err := CumulativeTWR(subs, 110, 110)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	rate, err := AnnualizeTWR(cum, 0)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(rate-0.10) > 1e-9 {
		t.Errorf("single-day TWR = %v, want 0.10 cumulative", rate)
	}
}

// ---- F6/F10 修复行为(spec FR-3,design ADR-4):拆分后的两个 seam。----

// 手算同 TestTWRKnownSequence:累计 0.331。
func TestCumulativeTWRKnownSequence(t *testing.T) {
	subs := []SubPeriodReturn{
		{BeginValueAfterCF: 100, EndValueBeforeCF: 110},
		{BeginValueAfterCF: 110, EndValueBeforeCF: 121},
		{BeginValueAfterCF: 121, EndValueBeforeCF: 133.1},
	}
	cum, err := CumulativeTWR(subs, 133.1, 133.1)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(cum-0.331) > 1e-9 {
		t.Errorf("cumulative = %.9f, want 0.331", cum)
	}
}

// 零端值(End 侧)→ 可判别 sentinel。旧实现 product×0 静默返 -100%(F6 陷阱)。
func TestCumulativeTWRZeroEndValueReturnsSentinel(t *testing.T) {
	_, err := CumulativeTWR([]SubPeriodReturn{{BeginValueAfterCF: 100, EndValueBeforeCF: 0}}, 100, 100)
	if err != ErrZeroValue {
		t.Errorf("err = %v, want ErrZeroValue (zero end value)", err)
	}
}

// finalValue==0(qty>0 但现价拍到 0)同样 sentinel——不让尾因子 ×0 产出 -100%。
// (review R1:旧漏检此端点,holdingTWR 坏价场景会返误导性 -100%。)
func TestCumulativeTWRZeroFinalValueReturnsSentinel(t *testing.T) {
	_, err := CumulativeTWR([]SubPeriodReturn{{BeginValueAfterCF: 100, EndValueBeforeCF: 110}}, 0, 110)
	if err != ErrZeroValue {
		t.Errorf("err = %v, want ErrZeroValue (zero final value)", err)
	}
}

// F10:累计 < -100% 年化会得 NaN → sentinel 防御(而非静默 NaN/0)。
func TestAnnualizeTWRCumulativeBelowMinusOneReturnsSentinel(t *testing.T) {
	_, err := AnnualizeTWR(-1.5, 365)
	if err != ErrInvalidCumulative {
		t.Errorf("err = %v, want ErrInvalidCumulative", err)
	}
}

func TestAnnualizeTWRLessThanOneDayReturnsCumulative(t *testing.T) {
	rate, err := AnnualizeTWR(0.10, 0)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(rate-0.10) > 1e-12 {
		t.Errorf("annualize(0.10, 0 days) = %v, want 0.10", rate)
	}
}

// 年化对拍:(1.331)^(1/2)-1(手算幂,独立于实现)。
func TestAnnualizeTWRTwoYear(t *testing.T) {
	rate, err := AnnualizeTWR(0.331, 730)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := math.Pow(1.331, 0.5) - 1
	if math.Abs(rate-want) > 1e-9 {
		t.Errorf("annualize = %.9f, want %.9f", rate, want)
	}
}
