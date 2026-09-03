// F7 sprint-3 TDD:TransactionLocalDataSource.list() 查询四件套(domain+DS 层)
// 组合矩阵单测 —— 分类过滤(FR-1)/描述搜索(FR-2)/四态排序(FR-3)/默认序不变(NFR-1)。
// 夹具照抄 transaction_local_ds_test.dart 的模式:内存 drift 库 + 手工种子。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

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

  /// 种子交易:直接走 DS 写路径(recordTransaction),借方/贷方分录显式给定,
  /// 金额排序口径(Σdebit)由分录形态精确控制。
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

  group('分类过滤(FR-1)', () {
    test('任一 entry 涉及该分类账户即命中;跨分类交易从任一侧命中;不命中为空', () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final card = await seedAccount('card', 1, AccountCategory.creditCard);
      final invest = await seedAccount('invest', 1, AccountCategory.investment);
      // t1 跨分类:card × cash;t2:invest × cash;t3:仅 cash(不单独断言,靠
      // savings 命中总数覆盖)。
      final t1 = await seedTxn(DateTime.utc(2026, 8, 1), 'card payment',
          [(card, 3000, 0), (cash, 0, 3000)]);
      final t2 = await seedTxn(DateTime.utc(2026, 8, 2), 'buy fund',
          [(invest, 5000, 0), (cash, 0, 5000)]);
      await seedTxn(DateTime.utc(2026, 8, 3), 'cash only',
          [(cash, 100, 0), (cash, 0, 100)]);

      // 信用卡分类:仅 t1(card 侧)。
      final byCard = await ds.list(
          const ListTransactionsParams(category: AccountCategory.creditCard));
      expect(byCard.transactions.map((t) => t.id), [t1.id]);
      expect(byCard.totalCount, 1);

      // 投资分类:仅 t2(invest 侧)。
      final byInvest = await ds.list(
          const ListTransactionsParams(category: AccountCategory.investment));
      expect(byInvest.transactions.map((t) => t.id), [t2.id]);

      // 储蓄分类:t1/t2/t3 全部涉及(cash 侧)→ 跨分类交易从任一侧命中。
      final bySavings = await ds.list(
          const ListTransactionsParams(category: AccountCategory.savings));
      expect(bySavings.totalCount, 3);

      // 不命中:夹具里没有贷款分类账户的交易。
      final byLoan = await ds.list(
          const ListTransactionsParams(category: AccountCategory.loan));
      expect(byLoan.transactions, isEmpty);
      expect(byLoan.totalCount, 0);
    });
  });

  group('描述搜索(FR-2)', () {
    test('contains 命中、大小写不敏感、空串/空白/null 不过滤、空描述不误命中', () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final lunch = await seedTxn(DateTime.utc(2026, 8, 1), '公司食堂 午餐',
          [(cash, 2500, 0), (cash, 0, 2500)]);
      final nf1 = await seedTxn(DateTime.utc(2026, 8, 2), 'Netflix Subscription',
          [(cash, 1500, 0), (cash, 0, 1500)]);
      final nf2 = await seedTxn(DateTime.utc(2026, 8, 3), 'netflix gift card',
          [(cash, 3000, 0), (cash, 0, 3000)]);
      // 空 description(与 null description 同口径:视空串)。
      await seedTxn(
          DateTime.utc(2026, 8, 4), '', [(cash, 100, 0), (cash, 0, 100)]);

      // 中文 contains 命中。
      var r = await ds
          .list(const ListTransactionsParams(searchText: '午餐'));
      expect(r.transactions.map((t) => t.id), [lunch.id]);

      // 大小写不敏感:大写查询命中两笔大小写各异的 netflix(默认序日期降序)。
      r = await ds.list(const ListTransactionsParams(searchText: 'NETFLIX'));
      expect(r.transactions.map((t) => t.id), [nf2.id, nf1.id]);

      // 查询两侧空白先 trim 再匹配(与"非空非空白才生效"同一口径)。
      r = await ds.list(const ListTransactionsParams(searchText: '  netflix  '));
      expect(r.transactions.map((t) => t.id), [nf2.id, nf1.id]);

      // 空串 / 纯空白 / null = 不过滤。
      r = await ds.list(const ListTransactionsParams(searchText: ''));
      expect(r.totalCount, 4);
      r = await ds.list(const ListTransactionsParams(searchText: '   '));
      expect(r.totalCount, 4);
      r = await ds.list(const ListTransactionsParams());
      expect(r.totalCount, 4);

      // 非空查询下,空描述(=null 口径空串)不误命中。
      r = await ds.list(const ListTransactionsParams(searchText: 'netflix'));
      expect(r.totalCount, 2);
    });
  });

  group('排序四态(FR-3)', () {
    test('date asc/desc:方向随 sortDir,同日 tie 恒 id DESC', () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final a = await seedTxn(DateTime.utc(2026, 8, 1), 'd1',
          [(cash, 100, 0), (cash, 0, 100)]);
      final b = await seedTxn(DateTime.utc(2026, 8, 3), 'd3',
          [(cash, 100, 0), (cash, 0, 100)]);
      // 同日两笔:id 大者在前(tie-break 恒 id DESC)。
      final s1 = await seedTxn(DateTime.utc(2026, 8, 2), 's1',
          [(cash, 100, 0), (cash, 0, 100)]);
      final s2 = await seedTxn(DateTime.utc(2026, 8, 2), 's2',
          [(cash, 100, 0), (cash, 0, 100)]);
      final laterSameDay = s1.id.compareTo(s2.id) > 0 ? s1 : s2;
      final earlierSameDay = laterSameDay == s1 ? s2 : s1;

      final desc = await ds.list(const ListTransactionsParams(
          sortKey: TxnSortKey.date, sortDir: TxnSortDir.desc));
      expect(desc.transactions.map((t) => t.id),
          [b.id, laterSameDay.id, earlierSameDay.id, a.id]);

      final asc = await ds.list(const ListTransactionsParams(
          sortKey: TxnSortKey.date, sortDir: TxnSortDir.asc));
      expect(asc.transactions.map((t) => t.id),
          [a.id, laterSameDay.id, earlierSameDay.id, b.id]);
    });

    test('amount asc/desc:按 Σdebit 比较(转账/复合交易口径,ADR-3)', () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final card = await seedAccount('card', 1, AccountCategory.creditCard);
      // 转账 100:一对分录 Σdebit=100。
      final small = await seedTxn(DateTime.utc(2026, 8, 1), 'transfer',
          [(card, 100, 0), (cash, 0, 100)]);
      // 复合 500:debit 300 + debit 200 / credit 500 → Σdebit=500。
      final mid = await seedTxn(DateTime.utc(2026, 8, 2), 'compound',
          [(card, 300, 0), (cash, 200, 0), (cash, 0, 500)]);
      // 复合 900:debit 400 + debit 500 / credit 900 → Σdebit=900。
      final big = await seedTxn(DateTime.utc(2026, 8, 3), 'compound2',
          [(card, 400, 0), (cash, 500, 0), (cash, 0, 900)]);

      final desc = await ds.list(const ListTransactionsParams(
          sortKey: TxnSortKey.amount, sortDir: TxnSortDir.desc));
      expect(desc.transactions.map((t) => t.id), [big.id, mid.id, small.id]);

      final asc = await ds.list(const ListTransactionsParams(
          sortKey: TxnSortKey.amount, sortDir: TxnSortDir.asc));
      expect(asc.transactions.map((t) => t.id), [small.id, mid.id, big.id]);
    });

    test('amount 同额 tie-break:恒 transactionDate DESC + id DESC,不随方向翻转',
        () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      // 四笔等额(Σdebit=500),日期 08-01 / 08-02 / 08-03×2。
      final a = await seedTxn(DateTime.utc(2026, 8, 1), 'a',
          [(cash, 500, 0), (cash, 0, 500)]);
      final b = await seedTxn(DateTime.utc(2026, 8, 2), 'b',
          [(cash, 500, 0), (cash, 0, 500)]);
      final s1 = await seedTxn(DateTime.utc(2026, 8, 3), 's1',
          [(cash, 500, 0), (cash, 0, 500)]);
      final s2 = await seedTxn(DateTime.utc(2026, 8, 3), 's2',
          [(cash, 500, 0), (cash, 0, 500)]);
      final laterSameDay = s1.id.compareTo(s2.id) > 0 ? s1 : s2;
      final earlierSameDay = laterSameDay == s1 ? s2 : s1;
      // 期望序(主键全平 → tie-break 恒定):08-03 id DESC → 08-02 → 08-01。
      final expected = [
        laterSameDay.id,
        earlierSameDay.id,
        b.id,
        a.id,
      ];

      final desc = await ds.list(const ListTransactionsParams(
          sortKey: TxnSortKey.amount, sortDir: TxnSortDir.desc));
      expect(desc.transactions.map((t) => t.id), expected);

      // 方向翻转只作用于主键;同额 tie 序保持不变(恒定稳定序)。
      final asc = await ds.list(const ListTransactionsParams(
          sortKey: TxnSortKey.amount, sortDir: TxnSortDir.asc));
      expect(asc.transactions.map((t) => t.id), expected);
    });
  });

  group('默认序不变(NFR-1)', () {
    test('不带新参数 与 显式默认参数 序列逐位一致,且= transactionDate DESC, id DESC',
        () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final seeded = [
        await seedTxn(DateTime.utc(2026, 8, 1), 'd1',
            [(cash, 100, 0), (cash, 0, 100)]),
        await seedTxn(DateTime.utc(2026, 8, 3), 'd3',
            [(cash, 300, 0), (cash, 0, 300)]),
        await seedTxn(DateTime.utc(2026, 8, 2), 's1',
            [(cash, 200, 0), (cash, 0, 200)]),
        await seedTxn(DateTime.utc(2026, 8, 2), 's2',
            [(cash, 200, 0), (cash, 0, 200)]),
      ];
      // 测试侧按现状规则(日期降序,id 降序)独立推导期望序。
      final expected = [...seeded]..sort((x, y) {
          final byDate = y.transactionDate.compareTo(x.transactionDate);
          return byDate != 0 ? byDate : y.id.compareTo(x.id);
        });

      final plain = await ds.list(const ListTransactionsParams());
      expect(plain.transactions.map((t) => t.id), expected.map((t) => t.id));

      // 显式传默认参数(含新字段默认值)与不传逐位一致。
      final explicit = await ds.list(const ListTransactionsParams(
        category: null,
        searchText: null,
        sortKey: TxnSortKey.date,
        sortDir: TxnSortDir.desc,
      ));
      expect(explicit.transactions.map((t) => t.id), plain.transactions.map((t) => t.id));
    });
  });

  group('组合:分类×搜索×排序×分页', () {
    test('savings × fee × 金额降序 × pageSize=2 两页翻完', () async {
      final cash = await seedAccount('cash', 1, AccountCategory.savings);
      final invest = await seedAccount('invest', 1, AccountCategory.investment);
      // 三笔命中:涉及 savings + 描述含 fee,金额 100/500/900。
      final small = await seedTxn(DateTime.utc(2026, 8, 1), 'bank fee',
          [(cash, 100, 0), (cash, 0, 100)]);
      final mid = await seedTxn(DateTime.utc(2026, 8, 2), 'annual fee',
          [(cash, 500, 0), (cash, 0, 500)]);
      final big = await seedTxn(DateTime.utc(2026, 8, 3), 'transfer fee',
          [(cash, 900, 0), (cash, 0, 900)]);
      // 干扰项①:描述不含 fee。
      await seedTxn(DateTime.utc(2026, 8, 4), 'groceries',
          [(cash, 700, 0), (cash, 0, 700)]);
      // 干扰项②:描述含 fee 但不涉及 savings(被分类过滤掉)。
      await seedTxn(DateTime.utc(2026, 8, 5), 'invest fee',
          [(invest, 600, 0), (invest, 0, 600)]);

      final page1 = await ds.list(const ListTransactionsParams(
        category: AccountCategory.savings,
        searchText: 'fee',
        sortKey: TxnSortKey.amount,
        sortDir: TxnSortDir.desc,
        pageSize: 2,
      ));
      expect(page1.transactions.map((t) => t.id), [big.id, mid.id]);
      expect(page1.totalCount, 3);
      expect(page1.hasMore, isTrue);
      expect(page1.nextPageToken, '2');

      final page2 = await ds.list(ListTransactionsParams(
        category: AccountCategory.savings,
        searchText: 'fee',
        sortKey: TxnSortKey.amount,
        sortDir: TxnSortDir.desc,
        pageSize: 2,
        pageToken: page1.nextPageToken,
      ));
      expect(page2.transactions.map((t) => t.id), [small.id]);
      expect(page2.hasMore, isFalse);
      expect(page2.nextPageToken, '');
    });
  });
}
