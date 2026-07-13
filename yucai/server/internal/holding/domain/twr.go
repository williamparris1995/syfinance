package domain

import (
	"errors"
	"math"
)

// TWR 错误。
var (
	ErrInsufficientPeriods = errors.New("twr: insufficient sub-periods")
	ErrZeroValue           = errors.New("twr: zero market value")
)

// SubPeriodReturn 是一个现金流日子区间的端点市场值。
//   - BeginValueAfterCF = BV_after(t_{i-1}): 上现金流日 trade 后的市场值
//   - EndValueBeforeCF  = BV_before(t_i):  当前现金流日 trade 前的市场值
//
// HPR_i = EndValueBeforeCF / BeginValueAfterCF(t_{i-1} trade 后 → t_i trade 前)。
// application 层负责构建子区间(_qty before/after trade × price × rate_)。
type SubPeriodReturn struct {
	BeginValueAfterCF float64
	EndValueBeforeCF  float64
}

// TWR 计算 GIPS 时间加权年化收益(actual/365)。
//   subPeriods 覆盖 [t_0, t_n] 现金流日(首笔 buy 后开始,见风险 #4)
//   finalValue  = 当前市值
//   lastAfterCF = BV_after(t_n)(最后现金流日 trade 后)
//   totalDays   = 首笔 trade_date → 今天的天数
//
// TWR_cumulative = ∏(End_i/Begin_i) × (finalValue/lastAfterCF) − 1
// TWR_annualized = (1 + cumulative)^(365/totalDays) − 1
//
// 降级:子区间空 → ErrInsufficientPeriods;BeginValue 或 lastAfterCF 零 → ErrZeroValue;
// totalDays < 1 → 返累计(不年化)。
func TWR(subPeriods []SubPeriodReturn, finalValue, lastAfterCF float64, totalDays int) (float64, error) {
	if len(subPeriods) == 0 {
		return 0, ErrInsufficientPeriods
	}
	product := 1.0
	for _, sp := range subPeriods {
		if sp.BeginValueAfterCF == 0 {
			return 0, ErrZeroValue
		}
		product *= sp.EndValueBeforeCF / sp.BeginValueAfterCF
	}
	if lastAfterCF == 0 {
		return 0, ErrZeroValue
	}
	product *= finalValue / lastAfterCF
	cumulative := product - 1
	if totalDays < 1 {
		return cumulative, nil // 单日:返累计
	}
	years := float64(totalDays) / 365.0
	return math.Pow(1+cumulative, 1/years) - 1, nil
}
