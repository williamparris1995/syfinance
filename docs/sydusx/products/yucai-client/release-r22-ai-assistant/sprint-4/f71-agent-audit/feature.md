---
title: F71 durable 审计表
keywords: agent_audit, 审计表, drift v15, AgentAuditSink, 操作记录, fail-open
---

# F71 durable 审计表

> /sydusx-brainstorming 2026-10-28 进入;analysis 同日 spec 落档(质询两决策)。R22 sprint-4 末票。

## 概述

drift v15 agent_audit 表(写事件留痕:工具/摘要/结果/实体 id/幂等键)+AgentAuditSink 双投(日志照旧+入库 fail-open)+设置卡「操作记录」只读对话框(倒序/分页/空态)。仅写事件入库;读留日志。

## Stories

- [ ] S1: 迁移+sink — drift v15 表+DAO/AgentAuditEvent+AgentAuditSink port(表写 fail-open 计数)/F70 executor 接线双投+单测(含读操作零行负测/表写失败 fail-open)。
- [ ] S2: 查看对话框 — 卡内「操作记录」行+只读对话框(倒序分页空态结果徽标,照 v21)+widget 测。
- [ ] S3: 全门+覆盖表 — 全量门+帽石(记账→表恰一行+实体关联+失败重试两行)+code-ledger。

## 非目标(Non-goals)

读操作入库(已否)/导出清理策略(backlog)/独立路由(已否)/人为写入标记(天然区分)。
