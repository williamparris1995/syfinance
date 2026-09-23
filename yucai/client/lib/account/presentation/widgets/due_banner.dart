/// 首页到期聚合条 DueBanner(2026-09 到期常显提醒 T3,spec FR-1/2/3/7 +
/// design LLD「DueBanner 布局契约」):账户页净资产 hero 上方的被动常显层。
///
/// **纯展示 + 回调式**:候选列表与三个动作回调由宿主注入,本 widget 不做
/// 导航/对话框/数据订阅(数据订阅在 accounts_page,直达动作在宿主接线),
/// 便于 widget 测试与跨宿主复用。
///
/// - 空态(候选空)→ [SizedBox.shrink],不渲染不占位(hero 回到顶部原位)。
/// - 收起态(默认):callout 行范式(照 design-v2 callout.warn 提示卡:色
///   10% 混 surface 软底 + 30% 描边 + 12 圆角),左侧色条 + 聚合文案 +
///   展开指示箭头;文案「⏰ N 笔待还 · 最近 X 天后」,存在逾期时逾期子句
///   前置「M 笔已逾期 D 天 · 共 K 笔待还 · 最近 X 天后」(spec 逾期优先)。
/// - 展开态(点击收起条切换):明细行列表,每行 = [色条] 名称 · ¥金额 ·
///   「X 天后到期/逾期 N 天」,行点击按 target 类型分派回调;尾「查看全部」
///   文字钮 → onViewAll。
/// - 着色承 F37 桶约定,与 `core/widgets/debt_list_widgets.dart`
///   `_dueUrgencyDecor`/`DebtCardFootCallout` 取**同一批语义令牌**:
///   逾期/≤7 天 = `context.yucai.negative`(红),≤15 天 = `context.yucai.warn`
///   (黄);收起条按最紧条目档,明细行各自档。零裸色(NFR-2)。
/// - 宽窄屏同构(NFR-3):单一布局,行内 Expanded + 省略号自适应,无两态
///   分叉(照 SeparatedRow 弹性范式)。
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// F37 桶 → 语义色:逾期/≤7 天红(negative)、≤15 天黄(warn)。
/// 与 debt_list_widgets._dueUrgencyDecor 同一批 `context.yucai` 令牌;
/// >15 天仅在 advanceDays 超出配置面(≤15)时可达,accent 兜底零裸色。
Color _bucketColor(BuildContext context, int daysLeft) {
  if (daysLeft <= 7) return context.yucai.negative;
  if (daysLeft <= 15) return context.yucai.warn;
  return context.yucai.accent;
}

/// 到期措辞:「X 天后到期 / 今日到期 / 逾期 N 天」(与写侧 policy.compose
/// 同词形,复用 [DueCandidateView.daysLeft] 口径,不另算差值)。
String _dueWording(int daysLeft) {
  if (daysLeft < 0) return '逾期 ${-daysLeft} 天';
  if (daysLeft == 0) return '今日到期';
  return '$daysLeft 天后到期';
}

/// 聚合文案:无逾期「⏰ N 笔待还 · 最近 X 天后」;有逾期时逾期子句前置
/// 「M 笔已逾期 D 天 · 共 K 笔待还」+ 最近子句(全逾期时无最近)。
/// X = 最小非负 daysLeft(0 → 「今日到期」),D = 最大逾期天数。
String dueBannerSummary(List<DueCandidateView> candidates) {
  final overdue =
      candidates.where((c) => c.daysLeft < 0).map((c) => -c.daysLeft);
  final future = candidates.where((c) => c.daysLeft >= 0).map((c) => c.daysLeft);
  final nearest = future.isEmpty ? null : future.reduce(math.min);
  final when = nearest == null
      ? ''
      : ' · ${nearest == 0 ? '今日到期' : '最近 $nearest 天后'}';
  if (overdue.isEmpty) {
    return '⏰ ${candidates.length} 笔待还$when';
  }
  final maxOverdue = overdue.reduce(math.max);
  return '⏰ ${overdue.length} 笔已逾期 $maxOverdue 天'
      ' · 共 ${candidates.length} 笔待还$when';
}

class DueBanner extends StatefulWidget {
  const DueBanner({
    super.key,
    required this.candidates,
    required this.onOpenCard,
    required this.onOpenDebt,
    required this.onViewAll,
  });

