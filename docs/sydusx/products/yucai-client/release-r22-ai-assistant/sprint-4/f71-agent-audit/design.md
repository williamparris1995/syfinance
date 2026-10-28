# Design: F71 durable 审计表

prototype: v21 —— 用户拍板 2026-10-28(三态整体确认:入口行/主态列表含失败重试对/空态;CURRENT→v21)

## Context

- spec:[spec.md](spec.md)(两拍板:仅写事件/卡内对话框);F70 executor logWrite 单点=sink 接线位;drift 现 v14。
- 家法:迁移照 v13/v14 先例;DAO/表照 core/localdb 既有;对话框照仓内 AlertDialog 只读先例。

## Decisions(ADRs)

- **ADR-1 sink 双投单点** — AgentAuditSink port{record(AgentAuditEvent)};实现=AssistantAuditLog(照旧)+AgentAuditDao.insert(**try/catch fail-open**,静默 debugPrint 计数);F70 executor 的 logWrite 调用点改调 sink(日志行为零变)。
- **ADR-2 表结构** — agent_audit(id 自增 pk/createdMillis/工具名/summary/ok/失败原因?/entityId?/idempotencyKey);索引:createdMillis 倒序查询;**不进 sync**(本地审计,不上行;表不参与备份镜像——备份对齐 backlog 与清理策略一并议)。
- **ADR-3 查询面** — AgentAuditDao.watchPage({limit,offset})+count();对话框分页 20/页「加载更多」式(免页码复杂)。
- **ADR-4 UI=卡内行+只读对话框** — 「操作记录」行(带条数 badge)→AlertDialog 内列表(时间/工具 chip/摘要/结果徽标 ok 绿|failed 红);空态文案;无编辑删除;照 v21。

## HLD

```
lib/core/localdb/ tables/agent_audit_table.dart + daos/agent_audit_dao.dart(v15 迁移)
lib/assistant/domain/ agent_audit_event.dart(值类型,F70 注释预留实体化)
lib/assistant/data/ agent_audit_sink.dart(port+双投 impl,DI)
  write_executor_impl.dart logWrite 位改调 sink
lib/assistant/presentation/widgets/ agent_audit_dialog.dart + 卡内入口行(model_management_card 挂)
```

## LLD

- 迁移:Migrator v15 createTable+索引;schemaVersion 15;v14→v15 无数据变换。
- AgentAuditEvent{tool,summary,ok,reason?,entityId?,idempotencyKey,createdAt};toString ASCII。
- fail-open:insert 异常 catch→debugPrint('agent audit insert failed: <type>')+计数器(诊断口,不上抛)。
- 对话框:FutureBuilder watchPage;「加载更多」append;条数 badge=dao.count()。

## Risks / Trade-offs

- [表膨胀(长期)] — 低频写;清理策略 backlog(与备份保留对齐)。
- [sync 镜像排除遗漏] — 表注册进 AppDatabase 但不进 sync 序列化白名单;e2e 回归钉(备份往返不含审计=既有 NFR 镜像测试模式)。
- [fail-open 吞错] — debugPrint+计数;诊断时可见。

## Migration Plan

v14→v15 纯增量;回滚=表 DROP(数据可弃)。sync/备份零改动(排除面)。

## Open Questions

- v21 对话框形态拍板(用户)。
