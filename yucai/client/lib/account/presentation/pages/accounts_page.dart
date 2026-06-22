import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/account/presentation/widgets/account_category_style.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';

/// 账户管理列表页。对齐 OD 原型 CSS 1:1：
///  - design-output/accounts-responsive/tablet.html （desktop/tablet）
///  - design-output/accounts-responsive/mobile.html  （mobile 390）
///
/// 布局：汇总头（.sumcard/.summary）→ 水平滚动筛选 chips（.chips/.chip）
///       → 按类型分组的账户卡片（.group/.group-head/.grid/.card/.acc）。
///
/// 注意：本页内容渲染在 AppShell 内（侧栏 + topbar），原型中 .wrap/.pagerow/
/// body padding/.tabbar/status-bar 由 AppShell 承载或与本页无关，故不对齐。
class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  /// null = 全部。
  AccountCategory? _filter;
  bool _showArchived = false; // 归档账户默认隐藏，勾选「含已归档」时显示
  /// 正在执行写操作的账户 id 集合（删除 / 关闭等），支持多操作并发追踪。
  final _pendingIds = <String>{};

  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>().add(LoadAccountsRequested());
  }

  String _formatCents(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    return '$sign¥ ${_groupThousands(yuan)}.$fen';
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

  List<Account> _accountsOf(AccountState state) {
    if (state is AccountsLoaded) return state.accounts;
    if (state is AccountError) return state.accounts;
    if (state is AccountFormSubmitting) return state.accounts;
    return const [];
  }

  Future<void> _confirmDelete(Account account) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除账户'),
        content: Text('确定删除「${account.name}」吗？此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('删除')),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() => _pendingIds.add(account.id));
      context.read<AccountBloc>().add(DeleteAccountRequested(account.id));
    }
  }

  Future<void> _openCreateForm() async {
    final created = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: context.read<AccountBloc>(),
              child: const AccountFormPage(),
            ),
          ),
        ) ??
        false;
    if (created && mounted) {
      AppToast.show(context, '账户创建成功');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocConsumer<AccountBloc, AccountState>(
        listener: (context, state) {
          if (state is AccountError && _pendingIds.isNotEmpty) {
            AppToast.show(context, state.message, type: ToastType.error);
            setState(_pendingIds.clear);
          } else if (state is AccountsLoaded && _pendingIds.isNotEmpty) {
            setState(_pendingIds.clear);
            AppToast.show(context, '操作完成');
          }
        },
        builder: (context, state) {
          final accounts = _accountsOf(state);
          final loading = state is AccountLoading && accounts.isEmpty;

          if (loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (accounts.isEmpty) {
            return _emptyState();
          }
          return _content(accounts);
        },
      ),
    );
  }

  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: () async =>
          context.read<AccountBloc>().add(LoadAccountsRequested()),
      child: ListView(
        children: [
          const SizedBox(height: 120),
          Center(
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.account_balance_wallet_outlined,
                      size: 30, color: AppColors.accent),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('还没有账户',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                const Text('点击右上角「新建账户」开始记录',
                    style: TextStyle(color: AppColors.muted, fontSize: 14)),
                const SizedBox(height: AppSpacing.lg),
                _NewAccountButton(onPressed: _openCreateForm),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(List<Account> accounts) {
    // account-as-category 方案下 Expense/Income 类型账户 = 分类，归属分类管理页，
    // 不应出现在账户列表。这里只保留资产/负债账户（equity 系统账户也排除）。
    final balanceSheet = accounts.where((a) =>
        a.accountType == AccountType.asset ||
        a.accountType == AccountType.liability);
    // 归档账户不参与活跃统计（合计/默认列表）；_showArchived 时才显示。
    final active = balanceSheet
        .where((a) => a.status == AccountStatus.active)
        .toList();
    final assetCents = active
        .where((a) => a.accountType == AccountType.asset)
        .fold<int>(0, (s, a) => s + a.currentBalanceCents);
    final liabCents = active
        .where((a) => a.accountType == AccountType.liability)
        .fold<int>(0, (s, a) => s + a.currentBalanceCents);
    final netCents = assetCents + liabCents; // 负债余额为负，相加得净资产
    final scoped = _showArchived ? balanceSheet.toList() : active;
    final filtered = _filter == null
        ? scoped
        : scoped.where((a) => a.category == _filter).toList();
    final groups = _groupByCategory(filtered);

    // chips 计数：全部 = 当前 scoped 总数；分类 = 该分类 scoped 数。
    final chipCounts = <AccountCategory?, int>{
      null: scoped.length,
      for (final c in AccountCategory.values)
        c: scoped.where((a) => a.category == c).length,
    };

    return RefreshIndicator(
      onRefresh: () async =>
          context.read<AccountBloc>().add(LoadAccountsRequested()),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AccountsHeader(
                  netCents: netCents,
                  assetCents: assetCents,
                  liabCents: liabCents,
                  onAdd: _openCreateForm,
                ),
                // .chips：水平滚动 + gap9 + chip h32 px14，active 黑底白字。
                // proto tablet padding:18px 0 4px；mobile padding:14px 0 4px。
                _FilterChips(
                  active: _filter,
                  counts: chipCounts,
                  onChanged: (v) => setState(() => _filter = v),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _showArchived,
                        onChanged: (v) =>
                            setState(() => _showArchived = v ?? false),
                      ),
                      const Text('含已归档账户',
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 13)),
                    ],
                  ),
                ),
                if (groups.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text('该筛选下暂无账户',
                          style: TextStyle(color: AppColors.muted))),
                  )
                else
                  for (final entry in groups.entries) ...[
                    _GroupBlock(
                      type: entry.key,
                      accounts: entry.value,
                      formatCents: _formatCents,
                      onDelete: _confirmDelete,
                    ),
                    // .group margin-top:28px（首个由 _content padding 提供，后续由此 SizedBox 提供）。
                    const SizedBox(height: AppSpacing.lg),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<AccountCategory, List<Account>> _groupByCategory(List<Account> accounts) {
    final groups = <AccountCategory, List<Account>>{};
    for (final a in accounts) {
      groups.putIfAbsent(a.category, () => []).add(a);
    }
    return groups;
  }
}

