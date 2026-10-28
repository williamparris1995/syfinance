// F71-T3 审计帽石集成测:真库+真 executor+真双投 sink(照 F70-T4
// write_pipeline_integration_test 装配范式 —— 脚本化 LlmStreamClient + 真
// 三写工具 registry + 真 AgentLoopServiceImpl + 真 AssistantPanelBloc + 真
// WriteExecutorImpl;与 F70 帽石的唯一差异 = executor 构造缝注入
// AgentAuditSinkImpl(真库 agentAuditDao,即 DI injection 1m 的生产装配
// 形状;F70 帽石构造不带 sink = 缺省回退纯日志,两文件互不扰动)。
//
// 审计面 = F70 写链语义在 agent_audit 表的投影,五断言链:
//   ① 记账全链(口述→tool_call 分片→pending 卡→确认前表零行)→ 确认后
//      agent_audit 恰一行逐字段(tool/summary=WriteAction 全文/ok/reason
//      null/entityId/idempotencyKey=卡键/createdMillis=执行时刻)+ 实体
//      id 与交易可关联查询回(真库 transactions 反查命中);同键二次确认
//      仍一行(F70 幂等集在审计面 = 零二次留痕)。
//   ② 改/删各一行:两轮全链后表恰两行(transaction_update/delete 各恰一
//      ok 行);update 行实体反查命中(原位 version+1),delete 行实体已
//      不在库(留痕即追责面 —— 表是删除后唯一回溯点)。
//   ③ 失败重试同键两行:提案后手删目标(真管道)→ 确认 transactionNotFound
//      failed 行(entityId null)→ 同 id 还原 → RetryWriteRequested 同键
//      → ok 行(失败不耗键,同键异果追加新行非行更新,spec「失败也留痕」
//      场景)。
//   ④ 取消零行:pending 卡 cancelled → 表零行(F70 取消语义在审计面 =
//      执行器不可达零留痕);取消后补确认仍零行(卡态守卫拒)。
//   ⑤ 对话框数据源互证(T2 对话框读面):watchPage(20/页倒序)与直查表
//      (select agent_audit,经 DAO 外的原始 select —— 与 DAO 实现独立)
//      逐行同一;count() 同值;limit+offset 窗口平铺 = 全序列(对话框
//      所见即表所存)。
// 表断言全部直查(AgentAuditDao 读面 + 原始 select 双路),不 import sink
// /executor 结果对象 —— 与执行面(bloc 消息/交易表)独立互证。
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/assistant/data/agent_audit_sink.dart';
import 'package:yucai_client/assistant/data/agent_loop_impl.dart';
import 'package:yucai_client/assistant/data/audit_log.dart';
import 'package:yucai_client/assistant/data/tools/transaction_add_tool.dart';
import 'package:yucai_client/assistant/data/tools/transaction_delete_tool.dart';
import 'package:yucai_client/assistant/data/tools/transaction_update_tool.dart';
import 'package:yucai_client/assistant/data/write_executor_impl.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/domain/tool_registry.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/presentation/assistant_panel/assistant_panel_bloc.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart'
    show RecordExpenseParams;

class _MockAccountRemote extends Mock implements AccountRemoteDataSource {}

class _MockTxnRemote extends Mock implements TransactionRemoteDataSource {}

/// 就绪配置(与 write_pipeline 帽石同款)。
const _readyConfig = AssistantConfig(
  enabled: true,
  model: 'qwen3:latest',
);

/// 脚本化 LlmStreamClient(帽石范式):每次 chat 依序消费一项
/// (List<LlmChunk> 回放),记录全部请求;零真实网络。
class _ScriptedLlmClient implements LlmStreamClient {
  _ScriptedLlmClient(this._rounds);

  final List<List<LlmChunk>> _rounds;
  final List<LlmChatRequest> requests = [];

  @override
  Stream<LlmChunk> chat(LlmChatRequest req) async* {
    requests.add(req);
    yield* Stream.fromIterable(_rounds[requests.length - 1]);
  }
}

