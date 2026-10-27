// F70-T4 写链帽石集成测:真库+真三写工具 registry+脚本化 LLM+真 loop+真
// bloc+真 WriteExecutorImpl 全链闭环(照 assistant_pipeline_integration_test
// 装配范式)。
//
// 与 T1(工具直调)、T2(执行器/bloc 分测)、T3(确认卡 widget)互补 —— 本文件
// 把「口述 → LLM tool_call 分片拼装 → 真工具提案(零落库)→ loop
// WriteProposed → bloc pending 确认卡 → ConfirmWrite → executor 真写
// (TransactionRepository 表单同管道)→ 审计/幂等/上下文注入」按 core/di
// injection 2g 装配语义手工组装(不跑 getIt)一次跑通,九断言链:
//   ① 工具 ToolData(requiresApproval)→ loop WriteProposed → bloc pending 卡
//      (action 携解析后内部 id;preview 携名称摘要)
//   ② 确认前 DB 零行(真库直查)
//   ③ ConfirmWrite → executor 真写 → DB 一行逐字段(金额 cents/科目账户/
//      资产账户/note)+ 余额联动(表单同管道)
//   ④ 审计 logWrite 行(English/ASCII)
//   ⑤ loop 会话上下文含「已记:」单行(appendToolOutcome,ADR-2)
//   ⑥ 改:脚本二轮 update 提案 → diff 卡 before/after → 确认 → DB 逐分重建
//      (note 逐侧保留 —— 全分录重建语义)
//   ⑦ 删:destructive 卡 → 确认 → DB 零行(分录级联清理+余额回滚)
//   ⑧ 幂等:同 key 二次确认 → DB 笔数不变(卡态守卫;零二次写审计)
//   ⑨ 取消:卡 cancelled → DB 零写零写审计
// DB 断言全部直查 drift DAO(transactionDao/accountDao),不 import 工具结果
// 对象、不经 repo 回读 —— 与提案 payload 独立互证(NFR-1 逐分一致)。
import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
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

/// 就绪配置(与 pipeline 帽石同款)。
const _readyConfig = AssistantConfig(
  enabled: true,
  model: 'qwen3:latest',
);

/// 脚本化 LlmStreamClient(帽石范式):每次 chat 依序消费一项
/// (List<LlmChunk> 回放),记录全部请求;零真实网络(NFR-4)。
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

/// 全链装配套件:bloc 持真 loop/真 executor(同一 loop 实例 —— 确认执行
/// 结果 appendToolOutcome 进同一会话上下文,镜像 DI 单例装配)。
class _Harness {
  _Harness(this.bloc, this.llm, this.loop);

  final AssistantPanelBloc bloc;
  final _ScriptedLlmClient llm;
  final AgentLoopServiceImpl loop;

  WriteApprovalMsg get card => bloc.state.messages
      .whereType<WriteApprovalMsg>()
      .reduce((a, b) => a.status == WriteApprovalStatus.pending ? a : b);
}

/// 现取唯一 pending 确认卡(提案已收口后的稳定态)。
WriteApprovalMsg pendingCardOf(AssistantPanelBloc bloc) {
  final pending = bloc.state.messages
      .whereType<WriteApprovalMsg>()
      .where((c) => c.status == WriteApprovalStatus.pending)
      .toList();
  expect(pending, hasLength(1), reason: '同刻单卡,恰一张 pending');
  return pending.single;
}

