// 投资目标关联页(holding-D,Task 11)。Task 6 对齐 OD v2 goals-desktop.html。
//
// 数据源(holding-D 真接,D-goal Task 10 接口):
//   - HoldingRepository.listInvestmentGoals() → Either<Failure, List<GoalView>>
//     (server 按 type=INVESTMENT filter,跨模块 goal gRPC 经 GoalViewDataSource)
//   - 客户端 filter linkedAccountId == holding.accountId(investment goals 少,
//     首批客户端 filter 足够;避免 proto/repo 加 linked_account filter)
//   - D-goal account 级:goal.linked_account_id 关联 investment account,
//     progress = Σ 该账户下 holdings mv(server 算 current_amount_cents)。
//
// 构造两条入口:
//   - holding 详情 push extra(有效 holding,accountId 非空)→ filter linked_account,
//     显「持仓市值 vs 目标额 · SYMBOL」+ 贡献占比 + 同账户持仓 picker。
//   - sidebar context.go('/holdings/goals') 无 extra(router 兜底空 Holding,
//     accountId='')→ 不 filter,显全部投资目标(跨账户总览),通用 sub,
//     无贡献占比 / picker。goalRepo(HoldingRepository)注入便于 widget test。
//
// 对齐 OD v2 goals-desktop.html:
//   ① page-head(h1 衬线「投资目标」+ sub「N 目标 · 跨账户总览 · 合计 ¥X」/
//     有效 holding 「持仓市值 vs 目标额 · SYMBOL」)
//   ② stat-row 4 卡(总数 / 超目标≥100% / 进行中 80-100% / 落后<80%,
//     计数中性 + 角标 icon 状态色:grey/green/gold/red)
//   ③ goal 卡(monogram icon + 名 + status badge + 当前/目标 mono + 金进度条%,
//     落后红条/超目标绿条)+ 贡献占比(有效 holding)
//
// 渲染模式:FutureBuilder<Either<Failure, List<GoalView>>>(无新 bloc,简化)。
//   - loading → 圆圈
//   - Left(failure) → 错误空态(displayMessage)
//   - Right(空 filter 结果) → 空态「该账户暂无投资目标」
//   - Right(goals) → page-head sub + stat-row + goal 卡片列表
// 关联 holding 选择仍走 HoldingBloc(ListHoldings 已加载,渲染同账户 holdings)。
import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/entities/goal_view_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_module_tabs.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_pie_chart.dart';

/// 投资目标关联页(holding-D)。对齐 OD v2 goals-desktop.html。
///
/// 接收 [holding](从 holding 详情进入,供 accountId + 贡献占比)与 [goalRepo]
/// (HoldingRepository,调 listInvestmentGoals)。goal 区走 FutureBuilder;
/// 关联 holding 选择走 context.read<HoldingBloc>()(ListHoldings)。
class GoalLinkPage extends StatefulWidget {
  const GoalLinkPage({
    super.key,
    required this.holding,
    required this.goalRepo,
  });

  /// 进入本页的 holding(提供 accountId 过滤 + marketValueCents 贡献占比)。
  final Holding holding;

  /// HoldingRepository(调 listInvestmentGoals,跨模块 goal gRPC 透传)。
  final HoldingRepository goalRepo;

  @override
  State<GoalLinkPage> createState() => _GoalLinkPageState();
}

class _GoalLinkPageState extends State<GoalLinkPage> {
  late Future<Either<Failure, List<GoalView>>> _goalsFuture;

