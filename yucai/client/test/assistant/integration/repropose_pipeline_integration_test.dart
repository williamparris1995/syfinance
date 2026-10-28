// F72-T2 帽石集成测:「以此再记一笔」真链全流程(spec FR-4/NFR-1,design
// ADR-3/ADR-4;照 write_pipeline / agent_audit_pipeline 装配范式)。
//
// 真库(drift 内存)+ 真工具(TransactionAddTool,账户池在工具内部)+
// 真 executor(审计双投 sink 入 agent_audit 表)+ 真 host(**guarded getIt
// 全生产解析路径**:registry 按名取 add 工具 / inbox 总线)+ 真对话框
// (记行 onTap → getIt inbox 上抛)。四断言链分两层:
//   ① 点击历史行本身零落库(NFR-1:提案=纯解析,交易/审计/余额全零动)
//   ② 新键:pending 卡幂等键 ≠ 原确认实例键(同键重放=AlreadyExecuted
//      空转的语义对立面 —— spec 简报钉定「新键过门」)
//   ③ 全流程过门:确认 → 新交易落库逐字段(默认推导:首资产户/首科目户)
//      + 审计新行 + 原交易逐字段不动 + 余额联动;取消 → 零副作用
//   ④ 改/删行点击无事件(只读态:对话框不关、浮层不开、零上抛)
//
// **双区家法(本文件实证,记档)**:①②④ = testWidgets(UI 点击链,全程
// **零写** —— 对话框 onTap → inbox → host → bloc 提案只读,drift 假时钟
// 下稳定);③ 的确认写**不可**在 testWidgets 假时钟区跑 —— 写路径
// `_insertWithEntries` 在 drift transaction 内 `watchEntriesByTransaction
// (id).first`(QueryStream 的零长 Timer 链),fake-async 区下即便
// pump/pumpAndSettle 推进假时钟 + runAsync 喂真实事件循环均**永不完成**
// (接管收尾实测:10min 超时)—— 故 ③ 照 F70/F71 帽石范式用**纯 test()
// 真事件循环直驱 bloc**(生产形状装配:addTool=registry.findByName 同源
// repo 工具,executor 4 参构造注入真 sink)。dialog onTap → inbox 与
// host inbox→浮层开的接线由 ①②④ 的 UI 链实证,③ 从 bloc 事件面续接
// (note = 原行 summary 读表原样,= 生产「对话框行 summary 上抛」同串)。
//
// testWidgets 侧收尾家法:末尾 `_pumpDownTree`(drift markAsClosed 零长
// Timer 烧毁,agent_audit_dialog_test 同款)。
// F49 修复轮注:bloc/host 的 accounts 缝已删 —— 账户解析(默认推导取名 +
// 名称→id 消歧)全归工具内部(deriveDefaults 旗标),装配面仅剩
// addTool(repo 在工具构造注入)。
import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/assistant/data/agent_audit_sink.dart';
import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/data/agent_loop_impl.dart';
import 'package:yucai_client/assistant/data/audit_log.dart';
import 'package:yucai_client/assistant/data/tools/transaction_add_tool.dart';
import 'package:yucai_client/assistant/data/write_executor_impl.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_manager_port.dart'
    show ModelManagerPort, ModelManifest;
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/domain/tool_registry.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/domain/write_executor.dart';
import 'package:yucai_client/assistant/presentation/assistant_panel/assistant_panel_bloc.dart';
import 'package:yucai_client/assistant/presentation/widgets/agent_audit_dialog.dart';
import 'package:yucai_client/assistant/presentation/widgets/assistant_overlay_host.dart';
import 'package:yucai_client/assistant/presentation/widgets/write_approval_card.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';

class _MockAccountRemote extends Mock implements AccountRemoteDataSource {}

class _MockTxnRemote extends Mock implements TransactionRemoteDataSource {}

/// 零轮脚本 LLM(本链零 LLM 调用:再记提案不经 loop.send)。
class _IdleLlm implements LlmStreamClient {
  @override
  Stream<LlmChunk> chat(LlmChatRequest req) => const Stream.empty();
}

