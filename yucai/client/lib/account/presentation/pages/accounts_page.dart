import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/account/presentation/widgets/account_category_style.dart';
import 'package:yucai_client/app/route_observer.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/yucai_menu.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/transaction/presentation/pages/transaction_form_page.dart';

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

/// 千分位 + 两位小数，前缀用 `currencySymbol(currencyCode)`。
/// 供总计/小计/状态卡等「单货币展示」场景复用（金额已是该货币口径）。
String _fmtSymbol(int cents, String currencyCode) {
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
  return '$sign${currencySymbol(currencyCode)}$buf.$fen';
}

/// Card 主数字 + 总计/小计共用的「展示金额」(cents，原货币口径)。对齐 OD 原型
/// `numValue()`：各 category 取对应字段——investment→市值、gold→现价×数量、
/// realEstate→现估值、loan→剩余本金，其余→currentBalance。Card 显示与 fold
/// 统一用此值，避免「Card 显示现估值但小计用 balance(=0)不计入」的口径不一致。
int _displayValueCents(Account a) {
  // 估值字段缺失（null/0）时回退 currentBalanceCents：例如武汉房产 currentBalance
  // =230万但 estateValue 未填，不能因估值缺失就把整笔资产踢出小计/总计。
  switch (a.category) {
    case AccountCategory.investment:
      final v = a.investMarketValueCents;
      return (v != null && v > 0) ? v : a.currentBalanceCents;
    case AccountCategory.goldFx:
      final cur = a.goldCurrentPriceCents;
      final qty = a.goldQuantity;
      return (cur != null && qty != null && cur > 0)
          ? (cur * qty).toInt()
          : a.currentBalanceCents;
    case AccountCategory.realEstate:
      final v = a.estateCurrentValueCents;
      return (v != null && v > 0) ? v : a.currentBalanceCents;
    case AccountCategory.fixedDeposit:
      final v = a.fixedPrincipalCents;
      return (v != null && v > 0) ? v : a.currentBalanceCents;
    case AccountCategory.loan:
      final v = a.loanRemainingCents;
      return (v != null && v != 0) ? v : a.currentBalanceCents;
    case AccountCategory.creditCard:
    case AccountCategory.savings:
    case AccountCategory.otherAsset:
    case AccountCategory.otherLiability:
      return a.currentBalanceCents;
  }
}

