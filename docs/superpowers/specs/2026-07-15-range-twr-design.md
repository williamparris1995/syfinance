# range TWR(区间时间加权收益)· 设计 spec

- **日期**: 2026-07-15
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: TWR(时间加权,CFA GIPS)从「只全期」扩展到「全期 + 区间」(**组合级**,对齐 XIRR 区间)。补全 [2026-07-13-twr-design.md](2026-07-13-twr-design.md) §3 defer 的 range TWR。单标的保持只全期(对齐 holdingXIRR)。

## 1. 背景

TWR(2026-07-13 完成)当前**只全期**(首笔 trade→现在),组合 + 单标的。原 spec §3 defer 了区间 TWR(近30日/12月/5年),理由「计算重 + 区间表现看 XIRR(已有)」。

XIRR 已有区间:`portfolioXIRR(ctx, tenantID, accountID, base, rangeStart) (full, rng)` 返全期+区间;`holdingXIRR` 只 full。`curveWindow(rangeName)`:CurveRange **DAY=近30日 / MONTH=近12月 / YEAR=近5年**(to=now,from=now-30d/12m/5y)。

range TWR 补全 TWR 区间维度(与 XIRR 区间并列),让区间表现也能看**时间加权**(剔除现金流时点,衡量投资决策能力)。

## 2. 目标

组合级 TWR 加区间(近30日/12月/5年),对齐 XIRR 的 full+range 模式。proto + client 展示。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| 组合级 TWR 全期+区间 | 单标的区间(holdingTWR 保持 only full,对齐 holdingXIRR) |
| computeTWR 通用化(全期=rangeStart=首笔 特例) | split-adjusted price(cross-cutting,独立 follow-up) |
| proto range_twr_annualized_pct(组合) | TWR 曲线(只数值,非时序) |
| client performance 区间 tab range TWR 行 | XIRR/TWR 缓存(性能) |

**零 domain/twr.go 改动**(TWR 纯函数已通用)。**零 schema**。

## 4. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 覆盖范围 | 组合 full+range,单标的 only full | 对齐 XIRR 现状(组合有区间,单标的只全期);scope 小,一致 |
| 2 | range 粒度 | CurveRange DAY/MONTH/YEAR(近30日/12月/5年) | 对齐 XIRR curveWindow;原 spec §3 预设 |
| 3 | 数学统一 | computeTWR(rangeStart) 通用(全期=rangeStart=首笔 特例) | 零回归(全期是区间特例);复用全期子区间逻辑 |
| 4 | proto field | 新 `range_twr_annualized_pct = 12`(组合 only) | field 12 未占用(twr=11 后);对齐 range_annualized_pct=10 |
| 5 | 实现 | portfolioTWR 调 computeTWR 两次(full+rng) | 对齐 portfolioXIRR 模式;最小改动 |

## 5. 架构

### server(改 application + proto,domain 不改)

| 层 | 组件 | 职责 |
|---|---|---|
| **domain**(不改) | `TWR(subPeriods, finalValue, lastAfterCF, totalDays)` | GIPS 纯函数,通用(全期/区间只换入参) |
| **application**(重构抽出) | `computeTWR(ctx, tenantID, accountID, base, trades, cashFlowDays, rangeStart) (*float64, error)` | 通用子区间逻辑(范围 [rangeStart, now]);从 portfolioTWR 抽出 |
| **application**(改签名) | `portfolioTWR(ctx, tenantID, accountID, base, rangeName) (full, rng *float64, err)` | 调 computeTWR 两次:full(rangeStart=cashFlowDays[0])+ rng(rangeStart=curveWindow(rangeName).from) |
| **application**(改) | `GetPortfolioPerformance` | 调 portfolioTWR(rangeName) 填 DTO range_twr_annualized_pct |
| **proto** | `PortfolioPerformanceResponse.range_twr_annualized_pct` (field 12) | 对齐 range_annualized_pct |

### client(改 entity/mapper/page)

| 层 | 组件 | 职责 |
|---|---|---|
| domain | `PortfolioPerformance.rangeTwrAnnualizedPct` (`double?`) | 区间 TWR |
| data | mapper optional→null | proto optional 映射 |
| presentation | performance_page 组合级区间 tab | range TWR 行(与 range XIRR 并列,null→'—') |

## 6. 数学(computeTWR 通用)

