import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/debt_detail_widgets.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/repositories/goal_repository.dart';
import 'package:yucai_client/holding/data/networth_ds.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_pie_chart.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 仪表盘（侧栏「概览」）。严格还原 desktop-dashboard.html 结构：
/// 问候头 → 净资产大卡 → 资产分解 4 卡 → 快捷操作 4 格 → 双栏（近期交易 /
/// 资产配置 + 即将到期）。净资产经 NetWorthService.GetNetWorth 折算到本位币
/// (server-side:账户余额 + 持仓市值 − 负债余额);未接入模块(交易、账单)以
/// 空态呈现,不伪造数字。

/// 千分位分组(1234567 → "1,234,567")。home_page 多处共用(净资产大卡 /
/// 收支卡 _formatCents / prog-amt),top-level 消除 3 处重复定义(M1 defer)。
String _groupThousands(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final NetWorthDataSource _netWorthDs = getIt<NetWorthDataSource>();
  late final CurrencySettings _currencySettings = getIt<CurrencySettings>();
  // 3 摘要卡数据源(getIt @LazySingleton,与 _netWorthDs 同款直调)。
  late final TransactionRepository _txnRepo = getIt<TransactionRepository>();
  late final BudgetRepository _budgetRepo = getIt<BudgetRepository>();
  late final GoalRepository _goalRepo = getIt<GoalRepository>();

  Future<NetWorthView>? _netWorthFuture;
  // 收支 summary:Right(含零值)→ 渲染卡(本月无收支是有意义状态,显 ¥0);Left
  // (RPC fail)→ null → 隐藏(fail 不 fold 成 ¥0 误导用户)。loading → 隐藏。
  Future<MonthlySummary?>? _summaryFuture;
  // 预算:null = 当月无 budget(Left/fail)→ 隐藏预算卡。
  Future<BudgetView?>? _budgetFuture;
  // 目标:空列表 = 无 active goal → 隐藏目标卡。
  Future<List<GoalView>>? _goalsFuture;

  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>().add(LoadAccountsRequested());
    _loadNetWorth();
    _loadSummaryCards();
    _currencySettings.listenable.addListener(_onBaseChanged);
  }

  /// 3 摘要卡并发拉取(照 _loadNetWorth 模式,各 Future 独立 await,无相互
  /// 依赖)。fail/空数据各自降级到隐藏或零值,不互相影响。
  void _loadSummaryCards() {
    final now = DateTime.now();
    final monthStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _summaryFuture = _txnRepo.summary(now.year, now.month)
        .then((r) => r.fold((_) => null, (s) => s));
    _budgetFuture = _budgetRepo
        .getBudgetByMonth(monthStr)
        .then((r) => r.fold((_) => null, (b) => b));
    _goalsFuture = _goalRepo
        .listGoals(completed: false)
        .then((r) => r.fold((_) => <GoalView>[], (g) => g));
  }

  void _loadNetWorth() {
    _netWorthFuture = () async {
      final base = await _currencySettings.getBaseCurrency();
      return _netWorthDs.getNetWorth(baseCurrency: base);
    }();
  }

  // Cross-page refresh: base currency changed in settings → re-fetch net worth
  // with the new reporting currency (setState rebuilds the FutureBuilder).
  void _onBaseChanged() {
    if (!mounted) return;
    _loadNetWorth();
    setState(() {});
  }

  @override
  void dispose() {
    _currencySettings.listenable.removeListener(_onBaseChanged);
    super.dispose();
  }

  List<Account> _accountsOf(AccountState state) {
    if (state is AccountsLoaded) return state.accounts;
    if (state is AccountError) return state.accounts;
    if (state is AccountFormSubmitting) return state.accounts;
    return const [];
  }

  /// 按 [AccountCategory] 把资产类账户余额拆成 流动 / 投资 / 固定 三栏。
  ///
  /// 取每账户 currentBalanceCents(原币,未经本位币折算)直接求和——dashboard
  /// 快速概览口径;净资产大卡的 assetTotal 来自 NetWorthView(已折算),两者
  /// 在多币种场景下可能有细微差异,可接受。负债类账户不计入(归总负债)。
  ({int liquid, int invest, int fixed}) _assetBreakdown(
      List<Account> accounts) {
    var liquid = 0, invest = 0, fixed = 0;
    for (final a in accounts) {
      // 只计资产类账户(user-acceptance 修复):income/expense 类账户余额是
      // 流量累积(复式记账的分类账),此前被 otherAsset 分类误入流动资产。
      if (a.accountType != AccountType.asset) continue;
      switch (a.category) {
        case AccountCategory.savings:
        case AccountCategory.otherAsset:
          liquid += a.currentBalanceCents;
        case AccountCategory.investment:
          invest += a.currentBalanceCents;
        case AccountCategory.fixedDeposit:
        case AccountCategory.goldFx:
        case AccountCategory.realEstate:
          fixed += a.currentBalanceCents;
        case AccountCategory.creditCard:
        case AccountCategory.loan:
        case AccountCategory.otherLiability:
          break;
      }
    }
    return (liquid: liquid, invest: invest, fixed: fixed);
  }

  String _formatCents(int cents, String currency, {bool signed = false}) {
    final neg = cents < 0;
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    final grouped = _groupThousands(yuan);
    final prefix = signed ? (neg ? '-' : '+') : (neg ? '-' : '');
    // 货币符号紧贴数字(对齐 OD styles.css .cur 的 margin 留白,非空格字符)。
    return '$prefix${currencySymbol(currency)}$grouped.$fen';
  }

  String _greeting(int hour) {
    if (hour < 6) return '夜深了';
    if (hour < 12) return '早上好';
    if (hour < 14) return '中午好';
    if (hour < 18) return '下午好';
    return '晚上好';
  }

  String _weekday(int w) {
    const names = ['', '星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return names[w];
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final name = auth is Authenticated ? auth.user.displayName : '御财用户';
    final now = DateTime.now();
    final dateStr =
        '${now.year} 年 ${now.month} 月 ${now.day} 日 · ${_weekday(now.weekday)}';

    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: BlocBuilder<AccountBloc, AccountState>(
        builder: (context, state) {
          final accounts = _accountsOf(state);
          final breakdown = _assetBreakdown(accounts);
          // 投资卡与净资产卡同口径:余额 + 持仓浮盈(nw.assets − 资产账户余额
          // 即浮盈;user-acceptance 修复:此前显示成本,与净资产 18,950 对不上)。
          return FutureBuilder<NetWorthView>(
            future: _netWorthFuture,
            builder: (context, snap) {
              final nw = snap.data;
              final liabTotal = nw?.totalLiabilitiesCents ?? 0;
              final netWorth = nw?.netWorthCents ?? 0;
              final currency = nw?.currency ?? 'CNY';

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg,
                    AppSpacing.lg, AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Header(
                            greeting: _greeting(now.hour),
                            name: name,
                            date: dateStr),
                        const SizedBox(height: AppSpacing.lg),
                        _NetWorthCard(
                          netWorth: netWorth,
                          currency: currency,
                          accountCount: accounts.length,
                          loading: !snap.hasData && snap.connectionState !=
                              ConnectionState.done,
                          error: snap.hasError,
                        ),
                        // ── 3 摘要卡(本月收支 / 预算 / 目标)照 OD 原型
                        // yucai-dashboard-home-a2fc。降级:loading/fail/无数据 →
                        // SizedBox.shrink 隐藏;收支卡例外 —— summary Right(含零值)
                        // 仍渲染 ¥0(本月无收支是有意义状态),只有 Left(RPC fail)隐藏。
                        // 每卡 FutureBuilder 用 EdgeInsets.only(top: md) 自带
                        // 上间距 —— 卡隐藏时零高度,_NetWorthCard 与 _SummaryRow
                        // 之间仍有 SizedBox(md) 兜底。
                        FutureBuilder<MonthlySummary?>(
                          future: _summaryFuture,
                          builder: (ctx, snap) => snap.data != null
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                      top: AppSpacing.sm + 4), // OD .flow gap=16(M3)
                                  child: _IncomeExpenseCard(
                                    summary: snap.data!,
                                    currency: currency,
                                    format: _formatCents,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        FutureBuilder<BudgetView?>(
                          future: _budgetFuture,
                          builder: (ctx, snap) => (snap.hasData &&
                                  snap.data != null)
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                      top: AppSpacing.sm + 4), // OD 16(M3)
                                  child: _BudgetCard(
                                    budget: snap.data!,
                                    currency: currency,
                                    format: _formatCents,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        FutureBuilder<List<GoalView>>(
                          future: _goalsFuture,
                          builder: (ctx, snap) => (snap.hasData &&
                                  snap.data!.isNotEmpty)
                              ? Padding(
                                  padding: const EdgeInsets.only(
                                      top: AppSpacing.sm + 4), // OD 16(M3)
                                  child: _GoalCard(
                                    goals: snap.data!,
                                    currency: currency,
                                    format: _formatCents,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _SummaryRow(
                          liquidTotal: breakdown.liquid,
                          // 投资卡=账户余额口径(成本);与净资产卡(含浮盈)的
                          // 口径差归 UI polish 线(R7-D 验收记录已注)。
                          investTotal: breakdown.invest,
                          fixedTotal: breakdown.fixed,
                          liabTotal: liabTotal,
                          format: (c, {bool signed = false}) =>
                              _formatCents(c, currency, signed: signed),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const _QuickActions(),
                        const SizedBox(height: AppSpacing.md),
                        _SplitLayout(
                          format: (c, {bool signed = false}) =>
                              _formatCents(c, currency, signed: signed),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ───────────────────────── 问候头 ─────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.greeting, required this.name, required this.date});
  final String greeting;
  final String name;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting，$name',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.displayFamily,
            fontFamilyFallback: AppTypography.displayFallback,
            color: context.yucai.fg,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(date, style: TextStyle(color: context.yucai.muted, fontSize: 12)),
      ],
    );
  }
}

// ───────────────────────── 净资产大卡 ─────────────────────────

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.netWorth,
    required this.currency,
    required this.accountCount,
    this.loading = false,
    this.error = false,
  });
  final int netWorth;
  final String currency;
  final int accountCount;
  final bool loading;
  final bool error;

  @override
  Widget build(BuildContext context) {
    // 显示本位币符号(CNY→¥,USD→$ 等,经 currencySymbol;非硬编码 ¥)。
    // loading 显示骨架 '--';error 显示 '加载失败'。
    final valueText = error
        ? '加载失败'
        : loading
            ? '--'
            : _groupThousands(netWorth ~/ 100);
    final symbol = currencySymbol(currency);
    return ClipRRect(
      borderRadius: AppRadius.lgBorder,
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1E21), Color(0xFF2A2D33)],
          ),
        ),
        child: Stack(
          children: [
            // 金色径向光晕（原型 ::after）
            Positioned(
              top: -40,
              right: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      context.yucai.accent.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('总净资产',
                    style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        letterSpacing: 0.4)),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '$symbol ',
                        style: TextStyle(
                            fontSize: 21,
                            color: Colors.white54,
                            fontFamily: AppTypography.displayFamily,
                            fontFamilyFallback: AppTypography.displayFallback),
                      ),
                      TextSpan(
                        text: valueText,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: -0.6,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback: AppTypography.displayFallback,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: context.yucai.positive.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.wallet,
                          size: 13, color: context.yucai.positive),
                      const SizedBox(width: 4),
                      Text('共 $accountCount 个账户',
                          style: TextStyle(
                              color: context.yucai.positive, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

// ───────────────────────── 摘要卡:本月收支 / 预算 / 目标 ─────────────────
// 照 OD 原型 yucai-dashboard-home-a2fc styles.css。颜色 token 略异于 AppColors:
// OD income #4a9d6e / expense #d4726e 比 context.yucai.positive/negative 更亮,贴近
// 暖色系 bg;直接内联(对齐 OD,不污染全局 token)。accent 与 context.yucai.accent 同。

const Color _kIncomeColor = Color(0xFF4A9D6E);
const Color _kExpenseColor = Color(0xFFD4726E);

/// 摘要卡阴影(对齐 OD `--shadow-card` 双层:0 1px 2px rgba(31,32,36,.05) +
/// 0 1px 1px rgba(31,32,36,.02))。3 摘要卡共用(M2 提取消重复)。
const List<BoxShadow> _kCardShadow = [
  BoxShadow(color: Color(0x0D1F2024), blurRadius: 2, offset: Offset(0, 1)),
  BoxShadow(color: Color(0x051F2024), blurRadius: 1, offset: Offset(0, 1)),
];

/// 2 · 本月收支(OD `.ie-*`)。两行 dot+label+amt,dashed 分隔;底部 serif 结余。
///
/// income/expense 来自 [MonthlySummary](server TransactionSummary RPC,scope=
/// month);net = income − expense。金额走父级 [_HomePageState._formatCents]
/// 共享格式化(千分位 + 本位币符号 + fen),收入 '+' / 支出 '−' 前缀手动拼以
/// 始终区分方向(_formatCents 的 signed 对 0 值返 '+' 不符支出语义)。
class _IncomeExpenseCard extends StatelessWidget {
  const _IncomeExpenseCard({
    required this.summary,
    required this.currency,
    required this.format,
  });

  final MonthlySummary summary;
  final String currency;
  final String Function(int cents, String currency, {bool signed}) format;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.smBorder,
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHead(
            label: '本月收支',
            period: '${summary.year} 年 ${summary.month} 月',
          ),
          const SizedBox(height: AppSpacing.sm + 4),
          _IeRow(
            dotColor: _kIncomeColor,
            name: '收入',
            amount: '+${format(summary.incomeCents, currency)}',
            amountColor: _kIncomeColor,
          ),
          // income/expense 间虚线分隔(对齐 OD .ie-row border-bottom:1px dashed
          // var(--border-soft)=#F1EDE5;与 _ProgressBar 背景同色)。复用 core
          // DebtDashedDivider(水平虚线 CustomPaint,Flutter 无原生 dashed border)。
          DebtDashedDivider(color: context.yucai.surfaceAlt),
          _IeRow(
            dotColor: _kExpenseColor,
            name: '支出',
            amount: '-${format(summary.expenseCents, currency)}',
            amountColor: _kExpenseColor,
          ),
          // 底部结余分隔线 + 双栏 label/amt。
          Padding(
            padding: EdgeInsets.only(top: AppSpacing.sm + 4),
            child: Divider(height: 1, thickness: 1, color: context.yucai.border),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm + 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('本月结余',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.yucai.fg)),
                const Spacer(),
                Text(
                  format(summary.netCents, currency),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: context.yucai.fg,
                    letterSpacing: -0.3,
                    fontFamily: AppTypography.displayFamily,
                    fontFamilyFallback: AppTypography.displayFallback,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IeRow extends StatelessWidget {
  const _IeRow({
    required this.dotColor,
    required this.name,
    required this.amount,
    required this.amountColor,
  });
  final Color dotColor;
  final String name;
  final String amount;
  final Color amountColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm - 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          Expanded(
            child: Text(name,
                style: TextStyle(fontSize: 13, color: context.yucai.muted)),
          ),
          Text(
            amount,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: amountColor,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// 3 · 本月预算(OD `.prog-*` + `.progress`)。progress bar accent 金;超支切红。
///
/// 用 [BudgetView.totalActualCents] / [BudgetView.totalAmountCents] /
/// [BudgetView.usagePct](server actuals 计算)。foot 左右两栏:剩余/超支金额 +
/// 当月剩余天数(仅当 budget.month 等于当前月时显示)。
class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.currency,
    required this.format,
  });

  final BudgetView budget;
  final String currency;
  final String Function(int cents, String currency, {bool signed}) format;

  @override
  Widget build(BuildContext context) {
    final over = budget.isOverBudget;
    final barColor = over ? _kExpenseColor : context.yucai.accent;
    final pct = budget.usagePct.clamp(0.0, 100.0);
    final remaining = budget.totalRemainingCents;
    final footLeft = over
        ? '超支 ${format(remaining.abs(), currency)}'
        : '剩余 ${format(remaining, currency)} 可用';
    final footRight = _monthDaysLeft(budget.month);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.smBorder,
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHead(
            label: '本月预算',
            period: '已用 ${budget.usagePct.round()}%',
            periodColor: over ? _kExpenseColor : null, // 超支标红(M4)
          ),
          const SizedBox(height: AppSpacing.sm),
          _ProgAmt(
            currentCents: budget.totalActualCents,
            plannedCents: budget.totalAmountCents,
            currency: currency,
            format: format,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ProgressBar(value: pct, color: barColor),
          const SizedBox(height: AppSpacing.sm - 4),
          Row(
            children: [
              Text(footLeft,
                  style: TextStyle(
                      fontSize: 11, color: context.yucai.muted)),
              const Spacer(),
              if (footRight != null)
                Text(footRight,
                    style: TextStyle(
                        fontSize: 11, color: context.yucai.muted)),
            ],
          ),
        ],
      ),
    );
  }

  /// 返回 budget.month 当月剩余天数的描述;非当月返回 null(footer 右栏隐藏)。
  /// 例:本月 15 号 → "7 月还剩 16 天"。跨月/格式异常 → null。
  String? _monthDaysLeft(String month) {
    final now = DateTime.now();
    if (month.length != 7) return null;
    final yr = int.tryParse(month.substring(0, 4));
    final mo = int.tryParse(month.substring(5, 7));
    if (yr == null || mo == null || yr != now.year || mo != now.month) {
      return null;
    }
    final lastOfMonth = DateTime(yr, mo + 1, 0).day;
    final left = lastOfMonth - now.day;
    return left > 0 ? '$mo 月还剩 $left 天' : '$mo 月最后一天';
  }
}

/// 4 · 目标进度(OD `.prog-*` + `.progress-bar.goal`)。取 goals 中第一个(顶级
/// 目标)展示;progress bar income 绿。foot 显示距目标差额 + 截止日预估。
class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.goals,
    required this.currency,
    required this.format,
  });

  final List<GoalView> goals;
  final String currency;
  final String Function(int cents, String currency, {bool signed}) format;

  @override
  Widget build(BuildContext context) {
    // 取第一个 active goal(listGoals(completed: false) 已过滤完成的)。多目标
    // 详情入口在 /goals;dashboard 只显概览。
    final goal = goals.first;
    final pct = goal.progressPct.clamp(0.0, 100.0);
    final remaining = goal.remainingCents;
    final footLeft = remaining > 0
        ? '距目标还差 ${format(remaining, currency)}'
        : '目标已达成';
    final footRight = goal.deadline == null
        ? null
        : '预计 ${goal.deadline!.year} 年 ${goal.deadline!.month} 月达成';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.smBorder,
        boxShadow: _kCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardHead(label: '目标进度', period: goal.name),
          const SizedBox(height: AppSpacing.sm),
          _ProgAmt(
            currentCents: goal.currentAmountCents,
            plannedCents: goal.targetAmountCents,
            currency: currency,
            format: format,
            trailingPct: goal.progressPct,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ProgressBar(value: pct, color: _kIncomeColor),
          const SizedBox(height: AppSpacing.sm - 4),
          Row(
            children: [
              Text(footLeft,
                  style: TextStyle(
                      fontSize: 11, color: context.yucai.muted)),
              const Spacer(),
              if (footRight != null)
                Text(footRight,
                    style: TextStyle(
                        fontSize: 11, color: context.yucai.muted)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── 共享子 widget(摘录自 OD .card-head / .prog-amt / .progress) ───

class _CardHead extends StatelessWidget {
  const _CardHead({required this.label, required this.period, this.periodColor});
  final String label;
  final String period;
  /// period 文字色(可选);null → 默认 muted。预算卡超支时传支出红(M4)。
  final Color? periodColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.yucai.fg)),
        const Spacer(),
        Text(period,
            style: TextStyle(
                fontSize: 11,
                color: periodColor ?? context.yucai.muted,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }
}

/// 预算/目标金额行(OD `.prog-amt`):¥current / planned(可选 · pct%)。
/// 主数字 20/600 mono tabular;"¥" 前缀 13 muted," / planned" 后缀 13 muted。
class _ProgAmt extends StatelessWidget {
  const _ProgAmt({
    required this.currentCents,
    required this.plannedCents,
    required this.currency,
    required this.format,
    this.trailingPct,
  });

  final int currentCents;
  final int plannedCents;
  final String currency;
  final String Function(int cents, String currency, {bool signed}) format;
  final double? trailingPct;

  @override
  Widget build(BuildContext context) {
    // 拆出 yuan + fen 以便 ¥ 前缀(小) + 整数部分(大) + 小数部分(小,与 OD 一致)。
    final abs = currentCents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    final grouped = _groupThousands(yuan);
    final neg = currentCents < 0;
    final cur = currencySymbol(currency);

    final suffix = trailingPct != null
        ? ' / ${format(plannedCents, currency)} · ${trailingPct!.round()}%'
        : ' / ${format(plannedCents, currency)}';

    return RichText(
      maxLines: 1,
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: [
          TextSpan(
            text: neg ? '-$cur ' : '$cur ',
            style: TextStyle(
                fontSize: 13, color: context.yucai.muted),
          ),
          TextSpan(
            text: grouped,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.yucai.fg,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          TextSpan(
            text: '.$fen',
            style: TextStyle(
                fontSize: 13, color: context.yucai.muted),
          ),
          TextSpan(
            text: suffix,
            style: TextStyle(
                fontSize: 13,
                color: context.yucai.muted,
                fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

}

/// 8px pill 进度条(OD `.progress`)。[value] 为 0–100 百分比,clamp 在此。
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value / 100,
        minHeight: 8,
        backgroundColor: context.yucai.surfaceAlt,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

// ───────────────────────── 资产分解 4 卡 ─────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.liquidTotal,
    required this.investTotal,
    required this.fixedTotal,
    required this.liabTotal,
    required this.format,
  });
  final int liquidTotal;
  final int investTotal;
  final int fixedTotal;
  final int liabTotal;
  final String Function(int, {bool signed}) format;

  @override
  Widget build(BuildContext context) {
    // 标签对齐原型（流动 / 投资 / 固定 / 负债）。按 AccountCategory 拆分：
    // 流动 = savings+otherAsset,投资 = investment,固定 = fixedDeposit+goldFx+realEstate。
    final cards = <_SummaryData>[
      _SummaryData('流动资产', format(liquidTotal), '储蓄 / 现金类账户', context.yucai.fg),
      _SummaryData('投资资产', format(investTotal), '证券 / 基金 / 理财', context.yucai.fg),
      _SummaryData('固定资产', format(fixedTotal), '定期 / 黄金 / 房产', context.yucai.fg),
      _SummaryData('总负债', format(liabTotal), liabTotal > 0 ? '负债类账户合计' : '暂无负债',
          liabTotal > 0 ? context.yucai.negative : context.yucai.muted),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 820 ? 4 : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: cols == 4 ? 1.5 : 1.7,
        children: [for (final d in cards) _SummaryCard(data: d)],
      );
    });
  }
}

class _SummaryData {
  const _SummaryData(this.label, this.value, this.sub, this.valueColor);
  final String label;
  final String value;
  final String sub;
  final Color valueColor;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.data});
  final _SummaryData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.label,
              style: TextStyle(color: context.yucai.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            data.value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: data.valueColor,
              letterSpacing: -0.3,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback,
            ),
          ),
          const SizedBox(height: 4),
          Text(data.sub,
              style: TextStyle(color: context.yucai.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

// ───────────────────────── 快捷操作 ─────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    // 严格匹配原型四格：记一笔 / 转账 / 买入投资 / 生成报表。
    // 转账 → 交易表单(内选 transfer);生成报表 → /reports(Task 2 报表分析页)。
    final actions = <(IconData, String, String)>[
      (LucideIcons.plus, '记一笔', '/transactions/new'),
      (LucideIcons.arrowLeftRight, '转账', '/transactions/new'),
      (LucideIcons.trendingUp, '买入投资', '/holdings/new'),
      (LucideIcons.barChart3, '生成报表', '/reports'),
    ];
    return LayoutBuilder(builder: (context, c) {
      final cols = c.maxWidth > 820 ? 4 : 2;
      return GridView.count(
        crossAxisCount: cols,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 2.0,
        children: [
          for (final a in actions)
            _QuickTile(
              icon: a.$1,
              label: a.$2,
              onTap: () => context.go(a.$3),
            ),
        ],
      );
    });
  }
}

class _QuickTile extends StatefulWidget {
  const _QuickTile({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        cursor:
            widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          transform: _hover
              ? Matrix4.translationValues(0, -1, 0)
              : Matrix4.identity(),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.yucai.surface,
            border: Border.all(
                color: _hover ? context.yucai.accent : context.yucai.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.yucai.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child:
                    Icon(widget.icon, size: 18, color: context.yucai.accent),
              ),
              const SizedBox(height: 8),
              Text(widget.label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 双栏：近期交易 / 资产配置 + 即将到期 ─────────────────────────

class _SplitLayout extends StatelessWidget {
  const _SplitLayout({required this.format});
  final String Function(int, {bool signed}) format;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 760;
      final left = _RecentTxnPanel(format: format);
      final rightColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _AssetAllocationPanel(),
          const SizedBox(height: AppSpacing.md),
          _UpcomingPaymentsPanel(format: format),
        ],
      );
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 14, child: left),
            const SizedBox(width: AppSpacing.md),
            Expanded(flex: 10, child: rightColumn),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [left, const SizedBox(height: AppSpacing.md), rightColumn],
      );
    });
  }
}

// ───────────────────────── 面板外壳（标题 + 可点击链接 + 内容槽）─────────

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.body,
    this.linkText = '查看全部',
    this.onViewAll,
  });

  final String title;
  final String linkText;
  final VoidCallback? onViewAll;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                InkWell(
                  onTap: onViewAll,
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(linkText,
                        style: TextStyle(
                          color: onViewAll != null
                              ? context.yucai.accent
                              : context.yucai.muted,
                          fontSize: 12,
                        )),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: context.yucai.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: body,
          ),
        ],
      ),
    );
  }
}

