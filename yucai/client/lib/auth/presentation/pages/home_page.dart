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
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
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
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final NetWorthDataSource _netWorthDs = getIt<NetWorthDataSource>();
  late final CurrencySettings _currencySettings = getIt<CurrencySettings>();

  Future<NetWorthView>? _netWorthFuture;

  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>().add(LoadAccountsRequested());
    _loadNetWorth();
    _currencySettings.listenable.addListener(_onBaseChanged);
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
    return '$prefix${currencySymbol(currency)} $grouped.$fen';
  }

  String _groupThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
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
      backgroundColor: AppColors.bg,
      body: BlocBuilder<AccountBloc, AccountState>(
        builder: (context, state) {
          final accounts = _accountsOf(state);
          final breakdown = _assetBreakdown(accounts);
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
                        const SizedBox(height: AppSpacing.md),
                        _SummaryRow(
                          liquidTotal: breakdown.liquid,
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
            color: AppColors.fg,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(date, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
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
                      AppColors.accent.withValues(alpha: 0.18),
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
                    color: AppColors.positive.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.wallet,
                          size: 13, color: const Color(0xFF6FCF9A)),
                      const SizedBox(width: 4),
                      Text('共 $accountCount 个账户',
                          style: const TextStyle(
                              color: Color(0xFF6FCF9A), fontSize: 13)),
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

  String _groupThousands(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
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
      _SummaryData('流动资产', format(liquidTotal), '储蓄 / 现金类账户', AppColors.fg),
      _SummaryData('投资资产', format(investTotal), '证券 / 基金 / 理财', AppColors.fg),
      _SummaryData('固定资产', format(fixedTotal), '定期 / 黄金 / 房产', AppColors.fg),
      _SummaryData('总负债', format(liabTotal), liabTotal > 0 ? '负债类账户合计' : '暂无负债',
          liabTotal > 0 ? AppColors.negative : AppColors.muted),
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
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
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
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
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
            color: AppColors.surface,
            border: Border.all(
                color: _hover ? AppColors.accent : AppColors.border),
            borderRadius: AppRadius.lgBorder,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child:
                    Icon(widget.icon, size: 18, color: AppColors.accent),
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
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
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
                              ? AppColors.accent
                              : AppColors.muted,
                          fontSize: 12,
                        )),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
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
          Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );

Widget _panelLoading() => const Center(
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
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
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
              ? _panelEmpty('暂无待办账单', '即将到期将在此提醒')
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
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.muted)),
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
