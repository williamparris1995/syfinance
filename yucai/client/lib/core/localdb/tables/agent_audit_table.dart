import 'package:drift/drift.dart';

/// F71(spec FR-1,design ADR-2)durable 审计表:agent 写操作留痕。
///
/// - **仅写事件**(NFR-1):读工具调用留结构化日志(AssistantAuditLog
///   .logToolCall),不入本表 —— 写入方唯一 = `AgentAuditSinkImpl`
///   (executor 确认执行后双投);行天然 actor=agent,与表单写入可区分。
/// - **排除面**(design ADR-2/Risk):本地审计不上行不镜像 —— sync 序列化
///   白名单(envelope_codec per-row 函数)与备份镜像(LocalSnapshotExporter
///   8 模块封闭清单)均为显式注册制,本表**不注册即排除**;e2e 钉 =
///   local_snapshot_exporter_test「agent audit rows stay out of the backup
///   envelope」。
/// - 索引建重防御:迁移侧走 `_createIndexIfAbsent` 守卫(见
///   app_database.dart)—— 全链首个建索引迁移,旧迁移测试伪造旧库只
///   回拨 user_version 不清库,重放不得撞 duplicate index。
/// - 清理/保留策略 backlog(与备份保留对齐另议,spec Out of scope)。
@TableIndex(name: 'agent_audit_created_millis_idx', columns: {#createdMillis})
class AgentAudits extends Table {
  /// SQL 表名(设计钉定单数 agent_audit)。
  @override
  String get tableName => 'agent_audit';

  /// 自增主键(append-only;同毫秒行的倒序次锚)。
  IntColumn get id => integer().autoIncrement()();

  /// 写入时刻(unix 毫秒;倒序索引承载对话框 watchPage 查询面)。
  IntColumn get createdMillis => integer()();

  /// 工具名(transaction_add / transaction_update / transaction_delete)。
  TextColumn get tool => text()();

  /// 动作摘要(WriteAction.toString,ASCII;含方向/金额/账户定位)。
  TextColumn get summary => text()();

  /// true = ok(绿徽标);false = failed(红徽标,reason 必有)。
  BoolColumn get ok => boolean()();

  /// 失败原因(英文单行;ok=true 恒 null —— 写入方契约)。
  TextColumn get reason => text().nullable()();

  /// 关联实体 id(落库交易 id;失败常见 null)。
  TextColumn get entityId => text().nullable()();

  /// 幂等键(确认实例 uuid,F70 键语义):同键失败重试 = 追加新行
  /// (失败不耗键,同键异果两行留痕),不是行更新。
  TextColumn get idempotencyKey => text()();
}
