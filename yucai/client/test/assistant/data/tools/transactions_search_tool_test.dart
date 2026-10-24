// F65-T1 TDD RED → GREEN:transactions_search 只读工具(FR-2,六项过滤 +
// 分页 + 过滤后聚合摘要)。真库夹具:内存 drift + 真实写入路径
// (recordExpense/recordIncome/recordTransfer)落交易,经**真实**
// TransactionRepositoryImpl + AccountRepositoryImpl(guest 路由)供数。
// 汇总口径 = TransactionSummary 同式(income 科目 credit 单边 / expense
// 科目 debit 单边);期望值由测试独立手算。
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/assistant/data/tools/transactions_search_tool.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
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

void main() {
  late db.AppDatabase database;
  late TransactionRepository txnsRepo;
  late AccountRepository accountsRepo;
  late TransactionsSearchTool tool;

  setUpAll(() {
    registerFallbackValue(_FakeListTransactionsParams());
  });

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final tracker = SessionModeTracker()..isGuest = true;
    final local = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    txnsRepo = TransactionRepositoryImpl(_MockTxnRemote(), local, tracker);
    accountsRepo = AccountRepositoryImpl(
        _MockAccountRemote(), AccountLocalDataSource(database), tracker);

    Future<String> seedAccount(String id, String name,
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
      return id;
    }

    final cash = await seedAccount('acc-cash', '现金',
        type: 1, category: 1, balance: 1000000);
    final card = await seedAccount('acc-card', '招行信用卡', type: 2, category: 2);
    // 分类账户 category = otherAsset(备份契约 int = AccountCategory.index+1
    // = 8;category_bloc 建分类账戶同值)。
    final food =
        await seedAccount('acc-food', '餐饮', type: 5, category: 8);
    final salary =
        await seedAccount('acc-salary', '工资', type: 4, category: 8);

    // ── 交易种子(真实写入路径;日期互异保证排序确定)──
    // e1 09-01 支出 5,000「美团外卖」(food × cash)
    await local.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 9, 1),
      expenseAccountId: food,
      assetAccountId: cash,
      amountCents: 5000,
      description: '美团外卖',
    ));
    // e2 09-15 支出 12,000「京东购物」(food × card)
    await local.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 9, 15),
      expenseAccountId: food,
      assetAccountId: card,
      amountCents: 12000,
      description: '京东购物',
    ));
    // e3 09-20 收入 800,000「工资」(cash × salary)
    await local.recordIncome(RecordIncomeParams(
      transactionDate: DateTime(2026, 9, 20),
      assetAccountId: cash,
      incomeAccountId: salary,
      amountCents: 800000,
      description: '9月工资',
    ));
    // e4 10-05 支出 3,000「美团买菜」(food × cash)
    await local.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 10, 5),
      expenseAccountId: food,
      assetAccountId: cash,
      amountCents: 3000,
      description: '美团买菜',
    ));
    // e5 09-25 转账 50,000(cash → card)
    await local.recordTransfer(RecordTransferParams(
      transactionDate: DateTime(2026, 9, 25),
      fromAccountId: cash,
      toAccountId: card,
      amountCents: 50000,
      description: '还款',
    ));

    tool = TransactionsSearchTool(txnsRepo, accountsRepo);
  });

  tearDown(() => database.close());

  Map<String, Object?> run(ToolResult r) => (r as ToolData).json;

  test('no filter: aggregate summary + top items (date desc) + pagination',
      () async {
    final json = run(await tool.execute(const {}));
    final summary = json['summary'] as Map<String, Object?>;
    // 独立手算(TransactionSummary 同式):income = credit(type4)单边;
    // expense = debit(type5)单边;transfer 不计。
    expect(summary['count'], 5);
    expect(summary['incomeCents'], 800000);
    expect(summary['incomeYuan'], '8,000.00');
    expect(summary['expenseCents'], 5000 + 12000 + 3000);
    expect(summary['expenseYuan'], '200.00');
    expect(summary['netCents'], 800000 - 20000);
    expect(json['totalCount'], 5);

    final items = (json['transactions'] as List).cast<Map<String, Object?>>();
    expect(items, hasLength(5));
    // 日期降序首条 = 10-05 支出。
    final first = items.first;
    expect(first['date'], '2026-10-05');
    expect(first['description'], '美团买菜');
    expect(first['direction'], 'out');
    expect(first['amountCents'], 3000);
    expect(first['amountYuan'], '30.00');
    expect((first['accounts'] as List), containsAll(['餐饮', '现金']));
  });

  test('direction=out narrows set and summary follows the filtered set',
      () async {
    final json = run(await tool.execute({'direction': 'out'}));
    final items = (json['transactions'] as List).cast<Map<String, Object?>>();
    expect(json['totalCount'], 3);
    expect(items.every((t) => t['direction'] == 'out'), isTrue);
    final summary = json['summary'] as Map;
    expect(summary['count'], 3);
    expect(summary['incomeCents'], 0);
    expect(summary['expenseCents'], 20000, reason: '汇总覆盖过滤后全集');
  });

  test('direction=in keeps income transactions only', () async {
    final json = run(await tool.execute({'direction': 'IN'}));
    expect(json['totalCount'], 1);
    final items = (json['transactions'] as List).cast<Map<String, Object?>>();
    expect(items.single['description'], '9月工资');
    expect(items.single['direction'], 'in');
  });

  test('date range [start,end] inclusive bounds', () async {
    final json = run(await tool.execute({
      'start': '2026-09-01',
      'end': '2026-09-30',
    }));
    expect(json['totalCount'], 4, reason: 'e1/e2/e3/e5 在 9 月窗内,e4 出局');
    final descs = (json['transactions'] as List)
        .cast<Map<String, Object?>>()
        .map((t) => t['description'])
        .toSet();
    expect(descs.contains('美团买菜'), isFalse);
  });

  test('account filter by name (case-insensitive) or id', () async {
    final byName = run(await tool.execute({'account': '现金'}));
    // 现金涉及:e1/e3/e4/e5(京东走卡)。
    expect(byName['totalCount'], 4);
    expect(
        (byName['transactions'] as List)
            .cast<Map<String, Object?>>()
            .map((t) => t['description'])
            .toSet()
            .contains('京东购物'),
        isFalse);

    final byId = run(await tool.execute({'account': 'acc-card'}));
    expect(byId['totalCount'], 2, reason: 'e2 + e5 涉及信用卡');

    final unknown = await tool.execute({'account': '不存在的账户'});
    expect(unknown, isA<ToolError>(), reason: '零命中 → 自纠 ToolError');
    expect((unknown as ToolError).message, contains('accounts_list'));
  });

  test('category filter (AccountCategory) hits any entry account', () async {
    // otherAsset = 分类账户(food/salary 的 category)→ e1/e2/e3/e4;
    // e5(仅现金×信用卡)出局。
    final json = run(await tool.execute({'category': 'otherAsset'}));
    expect(json['totalCount'], 4);
    final invalid = await tool.execute({'category': 'nope'});
    expect(invalid, isA<ToolError>());
    expect((invalid as ToolError).message, contains('otherAsset'),
        reason: '合法值列全,LLM 自纠');
  });

  test('keyword filter: contains, case-insensitive', () async {
    final json = run(await tool.execute({'keyword': '美团'}));
    expect(json['totalCount'], 2);
    final summary = json['summary'] as Map;
    expect(summary['expenseCents'], 8000, reason: '5,000 + 3,000');
  });

  test('combined filters compose (date + direction + keyword)', () async {
    final json = run(await tool.execute({
      'start': '2026-09-01',
      'end': '2026-09-30',
      'direction': 'out',
      'keyword': '京东',
    }));
    expect(json['totalCount'], 1);
    final items = (json['transactions'] as List).cast<Map<String, Object?>>();
    expect(items.single['description'], '京东购物');
    expect(items.single['amountCents'], 12000);
  });

  test('pagination: out-of-range page keeps summary, empty items', () async {
    final json = run(await tool.execute({'page': 9, 'page_size': 2}));
    expect((json['transactions'] as List), isEmpty);
    expect(json['totalCount'], 5);
    expect((json['summary'] as Map)['count'], 5,
        reason: '超界页空而汇总不丢(spec FR-2)');
    expect(json['hasMore'], isFalse);

    final p2 = run(await tool.execute({'page': 2, 'page_size': 2}));
    expect((p2['transactions'] as List), hasLength(2), reason: '第 2 页 = 第 3/4 条');
    expect(p2['hasMore'], isTrue, reason: '还有第 3 页(共 5 条)');
  });

  test('invalid args → self-correcting ToolError (no throw)', () async {
    expect(await tool.execute({'start': 'not-a-date'}), isA<ToolError>());
    expect(await tool.execute({'direction': 'sideways'}), isA<ToolError>());
    final inverted = await tool.execute({
      'start': '2026-10-01',
      'end': '2026-09-01',
    });
    expect(inverted, isA<ToolError>(),
        reason: 'start > end 自纠(提示 LLM 调换)');
  });

  test('repository failure → ToolError, no throw', () async {
    final failing = _MockTxnRepo();
    when(() => failing.list(any())).thenAnswer(
        (_) async => const dz.Left(UnexpectedFailure('db down')));
    final result =
        await TransactionsSearchTool(failing, accountsRepo).execute(const {});
    expect(result, isA<ToolError>());
  });

  test('transactions_search legalCategories alignment guard vs AccountCategory',
      () async {
    // const enum 副本漂移即红(镜像 AccountsListTool.legalKinds M2 守卫)。
    expect(
        TransactionsSearchTool.legalCategories,
        [
          'savings',
          'creditCard',
          'investment',
          'fixedDeposit',
          'goldFx',
          'realEstate',
          'loan',
          'otherAsset',
          'otherLiability',
          'storedValue',
        ],
    );
  });
}
