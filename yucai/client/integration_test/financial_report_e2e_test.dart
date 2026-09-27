/// F43 财务报告全链 E2E(T6,管道链路,真实本地数据源 + 真实 UI 走查)。
///
/// 链路:种子(账户+分录+预算+持仓最小集)→ 侧栏「报表分析」→ 顶栏
/// 「财务报告」入口(/reports)→ /reports/full 选期(上一期步进到种子月)
/// →「生成报告」→ 断言六章节关键数值(手算 oracle)+ 自适应缺席(种子
/// 缺预算的月:预算/投资章缺席 + 未包含项附注)→ 测后清库。
///
/// 夹具月固定 2026-06(过去月):demo 种子的交易/借入/持仓买入全部写在
/// 真实运行当月(≥ 2026-09 > 六月),六月窗口与六月末回放天然不含 demo
/// 分录 —— 绝对口径只余 demo 储蓄卡初始 1,000,000 分(常量,demo_seed)
/// 与本夹具,oracle 可手算;运行当月与六月不重合,任何未来运行日不变。
///
/// 夹具账本(报链* 前缀,金额单位分,日期全 UTC 月中避月界):
///   账户:报链资金 savings 资产 初始 400,000;报链餐饮 expense;
///         报链工资 income;报链证券账户 investment 资产;报链房贷 liability
///   t1 06-05 收入工资 400,000(借资金/贷工资)
///   t2 06-12 餐饮支出 120,000(借餐饮/贷资金)
///   t3 06-22 餐饮支出  80,000(借餐饮/贷资金)
///   t4 06-18 借入房贷 200,000(借资金/贷房贷,融资腿)
///   b1 06-10 买入 100 股 @10.00(现金腿 100,000,fee 0)
///   b2 06-20 买入 100 股 @13.00(现金腿 130,000,fee 0)
///   预算:2026-06 报链餐饮 限额 250,000
///
/// 六月 oracle(手算):
///   收支:收入 400,000 / 支出 200,000(debit 单边)/ 结余 200,000 /
///         储蓄率 50.0% / 活跃日 3(05/12/22)→ 日均 66,666
///   现金流:经营 +400,000 / −200,000;投资 −230,000;融资 +200,000;
///           三类净额 +170,000(= 期末−期初现金,勾稽不变式)
///   资产负债(期末,折 CNY):资产 1,800,000[demo 储蓄 1,000,000 + 报链资金
///         570,000 = 储蓄类 1,570,000;投资类 230,000]/ 负债 200,000 /
///         资产负债率 11.1%
///   净资产:期初 1,400,000 → 期末 1,860,000(含持仓期末市值 260,000),
///           +460,000 / +32.9%
///   预算:报链餐饮 actual 200,000(大边=Σdebit)/ limit 250,000 = 80.0%
///   投资:期初市值 0 / 期末 260,000(200 股@13,成交价 ffill)/ 净买入
///         230,000 / 估算收益 +30,000 / 区间 TWR 0.0%(期初零仓约定报 0)
///   对比期:五月无收支 → 首期无对比数据
/// 五月 oracle(自适应缺席):无分录无预算无持仓 → 六章缺预算/投资两章,
///   未包含项附注两条;净资产期初=期末 1,400,000;对比期(四月)空 → 首期。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/financial_report_e2e_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:flutter/widgets.dart' show ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide TransactionEntry;
import 'package:yucai_client/holding/data/holding_local_ds.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

