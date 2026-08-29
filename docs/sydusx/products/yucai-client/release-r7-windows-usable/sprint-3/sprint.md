# Sprint 3 — R7 收益本地化

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-08-29)。

## Sprint Goal

**离线可看收益分析**:XIRR/TWR(/CAGR)在 client 本地计算(G[R5 sprint-2] 算法+oracle Dart 移植),performance 页本地模式有真实数值——R7 收官,R6 defer 的「收益引擎离线化」补齐。

## Feature roster(依赖排序)

- [ ] **feature D** 2026-08-29-d1-local-return-engine — XIRR/TWR/CAGR Dart 镜像(归一化+Brent+GIPS 三态分段,server oracle 移植)+ performance 本地数据装配(本地模式现金流/MV 重建)+ 双源接线(本地算/在线 server 权威) `claimed: zcode-main 2026-08-29`

## defer

- 主指标语义消费(重命名/tooltip,server 已 enum 进 wire[R5-H])→ client UI polish 线;holding 级别收益本地化视 portfolio 落地成本;Android→R8。

## status: in-progress(feature D claimed)
