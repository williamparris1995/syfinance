import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';
import 'package:yucai_client/debt/domain/repositories/receivables_summary_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 债权列表页(别人欠我 / 应收)。结构对齐 [DebtsPage],语义换成 BorrowedOut:
///  - OD 原型 receivables.html / receivables-tablet.html / receivables-mobile.html
///  - Bloc 以 `LoadDebtsRequested(typeFilter: DebtType.borrowedOut)` 仅取债权。
///  - Label:「应收 / 收款 / 总应收 / 剩余应收 / 收回进度」(非 负债/还款)。
///
/// 布局:总应收概览(_OverviewCard,含本金收回进度 progress bar)
///       → 债权清单区头 → 三端响应式 _ReceivableCard 列表。
/// 注入:路由层 BlocProvider<DebtBloc>(Task 10);本页 context.watch<DebtBloc>()。
class ReceivablesPage extends StatefulWidget {
  const ReceivablesPage({super.key});

  @override
  State<ReceivablesPage> createState() => _ReceivablesPageState();
}

class _ReceivablesPageState extends State<ReceivablesPage> {
  // 列表筛选:默认「进行中」(隐藏已结清,对齐行业实践——已结清属历史,不占主列表)。
  _ListFilter _filter = _ListFilter.active;
  // 应收汇总(server 端 Task 7 算,nextPayment* / trend / overdue 等)。
  // null = 加载中 / 失败;stat strip/trend 显 loading/—(不阻塞列表)。
  ReceivablesSummary? _summary;

  @override
  void initState() {
    super.initState();
    // 仅取债权(借出 / 应收)。typeFilter 是 Task 1-6 已贯通的端到端通路。
    context
        .read<DebtBloc>()
        .add(const LoadDebtsRequested(typeFilter: DebtType.borrowedOut));
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final repo = getIt<ReceivablesSummaryRepository>();
    final result = await repo.fetch();
    if (!mounted) return;
    result.fold((_) => null, (s) => setState(() => _summary = s));
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
      // 创建债权 FAB(所有断点,空状态 + 有数据都可创建)。
      // 路由 /receivables/new 由 Task 10 接入;此处仅字符串引用,编译无依赖。
      // heroTag: null 禁 Hero —— indexedStack 保活多 branch 时避免与其它 branch
      // FAB 共用默认 Hero tag 冲突(参见 fab-hero-fix)。
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => context.push('/receivables/new'),
        backgroundColor: AppColors.accent,
        child: const Icon(LucideIcons.plus, color: Colors.white),
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
            child: const Icon(LucideIcons.handshake,
                size: 30, color: AppColors.accent),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text('还没有债权',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const Text('点击右下角「+」或下方按钮记录第一笔借出款项',
              style: TextStyle(color: AppColors.muted, fontSize: 14)),
          const SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: () => context.push('/receivables/new'),
            icon: const Icon(LucideIcons.plus),
            label: const Text('创建债权'),
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

    // 总计换算到 preferred 后累加;Card 剩余应收仍按原货币显示(Debt 实体无
    // currencyCode,统一按 preferred 符号呈现,与 prototype 一致)。
    int toPreferred(int cents) =>
        toPreferredCents(cents, 'CNY', cstate.rates, preferred);

    final totalRemaining = debts.fold<int>(
        0, (s, d) => s + toPreferred(d.remainingPrincipalCents));
    final totalPrincipal = debts.fold<int>(
        0, (s, d) => s + toPreferred(d.totalPrincipalCents));
    final totalCollected = totalPrincipal - totalRemaining;
    // 本金收回进度 = totalCollected / totalPrincipal(对齐 OD「本金收回进度」)。
    final overallRatio = totalPrincipal > 0
        ? (totalCollected / totalPrincipal).clamp(0.0, 1.0)
        : 0.0;
    // 下次收款 = min(dueDate)(最早到期的债权)。空列表时为 null。
    final nextCollectDate = debts.isEmpty
        ? null
        : debts
            .map((d) => d.dueDate)
            .reduce((a, b) => a.isBefore(b) ? a : b);

    // 列表口径:排序(逾期→到期→已结清沉底)+ 筛选。概览仍用全部(总应收是历史全貌)。
    final filtered = ([...debts]..sort(_compareReceivable))
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
                totalCollected: totalCollected,
                count: debts.length,
                overallRatio: overallRatio,
                preferred: preferred,
                nextCollectDate: nextCollectDate,
                summary: _summary,
              ),
              const SizedBox(height: AppSpacing.md),
              // L2: stat strip(summary 驱动)。null → loading 占位,不阻塞列表。
              _StatStrip(summary: _summary, preferred: preferred),
              const SizedBox(height: AppSpacing.lg),
              _SectionHead(count: debts.length),
              const SizedBox(height: AppSpacing.sm),
              _ListFilterSegmented(
                filter: _filter,
                activeCount:
                    debts.where((d) => d.remainingPrincipalCents > 0).length,
                settledCount:
                    debts.where((d) => d.remainingPrincipalCents <= 0).length,
                overdueCount: debts
                    .where((d) =>
                        d.remainingPrincipalCents > 0 &&
                        d.dueDate.isBefore(DateTime.now()))
                    .length,
                onChanged: (f) => setState(() => _filter = f),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('该筛选下无债权',
                        style:
                            TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                )
              else
                _ReceivableList(debts: filtered, preferred: preferred),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 总应收概览 ─────────────────────────

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.totalRemaining,
    required this.totalPrincipal,
    required this.totalCollected,
    required this.count,
    required this.overallRatio,
    required this.preferred,
    this.nextCollectDate,
    this.summary,
  });

