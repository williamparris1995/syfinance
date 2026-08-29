package domain

import (
	"math"
	"testing"
	"time"
)

func mustDate(s string) time.Time {
	t, err := time.Parse("2006-01-02", s)
	if err != nil {
		panic(err)
	}
	return t
}

// Excel =XIRR() 文档经典例:投入 -10000,分期收回 → 37.34%。
func TestXIRRMatchesExcel(t *testing.T) {
	cfs := []CashFlow{
		{Date: mustDate("2008-01-01"), Amount: -10000},
		{Date: mustDate("2008-03-01"), Amount: 2750},
		{Date: mustDate("2008-10-30"), Amount: 4250},
		{Date: mustDate("2009-02-15"), Amount: 3250},
		{Date: mustDate("2009-04-01"), Amount: 2750},
	}
	rate, err := XIRR(cfs)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// Excel XIRR = 0.373362535
	if math.Abs(rate-0.373362535) > 1e-6 {
		t.Errorf("XIRR = %.9f, want 0.373362535", rate)
	}
}

func TestXIRRInsufficientCashFlows(t *testing.T) {
	_, err := XIRR([]CashFlow{{Date: mustDate("2020-01-01"), Amount: -100}})
	if err != ErrInsufficientCashFlows {
		t.Errorf("err = %v, want ErrInsufficientCashFlows", err)
	}
}

// 全同号(无正负交叉)→ NPV 无零点。
func TestXIRRNoSolutionSameSign(t *testing.T) {
	_, err := XIRR([]CashFlow{
		{Date: mustDate("2020-01-01"), Amount: -100},
		{Date: mustDate("2020-06-01"), Amount: -50},
		{Date: mustDate("2021-01-01"), Amount: 0}, // 0 不算正
	})
	if err != ErrNoSolution {
		t.Errorf("err = %v, want ErrNoSolution", err)
	}
}

// 单笔 buy + 当前终值 → 正常收敛。
// 注:用 2021-01-01 → 2022-01-01(365 天,非闰年)使 actual/365 下 years=1.0,
// XIRR 精确 = 0.20。若用 2020-01-01 → 2021-01-01(跨闰年 366 天),Excel 语义
// 下真实 XIRR = 0.199402,与"一年 20%"的测试意图不符。
func TestXIRRSimpleGrowth(t *testing.T) {
	cfs := []CashFlow{
		{Date: mustDate("2021-01-01"), Amount: -10000},
		{Date: mustDate("2022-01-01"), Amount: 12000}, // 一年 20%
	}
	rate, err := XIRR(cfs)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(rate-0.20) > 1e-4 {
		t.Errorf("XIRR = %.6f, want ~0.20", rate)
	}
}

func TestQtyAtDateReplay(t *testing.T) {
	trades := []HoldingTransaction{
		{TradeType: TradeTypeBuy, Quantity: 100, TradeDate: mustDate("2020-01-10")},
		{TradeType: TradeTypeBuy, Quantity: 50, TradeDate: mustDate("2020-03-01")},
		{TradeType: TradeTypeSell, Quantity: 30, TradeDate: mustDate("2020-06-01")},
		{TradeType: TradeTypeSplit, Quantity: 2, TradeDate: mustDate("2020-09-01")}, // ratio=2
	}
	tests := []struct {
		name string
		date string
		want float64
	}{
		{"before any buy", "2020-01-01", 0},
		{"after first buy (strict <)", "2020-01-10", 0}, // rangeStart 当天归入期间
		{"after two buys", "2020-04-01", 150},
		{"after sell", "2020-07-01", 120},
		{"after split (×2)", "2020-10-01", 240},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := QtyAtDate(trades, mustDate(tt.date))
			if got != tt.want {
				t.Errorf("QtyAtDate(%s) = %v, want %v", tt.date, got, tt.want)
			}
		})
	}
}

// Dividend 不影响 qty。
func TestQtyAtDateDividendNoOp(t *testing.T) {
	trades := []HoldingTransaction{
		{TradeType: TradeTypeBuy, Quantity: 100, TradeDate: mustDate("2020-01-10")},
		{TradeType: TradeTypeDividend, Quantity: 100, TradeDate: mustDate("2020-06-01")},
	}
	got := QtyAtDate(trades, mustDate("2020-07-01"))
	if got != 100 {
		t.Errorf("QtyAtDate with dividend = %v, want 100", got)
	}
}

// ---- F3/F4 修复行为(spec FR-1/FR-2)。oracle 用两笔现金流的闭式解:
// (1+r)^(days/365) = -A1/A2 → r = (-A1/A2)^(365/days) - 1,与求解器零共享。

func twoFlowClosedFormRoot(a1, a2 float64, days float64) float64 {
	return math.Pow(-a2/a1, 365.0/days) - 1
}