/// Fake AssistantSettings(就绪配置;照 agent_audit_dialog_test 范式)。
class _FakeSettings extends Fake implements AssistantSettings {
  _FakeSettings(this._notifier);
  final ValueNotifier<AssistantConfig> _notifier;

  @override
  AssistantConfig get value => _notifier.value;

  @override
  ValueListenable<AssistantConfig> get listenable => _notifier;
}

/// Fake ModelManagerPort(ready 静态)。
class _FakeModelManager implements ModelManagerPort {
  @override
  final ValueNotifier<ModelState> state = ValueNotifier(const ModelReady());

  @override
  Future<void> download() async {}

  @override
  void pause() {}

  @override
  void cancel() {}

  @override
  Future<void> delete() async {}

  @override
  Future<int> diskUsageBytes() async => 0;

  @override
  ModelManifest get manifest => const ModelManifest(
      repo: 'r', file: 'f', sha256: 's', totalBytes: 1);
}

/// Fake EngineManager:ensureReady 计数(浮层开=预热断言)。
class _FakeEngineManager implements EngineManager {
  @override
  final ValueNotifier<EngineState> state = ValueNotifier(const EngineStopped());

  int readyCalls = 0;

  @override
  Future<void> ensureReady() async => readyCalls++;

  @override
  Future<void> shutdown() async {}

  @override
  void beginActivity() {}

  @override
  void endActivity() {}
}

const _readyConfig = AssistantConfig(enabled: true, model: 'qwen3:latest');

const _cashInitialCents = 1000000;

/// 原笔确认实例键(生产 = uuid 形态;钉定值供「新键 ≠ 原键」对照)。
const _originalKey = 'f47ac10b-58cc-4372-a567-0e02b2c3original';

/// 工具时钟(③ 日期缺省断言:再记提案不带日期 → 工具「今天」)。
DateTime _toolClock() => DateTime(2026, 10, 27);

