// 投资目标关联页(Task 10)。消费 Task 4 HoldingBloc(LoadHoldingsRequested →
// HoldingLoaded.holdings)。
//
// 对齐 A-od 设计源 goal-link-{desktop,tablet,mobile}.html(先读 mobile):
//   ① 概览头(达成统计,3 列紧凑)
//   ② goal 紧凑卡片列表(目标名/状态/进度大数/市值/目标/关联/预计达成)
//   ③ 关联 holding 选择(从 holdings 列 holding 供关联选择,bottom sheet picker)
//   ④ API 标注(⏳ D 待后端)
//
// ⏳D 全空态(本页核心):
//   holding.proto 的 HoldingService 10 RPC 无 goal 相关
//   (CreateSecurity/ListSecurities/UpdatePrice/Search/Buy/Sell/Dividend/Split/
//    ListHoldings/ListHoldingTransactions)。goal 数据是 D 子项目(未来
//   goal.proto)。本页 goal 区无法调真 proto → ⏳D 空态(诚实降级,非 mock):
//     - 概览头:统计数字全显示 ⏳(无 goal 数据)
//     - goal 列表区:空态 + 「⏳D 待后端 · holding-backed goals 数据源待 goal.proto」
//     - 关联 holding 选择:可从 holdings(✅ ListHoldings 已加载)渲染选择器,
//       但「关联到哪个 goal」无 goal 数据 → 选择器存在但目标列表为空。
//
// 空/Loading/Error(BlocBuilder<HoldingBloc,HoldingState>):
//   - HoldingLoading + 无背景 → 圆圈加载。
//   - HoldingError(isPendingBackend) → holdings 也 ⏳ → 整页降级为 ⏳ 空态。
//   - HoldingError(真业务) → 错误文案。
//   - HoldingLoaded → 概览(⏳) + goal 列表(⏳) + holding picker(holdings 渲染)。
//
// 路由:本页由路由层(Task 11)注入 BlocProvider<HoldingBloc>;此处
// context.read<HoldingBloc>().add(LoadHoldingsRequested())。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_pie_chart.dart';

/// 投资目标关联页(holding-backed goals)。对齐 A-od goal-link-*.html。
///
/// ⚠️ holding.proto 无 goal RPC/DTO → 整个 goal 区(概览 + 列表)显示 ⏳D 空态。
/// 仅关联 holding 选择可从已加载 holdings 渲染(但选择后无目标可关联)。
class GoalLinkPage extends StatefulWidget {
  const GoalLinkPage({super.key});

  @override
  State<GoalLinkPage> createState() => _GoalLinkPageState();
}