  final int totalRemaining; // 总剩余应收(preferred 口径)
  final int totalPrincipal; // 总借出本金(原始本金合计)
  final int totalCollected; // 累计已收
  final int count; // 在追债权笔数
  final double overallRatio; // 本金收回进度 0~1
  final String preferred;
  // 下次收款 = min(dueDate)(最早到期的债权到期日)。空列表时为 null → 不渲染。
  // 注:Debt 实体无 per-payment next date(下次收款期在 DebtDetail.schedule),
  // 用 dueDate 近似;标 label「下次收款」与 brief 对齐(最早到期日)。
  final DateTime? nextCollectDate;
  // L4 summary(server-side 计算的 trend / 待收利息 / 下次收款精确字段)。
  // null = 加载中,相关区块显占位;列表与基础 overview 不依赖它。
  final ReceivablesSummary? summary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, c) =>
          c.maxWidth < 600 ? _mobile(context) : _desktop(context),
    );
  }

  /// desktop/tablet 三栏概览(对齐 receivables.html .ov)。
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
              Icon(LucideIcons.handshake, size: 14, color: AppColors.accent),
              SizedBox(width: 7),
              Text('RECEIVABLES OVERVIEW · 债权总览',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.5,
                      color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('总应收',
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
              _kv('剩余应收', _fmtSymbol(totalRemaining, preferred)),
              _kv('累计已收', _fmtSymbol(totalCollected, preferred)),
              _kv('在追债权', '$count 笔'),
              if (nextCollectDate != null)
                _kv('下次收款', _fmtDate(nextCollectDate!)),
              // L4 trend(较上月本金变化)。null/0 时不渲染。
              if (summary != null && summary!.principalTrendCents != 0)
                _trendKv('较上月', summary!.principalTrendCents, preferred),
            ],
          ),
          const SizedBox(height: 6),
          // L4 breakdown:剩余应收下「含待收利息 ¥X」。null → 不渲染。
          if (summary != null && summary!.pendingInterestCents > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '含待收利息 ${_fmtSymbol(summary!.pendingInterestCents, preferred)}',
                style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
                    fontFeatures: AppTypography.tabularFigures),
              ),
            ),
          const SizedBox(height: 14),
          // L4 foot callout:下次收款精确字段(summary 驱动,带对方/期数/金额 + CTA)。
          if (summary != null && summary!.nextPaymentDate != null)
            _NextCollectCallout(summary: summary!, preferred: preferred),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('本金收回进度',
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

  /// mobile 紧凑概览(对齐 receivables-mobile.html .ov)。
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
              Icon(LucideIcons.handshake, size: 14, color: AppColors.accent),
              SizedBox(width: 7),
              Text('债权总览',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('总应收',
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
              _kv('已收', _fmtSymbol(totalCollected, preferred)),
              if (nextCollectDate != null)
                _kv('下次收款', _fmtDate(nextCollectDate!)),
              if (summary != null && summary!.principalTrendCents != 0)
                _trendKv('较上月', summary!.principalTrendCents, preferred),
            ],
          ),
          const SizedBox(height: 6),
          if (summary != null && summary!.pendingInterestCents > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '含待收利息 ${_fmtSymbol(summary!.pendingInterestCents, preferred)}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.muted,
                    fontFeatures: AppTypography.tabularFigures),
              ),
            ),
          const SizedBox(height: 10),
          if (summary != null && summary!.nextPaymentDate != null)
            _NextCollectCallout(summary: summary!, preferred: preferred),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('本金收回 · $count 笔在追',
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

  /// L4 trend kv:正绿负红 + 显式 +/- 符号。brief「较上月」(本金趋势)。
  Widget _trendKv(String k, int cents, String preferred) {
    final isUp = cents > 0;
    final color =
        isUp ? AppColors.positive : const Color(0xFFC4544D);
    final v = _fmtSymbol(cents, preferred);
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, color: AppColors.muted),
        children: [
          TextSpan(text: '$k '),
          TextSpan(
              text: v,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

/// L4 foot callout:下次收款精确字段(对方 + 期数 + 金额 + CTA「查看收款计划」)。
/// summary 驱动(nextPaymentDate/Amount/Counterparty/PeriodNo)。
class _NextCollectCallout extends StatelessWidget {
  const _NextCollectCallout({required this.summary, required this.preferred});
  final ReceivablesSummary summary;
  final String preferred;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4ED),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFFE9E2D2), width: 1),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.calendarClock,
              size: 16, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '下次收款 · 第 ${summary.nextPaymentPeriodNo} 期',
                  style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.fg,
                        fontFeatures: AppTypography.tabularFigures),
                    children: [
                      TextSpan(
                          text:
                              '${_fmtDate(summary.nextPaymentDate!)} · ${summary.nextPaymentCounterparty} · '),
                      TextSpan(
                          text: _fmtSymbol(
                              summary.nextPaymentAmountCents, preferred),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentHover)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // CTA → push detail(Task 10 接路由)。targetId 取 nextPaymentCounterparty
          // 无对应 id,故 CTA 仅占位文本按钮;真正的「查看收款计划」在详情页 schedule。
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentHover,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('查看收款计划',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── L2 stat strip(4-card) ─────────────────────────

/// L2:4-card stat strip(对齐 OD .stats-row)。summary 驱动;null → loading 占位。
/// - 笔数 / 已收本息(绿) / 待收利息 / 逾期应收(红 + 笔数)
class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.summary, required this.preferred});
  final ReceivablesSummary? summary;
  final String preferred;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      // loading:占位 —(不阻塞列表;高度对齐真实卡避免抖动)。
      return LayoutBuilder(
        builder: (ctx, c) => _grid(const [
          _StatCard('债权笔数', '—'),
          _StatCard('已收本息', '—'),
          _StatCard('待收利息', '—'),
          _StatCard('逾期应收', '—'),
        ], c.maxWidth),
      );
    }
    final s = summary!;
    return LayoutBuilder(
      builder: (ctx, c) => _grid([
        _StatCard('债权笔数', '${s.count}', sub: '私人·商业·亲友'),
        _StatCard('已收本息', _fmtSymbol(s.totalCollectedCents, preferred),
            color: AppColors.positive),
        _StatCard('待收利息', _fmtSymbol(s.pendingInterestCents, preferred)),
        _StatCard('逾期应收', _fmtSymbol(s.overdueAmountCents, preferred),
            color: AppColors.negative, sub: '${s.overdueCount} 笔'),
      ], c.maxWidth),
    );
  }

  Widget _grid(List<Widget> cards, double maxWidth) {
    // 4 卡始终并排(Row + Expanded 自适应宽度);mobile 上每卡略窄但仍可读。
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i < cards.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

/// 单张 stat 卡(对齐 OD .stat)。label / value(大字 mono)/ sub(可选小字)。
class _StatCard extends StatelessWidget {
  const _StatCard(this.label, this.value, {this.color, this.sub});
  final String label;
  final String value;
  final Color? color;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.4,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color ?? AppColors.fg,
              letterSpacing: -0.1,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 3),
            Text(sub!,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.muted)),
          ],
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
        const Text('债权明细',
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

// ───────────────────────── 债权列表(三端响应式) ─────────────────────────

class _ReceivableList extends StatelessWidget {
  const _ReceivableList({required this.debts, required this.preferred});
  final List<Debt> debts;
  final String preferred;

  @override
  Widget build(BuildContext context) {
    // mobile 单列 Column / tablet 2 列 / desktop auto-fill(≥3) GridView,
    // 对齐 debts_page._DebtList 的三断点模式(基于容器宽度)。
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 14.0;
        if (c.maxWidth < Breakpoints.mobileUpper) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < debts.length; i++) ...[
                _ReceivableCard(debt: debts[i], preferred: preferred),
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
            // 固定卡片高度。窄卡含 avatar+name / 剩余应收 / 进度 / meta3(Wrap 窄卡换行)
            // / foot callout / actions(L1 + L3 增容 + meta 换行余量)→ 440。
            mainAxisExtent: 440,
          ),
          itemCount: debts.length,
          itemBuilder: (_, i) =>
              _ReceivableCard(debt: debts[i], preferred: preferred),
        );
      },
    );
  }
}

