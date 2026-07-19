# holding price+snapshot 合并 e2e · 设计 spec

- **日期**: 2026-07-19
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: main(main-driven,从 main `0080325`)
- **范围**: 补 B-价格 sync + C-snapshot 跨层 integration test(**合并 1 spec**)。**纯 test 新增**,零 proto/schema/production 改。

## 1. 背景

holding e2e 套件系列:performance ✅(`8694afa..3d34548`)+ CreatedAt fix ✅(`ebd4e2a`)+ sell 双写 ✅(`29d207f..0080325`)。本 spec 是第 3 spec(price+snapshot)。

price+snapshot 现有 test:
- **priceprovider**:5 个 domain 单测(sina/yahoo/router/history/provider)
- **scheduler**:`scheduler_test` + `snapshot_scheduler_test`(单测)
- **application service**:SyncPrices/BackfillPriceHistory 单测(fake provider)
- **repository**:price_history_repo 单测

**缺跨层 integration**:provider → SyncPrices → price_history 持久化 + scheduler → snapshot 持久化(端到端)。

## 2. 目标

补 B-price sync + C-snapshot 跨层 integration(合并 1 spec):
- **B-price**:fake Provider → SyncPrices → price_history + CurrentPrice 持久化
- **C-snapshot**:SnapshotScheduler.SyncNow → SnapshotAllHoldings → holding_snapshot 持久化(market value)

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 合并 1 spec(B+C) | 是 | 用户选合并;两子模块独立但同属 e2e 套件第 3 spec;plan 拆 task(B/C/harness) |
| 2 | B-price 入口 | `service.SyncPrices`(非 scheduler ticker) | SyncPrices 是核心逻辑;ticker 异步,test 用 manual trigger;fake Provider 注入 |
| 3 | C-snapshot 入口 | `SnapshotScheduler.SyncNow`(manual trigger) | 不等 ticker/IntervalSource(异步 + 时间 gate);SyncNow 立即触发,确定性 |
| 4 | fake Provider | test 内 StubProvider(返固定 price + ErrNoSource) | 避免网络(sina/yahoo);照 priceprovider 单测 fake 范式 |
| 5 | TenantLister | wire auth.TenantRepository.FindAllIDs(adapter) | SnapshotAllHoldings 跨 tenant fan-out(memory D-goal 范式) |
| 6 | FIFO lot | 非范围 | lot consumption 是 sell realized(独立);本 spec snapshot 是 market value 时序 |

## 4. 范围边界

| 在范围 | 不在范围 |
|---|---|
| TestSyncPrices_PersistsPriceHistoryAndCurrentPrice | FIFO lot consumption(sell realized,独立) |
| TestSnapshotNow_PersistsHoldingSnapshot | 真 sina/yahoo provider(网络,defer) |
| fake Provider + CompositeRouter + TenantLister wire | scheduler ticker 异步 loop(test 用 SyncNow manual) |
| black-box(price_history/snapshot repo 查) | range-period 覆盖(performance 套件 future) |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| harness(新) | `setupPriceSnapshotHarness` | 真 ent + service(SetPriceRouter/SetSnapshotRepository/SetPriceHistoryRepository/SetTenantLister/SetNow)+ fake Provider + CompositeRouter + SnapshotScheduler |
| B-price test | `TestSyncPrices_PersistsPriceHistoryAndCurrentPrice` | fake Provider 返 price → SyncPrices → price_history + CurrentPrice |
| C-snapshot test | `TestSnapshotNow_PersistsHoldingSnapshot` | seed tenant/holding/security/price → SyncNow → holding_snapshot MV |
| 文件 | `yucai/server/tests/holding_price_snapshot_integration_test.go`(新) | +harness + 2 test |

## 6. 核心改动

### 6.1 setupPriceSnapshotHarness

扩展 `setupPerformanceHarness` 范式(真 ent + service + setter):
- wire 真 ent repo(security/holding/trade/snapshot/priceHistory)
- `service.SetSnapshotRepository` / `SetPriceHistoryRepository` / `SetPriceRouter(CompositeRouter{fakeProvider})` / `SetTenantLister(auth.TenantRepository.FindAllIDs adapter)` / `SetNow(fixed eval)`
- 返 svc + repos + tenantID/accountID + `SnapshotScheduler`(或直接用 svc.SnapshotAllHoldings 走 SyncNow)

