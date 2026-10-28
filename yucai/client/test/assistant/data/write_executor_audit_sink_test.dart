// F71-T1 TDD:executor → sink 接线(spec FR-2 全场景 + NFR-1 读零行负测)。
//
// 与 F70 write_executor_impl_test 的分工:彼文件钉「日志行为等价」(构造
// 不带 sink,既有测全绿 = 等价证,本文件不改);本文件钉 F71 落表后的
// 表侧契约 —— 记账恰一行逐字段 / 失败留痕+重试两行(同键异果)/ 读操作
// 零行负测 / 表写失败 fail-open(记账照成+日志仍在+计数+1)。
//
// 评审修复轮(summary 人话单源):summary 断言改人话 note 串,且与
// appendToolOutcome 会话注入**同串**断言(单源即证 —— 同一次 execute 的
// 表行 summary == loop 注入 note,分叉即刻红);日志行 payload 断言钉
// ASCII 机器串零变(logPayload 解耦)。
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/assistant/data/agent_audit_sink.dart';
import 'package:yucai_client/assistant/data/audit_log.dart';
import 'package:yucai_client/assistant/data/tools/transactions_search_tool.dart';
import 'package:yucai_client/assistant/data/write_executor_impl.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/domain/write_executor.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/agent_audit_dao.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockTxnRemote extends Mock implements TransactionRemoteDataSource {}

class _MockAccountRemote extends Mock implements AccountRemoteDataSource {}

class _MockTxnRepo extends Mock implements TransactionRepository {}

class _FakeListTransactionsParams extends Fake
    implements ListTransactionsParams {}

class _FakeUpdateTransactionParams extends Fake
    implements UpdateTransactionParams {}

class _FakeRecordExpenseParams extends Fake implements RecordExpenseParams {}

class _FakeAuditDao extends Mock implements AgentAuditDao {}

class _FakeCompanion extends Fake implements db.AgentAuditsCompanion {}

/// 收集型 fake loop(与 F70 测试同款:只消费 appendToolOutcome)。
class _FakeLoop implements AgentLoopService {
  final List<String> appendedOutcomes = [];

  @override
  void appendToolOutcome(String note) => appendedOutcomes.add(note);

  @override
  void resetConversation() {}

