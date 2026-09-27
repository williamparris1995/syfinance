/// F43 财务报告 —— 汇编编排服务(T4,ADR-1 纯快照)。
///
/// 四阶段编排(FR-8 进度契约,design LLD):loadingLedger → replaying →
/// assembling → performance,onPhase 回调驱动 UI 进度;输出 immutable
/// ReportDocument(F43/F44/F45 三票共享契约)。
///
/// domain 层边界:仅依赖本模块 port(ReportLedgerStore/ExpenseBasis)+
/// holding domain port(HoldingRepository);不 import 任何 data 层
/// (adapter 接线在 DI,ADR-2)。
library;

import 'package:injectable/injectable.dart';

import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/report/domain/balance_replay.dart';
import 'package:yucai_client/report/domain/cash_flow_classifier.dart';
import 'package:yucai_client/report/domain/expense_basis.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/domain/report_ledger_store.dart';

/// 生成阶段(FR-8:读取账本/回放余额/汇编章节/计算绩效)。
enum ReportPhase { loadingLedger, replaying, assembling, performance }

@LazySingleton()
class ReportAssemblyService {
  const ReportAssemblyService(
    this._store,
    this._expenseBasis,
    this._holdings,
  );

  final ReportLedgerStore _store;
  final ExpenseBasis _expenseBasis;
  final HoldingRepository _holdings;

  /// 汇编 [period] 报告期快照;[onPhase] 四阶段进度回调(顺序钉死)。
  Future<ReportDocument> generate(
    ReportPeriod period, {
    void Function(ReportPhase)? onPhase,
  }) async {
    void phase(ReportPhase p) => onPhase?.call(p);

    // —— 1. 读取账本:账户/分录/预算行一次性全量拉取(FR-2 纯本地)。——
    phase(ReportPhase.loadingLedger);
    final accounts = await _store.accounts();
    final entries = await _store.entries();
    final budgetRows = await _store.budgetRows();

    // —— 2. 回放余额 + 汇率簿(外币折 CNY 两级候选,ADR-3)。——
    phase(ReportPhase.replaying);
    final balances = BalanceReplay().replay(
      accounts: accounts,
      entries: entries,
      period: period,
    );
    final rateBook = await _RateBook.load(
      _store, accounts, period.start, period.endInclusive);

    // —— 3. 汇编四大章节(资产负债/收支/现金流;总览待绩效市值收口)。——
    phase(ReportPhase.assembling);
    final income = totalIncome(entries, period);
    final expense = _expenseBasis.totalExpense(entries, period);
    // 现金 = 仅 savings 类资产账户(严格口径,FR-5;谓词单点在
    // CashFlowClassifier.isCashAccount,防余额求和与分录分类两处漂移
    // 打穿勾稽;回放**原币**求和,与分录同单位——现金流勾稽不折算,
    // 折 CNY 仅用于时点数)。
    final cashAccounts = accounts
        .where((a) => CashFlowClassifier.isCashAccount(a.type, a.category))
        .toList(growable: false);
    final cashStart = cashAccounts.fold<int>(
      0, (s, a) => s + (balances[a.id]?.startCents ?? 0));
    final cashEnd = cashAccounts.fold<int>(
      0, (s, a) => s + (balances[a.id]?.endCents ?? 0));
    final balanceSheet = _balanceSheet(accounts, balances, rateBook);
    // T5-R1 分类名称契约:收支构成维度 = 科目账户 id,展示名按
    // id→name 映射挂入(name 缺失 → null,渲染层兜底转译 category)。
    final nameByAccountId = {for (final a in accounts) a.id: a.name};
    final incomeStatement = IncomeStatementSection(
      income: _withNames(incomeByCategory(entries, period), nameByAccountId),
      expense: _withNames(
          _expenseBasis.expenseByCategory(entries, period), nameByAccountId),
      dailyAvgCents: _dailyAvgCents(entries, period, income, expense),
      priorComparison: _priorComparison(entries, period, income - expense),
    );
    final cashFlow = const CashFlowClassifier().classify(
      entries: entries,
      period: period,
      cashStartCents: cashStart,
      cashEndCents: cashEnd,
    );

    // —— 4. 绩效:区间组合绩效(T3 强制本地路由)+ 自适应隐藏。——
    phase(ReportPhase.performance);
    final excluded = <String>[];
    final budget = _budgetSection(budgetRows, entries, period);
    if (budget == null) excluded.add('预算执行(本期无预算)');
    final performance = await _performanceSection(period, excluded);

    // —— 总览收口:净资产 = Σ资产回放[折 C] + 持仓时点市值 − Σ负债回放。
    final assetsStart = _sumConverted(accounts, balances, rateBook, 1, true);
    final assetsEnd = _sumConverted(accounts, balances, rateBook, 1, false);
    final liabStart = _sumConverted(accounts, balances, rateBook, 2, true);
    final liabEnd = _sumConverted(accounts, balances, rateBook, 2, false);

    // —— 附注(FR-3/FR-4):口径三条 + 汇率缺失披露 + 未包含项。——
    final notes = <ReportNote>[
      ReportNote(title: '口径说明', lines: [
        '期初/期末余额由全量分录回放重建,与首页现值口径可能存在小额差额。',
        '净资产与资产负债时点数按历史汇率(该日最近可得,缺失回退现值汇率)'
            '折算为 CNY,属近似口径;现金流与现金净变动为账本原币口径。',
        '现金及等价物仅含 savings(活期)类账户;定期存款按投资活动列示。',
        if (rateBook.skippedCurrencies.isNotEmpty)
          '以下币种无可用汇率,对应账户未折算计入:'
          '${rateBook.skippedCurrencies.join('、')}。',
      ]),
      if (excluded.isNotEmpty)
        ReportNote(
          title: '未包含项',
          lines: [for (final s in excluded) '未包含:$s'],
        ),
    ];

    return ReportDocument(
      period: period,
      generatedAt: DateTime.now().toUtc(),
      overview: OverviewSection.create(
        netWorthStartCents:
            assetsStart + performance.mvStartCents - liabStart,
        netWorthEndCents: assetsEnd + performance.mvEndCents - liabEnd,
        incomeCents: income,
        expenseCents: expense,
        cashDeltaCents: cashEnd - cashStart,
        notes: notes,
      ),
      balanceSheet: balanceSheet,
      incomeStatement: incomeStatement,
      cashFlow: cashFlow,
      budget: budget,
      investment: performance.investment,
      excludedSections: excluded,
    );
  }

