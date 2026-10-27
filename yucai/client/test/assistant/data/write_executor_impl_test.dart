// F70-T2 TDD:WriteExecutorImpl(ADR-1/ADR-3/ADR-6,FR-1..3/NFR-1/NFR-3)。
//
// 真库主路径(drift 内存库 + TransactionRepositoryImpl —— 表单同管道实证:
// 落库分录/余额联动/version 递增);mock repo 钉失败路径(version 冲突 →
// versionConflict / 异常 → runtimeType 零 payload)。幂等集:同 key 重复
// 触发零写;失败不耗键(重试同 key 从零再执行)。审计行 English/ASCII;
// 中文 note 只进 appendToolOutcome(会话上下文),不进日志串。
//
// 断言口径:WriteOutcome 非值相等类 —— 用 isA<> + 字段断言;持久化
// entry 携服务端 id —— 分录按 accountId/debit/credit/note 字段断言。
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/assistant/data/audit_log.dart';
import 'package:yucai_client/assistant/data/tools/tool_args.dart' show yuan;
import 'package:yucai_client/assistant/data/write_executor_impl.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/domain/write_executor.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
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

/// 收集型 fake loop:只消费 appendToolOutcome(ADR-2 注入缝)。
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
  late db.AppDatabase database;
  late TransactionRepository txnsRepo;
  late AccountRepository accountsRepo;
  late _FakeLoop loop;
  late List<String> auditLines;
  late WriteExecutorImpl executor;

  setUpAll(() {
    registerFallbackValue(_FakeListTransactionsParams());
    registerFallbackValue(_FakeUpdateTransactionParams());
    registerFallbackValue(_FakeRecordExpenseParams());
  });

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    final local = TransactionLocalDataSource(
        database, BalanceLocalUpdater(database));
    txnsRepo = TransactionRepositoryImpl(_MockTxnRemote(), local, tracker);
    accountsRepo = AccountRepositoryImpl(
        _MockAccountRemote(), AccountLocalDataSource(database), tracker);
    loop = _FakeLoop();
    auditLines = [];
    executor = WriteExecutorImpl(
      txnsRepo,
      loop,
      AssistantAuditLog(log: auditLines.add),
    );

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

    await seedAccount('acc-cash', '现金',
        type: 1, category: 1, balance: 1000000);
    await seedAccount('acc-card', '招行信用卡', type: 2, category: 2);
    await seedAccount('acc-food', '餐饮', type: 5, category: 8);
    await seedAccount('acc-transport', '交通', type: 5, category: 8);
    await seedAccount('acc-salary', '工资', type: 4, category: 8);
    await seedAccount('acc-bonus', '奖金', type: 4, category: 8);

    // 种子(现金基线:1,000,000 − 3,000 支出 + 800,000 收入 = 1,797,000)。
    await local.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 10, 5),
      expenseAccountId: 'acc-food',
      assetAccountId: 'acc-cash',
      amountCents: 3000,
      description: '美团买菜',
      note: '备注X',
    ));
    await local.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 9, 15),
      expenseAccountId: 'acc-food',
      assetAccountId: 'acc-card',
      amountCents: 12000,
      description: '京东购物',
    ));
    await local.recordIncome(RecordIncomeParams(
      transactionDate: DateTime(2026, 9, 20),
      assetAccountId: 'acc-cash',
      incomeAccountId: 'acc-salary',
      amountCents: 800000,
      description: '9月工资',
    ));
  });

  tearDown(() => database.close());

  /// 按描述取交易(断言与定位用)。
  Future<Transaction?> txnByDesc(String desc) async => (await txnsRepo
          .list(const ListTransactionsParams(pageSize: 500)))
      .fold((l) => null, (r) {
    for (final t in r.transactions) {
      if (t.description == desc) return t;
    }
    return null;
  });

  Future<int> txnCount() async => (await txnsRepo
          .list(const ListTransactionsParams(pageSize: 500)))
      .fold((l) => -1, (r) => r.transactions.length);

  Future<int> cashBalance() async => (await accountsRepo.list()).fold(
      (l) => -1,
      (accounts) => accounts
          .firstWhere((a) => a.id == 'acc-cash')
          .currentBalanceCents);

  /// 分录字段断言(持久化 entry 携服务端 id,Equatable 含 id 不等值)。
  void expectEntry(TransactionEntry e, String accountId,
      {int debit = 0, int credit = 0, String note = '', String? reason}) {
    expect(e.accountId, accountId, reason: reason);
    expect(e.debitCents, debit, reason: reason);
    expect(e.creditCents, credit, reason: reason);
    expect(e.note, note, reason: reason);
  }

  final addLunch = TransactionAdd(
    direction: WriteDirection.outflow,
    amountCents: 3500,
    description: '午饭',
    accountId: 'acc-cash',
    categoryId: 'acc-food',
    date: DateTime(2026, 10, 27),
  );

  group('Add(表单同管道,FR-1/NFR-1)', () {
    test('支出:recordExpense 落库(科目借/资产贷)+ 余额联动 + note + 审计',
        () async {
      final outcome = await executor.execute(addLunch, 'key-add-1');

      expect(outcome, isA<WriteExecuted>());
      final txn = await txnByDesc('午饭');
      expect(txn, isNotNull, reason: '同管道落库可回读');
      expect((outcome as WriteExecuted).entityId, txn!.id);
      expect(txn.entries, hasLength(2));
      expectEntry(txn.entries[0], 'acc-food', debit: 3500,
          reason: 'expense = 科目借方分录(recordExpense 同构)');
      expectEntry(txn.entries[1], 'acc-cash', credit: 3500);
      expect(txn.transactionDate, DateTime(2026, 10, 27));
      // NFR-1 同管道实证:余额联动由 repo 写路径自带(1,797,000 − 3,500)。
      expect(await cashBalance(), 1793500);
      // ADR-2:中文紧凑单行 note 注入会话上下文。
      expect(loop.appendedOutcomes, ['已记:支出 ¥35.00 午饭']);
      // NFR-3:English/ASCII 审计行(entity 携落库 id)。
      expect(
        auditLines.where((l) =>
            l.contains('assistant write tool=transaction_add') &&
            l.contains('status=ok') &&
            l.contains('entity=${txn.id}')),
        hasLength(1),
      );
    });

    test('收入:recordIncome 方向分流(资产借/科目贷)', () async {
      final outcome = await executor.execute(
        TransactionAdd(
          direction: WriteDirection.inflow,
          amountCents: 800000,
          description: '外快',
          accountId: 'acc-cash',
          categoryId: 'acc-salary',
          date: DateTime(2026, 10, 27),
        ),
        'key-add-2',
      );

      expect(outcome, isA<WriteExecuted>());
      final txn = await txnByDesc('外快');
      expectEntry(txn!.entries[0], 'acc-cash', debit: 800000);
      expectEntry(txn.entries[1], 'acc-salary', credit: 800000);
      // 千分位单源(评审 T2-M1):≥¥1000 note 与工具 preview 同格式。
      expect(loop.appendedOutcomes, ['已记:收入 ¥8,000.00 外快']);
      // 收入同管道余额联动:1,797,000 + 800,000。
      expect(await cashBalance(), 2597000);
    });

    test('千分位单源(评审 T2-M1):1234567 cents 两通道字符串逐字相等', () async {
      await executor.execute(
        TransactionAdd(
          direction: WriteDirection.outflow,
          amountCents: 1234567,
          description: '大额',
          accountId: 'acc-cash',
          categoryId: 'acc-food',
          date: DateTime(2026, 10, 27),
        ),
        'key-add-thousands',
      );

      // 通道一:工具 preview.amountYuan(bloc 确认消息数据源)= yuan()
      // 同源(DueReminderPolicy.formatYuan,含千分位)。
      expect(yuan(1234567), '12,345.67', reason: '含千分位');
      // 通道二:executor note —— 与通道一金额段逐字相等(≥¥1000 不分叉)。
      expect(loop.appendedOutcomes.single, '已记:支出 ¥12,345.67 大额');
      expect(
        loop.appendedOutcomes.single,
        '已记:支出 ¥${yuan(1234567)} 大额',
        reason: 'note 金额段 = 工具 preview 元串(两通道同源)',
      );
    });

    test('repo Left → WriteFailed(runtimeType) + 审计 error 行 + 零注入',
        () async {
      final mock = _MockTxnRepo();
      when(() => mock.recordExpense(any()))
          .thenAnswer((_) async => const dz.Left(NetworkFailure('offline')));
      final failing = WriteExecutorImpl(
        mock,
        loop,
        AssistantAuditLog(log: auditLines.add),
      );

      final outcome = await failing.execute(addLunch, 'key-add-fail');

      expect(outcome, isA<WriteFailed>());
      expect((outcome as WriteFailed).reason, 'NetworkFailure');
      expect(loop.appendedOutcomes, isEmpty, reason: '失败零注入');
      expect(
        auditLines.where((l) =>
            l.contains('tool=transaction_add') && l.contains('status=error')),
        hasLength(1),
      );
    });
  });

  group('幂等集(ADR-3/FR-1 幂等场景)', () {
    test('同 key 重复触发:AlreadyExecuted 回放,零写/零注入/零重复审计',
        () async {
      final first = await executor.execute(addLunch, 'key-idem');
      final entityId = (first as WriteExecuted).entityId;
      final countAfterFirst = await txnCount();

      final second = await executor.execute(addLunch, 'key-idem');

      expect(second, isA<AlreadyExecuted>());
      expect((second as AlreadyExecuted).entityId, entityId);
      expect(await txnCount(), countAfterFirst, reason: '不产生第二笔交易');
      expect(loop.appendedOutcomes, hasLength(1), reason: 'note 不重复注入');
      expect(
        auditLines.where((l) => l.contains('tool=transaction_add status=ok')),
        hasLength(1),
        reason: '审计不重复',
      );
    });

    test('不同 key 同操作 = 两次独立执行(幂等按键不按内容)', () async {
      await executor.execute(addLunch, 'key-a');
      await executor.execute(addLunch, 'key-b');
      expect(await txnCount(), 5, reason: '种子 3 + 两笔独立记账');
    });
  });

  group('Update(现读 version + 全分录重建,FR-2)', () {
    test('改金额+描述:entries 全重建,note 逐侧保留,version 现读递增',
        () async {
      final before = (await txnByDesc('美团买菜'))!;
      final outcome = await executor.execute(
        TransactionUpdate(
          direction: WriteDirection.outflow,
          transactionId: before.id,
          patch: TransactionPatch(
            amountCents: 4000,
            description: '美团买菜(改)',
          ),
        ),
        'key-upd-1',
      );

      expect(outcome, isA<WriteExecuted>());
      expect((outcome as WriteExecuted).entityId, before.id);
      final after = (await txnByDesc('美团买菜(改)'))!;
      expect(after.version, before.version + 1, reason: '现读 version 打底');
      expect(after.entries, hasLength(2));
      expectEntry(after.entries[0], 'acc-food', debit: 4000, note: '备注X',
          reason: '科目借侧重建,note 保留(全替换语义不冲掉)');
      expectEntry(after.entries[1], 'acc-cash', credit: 4000, note: '备注X');
      expect(loop.appendedOutcomes, ['已改:美团买菜(改) ¥40.00']);
      // 余额联动:改 30 → 40,现金再扣 1,000(1,797,000 − 1,000)。
      expect(await cashBalance(), 1796000);
    });

    test('改支出笔分类+账户:方向 outflow → 科目借/资产贷', () async {
      final before = (await txnByDesc('美团买菜'))!;
      await executor.execute(
        TransactionUpdate(
          direction: WriteDirection.outflow,
          transactionId: before.id,
          patch: TransactionPatch(
            categoryId: 'acc-transport',
            accountId: 'acc-card',
          ),
        ),
        'key-upd-2',
      );

      final after = (await txnByDesc('美团买菜'))!;
      expectEntry(after.entries[0], 'acc-transport', debit: 3000,
          note: '备注X');
      expectEntry(after.entries[1], 'acc-card', credit: 3000,
          note: '备注X');
    });

    test('改收入笔分类+账户:方向 inflow → 资产借/科目贷(镜像表单 '
        '_buildEntries income 分支)', () async {
      final before = (await txnByDesc('9月工资'))!;
      await executor.execute(
        TransactionUpdate(
          direction: WriteDirection.inflow,
          transactionId: before.id,
          patch: TransactionPatch(
            categoryId: 'acc-bonus',
            accountId: 'acc-card',
          ),
        ),
        'key-upd-3',
      );

      final after = (await txnByDesc('9月工资'))!;
      expectEntry(after.entries[0], 'acc-card', debit: 800000);
      expectEntry(after.entries[1], 'acc-bonus', credit: 800000);
    });

    test('改日期:patch.date 覆盖,其余字段现读随包(full-replace 语义)',
        () async {
      final before = (await txnByDesc('京东购物'))!;
      await executor.execute(
        TransactionUpdate(
          direction: WriteDirection.outflow,
          transactionId: before.id,
          patch: TransactionPatch(date: DateTime(2026, 9, 16)),
        ),
        'key-upd-4',
      );

      final after = (await txnByDesc('京东购物'))!;
      expect(after.transactionDate, DateTime(2026, 9, 16));
      expect(after.description, '京东购物', reason: '未改字段现读随包不被清空');
      expect(after.totalDebitCents, 12000);
    });

    test('目标笔已被手删:getById 失败 → WriteFailed(transactionNotFound)',
        () async {
      final target = (await txnByDesc('京东购物'))!;
      await txnsRepo.delete(target.id);

      final outcome = await executor.execute(
        TransactionUpdate(
          direction: WriteDirection.outflow,
          transactionId: target.id,
          patch: TransactionPatch(amountCents: 4000),
        ),
        'key-upd-missing',
      );

      expect(outcome, isA<WriteFailed>());
      expect((outcome as WriteFailed).reason, 'transactionNotFound');
      expect(loop.appendedOutcomes, isEmpty);
    });

    test('复杂分录(>2 条):拒绝重建 fail-closed,交易逐位不变', () async {
      // 平衡三分录:现金借 3,000;餐饮贷 1,000;交通贷 2,000。
      await txnsRepo.recordTransaction(RecordTransactionParams(
        transactionDate: DateTime(2026, 10, 20),
        description: '复合拆分',
        entries: const [
          TransactionEntry(
              accountId: 'acc-cash', debitCents: 3000, creditCents: 0),
          TransactionEntry(
              accountId: 'acc-food', debitCents: 0, creditCents: 1000),
          TransactionEntry(
              accountId: 'acc-transport', debitCents: 0, creditCents: 2000),
        ],
      ));
      final target = (await txnByDesc('复合拆分'))!;

      final outcome = await executor.execute(
        TransactionUpdate(
          direction: WriteDirection.outflow,
          transactionId: target.id,
          patch: TransactionPatch(amountCents: 9999),
        ),
        'key-upd-complex',
      );

      expect(outcome, isA<WriteFailed>());
      expect((outcome as WriteFailed).reason, 'unsupportedEntryLayout');
      final after = await txnByDesc('复合拆分');
      expect(after!.entries, hasLength(3), reason: '原分录不被截断重建');
      expect(after.totalDebitCents, 3000);
    });

    test('mock:version 冲突 → WriteFailed(versionConflict);重试同键成功;'
        '再击 AlreadyExecuted(失败不耗键)', () async {
      final mock = _MockTxnRepo();
      final seeded = Transaction(
        id: 'txn-v3',
        transactionDate: DateTime(2026, 10, 5),
        description: '美团买菜',
        version: 3,
        entries: const [
          TransactionEntry(
              accountId: 'acc-food', debitCents: 3000, creditCents: 0),
          TransactionEntry(
              accountId: 'acc-cash', debitCents: 0, creditCents: 3000),
        ],
      );
      when(() => mock.getById(any()))
          .thenAnswer((_) async => dz.Right(seeded));
      var updateCalls = 0;
      when(() => mock.update(any())).thenAnswer((_) async {
        updateCalls++;
        return updateCalls == 1
            ? const dz.Left(ServerFailure('数据已过期，请刷新后重试'))
            : dz.Right(seeded);
      });
      final mockedExecutor = WriteExecutorImpl(
        mock,
        loop,
        AssistantAuditLog(log: auditLines.add),
      );
      final action = TransactionUpdate(
        direction: WriteDirection.outflow,
        transactionId: 'txn-v3',
        patch: TransactionPatch(amountCents: 4000),
      );

      final first = await mockedExecutor.execute(action, 'key-vc');
      expect(first, isA<WriteFailed>());
      expect((first as WriteFailed).reason, 'versionConflict');
      expect(updateCalls, 1);
      // 失败不耗键:同 key 重试从零再执行 → 成功。
      final retry = await mockedExecutor.execute(action, 'key-vc');
      expect(retry, isA<WriteExecuted>());
      expect(updateCalls, 2, reason: '重试真实到达 repo.update');
      // 成功后键消耗:再击回放零写。
      final third = await mockedExecutor.execute(action, 'key-vc');
      expect(third, isA<AlreadyExecuted>());
      expect((third as AlreadyExecuted).entityId, 'txn-v3');
      expect(updateCalls, 2);
      expect(loop.appendedOutcomes, hasLength(1));
    });

    test('mock:repo 抛异常 → WriteFailed(runtimeType) 零 payload + 审计行',
        () async {
      final mock = _MockTxnRepo();
      when(() => mock.getById(any())).thenThrow(StateError('secret-payload'));
      final mockedExecutor = WriteExecutorImpl(
        mock,
        loop,
        AssistantAuditLog(log: auditLines.add),
      );

      final outcome = await mockedExecutor.execute(
        const TransactionDelete(transactionId: 'txn-x'),
        'key-throw',
      );

      expect(outcome, isA<WriteFailed>());
      expect((outcome as WriteFailed).reason, 'StateError');
      expect(
        auditLines.where((l) =>
            l.contains('tool=transaction_delete') &&
            l.contains('status=error')),
        hasLength(1),
      );
      expect(
        auditLines.every((l) => !l.contains('secret-payload')),
        isTrue,
        reason: '异常 payload 不入日志(F46 红线口径)',
      );
    });
  });

  group('Delete(FR-3)', () {
    test('同管道删除 + note 已删 + 审计行 + 余额回滚', () async {
      final target = (await txnByDesc('美团买菜'))!;

      final outcome = await executor.execute(
          TransactionDelete(transactionId: target.id), 'key-del-1');

      expect(outcome, isA<WriteExecuted>());
      expect((outcome as WriteExecuted).entityId, target.id);
      expect(await txnByDesc('美团买菜'), isNull, reason: '真删');
      expect(loop.appendedOutcomes, ['已删:美团买菜 ¥30.00']);
      expect(
        auditLines.where((l) =>
            l.contains('tool=transaction_delete') &&
            l.contains('status=ok') &&
            l.contains('entity=${target.id}')),
        hasLength(1),
      );
      // 删除同管道余额回滚:现金 +3,000(1,797,000 + 3,000)。
      expect(await cashBalance(), 1800000);
    });

    test('目标不存在 → WriteFailed(transactionNotFound),零注入', () async {
      final outcome = await executor.execute(
        const TransactionDelete(transactionId: 'no-such-txn'),
        'key-del-missing',
      );
      expect(outcome, isA<WriteFailed>());
      expect((outcome as WriteFailed).reason, 'transactionNotFound');
      expect(loop.appendedOutcomes, isEmpty);
    });
  });

  group('审计与注入红线(日志串无 CJK)', () {
    test('全部审计行可打印 ASCII;中文 note 只进 appendToolOutcome',
        () async {
      await executor.execute(addLunch, 'key-ascii');
      final target = (await txnByDesc('京东购物'))!;
      await executor.execute(
        TransactionUpdate(
          direction: WriteDirection.outflow,
          transactionId: target.id,
          patch: TransactionPatch(amountCents: 1500),
        ),
        'key-ascii-2',
      );
      await executor.execute(
          TransactionDelete(transactionId: target.id), 'key-ascii-3');

      expect(auditLines, isNotEmpty);
      final ascii = RegExp(r'^[\x20-\x7E]*$');
      for (final line in auditLines) {
        expect(line, matches(ascii), reason: 'audit line must be ASCII: $line');
      }
      expect(
        auditLines.every(
            (l) => !l.contains('已记') && !l.contains('已改') && !l.contains('已删')),
        isTrue,
        reason: '中文 note 不进日志串',
      );
      expect(loop.appendedOutcomes, hasLength(3));
    });
  });
}