import 'link_support.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等演示种子(照 link_tag_report_test)。
    await resetTestDb();
    final db = getIt<AppDatabase>();
    final accounts = AccountLocalDataSource(db);
    final txns = TransactionLocalDataSource(db, BalanceLocalUpdater(db));
    final budgets = BudgetLocalDataSource(db);
    final holdings = HoldingLocalDataSource(db, txns);

    // ---- 自包含夹具(报链* 前缀,与演示数据零耦合;见文件头账本)----
    final fundsId = await fundsAccount('报链资金', 400000); // 4,000.00
    Future<String> subject(String name, AccountType type,
            AccountCategory category) async =>
        (await accounts.create(CreateAccountParams(
          name: name,
          accountType: type,
          category: category,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          ownership: Ownership.personal,
        )))
            .id;
    final diningId = await subject('报链餐饮', AccountType.expense,
        AccountCategory.otherAsset);
    final salaryId = await subject(
        '报链工资', AccountType.income, AccountCategory.otherAsset);
    final investId = await subject(
        '报链证券账户', AccountType.asset, AccountCategory.investment);
    final loanId =
        await subject('报链房贷', AccountType.liability, AccountCategory.loan);

    // 配对复式(照 demo_seed / template_local_ds 的借贷形态)。
    Future<void> record(DateTime d, String desc, String debitId, int debit,
        String creditId, int credit) async {
      await txns.recordTransaction(RecordTransactionParams(
        transactionDate: d,
        description: desc,
        entries: [
          TransactionEntry(accountId: debitId, debitCents: debit, creditCents: 0),
          TransactionEntry(
              accountId: creditId, debitCents: 0, creditCents: credit),
        ],
      ));
    }

    // t1..t4(顺序无关,余额守卫只在买入处涉及:资金各时点均足额)。
    await record(DateTime.utc(2026, 6, 5), '报链工资入账', fundsId, 400000,
        salaryId, 400000);
    await record(DateTime.utc(2026, 6, 12), '报链午餐', diningId, 120000,
        fundsId, 120000);
    await record(DateTime.utc(2026, 6, 22), '报链晚餐', diningId, 80000,
        fundsId, 80000);
    await record(DateTime.utc(2026, 6, 18), '报链借入', fundsId, 200000,
        loanId, 200000);

    // b1/b2:两笔不同价买入(期末市值用 b2 成交价 ffill → 估算收益非零)。
    final sec = await holdings.createSecurity(
      symbol: 'F43RPT01',
      name: '报链稳健混合',
      type: SecurityType.fund,
      exchange: 'CN',
      currency: 'CNY',
    );
    await holdings.buy(
      accountId: investId,
      securityId: sec.id,
      fromAccountId: fundsId,
      quantity: 100,
      priceCents: 1000, // 10.00 → 现金腿 100,000
      tradeDate: '2026-06-10',
    );
    await holdings.buy(
      accountId: investId,
      securityId: sec.id,
      fromAccountId: fundsId,
      quantity: 100,
      priceCents: 1300, // 13.00 → 现金腿 130,000
      tradeDate: '2026-06-20',
    );

    // 预算:六月餐饮限额 250,000(actual 口径 = 大边 Σdebit = 200,000)。
    await budgets.createBudget(
      name: '报链六月伙食',
      month: '2026-06',
      currencyCode: 'CNY',
      items: [
        (accountId: diningId, plannedAmountCents: 250000, notes: null),
      ],
    );
  });

  // 测试数据生命周期收尾:close 后删独立测试库(种子+夹具全清)。
  tearDownAll(deleteTestDb);

  /// 真实启动 app → 侧栏「报表分析」→ 顶栏「财务报告」→ /reports/full
  /// → 期控件步进到 [year] 年 [month] 月 →「生成报告」。
  Future<void> openReport(WidgetTester t,
      {required int year, required int month}) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
    await goPage(t, '报表分析');
    await t.pumpAndSettle(const Duration(seconds: 2));
    // F43 T5(FR-1)入口:报表分析顶栏「财务报告」按钮 → /reports/full。
    await t.tap(find.byKey(const ValueKey('financialReportEntryButton')));
    await t.pumpAndSettle(const Duration(seconds: 2));
    // 选期:页面缺省 = 当前自然月;步进(上一期/下一期)到种子月
    //(运行日任意,步数 = 月差,方向随目标在过去/未来)。
    final now = DateTime.now();
    final diff = (now.year * 12 + now.month) - (year * 12 + month);
    final tooltip = diff >= 0 ? '上一期' : '下一期';
    for (var i = 0; i < diff.abs(); i++) {
      await t.tap(find.byTooltip(tooltip).first);
      await t.pumpAndSettle(const Duration(milliseconds: 400));
    }
    expect(find.text('$year 年 $month 月'), findsOneWidget,
        reason: '期标签已步进到 $year 年 $month 月');
    // 生成(Initial 态页头与引导卡各一枚按钮,取树序首个 = 页头)。
    await t.tap(find.text('生成报告').first);
    await t.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('报链①六月全量:六章在列 + 六章节关键数值(手算 oracle)', (t) async {
    await openReport(t, year: 2026, month: 6);

    // 六章标题齐(章节头 + 右缘锚点标签各一处)。
    for (final title
        in ['总览', '资产负债', '收支', '现金流', '预算执行', '投资绩效']) {
      expect(find.text(title), findsWidgets, reason: '章节「$title」在列');
    }
    expect(find.byKey(const ValueKey('sectionDot-5')), findsOneWidget,
        reason: '第 6 锚点(投资绩效)在列');

    // —— 总览:期初/期末净资产 + 变动 + 储蓄率 + 现金净变动 ——
    expect(find.text('¥14,000.00'), findsWidgets,
        reason: '期初净资产(hero + 变动表净资产/储蓄类行同额)');
    expect(find.text('¥18,600.00'), findsWidgets,
        reason: '期末净资产(hero + 变动表净资产行)');
    expect(find.text('+¥4,600.00'), findsWidgets,
        reason: '净资产变动(hero chip + 变动表行)');
    expect(find.text('+32.9%'), findsOneWidget, reason: '净资产变动 % 460,000/1,400,000');
    expect(find.text('50.0%'), findsWidgets, reason: '储蓄率 200,000/400,000');
    expect(find.text('+¥1,700.00'), findsWidgets,
        reason: '现金净变动(slim 卡 + 现金流合计 + 储蓄类变动行)');

    // —— 收支:金额 + 科目名 + 日均 + 首期对比缺席 ——
    expect(find.text('¥4,000.00'), findsWidgets,
        reason: '收入 400,000(指标卡 + 经营流入 + 收入构成)');
    expect(find.text('¥2,000.00'), findsWidgets, reason: '支出 200,000');
    expect(find.text('+¥2,000.00'), findsWidgets, reason: '结余 200,000');
    expect(find.text('¥666.66'), findsOneWidget,
        reason: '日均结余 = 200,000 ~/ 3 活跃日');
    expect(find.text('首期无对比数据'), findsOneWidget,
        reason: '五月(对比期)无收支 → 首期');
    expect(find.text('报链工资'), findsOneWidget,
        reason: '收入科目名(T5-R1 分类名称契约)');
    expect(find.text('报链餐饮'), findsWidgets, reason: '支出科目名 + 预算行名');

    // —— 现金流:三类活动 + 合计 + 勾稽脚注 ——
    expect(find.text('¥6,000.00'), findsOneWidget,
        reason: '合计流入 = 经营 4,000 + 融资 2,000');
    expect(find.text('¥4,300.00'), findsOneWidget,
        reason: '合计流出 = 经营 2,000 + 投资 2,300');
    expect(find.text('-¥2,300.00'), findsOneWidget, reason: '投资净额 −230,000');
    // 注:textContainingRich 对 Text.rich 会同时命中其内部 RichText
    //(同一处文案两个 widget),故用 findsWidgets 而非单数。
    expect(textContainingRich('与期末−期初现金余额一致'), findsWidgets,
        reason: '勾稽脚注(三类净额 +170,000 = Δcash)');

    // —— 资产负债:期末构成 + 合计 + 资产负债率 ——
    expect(find.text('¥18,000.00'), findsOneWidget, reason: '期末资产合计');
    expect(find.text('¥15,700.00'), findsWidgets,
        reason: '储蓄类构成 = demo 10,000 + 报链资金 5,700(构成 + 变动表期末行)');
    expect(find.textContaining('资产负债率 11.1%'), findsOneWidget,
        reason: '资产负债率 = 2,000/18,000');

    // —— 预算执行:limit + 使用率(未超支)——
    expect(textContainingRich(' / ¥2,500.00'), findsWidgets,
        reason: '预算限额 250,000(富文本 actual / limit)');
    expect(find.text('80.0%'), findsOneWidget,
        reason: '使用率 = 200,000/250,000');

    // —— 投资绩效:期末市值 / 净买入 / 估算收益 / TWR ——
    expect(find.text('¥2,600.00'), findsOneWidget,
        reason: '期末市值 = 200 股 @13.00(ffill)');
    expect(find.text('¥2,300.00'), findsWidgets,
        reason: '净买入 230,000(与投资流出/投资类构成同值多处)');
    expect(find.text('+¥300.00'), findsOneWidget,
        reason: '估算收益 = 2,600 − 0 − 2,300');
    expect(find.text('0.0%'), findsWidgets,
        reason: '区间 TWR 期初零仓约定报 0(otherAsset 零额构成行占比同串)');
  });

  testWidgets('报链②五月自适应:预算/投资章缺席 + 未包含项附注', (t) async {
    await openReport(t, year: 2026, month: 5);

    // 四章在列;两个自适应章节(FR-3)缺席 —— 章节头与锚点一并。
    for (final title in ['总览', '资产负债', '收支', '现金流']) {
      expect(find.text(title), findsWidgets, reason: '章节「$title」在列');
    }
    expect(find.text('预算执行'), findsNothing, reason: '五月无预算行 → 章节缺席');
    expect(find.text('投资绩效'), findsNothing, reason: '五月三点全零 → 章节缺席');
    expect(find.byKey(const ValueKey('sectionDot-4')), findsNothing,
        reason: '锚点同步缺席(仅 4 点)');

    // 未包含项附注披露两条(FR-3 自适应的显式表达)。
    expect(find.text('未包含项'), findsOneWidget);
    expect(find.textContaining('本期无预算'), findsOneWidget);
    expect(find.textContaining('本期无持仓'), findsOneWidget);

    // 空月口径:净资产期初 = 期末(demo 储蓄 10,000 + 报链资金 4,000)。
    expect(find.text('¥14,000.00'), findsWidgets,
        reason: '期初 = 期末净资产 14,000(hero 两处 + 变动表行)');
    expect(find.text('首期无对比数据'), findsOneWidget,
        reason: '四月(对比期)无收支 → 首期');
  });
}
