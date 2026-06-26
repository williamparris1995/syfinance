import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/currency/presentation/bloc/currency_bloc.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';

/// 债务详情页（Task 7）。
///
/// 对齐 OD 原型 `debt-detail.html`(desktop) / `debt-detail-tablet.html` /
/// `debt-detail-mobile.html`，并复用 [AccountDetailPage] 的 _hero（深色金
/// 渐变）+ DataCard / _StatIconSquare 模式。
///
/// 结构：Hero（counterparty + 类型 badge + 剩余本金 + progress bar）→
/// 5 StatCards（借款本金 / 年利率 / 到期日 / 摊还方法 / 已还期数）→
/// 还款计划 schedule（筛选 segmented + desktop 表 / mobile 卡列表）→
/// RecordPayment（点待还期「记账」→ 弹 from_account 选择 → 刷新）。
///
/// 注入：路由层 BlocProvider<DebtBloc>（Task 9）。本页 initState 发
/// [LoadDebtRequested]，context.watch<DebtBloc>() 读 [DebtDetailLoaded]。
class DebtDetailPage extends StatefulWidget {
  const DebtDetailPage({super.key, required this.id});

  final String id;

  @override
  State<DebtDetailPage> createState() => _DebtDetailPageState();
}

class _DebtDetailPageState extends State<DebtDetailPage> {
  /// schedule 筛选状态（全部/待还/已还/逾期）。默认「全部」。
  _ScheduleFilter _filter = _ScheduleFilter.all;

  /// 全量账户缓存（accountId → Account），供 RecordPayment 的 from_account
  /// 选择。initState 异步拉取（直接走 repository，不经 DebtBloc）。
  List<Account> _accounts = const [];

  /// RecordPayment 写操作进行中。dispatch 后置 true，BlocListener 收到
  /// [DebtDetailLoaded]（成功刷新）/[DebtError]（失败）后清零 + toast。
  bool _recordPending = false;

