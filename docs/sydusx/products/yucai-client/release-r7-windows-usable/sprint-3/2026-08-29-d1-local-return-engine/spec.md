# Spec — D1 local-return-engine(R7 sprint-3 feature D,R7 收官)

> grill 定案(2026-08-29):β 双源(guest 本地算+绑定断网 fallback 本地算);本地 TWR 口径=成交价锚(镜像无价格历史,事实盘点)。
> branch `feature/d1-local-return-engine`,worktree `C:/sywt/d1-local-return-engine`。
> 算法资产:R5-G(server Go:归一化+Brent+GIPS 三态,oracle 齐全)。

## Problem

本地模式 performance 页直接 throw「离线暂不支持收益分析」(`holding_local_ds.dart:448`);绑定断网同样报错——离线完整宪法在收益页的缺口(R6 显式 defer 项)。

## 现状盘点(2026-08-29)

- 本地数据面:Holdings(qty/avgCost)+ HoldingTransactions(priceCents/amountCents/feeCents)+ Securities(currentPriceCents)+ SecurityPriceHistories(guest 模式仅成交价锚点)。
- 镜像(`bound_mirror._refreshHoldings`)刷 holdings/trades/securities,**不含 price history** → 绑定模式本地 TWR 只能成交价锚。
- 双源缝隙已在:`HoldingRepositoryImpl.getPortfolioPerformance` 的 `_useLocal ? _local : _remote` 分支;`_local` 现 throw。
- server 参考:`internal/holding/domain/{xirr,brent,twr}.go` + 测试 oracle(xirr_test/brent_test/twr_test/segment e2e)。

## FRs

- **FR-1 Dart 引擎移植**:`lib/holding/domain/return_engine/`(纯函数):`xirr(cashflows)`(归一化+bracket 几何扩展包络 1e16+Brent+噪声模型回代校验)+ `cumulativeTwr/annualizeTwr`(GIPS:清仓段切分由装配层负责,domain 返可判别错误)。**oracle=G 测试用例逐值移植**(闭式解/Excel 37.34%/陡梯度深亏 −0.9697/1e8/极端 1.28e15/NaN graceful/月末钳制无关)。
- **FR-2 本地装配**:`_local.getPortfolioPerformance` 实现:现金流=trades(±fee)+ 终值=Σ qty×现价;TWR 子区间成交价 ffill;realized/unrealized/costBasis/totalPct 本地算;CAGR(costBasis→MV)。
- **FR-3 双源 β 接线**:guest→本地;绑定在线→server;**绑定断网→repo fallback 本地**(NetworkFailure/GrpcError 捕获后走 `_local`),不重试轰炸。
- **FR-4 曲线 best-effort**:price history+现价 ffill 出组合曲线;不足→空曲线+指标照常。
- **FR-5 口径标注**:本地/回退路径 TWR 附「离线口径·按成交价」(entity 字段,UI 呈现 polish 定)。

## NFRs

- oracle 对拍:相对误差 ≤1e-9(IEEE754 双精度一致预期)。
- `flutter test` 基线不退化;零 server 改动;错误隔离(计算异常→对应指标 nil,页面不炸)。

## 测试计划

- 引擎单测:G oracle 全量移植(xirr/twr ~20 例)+ 归一化等价/包络守卫/三态分段 e2e(清仓重建手算 1.21 链)。
- 装配单测(内存 drift):造 trades/holdings/securities → 指标断言(手算 oracle)。
- repo fallback 单测:绑定+remote 抛 NetworkFailure → 本地值返回 + 口径标注。
- 打包版冒烟:guest 模式建仓→performance 页数值可见;断网绑定→fallback。

## Grill record(2026-08-29)

1. **β 双源(vs α guest-only / γ 统一本地)** — 挑战:β 在线/离线 TWR 口径跳变(市场价 vs 成交价锚);辩护:宪法要求离线完整,跳变用「离线口径」标注诚实化,XIRR 主指标两口径基本一致;γ 否决(镜像无价格历史,在线也退化成成交价锚=比 server 差,为架构一致性牺牲数值质量);α 否决(断网收益页报错=宪法缺口)。用户"同意"。

## Scope boundary(排除即决策,逐条有主)

| 排除项 | 归属 | 理由 |
|---|---|---|
| holding 级 performance 本地化 | 后续 polish | 主页面优先;throw 改优雅降级不炸页 |
| 沪深300 benchmark 本地曲线 | 不做 | server-only 数据源 |
| 主指标 enum UI 消费(R5-H) | client polish 线 | server 已就位 |
| price history 镜像扩展 | ticket 16/后续 | 绑定离线 TWR 市场价口径的前提;当前 fallback 已诚实 |
| 多币种折算复杂化 | 沿现状 | 本币近似,标注口径 |

## 可行性

- **Technical: GO** — Go 参考+oracle 完整;数据面齐;双源缝隙现成。
- **Economic: GO** — 2-3 天(sprint-3 主体)。
- **Operational: GO** — 零部署。
