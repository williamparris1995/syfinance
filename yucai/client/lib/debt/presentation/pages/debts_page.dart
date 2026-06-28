import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/core/di/injection.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';
import 'package:yucai_client/debt/presentation/pages/debt_form_page.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 债务列表页。对齐 OD 原型：
///  - debts.html        （desktop：三栏概览 + 横向债务卡）
///  - debts-tablet.html （tablet：双列卡片）
///  - debts-mobile.html （mobile：单列堆叠卡 + FAB）
///
/// 布局：总债务概览（_OverviewCard，含整体还清进度 progress bar）
///       → 债务清单区头 → 三端响应式 _DebtCard 列表。
/// 注入：路由层 BlocProvider<DebtBloc>（Task 9）；本页 context.watch<DebtBloc>()。
class DebtsPage extends StatefulWidget {
  const DebtsPage({super.key});

  @override
  State<DebtsPage> createState() => _DebtsPageState();
}

class _DebtsPageState extends State<DebtsPage> {
  // 列表筛选:默认「进行中」(隐藏已结清,对齐 receivables_page)。
  _ListFilter _filter = _ListFilter.active;

  @override
  void initState() {
    super.initState();
    // borrowedIn 过滤:只列借入方向(负债),排除借出方向(债权/应收),
    // 后者归 /receivables 页(对齐 receivables_page 的 borrowedOut 过滤)。
    context
        .read<DebtBloc>()
        .add(const LoadDebtsRequested(typeFilter: DebtType.borrowedIn));
  }

