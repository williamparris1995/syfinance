# request-scoped TWR cache · 设计 spec

- **日期**: 2026-07-16
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: `portfolioTWR` 的 full+range `computeTWR` 共享 **request-scoped** `marketValueAtDateAsOf` cache,消除 range ⊂ full 的 BV(day) 重复计算。性能 follow-up([2026-07-13-twr](2026-07-13-twr-design.md) 风险2 cache defer + [range TWR](2026-07-15-range-twr-design.md) 加重)。**纯 application 内,透明**(domain/proto/client/handler 不改)。

## 1. 背景

TWR(`portfolioTWR → computeTWR`)遍历 N cashFlowDays × `marketValueAtDateAsOfWithTrades`(每 day BV_before + BV_after = 2 调用,各跨 M holdings Σ qty×price×rate)。原 spec 风险2「组合级跨 holding Σ BV:N 现金流日 × M holding。首批可接受;缓存 defer」。

range TWR(2026-07-15)加重:`portfolioTWR` 调 computeTWR **两次**(full rangeStart=cashFlowDays[0] + range rangeStart=curveWindow.from),各自 BV(day) 调用**重叠**(range effectiveDays ⊂ full effectiveDays)。同 (accountID, qtyAsOf, priceAsOf) 在 full 和 range 各算一次。

XIRR 不遍历 cashFlowDays(per-trade `collectTradeCashFlows` + 1 个 `marketValueAtDate(rangeStart)`),开销小,不受益。

**cache 收益点 = full+range TWR 的 BV(day) 重复**。

## 2. 目标

`portfolioTWR` 内 request-scoped cache,full+range computeTWR 共享 BV(day)。消除重叠计算。**透明**(结果 byte-identical)。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| request-scoped `mvCache`(portfolioTWR 内,full+range 共享) | persistent cache(跨 request,需失效) |
| cache `marketValueAtDateAsOfWithTrades` 结果 | price/qty 子结果 cache(底层,跨 XIRR 共享) |
| computeTWR 加 cache 参数(透明) | XIRR 缓存(不遍历 cashFlowDays,无收益) |
| benchmark 验证收益 | 跨 `GetPortfolioPerformance` cache(需失效) |

**零 domain/proto/client/handler 改动**(cache 纯 application 内)。

## 4. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | scope | **request-scoped**(portfolioTWR 内) | 无失效;最小改动;直接消除 full+range 重复 |
| 2 | 粒度 | `marketValueAtDateAsOfWithTrades` 结果(非 price 子结果) | 直接消除 BV(day) 重复;price cache 跨 XIRR 复杂 |
| 3 | 共享 | full+range computeTWR 共享(range ⊂ full) | range effectiveDays ⊂ full,BV 复用 |
| 4 | 透明 | cache 不影响结果(byte-identical) | 回归保证(全期+range TWR 不变) |
| 5 | 不改 XIRR | XIRR 不遍历 cashFlowDays,不 cache | 无收益 |

## 5. 架构

| 层 | 组件 | 职责 |
|---|---|---|
| **application**(新)| `mvCacheKey{accountID uuid.UUID, qtyAsOf, priceAsOf time.Time}` + `mvCache map[mvCacheKey]struct{val int64; ok bool}` | request-scoped cache 类型 |
| **application**(新)| `cachedMV(ctx, cache, trades, tenantID, accountID, qtyAsOf, priceAsOf, rateBase, base) (int64, bool)` | memoize `marketValueAtDateAsOfWithTrades`;hit 返,miss 算+存 |
| **application**(改)| `computeTWR(..., cache mvCache)` | 加 cache 参数;3 处 `marketValueAtDateAsOfWithTrades` → `cachedMV(cache, ...)` |
| **application**(改)| `portfolioTWR(...)` | 创建 `cache := mvCache{}`,传 computeTWR full + range(共享) |

## 6. cache key

```go
type mvCacheKey struct {
    accountID uuid.UUID  // nil(组合级)→ uuid.Nil;具体账户 → *accountID
    qtyAsOf   time.Time
    priceAsOf time.Time
}
type mvCache map[mvCacheKey]struct{ val int64; ok bool }
```

