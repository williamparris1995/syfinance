import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
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

  /// 编辑：预填现有账户，提交后触发更新。
  void _openEditForm(Account a) {
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AccountBloc>(),
          child: AccountFormPage(existing: a),
        ),
      ),
    )
        .then((ok) {
      if (ok == true && mounted) {
        AppToast.show(context, '账户已更新');
      }
    });
  }

  /// 复制：清空 id/version，以原账户为 seed 走创建流程。
  void _openCopyForm(Account a) {
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<AccountBloc>(),
          child: AccountFormPage(
            existing: a.copyWith(id: '', version: 0),
          ),
        ),
      ),
    )
        .then((ok) {
      if (ok == true && mounted) {
        AppToast.show(context, '账户已复制');
      }
    });
  }

  /// 关闭账户：归档（status=archived），账户仍可见但停止参与活跃统计。
  void _confirmClose(Account a) {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('关闭账户'),
        content: Text('关闭「${a.name}」？关闭后账户归档，详情仍可查看。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('关闭')),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        setState(() => _pendingIds.add(a.id));
        context.read<AccountBloc>().add(UpdateAccountRequested(
              UpdateAccountParams(
                id: a.id,
                version: a.version,
                status: AccountStatus.archived,
                // 保留现有值字段：account_remote_ds.update 对非 optional 标量
                // （name/icon/color/institution/creditLimitCents）无条件覆盖，
                // 不传会用默认值（''/0）→ 关闭账户会清空这些字段。补传当前值
                // 确保关闭只改 status，不破坏其他字段。string 字段（cardNumberTail
                // /notes/goldProductType）虽 remote_ds 对非空才设，但保留值更安全。
                // nullable 字段（26 个 type-specific）保持默认 null：remote_ds 对
                // null 不设，不会清空。
                name: a.name,
                icon: a.icon,
                color: a.color,
                institution: a.institution,
                creditLimitCents: a.creditLimitCents,
                cardNumberTail: a.cardNumberTail,
                notes: a.notes,
                goldProductType: a.goldProductType,
              ),
            ));
      }
    });
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
    final totalCents =
        accounts.fold<int>(0, (s, a) => s + a.currentBalanceCents);
    final filtered = _filter == null
        ? accounts
        : accounts.where((a) => a.category == _filter).toList();
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
                  totalCents: totalCents,
                  count: accounts.length,
                  onAdd: _openCreateForm,
                ),
                const SizedBox(height: AppSpacing.md),
                FilterBar<AccountCategory?>(
                  tabs: tabs,
                  active: _filter,
                  onChanged: (v) => setState(() => _filter = v),
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
                      onEdit: _openEditForm,
                      onDuplicate: _openCopyForm,
                      onClose: _confirmClose,
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
    required this.totalCents,
    required this.count,
    required this.onAdd,
  });

  final int totalCents;
  final int count;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    const TextSpan(
                      text: '全部账户余额合计 · ',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 15),
                    ),
                    TextSpan(
                      text: _formatInline(totalCents),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: totalCents < 0
                            ? AppColors.negative
                            : AppColors.fg,
                        letterSpacing: -0.3,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text('共 $count 个账户',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
        _NewAccountButton(onPressed: onAdd),
      ],
    );
  }

  String _formatInline(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    // 千分位
    final s = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$sign¥ $buf.$fen';
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
    required this.onEdit,
    required this.onDuplicate,
    required this.onClose,
  });

  final AccountCategory type;
  final List<Account> accounts;
  final String Function(int) formatCents;
  final Future<void> Function(Account) onDelete;
  final void Function(Account) onEdit;
  final void Function(Account) onDuplicate;
  final void Function(Account) onClose;

  @override
  Widget build(BuildContext context) {
    final subtotal =
        accounts.fold<int>(0, (s, a) => s + a.currentBalanceCents);
    final absSubtotal = subtotal.abs();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // group-header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(_categoryIcon(type), size: 20, color: AppColors.accent),
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
            // 原型 auto-fill minmax(280, 1fr) gap14。
            final colWidth = 280.0;
            final gap = 14.0;
            var cols =
                ((constraints.maxWidth + gap) / (colWidth + gap)).floor();
            if (cols < 1) cols = 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: 1.72,
              ),
              itemCount: accounts.length,
              itemBuilder: (_, i) => _AccountCard(
                account: accounts[i],
                formatCents: formatCents,
                barFraction: absSubtotal == 0
                    ? 0.4
                    : (accounts[i].currentBalanceCents.abs() / absSubtotal)
                        .clamp(0.06, 1.0),
                onLongPress: () => onDelete(accounts[i]),
                onEdit: () => onEdit(accounts[i]),
                onDuplicate: () => onDuplicate(accounts[i]),
                onClose: () => onClose(accounts[i]),
                onDelete: () => onDelete(accounts[i]),
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
    required this.barFraction,
    required this.onLongPress,
    this.onEdit,
    this.onDuplicate,
    this.onClose,
    this.onDelete,
  });

  final Account account;
  final String Function(int) formatCents;
  final double barFraction;
  final VoidCallback onLongPress;
  final VoidCallback? onEdit;
  final VoidCallback? onDuplicate;
  final VoidCallback? onClose;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final negative = account.currentBalanceCents < 0;
    final typeColor = _categoryColor(account.category);
    return DataCard(
      // 点击卡片直接进详情（⋯ 菜单另有点击/长按入口）。
      onTap: () => context.go('/accounts/${account.id}'),
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ac-top：左 name+机构，中 类型图标，右 操作菜单
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(
                      account.institution.isNotEmpty
                          ? '${account.institution} · ${account.currencyCode}'
                          : '${account.category.label} · ${account.currencyCode}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(_categoryIcon(account.category),
                    size: 18, color: typeColor),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz,
                    size: 18, color: AppColors.muted),
                tooltip: '账户操作',
                itemBuilder: (_) => const [
                  PopupMenuItem(
                      value: 'detail', child: Text('查看详情')),
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'copy', child: Text('复制')),
                  PopupMenuItem(
                      value: 'record',
                      enabled: false,
                      child: Text('记一笔（待交易模块）')),
                  PopupMenuItem(
                      value: 'transfer',
                      enabled: false,
                      child: Text('转账（待交易模块）')),
                  PopupMenuItem(value: 'close', child: Text('关闭账户')),
                  PopupMenuItem(value: 'delete', child: Text('删除账户')),
                ],
                onSelected: (v) {
                  switch (v) {
                    case 'detail':
                      context.go('/accounts/${account.id}');
                    case 'edit':
                      onEdit?.call();
                    case 'copy':
                      onDuplicate?.call();
                    case 'close':
                      onClose?.call();
                    case 'delete':
                      onDelete?.call();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ac-balance
          Text(
            formatCents(account.currentBalanceCents),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: negative ? AppColors.negative : AppColors.fg,
              fontFeatures: AppTypography.tabularFigures,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback,
            ),
          ),
          const SizedBox(height: 4),
          // ac-sub
          Text(_subline(account),
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 14),
          // ac-bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 3,
              color: AppColors.border,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: barFraction,
                child: Container(color: typeColor),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _subline(Account a) {
    if (a.creditLimitCents > 0) {
      return '额度 ${formatCents(a.creditLimitCents)} · ${a.ownership.label}';
    }
    return '可用余额 · ${a.ownership.label}';
  }
}

