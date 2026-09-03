/// F9 FR-6 管道链 E2E:三模块列表查询能力 DS 直调断言(管道链路,真实本地
/// 数据源)。
///
/// - 统链① 持仓 `listPaged`(F9 FR-3):搜索(symbol/name contains 忽略大小写)
///   + 市值降序全序(含同市值 tie → symbol 升序)+ pageSize=2 分页 token 语义
///   (数字 offset,拼接 = 全量、越界空页)。
/// - 统链② 债务 `list`(F9 FR-4):默认(无参)= DAO 行序零变化(raw drift
///   交叉核对 + 插入序前缀守卫)+ counterparty 搜索(忽略大小写)+ 金额/到期
///   四态全序(口径 = domain 纯函数 debtCompareQuery,页面同源)。
/// - 账户搜索为页面层实现(FR-5,不动 DS/repo 契约),管道侧免 DS 断言 ——
///   UI 级抽验见 ui_list_unify_test.dart 统UI④。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/link_list_unify_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/domain/debt_query.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late HoldingLocalDataSource holdings;
  late DebtLocalDataSource debts;

  late String investId; // 统链证券账户(持仓夹具专属,与 demo 证券账户隔离)

  // ---- 持仓夹具 oracle(统链* 前缀;createSecurity 后 currentPrice=0 →
  // marketValue = qty×avgCost = amount,fee=0 时 avgCost = priceCents)----
  //   插入序(= DAO 行序):一号..五号;市值(分):
  //     一号 F9uniOne   10 × 10,000 = 100,000(与五号同额 → tie 验 symbol 升序)
  //     二号 F9uniTwo   20 ×  8,000 = 160,000
  //     三号 F9uniThree 30 ×  5,000 = 150,000
  //     四号 F9uniFour  40 ×  3,000 = 120,000
  //     五号 F9uniFive  50 ×  2,000 = 100,000
  //   市值降序全序:[二号 160k, 三号 150k, 四号 120k, 五号 100k, 一号 100k]
  //   (tie 段 symbol 升序:'F9uniFive' < 'F9uniOne')。
  // ---- 债务夹具 oracle(统链* 前缀,borrowedIn + lumpSum + 无还款 →
  // remaining = total,全部未结清;不传 sourceAccountId → 不产生复式交易)----
  //   插入序(= DAO 行序):甲..丁;金额(分)/到期:
  //     甲 统链Bank甲 500,000  due 2027-03-01(counterparty 带 ASCII 段供忽略大小写断言)
  //     乙 统链债乙   900,000  due 2026-12-01
  //     丙 统链债丙   300,000  due 2027-06-01
  //     丁 统链债丁   700,000  due 2026-10-01
  //   金额序与到期序刻意反相关(四态各有唯一全序):
  //     金额降序 [乙,丁,甲,丙] / 金额升序 [丙,甲,丁,乙]
  //     到期升序 [丁,乙,甲,丙] / 到期降序 [丙,甲,乙,丁]
  late String debt1Id, debt2Id, debt3Id, debt4Id;

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(照 link_holding_buy_test)。
    await resetTestDb();
    db = getIt<AppDatabase>();
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    holdings = HoldingLocalDataSource(db, txns);
    debts =
        DebtLocalDataSource(db, TransactionLocalDataSource(db, BalanceLocalUpdater(db)));
    final accounts = AccountLocalDataSource(db);

    // ---- 持仓夹具(统链* 前缀,独立投资账户与 demo 持仓隔离) ----
    // 资金 ¥10,000(1,000,000 分)覆盖 5 笔买入合计 ¥6,300(630,000 分)。
    final fundsId = await fundsAccount('统链资金', 1000000);
    final invest = await accounts.create(const CreateAccountParams(
      name: '统链证券账户',
      accountType: AccountType.asset,
      category: AccountCategory.investment,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    investId = invest.id;
    Future<void> buyOne(String symbol, String name, double qty, int priceCents) async {
      final sec = await holdings.createSecurity(
        symbol: symbol,
        name: name,
        type: SecurityType.fund,
        exchange: 'CN',
        currency: 'CNY',
      );
      await holdings.buy(
        accountId: investId,
        securityId: sec.id,
        fromAccountId: fundsId,
        quantity: qty,
        priceCents: priceCents,
        tradeDate: '2026-08-20',
      );
    }

    await buyOne('F9uniOne', '统链一号', 10, 10000); // 市值 100,000 分
    await buyOne('F9uniTwo', '统链二号', 20, 8000); // 160,000
    await buyOne('F9uniThree', '统链三号', 30, 5000); // 150,000
    await buyOne('F9uniFour', '统链四号', 40, 3000); // 120,000
    await buyOne('F9uniFive', '统链五号', 50, 2000); // 100,000(与一号同额 tie)

    // ---- 债务夹具(统链* 前缀;lumpSum 单期,零利率 → schedule 单条本金) ----
    final loanAcc = await accounts.create(const CreateAccountParams(
      name: '统链负债账户',
      accountType: AccountType.liability,
      category: AccountCategory.loan,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    Future<String> createDebt(String counterparty, int principal, DateTime due) async {
      final d = await debts.create(
        accountId: loanAcc.id,
        counterparty: counterparty,
        interestRate: 0,
        amortizationIndex: 2, // lumpSum(AmortizationMethod.lumpSum.index)
        startDate: DateTime.utc(2026, 9, 1),
        dueDate: due,
        totalPrincipalCents: principal,
        type: DebtType.borrowedIn,
      );
      return d.id;
    }

    debt1Id = await createDebt('统链Bank甲', 500000, DateTime.utc(2027, 3, 1));
    debt2Id = await createDebt('统链债乙', 900000, DateTime.utc(2026, 12, 1));
    debt3Id = await createDebt('统链债丙', 300000, DateTime.utc(2027, 6, 1));
    debt4Id = await createDebt('统链债丁', 700000, DateTime.utc(2026, 10, 1));
  });

  tearDownAll(deleteTestDb);

  testWidgets('统链①持仓 listPaged:搜索忽略大小写 + 市值降序全序 + pageSize=2 分页 token',
      (t) async {
    // ---- ① 默认(仅 accountId 作用域,pageSize 100):市值降序全序 oracle ----
    // [二号 160k, 三号 150k, 四号 120k, 五号 100k, 一号 100k];tie 段(100k)
    // symbol 升序:F9uniFive 先于 F9uniOne。
    final base = await holdings.listPaged(accountId: investId);
    expect(base.totalCount, 5, reason: 'totalCount = 作用域内全量(非本页数)');
    expect(base.nextPageToken, '', reason: '整集一页取尽 → 无 token');
    expect(base.holdings.map((h) => h.securityName).toList(),
        ['统链二号', '统链三号', '统链四号', '统链五号', '统链一号'],
        reason: '市值降序全序;同额 tie(一号/五号 各 100,000 分)按 symbol 升序');
    // 市值口径手算钉死(无现价 → qty×avgCost = amount)。
    expect(base.holdings.map((h) => h.marketValueCents).toList(),
        [160000, 150000, 120000, 100000, 100000],
        reason: 'oracle:20×8,000 / 30×5,000 / 40×3,000 / 50×2,000 / 10×10,000');

    // ---- ② 搜索:symbol contains 忽略大小写(ASCII 段) ----
    final bySymbolUpper = await holdings.listPaged(
        accountId: investId, searchText: 'F9UNITWO');
    expect(bySymbolUpper.totalCount, 1);
    expect(bySymbolUpper.holdings.single.securitySymbol, 'F9uniTwo',
        reason: '搜索忽略大小写:F9UNITWO 命中 F9uniTwo');
    // name contains(中文段)。
    final byName = await holdings.listPaged(accountId: investId, searchText: '统链三');
    expect(byName.holdings.map((h) => h.securityName).toList(), ['统链三号'],
        reason: '搜索命中 name(contains)');

    // ---- ③ 搜索无命中 → 空集 + totalCount 0(demo 持仓不含「统链」) ----
    final miss = await holdings.listPaged(
        accountId: investId, searchText: '统链无此串');
    expect(miss.holdings, isEmpty);
    expect(miss.totalCount, 0);
    expect(miss.nextPageToken, '');

    // ---- ④ pageSize=2 分页:token 语义(拼接 = 全量 / 越界空页) ----
    final page1 =
        await holdings.listPaged(accountId: investId, pageSize: 2);
    expect(page1.holdings.map((h) => h.securityName).toList(), ['统链二号', '统链三号']);
    expect(page1.totalCount, 5, reason: 'totalCount 恒为过滤后全量');
    expect(page1.nextPageToken, '2', reason: '数字 offset token(照 F7 语义)');
    final page2 = await holdings.listPaged(
        accountId: investId, pageSize: 2, pageToken: page1.nextPageToken);
    expect(page2.holdings.map((h) => h.securityName).toList(), ['统链四号', '统链五号']);
    expect(page2.nextPageToken, '4');
    final page3 = await holdings.listPaged(
        accountId: investId, pageSize: 2, pageToken: page2.nextPageToken);
    expect(page3.holdings.map((h) => h.securityName).toList(), ['统链一号'],
        reason: '末页余 1 行(tie 段一号在五号之后)');
    expect(page3.nextPageToken, '', reason: '末页无 token');
    // 拼接(页序)= 默认全量(含顺序)。
    final pagedNames = [
      ...page1.holdings,
      ...page2.holdings,
      ...page3.holdings
    ].map((h) => h.securityName).toList();
    expect(pagedNames, base.holdings.map((h) => h.securityName).toList(),
        reason: '分页拼接 = 全量(含顺序)');
    // 越界 token:offset ≥ 过滤后总数 → 空页,无 token(不抛)。
    final beyond = await holdings.listPaged(
        accountId: investId, pageSize: 2, pageToken: '10');
    expect(beyond.holdings, isEmpty);
    expect(beyond.nextPageToken, '');

    // ---- ⑤ 搜索 × 分页组合:过滤后集合上切片 ----
    // oracle:搜索「统链」命中全部 5 只(与无搜索同集)→ pageSize=2 首 2 行
    // 同 ④ 页 1;搜索「一号」仅 1 只 → 单页取尽无 token。
    final combo = await holdings.listPaged(
        accountId: investId, searchText: '统链', pageSize: 2);
    expect(combo.holdings.map((h) => h.securityName).toList(), ['统链二号', '统链三号']);
    expect(combo.totalCount, 5);
    final comboSingle = await holdings.listPaged(
        accountId: investId, searchText: '一号', pageSize: 2);
    expect(comboSingle.holdings.map((h) => h.securityName).toList(), ['统链一号']);
    expect(comboSingle.nextPageToken, '', reason: '过滤后 1 只 < pageSize → 无下一页');
  });

  testWidgets('统链②债务 list:默认零变化 + counterparty 搜索 + 金额/到期四态全序',
      (t) async {
    // 统链前缀守卫(防 demo 债务污染 oracle):只取 counterparty 以「统链」开头的行。
    Future<List<String>> prefixed() async => (await debts.list())
        .map((d) => d.counterparty)
        .where((c) => c.startsWith('统链'))
        .toList();

    // ---- ① 默认(无参)= 插入序零变化 ----
    // raw drift 直读 debts 全表(独立于被测 DS 的映射/排序):list() 输出与
    // DAO 行序逐位一致 = 「不带参数时不排序」钉死(NFR-2)。
    final rawIds =
        (await db.select(db.debts).get()).map((r) => r.id).toList();
    final listIds = (await debts.list()).map((d) => d.id).toList();
    expect(listIds, rawIds,
        reason: '默认无参:与 DAO 行序逐位一致(raw drift 交叉核对,零重排)');
    // 前缀守卫:统链夹具按插入序 甲→乙→丙→丁。
    expect(await prefixed(), ['统链Bank甲', '统链债乙', '统链债丙', '统链债丁'],
        reason: '默认序 = 插入序(demo 借入/借出在前,统链夹具按创建序)');

    // ---- ② typeFilter 维度(既有参数回归:borrowedIn 含统链 4 笔,borrowedOut 不含) ----
    final borrowedIn = await debts.list(typeFilter: DebtType.borrowedIn);
    expect(
        borrowedIn
            .map((d) => d.counterparty)
            .where((c) => c.startsWith('统链'))
            .toList(),
        ['统链Bank甲', '统链债乙', '统链债丙', '统链债丁'],
        reason: 'typeFilter=borrowedIn:统链 4 笔全在(demo 招商银行同侧不影响前缀守卫)');
    final borrowedOut = await debts.list(typeFilter: DebtType.borrowedOut);
    expect(
        borrowedOut
            .map((d) => d.counterparty)
            .where((c) => c.startsWith('统链')),
        isEmpty,
        reason: 'typeFilter=borrowedOut:统链夹具全排除');

    // ---- ③ 搜索:counterparty contains 忽略大小写 ----
    // oracle:查询词「BANK」大写,counterparty「统链Bank甲」小写化后 contains 命中;
    // 乙/丙/丁(纯中文)与 demo 债务(招商银行/朋友借款)均不含该串。
    final byUpper = await debts.list(searchText: 'BANK');
    expect(byUpper.map((d) => d.counterparty).toList(), ['统链Bank甲'],
        reason: '搜索忽略大小写:BANK 命中 统链Bank甲(全集唯一,demo 不含)');
    // 收窄:「统链债」只命中乙/丙/丁(Bank甲 不含「统链债」连续串)。
    final byPrefix = await debts.list(searchText: '统链债');
    expect(byPrefix.map((d) => d.counterparty).toList(),
        ['统链债乙', '统链债丙', '统链债丁'],
        reason: '搜索收窄:只剩 counterparty 含「统链债」的乙/丙/丁');
    // 无命中 → 空集。
    final missList = await debts.list(searchText: '统链无此串');
    expect(missList, isEmpty);

    // ---- ④ 排序四态(金额/到期 × 升/降;前缀守卫防 demo 债务混序) ----
    // oracle(金额口径 totalPrincipalCents,到期口径 dueDate):
    //   金额:乙 900,000 > 丁 700,000 > 甲 500,000 > 丙 300,000
    //   到期:丁 2026-10 < 乙 2026-12 < 甲 2027-03 < 丙 2027-06(刻意反相关)
    Future<List<String>> sortedPrefixed(
            DebtSortKey key, DebtSortDir dir) async =>
        (await debts.list(typeFilter: DebtType.borrowedIn, sortKey: key, sortDir: dir))
            .map((d) => d.counterparty)
            .where((c) => c.startsWith('统链'))
            .toList();
    final amountDesc = await sortedPrefixed(DebtSortKey.amount, DebtSortDir.desc);
    expect(amountDesc, ['统链债乙', '统链债丁', '统链Bank甲', '统链债丙'],
        reason: '金额降序:900k > 700k > 500k > 300k');
    final amountAsc = await sortedPrefixed(DebtSortKey.amount, DebtSortDir.asc);
    expect(amountAsc, amountDesc.reversed.toList(),
        reason: '金额升序 = 降序镜像(四键互异,无 tie)');
    final dueAsc = await sortedPrefixed(DebtSortKey.dueDate, DebtSortDir.asc);
    expect(dueAsc, ['统链债丁', '统链债乙', '统链Bank甲', '统链债丙'],
        reason: '到期升序:2026-10 < 2026-12 < 2027-03 < 2027-06');
    final dueDesc = await sortedPrefixed(DebtSortKey.dueDate, DebtSortDir.desc);
    expect(dueDesc, dueAsc.reversed.toList(), reason: '到期降序 = 升序镜像');
    // (dueDate, asc) 直接委托 debtCompareList = **页面默认序**(NFR-2:排序
    // 控件初始态 = F9 改造前列表序)。注意与 ① 的 DS 无参默认(DAO 行序)是
    // 两个不同的「默认」—— DS 不带 sortKey 不排序,页面初始态用 debtCompareList
    // 排;此处对同一集合用 domain 纯函数手排对照钉死委托关系。
    final manualPageDefault = [...(await debts.list(typeFilter: DebtType.borrowedIn))]
      ..sort(debtCompareList);
    final manualPageDefaultPrefixed = manualPageDefault
        .map((d) => d.counterparty)
        .where((c) => c.startsWith('统链'))
        .toList();
    expect(dueAsc, manualPageDefaultPrefixed,
        reason: '(dueDate, asc) = debtCompareList 页面默认序(未结清在前 + 到期升序)');

    // ---- ⑤ 搜索 × 排序组合:过滤集合上应用四态 ----
    // oracle:「统链债」∩ 金额降序 → 乙(900k) > 丁(700k) > 丙(300k)。
    final combo = await debts.list(
      searchText: '统链债',
      sortKey: DebtSortKey.amount,
      sortDir: DebtSortDir.desc,
    );
    expect(combo.map((d) => d.counterparty).toList(), ['统链债乙', '统链债丁', '统链债丙'],
        reason: '组合:搜索收窄后按金额降序(Bank甲 被搜索剔除)');

    // sanity:夹具 id 与断言主体对应(防串号)。
    expect((await debts.get(debt1Id)).debt.counterparty, '统链Bank甲');
    expect((await debts.get(debt2Id)).debt.counterparty, '统链债乙');
    expect((await debts.get(debt3Id)).debt.counterparty, '统链债丙');
    expect((await debts.get(debt4Id)).debt.counterparty, '统链债丁');
  });
}