class _GoalLinkPageState extends State<GoalLinkPage> {
  @override
  void initState() {
    super.initState();
    // 拉取持仓供关联选择(goal 区本身 ⏳D 无数据源)。
    context.read<HoldingBloc>().add(const LoadHoldingsRequested());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.fg,
        elevation: 0,
        title: const Text('投资目标'),
      ),
      body: BlocBuilder<HoldingBloc, HoldingState>(
        builder: (context, state) {
          final loaded = _loadedOf(state);
          // Loading 且无背景 → 圆圈加载。
          if (state is HoldingLoading && loaded == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is HoldingError) {
            // ⏳ 端点 fail(holdings 接口降级)→ 整页 ⏳ 空态。
            if (state.isPendingBackend) {
              return _pendingFullEmpty();
            }
            // 真业务错误:无背景 → 错误空态。
            if (loaded == null) return _errorState(state.message);
          }
          // 主内容:holdings 已加载(或从 last 恢复)。
          // goal 区恒为 ⏳D 空态(无 goal RPC);holding picker 渲染 holdings。
          final holdings = loaded?.holdings ?? const <Holding>[];
          return _content(holdings);
        },
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

  Widget _content(List<Holding> holdings) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        _header(),
        const SizedBox(height: 14),
        // ① 概览头(⏳D 空态:goal 数据无源)。
        _overviewCard(),
        const SizedBox(height: 12),
        // ② goal 列表区(⏳D 空态核心)。
        _goalListRegion(),
        const SizedBox(height: 12),
        // ③ 关联 holding 选择(从 holdings 渲染,goal 无数据)。
        _holdingPickerRegion(holdings),
        const SizedBox(height: 14),
        // ④ API 标注(⏳D)。
        _apiNote(),
      ],
    );
  }

  /// 页面顶部说明(对齐 A-od topbar sub:持仓市值 vs 目标额 · ⏳ D)。
  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Icon(LucideIcons.target, size: 16, color: AppColors.accent),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '持仓市值 vs 目标额 · ⏳ D',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── ① 概览头(⏳D 空态) ─────────────────────────

  /// 概览统计卡(对齐 A-od m-goal-overview 3 列)。
  /// ⏳D:goal 数据无源 → 3 列均显示 ⏳ 占位(总数/超中/落后全无值)。
  Widget _overviewCard() {
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Row(
        children: [
          Expanded(
              child: _overviewCell(
            label: '总数',
            value: '—',
            sub: 'holding-backed',
            key: const ValueKey('goalOverviewTotal'),
          )),
          Container(
              width: 1, height: 36, color: AppColors.border),
          Expanded(
              child: _overviewCell(
            label: '超/中',
            value: '—',
            sub: '达成中',
            key: const ValueKey('goalOverviewOver'),
            valueColor: AppColors.accent,
          )),
          Container(
              width: 1, height: 36, color: AppColors.border),
          Expanded(
              child: _overviewCell(
            label: '落后',
            value: '—',
            sub: '需加码',
            key: const ValueKey('goalOverviewBehind'),
            valueColor: AppColors.negative,
          )),
        ],
      ),
    );
  }

  Widget _overviewCell({
    required String label,
    required String value,
    required String sub,
    Color? valueColor,
    Key? key,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      key: key,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: valueColor ?? AppColors.fg,
                fontFeatures: AppTypography.tabularFigures)),
        const SizedBox(height: 2),
        Text(sub,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
      ],
    );
  }

  // ───────────────────────── ② goal 列表区(⏳D 空态核心) ─────────────────────────

  /// goal 紧凑卡片列表区(对齐 A-od goalCards 容器)。
  /// **本页核心**:proto 无 goal RPC → 恒显示 ⏳D 空态
  /// (hourglass 图标 + 「⏳D 待后端 · holding-backed goals 数据源待 goal.proto」)。
  /// 对齐 Task 8/9 ⏳ 降级模式。
  Widget _goalListRegion() {
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.gem, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              const Text('投资目标',
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
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Text('⏳ D',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentHover)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _pendingGoalEmpty(),
        ],
      ),
    );
  }

  /// ⏳D goal 列表空态(复用 A-od trades-empty / Task 8 _goalCard 样式)。
  Widget _pendingGoalEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.hourglass,
                key: ValueKey('goalPendingIcon'),
                size: 28,
                color: AppColors.accent),
            const SizedBox(height: 8),
            const Text('⏳D 待后端',
                key: ValueKey('goalPendingTitle'),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fg)),
            const SizedBox(height: 4),
            const Text(
              'holding-backed goals 数据源待 goal.proto',
              key: ValueKey('goalPendingHint1'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 2),
            const Text(
              'holding.proto 无 goal RPC · 目标/进度/关联待后端接入',
              key: ValueKey('goalPendingHint2'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── ③ 关联 holding 选择 ─────────────────────────

  /// 关联 holding 选择区(对齐 A-od gd-holding-picker)。
  /// ✅ holdings 已加载(ListHoldings)→ 渲染 holding 列表供关联选择。
  /// ⚠️ 但「关联到哪个 goal」无 goal 数据 → 纯展示可选 holdings,点击触发
  /// 待后端提示(对齐 A-od toast「新建目标 ⏳ D」)。
  Widget _holdingPickerRegion(List<Holding> holdings) {
    return DataCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.link, size: 14, color: AppColors.accent),
              const SizedBox(width: 6),
              const Text('关联持仓选择',
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
                  color: AppColors.positive.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Text('✅ holdings',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.positive)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '可选 holding 列表(✅ ListHoldings)· 关联目标待 goal.proto',
            key: ValueKey('pickerHint'),
            style: TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          if (holdings.isEmpty)
            _pickerEmpty()
          else
            _holdingList(holdings),
        ],
      ),
    );
  }

  Widget _pickerEmpty() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.sm)),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.briefcase,
                key: ValueKey('pickerEmptyIcon'),
                size: 22,
                color: AppColors.muted),
            SizedBox(height: 6),
            Text('暂无可关联持仓',
                key: ValueKey('pickerEmptyTitle'),
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  /// holding 列表(对齐 A-od gd-hp-row:symbol/name + 市值 + 选择提示)。
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
    final typeColor =
        h.securityType != null ? (kHoldingTypeColors[h.securityType!] ?? AppColors.accent) : AppColors.accent;
    final typeLabel = h.securityType != null
        ? (kHoldingTypeLabels[h.securityType!] ?? '')
        : '';
    return InkWell(
      key: ValueKey('holdingRow-${h.id}'),
      onTap: () => _tapHolding(h),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.border),
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
                            style: TextStyle(
                                fontSize: 10.5, color: typeColor)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(h.securityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted)),
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
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _tapHolding(Holding h) {
    // ✅ holdings 数据可用,但 goal 端 ⏳D → 提示关联待后端
    // (对齐 A-od flashToast mock:选择 backing 重算 mock;此处诚实降级)。
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '「${h.securitySymbol}」关联目标 ⏳D 待 goal.proto'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ───────────────────────── ④ API 标注 ─────────────────────────

  /// API 标注(对齐 A-od api-note)。
  Widget _apiNote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        key: const ValueKey('apiNote'),
        children: [
          const Icon(LucideIcons.info, size: 14, color: AppColors.accent),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('⏳ D',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'goal.backing_holding_id ⏳ D;进度/ETA 前端 mock,A-flutter 接后端。',
              style: TextStyle(fontSize: 11.5, color: AppColors.fg),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── 整页 ⏳ / 错误空态 ─────────────────────────

  /// holdings 接口也 ⏳(isPendingBackend)→ 整页降级空态。
  Widget _pendingFullEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.hourglass,
              key: ValueKey('fullPendingIcon'),
              size: 32,
              color: AppColors.accent),
          const SizedBox(height: 10),
          const Text('⏳ 待后端',
              key: ValueKey('fullPendingTitle'),
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('持仓/目标接口尚未接入,稍后再试',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.alertCircle,
                size: 40, color: AppColors.negative),
            const SizedBox(height: 12),
            const Text('加载失败',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
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