/// 面板空态(inbox 图标 + 提示)。
Widget _panelEmpty(String hint, String sub) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.inbox,
              size: 28, color: AppColors.muted.withValues(alpha: 0.5)),
          const SizedBox(height: 8),
          Text(hint,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(sub, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );

Widget _panelLoading() => Center(
      child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.muted)),
    );

// ───────────────────────── A3: 近期交易面板 ─────────────────────────

/// 拉最近 5 笔交易(TransactionRepository.list)。FutureBuilder + mini row;
/// 失败/空 → 空态。原币金额未经折算(dashboard 概览)。
class _RecentTxnPanel extends StatefulWidget {
  const _RecentTxnPanel({required this.format});
  final String Function(int, {bool signed}) format;

  @override
  State<_RecentTxnPanel> createState() => _RecentTxnPanelState();
}

class _RecentTxnPanelState extends State<_RecentTxnPanel> {
  late final Future<Either<Failure, ListTransactionsResult>> _future =
      getIt<TransactionRepository>()
          .list(const ListTransactionsParams(pageSize: 5));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Either<Failure, ListTransactionsResult>>(
      future: _future,
      builder: (context, snap) {
        final Widget body;
        if (!snap.hasData) {
          body = snap.connectionState == ConnectionState.done
              ? _panelEmpty('暂无交易记录', '记一笔后将在此展示近期收支')
              : _panelLoading();
        } else {
          final txns =
              snap.data!.fold((_) => <Transaction>[], (r) => r.transactions);
          body = txns.isEmpty
              ? _panelEmpty('暂无交易记录', '记一笔后将在此展示近期收支')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final t in txns.take(5))
                      _TxnMiniRow(txn: t, format: widget.format),
                  ],
                );
        }
        return _Panel(
          title: '近期交易',
          linkText: '查看全部',
          onViewAll: () => context.go('/transactions'),
          body: body,
        );
      },
    );
  }
}

