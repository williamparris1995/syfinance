/// F43 财务报告全链 E2E(T6,管道链路,真实本地数据源 + 真实 UI 走查)
/// + F45 T3 导出入口可达断言 + F46 T3 AI 分析师缺省面断言(报链④:设置
/// 卡可达+六行+未启用禁用态;报告页「AI 解读」未启用缺席 —— 真实 LLM
/// 调用绝不进 e2e,边界注释见该链)。
///
/// 链路:种子(账户+分录+预算+持仓+闲置模板最小集)→ 侧栏「报表分析」
/// → 顶栏「财务报告」入口(/reports)→ /reports/full(视觉对齐批次:shell
/// 内页)选期(上一期步进到种子月,翻期自动重生成)→ 断言七章节关键数值
/// 与诊断发现(手算 oracle)+ 自适应缺席(种子缺预算的月:预算/投资章
/// 缺席 + 未包含项附注)+ F45 导出入口(Loaded 态「导出」按钮 + 格式
/// 菜单 PDF/Markdown 两项;真实 saveFile 原生对话框不可 e2e 自动化,断言
/// 到菜单层 —— 见报链③注释边界)→ 测后清库。
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
///   模板:报链视频会员 月度 15.00,billingDay 9,startDate 2026-05-09,
///         autoRecord=false(F44 T4 闲置夹具:系列首笔 nextAfter(anchor)
///         = 2026-06-09 落六月应扣日,但从未记账;demo 两模板 startDate
///         2026-08,六月/五月应扣日均空)
///
/// 六月 oracle(手算):
///   收支:收入 400,000 / 支出 200,000(debit 单边)/ 结余 200,000 /
///         储蓄率 50.0% / 日均支出 = 200,000 ~/ 30 自然日 = 6,666(视觉
///         对齐批次口径,原型「日均支出」同式)
///   现金流:经营 +400,000 / −200,000;投资 −230,000;融资 +200,000;
///           三类净额 +170,000(= 期末−期初现金,勾稽不变式);明细列:
///           经营 = 语义文案(双侧);投资 =「投资 ¥2,300.00」;融资 =
///           「贷款 ¥2,000.00」(对手分类净额,视觉对齐批次)
///   资产负债(期末,折 CNY):资产 1,800,000[demo 储蓄 1,000,000 + 报链资金
///         570,000 = 储蓄类 1,570,000;投资类 230,000]/ 负债 200,000 /
///         资产负债率 11.1%
///   净资产:期初 1,400,000 → 期末 1,860,000(含持仓期末市值 260,000),
///           +460,000 / +32.9%
///   预算:报链餐饮 actual 200,000(大边=Σdebit)/ limit 250,000 = 80.0%
///   投资:期初市值 0 / 期末 260,000(200 股@13,成交价 ffill)/ 净买入
///         230,000 / 估算收益 +30,000 / 区间 TWR 0.0%(期初零仓约定报 0)
///   诊断(F44,2 warn + 2 info):R4 闲置订阅(应扣日 06-09 无关联记账;
///         nextDate = create 时 nextAfter(start) = 06-09,在期内 → 不落
///         「期末后一周」grace 窗口;周期月数走异常兜底(nextDate 不晚于
///         期内最后应扣日)→ 1 → 月度等价 = 15,000 = ¥150.00)+ H1 支出
///         集中(报链餐饮 200,000 = 当期支出 100.0% ≥ 40%)+ R5 单笔大额
///         ×2(日均 = 200,000÷30 自然日 = 6,667 → 3×门槛 20,000、占比门槛
///         40,000:6/12 报链午餐 120,000(18.0 倍/60.0%)与 6/22 报链晚餐
///         80,000(12.0 倍/40.0%)双门槛均过);R1/R6/R2/R3 手推全不触发
///         (储蓄率 50%、runway 1,570,000÷66,666≈23.6 月、预算未超支、
///         负债率 11.1%)→ 0 风险 2 提示 2 关注,序 [R4,H1,R5,R5]。
///   对比期:五月无收支 → 首期无对比数据
/// 五月 oracle(自适应缺席):无分录无预算无持仓 → 六章缺预算/投资两章,
///   未包含项附注两条;净资产期初=期末 1,400,000;对比期(四月)空 → 首期;
///   诊断零发现(模板应扣日空/收支空/trailing3m=0)→ 第七章健康卡 +
///   总览单行健康徽章(储蓄率 0.0%、资产负债率 0.0%;runway 无基数省略)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/financial_report_e2e_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
library;

