// TDD RED → GREEN:F9-T3 持仓 DS 查询能力(listPaged:搜索 + 分页)单测。
//
// F9 FR-3 / ADR-3:照 F7 in-memory 管道给 HoldingLocalDataSource 增可选查询
// 参数 —— searchText(标的 symbol/name contains 忽略大小写)+ pageSize/
// pageToken(offset 语义,含 nextToken 返回)。默认路径零变化(NFR-2):不带
// 参数时输出与既有 listHoldings 一致。
//
// 夹具:内存 drift 库 + 3 只持仓(经 buy 建仓 + updateSecurityPrice 定价),
// 市值刻意拉开(AAPL 2000万 > ETF 45万 > GOLD 10万)以断言「按市值降序」的
// DS 基准序(offset 分页需要确定性全序)。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/account_dao.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

void main() {
  late db.AppDatabase database;
  late HoldingLocalDataSource holding;
  late AccountDao accounts;
  String cash = '';
  String inv = '';

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    final txns =
        TransactionLocalDataSource(database, BalanceLocalUpdater(database));
    holding = HoldingLocalDataSource(database, txns);
    accounts = database.accountDao;

    Future<String> seedAccount(String name, int type, int balance) async {
      final id = 'acc-$name';
      await accounts.insertAccount(db.AccountsCompanion.insert(
        id: id,
        name: name,
        accountType: type,
        category: 2,
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

    cash = await seedAccount('cash', 1, 300000000); // ¥300 万
    inv = await seedAccount('inv', 1, 0);

    // 3 只持仓:市值 2000 万 / 45 万 / 10 万(原币 CNY)。
    Future<void> seed(String symbol, String name, double qty, int price) async {
      final sec = await holding.createSecurity(
          symbol: symbol, name: name, type: SecurityType.stock, currency: 'CNY');
      await holding.updateSecurityPrice(id: sec.id, priceCents: price);
      await holding.buy(
        accountId: inv,
        securityId: sec.id,
        fromAccountId: cash,
        quantity: qty,
        priceCents: price,
        tradeDate: '2026-08-01',
      );
    }

    await seed('AAPL', 'Apple Inc.', 100, 2000000); // mv 2000 万
    await seed('510300', '沪深300ETF', 1000, 450); // mv 45 万
    await seed('600519', '贵州茅台', 10, 10000); // mv 10 万
  });

  tearDown(() => database.close());

  group('F9-T3 listPaged 默认路径(NFR-2 零变化)', () {
    test('无参数:返回全部持仓,按市值降序,与 listHoldings 同集', () async {
      final page = await holding.listPaged();
      expect(page.holdings, hasLength(3));
      expect(page.totalCount, 3);
      expect(page.nextPageToken, '');
      // DS 基准序 = 市值降序(offset 分页需确定性全序;口径注释见实现)。
      expect(page.holdings.map((h) => h.securitySymbol).toList(),
          ['AAPL', '510300', '600519']);
      // 与既有 list 不带参路径同集(默认 pageSize 100 不截断)。
      final legacy = await holding.listHoldings();
      expect(page.holdings.map((h) => h.id).toSet(),
          legacy.map((h) => h.id).toSet());
    });

    test('accountId 作用域沿用(与 listHoldings 同语义)', () async {
      final page = await holding.listPaged(accountId: 'acc-none');
      expect(page.holdings, isEmpty);
      expect(page.totalCount, 0);
    });
  });

  group('F9-T3 listPaged searchText(symbol/name contains 忽略大小写)', () {
    test('symbol 命中(小写查询命中大写 symbol)', () async {
      final page = await holding.listPaged(searchText: 'aapl');
      expect(page.holdings.map((h) => h.securitySymbol), ['AAPL']);
    });

    test('name 命中(英文名片段)', () async {
      final page = await holding.listPaged(searchText: 'apple');
      expect(page.holdings.map((h) => h.securitySymbol), ['AAPL']);
    });

    test('name 命中(中文名片段)', () async {
      final page = await holding.listPaged(searchText: '茅台');
      expect(page.holdings.map((h) => h.securitySymbol), ['600519']);
    });

    test('未命中返回空 + 空白/_null 不过滤', () async {
      expect((await holding.listPaged(searchText: 'zzz')).holdings, isEmpty);
      expect((await holding.listPaged(searchText: '  ')).holdings, hasLength(3));
      expect((await holding.listPaged(searchText: null)).holdings, hasLength(3));
    });
  });

  group('F9-T3 listPaged 分页(offset pageToken,照 F7 语义)', () {
    test('pageSize=2:第 1 页 2 条 + nextToken;翻页取剩余;末页 token 空', () async {
      final p1 = await holding.listPaged(pageSize: 2);
      expect(p1.holdings.map((h) => h.securitySymbol).toList(),
          ['AAPL', '510300']);
      expect(p1.totalCount, 3);
      expect(p1.nextPageToken, '2');

      final p2 = await holding.listPaged(pageSize: 2, pageToken: '2');
      expect(p2.holdings.map((h) => h.securitySymbol).toList(), ['600519']);
      expect(p2.totalCount, 3);
      expect(p2.nextPageToken, '');
    });

    test('越界 pageToken:返回空页,不越界不抛', () async {
      final page = await holding.listPaged(pageSize: 2, pageToken: '99');
      expect(page.holdings, isEmpty);
      expect(page.nextPageToken, '');
    });

    test('pageSize<=0 回退默认 100(照 F7 口径)', () async {
      final page = await holding.listPaged(pageSize: 0);
      expect(page.holdings, hasLength(3));
    });

    test('搜索 + 分页叠加:先过滤后分页,token 作用于过滤后集合', () async {
      // 搜索 '0'(命中 510300/600519,AAPL 无 0)后 pageSize=1:第 1 页 510300
      //(mv 45 万 > 10 万),第 2 页 600519。
      final p1 = await holding.listPaged(searchText: '0', pageSize: 1);
      expect(p1.holdings.map((h) => h.securitySymbol).toList(), ['510300']);
      expect(p1.totalCount, 2);
      final p2 =
          await holding.listPaged(searchText: '0', pageSize: 1, pageToken: '1');
      expect(p2.holdings.map((h) => h.securitySymbol).toList(), ['600519']);
      expect(p2.nextPageToken, '');
    });
  });
}
