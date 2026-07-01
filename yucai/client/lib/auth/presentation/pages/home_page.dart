import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_bloc.dart';
import 'package:yucai_client/auth/presentation/bloc/auth_state.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/currency/data/currency_settings.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/holding/data/networth_ds.dart';
import 'package:yucai_client/holding/domain/entities/net_worth_entity.dart';

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
          return FutureBuilder<NetWorthView>(
            future: _netWorthFuture,
            builder: (context, snap) {
              final nw = snap.data;
              final assetTotal = nw?.totalAssetsCents ?? 0;
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
                          assetTotal: assetTotal,
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
                      Icon(Icons.account_balance_wallet_outlined,
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
    required this.assetTotal,
    required this.liabTotal,
    required this.format,
  });
  final int assetTotal;
  final int liabTotal;
  final String Function(int, {bool signed}) format;

  @override
  Widget build(BuildContext context) {
    // 标签对齐原型（流动 / 投资 / 固定 / 负债）；当前 domain 只有会计五类型，
    // 流动资产 = 资产类合计；投资 / 固定资产尚未接入（持仓模块未上线）。
    final cards = <_SummaryData>[
      _SummaryData('流动资产', format(assetTotal), '资产类账户合计', AppColors.fg),
      _SummaryData('投资资产', '待接入', '持仓模块未上线', AppColors.muted),
      _SummaryData('固定资产', '待接入', '尚未记录', AppColors.muted),
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
    // 严格匹配原型四格：记一笔 / 转账 / 买入投资 / 生成报表（均未上线）。
    const actions = <(IconData, String)>[
      (Icons.add, '记一笔'),
      (Icons.swap_horiz, '转账'),
      (Icons.trending_up, '买入投资'),
      (Icons.insert_chart_outlined, '生成报表'),
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
            _QuickTile(icon: a.$1, label: a.$2),
        ],
      );
    });
  }
}

class _QuickTile extends StatefulWidget {
  const _QuickTile({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  State<_QuickTile> createState() => _QuickTileState();
}

class _QuickTileState extends State<_QuickTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: MouseCursor.defer,
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
          border:
              Border.all(color: _hover ? AppColors.accent : AppColors.border),
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
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
      final left = _Panel(
        title: '近期交易',
        linkText: '查看全部',
        emptyHint: '暂无交易记录',
        emptySub: '交易模块上线后将在此展示近期收支',
      );
      final rightColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Panel(
            title: '资产配置',
            linkText: '详情',
            emptyHint: '暂无持仓数据',
            emptySub: '投资模块上线后将展示资产分布',
          ),
          const SizedBox(height: AppSpacing.md),
          _Panel(
            title: '即将到期',
            linkText: '全部',
            emptyHint: '暂无待办账单',
            emptySub: '债务与账单到期后将在此提醒',
          ),
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

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.linkText,
    required this.emptyHint,
    required this.emptySub,
  });

  final String title;
  final String linkText;
  final String emptyHint;
  final String emptySub;

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
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(linkText,
                    style: const TextStyle(
                        color: AppColors.accent, fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 28, color: AppColors.muted.withValues(alpha: 0.5)),
                  const SizedBox(height: 8),
                  Text(emptyHint,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(emptySub,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