  /// 绩效段(generate 第 4 阶段核心):区间组合绩效 → 投资章节 + 净资产
  /// 所需时点市值。
  ///
  /// 「无持仓」判定:无区间分解(坏价/取数失败)或期内三点全零(期初期
  /// 末市值与净买入均为 0 = 期内从未持仓)——不额外调 listHoldings(三态
  /// 路由会走 remote,破坏 FR-2 纯本地汇编)。
  ///
  /// Failure 静默降级:[_fetchPerformance] 的 Left 与坏价 period=null 共用
  /// 「投资绩效(本期无持仓)」一条披露文案——**文案细分(坏价/取数失败
  /// vs 无持仓)记 backlog**,本票不改行为。
  Future<({InvestmentSection? investment, int mvStartCents, int mvEndCents})>
      _performanceSection(ReportPeriod period, List<String> excluded) async {
    final perf = await _fetchPerformance(period);
    final pp = perf?.period;
    final hasPosition = pp != null &&
        (pp.beginMvCents != 0 || pp.endMvCents != 0 || pp.netBuyCents != 0);
    final InvestmentSection? investment = hasPosition
        ? InvestmentSection.create(
            mvStartCents: pp.beginMvCents,
            mvEndCents: pp.endMvCents,
            netBuyCents: pp.netBuyCents,
            twr: pp.twrPct,
          )
        : null;
    if (investment == null) excluded.add('投资绩效(本期无持仓)');
    return (
      investment: investment,
      mvStartCents: hasPosition ? pp.beginMvCents : 0,
      mvEndCents: hasPosition ? pp.endMvCents : 0,
    );
  }

  /// 拉取区间组合绩效(T3 强制本地路由:显式区间参数;Left 失败优雅
  /// 降级 → null = 投资章节隐藏,见 [_performanceSection] backlog 注)。
  Future<PortfolioPerformance?> _fetchPerformance(ReportPeriod period) async {
    final either = await _holdings.getPortfolioPerformance(
      range: 'YEAR', // 占位:显式区间优先(T3),该值不参与计算
      baseCurrency: 'CNY',
      rangeStart: period.start,
      rangeEnd: period.endInclusive,
    );
    PortfolioPerformance? perf;
    either.fold((l) => perf = null, (r) => perf = r);
    return perf;
  }

