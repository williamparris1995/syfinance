package domain

import (
	"errors"
	"math"
)

// TWR 错误。
var (
	ErrInsufficientPeriods = errors.New("twr: insufficient sub-periods")
	ErrZeroValue           = errors.New("twr: zero market value")
	ErrInvalidCumulative   = errors.New("twr: cumulative return below -100%, not annualizable")
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

// CumulativeTWR 计算区间累计时间加权收益:
//
//	TWR_cumulative = ∏(End_i/Begin_i) × (finalValue/lastAfterCF) − 1
//
// 任一端点为零(Begin/End/lastAfterCF)→ ErrZeroValue(可判别 sentinel:
// 旧实现零 End 会静默 product×0 返 -100%,F6 陷阱;清仓分段由 application
// 层负责,本函数不猜测)。
func CumulativeTWR(subPeriods []SubPeriodReturn, finalValue, lastAfterCF float64) (float64, error) {
	if len(subPeriods) == 0 {
		return 0, ErrInsufficientPeriods
	}
	product := 1.0
	for _, sp := range subPeriods {
		if sp.BeginValueAfterCF == 0 || sp.EndValueBeforeCF == 0 {
			return 0, ErrZeroValue
		}
		product *= sp.EndValueBeforeCF / sp.BeginValueAfterCF
	}
	if lastAfterCF == 0 {
		return 0, ErrZeroValue
	}
	product *= finalValue / lastAfterCF
	return product - 1, nil
}

// AnnualizeTWR 年化累计收益(actual/365):
//
//	TWR_annualized = (1 + cumulative)^(365/totalDays) − 1
//
// totalDays < 1 → 返累计(不年化);cumulative < -1 → ErrInvalidCumulative
// (F10:负底数分数幂会得 NaN,sentinel 防御而非静默污染)。
func AnnualizeTWR(cumulative float64, totalDays int) (float64, error) {
	if totalDays < 1 {
		return cumulative, nil
	}
	if cumulative < -1 {
		return 0, ErrInvalidCumulative
	}
	years := float64(totalDays) / 365.0
	return math.Pow(1+cumulative, 1/years) - 1, nil
}