class _TxnMiniRow extends StatelessWidget {
  const _TxnMiniRow({required this.txn, required this.format});
  final Transaction txn;
  final String Function(int, {bool signed}) format;

  @override
  Widget build(BuildContext context) {
    final desc = txn.description.isEmpty ? '未命名交易' : txn.description;
    final amount = txn.totalDebitCents;
    final d = txn.transactionDate;
    final dateStr = '${d.month}/${d.day}';
    return InkWell(
      onTap: () => context.go('/transactions/${txn.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(desc,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(dateStr,
                      style: TextStyle(
                          fontSize: 11, color: context.yucai.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(format(amount),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures)),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── A4: 资产配置面板(HoldingPieChart) ─────────

/// 自持 BlocProvider<HoldingBloc>:进入即 LoadHoldingsRequested;按 SecurityType
/// 聚合 marketValueCents → HoldingPieChart。空/失败 → 空态。HoldingBloc 为
/// @factory,这里直接构造(对齐 router /holdings 模式),BlocProvider 负责释放。
class _AssetAllocationPanel extends StatelessWidget {
  const _AssetAllocationPanel();

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HoldingBloc>(
      create: (_) {
        final b = HoldingBloc(getIt<HoldingRepository>());
        b.add(const LoadHoldingsRequested());
        return b;
      },
      child: BlocBuilder<HoldingBloc, HoldingState>(
        builder: (context, state) {
          final Widget body;
          if (state is HoldingLoaded) {
            final slices = _aggregateSlices(state.holdings);
            body = slices.isEmpty
                ? _panelEmpty('暂无持仓数据', '买入后将展示资产分布')
                : HoldingPieChart(slices: slices);
          } else if (state is HoldingError) {
            body = _panelEmpty('加载失败', '稍后重试');
          } else {
            body = _panelLoading();
          }
          return _Panel(
            title: '资产配置',
            linkText: '详情',
            onViewAll: () => context.go('/holdings'),
            body: body,
          );
        },
      ),
    );
  }
}

/// 按 SecurityType 聚合 holdings 的 marketValueCents → HoldingSlice 列表。
List<HoldingSlice> _aggregateSlices(List<Holding> holdings) {
  final totals = <SecurityType, int>{};
  for (final h in holdings) {
    final t = h.securityType;
    if (t == null) continue;
    totals[t] = (totals[t] ?? 0) + h.marketValueCents;
  }
  return [
    for (final entry in totals.entries)
      HoldingSlice(type: entry.key, valueCents: entry.value),
  ];
}

// ───────────────────────── A5: 即将到期面板(DebtRepository) ──────────

/// 拉未来 30 天到期还款(DebtRepository.upcomingPayments)。FutureBuilder +
/// mini row;失败/空 → 空态。展示 nextPaymentDate + nextPaymentAmountCents。
class _UpcomingPaymentsPanel extends StatefulWidget {
  const _UpcomingPaymentsPanel({required this.format});
  final String Function(int, {bool signed}) format;

  @override
  State<_UpcomingPaymentsPanel> createState() => _UpcomingPaymentsPanelState();
}

class _UpcomingPaymentsPanelState extends State<_UpcomingPaymentsPanel> {
  late final Future<Either<Failure, List<Debt>>> _future =
      getIt<DebtRepository>().upcomingPayments(30);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Either<Failure, List<Debt>>>(
      future: _future,
      builder: (context, snap) {
        final Widget body;
        if (!snap.hasData) {
          body = snap.connectionState == ConnectionState.done
              ? Column(children: [
                  _panelEmpty('暂无待办账单', '即将到期将在此提醒'),
                  const _SubscribeLink(),
                ])
              : _panelLoading();
        } else {
          final debts = snap.data!.fold((_) => <Debt>[], (l) => l);
          body = debts.isEmpty
              ? _panelEmpty('暂无待办账单', '即将到期将在此提醒')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final dbt in debts.take(4))
                      _DebtMiniRow(debt: dbt, format: widget.format),
                  ],
                );
        }
        return _Panel(
          title: '即将到期',
          linkText: '全部',
          onViewAll: () => context.go('/debts'),
          body: body,
        );
      },
    );
  }
}

class _DebtMiniRow extends StatelessWidget {
  const _DebtMiniRow({required this.debt, required this.format});
  final Debt debt;
  final String Function(int, {bool signed}) format;

  @override
  Widget build(BuildContext context) {
    final name = debt.counterparty.isEmpty ? '未命名债务' : debt.counterparty;
    final d = debt.nextPaymentDate;
    final dateStr = d != null ? '${d.month}/${d.day}' : '—';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('到期 $dateStr',
                    style: TextStyle(
                        fontSize: 11, color: context.yucai.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(format(debt.nextPaymentAmountCents),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}


/// 订阅/周期模板入口(R7 用户找回的功能):面板空态/有数据均展示。
class _SubscribeLink extends StatelessWidget {
  const _SubscribeLink();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Align(
        alignment: Alignment.centerRight,
        child: ActionChip(
          label: const Text('订阅管理', style: TextStyle(fontSize: 12)),
          avatar: const Icon(LucideIcons.repeat, size: 14),
          onPressed: () => context.go('/accounts/templates'),
        ),
      ),
    );
  }
}
