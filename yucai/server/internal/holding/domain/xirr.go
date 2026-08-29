package domain

import (
	"errors"
	"math"
	"sort"
	"time"
)

// XIRR 现金流计算错误。
var (
	ErrInsufficientCashFlows = errors.New("xirr: insufficient cash flows")
	ErrNoSolution            = errors.New("xirr: no solution")
)

// 求解包络与 bracket 扩展参数(design ADR-2/ADR-3)。
//   - 入口归一化(除 max|amount|)使收敛阈值与金额量级解耦(F3/F11);
//   - 下界取 -0.999999(rate→-1 数值爆炸);上界 1e16 覆盖 1 天 +10%
//     (真根 ≈1.28e15)等极端短日解,超出视为发散(F4;research 2.3 的
//     ceiling=1e16 修正自其 1e8 建议——后者装不下其附录 B 自己的用例)。
const (
	xirrRateFloor   = -0.999999
	xirrRateCeiling = 1e16
	xirrMaxExpand   = 60
	xirrBrentXTol   = 2e-12
)

// CashFlow 是一笔带日期的现金流。Amount 负=流出(投入),正=流入(收回)。
// 币种/单位无关 —— application 层负责把多币种折算到同币种再喂入。
type CashFlow struct {
	Date   time.Time
	Amount float64
}

// XIRR 计算现金流的年化内部收益率(actual/365,对齐 Excel XIRR)。
// 返回年化比率(如 0.085 = 8.5%)。现金流<2、全同号(无零点)、
// 包络 (-0.999999, 1e16) 内无根或超出包络时返回对应 sentinel error。
//
// 求解:入口归一化 + 自适应几何 bracket 扩展 + Brent(1973)
// (对齐 scipy.optimize.brentq / MATLAB fzero 行业默认;bracketed 保证收敛)。
// Excel 仅作值 oracle(actual/365 同口径),不复刻其 Newton 算法。
func XIRR(cashflows []CashFlow) (float64, error) {
	if len(cashflows) < 2 {
		return 0, ErrInsufficientCashFlows
	}
	hasPos, hasNeg := false, false
	for _, cf := range cashflows {
		if cf.Amount > 0 {
			hasPos = true
		}
		if cf.Amount < 0 {
			hasNeg = true
		}
	}
	if !hasPos || !hasNeg {
		return 0, ErrNoSolution
	}

	sorted := make([]CashFlow, len(cashflows))
	copy(sorted, cashflows)
	sort.Slice(sorted, func(i, j int) bool { return sorted[i].Date.Before(sorted[j].Date) })

	t0 := sorted[0].Date
	years := make([]float64, len(sorted))
	amounts := make([]float64, len(sorted))
	maxAbs := 0.0
	for i, cf := range sorted {
		years[i] = cf.Date.Sub(t0).Hours() / 24 / 365.0
		amounts[i] = cf.Amount
		if a := math.Abs(cf.Amount); a > maxAbs {
			maxAbs = a
		}
	}
	if maxAbs == 0 {
		return 0, ErrNoSolution
	}
	// 归一化:NPV(r; α·cf) = α·NPV(r; cf),零点不变;NPV 量级进入 O(N),
	// 浮点噪声与收敛阈值解耦(修 F3 大额不收敛,附带覆盖 F11 精度边界)。
	for i := range amounts {
		amounts[i] /= maxAbs
	}

	npv := func(rate float64) float64 {
		sum := 0.0
		for i := range sorted {
			sum += amounts[i] / math.Pow(1+rate, years[i])
		}
		return sum
	}

	// 下界评估:超长年限下 (1+floor)^years 可能下溢出为 0 导致 ±Inf/NaN,
	// 逐级回退到较温和的 floor(个人理财年限远够用;全 NaN → ErrNoSolution)。
	lo := xirrRateFloor
	nLo := npv(lo)
	for math.IsNaN(nLo) && lo < -0.99 {
		lo = (lo + 1) * 0.5 * 0.1 // 向 0 收敛一步后重试(保持 < -0.99 语义内)
		lo = math.Max(lo, -0.99)
		nLo = npv(lo)
	}
	if math.IsNaN(nLo) {
		return 0, ErrNoSolution
	}

	// 自适应几何扩展:hi 自 0.1(先跨过 1)逐次翻倍直至与 lo 反号。
	hi, nHi := 0.1, npv(0.1)
	if !(nLo*nHi <= 0) {
		found := false
		for iter := 0; iter < xirrMaxExpand; iter++ {
			if hi < 1 {
				hi = 1
			} else {
				hi *= 2
			}
			nHi = npv(hi)
			if nLo*nHi <= 0 {
				found = true
				break
			}
			if hi > xirrRateCeiling {
				break
			}
		}
		if !found && nLo*nHi > 0 {
			return 0, ErrNoSolution
		}
	}

	return brentRoot(npv, lo, hi, nLo, nHi, xirrBrentXTol, 4*(math.Nextafter(1, 2)-1))
}

// QtyAtDate 按 transaction 时间序回放,返回 date 开盘前持有的份额
// (严格 TradeDate < date —— date 当天的 trade 归入区间期间现金流)。
// Buy 加、Sell 减、Split 按 Quantity(=ratio)乘当前累计、Dividend 跳过
// (现金分红不碰持仓)。供区间 XIRR 的期初市值重建用。
func QtyAtDate(trades []HoldingTransaction, date time.Time) float64 {
	sorted := make([]HoldingTransaction, len(trades))
	copy(sorted, trades)
	sort.SliceStable(sorted, func(i, j int) bool { return sorted[i].TradeDate.Before(sorted[j].TradeDate) })
	qty := 0.0
	for _, t := range sorted {
		if !t.TradeDate.Before(date) {
			break
		}
		switch t.TradeType {
		case TradeTypeBuy:
			qty += t.Quantity
		case TradeTypeSell:
			qty -= t.Quantity
		case TradeTypeSplit:
			qty *= t.Quantity
		case TradeTypeDividend:
			// no-op
		}
	}
	return qty
}