  /// holding 是否有效(accountId 非空)。
  /// 有效(从 holding 详情 push extra)→ filter linked_account == holding.accountId;
  /// 空(从 sidebar context.go('/holdings/goals') 无 extra,router 兜底空 Holding)
  ///   → 不 filter,显示全部投资目标(跨账户总览),sub 用通用文案。
  bool get _hasHolding => widget.holding.accountId.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // goal 区数据源:listInvestmentGoals(客户端 filter linked_account)。
    _goalsFuture = widget.goalRepo.listInvestmentGoals();
    // 拉取持仓供关联选择(同账户 holdings 列表)。
    context.read<HoldingBloc>().add(const LoadHoldingsRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: Column(
        children: [
          // 模块内 tab(Task 2 HoldingModuleTabs,投资目标 active 金下划线)。
          // 固定于内容区顶部常驻,不随滚动消失(对齐 Task 3-5 holdings/security/
          // performance 模式)。
          const HoldingModuleTabs(),
          Expanded(
            child: BlocBuilder<HoldingBloc, HoldingState>(
              builder: (context, state) {
                final loaded = _loadedOf(state);
                // holdings loading 且无背景 → 圆圈加载。
                if (state is HoldingLoading && loaded == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state is HoldingError) {
                  // ⏳ 端点 fail(holdings 接口降级)→ holding 选择区降级为空。
                  if (state.isPendingBackend) {
                    return _goalsRegion(const <Holding>[]);
                  }
                  if (loaded == null) return _errorState(state.message);
                }
                final holdings = loaded?.holdings ?? const <Holding>[];
                return _goalsRegion(holdings);
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 从任意 state 取出 HoldingLoaded(从 HoldingError.last / HoldingSubmitting.last
  /// 恢复背景,对齐 holdings_page _loadedOf 模式)。
  HoldingLoaded? _loadedOf(HoldingState state) {
    if (state is HoldingLoaded) return state;
    HoldingState? probe = state;
    while (true) {
      if (probe is HoldingLoaded) return probe;
      if (probe is HoldingError) {
        probe = probe.last;
      } else if (probe is HoldingSubmitting) {
        probe = probe.last;
      } else {
        return null;
      }
      if (probe == null) return null;
    }
  }

  // ───────────────────────── 主内容 ─────────────────────────

  Widget _goalsRegion(List<Holding> holdings) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // ① page-head h1(衬线「投资目标」,对齐 OD .page-title h1 serif 26)。
        _pageHeadTitle(),
        const SizedBox(height: 14),
        // ② + ③ goal 区(FutureBuilder:sub + stat-row + goal 卡片)。
        _goalsFutureRegion(),
        const SizedBox(height: 12),
        // ④ 关联 holding 选择(仅有效 holding:同账户 holdings 渲染;
        //   跨账户总览无 account 上下文,跳过)。
        if (_hasHolding) ...[
          _holdingPickerRegion(holdings),
          const SizedBox(height: 14),
        ],
        // ⑤ 实现说明(account 级 goal + 贡献口径)。
        _implNote(),
      ],
    );
  }

  /// page-head h1(对齐 OD v2 .page-title h1 font-display serif 26px)。
  /// 常驻顶部,sub 与统计放 _goalsFutureRegion(success 分支,需 goals 数据)。
  Widget _pageHeadTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '投资目标',
          key: ValueKey('goalHeaderH1'),
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w600,
            fontFamily: AppTypography.displayFamily,
            fontFamilyFallback: AppTypography.displayFallback,
            color: context.yucai.fg,
            height: 1.15,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }

  // ───────────────────────── goal 区(FutureBuilder) ─────────────────────────

  Widget _goalsFutureRegion() {
    return FutureBuilder<Either<Failure, List<GoalView>>>(
      future: _goalsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _GoalLoading();
        }
        if (snapshot.hasError) {
          return _goalError('加载失败：${snapshot.error}');
        }
        return snapshot.data!.fold(
          (f) => _goalError(f.displayMessage),
          (allInvestmentGoals) {
            // 有效 holding(accountId 非空)→ 客户端 filter linked_account;
            // 空 holding(从 sidebar 进)→ 不 filter,显示全部投资目标(跨账户)。
            final goals = _hasHolding
                ? allInvestmentGoals
                    .where(
                        (g) => g.linkedAccountId == widget.holding.accountId)
                    .toList()
                : allInvestmentGoals;
            if (goals.isEmpty) {
              return _goalEmptyCard();
            }
            return _goalsContent(goals);
          },
        );
      },
    );
  }

  /// goal 区 success 内容(对齐 OD v2 .page-head .sub + .stat-row + .goal-list):
  /// sub 行 + 4 统计卡 + goal 卡片列表。
  Widget _goalsContent(List<GoalView> goals) {
    final over = goals.where((g) => g.progressPct >= 100).length;
    final onTrack = goals
        .where((g) => g.progressPct >= 80 && g.progressPct < 100)
        .length;
    final behind = goals.where((g) => g.progressPct < 80).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ① page-head sub(对齐 OD .page-title .sub;b 元素加粗 fg)。
        _pageSub(goals),
        const SizedBox(height: 16),
        // ② 4 统计卡(总数 / 超目标 / 进行中 / 落后)。
        _statRow(
          total: goals.length,
          over: over,
          onTrack: onTrack,
          behind: behind,
        ),
        const SizedBox(height: 16),
        // ③ goal 卡片列表(对齐 OD .goal-list)。
        for (var i = 0; i < goals.length; i++) ...[
          _goalCard(goals[i]),
          if (i < goals.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }

  /// page-head sub(对齐 OD .page-title .sub;font-size 13 muted,b 加粗 fg)。
  /// 有效 holding → 「持仓市值 vs 目标额 · SYMBOL」;
  /// 空 holding(跨账户)→ 「N 个目标 · 跨账户总览 · 合计 ¥X」(goals 合计 current)。
  Widget _pageSub(List<GoalView> goals) {
    if (_hasHolding) {
      return Text(
        '持仓市值 vs 目标额 · ${widget.holding.securitySymbol}',
        key: const ValueKey('goalHeaderSub'),
        style: TextStyle(fontSize: 13, color: context.yucai.muted),
      );
    }
    // 跨账户合计 current(原币混合时按各自 currentCents 求和;多币种严谨换算
    // 见 holdings_page CurrencyBloc,本页 goals 通常同币种,简化直求和)。
    // GoalView 无 currency 字段(account 级,沿用 holding.currency;空 holding
    // → null → CNY 兜底)。
    final total = goals.fold<int>(0, (s, g) => s + g.currentCents);
    final code = widget.holding.currency ?? 'CNY';
    return DefaultTextStyle(
      key: const ValueKey('goalHeaderSub'),
      style: TextStyle(fontSize: 13, color: context.yucai.muted, height: 1.6),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text('${goals.length} 个目标'),
          const Text('   ·   '),
          const Text('跨账户总览'),
          const Text('   ·   合计 '),
          Text(
            _fmtRaw(total, code),
            style: TextStyle(
              color: context.yucai.fg,
              fontWeight: FontWeight.w600,
              fontFeatures: AppTypography.tabularFigures),
          ),
        ],
      ),
    );
  }

  /// goal 区 loading(对齐 A-od trades-loading,圆圈 + 文案)。
  Widget _goalError(String message) {
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          color: context.yucai.surfaceAlt,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          border: Border.fromBorderSide(BorderSide(color: context.yucai.border)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.alertCircle,
                  key: ValueKey('goalErrorIcon'),
                  size: 26,
                  color: context.yucai.negative),
              const SizedBox(height: 8),
              const Text('加载失败',
                  key: ValueKey('goalErrorTitle'),
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(message,
                  key: const ValueKey('goalErrorMessage'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5, color: context.yucai.muted)),
            ],
          ),
        ),
      ),
    );
  }

  /// goal 列表空态。有效 holding → 「该账户暂无投资目标」;
  /// 空 holding(跨账户)→ 「暂无投资目标」。
  Widget _goalEmptyCard() {
    final title = _hasHolding ? '该账户暂无投资目标' : '暂无投资目标';
    final hint = _hasHolding ? '在目标页新建目标并关联本投资账户' : '在目标页新建目标并关联投资账户';
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28),
        decoration: BoxDecoration(
          color: context.yucai.surfaceAlt,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
          border: Border.fromBorderSide(BorderSide(color: context.yucai.border)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.inbox,
                  key: ValueKey('goalEmptyIcon'),
                  size: 28,
                  color: context.yucai.muted),
              const SizedBox(height: 8),
              Text(title,
                  key: const ValueKey('goalEmptyTitle'),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.yucai.fg)),
              const SizedBox(height: 4),
              Text(hint,
                  key: const ValueKey('goalEmptyHint'),
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 11.5, color: context.yucai.muted)),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── ② stat-row(4 卡,计数中性 + 角标 icon 状态色) ─────────────────────────

  /// 4 统计卡(对齐 OD v2 .stat-row):总数 / 超目标≥100% / 进行中 80-100% / 落后<80%。
  /// **计数中性**:value 用 fg(不染盈亏色);仅角标 icon 染状态色(grey/green/gold/red)。
  /// 窄屏(<600)折 2×2(对齐 OD 移动端 stat-row 折行)。
  Widget _statRow({
    required int total,
    required int over,
    required int onTrack,
    required int behind,
  }) {
    final tiles = <Widget>[
      _statTile(
        key: const ValueKey('goalOverviewTotal'),
        label: '目标总数',
        value: '$total',
        sub: '跨账户汇总',
        cornerIcon: LucideIcons.plus,
        cornerBg: context.yucai.surfaceAlt,
        cornerFg: context.yucai.fg,
      ),
      _statTile(
        key: const ValueKey('goalOverviewOver'),
        label: '超目标 ≥100%',
        value: '$over',
        sub: '已达成 / 超额',
        cornerIcon: LucideIcons.check,
        cornerBg: context.yucai.positive.withValues(alpha: 0.14),
        cornerFg: context.yucai.positive,
      ),
      _statTile(
        key: const ValueKey('goalOverviewOnTrack'),
        label: '进行中',
        value: '$onTrack',
        sub: '80-100% · 按计划',
        cornerIcon: LucideIcons.activity,
        cornerBg: context.yucai.accentSoft,
        cornerFg: context.yucai.accentDeep,
      ),
      _statTile(
        key: const ValueKey('goalOverviewBehind'),
        label: '落后 <80%',
        value: '$behind',
        sub: '需加速投入',
        cornerIcon: LucideIcons.alertTriangle,
        cornerBg: context.yucai.negative.withValues(alpha: 0.14),
        cornerFg: context.yucai.negative,
      ),
    ];
    return LayoutBuilder(
      builder: (ctx, c) {
        final isMobile = c.maxWidth < 600;
        if (isMobile) {
          return Column(
            children: [
              for (var i = 0; i < tiles.length; i += 2) ...[
                Row(
                  children: [
                    Expanded(child: tiles[i]),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: tiles[i + 1]),
                  ],
                ),
                if (i + 2 < tiles.length)
                  const SizedBox(height: AppSpacing.sm),
              ],
            ],
          );
        }
        return Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              Expanded(child: tiles[i]),
              if (i < tiles.length - 1) const SizedBox(width: AppSpacing.sm),
            ],
          ],
        );
      },
    );
  }

  /// 单统计卡(对齐 OD .stat:label 12px muted / value 22px mono tabular 中性 /
  /// sub 11.5px muted;右上角 corner icon 26×26 圆角 7 状态色背景)。
  /// FittedBox 保证窄屏长金额不溢出。
  Widget _statTile({
    required Key key,
    required String label,
    required String value,
    required String sub,
    required IconData cornerIcon,
    required Color cornerBg,
    required Color cornerFg,
  }) {
    return DataCard(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 12, color: context.yucai.muted)),
                const SizedBox(height: 7),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      color: context.yucai.fg,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(sub,
                    style: TextStyle(
                        fontSize: 11.5, color: context.yucai.muted)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // 角标 icon(对齐 OD .stat .corner:26×26 圆角 7,状态色背景 + icon)。
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: cornerBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(cornerIcon, size: 15, color: cornerFg),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── ③ goal 卡(对齐 OD v2 .goal-card) ─────────────────────────

  /// 单个 goal 卡(对齐 OD v2 .goal-card):monogram icon + 名 + sub +
  /// status badge(进行中/落后/超目标)+ 当前/目标 mono + 金进度条%(落后红/超目标绿)+
  /// 贡献占比(仅有效 holding)。
  Widget _goalCard(GoalView g) {
    final pct = g.progressPct.clamp(0, 999).toDouble();
    final pctLabel = pct >= 100
        ? '${pct.toStringAsFixed(0)}%'
        : '${pct.toStringAsFixed(1)}%';
    // GoalView 无 currency 字段(account 级 → 沿用 holding.currency;空 holding
    // → null → CNY 兜底,跨账户合计亦用 CNY 展示)。
    final code = widget.holding.currency ?? 'CNY';
    // 该 holding 对本 goal 的贡献占比 = holding.marketValueCents / goal.targetCents。
    // (account 级:goal.current 已含 Σ 账户 holdings mv;此处拆出该 holding 的份额。)
    final contributionPct = g.targetCents > 0
        ? (widget.holding.marketValueCents / g.targetCents * 100)
            .clamp(0, 999)
            .toStringAsFixed(1)
        : '0.0';
    final isOver = g.progressPct >= 100;
    final isBehind = g.progressPct < 80;
    // 进度条 / pct 染色:落后红 / 超目标绿 / 进行中金(对齐 OD .g-fill/.g-pct)。
    final progressColor = isOver
        ? context.yucai.positive
        : (isBehind ? context.yucai.negative : context.yucai.accent);

    return DataCard(
      key: ValueKey('goalRow-${g.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部:monogram icon + 名/sub + status badge(对齐 OD .g-top)。
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // monogram icon container(对齐 OD .g-icon[t="safety"] gold-soft +
              // 御财金 icon;无 goal type 数据 → 通用 target icon)。
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: context.yucai.accentSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(LucideIcons.target,
                    size: 19, color: context.yucai.accentDeep),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(g.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        key: ValueKey('goalRowName-${g.id}'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback: AppTypography.displayFallback,
                          color: context.yucai.fg,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      _goalCardSub(g),
                      style: TextStyle(
                          fontSize: 11.5, color: context.yucai.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(isOver: isOver, isBehind: isBehind),
            ],
          ),
          const SizedBox(height: 16),
          // 金额行:当前市值 / 目标额 + 大百分比(对齐 OD .g-amts + .g-pct)。
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _amtCell(
                label: '当前市值',
                value: _fmtRaw(g.currentCents, code),
                valueKey: ValueKey('goalRowCurrent-${g.id}'),
                valueColor: context.yucai.fg,
              ),
              const SizedBox(width: 24),
              _amtCell(
                label: '目标额',
                value: _fmtRaw(g.targetCents, code),
                valueKey: ValueKey('goalRowTarget-${g.id}'),
                valueColor: context.yucai.muted,
              ),
              const Spacer(),
              // 大百分比(对齐 OD .g-pct mono 15 w700,落后红/超目标绿/进行中金)。
              Text(pctLabel,
                  key: ValueKey('goalRowPct-${g.id}'),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: progressColor,
                      fontFeatures: AppTypography.tabularFigures)),
            ],
          ),
          const SizedBox(height: 12),
          // 进度条(对齐 OD .g-progress:track 10px 高 + fill gold/red/green)。
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: LinearProgressIndicator(
              key: ValueKey('goalRowBar-${g.id}'),
              value: (pct / 100).clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: context.yucai.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
          // 该 holding 贡献占比(仅有效 holding;跨账户总览无单 holding 贡献口径,
          // 仍保留「已完成」标记)。
          if (_hasHolding || g.isCompleted) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (_hasHolding) ...[
                  Icon(LucideIcons.pieChart,
                      size: 11, color: context.yucai.muted),
                  const SizedBox(width: 4),
                  Text('${widget.holding.securitySymbol} 贡献 ',
                      style: TextStyle(
                          fontSize: 10.5, color: context.yucai.muted)),
                  Text('$contributionPct%',
                      key: ValueKey('goalRowContribution-${g.id}'),
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: context.yucai.accent)),
                  const SizedBox(width: 6),
                ],
                if (g.isCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: context.yucai.positive.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('已完成',
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: context.yucai.positive)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// goal 卡 sub 行(对齐 OD .g-sub:账户 / 风险上下文)。
  /// 有效 holding → 「账户 a1 · 该账户目标」;
  /// 空 holding(跨账户)→ 「跨账户投资目标」。
  String _goalCardSub(GoalView g) {
    if (_hasHolding) {
      return '账户 ${g.linkedAccountId ?? widget.holding.accountId} · 该账户目标';
    }
    final ac = g.linkedAccountId;
    return ac == null || ac.isEmpty
        ? '跨账户投资目标'
        : '账户 $ac · 跨账户投资目标';
  }

  /// status badge(对齐 OD .badge:prog/behind/ahead)。
  /// 超目标≥100% → 绿;落后<80% → 红;进行中 80-100% → 金。
  Widget _statusBadge({required bool isOver, required bool isBehind}) {
    final (label, bg, fg) = isOver
        ? ('超目标', context.yucai.positive.withValues(alpha: 0.14), context.yucai.positive)
        : isBehind
            ? ('落后', context.yucai.negative.withValues(alpha: 0.14), context.yucai.negative)
            : ('进行中', context.yucai.accentSoft, context.yucai.accentDeep);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }

  /// 金额 cell(对齐 OD .g-amts:label 11 muted + value mono 18 w600)。
  Widget _amtCell({
    required String label,
    required String value,
    required Key valueKey,
    required Color valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: TextStyle(fontSize: 11, color: context.yucai.muted)),
        const SizedBox(height: 3),
        Text(value,
            key: valueKey,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                color: valueColor,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }

  // ───────────────────────── ④ 关联 holding 选择 ─────────────────────────

  /// 关联 holding 选择区(对齐 A-od gd-holding-picker):同账户 holdings 渲染,
  /// 供用户参考本账户下其他持仓(本 holding 已选中)。纯展示(无 goal 关联动作,
  /// account 级 goal 按 linked_account 自动归属)。
  Widget _holdingPickerRegion(List<Holding> holdings) {
    final sameAccount = holdings
        .where((h) => h.accountId == widget.holding.accountId)
        .toList();
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.link, size: 14, color: context.yucai.accent),
              const SizedBox(width: 6),
              const Text('同账户持仓',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.yucai.positive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Text('✅ holdings',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: context.yucai.positive)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '账户 ${widget.holding.accountId} 下的持仓(account 级 goal 自动归属)',
            key: const ValueKey('pickerHint'),
            style: TextStyle(fontSize: 11.5, color: context.yucai.muted),
          ),
          const SizedBox(height: 12),
          if (sameAccount.isEmpty)
            _pickerEmpty()
          else
            _holdingList(sameAccount),
        ],
      ),
    );
  }

  Widget _pickerEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        border: Border.fromBorderSide(BorderSide(color: context.yucai.border)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.briefcase,
                key: ValueKey('pickerEmptyIcon'),
                size: 22,
                color: context.yucai.muted),
            SizedBox(height: 6),
            Text('该账户暂无持仓',
                key: ValueKey('pickerEmptyTitle'),
                style: TextStyle(fontSize: 12.5, color: context.yucai.muted)),
          ],
        ),
      ),
    );
  }

  /// holding 列表(对齐 A-od gd-hp-row:symbol/name + 市值 + 当前 holding 标记)。
  Widget _holdingList(List<Holding> holdings) {
    final sorted = [...holdings]
      ..sort((a, b) => b.marketValueCents.compareTo(a.marketValueCents));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          _holdingRow(sorted[i]),
          if (i < sorted.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _holdingRow(Holding h) {
    final code = h.currency ?? 'CNY';
    final typeColor = h.securityType != null
        ? holdingTypeColorOf(context, h.securityType!)
        : context.yucai.accent;
    final typeLabel = h.securityType != null
        ? (kHoldingTypeLabels[h.securityType!] ?? '')
        : '';
    final isCurrent = h.id == widget.holding.id;
    return Container(
      key: ValueKey('holdingRow-${h.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        border: Border.all(
            color: isCurrent ? context.yucai.accent : context.yucai.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: typeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(h.securitySymbol,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            fontFeatures: AppTypography.tabularFigures)),
                    if (typeLabel.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text(typeLabel,
                          style:
                              TextStyle(fontSize: 10.5, color: typeColor)),
                    ],
                    if (isCurrent) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: context.yucai.accentSoft,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('当前',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: context.yucai.accentDeep)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(h.securityName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5, color: context.yucai.muted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_fmtRaw(h.marketValueCents, code),
                  key: ValueKey('holdingRowMv-${h.id}'),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures)),
              Text(code,
                  style: TextStyle(
                      fontSize: 10.5, color: context.yucai.muted)),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── ⑤ 实现说明 ─────────────────────────

  /// 实现说明(对齐 A-od api-note,改 account 级口径)。
  Widget _implNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.yucai.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        key: const ValueKey('apiNote'),
        children: [
          Icon(LucideIcons.info, size: 14, color: context.yucai.accent),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: context.yucai.accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('account 级',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'goal.linked_account_id 关联投资账户,progress 由 server 按 Σ 该账户 holdings mv 计算;贡献占比 = holding.mv / goal.target。',
              style: TextStyle(fontSize: 11.5, color: context.yucai.fg),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 错误空态 ─────────────────────────

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.alertCircle,
                size: 40, color: context.yucai.negative),
            const SizedBox(height: 12),
            const Text('加载失败',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.yucai.muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── helpers ─────────────────────────

  /// 金额 cents 格式化(千分位 + 2 位小数 + 货币符号)。
  String _fmtRaw(int cents, String currencyCode) {
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
}

/// goal 区 loading 占位(对齐 A-od trades-loading)。
class _GoalLoading extends StatelessWidget {
  const _GoalLoading();

  @override
  Widget build(BuildContext context) {
    return DataCard(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
                key: ValueKey('goalLoading'), strokeWidth: 2.5),
            SizedBox(height: 10),
            Text('加载投资目标…',
                key: ValueKey('goalLoadingText'),
                style: TextStyle(fontSize: 12, color: context.yucai.muted)),
          ],
        ),
      ),
    );
  }
}