/// 全链装配套件:bloc 持真 loop/真 executor(同 loop/同 audit/同 sink 实例
/// —— 镜像 DI 单例装配);sink = 真双投 impl(真库 dao)。
class _Harness {
  _Harness(this.bloc, this.llm, this.loop, this.sink);

  final AssistantPanelBloc bloc;
  final _ScriptedLlmClient llm;
  final AgentLoopServiceImpl loop;
  final AgentAuditSinkImpl sink;

  /// 现取唯一确认卡(提案收口后的稳定态;pending/failed/confirmed 通用)。
  WriteApprovalMsg get card => bloc.state.messages
      .whereType<WriteApprovalMsg>()
      .reduce((a, b) => b);
}

/// 现取唯一 pending 确认卡。
WriteApprovalMsg pendingCardOf(AssistantPanelBloc bloc) {
  final pending = bloc.state.messages
      .whereType<WriteApprovalMsg>()
      .where((c) => c.status == WriteApprovalStatus.pending)
      .toList();
  expect(pending, hasLength(1), reason: '同刻单卡,恰一张 pending');
  return pending.single;
}

const _cashInitialCents = 1000000;

/// add 提案轮 chunks(与 write_pipeline 帽石同款:args 分片拆两段钉流式
/// 拼装)。
List<LlmChunk> addProposalRound(String callId) => [
      const TextChunk('好的,我来记这笔。'),
      ToolCallDelta(0, id: callId, name: 'transaction_add'),
      const ToolCallDelta(
          0, argsDelta: '{"direction":"out","amount":35,"description":"午饭",'),
      const ToolCallDelta(
          0, argsDelta: '"account":"现金","category":"餐饮","date":"2026-10-27"}'),
      const Finish('tool_calls'),
    ];

