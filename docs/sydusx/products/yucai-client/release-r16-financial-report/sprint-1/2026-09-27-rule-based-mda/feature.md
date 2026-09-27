---
title: F44 rule-based-mda
keywords: [MD&A, 诊断, 建议, 规则引擎, 消费习惯, 问题诊断, 优化建议, 闲置订阅, 储蓄率, rule-based-mda]
---

# Feature — F44 规则诊断引擎 MD&A(R16 sprint-1)

> 2026-09-27 立项。release 级拍板「规则为主+预留 AI」见 [release.md](../../release.md) Decisions;输入契约=F43 ReportDocument(三票共享);导出=F45(sprint-2)。

## Description

现状:F43 已落六章节汇编报告(ReportDocument 纯快照+报告页),无诊断/建议层。目标:①规则库骨架(MdaRule 接口+Finding 结论模型:规则名/严重度/结论文本/溯源数据/建议);②规则集三类——消费习惯(类别结构/集中度/环比突增)、问题诊断(储蓄率/预算超支/负债率与到期/闲置订阅/大额异常)、优化建议(规则→建议映射,每条可解释可溯源);③报告页新增「诊断与建议」章节渲染(含空态);④AI 预留接口(LLM 叙述 port,注入缝+fake 测试,不接实现)。零 proto/server 改动。

## Stories

- [ ] S1: 规则库骨架(MdaRule 接口+Finding 模型+规则引擎执行器,输入 ReportDocument)
- [ ] S2: 消费习惯规则集(类别结构/集中度/环比突增)
- [ ] S3: 问题诊断规则集(储蓄率/预算超支/负债率/闲置订阅/大额异常)
- [ ] S4: 优化建议映射(规则→建议,可解释)
- [ ] S5: 报告页「诊断与建议」章节(渲染+空态;UI 原型走设计阶段)
- [ ] S6: AI 预留接口(narrative port+fake 测试)
- [ ] S7: 测试与门(flutter 全绿+analyze 基线+client-e2e+零 proto)

## Keywords

`MD&A` `诊断` `建议` `规则引擎` `消费习惯` `问题诊断` `优化建议` `闲置订阅` `储蓄率` `rule-based-mda`