  @override
  void initState() {
    super.initState();
    context.read<DebtBloc>().add(LoadDebtRequested(widget.id));
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final repo = getIt<AccountRepository>();
    final result = await repo.list();
    if (!mounted) return;
    result.fold(
      (_) => null, // 失败：保持空列表，RecordPayment 仍可用空 picker。
      (accounts) => setState(() {
        _accounts = accounts
            .where((a) =>
                a.accountType == AccountType.asset &&
                a.status == AccountStatus.active)
            .toList();
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _scaffold();
  }

  Widget _scaffold() {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.fg,
        elevation: 0,
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('债务详情'),
      ),
      body: BlocListener<DebtBloc, DebtState>(
        // 仅在 RecordPayment 写操作进行中时，对终态反应。
        listenWhen: (p, c) =>
            _recordPending && (c is DebtDetailLoaded || c is DebtError),
        listener: (context, state) {
          if (state is DebtDetailLoaded) {
            setState(() => _recordPending = false);
            AppToast.show(context, '还款已记账', type: ToastType.success);
          } else if (state is DebtError) {
            setState(() => _recordPending = false);
            AppToast.show(context, state.message, type: ToastType.error);
          }
        },
        child: BlocBuilder<DebtBloc, DebtState>(
          builder: (context, state) {
            if (state is DebtLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is DebtError) {
              return Center(child: Text(state.message));
            }
            if (state is DebtDetailLoaded) {
              return _body(state.detail);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _body(DebtDetail detail) {
    final cstate = context.watch<CurrencyBloc>().state;
    final preferred = cstate.preferred;
    final w = MediaQuery.of(context).size.width;
    final isMobile = w <= 720; // ≤720 mobile（与 account_detail_page 对齐）

    return ListView(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 60)
          : const EdgeInsets.fromLTRB(36, 24, 36, 70),
      children: [
        _hero(detail.debt, preferred),
        const SizedBox(height: 18),
        _statsRow(detail, preferred),
        const SizedBox(height: 18),
        _scheduleSection(detail.schedule, isMobile, preferred),
      ],
    );
  }

  // ───────────────────────── Hero ─────────────────────────

  /// 深色金渐变 Hero（对齐 OD .hero + account_detail_page._hero）。
  /// counterparty + 类型 badge + 剩余本金（大字）+ progress bar + 已还期次。
  Widget _hero(Debt debt, String preferred) {
    final isMobile = MediaQuery.of(context).size.width <= 720;
    final ratio = debt.progressRatio;
    final pct = (ratio * 100).toStringAsFixed(1);
    final badge = _inferBadge(debt.counterparty);
    // 已还期数 / 总期数（schedule 总期数未知 —— 用 debt 维度近似：用 progressRatio
    // 不直接给期次，故 hero-prog 文案显「还清进度」+ 百分比，对齐 OD）。
    return ClipRRect(
      borderRadius: AppRadius.lgBorder,
      child: Container(
        padding: const EdgeInsets.fromLTRB(32, 26, 32, 28),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1C1E21), Color(0xFF2A2D33)],
          ),
        ),
        child: Stack(
          children: [
            // 径向金色光晕（御财金 #B08D57 alpha 0.28，对齐 OD .hero::before）。
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.28),
                      AppColors.accent.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.45, 0.70],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // back-link（对齐 OD .back-link）。
                InkWell(
                  onTap: () => context.pop(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.arrowLeft,
                          size: 15, color: Color(0xFF9AA0A8)),
                      SizedBox(width: 6),
                      Text('返回债务管理',
                          style:
                              TextStyle(fontSize: 12.5, color: Color(0xFF9AA0A8))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // hero-name：counterparty + 类型 badge + acct meta。
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    Text(
                      debt.counterparty,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 0.01,
                        height: 1.15,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback,
                      ),
                    ),
                    _heroBadge(badge.label),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        _amortLabel(debt.amortization),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.6),
                          fontFeatures: AppTypography.tabularFigures,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                // hero-kicker + 剩余本金（大字）。
                const Text(
                  'REMAINING PRINCIPAL · 剩余本金',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Color(0xFF9AA0A8),
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  key: const ValueKey('heroRemaining'),
                  _fmtSymbol(debt.remainingPrincipalCents, preferred),
                  style: TextStyle(
                    fontSize: isMobile ? 34 : 46,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.4,
                    color: Colors.white,
                    fontFeatures: AppTypography.tabularFigures,
                    fontFamily: AppTypography.displayFamily,
                    fontFamilyFallback: AppTypography.displayFallback,
                  ),
                ),
                const SizedBox(height: 18),
                // hero-prog：还清进度 + 百分比 + progress bar（金色 + 半透明白底）。
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('还清进度',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9AA0A8))),
                    Text('$pct%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFE8C894),
                          fontFeatures: AppTypography.tabularFigures,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(9999),
                  child: LinearProgressIndicator(
                    key: const ValueKey('heroProgress'),
                    value: ratio,
                    minHeight: 9,
                    backgroundColor: Colors.white.withValues(alpha: 0.10),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFFB08D57).withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// hero 类型 badge（金色实心，对齐 OD .badge.badge-house）。
  Widget _heroBadge(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                  color: Color(0xFFD9B97E), shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFFD9B97E),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2)),
          ],
        ),
      );

  // ───────────────────────── StatRow ─────────────────────────

  /// 5 StatCards（对齐 OD .stats grid 5 列）：借款本金 / 年利率 / 到期日 /
  /// 摊还方法 / 已还期数。desktop 5 列 / tablet-mobile 2 列。
  Widget _statsRow(DebtDetail detail, String preferred) {
    final debt = detail.debt;
    final paidCount =
        detail.schedule.where((e) => e.paid).length;
    final total = detail.schedule.length;
    final stats = <_StatCardData>[
      _StatCardData(
        label: '借款本金',
        icon: LucideIcons.banknote,
        value: _fmtSymbol(debt.totalPrincipalCents, preferred),
        sub: '${_fmtDate(debt.startDate)} 放款',
      ),
      _StatCardData(
        label: '年利率',
        icon: LucideIcons.percent,
        value: '${debt.interestRate.toStringAsFixed(2)}%',
        sub: '年化',
      ),
      _StatCardData(
        label: '到期日',
        icon: LucideIcons.calendar,
        value: _fmtDate(debt.dueDate),
        sub: _remainingMonthsLabel(debt.dueDate),
      ),
      _StatCardData(
        label: '摊还方法',
        icon: LucideIcons.lineChart,
        value: _amortLabel(debt.amortization),
        sub: '月供 ${_fmtSymbol(_approxMonthly(debt), preferred)}',
      ),
      _StatCardData(
        label: '已还期数',
        icon: LucideIcons.check,
        value: '$paidCount / $total',
        sub: '累计 ${detail.schedule.where((e) => e.paid).fold<int>(0,
            (s, e) => s + e.interestCents) ~/ 100 > 0 ? "已还" : "暂无"}',
      ),
    ];
    final w = MediaQuery.of(context).size.width;
    final isTablet = w <= 900;
    return GridView.count(
      key: const ValueKey('statsRow'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 2 : 5,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      mainAxisExtent: 148,
      children: [for (final s in stats) _StatCard(data: s)],
    );
  }

  // ───────────────────────── Schedule ─────────────────────────

  Widget _scheduleSection(
      List<PaymentEntry> schedule, bool isMobile, String preferred) {
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // sec-head：标题 + sum-pills（已还/待还/逾期 计数）。
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('还款计划表',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              _sumPills(schedule),
            ],
          ),
          const SizedBox(height: 14),
          // 筛选 segmented（全部/待还/已还/逾期）。
          _filterSegmented(),
          const SizedBox(height: 14),
          // 列表（desktop/tablet 表 / mobile 卡）。
          _filteredSchedule(schedule).isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('该筛选下无期次',
                        style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
                )
              : isMobile
                  ? _scheduleCardList(schedule, preferred)
                  : _scheduleTable(schedule, preferred),
        ],
      ),
    );
  }

  /// sum-pills：已还(绿)/待还(中性)/逾期(红) 计数（对齐 OD .sum-pills）。
  Widget _sumPills(List<PaymentEntry> schedule) {
    final paid = schedule.where((e) => e.status == PaymentStatus.paid).length;
    final pending =
        schedule.where((e) => e.status == PaymentStatus.pending).length;
    final overdue =
        schedule.where((e) => e.status == PaymentStatus.overdue).length;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _pill('已还', paid, AppColors.positive, const Color(0xFF2D8A6E)),
        _pill('待还', pending, const Color(0xFF54585F), const Color(0xFFBDB8AA)),
        _pill('逾期', overdue, AppColors.negative, const Color(0xFFC4544D)),
      ],
    );
  }

  Widget _pill(
      String label, int count, Color fg, Color dot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: fg)),
          const SizedBox(width: 4),
          Text('$count',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }

  /// 筛选 segmented（对齐 OD .tabs：全部/待还/已还/逾期）。
  Widget _filterSegmented() {
    const segments = [
      (_ScheduleFilter.all, '全部'),
      (_ScheduleFilter.pending, '待还'),
      (_ScheduleFilter.paid, '已还'),
      (_ScheduleFilter.overdue, '逾期'),
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
          for (final (f, label) in segments)
            _filterSegment(f, label),
        ],
      ),
    );
  }

  Widget _filterSegment(_ScheduleFilter f, String label) {
    final active = f == _filter;
    return InkWell(
      key: ValueKey('filterSegment-$label'),
      onTap: () => setState(() => _filter = f),
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
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            color: active ? AppColors.accentHover : const Color(0xFF54585F),
          ),
        ),
      ),
    );
  }

  List<PaymentEntry> _filteredSchedule(List<PaymentEntry> schedule) {
    switch (_filter) {
      case _ScheduleFilter.all:
        return schedule;
      case _ScheduleFilter.pending:
        return schedule.where((e) => e.status == PaymentStatus.pending).toList();
      case _ScheduleFilter.paid:
        return schedule.where((e) => e.status == PaymentStatus.paid).toList();
      case _ScheduleFilter.overdue:
        return schedule
            .where((e) => e.status == PaymentStatus.overdue)
            .toList();
    }
  }

  /// desktop/tablet 表（对齐 OD table）：期次/还款日 + 本金 + 利息 + 合计 +
  /// 状态 badge + 操作（记账/已结清）。
  Widget _scheduleTable(List<PaymentEntry> schedule, String preferred) {
    final entries = _filteredSchedule(schedule);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Table(
        columnWidths: const {
          0: FlexColumnWidth(1.4),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1),
          3: FlexColumnWidth(1),
          4: IntrinsicColumnWidth(),
          5: IntrinsicColumnWidth(),
        },
        children: [
          TableRow(
            decoration: const BoxDecoration(
              color: Color(0xFFFBFAF6),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            children: [
              _tableHeader('期次 / 还款日', align: TextAlign.left),
              _tableHeader('本金', align: TextAlign.right),
              _tableHeader('利息', align: TextAlign.right),
              _tableHeader('合计', align: TextAlign.right),
              _tableHeader('状态', align: TextAlign.center),
              _tableHeader('操作', align: TextAlign.center),
            ],
          ),
          for (var i = 0; i < entries.length; i++)
            _scheduleRow(entries[i], i + 1, entries.length, preferred),
        ],
        ),
      ),
    );
  }

  Widget _tableHeader(String label, {required TextAlign align}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Text(label,
          textAlign: align,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
            fontFeatures: AppTypography.tabularFigures,
          )),
    );
  }

  TableRow _scheduleRow(
      PaymentEntry e, int idx, int total, String preferred) {
    final isLast = idx == total;
    const border = BorderSide(color: Color(0xFFEFECE5));
    return TableRow(
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: border),
      ),
      children: [
        // 期次 + 还款日
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('第 $idx 期',
                  style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      fontFeatures: AppTypography.tabularFigures)),
              const SizedBox(height: 2),
              Text(_fmtDate(e.paymentDate),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFeatures: AppTypography.tabularFigures)),
            ],
          ),
        ),
        _cellRight(_fmtSymbol(e.principalCents, preferred)),
        _cellRight(_fmtSymbol(e.interestCents, preferred)),
        _cellRight(_fmtSymbol(e.totalCents, preferred), bold: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(child: _statusBadge(e)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(child: _scheduleAction(e)),
        ),
      ],
    );
  }

  Widget _cellRight(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(text,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            fontFeatures: AppTypography.tabularFigures,
          )),
    );
  }

  /// mobile 卡列表（对齐 OD debt-detail-mobile .sch-card）。
  Widget _scheduleCardList(List<PaymentEntry> schedule, String preferred) {
    final entries = _filteredSchedule(schedule);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _scheduleCard(entries[i], i + 1, preferred),
          if (i < entries.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _scheduleCard(PaymentEntry e, int idx, String preferred) {
    final status = e.status;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: status == PaymentStatus.overdue
            ? const Color(0x08C4544D) // 极淡红底（overdue 卡）
            : AppColors.surface,
        border: Border.all(
            color: status == PaymentStatus.overdue
                ? const Color(0x33C4544D)
                : AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // top：期次·日期 + 状态 badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('第 $idx 期 · ${_fmtDate(e.paymentDate)}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      fontFeatures: AppTypography.tabularFigures)),
              _statusBadge(e),
            ],
          ),
          const SizedBox(height: 10),
          // 本金 / 利息 / 合计 三列
          Row(
            children: [
              Expanded(
                  child: _cardAmtCell('本金',
                      _fmtSymbol(e.principalCents, preferred))),
              Expanded(
                  child: _cardAmtCell('利息',
                      _fmtSymbol(e.interestCents, preferred))),
              Expanded(
                  child: _cardAmtCell(
                      '合计', _fmtSymbol(e.totalCents, preferred),
                      total: true)),
            ],
          ),
          const SizedBox(height: 10),
          // foot：记账按钮 / 已结清
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_scheduleAction(e)],
          ),
        ],
      ),
    );
  }

  Widget _cardAmtCell(String k, String v, {bool total = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(v,
            style: TextStyle(
                fontSize: 13,
                fontWeight: total ? FontWeight.w600 : FontWeight.w400,
                color: total ? AppColors.fg : AppColors.fg,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }

  /// 状态 badge（对齐 OD .status.status-paid/due/overdue）：
  /// 已还绿 / 待还中性 / 逾期红。
  Widget _statusBadge(PaymentEntry e) {
    final (label, fg, bg, icon) = switch (e.status) {
      PaymentStatus.paid => (
          '已还',
          AppColors.positive,
          const Color(0x1A2D8A6E),
          LucideIcons.check
        ),
      PaymentStatus.pending => (
          '待还',
          const Color(0xFF54585F),
          const Color(0xFFF1EFE9),
          null
        ),
      PaymentStatus.overdue => (
          '逾期',
          AppColors.negative,
          const Color(0x1AC4544D),
          LucideIcons.alertCircle
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(9999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  /// 操作列：待还/逾期 → 「记账」按钮；已还 → 「已结清」标记。
  Widget _scheduleAction(PaymentEntry e) {
    if (e.paid) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.check, size: 13, color: AppColors.positive),
          SizedBox(width: 4),
          Text('已结清',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      );
    }
    final overdue = e.status == PaymentStatus.overdue;
    return OutlinedButton.icon(
      onPressed: () => _openRecordPayment(e),
      icon: Icon(LucideIcons.penLine, size: 13, color: overdue ? Colors.white : null),
      label: const Text('记账'),
      style: overdue
          ? OutlinedButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
              side: const BorderSide(color: AppColors.negative),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
              minimumSize: const Size(0, 30),
              textStyle: const TextStyle(fontSize: 12),
            )
          : OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentHover,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
              minimumSize: const Size(0, 30),
              textStyle: const TextStyle(fontSize: 12),
            ),
    );
  }

  // ───────────────────────── RecordPayment ─────────────────────────

  /// 弹 RecordPayment 对话框：还款金额（只读，对齐 OD .amount-box）+ from_account
  /// 下拉（asset 账户列表）+ 确认 → dispatch RecordPaymentRequested。
  void _openRecordPayment(PaymentEntry e) {
    showDialog<void>(
      context: context,
      builder: (dctx) => _RecordPaymentDialog(
        entry: e,
        accounts: _accounts,
        debtId: widget.id,
        onSubmit: (fromAccountId) {
          Navigator.pop(dctx);
          setState(() => _recordPending = true);
          context.read<DebtBloc>().add(RecordPaymentRequested(
                debtId: widget.id,
                scheduleEntryId: e.id,
                fromAccountId: fromAccountId,
              ));
        },
      ),
    );
  }

  // ───────────────────────── 工具 ─────────────────────────

  /// 千分位 + 两位小数 + 货币符号前缀（与 debts_page._fmtSymbol 一致）。
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

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _remainingMonthsLabel(DateTime dueDate) {
    final now = DateTime.now();
    final months = (dueDate.year - now.year) * 12 +
        (dueDate.month - now.month);
    if (months <= 0) return '已到期';
    return '剩余 $months 个月';
  }

  /// 近似月供（Debt 实体无 monthly 字段；用摊还方法粗估）：
  /// 等额本息/等额本金 → total/期数（未知期数时用 dueDate-startDate 月份近似）；
  /// 一次性 → 到期还本。
  int _approxMonthly(Debt debt) {
    if (debt.amortization == AmortizationMethod.lumpSum) {
      return debt.totalPrincipalCents;
    }
    final months = (debt.dueDate.year - debt.startDate.year) * 12 +
        (debt.dueDate.month - debt.startDate.month);
    if (months <= 0) return 0;
    return debt.totalPrincipalCents ~/ months;
  }
}

// ───────────────────────── 私有辅助类 ─────────────────────────

/// schedule 筛选枚举（全部/待还/已还/逾期）。
enum _ScheduleFilter { all, pending, paid, overdue }

/// StatCard 数据。
class _StatCardData {
  const _StatCardData({
    required this.label,
    required this.icon,
    required this.value,
    required this.sub,
  });
  final String label;
  final IconData icon;
  final String value;
  final String sub;
}

/// StatCard（对齐 OD .stat：金 icon + label + value + sub）。
class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 13, color: AppColors.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(data.label,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        letterSpacing: 0.5)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(data.value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.01,
                fontFeatures: AppTypography.tabularFigures,
              )),
          const SizedBox(height: 5),
          Text(data.sub,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.muted,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

/// RecordPayment 对话框（对齐 OD .modal / .sheet）：
/// 还款金额（只读 amount-box）+ from_account 下拉 + 确认。
class _RecordPaymentDialog extends StatefulWidget {
  const _RecordPaymentDialog({
    required this.entry,
    required this.accounts,
    required this.debtId,
    required this.onSubmit,
  });

  final PaymentEntry entry;
  final List<Account> accounts;
  final String debtId;
  final void Function(String fromAccountId) onSubmit;

  @override
  State<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends State<_RecordPaymentDialog> {
  late String _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _selectedAccountId =
        widget.accounts.isNotEmpty ? widget.accounts.first.id : '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('记录还款'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 还款金额（amount-box 金底）。
            const Text('还款金额',
                style: TextStyle(fontSize: 12, color: Color(0xFF54585F))),
            const SizedBox(height: 7),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                border: Border.all(color: const Color(0xFFE8DCC2)),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Text('¥',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text(
                    '${widget.entry.totalCents ~/ 100}.${(widget.entry.totalCents % 100).toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppTypography.tabularFigures),
                  ),
                  const Spacer(),
                  Text(
                      '期次 · ${_fmtDate(widget.entry.paymentDate)}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.accentHover,
                          fontFeatures: AppTypography.tabularFigures)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // from_account 下拉。
            const Text('从账户转出（关联 from_account）',
                style: TextStyle(fontSize: 12, color: Color(0xFF54585F))),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              value: _selectedAccountId.isEmpty ? null : _selectedAccountId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: widget.accounts.isEmpty
                  ? const [
                      DropdownMenuItem(
                        value: '',
                        child: Text('无可用资产账户'),
                      )
                    ]
                  : [
                      for (final a in widget.accounts)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(
                              '${a.name}（余额 ${_fmtBalance(a.currentBalanceCents)}）'),
                        ),
                    ],
              onChanged: (v) {
                if (v != null) setState(() => _selectedAccountId = v);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _selectedAccountId.isEmpty
              ? null
              : () => widget.onSubmit(_selectedAccountId),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: Colors.white,
          ),
          child: const Text('确认记账'),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  String _fmtBalance(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    return '$sign¥$yuan.$fen';
  }
}

// ───────────────────────── 顶层 helper（测试可见） ─────────────────────────

/// 摊还方法 label（与 debts_page._amortLabel 同语义，独立定义避免跨文件依赖）。
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

/// 从 counterparty 关键字推断类型 badge（与 debts_page._inferBadge 同语义）。
_BadgeStyle _inferBadge(String counterparty) {
  final s = counterparty.toLowerCase();
  if (counterparty.contains('房') || s.contains('mortgage')) {
    return const _BadgeStyle(label: '房贷');
  }
  if (counterparty.contains('车') || s.contains('car')) {
    return const _BadgeStyle(label: '车贷');
  }
  if (counterparty.contains('信用卡') || s.contains('credit')) {
    return const _BadgeStyle(label: '信用卡');
  }
  if (counterparty.contains('亲友') ||
      counterparty.contains('借') ||
      s.contains('friend')) {
    return const _BadgeStyle(label: '亲友借款');
  }
  return const _BadgeStyle(label: '借款');
}

class _BadgeStyle {
  const _BadgeStyle({required this.label});
  final String label;
}