func npvAt(cfs []CashFlow, rate float64) float64 {
	t0 := cfs[0].Date
	sum := 0.0
	for _, cf := range cfs {
		years := cf.Date.Sub(t0).Hours() / 24 / 365.0
		sum += cf.Amount / math.Pow(1+rate, years)
	}
	return sum
}

// F3:1e8 cents 量级(365 天整年)→ 精确 10%,research 附录 B 用例。
func TestXIRRLargeCashFlowsConverge(t *testing.T) {
	cfs := []CashFlow{
		{Date: mustDate("2024-01-01"), Amount: -1e8},
		{Date: mustDate("2024-12-31"), Amount: 1.1e8}, // 2024-01-01→12-31 恰 365 天
	}
	rate, err := XIRR(cfs)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if math.Abs(rate-0.10) > 1e-4 {
		t.Errorf("XIRR = %.9f, want ~0.10 (1e8 cents)", rate)
	}
}

// F3 核心:scale 不变性——同组现金流放大 1e9 倍后根不变(入口归一化的可观测性质)。
func TestXIRRScaleInvarianceLargeMagnitudes(t *testing.T) {
	base := []CashFlow{
		{Date: mustDate("2023-01-01"), Amount: -200_000_000},
		{Date: mustDate("2023-07-01"), Amount: -300_000_000},
		{Date: mustDate("2024-01-01"), Amount: 610_000_000}, // 365 天,root ≈ 0.0665
	}
	scaled := make([]CashFlow, len(base))
	for i, cf := range base {
		scaled[i] = CashFlow{Date: cf.Date, Amount: cf.Amount * 1e9}
	}
	rBase, errBase := XIRR(base)
	rScaled, errScaled := XIRR(scaled)
	if errBase != nil || errScaled != nil {
		t.Fatalf("errors: base=%v scaled=%v", errBase, errScaled)
	}
	if math.Abs(rScaled-rBase) > 1e-6 {
		t.Errorf("scale invariance: base=%.9f scaled=%.9f", rBase, rScaled)
	}
	// 多笔残差自洽:NPV(r) ≈ 0(相对 scale)。
	scale := 0.0
	for _, cf := range scaled {
		scale += math.Abs(cf.Amount)
	}
	if res := npvAt(scaled, rScaled); math.Abs(res) > 1e-6*scale {
		t.Errorf("NPV residual %.3e exceeds tol (scale %.3e)", res, scale)
	}
}

// F4:1 天 +10% → 年化闭式解 ≈1.28e15;旧固定 bracket [-0.9999,1000] 漏解。
func TestXIRRExtremeShortPeriodHighReturn(t *testing.T) {
	cfs := []CashFlow{
		{Date: mustDate("2024-01-01"), Amount: -100},
		{Date: mustDate("2024-01-02"), Amount: 110}, // 1 天 +10%
	}
	rate, err := XIRR(cfs)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := twoFlowClosedFormRoot(-100, 110, 1)
	if math.Abs(rate-want) > 1e-6*math.Abs(want) {
		t.Errorf("XIRR = %.6e, want %.6e (1-day 10%%)", rate, want)
	}
}

// F4:1 周 +5% → 年化 ≈11.6;私域常态场景,旧实现直接 ErrNoSolution。
func TestXIRRWeekGainResolves(t *testing.T) {
	cfs := []CashFlow{
		{Date: mustDate("2024-01-01"), Amount: -100},
		{Date: mustDate("2024-01-08"), Amount: 105}, // 7 天 +5%
	}
	rate, err := XIRR(cfs)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := twoFlowClosedFormRoot(-100, 105, 7)
	if math.Abs(rate-want) > 1e-6*math.Abs(want) {
		t.Errorf("XIRR = %.9f, want %.9f (7-day 5%%)", rate, want)
	}
}

// 包络守卫:1 天翻倍 → 年化 2^365 ≈7.5e109 超上界 1e16 → ErrNoSolution。
func TestXIRRBeyondCeilingReturnsNoSolution(t *testing.T) {
	cfs := []CashFlow{
		{Date: mustDate("2024-01-01"), Amount: -100},
		{Date: mustDate("2024-01-02"), Amount: 200},
	}
	if _, err := XIRR(cfs); err != ErrNoSolution {
		t.Errorf("err = %v, want ErrNoSolution (beyond 1e16 envelope)", err)
	}
}

