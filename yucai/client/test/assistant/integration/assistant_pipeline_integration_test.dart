// F64 集成帽石测:registry + loop + 真工具 模块级组装闭环。
//
// 与 T5(agent_loop_impl_test,全 fake 工具)与 T3(tools_caliber_test,
// 工具直调无 loop)互补 —— 本文件把「真组件」按 core/di 2g 装配语义手工
// 组装(不跑 getIt,代 DI 胶水直测,收口 review 观察项):
//   内存 drift 库(T3 建库种子范式)→ 真 NetWorthSnapshotTool 经真
//   core/di NetWorthSnapshotSourceAdapter(委托 NetWorthLocalDataSource,
//   与 home 净资产大卡同源)→ 真 AssistantToolRegistry 注册三只读工具
//   → 真 AgentLoopServiceImpl + 脚本化 LlmStreamClient(T5 回放范式,
//   首轮吐 networth_snapshot tool_call 分片,次轮吐文本终答)。
//
// 断言钉死:事件序列 ToolCallStart/ToolCallEnd(true)/TextDelta/Done;
// 次轮 tool 消息里的 cents = 种子净资产逐分值(同库直查独立重算比对,
// NFR-1);审计行含 tool=networth_snapshot 且全 ASCII(FR-5)。
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/assistant/data/agent_loop_impl.dart';
import 'package:yucai_client/assistant/data/audit_log.dart';
import 'package:yucai_client/assistant/data/tools/accounts_list_tool.dart';
import 'package:yucai_client/assistant/data/tools/debts_list_tool.dart';
import 'package:yucai_client/assistant/data/tools/networth_snapshot_tool.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/base_currency_port.dart';
import 'package:yucai_client/assistant/domain/tool_registry.dart';
import 'package:yucai_client/core/di/networth_snapshot_source_adapter.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/data/debt_repository_impl.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart'
    show NetWorthLocalDataSource;
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

class _MockAccountRemote extends Mock implements AccountRemoteDataSource {}

class _MockDebtRemote extends Mock implements DebtRemoteDataSource {}

/// BaseCurrencySource 微 port 缝(生产=core/di BaseCurrencySourceAdapter
/// 委托 CurrencySettings→secure storage;secure storage 平台通道不在本测
/// 范围,固定 CNY 与库种子币种一致)。
class _FixedBaseCurrency implements BaseCurrencySource {
  @override
  Future<String> getBaseCurrency() async => 'CNY';
}

/// 就绪配置(F66-T1 收窄后:enabled + model;与 T5 同款)。
const _readyConfig = AssistantConfig(
  enabled: true,
  model: 'qwen3:latest',
);

/// 脚本化 LlmStreamClient(T5 _ScriptedLlmClient 范式):每次 chat 依序
/// 消费一项(List<LlmChunk> 回放),记录全部请求;零真实网络(NFR-4)。
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

String _describe(AssistantEvent event) => switch (event) {
      TextDelta(:final delta) => 'text:$delta',
      ToolCallStart(:final id, :final name) => 'start:$id:$name',
      ToolCallEnd(:final id, :final ok) => 'end:$id:$ok',
      // F70-T2:写提案事件(此处注册表无写工具,分支不可达 —— 穷尽性钉住)。
      WriteProposed(:final toolName) => 'proposed:$toolName',
      Done() => 'done',
      AssistantError(:final message) => 'error:$message',
    };

final _fixedNow = DateTime.utc(2026, 10, 23, 4);