```
入参:rangeStart time.Time(全期=cashFlowDays[0];区间=curveWindow.from)
effectiveDays = cashFlowDays where day > rangeStart       // 子区间现金流日
begin = BV_after(rangeStart)
      = marketValueAtDateAsOfWithTrades(qtyAsOf=rangeStart.AddDate(0,0,1), priceAsOf=rangeStart)
prevAfter = begin
for day in effectiveDays:
    BV_before = marketValueAtDateAsOfWithTrades(day, day)
    subPeriods.append({BeginValueAfterCF: prevAfter, EndValueBeforeCF: BV_before})
    prevAfter = BV_after(day) = marketValueAtDateAsOfWithTrades(day.AddDate(0,0,1), day)
finalValue = currentMarketValueInBase(tenantID, accountID, base)
totalDays  = int(rangeStart → now 的天数)
return domain.TWR(subPeriods, finalValue, prevAfter, totalDays)
```

**统一性(零回归保证)**:
- 全期 rangeStart = `cashFlowDays[0]`(首笔 trade 日)→ effectiveDays = `cashFlowDays[1:]`(等价原 i>0);begin = BV_after(首笔)
- 区间 rangeStart = `curveWindow.from` → effectiveDays = from 后现金流日;begin = BV_after(from)
- 边界完全一致 → **全期是区间的特例** → 现有 portfolioTWR 行为 byte-identical

## 7. 降级(对齐全期链)

- `effectiveDays` 空 / `subPeriods` < 1 → nil(`ErrInsufficientPeriods`)
- 区间内 price 缺(美股/OTC)→ `marketValueAtDateAsOfWithTrades` 返 false → nil(对齐全期)
- rangeStart 日 BV=0(区间初空仓)→ `ErrZeroValue` → nil
- 区间 < 2 现金流日 → nil
- 单标的 `holdingTWR` 不变(只 full)

## 8. proto

```proto
// PortfolioPerformanceResponse(组合,field 12 = twr_annualized_pct=11 之后,未占用)
optional double range_twr_annualized_pct = 12;  // TWR 区间年化%(nil=降级/区间不足)
```

HoldingPerformanceResponse **不改**(单标的 only full,twr=8 保持)。

regen:`cd yucai && make gen-dart` + `cd yucai/server && buf generate --template buf.gen.go.yaml`(**protoc_plugin 25.0.0**,见 memory `yucai-dev-env`)。

## 9. client

- `PortfolioPerformance` entity 加 `final double double? rangeTwrAnnualizedPct`
- mapper:`rangeTwrAnnualizedPct: dto.hasRangeTwrAnnualizedPct() ? dto.rangeTwrAnnualizedPct : null`
- performance_page 组合级区间 tab:range TWR 行(标"时间加权",与 range XIRR "资金加权" 并列),null → '—'

## 10. 测试

- **computeTWR 通用**:
  - 全期(rangeStart=cashFlowDays[0])→ **byte-identical 对齐现有 portfolioTWR 结果**(回归)
  - 区间(known rangeStart)→ 手算子区间 + TWR(GIPS 连乘验证)
- **降级**:区间不足 / price 缺 / 区间初空仓 → nil
- **portfolioTWR**:full + rng 都算(两次 computeTWR)
- **proto/handler**:range_twr 映射 + regen
- **回归**:全期 TWR + XIRR 不破(共享 data helpers;新 field 不影响既有)

## 11. 风险

1. **性能**:portfolioTWR 调 computeTWR 两次(full + range),每次 N 现金流日 × `marketValueAtDateAsOfWithTrades`。XIRR 同(两次)。首批可接受(对齐 XIRR);缓存 defer。
2. **rangeStart 非交易日 BV**:`marketValueAtDateAsOfWithTrades(qtyAsOf=rangeStart+1d, priceAsOf=rangeStart)` 算 rangeStart 日收盘持仓(qty as-of rangeStart+1 = rangeStart 收盘后)× rangeStart 日价。正确(区间初持仓)。`QtyAtDate` replay 已支持 as-of。
3. **区间初空仓**(rangeStart < 首笔 trade):BV_after(rangeStart)=0 → `ErrZeroValue` → nil。正确(区间初无持仓)。
4. **price 缺**(rangeStart 日或区间内美股无价):`marketValueAtDateAsOfWithTrades` 返 false → nil。对齐全期降级。
5. **proto field 12** ✅ 已核实未占用(PortfolioPerformanceResponse 现有 1/7/8/10/11,12 空闲)。
6. **wire 不改**(复用 portfolioTWR,无新 provider)。

## 12. 参考

- TWR 全期 spec:[2026-07-13-twr-design.md](2026-07-13-twr-design.md) §3 defer range TWR
- XIRR 区间参照:`portfolioXIRR`(service.go:1196)+ `curveWindow`(service.go:464)
- domain TWR:[twr.go](../../yucai/server/internal/holding/domain/twr.go)
- proto:[holding.proto PortfolioPerformanceResponse](../../yucai/proto/holding/v1/holding.proto) L185-197
- memory:[[holding-asset-management-todo]](TWR defer follow-up)
