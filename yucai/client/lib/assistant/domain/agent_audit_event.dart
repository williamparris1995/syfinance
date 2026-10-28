/// F71(spec FR-2,design ADR-1/LLD)—— agent 写操作审计事件(值类型)。
///
/// F70 `AssistantAuditLog.logWrite` 注释预留的实体化落位:executor 确认
/// 执行后构造本事件交 `AgentAuditSink.record` 双投(日志照旧 + agent_audit
/// 入库)。字段契约 = 表列(design ADR-2)一对一:
/// tool/summary/ok/reason?/entityId?/idempotencyKey + createdAt(表侧
/// createdMillis)。
///
/// [Object.toString] 全 ASCII(非可打印 ASCII 剔除)—— 事件可能进日志串/
/// 调试输出,项目门禁 = 日志串无 CJK(镜像 write_action.dart / audit_log
/// .dart 的 _asciiOnly 口径)。自由文本(summary/reason/entityId)过滤,
/// tool/idempotencyKey 天然 ASCII(构造方契约:工具名常量 + uuid)。
library;

/// 一次 agent 写执行留痕(不可变值对象;createdAt 缺省当前时刻)。
class AgentAuditEvent {
  AgentAuditEvent({
    required this.tool,
    required this.summary,
    required this.ok,
    this.reason,
    this.entityId,
    required this.idempotencyKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// 工具名(transaction_add / transaction_update / transaction_delete)。
  final String tool;

  /// 动作摘要(WriteAction.toString;方向/金额/账户定位,零敏感 payload)。
  final String summary;

  /// true = ok;false = failed([reason] 必有 —— 写入方契约)。
  final bool ok;

  /// 失败原因(英文单行;ok=true 时恒 null)。不进日志行(F70 行为零变),
  /// 只入库。
  final String? reason;

  /// 关联实体 id(落库交易 id;失败常见 null)。
  final String? entityId;

  /// 幂等键(确认实例 uuid,F70 键语义):失败不耗键,重试同键 = 新事件。
  final String idempotencyKey;

  /// 事件时刻(表侧落 createdMillis 毫秒;测试可注入钉定值)。
  final DateTime createdAt;

  @override
  String toString() =>
      'AgentAuditEvent(tool=${_ascii(tool)}, summary=${_ascii(summary)}, '
      'ok=$ok, reason=${_ascii(reason ?? '')}, '
      'entityId=${_ascii(entityId ?? '')}, '
      'idempotencyKey=${_ascii(idempotencyKey)}, createdAtMillis='
      '${createdAt.millisecondsSinceEpoch})';

  /// 剔除非可打印 ASCII(0x20..0x7E)—— toString 全 ASCII 门。
  static String _ascii(String value) => String.fromCharCodes(
        value.codeUnits.where((c) => c >= 0x20 && c <= 0x7E),
      );
}
