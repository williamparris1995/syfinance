# split-adjusted price(TWR split 日 BV 修正)· 设计 spec

- **日期**: 2026-07-16
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `main`(`holding-asset-management` 已于 2026-07-16 fast-forward 并入)
- **范围**: 修正 TWR 在 stock split 当天的 BV 跨尺度 bug —— **纯 split 日不作为 cashFlowDays 切点**。纯 application 内(`uniqueSortedTradeDates` 单函数 + 2 个 TWR caller 自动受益),透明(无 split 场景 byte-identical)。**不动 XIRR / price 存储 / `QtyAtDate` / proto / client**。

## 1. 背景

stock split(`RecordSplit` ratio,1 股变 N 股、每股价格 /N)发生时:

- `price_history` 存 **raw price** —— Sina 日K 本就不复权;Yahoo 用 `indicators.quote.close`(**raw close**,非 `adjclose`),且未传 `events=split`。两个 provider 都是 raw → split 日前后 raw price 跳变(如 ¥100 → ¥50)。
- `QtyAtDate` **已正确处理 split**(`qty *= ratio`,[xirr.go:132](../../yucai/server/internal/holding/domain/xirr.go#L132))。
- TWR `cashFlowDays = uniqueSortedTradeDates(trades)`,**目前含 split 日**。

**bug**:TWR 在 split 日计算 `BV_before = QtyAtDate(day)×price(day)` 与 `BV_after = QtyAtDate(day+1)×price(day)`,用**同一个 price** 配**跨尺度 qty**(`qtyBefore` pre-split / `qtyAfter` post-split)→ 必有一个 BV 错(差 1/ratio)→ 虚假 sub-period HPR。

split 是**非现金流事件**(GIPS 市值中性,`BV_before` 应 == `BV_after`,不产生 HPR)。

**影响路径**:`holdingTWR`(单标的,[service.go:1435](../../yucai/server/internal/holding/application/service.go#L1435))+ `portfolioTWR → computeTWR`(组合 full+range,[service.go:1297](../../yucai/server/internal/holding/application/service.go#L1297))两路径同结构 bug。数值例:`BV_before(06-01)=100(pre)×price` 与 `BV_after(06-01)=200(post)×price`,若 `price=¥100` → after 虚高 ¥20000;若 `price=¥50` → before 虚低 ¥5000。

**XIRR 不受影响**:range 初值是单时点 `QtyAtDate(date)×priceAtOrBefore(date)`,raw price 下 qty 与 price 同尺度自洽;split cash flow 被 `continue` 跳过([service.go:1045](../../yucai/server/internal/holding/application/service.go#L1045))。

## 2. 目标

split 日不产生虚假 HPR;TWR 只反映真实市场涨跌。**最小改动,无 split 零回归**(byte-identical)。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| `uniqueSortedTradeDates` 排除纯 split 日(语义对齐「现金流日」) | XIRR(raw 单时点自洽,split cashflow 已跳过) |
| `holdingTWR` + `portfolioTWR` 受益(2 caller 自动) | price_history 存储 raw → adjusted(Yahoo/Sina provider 不动) |
| split 场景 TWR 单测(GIPS 手算) | 自动获取 split events(Yahoo `events=splits` → 自动 RecordSplit) |
| | split+buy **同日**极端边界 |
| | `priceAtOrBefore` / `QtyAtDate` 改动 |

**零 proto / client / handler / domain(除 `uniqueSortedTradeDates` 语义)改动。**

## 4. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 修复方案 | **方案 1:split 日不作为切点** | 最小、不动 price 体系,契合「仅修 TWR split 日 BV」范围;方案 2(BV 强制中性)仍需配 split 前 price 不完全;方案 3(strict-before price)影响所有 BV 路径含 XIRR |
| 2 | 改点 | `uniqueSortedTradeDates` 单函数 | grep 确认仅 2 TWR caller(portfolioTWR + holdingTWR);DRY、语义准确(「现金流日」本就不含 split) |
| 3 | split trade 去留 | **留 trades 列表** | `QtyAtDate` 需 replay split 调整 qty;份额变化在相邻 cashFlowDay 的 BV 体现 |
| 4 | 透明性 | 无 split 场景 byte-identical | 纯 split 日不存在 → cashFlowDays 不变 → 现有 156 TWR 测全绿 |

## 5. 架构

| 层 | 组件 | 职责 |
|---|---|---|
| **application**(改)| `uniqueSortedTradeDates(trades)` | 按 day 分组,只列**含 buy/sell/dividend**的日子(纯 split 日排除);split trade 仍由 caller 的 `trades` 持有 |
| **application**(受益)| `holdingTWR` / `portfolioTWR` | `cashFlowDays` 自动不含纯 split 日(无需改 caller) |
| **不动**| `QtyAtDate` / `priceAtOrBefore` / `computeTWR` 循环 / `cachedMV` / XIRR | split 处理已在 `QtyAtDate`;BV 单时点自洽 |

## 6. 核心改动

`uniqueSortedTradeDates`([service.go:1355](../../yucai/server/internal/holding/application/service.go#L1355)):

```go
// uniqueSortedTradeDates extracts unique trade_date values (day-truncated,
// sorted ascending) that are TWR cash-flow days — days with at least one
// buy/sell/dividend. Pure-split days are excluded: a split is a non-cash-flow
// event (market-value-neutral under GIPS), so it must not seed a TWR sub-period,
// or BV_before/after would pair one price with cross-scale (pre-/post-split)
// quantities → phantom HPR. The split trade stays in trades so QtyAtDate replay
// folds the ratio into the BV of the adjacent cash-flow days.
func uniqueSortedTradeDates(trades []domain.HoldingTransaction) []time.Time {
    hasCashFlow := map[time.Time]bool{}
    for _, t := range trades {
        if t.TradeType == domain.TradeTypeSplit {
            continue
        }
        hasCashFlow[t.TradeDate.Truncate(24*time.Hour)] = true
    }
    days := make([]time.Time, 0, len(hasCashFlow))
    for d := range hasCashFlow {
        days = append(days, d)
    }
    sort.Slice(days, func(i, j int) bool { return days[i].Before(days[j]) })
    return days
}
```

split+buy 同日:该日有 buy(非 split)→ `hasCashFlow[d]=true` → 仍列入(符合边界,见 §9.2)。

## 7. 正确性论证

split 日移出切点 → 每个 cashFlowDay 的 BV 是**单时点 raw price × 同尺度 qty**(自洽);相邻 cashFlowDay 之间 split 经 `QtyAtDate` replay 体现,split 市值中性(pre qty × pre price == post qty × post price)使两端 BV 比值**只反映真实涨跌**,不引入虚假 HPR。

**数值例 A**(split 后有卖出,1:2 split 06-01,raw 05-31 ¥100 / 06-02 ¥50):
```
buy 100@¥100(05-15) → split 1:2(06-01) → sell 50@¥60(07-01)
cashFlowDays = [05-15, 07-01]            (06-01 纯 split 排除)
BV_after(05-15) = QtyAtDate(05-16)×price(05-15) = 100×¥100 = ¥10000  (pre-split 自洽)
BV_before(07-01) = QtyAtDate(07-01)×price(07-01) = 200×¥60 = ¥12000  (post-split 自洽,replay split 100×2)
子区间 HPR = 12000/10000 = +20%  ✅ 真实收益(无 split 跳变)
```

**数值例 B**(split 是最后动作,验证 `lastAfterCF`/`finalValue` 连接):
```
buy 100@¥100(05-15) → split 1:2(06-01) → current price ¥50(无后续 trade)
cashFlowDays = [05-15]                   (06-01 排除)
lastAfterCF = BV_after(05-15) = 100×¥100 = ¥10000  (pre-split 尺度)
finalValue   = 200×¥50                  = ¥10000  (post-split 尺度)
TWR cumulative = finalValue/lastAfterCF − 1 = 0%   ✅ split 市值中性,无虚假收益
```

对比当前(bug):06-01 作切点,`BV_before/after(06-01)` 用同一 price 配跨尺度 qty → ¥5000 或 ¥20000 → 虚假 HPR。

## 8. 测试

新增 split 场景(application 层,GIPS 手算,对齐 TWR/XIRR 既有验证风格):

- **split 中性**:`holdingTWR` buy 100@¥100 → split 1:2 → current ¥50 ⇒ **cumulative 0%**(100×100==200×50)
- **split 后涨**:`holdingTWR` buy 100@¥100 → split 1:2 → current ¥60 ⇒ **cumulative +20%**
- **split 在最后**:`holdingTWR` 验证 `lastAfterCF`(pre-split 尺度)与 `finalValue`(post-split 尺度)市值中性连接(数值例 B)
- **含 split 的组合**:`portfolioTWR` full + range 同理(组合含一个 split holding)
- **零回归**:现有 TWR 测(byte-identical,无 split 场景 cashFlowDays 不变)

## 9. 风险

1. **`uniqueSortedTradeDates` 语义变化**:纯 split 日不返回。已确认 2 caller(portfolioTWR + holdingTWR)都 TWR;实现前 grep 全 caller(含 test fake)验证无其他依赖「含 split 日」的消费者。
2. **split+buy 同日**:该日有 buy → 仍切点。`BV_before = qtyBefore(pre-split)×price(当日 post-split raw)` 可能尺度错位。极罕见(拆股当天买入且同日记录),defer 注释。
3. **最后 trade 是 split**:`cashFlowDays` 不含 → `lastAfterCF` = 最后非-split cashFlowDay 的 `BV_after`(pre-split 尺度),`finalValue`(post-split 尺度)靠市值中性正确连接(数值例 B 已验证)。
4. **rangeStart 恰为 split 日**:`computeTWR` `beginAfter = cachedMV(rangeStart+1, rangeStart)` 边际自洽性,罕见,defer。
5. **`QtyAtDate` 同日 split+buy 顺序**:`allTradesForTenant` deterministic(TradeDate ASC, ID ASC),但 split+buy 同日极端,defer(同 §9.2)。

## 10. 参考

- TWR 全期 spec:[2026-07-13-twr-design.md](2026-07-13-twr-design.md)(GIPS 子区间连乘)
- range TWR spec:[2026-07-15-range-twr-design.md](2026-07-15-range-twr-design.md)(`computeTWR` full+range,split-adjusted defer 记录)
- TWR cache spec:[2026-07-16-twr-cache-design.md](2026-07-16-twr-cache-design.md)(`cachedMV` request-scoped)
- `uniqueSortedTradeDates`/`holdingTWR`/`portfolioTWR`/`computeTWR`/`QtyAtDate`:[service.go](../../yucai/server/internal/holding/application/service.go) L1355/1415/1331/1281 + [xirr.go](../../yucai/server/internal/holding/domain/xirr.go) L118
- memory:`holding-asset-management-todo`(split-adjusted price defer follow-up)
