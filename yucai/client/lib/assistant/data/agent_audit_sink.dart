/// F71(spec FR-2,design ADR-1)—— 审计双投 sink(单点)。
///
/// port:[AgentAuditSink.record] —— executor 确认执行后的**唯一**审计出口
/// (F70 logWrite 调用位的后继);实现双投(design LLD 顺序):
///   ① AssistantAuditLog.logWrite —— F70 English/ASCII 日志行**逐字节照旧**
///      (零变;reason 不进日志行,F70 行为不动);
///   ② AgentAuditDao.insert —— agent_audit 入库(F71 本体);**fail-open**:
///      insert 异常 catch → 静默 debugPrint('agent audit insert failed:
///      <type>')+ 失败计数([insertFailures] 诊断口),不上抛 —— 记账主链路
///      永不被审计入库拖垮(spec「表写失败不阻断」场景)。
///
/// 读工具调用**不经本 sink**(NFR-1:读留 logToolCall 日志,不入表)。
///
/// DI:1m 手工注册家法(injection.dart;dao 经 AppDatabase.agentAuditDao
/// 注入缝带入);单测以 fake dao / mocktail 注入(this._dao 为普通构造参)。
library;

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:yucai_client/assistant/data/audit_log.dart';
import 'package:yucai_client/assistant/domain/agent_audit_event.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/agent_audit_dao.dart';

/// 审计双投 port(executor 唯一消费;测试 fake 面)。
abstract class AgentAuditSink {
  /// 留痕一次写执行:先日志(F70 行为零变)后入库(fail-open)。
  Future<void> record(AgentAuditEvent event);
}

/// 生产实现:AssistantAuditLog + AgentAuditDao 双投。
class AgentAuditSinkImpl implements AgentAuditSink {
  AgentAuditSinkImpl(this._log, this._dao);

  final AssistantAuditLog _log;
  final AgentAuditDao _dao;

  int _insertFailures = 0;

  /// 入库失败计数(诊断口:fail-open 静默吞错的唯一可观测面;零失败 = 0)。
  int get insertFailures => _insertFailures;

  @override
  Future<void> record(AgentAuditEvent event) async {
    // ① 先日志:与 F70 executor 直调 logWrite 逐参一致(entityId null →
    //    空串 = F70「失败常见无实体」口径),reason 不进日志行;payload 取
    //    [AgentAuditEvent.logPayload](ASCII 机器串)而非 summary —— summary
    //    评审修复后为人话单源 note(CJK),日志行零变靠此解耦。
    _log.logWrite(
      tool: event.tool,
      payloadSummary: event.logPayload,
      entityId: event.entityId ?? '',
      ok: event.ok,
    );
    // ② 后入库:fail-open —— 任何异常静默计数,绝不上抛(design ADR-1)。
    try {
      await _dao.insertEvent(db.AgentAuditsCompanion.insert(
        createdMillis: event.createdAt.millisecondsSinceEpoch,
        tool: event.tool,
        summary: event.summary,
        ok: event.ok,
        reason: Value(event.reason),
        entityId: Value(event.entityId),
        idempotencyKey: event.idempotencyKey,
      ));
    } catch (e) {
      _insertFailures++;
      debugPrint('agent audit insert failed: ${e.runtimeType}');
    }
  }
}