void main() {
  late db.AppDatabase database;
  late AssistantToolRegistry registry;
  late List<String> auditLines;

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    auditLines = [];

    // —— 按 core/di injection.dart 2g 装配语义手工组装(不跑 getIt)——
    final tracker = SessionModeTracker()..isGuest = true;
    final accountsRepo = AccountRepositoryImpl(
      _MockAccountRemote(),
      AccountLocalDataSource(database),
      tracker,
    );
    final debtsRepo = DebtRepositoryImpl(
      _MockDebtRemote(),
      DebtLocalDataSource(
          database, TransactionLocalDataSource(database, BalanceLocalUpdater(database))),
      tracker,
    );
    registry = AssistantToolRegistry()
      ..register(NetWorthSnapshotTool(
        NetWorthSnapshotSourceAdapter(NetWorthLocalDataSource(database)),
        _FixedBaseCurrency(),
      ))
      ..register(AccountsListTool(accountsRepo, debtsRepo, () => _fixedNow))
      ..register(DebtsListTool(debtsRepo, () => _fixedNow));

    // —— T3 建库种子范式(tools_caliber_test 同款)——
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'acc-cash',
      name: '现金',
      accountType: 1,
      category: 1,
      currencyCode: 'CNY',
      initialBalanceCents: 1234567,
      currentBalanceCents: 1234567,
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
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'acc-card',
      name: '招行信用卡',
      accountType: 2,
      category: 2,
      currencyCode: 'CNY',
      initialBalanceCents: 500500,
      currentBalanceCents: 500500,
      ownership: 1,
      icon: '',
      color: '',
      chartCode: '',
      isSystem: false,
      sortOrder: 1,
      institution: '',
      cardNumberTail: '',
      notes: '',
      goldProductType: '',
      status: 1,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
      creditLimitCents: const Value(5000000),
    ));
    // 载体户:净资产负债计入,accounts_list 出局。
    await database.accountDao.insertAccount(db.AccountsCompanion.insert(
      id: 'acc-carrier',
      name: '平安卡贷载体',
      accountType: 2,
      category: 6,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      currentBalanceCents: 0,
      ownership: 1,
      icon: '',
      color: '',
      chartCode: '',
      isSystem: true,
      sortOrder: 2,
      institution: '',
      cardNumberTail: '',
      notes: '',
      goldProductType: '',
      status: 1,
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));

    Future<void> seedDebt(String id,
            {required int total,
            required int debtType,
            required String subtype,
            String? collectionAccountId}) =>
        database.debtDao.insertDebt(db.DebtsCompanion.insert(
          id: id,
          accountId: 'acc-carrier',
          counterparty: 'cp-$id',
          interestRate: 0.5,
          amortizationMethod: 1,
          startDate: DateTime.utc(2026, 8, 1),
          dueDate: DateTime.utc(2027, 8, 1),
          totalPrincipalCents: total,
          debtType: debtType,
          subtype: subtype,
          contact: '',
          contractRef: '',
          collectionAccountId: Value(collectionAccountId),
          version: 1,
          createdAt: DateTime.utc(2026, 8, 1),
          updatedAt: DateTime.utc(2026, 8, 1),
        ));

    Future<void> seedEntry(String debtId, String id, DateTime date,
            int principal, {bool paid = false}) =>
        database.debtDao.insertScheduleEntry(
            db.PaymentScheduleEntriesCompanion.insert(
          id: id,
          debtId: debtId,
          paymentDate: date,
          principalCents: principal,
          interestCents: 0,
          totalCents: principal,
          paidCents: paid ? principal : 0,
          paid: paid,
        ));

    // d1 挂卡卡贷:total 460000,e1 已还 100000 → 负债贡献 360000。
    await seedDebt('d1',
        total: 460000,
        debtType: 1,
        subtype: DebtSubtypes.cardLoan,
        collectionAccountId: 'acc-card');
    await seedEntry('d1', 'e1', DateTime.utc(2026, 8, 1), 100000, paid: true);
    await seedEntry('d1', 'e2', DateTime.utc(2026, 9, 1), 110000);
    await seedEntry('d1', 'e3', DateTime.utc(2026, 11, 1), 120000);
    await seedEntry('d1', 'e4', DateTime.utc(2026, 12, 1), 130000);

    // d2 已结清;d3 借出 —— 净资产均不计。
    await seedDebt('d2',
        total: 200000, debtType: 1, subtype: DebtSubtypes.creditLoan);
    await seedEntry('d2', 'e5', DateTime.utc(2026, 8, 1), 200000, paid: true);
    await seedDebt('d3',
        total: 50000, debtType: 2, subtype: DebtSubtypes.creditLoan);
    await seedEntry('d3', 'e6', DateTime.utc(2026, 11, 1), 50000);
  });

  tearDown(() => database.close());

  AgentLoopServiceImpl makeLoop(_ScriptedLlmClient llm) =>
      AgentLoopServiceImpl(
        llm,
        registry,
        AssistantAuditLog(log: auditLines.add),
        () => _readyConfig,
      );

  /// 两轮脚本:首轮 = 文本前导 + networth_snapshot tool_call 分片
  /// (args 空对象拆两个分片,钉流式拼装);次轮 = 文本终答。
  _ScriptedLlmClient makeScriptedLlm() => _ScriptedLlmClient([
        [
          const TextChunk('正在查询净资产。'),
          const ToolCallDelta(0, id: 'call_nw_1', name: 'networth_snapshot'),
          const ToolCallDelta(0, argsDelta: '{'),
          const ToolCallDelta(0, argsDelta: '}'),
          const Finish('tool_calls'),
        ],
        [
          const TextChunk('你的净资产为 '),
          const TextChunk('8,745.67 CNY。'),
          const Finish('stop'),
        ],
      ]);

  test('真组件组装:ToolCallStart/ToolCallEnd(true)/TextDelta/Done,'
      '次轮回填库里真值(逐分)', () async {
    final llm = makeScriptedLlm();
    final loop = makeLoop(llm);

    final events = await loop.send('我现在有多少净资产?').toList();

    // —— 事件序列(FR-3 形状,真工具执行成功)——
    expect(events.map(_describe), [
      'text:正在查询净资产。',
      'start:call_nw_1:networth_snapshot',
      'end:call_nw_1:true',
      'text:你的净资产为 ',
      'text:8,745.67 CNY。',
      'done',
    ]);
    final end = events.whereType<ToolCallEnd>().single;
    expect(end.ok, isTrue, reason: '真工具在真库上执行成功');

    // —— 首轮请求:真注册表 schema 三工具齐上,配置取值缝生效 ——
    expect(llm.requests, hasLength(2));
    expect(llm.requests.first.model, 'qwen3:latest');
    final schemaNames = llm.requests.first.toolsSchema
        .map((t) => (t['function'] as Map)['name'])
        .toSet();
    expect(schemaNames, {'networth_snapshot', 'accounts_list', 'debts_list'},
        reason: 'registry 序列化整体进入真 loop 请求(core/di 2g 装配语义)');

    // —— 次轮 tool 消息:cents = 种子净资产逐分值(同库直查独立重算)——
    final second = llm.requests.last.messages;
    expect(
      second.map((m) => m['role']),
      ['system', 'user', 'assistant', 'tool'],
    );
    final toolMsg = second[3];
    expect(toolMsg['tool_call_id'], 'call_nw_1');
    final content = toolMsg['content'] as String;
    expect(content.startsWith('<tool_data>'), isTrue, reason: 'NFR-3 定界');
    expect(content.endsWith('</tool_data>'), isTrue);
    final payload = jsonDecode(content.substring(
      '<tool_data>'.length,
      content.length - '</tool_data>'.length,
    )) as Map<String, dynamic>;

    final accountRows = await database.accountDao.getAllAccounts();
    final directAssets = accountRows
        .where((r) => r.accountType == 1)
        .fold(0, (s, r) => s + r.currentBalanceCents);
    final debtRows = await database.debtDao.watchAllDebts().first;
    var directLiabilities = 0;
    for (final d in debtRows) {
      if (d.debtType == 1) {
        final schedule = await database.debtDao.getScheduleByDebt(d.id);
        directLiabilities +=
            d.totalPrincipalCents - schedule.fold(0, (s, e) => s + e.paidCents);
      }
    }
    expect(payload['totalAssetsCents'], directAssets, reason: 'assets 逐分');
    expect(payload['totalLiabilitiesCents'], directLiabilities,
        reason: 'liabilities 逐分');
    expect(payload['netWorthCents'], directAssets - directLiabilities,
        reason: 'netWorth = assets - liabilities 逐分');
    expect(directAssets, 1234567, reason: '种子夹具自证:assets');
    expect(directLiabilities, 360000, reason: '种子夹具自证:liabilities');
    expect(payload['netWorthCents'], 874567, reason: '种子净资产 874567');
    expect(payload['currency'], 'CNY');
    expect((payload['formatted'] as Map)['netWorth'], '8,745.67');
  });

  test('审计:真管线行含 tool=networth_snapshot status=ok,全 ASCII(FR-5)',
      () async {
    final loop = makeLoop(makeScriptedLlm());

    await loop.send('我现在有多少净资产?').toList();

    expect(
      auditLines.where(
        (l) => l.contains('tool=networth_snapshot') && l.contains('status=ok'),
      ),
      hasLength(1),
      reason: '工具调用审计行(经真 registry 分发 → 真工具执行)',
    );
    expect(auditLines.where((l) => l.contains('llm host=localhost')),
        hasLength(2), reason: '两轮 LLM 请求各一行');
    expect(auditLines.where((l) => l.contains('model=qwen3:latest')),
        isNotEmpty);
    final ascii = RegExp(r'^[\x20-\x7E]*$');
    for (final line in auditLines) {
      expect(line, matches(ascii), reason: 'audit line must be ASCII: $line');
    }
  });
}