// ───────────────────────── 汇总头 ─────────────────────────

class _AccountsHeader extends StatelessWidget {
  const _AccountsHeader({
    required this.netCents,
    required this.assetCents,
    required this.liabCents,
    required this.onAdd,
  });

  final int netCents;
  final int assetCents;
  final int liabCents;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) => c.maxWidth < 600 ? _mobileCard(context) : _sumcard(context),
    );
  }

  /// desktop/tablet：白卡 sumcard（对齐 tablet.html .sumcard）。
  /// 右上 accent-soft 圆形装饰（原型 .sumcard .deco，190px，比 mobile 124 大）。
  /// proto: padding:26px 30px; gap:32px; border-radius:14; bg:#fff; 无 box-shadow。
  Widget _sumcard(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -54,
          right: -44,
          child: Container(
            width: 190,
            height: 190,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accentSoft,
            ),
          ),
        ),
        Container(
          // .sumcard padding:26px 30px（vertical 26 / horizontal 30）
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorder, // radius-lg 14
            // proto .sumcard 无 box-shadow（仅有 deco 圆 + border-radius + bg）。
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _netBlock(),
                    const SizedBox(width: 32), // gap:32px
                    _vline(),
                    const SizedBox(width: 32),
                    _statBlock('总资产', assetCents, AppColors.positive),
                    const SizedBox(width: 32),
                    _vline(),
                    const SizedBox(width: 32),
                    _statBlock('总负债', liabCents, AppColors.negative),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              _NewAccountButton(onPressed: onAdd),
            ],
          ),
        ),
      ],
    );
  }

  /// mobile：紧凑汇总卡（对齐 mobile.html .summary）。
  /// proto: padding:18px 20px 17px; border-radius:14; margin-top:6; deco 124 circle。
  Widget _mobileCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6), // .summary margin-top:6px
      clipBehavior: Clip.hardEdge, // 让 deco 圆被 radius 裁剪
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
      ),
      child: Stack(
        children: [
          // 右上 accent-soft 圆形装饰（原型 .deco）。
          Positioned(
            top: -38,
            right: -32,
            child: Container(
              width: 124,
              height: 124,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentSoft,
              ),
            ),
          ),
          Padding(
            // .summary padding:18px 20px 17px
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('全部账户余额合计',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
                const SizedBox(height: 5),
                Text(
                  _fmt(netCents),
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: netCents < 0 ? AppColors.negative : AppColors.fg,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
                const SizedBox(height: 9),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    children: [
                      const TextSpan(text: '资产 '),
                      TextSpan(
                          text: _fmt(assetCents),
                          style: const TextStyle(color: AppColors.positive)),
                      const TextSpan(text: '   ·   负债 '),
                      TextSpan(
                          text: _fmt(liabCents),
                          style: const TextStyle(color: AppColors.negative)),
                    ],
                  ),
                  style: const TextStyle(
                      fontFeatures: AppTypography.tabularFigures),
                ),
                const SizedBox(height: 14),
                // mobile 顶部无 AppShell + 按钮，汇总卡内提供「新建账户」入口
                // （对齐原型 mobile topbar 的 + 意图）。
                Center(child: _NewAccountButton(onPressed: onAdd)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// .net-label 13 muted + .net-val 30 display w600 mt:6 letter-spacing:.5。
  Widget _netBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('净资产合计', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
          _fmt(netCents),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: netCents < 0 ? AppColors.negative : AppColors.fg,
            fontFamily: AppTypography.displayFamily,
            fontFamilyFallback: AppTypography.displayFallback,
          ),
        ),
      ],
    );
  }

  /// .stat-label 12 muted + .stat-val 19 mono w600 mt:5 tabular。
  Widget _statBlock(String label, int cents, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          _fmt(cents),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: color,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ],
    );
  }

  /// .vline 1×48 border color。
  Widget _vline() =>
      Container(width: 1, height: 48, color: AppColors.border);

  /// 千分位 + 两位小数（¥ 前缀）。净资产/资产为正、负债为负（带 -）。
  static String _fmt(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    final s = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$sign¥$buf.$fen';
  }
}

