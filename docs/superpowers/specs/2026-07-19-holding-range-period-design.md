# holding range-period coverage e2e · 设计 spec

- **日期**: 2026-07-19
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: main(main-driven,从 main `a6a7eb4`)
- **范围**: 补 range XIRR/CAGR 覆盖(performance 套件只 full)。方案 A 单 trade,精确 0.30。**纯 test 新增**,零 proto/schema/production 改。

## 1. 背景

performance e2e 套件(S1-S4,`8694afa..3d34548`)只验 **full 期**,range defer。plan 提:curveWindow 无 ALL(MONTH/YEAR/DAY)+ QtyAtDate strict-< 致 range 微妙(rangeStart<first trade → qty=0 degrade;rangeStart==trade → holding range XIRR 伪非空 fallback full)。

本 spec 补 range-period 覆盖(方案 A 单 trade,精确 range XIRR/CAGR 0.30)。

## 2. 目标

- 补 portfolio range XIRR/CAGR(精确 0.30,365 天)
- 补 portfolio range TWR degrade nil 断言(单 trade effectiveDays=0)
- 补 holding range XIRR/CAGR 非伪非空(`*range != *full`,rangeStart>trade qty>0)

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 方案 A 单 trade | 是 | 干净 range XIRR/CAGR 0.30(单 flow,365 天);range TWR degrade nil(单 trade effectiveDays=0);最简可精确验 |
| 2 | now=2023-01-02(re-SetNow) | 是 | 避 2/29 干净 365 天(MONTH rangeStart=2022-01-02,2022 非闰年);trade @ 2021-06-01 < rangeStart |
| 3 | range TWR degrade nil 断言 | 是 | 单 trade effectiveDays=0 → computeTWR degrade;portfolio-only(holding DTO 无 RangeTwr) |
| 4 | holding range 非伪非空 | 是 | computeHoldingRangeXIRR qty==0 fallback full(伪非空);fixture rangeStart>trade qty>0 → range 真,`*range != *full` |
| 5 | range TWR 非 nil 覆盖 defer | 是 | 需多 trade(方案 B),复杂;defer future |

## 4. 范围边界

| 在范围 | 不在范围 |
|---|---|
| TestRangePeriod portfolio range XIRR/CAGR 0.30 + TWR nil | range TWR 非 nil(方案 B 多 trade,future) |
| holding range XIRR/CAGR 非伪非空 | savings/debt goal(非 performance) |
| now=2023-01-02 re-SetNow(避 2/29) | lot 路径(独立 spec done) |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| test | `TestRangePeriod_XIRR_CAGR` | 追加 `holding_performance_integration_test.go`(复用 `setupPerformanceHarness` + re-SetNow 2023-01-02) |
| 文件 | `holding_performance_integration_test.go`(改,+1 test) | 纯 test 追加 |

## 6. 核心改动

### 6.1 TestRangePeriod_XIRR_CAGR

- `setupPerformanceHarness`(默认 now=2021-01-01)
- `svc.SetNow(2023-01-02)`(re-覆盖,避 2/29 + rangeStart>trade)
- seed security + `UpdateSecurityPrice(13000)`
- buy 100@10000 @ 2021-06-01
- `seedPriceHistory(2022-01-02, 10000)`(rangeStart price,priceAtOrBefore rebuild)
- `GetHoldingPerformance(holding, "MONTH", "CNY")` → range XIRR/CAGR
- `GetPortfolioPerformance(tenant, account, "MONTH", false, "CNY")` → range XIRR/CAGR/TWR
- 验:
  - portfolio range XIRR = 0.30(rangeCfs `[-1e6@2022-01-02, +1.3e6@2023-01-02]`,365 天)
  - portfolio range CAGR = 0.30(`(1.3e6/1e6)^(365/365)-1`)
  - portfolio range TWR = nil(单 trade effectiveDays=0 degrade)
  - holding range XIRR = 0.30(非 fallback full,rangeStart>trade qty=100>0;`*range != *full` 验)
  - holding range CAGR = 0.30(price ratio 10000→13000)

## 7. 数据流

```
SetNow(2023-01-02)+ seed security(13000)+ buy 100@10000@2021-06-01 + seedPriceHistory(2022-01-02, 10000)
→ curveWindow MONTH: rangeStart=2022-01-02(>trade 2021-06-01), now=2023-01-02(365天)
→ portfolio range XIRR: rangeCfs=[{2022-01-02,-1e6},{2023-01-02,+1.3e6}] → XIRR 0.30
→ portfolio range CAGR: (1.3e6/1e6)^(365/365)-1 = 0.30
→ portfolio range TWR: effectiveDays=[] (单 trade) → degrade nil
→ holding range XIRR: qty@rangeStart=100>0 → 真 range 0.30(非 fallback full)
→ holding range CAGR: price ratio 10000→13000 = 0.30
```

## 8. 测试

| 场景 | 覆盖 | 断言 |
|---|---|---|
| TestRangePeriod_XIRR_CAGR | portfolio range XIRR/CAGR 0.30 + TWR nil + holding range 非伪非空 | portfolio range XIRR=0.30 / CAGR=0.30 / TWR=nil;holding range XIRR=0.30(≠full)/CAGR=0.30 |

零回归:全量 server 测 pass + build green(performance S1-S4 + sell + price+snapshot + goal + lot + buy doublewrite 不破)。

## 9. 风险

1. **now=2023-01-02 re-SetNow**:harness 默认 2021-01-01;test re-SetNow 覆盖(2023-01-02 避 2/29,rangeStart=2022-01-02 365天)。
2. **rangeStart>trade**:trade @ 2021-06-01 < rangeStart 2022-01-02 → qty@rangeStart=100(避 degrade/伪非空)。
3. **price_history seed(2022-01-02)**:priceAtOrBefore(rangeStart)需 row;否则 degrade。
4. **range TWR degrade nil**(单 trade effectiveDays=0):断言 nil(非 0.30)。
5. **holding range 非伪非空**:rangeStart>trade qty>0 → 真 range;`*range != *full` 验(避免 fallback full 误判)。
6. **holdingCAGR range 不需 qty**(price ratio):rangeStart price seed 即可。
7. 零 proto/schema(纯 test)。

## 10. 参考

- range 计算:[service.go portfolioXIRR:1231](../../yucai/server/internal/holding/application/service.go)/ portfolioTWR:1363 / portfolioCAGR:1547 / computeHoldingRangeXIRR:1053 / holdingCAGR:1582
- QtyAtDate edge:[xirr.go:114](../../yucai/server/internal/holding/domain/xirr.go)(strict-<)
- curveWindow:[service.go:485](../../yucai/server/internal/holding/application/service.go)(MONTH/YEAR/DAY 无 ALL)
- performance 套件:[2026-07-19-holding-e2e-design.md](2026-07-19-holding-e2e-design.md)(S1-S4 full,range defer)
