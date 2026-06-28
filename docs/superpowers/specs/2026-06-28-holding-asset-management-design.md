# Holding 资产管理系统 · 总体设计

- **日期**: 2026-06-28
- **状态**: 总体设计文档(指导全局);首个实施 plan 针对子项目 A(holding 基础 + 双写)
- **范围**: holding 模块移植 + 资产管理(双写账户联动 + 价格分类策略 + 收益统计 + 模块关联)
- **分支**: `holding-asset-management`(从 main `884b92d`)
- **文档性质**: 总体设计(全景),非单实现 spec。各子项目(A/B/C/D)各自独立的 spec→plan→实现 cycle

## 1. 背景与目标

御财 Flutter 缺 holding 模块(后端 server 已完整:Security + Holding + 4 种交易 + 持仓查询)。syfinance Tauri 有完整参考(HoldingsPage:持仓表 + 饼图 + 交易)。

用户需求升级:holding 不是「简单移植」,而是「资产管理系统」:
- **自动关联账户**(buy/sell/dividend/fee 联动资金账户余额,像 debt 双写)
- **资产分类策略**(哪些资产 API 自动更新价格,哪些手动输入)
- **收益统计**(日/月/年/累计)
- **交易记录创建**(哪些操作创建 transaction/双写)
- **模块关联**(holding ↔ account/budget/goal/currency)

目标:holding 升级为资产管理核心,与 account/transaction/budget/goal/currency 系统联动。

## 2. 资产分类边界(核心模型)

### 2.1 holding security vs account asset

御财已有清晰的两类资产边界:

| 类别 | 范畴 | 位置 | 价格更新 |
|---|---|---|---|
| **Holding security**(证券持仓) | stock / fund / etf / bond / gold(纸黄金) / option | holding 模块 | API 自动(公开行情)或手动 |
| **Account asset**(非证券资产) | real_estate / fixed_deposit / gold_fx(实物黄金) / other_asset(收藏/保险) / savings / investment / credit_card / loan | account 模块 | 手动估值(定期可利息自动) |

**边界原则**:holding = 可公开报价的证券(可 API 行情);account = 非证券资产(手动估值,余额由 account/transaction 管)。资金账户(savings/investment)是 holding 双写的对手方。

### 2.2 价格更新矩阵

| 资产 | 位置 | 价格/估值 | 收益类型 |
|---|---|---|---|
| stock/etf/fund/option | holding | API 自动(B 子项目)或手动(首批) | realized + unrealized + 日/月/年(C) |
| bond | holding | API(交易所债)或手动(OTC) | realized + unrealized |
| gold(纸黄金) | holding | API(金价) | realized + unrealized |
| real_estate | account | 手动估值(定期重估) | 增值(估值差) |
| fixed_deposit | account | 手动(本金)+ 利息自动计算 | 利息 |
| gold_fx(实物黄金/外汇) | account | 手动(部分 API) | 增值 |
| savings/investment | account | 余额(transaction 驱动) | — |
| other_asset(收藏/保险) | account | 手动估值 | 增值 |

## 3. 模块关联架构

```
                 ┌──────────┐
   buy/sell ────▶│ account  │◀──双写(资金账户余额)
   dividend/fee  │ (资金侧) │
                 └────┬─────┘
                      │ 双写创建
                 ┌────▼─────┐
                 │transaction│(复式 entries,审计痕迹)
                 └────┬─────┘
   ┌──────────┐   ┌───▼────┐   ┌──────────┐
   │ budget   │   │holding │   │ goal     │
   │(投资不计 │   │ (核心) │   │(投资目标│
   │ 预算可配)│   │        │   │ D 后续) │
   └──────────┘   └───┬────┘   └──────────┘
                      │
                 ┌────▼─────┐
                 │ currency │(跨国证券外币换算,rate 已有,D)
                 └──────────┘
```

**关联**:
- **holding ↔ account**:双写余额(buy/sell/dividend/fee 联动资金账户)— A 子项目
- **holding ↔ transaction**:双写产物(复式 entries)— A 子项目
- **holding ↔ budget**:投资通常不计预算(资产转移非消费),可配置 — D 子项目
- **holding ↔ goal**:投资目标关联 — D 子项目(后续)
- **holding ↔ currency**:跨国证券外币换算(价格币种 → 本币,用 currency rate)— D 子项目

## 4. 子项目 A — holding 基础 + 双写(核心闭环)

### 4.1 server 双写改造(复用 debt 双写模式)

**关键发现**:`HoldingTransaction.TransactionID *uuid.UUID` 字段([entity.go:127](yucai/server/internal/holding/domain/entity.go))**已预留**双写钩子,只是 application service 没接。改造 = 像 debt handler 那样注入 transaction service + accountLookup,双写填该字段。