// ───────────────────────── 债权卡 ─────────────────────────

/// 单张债权卡。对齐 prototype .rcv / debts_page._DebtCard 结构:
///  - row1:债务人(counterparty)+ 类型 badge(+ 逾期红 badge)
///  - mid:剩余应收(大字 mono)+ 收回进度 progress bar(金色已收 + 灰底)
///  - meta:利率 + 到期 + 摊还方式
///  - actions:详情 / 收款 / 更多(占位)
class _ReceivableCard extends StatelessWidget {
  const _ReceivableCard({required this.debt, required this.preferred});
  final Debt debt;
  final String preferred;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width <= Breakpoints.mobileUpper;
    final isSettled = debt.remainingPrincipalCents <= 0;
    // 卡片自宽选布局:mobile 屏 → 紧凑;宽卡(单列 desktop / tablet 双列)→ 横向 row;
    // 窄卡(≥3 列 desktop grid,单卡 < ~560px)→ 竖向 full(避免横向 row 溢出)。
    final Widget card;
    if (isMobile) {
      card = _compactCard(context);
    } else {
      card = LayoutBuilder(
        builder: (ctx, c) =>
            c.maxWidth >= 560 ? _fullCard(context) : _narrowFullCard(context),
      );
    }
    // 已结清债权整卡淡化,突出"已完成"特殊状态。
    return isSettled ? Opacity(opacity: 0.6, child: card) : card;
  }

  /// desktop/tablet 宽卡(单列或 2 列):L3 横向 4-col row。
  Widget _fullCard(BuildContext context) {
    final badge = _badgeFor(debt);
    final isOverdue = debt.dueDate.isBefore(DateTime.now());
    final isSettled = debt.remainingPrincipalCents <= 0;
    // L3 foot:下次收款(debt.nextPaymentDate 驱动;非空才渲染)。
    final hasNext = debt.nextPaymentDate != null &&
        !isSettled &&
        debt.nextPaymentAmountCents > 0;
    return DataCard(
      onTap: () => context.push('/receivables/${debt.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // L3 横向 4-col row:col1 avatar+name+badge | col2 剩余应收大字 |
          // col3 收回进度+已收 | col4 meta2(利率/到期/摊还)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // col1: avatar + name + badge(+ 已结清/逾期)
              Expanded(
                flex: 3,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // L1: 44px avatar tile(首字 + 类型色)。
                    _ReceivableAvatar(
                      initial: debt.counterparty.characters.isEmpty
                          ? '?'
                          : debt.counterparty.characters.first,
                      color: _avatarColorFor(debt),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(debt.counterparty,
                              style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: AppTypography.displayFamily,
                                  fontFamilyFallback:
                                      AppTypography.displayFallback)),
                          const SizedBox(height: 5),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _Badge(
                                  label: badge.label,
                                  fg: badge.fg,
                                  bg: badge.bg),
                              if (isSettled)
                                const _Badge(
                                    label: '已结清 ✓',
                                    fg: AppColors.positive,
                                    bg: Color(0x1A2D8A6E))
                              else if (isOverdue)
                                const _Badge(
                                    label: '逾期',
                                    fg: AppColors.negative,
                                    bg: Color(0x1AC4544D)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // col2: 剩余应收大字。
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('剩余应收',
                        style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.5,
                            color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text(
                      _fmtSymbol(debt.remainingPrincipalCents, preferred),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.15,
                        fontFeatures: AppTypography.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // col3: 收回进度 + 已收金额。
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProgressRow(ratio: debt.progressRatio, thin: true),
                    const SizedBox(height: 6),
                    Text(
                      '已收 ${_fmtSymbol(debt.totalPrincipalCents - debt.remainingPrincipalCents, preferred)}',
                      style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColors.muted,
                          fontFeatures: AppTypography.tabularFigures),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // col4: meta2 利率 / 到期 / 摊还。
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetaItem(
                        icon: LucideIcons.percent,
                        text: '${debt.interestRate.toStringAsFixed(2)}%'),
                    const SizedBox(height: 5),
                    _MetaItem(
                        icon: LucideIcons.calendar,
                        text: '到期 ${_fmtDate(debt.dueDate)}'),
                    const SizedBox(height: 5),
                    _MetaItem(
                        icon: LucideIcons.lineChart,
                        text: _amortLabel(debt.amortization)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // L3 foot callout:下次收款(debt.nextPayment*)+ 逾期天数 + 收款 CTA。
          if (hasNext || isOverdue && !isSettled) ...[
            _CardFootCallout(
              debt: debt,
              preferred: preferred,
              hasNext: hasNext,
              isOverdue: isOverdue,
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          _actionBar(debt, context),
        ],
      ),
    );
  }

  /// desktop ≥3 列 grid 窄卡:竖向 avatar+name+badge → 剩余应收 → 进度 → meta → foot。
  /// (横向 4-col row 在窄卡溢出,故竖向 fallback。仍含 L1 avatar + L3 foot callout。)
  Widget _narrowFullCard(BuildContext context) {
    final badge = _badgeFor(debt);
    final isOverdue = debt.dueDate.isBefore(DateTime.now());
    final isSettled = debt.remainingPrincipalCents <= 0;
    final hasNext = debt.nextPaymentDate != null &&
        !isSettled &&
        debt.nextPaymentAmountCents > 0;
    return DataCard(
      onTap: () => context.push('/receivables/${debt.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ReceivableAvatar(
                initial: debt.counterparty.characters.isEmpty
                    ? '?'
                    : debt.counterparty.characters.first,
                color: _avatarColorFor(debt),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(debt.counterparty,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppTypography.displayFamily,
                            fontFamilyFallback:
                                AppTypography.displayFallback)),
                    const SizedBox(height: 5),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _Badge(
                            label: badge.label, fg: badge.fg, bg: badge.bg),
                        if (isSettled)
                          const _Badge(
                              label: '已结清 ✓',
                              fg: AppColors.positive,
                              bg: Color(0x1A2D8A6E))
                        else if (isOverdue)
                          const _Badge(
                              label: '逾期',
                              fg: AppColors.negative,
                              bg: Color(0x1AC4544D)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text('剩余应收',
              style: TextStyle(
                  fontSize: 10.5, letterSpacing: 0.5, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(
            _fmtSymbol(debt.remainingPrincipalCents, preferred),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.15,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 9),
          _ProgressRow(ratio: debt.progressRatio),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 5,
            children: [
              _MetaItem(
                  icon: LucideIcons.percent,
                  text: '${debt.interestRate.toStringAsFixed(2)}%'),
              _MetaItem(
                  icon: LucideIcons.calendar,
                  text: '到期 ${_fmtDate(debt.dueDate)}'),
              _MetaItem(
                  icon: LucideIcons.lineChart,
                  text: _amortLabel(debt.amortization)),
            ],
          ),
          if (hasNext || isOverdue && !isSettled) ...[
            const SizedBox(height: 10),
            _CardFootCallout(
              debt: debt,
              preferred: preferred,
              hasNext: hasNext,
              isOverdue: isOverdue,
            ),
          ],
          const Spacer(),
          _actionBar(debt, context),
        ],
      ),
    );
  }

  /// mobile 紧凑卡(对齐 receivables-mobile.html .rcv;L1 加 avatar)。
  Widget _compactCard(BuildContext context) {
    final badge = _badgeFor(debt);
    final isOverdue = debt.dueDate.isBefore(DateTime.now());
    final isSettled = debt.remainingPrincipalCents <= 0;
    final hasNext = debt.nextPaymentDate != null &&
        !isSettled &&
        debt.nextPaymentAmountCents > 0;
    // mobile 列表用 Column 自适应高度,无 Spacer(unbounded 高度下 Spacer 报错)。
    return DataCard(
      onTap: () => context.push('/receivables/${debt.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // L1: 36px avatar(mobile 略小)。
              _ReceivableAvatar(
                initial: debt.counterparty.characters.isEmpty
                    ? '?'
                    : debt.counterparty.characters.first,
                color: _avatarColorFor(debt),
              ),
              const SizedBox(width: 10),
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
                        if (isSettled)
                          const _Badge(
                              label: '已结清 ✓',
                              fg: AppColors.positive,
                              bg: Color(0x1A2D8A6E))
                        else if (isOverdue)
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
                  const Text('剩余应收',
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
                  icon: LucideIcons.calendar,
                  text: '到期 ${_fmtDate(debt.dueDate)}'),
            ],
          ),
          if (hasNext || isOverdue && !isSettled) ...[
            const SizedBox(height: 10),
            _CardFootCallout(
              debt: debt,
              preferred: preferred,
              hasNext: hasNext,
              isOverdue: isOverdue,
            ),
          ],
          const SizedBox(height: 10),
          _actionBar(debt, context),
        ],
      ),
    );
  }

  /// 卡片底部操作栏:详情 / 收款 / 更多。
  /// - 详情 → 跳详情页(Task 8)。
  /// - 收款 → 占位(Toast 提示);真正的收款录入在详情页 schedule 行内
  ///   (列表 DebtDTO 不知哪期,与 debts_page 记账按钮同口径)。
  /// - 更多 → PopupMenuButton<String>(编辑/删除占位)。
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
            icon: LucideIcons.info,
            label: '详情',
            onTap: (_) => context.push('/receivables/${debt.id}'),
          ),
          _ActionBtn(
            icon: LucideIcons.moreHorizontal,
            label: '更多',
            onTap: (_) => _showMoreMenu(context),
          ),
        ],
      ),
    );
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.pencil, color: AppColors.muted),
              title: const Text('编辑债权'),
              onTap: () {
                Navigator.pop(sctx);
                context.push('/receivables/${debt.id}');
              },
            ),
            ListTile(
              leading:
                  const Icon(LucideIcons.trash2, color: AppColors.negative),
              title: const Text('删除债权',
                  style: TextStyle(color: AppColors.negative)),
              onTap: () {
                Navigator.pop(sctx);
                context.read<DebtBloc>().add(DeleteDebtRequested(debt.id));
              },
            ),
          ],
        ),
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
            const Text('收回进度',
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

// ───────────────────────── 类型 badge(简化:counterparty 关键字推断) ─────────────────────────

class _BadgeStyle {
  const _BadgeStyle({required this.label, required this.fg, required this.bg});
  final String label;
  final Color fg;
  final Color bg;
}

/// 卡片类型 badge:优先用持久化 subtype const label(Task 9);
/// subtype 空(legacy 债权)→ fallback counterparty 关键字推断 _inferBadge。
/// const 判断,禁裸 subtype 字符串。持久化 subtype 用中性金色样式,
/// fallback 保留推断的语义色(商业蓝/亲友绿/...)。
_BadgeStyle _badgeFor(Debt debt) {
  if (debt.subtype.isNotEmpty) {
    final label = ReceivableSubtypes.labels[debt.subtype];
    if (label != null) {
      return _BadgeStyle(
          label: label, fg: AppColors.accentHover, bg: AppColors.accentSoft);
    }
  }
  return _inferBadge(debt.counterparty);
}

/// 从 counterparty 关键字推断债权类型 badge(商业/亲友/私人/借款)。
/// 对齐 OD receivables.html 的 b-business / b-family / b-personal。
/// Task 9 起仅作 subtype 为空(legacy)时的 fallback。
_BadgeStyle _inferBadge(String counterparty) {
  final s = counterparty.toLowerCase();
  if (counterparty.contains('公司') ||
      counterparty.contains('企业') ||
      counterparty.contains('商') ||
      s.contains('biz') ||
      s.contains('business')) {
    return const _BadgeStyle(
        label: '商业借款', fg: Color(0xFF3A6695), bg: Color(0xFFEAF0F6));
  }
  if (counterparty.contains('亲友') ||
      counterparty.contains('家人') ||
      s.contains('family') ||
      s.contains('friend')) {
    return const _BadgeStyle(
        label: '亲友借款',
        fg: AppColors.positive,
        bg: Color(0x1A2D8A6E) // rgba(45,138,110,.10)
        );
  }
  if (counterparty.contains('信用卡') || s.contains('credit')) {
    return const _BadgeStyle(
        label: '信用卡',
        fg: AppColors.negative,
        bg: Color(0x1AC4544D) // rgba(196,84,77,.10)
        );
  }
  return const _BadgeStyle(
      label: '私人借款', fg: AppColors.accentHover, bg: AppColors.accentSoft);
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
          // Flexible + ellipsis:窄卡(mobile / 3-col grid)下 _Badge 被挤时
          // 文本省略而非整 Row 溢出(避免 test framework 把 overflow 当 fail)。
          Flexible(
            child: Text(label,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── L1 avatar tile + L3 foot callout ─────────────────────────

/// L1:44px avatar tile。债务人首字 + 类型色背景(对齐 OD .avatar)。
/// 类型色:_avatarColorFor 推断(商业蓝 / 亲友绿 / 私人金 / 其他灰)。
class _ReceivableAvatar extends StatelessWidget {
  const _ReceivableAvatar({required this.initial, required this.color});
  final String initial;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: color,
          fontFamily: AppTypography.displayFamily,
          fontFamilyFallback: AppTypography.displayFallback,
        ),
      ),
    );
  }
}

