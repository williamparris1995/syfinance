# Task Brief T1 — drift v15 迁移 + AgentAuditSink 双投

- worktree `.claude/worktrees/r22-f71`(分支 feature/r22-f71)。TDD;不碰 server/F46;**drift schema 迁移与表注册豁免**;F70 write_executor_impl 的 logWrite 调用位改调 sink 豁免(日志行为零变)。
- 必读:design.md(ADR-1/2/3,LLD)+spec FR-1/FR-2 全场景;`lib/core/localdb/`(app_database.dart schemaVersion 现值确认[v14?]与迁移家法/tables+daos 先例);F70 的 `write_executor_impl.dart` logWrite 位与 `audit_log.dart`。
- 任务:
  1. **drift v15**:`tables/agent_audit_table.dart`(id pk 自增/createdMillis/工具名/summary/ok/失败原因 nullable/entityId nullable/idempotencyKey)+`daos/agent_audit_dao.dart`(insert/watchPage{limit,offset} 倒序/count);schemaVersion→15+Migrator createTable+createdMillis 索引;**表不进 sync 序列化白名单与备份镜像**(照既有排除面先例,grep backup/sync 白名单确认注册方式;备份往返不含审计的既有 NFR 镜像测试模式若在,顺手扩一条)。
  2. **AgentAuditEvent 值类型**(`lib/assistant/domain/agent_audit_event.dart`,F70 注释预留实体化;toString 全 ASCII)。
  3. **AgentAuditSink**(`lib/assistant/data/agent_audit_sink.dart`):abstract port{Future<void> record(AgentAuditEvent)};impl=AssistantAuditLog(照旧 English 行)+dao.insert **try/catch fail-open**(静默 debugPrint ASCII+失败计数 getter);DI 注册(dao 依赖注入缝,单测 fake)。
  4. **executor 接线**:logWrite 调用位改调 sink.record(构造扩 sink 缝;日志输出零变化——sink 内先日志后入库)。
  5. 单测:迁移幂等(v14 库升 v15 零丢)/记账后表恰一行逐字段/失败留痕 failed+重试后两行(同键异果)/**读操作零行负测**(跑一次只读工具后表零行)/表写失败 fail-open(记账照成+日志仍在+计数+1)/count+watchPage 倒序分页。
- 验证门:`flutter test test/assistant/` 绿/analyze 零新增(466)/server diff 空。commit `feat(assistant): F71-T1 审计表迁移+sink 双投`。汇报:文件清单+测试数+备份/sync 排除面核证+commit hash。
