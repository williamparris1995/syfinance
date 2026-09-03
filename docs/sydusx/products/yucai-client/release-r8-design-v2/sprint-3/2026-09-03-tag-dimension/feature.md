# Feature — F8 标签维度(R8 sprint-3)

> 2026-09-03 用户拍板:补齐 F6 确认的功能缺口(标签反查+报表标签维度)。

## Description

标签模块从"只有交易→标签方向"补全为双向:①**按标签反查交易**——TagDao 增反向查询(junction 表 join),入口形态 analysis 定(标签页点标签看交易/交易列表加标签筛选);②**报表标签口径**——报表聚合支持按标签维度(分类饼图旁的标签维度/标签筛选)。注意:F6 备份链的"TransactionTags junction 不入备份契约"照实断言——若本 feature 改备份契约需同步改 FR-10 断言。

## Stories

- [ ] S1: TagDao 反向查询(标签→交易列表)
- [ ] S2: 反查 UI 入口(形态 analysis 定)
- [ ] S3: 报表标签口径(聚合维度/筛选,形态 analysis 定)
- [ ] S4: F6 回归门同步(标签链断言扩展;备份契约若变同步 FR-10)

## title

F8 标签维度(反查交易+报表标签口径)

## keywords

tag-dimension, reverse-query, tag-filter, report-by-tag, tag, F8
