// F70-T1 TDD RED → GREEN:transaction_update 写工具(ADR-1/ADR-4)。
// 定位=复用只读面(repo.list:keyword+时间窗/缺省最近一笔=时间倒序首条,
// 跳过转账);多候选 → ToolError 列前 3;execute 返回 requiresApproval
// ToolData(patch 内部 id)零写断言(mock repo verifyNever)。
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/assistant/data/tools/transaction_update_tool.dart';
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
  late TransactionUpdateTool tool;

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
    await seedAccount('acc-transport', '交通', type: 5, category: 8);
    await seedAccount('acc-salary', '工资', type: 4, category: 8);
    await seedAccount('acc-bonus', '奖金', type: 4, category: 8);

    // 交易种子(真实写路径;日期互异):
    // e1 09-01 支出 5,000 美团外卖 | e2 09-15 支出 12,000 京东购物(卡)
    // e3 09-20 收入 800,000 9月工资 | e5 09-25 转账 还款
    // e4 10-05 支出 3,000 美团买菜 | e6 10-10 转账 还款2(最新 = 转账,须跳过)
    Future<void> expense(DateTime d, int cents, String desc, String asset) =>
        local.recordExpense(RecordExpenseParams(
          transactionDate: d,
          expenseAccountId: 'acc-food',
          assetAccountId: asset,
          amountCents: cents,
          description: desc,
        ));

    await expense(DateTime(2026, 9, 1), 5000, '美团外卖', 'acc-cash');
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
    await local.recordTransfer(RecordTransferParams(
      transactionDate: DateTime(2026, 9, 25),
      fromAccountId: 'acc-cash',
      toAccountId: 'acc-card',
      amountCents: 50000,
      description: '还款',
    ));
    await expense(DateTime(2026, 10, 5), 3000, '美团买菜', 'acc-cash');
    await local.recordTransfer(RecordTransferParams(
      transactionDate: DateTime(2026, 10, 10),
      fromAccountId: 'acc-cash',
      toAccountId: 'acc-card',
      amountCents: 30000,
      description: '还款2',
    ));

    tool = TransactionUpdateTool(txnsRepo, accountsRepo);
  });

  tearDown(() => database.close());

  Map<String, Object?> ok(ToolResult r) => (r as ToolData).json;

  /// 全量交易(供取 id/断言零写)。
  Future<Map<String, Transaction>> txnsByDesc() async => (await txnsRepo
          .list(const ListTransactionsParams(pageSize: 500)))
      .fold((l) => <String, Transaction>{},
          (r) => {for (final t in r.transactions) t.description: t});

  group('定位(复用只读面)', () {
    test('无过滤 = 最近一笔:时间倒序首条且跳过转账(e6 10-10 还款2 出局)',
        () async {
      final txns = await txnsByDesc();
      final json = ok(await tool.execute(const {'new_amount': 40}));
      final action = json['action'] as Map<String, Object?>;
      expect(action['type'], 'transaction_update');
      expect(action['transactionId'], txns['美团买菜']!.id,
          reason: '最近一笔 in/out = 10-05 美团买菜(10-10 是转账)');
      expect((action['patch'] as Map)['amountCents'], 4000);
      expect(json['requiresApproval'], isTrue);
    });

    test('keyword 唯一命中(京东购物)→ 定位该笔', () async {
      final txns = await txnsByDesc();
      final json = ok(await tool.execute(const {
        'keyword': '京东',
        'new_description': '京东购物(退货重记)',
      }));
      expect((json['action'] as Map)['transactionId'], txns['京东购物']!.id);
      expect(((json['action'] as Map)['patch'] as Map)['description'],
          '京东购物(退货重记)');
    });

    test('keyword 多候选(美团 ×2)→ ToolError 列前 3 让 LLM 问用户', () async {
      final result = await tool.execute(const {
        'keyword': '美团',
        'new_amount': 40,
      });
      expect(result, isA<ToolError>());
      final msg = (result as ToolError).message;
      expect(msg, contains('美团外卖'));
      expect(msg, contains('美团买菜'));
    });

    test('keyword + 时间窗收窄到唯一(美团 + start 10-01)', () async {
      final txns = await txnsByDesc();
      final json = ok(await tool.execute(const {
        'keyword': '美团',
        'date_start': '2026-10-01',
        'new_amount': 40,
      }));
      expect((json['action'] as Map)['transactionId'], txns['美团买菜']!.id);
    });

    test('零命中 → ToolError 引导 transactions_search/放宽窗口', () async {
      final result = await tool.execute(const {
        'keyword': '不存在的交易',
        'new_amount': 40,
      });
      expect(result, isA<ToolError>());
      expect((result as ToolError).message, contains('transactions_search'));
    });

    test('时间窗独立定位(09-18..09-22 唯一收入)', () async {
      final txns = await txnsByDesc();
      final json = ok(await tool.execute(const {
        'date_start': '2026-09-18',
        'date_end': '2026-09-22',
        'new_amount': 8000,
      }));
      expect(
        (json['action'] as Map)['transactionId'],
        txns['9月工资']!.id,
        reason: '窗内唯一 in/out = 09-20 9月工资',
      );
    });

    test('时间窗多候选 → ToolError(09-10..09-30 = 京东+工资)', () async {
      final result = await tool.execute(const {
        'date_start': '2026-09-10',
        'date_end': '2026-09-30',
        'new_amount': 8000,
      });
      expect(result, isA<ToolError>());
      expect((result as ToolError).message, contains('京东购物'));
      expect(result.message, contains('9月工资'));
    });
  });

  group('patch 参数面(至少一字段/字段解析)', () {
    test('无任何 new_* 字段 → ToolError(至少一字段)', () async {
      final result = await tool.execute(const {'keyword': '京东'});
      expect(result, isA<ToolError>());
      expect((result as ToolError).message, contains('at least one'));
    });

    test('new_category 按定位方向解析(out → expense 账户)', () async {
      final txns = await txnsByDesc();
      final json = ok(await tool.execute(const {
        'keyword': '美团买菜',
        'new_category': '交通',
      }));
      expect(((json['action'] as Map)['patch'] as Map)['categoryId'],
          'acc-transport');
      expect(txns['美团买菜']!.id, isNotEmpty);
    });

    test('new_category 对收入交易解析到 income 账户(奖金)', () async {
      final json = ok(await tool.execute(const {
        'keyword': '9月工资',
        'new_category': '奖金',
      }));
      expect(((json['action'] as Map)['patch'] as Map)['categoryId'],
          'acc-bonus');
    });

    test('new_category 与方向不符(收入给支出分类)→ ToolError', () async {
      final result = await tool.execute(const {
        'keyword': '9月工资',
        'new_category': '餐饮',
      });
      expect(result, isA<ToolError>());
    });

    test('new_account 解析到资产账户 id;new_amount/new_date 同批', () async {
      final json = ok(await tool.execute(const {
        'keyword': '京东购物',
        'new_account': '现金',
        'new_amount': 15,
        'new_date': '2026-09-16',
      }));
      final patch = (json['action'] as Map)['patch'] as Map<String, Object?>;
      expect(patch['accountId'], 'acc-cash');
      expect(patch['amountCents'], 1500);
      expect(patch['date'], '2026-09-16');
      expect(patch.containsKey('description'), isFalse,
          reason: '未提及字段不出现在 patch');
    });

    test('new_amount 垃圾/<=0 → ToolError;new_date 非法 → ToolError',
        () async {
      for (final args in [
        {'keyword': '京东购物', 'new_amount': 'abc'},
        {'keyword': '京东购物', 'new_amount': 0},
        {'keyword': '京东购物', 'new_date': 'not-a-date'},
        {'keyword': '京东购物', 'new_account': '不存在的账户'},
      ]) {
        expect(await tool.execute(args), isA<ToolError>(), reason: '$args');
      }
    });
  });

  group('preview 前后对比(T3 diff 卡数据源)', () {
    test('before = 定位笔现状;after = patch 覆盖后(名称展示)', () async {
      final json = ok(await tool.execute(const {
        'keyword': '美团买菜',
        'new_amount': 40,
        'new_category': '交通',
      }));
      final preview = json['preview'] as Map<String, Object?>;
      final before = preview['before'] as Map<String, Object?>;
      final after = preview['after'] as Map<String, Object?>;
      expect(before['description'], '美团买菜');
      expect(before['amountCents'], 3000);
      expect(before['amountYuan'], '30.00');
      expect(before['direction'], 'out');
      expect(before['account'], '现金');
      expect(before['category'], '餐饮');
      expect(before['date'], '2026-10-05');
      expect(after['amountCents'], 4000);
      expect(after['amountYuan'], '40.00');
      expect(after['category'], '交通');
      expect(after['description'], '美团买菜', reason: '未改字段原样');
    });
  });

  group('零写断言(ADR-1)', () {
    test('真实 repo:提案后交易集合逐位不变', () async {
      final before = await txnsByDesc();
      await tool.execute(const {'keyword': '京东购物', 'new_amount': 15});
      final after = await txnsByDesc();
      expect(after.length, before.length);
      final b = before['京东购物']!;
      final a = after['京东购物']!;
      expect(a.totalDebitCents, b.totalDebitCents,
          reason: '提案不触发任何写(金额不变)');
      expect(a.entries, hasLength(b.entries.length));
      expect(a.description, b.description);
    });

    test('mock repo verifyNever:update/delete/record* 零调用', () async {
      final mock = _MockTxnRepo();
      when(() => mock.list(any())).thenAnswer(
        (_) async => dz.Right(ListTransactionsResult(transactions: [
          Transaction(
            id: 'txn-9',
            transactionDate: DateTime(2026, 10, 5),
            description: 'mock 交易',
            version: 3,
            entries: const [
              TransactionEntry(
                  accountId: 'acc-food', debitCents: 3000, creditCents: 0),
              TransactionEntry(
                  accountId: 'acc-cash', debitCents: 0, creditCents: 3000),
            ],
          ),
        ])),
      );

      final result = await TransactionUpdateTool(mock, accountsRepo)
          .execute(const {'new_amount': 40});

      expect(result, isA<ToolData>());
      expect(((result as ToolData).json['action'] as Map)['transactionId'],
          'txn-9');
      verifyNever(() => mock.update(any()));
      verifyNever(() => mock.delete(any()));
      verifyNever(() => mock.recordExpense(any()));
      verifyNever(() => mock.recordIncome(any()));
      verifyNever(() => mock.recordTransfer(any()));
      verifyNever(() => mock.recordTransaction(any()));
    });

    test('repo list 失败 → ToolError(不炸)', () async {
      final mock = _MockTxnRepo();
      when(() => mock.list(any()))
          .thenAnswer((_) async => const dz.Left(UnexpectedFailure('db down')));
      expect(
        await TransactionUpdateTool(mock, accountsRepo)
            .execute(const {'new_amount': 40}),
        isA<ToolError>(),
      );
    });
  });

  test('参数面 ≤8 项(NFR-2),不暴露内部 id 参数', () {
    final props = tool.parametersSchema['properties'] as Map;
    expect(props.length, lessThanOrEqualTo(8));
    expect(props.containsKey('transaction_id'), isFalse);
    expect(tool.name, 'transaction_update');
  });
}
