# Sprint 1 — R16 财务报告:汇编层+报告页+规则诊断(F43+F44)

> /sydusx-portfolio 2026-09-25 立项。brainstorm 三决策(规则为主+预留 AI / 页面+导出 / R16 先行)见 [release.md](../release.md) Decisions。

## Sprint Goal

用户可按月/年生成分章节的财务报告并应用内阅读:汇编层(多 RPC 聚合+现金流量表+ExpenseBasis 口径抽象)+章节式报告页(F43),叠加规则版 MD&A「诊断与建议」章节(F44);零 proto/server 改动,离线/guest 一致。

## Feature roster

- [ ] **feature F43** financial-report-page — 报告汇编层+财务报告页(报告模型/多 RPC 聚合/现金流量表聚合/ExpenseBasis 抽象/章节式页面) `claimed: zcode-r16-f43 2026-09-25`
- [ ] **feature F44** rule-based-mda — 规则诊断引擎 MD&A(规则库骨架+消费习惯/问题诊断/优化建议规则集+报告页章节渲染+AI 预留接口)

## status: pending