`tenantID`/`rateBase`/`base` 在 `portfolioTWR` 内固定(一次 request 同 base),不进 key。

`cachedMV`:
```go
func (s *Service) cachedMV(ctx context.Context, cache mvCache, trades []domain.HoldingTransaction,
    tenantID uuid.UUID, accountID *uuid.UUID, qtyAsOf, priceAsOf time.Time, rateBase float64, base string) (int64, bool) {
    ac := uuid.Nil
    if accountID != nil {
        ac = *accountID
    }
    key := mvCacheKey{accountID: ac, qtyAsOf: qtyAsOf, priceAsOf: priceAsOf}
    if v, hit := cache[key]; hit {
        return v.val, v.ok
    }
    val, ok := s.marketValueAtDateAsOfWithTrades(ctx, trades, tenantID, accountID, qtyAsOf, priceAsOf, rateBase, base)
    cache[key] = struct{ val int64; ok bool }{val, ok}
    return val, ok
}
```

`computeTWR` 的 3 处 `marketValueAtDateAsOfWithTrades` 调用(BV_after(rangeStart) + BV_before/after(effectiveDays))→ `cachedMV(cache, ...)`。

## 7. 收益

- range computeTWR effectiveDays(`cashFlowDays after curveWindow.from`)⊂ full(`cashFlowDays[1:]`)
- range 的 BV(day) **cache hit** 复用 full(overlap)
- 省 range effectiveDays × 2(BV_before/after)次 `marketValueAtDateAsOfWithTrades`(各跨 M holdings Σ)
- 量化:benchmark(N=10 cashFlowDays × M=5 holdings,portfolioTWR before/after `marketValueAtDateAsOfWithTrades` 调用数)

## 8. 测试

- **正确性**:同 key 返同结果;cache hit 时 `marketValueAtDateAsOfWithTrades` 不重调(mock 调用计数验证)
- **回归**:全期 + range TWR **byte-identical**(cache 透明,现有 range TWR Task 1/2 测不破)
- **benchmark**:N=10 days × M=5 holdings,portfolioTWR 的 `marketValueAtDateAsOfWithTrades` 调用数 before(无 cache,full+range 各算)/ after(cache,range hit)—— 期望 range 的 BV 全 hit

## 9. 风险

1. **cache key 正确性**:accountID nil→`uuid.Nil`(组合);qtyAsOf/priceAsOf `time.Time` 精确(同 day 同 key,struct 可比较)。
2. **cache 透明性**:cache 只 memoize(miss→算+存,hit→返),不改算法。回归 byte-identical 保证(Task 1/2 测)。
3. **rateBase/base 不进 key**:`portfolioTWR` 内同 base(一次 request),固定。若未来同 request 多 base,需进 key(本 scope 单 base)。
4. **nil/ok 缓存**:`ok=false`(price 缺降级)也 cache(避免重算 price 缺)。`struct{val, ok}` 存两者。
5. **无失效(request-scoped)**:每 request(portfolioTWR 调用)重建 cache。无跨 request 残留。price 更新(scheduler)不影响(request 内快照)。
6. **memory**:cache 大小 = O(unique (accountID, qtyAsOf, priceAsOf))。N cashFlowDays × 2(BV_before qtyAsOf=day, BV_after qtyAsOf=day+1)+ rangeStart。bounded(数十~百)。无泄漏。

## 10. 参考

- TWR 全期 spec:[2026-07-13-twr-design.md](2026-07-13-twr-design.md) 风险2(N×M 性能,cache defer)
- range TWR spec:[2026-07-15-range-twr-design.md](2026-07-15-range-twr-design.md)(computeTWR full+range,加重)
- `portfolioTWR`/`computeTWR`/`marketValueAtDateAsOfWithTrades`:[service.go](../../yucai/server/internal/holding/application/service.go) L1132/1230/1289
- memory:[[holding-asset-management-todo]](TWR cache defer)
