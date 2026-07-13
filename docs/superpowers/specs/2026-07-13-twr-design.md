# TWR 时间加权收益 · 设计 spec

- **日期**: 2026-07-13
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: TWR(时间加权收益,CFA GIPS 标准)—— 精确子区间连乘,**只全期**,**组合 + 单标的**。与 XIRR(资金加权)互补
- **上游**: [2026-07-12-xirr-handoff.md](2026-07-12-xirr-handoff.md)(TWR follow-up)+ [2026-07-12-xirr-design.md](2026-07-12-xirr-design.md)(XIRR 数据基础复用)

## 1. 背景

XIRR(资金加权 IRR,P0)已完成 —— 反映"我投入的钱实际回报多少"(考虑现金流时点)。但 XIRR 受加减仓时点影响(用户择时差 → XIRR 低,即便标的选得好)。

**TWR(时间加权)** 剔除现金流时点影响,衡量**投资决策能力**(选股/标的选择)。CFA Institute GIPS 标准(2010 起每次外部现金流日重估,强制精确 TWR)。

御财 holding 数据基础(holding_transaction 现金流 / price_history 端点估值 / rate_history 折算 / QtyAtDate replay)已就绪(XIRR 建),TWR 复用。

## 2. 目标

加 TWR(精确子区间连乘,全期,组合 + 单标的),与 XIRR 双维度展示(资金加权 + 时间加权)。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| 精确 TWR(GIPS 子区间连乘) | Modified Dietz 近似(精确已选) |
| **只全期**(首笔 buy → 现在) | 区间 TWR(近30日/12月/5年;计算重,defer) |
| 组合级(折算 base)+ 单标的级(原币) | TWR 基准对比(CSI300 TWR) |
| proto `twr_annualized_pct`(optional)+ 双维度 UI | TWR 曲线(只数值,非时序) |

**零 schema 改动**:复用 XIRR 数据(holding_transaction/price_history/rate_history)+ data helpers(marketValueAtDate/QtyAtDate/priceAtOrBefore/collectTradeCashFlows/allTradesForTenant/currentMarketValueInBase)。

## 4. 决策记录(brainstorm 拍板)

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 算法 | **精确 TWR**(GIPS 子区间连乘) | 行业标准;数据支持(每现金流日 price_history×QtyAtDate);剔除现金流时点最准 |
| 2 | 范围 | **只全期**(区间 defer) | P0 简化;TWR 区间计算重(区间内多子区间);区间表现看 XIRR(已有) |
| 3 | 作用域 | **组合 + 单标的** | 对齐 XIRR;整体(组合)+ 单标的决策能力 |
| 4 | domain 设计 | `TWR(SubPeriodReturn[], finalValue, lastAfterCF, totalDays)` 纯函数 | 对齐 `XIRR(CashFlow[])` 模式(domain 纯算法 + application 数据编排分离) |
| 5 | TWR 用市场值(BV) | **BV_before/after**(qty×price),非 CF 金额 | GIPS:CF 只标识切点;buy BV_after>BV_before(持仓增),与 XIRR(CF 负)不同 |
| 6 | proto 字段 | 新 `twr_annualized_pct`(optional,组合+单标的) | XIRR `annualized_pct` 保留;TWR 并列 |
| 7 | UI | 双维度(XIRR 资金加权 + TWR 时间加权) | 互补;null `—` |

## 5. 架构与分层

| 层 | 组件 | 职责 |
|---|---|---|
| **domain**(新)| `internal/holding/domain/twr.go` | `TWR(subPeriods []SubPeriodReturn, finalValue, lastAfterCF float64, totalDays int) (annualized float64, err error)` 纯函数 + `SubPeriodReturn{BeginValueAfterCF, EndValueBeforeCF}` + sentinel。对齐 `XIRR(CashFlow[])` |
| **application**(扩)| `service.go` | `portfolioTWR`/`holdingTWR`(构建子区间:cashFlowDays 切分 + BV_before/after 估值)+ 复用 XIRR data helpers |
| **proto**(扩)| `holding.proto` | `optional double twr_annualized_pct`(PortfolioPerformanceResponse + HoldingPerformanceResponse) |
| **client**(扩)| entity/mapper/page | `twrAnnualizedPct`(`double?`)+ annualized 卡双维度 UI |

**零改动**:ent schema / domain XIRR/CashFlow/QtyAtDate(复用)/ wire(Service 签名不变)。

**数据流**:
```
portfolioTWR(ctx, tenantID, accountID, base)
  → trades := allTradesForTenant (复用 XIRR)
  → cashFlowDays := sorted unique trade_date
  → 子区间:每 day BV_before(qty<day × price@day × rate)+ BV_after(qty<day+1 × price@day × rate)
  → finalValue := currentMarketValueInBase (复用 XIRR)
  → TWR(subPeriods, finalValue, lastAfterCF, totalDays)  [domain 纯函数]
  → twr_annualized_pct (proto optional) → client double? → UI 双维度
```

## 6. TWR 算法(GIPS 子区间连乘)

### 6.1 GIPS 公式