// 下界 NaN 回退路径:>54 年混号尾流使 (1+floor)^years 下溢 → ±Inf 相消 NaN
// (仅非常规现金流可达——常规流的 NaN 需要晚段混号,spec 排除多根语义)。
// 修复后 lo 逐级上移且始终 ∈ (-1, -0.99](review R1:旧算术会推成正值);
// 行为断言:优雅返回——要么给出残差合格的根,要么干净的 ErrNoSolution,
// 绝不 panic/泄漏 Inf。
func TestXIRRNaNFloorFallbackGraceful(t *testing.T) {
	cfs := []CashFlow{
		{Date: mustDate("1970-01-01"), Amount: -100},
		{Date: mustDate("2025-01-01"), Amount: 500}, // y55:(1e-6)^55 下溢 → +Inf @floor
		{Date: mustDate("2026-01-01"), Amount: -3},  // y56:→ -Inf @floor → NaN
	}
	rate, err := XIRR(cfs)
	if err != nil {
		if err != ErrNoSolution {
			t.Fatalf("err = %v, want ErrNoSolution or nil (graceful NaN-floor handling)", err)
		}
		return // 多根非常规流:干净拒绝(spec 边界:多根不处理)
	}
	if math.IsNaN(rate) || math.IsInf(rate, 0) {
		t.Fatalf("rate = %v, want finite", rate)
	}
	if res := npvAt(cfs, rate); math.Abs(res) > 1e-6 {
		t.Errorf("NPV residual %.3e exceeds tol after NaN-floor fallback", res)
	}
}

// 陡梯度深亏回归(review R2):11 年 -97% 组合,局部 |f'| ≈ 5e16——
// 任何可表示 double 的 NPV 残差 ≥ ~6,绝对阈值的回代校验会误杀为 nil。
// 根值 -0.9697111967122702 为独立数值复算(reviewer 机器对拍)。
func TestXIRRSteepGradientDeepLossResolves(t *testing.T) {
	cfs := []CashFlow{
		{Date: mustDate("2010-01-01"), Amount: -1e6},
		{Date: mustDate("2015-01-01"), Amount: -1e6},
		{Date: mustDate("2020-01-01"), Amount: -1e6},
		{Date: mustDate("2021-01-01"), Amount: 3e4},
	}
	rate, err := XIRR(cfs)
	if err != nil {
		t.Fatalf("unexpected error: %v (steep-gradient root must not be false-rejected)", err)
	}
	if math.Abs(rate-(-0.9697111967122702)) > 1e-9 {
		t.Errorf("rate = %.16f, want -0.9697111967122702", rate)
	}
}

// FR-7 多笔样本 NPV 残差表:解的质量由 |NPV(r)| ≤ tol·scale 独立断言
// (Excel 文档例另作值对拍 0.373362535,见 TestXIRRMatchesExcel)。
func TestXIRRMultiFlowNPVResidual(t *testing.T) {
	cases := []struct {
		name string
		cfs  []CashFlow
	}{
		{
			"excel doc example",
			[]CashFlow{
				{Date: mustDate("2008-01-01"), Amount: -10000},
				{Date: mustDate("2008-03-01"), Amount: 2750},
				{Date: mustDate("2008-10-30"), Amount: 4250},
				{Date: mustDate("2009-02-15"), Amount: 3250},
				{Date: mustDate("2009-04-01"), Amount: 2750},
			},
		},
		{
			"mixed sign mid-stream",
			[]CashFlow{
				{Date: mustDate("2021-01-01"), Amount: -500000},
				{Date: mustDate("2021-06-01"), Amount: 300000},
				{Date: mustDate("2022-01-01"), Amount: -200000},
				{Date: mustDate("2022-07-01"), Amount: 520000},
			},
		},
		{
			"twelve monthly buys then exit",
			[]CashFlow{
				{Date: mustDate("2023-01-01"), Amount: -1000},
				{Date: mustDate("2023-02-01"), Amount: -1000},
				{Date: mustDate("2023-03-01"), Amount: -1000},
				{Date: mustDate("2023-04-01"), Amount: -1000},
				{Date: mustDate("2023-05-01"), Amount: -1000},
				{Date: mustDate("2023-06-01"), Amount: -1000},
				{Date: mustDate("2023-07-01"), Amount: -1000},
				{Date: mustDate("2023-08-01"), Amount: -1000},
				{Date: mustDate("2023-09-01"), Amount: -1000},
				{Date: mustDate("2023-10-01"), Amount: -1000},
				{Date: mustDate("2023-11-01"), Amount: -1000},
				{Date: mustDate("2023-12-01"), Amount: -1000},
				{Date: mustDate("2023-12-31"), Amount: 14100},
			},
		},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			rate, err := XIRR(tc.cfs)
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			scale := 0.0
			for _, cf := range tc.cfs {
				scale += math.Abs(cf.Amount)
			}
			if res := npvAt(tc.cfs, rate); math.Abs(res) > 1e-9*scale {
				t.Errorf("NPV residual %.3e exceeds tol (scale %.3e)", res, scale)
			}
		})
	}
}
