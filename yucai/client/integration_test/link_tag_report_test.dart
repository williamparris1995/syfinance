/// F6 FR-4 标签(挂载/读回/幂等/移除,改形后口径)+ FR-8 报表 oracle 链 E2E
/// (管道链路,真实本地数据源)。
///
/// 链路 A(标签):建 2 标签挂同一交易(其一重复挂)→ getTransactionTags 恰 2
/// (幂等)→ 移除 1 → 恰 1。全库只有「交易→标签」方向,无按标签反查
/// (ADR-7 改形,不写反查断言)。
/// 链路 B(报表):跨 2026-08/09 两月、两个 expense 分类 + 一个 income 分类
/// 的已知收支夹具 → summary 收入/支出/净额/日均/byDay 手算 oracle;
/// aggregateCategorySlices(纯函数)聚合占比 oracle;两月窗口互相隔离。
/// summary 窗口是「本地时区月界」+ 交易日取 UTC(文本存储),夹具全部取
/// 月中(10/12/15/20/25 号)避开任何时区下的月界漂移。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/link_tag_report_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart'
    hide Transaction, TransactionEntry;
import 'package:yucai_client/report/presentation/widgets/category_breakdown_pie.dart';
import 'package:yucai_client/tag/data/tag_repository_impl.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TransactionLocalDataSource txns;
  late AccountLocalDataSource accounts;
  late TagLocalDataSource tags;

  late String fundsId; // 标链资金(CNY 储蓄,初始 10,000.00)
  late String diningId; // 标链餐饮(expense)
  late String transitId; // 标链交通(expense)
  late String salaryId; // 标链工资(income)

  // 夹具账本(全部月中 UTC 日,oracle 的唯一输入):
  //   t1 2026-09-10  expense 标链餐饮   8,800(88.00)—— 标签链挂这笔
  //   t2 2026-09-10  expense 标链交通   3,300(33.00)
  //   t3 2026-09-20  expense 标链餐饮  12,200(122.00)
  //   t4 2026-09-20  income  标链工资 350,000(3,500.00)
  //   t5 2026-08-12  expense 标链交通   5,500(55.00)
  //   t6 2026-08-25  expense 标链餐饮   4,400(44.00)
  //   t7 2026-08-25  income  标链工资 280,000(2,800.00)
  // 9 月 oracle:income 350,000 / expense 24,300 / net 325,700 / 2 个活跃日。
  // 8 月 oracle:income 280,000 / expense  9,900 / net 270,100 / 2 个活跃日。
  // 资金余额终值 oracle:1,000,000 +630,000 −34,200 = 1,595,800 分。
  late String t1Id;

  // 夹具前基线(demo 种子写在真实运行当月,可能落在 2026-08/09):
  // 全月口径断言用「前後差值」(design 风险表:demo_seed 与夹具耦合 → 差值不断绝对);
  // 纯 oracle 用 summary(accountId: 标链资金) 作用域 —— demo 交易不经过本夹具账户,
  // 作用域内只有上表 7 笔。
  var baseSepIncome = 0, baseSepExpense = 0;
  late Set<String> baseSepDays; // 基线 9 月活跃日(YYYY-MM-DD 集合)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(照 link_receivable_collect_test.dart)。
    await resetTestDb();
    db = getIt<AppDatabase>();
    accounts = AccountLocalDataSource(db);
    txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    tags = TagLocalDataSource(db);

    // ---- 基线:夹具写入前的全月 summary(差值断言的参照) ----
    final baseSep = await txns.summary(2026, 9);
    baseSepIncome = baseSep.incomeCents;
    baseSepExpense = baseSep.expenseCents;
    baseSepDays = baseSep.byDay.map((d) => d.date).toSet();

    // ---- 自包含夹具(标链* 前缀,与演示数据零耦合) ----
    fundsId = await fundsAccount('标链资金', 1000000); // 10,000.00
    final dining = await accounts.create(const CreateAccountParams(
      name: '标链餐饮',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    diningId = dining.id;
    final transit = await accounts.create(const CreateAccountParams(
      name: '标链交通',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    transitId = transit.id;
    final salary = await accounts.create(const CreateAccountParams(
      name: '标链工资',
      accountType: AccountType.income,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    salaryId = salary.id;

    // expense:debit 分类 / credit 资金;income:debit 资金 / credit 分类
    // (配对复式,照 template_local_ds._createTxnForRow / demo_seed)。
    Future<Transaction> expense(DateTime d, String cat, int cents) =>
        txns.recordTransaction(RecordTransactionParams(
          transactionDate: d,
          description: '标链支出',
          entries: [
            TransactionEntry(accountId: cat, debitCents: cents, creditCents: 0),
            TransactionEntry(
                accountId: fundsId, debitCents: 0, creditCents: cents),
          ],
        ));
    Future<Transaction> income(DateTime d, int cents) =>
        txns.recordTransaction(RecordTransactionParams(
          transactionDate: d,
          description: '标链收入',
          entries: [
            TransactionEntry(
                accountId: fundsId, debitCents: cents, creditCents: 0),
            TransactionEntry(
                accountId: salaryId, debitCents: 0, creditCents: cents),
          ],
        ));

    t1Id = (await expense(DateTime.utc(2026, 9, 10), diningId, 8800)).id;
    await expense(DateTime.utc(2026, 9, 10), transitId, 3300);
    await expense(DateTime.utc(2026, 9, 20), diningId, 12200);
    await income(DateTime.utc(2026, 9, 20), 350000);
    await expense(DateTime.utc(2026, 8, 12), transitId, 5500);
    await expense(DateTime.utc(2026, 8, 25), diningId, 4400);
    await income(DateTime.utc(2026, 8, 25), 280000);
  });

  tearDownAll(deleteTestDb);

  testWidgets('标链①标签:挂 2(其一重复)读回恰 2(幂等),移除 1 读回恰 1', (t) async {
    final tagA = await tags.create(name: '标链报销', color: '#2E7D32');
    final tagB = await tags.create(name: '标链必要', color: '#1565C0');

    // 挂 A、B,再重复挂 A(幂等:junction 已存在 → no-op 成功)。
    await tags.addTagToTransaction(tagId: tagA.id, transactionId: t1Id);
    await tags.addTagToTransaction(tagId: tagB.id, transactionId: t1Id);
    await tags.addTagToTransaction(tagId: tagA.id, transactionId: t1Id);

    final attached = await tags.getTransactionTags(t1Id);
    expect(attached, hasLength(2), reason: '重复挂载幂等,恰 2 个');
    expect(attached.map((x) => x.name).toSet(), {'标链报销', '标链必要'});

    // 移除 A → 恰 1(只剩 B)。
    await tags.removeTagFromTransaction(tagId: tagA.id, transactionId: t1Id);
    final after = await tags.getTransactionTags(t1Id);
    expect(after, hasLength(1));
    expect(after.single.name, '标链必要');
  });

  testWidgets('标链②九月 oracle:summary(2026,9, accountId) 四额 + byDay + 聚合占比', (t) async {
    // 作用域 summary:demo 交易不经标链资金 → 只有夹具 7 笔中的 9 月 4 笔。
    final s = await txns.summary(2026, 9, accountId: fundsId);

    // oracle(手算,见文件头账本):
    expect(s.incomeCents, 350000, reason: '收入 = credit 收入账户合计');
    expect(s.expenseCents, 24300, reason: '支出 = debit 支出账户合计(8,800+3,300+12,200)');
    expect(s.netCents, 325700, reason: '净额 = 350,000 − 24,300');
    // 活跃日 = 09-10、09-20 两日 → 325,700 ~/ 2 = 162,850。
    expect(s.dailyAvgCents, 162850, reason: '日均 = net ~/ 活跃日数');

    // byDay:升序两日;每日 byCategory 按金额降序,收入/支出同列。
    expect(s.byDay.map((d) => d.date).toList(), ['2026-09-10', '2026-09-20']);
    final d10 = s.byDay.first;
    expect(d10.totalIncomeCents, 0);
    expect(
      d10.byCategory.map((c) => (c.name, c.amountCents)).toList(),
      [('标链餐饮', 8800), ('标链交通', 3300)],
      reason: '同日分类按金额降序',
    );
    final d20 = s.byDay.last;
    expect(d20.totalIncomeCents, 350000);
    expect(
      d20.byCategory.map((c) => (c.name, c.amountCents, c.accountType)).toList(),
      [('标链工资', 350000, 'income'), ('标链餐饮', 12200, 'expense')],
    );

    // aggregateCategorySlices(纯函数,category_breakdown_pie.dart:55):
    // expense 口径 → 餐饮 8,800+12,200=21,000 / 交通 3,300,降序。
    final slices =
        aggregateCategorySlices(s, filter: CategoryFilter.expense);
    expect(slices.map((x) => (x.name, x.amountCents)).toList(),
        [('标链餐饮', 21000), ('标链交通', 3300)]);
    // 占比 oracle(饼图图例同式 amount/total×100):
    //   餐饮 21,000/24,300 = 86.42%(86.4197…),交通 3,300/24,300 = 13.58%。
    final total = slices.fold<int>(0, (a, x) => a + x.amountCents);
    expect(total, 24300);
    expect(slices.first.amountCents / total * 100, closeTo(86.42, 0.01));
    expect(slices.last.amountCents / total * 100, closeTo(13.58, 0.01));

    // income 口径 → 仅工资 3,500.00,占比 100%。
    final incSlices =
        aggregateCategorySlices(s, filter: CategoryFilter.income);
    expect(incSlices.single.name, '标链工资');
    expect(incSlices.single.amountCents, 350000);

    // 资金余额终值 oracle(raw drift):1,000,000 +630,000 −34,200 = 1,595,800。
    expect(await balanceOf(db, fundsId), 1595800,
        reason: '资金终值 = 初始 + 收入合计 − 支出合计');
  });

  testWidgets('标链③八月独立 oracle + 九月全月差值口径(月窗口隔离)', (t) async {
    // 8 月作用域 oracle:income 280,000 / expense 9,900 / net 270,100,
    // 活跃日 08-12、08-25 → 270,100 ~/ 2 = 135,050。
    final aug = await txns.summary(2026, 8, accountId: fundsId);
    expect(aug.incomeCents, 280000);
    expect(aug.expenseCents, 9900, reason: '8 月支出 = 5,500+4,400');
    expect(aug.netCents, 270100);
    expect(aug.dailyAvgCents, 135050);
    expect(aug.byDay.map((d) => d.date).toList(), ['2026-08-12', '2026-08-25'],
        reason: '月窗口隔离:8 月窗口不含 9 月交易日');

    // 九月全月(无作用域)差值口径:demo 种子可能落 9 月 → 断言前后差值。
    final sep = await txns.summary(2026, 9);
    expect(sep.incomeCents, baseSepIncome + 350000,
        reason: '全月收入 = 基线 + 夹具收入');
    expect(sep.expenseCents, baseSepExpense + 24300,
        reason: '全月支出 = 基线 + 夹具支出');
    expect(sep.netCents, (baseSepIncome + 350000) - (baseSepExpense + 24300),
        reason: '净额 = 差值口径收入 − 差值口径支出');
    // 活跃日 = 基线日 ∪ 夹具日(09-10/09-20);日均 = 全月净额 ~/ 活跃日数。
    final activeDays = baseSepDays.union({'2026-09-10', '2026-09-20'});
    expect(sep.byDay.map((d) => d.date).toSet(), activeDays,
        reason: '活跃日集合 = 基线 ∪ 夹具');
    expect(sep.dailyAvgCents, sep.netCents ~/ activeDays.length,
        reason: '日均 = net ~/ 活跃日数(month scope)');
  });
}
