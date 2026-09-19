---
title: F37 due-urgency
keywords: [到期, 紧迫度, 7天, 15天, 红色, 黄色, due-urgency, 排序, 债务, 债权]
---

# Feature — F37 债务/债权到期紧迫度标识(R14 sprint-2)

> 2026-09-19 用户需求。排序默认序已为「未结清在前+到期升序」(F9 既有,NFR-2),本票补视觉紧迫度。

## Description

债务/债权列表卡片的到期日无紧迫度视觉。目标:未结清债按 dueDate 分桶着色——已逾期/≤7 天=红(negative)、≤15 天=黄(warn)、其余正常;到期日文本追加「N天内到期」;排序默认保持到期升序(最近到期置顶)。共享卡片组件(DebtCardMetaKv/MetaItem 加可选色参)一次实现,债务+债权两页经 DebtViewSemantics 自动同待遇。

## Stories

- [ ] S1: domain 紧迫度分桶(debt_query.dart,纯函数+测试:已结清 none/逾期/≤7/≤15/16+ none/排序显性验证)
- [ ] S2: 卡片着色(MetaKv/MetaItem 色参+到期日三处渲染点着色+后缀)
- [ ] S3: 回归+全量门

## Keywords

`到期` `紧迫度` `due-urgency` `7天` `15天` `红色` `黄色` `排序`