### 6.2 TestSyncPrices_PersistsPriceHistoryAndCurrentPrice(B-price)

- seed security("600519", CNY, CurrentPriceCents=0 初始)
- fake Provider.FetchPrice 返 priceCents=15000(source="test")
- `svc.SyncPrices` → 验:
  - `security.CurrentPriceCents == 15000`(`securityRepo.FindByID`)
  - price_history 持久化(`priceHistoryRepo.FindBySecurity` 含今日 price=15000)

### 6.3 TestSnapshotNow_PersistsHoldingSnapshot(C-snapshot)

- seed tenant + holding(100 qty)+ security(CurrentPrice=13000)+ price_history(为 MV)
- `SnapshotScheduler.SyncNow(ctx)` → `svc.SnapshotAllHoldings`(cross-tenant fan-out via TenantLister)
- 验:`snapshotRepo.FindSnapshots` 返 holding_snapshot(market value = 100×13000=1300000,SnapshotDate=today)

## 7. 数据流

**B-price**:
```
seed security(CurrentPrice=0) + fake Provider(返 15000)
→ svc.SyncPrices: router.FetchPrice → 15000 → priceHistoryRepo.Save(今日 15000) + securityRepo.UpdatePrice(15000)
→ 验 CurrentPrice=15000 + price_history 含 15000
```

**C-snapshot**:
```
seed tenant/holding(100 qty)/security(price=13000)/price_history
→ SnapshotScheduler.SyncNow → svc.SnapshotAllHoldings(cross-tenant fan-out)
→ per holding: MV = qty × price → snapshotRepo.Save(holding_snapshot)
→ 验 FindSnapshots 返 MV=1300000
```

## 8. 测试

| 场景 | 覆盖 | 断言 |
|---|---|---|
| TestSyncPrices_PersistsPriceHistoryAndCurrentPrice | B-price sync 跨层 | CurrentPrice 更新 + price_history 持久化 |
| TestSnapshotNow_PersistsHoldingSnapshot | C-snapshot 跨层 | holding_snapshot MV 持久化 |

零回归:全量 server 测 pass + build green(performance 套件 S1-S4 + sell 双写 + buy 不破)。

## 9. 风险

1. **fake Provider 接口**:test StubProvider 实现 FetchPrice(返固定 + ErrNoSource 跳过)。照 priceprovider 单测 fake 范式。
2. **SnapshotAllHoldings 跨 tenant**:`TenantLister` wire(auth.TenantRepository.FindAllIDs adapter);fan-out per tenant。memory D-goal 范式(implementer plan 确认 wire)。
3. **MV 计算**:snapshot MV = qty × price。需 seed price_history(priceAtOrBefore)或 security.CurrentPrice(implementer 确认 SnapshotHoldings 用哪个)。
4. **SyncNow manual trigger**:不等 ticker/IntervalSource(test 确定性)。
5. **snapshot 时序**:SnapshotDate = today(`s.now()` 注入;Task 1 SetNow 复用,固定评估日)。
6. **CompositeRouter wire**:`service.SetPriceRouter(CompositeRouter{fakeProvider})`。
7. 零 proto/schema/production 改(纯 test)。

## 10. 参考

- priceprovider 接口:[provider.go](../../yucai/server/internal/holding/adapter/driven/priceprovider/provider.go)(Provider/Router/ErrNoSource)
- scheduler:[snapshot_scheduler.go](../../yucai/server/internal/holding/scheduler/snapshot_scheduler.go)(Snapshotter/SnapshotScheduler.SyncNow)
- service:`SyncPrices`(service.go:589)/ `SnapshotHoldings`(service.go:481)/ `SnapshotAllHoldings`
- holding e2e 套件:[2026-07-19-holding-e2e-design.md](2026-07-19-holding-e2e-design.md) + sell 双写 [2026-07-19-holding-sell-doublewrite-design.md](2026-07-19-holding-sell-doublewrite-design.md)
- memory:D-goal TenantLister 范式(auth.TenantRepository.FindAllIDs fan-out)
