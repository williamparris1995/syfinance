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

/// 债权详情页（Task 8）—— 收款语义。
///
/// 结构对称 [DebtDetailPage]，但承载 **BorrowedOut** receivable（别人欠我）：
///  - OD 原型 `receivable-detail.html`(desktop) / `-tablet.html` / `-mobile.html`
///  - Label:「剩余应收 / 收款计划 / 确认收款 / 已收 / 待收 / 逾期」
///    （非「剩余本金 / 还款计划 / 记账」）。
///  - 确认收款 = RecordPayment 收款语义（别人还我 → to 我的收款账户）。
///    proto RecordPayment 沿用（debt_id + schedule_entry_id + from_account_id），
///    仅 UI label/语义不同。
///  - schedule entry：已收 = 绿 ✓（别人已还这期）；待收 = 中性；逾期 = 红。
///
/// 注入：路由层 BlocProvider<DebtBloc>（Task 10）。本页 initState 发
/// [LoadDebtRequested]，context.watch<DebtBloc>() 读 [DebtDetailLoaded]。
/// 加载按 `id`（与 debt_detail_page 同口径，单笔债务加载不传 typeFilter）。
class ReceivableDetailPage extends StatefulWidget {
  const ReceivableDetailPage({super.key, required this.id});

  final String id;

  @override
  State<ReceivableDetailPage> createState() => _ReceivableDetailPageState();
}

class _ReceivableDetailPageState extends State<ReceivableDetailPage> {
  /// schedule 筛选状态（全部/待收/已收/逾期）。默认「全部」。
  _ScheduleFilter _filter = _ScheduleFilter.all;

  /// 全量收款账户缓存（accountId → Account），供 确认收款 选择 to_account。
  /// initState 异步拉取（直接走 repository，不经 DebtBloc）。
  List<Account> _accounts = const [];

