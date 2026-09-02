/// F6 FR-2 订阅自动补账 + FR-3 模板记账链 E2E(管道链路,真实本地数据源)。
///
/// 链路:autoRecord 模板 → AutoRecordScheduler.run(fixedToday) 一次性补账
/// → 断言逐期交易落库/余额联动/nextDate 前移/endDate 截断;空 category 兜底
/// 自动建「订阅·<模板名>」分类账户(a7e580ac 回归);手动 record 字段一致性
/// 与暂停守卫。模式照 link_receivable_collect_test.dart:夹具独立前缀(订链*/模链*),
/// 断言用前后差值,oracle 手算内联注释。
///
/// 语义出入说明(以代码为准,简报口径按此修正):
/// 调度循环条件 `!cur.isAfter(day)` **含当日**(nextDate==today 也补记),
/// 故「补恰 3 笔」的夹具取 startDate = fixedToday −3 个月(首期 nextDate =
/// fixedToday −2 个月),3 期 = 前两月 + 当月;endDate 截断同理按「≤ endDate
/// 含当日」取 endDate = fixedToday −1 个月 → 恰 2 笔。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/link_subscription_template_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/auto_record_scheduler.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_scanner.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

import 'link_support.dart';

/// 测试不测通知(design ADR-4):调度器通知腿注入 no-op 实现,
/// 只保证 show(copy) 可被无副作用地调用。
class _NoopNotifier implements ReminderNotifier {
  @override
  Future<void> show(DueNotificationCopy copy) async {}
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TemplateLocalDataSource templatesDs;
  late TransactionLocalDataSource txns;
  late AccountLocalDataSource accounts;
  late AutoRecordScheduler scheduler;

  late String fundsId; // 订链资金(CNY 储蓄,初始 10,000.00)
  late String catId; // 订链分类(expense 分类账户,模链④用)
  late String subId; // 订链会员(autoRecord 月度订阅,补账主夹具;早停夹具按 description 断言,不留 id)
  late String fbId; // 订链无类(空 category 兜底回归夹具)
  late String tplId; // 模链月费(手动 record 一致性夹具)

  // date-only 字符串夹具帮手(模板 create/endDate 均为 'YYYY-MM-DD' 字符串)。
  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(照 link_receivable_collect_test.dart)。
    await resetTestDb();
    db = getIt<AppDatabase>();
    txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    accounts = AccountLocalDataSource(db);
    templatesDs = TemplateLocalDataSource(db, txns);
    // 调度编排照 notifications_bootstrap 的生产接线(ADR-4):
    // TemplateRepoAutoRecord 包装双源模板 repo(guest 默认走本地 DS)。
    scheduler = AutoRecordScheduler(
      templates: TemplateRepoAutoRecord(getIt<TemplateRepository>()),
      notifier: _NoopNotifier(),
    );

    // ---- 自包含夹具(订链*/模链* 前缀,与演示数据零耦合) ----
    fundsId = await fundsAccount('订链资金', 1000000); // 10,000.00
    final cat = await accounts.create(const CreateAccountParams(
      name: '订链分类',
      accountType: AccountType.expense,
      category: AccountCategory.otherAsset,
      currencyCode: 'CNY',
      initialBalanceCents: 0,
      ownership: Ownership.personal,
    ));
    catId = cat.id;

    // 订链会员:月度 25.00,startDate = fixedToday −3 个月(2026-06-02)
    // → create 时 nextDate = start 后一个周期 = 2026-07-02(首期发生日)。
    subId = (await templatesDs.create(
      name: '订链会员',
      amountCents: 2500, // 25.00
      direction: TemplateDirection.expense,
      sourceAccountId: fundsId,
      cycle: TemplateCycle.monthly,
      billingDay: 0, // ≤0 取发生日(每月 2 号)
      startDate: iso(DateTime(fixedToday.year, fixedToday.month - 3, fixedToday.day)),
      autoRecord: true,
    ))
        .id;

    // 订链无类:空 category(a7e580ac 回归),手动 record,不进调度。
    fbId = (await templatesDs.create(
      name: '订链无类',
      amountCents: 3900, // 39.00
      direction: TemplateDirection.expense,
      sourceAccountId: fundsId,
      cycle: TemplateCycle.monthly,
      billingDay: 0,
      startDate: iso(DateTime(fixedToday.year, fixedToday.month - 1, fixedToday.day)),
      autoRecord: false,
    ))
        .id;