  /// 收入口径(T2 遗留#4 收编):income(4) 科目 **credit 单边** 汇总,
  /// 与 conformance 门/TransactionLocalDataSource.summary 的
  /// 「income accounts: credit side counts」同口径(debit 不冲抵)。
  static int totalIncome(List<LedgerEntryRow> entries, ReportPeriod period) =>
      _incomeByAccount(entries, period).values.fold(0, (a, b) => a + b);

  /// 收入分类构成(income 科目账户维度,按金额降序——镜像 basis 排序惯例)。
  static List<CategoryAmount> incomeByCategory(
    List<LedgerEntryRow> entries,
    ReportPeriod period,
  ) {
    final byAccount = _incomeByAccount(entries, period);
    final total = byAccount.values.fold(0, (a, b) => a + b);
    final rows = [
      for (final entry in byAccount.entries)
        CategoryAmount.create(
          category: entry.key,
          amountCents: entry.value,
          totalCents: total,
        ),
    ];
    rows.sort((a, b) => b.amountCents.compareTo(a.amountCents));
    return rows;
  }

  /// 期内 income 科目分录按账户累计(**只取 credit 单边**)。
  static Map<String, int> _incomeByAccount(
      List<LedgerEntryRow> entries, ReportPeriod period) {
    final byAccount = <String, int>{};
    for (final e in entries) {
      if (e.accountType != 4) continue; // 仅 income 科目
      if (!period.contains(e.date)) continue;
      byAccount[e.accountId] = (byAccount[e.accountId] ?? 0) + e.creditCents;
    }
    return byAccount;
  }

  /// 日均:
  /// - 月报 = 结余 ~/ 活跃天数(TransactionSummary 同款:活跃日 = 期内
  ///   有 income/expense 分录的自然日,截断除法,无活跃日 → 0);
  /// - 年报 = 全年支出 ~/ 当年自然天数(365/366)——**报告定案口径**。
  ///   差异理由:TransactionSummary 仅月 scope 计算 dailyAvg(结余/活跃
  ///   日),年报无既成规则;全年视角下「活跃日」随记账频次漂移(记 10
  ///   天与记 300 天差 30 倍,日均失义),自然天数分母稳定可比,且取
  ///   「日均支出」符合年度报告的阅读预期(审视角,结余波动大)。
  static int _dailyAvgCents(
    List<LedgerEntryRow> entries,
    ReportPeriod period,
    int income,
    int expense,
  ) {
    if (period is ReportYearly) {
      final days =
          DateTime(period.year + 1).difference(DateTime(period.year)).inDays;
      return expense ~/ days;
    }
    final activeDays = <String>{};
    for (final e in entries) {
      if (e.accountType != 4 && e.accountType != 5) continue;
      if (!period.contains(e.date)) continue;
      activeDays.add('${e.date.year}-${e.date.month}-${e.date.day}');
    }
    if (activeDays.isEmpty) return 0;
    return (income - expense) ~/ activeDays.length;
  }

  /// 对比期(月报=环比上月,1 月回上年 12 月;年报=同比上年):同一份
  /// entries 重过滤前期重算结余;前期无任何收支数据 → null(首期)。
  PriorComparison? _priorComparison(
    List<LedgerEntryRow> entries,
    ReportPeriod period,
    int surplus,
  ) {
    final prior = switch (period) {
      ReportMonthly(:final year, :final month) => month == 1
          ? ReportPeriod.monthly(year - 1, 12)
          : ReportPeriod.monthly(year, month - 1),
      ReportYearly(:final year) => ReportPeriod.yearly(year - 1),
    };
    final priorIncome = totalIncome(entries, prior);
    final priorExpense = _expenseBasis.totalExpense(entries, prior);
    if (priorIncome == 0 && priorExpense == 0) return null;
    return PriorComparison.create(
      label: '较 ${prior.label}',
      surplusCents: surplus,
      priorSurplusCents: priorIncome - priorExpense,
    );
  }