  /// 窗口内候选(宿主订阅 [DueCandidateProvider.stream] 注入)。
  final List<DueCandidateView> candidates;

  /// 信用卡条目直达:唤起该卡还款对话框(宿主按 accountId 查账户对象)。
  final ValueChanged<AccountTarget> onOpenCard;

  /// 债务期次条目直达:跳该债务详情页。
  final ValueChanged<DebtTarget> onOpenDebt;

  /// 「查看全部」→ 收件箱(/inbox)。
  final VoidCallback onViewAll;

  @override
  State<DueBanner> createState() => _DueBannerState();
}

class _DueBannerState extends State<DueBanner> {
  /// 默认收起(spec FR-2)。
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.candidates.isEmpty) return const SizedBox.shrink();
    // 最紧条目档 = 最小 daysLeft(逾期为负,恒最紧)。
    final tightest =
        widget.candidates.map((c) => c.daysLeft).reduce(math.min);
    final tone = _bucketColor(context, tightest);
    // callout.warn 同族软底:色 10% 混 surface(callout 范式,零新 hex)。
    final soft = Color.alphaBlend(
        tone.withValues(alpha: 0.10), context.yucai.surface);
    return Container(
      key: const ValueKey('dueBanner'),
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withValues(alpha: 0.30)),
      ),
      // IntrinsicHeight:让左侧色条(Container 无内在高度)得以 stretch 到
      // 内容列高 —— 本条常驻无限高滚动列,外层 Row 直接 stretch 会向子级
      // 强推无穷高度约束,故先以内在高度封顶(IntrinsicHeight 标准用法)。
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧色条:最紧条目档着色(design LLD「行背景/左侧色条按最紧档」)。
            Container(
              key: const ValueKey('dueBannerSideBar'),
              width: 4,
              color: tone,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _summaryRow(context),
                  if (_expanded) ...[
                    for (var i = 0; i < widget.candidates.length; i++)
                      _detailRow(context, widget.candidates[i],
                          isFirst: i == 0),
                    _viewAllRow(context),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 收起态聚合行(展开态即本行的列表头):点击切换展开/收起。
  Widget _summaryRow(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: const ValueKey('dueBannerSummaryRow'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _expanded = !_expanded),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 8, 9),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  dueBannerSummary(widget.candidates),
                  maxLines: 2, // 窄屏允许折行(同构自适应)
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.fg,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 展开指示箭头(展开时向上)。
              Transform.rotate(
                angle: _expanded ? math.pi : 0,
                child: Icon(LucideIcons.chevronDown,
                    size: 16, color: context.yucai.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 展开态明细行:[行色条] 名称 · ¥金额 · 到期措辞(着色同桶);
  /// 点击按 target 类型分派(ADR-2 sealed 穷尽)。
  Widget _detailRow(BuildContext context, DueCandidateView c,
      {required bool isFirst}) {
    final tone = _bucketColor(context, c.daysLeft);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        key: ValueKey('dueBannerRow-${c.entryKey}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          final target = c.target;
          switch (target) {
            case AccountTarget():
              widget.onOpenCard(target);
            case DebtTarget():
              widget.onOpenDebt(target);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                  color: isFirst
                      ? context.yucai.border
                      : context.yucai.border.withValues(alpha: 0.5)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
          child: Row(
            children: [
              // 行色条:该条目自身档着色(F37 桶)。
              Container(width: 3, height: 18, color: tone),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.yucai.fg,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                    children: [
                      // 名称(可省略,窄屏自适应)。
                      TextSpan(
                        text: c.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      // 金额:与写侧通知文案同源 money 工具(千分位两位)。
                      TextSpan(
                          text:
                              ' · ¥${DueReminderPolicy.formatYuan(c.amountCents)}'),
                      // 到期措辞:按桶着色(逾期/≤7 红,≤15 黄)。
                      TextSpan(
                        text: ' · ${_dueWording(c.daysLeft)}',
                        style: TextStyle(
                          color: tone,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 展开态尾「查看全部」文字钮 → onViewAll(/inbox 入口,FR-7)。
  Widget _viewAllRow(BuildContext context) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
      child: TextButton(
        key: const ValueKey('dueBannerViewAll'),
        onPressed: widget.onViewAll,
        style: TextButton.styleFrom(
          foregroundColor: context.yucai.accentDeep,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: const Size(0, 0),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        child: const Text('查看全部 ›'),
      ),
    );
  }
}