// ───────────────────────── 类型色 / 图标 ─────────────────────────

Color _categoryColor(AccountCategory c) {
  switch (c) {
    case AccountCategory.savings:
      return AppColors.positive;
    case AccountCategory.creditCard:
      return const Color(0xFF6B8CCE);
    case AccountCategory.investment:
      return AppColors.accent;
    case AccountCategory.fixedDeposit:
      return const Color(0xFF8A8A6B);
    case AccountCategory.goldFx:
      return const Color(0xFFC9A03D);
    case AccountCategory.realEstate:
      return const Color(0xFF8C7BB5);
    case AccountCategory.loan:
      return AppColors.negative;
    case AccountCategory.otherAsset:
      return AppColors.muted;
    case AccountCategory.otherLiability:
      return AppColors.negative;
  }
}

IconData _categoryIcon(AccountCategory c) {
  switch (c) {
    case AccountCategory.savings:
      return Icons.account_balance_wallet_outlined;
    case AccountCategory.creditCard:
      return Icons.credit_card_outlined;
    case AccountCategory.investment:
      return Icons.trending_up;
    case AccountCategory.fixedDeposit:
      return Icons.hourglass_bottom;
    case AccountCategory.goldFx:
      return Icons.diamond_outlined;
    case AccountCategory.realEstate:
      return Icons.home_outlined;
    case AccountCategory.loan:
      return Icons.request_quote_outlined;
    case AccountCategory.otherAsset:
      return Icons.inventory_2_outlined;
    case AccountCategory.otherLiability:
      return Icons.pending_actions;
  }
}
