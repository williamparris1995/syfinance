# Holding 收益引擎 XIRR 修正 · 设计 spec

- **日期**: 2026-07-12
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: 把 holding 简单收益引擎替换为 **XIRR**(资金加权内部收益率),**全期 + 区间** × **组合 + 单标的**
- **上游 handoff**: [2026-07-12-xirr-handoff.md](2026-07-12-xirr-handoff.md)(P0 基础正确性,deep-research 结论)
- **数据基础**: [2026-06-30-holding-snapshot-design.md](2026-06-30-holding-snapshot-design.md)(C 子项目已完成:FIFO lot / holding_snapshot / security_price_history / currency_rate_history)

## 1. 背景

御财 holding 收益引擎**基础正确性缺陷**(handoff P0):
- `totalPct = total / costBasis × 100`([service.go:668](../../yucai/server/internal/holding/application/service.go#L668))—— 简单收益
- `annualizedPct = totalReturn / years × 100`([service.go:910](../../yucai/server/internal/holding/application/service.go#L910))—— 线性年化,注释自标 `not CAGR`,⚠️ **无测试覆盖**

组合有资金进出时(buy=contribution / sell=withdrawal / dividend=现金流入),简单收益 `(终值-初值)/初值` **错误** —— 须用 **XIRR**(资金加权 IRR,考虑现金流时点)。deep-research 调研结论:个人理财场景 XIRR 优先于 TWR/风险指标,定为 P0。

本 spec 经 brainstorm 决策:**上 XIRR(非 TWR)**,**全期 + 区间**,**组合 + 单标的**,区间初值用 **price_history 重建**。

## 2. 目标

修正 holding 收益引擎为 XIRR,直击 P0 基础正确性。用户视角:"**我投入的钱(考虑加减仓时点)实际年化回报多少**"。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| XIRR 纯函数(domain,Newton + bisection fallback) | TWR 时间加权(handoff 留 follow-up) |
| 全期 XIRR + 区间 XIRR(随 CurveRange) | 风险指标 Sharpe 等(handoff roadmap) |
| 组合级(折算 base CNY)+ 单标的级(原币) | snapshot 全量逐日回填(C 决策④明确不做) |
| 区间初值 `price_history × reconstructed qty` 重建 | 美股/OTC 历史价回填(spec §14 首批不覆盖 → 降级) |
| proto `annualized_pct` 语义升级 + `range_annualized_pct` 新增 | XIRR 结果缓存 / 物化(YAGNI,首批可接受) |
| client `performance_page` + `holding_detail_page` 展示 | UI 布局重设计(填现有 OD 对齐布局) |

**关键:零 schema 改动** —— XIRR 所需数据全在现有表(holding_transaction / security_price_history / currency_rate_history / holding_lots)。**不碰 ent schema、不建新表、不碰 holding_lots**。

## 4. 决策记录(brainstorm 拍板)

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 收益算法 | **XIRR**(资金加权 IRR) | 个人理财直观("我的钱回报多少"),数据现成,直击 P0;TWR 受 snapshot 不回填约束 |
| 2 | 时间语义 | **全期 + 区间两者** | 全期=整体回报主指标;区间=近30日/12月/5年视角,随 range 切换 |
| 3 | 作用域 | **组合 + 单标的** | 两处现有 RPC/UI(performance_page 组合 + holding_detail 单标的) |
| 4 | 区间初值来源 | **price_history × reconstructed qty** | 最准确;覆盖 A股+CSI300 ~5年;snapshot 不回填会让 snapshot-only 方案丢失早期 |
| 5 | XIRR 实现 | **自写 domain 纯函数**(不引第三方库) | 对齐 `ConsumeLotsFIFO`/`ApplySellFIFO` 风格,可控可测,对比 Excel 验证 |
| 6 | `annualized_pct` 字段 | **语义升级为全期 XIRR**(非新增并列) | 不留废弃占位;现值本就是 `not CAGR` 待修正 |
| 7 | `total_pct` 字段 | **保留**(简单累计) | 无现金流时仍正确,有展示价值 |
| 8 | 降级表达 | **proto3 `optional` presence** | 非哨兵值(0 歧义),client `hasXxx()` 判断 |
| 9 | 多币种折算时点 | **trade_date 当日 `rate_history`** | 避免汇率波动污染 IRR(非当前汇率) |
| 10 | 数值稳定性 | **Newton-Raphson + bisection fallback** | 主迭代不收敛时二分兜底,对标 Excel XIRR 行为 |

## 5. 架构与分层

**DDD 落点**(算法与数据编排严格分离):

| 层 | 组件 | 职责 |
|---|---|---|
| **domain**(新) | `internal/holding/domain/xirr.go` | `XIRR(cashflows []CashFlow) (rate float64, err error)` 纯函数 + `CashFlow{Date, Amount}` 类型 + 边界 sentinel error。对齐 `ConsumeLotsFIFO` 风格,无依赖、可纯单测(对比 Excel) |
| **application**(扩) | `service.go` 新增私有方法 | `buildCashFlows`(trade→现金流+折算)/ `qtyAtDate`(transaction replay)/ `marketValueAtDate`(qty×price_history 向前填充)/ `portfolioXIRR`/`holdingXIRR`;改造 `GetPortfolioPerformance`/`GetHoldingPerformance` 填 XIRR |
| **proto** | `holding.proto` | `annualized_pct` 改 optional + 语义升级;新增 `range_annualized_pct`(见 §8) |
| **client** | data/domain/presentation | 接 XIRR 字段(nullable)→ performance_page / holding_detail 展示 |

**依赖注入**:`Service` 已注入 `tradeRepo` / `priceHistoryRepo` / `rateRepo` / `snapshotRepo`([service.go:19-30](../../yucai/server/internal/holding/application/service.go#L19-L30))—— XIRR 编排用的全是现有依赖。domain 纯函数无依赖。**wire 无需改**(对 handoff 约束#2 的澄清:本任务不碰 `wire_gen.go`)。

## 6. XIRR 算法 + 现金流语义

### 6.1 CashFlow 类型(domain,币种/单位无关 —— 纯 float64)

```go
type CashFlow struct {
    Date   time.Time
    Amount float64 // signed: 负=流出(投入), 正=流入(收回)
}

// XIRR 求解 NPV(rate)=Σ cf.Amount/(1+rate)^years = 0 的年化 rate
func XIRR(cashflows []CashFlow) (rate float64, err error)
```

### 6.2 trade → CashFlow 映射(application 层构建)

| 事件 | Amount | 日期 | 代码依据 |
|---|---|---|---|
| Buy | `−(AmountCents + FeeCents)` | TradeDate | [service.go:113-114](../../yucai/server/internal/holding/application/service.go#L113-L114) |
| Sell | `+(AmountCents − FeeCents)` | TradeDate | [service.go:179-180](../../yucai/server/internal/holding/application/service.go#L179-L180) |
| Dividend | `+AmountCents`(=TotalAmountCents,无 fee) | TradeDate | [service.go:196](../../yucai/server/internal/holding/application/service.go#L196) |
| Split | **忽略** | — | RecordSplit 无 amount;不碰现金流 |
| **全期终值** | `+Σ 当前总市值` | today | "今天清仓能收回" |
| **区间初投入** | `−Σ 区间初市值` | rangeStart | 期初已持仓视作投入(§7 重建) |
| **区间末终值** | `+Σ 当前总市值` | today | CurveRange=近N日/月/年,rangeEnd=today |

**关键确认**:`RecordDividend` 不调 ApplyBuy/Sell、不建/消 lot([service.go:191-205](../../yucai/server/internal/holding/application/service.go#L191-L205))→ 是**现金分红**(非再投),XIRR 里就是正现金流。

### 6.3 XIRR 算法(Newton-Raphson,actual/365 对齐 Excel XIRR)

```
现金流按 Date 排序;t0 = 首个日期;years_i = (date_i − t0).Days / 365
NPV(r)  = Σ cf_i / (1+r)^years_i
NPV'(r) = Σ −years_i × cf_i / (1+r)^(years_i+1)
r ← r − NPV(r)/NPV'(r);  guess=0.1;  收敛 |Δr|<1e-7 或 max 100 迭代
不收敛或 |r| 越界 → bisection fallback(区间 [-0.999, 1000]);仍失败 → ErrNoSolution
```

### 6.4 边界 / 错误矩阵(domain 返回 sentinel error,application 降级为 null)

| 场景 | 处理 | UI |
|---|---|---|
| 现金流 < 2 | `ErrInsufficientCashFlows` | `—` |
| 全同号(无零点,如终值=0 全亏光) | `ErrNoSolution` | `—` |
| Newton 不收敛(震荡/多解,bisection 也失败) | `ErrNoSolution` | `—` |
| 零成本(costBasis=0,赠股) | `ErrInsufficientCashFlows` | `—` |
| 区间起点早于首笔 buy(qty@rangeStart=0) | 退化为全期(自然降级,非错误) | 显全期值 |

## 7. 区间端点估值 + 多币种折算

方案 A 核心:区间 XIRR 的"区间初市值"从历史数据重建。

### 7.1 qtyAtDate(transaction replay)

从 holding 全部 trade 按时间序回放到目标日的累计持仓量:

```go
func qtyAtDate(trades []HoldingTransaction, date time.Time) float64 {
    sort by TradeDate; qty := 0.0
    for t in trades (TradeDate < date):  // 严格早于 date = date 开盘前持仓
        switch t.TradeType:
            Buy:      qty += t.Quantity
            Sell:     qty -= t.Quantity
            Split:    qty *= t.Quantity   // Quantity=Ratio,对当时持仓生效
            Dividend: // 跳过(现金分红不碰 qty)
    return qty
}
```

**边界语义**:`qty@rangeStart` 取严格 `TradeDate < rangeStart`(rangeStart 当天的 trade 归入区间期间现金流,见 §7.5),表示 rangeStart **开盘前**已持仓。Split 自然只对 `splitDate < date` 的持仓生效(date 早于 split 则循环未触达)。

### 7.2 marketValueAtDate

```go
func (s *Service) marketValueAtDate(qty float64, sec Security, date time.Time) (cents int64, ok bool) {
    if qty == 0 { return 0, true }
    price, ok := s.priceHistoryRepo.FindAtOrBefore(sec.ID, date) // 向前填充
    if !ok { return 0, false }                                    // 历史价缺失
    return int64(qty * float64(price)), true
}
```

price 从 `security_price_history` 取 **≤ date 的最近一条**(向前填充,对齐 `RateHistoryRepository.FindRate` 现有模式)。`priceHistoryRepo` 现有 `FindBySecurity(from,to)` 可覆盖,或加便捷方法 `FindAtOrBefore`(实现 trivial)。

### 7.3 多币种折算(组合级)

每笔现金流用 **trade_date 当日汇率**折算 base(非当前汇率),避免汇率波动污染 IRR:

```
cf.Amount = currencydomain.ConvertToBase(trade原币amount,
                rateRepo.FindRate(currency, trade.TradeDate), baseRate)
```

`ConvertToBase` 复用 `samplePortfolioInBase` 已用的 `currencydomain.ConvertToBase`。**单标的级:原币,不折算**。

### 7.4 price_history 缺失降级

| 标的类型 | 区间初价 | 区间 XIRR | 全期 XIRR |
|---|---|---|---|
| A股 + CSI300(~5年回填) | ✅ 有 | ✅ 可算 | ✅ 可算 |
| 美股/OTC(stub 无历史) | ❌ 缺 | `—` 降级 | ✅ 可算(只要现金流 + 当前价) |

降级规则:**任一 holding 的区间初价缺失 → 该区间 XIRR 返回 null**(`—`,不造假、不部分算)。全期 XIRR 不受影响(不需要历史端点)。

### 7.5 组合现金流汇总(伪码)

```
trades := tradeRepo.FindAll(tenant, account, securityID=nil)   // 一次拿全
全期 cashflows := [mapTrade(t, rate@tradeDate) for t in trades]
                + [{today, +Σ当前市值折算base}]
区间 cashflows := [{rangeStart, −Σ marketValueAtDate(rangeStart)折算base}]
                + [mapTrade(t) for t in trades if rangeStart ≤ t.TradeDate ≤ today]  // 含 rangeStart 当天(配合 §7.1 qty 用 < rangeStart)
                + [{today, +Σ当前市值折算base}]
```

## 8. server Service + proto

### 8.1 Service 方法签名不变(内部加 XIRR 编排)

```go
GetPortfolioPerformance(ctx, tenantID, accountID*, rangeName, withBenchmark, baseCurrency)
GetHoldingPerformance(ctx, tenantID, holdingID, rangeName, baseCurrency)
```

新增私有方法:
```go
buildCashFlows(trades, mode {full|range}, rangeStart, baseCurrency) []CashFlow
portfolioXIRR(ctx, tenantID, accountID*, baseCurrency) (full, rng float64, err error) // 组合,折算 base
holdingXIRR(ctx, holdingID, baseCurrency) (full, rng float64, err error)              // 单标的,原币
```

`GetPortfolioPerformance` 内部:`totalPct` 保留(现有计算);`annualizedPct` 从线性年化换成 `portfolioXIRR().full`;新增 `range` = `portfolioXIRR().rng`。

### 8.2 proto 字段策略

`PortfolioPerformanceResponse`:
| 字段 | 现状 | 改造 |
|---|---|---|
| 1-6 / 8-9(曲线/realized/unrealized/total_cents/total_pct/currency) | — | **不变**(`total_pct` 简单累计保留) |
| `annualized_pct`(7) | 线性年化(not CAGR,无测试) | **语义升级为全期 XIRR**,改 `optional`(降级缺省) |
| `range_annualized_pct`(10,新) | — | 区间 XIRR 年化%(随 CurveRange),`optional` |

`HoldingPerformanceResponse`(现无 pct):
| 新字段 | 说明 |
|---|---|
| `annualized_pct`(6,新) | 全期 XIRR(原币),`optional` |
| `range_annualized_pct`(7,新) | 区间 XIRR(原币),`optional` |

**range 语义**:全期 XIRR 与 range 无关(每次返回同值);区间 XIRR 随 range 切换变化。

**regen**:`cd yucai/proto && buf generate --template buf.gen.go.yaml`(Go)+ `make gen-dart`(**protoc_plugin 25.0.0**,见 [[yucai-dev-env]])。

## 9. client 展示

| 层 | 改动 |
|---|---|
| **data** | stub regen 自动带新字段;`portfolioResponseToEntity`/`holdingResponseToEntity` mapper 加 XIRR 字段映射(proto optional → `double?`) |
| **domain** | [PortfolioPerformance](../../yucai/client/lib/holding/domain/entities/performance_entity.dart#L21):`annualizedPct` 改 `double?`(语义=全期 XIRR)+ 新增 `rangeAnnualizedPct`(`double?`);[HoldingPerformance](../../yucai/client/lib/holding/domain/entities/performance_entity.dart#L62):新增 `annualizedPct` + `rangeAnnualizedPct`(`double?`) |
| **presentation** | `performance_page:468` 年化位接全期 XIRR;range 切换副位显区间 XIRR;`holding_detail_page` 新增 XIRR 展示;null → `'—'` |

**展示语义**:全期 XIRR 主位(恒定,反映"整体回报")+ 区间 XIRR 副位(随 range tab 切换)。

**布局 defer**:performance_page 已 OD 对齐(holding-ui redesign),"两个数怎么摆"是填数据进现有布局,具体留实现阶段(写代码看实际格子,或对齐 OD/visual companion)。

## 10. 降级矩阵(全 `optional`/null → `'—'`)

| 场景 | 全期 XIRR | 区间 XIRR |
|---|---|---|
| A股+CSI300(有历史价) | ✅ | ✅ |
| 美股/OTC(无历史价) | ✅ | `—` |
| 无 trade / 单笔 buy(现金流<2) | `—` | `—` |
| 终值=0(全亏,全同号无零点) | `—` | `—` |
| XIRR 不收敛(Newton+bisection 双失败) | `—` | `—` |
| range 早于首笔 buy(qty@start=0) | 退化=全期 | =全期 |
| 零成本(costBasis=0) | `—` | `—` |

## 11. 测试策略(全程 TDD)

### server
- **domain `xirr.go`**(纯函数,无 DB):
  - `XIRR` 对比 Excel `=XIRR()` 已知 case(Excel 文档经典例 + 自构造 multi-flow),误差 < 1e-6
  - 边界:<2 现金流 / 全同号 / 零成本 / 不收敛 → 对应 sentinel error
  - proptest:`NPV(returned_rate) = 0` 守恒验证
  - `qtyAtDate` replay(buy/sell/split 序列、边界日期、split 时机)
  - `marketValueAtDate` 向前填充 / 价格缺失 → ok=false
- **application**:portfolioXIRR / holdingXIRR(mock tradeRepo/priceHistoryRepo/rateRepo);GetPortfolioPerformance / GetHoldingPerformance XIRR 字段(enttest SQLite 集成);多币种交易日折算;美股缺历史→区间 null 降级
- **handler**:2 RPC XIRR 字段映射

### client
- mapper(XIRR nullable 映射)+ widget(performance/detail 真数据 + `'—'` 空态)+ 回归现有测不破坏

### P0 验证基准
真实交易数据 server 算 XIRR vs 手动 Excel `=XIRR()` 比对(handoff 执行建议⑤)。

## 12. 风险清单(plan 需显式处理)

1. **XIRR 数值稳定性**(不收敛/多解)→ Newton + bisection fallback + 对比 Excel 测试覆盖
2. **qty replay 与 split 语义**→ 单测覆盖 buy/sell/split 时间序列,边界日期(split 当日、split 前/后)
3. **price_history 缺失(美股/OTC)**→ 区间 XIRR 降级 null,全期不受影响;client `'—'`
4. **`annualized_pct` 语义升级破坏现有展示**→ proto 改 optional + client 改 nullable + `'—'`;回归 performance_page widget 测
5. **多币种交易日汇率缺失(节假日)**→ rate 向前填充(对齐 `FindRate` 现有模式)+ 日志
6. **性能**(组合全期遍历全部历史 trade + 按需查 price/rate)→ 首批可接受(`GetPortfolioPerformance` 已查多源);XIRR 本身 ~100 迭代×N 现金流,毫秒级;缓存 defer(YAGNI)

## 13. 实施顺序建议(供 writing-plans,约 8 task)

```
───────── server ─────────
Task 1  domain/xirr.go:XIRR + CashFlow + 边界 sentinel + qtyAtDate + marketValueAtBase(TDD,对比 Excel)
Task 2  application:buildCashFlows + portfolioXIRR + holdingXIRR + 多币种交易日折算(TDD)
Task 3  改造 GetPortfolioPerformance/GetHoldingPerformance 填 XIRR + 降级;enttest 集成测
Task 4  proto:annualized_pct 改 optional + range_annualized_pct;buf regen + handler 单测
Task 5  端到端:真实交易数据 server XIRR vs Excel XIRR 比对(P0 验证基准)
───────── flutter ─────────
Task 6  proto stub regen(make gen-dart,protoc_plugin 25.0.0)+ entity nullable + mapper
Task 7  presentation:performance_page(全期+区间)+ holding_detail XIRR 展示 + 降级 '—'(widget test)
Task 8  全链路验证(flutter run)+ final whole-branch review(XIRR commits)
```

## 14. 参考

- handoff:[2026-07-12-xirr-handoff.md](2026-07-12-xirr-handoff.md)(deep-research 调研结论,agnifolio/CFA GIPS)
- 数据基础 spec:[2026-06-30-holding-snapshot-design.md](2026-06-30-holding-snapshot-design.md)(C snapshot / FIFO lot / price_history / rate_history)
- 现状收益代码:[service.go GetPortfolioPerformance:644](../../yucai/server/internal/holding/application/service.go#L644) / [annualizedPct:910](../../yucai/server/internal/holding/application/service.go#L910)
- memory:[[holding-asset-management-todo]] / [[yucai-wire-handmaintained]](本任务不改 wire)/ [[yucai-dev-env]]
