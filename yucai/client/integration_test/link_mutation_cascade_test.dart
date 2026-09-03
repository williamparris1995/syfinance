/// F6 FR-9 变更级联(编辑重算/删除回滚/账户删除守卫/归档)+ FR-14 列表查询
/// E2E(管道链路,真实本地数据源)。
///
/// 链路 A(变更级联):记一笔已知金额交易 → update 改金额(同账户)→ 余额差值
/// = 新旧差;update 换账户 → 旧账户回滚 + 新账户入账(双腿);delete → 余额
/// 回滚至基线;账户非零余额删除守卫;净零(有历史)可删;archived 置位。
/// 链路 B(列表):accountId 过滤 / 月份窗 / typeFilter(粗分类:2 笔平衡分录
/// 即 transfer,income/expense 不可分,照实断言)/ 默认排序 transactionDate
/// DESC,id DESC / pageSize=2 分页拼接 = 全量;⑦ 补(F7 FR-5)category 维度 /
/// 描述搜索(contains 忽略大小写)/ 排序四态补三态(date asc + 金额升降,口径
/// Σdebit,tie 恒日期+id 降序不随方向翻转)/ category×search×金额降序×分页组合。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/link_mutation_cascade_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart'
    hide Transaction, TransactionEntry;
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late AccountLocalDataSource accounts;
  late TransactionLocalDataSource txns;

  late String fundsId; // 级链资金(CNY 储蓄,初始 10,000.00)
  late String walletId; // 级链钱包(CNY 储蓄,初始 0;跨账户腿)
  late String diningId; // 级链餐饮(expense 分类)
  late String salaryId; // 级链工资(income 分类)
  late String guardId; // 级链守卫(初始 5,000.00;删除守卫用)
  late String archiveId; // 级链归档(初始 0;archived 用)

  // 列表夹具(全部 级链* 前缀描述;日期取 2026-05/06 固定月,远离 demo
  // 种子的「真实运行当月」,月份窗断言不受种子污染):
  //   m1 2026-05-10  expense 级链午餐一  8,800(dining/funds)
  //   m2 2026-05-10  expense 级链午餐二  3,300(dining/funds)—— 与 m1 同日验 id 序
  //   m3 2026-05-20  income  级链工资   55,000(funds/salary)
  //   m4 2026-05-25  transfer 级链转账  12,000(funds→wallet)
  //   m5 2026-06-05  compound 级链复合   1,500(debit dining 1,000 + debit
  //                                      wallet 500 / credit funds 1,500)
  // m 夹具后基线(编辑/删除链的回滚参照;余额规则 asset/expense=debit−credit):
  //   funds = 1,000,000 −8,800 −3,300 +55,000 −12,000 −1,500 = 1,029,400
  //   dining(expense)= 8,800+3,300+1,000 = 13,100
  //   wallet(asset)= +12,000(m4 debit)+500(m5 debit,资产 debit 增)= 12,500
  late String m1Id, m2Id, m3Id, m4Id, m5Id;
  late int baseFunds, baseDining, baseWallet;
  late String e1Id; // 级链编辑支出(① 建立并改额,② 换账户,③ 删除)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(照 link_receivable_collect_test.dart)。
    await resetTestDb();
    db = getIt<AppDatabase>();
    accounts = AccountLocalDataSource(db);
    txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));

    // ---- 自包含夹具(级链* 前缀,与演示数据零耦合) ----
    fundsId = await fundsAccount('级链资金', 1000000); // 10,000.00
    final wallet = await accounts.create(const CreateAccountParams(
      name: '级链钱包',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    walletId = wallet.id;
    final dining = await accounts.create(const CreateAccountParams(
      name: '级链餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    diningId = dining.id;
    final salary = await accounts.create(const CreateAccountParams(
      name: '级链工资',
      accountType: AccountType.income,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    salaryId = salary.id;
    guardId = await fundsAccount('级链守卫', 500000); // 5,000.00
    final archive = await accounts.create(const CreateAccountParams(
      name: '级链归档',
      accountType: AccountType.asset,
      category: AccountCategory.savings,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    archiveId = archive.id;

    // ---- 列表夹具 m1..m5(编辑链用独立交易,见 ①) ----
    Future<Transaction> expense(
            DateTime d, String desc, int cents) =>
        txns.recordTransaction(RecordTransactionParams(
          transactionDate: d,
          description: desc,
          entries: [
            TransactionEntry(
                accountId: diningId, debitCents: cents, creditCents: 0),
            TransactionEntry(
                accountId: fundsId, debitCents: 0, creditCents: cents),
          ],
        ));
    m1Id = (await expense(DateTime.utc(2026, 5, 10), '级链午餐一', 8800)).id;
    m2Id = (await expense(DateTime.utc(2026, 5, 10), '级链午餐二', 3300)).id;
    m3Id = await txns
        .recordTransaction(RecordTransactionParams(
          transactionDate: DateTime.utc(2026, 5, 20),
          description: '级链工资',
          entries: [
            TransactionEntry(
                accountId: fundsId, debitCents: 55000, creditCents: 0),
            TransactionEntry(
                accountId: salaryId, debitCents: 0, creditCents: 55000),
          ],
        ))
        .then((x) => x.id);
    m4Id = await txns
        .recordTransaction(RecordTransactionParams(
          transactionDate: DateTime.utc(2026, 5, 25),
          description: '级链转账',
          entries: [
            TransactionEntry(
                accountId: walletId, debitCents: 12000, creditCents: 0),
            TransactionEntry(
                accountId: fundsId, debitCents: 0, creditCents: 12000),
          ],
        ))
        .then((x) => x.id);
    m5Id = await txns
        .recordTransaction(RecordTransactionParams(
          transactionDate: DateTime.utc(2026, 6, 5),
          description: '级链复合',
          entries: [
            TransactionEntry(
                accountId: diningId, debitCents: 1000, creditCents: 0),
            TransactionEntry(
                accountId: walletId, debitCents: 500, creditCents: 0),
            TransactionEntry(
                accountId: fundsId, debitCents: 0, creditCents: 1500),
          ],
        ))
        .then((x) => x.id);

    // ---- 基线(编辑/删除链的回滚参照;此刻库内 m 夹具已就位) ----
    baseFunds = await balanceOf(db, fundsId);
    baseDining = await balanceOf(db, diningId);
    baseWallet = await balanceOf(db, walletId);
    // oracle sanity:1,029,400 / 13,100 / 12,500(文件头账本)。
    expect(baseFunds, 1029400, reason: 'm 夹具后资金基线 oracle');
    expect(baseDining, 13100, reason: 'm 夹具后餐饮基线 oracle');
    expect(baseWallet, 12500, reason: 'm 夹具后钱包基线 oracle');
  });

  tearDownAll(deleteTestDb);

  testWidgets('级链①编辑重算:改金额(同账户)余额差 = 新旧差,version+1', (t) async {
    // 记一笔 200.00 支出(debit 餐饮 / credit 资金)。
    final e1 = await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime.utc(2026, 6, 10),
      description: '级链编辑支出',
      entries: [
        TransactionEntry(
            accountId: diningId, debitCents: 20000, creditCents: 0),
        TransactionEntry(accountId: fundsId, debitCents: 0, creditCents: 20000),
      ],
    ));
    e1Id = e1.id;
    expect(e1.version, 1);
    expect(await balanceOf(db, fundsId), baseFunds - 20000,
        reason: 'sanity:记入后资金 −200.00');

    // update 改金额 200.00 → 260.00(同账户结构)。
    // 读代码确认:update = 事务内 applyEntries(旧,−1) → 更新头 → 全量替换
    // entries → applyEntries(新,+1);description 全量替换(必传)。
    final updated = await txns.update(UpdateTransactionParams(
      id: e1.id,
      version: e1.version,
      description: '级链编辑支出',
      transactionDate: DateTime.utc(2026, 6, 10),
      entries: [
        TransactionEntry(
            accountId: diningId, debitCents: 26000, creditCents: 0),
        TransactionEntry(accountId: fundsId, debitCents: 0, creditCents: 26000),
      ],
    ));

    // oracle:回滚旧 −20,000 再入新 −26,000 → 净差 = −6,000;
    // dining(expense:debit−credit)对称 +6,000。
    expect(await balanceOf(db, fundsId), baseFunds - 26000,
        reason: '编辑重算:资金终值 = 基线 − 新金额');
    expect(await balanceOf(db, diningId), baseDining + 26000,
        reason: '编辑重算:餐饮终值 = 基线 + 新金额');
    expect(updated.version, 2, reason: '乐观锁版本 +1');
    expect(updated.entries, hasLength(2));
    expect(updated.totalDebitCents, 26000);
  });

  testWidgets('级链②编辑换账户:旧账户回滚 + 新账户入账(双腿)', (t) async {
    final preFunds = await balanceOf(db, fundsId); // 基线 −260.00
    final preWallet = await balanceOf(db, walletId); // 12,500

    // 把 credit 腿从资金换到钱包(debit 餐饮不变);version 用最新读数(① 后 = 2)。
    final fresh = await txns.getById(e1Id);
    await txns.update(UpdateTransactionParams(
      id: e1Id,
      version: fresh.version,
      description: '级链编辑支出',
      transactionDate: DateTime.utc(2026, 6, 10),
      entries: [
        TransactionEntry(
            accountId: diningId, debitCents: 26000, creditCents: 0),
        TransactionEntry(
            accountId: walletId, debitCents: 0, creditCents: 26000),
      ],
    ));

    // oracle:资金回滚 +26,000(回到基线);钱包入账 −26,000(双腿)。
    expect(await balanceOf(db, fundsId), preFunds + 26000,
        reason: '旧账户回滚 +旧金额');
    expect(await balanceOf(db, walletId), preWallet - 26000,
        reason: '新账户入账 −新金额');
    expect(await balanceOf(db, fundsId), baseFunds,
        reason: '资金回到编辑链前基线');
  });

  testWidgets('级链③删除回滚:余额回到基线,头行不可再读', (t) async {
    await txns.delete(e1Id);

    // oracle:applyEntries(旧,−1) → 三腿全部回滚至 m 夹具基线。
    expect(await balanceOf(db, fundsId), baseFunds, reason: '资金回滚至基线');
    expect(await balanceOf(db, diningId), baseDining, reason: '餐饮回滚至基线');
    expect(await balanceOf(db, walletId), baseWallet, reason: '钱包回滚至基线');
    await expectLater(txns.getById(e1Id),
        throwsA(isA<ServerFailure>().having(
            (f) => f.message, 'message', '交易不存在')));
  });

  testWidgets('级链④账户删除守卫:非零拒删;清零后净零可删(历史 entries 成孤儿为现状语义)',
      (t) async {
    // 非零余额(5,000.00)→ 拒删,文案照生产代码逐字。
    await expectLater(
      accounts.delete(guardId),
      throwsA(isA<ServerFailure>().having((f) => f.message, 'message',
          '账户余额非零，无法删除，请先清空余额或转账后再试')),
    );

    // 清零:转出 5,000.00 到钱包(debit 钱包 / credit 守卫)。
    await txns.recordTransaction(RecordTransactionParams(
      transactionDate: DateTime.utc(2026, 6, 15),
      description: '级链清零',
      entries: [
        TransactionEntry(
            accountId: walletId, debitCents: 500000, creditCents: 0),
        TransactionEntry(
            accountId: guardId, debitCents: 0, creditCents: 500000),
      ],
    ));
    expect(await balanceOf(db, guardId), 0, reason: 'sanity:守卫账户已净零');

    // 净零 + 有交易历史 → delete 成功(守卫只看 currentBalanceCents)。
    await accounts.delete(guardId);
    await expectLater(
      accounts.getById(guardId),
      throwsA(isA<ServerFailure>()
          .having((f) => f.message, 'message', '账户不存在')),
    );

    // 照实断言(现状语义,非缺陷定性):transaction_entries.account_id 是
    // 跨模块普通列(无 FK,app 层完整性),账户删除不级联清理 entries
    // —— 历史分录成为悬挂引用仍在库中。
    final orphanEntries = await (db.select(db.transactionEntries)
          ..where((e) => e.accountId.equals(guardId)))
        .get();
    expect(orphanEntries, isNotEmpty,
        reason: '净零删除后历史 entries 保留(孤儿现状语义,注释钉死)');
  });

  testWidgets('级链⑤账户归档:archived 置位,状态字段持久化', (t) async {
    final before = await accounts.getById(archiveId);
    expect(before.status, AccountStatus.active, reason: 'sanity:初始 active');

    // 读代码确认:归档走 update(status: AccountStatus.archived),
    // 存储为 domain index+1(active=1/archived=2),乐观锁版本 +1。
    final updated = await accounts.update(UpdateAccountParams(
      id: archiveId,
      version: before.version,
      status: AccountStatus.archived,
    ));

    expect(updated.status, AccountStatus.archived, reason: '返回视图已归档');
    expect(updated.version, before.version + 1, reason: '版本 +1');
    // raw drift 直读状态列(独立于被测 DS 的映射):archived = 2。
    final row = await (db.select(db.accounts)
          ..where((a) => a.id.equals(archiveId)))
        .getSingle();
    expect(row.status, AccountStatus.archived.index + 1,
        reason: '状态列持久化 = domain index+1 = 2');
  });

  testWidgets('级链⑥列表查询:账户/月份窗/口味过滤 + 排序 + 分页拼接 = 全量', (t) async {
    // ① accountId 过滤:钱包被 m4(借方)、m5(借方 500)、级链清零(借方)
    // 三笔触及 → 恰这 3 笔(demo 交易不经级链账户)。
    final byWallet =
        await txns.list(ListTransactionsParams(accountId: walletId));
    expect(
        byWallet.transactions.map((x) => x.description).toSet(),
        {'级链转账', '级链复合', '级链清零'},
        reason: 'accountId 过滤:只剩触及该账户的交易');
    expect(byWallet.totalCount, 3);

    // ② 月份窗 2026-05:窗内全部落窗(边界含),级链* 恰 m1..m4,
    // 6 月的 m5/清零不在窗内(demo 交易在真实运行当月 ≥2026-09,窗不受污染)。
    final may = await txns.list(ListTransactionsParams(
      dateFrom: DateTime.utc(2026, 5, 1),
      dateTo: DateTime.utc(2026, 5, 31),
    ));
    for (final x in may.transactions) {
      final u = x.transactionDate.toUtc();
      expect(u.year, 2026, reason: '月份窗:返回行都在 2026 年');
      expect(u.month, 5, reason: '月份窗:返回行都在 5 月');
    }
    final mayDescs = may.transactions
        .map((x) => x.description)
        .where((d) => d.startsWith('级链'))
        .toSet();
    expect(mayDescs, {'级链午餐一', '级链午餐二', '级链工资', '级链转账'},
        reason: '月份窗:只剩窗口内(级链前缀口径,防 demo 污染)');

    // ③ typeFilter(读代码确认 inferFlavour 粗分类:恰 2 笔平衡分录 →
    // transfer,否则 compound;income/expense 不可分,不断言能分)。
    // 作用域资金账户:m1..m4 两笔平衡 → transfer;m5 三笔 → compound。
    final asTransfer = await txns.list(ListTransactionsParams(
      accountId: fundsId,
      typeFilter: TxnFlavour.transfer,
    ));
    expect(
        asTransfer.transactions.map((x) => x.description).toSet(),
        {'级链午餐一', '级链午餐二', '级链工资', '级链转账'},
        reason: 'transfer 口味 = 2 笔平衡分录(收支也归 transfer,粗分类语义)');
    final asCompound = await txns.list(ListTransactionsParams(
      accountId: fundsId,
      typeFilter: TxnFlavour.compound,
    ));
    expect(asCompound.transactions.map((x) => x.description).toSet(),
        {'级链复合'},
        reason: 'compound 口味 = 非 2 笔平衡');

    // ④ 默认排序 = transactionDate DESC,id DESC(资金作用域全量 5 笔):
    // m5(06-05)> m4(05-25)> m3(05-20)> {m1,m2}(05-10,同日按 id 降序)。
    final sorted =
        await txns.list(ListTransactionsParams(accountId: fundsId));
    final ids = sorted.transactions.map((x) => x.id).toList();
    final sameDayDesc = [m1Id, m2Id]..sort((a, b) => b.compareTo(a));
    expect(ids, [m5Id, m4Id, m3Id, ...sameDayDesc],
        reason: '日期降序,同日两笔按 id 降序');
    // 全局(无作用域)也满足日期非升序(demo 与级链混排的口径检查)。
    final global = await txns.list(const ListTransactionsParams());
    for (var i = 1; i < global.transactions.length; i++) {
      final prev = global.transactions[i - 1].transactionDate;
      final next = global.transactions[i].transactionDate;
      expect(next.isBefore(prev) || next.isAtSameMomentAs(prev), isTrue,
          reason: '全列表日期非升序(DESC)');
    }

    // ⑤ 分页:pageSize=2 走 3 页拼全量(资金作用域 5 笔)。
    final page1 = await txns.list(ListTransactionsParams(
        accountId: fundsId, pageSize: 2));
    expect(page1.transactions, hasLength(2));
    expect(page1.totalCount, 5, reason: 'totalCount = 过滤后全量');
    expect(page1.nextPageToken, '2', reason: '数字 offset token');
    final page2 = await txns.list(ListTransactionsParams(
        accountId: fundsId, pageSize: 2, pageToken: page1.nextPageToken));
    expect(page2.transactions, hasLength(2));
    expect(page2.nextPageToken, '4');
    final page3 = await txns.list(ListTransactionsParams(
        accountId: fundsId, pageSize: 2, pageToken: page2.nextPageToken));
    expect(page3.transactions, hasLength(1));
    expect(page3.nextPageToken, '', reason: '末页无 token');
    // 拼接(页序)= 全量集合与顺序。
    final pagedIds = [
      ...page1.transactions,
      ...page2.transactions,
      ...page3.transactions
    ].map((x) => x.id).toList();
    expect(pagedIds, ids, reason: '分页拼接 = 全量(含顺序)');

    // 越界 token:offset ≥ 过滤后总数 → 空页,无 token。
    final beyond = await txns.list(ListTransactionsParams(
        accountId: fundsId, pageSize: 2, pageToken: '10'));
    expect(beyond.transactions, isEmpty);
    expect(beyond.nextPageToken, '');
  });

  testWidgets('级链⑦查询扩展:category 维度/描述搜索/排序四态/组合叠加', (t) async {
    // ---- 夹具补充(自包含 级链查* 前缀;2026-07 固定月,远离 demo 当月) ----
    // 跨分类账户:级链查卡(creditCard;既有夹具账户只有 savings/otherAsset,
    // demo 种子亦无信用卡账户 → creditCard 断言可免前缀守卫做全集)。
    //   q1 2026-07-01 级链查Netflix 4,400(dining/funds)—— ASCII 段供忽略大小写断言
    //   q2 2026-07-02 级链查卡费   4,400(card/funds)—— 与 q1 同额(金额排序 tie)
    //   q3 2026-07-03 级链查咖啡     700(card/funds)
    final card = await accounts.create(const CreateAccountParams(
      name: '级链查卡',
      accountType: AccountType.liability,
      category: AccountCategory.creditCard,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    Future<Transaction> q(DateTime d, String desc, String debitAcc, int cents) =>
        txns.recordTransaction(RecordTransactionParams(
          transactionDate: d,
          description: desc,
          entries: [
            TransactionEntry(
                accountId: debitAcc, debitCents: cents, creditCents: 0),
            TransactionEntry(
                accountId: fundsId, debitCents: 0, creditCents: cents),
          ],
        ));
    await q(DateTime.utc(2026, 7, 1), '级链查Netflix', diningId, 4400);
    await q(DateTime.utc(2026, 7, 2), '级链查卡费', card.id, 4400);
    await q(DateTime.utc(2026, 7, 3), '级链查咖啡', card.id, 700);

    // 查询结果描述序列 helper(排序断言用全序,不能只比对集合)。
    Future<List<String>> descsOf(ListTransactionsParams p) async =>
        (await txns.list(p)).transactions.map((x) => x.description).toList();

    // ---- ① category 维度(F7 FR-1):任一 entry 涉及该分类账户即入选 ----
    // oracle(creditCard,全集免守卫):仅 q2(借卡)/q3(借卡)两笔 entries 涉及
    // 信用卡账户;m1..m5/清零不涉,q1 借餐饮不涉 → 恰 2 笔。
    final byCard = await txns.list(
        const ListTransactionsParams(category: AccountCategory.creditCard));
    expect(byCard.transactions.map((x) => x.description).toSet(),
        {'级链查卡费', '级链查咖啡'},
        reason: 'category=creditCard:只剩涉信用卡账户的交易(demo 无该分类)');
    expect(byCard.totalCount, 2);

    // oracle(otherAsset,级链前缀守卫防 demo 工资/午餐也涉 otherAsset):
    // 午餐一/二(dining)、工资(salary)、复合(dining 腿)、Netflix(dining)入选;
    // 转账(wallet+funds 均 savings)、清零(wallet+guard 均 savings)、
    // 卡费/咖啡(card creditCard+funds)排除。
    final byOther = await txns
        .list(const ListTransactionsParams(category: AccountCategory.otherAsset));
    expect(
        byOther.transactions
            .map((x) => x.description)
            .where((d) => d.startsWith('级链'))
            .toSet(),
        {'级链午餐一', '级链午餐二', '级链工资', '级链复合', '级链查Netflix'},
        reason: 'category=otherAsset:跨分类交易被剔出(纯储蓄/信用卡腿不选)');

    // oracle(savings,级链前缀守卫):9 笔全集 = m1..m5 + 清零(经 wallet 储蓄腿)
    // + q1..q3(经 funds 储蓄腿)。
    final bySavings = await txns
        .list(const ListTransactionsParams(category: AccountCategory.savings));
    expect(
        bySavings.transactions
            .map((x) => x.description)
            .where((d) => d.startsWith('级链'))
            .toSet(),
        {
          '级链午餐一', '级链午餐二', '级链工资', '级链转账', '级链复合', '级链清零',
          '级链查Netflix', '级链查卡费', '级链查咖啡'
        },
        reason: 'category=savings:涉资金/钱包储蓄腿的级链交易全集');

    // ---- ② searchText(F7 FR-2):contains + 忽略大小写 ----
    // oracle:仅 q1 描述含「Netflix」;查询词「NETFLIX」与描述大小写不同,
    // 双侧 toLowerCase 后 contains 命中(demo 无 netflix 交易,模板不入交易表)。
    final netflix = await txns
        .list(const ListTransactionsParams(searchText: 'NETFLIX'));
    expect(netflix.transactions.map((x) => x.description).toSet(),
        {'级链查Netflix'},
        reason: '搜索忽略大小写:NETFLIX 命中 Netflix');
    expect(netflix.totalCount, 1);
    // 无命中词 → 空集(demo 描述亦不含该串)。
    final miss =
        await txns.list(const ListTransactionsParams(searchText: '级链查无此串'));
    expect(miss.transactions, isEmpty, reason: '搜索无命中 → 空列表');
    expect(miss.totalCount, 0);

    // ---- ③ 排序四态(F7 FR-3;默认 date desc 已于 ⑥ 钉死,补三态) ----
    // 作用域 = 资金账户(8 笔 = m1..m5 + q1..q3;清零只涉 wallet/guard 不入,
    // demo 不涉级链账户),金额口径 Σdebit。oracle:
    //   工资 55,000 > 转账 12,000 > 午餐一 8,800 >
    //   {卡费 4,400(07-02), Netflix 4,400(07-01)} 同额 tie 恒按日期 DESC >
    //   午餐二 3,300 > 复合 1,500 > 咖啡 700
    final amountDesc = await descsOf(ListTransactionsParams(
        accountId: fundsId,
        sortKey: TxnSortKey.amount,
        sortDir: TxnSortDir.desc));
    expect(amountDesc, [
      '级链工资', '级链转账', '级链午餐一', '级链查卡费', '级链查Netflix',
      '级链午餐二', '级链复合', '级链查咖啡'
    ], reason: '金额降序 Σdebit;同额 4,400 tie 按日期降序(卡费 07-02 先于 Netflix 07-01)');
    // 升序 = 主键镜像,但 tie 段不翻转(tie-break 恒 date DESC,id DESC)。
    final amountAsc = await descsOf(ListTransactionsParams(
        accountId: fundsId,
        sortKey: TxnSortKey.amount,
        sortDir: TxnSortDir.asc));
    expect(amountAsc, [
      '级链查咖啡', '级链复合', '级链午餐二', '级链查卡费', '级链查Netflix',
      '级链午餐一', '级链转账', '级链工资'
    ], reason: '金额升序;tie 段与降序同序(恒定 tie-break 不随方向翻转)');
    // 日期升序:同日 m1/m2 仍按 id 降序(tie-break 不随方向翻转)。
    final dateAsc = await descsOf(ListTransactionsParams(
        accountId: fundsId,
        sortKey: TxnSortKey.date,
        sortDir: TxnSortDir.asc));
    final sameDay = [m1Id, m2Id]..sort((a, b) => b.compareTo(a));
    expect(
        dateAsc,
        [
          for (final id in sameDay) id == m1Id ? '级链午餐一' : '级链午餐二',
          '级链工资', // 05-20
          '级链转账', // 05-25
          '级链复合', // 06-05
          '级链查Netflix', // 07-01
          '级链查卡费', // 07-02
          '级链查咖啡', // 07-03
        ],
        reason: '日期升序;同日两笔按 id 降序(与默认降序同 tie 序)');

    // ---- ④ 组合:category × searchText × 金额降序 × 分页 一条 ----
    // oracle:otherAsset(dining/salary)∩ 描述含「级链午餐」→ 恰 午餐一 8,800 /
    // 午餐二 3,300(demo「午餐」不含「级链午餐」串,工资描述亦不含);金额降序
    // → 一先二后;pageSize=1 → 两页各 1 笔,token 数字递进,末页空。
    final comb1 = await txns.list(const ListTransactionsParams(
      category: AccountCategory.otherAsset,
      searchText: '级链午餐',
      sortKey: TxnSortKey.amount,
      sortDir: TxnSortDir.desc,
      pageSize: 1,
    ));
    expect(comb1.totalCount, 2);
    expect(comb1.transactions.map((x) => x.description).toList(), ['级链午餐一'],
        reason: '组合页 1:过滤后金额最大者');
    expect(comb1.nextPageToken, '1');
    final comb2 = await txns.list(ListTransactionsParams(
      category: AccountCategory.otherAsset,
      searchText: '级链午餐',
      sortKey: TxnSortKey.amount,
      sortDir: TxnSortDir.desc,
      pageSize: 1,
      pageToken: comb1.nextPageToken,
    ));
    expect(comb2.transactions.map((x) => x.description).toList(), ['级链午餐二']);
    expect(comb2.nextPageToken, '', reason: '组合末页无 token');
  });
}