```
现金流日 t_0 < t_1 < ... < t_n(按 trade_date 排序)
BV_before(t_i) = qty@(t_i trade 前)× price@(t_i)     [现金流前的市场值]
BV_after(t_i)  = qty@(t_i trade 后)× price@(t_i)     [现金流后的市场值]
子区间 HPR_i = BV_before(t_i) / BV_after(t_{i-1})    [t_{i-1} trade 后 → t_i trade 前]
末段 HPR_final = finalValue / BV_after(t_n)          [最后 trade 后 → 当前]
TWR_cumulative = ∏ HPR_i × HPR_final − 1
TWR_annualized = (1 + TWR_cumulative) ^ (365 / totalDays) − 1   [actual/365,对齐 XIRR]
```

**TWR 用市场值(BV)**,非 CF 金额。buy:BV_after > BV_before(持仓增);sell:BV_after < BV_before。CF(buy/sell/dividend)只标识子区间切点。

### 6.2 domain 纯函数(twr.go)

```go
var (
    ErrInsufficientPeriods = errors.New("twr: insufficient sub-periods")
    ErrZeroValue           = errors.New("twr: zero market value")
)

// SubPeriodReturn 是一个现金流日子区间的端点值。
// BeginValueAfterCF = BV_after(t_{i-1})(上现金流日 trade 后的市场值)
// EndValueBeforeCF  = BV_before(t_i)(当前现金流日 trade 前的市场值)
type SubPeriodReturn struct {
    BeginValueAfterCF float64
    EndValueBeforeCF  float64
}

// TWR 计算 GIPS 时间加权年化收益(actual/365)。
// subPeriods 覆盖 [t_0, t_n] 现金流日;finalValue = 当前市值;
// lastAfterCF = BV_after(t_n)(最后现金流日 trade 后);totalDays = 首笔→今天天数。
func TWR(subPeriods []SubPeriodReturn, finalValue, lastAfterCF float64, totalDays int) (float64, error) {
    if len(subPeriods) == 0 { return 0, ErrInsufficientPeriods }
    product := 1.0
    for _, sp := range subPeriods {
        if sp.BeginValueAfterCF == 0 { return 0, ErrZeroValue }
        product *= sp.EndValueBeforeCF / sp.BeginValueAfterCF
    }
    if lastAfterCF == 0 { return 0, ErrZeroValue }
    product *= finalValue / lastAfterCF
    cumulative := product - 1
    if totalDays < 1 { return cumulative, nil } // 单日:返累计不年化
    years := float64(totalDays) / 365.0
    return math.Pow(1+cumulative, 1/years) - 1, nil
}
```

## 7. application 编排

### 7.1 portfolioTWR / holdingTWR

```go
// portfolioTWR 算组合级 TWR(base 折算,全期)。降级返回 nil。
func (s *Service) portfolioTWR(ctx context.Context, tenantID uuid.UUID, accountID *uuid.UUID, baseCurrency string) (*float64, error)

// holdingTWR 算单标的级 TWR(原币,全期)。降级返回 nil。
func (s *Service) holdingTWR(ctx context.Context, holdingID uuid.UUID) (*float64, error)
```

构建子区间(复用 XIRR data helpers):
```go
trades := s.allTradesForTenant(ctx, tenantID, accountID)        // 复用 XIRR
cashFlowDays := sortedUniqueTradeDates(trades)                  // 子区间切点
subPeriods := []SubPeriodReturn{}
var prevAfterCF float64
for i, day := range cashFlowDays {
    BV_before := s.marketValueBeforeTrade(ctx, tenantID, accountID, day, rateBase, base)  // Σ qty<day × price@day × rate
    BV_after  := s.marketValueAfterTrade(ctx, tenantID, accountID, day, rateBase, base)   // Σ qty<day+1 × price@day × rate
    if i > 0 { subPeriods = append(subPeriods, SubPeriodReturn{Begin: prevAfterCF, End: BV_before}) }
    prevAfterCF = BV_after
}
finalValue := s.currentMarketValueInBase(ctx, tenantID, accountID, base)  // 复用 XIRR
totalDays := int(time.Since(cashFlowDays[0]).Hours() / 24)
rate, err := domain.TWR(subPeriods, finalValue, prevAfterCF, totalDays)
if err != nil { return nil, nil }  // 降级
return ptrFloat(rate), nil
```

### 7.2 BV_before/after helper

XIRR `marketValueAtDate(date)` 用 `QtyAtDate(strict < date)`(trade 前)。TWR 需 **before/after trade 分离**:

```go
// marketValueBeforeTrade:qty@(trade 前)= QtyAtDate(< day),price@day
func (s *Service) marketValueBeforeTrade(ctx, tenantID, accountID, day, rateBase, base) float64

// marketValueAfterTrade:qty@(trade 后)= QtyAtDate(< day+1day),price@day(同日,价格不变)
func (s *Service) marketValueAfterTrade(ctx, tenantID, accountID, day, rateBase, base) float64
```

实现:复用 `marketValueAtDate` 内部逻辑(qty×price×rate Σ),加 `qtyAsOf` 参数或 2 helper。`price@day` 用 `priceAtOrBefore(day)`(向前填充,复用 XIRR)。

