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
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/core/widgets/filter_bar.dart';

/// 账户管理列表页。严格还原 desktop-accounts.html：
/// 汇总头（合计 · ¥X + 新建按钮）→ 胶囊筛选 → 按类型分组的账户卡片网格。
/// 每张卡 = ac-top（名称+机构 / 类型图标）→ 余额 → 副信息 → 3px 进度条。
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

    final tabs = <FilterTab<AccountCategory?>>[
      const FilterTab(null, '全部'),
      for (final t in AccountCategory.values) FilterTab(t, t.label),
    ];

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
                const SizedBox(height: AppSpacing.md),
                FilterBar<AccountCategory?>(
                  tabs: tabs,
                  active: _filter,
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
                const SizedBox(height: AppSpacing.lg),
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
                    const SizedBox(height: AppSpacing.xl),
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
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorder,
            boxShadow: const [
              BoxShadow(color: Color(0x141A1916), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _netBlock(),
                    const SizedBox(width: 26),
                    _vline(),
                    const SizedBox(width: 26),
                    _statBlock('总资产', assetCents, AppColors.positive),
                    const SizedBox(width: 26),
                    _vline(),
                    const SizedBox(width: 26),
                    _statBlock('总负债', liabCents, AppColors.negative),
                  ],
                ),
              ),
              _NewAccountButton(onPressed: onAdd),
            ],
          ),
        ),
      ],
    );
  }

  /// mobile：紧凑汇总卡（对齐 mobile.html .summary）。
  Widget _mobileCard(BuildContext context) {
    return Stack(
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
        Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 17),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadius.lgBorder,
          ),
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
            ],
          ),
        ),
      ],
    );
  }

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
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: _hover ? AppColors.accentHover : AppColors.accent,
            borderRadius: AppRadius.smBorder,
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 15, color: Colors.white),
              SizedBox(width: 6),
              Text('新建账户',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // group-header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(categoryIcon(type), size: 20, color: AppColors.accent),
              const SizedBox(width: 8),
              Text(type.label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('合计 ${formatCents(subtotal)}',
                  style: TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                      fontFeatures: AppTypography.tabularFigures)),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: AppSpacing.sm),
        // account-grid
        LayoutBuilder(
          builder: (context, constraints) {
            // 三断点（基于 group 容器宽 ≈ page 内容宽）：
            //   mobile <600     → 1 列，紧凑行（aspect 2.3 更矮）
            //   tablet 600-1099 → 2 列，完整卡（aspect 1.72）
            //   desktop >=1100  → auto-fill 280px，完整卡（aspect 1.72）
            // gap14 与原型 minmax(280, 1fr) gap14 一致。
            final gap = 14.0;
            int cols;
            double aspect;
            if (constraints.maxWidth < 600) {
              cols = 1;
              // 紧凑行实际高度含 padding + 标题 + 副信息 + 进度条 ~120-130h；
              // 窄屏（390 - padding → 卡 ~290w）需 aspect ~2.3 避免溢出。
              aspect = 2.3;
            } else if (constraints.maxWidth < 1100) {
              cols = 2;
              aspect = 1.72;
            } else {
              const colWidth = 280.0;
              cols = ((constraints.maxWidth + gap) / (colWidth + gap)).floor();
              if (cols < 1) cols = 1;
              aspect = 1.72;
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

class _AccountCard extends StatelessWidget {
  const _AccountCard({
    required this.account,
    required this.formatCents,
    required this.onLongPress,
  });

  final Account account;
  final String Function(int) formatCents;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    // 断点基于页面宽度（非卡片宽度）：mobile(<600) 紧凑行，desktop/tablet 完整卡。
    // 卡片宽度（网格 cell ~280-500）永远 <600，故不能用 LayoutBuilder 约束判形态。
    final isMobile = MediaQuery.of(context).size.width < 600;
    return isMobile ? _compactCard(context) : _fullCard(context);
  }

  /// desktop/tablet 完整卡（对齐 tablet.html .card：cicon 左 + cmain + cv 右 + csub 分隔 + bar + bar-meta）。
  /// 操作（编辑/记账/转账/删除等）移至详情页 AppBar，列表卡点即进详情（对齐原型无 menu）。
  Widget _fullCard(BuildContext context) {
    final a = account;
    final negative = a.currentBalanceCents < 0;
    final typeColor = categoryColor(a.category);
    final archived = a.status == AccountStatus.archived;
    final spec = _usageSpec(a); // (fraction, color)? — 仅信用卡/贷款
    final (label, val) = _compactVal(a); // 复用 compact label/val（对齐原型 describe）

    Widget card = DataCard(
      onTap: () => context.go('/accounts/${a.id}'),
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // r1：cicon(左) + cmain + cv(右)（对齐原型 .card .r1）
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryIcon(a.category), size: 21, color: typeColor),
              ),
              const SizedBox(width: 13),
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
                          const Text('已归档',
                              style:
                                  TextStyle(color: AppColors.muted, fontSize: 10)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
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
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11.5)),
                    const SizedBox(height: 2),
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
          // csub：副信息（实线 border-top 分隔，对齐原型 .csub）
          if (_hasSub(a)) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.only(top: 13),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: _sublineWidget(a),
            ),
          ],
          // bar + bar-meta（仅信用卡/贷款，对齐原型 .bar + .bar-meta）
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
    if (archived) card = Opacity(opacity: 0.55, child: card);
    return card;
  }

  /// mobile 紧凑行卡片（对齐 mobile.html .acc）。
  /// 水平：aicon + (name + 机构·尾号) | (label + 余额)；下方副信息 + 进度条。
  Widget _compactCard(BuildContext context) {
    final a = account;
    final negative = a.currentBalanceCents < 0;
    final typeColor = categoryColor(a.category);
    final archived = a.status == AccountStatus.archived;
    final spec = _usageSpec(a); // (fraction, color)? — 复用，仅信用卡/贷款非 null
    final (label, val) = _compactVal(a); // (label, 格式化值)

    Widget card = DataCard(
      onTap: () => context.go('/accounts/${a.id}'),
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // r1：aicon + amain + av
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(categoryIcon(a.category), size: 18, color: typeColor),
              ),
              const SizedBox(width: 11),
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
                          const Text('已归档',
                              style:
                                  TextStyle(color: AppColors.muted, fontSize: 10)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _subline(a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 10.5)),
                  const SizedBox(height: 2),
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
          // 副信息（分隔）+ 进度条（若有）。
          if (_hasSub(a) || spec != null) ...[
            const SizedBox(height: 9),
            // asub：复用 _sublineWidget（类型副信息），实线 border-top 近似原型虚线
            // （Flutter 原生无 dotted；如需精确虚线后续用 dotted_border 包）。
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Container(
                padding: const EdgeInsets.only(top: 9),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: _sublineWidget(a),
              ),
            ),
          ],
          if (spec != null) ...[
            const SizedBox(height: 8),
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
        ],
      ),
    );
    if (archived) card = Opacity(opacity: 0.55, child: card);
    return card;
  }

  /// 紧凑行右侧 (label, value)：主数字按 category（对齐原型 describe()）。
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

  /// 是否有类型副信息（紧凑行虚线下方）。储蓄无利率时无副信息。
  bool _hasSub(Account a) {
    if (a.category == AccountCategory.savings &&
        a.interestRate == null) return false;
    return true;
  }

  /// 卡片副标题：机构 · 卡号尾号（对齐 OD accounts.html hero-sub）。
  /// institution 空 → fallback category · 币种（保留可读性）。
  String _subline(Account a) {
    if (a.institution.isNotEmpty) {
      return a.cardNumberTail.isNotEmpty
          ? '${a.institution} · 尾号 ${a.cardNumberTail}'
          : a.institution;
    }
    return '${a.category.label} · ${a.currencyCode}';
  }

  /// 类型专属副信息。按 [Account.category] 分支渲染：
  /// 储蓄=利率（interestRate 有值时）/ 信用卡=额度+账单+还款日 / 投资=今年收益率
  /// / 定期=到期日+利率 / 黄金=买入+涨幅 / 房产=现估值+增值 / 贷款=原始+月供+下次还款。
  /// 涨跌幅/收益率正绿负红（[AppColors.positive]/[AppColors.negative]）。
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
        // 涨幅按单位价格比（现价/买入价），与持仓数量无关。
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
            ? Text('可用余额', style: style)
            : Text('利率 ${rate.toStringAsFixed(2)}%', style: style);
    }
  }

  /// 返回 (fraction, color)，无法计算时 null（不渲染 bar）。
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