  @override
  Stream<AssistantEvent> send(String userMessage) => const Stream.empty();
}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeListTransactionsParams());
    registerFallbackValue(_FakeUpdateTransactionParams());
    registerFallbackValue(_FakeRecordExpenseParams());
    registerFallbackValue(_FakeCompanion());
  });

  late db.AppDatabase database;
  late TransactionRepository txnsRepo;
  late _FakeLoop loop;
  late List<String> auditLines;
  late TransactionsSearchTool readTool;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    txnsRepo = TransactionRepositoryImpl(
      _MockTxnRemote(),
      TransactionLocalDataSource(database, BalanceLocalUpdater(database)),
      tracker,
    );
    final accountsRepo = AccountRepositoryImpl(
      _MockAccountRemote(), AccountLocalDataSource(database), tracker,
    );
    // 现金 + 餐饮科目(记账落库素材;accountsRepo 供只读工具负测)。
    for (final (id, type, category) in [
      ('acc-cash', 1, 1),
      ('acc-food', 5, 8),
    ]) {
      await database.accountDao.insertAccount(db.AccountsCompanion.insert(
        id: id,
        name: id,
        accountType: type,
        category: category,
        currencyCode: 'CNY',
        initialBalanceCents: 1000000,
        currentBalanceCents: 1000000,
        ownership: 1,
        icon: '',
        color: '',
        chartCode: '',
        isSystem: false,
        sortOrder: 0,
        institution: '',
        cardNumberTail: '',
        notes: '',
        goldProductType: '',
        status: 1,
        version: 1,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      ));
    }
    loop = _FakeLoop();
    auditLines = [];
    // 供读工具负测用的只读工具(同一 repo 面,真库)。
    readTool = TransactionsSearchTool(txnsRepo, accountsRepo);
  });

  tearDown(() => database.close());

  final addLunch = TransactionAdd(
    direction: WriteDirection.outflow,
    amountCents: 3500,
    description: '午饭',
    accountId: 'acc-cash',
    categoryId: 'acc-food',
    date: DateTime(2026, 10, 27),
  );

  /// 全链装配:真 executor + 真双投 sink(真库 dao)。
  WriteExecutorImpl executorWithSink(AgentAuditSink sink) =>
      WriteExecutorImpl(txnsRepo, loop, AssistantAuditLog(log: auditLines.add),
          sink);

  test('记账留痕:表恰一行,逐字段 + 实体 id 可关联交易', () async {
    final before = DateTime.now().millisecondsSinceEpoch;
    final sink = AgentAuditSinkImpl(
        AssistantAuditLog(log: auditLines.add), database.agentAuditDao);
    final outcome =
        await executorWithSink(sink).execute(addLunch, 'key-add-audit');

    expect(outcome, isA<WriteExecuted>());
    final entityId = (outcome as WriteExecuted).entityId;
    expect(await database.agentAuditDao.count(), 1, reason: '恰一行');

    final row =
        (await database.agentAuditDao.watchPage().first).single;
    expect(row.tool, 'transaction_add');
    expect(row.summary, '已记:支出 ¥35.00 午饭',
        reason: '摘要 = 人话单源 note(executor 单点构造)');
    expect(row.summary, loop.appendedOutcomes.single,
        reason: '单源即证:表行 summary == appendToolOutcome 会话注入同串');
    expect(row.summary, contains('¥35.00'), reason: '金额段千分位同源 yuan()');
    expect(row.ok, isTrue);
    expect(row.reason, isNull);
    expect(row.entityId, entityId, reason: '幂等关联键 = 落库交易 id');
    expect(row.idempotencyKey, 'key-add-audit');
    expect(row.createdMillis,
        allOf(greaterThanOrEqualTo(before), lessThanOrEqualTo(
            DateTime.now().millisecondsSinceEpoch + 1)),
        reason: '留痕时刻 = 执行时刻毫秒');
    // 日志行零变:payload = ASCII 机器串(WriteAction.toString 自过滤),
    // 人话 summary 不入日志行(summary/logPayload 两投各取各源)。
    expect(
      auditLines.where((l) =>
          l.contains('assistant write tool=transaction_add') &&
          l.contains('status=ok') &&
          l.contains('payload=${addLunch.toString()}')),
      hasLength(1),
      reason: '日志 payload = F70 机器串逐字节零变(logPayload 解耦)',
    );
    expect(auditLines.every((l) => !l.contains('已记')),
        isTrue, reason: '人话 note 不进日志串(项目门禁)');

    // 实体 id 关联:交易真在库(对应交易可由实体 id 反查)。
    final linked = await (database.select(database.transactions)
          ..where((t) => t.id.equals(entityId)))
        .get();
    expect(linked, hasLength(1));
  });

  test('失败也留痕:failed+原因;同键重试成功后再加一行 ok(同键异果两行)',
      () async {
    final mock = _MockTxnRepo();
    when(() => mock.recordExpense(any()))
        .thenAnswer((_) async => const dz.Left(ServerFailure('stale')));
    final sink = AgentAuditSinkImpl(
        AssistantAuditLog(log: auditLines.add), database.agentAuditDao);

    // 第一次:mock 版 executor(失败路径)。
    final failing = WriteExecutorImpl(
      mock,
      loop,
      AssistantAuditLog(log: auditLines.add),
      sink,
    );
    final first = await failing.execute(addLunch, 'key-vc-audit');
    expect(first, isA<WriteFailed>());
    expect((first as WriteFailed).reason, 'ServerFailure',
        reason: 'repo Left → runtimeType 单行原因(F70 口径照旧)');

    // 第二次:重试同键,真库 executor(成功路径)。
    final second =
        await executorWithSink(sink).execute(addLunch, 'key-vc-audit');
    expect(second, isA<WriteExecuted>());

    expect(await database.agentAuditDao.count(), 2, reason: '同键两行留痕');
    final rows = await database.agentAuditDao.watchPage().first;
    // 倒序:后写的 ok 在前。
    expect(rows.first.ok, isTrue);
    expect(rows.first.entityId, (second as WriteExecuted).entityId);
    expect(rows.first.summary, '已记:支出 ¥35.00 午饭');
    expect(rows.last.ok, isFalse);
    expect(rows.last.reason, 'ServerFailure');
    expect(rows.last.entityId, isNull);
    // Add 的 note 纯 action 派生 —— 失败行摘要 = 尝试动作人话串(与重试
    // ok 行同串,对话框同键重试对可辨识);会话注入仅成功一次。
    expect(rows.last.summary, '已记:支出 ¥35.00 午饭',
        reason: '失败行摘要 = 人话尝试串(Add 素材齐备,不回退机器串)');
    expect(loop.appendedOutcomes, ['已记:支出 ¥35.00 午饭'],
        reason: '失败零注入,成功恰一次注入(与表行同串)');
    expect(rows.map((r) => r.idempotencyKey).toSet(), {'key-vc-audit'},
        reason: '同键异果:两行同一幂等键');
  });

  test('读操作零行负测(NFR-1):跑一次只读工具,表零行', () async {
    // 写一笔(非零基线对照:表当前 1 行)+ 读工具跑一轮。
    final sink = AgentAuditSinkImpl(
        AssistantAuditLog(log: auditLines.add), database.agentAuditDao);
    await executorWithSink(sink).execute(addLunch, 'key-seed-read');
    expect(await database.agentAuditDao.count(), 1);

    final result = await readTool.execute(const {});

    expect(result, isA<ToolData>(), reason: '读工具正常出数');
    expect(await database.agentAuditDao.count(), 1,
        reason: '读调用零入库(NFR-1:读留日志,表只收写事件)');
  });

  test('表写失败 fail-open:记账照成 + 日志仍在 + 计数 +1', () async {
    final dao = _FakeAuditDao();
    when(() => dao.insertEvent(any())).thenThrow(StateError('disk'));
    final sink = AgentAuditSinkImpl(AssistantAuditLog(log: auditLines.add), dao);

    final outcome =
        await executorWithSink(sink).execute(addLunch, 'key-failopen');

    // 记账照常成功(主链路不被审计拖垮)。
    expect(outcome, isA<WriteExecuted>());
    final entityId = (outcome as WriteExecuted).entityId;
    final rows = await (database.select(database.transactions)
          ..where((t) => t.id.equals(entityId)))
        .get();
    expect(rows, hasLength(1), reason: '交易真落库');
    // 日志行仍在 + 无用户可见错误(record 不上抛)。
    expect(
      auditLines.where((l) =>
          l.contains('assistant write tool=transaction_add') &&
          l.contains('status=ok')),
      hasLength(1),
    );
    expect(loop.appendedOutcomes, hasLength(1), reason: '会话注入照常');
    // 计数 +1。
    expect(sink.insertFailures, 1);
  });
}