/// L3 foot callout(单卡):下次收款 + 逾期天数 + 收款 CTA。
/// - hasNext(debt.nextPayment* 非空)→ 显「下次收款 · 第 N 期 · 日期 · 金额」+「收款」CTA。
/// - isOverdue && !settled → 显「逾期 N 天」红色提示。
class _CardFootCallout extends StatelessWidget {
  const _CardFootCallout({
    required this.debt,
    required this.preferred,
    required this.hasNext,
    required this.isOverdue,
  });
  final Debt debt;
  final String preferred;
  final bool hasNext;
  final bool isOverdue;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final overdueDays = isOverdue
        ? now.difference(debt.dueDate).inDays
        : 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F4ED),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: const Color(0xFFE9E2D2), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            hasNext ? LucideIcons.calendarClock : LucideIcons.alertTriangle,
            size: 15,
            color: isOverdue && !hasNext ? AppColors.negative : AppColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasNext)
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.fg,
                          fontFeatures: AppTypography.tabularFigures),
                      children: [
                        const TextSpan(
                            text: '下次收款 · ',
                            style: TextStyle(
                                color: AppColors.muted,
                                fontWeight: FontWeight.w500)),
                        TextSpan(
                            text:
                                '第 ${debt.nextPaymentPeriodNo} 期 · ${_fmtDate(debt.nextPaymentDate!)}'),
                        TextSpan(
                            text:
                                ' · ${_fmtSymbol(debt.nextPaymentAmountCents, preferred)}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.accentHover)),
                      ],
                    ),
                  )
                else
                  Text('逾期 $overdueDays 天',
                      style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.negative,
                          fontWeight: FontWeight.w600)),
                if (hasNext && isOverdue) ...[
                  const SizedBox(height: 2),
                  Text('含逾期 $overdueDays 天',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.negative)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 收款 CTA → push detail(列表不知哪期收款,跳详情页 schedule 处理)。
          TextButton.icon(
            onPressed: () => context.push('/receivables/${debt.id}'),
            icon: const Icon(LucideIcons.handCoins, size: 14),
            label: const Text('收款',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentHover,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar 类型色推断(对齐 _inferBadge 语义:商业蓝 / 亲友绿 / 私人金 / 其他灰)。
/// subtype 持久化(中性金);fallback 走 _inferBadge 同口径,加 other gray 兜底。
Color _avatarColorFor(Debt debt) {
  if (debt.subtype.isNotEmpty) {
    return AppColors.accentHover; // 中性金(与 _badgeFor 持久化分支一致)
  }
  final s = debt.counterparty.toLowerCase();
  if (debt.counterparty.contains('公司') ||
      debt.counterparty.contains('企业') ||
      debt.counterparty.contains('商') ||
      s.contains('biz') ||
      s.contains('business')) {
    return const Color(0xFF3A6695); // 商业蓝
  }
  if (debt.counterparty.contains('亲友') ||
      debt.counterparty.contains('家人') ||
      s.contains('family') ||
      s.contains('friend')) {
    return AppColors.positive; // 亲友绿
  }
  if (debt.counterparty.contains('信用卡') || s.contains('credit')) {
    return AppColors.negative; // 信用卡红
  }
  // 其他(无明确关键字)→ gray,区别于「私人借款」的金色。
  return const Color(0xFF7A776E);
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

/// YYYY-MM-DD 完整日期格式(对齐 brief「下次收款 / 到期 2026-08-15」)。
String _fmtDate(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// 千分位 + 两位小数 + 货币符号前缀。对齐 debts_page._fmtSymbol。
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

/// 列表筛选:默认「进行中」(隐藏已结清)。「全部」含已结清,「已结清」只看历史,
/// 「逾期」只看 dueDate < now && !settled(L4 新增)。
enum _ListFilter { all, active, settled, overdue }

/// 列表排序:未结清在前(按到期升序 —— 逾期因 dueDate 早自然靠前),已结清沉底。
int _compareReceivable(Debt a, Debt b) {
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
    case _ListFilter.overdue:
      return !settled && d.dueDate.isBefore(DateTime.now());
  }
}

/// 列表筛选 segmented(全部/进行中/已结清/逾期 + 各自计数,L4 加逾期 tab)。
class _ListFilterSegmented extends StatelessWidget {
  const _ListFilterSegmented({
    required this.filter,
    required this.activeCount,
    required this.settledCount,
    required this.overdueCount,
    required this.onChanged,
  });
  final _ListFilter filter;
  final int activeCount;
  final int settledCount;
  final int overdueCount;
  final ValueChanged<_ListFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    const segments = [
      (_ListFilter.all, '全部'),
      (_ListFilter.active, '进行中'),
      (_ListFilter.settled, '已结清'),
      (_ListFilter.overdue, '逾期'),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFECE5),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      // Wrap 替代 Row(4-seg 在窄 mobile 可能换行,避免溢出)。
      child: Wrap(
        spacing: 0,
        runSpacing: 0,
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
      _ListFilter.overdue => overdueCount,
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
