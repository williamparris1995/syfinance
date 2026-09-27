---
title: F43 financial-report-page
keywords: [财务报告, 报告, financial report, 汇编, 章节式报告, ExpenseBasis, 口径, 现金流量表, financial-report-page]
---

# Feature — F43 报告汇编层+财务报告页(R16 sprint-1)

> 2026-09-25 立项。release 级拍板见 [release.md](../../release.md) Decisions;本票=汇编层+页面+口径抽象,MD&A 规则诊断=F44(同 sprint 后续),导出=F45(sprint-2)。

## Description

现状:仅「报表分析」页(/reports,三图表交互,数据=TransactionSummary 单 RPC),无「一份规范报告」的概念。目标:①报告期选择(月/年)→ client 侧报告汇编服务,聚合既有 RPC(TransactionSummary / GetNetWorth / ComputeBudgetActuals / GetPortfolioPerformance / GetGoalProgressHistory / GetUpcomingPayments)成统一报告模型;②章节式财务报告页:总览 / 资产负债 / 收支 / 现金流 / 预算执行 / 投资绩效(复用 design-v2 主题与既有图表组件;现金流量表=现金类科目流入流出汇总,现无现成 RPC,client 侧聚合);③ExpenseBasis 口径抽象(接口+现金口径实现+测试钉死;待摊口径归 R17 待摊引擎接入,本票不做);④guest/离线路径与在线一致(本地优先架构既有数据源)。目标零 proto/server 改动。

## Stories

- [ ] S1: 报告汇编服务(报告模型+期选择+多 RPC 聚合+guest/离线一致)
- [ ] S2: 现金流量表聚合(现金类科目流入/流出,client 侧)
- [ ] S3: ExpenseBasis 口径抽象+现金口径实现(接口+待摊接入点测试预留)
- [ ] S4: 章节式报告页(六章节;design-v2 主题;UI 走 sydusx-prototype 出原型)
- [ ] S5: 测试与门(flutter 全绿+analyze 基线+client-e2e;零 proto 改动免 go 门)

## Keywords

`财务报告` `报告` `financial report` `汇编` `章节式报告` `ExpenseBasis` `口径` `现金流量表` `financial-report-page`
