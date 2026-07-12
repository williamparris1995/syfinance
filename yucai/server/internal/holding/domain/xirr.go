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

// CashFlow 是一笔带日期的现金流。Amount 负=流出(投入),正=流入(收回)。
// 币种/单位无关 —— application 层负责把多币种折算到同币种再喂入。
type CashFlow struct {
	Date   time.Time
	Amount float64
}

// XIRR 计算现金流的年化内部收益率(actual/365,对齐 Excel XIRR)。
// 返回年化比率(如 0.085 = 8.5%)。现金流<2、全同号(无零点)、
// Newton+bisection 都失败时返回对应 sentinel error。
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
	for i, cf := range sorted {
		years[i] = cf.Date.Sub(t0).Hours() / 24 / 365.0
		amounts[i] = cf.Amount
	}

	npv := func(rate float64) float64 {
		sum := 0.0
		for i := range sorted {
			sum += amounts[i] / math.Pow(1+rate, years[i])
		}
		return sum
	}
	npvPrime := func(rate float64) float64 {
		sum := 0.0
		for i := range sorted {
			sum += -years[i] * amounts[i] / math.Pow(1+rate, years[i]+1)
		}
		return sum
	}

	// Newton-Raphson 主迭代(guess=0.1)。
	rate := 0.1
	for iter := 0; iter < 100; iter++ {
		f := npv(rate)
		if math.Abs(f) < 1e-7 {
			return rate, nil
		}
		d := npvPrime(rate)
		if d == 0 {
			break
		}
		next := rate - f/d
		if math.Abs(next-rate) < 1e-9 {
			return next, nil
		}
		rate = next
		if rate <= -1 || rate > 1e4 {
			break // 越界,转 bisection
		}
	}

	// Bisection fallback 在 [-0.9999, 1000] 找根。
	lo, hi := -0.9999, 1000.0
	nLo := npv(lo)
	nHi := npv(hi)
	if nLo*nHi > 0 {
		return 0, ErrNoSolution
	}
	for iter := 0; iter < 200; iter++ {
		mid := (lo + hi) / 2
		f := npv(mid)
		if math.Abs(f) < 1e-7 || (hi-lo)/2 < 1e-9 {
			return mid, nil
		}
		if nLo*f < 0 {
			hi = mid
		} else {
			lo = mid
			nLo = f
		}
	}
	return 0, ErrNoSolution
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
