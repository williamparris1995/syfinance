# F71 code-plan

> /sydusx-execute 2026-10-28。批次:[T1]→[T2]→[T3];SDD;UI 照 prototype/CURRENT v21。

- [ ] T1 迁移+sink — drift v15 agent_audit 表+DAO(watchPage/count)/AgentAuditEvent 值类型/AgentAuditSink port+双投 impl(fail-open)/F70 executor logWrite 位改调 sink/读操作零行负测+表写失败 fail-open 测
- [ ] T2 查看对话框 — 卡内「操作记录」行(条数 badge)+agent_audit_dialog(倒序/加载更多/空态/徽标,照 v21)+widget 测
- [ ] T3 全门+覆盖表 — 全量门+帽石(记账→表恰一行+实体关联+失败重试两行+备份往返不含审计)+code-ledger
