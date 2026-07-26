package domain

import "math"

// ConvertToBase 折算 amount 从 fromCode 到 baseCode,经 CNY-base rate 交叉。
// 约定:rate[X] = "1 X 兑多少 CNY"(rate[CNY] = 1.0)。SyncRates 落库前已将
// Frankfurter EUR-base 重基到此处消费的 CNY-base。
// rateFrom/rateBase 由 caller 经 RateHistoryRepository.FindRate 取。
// 公式:amount × rateFrom / rateBase。from==base(rate 相等)→ amount 不变。
// rate 缺失(caller 传 1.0)→ 原币。math.Round 防浮点截断。
func ConvertToBase(amount int64, rateFrom, rateBase float64) int64 {
	if rateBase == 0 {
		return amount // 防除零(不应发生,CNY base=1.0)
	}
	return int64(math.Round(float64(amount) * rateFrom / rateBase))
}