    // 模链月费:带 category(指向订链分类),手动 record 一致性夹具。
    tplId = (await templatesDs.create(
      name: '模链月费',
      amountCents: 8800, // 88.00
      direction: TemplateDirection.expense,
      sourceAccountId: fundsId,
      cycle: TemplateCycle.monthly,
      billingDay: 0,
      startDate: iso(DateTime(fixedToday.year, fixedToday.month - 3, fixedToday.day)),
      autoRecord: false,
      category: catId,
    ))
        .id;
  });

  tearDownAll(deleteTestDb);

  testWidgets('订链①订阅补账:恰 3 笔 / 余额 −3×金额 / nextDate 前移过今天', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 10,000.00

    // fixedToday=2026-09-02;首期 nextDate=2026-07-02 → 逐周期推进:
    // 07-02、08-02、09-02(调度含当日,共 3 笔)→ 停在 10-02(> today)。
    final result = await scheduler.run(fixedToday);

    // demo 种子的两个模板均 autoRecord=false → 到期名单只含本模板。
    expect(result.templates, 1, reason: 'autoRecord 且未暂停的到期模板数');
    expect(result.recorded, 3, reason: '一次性补齐 3 期');
    expect(result.failed, 0, reason: '无失败模板');

    // raw drift 查 description=模板名 的交易(ADR-3:独立于被测 DS 读)。
    final rows = await (db.select(db.transactions)
          ..where((x) => x.description.equals('订链会员')))
        .get();
    expect(rows.length, 3, reason: '交易 description=模板名,恰 3 笔');
    final dates = rows
        .map((r) => DateTime.utc(r.transactionDate.year, r.transactionDate.month,
            r.transactionDate.day))
        .toList()
      ..sort();
    expect(dates, [
      DateTime.utc(2026, 7, 2),
      DateTime.utc(2026, 8, 2),
      DateTime.utc(2026, 9, 2),
    ], reason: '各期交易日=当时的 nextDate');

    // oracle:expense 方向 credit 资金账户 → 余额 −3×2,500 = −7,500 分。
    expect(await balanceOf(db, fundsId), beforeFunds - 3 * 2500,
        reason: '订阅补账:资金 −3×金额');

    // nextDate 前移至 fixedToday 之后(2026-10-02),下一轮不再补。
    final after = await templatesDs.get(subId);
    expect(after.nextDate, '2026-10-02', reason: 'nextDate 前移至今天之后');
  });

  testWidgets('订链②endDate 截断:endDate=今天−1 个月 → 只补到 endDate 为止(2 笔)', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 9,925.00(① 之后)

    // 本测试自包含夹具(照 T1 收链① 模式):订链早停,月度 12.00,同起点
    // (startDate = fixedToday −3 个月);endDate = fixedToday −1 个月(2026-08-02)。
    await templatesDs.create(
      name: '订链早停',
      amountCents: 1200, // 12.00
      direction: TemplateDirection.expense,
      sourceAccountId: fundsId,
      cycle: TemplateCycle.monthly,
      billingDay: 0,
      startDate: iso(DateTime(fixedToday.year, fixedToday.month - 3, fixedToday.day)),
      endDate: iso(DateTime(fixedToday.year, fixedToday.month - 1, fixedToday.day)),
      autoRecord: true,
    );

    // 上一轮后订链会员 nextDate 已是 2026-10-02(> today)→ 本轮 0 笔;
    // 订链早停 nextDate=2026-07-02,endDate=2026-08-02:
    // 07-02、08-02(≤ endDate 含当日)各记 1 笔,09-02 > endDate 停 → 2 笔。
    final result = await scheduler.run(fixedToday);
    expect(result.templates, 2, reason: '两个 autoRecord 模板(其一已无到期)');
    expect(result.recorded, 2, reason: 'endDate 截断后只补 2 期');
    expect(result.failed, 0);

    final rows = await (db.select(db.transactions)
          ..where((x) => x.description.equals('订链早停')))
        .get();
    expect(rows.length, 2, reason: '只到 endDate 为止');
    final dates = rows
        .map((r) => DateTime.utc(r.transactionDate.year, r.transactionDate.month,
            r.transactionDate.day))
        .toList()
      ..sort();
    expect(dates, [DateTime.utc(2026, 7, 2), DateTime.utc(2026, 8, 2)],
        reason: '发生日逐期推进且不越过 endDate');

    // oracle:资金 −2×1,200 = −2,400 分。
    expect(await balanceOf(db, fundsId), beforeFunds - 2 * 1200,
        reason: 'endDate 截断:资金只扣 2 期');

    // 订链会员未被本轮重复补记(仍是 3 笔,nextDate 停在未来)。
    final memberRows = await (db.select(db.transactions)
          ..where((x) => x.description.equals('订链会员')))
        .get();
    expect(memberRows.length, 3, reason: '已补齐的模板不再重复记账');
  });

  testWidgets('订链③空 category 兜底:自动建「订阅·<模板名>」分类账户(a7e580ac 回归)', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 9,901.00(② 之后)

    // 前置:兜底账户尚不存在(按名查账户列表)。
    final namesBefore = (await accounts.list()).map((a) => a.name);
    expect(namesBefore, isNot(contains('订阅·订链无类')),
        reason: '兜底前不存在同名分类账户');

    final res = await templatesDs.record(fbId);

    // 兜底账户已建:名为「订阅·<模板名>」,expense 方向 → 类型 5(expense)。
    final accs = await accounts.list();
    final fbAcc = accs.firstWhere((a) => a.name == '订阅·订链无类');
    expect(fbAcc.accountType, AccountType.expense,
        reason: 'expense 模板兜底建 expense 分类账户');

    // 交易入列:兜底账户在借方(debit=金额)、资金账户在贷方(credit=金额)。
    final txn = await txns.getById(res.transactionId);
    expect(txn.description, '订链无类');
    final debitLeg =
        txn.entries.firstWhere((e) => e.accountId == fbAcc.id);
    expect(debitLeg.debitCents, 3900, reason: '兜底账户承接借方');
    final creditLeg =
        txn.entries.firstWhere((e) => e.accountId == fundsId);
    expect(creditLeg.creditCents, 3900, reason: '资金账户承接贷方');

    // oracle:资金 −3,900 分。
    expect(await balanceOf(db, fundsId), beforeFunds - 3900,
        reason: '空 category 模板记账照常联动资金余额');
  });

  testWidgets('模链④模板 record:字段一致 + 余额联动 + nextDate 推进 + 暂停守卫', (t) async {
    final beforeFunds = await balanceOf(db, fundsId); // 9,862.00(③ 之后)
    final beforeCat = await balanceOf(db, catId); // 0.00

    // record 时 nextDate = 2026-07-02(create 时算好,首期发生日)。
    final res = await templatesDs.record(tplId);

    // 交易字段与模板一致:description=模板名、交易日=record 时 nextDate、
    // expense 方向配对复式(debit 分类 / credit 资金)。
    final txn = await txns.getById(res.transactionId);
    expect(txn.description, '模链月费');
    expect(txn.transactionDate, DateTime.utc(2026, 7, 2),
        reason: '交易日 = record 时的 nextDate');
    expect(txn.entries, hasLength(2));
    final catLeg = txn.entries.firstWhere((e) => e.accountId == catId);
    expect(catLeg.debitCents, 8800);
    expect(catLeg.creditCents, 0);
    final fundsLeg = txn.entries.firstWhere((e) => e.accountId == fundsId);
    expect(fundsLeg.debitCents, 0);
    expect(fundsLeg.creditCents, 8800);

    // oracle:资金(asset,debit−credit)−8,800;分类(expense 同向)借方 +8,800。
    expect(await balanceOf(db, fundsId), beforeFunds - 8800,
        reason: '资金账户 −金额');
    expect(await balanceOf(db, catId), beforeCat + 8800,
        reason: '分类账户借方 +金额(expense:debit−credit)');

    // nextDate 推进一个周期(07-02 → 08-02),lastTransactionId 落位。
    final after = await templatesDs.get(tplId);
    expect(after.nextDate, '2026-08-02', reason: 'nextDate 推进一个周期');
    expect(after.lastTransactionId, res.transactionId,
        reason: 'lastTransactionId = 本次交易 id');
    expect(res.nextDate, DateTime.utc(2026, 8, 2),
        reason: 'RecordResult 返回推进后的 nextDate');

    // 暂停模板 → record 抛「模板已暂停」。
    await templatesDs.pause(tplId);
    await expectLater(
      templatesDs.record(tplId),
      throwsA(isA<ServerFailure>()
          .having((f) => f.message, 'message', '模板已暂停')),
    );
  });
}
