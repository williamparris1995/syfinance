# Code Ledger — F43(R16 sprint-1)

> execute 进度账本(controller 维护;防压缩丢进度)。

| task | 状态 | 实施 | 评审 | fix 轮 | commit |
|---|---|---|---|---|---|
| T1 report domain 纯核 | ✅ done | ✅ 40/40 绿(修后) | 两轴:1 Important+5 Minor→R1 全修毕(debit 单边/改名/contains/ReportNote/factory/月校验) | R1 收口(4916db1c) | 910c4d16+4916db1c |
| T2 LedgerStore adapter+conformance+性能 | ✅ done | ✅ 297→316 绿,全量 2145 绿,analyze 零新增 | 两轴:0 HARD;1 Important(toLocal 时区)+2 Minor | R1 收口(03a9419f):raw 直通+镜像种子进门+孤儿/双拉注释;2 Minor 注释路线零行为改 | b1cd1697+03a9419f |
| T4 ReportAssemblyService | ✅ done | ✅ report 83 绿+全量 2149 绿(T5 在途除外),analyze 零新增 | 两轴:1 Important WRONG+1 WRONG+2 MISSING+3 JUDGEMENT | R1 收口(290d977c):预算账户级去重(月报 per-item 同构/年报 (账户,月) 去重)+附注原币口径+年报日均=自然天数+isCashAccount 单点+_performanceSection 抽取;+5 测试全 RED→GREEN | 453523be+290d977c |
| T5 bloc+页面+路由 | ✅ done | ✅ a53dac1f+d7d1fda3:report 99 绿+全量 2167 绿,analyze 446 持平,零裸色门过 | 两轴 PASS(0 HARD/Spec 零 MISSING-WRONG);MED 渲染层计算+LOW 三件 | R1 收口(d7d1fda3):name 契约五点全落+netWorthChangePct/debtRatioPct/totals factory+Equatable+Semantics;backlog=页面拆分(F45 前)/_onPhaseOf 共享 | a53dac1f+d7d1fda3 |
| T3 assembler 区间扩展 | ✅ done | ✅ 226→234 绿,全量 2117 绿 | 两轴 PASS:0 HARD/3 JUDGEMENT Minor(DRY 日归一/Long Method=未来重构);Spec 1 Minor MISSING(负值 estGain 场景→转 T2 补)1 跨任务 Important(区间→本地路由→转 T2)0 WRONG 0 越界 | 免修(两落点均入 T2) | 3f70bde0 |
| T4 ReportAssemblyService | 待 T1+T2+T3 | — | — | — | — |
| T6 门与收尾 | ✅ done | ✅ 048fee8e:e2e 15/15(新成员)+五项门全绿(2167 测/analyze 零新增/零 diff/幂等) | —(收尾任务免评审) | 金图重录=暗色(环境性,照先例;主题耦合债记 backlog) | 048fee8e |

## 裁定记录

- T1-R1-01(Important):CashExpenseBasis 按 spec/design 改 **debit 单边**(=TransactionSummary 现状语义,报告收支与 /reports 页一致是 FR-7 本意);净额口径(退款冲抵)废止,记 R17 待摊 basis 变体候选。根因=task-brief-1 与 spec 矛盾未上报(controller 失误)。
- T1-R1-02(Minor×2 不修):'savings' 魔法串(纯度约束无 proto import,注释钉死);VO 不 extend Equatable(快照无相等性需求)。
- 评审亮点(供 T4/T5 继承):勾稽 assert 前置进 classifier 早失败;测试全手算 oracle;月边界 23:59:59 语义钉死。

## 环境注记

- T3 在途时 worktree 有 holding 未提交改动+pub get 刷新的 generated_plugin_registrant(平台噪音,合并前 checkout)。
- 并行 flutter test 偶发 .dart_tool 争用:子代理重跑即可,非因果失败。