### 7.3 Get 方法接入

`GetPortfolioPerformance` / `GetHoldingPerformance` 调 `portfolioTWR`/`holdingTWR`,填 DTO `TwrAnnualizedPct *float64`。

## 8. proto + client

### 8.1 proto(`holding.proto`)

`PortfolioPerformanceResponse` 加(在 `range_annualized_pct` 后):
```proto
optional double twr_annualized_pct = 11;  // TWR 时间加权年化%(全期,nil=降级)
```
`HoldingPerformanceResponse` 加(在 `range_annualized_pct` 后):
```proto
optional double twr_annualized_pct = 8;  // TWR(原币,全期,nil=降级)
```

regen:`cd yucai/proto && buf generate --template buf.gen.go.yaml`(Go)+ `make gen-dart`(Dart,protoc_plugin 25.0.0)。

### 8.2 client

- entity `PortfolioPerformance`/`HoldingPerformance` 加 `twrAnnualizedPct`(`double?`)
- mapper `hasTwrAnnualizedPct() ? twrAnnualizedPct : null`
- UI:annualized 卡加 TWR 行(双维度:XIRR 标"资金加权"、TWR 标"时间加权"),null `—`。布局 defer 到实现(填现有卡,或 visual companion 对齐)

## 9. 降级 + 测试

**降级**(全 nil → `—`):
| 场景 | 处理 |
|---|---|
| 无 trade / 子区间 < 1 | `ErrInsufficientPeriods` → nil |
| BV 零(空仓子区间) | `ErrZeroValue` → nil |
| 美股 price 缺(BV 无法估) | application 跳过 → nil |
| 单日(totalDays < 1) | 返累计(不年化) |

**测试**:
- **domain `TWR`**:手算子区间序列(已知 HPR 连乘,如 3 子区间 [1.0→1.1, 1.1→1.21, 1.21→1.33] → TWR 33%)+ 边界(< 1 / 零值 / 单日)+ proptest(∏ 守恒)
- **application**:`portfolioTWR`/`holdingTWR`(mock repo,fake BV 序列)+ 降级(price 缺 → nil)
- **proto/handler**:`twr_annualized_pct` optional 映射
- **client**:mapper nullable + widget(双维度 + `—`)
- **回归**:XIRR 现有测不破(共享 data helpers;TWR 加字段不影响 XIRR annualized_pct)

## 10. 风险清单

1. **BV_before/after 同日 qty 计算**:`QtyAtDate(<day)`(trade 前)vs `QtyAtDate(<day+1)`(trade 后)。同日多 trade 排序(XIRR Minor:已 `sort.SliceStable`)。边界:split 当日 qty×ratio。
2. **组合级跨 holding Σ BV**:每现金流日跨所有 holding Σ(qty×price×rate)。性能(N 现金流日 × M holding)。首批可接受(同 XIRR marketValueAtDate);缓存 defer。
3. **price 缺失(美股)**:BV_before/after 无法估 → 该现金流日子区间跳过或整体降级 nil。需决策:跳过该日(子区间合并)vs 整体 nil。**推荐整体 nil**(保守,对齐 XIRR 美股降级)。
4. **首笔前 BV=0**:首笔 buy 前 BV_before=0 → `ErrZeroValue`?或首笔子区间从 buy 后开始(BV_after(t_0) 作 begin)。**推荐**:subPeriods 从 i>0 开始(首笔 BV_after 作 prevAfterCF,不作为 EndValueBeforeCF),避免除零。
5. **wire 手改**:Service 签名不变 → wire 无需改(对齐 XIRR)。
6. **proto regen**:`buf generate` + `make gen-dart`(protoc_plugin 25.0.0,对齐 XIRR/Yahoo)。

## 11. 实施顺序(供 writing-plans,约 6 task)

```
Task 1  domain/twr.go:TWR 纯函数 + SubPeriodReturn + sentinel + 单测(手算 case + 边界 + proptest,TDD)
Task 2  application:marketValueBeforeTrade/AfterTrade helper(BV before/after 分离)+ 单测
Task 3  application:portfolioTWR/holdingTWR(构建子区间 + 调 TWR + 降级)+ 单测(mock repo)
Task 4  GetPortfolioPerformance/GetHoldingPerformance 接入 TWR(填 DTO)+ 降级
Task 5  proto:twr_annualized_pct optional + regen(Go+Dart)+ handler 组装
Task 6  client:entity nullable + mapper + 双维度 UI + widget test + 回归
```

## 12. 参考

- handoff:[2026-07-12-xirr-handoff.md](2026-07-12-xirr-handoff.md)(TWR follow-up)
- XIRR spec:[2026-07-12-xirr-design.md](2026-07-12-xirr-design.md)(数据基础复用)
- 现状代码:[xirr.go](../../yucai/server/internal/holding/domain/xirr.go) / [service.go portfolioXIRR](../../yucai/server/internal/holding/application/service.go) / [marketValueAtDate](../../yucai/server/internal/holding/application/service.go)
- memory:[[holding-asset-management-todo]](TWR defer)/ [[yucai-dev-env]](proto regen)