改造点(`holding/application/service.go` 或 handler 层,对齐 debt 模式):
- `BuyHolding`:双写 `credit 资金账户(现金−)` + `debit 持仓账户(asset+ hold 等价)`,金额 = price×qty + fee;填 `HoldingTransaction.TransactionID`
- `SellHolding`:反向 `debit 资金账户(现金+)` + `credit 持仓账户(asset−)`;realized PnL(`ApplySell` 已返回)
- `RecordDividend`:`debit 资金账户(现金+)` + `credit dividend income(+)`
- `fee`:随 buy/sell 记 `fee expense(+)` + `credit 资金账户(现金−)`
- `RecordSplit`:不动现金(只调数量/成本),**不双写** account

**失败策略**:fail-fast validate(资金账户 asset + 余额足够 buy)+ best-effort transaction(对齐 debt)。

### 4.2 复式方向表

| 操作 | debit | credit | 金额 |
|---|---|---|---|
| buy | 持仓账户(asset+) | 资金账户(现金−) | price×qty |
| buy fee | fee expense(+) | 资金账户(现金−) | fee |
| sell | 资金账户(现金+) | 持仓账户(asset−) | price×qty |
| sell fee | fee expense(+) | 资金账户(现金−) | fee |
| dividend | 资金账户(现金+) | dividend income(+) | totalAmount |
| split | —(不动现金)— | — | — |

### 4.3 Flutter 移植(对齐 account/transaction/debt layers)

**proto holding Dart stubs 已就绪** ✓。layers:
- `domain/`:holding_entity(Holding + HoldingTrade), security_entity, holding_repository, value_objects(SecurityType/TradeType)
- `data/`:holding_remote_ds(gRPC 10 API), holding_repository_impl, mappers
- `presentation/`:holding_bloc(event/state), pages, widgets

**首批 API**:CreateSecurity / ListSecurities / SearchSecurities / UpdateSecurityPrice / BuyHolding / SellHolding / RecordDividend / ListHoldings(8)。**server 双写改造**(§4.1)一次性覆盖 Buy/Sell/Dividend/Split 全部;**Flutter UI 首批**聚焦 security/buy/sell/dividend/list/收益,RecordSplit 的 UI + ListHoldingTransactions 交易历史作为 A 内增量(后置)。

**DI**(getIt 注册 HoldingRepository)+ 路由(`/holdings`)。

### 4.4 收益计算(client,server ListHoldings 返回 avgCost/quantity)
- `marketValue = quantity × currentPrice`
- `unrealizedPnL = marketValue − avgCost × quantity`([UnrealizedPnL](yucai/server/internal/holding/domain/entity.go) 已有)
- `realizedPnL`(卖出实现,ApplySell 返回)— A 后续增量显示
- `pnlPct = pnl / costBasis`

## 5. 子项目 B — 价格自动 sync(增量)

### 5.1 scheduler(复用 currency scheduler 模式)

复用御财已有的 background scheduler 模式([currency/scheduler/scheduler.go](yucai/server/internal/currency/scheduler/scheduler.go) `NewScheduler` + `provider.FetchRates` + `IntervalSource` 门控):
- `holding/scheduler/`:price scheduler(NewScheduler + Start + SyncPrices,按 IntervalSource 门控)
- price provider 接口(`FetchPrice(ctx, symbol) (int64, error)`),实现多源
- 每日(或更频)刷新所有 active security 的 CurrentPriceCents → `UpdateSecurityPrice`

### 5.2 API 选型(首批 1-2 个免费源)

| 市场 | API(免费) | 覆盖 |
|---|---|---|
| A 股 | 新浪财经 / 腾讯财经 / AKShare | stock/fund/etf(沪深) |
| 美股/全球 | Yahoo Finance / Alpha Vantage | stock/etf |
| 黄金 | Metals-API / GoldAPI / 新浪 | gold |
| 加密 | CoinGecko / CoinMarketCap | crypto(若加) |

**首批**:新浪(A股)+ Yahoo(美股)两个 provider,按 SecurityType/Exchange 路由。provider 可配置(后续扩展)。

### 5.3 Flutter
- 持仓页「刷新价格」按钮(loading + last-updated 时间戳)
- 价格自动 sync 后 ListHoldings 重算 marketValue/pnl

## 6. 子项目 C — 收益统计(增量)

### 6.1 realized/unrealized(server 已有)
- `ApplySell` 返回 realizedPnL([entity.go:76](yucai/server/internal/holding/domain/entity.go))
- `UnrealizedPnL` 方法
- A 子项目先显示当前 unrealized;realized 累计显示属 C