void main() {
  late db.AppDatabase database;
  late List<String> auditLines;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    auditLines = [];

    Future<void> seedAccount(String id, String name,
        {required int type, required int category, int balance = 0}) async {
      await database.accountDao.insertAccount(db.AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: type,
        category: category,
        currencyCode: 'CNY',
        initialBalanceCents: balance,
        currentBalanceCents: balance,
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

    // 账户口径与 write_pipeline 帽石同款(asset=1/expense=5/income=4)。
    await seedAccount('acc-cash', '现金',
        type: 1, category: 1, balance: _cashInitialCents);
    await seedAccount('acc-card', '招行信用卡', type: 2, category: 2);
    await seedAccount('acc-food', '餐饮', type: 5, category: 8);
    await seedAccount('acc-transport', '交通', type: 5, category: 8);
    await seedAccount('acc-salary', '工资', type: 4, category: 8);
    await seedAccount('acc-bonus', '奖金', type: 4, category: 8);
  });

  tearDown(() => database.close());

  /// 照 DI injection 1m 生产装配手工组装(不跑 getIt):真三写工具
  /// registry → 真 AgentLoopServiceImpl → 真双投 sink(真库 dao)→ 真
  /// WriteExecutorImpl(4 参构造,sink 缝注入)→ 真 AssistantPanelBloc。
  _Harness makeHarness(_ScriptedLlmClient llm) {
    final tracker = SessionModeTracker()..isGuest = true;
    final txnsRepo = TransactionRepositoryImpl(
      _MockTxnRemote(),
      TransactionLocalDataSource(database, BalanceLocalUpdater(database)),
      tracker,
    );
    final accountsRepo = AccountRepositoryImpl(
      _MockAccountRemote(),
      AccountLocalDataSource(database),
      tracker,
    );
    final audit = AssistantAuditLog(log: auditLines.add);
    final sink = AgentAuditSinkImpl(audit, database.agentAuditDao);
    final registry = AssistantToolRegistry()
      ..register(TransactionAddTool(accountsRepo, () => DateTime(2026, 10, 27)))
      ..register(TransactionUpdateTool(txnsRepo, accountsRepo))
      ..register(TransactionDeleteTool(txnsRepo, accountsRepo));
    final loop =
        AgentLoopServiceImpl(llm, registry, audit, () => _readyConfig);
    final executor = WriteExecutorImpl(txnsRepo, loop, audit, sink);
    final bloc = AssistantPanelBloc(
      loop: loop,
      config: ValueNotifier(_readyConfig),
      modelState: ValueNotifier(const ModelReady()),
      engineState: ValueNotifier(
          EngineReady(Uri.parse('http://127.0.0.1:18365/v1'))),
      writeExecutor: executor,
      frameInterval: Duration.zero,
    );
    return _Harness(bloc, llm, loop, sink);
  }

  /// 夹具交易(表单同管道落库;update/delete 帽种的定位目标)。
  Future<void> seedExpense(String description, {String note = ''}) =>
      TransactionLocalDataSource(database, BalanceLocalUpdater(database))
          .recordExpense(RecordExpenseParams(
        transactionDate: DateTime(2026, 10, 5),
        expenseAccountId: 'acc-food',
        assetAccountId: 'acc-cash',
        amountCents: 3000,
        description: description,
        note: note,
      ));

  // —— 真库直查独立断言件 ——

  Future<List<db.Transaction>> allTxns() =>
      database.transactionDao.getAllTransactions();

  Future<List<db.TransactionEntry>> allEntries() =>
      database.transactionDao.getAllEntries();

  Future<int> cashBalanceCents() async => (await database.accountDao
          .getAllAccounts())
      .firstWhere((a) => a.id == 'acc-cash')
      .currentBalanceCents;

  /// 审计表读面(对话框同款 watchPage;表断言用大窗一次取全)。
  Future<List<db.AgentAudit>> auditRows() =>
      database.agentAuditDao.watchPage(limit: 100).first;

  Future<int> auditCount() => database.agentAuditDao.count();

  /// 审计表原始 select 直查(与 DAO 实现独立的双路互证)。
  Future<List<db.AgentAudit>> auditRowsByRawSelect() =>
      (database.select(database.agentAudits)
            ..orderBy([
              (t) => OrderingTerm.desc(t.createdMillis),
              (t) => OrderingTerm.desc(t.id),
            ]))
          .get();

  Future<void> pump([int ms = 60]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// ⑤ 对话框数据源互证:watchPage(对话框读面)== 原始 select 直查 ==
  /// count 同值;limit+offset 窗口平铺 = 全序列。
  Future<void> expectDialogFeedMatchesTable() async {
    final feed = await database.agentAuditDao.watchPage().first;
    final direct = await auditRowsByRawSelect();
    expect(feed.map((r) => r.id), direct.map((r) => r.id),
        reason: '对话框数据源(watchPage)与表直查逐行同一');
    expect(feed.map((r) => r.summary), direct.map((r) => r.summary));
    expect(await auditCount(), direct.length, reason: 'count 与序列同值');
    // 窗口平铺(对话框 20/页「加载更多」的取数形状):逐页拼接 = 全序列。
    final tiled = <db.AgentAudit>[];
    for (var offset = 0; offset < direct.length; offset += 20) {
      tiled.addAll(await database.agentAuditDao
          .watchPage(limit: 20, offset: offset)
          .first);
    }
    expect(tiled.map((r) => r.id), direct.map((r) => r.id),
        reason: 'limit+offset 窗口平铺 = 全序列(零漏零重)');
  }

  test('记账留痕①:确认前表零行 → 确认后恰一行逐字段 + 实体可关联查询回 → '
      '同键二次确认仍一行(幂等零二次留痕)', () async {
    final llm = _ScriptedLlmClient([
      addProposalRound('call_add_audit_1'),
      [
        const TextChunk('已生成待确认的记账提案,请在确认卡上确认。'),
        const Finish('stop'),
      ],
    ]);
    final h = makeHarness(llm);

    h.bloc.add(const SendRequested('记一笔午饭 35 块,用现金,分类餐饮'));
    await pump();

    final card = pendingCardOf(h.bloc);
    final add = card.action as TransactionAdd;
    expect(add.amountCents, 3500);

    // 确认前表零行(提案 = 零执行零留痕,FR-5 确认门在审计面)。
    expect(await auditCount(), 0, reason: '确认前 agent_audit 零行');
    expect(await auditRows(), isEmpty);

    final beforeConfirm = DateTime.now().millisecondsSinceEpoch;
    h.bloc.add(ConfirmWriteRequested(card.idempotencyKey));
    await pump();
    final afterConfirm = DateTime.now().millisecondsSinceEpoch;

    // —— 恰一行,逐字段。
    expect(await auditCount(), 1, reason: '一次确认记账 = 恰一行留痕');
    final row = (await auditRows()).single;
    expect(row.tool, 'transaction_add');
    expect(row.summary, add.toString(),
        reason: '摘要 = WriteAction 全文(入库串零改写)');
    expect(row.summary, contains('amountCents=3500'));
    expect(row.summary, contains('direction=out'));
    expect(row.ok, isTrue);
    expect(row.reason, isNull, reason: 'ok 行无失败原因');
    expect(row.idempotencyKey, card.idempotencyKey,
        reason: '幂等键 = 确认卡键(F70 键语义入列)');
    expect(row.createdMillis,
        inInclusiveRange(beforeConfirm, afterConfirm + 1),
        reason: '留痕时刻 = 执行时刻毫秒');

    // —— 实体 id 与交易可关联查询回(真库 transactions 反查命中)。
    final entityId = row.entityId;
    expect(entityId, isNotNull, reason: '成功行必携实体 id');
    final linked = await (database.select(database.transactions)
          ..where((t) => t.id.equals(entityId!)))
        .get();
    expect(linked, hasLength(1), reason: '实体 id 反查交易命中');
    expect(linked.single.description, '午饭');
    expect(linked.single.transactionDate, DateTime(2026, 10, 27));

    // —— 同键二次确认(双击/重放)→ 幂等集短路 → 表仍一行零二次留痕。
    h.bloc.add(ConfirmWriteRequested(card.idempotencyKey));
    await pump();
    expect(await auditCount(), 1, reason: '幂等集在审计面 = 零二次留痕');
    expect((await auditRows()).single.idempotencyKey, card.idempotencyKey);
    expect(h.sink.insertFailures, 0, reason: '真库入库零失败(fail-open 未触发)');
    expect(h.card.status, WriteApprovalStatus.confirmed);

    // —— ⑤ 对话框数据源互证(1 行面)。
    await expectDialogFeedMatchesTable();

    await h.bloc.close();
  });

  test('改+删各留一行②:两轮全链后表恰两行(update/delete 各恰一 ok 行;'
      'update 实体反查原位命中,delete 实体不在库=表为唯一回溯点)', () async {
    await seedExpense('美团买菜', note: '备注X');
    final seeded = (await allTxns()).single;
    final llm = _ScriptedLlmClient([
      [
        const ToolCallDelta(0, id: 'call_upd_audit', name: 'transaction_update'),
        const ToolCallDelta(0, argsDelta: '{"keyword":"美团",'),
        const ToolCallDelta(0, argsDelta: '"new_amount":40}'),
        const Finish('tool_calls'),
      ],
      [
        const TextChunk('修改提案已生成,确认后生效。'),
        const Finish('stop'),
      ],
      [
        const ToolCallDelta(0, id: 'call_del_audit', name: 'transaction_delete'),
        const ToolCallDelta(0, argsDelta: '{"keyword":'),
        const ToolCallDelta(0, argsDelta: '"美团"}'),
        const Finish('tool_calls'),
      ],
      [
        const TextChunk('删除提案已生成,确认后不可撤销。'),
        const Finish('stop'),
      ],
    ]);
    final h = makeHarness(llm);

    // —— 改一轮:确认后 +1 行(transaction_update,ok,实体反查原位)。
    h.bloc.add(const SendRequested('把美团那笔改成 40 块'));
    await pump();
    final updCard = pendingCardOf(h.bloc);
    final update = updCard.action as TransactionUpdate;
    expect(update.transactionId, seeded.id);
    expect(await auditCount(), 0, reason: '改链确认前零留痕');

    h.bloc.add(ConfirmWriteRequested(updCard.idempotencyKey));
    await pump();

    expect(await auditCount(), 1);
    final updRow = (await auditRows()).single;
    expect(updRow.tool, 'transaction_update');
    expect(updRow.summary, update.toString());
    expect(updRow.ok, isTrue);
    expect(updRow.reason, isNull);
    expect(updRow.entityId, seeded.id, reason: 'update 留痕实体 = 原位笔 id');
    expect(updRow.idempotencyKey, updCard.idempotencyKey);
    final afterUpdate = await (database.select(database.transactions)
          ..where((t) => t.id.equals(seeded.id)))
        .get();
    expect(afterUpdate, hasLength(1), reason: '实体 id 反查命中(改后原位)');
    expect(afterUpdate.single.version, seeded.version + 1);
    expect(afterUpdate.single.id, seeded.id, reason: '原位更新非删旧建新');

    // —— 删一轮:确认后再 +1 行(transaction_delete,ok,实体已不在库)。
    h.bloc.add(const SendRequested('把美团那笔删了'));
    await pump();
    final delCard = pendingCardOf(h.bloc);
    final delete = delCard.action as TransactionDelete;
    expect(delete.transactionId, seeded.id);

    h.bloc.add(ConfirmWriteRequested(delCard.idempotencyKey));
    await pump();

    // —— 表恰两行,各工具恰一,倒序(后写的 delete 在前)。
    final rows = await auditRows();
    expect(rows, hasLength(2), reason: '改+删各一行');
    expect(rows.map((r) => r.tool).toList(),
        ['transaction_delete', 'transaction_update'],
        reason: '倒序:删(后发生)在前');
    final updRow2 = rows.singleWhere((r) => r.tool == 'transaction_update');
    final delRow = rows.singleWhere((r) => r.tool == 'transaction_delete');
    expect(updRow2.id, updRow.id, reason: '改行不被删轮扰动(append-only)');
    expect(delRow.ok, isTrue);
    expect(delRow.reason, isNull);
    expect(delRow.summary, delete.toString());
    expect(delRow.entityId, seeded.id,
        reason: 'delete 留痕实体 = 被删笔 id(删除后唯一回溯点)');
    expect(delRow.idempotencyKey, delCard.idempotencyKey);
    expect(updRow.idempotencyKey, isNot(delRow.idempotencyKey),
        reason: '两轮确认卡键独立');
    expect(await allTxns(), isEmpty,
        reason: '删除后交易不在库 —— 审计表是追责唯一回溯点');
    expect(await allEntries(), isEmpty);

    // —— ⑤ 对话框数据源互证(2 行面:逐行同一 + 窗口平铺)。
    await expectDialogFeedMatchesTable();

    await h.bloc.close();
  });

  test('失败重试同键两行③:提案后实体消失 → 确认 failed(transactionNotFound)'
      ' → 同 id 还原 → 同键重试 ok(失败不耗键,同键异果两行)', () async {
    await seedExpense('美团买菜');
    final seeded = (await allTxns()).single;
    final seededEntries = await allEntries();

    final llm = _ScriptedLlmClient([
      [
        const ToolCallDelta(0, id: 'call_del_retry', name: 'transaction_delete'),
        const ToolCallDelta(0, argsDelta: '{"keyword":'),
        const ToolCallDelta(0, argsDelta: '"美团"}'),
        const Finish('tool_calls'),
      ],
      [
        const TextChunk('删除提案已生成,确认后不可撤销。'),
        const Finish('stop'),
      ],
    ]);
    final h = makeHarness(llm);

    h.bloc.add(const SendRequested('把美团那笔删了'));
    await pump();
    final card = pendingCardOf(h.bloc);
    final key = card.idempotencyKey;
    expect((card.action as TransactionDelete).transactionId, seeded.id);

    // 提案与确认之间实体被手删(真管道 delete —— 表单同款级联)。
    await TransactionLocalDataSource(database, BalanceLocalUpdater(database))
        .delete(seeded.id);
    expect(await allTxns(), isEmpty);

    h.bloc.add(ConfirmWriteRequested(key));
    await pump();

    // —— 失败留痕:一行 failed,原因在,实体 null,键在。
    expect(h.card.status, WriteApprovalStatus.failed);
    expect(h.card.failureReason, 'transactionNotFound');
    expect(await allTxns(), isEmpty);
    expect(await auditCount(), 1, reason: '失败也留痕(恰一行)');
    final failedRow = (await auditRows()).single;
    expect(failedRow.tool, 'transaction_delete');
    expect(failedRow.ok, isFalse);
    expect(failedRow.reason, 'transactionNotFound',
        reason: '失败原因入列(对话框红徽标小字源)');
    expect(failedRow.entityId, isNull, reason: '失败常见无实体');
    expect(failedRow.idempotencyKey, key);
    expect(failedRow.summary, (card.action as TransactionDelete).toString());

    // 同 id 还原(头+分录原样回插 + 余额同向回摆 —— 模拟同步还原/撤误删)。
    await database.transaction(() async {
      await database.into(database.transactions).insert(
          seeded.toCompanion(false));
      for (final e in seededEntries) {
        await database.into(database.transactionEntries)
            .insert(e.toCompanion(false));
      }
      await BalanceLocalUpdater(database).applyEntries(seededEntries, 1);
    });
    expect(await allTxns(), hasLength(1), reason: '还原后目标笔可见');

    // —— 同键重试(失败不耗键)→ 执行成功 → 第二行 ok。
    h.bloc.add(RetryWriteRequested(key));
    await pump();

    expect(h.card.status, WriteApprovalStatus.confirmed);
    expect(await allTxns(), isEmpty, reason: '重试真删(执行面互证)');
    expect(await cashBalanceCents(), _cashInitialCents,
        reason: '手删回摆+还原回摆+重试删除 = 余额归位(同管道三摆)');
    final rows = await auditRows();
    expect(rows, hasLength(2), reason: '同键两行:追加新行非行更新');
    expect(rows.map((r) => r.idempotencyKey).toSet(), {key},
        reason: '两行同一幂等键(同键异果)');
    expect(rows.first.ok, isTrue, reason: '倒序:后写的 ok 在前');
    expect(rows.first.entityId, seeded.id);
    expect(rows.first.reason, isNull);
    expect(rows.last.ok, isFalse);
    expect(rows.last.reason, 'transactionNotFound');
    expect(rows.last.entityId, isNull);

    // —— ⑤ 对话框数据源互证(2 行面)。
    await expectDialogFeedMatchesTable();

    await h.bloc.close();
  });

  test('取消零行④:pending 卡 cancelled → 表零行零交易;取消后补确认仍零行'
      '(F70 幂等/取消语义在审计面)', () async {
    final llm = _ScriptedLlmClient([
      addProposalRound('call_add_cancel'),
      [
        const TextChunk('已生成待确认的记账提案。'),
        const Finish('stop'),
      ],
    ]);
    final h = makeHarness(llm);

    h.bloc.add(const SendRequested('记一笔午饭 35 块,用现金,分类餐饮'));
    await pump();

    final card = pendingCardOf(h.bloc);
    expect(await auditCount(), 0);

    // —— 取消:执行器不可达 → 零写零留痕。
    h.bloc.add(CancelWriteRequested(card.idempotencyKey));
    await pump();

    expect(h.card.status, WriteApprovalStatus.cancelled);
    expect(await auditCount(), 0, reason: '取消零留痕(执行器不可达)');
    expect(await auditRows(), isEmpty);
    expect(await allTxns(), isEmpty, reason: '取消零落库');
    expect(auditLines.where((l) => l.contains('assistant write')), isEmpty,
        reason: '日志投照旧零行(双投同源,表零 = 日志零)');

    // —— 取消后补确认 = 卡态守卫拒,仍零行零写。
    h.bloc.add(ConfirmWriteRequested(card.idempotencyKey));
    await pump();
    expect(await auditCount(), 0, reason: 'cancelled 卡确认零留痕');
    expect(await allTxns(), isEmpty);

    // —— ⑤ 对话框数据源互证(空表面:watchPage 空 + count 0 + 直查空
    //    —— T2 对话框空态文案的判定源)。
    final feed = await database.agentAuditDao.watchPage().first;
    expect(feed, isEmpty);
    expect(await auditCount(), 0);
    expect(await auditRowsByRawSelect(), isEmpty);
    await expectDialogFeedMatchesTable();

    await h.bloc.close();
  });
}
