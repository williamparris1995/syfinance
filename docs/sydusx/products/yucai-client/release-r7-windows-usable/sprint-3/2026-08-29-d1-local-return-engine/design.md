# Design — D1 local-return-engine(R7 sprint-3 feature D)

> 消费 [spec.md](./spec.md)。算法设计=R5-G design(8 ADR)直接引用,不重开;此处只记 D 特有决策。

## Decisions(D 特有)

- **ADR-D1 引擎为纯函数包** `lib/holding/domain/return_engine/`(xirr.dart/brent.dart/twr.dart):无 drift/插件依赖,oracle 测试直打;与 Go 版逐函数对应(brentRoot/xirr/cumulativeTwr/annualizeTwr 同名同参语义)。
- **ADR-D2 装配在 local ds**:`holding_local_ds.getPortfolioPerformance` 组装(查询 drift→构造现金流/MV 序列→调引擎);错误→对应指标 null(entity 本就 nullable)。
- **ADR-D3 β fallback 在 repo**:绑定分支 remote 结果为 NetworkFailure 类 Left 时改走 `_local`(一次性,不重试);新增 entity 字段 `offlineScope`(bool)承载口径标注。
- **ADR-D4 成交价 ffill**:本地价格序列=trades 的 (date→price) + securities.currentPrice(视为今日价)合并排序前向填充;TWR/曲线共用。

## HLD

```
performance bloc → HoldingRepositoryImpl.getPortfolioPerformance
                     ├─ guest → _local(引擎)
                     ├─ bound+online → _remote(server 权威)
                     └─ bound+NetworkFailure → _local(引擎,offlineScope=true)
_local → drift(holdings/trades/securities/priceHistory)
       → return_engine(纯函数)→ PortfolioPerformance
```

## Risks

| 风险 | 缓解 |
|---|---|
| 移植数值漂移 | G oracle 逐值对拍(≤1e-9 相对);IEEE754 双端一致 |
| 本地口径误当 server 值 | offlineScope 字段+UI 标注(FR-5) |
| ffill 语义差(无价区间) | 空曲线+指标照常(FR-4 优雅降级) |

## Migration

无 schema 变更(entity 加可空字段+offlineScope 默认 false,UI 兼容)。