/// .newbtn：margin-left:auto height:40 padding:0 20 radius:9999px accent bg
/// #fff 14 w600 gap7 box-shadow:0 4px 12px rgba(176,141,87,.32)；:hover accent-press。
/// + 字号 18 w400。
class _NewAccountButton extends StatefulWidget {
  const _NewAccountButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  State<_NewAccountButton> createState() => _NewAccountButtonState();
}

class _NewAccountButtonState extends State<_NewAccountButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40, // .newbtn height:40px
          padding: const EdgeInsets.symmetric(horizontal: 20), // 0 20px
          decoration: BoxDecoration(
            color: _hover ? const Color(0xFF98773F) : AppColors.accent, // :hover accent-press(#98773f)
            borderRadius: BorderRadius.circular(9999), // radius:9999px (pill)
            boxShadow: const [
              // .newbtn box-shadow:0 4px 12px rgba(176,141,87,.32)
              BoxShadow(
                color: Color(0x52B08D57),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 18, color: Colors.white), // .pl 18 w400
              SizedBox(width: 7), // gap:7px
              Text('新建账户',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14, // 14 w600
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── 筛选 chips（水平滚动） ───────────────────────

/// 对齐 prototype .chips + .chip：
///  - .chips display:flex gap:9 overflow-x:auto padding:18px 0 4px（tablet）
///    / gap:8 padding:14px 0 4px（mobile）
///  - .chip h:32 padding:0 14 radius:9999 bg:#fff border:1 #e6e3dc 13 #1a1916
///    .cnt 12 mono muted；active bg/border #1a1916 #fff .cnt 55%white
///    :not(.active):hover border-color accent
///
/// 决策：弃用共享 FilterBar（Wrap 布局，active 用 accent 金、无 count），
/// 改为本页内联水平滚动 chip 行以 1:1 还原原型（黑底 active + count badge +
/// hover 金边）。FilterBar 本身不改（被 transactions_page 等复用）。
class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.active,
    required this.counts,
    required this.onChanged,
  });

  final AccountCategory? active;
  final Map<AccountCategory?, int> counts;
  final ValueChanged<AccountCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    final defs = <AccountCategory?>[null, ...AccountCategory.values];
    final isMobile = MediaQuery.of(context).size.width < 600;
    // proto gap：tablet 9 / mobile 8；padding-top：tablet 18 / mobile 14。
    final gap = isMobile ? 8.0 : 9.0;
    final padTop = isMobile ? 14.0 : 18.0;
    return Padding(
      padding: EdgeInsets.only(top: padTop, bottom: 4),
      // 横向滚动 + 隐藏滚动条（还原原型 .chips{overflow-x:auto} 无可见 scrollbar）。
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(scrollbars: false),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal, // overflow-x:auto
          child: SeparatedRow(
            gap: gap,
            children: [
              for (final c in defs)
                _Chip(
                  label: c?.label ?? '全部',
                  count: counts[c] ?? 0,
                  selected: c == active,
                  onTap: () => onChanged(c),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 简单的 Row + 等宽 gap（无 Expanded，支持横向滚动自然宽度）。
class SeparatedRow extends StatelessWidget {
  const SeparatedRow({super.key, required this.gap, required this.children});
  final double gap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      items.add(children[i]);
      if (i < children.length - 1) items.add(SizedBox(width: gap));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: items);
  }
}

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    const activeBg = Color(0xFF1A1916); // #1a1916（.chip.active）
    const activeBorder = Color(0xFF1A1916);
    final border = widget.selected
        ? activeBorder
        : (_hover ? AppColors.accent : AppColors.border); // :not(.active):hover accent
    final bg = widget.selected ? activeBg : AppColors.surface;
    final fg = widget.selected ? Colors.white : AppColors.fg;
    // .cnt：非 active muted；active rgba(255,255,255,.55)
    final cntColor =
        widget.selected ? const Color(0x8CFFFFFF) : AppColors.muted;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150), // .chip transition:.15s
          // .chip height:32 padding:0 14 radius:9999
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // .chip 13 #1a1916（active #fff）
              Text(widget.label,
                  style: TextStyle(
                      color: fg, fontSize: 13, fontWeight: FontWeight.w400)),
              const SizedBox(width: 6), // gap:6
              // .cnt 12 mono tabular muted
              Text('${widget.count}',
                  style: TextStyle(
                    color: cntColor,
                    fontSize: 12,
                    fontFeatures: AppTypography.tabularFigures,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 分组 ─────────────────────────

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.type,
    required this.accounts,
    required this.formatCents,
    required this.onDelete,
  });

  final AccountCategory type;
  final List<Account> accounts;
  final String Function(int) formatCents;
  final Future<void> Function(Account) onDelete;

  @override
  Widget build(BuildContext context) {
    final subtotal =
        accounts.fold<int>(0, (s, a) => s + a.currentBalanceCents);
    final isLiability = accounts.first.accountType == AccountType.liability;
    final typeColor = categoryColor(type);
    // .group-head：gap 11 / padding 0 2 15（tablet）；mobile gap 9 / padding 4 2 10。
    final isMobile = MediaQuery.of(context).size.width < 600;
    final headGap = isMobile ? 9.0 : 11.0;
    final headPad = isMobile
        ? const EdgeInsets.fromLTRB(2, 4, 2, 10)
        : const EdgeInsets.fromLTRB(2, 0, 2, 15);
    final giconSize = isMobile ? 28.0 : 34.0; // mobile 28 / tablet 34
    final gnameSize = isMobile ? 15.0 : 17.0; // mobile 15 / tablet 17
    final gcntSize = isMobile ? 11.5 : 12.5; // mobile 11.5 / tablet 12.5
    final gsubSize = isMobile ? 13.5 : 15.0; // mobile 13.5 / tablet 15
    final iconIconSize = isMobile ? 14.0 : 16.0; // gicon font-size 14/16

    // .group margin-top:28px（首组无 margin，由外层 spacing 提供；此 widget 自身不加）。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // group-head（无 Divider —— 原型 .group-head 后直接 .grid，无分隔线）
        Padding(
          padding: headPad,
          child: Row(
            children: [
              // .gicon 圆 bg:类型色软底 + 类型图标
              Container(
                width: giconSize,
                height: giconSize,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryIcon(type), size: iconIconSize, color: typeColor),
              ),
              SizedBox(width: headGap),
              Text(type.label,
                  style: TextStyle(
                      fontSize: gnameSize, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              // .gcnt N 个账户
              Text('${accounts.length} 个账户',
                  style: TextStyle(color: AppColors.muted, fontSize: gcntSize)),
              const Spacer(),
              // .gsub 小计 ¥X —— mono tabular w600；<small>小计</small> 11 muted 前缀（仅 tablet）
              if (!isMobile)
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: gsubSize,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures,
                      color: isLiability ? AppColors.negative : AppColors.fg,
                    ),
                    children: [
                      const TextSpan(
                        text: '小计 ',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w400),
                      ),
                      TextSpan(text: formatCents(subtotal)),
                    ],
                  ),
                )
              else
                // mobile .gsub 无「小计」前缀，直接金额
                Text(
                  formatCents(subtotal),
                  style: TextStyle(
                    fontSize: gsubSize,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures,
                    color: isLiability ? AppColors.negative : AppColors.fg,
                  ),
                ),
            ],
          ),
        ),
        // account-grid
        LayoutBuilder(
          builder: (context, constraints) {
            // 三断点（基于 group 容器宽 ≈ page 内容宽）：
            //   mobile <600     → 1 列 Column（卡片高度自适应内容，无 aspect 约束）
            //   tablet 600-1099 → 2 列 GridView，aspect 取适配最高卡片的值
            //   desktop >=1100  → auto-fill 280px GridView，同上 aspect
            //
            // 高度问题：固定 childAspectRatio 会让高内容卡（subline+bar+bar-meta，
            // 如信用卡/贷款）底部被裁剪、矮卡留白。mobile 改 Column 使每卡 intrinsic
            // 高度；tablet/desktop 取一个能容纳最高卡内容的 aspect（实测最高内容
            // ≈165px @ 280 宽 → 1.70；但 tablet 卡更宽（~500）需 height 同 165 →
            // aspect≈3.0，取 3.1 留余量；desktop 280 宽取 1.68 留余量）。
            const gap = 14.0;
            if (constraints.maxWidth < 600) {
              // mobile：Column + SizedBox gap 还原 mainAxisSpacing:14。
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < accounts.length; i++) ...[
                    _AccountCard(
                      account: accounts[i],
                      formatCents: formatCents,
                      onLongPress: () => onDelete(accounts[i]),
                    ),
                    if (i < accounts.length - 1) const SizedBox(height: gap),
                  ],
                ],
              );
            }
            int cols;
            double aspect;
            if (constraints.maxWidth < 1100) {
              cols = 2;
              // tablet 卡宽 ~500，最高内容 ~165 → aspect≈3.0，取 3.1 留余量。
              aspect = 3.1;
            } else {
              const colWidth = 280.0;
              cols = ((constraints.maxWidth + gap) / (colWidth + gap)).floor();
              if (cols < 1) cols = 1;
              // desktop 卡宽 280，最高内容 ~165 → aspect≈1.70，取 1.68 留余量。
              aspect = 1.68;
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: aspect,
              ),
              itemCount: accounts.length,
              itemBuilder: (_, i) => _AccountCard(
                account: accounts[i],
                formatCents: formatCents,
                onLongPress: () => onDelete(accounts[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ───────────────────────── 账户卡 ─────────────────────────

/// 原型 .card / .acc：自承载 hover（MouseRegion + AnimatedContainer）以精确还原
/// translateY(-2px) + box-shadow:0 10px 26px rgba(0,0,0,.07)。
/// 弃用共享 DataCard（其 translateY-1 + border + 不同 shadow 无法 1:1 匹配原型）。
class _AccountCard extends StatefulWidget {
  const _AccountCard({
    required this.account,
    required this.formatCents,
    required this.onLongPress,
  });

  final Account account;
  final String Function(int) formatCents;
  final VoidCallback onLongPress;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _hover = false;
  // mobile :active transform:scale(.985) —— 仅 press 期间。
  bool _pressed = false;

  /// 透传 widget.formatCents，使 helper 方法内部沿用原 `formatCents(...)` 调用。
  String Function(int) get formatCents => widget.formatCents;

  @override
  Widget build(BuildContext context) {
    // 断点基于页面宽度：mobile(<600) 紧凑行，desktop/tablet 完整卡。
    final isMobile = MediaQuery.of(context).size.width < 600;
    return isMobile ? _compactCard(context) : _fullCard(context);
  }

  /// 计算 hover/active 的 transform：
  ///  - desktop/tablet .card:hover → translateY(-2px)
  ///  - mobile .acc:active → scale(0.985)
  Matrix4 _transformFor(bool isMobile) {
    if (isMobile) {
      if (!_pressed) return Matrix4.identity();
      // .acc:active scale(0.985) —— 直接构造缩放矩阵（vector_math 的 scale() 已废弃）。
      return Matrix4.diagonal3Values(0.985, 0.985, 1.0);
    }
    return _hover
        ? Matrix4.translationValues(0.0, -2.0, 0.0)
        : Matrix4.identity();
  }

  Widget _cardShell({required Widget child, required bool isMobile}) {
    final a = widget.account;
    final archived = a.status == AccountStatus.archived;
    // .card padding:18px 20px radius:14；.acc padding:12px 14px radius:10 mb:8。
    final padding = isMobile
        ? const EdgeInsets.symmetric(horizontal: 14, vertical: 12)
        : const EdgeInsets.symmetric(horizontal: 20, vertical: 18);
    final radius = isMobile ? AppRadius.sm : AppRadius.lg; // 10 / 14
    Widget card = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() {
        _hover = false;
        _pressed = false;
      }),
      child: GestureDetector(
        onTap: () => context.go('/accounts/${a.id}'),
        onLongPress: widget.onLongPress,
        onTapDown: (_) => isMobile ? setState(() => _pressed = true) : null,
        onTapUp: (_) => isMobile ? setState(() => _pressed = false) : null,
        onTapCancel: () => isMobile ? setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140), // .card transition:.14s
          transform: _transformFor(isMobile),
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.all(Radius.circular(radius)),
            // 无 border（原型 .card/.acc 均无 border，仅有 bg + radius）。
            boxShadow: isMobile
                ? const []
                : [
                    if (_hover)
                      // .card:hover box-shadow:0 10px 26px rgba(0,0,0,.07)
                      const BoxShadow(
                        color: Color(0x12000000), // .07 alpha
                        blurRadius: 26,
                        offset: Offset(0, 10),
                      ),
                  ],
          ),
          child: child,
        ),
      ),
    );
    if (archived) card = Opacity(opacity: 0.55, child: card);
    return card;
  }

  /// desktop/tablet 完整卡（对齐 tablet.html .card）。
  Widget _fullCard(BuildContext context) {
    final a = widget.account;
    final negative = a.currentBalanceCents < 0;
    final typeColor = categoryColor(a.category);
    final spec = _usageSpec(a);
    final (label, val) = _compactVal(a);
    final archived = a.status == AccountStatus.archived;

    return _cardShell(
      isMobile: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // r1：cicon(左 44) + cmain + cv(右)
          Row(
            children: [
              // .cicon 44 circle font-size 21
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryIcon(a.category), size: 21, color: typeColor),
              ),
              const SizedBox(width: 13), // .r1 gap:13
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                        if (archived) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.muted.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('已归档',
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3), // .corg margin-top:3
                    Text(
                      _subline(a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8), // .cv padding-left:8
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // .cvlabel 11.5 muted
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11.5)),
                    const SizedBox(height: 2), // .cval margin-top:2
                    // .cval 21 mono w600 tabular
                    Text(
                      val,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: negative ? AppColors.negative : AppColors.fg,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // .csub margin-top:14 padding-top:13 border-top 1px #e6e3dc 12.5 muted
          if (_hasSub(a)) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 13),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: _sublineWidget(a),
            ),
          ],
          // .bar 6 radius:6 bg:accent-soft margin-top:13
          if (spec != null) ...[
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: spec.$1,
                minHeight: 6,
                backgroundColor: AppColors.accentSoft,
                valueColor: AlwaysStoppedAnimation<Color>(spec.$2),
              ),
            ),
            // .bar-meta margin-top:7 mono 11.5 space-between
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    a.category == AccountCategory.creditCard
                        ? '已用 ${formatCents(a.currentBalanceCents.abs())} / ${formatCents(a.creditLimitCents)}'
                        : '已还 ${formatCents((a.loanOriginalCents ?? 0) - (a.loanRemainingCents ?? 0))} / ${formatCents(a.loanOriginalCents ?? 0)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11.5,
                        fontFeatures: AppTypography.tabularFigures),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${(spec.$1 * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                      color: spec.$2,
                      fontSize: 11.5,
                      fontFeatures: AppTypography.tabularFigures),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// mobile 紧凑行卡片（对齐 mobile.html .acc）。
  Widget _compactCard(BuildContext context) {
    final a = widget.account;
    final negative = a.currentBalanceCents < 0;
    final typeColor = categoryColor(a.category);
    final archived = a.status == AccountStatus.archived;
    final spec = _usageSpec(a);
    final (label, val) = _compactVal(a);

    // .acc margin-bottom:8（由外层 GridView mainAxisSpacing 提供，故不加内 margin）。
    return _cardShell(
      isMobile: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // r1：aicon(36) + amain + av
          Row(
            children: [
              // .aicon 36 circle font-size 17
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryIcon(a.category), size: 17, color: typeColor),
              ),
              const SizedBox(width: 11), // .r1 gap:11
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(a.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14.5, fontWeight: FontWeight.w600)),
                        ),
                        if (archived) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.muted.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('已归档',
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2), // .aorg margin-top:2
                    Text(
                      _subline(a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8), // .av padding-left:8
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // .avlabel 10.5 muted margin-bottom:2
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 10.5)),
                  const SizedBox(height: 2),
                  // .aval 15 mono w600 tabular
                  Text(
                    val,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: negative ? AppColors.negative : AppColors.fg,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ],
              ),
            ],
          ),
          // .bar 5 radius:5 margin-top:10（在 .asub 之前 —— proto 顺序）
          if (spec != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: spec.$1,
                minHeight: 5,
                backgroundColor: AppColors.accentSoft,
                valueColor: AlwaysStoppedAnimation<Color>(spec.$2),
              ),
            ),
          ],
          // .asub margin-top:9 padding-top:9 border-top 1px (dashed→solid) 11.5 muted
          if (_hasSub(a)) ...[
            const SizedBox(height: 9),
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 9),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: _sublineWidget(a),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── 以下为业务副信息 helper（保持原逻辑不变） ───

  (String, String) _compactVal(Account a) {
    switch (a.category) {
      case AccountCategory.creditCard:
        return ('当前欠款', formatCents(a.currentBalanceCents));
      case AccountCategory.loan:
        return ('剩余本金', formatCents(a.loanRemainingCents ?? 0));
      case AccountCategory.investment:
        return ('当前市值', formatCents(a.investMarketValueCents ?? 0));
      case AccountCategory.goldFx:
        final cur = a.goldCurrentPriceCents ?? 0;
        final qty = a.goldQuantity ?? 0;
        return ('当前现值', formatCents((cur * qty).toInt()));
      case AccountCategory.realEstate:
        return ('现估值', formatCents(a.estateCurrentValueCents ?? 0));
      case AccountCategory.fixedDeposit:
        return ('存单本金', formatCents(a.fixedPrincipalCents ?? 0));
      case AccountCategory.otherAsset:
        return ('账户金额', formatCents(a.currentBalanceCents));
      case AccountCategory.otherLiability:
        return ('待还金额', formatCents(a.currentBalanceCents));
      case AccountCategory.savings:
        return ('可用余额', formatCents(a.currentBalanceCents));
    }
  }

  bool _hasSub(Account a) {
    if (a.category == AccountCategory.savings && a.interestRate == null) {
      return false;
    }
    return true;
  }

  String _subline(Account a) {
    if (a.institution.isNotEmpty) {
      return a.cardNumberTail.isNotEmpty
          ? '${a.institution} · 尾号 ${a.cardNumberTail}'
          : a.institution;
    }
    return '${a.category.label} · ${a.currencyCode}';
  }

  Widget _sublineWidget(Account a) {
    const style = TextStyle(color: AppColors.muted, fontSize: 12);
    Color tone(double v) => v >= 0 ? AppColors.positive : AppColors.negative;
    String sign(double v) => v >= 0 ? '+' : '';
    switch (a.category) {
      case AccountCategory.creditCard:
        return Text(
          '额度 ${formatCents(a.creditLimitCents)} · '
          '账单${a.creditBillingDay ?? '-'}日 / '
          '还款${a.creditRepaymentDay ?? '-'}日',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case AccountCategory.investment:
        final r = a.investReturnYtd ?? 0.0;
        return Text(
          '${sign(r)}${r.toStringAsFixed(2)}% 今年收益',
          style: TextStyle(color: tone(r), fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case AccountCategory.fixedDeposit:
        return Text(
          '到期 ${_fmtDate(a.fixedMaturityDate)} · '
          '利率 ${a.interestRate?.toStringAsFixed(2) ?? '-'}%',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case AccountCategory.goldFx:
        final qty = a.goldQuantity ?? 0;
        final cur = a.goldCurrentPriceCents ?? 0;
        final buy = a.goldBuyPriceCents ?? 0;
        final pct = buy > 0 ? (cur - buy) / buy * 100 : 0.0;
        return Text(
          '现值 ${formatCents((cur * qty).toInt())} · 买入 ${formatCents(buy)} · '
          '${sign(pct)}${pct.toStringAsFixed(2)}%',
          style: TextStyle(color: tone(pct), fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case AccountCategory.realEstate:
        final cur = a.estateCurrentValueCents ?? 0;
        final buy = a.estatePurchasePriceCents ?? 0;
        final pct = buy > 0 ? (cur - buy) / buy * 100 : 0.0;
        return Text(
          '现估值 ${formatCents(cur)} · ${sign(pct)}${pct.toStringAsFixed(2)}%',
          style: TextStyle(color: tone(pct), fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case AccountCategory.loan:
        return Text(
          '原始 ${formatCents(a.loanOriginalCents ?? 0)} · '
          '月供 ${formatCents(a.loanMonthlyCents ?? 0)} · '
          '下次 ${_fmtDate(a.loanNextPaymentDate)}',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case AccountCategory.savings:
      case AccountCategory.otherAsset:
      case AccountCategory.otherLiability:
        final rate = a.interestRate;
        return rate == null
            ? const Text('可用余额', style: style)
            : Text('利率 ${rate.toStringAsFixed(2)}%', style: style);
    }
  }

  (double, Color)? _usageSpec(Account a) {
    switch (a.category) {
      case AccountCategory.creditCard:
        if (a.creditLimitCents <= 0) return null;
        final v = (a.currentBalanceCents.abs() / a.creditLimitCents)
            .clamp(0.0, 1.0);
        return (v, AppColors.negative);
      case AccountCategory.loan:
        final orig = a.loanOriginalCents ?? 0;
        final remain = a.loanRemainingCents ?? 0;
        if (orig <= 0) return null;
        final v = ((orig - remain) / orig).clamp(0.0, 1.0);
        return (v, AppColors.positive);
      default:
        return null;
    }
  }

  static String _fmtDate(DateTime? d) =>
      d == null ? '-' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
