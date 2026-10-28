// F72-T2 TDD:note_parser(spec FR-4,design ADR-3)—— 审计「已记:」族
// 摘要 → 记一笔三要素(方向/金额/描述)的确定性解析。
//
// **成对往返测(格式漂移即红,design Risk 钉死)**:生成侧不走手写样例 ——
// 真跑 [WriteExecutorImpl](_writeNote 单点构造)在真库上执行 TransactionAdd,
// 从 fake loop 的 appendToolOutcome 捕获真实 note,再 parse 回来逐字段相等;
// _writeNote 格式任何漂移(词序/分隔/金额格式)→ parse null/字段不符 → 红。
//
// 畸形串 → null:改/删族(ADR-3「改/删行零解析」)、无金额、未知方向词、
// 零额、垃圾前缀、失败行 ASCII 机器串回退(summary 人话缺失时审计行的
// 实际形态)—— 上游(bloc)以 null 转 ErrorMsg,零卡零写。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/assistant/data/audit_log.dart';
import 'package:yucai_client/assistant/data/note_parser.dart';
import 'package:yucai_client/assistant/data/write_executor_impl.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/domain/write_executor.dart'
    show WriteExecuted;
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';

class _MockTxnRemote extends Mock implements TransactionRemoteDataSource {}

/// 收集型 fake loop:只消费 appendToolOutcome(note 真实生成侧出口)。
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
  // —— 成对往返:真 executor 生成 → parse → 三要素相等(格式漂移即红)——
  group('与 _writeNote 成对往返(生成→解析→字段相等)', () {
    late db.AppDatabase database;
    late _FakeLoop loop;
    late WriteExecutorImpl executor;

    setUp(() async {
      database = db.AppDatabase(NativeDatabase.memory());
      final tracker = SessionModeTracker()..isGuest = true;
      final txnsRepo = TransactionRepositoryImpl(
        _MockTxnRemote(),
        TransactionLocalDataSource(database, BalanceLocalUpdater(database)),
        tracker,
      );
      loop = _FakeLoop();
      executor = WriteExecutorImpl(
        txnsRepo,
        loop,
        AssistantAuditLog(log: (_) {}),
      );
      // 账户口径与 write_executor_impl_test 种子同款(asset=1/income=4/
      // expense=5 —— proto 值域;账户即分类)。
      Future<void> seed(String id, String name,
              {required int type, required int category}) =>
          database.accountDao.insertAccount(db.AccountsCompanion.insert(
            id: id,
            name: name,
            accountType: type,
            category: category,
            currencyCode: 'CNY',
            initialBalanceCents: 0,
            currentBalanceCents: 0,
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
      await seed('acc-cash', '现金', type: 1, category: 1);
      await seed('acc-food', '餐饮', type: 5, category: 8);
      await seed('acc-salary', '工资', type: 4, category: 8);
    });

    tearDown(() => database.close());

    Future<String> noteOf(TransactionAdd action) async {
      final outcome = await executor.execute(action, 'key-${action.amountCents}');
      expect(outcome, isA<WriteExecuted>(), reason: '夹具前提:种子库上执行成功');
      return loop.appendedOutcomes.last;
    }

    test('支出小额 + 描述「已记:支出 ¥35.00 午饭」', () async {
      final action = TransactionAdd(
        direction: WriteDirection.outflow,
        amountCents: 3500,
        description: '午饭',
        accountId: 'acc-cash',
        categoryId: 'acc-food',
        date: DateTime(2026, 10, 27),
      );
      final note = await noteOf(action);
      expect(note, '已记:支出 ¥35.00 午饭', reason: '生成侧形态钉定(漂移即红)');
      final parsed = AddActionFromNote.parse(note);
      expect(parsed, isNotNull);
      expect(parsed!.direction, WriteDirection.outflow);
      expect(parsed.amountCents, 3500);
      expect(parsed.description, '午饭');
    });

    test('收入千分位金额 + 描述「已记:收入 ¥1,234.50 工资」', () async {
      final action = TransactionAdd(
        direction: WriteDirection.inflow,
        amountCents: 123450,
        description: '工资',
        accountId: 'acc-cash',
        categoryId: 'acc-salary',
        date: DateTime(2026, 10, 27),
      );
      final note = await noteOf(action);
      expect(note, '已记:收入 ¥1,234.50 工资',
          reason: 'yuan() 千分位进 note(与确认消息同源)');
      final parsed = AddActionFromNote.parse(note);
      expect(parsed, isNotNull);
      expect(parsed!.direction, WriteDirection.inflow);
      expect(parsed.amountCents, 123450);
      expect(parsed.description, '工资');
    });

    test('空描述「已记:支出 ¥35.00」(_flat 首尾去空)→ 描述空串', () async {
      final action = TransactionAdd(
        direction: WriteDirection.outflow,
        amountCents: 3500,
        description: '',
        accountId: 'acc-cash',
        categoryId: 'acc-food',
        date: DateTime(2026, 10, 27),
      );
      final note = await noteOf(action);
      expect(note, '已记:支出 ¥35.00');
      final parsed = AddActionFromNote.parse(note);
      expect(parsed, isNotNull);
      expect(parsed!.direction, WriteDirection.outflow);
      expect(parsed.amountCents, 3500);
      expect(parsed.description, '');
    });
  });

  // —— 直接解析(生成侧之外的宽窄边界)——
  group('直接解析', () {
    test('多词描述(含空格/含 ¥ 字符)整段保留', () {
      final parsed = AddActionFromNote.parse('已记:支出 ¥35.00 美团 买菜 ¥券');
      expect(parsed, isNotNull);
      expect(parsed!.direction, WriteDirection.outflow);
      expect(parsed.amountCents, 3500);
      expect(parsed.description, '美团 买菜 ¥券');
    });

    test('头尾空白容忍', () {
      final parsed = AddActionFromNote.parse('  已记:收入 ¥88.00 红包  ');
      expect(parsed, isNotNull);
      expect(parsed!.direction, WriteDirection.inflow);
      expect(parsed.amountCents, 8800);
      expect(parsed.description, '红包');
    });
  });

  // —— 畸形串 → null(上游转 ErrorMsg,零卡零写)——
  group('畸形串 null', () {
    test('改/删族零解析(ADR-3)', () {
      expect(AddActionFromNote.parse('已改:美团买菜 ¥40.00'), isNull);
      expect(AddActionFromNote.parse('已删:美团买菜 ¥30.00'), isNull);
    });

    test('未知方向词', () {
      expect(AddActionFromNote.parse('已记:转账 ¥35.00 午饭'), isNull);
    });

    test('无金额 / 金额垃圾 / 零额 / 负额', () {
      expect(AddActionFromNote.parse('已记:支出 午饭'), isNull);
      expect(AddActionFromNote.parse('已记:支出 ¥abc 午饭'), isNull);
      expect(AddActionFromNote.parse('已记:支出 ¥0.00 午饭'), isNull,
          reason: 'TransactionAdd 恒正不变量');
      expect(AddActionFromNote.parse('已记:支出 ¥-35.00 午饭'), isNull);
    });

    test('空串/纯空白/无前缀/失败行 ASCII 机器串回退', () {
      expect(AddActionFromNote.parse(''), isNull);
      expect(AddActionFromNote.parse('   '), isNull);
      expect(AddActionFromNote.parse('支出 ¥35.00 午饭'), isNull);
      expect(
        AddActionFromNote.parse(
            'TransactionAdd(direction=out, amountCents=3500, '
            'description=lunch, accountId=a, categoryId=c, date=2026-10-27)'),
        isNull,
        reason: '素材缺失失败行的机器串 summary 回退形态',
      );
    });
  });
}
