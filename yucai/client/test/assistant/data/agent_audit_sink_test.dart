// F71-T1 TDD:AgentAuditSinkImpl 双投 + fail-open(spec FR-2,design ADR-1)。
//
// 双投:① AssistantAuditLog English/ASCII 日志行(F70 形状逐字节零变,
// 与直调 logWrite 对照)② agent_audit 入库(mock dao verify 捕获 companion
// 逐字段)。fail-open:dao 抛异常 → 不上抛 + 计数 +1 + 日志行仍在;
// 连续失败计数累积(诊断口)。
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/assistant/data/agent_audit_sink.dart';
import 'package:yucai_client/assistant/data/audit_log.dart';
import 'package:yucai_client/assistant/domain/agent_audit_event.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/agent_audit_dao.dart';

class _MockAuditDao extends Mock implements AgentAuditDao {}

class _FakeCompanion extends Fake implements db.AgentAuditsCompanion {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeCompanion()));

  test('双投:日志行与 F70 直调 logWrite 逐字节一致 + 表恰一行逐字段',
      () async {
    final database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(() => database.close());
    final sinkLines = <String>[];
    final directLines = <String>[];
    final sink = AgentAuditSinkImpl(
        AssistantAuditLog(log: sinkLines.add), database.agentAuditDao);

    final event = AgentAuditEvent(
      tool: 'transaction_add',
      summary: 'TransactionAdd(direction=out, amountCents=3500)',
      ok: true,
      entityId: 'txn-abc',
      idempotencyKey: 'key-1',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1770000000123,
          isUtc: true),
    );

    // F70 直调对照(等价证基准:同参 logWrite)。
    AssistantAuditLog(log: directLines.add).logWrite(
      tool: event.tool,
      payloadSummary: event.summary,
      entityId: event.entityId ?? '',
      ok: event.ok,
    );

    await sink.record(event);

    // ① 日志行零变(与 F70 直调逐字节相等;reason 不进日志行)。
    expect(sinkLines, hasLength(1));
    expect(sinkLines.single, directLines.single);
    expect(sinkLines.single,
        contains('assistant write tool=transaction_add status=ok'));
    // ② 入库逐字段。
    final rows = await database.agentAuditDao.watchPage().first;
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.createdMillis, 1770000000123);
    expect(row.tool, 'transaction_add');
    expect(row.summary, event.summary);
    expect(row.ok, isTrue);
    expect(row.reason, isNull);
    expect(row.entityId, 'txn-abc');
    expect(row.idempotencyKey, 'key-1');
    expect(sink.insertFailures, 0);
  });

  test('fail-open:dao 抛异常 → 不上抛 + 计数累积 + 日志行仍在',
      () async {
    final dao = _MockAuditDao();
    when(() => dao.insertEvent(any())).thenThrow(StateError('disk full'));
    final lines = <String>[];
    final sink = AgentAuditSinkImpl(AssistantAuditLog(log: lines.add), dao);

    await sink.record(AgentAuditEvent(
      tool: 'transaction_delete',
      summary: 'TransactionDelete(transactionId=txn-x)',
      ok: false,
      reason: 'transactionNotFound',
      idempotencyKey: 'key-f',
    ));

    expect(sink.insertFailures, 1, reason: '失败计数 +1');
    expect(lines, hasLength(1), reason: '日志行仍发出(先日志后入库)');
    expect(lines.single, contains('tool=transaction_delete status=error'));
    // 失败 reason 只入库不进日志行(零变口径)。
    expect(lines.single.contains('transactionNotFound'), isFalse);

    // 第二次失败累积(诊断口非熔断)。
    await sink.record(AgentAuditEvent(
      tool: 'transaction_add',
      summary: 's',
      ok: true,
      idempotencyKey: 'key-f2',
    ));
    expect(sink.insertFailures, 2);
    verify(() => dao.insertEvent(any())).called(2);
  });

  test('入库捕获 companion 逐字段(ok=false 携 reason/entityId null)',
      () async {
    final dao = _MockAuditDao();
    when(() => dao.insertEvent(any())).thenAnswer((_) async => 1);
    final sink = AgentAuditSinkImpl(
        AssistantAuditLog(log: (_) {}), dao);

    await sink.record(AgentAuditEvent(
      tool: 'transaction_update',
      summary: 'TransactionUpdate(...)',
      ok: false,
      reason: 'versionConflict',
      idempotencyKey: 'key-vc',
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(1770000099999, isUtc: true),
    ));

    final captured = verify(() => dao.insertEvent(captureAny())).captured;
    final companion = captured.single as db.AgentAuditsCompanion;
    expect(companion.createdMillis.value, 1770000099999);
    expect(companion.tool.value, 'transaction_update');
    expect(companion.ok.value, isFalse);
    expect(companion.reason.value, 'versionConflict');
    expect(companion.entityId, const Value(null),
        reason: 'null entityId → 显式 NULL(insert 语义同 absent)');
    expect(companion.idempotencyKey.value, 'key-vc');
  });
}
