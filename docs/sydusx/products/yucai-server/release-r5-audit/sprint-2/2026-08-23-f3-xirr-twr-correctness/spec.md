# Spec — F3 xirr-twr-correctness(R5 sprint-2 feature G)

> 源 ticket [.scratch/yucai-audit/issues/06](../../../../../../../.scratch/yucai-audit/issues/06-financial-calculation-correctness.md) 决策 2/3/4 + Q5(决策已 resolved 2026-07-26),另折入 F12 最小守卫(grill 决策 #4)。决策 1(主指标切换)= feature H,紧跟本 feature(grill 决策 #3)。
> research [.scratch/yucai-audit/research/financial-calc-standards.md](../../../../../../../.scratch/yucai-audit/research/financial-calc-standards.md)(14 信源:Excel / scipy / numpy-financial / GIPS / CFA)。
> branch `feature/f3-xirr-twr-correctness`,worktree `.claude/worktrees/f3-xirr-twr-correctness`。

## Problem

收益引擎六项数值缺陷 + 一项入口守卫缺失(代码定位 2026-08-29):

- **[F3 P1]** XIRR 收敛阈值绝对值 1e-7(`holding/domain/xirr.go:74`)——大额组合(≥1e7 cents 危险,1e8 必现)NPV 浮点噪声大于阈值永不收敛 → ErrNoSolution → 静默 nil。
- **[F4 P1]** bisection fallback 固定 bracket [-0.9999, 1000](`xirr.go:92`)——短日暴利解(1 天 +10% → 年化 ≈1.28e15)在区间外,漏解 → ErrNoSolution(UI 空白的已知成因之一)。
- **[F5 P1]** Buy/Sell `AmountCents = int64(float64(PriceCents) × Quantity)` 截断 **4 处**(`holding/adapter/driving/grpc/holding_handler.go:104/140` + `holding/application/service.go:150/244`)——逐笔分位漂移进 XIRR/TWR。
- **[F6 P1]** TWR 全期一条链,不切分完全清仓段(`holding/application/service.go:1428` computeTWR)——GIPS:完全清仓=组合终止,重建应重启子链;现状要么零端值降级要么口径失真。
- **[F7 P1]** 等额本金 `monthlyPrincipal = TotalPrincipalCents / int64(months)` 整除截断 + 利息按截断 remaining 复算(`debt/domain/service.go:50-71`)——系统性偏差。
- **[F10 P1]** TWR 年化 `math.Pow(1+cumulative, 1/years)` 无 `cumulative<-1` 防御(`holding/domain/twr.go:56`)——NaN 风险。
- **[F12 P2→G]** RecordSplit 三层(`holding_handler.go:188` / `service.go:297` / `domain/entity.go:108`)均无 ratio≤0 校验——quantity 无条件乘,坏请求静默打烂持仓且成本不调整。

## FRs

- **FR-1 XIRR 入口归一化**:`XIRR()` 入口按 max|amount| 归一化全部现金流——数学等价(NPV(r; α·cf) = α·NPV(r; cf),零点不变;scipy atol + rtol·scale 风格)。scale=0 → ErrNoSolution。附带解决 F11(float64 精度上限)。
- **FR-2 Brent-only 求解器**:删除 Newton 主迭代与固定 bracket bisection。自适应几何倍增扩展(lo 固定 -0.999999;hi 自 0.1 起翻倍直至 NPV 反号;上界 1e16,超出返 ErrNoSolution;扩展次数封顶)后 Brent(1973)求根——对齐 scipy brentq / MATLAB fzero / Numerical Recipes zbrent 行业默认。包络 (-0.999999, 1e16) 内存在根 ⇒ 必收敛。Excel 仅作值 oracle,不复刻其 Newton 算法。
- **FR-3 TWR 清仓分段 + sentinel**:(a) service 层完全清仓段(qty=0 区间)切分子链——链乘重启,重建视为新 track(GIPS:完全清仓=组合终止);(b) domain 层零端值与 `cumulative<-1` 返**可判别** error(非 NaN、非泛型错误);(c) service 捕获后照旧映射 nil 降级 + 英文结构化日志记原因。**DTO/proto 零改动**(grill #1)。
- **FR-4 AmountCents 统一 math.Round**:4 处截断全改四舍五入(层级归属——handler 透传 service 统一 round vs 两层各自 round——留 design 决策)。
- **FR-5 等额本金均摊修正**:月供本金浮点均摊 + 每月四舍五入,末月吸收余差(总额守恒);利息按真实 float remaining 复算。**存量已生成 schedule 不变**(仅新生成走新算法;ticket 决策 4)。
- **FR-6 split 入口守卫**:ratio≤0 请求拒绝(InvalidArgument 语义;守卫层级留 design)。fail-closed:校验先于任何持久化/lot 变更。
- **FR-7 真实样本 oracle 测试**:端到端——大额 1e8 收敛、清仓重建分段链乘、Excel/scipy 值对拍断言;真 cashflow 样本经 service 层真实取数,防 mock 掩盖(同 07 F1 决策)。

## NFRs

- 收敛可靠性:包络内必收敛(Brent bracketed 保证);无根/包络外/全同号/<2 笔 → ErrNoSolution,domain error 可判别。
- 向后兼容:DTO/proto 零改动;`go test ./...` 全绿(行为变更导致的既有断言更新需逐一记录);debt 零 schema 零迁移。
- 降级可观测:降级原因结构化英文日志(full-liquidation / zero-endpoint / no-solution / diverged;无 CJK——CLAUDE.md 日志约束)。
- 性能不退化:御财规模(<1000 cashflows)求解时延与现状同量级(research 2.3:此规模 Brent 与 bisection 差异可忽略)。

## 测试计划

- xirr 单测:大额 1e8 收敛 / 1 天+10% 极端解(≈1.28e15)/ 常规多笔 / 全同号 / <2 笔 / 包络外 ErrNoSolution / 归一化等价性(同组样本归一前后同根)。
- twr 单测:清仓分段链乘(手算 oracle)/ 零端点 sentinel / cumulative<-1 防御 / totalDays<1 返累计。
- service 集成:清仓重建 e2e(真 trades → 分段值)/ 大额 1e8 e2e / Excel XIRR 值 3-5 组对拍 + NPV(r)=0 自洽断言。
- debt 单测:均摊本金总和守恒 / interest 序列手算对拍 / 存量 schedule 不变。
- split 守卫:ratio=0 / ratio=-1 拒绝,holdings/lots 零变更。

## Grill record(2026-08-29,用户逐条拍板)

1. **TWR sentinel wire 层不动** — 挑战:绑定用户在收益本地化落地前的窗口期承受含糊降级(nil 不区分原因);辩护:本地化(pivot A client 线)将取代 DTO 路径,零 contract 债优先,届时 client 原生表达降级原因。
2. **Brent-only 删 Newton** — 挑战:删一段能工作的 fast path;非常规现金流多根时与 Excel(同 guess 起点的 Newton)可能收敛到不同合法根;辩护:scipy/MATLAB/NR 行业默认 bracket-first,包络内 Newton 可解集 ⊆ Brent 可解集,Excel 只作值对拍(oracle 断言结果非算法)。
3. **H 紧跟 G 不并不推** — 挑战:H 的 server DTO 改动是给将被本地化取代的路径刷漆;辩护:F2 P0(头部指标 CAGR 方法论失真)在窗口期继续骗人,vision「财务计算准确」的完成语义含主指标正确。
4. **F12 最小守卫折进 G** — 挑战:为 ticket 明确 P2 的东西破 scope 纪律;辩护:静默数据损坏的「视反馈」机制失灵(发现即已损坏),sprint-2「数据完整性+计算正确性」立意覆盖,E/F 有意图覆盖先例(goal/template 引用列)。
5. **rateCeiling 修正 1e8 → 1e16** — research 内部矛盾:其 2.3 建议 ceiling=1e8,装不下其附录 B 自己的测试用例(1 天 +10% 真根 ≈1.28e15);上界改 1e16 覆盖该 case,超出仍返 ErrNoSolution。

## Scope boundary(排除即决策,逐条有主)

| 排除项 | 归属 | 理由 |
|---|---|---|
| 决策 1 主指标切换 + 口径标注 | **feature H**(紧跟 G) | 依赖 G 数值稳定;grill #3 |
| F13 LumpSum 单利口径 | P2 backlog | ticket 06 原文;显示口径非计算 bug |
| client UI 口径/tooltip/短期间警告 | client 线 defer | research 2.2(d);portfolio pivot A(2026-08-29) |
| 存量 schedule 重算 | 不做 | ticket 决策 4:仅新生成走新算法 |
| 等额本息(equalPrincipalInterest) | 无需修 | 代码事实:已是 roundToInt64 + float remaining 模式,与 F7 目标形态一致 |
| 多根(非常规现金流)语义 | 不处理 | 持仓现金流天然常规(先买后卖)单根;scipy 同样把选根交给 bracket |

## 可行性

- **Technical: GO** — 纯 domain/局部 service 改动,零 schema 零 wire;Brent 移植约百行 Go,oracle 测试护正确性;TWR 分段为主要风险点(GIPS 示例 + e2e 缓解)。
- **Economic: GO** — research 附录 A 估各修法 0.5-4h,合计中等体量单 feature,无外部依赖。
- **Operational: GO** — 无部署/迁移影响;观测仅增结构化日志。
