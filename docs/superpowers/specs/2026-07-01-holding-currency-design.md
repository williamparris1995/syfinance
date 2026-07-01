# Holding 子项目 D-currency · 多币种折算 + net-worth 聚合 设计

- **日期**: 2026-07-01
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: D-currency 完整(realized 多币种折算(C defer)+ net-worth 跨模块聚合(account+holding+debt)+ 用户可配本位币)
- **上游全景设计**: [2026-06-28-holding-asset-management-design.md](2026-06-28-holding-asset-management-design.md) §7.3
- **前置**: A+B+C+D-goal 已完成(final review Ready to merge Yes)
- **D 分解**: D-goal ✅;**D-currency 首批(本 spec)**;D-budget 后续

## 1. 背景与目标

御财多币种现状(Explore 确认):
- account **per-account currency_code**(原币 balance,[account.go:48-56](../../yucai/server/internal/account/ent/schema/account.go#L48))
- holding 组合曲线/unrealized/costBasis **已折算 CNY**(C);**realized 未折算**(C defer,[service.go:728-751](../../yucai/server/internal/holding/application/service.go#L728) 原币相加)
- **`home_page.dart` net-worth bug**([home_page.dart:84-90](../../yucai/client/lib/auth/presentation/pages/home_page.dart#L84)):原币 cents 直加(未折算)+ ¥ 硬编码;`accounts_page.dart` 已折算(client EUR-base `toPreferredCents`)—— 两页口径不一致
- **server 无 net-worth 聚合**(空白,grep proto 0 命中)
- `rate_history`(CNY-base,[rate_history.go:36-37](../../yucai/server/internal/currency/ent/schema/rate_history.go#L36),FindRate 向前填充,C 建)
- 组合本位币**硬编码 CNY**([service.go:665](../../yucai/server/internal/holding/application/service.go#L665))

D-currency 目标:
1. **realized 多币种折算**(C defer 接):`aggregateRealized`/`ForSecurity` 加 rate 折算
2. **net-worth 跨模块聚合**:新 `networth` 模块,`GetNetWorth` RPC(Σ account+holding − debt × rate → base)
3. **用户可配本位币**:client settings + RPC `baseCurrency` 参数(统一 net-worth + 组合曲线 + realized)

## 2. 范围边界

| 在范围(D-currency) | 不在范围(D-budget/后续) |
|---|---|
| realized 折算(aggregateRealized + base) | D-budget(actuals/排除/UI) |
| networth 模块(GetNetWorth 跨模块聚合) | 跨币种转账 FX(transaction 禁止跨币种,钩子留) |
| 用户可配本位币(client settings + RPC base) | server user profile 持久偏好(首批 client 本地) |
| convertToBase helper(CNY-base 交叉) | per-tenant 本位币(server 配置) |
| home_page 修 bug(GetNetWorth) | net-worth 时序 snapshot(每日 net-worth 历史) |
| 统一可配(GetPortfolioPerformance/GetHoldingPerformance base) | net-worth 细分 breakdown(首批粗 资产−负债) |

## 3. 架构总览

```
GetNetWorth RPC (networth/v1) ← Flutter home(baseCurrency from settings)
   ↓
networth application.GetNetWorth(ctx, tenantID, baseCurrency)
   ├─ AccountBalanceSource.SumByCurrency(tenantID)  → map[code]int64(原币)
   ├─ HoldingMarketValueSource.SumByCurrency(tenantID) → map[code]int64
   └─ DebtSource.SumByCurrency(tenantID) → map[code]int64
   ↓
每 (code, amount) × convertToBase(code, base, today) → base
totalAssets = Σ(account+holding) base; totalLiab = Σ debt base; netWorth = assets − liab

realized 折算(holding):
aggregateRealized(ctx, tenantID, baseCurrency):每 trade realized × convertToBase(security.CurrencyCode, base, tradeDate) → Σ base
```

**convertToBase helper**(核心复用):
- rate_history 是 CNY-base。任意 base 经 CNY 交叉:`amount × rate[from] / rate[base]`(from==base→1.0;CNY 作 base→rate[CNY]=1.0)
- 缺失 rate → 1.0 fallback(原币,对齐 C nil-guard)

**统一可配**:net-worth + `GetPortfolioPerformance`(组合曲线/realized/unrealized/costBasis)+ `GetHoldingPerformance` 都接 `baseCurrency` 参数,`convertToBase` 复用。

**跨模块 port**(networth 本地接口,结构实现,networth 不 import account/holding/debt —— 同 D-goal `AccountMarketValueSource` 模式)。

## 4. server 改动

### 4.1 convertToBase helper
位置:`currency/domain`(纯函数,易测)。
```go
// convertToBase 折算 amount 从 fromCode 到 baseCode,经 CNY-base rate 交叉。
// amount × rateFrom / rateBase。from==base → amount。rate 缺失(caller 传 1.0)→ 原币。
func convertToBase(amount int64, rateFrom, rateBase float64) int64 {
    return int64(math.Round(float64(amount) * rateFrom / rateBase))
}
```
(rateFrom/rateBase 由 caller 经 `RateHistoryRepository.FindRate` 取;helper 纯计算,不依赖 repo)

### 4.2 新 networth 模块(`internal/networth/`)
- domain 3 port(本地,结构实现):
  - `AccountBalanceSource.SumByCurrency(ctx, tenantID) → map[string]int64`
  - `HoldingMarketValueSource.SumByCurrency(ctx, tenantID) → map[string]int64`
  - `DebtSource.SumByCurrency(ctx, tenantID) → map[string]int64`
- `application.Service.GetNetWorth(ctx, tenantID, baseCurrency) → GetNetWorthResult{TotalAssetsCents, TotalLiabilitiesCents, NetWorthCents, Currency}`
- 各模块加 `SumByCurrency`(account Σ balance by code / holding Σ mv by code / debt Σ remaining by code)

### 4.3 realized 折算(holding 改,C defer 接)
- `aggregateRealized(ctx, tenantID, baseCurrency)`:每 trade → `security.CurrencyCode` → `FindRate(code, tradeDate)` + `FindRate(base)` → `convertToBase` → Σ base
- `aggregateRealizedForSecurity` 同(单 holding)
- 照 [samplePortfolioCNY:696-699](../../yucai/server/internal/holding/application/service.go#L696) 模式

### 4.4 GetPortfolioPerformance/GetHoldingPerformance 加 baseCurrency
- `GetPortfolioPerformance(ctx, tenantID, accountID*, range, withBenchmark, baseCurrency)`
- `samplePortfolioCNY` → `samplePortfolioInBase`(snapshot × convertToBase)
- `currentUnrealizedCNY`/`currentCostBasisCNY` → `InBase`(统一)
- `Currency: baseCurrency`(非硬编码 CNY)

### 4.5 proto
- 新 `networth/v1/service.proto`:`GetNetWorth(GetNetWorthRequest{string base_currency=1}) returns (GetNetWorthResponse{int64 total_assets_cents, int64 total_liabilities_cents, int64 net_worth_cents, string currency})`
- `holding.proto`:`GetPortfolioPerformanceRequest`/`GetHoldingPerformanceRequest` 加 `string base_currency`

### 4.6 wire + main
- networth service 接线(3 port 注入 account/holding/debt 结构)
- `wire_gen.go` 手改(镜像 B/C/D-goal,见 [[yucai-wire-handmaintained]])

## 5. schema 改动

**零新表**。复用 `rate_history`(C 建)。networth 无持久化(实时聚合)。

## 6. Flutter 改动

### 6.1 home_page 修 bug
- `_NetWorthCard` 调 `GetNetWorth(baseCurrency)` 显示(总资产/负债/净值,base 符号)
- 替换原币直加 fold([home_page.dart:84-90](../../yucai/client/lib/auth/presentation/pages/home_page.dart#L84))

### 6.2 client settings
- `baseCurrency` 存本地(`shared_preferences` 默认 CNY;Task 0 Read 确认御财 storage 方式)
- `CurrencySettings` service(getIt 单例,read/write baseCurrency)

### 6.3 本位币选择 UI
- settings 页 picker(CNY/USD/EUR/...,从 currency 模块)—— 首批单 dropdown
- 切换 → 刷新 home/performance

### 6.4 performance/holding_detail
- 传 `baseCurrency` 给 `GetPortfolioPerformance`/`GetHoldingPerformance`

## 7. 失败/降级策略
| 场景 | 处理 |
|---|---|
| rate 缺失(某币种无 rate_history) | `convertToBase` 1.0 fallback(原币,日志) |
| GetNetWorth fail | home 错误态(非崩溃;**不回退原 bug**) |
| baseCurrency 无效/空 | 默认 CNY |
| account/holding/debt port fail | best-effort(该模块跳过 + 日志,不中断) |

## 8. 测试策略(全程 TDD)
- **server**:`convertToBase`(交叉 + 同币 + 缺失 1.0 + math.Round)+ `GetNetWorth`(mock 3 port)+ `aggregateRealized` base(realized 折算)+ `GetPortfolioPerformance` base(曲线/unrealized/costBasis 统一)
- **Flutter**:home GetNetWorth 渲染 + CurrencySettings 读写 + picker 切换刷新

## 9. 前置验证(Task 0)
- **Read 御财 client storage 方式**(`shared_preferences`?hive?其他?)—— 决定 CurrencySettings 实现
- Read account/debt application(确认 `SumByCurrency` 可加 / 现有 Σ 钩子)
- 确认 `rate_history` FindRate(C 建,向前填充)

## 10. 实施顺序建议(供 writing-plans,~13 task)
```
1. convertToBase helper(currency/domain 纯函数 + 单测)
2. realized 折算(holding aggregateRealized/ForSecurity + base 参数)
3. GetPortfolioPerformance/GetHoldingPerformance 加 baseCurrency(曲线/unrealized/costBasis 统一 base)
4. networth 模块(domain 3 port + application GetNetWorth)
5. account/holding/debt 加 SumByCurrency(结构满足 port)
6. networth proto + handler
7. holding proto base + handler 改
8. wire + main(networth 接线 + 3 port 注入)
9. server e2e(GetNetWorth 多币种 + realized 折算 + base 切换)
10. Flutter client settings(baseCurrency,CurrencySettings)
11. Flutter home(GetNetWorth 修 bug + 本位币显示)
12. Flutter performance/detail(传 baseCurrency)+ settings picker
13. 全链路 + final review
```

## 11. 决策记录(用户拍板)
| # | 决策 | 选定 |
|---|---|---|
| D-currency 范围 | realized / net-worth / 全 | **全 D-currency**(realized + net-worth) |
| ① net-worth 路径 | server GetNetWorth / client 修 / 两者 | **server GetNetWorth RPC**(跨模块聚合,统一口径,CNY-base 与 rate_history 一致) |
| ② 本位币 | CNY 固定 / 用户可配 | **用户可配**(client 选 base) |
| ③ 本位币偏好存储 | client settings / server profile / 两者 | **client settings + RPC 参数**(首批简,无 server profile;后续可加) |
| ④ 可配范围 | GetNetWorth only / 统一 | **统一**(net-worth + 组合曲线 + realized/unrealized 都 base,convertToBase 复用) |
| ⑤ net-worth 组成 | 粗(资产−负债)/ 细(breakdown) | **粗**(首批,细分 defer) |

## 12. 风险清单(plan 需显式处理)
1. **client storage 方式**(Task 0 Read 确认 shared_preferences/hive/其他)—— CurrencySettings 实现依赖
2. **跨模块 port**(3 个:account/holding/debt `SumByCurrency`,结构实现,networth 不 import 三者;类似 D-goal `AccountMarketValueSource`)
3. **convertToBase 精度**(int64 × float rate,`math.Round` 对齐 entity.go 惯例;除零防护 rateBase=0)
4. **GetPortfolioPerformance 改签名**(加 baseCurrency 参数,贯穿曲线/unrealized/costBasis/realized;回归 C 测)
5. **debt application SumByCurrency**(确认 debt 模块有 per-currency Σ 钩子,或加)
6. **rate base 一致**(server CNY-base,client 改用 server GetNetWorth 而非原 EUR-base toPreferredCents for home;accounts_page 可保留 client 折算或改 server)

## 13. 参考
- C defer 点:[aggregateRealized service.go:728-751](../../yucai/server/internal/holding/application/service.go#L728) + [samplePortfolioCNY:696-699](../../yucai/server/internal/holding/application/service.go#L696)(折算样板)
- D-goal:[AccountMarketValueSource](../../yucai/server/internal/goal/domain/repository.go) 结构 port 模式(networth 3 port 照搬)
- rate_history(C 建):[FindRate 向前填充](../../yucai/server/internal/currency/adapter/driven/repository/rate_history_repo.go#L27)
- home_page bug:[home_page.dart:84-90](../../yucai/client/lib/auth/presentation/pages/home_page.dart#L84)(原币直加)
- 相关:[[yucai-wire-handmaintained]] [[yucai-dev-env]]