### 6.2 日/月/年/累计(新增 snapshot)

**新表** `market_value_snapshots`:
| 列 | 说明 |
|---|---|
| id, tenant_id | |
| holding_id | 关联持仓 |
| snapshot_date | 日期(每日 1 条) |
| market_value_cents | 当日市值(qty × 当日 price) |
| unrealized_pnl_cents | 当日浮动盈亏 |
| created_at | |

**每日 scheduler**(复用 scheduler 模式):收盘后对所有 active holding 快照。

**统计计算**(server 或 client):
- 日:pnl 当日变化
- 月/年:snapshot 时序聚合(期初→期末市值差 + 期间 realized)
- 累计:总 realized + 当前 unrealized

### 6.3 Flutter
- 统计 UI:收益曲线图(日/月/年切换)+ realized/unrealized 分解 + 年化
- 持仓详情页嵌收益历史

## 7. 子项目 D — 模块关联细化(增量)

### 7.1 budget
- 投资 transaction(buy/sell)默认**不计预算**(资产转移非消费)
- 可配置:holding 关联的资金账户标记「投资」,其 transaction 排除预算统计

### 7.2 goal
- 投资目标:goal 可关联 holding(或 security),进度 = 持仓市值 vs 目标额
- 后续设计

### 7.3 currency
- 跨国证券:security 有 CurrencyCode;市值换算到本币(`marketValue × rate`,用 currency rate)
- 多币种持仓汇总

## 8. OD UI(holding 三端,对齐御财设计语言)

对齐御财现有 OD 原型(account/transaction/debt/receivable)设计语言,desktop/tablet/mobile 三端(对齐 transaction-trisize 模式):

| 页面/组件 | 内容 |
|---|---|
| **持仓列表**(holdings_page) | 持仓表(symbol/名称/量/成本/现价/市值/盈亏/盈亏%)+ 排序 + type 筛选 + 顶部 StatCard(总市值/总成本/总盈亏/收益率) |
| **交易 Sheet** | buy/sell 共用(选 security + 资金账户 + 数量/价格/费用/日期);dividend/split 单独 |
| **Security 管理** | 创建/列表/搜索 security(symbol/name/type/exchange/currency)+ 价格更新(首批手动) |
| **持仓详情**(holding_detail) | 单持仓摘要 + realized/unrealized + 交易记录(首批简化)+ 收益图表(C) |
| **收益统计**(C) | 日/月/年曲线 + realized/unrealized 分解 |

**交互/动画**(对齐御财惯例):排序/筛选过渡、Sheet 滑入、StatCard 数字滚动、价格刷新 loading、mobile step wizard。

## 9. 实施路线

**A → B → C → D**,每子项目独立 spec→plan→实现:
1. **A. 基础 + 双写**(核心闭环:security + buy/sell/dividend + 双写 account + Flutter + OD UI)
2. **B. 价格自动 sync**(scheduler + 行情 provider)
3. **C. 收益统计**(snapshot 表 + 日/月/年)
4. **D. 模块关联**(budget/goal/currency)

A 完成即有可用 holding(手动价格 + 双写 + 基础收益);B/C/D 增量增强。

## 10. 范围边界

**本总体设计文档**:全局指导(资产分类 + 模块关联 + A/B/C/D 概要),不含单子项目实现细节。

**各子项目 spec**(后续,各自独立):
- A 的详细 spec(含 server 双写复式、Flutter layers、OD 原型)→ plan → 实现
- B/C/D 类似

**首批实现**:子项目 A(下一个 brainstorm→spec→plan,基于本总体设计)。

## 11. 参考

- **debt 双写模式**(A 复用):[credit-card-dual-track-sync-design.md](2026-06-28-credit-card-dual-track-sync-design.md) + [create-debt-dual-write-design.md](2026-06-28-create-debt-dual-write-design.md)
- **currency scheduler 模式**(B/C 复用):[yucai/server/internal/currency/scheduler/scheduler.go](../../yucai/server/internal/currency/scheduler/scheduler.go)
- **holding domain**(TransactionID 预留双写钩子):[yucai/server/internal/holding/domain/entity.go](../../yucai/server/internal/holding/domain/entity.go)
- **syfinance Tauri HoldingsPage**(功能参考):[src/pages/HoldingsPage.tsx](../../src/pages/HoldingsPage.tsx)
- **业界**(资产分类/价格 API):MoneyWiz/Ghostfolio/雪球(证券 API 自动:Yahoo/新浪/腾讯;房产/收藏手动)— WebSearch 限流,基于内置领域知识
