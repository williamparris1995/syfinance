# Sprint 1 — R16 财务报告:汇编层+报告页+规则诊断(F43+F44)

> /sydusx-portfolio 2026-09-25 立项。brainstorm 三决策(规则为主+预留 AI / 页面+导出 / R16 先行)见 [release.md](../release.md) Decisions。

## Sprint Goal

用户可按月/年生成分章节的财务报告并应用内阅读:汇编层(多 RPC 聚合+现金流量表+ExpenseBasis 口径抽象)+章节式报告页(F43),叠加规则版 MD&A「诊断与建议」章节(F44);零 proto/server 改动,离线/guest 一致。

## Feature roster

- [x] **feature F43** financial-report-page — 报告汇编层+财务报告页(报告模型/纯本地汇编/回放/现金流分类器/ExpenseBasis 抽象/章节式页面) ✅ done(2026-09-25,ff 合并 `5630030b`:全流程 analysis[六决策 grill]→design[ADR×7+prototype v7 变体 B,OD run 64dbf66b]→execute[T1-T6 SDD:六任务+五回合两轴评审全修毕——1 Important×3 拍平:basis debit 单边/toLocal 时区陷阱/预算同账户翻倍]→review 门[REJECT→PASS:FR-7 假 basis 替换测试补齐,sabotage RED 证据]→test 门;**门:2168 测全绿+analyze 446 零新增+client-e2e 15/15[新成员 financial_report]+proto/server 零 diff+NFR-1 计时~1s<2s**;conformance 双门[summary 收支逐项相等+budget 口径对照];金图=亮色近同图 0.16% 带状差。backlog:页面拆分[F45 前]/金图 ThemeMode 钉死/绩效 Failure 文案细分/净额 basis[R17 候选])
- [ ] **feature F44** rule-based-mda — 规则诊断引擎 MD- [ ] **feature F44** rule-based-mda — 规则诊断引擎 MD&A(规则库骨架+消费习惯/问题诊断/优化建议规则集+报告页章节渲染+AI 预留接口)A(规则库骨架+消费习惯/问题诊断/优化建议规则集+报告页章节渲染+AI 预留接口) `claimed: zcode-r16-f44 2026-09-27`

## status: pending
