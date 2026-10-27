// F70-T1 TDD RED → GREEN:transaction_delete 写工具(ADR-1/ADR-4)。
// 定位同 update(keyword+时间窗/缺省最近一笔,跳过转账);execute 返回
// requiresApproval ToolData(destructive 强提示数据)零落库。
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/assistant/data/tools/transaction_delete_tool.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
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

class _FakeRecordIncomeParams extends Fake implements RecordIncomeParams {}

class _FakeRecordTransferParams extends Fake implements RecordTransferParams {}

class _FakeRecordTransactionParams extends Fake
    implements RecordTransactionParams {}

void main() {
  late db.AppDatabase database;
  late TransactionRepository txnsRepo;
  late AccountRepository accountsRepo;
  late TransactionDeleteTool tool;

  setUpAll(() {
    registerFallbackValue(_FakeListTransactionsParams());
    registerFallbackValue(_FakeUpdateTransactionParams());
    registerFallbackValue(_FakeRecordExpenseParams());
    registerFallbackValue(_FakeRecordIncomeParams());
    registerFallbackValue(_FakeRecordTransferParams());
    registerFallbackValue(_FakeRecordTransactionParams());
  });

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    final local = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    txnsRepo = TransactionRepositoryImpl(_MockTxnRemote(), local, tracker);
    accountsRepo = AccountRepositoryImpl(
        _MockAccountRemote(), AccountLocalDataSource(database), tracker);

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

    await seedAccount('acc-cash', '现金', type: 1, category: 1, balance: 1000000);
    await seedAccount('acc-card', '招行信用卡', type: 2, category: 2);
    await seedAccount('acc-food', '餐饮', type: 5, category: 8);
    await seedAccount('acc-salary', '工资', type: 4, category: 8);

    // 与 update 夹具同族:e4 10-05 美团买菜 = 最新 in/out;e6 10-10 转账须跳过。
    await local.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 9, 1),
      expenseAccountId: 'acc-food',
      assetAccountId: 'acc-cash',
      amountCents: 5000,
      description: '美团外卖',
    ));
    await local.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 10, 5),
      expenseAccountId: 'acc-food',
      assetAccountId: 'acc-cash',
      amountCents: 3000,
      description: '美团买菜',
    ));
    await local.recordTransfer(RecordTransferParams(
      transactionDate: DateTime(2026, 10, 10),
      fromAccountId: 'acc-cash',
      toAccountId: 'acc-card',
      amountCents: 30000,
      description: '还款2',
    ));

    tool = TransactionDeleteTool(txnsRepo, accountsRepo);
  });

  tearDown(() => database.close());

  Map<String, Object?> ok(ToolResult r) => (r as ToolData).json;

  Future<Map<String, Transaction>> txnsByDesc() async => (await txnsRepo
          .list(const ListTransactionsParams(pageSize: 500)))
      .fold((l) => <String, Transaction>{},
          (r) => {for (final t in r.transactions) t.description: t});

  test('keyword 唯一命中 → action{transactionId} + destructive preview',
      () async {
    final txns = await txnsByDesc();
    final json = ok(await tool.execute(const {'keyword': '美团买菜'}));

    expect(json['requiresApproval'], isTrue);
    expect(json['action'], {
      'type': 'transaction_delete',
      'transactionId': txns['美团买菜']!.id,
    });
    final preview = json['preview'] as Map<String, Object?>;
    expect(preview['destructive'], isTrue, reason: '删除不可撤销强提示');
    final target = preview['target'] as Map<String, Object?>;
    expect(target['description'], '美团买菜');
    expect(target['amountCents'], 3000);
    expect(target['amountYuan'], '30.00');
    expect(target['direction'], 'out');
    expect(target['account'], '现金');
    expect(target['category'], '餐饮');
    expect(target['date'], '2026-10-05');
  });

  test('缺省 = 最近一笔且跳过转账(10-10 转账出局)', () async {
    final txns = await txnsByDesc();
    final json = ok(await tool.execute(const {}));
    expect((json['action'] as Map)['transactionId'], txns['美团买菜']!.id);
  });

  test('多候选(美团 ×2)→ ToolError 列前 3 让 LLM 问用户', () async {
    final result = await tool.execute(const {'keyword': '美团'});
    expect(result, isA<ToolError>());
    final msg = (result as ToolError).message;
    expect(msg, contains('美团外卖'));
    expect(msg, contains('美团买菜'));
  });

  test('时间窗收窄到唯一', () async {
    final txns = await txnsByDesc();
    final json = ok(await tool.execute(const {
      'keyword': '美团',
      'date_start': '2026-10-01',
    }));
    expect((json['action'] as Map)['transactionId'], txns['美团买菜']!.id);
  });

  test('零命中 → ToolError 引导 transactions_search;非法日期 → ToolError',
      () async {
    final zero = await tool.execute(const {'keyword': '不存在'});
    expect(zero, isA<ToolError>());
    expect((zero as ToolError).message, contains('transactions_search'));

    final badDate = await tool.execute(const {
      'keyword': '美团买菜',
      'date_start': 'not-a-date',
    });
    expect(badDate, isA<ToolError>());
  });

  group('零写断言(ADR-1)', () {
    test('真实 repo:提案后笔数不变', () async {
      final before = await txnsByDesc();
      await tool.execute(const {'keyword': '美团买菜'});
      expect((await txnsByDesc()).length, before.length);
    });

    test('mock repo verifyNever:delete/update/record* 零调用', () async {
      final mock = _MockTxnRepo();
      when(() => mock.list(any())).thenAnswer(
        (_) async => dz.Right(ListTransactionsResult(transactions: [
          Transaction(
            id: 'txn-9',
            transactionDate: DateTime(2026, 10, 5),
            description: 'mock 交易',
            entries: const [
              TransactionEntry(
                  accountId: 'acc-food', debitCents: 3000, creditCents: 0),
              TransactionEntry(
                  accountId: 'acc-cash', debitCents: 0, creditCents: 3000),
            ],
          ),
        ])),
      );

      final result = await TransactionDeleteTool(mock, accountsRepo)
          .execute(const {'keyword': 'mock'});

      expect(result, isA<ToolData>());
      verifyNever(() => mock.delete(any()));
      verifyNever(() => mock.update(any()));
      verifyNever(() => mock.recordExpense(any()));
      verifyNever(() => mock.recordIncome(any()));
      verifyNever(() => mock.recordTransfer(any()));
      verifyNever(() => mock.recordTransaction(any()));
    });

    test('repo list 失败 → ToolError(不炸)', () async {
      final mock = _MockTxnRepo();
      when(() => mock.list(any()))
          .thenAnswer((_) async => const dz.Left(UnexpectedFailure('db down')));
      expect(await TransactionDeleteTool(mock, accountsRepo).execute(const {}),
          isA<ToolError>());
    });
  });

  test('参数面 ≤8 项(NFR-2),不暴露内部 id 参数', () {
    final props = tool.parametersSchema['properties'] as Map;
    expect(props.length, lessThanOrEqualTo(8));
    expect(props.containsKey('transaction_id'), isFalse);
    expect(tool.name, 'transaction_delete');
  });
}
