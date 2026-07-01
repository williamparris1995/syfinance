package domain

import "math"

// ConvertToBase 折算 amount 从 fromCode 到 baseCode,经 CNY-base rate 交叉。
// rateFrom/rateBase 由 caller 经 RateHistoryRepository.FindRate 取(1 外币 = X CNY)。
// 公式:amount × rateFrom / rateBase。from==base(rate 相等)→ amount 不变。
// rate 缺失(caller 传 1.0)→ 原币。math.Round 防浮点截断。
func ConvertToBase(amount int64, rateFrom, rateBase float64) int64 {
	if rateBase == 0 {
		return amount // 防除零(不应发生,CNY base=1.0)
	}
	return int64(math.Round(float64(amount) * rateFrom / rateBase))
}