  /// 预算执行章节(FR-3 #5):期内无预算行 → null(章节隐藏)。
  ///
  /// 口径对照 budget_local_ds(读时 actuals,server 规则,L157-186):
  /// 每 item 的实际发生额 = 其账户在该预算月窗口的 **max(Σdebit,
  /// Σcredit)**——比支出口径(debit 单边)宽:贷方冲回大于借方时(如
  /// 退款型分录)按大边计,与预算页/服务端展示一致(conformance 门钉死)。
  /// **actual 为账户级**:同月同账户多 item 各自展示同一份大边 actual,
  /// 不相加翻倍。
  ///
  /// - 月报 = 当月各 item(budget_local_ds BudgetItemView 同构:每 item
  ///   一行,限额各自展示);
  /// - 年报 = 按账户逐月汇总:actual 按 **(账户,月) 去重**后累加(每
  ///   账户每月只计一份大边;同月多 item 不翻倍),限额按 item 累加
  ///   (每月 planned 可不同,「限额×月数」仅在各月等额时与逐月汇总等价,
  ///   故取逐月汇总以贴合 budget_local_ds 语义)。
  static BudgetSection? _budgetSection(
    List<BudgetRow> budgetRows,
    List<LedgerEntryRow> entries,
    ReportPeriod period,
  ) {
    final inPeriod = switch (period) {
      ReportMonthly(:final year, :final month) => budgetRows
          .where((r) => r.month == '$year-${month.toString().padLeft(2, '0')}'),
      ReportYearly(:final year) =>
        budgetRows.where((r) => r.month.startsWith('$year-')),
    };
    if (inPeriod.isEmpty) return null;

    // (账户|YYYY-MM)→(Σdebit, Σcredit)单遍累计(仅预算行命中的键会被
    // 读取,期外/无预算月自然不计)。
    final debitByKey = <String, int>{};
    final creditByKey = <String, int>{};
    for (final e in entries) {
      final month = '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}';
      final key = '${e.accountId}|$month';
      debitByKey[key] = (debitByKey[key] ?? 0) + e.debitCents;
      creditByKey[key] = (creditByKey[key] ?? 0) + e.creditCents;
    }

    // 账户级大边 actual(budget_local_ds:larger side wins)。
    int actualOf(String accountId, String month) => _maxSide(
        debitByKey['$accountId|$month'] ?? 0,
        creditByKey['$accountId|$month'] ?? 0);

    switch (period) {
      case ReportMonthly():
        return BudgetSection(
          items: [
            for (final r in inPeriod)
              ReportBudgetItem.create(
                name: r.accountName ?? r.accountId,
                actualCents: actualOf(r.accountId, r.month),
                limitCents: r.plannedCents,
              ),
          ],
        );
      case ReportYearly():
        final actualBy = <String, int>{};
        final limitBy = <String, int>{};
        final nameBy = <String, String>{};
        final countedMonths = <String, Set<String>>{};
        for (final r in inPeriod) {
          limitBy[r.accountId] = (limitBy[r.accountId] ?? 0) + r.plannedCents;
          nameBy[r.accountId] = r.accountName ?? r.accountId;
          // (账户,月) 去重:同月多 item 只计一份大边 actual。
          if (countedMonths
              .putIfAbsent(r.accountId, () => <String>{})
              .add(r.month)) {
            actualBy[r.accountId] =
                (actualBy[r.accountId] ?? 0) + actualOf(r.accountId, r.month);
          }
        }
        return BudgetSection(
          items: [
            for (final accountId in actualBy.keys)
              ReportBudgetItem.create(
                name: nameBy[accountId] ?? accountId,
                actualCents: actualBy[accountId] ?? 0,
                limitCents: limitBy[accountId] ?? 0,
              ),
          ],
        );
    }
  }

  /// (Σdebit, Σcredit) 取大边(budget_local_ds:larger side wins)。
  static int _maxSide(int debit, int credit) => debit > credit ? debit : credit;

  /// 某会计类型账户的期初/期末回放余额折 CNY 求和(无汇率外币账户
  /// 跳过不计——附注披露,ADR-3)。
  static int _sumConverted(
    List<AccountRow> accounts,
    Map<String, BalanceAtPeriod> balances,
    _RateBook rateBook,
    int type,
    bool atStart,
  ) {
    var sum = 0;
    for (final a in accounts.where((a) => a.type == type)) {
      final converted = rateBook.convert(
        a.currencyCode,
        atStart
            ? (balances[a.id]?.startCents ?? 0)
            : (balances[a.id]?.endCents ?? 0),
        atStart,
      );
      if (converted != null) sum += converted;
    }
    return sum;
  }

