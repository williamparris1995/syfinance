// F70-T1 TDD RED → GREEN:transaction_add 写工具(ADR-1 两段执行)。
// execute 一律返回 requiresApproval ToolData(解析后 WriteAction 内部 id +
// preview 摘要)零落库;真库夹具镜像 transactions_search_tool_test(内存
// drift + guest 路由真实 repo),名称→id 解析/消歧/参数面/零写断言。
import 'package:dartz/dartz.dart' as dz;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/data/account_remote_ds.dart';
import 'package:yucai_client/account/data/account_repository_impl.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/assistant/data/tools/transaction_add_tool.dart';
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

class _MockAccountRepo extends Mock implements AccountRepository {}

class _FakeCreateAccountParams extends Fake implements CreateAccountParams {}

class _FakeUpdateAccountParams extends Fake implements UpdateAccountParams {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeCreateAccountParams());
    registerFallbackValue(_FakeUpdateAccountParams());
  });

  late db.AppDatabase database;
  late TransactionRepository txnsRepo;
  late AccountRepository accountsRepo;
  late TransactionAddTool tool;

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

    // 资产/负债户(付款载体)+ 分类账户(支出/收入,category=8 otherAsset
    // 与分类页建户同值)+ 同名「现金」双户(消歧用)。
    await seedAccount('acc-cash', '现金', type: 1, category: 1, balance: 1000000);
    await seedAccount('acc-cash2', '现金', type: 1, category: 1);
    await seedAccount('acc-card', '招行信用卡', type: 2, category: 2);
    await seedAccount('acc-food', '餐饮', type: 5, category: 8);
    await seedAccount('acc-transport', '交通', type: 5, category: 8);
    await seedAccount('acc-salary', '工资', type: 4, category: 8);
    await seedAccount('acc-bonus', '奖金', type: 4, category: 8);

    // 一笔既有交易:零写断言的「前后笔数不变」基准。
    await local.recordExpense(RecordExpenseParams(
      transactionDate: DateTime(2026, 9, 1),
      expenseAccountId: 'acc-food',
      assetAccountId: 'acc-cash',
      amountCents: 5000,
      description: '美团外卖',
    ));

    tool = TransactionAddTool(
      accountsRepo,
      () => DateTime(2026, 10, 27, 15, 30),
    );
  });

  tearDown(() => database.close());

  Map<String, Object?> ok(ToolResult r) => (r as ToolData).json;

  Future<int> txnCount() async => (await txnsRepo
          .list(const ListTransactionsParams(pageSize: 500)))
      .fold((l) => -1, (r) => r.transactions.length);

  group('解析全流程(名称→内部 id,零落库)', () {
    test('支出:账户/分类名称解析为 id,direction=out,金额元转 cents', () async {
      final before = await txnCount();
      final result = await tool.execute(const {
        'direction': 'out',
        'amount': 35,
        'description': '午饭',
        'account': '招行信用卡',
        'category': '餐饮',
        'date': '2026-10-26',
      });

      final json = ok(result);
      expect(json['requiresApproval'], isTrue, reason: 'ADR-1:一律待确认');
      expect(json['action'], {
        'type': 'transaction_add',
        'direction': 'out',
        'amountCents': 3500,
        'description': '午饭',
        'accountId': 'acc-card',
        'categoryId': 'acc-food',
        'date': '2026-10-26',
      });
      final preview = json['preview'] as Map<String, Object?>;
      expect(preview['direction'], 'out');
      expect(preview['amountCents'], 3500);
      expect(preview['amountYuan'], '35.00');
      expect(preview['description'], '午饭');
      expect(preview['account'], '招行信用卡');
      expect(preview['category'], '餐饮');
      expect(preview['date'], '2026-10-26');

      expect(await txnCount(), before, reason: '提案零落库');
    });

    test('收入:direction=in 分类解析到 income 账户', () async {
      final json = ok(await tool.execute(const {
        'direction': 'in',
        'amount': 8000,
        'description': '工资',
        'account': '招行信用卡',
        'category': '工资',
      }));
      expect((json['action'] as Map)['direction'], 'in');
      expect((json['action'] as Map)['categoryId'], 'acc-salary');
      expect((json['action'] as Map)['accountId'], 'acc-card');
      expect((json['preview'] as Map)['date'], '2026-10-27',
          reason: '日期缺省今天(clock 注入)');
    });

    test('金额 lenient:小数/字符串/千分位均可(元 → cents 四舍五入)', () async {
      for (final (raw, cents) in [
        (35.5, 3550),
        ('40', 4000),
        ('1,000', 100000),
        (0.01, 1),
      ]) {
        final json = ok(await tool.execute({
          'direction': 'out',
          'amount': raw,
          'description': 'x',
          'account': '招行信用卡',
          'category': '交通',
        }));
        expect((json['action'] as Map)['amountCents'], cents,
            reason: 'amount=$raw');
      }
    });
  });

  group('direction 枚举自纠', () {
    test('大小写不敏感(IN → in);非法值列合法值', () async {
      final json = ok(await tool.execute(const {
        'direction': 'IN',
        'amount': 1,
        'description': 'x',
        'account': '招行信用卡',
        'category': '奖金',
      }));
      expect((json['action'] as Map)['direction'], 'in');

      final bad = await tool.execute(const {
        'direction': 'sideways',
        'amount': 1,
        'description': 'x',
        'account': '招行信用卡',
        'category': '餐饮',
      });
      expect(bad, isA<ToolError>());
      expect((bad as ToolError).message, contains('in, out'));
    });

    test('缺失 direction → ToolError(必填)', () async {
      final result = await tool.execute(const {
        'amount': 1,
        'description': 'x',
        'account': '招行信用卡',
        'category': '餐饮',
      });
      expect(result, isA<ToolError>());
    });
  });

  group('名称解析与消歧(澄清原则)', () {
    test('account 缺失 → ToolError 引导 accounts_list 后问用户', () async {
      final result = await tool.execute(const {
        'direction': 'out',
        'amount': 35,
        'description': '午饭',
        'category': '餐饮',
      });
      expect(result, isA<ToolError>());
      expect((result as ToolError).message, contains('accounts_list'));
    });

    test('account 未知 → ToolError(查无引导,FR-4)', () async {
      final result = await tool.execute(const {
        'direction': 'out',
        'amount': 35,
        'description': '午饭',
        'account': '不存在的卡',
        'category': '餐饮',
      });
      expect(result, isA<ToolError>());
      expect((result as ToolError).message, contains('accounts_list'));
    });

    test('account 多候选(同名「现金」×2)→ ToolError 列候选', () async {
      final result = await tool.execute(const {
        'direction': 'out',
        'amount': 35,
        'description': '午饭',
        'account': '现金',
        'category': '餐饮',
      });
      expect(result, isA<ToolError>());
      expect((result as ToolError).message, contains('现金'));
    });

    test('category 缺失 → ToolError 列当前方向全部分类账户(让 LLM 选/问)',
        () async {
      final result = await tool.execute(const {
        'direction': 'out',
        'amount': 35,
        'description': '午饭',
        'account': '招行信用卡',
      });
      expect(result, isA<ToolError>());
      final msg = (result as ToolError).message;
      expect(msg, contains('餐饮'));
      expect(msg, contains('交通'));
      expect(msg, isNot(contains('工资')), reason: 'out 只列支出分类');
    });

    test('category 与方向不符(收入给了支出分类)→ ToolError', () async {
      final result = await tool.execute(const {
        'direction': 'in',
        'amount': 100,
        'description': '奖金',
        'account': '招行信用卡',
        'category': '餐饮',
      });
      expect(result, isA<ToolError>());
    });
  });

  group('参数面自纠(非法值 → ToolError,零异常)', () {
    test('amount 垃圾/<=0/缺失 → ToolError', () async {
      for (final amount in ['abc', 0, -5, null]) {
        final args = <String, Object>{
          'direction': 'out',
          'description': 'x',
          'account': '招行信用卡',
          'category': '餐饮',
          if (amount != null) 'amount': amount,
        };
        final result = await tool.execute(args);
        expect(result, isA<ToolError>(), reason: 'amount=$amount');
      }
    });

    test('date 非法 → ToolError;合法 ISO 缺省今天', () async {
      final bad = await tool.execute(const {
        'direction': 'out',
        'amount': 35,
        'description': 'x',
        'account': '招行信用卡',
        'category': '餐饮',
        'date': 'not-a-date',
      });
      expect(bad, isA<ToolError>());

      final json = ok(await tool.execute(const {
        'direction': 'out',
        'amount': 35,
        'description': 'x',
        'account': '招行信用卡',
        'category': '餐饮',
      }));
      expect((json['action'] as Map)['date'], '2026-10-27');
    });

    test('空参数 → ToolError(不炸)', () async {
      expect(await tool.execute(const {}), isA<ToolError>());
    });
  });

  group('零写断言(ADR-1:execute 永不落库)', () {
    test('真实 repo:成功提案后交易笔数不变', () async {
      final before = await txnCount();
      await tool.execute(const {
        'direction': 'out',
        'amount': 35,
        'description': '午饭',
        'account': '招行信用卡',
        'category': '餐饮',
      });
      expect(await txnCount(), before);
    });

    test('mock repo verifyNever:账户仓储写方法零调用', () async {
      final mock = _MockAccountRepo();
      when(() => mock.list()).thenAnswer(
        (_) async => const dz.Right([
          Account(
            id: 'acc-card',
            name: '招行信用卡',
            accountType: AccountType.liability,
            category: AccountCategory.creditCard,
            currencyCode: 'CNY',
            initialBalanceCents: 0,
            currentBalanceCents: 0,
            ownership: Ownership.personal,
            status: AccountStatus.active,
          ),
          Account(
            id: 'acc-food',
            name: '餐饮',
            accountType: AccountType.expense,
            category: AccountCategory.otherAsset,
            currencyCode: 'CNY',
            initialBalanceCents: 0,
            currentBalanceCents: 0,
            ownership: Ownership.personal,
            status: AccountStatus.active,
          ),
        ]),
      );

      final result = await TransactionAddTool(mock).execute(const {
        'direction': 'out',
        'amount': 35,
        'description': '午饭',
        'account': '招行信用卡',
        'category': '餐饮',
      });

      expect(result, isA<ToolData>(), reason: 'mock 正常提案');
      verifyNever(() => mock.create(any()));
      verifyNever(() => mock.update(any()));
      verifyNever(() => mock.delete(any()));
    });

    test('账户仓储失败 → ToolError(不炸)', () async {
      final mock = _MockAccountRepo();
      when(() => mock.list())
          .thenAnswer((_) async => const dz.Left(UnexpectedFailure('db down')));
      expect(
        await TransactionAddTool(mock).execute(const {
          'direction': 'out',
          'amount': 1,
          'account': 'x',
          'category': 'y',
        }),
        isA<ToolError>(),
      );
    });
  });

  test('参数面 ≤8 项(NFR-2)', () {
    expect(tool.parametersSchema['properties'], isA<Map>());
    expect(
      (tool.parametersSchema['properties'] as Map).length,
      lessThanOrEqualTo(8),
    );
    expect(tool.name, 'transaction_add');
  });
}
