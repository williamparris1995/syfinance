---
title: F43 financial-report-page
keywords: [财务报告, 报告, financial report, 汇编, 章节式报告, ExpenseBasis, 口径, 现金流量表, financial-report-page]
---

# Feature — F43 报告汇编层+财务报告页(R16 sprint-1)

> 2026-09-25 立项。release 级拍板见 [release.md](../../release.md) Decisions;本票=汇编层+页面+口径抽象,MD&A 规则诊断=F44(同 sprint 后续),导出=F45(sprint-2)。

## Description

现状:仅「报表分析」页(/reports,三图表交互,数据=TransactionSummary 单源),无「一份规范报告」的概念。目标(grill 后定稿,详见 [spec.md](spec.md)):①报告期(月/年)+/reports 顶栏入口+子路由报告页;②**纯本地汇编**(三态一致:guest/bound-离线/bound-在线同一报告;本地库=绑定后全量镜像),报告模型含六章节——总览/资产负债(期初期末**回放重建**+附注)/收支(环比或同比)/现金流(严格口径:现金=仅 savings,经营/投资/融资三类+勾稽)/预算执行/投资绩效(金额口径+**区间 TWR**),无数据章节自适应隐藏+总览附注披露;③ExpenseBasis 口径抽象(现金口径默认实现,待摊接入点测试钉死,R17 接入);④扩展 LocalPerformanceAssembler 支持任意报告期。零 proto/server 改动。

## Stories

- [ ] S1: 报告模型+汇编服务(纯本地三态一致;月/年期选择;FR-1/FR-2)
- [ ] S2: 时点回放服务(期初/期末账户余额+净资产重建,含持仓时点市值;FR-4)
- [ ] S3: 现金流分类器(严格口径:现金=仅 savings;经营/投资/融资三类+勾稽不变式测试;FR-5)
- [ ] S4: ExpenseBasis 口径抽象+现金口径默认实现+待摊接入点测试(FR-7)
- [ ] S5: 投资绩效区间扩展(assembler rangeStart/End+金额口径+区间 TWR;FR-6)
- [ ] S6: 章节式报告页(六章节+自适应隐藏+口径/未包含项附注;/reports 顶栏入口+子路由;FR-3;UI 原型走设计阶段)
- [ ] S7: 测试与门(flutter 全绿+analyze 基线+client-e2e+proto/server 零 diff 门;NFR-1/2/3)

## Keywords

`财务报告` `报告` `financial report` `汇编` `章节式报告` `ExpenseBasis` `口径` `现金流量表` `financial-report-page`
