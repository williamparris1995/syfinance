// F8 sprint-3 TDD:标签维度管道层 ——
//  - TagDao.transactionIdsForTag 反查(FR-1 / design ADR-1:junction 单点);
//  - TransactionLocalDataSource.list() tagId 过滤(FR-1 / ADR-2:F7 分类/搜索
//    之后插入;空集 = 无关联交易 → 空结果,与未传严格区分);
//  - summary 聚合前同过滤(FR-4,复用同一 TagDao 方法)+ repo 接口/impl
//    tagId 可选参透传(既有调用零改)。
// 夹具照抄 transaction_local_ds_list_query_test.dart(F7)的内存 drift 库 +
// 手工种子模式。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/data/transaction_repository_impl.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

class _MockTxnRemote extends Mock implements TransactionRemoteDataSource {}

void main() {
  late db.AppDatabase database;
  late TransactionLocalDataSource ds;
  late AccountDao accounts;

  setUp(() {
    database = db.AppDatabase(NativeDatabase.memory());
    ds = TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    accounts = database.accountDao;
  });

  tearDown(() => database.close());

  /// 种子账户:category 按备份契约存枚举 index + 1(account_local_ds 写入口径)。
  Future<String> seedAccount(
      String name, int type, AccountCategory category) async {
    final id = 'acc-$name';
    await accounts.insertAccount(db.AccountsCompanion.insert(
      id: id,
      name: name,
      accountType: type,
      category: category.index + 1,
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
    return id;
  }

  /// 种子交易:直接走 DS 写路径(recordTransaction),分录显式给定。
  Future<Transaction> seedTxn(DateTime date, String description,
      List<(String accountId, int debit, int credit)> legs) {
    return ds.recordTransaction(RecordTransactionParams(
      transactionDate: date,
      description: description,
      entries: [
        for (final leg in legs)
          TransactionEntry(
              accountId: leg.$1, debitCents: leg.$2, creditCents: leg.$3),
      ],
    ));
  }

  /// 种子标签:直接走 TagDao 写入口径(与 TagLocalDataSource.create 同构)。
  Future<String> seedTag(String name) async {
    final id = 'tag-$name';
    await database.tagDao.insertTag(db.TagsCompanion.insert(
      id: id,
      name: name,
      color: '#112233',
      version: 1,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    ));
    return id;
  }

  /// 种子联表:交易 ↔ 标签(junction 本地私有表,直插)。
  Future<void> linkTag(String txnId, String tagId) =>
      database.tagDao.insertTransactionTag(db.TransactionTagsCompanion.insert(
        transactionId: txnId,
        tagId: tagId,
      ));

  group('TagDao 反查(FR-1 / ADR-1 单点)', () {
    test('transactionIdsForTag:返回该标签全部关联 id;跨标签隔离;无关联→空集',
        () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final tagA = await seedTag('A');
      final tagB = await seedTag('B');
      final t1 = await seedTxn(DateTime.utc(2026, 8, 1), 'd1',
          [(cash, 100, 0), (cash, 0, 100)]);
      final t2 = await seedTxn(DateTime.utc(2026, 8, 2), 'd2',
          [(cash, 200, 0), (cash, 0, 200)]);
      await linkTag(t1.id, tagA);
      await linkTag(t2.id, tagA);
      await linkTag(t2.id, tagB); // t2 同时挂 A、B(多标签交易)

      // 挂 A 的全部关联交易(t1 + t2)。
      expect(await database.tagDao.transactionIdsForTag(tagA), {t1.id, t2.id});
      // 跨标签隔离:查 B 只见 t2,不见仅挂 A 的 t1。
      expect(await database.tagDao.transactionIdsForTag(tagB), {t2.id});
      // 无任何关联(含不存在的标签 id)→ 空集。
      expect(await database.tagDao.transactionIdsForTag('tag-none'), isEmpty);
    });
  });

  group('list tagId 过滤(FR-1 / ADR-2)', () {
    test('命中:仅关联该标签的交易;跨标签隔离;默认序照旧(日期降序)', () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final tagA = await seedTag('A');
      final tagB = await seedTag('B');
      final t1 = await seedTxn(DateTime.utc(2026, 8, 1), 'd1',
          [(cash, 100, 0), (cash, 0, 100)]);
      final t2 = await seedTxn(DateTime.utc(2026, 8, 2), 'd2',
          [(cash, 200, 0), (cash, 0, 200)]);
      // 无标签干扰项:不应命中任何 tagId 查询。
      await seedTxn(DateTime.utc(2026, 8, 3), 'd3',
          [(cash, 300, 0), (cash, 0, 300)]);
      await linkTag(t1.id, tagA);
      await linkTag(t2.id, tagA);
      await linkTag(t2.id, tagB);

      // 挂 A:t1、t2(默认序日期降序 → t2 在前);t3 无标签不命中。
      final byA = await ds.list(ListTransactionsParams(tagId: tagA));
      expect(byA.transactions.map((t) => t.id), [t2.id, t1.id]);
      expect(byA.totalCount, 2);

      // 跨标签隔离:查 B 仅 t2。
      final byB = await ds.list(ListTransactionsParams(tagId: tagB));
      expect(byB.transactions.map((t) => t.id), [t2.id]);
      expect(byB.totalCount, 1);
    });

    test('空集=空结果,与未传 tagId(全量)严格区分', () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final lonely = await seedTag('lonely'); // 标签存在但无任何关联
      final t1 = await seedTxn(DateTime.utc(2026, 8, 1), 'd1',
          [(cash, 100, 0), (cash, 0, 100)]);

      // 标签存在、junction 无行 → 关联集为空 → 空结果(非"不过滤")。
      final empty = await ds.list(ListTransactionsParams(tagId: lonely));
      expect(empty.transactions, isEmpty);
      expect(empty.totalCount, 0);

      // 未传 tagId = 不过滤,全量返回。
      final all = await ds.list(const ListTransactionsParams());
      expect(all.transactions.map((t) => t.id), [t1.id]);
      expect(all.totalCount, 1);
    });

    test('tagId × 搜索 × 分类 叠加(交集)', () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final card = await seedAccount('card', 1, AccountCategory.creditCard);
      final tagA = await seedTag('A');
      // 唯一命中:描述含 fee + 涉及 savings + 挂 A。
      final hit = await seedTxn(DateTime.utc(2026, 8, 1), 'lunch fee',
          [(cash, 100, 0), (cash, 0, 100)]);
      // 干扰①:标签/搜索命中,分类不命中(仅信用卡)。
      final d1 = await seedTxn(DateTime.utc(2026, 8, 2), 'card fee',
          [(card, 200, 0), (card, 0, 200)]);
      // 干扰②:搜索/分类命中,无标签。
      await seedTxn(DateTime.utc(2026, 8, 3), 'groceries fee',
          [(cash, 300, 0), (cash, 0, 300)]);
      // 干扰③:分类/标签命中,搜索不命中。
      final d3 = await seedTxn(DateTime.utc(2026, 8, 4), 'no match',
          [(cash, 400, 0), (cash, 0, 400)]);
      await linkTag(hit.id, tagA);
      await linkTag(d1.id, tagA);
      await linkTag(d3.id, tagA);

      final r = await ds.list(ListTransactionsParams(
        category: AccountCategory.savings,
        searchText: 'fee',
        tagId: tagA,
      ));
      expect(r.transactions.map((t) => t.id), [hit.id]);
      expect(r.totalCount, 1);
    });

    test('默认(无 tagId)逐位不变:不带 与 显式 tagId:null 序列逐位一致',
        () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final tagA = await seedTag('A');
      final seeded = [
        await seedTxn(DateTime.utc(2026, 8, 1), 'd1',
            [(cash, 100, 0), (cash, 0, 100)]),
        await seedTxn(DateTime.utc(2026, 8, 3), 'd3',
            [(cash, 300, 0), (cash, 0, 300)]),
        await seedTxn(DateTime.utc(2026, 8, 2), 's1',
            [(cash, 200, 0), (cash, 0, 200)]),
      ];
      // 部分交易挂标签:证明默认路径(未传 tagId)不受过滤影响。
      await linkTag(seeded[0].id, tagA);
      // 测试侧按现状规则(日期降序,id 降序)独立推导期望序。
      final expected = [...seeded]..sort((x, y) {
          final byDate = y.transactionDate.compareTo(x.transactionDate);
          return byDate != 0 ? byDate : y.id.compareTo(x.id);
        });

      final plain = await ds.list(const ListTransactionsParams());
      expect(plain.transactions.map((t) => t.id), expected.map((t) => t.id));

      // 显式传 tagId: null 与不传逐位一致(NFR:默认路径逐位不变)。
      final explicitNull =
          await ds.list(const ListTransactionsParams(tagId: null));
      expect(explicitNull.transactions.map((t) => t.id),
          plain.transactions.map((t) => t.id));
      expect(explicitNull.totalCount, plain.totalCount);
    });
  });

  group('summary tagId 口径(FR-4 / 聚合前过滤)', () {
    test('含标签交易计入、无标签剔出;byDay/dailyAvg 同口径;默认口径不变',
        () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final food = await seedAccount('food', 5, AccountCategory.savings);
      final salary = await seedAccount('salary', 4, AccountCategory.savings);
      final tagA = await seedTag('A');
      // 挂 A:支出 5000(08-21)+ 收入 800000(08-22)。
      final e1 = await ds.recordExpense(RecordExpenseParams(
        transactionDate: DateTime.utc(2026, 8, 21),
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 5000,
      ));
      final i1 = await ds.recordIncome(RecordIncomeParams(
        transactionDate: DateTime.utc(2026, 8, 22),
        assetAccountId: cash,
        incomeAccountId: salary,
        amountCents: 800000,
      ));
      // 无标签:支出 3000(与 e1 同日),应被剔出。
      await ds.recordExpense(RecordExpenseParams(
        transactionDate: DateTime.utc(2026, 8, 21),
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 3000,
      ));
      await linkTag(e1.id, tagA);
      await linkTag(i1.id, tagA);

      final s = await ds.summary(2026, 8, tagId: tagA);
      expect(s.incomeCents, 800000);
      expect(s.expenseCents, 5000); // 无标签的 3000 被剔出
      expect(s.netCents, 795000);
      expect(s.byDay.map((d) => d.date), ['2026-08-21', '2026-08-22']);
      // month 口径 dailyAvg = net / 活跃日数(标签集内 2 个活跃日)。
      expect(s.dailyAvgCents, 795000 ~/ 2);

      // 默认(无 tagId)口径不变:全量计入(既有调用零改)。
      final full = await ds.summary(2026, 8);
      expect(full.incomeCents, 800000);
      expect(full.expenseCents, 8000);
      expect(full.netCents, 792000);
    });

    test('空集标签 → 全零聚合(与未传区分)', () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final food = await seedAccount('food', 5, AccountCategory.savings);
      final lonely = await seedTag('lonely'); // 无任何关联
      await ds.recordExpense(RecordExpenseParams(
        transactionDate: DateTime.utc(2026, 8, 21),
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 5000,
      ));

      // 标签存在、关联集为空 → 空聚合(非"不过滤")。
      final s = await ds.summary(2026, 8, tagId: lonely);
      expect(s.incomeCents, 0);
      expect(s.expenseCents, 0);
      expect(s.netCents, 0);
      expect(s.byDay, isEmpty);
      expect(s.dailyAvgCents, 0);

      // 未传 = 全量。
      final full = await ds.summary(2026, 8);
      expect(full.expenseCents, 5000);
    });
  });

  group('repo 透传(F8 FR-4)', () {
    test('guest 路由 summary(tagId:) 落本地聚合,标签口径生效', () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final food = await seedAccount('food', 5, AccountCategory.savings);
      final tagA = await seedTag('A');
      final e1 = await ds.recordExpense(RecordExpenseParams(
        transactionDate: DateTime.utc(2026, 8, 21),
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 5000,
      ));
      await ds.recordExpense(RecordExpenseParams(
        transactionDate: DateTime.utc(2026, 8, 21),
        expenseAccountId: food,
        assetAccountId: cash,
        amountCents: 3000,
      ));
      await linkTag(e1.id, tagA);

      final repo = TransactionRepositoryImpl(
          _MockTxnRemote(), ds, SessionModeTracker()..isGuest = true);
      final result = await repo.summary(2026, 8, tagId: tagA);
      final s = result.fold((l) => throw StateError('expected Right'), (r) => r);
      expect(s.expenseCents, 5000); // tagId 透传到本地聚合,无标签剔出

      // 既有调用形态(不带 tagId)零改:全量。
      final full = await repo.summary(2026, 8);
      final fs =
          full.fold((l) => throw StateError('expected Right'), (r) => r);
      expect(fs.expenseCents, 8000);
    });
  });
}