import 'package:flutter/material.dart' show IgnorePointer, Switch, TextField;
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
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
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

    // F44 T4 闲置模板:月度 150.00,startDate/billingDay 05-09 → 系列
    // 首笔 nextAfter(start) = 2026-06-09 = create 内 nextDate(锚 startDate,
    // 与运行日无关)→ 六月应扣日 [06-09];未暂停 + 从未记账 → R4 闲置。
    // nextDate 06-09 在期内(< 期末,grace 窗口按「期末后一周」判,任何
    // 运行时区都不误宽限);autoRecord=false → 启动调度器(autoRecord &&
    // !paused 谓词)不推进 nextDate,任意运行日结论不变;五月应扣日空
    // (系列首笔 06-09 > 05-31)→ 五月零发现不受影响。
    final templates = TemplateLocalDataSource(db, txns);
    await templates.create(
      name: '报链视频会员',
      amountCents: 15000, // 150.00
      direction: TemplateDirection.expense,
      sourceAccountId: fundsId,
      cycle: TemplateCycle.monthly,
      billingDay: 9,
      startDate: '2026-05-09',
      autoRecord: false,
    );
  });

  // 测试数据生命周期收尾:close 后删独立测试库(种子+夹具全清)。
  tearDownAll(deleteTestDb);

  /// 真实启动 app → 侧栏「报表分析」→ 顶栏「财务报告」→ /reports/full
  /// (视觉对齐批次:shell 内页,侧栏/顶栏常驻)→ 期控件步进到
  /// [year] 年 [month] 月。
  ///
  /// 范式(视觉对齐批次同步,a647b72a 反馈②之后):翻期**自动重新生成**
  /// —— Initial 态直接步进,第一步即触发上一期的完整生成(Loading→
  /// Loaded),步进到目标月即得该月报告;不再「步进后点生成报告」
  /// (Loaded 态无生成按钮,旧范式已不可用)。GlobalKey 重叠异常由
  /// 章节锚 key 池按文档令牌换池修复(widget 测试钉死),翻期链路零异常。
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
    //(运行日任意,步数 = 月差,方向随目标在过去/未来);每步自动重生成,
    // 每步等生成 + 过渡收尾再步下一步。
    final now = DateTime.now();
    final diff = (now.year * 12 + now.month) - (year * 12 + month);
    final tooltip = diff >= 0 ? '上一期' : '下一期';
    for (var i = 0; i < diff.abs(); i++) {
      await t.tap(find.byTooltip(tooltip).first);
      await t.pumpAndSettle(const Duration(milliseconds: 800));
    }
    expect(find.text('$year 年 $month 月'), findsOneWidget,
        reason: '期标签已步进到 $year 年 $month 月(自动重生成完毕)');
  }

  testWidgets('报链①六月全量:七章在列 + 关键数值与诊断发现(手算 oracle)', (t) async {
    await openReport(t, year: 2026, month: 6);

    // 七章标题齐(章节头 + 右缘锚点标签各一处;F44 第七章恒在列)。
    for (final title in [
      '总览',
      '资产负债',
      '收支',
      '现金流',
      '预算执行',
      '投资绩效',
      '诊断与建议',
    ]) {
      expect(find.text(title), findsWidgets, reason: '章节「$title」在列');
    }
    expect(find.byKey(const ValueKey('sectionDot-5')), findsOneWidget,
        reason: '第 6 锚点(投资绩效)在列');
    expect(find.byKey(const ValueKey('sectionDot-6')), findsOneWidget,
        reason: '第 7 锚点(诊断与建议)在列');

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

    // —— 收支:金额 + 科目名 + 日均支出 + 首期对比缺席 ——
    expect(find.text('¥4,000.00'), findsWidgets,
        reason: '收入 400,000(指标卡 + 经营流入 + 收入构成)');
    expect(find.text('¥2,000.00'), findsWidgets, reason: '支出 200,000');
    expect(find.text('+¥2,000.00'), findsWidgets, reason: '结余 200,000');
    expect(find.text('日均支出'), findsOneWidget, reason: '摘要行口径 = 日均支出');
    expect(find.text('¥66.66'), findsOneWidget,
        reason: '日均支出 = 200,000 ~/ 30 自然日(视觉对齐批次口径)');
    expect(find.text('首期无对比数据'), findsOneWidget,
        reason: '五月(对比期)无收支 → 首期');
    expect(find.text('报链工资'), findsOneWidget,
        reason: '收入科目名(T5-R1 分类名称契约)');
    expect(find.text('报链餐饮'), findsWidgets, reason: '支出科目名 + 预算行名');

    // —— 现金流:三类活动 + 合计 + 明细列 + 勾稽脚注 ——
    expect(find.text('¥6,000.00'), findsOneWidget,
        reason: '合计流入 = 经营 4,000 + 融资 2,000');
    expect(find.text('¥4,300.00'), findsOneWidget,
        reason: '合计流出 = 经营 2,000 + 投资 2,300');
    expect(find.text('-¥2,300.00'), findsOneWidget, reason: '投资净额 −230,000');
    // 明细列(视觉对齐批次,原型 v9 五列):经营 = 矩阵语义文案;投资/
    // 融资 = 对手分类净额(investment/loan 唯一对手)。
    expect(find.text('明细'), findsOneWidget, reason: '明细列表头在列');
    expect(find.text('工资等日常收入 · 日常消费支出'), findsOneWidget,
        reason: '经营明细 = 分类器矩阵语义(双侧在场)');
    expect(find.text('投资 ¥2,300.00'), findsOneWidget,
        reason: '投资明细 = 对手分类净额(报链证券账户 investment)');
    expect(find.text('贷款 ¥2,000.00'), findsOneWidget,
        reason: '融资明细 = 对手分类净额(报链房贷 loan)');
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

    // —— 诊断与建议(F44):第七章节 + Finding 文案 + 总览摘要卡 ——
    // 4 发现 = R4/H1 两 warn + R5 两 info;序 [R4,H1,R5,R5] → 0 风险
    // 2 提示 2 关注,top-3 = R4/H1/R5(午餐笔)。注:textContainingRich
    // 对每处文案命中 Text + 其内 RichText 两个 widget(文件头注同款),
    // 每条结论两个渲染位(摘要卡 + 第七章)→ 4;仅第七章 → 2。
    expect(find.text('诊断摘要 · 0 风险 2 提示 2 关注'), findsOneWidget,
        reason: '总览摘要卡计数头(R4 闲置 + H1 集中 + R5 大额 ×2)');
    expect(find.text('提示 · 2'), findsOneWidget,
        reason: '第七章分组头(warn 组,空组不渲染)');
    // R4 结论文案:摘要卡 top-3 首行 + 第七章卡各一处(文案直出引擎)。
    expect(textContainingRich('可能闲置:1 个支出订阅(报链视频会员)'),
        findsNWidgets(4), reason: 'R4 闲置订阅结论(摘要卡 + 第七章)');
    expect(textContainingRich('月度等价合计约 ¥150.00'), findsNWidgets(4),
        reason: 'R4 月度等价 = 15,000 ÷ 1 个月周期(异常兜底:nextDate 不晚于末应扣日)');
    expect(find.text('前往订阅中心 →'), findsOneWidget,
        reason: 'R4 actionLink 跳转按钮(唯一 actionLink)');
    // H1 结论文案:摘要卡 top-3 次行 + 第七章卡各一处。
    expect(textContainingRich('支出集中于「报链餐饮」类别'), findsNWidgets(4),
        reason: 'H1 集中结论(摘要卡 + 第七章)');
    expect(textContainingRich('占当期总支出 100.0%'), findsNWidgets(4),
        reason: 'H1 占比 = 200,000 / 200,000');
    // R5(顺带钉死数值):午餐笔 = top-3 第三行 + 第七章卡;晚餐笔只在第七章。
    expect(textContainingRich('「报链午餐」¥1,200.00'), findsNWidgets(4),
        reason: 'R5 午餐笔(120,000 = 日均 6,667 的 18.0 倍/占 60.0%)');
    expect(textContainingRich('「报链晚餐」¥800.00'), findsNWidgets(2),
        reason: 'R5 晚餐笔(12.0 倍/占 40.0%,top-3 容量外仅第七章)');
    // 行尾语义 chip(视觉对齐批次):R5 午餐笔在 top-3 → 摘要卡 1 枚中性
    // chip「≥ 日均支出×3」;R4/H1 无 chip,R5 晚餐笔不在 top-3。
    expect(find.text('≥ 日均支出×3'), findsOneWidget,
        reason: 'R5 行尾中性 chip(阈值标签,仅摘要卡渲染)');
    expect(find.text('查看全部 ↓'), findsOneWidget,
        reason: '摘要卡「查看全部」锚滚入口(mdaViewAllLink)');
  });

  testWidgets('报链②五月自适应:预算/投资章缺席 + 未包含项附注 + 零发现健康态', (t) async {
    await openReport(t, year: 2026, month: 5);

    // 五章在列(前四章 + F44 第七章恒在列);两个自适应章节(FR-3)缺席
    // —— 章节头与锚点一并。
    for (final title in ['总览', '资产负债', '收支', '现金流', '诊断与建议']) {
      expect(find.text(title), findsWidgets, reason: '章节「$title」在列');
    }
    expect(find.text('预算执行'), findsNothing, reason: '五月无预算行 → 章节缺席');
    expect(find.text('投资绩效'), findsNothing, reason: '五月三点全零 → 章节缺席');
    expect(find.byKey(const ValueKey('sectionDot-4')), findsOneWidget,
        reason: '锚点链 = 5 点(四固定章 + 诊断与建议,末位 index 4)');
    expect(find.byKey(const ValueKey('sectionDot-5')), findsNothing,
        reason: '预算/投资缺席 → 第 6 锚点不在');

    // 未包含项附注披露两条(FR-3 自适应的显式表达)。
    expect(find.text('未包含项'), findsOneWidget);
    expect(find.textContaining('本期无预算'), findsOneWidget);
    expect(find.textContaining('本期无持仓'), findsOneWidget);

    // 空月口径:净资产期初 = 期末(demo 储蓄 10,000 + 报链资金 4,000)。
    expect(find.text('¥14,000.00'), findsWidgets,
        reason: '期初 = 期末净资产 14,000(hero 两处 + 变动表行)');
    expect(find.text('首期无对比数据'), findsOneWidget,
        reason: '四月(对比期)无收支 → 首期');

    // —— 诊断与建议(F44):零发现两态 ——
    expect(find.text('本期诊断:0 风险 0 提示 0 关注 · 未发现需关注项 ✓'),
        findsOneWidget,
        reason: '总览单行健康徽章(零发现态)');
    expect(find.text('本期诊断未发现需关注项'), findsOneWidget,
        reason: '第七章健康卡标题');
    expect(find.text('储蓄率 0.0%、资产负债率 0.0%,均在健康区间'), findsOneWidget,
        reason: '健康卡通过项(runway 无基数 trailing3m=0 → 第三段省略)');
    expect(find.text('查看全部 ↓'), findsNothing,
        reason: '零发现态无 top-3 摘要卡(整卡降级为徽章)');
  });

  testWidgets('报链③导出入口:Loaded 态「导出」按钮 + 格式菜单 PDF/Markdown 两项',
      (t) async {
    await openReport(t, year: 2026, month: 6);

    // —— F45 T2 入口(FR-1):Loaded 态页头「导出」按钮在列 ——
    // key 与 tooltip 双锚(tooltip 与保存对话框标题同词,文案统一)。
    expect(find.byKey(const ValueKey('reportExportButton')), findsOneWidget,
        reason: 'Loaded 态导出按钮在列(Initial 态缺席由 widget 测试钉)');
    expect(find.byTooltip('导出财务报告'), findsOneWidget);

    // —— 格式菜单可弹:PDF/Markdown 两项(桌面单后缀形态的格式切换层)——
    await t.tap(find.byKey(const ValueKey('reportExportButton')));
    await t.pumpAndSettle(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('reportExportFormatPdf')), findsOneWidget,
        reason: '格式菜单 PDF 项');
    expect(find.byKey(const ValueKey('reportExportFormatMarkdown')),
        findsOneWidget,
        reason: '格式菜单 Markdown 项');

    // —— 边界(钉死):选中格式后会唤起 FilePicker.saveFile 原生保存
    // 对话框 —— 系统级 UI 无 e2e 句柄,不可自动化;本链断言到格式菜单
    // 层为止。选中后的完整导出流(默认文件名「御财财务报告-2026年06月」/
    // 落盘 bytes/toast/打开)由 widget 测试以注入缝全覆盖
    // (financial_report_page_export_test,e2e 不重复)。
    // 此处点空白处收起菜单(full_audit 范式),零副作用退出 —— 不触
    // 真实对话框、零文件写入。视觉对齐批次:页面挂 shell branch 后,
    // 菜单 route 推在 **branch 嵌套 navigator**(覆盖面 = 内容区,不含
    // 侧栏)——收起点击须落在内容区内(旧坐标 (5,400) 落在侧栏 nav
    // 项上,会切走分支且菜单不收);取内容区中部空白(两种布局皆在
    // 页身,无交互件)。
    await t.tapAt(const Offset(500, 300));
    await t.pumpAndSettle(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('reportExportFormatPdf')), findsNothing,
        reason: '菜单已收起(未选中任何格式,导出链未触发)');
  });

  // F46 T3:AI 分析师缺省面(两页)。种子库 = bootstrap load 后 secure
  // storage 无 llm.* 键 → LlmConfig 缺省 enabled=false → ready=false。
  testWidgets('报链④AI 分析师缺省面:设置卡六行+未启用禁用态;报告页「AI 解读」未启用缺席',
      (t) async {
    // —— 边界(钉死):真实 LLM 调用绝不进 e2e —— BYOK 出站 = 网络 +
    // 计费 + 用户 API Key,自动化回归零触网。本链只断言「未启用」缺省
    // 面,不扳启用开关、零网络;启用流(免责对话框)/配置写入/narrate
    // 三态由 widget 测试以注入缝全覆盖(llm_settings_card_test /
    // financial_report_page_analyst_test),e2e 不重复。
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));

    // —— 设置页:卡可达 + 六行(默认服务商=智谱 → 无「服务端点」行)——
    await goPage(t, '设置');
    final card = find.text('AI 分析师');
    await t.ensureVisible(card);
    await t.pumpAndSettle();
    expect(card.evaluate(), isNotEmpty, reason: '设置页「AI 分析师」卡可达');
    for (final label in [
      '启用 AI 分析师',
      '服务商',
      'API Key',
      '模型名',
      '城市规模',
      '订阅名明文',
    ]) {
      final row = find.text(label);
      await t.ensureVisible(row.first);
      await t.pumpAndSettle();
      expect(row.evaluate(), isNotEmpty, reason: '设置卡行「$label」渲染');
    }
    expect(find.text('服务端点'), findsNothing,
        reason: '默认智谱 → 自定义端点输入行缺席(恰六行)');

    // —— 未启用禁用态(v9 .llm-cfg.off):开关关 + 输入框禁用 + 配置区罩住 ——
    expect(
        t.widget<Switch>(find.byKey(const ValueKey('llmEnableSwitch'))).value,
        isFalse,
        reason: '种子库默认未启用(Migration Plan 缺省关)');
    expect(
        t.widget<TextField>(find.byKey(const ValueKey('llmApiKeyInput')))
            .enabled,
        isFalse,
        reason: '未启用 → API Key 输入禁用');
    expect(
        t.widget<TextField>(find.byKey(const ValueKey('llmModelInput')))
            .enabled,
        isFalse,
        reason: '未启用 → 模型名输入禁用');
    expect(
        t.widgetList<IgnorePointer>(find.ancestor(
                of: find.byKey(const ValueKey('llmProviderSeg')),
                matching: find.byType(IgnorePointer)))
            .any((w) => w.ignoring),
        isTrue,
        reason: '未启用 → 配置行被罩住(v9 pointer-events:none)');

    // —— 报告页:「AI 解读」入口未启用缺席。入口门 = ready && Loaded,
    // 未启用(ready=false):Initial 态(非 Loaded)缺席;Loaded 态恒显灰态
    // 引导按钮(热修 2026-09-28 反馈④:可发现性优先,点击无副作用)。
    await goPage(t, '报表分析');
    await t.pumpAndSettle(const Duration(seconds: 2));
    await t.tap(find.byKey(const ValueKey('financialReportEntryButton')));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('analystNarrateButton')), findsNothing,
        reason: '未启用 → Initial 态(非 Loaded)无「AI 解读」按钮');
    await t.tap(find.text('生成报告').first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byKey(const ValueKey('analystNarrateButton')), findsOneWidget,
        reason: '未启用 → Loaded 态灰态按钮可见(可发现性热修)');
    await t.tap(find.byKey(const ValueKey('analystNarrateButton')));
    await t.pump();
    expect(find.text('解读生成中…'), findsNothing,
        reason: '灰态点击零 LLM 调用');
    expect(find.text('分析师解读'), findsNothing,
        reason: '解读小节 idle 自隐(从未触发 narrate,零 LLM 调用)');
  });
}
