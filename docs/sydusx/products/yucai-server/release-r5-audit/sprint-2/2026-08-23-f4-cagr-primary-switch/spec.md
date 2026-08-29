# Spec — F4 cagr-primary-switch(R5 sprint-2 feature H)

> 源 ticket [.scratch/yucai-audit/issues/06](../../../../../../../.scratch/yucai-audit/issues/06-financial-calculation-correctness.md) 决策 1(resolved 2026-07-26):portfolioXIRR 切主指标,CAGR 降级辅助+口径标注。G(xirr-twr-correctness,✅ done 2026-08-29)修好数值稳定性后本 feature 落地 DTO 层。
> branch `feature/f4-cagr-primary-switch`,worktree `.claude/worktrees/f4-cagr-primary-switch`。

## Problem

`PortfolioPerformance`(proto `holding.proto:185-200`)里 XIRR/TWR/CAGR 是三个平行 optional 字段,主指标概念不在 wire——头部指标由 client 自挑,方法论有 bug 的 CAGR(忽略已实现盈亏,清仓重建严重失真,F2 P0)与其他指标地位相同,口径无机器可读标注。

## 现状盘点(2026-08-29)

- proto:`annualized_pct=7`(XIRR)/`twr_annualized_pct=11`/`cagr_annualized_pct=13`,注释未标主辅与口径。
- service:`GetPortfolioPerformance`(`service.go:776`)装配三组值,无主指标语义。
- 契约:`portfolio/contracts/yucai-api`(server produces/client consumes);R6 client done,消费方变动需记档。

## FRs

- **FR-1 proto 契约(β 方案,grill 定案)**:`PortfolioPerformance` 新增 `ReturnMetric` enum(仅 `XIRR=1`,零值 UNSPECIFIED)与 `CagrScope` enum(仅 `CURRENT_HOLDINGS_COST_TO_MV=1`),及 `optional` 字段 `primary_return_metric` / `cagr_scope`;字段注释标主辅+口径(XIRR=主指标;CAGR=辅助,仅当前持仓成本→市值、忽略已实现盈亏)。
- **FR-2 server 填充**:dto.go `PortfolioPerformance` 补两字段;`GetPortfolioPerformance` 恒填常量语义值(无 nil 分支)。
- **FR-3 regen 边界**:仅 server `holding.pb.go` regen;client `gen-dart` 不跑(client 零改动,旧 pb 不受纯新增 optional 字段影响;client 线收益本地化时随行 regen)。
- **FR-4 契约记档 + 测试**:`contracts/yucai-api` 记本次向后兼容变更(新增 optional×2,消费 defer 至 client 线);service 断言两字段填充。

## NFRs

- 向后兼容:纯新增 optional 字段,旧 client 编译/运行无感;既有 `go test ./...` 全绿。
- 边界不变:改动限于 proto + holding application/handler;depguard 无新依赖方向。
- 注释英文与 proto 既有风格一致。

## 测试计划

- service 单测:`GetPortfolioPerformance` 返回的两枚举字段 = 常量语义值(含 benchmark off/on 两形态)。
- handler 层:响应含两字段(gRPC round-trip 类型正确)。
- 既有套件全绿(基线不退化)。

## Grill record(2026-08-29)

1. **wire 形态 β(enum 字段)vs α(纯注释)** — 挑战:β 为永不再变的常量付 regen+契约通告成本,"配置表演";辩护:grill #3(G 阶段)承诺的"DTO 层就位"诚实落地=机器可读,单一事实源(指标语义归 server/展示归 client),i18n 文案不跨端;α 的 H 名不副实。用户"同样同意"。

## Scope boundary(排除即决策,逐条有主)

| 排除项 | 归属 | 理由 |
|---|---|---|
| HoldingPerformance 加同款字段 | 不做 | 其 CAGR 是 price-based 口径不同;展示层归 client 线统一 |
| client 消费(重命名/tooltip/头部切换/gen-dart) | client 线 defer | R5 scope 外(sprint 行已记);纯新增 optional 无破坏 |
| enum 值域扩展(TWR primary 等) | YAGNI 不做 | 无需求证据;字段可扩展天然支持 |
| portfolioCAGR 计算逻辑改动 | 不做 | G 已保证数值;本 feature 只动语义标注 |

## 可行性

- **Technical: GO** — proto regen 链 R6-G(UploadBackup)验证可用;改动面小而清晰。
- **Economic: GO** — ~1-2h。
- **Operational: GO** — 零迁移零部署,旧 client 无感。