  /// 资产负债章节:期末构成(资产/负债各自按 category 降序)+ 变动行
  /// (资产∪负债分类并集;category 缺失的旧数据归入「未分类」;无汇率
  /// 外币账户不进构成,与净资产口径一致)。
  static BalanceSheetSection _balanceSheet(
    List<AccountRow> accounts,
    Map<String, BalanceAtPeriod> balances,
    _RateBook rateBook,
  ) {
    // 期初/期末按 category 汇总,资产/负债分桶(避免同名 category 串桶;
    // 无汇率外币账户跳过两栏,与净资产口径一致)。
    final assetsEndBy = <String, int>{};
    final liabEndBy = <String, int>{};
    final assetsStartBy = <String, int>{};
    final liabStartBy = <String, int>{};
    for (final a in accounts.where((a) => a.type == 1 || a.type == 2)) {
      final start = rateBook.convert(
          a.currencyCode, balances[a.id]?.startCents ?? 0, true);
      final end = rateBook.convert(
          a.currencyCode, balances[a.id]?.endCents ?? 0, false);
      if (start == null || end == null) continue;
      final key = a.category ?? '未分类';
      (a.type == 1 ? assetsEndBy : liabEndBy)[key] =
          ((a.type == 1 ? assetsEndBy : liabEndBy)[key] ?? 0) + end;
      (a.type == 1 ? assetsStartBy : liabStartBy)[key] =
          ((a.type == 1 ? assetsStartBy : liabStartBy)[key] ?? 0) + start;
    }

    List<CategoryAmount> toComposition(Map<String, int> by) {
      final total = by.values.fold(0, (a, b) => a + b);
      final rows = [
        for (final e in by.entries)
          CategoryAmount.create(
            category: e.key,
            amountCents: e.value,
            totalCents: total,
          ),
      ]..sort((a, b) => b.amountCents.compareTo(a.amountCents));
      return rows;
    }

    // create factory:合计与资产负债率构造期算好(渲染层零计算,T5-R1)。
    return BalanceSheetSection.create(
      assets: toComposition(assetsEndBy),
      liabilities: toComposition(liabEndBy),
      changes: [
        // 变动行分类并集:资产桶序 + 负债新键序(插入序,确定性输出)。
        for (final key in {...assetsStartBy.keys, ...liabStartBy.keys})
          BalanceChange.create(
            category: key,
            startCents: (assetsStartBy[key] ?? 0) + (liabStartBy[key] ?? 0),
            endCents: (assetsEndBy[key] ?? 0) + (liabEndBy[key] ?? 0),
          ),
      ],
    );
  }

  /// 把 [rows](维度 = 科目账户 id)挂上账户展示名(pct 等派生已构造好,
  /// 原样保留;name 缺失 → null)。T5-R1 分类名称契约单点。
  static List<CategoryAmount> _withNames(
    List<CategoryAmount> rows,
    Map<String, String?> names,
  ) =>
      [
        for (final r in rows)
          CategoryAmount(
            category: r.category,
            amountCents: r.amountCents,
            pct: r.pct,
            name: names[r.category],
          ),
      ];
}

/// 汇率簿:期内两时点的有效汇率(历史 ≤ 日最近可得 → 现值回退 →
/// 双缺失跳过),CNY 直加不查(ADR-3 两级近似,策略单点在 domain)。
class _RateBook {
  _RateBook(this._start, this._end, this.skippedCurrencies);

  final Map<String, double?> _start; // code → 有效汇率(null=缺失)
  final Map<String, double?> _end;
  final Set<String> skippedCurrencies;

  static Future<_RateBook> load(
    ReportLedgerStore store,
    List<AccountRow> accounts,
    DateTime start,
    DateTime end,
  ) async {
    final codes = accounts
        .where((a) => a.type == 1 || a.type == 2)
        .map((a) => a.currencyCode)
        .where((c) => c != 'CNY')
        .toSet();
    final atStart = <String, double?>{};
    final atEnd = <String, double?>{};
    for (final code in codes) {
      atStart[code] = _effective(await store.rateToCny(code, start));
      atEnd[code] = _effective(await store.rateToCny(code, end));
    }
    final skipped = codes
        .where((c) => atStart[c] == null || atEnd[c] == null)
        .toSet();
    return _RateBook(atStart, atEnd, skipped);
  }

  /// 快照择优:历史优先,现值回退;双缺失/非正数 → null(跳过折算)。
  static double? _effective(RateQuote quote) {
    final rate = quote.asOfRate ?? quote.currentRate;
    if (rate == null || rate <= 0 || rate.isNaN) return null;
    return rate;
  }

  /// [cents](原币)折 CNY;CNY 直加;无有效汇率 → null(调用方跳过)。
  int? convert(String code, int cents, bool atStart) {
    if (code == 'CNY') return cents;
    final rate = atStart ? _start[code] : _end[code];
    if (rate == null) return null;
    return (cents * rate).round();
  }
}