  /// 确认收款 写操作进行中。dispatch 后置 true，BlocListener 收到
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
      (_) => null, // 失败：保持空列表，确认收款 仍可用空 picker。
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
        title: const Text('收款详情'),
      ),
      body: BlocListener<DebtBloc, DebtState>(
        // 仅在 确认收款 写操作进行中时，对终态反应。
        listenWhen: (p, c) =>
            _recordPending && (c is DebtDetailLoaded || c is DebtError),
        listener: (context, state) {
          if (state is DebtDetailLoaded) {
            setState(() => _recordPending = false);
            // Task 4 (ccs): RecordPayment 双写后 server 端收款账户余额已变,
            // 重新拉账户列表刷新收款账户 picker 余额(依赖 _accounts 的
            // currentBalanceCents)。
            _loadAccounts();
            AppToast.show(context, '已确认收款', type: ToastType.success);
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
    final isMobile = w <= 720; // ≤720 mobile（与 debt_detail_page 对齐）
    // D3:desktop(>1080)双列带 side panel;tablet/mobile 单列(side panel 下移)。
    final showSide = w > 1080;

    return ListView(
      padding: isMobile
          ? const EdgeInsets.fromLTRB(16, 14, 16, 60)
          : const EdgeInsets.fromLTRB(36, 24, 36, 70),
      children: [
        if (showSide)
          // desktop 双列:Row 内 左 expanded(hero+stats+schedule)+ 右 320 side。
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _hero(detail.debt, preferred, detail),
                    const SizedBox(height: 18),
                    _statsRow(detail, preferred),
                    const SizedBox(height: 18),
                    _scheduleSection(
                        detail.schedule, detail.debt, isMobile, preferred),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 320,
                child: _sidePanel(detail, preferred),
              ),
            ],
          )
        else ...[
          _hero(detail.debt, preferred, detail),
          const SizedBox(height: 18),
          _statsRow(detail, preferred),
          const SizedBox(height: 18),
          _scheduleSection(detail.schedule, detail.debt, isMobile, preferred),
          const SizedBox(height: 18),
          _sidePanel(detail, preferred),
        ],
      ],
    );
  }

  // ───────────────────────── Hero ─────────────────────────

  /// 深色金渐变 Hero（D1 双列,对齐 OD .hero-inner grid 1.6fr/1fr）。
  /// 左:hero-avatar(50px 类型色 tile) + name/badges + 剩余应收(大字) + delta pill
  ///     (remainingTrendCents:负=减少=收回 绿;正=增加 红;0 不显) + progress bar。
  /// 右:hero-side 4-tile grid(年利率/月供/到期日/已收期数)。
  /// mobile/窄屏(<900)单列(avatar + delta + 4-tile 2×2),对齐 OD @media(max-width:1080px)。
  Widget _hero(Debt debt, String preferred, DebtDetail detail) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w <= 720;
    final isNarrow = w <= 1080; // ≤1080 单列(对齐 OD .hero-inner grid → 1fr)
    final ratio = debt.progressRatio;
    final pct = (ratio * 100).toStringAsFixed(1);
    final badge = _inferBadge(debt.counterparty);
    final isSettled = debt.remainingPrincipalCents <= 0;
    final avatarColor = _avatarColorFor(debt);
    final paidCount = detail.schedule.where((e) => e.paid).length;
    final total = detail.schedule.length;
    final initial =
        debt.counterparty.isNotEmpty ? debt.counterparty.characters.first : '?';

    final avatarTile = Container(
      key: const ValueKey('heroAvatar'),
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: avatarColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: avatarColor.withValues(alpha: 0.55), width: 1),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: _lighten(avatarColor),
          fontSize: 22,
          fontWeight: FontWeight.w700,
          fontFamily: AppTypography.displayFamily,
          fontFamilyFallback: AppTypography.displayFallback,
        ),
      ),
    );

    // hero 左侧主块。
    final heroMain = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => context.pop(),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.arrowLeft, size: 15, color: Color(0xFF9AA0A8)),
              SizedBox(width: 6),
              Text('返回债权管理',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF9AA0A8))),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            avatarTile,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
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
                      if (isSettled) _heroBadge('已结清 ✓'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '借出 ${_fmtSymbol(debt.totalPrincipalCents, preferred)} · '
                    '${_fmtDate(debt.startDate)} · ${_amortLabel(debt.amortization)} · '
                    '$total 期',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: const Color(0xFFA8A59A),
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const Text(
          'REMAINING RECEIVABLE · 剩余应收（本金）',
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
        // delta pill:remainingTrendCents 负=减少=收回 绿;正=增加 红;0 不显。
        if (debt.remainingTrendCents != 0) ...[
          const SizedBox(height: 11),
          _deltaPill(debt.remainingTrendCents, preferred, paidCount, total),
        ],
        const SizedBox(height: 14),
        // hero-prog-meta:已收/剩余 文案。mobile 窄屏两段会溢出 → 用 Wrap 自动换行。
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          runSpacing: 4,
          children: [
            Text(
              '已收本金 ${_fmtSymbol(debt.totalPrincipalCents - debt.remainingPrincipalCents, preferred)}',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFFA8A59A),
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
            Text(
              '剩余 ${_fmtSymbol(debt.remainingPrincipalCents, preferred)} · 收回 $pct%',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFFE7DFCA),
                fontWeight: FontWeight.w600,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
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
    );

    // hero 右侧 4-tile(2×2)。
    final heroSide = _heroSide(debt, preferred, paidCount, total);

    return ClipRRect(
      borderRadius: AppRadius.lgBorder,
      child: Container(
        padding: isMobile
            ? const EdgeInsets.fromLTRB(22, 22, 22, 24)
            : const EdgeInsets.fromLTRB(30, 28, 30, 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2126), Color(0xFF24201A), Color(0xFF1C1E21)],
          ),
        ),
        child: Stack(
          children: [
            // 径向金色光晕(对齐 OD .hero::before / .hero::after)。
            Positioned(
              top: -70,
              right: -50,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.34),
                      AppColors.accent.withValues(alpha: 0.06),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 0.7],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -90,
              left: 80,
              child: Container(
                width: 280,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accent.withValues(alpha: 0.13),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
            isNarrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      heroMain,
                      const SizedBox(height: 22),
                      heroSide,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 16, child: heroMain),
                      const SizedBox(width: 34),
                      Expanded(flex: 10, child: heroSide),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  /// delta pill:remainingTrendCents(负=减少=收回 绿 pill ↓;正=增加 红 pill ↑)。
  Widget _deltaPill(int trendCents, String preferred, int paidCount, int total) {
    final decreasing = trendCents < 0; // 负 = 较上月减少(收回,绿)
    final abs = trendCents.abs();
    final fg = decreasing ? const Color(0xFF7FC9A8) : const Color(0xFFE29A93);
    final bg = decreasing
        ? const Color(0x332D8A6E)
        : const Color(0x33C4544D);
    final icon = decreasing ? LucideIcons.arrowDown : LucideIcons.arrowUp;
    final verb = decreasing ? '减少' : '增加';
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Container(
          key: const ValueKey('heroDelta'),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: fg),
              const SizedBox(width: 4),
              Text(
                _fmtSymbol(abs, preferred),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fg,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ],
          ),
        ),
        Text(
          '较上月$verb · 已收回 $paidCount / $total 期',
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFFBCB9AD),
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ],
    );
  }

  /// hero 右侧 4-tile(年利率/月供/到期日/已收期数)。
  Widget _heroSide(Debt debt, String preferred, int paidCount, int total) {
    return GridView.count(
      key: const ValueKey('heroSide'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      // 固定行高(label 10.5 + gap 3 + value 15(可换行至 2 行)+ padding 8*2)。
      mainAxisExtent: 78,
      childAspectRatio: 1.7,
      children: [
        _heroTile('年利率', '${debt.interestRate.toStringAsFixed(2)}%'),
        _heroTile('月供', _fmtSymbol(_approxMonthly(debt), preferred)),
        _heroTile('到期日', _fmtDate(debt.dueDate)),
        _heroTile('已收期数', '$paidCount / $total'),
      ],
    );
  }

  Widget _heroTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xFF8F8D83),
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF3EFEA),
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  /// 类型色:复用 receivables_page._avatarColorFor 语义(商业蓝/亲友绿/私人金/其他灰)。
  Color _avatarColorFor(Debt debt) {
    if (debt.subtype.isNotEmpty) return AppColors.accentHover;
    final s = debt.counterparty.toLowerCase();
    if (debt.counterparty.contains('公司') ||
        debt.counterparty.contains('企业') ||
        debt.counterparty.contains('商') ||
        s.contains('biz') ||
        s.contains('business')) {
      return const Color(0xFF3A6695);
    }
    if (debt.counterparty.contains('亲友') ||
        debt.counterparty.contains('家人') ||
        s.contains('family') ||
        s.contains('friend')) {
      return AppColors.positive;
    }
    if (debt.counterparty.contains('信用卡') || s.contains('credit')) {
      return AppColors.negative;
    }
    return const Color(0xFF7A776E);
  }

  /// avatar tile 文字色:类型色浅化(深色 hero 底上可读)。
  Color _lighten(Color c) {
    final r = c.r;
    final g = c.g;
    final b = c.b;
    final nr = ((r * 255 + (255 - r * 255) * 0.45)).round().clamp(0, 255);
    final ng = ((g * 255 + (255 - g * 255) * 0.45)).round().clamp(0, 255);
    final nb = ((b * 255 + (255 - b * 255) * 0.45)).round().clamp(0, 255);
    return Color.fromARGB(255, nr, ng, nb);
  }

  /// hero 类型 badge（金色实心，对齐 OD .badge）。
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

  /// D2:5 StatCards 金额维度(对齐 OD .stats grid 5 列):
  /// 借出本金 / 已收合计(绿)/ 待收合计 / 累计利息收入(绿)/ 逾期应收(红+ N 期)。
  /// 金额从 schedule 聚合(client 算)。desktop 5 列 / tablet-mobile 2 列。
  Widget _statsRow(DebtDetail detail, String preferred) {
    final debt = detail.debt;
    final schedule = detail.schedule;
    final paidPrincipal =
        schedule.where((e) => e.paid).fold<int>(0, (s, e) => s + e.principalCents);
    final paidInterest =
        schedule.where((e) => e.paid).fold<int>(0, (s, e) => s + e.interestCents);
    final paidTotal = paidPrincipal + paidInterest;
    final unpaidEntries = schedule.where((e) => !e.paid);
    final pendingTotal =
        unpaidEntries.fold<int>(0, (s, e) => s + e.totalCents);
    final overdueEntries =
        schedule.where((e) => e.status == PaymentStatus.overdue && !e.paid);
    final overdueTotal =
        overdueEntries.fold<int>(0, (s, e) => s + e.totalCents);
    final overdueCount = overdueEntries.length;

    final stats = <_StatCardData>[
      _StatCardData(
        label: '借出本金',
        icon: LucideIcons.banknote,
        value: _fmtSymbol(debt.totalPrincipalCents, preferred),
        sub: '${_fmtDate(debt.startDate)} 放款',
      ),
      _StatCardData(
        label: '已收合计',
        icon: LucideIcons.check,
        value: _fmtSymbol(paidTotal, preferred),
        // sub 紧凑:本/利 分行(max 2 行,适配窄 StatCard)。
        sub: '本 ${_fmtSymbol(paidPrincipal, preferred)} · '
            '利 ${_fmtSymbol(paidInterest, preferred)}',
        valueColor: AppColors.positive,
      ),
      _StatCardData(
        label: '待收合计',
        icon: LucideIcons.clock,
        value: _fmtSymbol(pendingTotal, preferred),
        sub: '剩本 ${_fmtSymbol(debt.remainingPrincipalCents, preferred)}',
      ),
      _StatCardData(
        label: '累计利息收入',
        icon: LucideIcons.trendingUp,
        value: _fmtSymbol(paidInterest, preferred),
        sub: '年化 ${debt.interestRate.toStringAsFixed(2)}%',
        valueColor: paidInterest > 0 ? AppColors.positive : null,
      ),
      _StatCardData(
        label: '逾期应收',
        icon: LucideIcons.alertCircle,
        value: _fmtSymbol(overdueTotal, preferred),
        sub: overdueCount > 0 ? '$overdueCount 期 · 待催收' : '无逾期',
        valueColor: overdueCount > 0 ? AppColors.negative : null,
      ),
    ];
    final w = MediaQuery.of(context).size.width;
    final isTablet = w <= 900;
    return GridView.count(
      key: const ValueKey('statsRow'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 2 : 5,
      mainAxisSpacing: 13,
      crossAxisSpacing: 13,
      mainAxisExtent: 168,
      children: [for (final s in stats) _StatCard(data: s)],
    );
  }

  // ───────────────────────── Schedule ─────────────────────────

  Widget _scheduleSection(
      List<PaymentEntry> schedule, Debt debt, bool isMobile, String preferred) {
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // sec-head：标题 + sum-pills（已收/待收/逾期 计数）。
          // mobile 窄屏标题+pills 会溢出 → 用 Wrap 自动换行。
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              const Text('收款计划',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              _sumPills(schedule),
            ],
          ),
          const SizedBox(height: 14),
          // 筛选 segmented（全部/待收/已收/逾期）。
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
                  ? _scheduleCardList(schedule, debt, preferred)
                  : _scheduleTable(schedule, debt, preferred),
        ],
      ),
    );
  }

  /// sum-pills：已收(绿)/待收(中性)/逾期(红) 计数（对齐 OD .mini-stats）。
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
        _pill('已收', paid, AppColors.positive, const Color(0xFF2D8A6E)),
        _pill('待收', pending, const Color(0xFF54585F), const Color(0xFFBDB8AA)),
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

  /// 筛选 segmented（对齐 OD .seg：全部/待收/已收/逾期）。
  Widget _filterSegmented() {
    const segments = [
      (_ScheduleFilter.all, '全部'),
      (_ScheduleFilter.pending, '待收'),
      (_ScheduleFilter.paid, '已收'),
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

  /// desktop/tablet 表（对齐 OD table）：期次/收款日 + 收回本金 + 利息收入 +
  /// 合计 + 状态 badge + 操作（确认收款/已确认）。
  Widget _scheduleTable(List<PaymentEntry> schedule, Debt debt, String preferred) {
    final entries = _filteredSchedule(schedule);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
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
              _tableHeader('期次 / 收款日', align: TextAlign.left),
              _tableHeader('收回本金', align: TextAlign.right),
              _tableHeader('利息收入', align: TextAlign.right),
              _tableHeader('合计', align: TextAlign.right),
              _tableHeader('状态', align: TextAlign.center),
              _tableHeader('操作', align: TextAlign.center),
            ],
          ),
          for (var i = 0; i < entries.length; i++)
            _scheduleRow(entries[i], debt, i + 1, entries.length, preferred),
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
      PaymentEntry e, Debt debt, int idx, int total, String preferred) {
    final isLast = idx == total;
    const border = BorderSide(color: Color(0xFFEFECE5));
    return TableRow(
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: border),
      ),
      children: [
        // 期次 + 收款日
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Center(child: _scheduleAction(e, debt, preferred)),
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

  /// mobile 卡列表（对齐 OD receivable-detail-mobile 卡）。
  Widget _scheduleCardList(List<PaymentEntry> schedule, Debt debt, String preferred) {
    final entries = _filteredSchedule(schedule);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _scheduleCard(entries[i], debt, i + 1, preferred),
          if (i < entries.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _scheduleCard(PaymentEntry e, Debt debt, int idx, String preferred) {
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
              Flexible(
                child: Text('第 $idx 期 · ${_fmtDate(e.paymentDate)}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFeatures: AppTypography.tabularFigures)),
              ),
              _statusBadge(e),
            ],
          ),
          const SizedBox(height: 10),
          // 收回本金 / 利息收入 / 合计 三列
          Row(
            children: [
              Expanded(
                  child: _cardAmtCell('收回本金',
                      _fmtSymbol(e.principalCents, preferred))),
              Expanded(
                  child: _cardAmtCell('利息收入',
                      _fmtSymbol(e.interestCents, preferred))),
              Expanded(
                  child: _cardAmtCell(
                      '合计', _fmtSymbol(e.totalCents, preferred),
                      total: true)),
            ],
          ),
          const SizedBox(height: 10),
          // foot：确认收款按钮 / 已确认
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_scheduleAction(e, debt, preferred)],
          ),
        ],
      ),
    );
  }

  Widget _cardAmtCell(String k, String v, {bool total = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(k, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: total ? FontWeight.w600 : FontWeight.w400,
                color: total ? AppColors.fg : AppColors.fg,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }

  /// 状态 badge（对齐 OD .st-paid/.st-pending/.st-overdue）：
  /// 已收绿 / 待收中性 / 逾期红。
  Widget _statusBadge(PaymentEntry e) {
    final (label, fg, bg, icon) = switch (e.status) {
      PaymentStatus.paid => (
          '已收',
          AppColors.positive,
          const Color(0x1A2D8A6E),
          LucideIcons.check
        ),
      PaymentStatus.pending => (
          '待收',
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

  // ───────────────────────── Side Panel (D3) ─────────────────────────

  /// D3:右侧 side panel —— 收款账户卡 + 借款信息卡(对齐 OD .side-card)。
  /// desktop(>1080)与 main Row 并列;mobile/窄屏追加到 main ListView 下方。
  Widget _sidePanel(DebtDetail detail, String preferred) {
    final debt = detail.debt;
    // 收款账户名 lookup:collectionAccountId / accountId(应收账户)在 _accounts。
    final collectionName = _lookupAccountName(debt.collectionAccountId);
    final receivableName = _lookupAccountName(debt.accountId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 收款账户卡。
        DataCard(
          key: const ValueKey('sideCollectionCard'),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.shieldCheck, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('收款账户',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback,
                      )),
                ],
              ),
              const SizedBox(height: 14),
              _sideRow('收款至', collectionName ?? '未设置'),
              _sideRow('应收账户', receivableName ?? '—'),
            ],
          ),
        ),
        const SizedBox(height: 18),
        // 借款信息卡。
        DataCard(
          key: const ValueKey('sideLoanCard'),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.info, size: 16, color: AppColors.accent),
                  const SizedBox(width: 8),
                  const Text('借款信息',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback,
                      )),
                ],
              ),
              const SizedBox(height: 14),
              _sideRow('债务人', debt.counterparty),
              _sideRow('联系方式', debt.contact.isEmpty ? '—' : debt.contact),
              _sideRow('借出日期', _fmtDate(debt.startDate)),
              _sideRow('到期日期', _fmtDate(debt.dueDate)),
              _sideRow('摊还方法', _amortLabel(debt.amortization)),
              _sideRow(
                '合同/借据',
                debt.contractRef.isEmpty ? '—' : debt.contractRef,
                valueColor: debt.contractRef.isEmpty ? null : AppColors.accentHover,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// side panel 行:k/v 对齐,底部虚线分隔(对齐 OD .rl dashed border)。
  Widget _sideRow(String k, String v, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(k,
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              v,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.fg,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 从 _accounts 缓存按 id 解析账户名(_accounts 含 inactive 时仍可解析;
  /// 但 _loadAccounts 仅 active asset,故 collection 账户若是非 asset 则 null)。
  String? _lookupAccountName(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final a in _accounts) {
      if (a.id == id) return a.name;
    }
    return null;
  }

  /// 操作列:待收/逾期 → 「确认收款」。
  /// D4:若 debt.collectionAccountId 非空 → 行内 link-btn 直接 dispatch
  /// RecordPayment(from=collectionAccountId)+ toast,无 dialog。
  /// collection 为空(legacy)→ fallback dialog(_openRecordPayment)。
  /// 已收 → 「已确认」标记。
  Widget _scheduleAction(PaymentEntry e, Debt debt, String preferred) {
    if (e.paid) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.check, size: 13, color: AppColors.positive),
          SizedBox(width: 4),
          Text('已确认',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      );
    }
    final overdue = e.status == PaymentStatus.overdue;
    final hasCollection =
        debt.collectionAccountId != null && debt.collectionAccountId!.isNotEmpty;

    // D4 行内:collection 已配置 → 直接确认 + toast(无 dialog)。
    if (hasCollection) {
      return OutlinedButton.icon(
        onPressed: () => _confirmInline(e, debt.collectionAccountId!, preferred),
        icon: Icon(LucideIcons.check,
            size: 13, color: overdue ? Colors.white : null),
        label: const Text('确认收款'),
        style: overdue
            ? OutlinedButton.styleFrom(
                backgroundColor: AppColors.negative,
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.negative),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                minimumSize: const Size(0, 30),
                textStyle: const TextStyle(fontSize: 12),
              )
            : OutlinedButton.styleFrom(
                foregroundColor: AppColors.accentHover,
                side: const BorderSide(color: AppColors.border),
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                minimumSize: const Size(0, 30),
                textStyle: const TextStyle(fontSize: 12),
              ),
      );
    }

    // fallback:collection 为空(legacy)→ 弹 dialog 选收款账户。
    return OutlinedButton.icon(
      onPressed: () => _openRecordPayment(e),
      icon: Icon(LucideIcons.check,
          size: 13, color: overdue ? Colors.white : null),
      label: const Text('确认收款'),
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

  /// D4 行内确认:直接 dispatch RecordPayment + toast(无 dialog)。
  void _confirmInline(
      PaymentEntry e, String collectionAccountId, String preferred) {
    setState(() => _recordPending = true);
    context.read<DebtBloc>().add(RecordPaymentRequested(
          debtId: widget.id,
          scheduleEntryId: e.id,
          fromAccountId: collectionAccountId,
        ));
    // 即时反馈 toast(成功后 BlocListener 还会再 reload+toast,
    // 这里给即时确认感;金额按 entry.totalCents 显示)。
    AppToast.show(context, '已确认收款 ${_fmtSymbol(e.totalCents, preferred)}',
        type: ToastType.success);
  }

  // ───────────────────────── 确认收款 (RecordPayment) ─────────────────────────

  /// 弹 确认收款 对话框：收款金额（只读，对齐 OD .amount-box）+ to_account
  /// 下拉（我的收款账户列表）+ 确认 → dispatch RecordPaymentRequested。
  ///
  /// 收款语义：别人还我 → 钱进我的收款账户。proto RecordPayment 沿用
  /// （debt_id + schedule_entry_id + from_account_id），仅 label 不同。
  void _openRecordPayment(PaymentEntry e) {
    // 多币种:dialog amount-box 走 _fmtSymbol(cents, preferred),与主路径
    // detail page 一致(避免 preferred=USD 时 dialog ¥ vs 主页面 $)。
    final preferred = context.read<CurrencyBloc>().state.preferred;
    showDialog<void>(
      context: context,
      builder: (dctx) => _ConfirmReceiptDialog(
        entry: e,
        accounts: _accounts,
        debtId: widget.id,
        preferred: preferred,
        onSubmit: (toAccountId) {
          Navigator.pop(dctx);
          setState(() => _recordPending = true);
          context.read<DebtBloc>().add(RecordPaymentRequested(
                debtId: widget.id,
                scheduleEntryId: e.id,
                fromAccountId: toAccountId,
              ));
        },
      ),
    );
  }

  // ───────────────────────── 工具 ─────────────────────────

  /// 千分位 + 两位小数 + 货币符号前缀（与 receivables_page._fmtSymbol 一致）。
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

  /// 近似月收（Debt 实体无 monthly 字段；用摊还方法粗估）：
  /// 等额本息/等额本金 → total/期数（未知期数时用 dueDate-startDate 月份近似）；
  /// 一次性 → 到期收本。
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

/// schedule 筛选枚举（全部/待收/已收/逾期）。
enum _ScheduleFilter { all, pending, paid, overdue }

/// StatCard 数据。
class _StatCardData {
  const _StatCardData({
    required this.label,
    required this.icon,
    required this.value,
    required this.sub,
    this.valueColor,
  });
  final String label;
  final IconData icon;
  final String value;
  final String sub;
  /// value 文字色:null=默认 fg;positive=绿;negative=红(对齐 OD .stat.good/.warn)。
  final Color? valueColor;
}

/// StatCard（对齐 OD .stat：金 icon + label + value + sub,value 可 good/warn 色）。
class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.01,
                color: data.valueColor ?? AppColors.fg,
                fontFeatures: AppTypography.tabularFigures,
              )),
          const SizedBox(height: 5),
          Text(data.sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.muted,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

/// 确认收款 对话框（对齐 OD .modal / .sheet）：
/// 收款金额（只读 amount-box）+ 收款账户下拉 + 确认。
///
/// 收款语义：别人还我 → to 我的收款账户。proto RecordPayment 沿用
/// （from_account_id 字段在 UI 上即「收款账户」语义）。
class _ConfirmReceiptDialog extends StatefulWidget {
  const _ConfirmReceiptDialog({
    required this.entry,
    required this.accounts,
    required this.debtId,
    required this.onSubmit,
    required this.preferred,
  });

  final PaymentEntry entry;
  final List<Account> accounts;
  final String debtId;
  final void Function(String toAccountId) onSubmit;
  /// 多币种(Global #11):amount-box 走 _fmtSymbol(cents, preferred),
  /// 与主路径 detail page 一致(避免 dialog ¥ vs 主页面 $ 不一致)。
  final String preferred;

  @override
  State<_ConfirmReceiptDialog> createState() => _ConfirmReceiptDialogState();
}

class _ConfirmReceiptDialogState extends State<_ConfirmReceiptDialog> {
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
      title: const Text('确认收款'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 收款金额（amount-box 金底）。
            const Text('收款金额',
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
                  // 多币种:走 _fmtSymbol(cents, preferred),符号已含千分位+前缀
                  // (与主路径 detail page / hero / schedule 一致,Global #11)。
                  Text(
                    _fmtSymbol(widget.entry.totalCents, widget.preferred),
                    style: const TextStyle(
                        color: AppColors.accent,
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
            // 收款账户下拉（别人还我 → to 我的收款账户）。
            const Text('收款至账户（别人还我入账的账户）',
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
                        child: Text('无可用收款账户'),
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
          child: const Text('确认收款'),
        ),
      ],
    );
  }

  String _fmtDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  /// 千分位 + 两位小数 + 货币符号前缀(与 _ReceivableDetailPageState._fmtSymbol
  /// 同语义,独立定义以避跨 State 类依赖)。多币种(Global #11)。
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

  String _fmtBalance(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    return '$sign¥$yuan.$fen';
  }
}

// ───────────────────────── 顶层 helper（测试可见） ─────────────────────────

/// 摊还方法 label（与 receivables_page._amortLabel 同语义，独立定义避免跨文件依赖）。
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

/// 从 counterparty 关键字推断债权类型 badge（对齐 receivables_page._inferBadge）。
_BadgeStyle _inferBadge(String counterparty) {
  final s = counterparty.toLowerCase();
  if (counterparty.contains('公司') ||
      counterparty.contains('企业') ||
      counterparty.contains('商') ||
      s.contains('biz') ||
      s.contains('business')) {
    return const _BadgeStyle(label: '商业借款');
  }
  if (counterparty.contains('亲友') ||
      counterparty.contains('家人') ||
      s.contains('family') ||
      s.contains('friend')) {
    return const _BadgeStyle(label: '亲友借款');
  }
  if (counterparty.contains('信用卡') || s.contains('credit')) {
    return const _BadgeStyle(label: '信用卡');
  }
  return const _BadgeStyle(label: '私人借款');
}

class _BadgeStyle {
  const _BadgeStyle({required this.label});
  final String label;
}
