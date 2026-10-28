/// F71(spec FR-2,design ADR-1/LLD)—— agent 写操作审计事件(值类型)。
///
/// F70 `AssistantAuditLog.logWrite` 注释预留的实体化落位:executor 确认
/// 执行后构造本事件交 `AgentAuditSink.record` 双投(日志照旧 + agent_audit
/// 入库)。字段契约 = 表列(design ADR-2)一对一:tool/summary/ok/reason?
/// /entityId?/idempotencyKey + createdAt(表侧 createdMillis);**唯一非表列
/// 字段 = [logPayload]**(日志投专用解耦缝,评审修复轮引入 —— summary 改
/// 人话单源后,ASCII 日志行零变的素材来源;见字段注)。
///
/// [Object.toString] 全 ASCII(非可打印 ASCII 剔除)—— 事件可能进日志串/
/// 调试输出,项目门禁 = 日志串无 CJK(镜像 write_action.dart / audit_log
/// .dart 的 _asciiOnly 口径)。自由文本(summary/logPayload/reason/entityId)
/// 过滤,tool/idempotencyKey 天然 ASCII(构造方契约:工具名常量 + uuid)。
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
    String? logPayload,
  })  : createdAt = createdAt ?? DateTime.now(),
        logPayload = logPayload ?? summary;

  /// 工具名(transaction_add / transaction_update / transaction_delete)。
  final String tool;

  /// 动作摘要(人话单行 note —— 与 executor appendToolOutcome 会话注入
  /// **同源单点**(评审修复 T1-M1/T2-H1 同根):「已记:支出 ¥35.00 午饭」
  /// 式,update/delete 同族「已改:」「已删:」;入库列即对话框摘要列。
  /// 现读素材缺失的失败路(notFound/异常兜底)由构造方回退机器串。
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

  /// ASCII 日志 payload(WriteAction.toString;**不入库** —— 日志投专用,
  /// F71 评审修复解耦缝):summary 改人话(CJK)后,日志行的 payload 素材
  /// 不能再取 summary,否则 F70 English/ASCII 日志行被改写(项目门禁 +
  /// F70 行为零变)。缺省 = summary(不带该参的既有构造位行为不变)。
  final String logPayload;

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
