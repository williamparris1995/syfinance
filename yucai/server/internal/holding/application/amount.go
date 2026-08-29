package application

import "math"

// TradeAmountCents 计算 trade 金额(priceCents × quantity,四舍五入到分)。
// Buy/Sell 的 double-write 金额规则单点:handler(余额校验 + 现金记录)与
// service(持仓交易记录)都必须经本函数,禁止各自内联 int64(float64×)
// 截断(F5 病灶:逐笔分位漂移进 XIRR/TWR)。
func TradeAmountCents(priceCents int64, quantity float64) int64 {
	return int64(math.Round(float64(priceCents) * quantity))
}