  List<Debt> _debtsOf(DebtState state) {
    if (state is DebtsLoaded) return state.debts;
    if (state is DebtSubmitting) return state.last;
    if (state is DebtError) return state.last;
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // 创建债务 FAB(所有断点,空状态 + 有数据都可创建)。
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/debts/new'),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: BlocBuilder<DebtBloc, DebtState>(
        builder: (context, state) {
          final debts = _debtsOf(state);
          final loading = state is DebtLoading && debts.isEmpty;

          if (loading) return const Center(child: CircularProgressIndicator());
          if (debts.isEmpty) return _emptyState();
          return _content(debts);
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.account_balance_outlined,
                size: 30, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('还没有债务',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('点击右下角「+」或下方按钮创建第一笔债务记录',
              style: TextStyle(color: AppColors.muted, fontSize: 14)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push('/debts/new'),
            icon: const Icon(Icons.add),
            label: const Text('创建债务'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(List<Debt> debts) {
    final cstate = context.watch<CurrencyBloc>().state;
    final preferred = cstate.preferred;

    // 总计换算到 preferred 后累加；Card 剩余本金仍按原货币显示（Debt 实体无
    // currencyCode，统一按 preferred 符号呈现，与 prototype 一致）。
    int toPreferred(int cents) =>
        toPreferredCents(cents, 'CNY', cstate.rates, preferred);

    final totalRemaining = debts.fold<int>(
        0, (s, d) => s + toPreferred(d.remainingPrincipalCents));
    final totalPrincipal = debts.fold<int>(
        0, (s, d) => s + toPreferred(d.totalPrincipalCents));
    final totalRepaid = totalPrincipal - totalRemaining;
    // 整体还清进度 = sum(progressRatio * total)/sum(total) ≡ totalRepaid/totalPrincipal。
    final overallRatio = totalPrincipal > 0
        ? (totalRepaid / totalPrincipal).clamp(0.0, 1.0)
        : 0.0;
    // 下次还款 = min(dueDate)（最早到期的债务）。空列表时为 null。
    final nextPaymentDate = debts.isEmpty
        ? null
        : debts
            .map((d) => d.dueDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);

    // 列表口径:排序(逾期→到期→已结清沉底)+ 筛选。概览仍用全部。
    final filtered = ([...debts]..sort(_compareDebt))
        .where((d) => _matchesListFilter(d, _filter))
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _OverviewCard(
                totalRemaining: totalRemaining,
                totalPrincipal: totalPrincipal,
                totalRepaid: totalRepaid,
                count: debts.length,
                overallRatio: overallRatio,
                preferred: preferred,
                nextPaymentDate: nextPaymentDate,
              ),
              const SizedBox(height: AppSpacing.lg),
              _SectionHead(count: debts.length),
              const SizedBox(height: AppSpacing.sm),
              _ListFilterSegmented(
                filter: _filter,
                activeCount:
                    debts.where((d) => d.remainingPrincipalCents > 0).length,
                settledCount:
                    debts.where((d) => d.remainingPrincipalCents <= 0).length,
                onChanged: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('该筛选下无债务',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                )
              else
                _DebtList(debts: filtered, preferred: preferred),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 总债务概览 ─────────────────────────

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.totalRemaining,
    required this.totalPrincipal,
    required this.totalRepaid,
    required this.count,
    required this.overallRatio,
    required this.preferred,
    this.nextPaymentDate,
  });

  final int totalRemaining; // 总剩余本金（preferred 口径）
  final int totalPrincipal; // 总负债（原始本金合计）
  final int totalRepaid; // 累计已还
  final int count; // 在途债务笔数
  final double overallRatio; // 整体还清进度 0~1
  final String preferred;
  // 下次还款 = min(dueDate)（最早到期的债务到期日）。空列表时为 null → 不渲染。
  // 注：Debt 实体无 per-payment next date（下次还款期在 DebtDetail.schedule），
  // 用 dueDate 近似；标 label「下次还款」与 brief 对齐（最早到期日）。
  final DateTime? nextPaymentDate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) =>
          c.maxWidth < 600 ? _mobile(context) : _desktop(context),
    );
  }

  /// desktop/tablet 三栏概览（对齐 debts.html .overview）。
  Widget _desktop(BuildContext context) {
    final pct = (overallRatio * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A1C1E21), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance, size: 14, color: AppColors.accent),
              SizedBox(width: 7),
              Text('DEBT OVERVIEW · 总债务概览',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('总负债',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF54585F),
                  fontFamily: AppTypography.displayFamily,
                  fontFamilyFallback: AppTypography.displayFallback)),
          const SizedBox(height: 4),
          Text(
            _fmtSymbol(totalPrincipal, preferred),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 22,
            runSpacing: 4,
            children: [
              _kv('总剩余本金', _fmtSymbol(totalRemaining, preferred)),
              _kv('累计已还', _fmtSymbol(totalRepaid, preferred)),
              _kv('在途债务', '$count 笔'),
              if (nextPaymentDate != null)
                _kv('下次还款', _fmtDate(nextPaymentDate!)),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('整体还清进度',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
              Text('$pct%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentHover,
                      fontFeatures: AppTypography.tabularFigures)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: overallRatio,
              minHeight: 9,
              backgroundColor: const Color(0xFFE9E5DB),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  /// mobile 紧凑概览（对齐 debts-mobile.html .overview）。
  Widget _mobile(BuildContext context) {
    final pct = (overallRatio * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance, size: 14, color: AppColors.accent),
              SizedBox(width: 7),
              Text('总债务概览',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('总负债',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF54585F),
                  fontFamily: AppTypography.displayFamily,
                  fontFamilyFallback: AppTypography.displayFallback)),
          const SizedBox(height: 4),
          Text(
            _fmtSymbol(totalPrincipal, preferred),
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 22,
            runSpacing: 4,
            children: [
              _kv('剩余', _fmtSymbol(totalRemaining, preferred)),
              _kv('已还', _fmtSymbol(totalRepaid, preferred)),
              if (nextPaymentDate != null)
                _kv('下次还款', _fmtDate(nextPaymentDate!)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('整体还清 · $count 笔在途',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.muted)),
              Text('$pct%',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentHover,
                      fontFeatures: AppTypography.tabularFigures)),
            ],
          ),
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              value: overallRatio,
              minHeight: 9,
              backgroundColor: const Color(0xFFE9E5DB),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
        children: [
          TextSpan(text: '$k '),
          TextSpan(
              text: v,
              style: const TextStyle(
                  color: AppColors.fg,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

// ───────────────────────── 区头 ─────────────────────────

class _SectionHead extends StatelessWidget {
  const _SectionHead({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('债务清单',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback)),
        const SizedBox(width: 6),
        Text('$count 笔',
            style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.muted,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }
}

// ───────────────────────── 债务列表（三端响应式） ─────────────────────────

class _DebtList extends StatelessWidget {
  const _DebtList({required this.debts, required this.preferred});
  final List<Debt> debts;
  final String preferred;

  @override
  Widget build(BuildContext context) {
    // mobile 单列 Column / tablet 2 列 / desktop auto-fill(≥3) GridView，
    // 对齐 accounts_page._GroupBlock 的三断点模式（基于容器宽度）。
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 14.0;
        if (c.maxWidth < Breakpoints.mobileUpper) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < debts.length; i++) ...[
                _DebtCard(debt: debts[i], preferred: preferred),
                if (i < debts.length - 1) const SizedBox(height: gap),
              ],
            ],
          );
        }
        int cols;
        if (c.maxWidth < Breakpoints.desktopLower) {
          cols = 2;
        } else {
          const colWidth = 280.0;
          cols = ((c.maxWidth + gap) / (colWidth + gap)).floor();
          if (cols < 1) cols = 1;
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            // 固定卡片高度（与内容宽无关），覆盖最高卡（counterparty + mid +
            // progress + meta + actions）。到期 yyyy-MM-dd 比 yyyy-M 略宽 → 348。
            mainAxisExtent: 348,
          ),
          itemCount: debts.length,
          itemBuilder: (_, i) =>
              _DebtCard(debt: debts[i], preferred: preferred),
        );
      },
    );
  }
}

// ───────────────────────── 债务卡 ─────────────────────────

/// 单张债务卡。对齐 prototype .debt-card / .card.debt-card：
///  - row1：counterparty + 类型 badge
///  - meta：利率 + 到期 + 摊还方式
///  - mid：剩余本金（大字 mono）+ 已还进度 progress bar（金色已还 + 灰底）
///  - actions：记账 / 详情 / 更多
class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.debt, required this.preferred});
  final Debt debt;
  final String preferred;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= Breakpoints.mobileUpper;
    return isMobile ? _compactCard(context) : _fullCard(context);
  }

  Widget _fullCard(BuildContext context) {
    final badge = _inferBadge(debt.counterparty);
    final isOverdue = debt.dueDate.isBefore(DateTime.now());
    // 无 DataCard.onTap：操作栏按钮（详情/记账）负责导航，避免外层
    // GestureDetector 吞掉内层 _ActionBtn 的 tap（对齐 account card 模式 ——
    // account card 仅靠 _hoverActionBar 按钮跳转，card 本身不整体可点）。
    return DataCard(
      onTap: () => context.push('/debts/${debt.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // row1：counterparty + badge（+ 逾期红 badge）
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(debt.counterparty,
                  style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              _Badge(label: badge.label, fg: badge.fg, bg: badge.bg),
              if (isOverdue)
                const _Badge(
                    label: '逾期',
                    fg: AppColors.negative,
                    bg: Color(0x1AC4544D) // rgba(196,84,77,.10)
                    ),
            ],
          ),
          const SizedBox(height: 9),
          // mid：剩余本金 + 进度
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('剩余本金',
                        style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.5,
                            color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text(
                      _fmtSymbol(debt.remainingPrincipalCents, preferred),
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          _ProgressRow(ratio: debt.progressRatio),
          const SizedBox(height: 10),
          // meta：利率 / 到期 / 摊还
          Wrap(
            spacing: 14,
            runSpacing: 5,
            children: [
              _MetaItem(
                  icon: Icons.percent,
                  text: '${debt.interestRate.toStringAsFixed(2)}%'),
              _MetaItem(
                  icon: Icons.event_outlined,
                  text: '到期 ${_fmtDate(debt.dueDate)}'),
              _MetaItem(
                  icon: Icons.show_chart,
                  text: _amortLabel(debt.amortization)),
            ],
          ),
          // Spacer 占据剩余高度，把操作栏推到卡片底部（对齐 account card
          // _fullCard 的 const Spacer() + _hoverActionBar 模式）。GridView
          // mainAxisExtent 固定卡高时，矮卡中部内容上方留白而非底部。
          const Spacer(),
          _actionBar(debt, context),
        ],
      ),
    );
  }

  /// mobile 紧凑卡（对齐 debts-mobile.html .card.debt-card）。
  Widget _compactCard(BuildContext context) {
    final badge = _inferBadge(debt.counterparty);
    final isOverdue = debt.dueDate.isBefore(DateTime.now());
    // 无 DataCard.onTap（同 _fullCard）：操作栏按钮负责导航，避免吞 tap。
    // mobile 列表用 Column 自适应高度，无 Spacer（unbounded 高度下 Spacer 报错）。
    return DataCard(
      onTap: () => context.push('/debts/${debt.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(debt.counterparty,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                fontFamily: AppTypography.displayFamily,
                                fontFamilyFallback:
                                    AppTypography.displayFallback)),
                        _Badge(label: badge.label, fg: badge.fg, bg: badge.bg),
                        if (isOverdue)
                          const _Badge(
                              label: '逾期',
                              fg: AppColors.negative,
                              bg: Color(0x1AC4544D) // rgba(196,84,77,.10)
                              ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_amortLabel(debt.amortization)} · ${debt.interestRate.toStringAsFixed(2)}%',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('剩余本金',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    _fmtSymbol(debt.remainingPrincipalCents, preferred),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          _ProgressRow(ratio: debt.progressRatio, thin: false),
          const SizedBox(height: 8),
          Row(
            children: [
              _MetaItem(
                  icon: Icons.event_outlined,
                  text: '到期 ${_fmtDate(debt.dueDate)}'),
            ],
          ),
          const SizedBox(height: 10),
          _actionBar(debt, context),
        ],
      ),
    );
  }

  /// 卡片底部操作栏：详情 / 更多。
  /// - 详情 → 跳详情页（记账在详情页 schedule 行内 —— 列表 DebtDTO 不知哪期）。
  /// - 更多 → PopupMenuButton<String>（Flutter 自动贴按钮定位，无需手算
  ///   findRenderObject 坐标；对齐 account card _hoverActionBar 的更多按钮模式）。
  ///   items：编辑 / 删除（占位，暂仅 toast 提示）。
  Widget _actionBar(Debt debt, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 11),
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border, width: 1.0)),
      ),
      child: Row(
        children: [
          _ActionBtn(
            icon: Icons.info_outline,
            label: '详情',
            onTap: (_) => context.push('/debts/${debt.id}'),
          ),
          _ActionBtn(
            icon: Icons.edit_outlined,
            label: '编辑',
            onTap: (_) => Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => BlocProvider<DebtBloc>(
                  // push 的 route tree 独立,不继承 /debts BlocProvider,需自带。
                  create: (_) => DebtBloc(getIt<DebtRepository>()),
                  child: DebtFormPage(existing: debt),
                ),
              ),
            ),
          ),
          _ActionBtn(
            icon: Icons.delete_outline,
            label: '删除',
            onTap: (_) async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dctx) => AlertDialog(
                  title: const Text('删除债务'),
                  content: Text(
                      '确定删除「${debt.counterparty}」?此操作不可撤销。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(dctx, false),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () => Navigator.pop(dctx, true),
                        child: const Text('删除',
                            style:
                                TextStyle(color: AppColors.negative))),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                context.read<DebtBloc>().add(DeleteDebtRequested(debt.id));
              }
            },
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 卡内小组件 ─────────────────────────

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.ratio, this.thin = true});
  final double ratio;
  final bool thin;

  @override
  Widget build(BuildContext context) {
    final pct = (ratio * 100).toStringAsFixed(1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('已还进度',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            Text('$pct%',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentHover,
                    fontFeatures: AppTypography.tabularFigures)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(9999),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: thin ? 6 : 9,
            backgroundColor: const Color(0xFFE9E5DB),
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.muted,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final ValueChanged<BuildContext>? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap == null ? null : () => onTap!(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: AppColors.muted),
                const SizedBox(height: 3),
                Text(label,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 11)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 类型 badge（简化：counterparty 关键字推断） ─────────────────────────

class _BadgeStyle {
  const _BadgeStyle({required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg;
  final Color bg;
}

/// 从 counterparty 关键字推断类型 badge（房贷/车贷/信用卡/亲友借款/借款）。
/// 简化策略：Debt 实体不带 category，只能从文案推。Task 7 表单可显式选择类型。
_BadgeStyle _inferBadge(String counterparty) {
  final s = counterparty.toLowerCase();
  if (counterparty.contains('房') || s.contains('mortgage')) {
    return const _BadgeStyle(
        label: '房贷', fg: AppColors.accentHover, bg: AppColors.accentSoft);
  }
  if (counterparty.contains('车') || s.contains('car')) {
    return const _BadgeStyle(
        label: '车贷', fg: Color(0xFF56606B), bg: Color(0xFFEEF0F2));
  }
  if (counterparty.contains('信用卡') || s.contains('credit')) {
    return const _BadgeStyle(
        label: '信用卡',
        fg: AppColors.negative,
        bg: Color(0x1AC4544D) // rgba(196,84,77,.10)
        );
  }
  if (counterparty.contains('亲友') ||
      counterparty.contains('借') ||
      s.contains('friend')) {
    return const _BadgeStyle(
        label: '亲友借款',
        fg: AppColors.positive,
        bg: Color(0x1A2D8A6E) // rgba(45,138,110,.10)
        );
  }
  return const _BadgeStyle(
      label: '借款', fg: AppColors.accentHover, bg: AppColors.accentSoft);
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ───────────────────────── helpers ─────────────────────────

String _amortLabel(AmortizationMethod m) {
  switch (m) {
    case AmortizationMethod.equalPrincipalInterest:
      return '等额本息';
    case AmortizationMethod.equalPrincipal:
      return '等额本金';
    case AmortizationMethod.lumpSum:
      return '一次性归还';
  }
}

/// YYYY-MM-DD 完整日期格式（对齐 brief「下次还款 / 到期 2051-06-01」）。
String _fmtDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// 千分位 + 两位小数 + 货币符号前缀。对齐 accounts_page._fmtSymbol。
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

// ───────────────────────── 列表筛选(全部/进行中/已结清)+ 排序 ─────────────────────────

/// 列表筛选:默认「进行中」(隐藏已结清)。对齐 receivables_page._ListFilter。
enum _ListFilter { all, active, settled }

/// 列表排序:未结清在前(按到期升序 —— 逾期因 dueDate 早自然靠前),已结清沉底。
int _compareDebt(Debt a, Debt b) {
  final aSettled = a.remainingPrincipalCents <= 0;
  final bSettled = b.remainingPrincipalCents <= 0;
  if (aSettled != bSettled) return aSettled ? 1 : -1;
  return a.dueDate.compareTo(b.dueDate);
}

bool _matchesListFilter(Debt d, _ListFilter f) {
  final settled = d.remainingPrincipalCents <= 0;
  switch (f) {
    case _ListFilter.all:
      return true;
    case _ListFilter.active:
      return !settled;
    case _ListFilter.settled:
      return settled;
  }
}

/// 列表筛选 segmented(全部/进行中/已结清 + 各自计数)。复用详情页 schedule 筛选样式。
class _ListFilterSegmented extends StatelessWidget {
  const _ListFilterSegmented({
    required this.filter,
    required this.activeCount,
    required this.settledCount,
    required this.onChanged,
  });
  final _ListFilter filter;
  final int activeCount;
  final int settledCount;
  final ValueChanged<_ListFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const segments = [
      (_ListFilter.all, '全部'),
      (_ListFilter.active, '进行中'),
      (_ListFilter.settled, '已结清'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFECE5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (f, label) in segments) _segment(f, label),
        ],
      ),
    );
  }

  Widget _segment(_ListFilter f, String label) {
    final active = f == filter;
    final count = switch (f) {
      _ListFilter.active => activeCount,
      _ListFilter.settled => settledCount,
      _ListFilter.all => activeCount + settledCount,
    };
    return InkWell(
      key: ValueKey('listFilter-$label'),
      onTap: () => onChanged(f),
      borderRadius: BorderRadius.circular(7),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: active
              ? const [
                  BoxShadow(
                      color: Color(0x0F1C1E21),
                      blurRadius: 3,
                      offset: Offset(0, 1))
                ]
              : const [],
        ),
        child: Text(
          '$label $count',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.accentHover : const Color(0xFF54585F),
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ),
    );
  }
}