const _cashInitialCents = 1000000;

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

    // 账户口径与 write_executor_impl_test 种子同款(asset=1/liability=2/
    // income=4/expense=5 —— proto 值域;账户即分类:expense/income 科目户
    // 与表单下拉同源)。
    await seedAccount('acc-cash', '现金',
        type: 1, category: 1, balance: _cashInitialCents);
    await seedAccount('acc-card', '招行信用卡', type: 2, category: 2);
    await seedAccount('acc-food', '餐饮', type: 5, category: 8);
    await seedAccount('acc-transport', '交通', type: 5, category: 8);
    await seedAccount('acc-salary', '工资', type: 4, category: 8);
    await seedAccount('acc-bonus', '奖金', type: 4, category: 8);
  });

  tearDown(() => database.close());

  /// 按 core/di injection 2g 装配语义手工组装(不跑 getIt):
  /// 真三写工具 registry → 真 AgentLoopServiceImpl → 真 WriteExecutorImpl
  /// (同 audit/同 loop)→ 真 AssistantPanelBloc(三状态缝全就绪)。
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
    final registry = AssistantToolRegistry()
      ..register(TransactionAddTool(accountsRepo, () => DateTime(2026, 10, 27)))
      ..register(TransactionUpdateTool(txnsRepo, accountsRepo))
      ..register(TransactionDeleteTool(txnsRepo, accountsRepo));
    final loop =
        AgentLoopServiceImpl(llm, registry, audit, () => _readyConfig);
    final executor = WriteExecutorImpl(txnsRepo, loop, audit);
    final bloc = AssistantPanelBloc(
      loop: loop,
      config: ValueNotifier(_readyConfig),
      modelState: ValueNotifier(const ModelReady()),
      engineState: ValueNotifier(
          EngineReady(Uri.parse('http://127.0.0.1:18365/v1'))),
      writeExecutor: executor,
      frameInterval: Duration.zero,
    );
    return _Harness(bloc, llm, loop);
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

  // —— 真库直查独立断言件(drift DAO,不经工具/repo)——

  Future<List<db.Transaction>> allTxns() =>
      database.transactionDao.getAllTransactions();

  Future<List<db.TransactionEntry>> allEntries() =>
      database.transactionDao.getAllEntries();

  Future<int> cashBalanceCents() async => (await database.accountDao
          .getAllAccounts())
      .firstWhere((a) => a.id == 'acc-cash')
      .currentBalanceCents;

  Future<void> pump([int ms = 60]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  /// 剥 <tool_data> 定界解 JSON(NFR-3 定界形状)。
  Map<String, dynamic> decodeToolData(String content) => jsonDecode(content
          .substring('<tool_data>'.length, content.length - '</tool_data>'.length))
      as Map<String, dynamic>;

  void expectEntryLayout(db.TransactionEntry e, String accountId,
      {int debit = 0, int credit = 0, String note = '', String? reason}) {
    expect(e.accountId, accountId, reason: reason);
    expect(e.debitCents, debit, reason: reason);
    expect(e.creditCents, credit, reason: reason);
    expect(e.note, note, reason: reason);
  }

  test('记一笔全链①②③④⑤⑧:提案卡(解析后 id+摘要)→确认前零行→确认真写'
      '逐字段→审计→已记上下文单行→同 key 二次确认笔数不变', () async {
    final llm = _ScriptedLlmClient([
      [
        const TextChunk('好的,我来记这笔。'),
        const ToolCallDelta(0, id: 'call_add_1', name: 'transaction_add'),
        const ToolCallDelta(
            0, argsDelta: '{"direction":"out","amount":35,"description":"午饭",'),
        const ToolCallDelta(
            0, argsDelta: '"account":"现金","category":"餐饮","date":"2026-10-27"}'),
        const Finish('tool_calls'),
      ],
      [
        const TextChunk('已生成待确认的记账提案,请在确认卡上确认。'),
        const Finish('stop'),
      ],
      [
        const TextChunk('记到了现金账户,分类餐饮。'),
        const Finish('stop'),
      ],
    ]);
    final h = makeHarness(llm);

    h.bloc.add(const SendRequested('记一笔午饭 35 块,用现金,分类餐饮'));
    await pump();

    // —— ① 事件链收口进 bloc:UserMsg → 前导 AssistantMsg → 工具条(ok)→
    //    pending 确认卡 → 收尾 AssistantMsg(顺序即 loop 事件序)。
    expect(h.bloc.state.sendState, PanelSendState.idle);
    expect(
      h.bloc.state.messages.map((m) => m.runtimeType).toList(),
      [UserMsg, AssistantMsg, ToolStatusMsg, WriteApprovalMsg, AssistantMsg],
      reason: 'ToolCallStart/End(true)→WriteProposed 全链事件序(bloc 消费面)',
    );
    final toolBar = h.bloc.state.messages.whereType<ToolStatusMsg>().single;
    expect(toolBar.name, 'transaction_add');
    expect(toolBar.ok, isTrue, reason: '提案工具在真库上解析成功');

    final card = pendingCardOf(h.bloc);
    expect(card.action, isA<TransactionAdd>());
    final add = card.action as TransactionAdd;
    // 解析后内部 id(名称→id 在提案时钉定;LLM 不可见)。
    expect(add.accountId, 'acc-cash', reason: '「现金」→ 资产户内部 id');
    expect(add.categoryId, 'acc-food', reason: '「餐饮」→ 科目户内部 id');
    expect(add.amountCents, 3500, reason: '口述 35 元 → cents(逐分)');
    expect(add.direction, WriteDirection.outflow);
    expect(add.description, '午饭');
    expect(add.date, DateTime(2026, 10, 27));
    // preview 名称摘要(确认卡渲染源)。
    expect(card.preview['amountYuan'], '35.00');
    expect(card.preview['account'], '现金');
    expect(card.preview['category'], '餐饮');
    expect(card.preview['date'], '2026-10-27');
    expect(card.preview['direction'], 'out');

    // —— ①' 工具轮 ToolData(requiresApproval)原样回填 LLM:次轮请求的
    //    tool 消息携 requiresApproval=true + 解析后 id(两段执行契约形状)。
    expect(llm.requests, hasLength(2), reason: '提案轮 + 收尾轮');
    expect(
      llm.requests.first.toolsSchema
          .map((t) => (t['function'] as Map)['name'])
          .toSet(),
      {'transaction_add', 'transaction_update', 'transaction_delete'},
      reason: '真 registry 三写工具 schema 整体进入真 loop 请求',
    );
    final toolMsg = llm.requests.last.messages
        .firstWhere((m) => m['role'] == 'tool');
    final payload = decodeToolData(toolMsg['content'] as String);
    expect(payload['requiresApproval'], isTrue);
    expect(payload['action'],
        {'type': 'transaction_add', 'direction': 'out', 'amountCents': 3500,
         'description': '午饭', 'accountId': 'acc-cash',
         'categoryId': 'acc-food', 'date': '2026-10-27'});

    // —— ② 确认前 DB 零行(真库直查;工具/loop/bloc 全链零写)。
    expect(await allTxns(), isEmpty, reason: '确认前交易零行(FR-5 代码门)');
    expect(await allEntries(), isEmpty, reason: '确认前分录零行');
    expect(await cashBalanceCents(), _cashInitialCents,
        reason: '确认前余额零变动');

    // —— ③ ConfirmWrite → executor 真写 → DB 一行逐字段。
    final key = card.idempotencyKey;
    h.bloc.add(ConfirmWriteRequested(key));
    await pump();

    final rows = await allTxns();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.description, '午饭');
    expect(row.transactionDate, DateTime(2026, 10, 27));
    final entries = await allEntries();
    expect(entries, hasLength(2));
    expect(entries.every((e) => e.transactionId == row.id), isTrue);
    final debit = entries.singleWhere((e) => e.debitCents > 0);
    final credit = entries.singleWhere((e) => e.creditCents > 0);
    expectEntryLayout(debit, 'acc-food', debit: 3500, note: '',
        reason: 'expense = 科目借方分录(recordExpense 表单同构)');
    expectEntryLayout(credit, 'acc-cash', credit: 3500, note: '',
        reason: '资产贷方分录');
    expect(debit.debitCents, credit.creditCents,
        reason: '借贷平衡(逐分)');
    // NFR-1 表单同管道:余额联动同源获得。
    expect(await cashBalanceCents(), _cashInitialCents - 3500,
        reason: '确认后余额联动(同管道非旁路直写)');
    expect(h.card.status, WriteApprovalStatus.confirmed);
    expect(h.bloc.state.messages,
        contains(const AssistantMsg('已记:支出 ¥35.00 午饭')),
        reason: 'bloc 本地确认消息(与 executor 注入 note 同词汇同序)');

    // —— ④ 审计 logWrite 行(English/ASCII;entity= 落库 id)。
    expect(
      auditLines.where((l) =>
          l.contains('assistant write tool=transaction_add') &&
          l.contains('status=ok') &&
          l.contains('entity=${row.id}')),
      hasLength(1),
    );
    final ascii = RegExp(r'^[\x20-\x7E]*$');
    for (final line in auditLines) {
      expect(line, matches(ascii), reason: 'audit line must be ASCII: $line');
    }

    // —— ⑤ appendToolOutcome:下一 send 的 LLM 请求上下文含「已记:」单行。
    h.bloc.add(const SendRequested('刚才那笔记到哪了?'));
    await pump();
    expect(llm.requests, hasLength(3));
    final outcomeMsgs = llm.requests.last.messages.where((m) =>
        m['role'] == 'tool' &&
        (m['content'] as String).startsWith('已记:'));
    expect(outcomeMsgs, hasLength(1), reason: '恰一条已记注入(不重复)');
    final note = outcomeMsgs.single['content'] as String;
    expect(note, '已记:支出 ¥35.00 午饭');
    expect(note.contains('\n'), isFalse, reason: '单行紧凑(上下文膨胀防线)');

    // —— ⑧ 幂等:同 key 二次确认(双击/重放)→ 卡态守卫拒,DB 笔数不变。
    h.bloc.add(ConfirmWriteRequested(key));
    await pump();
    expect(await allTxns(), hasLength(1), reason: '不产生第二笔(FR-1 幂等)');
    expect(await allEntries(), hasLength(2));
    expect(
      auditLines.where((l) => l.contains('assistant write')),
      hasLength(1),
      reason: '零二次写审计(卡态守卫在 executor 前)',
    );
    expect(h.card.status, WriteApprovalStatus.confirmed);

    await h.bloc.close();
  });

  test('改一笔全链⑥:脚本 update 提案 → diff 卡 before/after → 确认 → '
      'DB 逐分重建(note 逐侧保留)', () async {
    await seedExpense('美团买菜', note: '备注X');
    final seeded = (await allTxns()).single;
    final llm = _ScriptedLlmClient([
      [
        const ToolCallDelta(0, id: 'call_upd_1', name: 'transaction_update'),
        const ToolCallDelta(0, argsDelta: '{"keyword":"美团",'),
        const ToolCallDelta(0, argsDelta: '"new_amount":40}'),
        const Finish('tool_calls'),
      ],
      [
        const TextChunk('修改提案已生成,确认后生效。'),
        const Finish('stop'),
      ],
    ]);
    final h = makeHarness(llm);

    h.bloc.add(const SendRequested('把美团那笔改成 40 块'));
    await pump();

    // —— 提案:定位(复用只读面)+ patch;diff 卡 before/after 名称摘要。
    final card = pendingCardOf(h.bloc);
    expect(card.action, isA<TransactionUpdate>());
    final update = card.action as TransactionUpdate;
    expect(update.transactionId, seeded.id, reason: '定位到种子笔内部 id');
    expect(update.direction, WriteDirection.outflow, reason: '方向随提案钉定');
    expect(update.patch.amountCents, 4000, reason: '40 元 → cents');
    expect(card.preview['before'], isA<Map>());
    expect(card.preview['after'], isA<Map>());
    final before = Map<String, Object>.from(card.preview['before'] as Map);
    final after = Map<String, Object>.from(card.preview['after'] as Map);
    expect(before['amountYuan'], '30.00');
    expect(after['amountYuan'], '40.00');
    expect(before['description'], '美团买菜');
    expect(after['description'], '美团买菜', reason: '未改字段 before=after');
    expect(before['category'], '餐饮');
    expect(after['category'], '餐饮');
    expect(before['account'], '现金');
    expect(after['account'], '现金');

    // 确认前 DB 未变(逐分:1 笔/2 分录/各 3000/余额未动)。
    expect(await allTxns(), hasLength(1));
    final preEntries = await allEntries();
    expect(preEntries, hasLength(2));
    expect(preEntries.map((e) => e.debitCents + e.creditCents),
        everyElement(3000), reason: '确认前金额未动');
    expect(await cashBalanceCents(), _cashInitialCents - 3000);

    h.bloc.add(ConfirmWriteRequested(card.idempotencyKey));
    await pump();

    // —— DB 逐分重建:同 id、金额 3000→4000、借贷两侧、note 逐侧保留。
    final rows = await allTxns();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.id, seeded.id, reason: '原位更新非删旧建新');
    expect(row.version, seeded.version + 1, reason: '现读 optimistic version');
    expect(row.description, '美团买菜');
    expect(row.transactionDate, DateTime(2026, 10, 5), reason: '未改字段现读随包');
    final entries = await allEntries();
    expect(entries, hasLength(2));
    final debit = entries.singleWhere((e) => e.debitCents > 0);
    final credit = entries.singleWhere((e) => e.creditCents > 0);
    expectEntryLayout(debit, 'acc-food', debit: 4000, note: '备注X',
        reason: '全分录重建,note 不被全替换语义冲掉');
    expectEntryLayout(credit, 'acc-cash', credit: 4000, note: '备注X');
    expect(await cashBalanceCents(), _cashInitialCents - 4000,
        reason: '改 30→40:余额联动再扣 1,000(同管道)');
    expect(h.card.status, WriteApprovalStatus.confirmed);
    expect(h.bloc.state.messages,
        contains(const AssistantMsg('已改:美团买菜 ¥40.00')));
    expect(
      auditLines.where((l) =>
          l.contains('assistant write tool=transaction_update') &&
          l.contains('status=ok')),
      hasLength(1),
    );

    await h.bloc.close();
  });

  test('删一笔全链⑦:destructive 卡 → 确认 → DB 零行(分录级联+余额回滚)',
      () async {
    await seedExpense('美团买菜');
    final seeded = (await allTxns()).single;
    final llm = _ScriptedLlmClient([
      [
        const ToolCallDelta(0, id: 'call_del_1', name: 'transaction_delete'),
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

    // —— 提案:destructive 强提示位 + 目标摘要。
    final card = pendingCardOf(h.bloc);
    expect(card.action, isA<TransactionDelete>());
    expect((card.action as TransactionDelete).transactionId, seeded.id);
    expect(card.preview['destructive'], isTrue, reason: 'V3 红警示数据位');
    final target = Map<String, Object>.from(card.preview['target'] as Map);
    expect(target['description'], '美团买菜');
    expect(target['amountYuan'], '30.00');
    expect(target['category'], '餐饮');

    // 确认前 DB 仍在(1 行)。
    expect(await allTxns(), hasLength(1));

    h.bloc.add(ConfirmWriteRequested(card.idempotencyKey));
    await pump();

    // —— DB 零行:交易头 + 分录全清(表单同款删除管道,关联清理同源)。
    expect(await allTxns(), isEmpty, reason: '交易头零行(FR-3)');
    expect(await allEntries(), isEmpty, reason: '分录级联清理零行');
    expect(await cashBalanceCents(), _cashInitialCents,
        reason: '删除同管道余额回滚(同管道非旁路)');
    expect(h.card.status, WriteApprovalStatus.confirmed);
    expect(h.bloc.state.messages,
        contains(const AssistantMsg('已删:美团买菜 ¥30.00')));
    expect(
      auditLines.where((l) =>
          l.contains('assistant write tool=transaction_delete') &&
          l.contains('status=ok') &&
          l.contains('entity=${seeded.id}')),
      hasLength(1),
    );

    await h.bloc.close();
  });

  test('取消⑨:pending 卡 cancelled → DB 零写零写审计', () async {
    final llm = _ScriptedLlmClient([
      [
        const ToolCallDelta(0, id: 'call_add_2', name: 'transaction_add'),
        const ToolCallDelta(
            0, argsDelta: '{"direction":"out","amount":35,"description":"午饭",'),
        const ToolCallDelta(
            0, argsDelta: '"account":"现金","category":"餐饮","date":"2026-10-27"}'),
        const Finish('tool_calls'),
      ],
      [
        const TextChunk('已生成待确认的记账提案。'),
        const Finish('stop'),
      ],
    ]);
    final h = makeHarness(llm);

    h.bloc.add(const SendRequested('记一笔午饭 35 块,用现金,分类餐饮'));
    await pump();

    final card = pendingCardOf(h.bloc);
    expect(card.action, isA<TransactionAdd>());

    // —— ⑨ 取消:卡转 cancelled,零写(交易/分录/余额/审计全零)。
    h.bloc.add(CancelWriteRequested(card.idempotencyKey));
    await pump();

    expect(h.bloc.state.messages.whereType<WriteApprovalMsg>().single.status,
        WriteApprovalStatus.cancelled);
    expect(await allTxns(), isEmpty, reason: '取消零落库');
    expect(await allEntries(), isEmpty);
    expect(await cashBalanceCents(), _cashInitialCents);
    expect(auditLines.where((l) => l.contains('assistant write')), isEmpty,
        reason: '取消零写审计行(执行器不可达)');

    // 取消后确认 = 守卫拒(代码门:cancelled 卡不可再确认)。
    h.bloc.add(ConfirmWriteRequested(card.idempotencyKey));
    await pump();
    expect(await allTxns(), isEmpty, reason: 'cancelled 卡确认零写');

    await h.bloc.close();
  });
}