class _AccountsPageState extends State<AccountsPage> with RouteAware {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 订阅全局 RouteObserver：从详情页/编辑页 pop 回来时 didPopNext 触发，重新拉
    // 列表——详情页用独立 AccountBloc，编辑只刷新它自己的 bloc，列表不会自动更新。
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    // 从详情/编辑返回：账户数据可能已变（编辑估值、记交易等），重新拉取。
    if (mounted) {
      context.read<AccountBloc>().add(LoadAccountsRequested());
    }
  }

  String _formatCents(int cents, String currencyCode) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    return '$sign${currencySymbol(currencyCode)}${_groupThousands(yuan)}.$fen';
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
            existing:
                a.copyWith(id: '', version: 0, name: '${a.name}（副本）'),
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
                // 确保关闭只改 status，不破坏其他字段。
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

  /// 重新激活：把归档账户恢复为 active（与 _confirmClose 对称）。
  void _reactivate(Account a) {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('重新激活账户'),
        content: Text('重新激活「${a.name}」？账户恢复活跃状态。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('激活')),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        setState(() => _pendingIds.add(a.id));
        context.read<AccountBloc>().add(UpdateAccountRequested(
              UpdateAccountParams(
                id: a.id,
                version: a.version,
                status: AccountStatus.active,
                // 保留现有值字段（同 _confirmClose）。
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
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
                    color: context.yucai.accentSoft,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(LucideIcons.wallet,
                      size: 30, color: context.yucai.accent),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text('还没有账户',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('点击右上角「新建账户」开始记录',
                    style: TextStyle(color: context.yucai.muted, fontSize: 14)),
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
    // 货币换算口径（rates/preferred 来自 CurrencyBloc）。总计/小计统一换算到
    // preferred 后累加；Card 余额仍按各账户原货币显示（见 _formatCents）。
    final cstate = context.watch<CurrencyBloc>().state;
    // account-as-category 方案下 Expense/Income 类型账户 = 分类，归属分类管理页，
    // 不应出现在账户列表。这里只保留资产/负债账户（equity 系统账户也排除）。
    final balanceSheet = accounts.where((a) =>
        a.accountType == AccountType.asset ||
        a.accountType == AccountType.liability);
    // 归档账户不参与活跃统计（合计/默认列表）；_showArchived 时才显示。
    final active = balanceSheet
        .where((a) => a.status == AccountStatus.active)
        .toList();
    final assetCents = active.where((a) => a.accountType == AccountType.asset).fold<int>(
        0,
        (s, a) => s +
            toPreferredCents(_displayValueCents(a), a.currencyCode, cstate.rates, cstate.preferred));
    // 负债类用 currentBalanceCents（欠款/余额，负值），不用 _displayValueCents：
    // loan 的 loanRemainingCents 是正数（剩余本金），若 fold 进 netCents(=asset+liab)
    // 会把负债误加成资产。资产类才用 _displayValueCents（含估值字段）。
    final liabCents = active.where((a) => a.accountType == AccountType.liability).fold<int>(
        0,
        (s, a) => s +
            toPreferredCents(a.currentBalanceCents, a.currencyCode, cstate.rates, cstate.preferred));
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
                  preferred: cstate.preferred,
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
                      Text('含已归档账户',
                          style: TextStyle(
                              color: context.yucai.muted, fontSize: 13)),
                    ],
                  ),
                ),
                if (groups.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(
                      child: Text('该筛选下暂无账户',
                          style: TextStyle(color: context.yucai.muted))),
                  )
                else
                  for (final entry in groups.entries) ...[
                    _GroupBlock(
                      type: entry.key,
                      accounts: entry.value,
                      formatCents: _formatCents,
                      onEdit: _openEditForm,
                      onDuplicate: _openCopyForm,
                      onClose: _confirmClose,
                      onReactivate: _reactivate,
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
    required this.preferred,
    required this.onAdd,
  });

  final int netCents;
  final int assetCents;
  final int liabCents;
  /// 总计金额的展示货币代码（已换算到此货币），用于符号前缀。
  final String preferred;
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.yucai.accentSoft,
            ),
          ),
        ),
        Container(
          // .sumcard padding:26px 30px（vertical 26 / horizontal 30）
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 26),
          decoration: BoxDecoration(
            color: context.yucai.surface,
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
                    _statBlock('总资产', assetCents, context.yucai.positive),
                    const SizedBox(width: 32),
                    _vline(),
                    const SizedBox(width: 32),
                    _statBlock('总负债', liabCents, context.yucai.negative),
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
      decoration: BoxDecoration(
        color: context.yucai.surface,
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.yucai.accentSoft,
              ),
            ),
          ),
          // 右上角圆形 + 新建按钮（mobile：只 Icon 无文字，对齐原型 mobile topbar + 意图）
          Positioned(
            top: 14,
            right: 14,
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: context.yucai.accent,
                ),
                child: const Icon(LucideIcons.plus, color: Colors.white, size: 20),
              ),
            ),
          ),
          Padding(
            // .summary padding:18px 20px 17px
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('全部账户余额合计',
                    style: TextStyle(color: context.yucai.muted, fontSize: 12.5)),
                const SizedBox(height: 5),
                Text(
                  _fmtSymbol(netCents, preferred),
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                    color: netCents < 0 ? context.yucai.negative : context.yucai.fg,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
                const SizedBox(height: 9),
                Text.rich(
                  TextSpan(
                    style: TextStyle(fontSize: 12, color: context.yucai.muted),
                    children: [
                      const TextSpan(text: '资产 '),
                      TextSpan(
                          text: _fmtSymbol(assetCents, preferred),
                          style: TextStyle(color: context.yucai.positive)),
                      const TextSpan(text: '   ·   负债 '),
                      TextSpan(
                          text: _fmtSymbol(liabCents, preferred),
                          style: TextStyle(color: context.yucai.negative)),
                    ],
                  ),
                  style: const TextStyle(
                      fontFeatures: AppTypography.tabularFigures),
                ),
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
        Text('净资产合计', style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 6),
        Text(
          _fmtSymbol(netCents, preferred),
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
        Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 5),
        Text(
          _fmtSymbol(cents, preferred),
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
            color: _hover ? context.yucai.accentDeep : context.yucai.accent, // :hover accent-press(#98773f)
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
              Icon(LucideIcons.plus, size: 18, color: Colors.white), // .pl 18 w400
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
    final activeBg = context.yucai.fg; // v2:.chip.active 用前景深底
    final activeBorder = context.yucai.fg;
    final border = widget.selected
        ? activeBorder
        : (_hover ? context.yucai.accent : context.yucai.border); // :not(.active):hover accent
    final bg = widget.selected ? activeBg : context.yucai.surface;
    final fg = widget.selected ? Colors.white : context.yucai.fg;
    // .cnt：非 active muted；active rgba(255,255,255,.55)
    final cntColor =
        widget.selected ? const Color(0x8CFFFFFF) : context.yucai.muted;
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
    required this.onEdit,
    required this.onDuplicate,
    required this.onClose,
    required this.onReactivate,
    required this.onDelete,
  });

  final AccountCategory type;
  final List<Account> accounts;
  final String Function(int, String) formatCents;
  final void Function(Account) onEdit;
  final void Function(Account) onDuplicate;
  final void Function(Account) onClose;
  final void Function(Account) onReactivate;
  final Future<void> Function(Account) onDelete;

  @override
  Widget build(BuildContext context) {
    final cstate = context.watch<CurrencyBloc>().state;
    final subtotal = accounts.fold<int>(
        0,
        (s, a) => s +
            toPreferredCents(
                a.accountType == AccountType.liability
                    ? a.currentBalanceCents
                    : _displayValueCents(a),
                a.currencyCode,
                cstate.rates,
                cstate.preferred));
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
    // 小计金额（已换算到 preferred 货币 + preferred 符号）。
    final subText = _fmtSymbol(subtotal, cstate.preferred);

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
                  style: TextStyle(color: context.yucai.muted, fontSize: gcntSize)),
              const Spacer(),
              // .gsub 小计：换算到 preferred 货币后用 preferred 符号显示。
              if (!isMobile)
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: gsubSize,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures,
                      color: isLiability ? context.yucai.negative : context.yucai.fg,
                    ),
                    children: [
                      TextSpan(
                        text: '小计 ',
                        style: TextStyle(
                            fontSize: 11,
                            color: context.yucai.muted,
                            fontWeight: FontWeight.w400),
                      ),
                      TextSpan(text: subText),
                    ],
                  ),
                )
              else
                // mobile .gsub 无「小计」前缀，直接金额
                Text(
                  subText,
                  style: TextStyle(
                    fontSize: gsubSize,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures,
                    color: isLiability ? context.yucai.negative : context.yucai.fg,
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
            //   tablet 600-1099 → 2 列 GridView，mainAxisExtent 固定高度
            //   desktop >=1100  → auto-fill 280px GridView，同上 mainAxisExtent
            //
            // 高度问题：固定 childAspectRatio 会让高内容卡（cicon row + csub +
            // bar + bar-meta + hover action bar，如信用卡/贷款）底部被裁剪
            //（aspect 依赖 cell width，宽视口算出的高度不足以容纳最高卡片）。
            // 改用 mainAxisExtent 设固定卡片高度（与 cell width 无关），
            // 直接取能容纳最高卡内容（信用卡，含始终渲染的 hover action bar）的值。
            //
            // 内容高度估算（_fullCard 最高 = 信用卡，含 csub+bar+meta+action bar）：
            //   padding 18*2 = 36
            //   cicon row 44
            //   csub 14(margin)+13(padding-top/border)+~17(text) = 44
            //   bar  13(margin)+6 = 19
            //   meta 7(margin)+~15(text) = 22
            //   action bar 13(margin)+11(padding-top)+16(icon)+3+14(text)+2*2(vpad) = 61
            //   合计 ≈ 226px，+10 余量 → mainAxisExtent = 236
            const gap = 14.0;
            // 固定卡片高度（与列数/视口宽无关），覆盖最高卡（信用卡）。
            const cardExtent = 236.0;
            if (constraints.maxWidth < 600) {
              // mobile：Column + SizedBox gap 还原 mainAxisSpacing:14。
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < accounts.length; i++) ...[
                    _AccountCard(
                      account: accounts[i],
                      formatCents: formatCents,
                      onEdit: () => onEdit(accounts[i]),
                      onDuplicate: () => onDuplicate(accounts[i]),
                      onClose: () => onClose(accounts[i]),
                      onReactivate: () => onReactivate(accounts[i]),
                      onDelete: () => onDelete(accounts[i]),
                    ),
                    if (i < accounts.length - 1) const SizedBox(height: gap),
                  ],
                ],
              );
            }
            int cols;
            if (constraints.maxWidth < 1100) {
              cols = 2;
            } else {
              const colWidth = 280.0;
              cols = ((constraints.maxWidth + gap) / (colWidth + gap)).floor();
              if (cols < 1) cols = 1;
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                // 固定卡片高度（与 cell width 无关），确保最高卡（信用卡）
                // 完整显示不裁剪；矮卡（如储蓄）底部留白可接受。
                mainAxisExtent: cardExtent,
              ),
              itemCount: accounts.length,
              itemBuilder: (_, i) => _AccountCard(
                account: accounts[i],
                formatCents: formatCents,
                onEdit: () => onEdit(accounts[i]),
                onDuplicate: () => onDuplicate(accounts[i]),
                onClose: () => onClose(accounts[i]),
                onReactivate: () => onReactivate(accounts[i]),
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

/// 原型 .card / .acc：自承载 hover（MouseRegion + AnimatedContainer）以精确还原
/// translateY(-2px) + box-shadow:0 10px 26px rgba(0,0,0,.07)。
/// 弃用共享 DataCard（其 translateY-1 + border + 不同 shadow 无法 1:1 匹配原型）。
class _AccountCard extends StatefulWidget {
  const _AccountCard({
    required this.account,
    required this.formatCents,
    required this.onEdit,
    required this.onDuplicate,
    required this.onClose,
    required this.onReactivate,
    required this.onDelete,
  });

  final Account account;
  final String Function(int, String) formatCents;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onClose;
  final VoidCallback onReactivate;
  final VoidCallback onDelete;

  @override
  State<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<_AccountCard> {
  bool _hover = false;
  // mobile :active transform:scale(.985) —— 仅 press 期间。
  bool _pressed = false;

  /// 透传 widget.formatCents，使 helper 方法内部沿用原 `formatCents(...)` 调用。
  String Function(int, String) get formatCents => widget.formatCents;

  Account get a => widget.account;

  /// 记一笔/转账：push TransactionFormPage，预选本账户（省去用户在表单里
  /// 重挑账户）。记一笔默认支出 tab；转账直入转账 tab 且本账户作为转出方。
  /// 同 account_detail_page._recordTxn：成功返回后 toast + 重新拉账户列表
  ///（交易可能改变余额）。
  void _recordTxn(BuildContext context, {TxnType? initialType}) {
    Navigator.of(context)
        .push<bool>(MaterialPageRoute(
            builder: (_) => TransactionFormPage(
                  initialAccountId: a.id,
                  initialType: initialType,
                )))
        .then((ok) {
      if (ok == true && context.mounted) {
        AppToast.show(context, '交易已记录', type: ToastType.success);
        // 刷新账户列表（余额/近期交易视图依赖最新数据）。
        context.read<AccountBloc>().add(LoadAccountsRequested());
      }
    });
  }

  /// 长按 → 弹出快捷操作菜单（编辑/记一笔/转账/复制/关闭or激活/删除）。
  /// anchor 必须取本次手势的即时 globalPosition —— 禁用任何跨触发的缓存
  /// 锚点（F5 前用上一次长按的坐标，桌面端点「更多」会飞到旧位置）。
  Future<void> _showQuickMenu(BuildContext context, Offset anchor) async {
    final archived = a.status == AccountStatus.archived;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final selected = await showMenu<String>(
      context: context,
      // 相对 Overlay 的长按全局坐标定位。
      position: RelativeRect.fromLTRB(
        anchor.dx,
        anchor.dy,
        overlay.size.width - anchor.dx,
        overlay.size.height - anchor.dy,
      ),
      items: <PopupMenuEntry<String>>[
        const PopupMenuItem(value: 'edit', child: Text('编辑')),
        const PopupMenuItem(value: 'record', child: Text('记一笔')),
        const PopupMenuItem(value: 'transfer', child: Text('转账')),
        const PopupMenuItem(value: 'duplicate', child: Text('复制')),
        PopupMenuItem(
            value: archived ? 'reactivate' : 'close',
            child: Text(archived ? '重新激活' : '关闭账户')),
        const PopupMenuDivider(),
        PopupMenuItem(
            value: 'delete',
            child: Text('删除账户',
                style: TextStyle(color: context.yucai.negative))),
      ],
    );
    if (!mounted || selected == null) return;
    switch (selected) {
      case 'edit':
        widget.onEdit();
      case 'record':
        _recordTxn(this.context);
      case 'transfer':
        _recordTxn(this.context, initialType: TxnType.transfer);
      case 'duplicate':
        widget.onDuplicate();
      case 'close':
        widget.onClose();
      case 'reactivate':
        widget.onReactivate();
      case 'delete':
        widget.onDelete();
    }
  }

  /// 「更多」按钮的 MenuAnchor 快捷条目（与长按菜单同项，桌面点击路径）。
  List<Widget> _quickMenuItems(BuildContext context) {
    final archived = a.status == AccountStatus.archived;
    return [
      MenuItemButton(
        leadingIcon:
            Icon(LucideIcons.pencil, size: 15, color: context.yucai.muted),
        child: const Text('编辑'),
        onPressed: widget.onEdit,
      ),
      MenuItemButton(
        leadingIcon:
            Icon(LucideIcons.plus, size: 15, color: context.yucai.muted),
        child: const Text('记一笔'),
        onPressed: () => _recordTxn(context),
      ),
      MenuItemButton(
        leadingIcon: Icon(LucideIcons.arrowLeftRight,
            size: 15, color: context.yucai.muted),
        child: const Text('转账'),
        onPressed: () => _recordTxn(context, initialType: TxnType.transfer),
      ),
      MenuItemButton(
        leadingIcon:
            Icon(LucideIcons.copy, size: 15, color: context.yucai.muted),
        child: const Text('复制'),
        onPressed: widget.onDuplicate,
      ),
      MenuItemButton(
        leadingIcon:
            Icon(LucideIcons.archive, size: 15, color: context.yucai.muted),
        child: Text(archived ? '重新激活' : '关闭账户'),
        onPressed: archived ? widget.onReactivate : widget.onClose,
      ),
      const Divider(height: 1),
      MenuItemButton(
        leadingIcon:
            Icon(LucideIcons.trash2, size: 15, color: context.yucai.negative),
        child: Text('删除账户', style: TextStyle(color: context.yucai.negative)),
        onPressed: widget.onDelete,
      ),
    ];
  }

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
        // 长按 → 弹出快捷菜单（含删除）；不再直接删除。
        onLongPressStart: (details) =>
            // 即时 globalPosition 定位（跨触发缓存锚点会飞位，见 F5）。
            _showQuickMenu(context, details.globalPosition),
        onTapDown: (_) => isMobile ? setState(() => _pressed = true) : null,
        onTapUp: (_) => isMobile ? setState(() => _pressed = false) : null,
        onTapCancel: () => isMobile ? setState(() => _pressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140), // .card transition:.14s
          transform: _transformFor(isMobile),
          padding: padding,
          decoration: BoxDecoration(
            color: context.yucai.surface,
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
                              color: context.yucai.muted.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('已归档',
                                style: TextStyle(
                                    color: context.yucai.muted, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3), // .corg margin-top:3
                    Text(
                      _subline(a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.yucai.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8), // .cv padding-left:8
              // Flexible(loose)：窄卡时把 val 限制在分配宽度内（cval ellipsis），
              // 避免裸 Column 溢出；由左侧 Expanded 推到行末，crossAxisAlignment.end
              // 让 cvlabel/cval 在 val 列内靠右（行末）。
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // .cvlabel 11.5 muted
                    Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: context.yucai.muted, fontSize: 11.5)),
                    const SizedBox(height: 2), // .cval margin-top:2
                    // .cval 21 mono w600 tabular
                    Text(
                      val,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                        color: negative ? context.yucai.negative : context.yucai.fg,
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
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.yucai.border)),
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
                backgroundColor: context.yucai.accentSoft,
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
                        ? '已用 ${formatCents(a.currentBalanceCents.abs(), a.currencyCode)} / ${formatCents(a.creditLimitCents, a.currencyCode)}'
                        : '已还 ${formatCents((a.loanOriginalCents ?? 0) - (a.loanRemainingCents ?? 0), a.currencyCode)} / ${formatCents(a.loanOriginalCents ?? 0, a.currencyCode)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.yucai.muted,
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
          // 操作栏贴卡片底部：Spacer 占据剩余高度把操作栏推到最底（对齐原型
          // .ac-actions 位于 .card 底部，而非内容流末尾的留白处）。
          const Spacer(),
          // 快捷操作栏（对齐 accounts.html .ac-actions）：详情/编辑/记账/转账/更多，
          // 始终常驻显示（此前仅 hover 淡入，desktop 不悬停看不到操作入口）。
          _hoverActionBar(context),
        ],
      ),
    );
  }

  /// desktop/tablet 卡片底部快捷操作栏（对齐 prototype .ac-actions）。
  /// 5 个等宽按钮（详情/编辑/记账/转账/更多），始终渲染以保持卡片高度稳定，
  /// 通过 AnimatedOpacity + Transform.translate 实现 hover 时淡入 + 上滑动画。
  /// 非悬停时 IgnorePointer 屏蔽点击（避免误触透明按钮）。
  Widget _hoverActionBar(BuildContext context) {
    // 始终显示在卡片底部（详情/编辑/记账/转账/更多），对齐 OD 原型 .ac-actions。
    // 此前仅 hover 时淡入，desktop 不悬停看不到操作入口，改为常驻可见。
    return Container(
      margin: const EdgeInsets.only(top: 13),
      padding: const EdgeInsets.only(top: 11),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.yucai.border, width: 1.0),
        ),
      ),
      child: Row(
        children: [
          _actionBtn(
            icon: LucideIcons.info,
            label: '详情',
            onTap: () => context.go('/accounts/${a.id}'),
          ),
          _actionBtn(
            icon: LucideIcons.pencil,
            label: '编辑',
            onTap: widget.onEdit,
          ),
          _actionBtn(
            icon: LucideIcons.filePlus,
            label: '记账',
            onTap: () => _recordTxn(context),
          ),
          _actionBtn(
            icon: LucideIcons.arrowLeftRight,
            label: '转账',
            onTap: () => _recordTxn(context, initialType: TxnType.transfer),
          ),
          // 更多：MenuAnchor 锚定按钮本体（自动翻转/钳制窗口内，
          // 不做任何手算坐标 —— F5 前复用长按陈旧锚点导致菜单飞位）。
          Expanded(
            child: MenuAnchor(
              style: yucaiMenuStyle(context),
              menuChildren: _quickMenuItems(context),
              builder: (menuContext, controller, child) => MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.moreHorizontal,
                            size: 16, color: menuContext.yucai.muted),
                        const SizedBox(height: 3),
                        Text('更多',
                            style: TextStyle(
                                color: menuContext.yucai.muted,
                                fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 单个等宽快捷按钮（icon + label，纵向）。
  Widget _actionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isLast = false,
  }) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: context.yucai.muted),
                const SizedBox(height: 3),
                Text(label,
                    style: TextStyle(
                        color: context.yucai.muted, fontSize: 11)),
              ],
            ),
          ),
        ),
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
                              color: context.yucai.muted.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('已归档',
                                style: TextStyle(
                                    color: context.yucai.muted, fontSize: 10)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2), // .aorg margin-top:2
                    Text(
                      _subline(a),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.yucai.muted, fontSize: 11.5),
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
                      style: TextStyle(
                          color: context.yucai.muted, fontSize: 10.5)),
                  const SizedBox(height: 2),
                  // .aval 15 mono w600 tabular
                  Text(
                    val,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: negative ? context.yucai.negative : context.yucai.fg,
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
                backgroundColor: context.yucai.accentSoft,
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
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.yucai.border)),
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
    final label = switch (a.category) {
      AccountCategory.creditCard => '当前欠款',
      AccountCategory.loan => '剩余本金',
      AccountCategory.investment => '当前市值',
      AccountCategory.goldFx => '当前现值',
      AccountCategory.realEstate => '现估值',
      AccountCategory.fixedDeposit => '存单本金',
      AccountCategory.otherAsset => '账户金额',
      AccountCategory.otherLiability => '待还金额',
      AccountCategory.savings => '可用余额',
    };
    // 金额统一取 _displayValueCents（与总计/小计同口径），原货币符号。
    return (label, formatCents(_displayValueCents(a), a.currencyCode));
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
    final style = TextStyle(color: context.yucai.muted, fontSize: 12);
    Color tone(double v) => v >= 0 ? context.yucai.positive : context.yucai.negative;
    String sign(double v) => v >= 0 ? '+' : '';
    switch (a.category) {
      case AccountCategory.creditCard:
        return Text(
          '额度 ${formatCents(a.creditLimitCents, a.currencyCode)} · '
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
        final cur = a.goldCurrentPriceCents ?? 0;
        final buy = a.goldBuyPriceCents ?? 0;
        final pct = buy > 0 ? (cur - buy) / buy * 100 : 0.0;
        return Text(
          '买入 ${formatCents(buy, a.currencyCode)} · 涨幅 ${sign(pct)}${pct.toStringAsFixed(2)}%',
          style: TextStyle(color: tone(pct), fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case AccountCategory.realEstate:
        final cur = a.estateCurrentValueCents ?? 0;
        final buy = a.estatePurchasePriceCents ?? 0;
        final pct = buy > 0 ? (cur - buy) / buy * 100 : 0.0;
        return Text(
          '买入 ${formatCents(buy, a.currencyCode)} · 增值 ${sign(pct)}${pct.toStringAsFixed(2)}%',
          style: TextStyle(color: tone(pct), fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      case AccountCategory.loan:
        return Text(
          '原始 ${formatCents(a.loanOriginalCents ?? 0, a.currencyCode)} · '
          '月供 ${formatCents(a.loanMonthlyCents ?? 0, a.currencyCode)} · '
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

  (double, Color)? _usageSpec(Account a) {
    switch (a.category) {
      case AccountCategory.creditCard:
        if (a.creditLimitCents <= 0) return null;
        final v = (a.currentBalanceCents.abs() / a.creditLimitCents)
            .clamp(0.0, 1.0);
        return (v, context.yucai.negative);
      case AccountCategory.loan:
        final orig = a.loanOriginalCents ?? 0;
        final remain = a.loanRemainingCents ?? 0;
        if (orig <= 0) return null;
        final v = ((orig - remain) / orig).clamp(0.0, 1.0);
        return (v, context.yucai.positive);
      default:
        return null;
    }
  }

  static String _fmtDate(DateTime? d) =>
      d == null ? '-' : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