void main() {
  // —— 共享:种子账户(账户口径与 write_pipeline 帽石同款;负债户先插
  // —— 钉死默认推导的**资产优先**(首资产户 现金,而非更早插入的信用卡)。
  Future<void> seedAccounts(db.AppDatabase database) async {
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

    await seedAccount('acc-card', '招行信用卡', type: 2, category: 2);
    await seedAccount('acc-cash', '现金',
        type: 1, category: 1, balance: _cashInitialCents);
    await seedAccount('acc-food', '餐饮', type: 5, category: 8);
    await seedAccount('acc-transport', '交通', type: 5, category: 8);
    await seedAccount('acc-salary', '工资', type: 4, category: 8);
  }

  /// 原笔真路径落库(executor + 双投 sink):交易 1 笔 + 审计 1 行
  /// (key=_originalKey;summary = 人话 note 单源串)。
  Future<void> seedOriginalAdd(db.AppDatabase database) async {
    final tracker = SessionModeTracker()..isGuest = true;
    final txnsRepo = TransactionRepositoryImpl(
      _MockTxnRemote(),
      TransactionLocalDataSource(database, BalanceLocalUpdater(database)),
      tracker,
    );
    final audit = AssistantAuditLog(log: (_) {});
    final loop = AgentLoopServiceImpl(
        _IdleLlm(), AssistantToolRegistry(), audit, () => _readyConfig);
    final executor = WriteExecutorImpl(
      txnsRepo,
      loop,
      audit,
      AgentAuditSinkImpl(audit, database.agentAuditDao),
    );
    await executor.execute(
      TransactionAdd(
        direction: WriteDirection.outflow,
        amountCents: 3500,
        description: '午饭',
        accountId: 'acc-cash',
        categoryId: 'acc-food',
        date: DateTime(2026, 10, 5),
      ),
      _originalKey,
    );
  }

  Future<List<db.Transaction>> allTxns(db.AppDatabase database) =>
      database.transactionDao.getAllTransactions();

  Future<List<db.AgentAudit>> allAuditRows(db.AppDatabase database) =>
      (database.select(database.agentAudits)
            ..orderBy([(t) => OrderingTerm.desc(t.id)])
            ..limit(10))
          .get();

  Future<int> cashBalanceCents(db.AppDatabase database) async =>
      (await database.accountDao.getAllAccounts())
          .firstWhere((a) => a.id == 'acc-cash')
          .currentBalanceCents;

  // =========================================================================
  // ③ 纯 test() 真事件循环(确认写在假时钟区不可跑,见文件头「双区家法」):
  // 生产形状装配直驱 bloc —— note 读表原样(= 生产对话框行 summary 上抛)
  // → ProposeFromHistoryRequested → pending 卡新键 → 确认过门 → 新交易
  // + 审计新行 + 原笔逐字段不动 + 余额联动。照 F70/F71 帽石 makeHarness
  // 范式(bloc 事件面续接 UI 链;①②已实证 dialog→inbox→host→浮层开)。
  // =========================================================================
  group('③ 再记提案→确认过门(真链:bloc 直驱,生产形状装配)', () {
    late db.AppDatabase database;

    setUp(() async {
      database = db.AppDatabase(NativeDatabase.memory());
      await seedAccounts(database);
      await seedOriginalAdd(database);
    });

    tearDown(() => database.close());

    Future<void> pump([int ms = 60]) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    AssistantPanelBloc makeBloc() {
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
      final audit = AssistantAuditLog(log: (_) {});
      final sink = AgentAuditSinkImpl(audit, database.agentAuditDao);
      // 生产形状:host initState 的 guarded getIt 解析 = registry 按名取
      // transaction_add 工具(账户池在工具内部,bloc 零 repo 缝)。
      final registry = AssistantToolRegistry()
        ..register(TransactionAddTool(accountsRepo, _toolClock));
      final loop = AgentLoopServiceImpl(_IdleLlm(), registry, audit, () => _readyConfig);
      final executor = WriteExecutorImpl(txnsRepo, loop, audit, sink);
      final addTool =
          registry.findByName('transaction_add') as TransactionAddTool?;
      return AssistantPanelBloc(
        loop: loop,
        config: ValueNotifier(_readyConfig),
        modelState: ValueNotifier(const ModelReady()),
        engineState: ValueNotifier(
            EngineReady(Uri.parse('http://127.0.0.1:18365/v1'))),
        writeExecutor: executor,
        addTool: addTool,
        frameInterval: Duration.zero,
      );
    }

    test('note(读表原样)→ pending 卡新键+默认推导 → 零落库 → 确认 → '
        '新交易+审计新行(原笔不动+余额联动)→ 同键二次确认幂等零双写',
        () async {
      final bloc = makeBloc();
      addTearDown(bloc.close);

      final before = await allTxns(database);
      final auditBefore = await allAuditRows(database);
      expect(before, hasLength(1), reason: '夹具前提:原笔 1 笔');
      expect(auditBefore, hasLength(1));
      final original = before.single;
      // note = 原行 summary 读表原样(生产「对话框行 summary 上抛」同串)。
      final note = auditBefore.single.summary;
      expect(note, '已记:支出 ¥35.00 午饭', reason: '夹具前提:人话 note 单源');

      // —— 提案(= ①② 的 bloc 事件面):解析→默认推导→execute 消歧→
      //    pending 新键 —— 本步零落库(NFR-1;执行器不可达)。
      bloc.add(ProposeFromHistoryRequested(note));
      await pump();

      final cards = bloc.state.messages.whereType<WriteApprovalMsg>().toList();
      expect(cards, hasLength(1));
      final card = cards.single;
      expect(card.status, WriteApprovalStatus.pending);
      expect(card.idempotencyKey, isNot(equals(_originalKey)),
          reason: '② 新键:再记一笔 ≠ 同键重放(AlreadyExecuted 空转已否)');
      expect(card.sourceLabel, '来自历史记录',
          reason: 'T2-M2:真链再记提案卡携溯源行(bloc 数据面;渲染面 = ①)');
      final add = card.action as TransactionAdd;
      expect(add.amountCents, 3500);
      expect(add.description, '午饭');
      expect(add.direction, WriteDirection.outflow);
      expect(add.accountId, 'acc-cash', reason: '默认推导 = 首资产户(资产优先)');
      expect(add.categoryId, 'acc-food', reason: '默认推导 = 首支出科目户');
      expect(card.preview['account'], '现金');
      expect(card.preview['category'], '餐饮');
      // ① 点击/提案本身零落库(交易/审计/余额全零动)。
      expect(await allTxns(database), hasLength(1), reason: '提案零落库');
      expect(await allAuditRows(database), hasLength(1), reason: '提案零审计行');
      expect(await cashBalanceCents(database), _cashInitialCents - 3500,
          reason: '提案零余额变动(原笔已扣 3500)');

      // —— 确认过门(NFR-1 唯一写通道)——
      bloc.add(ConfirmWriteRequested(card.idempotencyKey));
      await pump();
      await pump();

      final txns = await allTxns(database);
      expect(txns, hasLength(2), reason: '确认后恰两笔(原笔+新笔)');
      final untouched = txns.singleWhere((t) => t.id == original.id);
      expect(untouched.version, original.version, reason: '原交易不动(version)');
      expect(untouched.description, original.description);
      final created = txns.singleWhere((t) => t.id != original.id);
      expect(created.description, '午饭');
      expect(created.transactionDate, DateTime(2026, 10, 27),
          reason: '日期缺省今天(工具时钟钉定)');
      final entries = await database.transactionDao.getAllEntries();
      final newEntries =
          entries.where((e) => e.transactionId == created.id).toList();
      expect(newEntries, hasLength(2));
      final debit = newEntries.singleWhere((e) => e.debitCents > 0);
      final credit = newEntries.singleWhere((e) => e.creditCents > 0);
      expect(debit.accountId, 'acc-food');
      expect(credit.accountId, 'acc-cash');
      expect(debit.debitCents, 3500);
      // 余额联动(表单同管道):原笔已扣 3500,确认再扣 3500。
      expect(await cashBalanceCents(database), _cashInitialCents - 7000);

      // 审计新行(ok / 新键 / 关联新实体;原行不动)。
      final auditRows = await allAuditRows(database);
      expect(auditRows, hasLength(2));
      final newAudit = auditRows.first; // id 倒序 = 新行在顶
      expect(newAudit.tool, 'transaction_add');
      expect(newAudit.ok, isTrue);
      expect(newAudit.summary, '已记:支出 ¥35.00 午饭', reason: '人话 note 单源');
      expect(newAudit.idempotencyKey, card.idempotencyKey);
      expect(newAudit.idempotencyKey, isNot(equals(_originalKey)));
      expect(newAudit.entityId, created.id);
      // 卡转 confirmed(F70 既有语义在再记链复钉)。
      final doneCard =
          bloc.state.messages.whereType<WriteApprovalMsg>().single;
      expect(doneCard.status, WriteApprovalStatus.confirmed);

      // 幂等补钉:同键二次确认 = AlreadyExecuted 空转(零二次写/零二次
      // 审计行;F70 语义在再记链的可观测面)。
      bloc.add(ConfirmWriteRequested(card.idempotencyKey));
      await pump();
      expect(await allTxns(database), hasLength(2), reason: '幂等:零二次写');
      expect(await allAuditRows(database), hasLength(2), reason: '幂等:零二次审计');
    });
  });

  // =========================================================================
  // ①②④ testWidgets(UI 点击链,全程零写;见文件头「双区家法」)。
  // =========================================================================
  group('①②④ UI 链(testWidgets:对话框→inbox→host→浮层+bloc;零写)', () {
    late db.AppDatabase database;
    late _FakeEngineManager engine;

    setUp(() async {
      database = db.AppDatabase(NativeDatabase.memory());
      engine = _FakeEngineManager();
      await seedAccounts(database);
    });

    tearDown(() async {
      await getIt.reset();
      await database.close();
    });

    /// 泄微任务隙的稳定泵(bloc 事件异步处理后再收帧)。
    Future<void> settle(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 30));
      await tester.pumpAndSettle();
    }

    /// 生产装配(guarded getIt 全解析:host 不带注入参数)。
    Future<void> pumpApp(WidgetTester tester) async {
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
      final auditLines = <String>[];
      final audit = AssistantAuditLog(log: auditLines.add);
      final registry = AssistantToolRegistry()
        ..register(TransactionAddTool(accountsRepo, _toolClock));
      final loop = AgentLoopServiceImpl(_IdleLlm(), registry, audit, () => _readyConfig);
      final executor = WriteExecutorImpl(
        txnsRepo,
        loop,
        audit,
        AgentAuditSinkImpl(audit, database.agentAuditDao),
      );
      getIt
        ..registerSingleton<AgentLoopService>(loop)
        ..registerSingleton<AssistantSettings>(
            _FakeSettings(ValueNotifier(_readyConfig)))
        ..registerSingleton<ModelManagerPort>(_FakeModelManager())
        ..registerSingleton<EngineManager>(engine)
        ..registerSingleton<WriteExecutor>(executor)
        ..registerSingleton<AssistantToolRegistry>(registry)
        ..registerSingleton<AssistantReproposeInbox>(AssistantReproposeInbox());
      // host 内建 bloc(不带注入参数 —— guarded getIt 全生产解析);断言全走
      // UI/DB 可观测面,不直驱 bloc。

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              Builder(
                builder: (context) => TextButton(
                  key: const ValueKey('openAuditDialog'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => AgentAuditDialog(dao: database.agentAuditDao),
                  ),
                  child: const Text('打开审计'),
                ),
              ),
              const Expanded(
                  child: AssistantOverlayHost(frameInterval: Duration.zero)),
            ],
          ),
        ),
      ));
      await settle(tester);
    }

    /// 把面板消息列表内的目标滚到可点(空会话首卡不触发 _MessageList 自动
    /// 滚底的既有 quirk —— 测试自拖至 hitTestable)。
    Future<void> revealInPanel(WidgetTester tester, Key key) async {
      final list = find
          .descendant(
            of: find.byKey(const ValueKey('assistantPanel')),
            matching: find.byType(ListView),
          )
          .first;
      for (var i = 0;
          i < 12 && find.byKey(key).hitTestable().evaluate().isEmpty;
          i++) {
        await tester.drag(list, const Offset(0, -60));
        await tester.pump();
      }
      expect(find.byKey(key).hitTestable(), findsOneWidget,
          reason: '按钮应已滚入面板视口');
    }

    /// 卸树 + 推进假时钟烧掉 drift markAsClosed 零长 Timer(dialog 测同款)。
    Future<void> pumpDownTree(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 16));
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.tap(find.byKey(const ValueKey('openAuditDialog')));
      await settle(tester);
    }

    testWidgets('①② 点历史行:对话框关+浮层开(预热)→ pending 卡新键预填'
        '(默认推导)→ 点击本身零落库', (tester) async {
      await tester.runAsync(() async {
        await seedOriginalAdd(database);
      });
      expect((await allTxns(database)), hasLength(1), reason: '夹具前提:原笔 1 笔');
      expect((await allAuditRows(database)), hasLength(1));
      await pumpApp(tester);
      await openDialog(tester);
      expect(find.text('AI 助手 · 操作记录'), findsOneWidget);
      expect(find.text('已记:支出 ¥35.00 午饭'), findsOneWidget);

      // —— 点历史行(dialog onTap → inbox → host → bloc)——
      await tester.tap(find.text('以此再记一笔 ›'));
      await settle(tester);

      // 对话框关 + 浮层开(ADR-4「若未开则 host 打开」+ 打开即预热)。
      expect(find.text('AI 助手 · 操作记录'), findsNothing, reason: '对话框已关');
      expect(find.byKey(const ValueKey('assistantPanel')), findsOneWidget,
          reason: '助手浮层已开');
      expect(engine.readyCalls, greaterThan(0), reason: '打开浮层即预热(ADR-1)');

      // —— ② pending 卡:新键 ≠ 原确认实例键;三要素+默认推导预填 ——
      final cardWidget =
          tester.widget<WriteApprovalCard>(find.byType(WriteApprovalCard));
      final card = cardWidget.card;
      expect(card.status, WriteApprovalStatus.pending);
      final originalKey =
          (await allAuditRows(database)).single.idempotencyKey;
      expect(card.idempotencyKey, isNot(equals(originalKey)),
          reason: '新键:再记一笔 ≠ 同键重放');
      expect(card.sourceLabel, '来自历史记录',
          reason: 'T2-M2:真链再记提案卡携溯源行');
      final add = card.action as TransactionAdd;
      expect(add.amountCents, 3500);
      expect(add.description, '午饭');
      expect(add.direction, WriteDirection.outflow);
      expect(add.accountId, 'acc-cash', reason: '默认推导 = 首资产户(资产优先)');
      expect(add.categoryId, 'acc-food', reason: '默认推导 = 首支出科目户');
      expect(card.preview['account'], '现金');
      expect(card.preview['category'], '餐饮');
      // 溯源行真链渲染:浮层内确认卡卡头小字可见(v22「记一笔(来自历史)」)。
      expect(find.text('来自历史记录'), findsOneWidget);

      // —— ① 点击本身零落库(交易/审计/余额全零动;NFR-1)——
      expect(await allTxns(database), hasLength(1), reason: '点击历史行零落库');
      expect(await allAuditRows(database), hasLength(1), reason: '零新增审计行');
      expect(await cashBalanceCents(database), _cashInitialCents - 3500,
          reason: '余额零变动(原笔已扣 3500)');
      // (确认过门落库断言 = 纯 test() 真事件循环组,文件头「双区家法」。)
      await pumpDownTree(tester);
    });

    testWidgets('取消:pending 卡取消 → 零副作用(交易/审计/余额零动)',
        (tester) async {
      await tester.runAsync(() async {
        await seedOriginalAdd(database);
      });
      await pumpApp(tester);
      await openDialog(tester);

      await tester.tap(find.text('以此再记一笔 ›'));
      await settle(tester);
      expect(find.byKey(const ValueKey('writeApprovalCard')), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('writeApprovalCancel')),
        60,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('assistantPanel')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await revealInPanel(tester, const ValueKey('writeApprovalCancel'));
      await tester.tap(find.byKey(const ValueKey('writeApprovalCancel')));
      await settle(tester);

      final cardWidget =
          tester.widget<WriteApprovalCard>(find.byType(WriteApprovalCard));
      expect(cardWidget.card.status, WriteApprovalStatus.cancelled);
      expect(await allTxns(database), hasLength(1), reason: '取消零落库');
      expect(await allAuditRows(database), hasLength(1), reason: '取消零审计行');
      expect(await cashBalanceCents(database), _cashInitialCents - 3500);
      await pumpDownTree(tester);
    });

    testWidgets('④ 改/删行只读:点击无事件(对话框不关/浮层不开/零落库)',
        (tester) async {
      await tester.runAsync(() async {
        await seedOriginalAdd(database);
      });
      // 直插改/删族审计行(改/删语义 = 只读;无需真执行)。
      await database.agentAuditDao.insertEvent(db.AgentAuditsCompanion.insert(
        createdMillis: DateTime(2026, 10, 27, 12, 0).millisecondsSinceEpoch,
        tool: 'transaction_update',
        summary: '已改:美团买菜 ¥64.00',
        ok: true,
        idempotencyKey: 'key-update-1',
      ));
      await database.agentAuditDao.insertEvent(db.AgentAuditsCompanion.insert(
        createdMillis: DateTime(2026, 10, 27, 11, 0).millisecondsSinceEpoch,
        tool: 'transaction_delete',
        summary: '已删:旧手机壳 ¥15.00',
        ok: true,
        idempotencyKey: 'key-delete-1',
      ));
      await pumpApp(tester);
      await openDialog(tester);

      await tester.tap(find.text('已改:美团买菜 ¥64.00'));
      await tester.pump();
      await tester.tap(find.text('已删:旧手机壳 ¥15.00'));
      await tester.pump();

      expect(find.text('AI 助手 · 操作记录'), findsOneWidget, reason: '对话框不关');
      expect(find.byKey(const ValueKey('assistantPanel')), findsNothing,
          reason: '浮层不开(零事件)');
      expect(find.byKey(const ValueKey('assistantFab')), findsOneWidget,
          reason: 'FAB 仍在(未开浮层)');
      expect(await allTxns(database), hasLength(1), reason: '零落库');
      await pumpDownTree(tester);
    });
  });
}
