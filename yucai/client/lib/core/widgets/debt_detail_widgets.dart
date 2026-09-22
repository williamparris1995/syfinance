import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/core/widgets/debt_list_widgets.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';
import 'package:yucai_client/core/widgets/gold_amount.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// 共享的 debt / receivable **详情页** 组件(结构样式两侧完全一致,差异由
/// [DebtViewSemantics] 注入)。包含:
///  - [DebtDetailHero]       深色金渐变 hero(avatar + name + badges + 剩余 + delta + progress + 4-tile side)
///  - [DebtDetailStatsRow]   5-stat 金额维度 grid(借出/借款本金 + 已收/已还合计 + 待收/待还合计 + 累计利息 + 逾期)
///  - [DebtDetailSchedule]   schedule panel(panel-head + sum-pills + filter + 表/卡 + 行内确认)
///  - [DebtDetailSidePanel]  side panel(收款/还款账户卡 + 借款信息卡)
///  - [DebtRecordDialog]     RecordPayment / 确认收款 dialog
///  - 小件:[DebtDashedDivider] / status badge / sum pills
///
/// 同一组件实例 + 不同 [DebtViewSemantics] = debt 与 receivable 详情页结构样式
/// 真正一致(镜像),仅文案/颜色语义不同。
///
/// **F4-P2 色彩豁免清单(hero / preview 固定深色面)**:[DebtDetailHero] 是 OD
/// 原型刻意的固定深色金渐变卡(两主题一致),卡内固定内景色(卡面渐变
/// #1F2126/#24201A/#1C1E21、白系文本、金饰 #D9B97E/#D9B878/#E7DFCA/#F3EFEA、
/// 进度金渐变 #C9A86B/#E0C489)**不随主题迁**——固定深底上亮暗两态均可辨识
/// 且不刺眼;辅助文字走 context.yucai.muted、辉光走 context.yucai.accent
/// (暗色下自动切鎏金)。语义色(pill/badge 半透明底)改由令牌 withValues 派生。
/// 另:schedule 激活 chip 的投影 #1A1C1E21 系深灰黑阴影——暗色墨黑底上天然
/// 不可见,恰好等效 v2 暗色「无阴影」设计(同 debt_list_widgets 豁免口径),
/// 保原值不迁。

// ───────────────────────── Hero ─────────────────────────

/// 深色金渐变 Hero(对齐 OD .hero)。desktop(>1080)双列(heroMain + heroSide 4-tile);
/// tablet/mobile(≤1080)单列(主块在上,4-tile 在下)。
///
/// 两侧共用:剩余应收/本金、delta(减少=绿)、progress、年利率/月供/到期日/已收/已还期数。
/// [badgeLabel] / [avatarColor] / [accountName] 由调用方按自身 subtype 集合与账户缓存推断。
class DebtDetailHero extends StatelessWidget {
  const DebtDetailHero({
    super.key,
    required this.sem,
    required this.debt,
    required this.preferred,
    required this.paidCount,
    required this.total,
    required this.badgeLabel,
    required this.avatarColor,
    this.accountName,
  });

  final DebtViewSemantics sem;
  final Debt debt;
  final String preferred;
  final int paidCount;
  final int total;
  final String badgeLabel;
  final Color avatarColor;
  /// hero-sub「关联账户 X」的账户名;null → 不附「关联账户」段。
  final String? accountName;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w <= 720;
    final isNarrow = w <= 1080;
    final ratio = debt.progressRatio;
    final pct = (ratio * 100).toStringAsFixed(1);
    final isSettled = debt.remainingPrincipalCents <= 0;
    final initial = debt.counterparty.isNotEmpty
        ? debt.counterparty.characters.first
        : '?';

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

    final heroMain = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                          color: Colors.white, // 深金卡固定深底白系(F15/F4-P2 豁免,见文件头)
                          letterSpacing: 0.01,
                          height: 1.15,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback: AppTypography.displayFallback,
                        ),
                      ),
                      _heroBadge(context, badgeLabel),
                      if (isSettled) _heroBadge(context, '已结清 ✓'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${sem.cardMetaLentLabel} ${sharedFmtSymbol(debt.totalPrincipalCents, preferred)} · '
                    '${sharedFmtDate(debt.startDate)} · ${sharedAmortLabel(debt.amortization)} · '
                    '$total 期'
                    '${accountName == null ? '' : ' · 关联账户 $accountName'}',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.yucai.muted,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          sem.detailHeroRemainingLabel,
          style: TextStyle(
            fontSize: 11,
            color: context.yucai.muted,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
        const SizedBox(height: 6),
        GoldAmount(
          key: const ValueKey('heroRemaining'),
          cents: debt.remainingPrincipalCents,
          preferred: preferred,
          curSize: isMobile ? 18 : 28,
          numSize: isMobile ? 34 : 46,
          numWeight: FontWeight.w700,
          numLetterSpacing: -0.4,
          numColor: Colors.white, // 深金卡固定深底白系(F15/F4-P2 豁免,见文件头)
          curColor: const Color(0xFFD9B878),
          numFontFamily: AppTypography.displayFamily,
          numFontFamilyFallback: AppTypography.displayFallback,
        ),
        const SizedBox(height: 11),
        _deltaArea(context, debt.remainingTrendCents),
        const SizedBox(height: 14),
        ClipRRect(
          key: const ValueKey('heroProgress'),
          borderRadius: BorderRadius.circular(9999),
          child: SizedBox(
            width: double.infinity,
            height: 13,
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Color(0xFFC9A86B), Color(0xFFE0C489)],
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 13,
                // 深金卡固定深底白系(F15/F4-P2 豁免,见文件头):
                // 轨道白 12% 半透、值色白(经 ShaderMask 染金渐变)。
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '${sem.detailHeroPaidProgCollected} ${sharedFmtSymbol(debt.totalPrincipalCents - debt.remainingPrincipalCents, preferred)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: context.yucai.muted,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ),
            Flexible(
              child: Text(
                '剩余 ${sharedFmtSymbol(debt.remainingPrincipalCents, preferred)} · ${sem.detailHeroPaidProgRemaining} $pct%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFFE7DFCA),
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final heroSide = _heroSide(context);

    return ClipRRect(
      borderRadius: AppRadius.lgBorder,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 30),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1F2126), Color(0xFF24201A), Color(0xFF1C1E21)],
          ),
        ),
        child: Stack(
          children: [
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
                      context.yucai.accent.withValues(alpha: 0.34),
                      context.yucai.accent.withValues(alpha: 0.06),
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
                      context.yucai.accent.withValues(alpha: 0.13),
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

  /// delta 区:总显「已收回/已还 N/M 期」;trendCents != 0 时附 trend pill(减少=绿)。
  Widget _deltaArea(BuildContext context, int trendCents) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        if (trendCents != 0) _trendPill(context, trendCents),
        Text(
          trendCents != 0
              ? '较上月${trendCents < 0 ? '减少' : '增加'} · ${sem.detailHeroPaidCountLabel} $paidCount / $total 期'
              : '${sem.detailHeroPaidCountLabel} $paidCount / $total 期',
          style: TextStyle(
            fontSize: 12.5,
            color: context.yucai.muted,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ],
    );
  }

  /// trend pill:负=减少=绿 pill ↓;正=增加=红 pill ↑。两侧「剩余减少 = 好 = 绿」同向。
  Widget _trendPill(BuildContext context, int trendCents) {
    final decreasing = trendCents < 0;
    final abs = trendCents.abs();
    // pill 底色由 positive/negative 令牌 20% 派生(原 v1 绿/红 20% 透底),
    // 暗色下跟随主题(暗色 positive/negative 为提亮档)。
    final fg = decreasing ? context.yucai.positive : context.yucai.negative;
    final bg = decreasing
        ? context.yucai.positive.withValues(alpha: 0.20)
        : context.yucai.negative.withValues(alpha: 0.20);
    final icon = decreasing ? LucideIcons.arrowDown : LucideIcons.arrowUp;
    return Container(
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
            sharedFmtSymbol(abs, preferred),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: fg,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  /// hero 右侧 4-tile:年利率 / 月供 / 到期日 / 已收·已还期数。
  Widget _heroSide(BuildContext context) {
    return GridView.count(
      key: const ValueKey('heroSide'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      mainAxisExtent: 72,
      childAspectRatio: 1.55,
      children: [
        _heroTile(context, '年利率', '${(debt.interestRate * 100).toStringAsFixed(2)}%'),
        _heroTile(context, '月供', sharedFmtSymbol(_approxMonthly(debt), preferred)),
        _heroTile(context, '到期日', sharedFmtDate(debt.dueDate)),
        _heroTile(context, sem.isReceivable ? '已收期数' : '已还期数',
            '$paidCount / $total'),
      ],
    );
  }

  Widget _heroTile(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        // 深金卡固定深底白系(F15/F4-P2 豁免,见文件头):tile 白系半透面/描边。
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
            style: TextStyle(
              fontSize: 10.5,
              color: context.yucai.muted,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFFF3EFEA),
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroBadge(BuildContext context, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          // badge 底走主题 accent 22%(亮=翡翠、暗=鎏金,与同卡辉光同源)。
          color: context.yucai.accent.withValues(alpha: 0.22),
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

  /// avatar tile 文字色:类型色浅化(深色 hero 底上可读)。
  static Color _lighten(Color c) {
    final r = c.r;
    final g = c.g;
    final b = c.b;
    final nr = ((r * 255 + (255 - r * 255) * 0.45)).round().clamp(0, 255);
    final ng = ((g * 255 + (255 - g * 255) * 0.45)).round().clamp(0, 255);
    final nb = ((b * 255 + (255 - b * 255) * 0.45)).round().clamp(0, 255);
    return Color.fromARGB(255, nr, ng, nb);
  }

  /// 近似月供(Debt 实体无 monthly 字段;摊还方法粗估)。
  static int _approxMonthly(Debt debt) {
    if (debt.amortization == AmortizationMethod.lumpSum) {
      return debt.totalPrincipalCents;
    }
    final months = (debt.dueDate.year - debt.startDate.year) * 12 +
        (debt.dueDate.month - debt.startDate.month);
    if (months <= 0) return 0;
    return debt.totalPrincipalCents ~/ months;
  }
}

// ───────────────────────── 5-stat StatsRow ─────────────────────────

/// 从 [DebtDetail] 的 schedule 聚合 5 张金额维度 stat 卡(两侧共用 = 镜像):
///  本金 / 已收·已还合计 / 待收·待还合计 / 累计利息收入·还息 / 逾期应收·应付。
/// 颜色语义由 [DebtViewSemantics.interestIncomeColor] / [pendingPrincipalColor] 决定。
///
/// F4-P2:语义色经 context.yucai 解析(顶层函数无 context → 补形参穿线;
/// 调用点:debt/receivable detail 页,签名变化一次性改调用点)。
List<DebtStatCardData> buildDebtDetailStats(
    BuildContext context, DebtDetail detail, String preferred, DebtViewSemantics sem) {
  final debt = detail.debt;
  final schedule = detail.schedule;
  final paidPrincipal =
      schedule.where((e) => e.paid).fold<int>(0, (s, e) => s + e.principalCents);
  final paidInterest =
      schedule.where((e) => e.paid).fold<int>(0, (s, e) => s + e.interestCents);
  final paidTotal = paidPrincipal + paidInterest;
  final unpaidEntries = schedule.where((e) => !e.paid);
  final pendingPrincipal =
      unpaidEntries.fold<int>(0, (s, e) => s + e.principalCents);
  final pendingInterest =
      unpaidEntries.fold<int>(0, (s, e) => s + e.interestCents);
  final pendingTotal = pendingPrincipal + pendingInterest;
  final overdueEntries =
      schedule.where((e) => e.status == PaymentStatus.overdue && !e.paid);
  final overdueTotal = overdueEntries.fold<int>(0, (s, e) => s + e.totalCents);
  final overdueCount = overdueEntries.length;
  final daysOverdue = overdueEntries.isEmpty
      ? 0
      : DateTime.now().difference(overdueEntries.first.paymentDate).inDays;
  final overdueSub =
      overdueCount > 0 ? '$overdueCount 期 · 逾期 $daysOverdue 天' : '无逾期';
  final paidBreakdown = sem.statPaidBreakdownPattern
      .replaceAll('{p}', sharedFmtSymbol(paidPrincipal, preferred))
      .replaceAll('{i}', sharedFmtSymbol(paidInterest, preferred));
  final pendingBreakdown = sem.statPendingBreakdownPattern
      .replaceAll('{p}', sharedFmtSymbol(pendingPrincipal, preferred))
      .replaceAll('{i}', sharedFmtSymbol(pendingInterest, preferred));

  return <DebtStatCardData>[
    DebtStatCardData(
      label: sem.statPrincipalLabel,
      icon: LucideIcons.banknote,
      value: sharedFmtSymbol(debt.totalPrincipalCents, preferred),
      sub: '${sharedFmtDate(debt.startDate)} 放款',
    ),
    DebtStatCardData(
      label: sem.statPaidTotalLabel,
      icon: LucideIcons.check,
      value: sharedFmtSymbol(paidTotal, preferred),
      sub: paidBreakdown,
      valueColor: context.yucai.positive,
    ),
    DebtStatCardData(
      label: sem.statPendingTotalLabel,
      icon: LucideIcons.clock,
      value: sharedFmtSymbol(pendingTotal, preferred),
      sub: pendingBreakdown,
      // 语义描述符解析:neutral(receivable)→ null 回落默认 fg;
      // negative(debt 负债压力)→ context.yucai.negative。
      valueColor: sem.pendingPrincipalColor.resolve(context),
    ),
    DebtStatCardData(
      label: sem.statInterestLabel,
      icon: LucideIcons.trendingUp,
      value: sharedFmtSymbol(paidInterest, preferred),
      sub: '年化 ${(debt.interestRate * 100).toStringAsFixed(2)}%',
      valueColor: paidInterest > 0
          ? sem.interestIncomeColor.resolve(context)
          : null,
    ),
    DebtStatCardData(
      label: sem.statOverdueTotalLabel,
      icon: LucideIcons.alertCircle,
      value: sharedFmtSymbol(overdueTotal, preferred),
      sub: overdueSub,
      valueColor: overdueCount > 0 ? context.yucai.negative : null,
    ),
  ];
}

class DebtStatCardData {
  const DebtStatCardData({
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
  final Color? valueColor;
}

/// 5 StatCards 金额维度 grid(对齐 OD .stats grid 5 列)。desktop 5 列 / tablet-mobile 2 列。
/// 调用方构建 5 个 [DebtStatCardData](本金 / 已收·已还合计 / 待收·待还合计 / 累计利息 / 逾期)。
class DebtDetailStatsRow extends StatelessWidget {
  const DebtDetailStatsRow({super.key, required this.stats});
  final List<DebtStatCardData> stats;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isTablet = w <= 900;
    return GridView.count(
      key: const ValueKey('statsRow'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 2 : 5,
      mainAxisSpacing: 13,
      crossAxisSpacing: 13,
      mainAxisExtent: 140,
      children: [for (final s in stats) _StatCard(data: s)],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});
  final DebtStatCardData data;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(data.icon, size: 13, color: context.yucai.accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(data.label,
                    style: TextStyle(
                        fontSize: 11.5, color: context.yucai.muted)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.01,
                color: data.valueColor ?? context.yucai.fg,
                fontFeatures: AppTypography.tabularFigures,
              )),
          const SizedBox(height: 4),
          Text(data.sub,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  color: context.yucai.muted,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

// ───────────────────────── Schedule ─────────────────────────

/// schedule 筛选枚举(全部/待收·待还/已收·已还/逾期)。
enum DebtScheduleFilter { all, pending, paid, overdue }

/// schedule section(panel-head + sum-pills + filter + 表/卡 + 行内确认)。
///
/// 行内确认(D4):[collectionAccountId] 非空 → [onConfirmInline] 直接 dispatch(无 dialog);
/// 否则 → [onOpenDialog] 弹 dialog。两侧同结构,文案/颜色由 [sem] 注入。
class DebtDetailSchedule extends StatefulWidget {
  const DebtDetailSchedule({
    super.key,
    required this.sem,
    required this.schedule,
    required this.debt,
    required this.preferred,
    required this.isMobile,
    required this.collectionAccountId,
    required this.onConfirmInline,
    required this.onOpenDialog,
    // 单期改日(Google-Calendar 式):非空时未还期次的日期可点改。已还期次冻结。
    this.onEditDate,
    // 标记已还(历史还款,不记账):非空时未还期次显示「标记已还」副动作。
    this.onMarkPaid,
    // 不再提醒(催办挂失):非空时未还期次显示「不再提醒」副动作,
    // 未还清也可停掉本期催办(2026-09 催办模式)。
    this.onDismissReminder,
    // 批量标记已还:非空时显示「多选」入口(仅可选过去未还期次)。
    this.onMarkPaidBatch,
  });

  final DebtViewSemantics sem;
  final List<PaymentEntry> schedule;
  final Debt debt;
  final String preferred;
  final bool isMobile;
  final String? collectionAccountId;
  final void Function(PaymentEntry entry) onConfirmInline;
  final void Function(PaymentEntry entry) onOpenDialog;
  final ValueChanged<PaymentEntry>? onEditDate;
  final ValueChanged<PaymentEntry>? onMarkPaid;
  final ValueChanged<List<PaymentEntry>>? onMarkPaidBatch;
  final ValueChanged<PaymentEntry>? onDismissReminder;

  @override
  State<DebtDetailSchedule> createState() => _DebtDetailScheduleState();
}

class _DebtDetailScheduleState extends State<DebtDetailSchedule> {
  DebtScheduleFilter _filter = DebtScheduleFilter.all;
  bool _selecting = false; // 多选模式(批量标记已还)
  final Set<String> _selectedIds = <String>{};

  /// 多选/批量标记操作行:进入多选 → 勾选过去未还期次 → 批量标记。
  Widget _batchBar(BuildContext context) {
    final markableAll = _filtered.where(_markable).toList();
    final selectedEntries = widget.schedule
        .where((e) => _selectedIds.contains(e.id))
        .toList();
    return Row(
      children: [
        TextButton.icon(
          key: const ValueKey('batchSelectToggle'),
          onPressed: () => setState(() {
            _selecting = !_selecting;
            _selectedIds.clear();
          }),
          icon: Icon(_selecting ? LucideIcons.x : LucideIcons.listChecks,
              size: 13, color: context.yucai.muted),
          label: Text(_selecting ? '取消多选' : '多选标记'),
          style: TextButton.styleFrom(
            foregroundColor: context.yucai.muted,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: const Size(0, 26),
            textStyle: const TextStyle(fontSize: 11.5),
          ),
        ),
        if (_selecting) ...[
          TextButton(
            onPressed: markableAll.isEmpty
                ? null
                : () => setState(() => _selectedIds
                    ..clear()
                    ..addAll(markableAll.map((e) => e.id))),
            child: Text('全选可标(${markableAll.length})'),
            style: TextButton.styleFrom(
              foregroundColor: context.yucai.accentDeep,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(0, 26),
              textStyle: const TextStyle(fontSize: 11.5),
            ),
          ),
          const Spacer(),
          FilledButton.icon(
            key: const ValueKey('batchMarkPaidButton'),
            onPressed: selectedEntries.isEmpty || widget.onMarkPaidBatch == null
                ? null
                : () {
                    widget.onMarkPaidBatch!(selectedEntries);
                    setState(() {
                      _selecting = false;
                      _selectedIds.clear();
                    });
                  },
            icon: const Icon(LucideIcons.flag, size: 13),
            label: Text('标记已还(${selectedEntries.length})'),
            style: FilledButton.styleFrom(
              backgroundColor: context.yucai.accent,
              foregroundColor: context.yucai.onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              minimumSize: const Size(0, 28),
              textStyle: const TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ],
    );
  }

  void _toggleSelect(PaymentEntry e) => setState(() {
        _selectedIds.contains(e.id)
            ? _selectedIds.remove(e.id)
            : _selectedIds.add(e.id);
      });

  /// 「过去时间」判定:严格早于今天零点(未来期次不可标已还)。
  bool _isPast(PaymentEntry e) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return e.paymentDate.isBefore(today);
  }

  /// 可批量标记的期次:未还 且 已过去。
  bool _markable(PaymentEntry e) =>
      !e.paid && _isPast(e);

  List<PaymentEntry> get _filtered => switch (_filter) {
        DebtScheduleFilter.all => widget.schedule,
        DebtScheduleFilter.pending =>
          widget.schedule.where((e) => e.status == PaymentStatus.pending).toList(),
        DebtScheduleFilter.paid =>
          widget.schedule.where((e) => e.status == PaymentStatus.paid).toList(),
        DebtScheduleFilter.overdue => widget.schedule
            .where((e) => e.status == PaymentStatus.overdue)
            .toList(),
      };

  @override
  Widget build(BuildContext context) {
    final sem = widget.sem;
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          widget.isMobile
              ? Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 10,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _panelTitle(sem),
                        const SizedBox(height: 9),
                        _sumPills(widget.schedule, sem),
                      ],
                    ),
                    _filterSegmented(sem),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _panelTitle(sem),
                          const SizedBox(height: 9),
                          _sumPills(widget.schedule, sem),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _filterSegmented(sem),
                  ],
                ),
          const SizedBox(height: 8),
          if (widget.onMarkPaidBatch != null) _batchBar(context),
          const SizedBox(height: 6),
          if (_filtered.isEmpty)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text('该筛选下无期次',
                    style: TextStyle(color: context.yucai.muted, fontSize: 12)),
              ),
            )
          else if (widget.isMobile)
            _scheduleCardList()
          else
            _scheduleTable(),
        ],
      ),
    );
  }

  Widget _panelTitle(DebtViewSemantics sem) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(sem.scheduleTitleIcon, size: 17, color: context.yucai.accent),
        const SizedBox(width: 8),
        Text(sem.scheduleTitle,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback)),
      ],
    );
  }

  Widget _sumPills(List<PaymentEntry> schedule, DebtViewSemantics sem) {
    final paid = schedule.where((e) => e.status == PaymentStatus.paid).length;
    final pending =
        schedule.where((e) => e.status == PaymentStatus.pending).length;
    final overdue =
        schedule.where((e) => e.status == PaymentStatus.overdue).length;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        _pill(sem.sumPaidLabel, paid, context.yucai.positive, context.yucai.positive.withValues(alpha: 0.10)),
        _pill(sem.sumPendingLabel, pending, context.yucai.muted,
            context.yucai.surfaceAlt),
        _pill(sem.statusOverdueLabel, overdue, context.yucai.negative,
            context.yucai.negative.withValues(alpha: 0.10)),
      ],
    );
  }

  Widget _pill(String label, int count, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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

  Widget _filterSegmented(DebtViewSemantics sem) {
    final paid =
        widget.schedule.where((e) => e.status == PaymentStatus.paid).length;
    final pending =
        widget.schedule.where((e) => e.status == PaymentStatus.pending).length;
    final overdue =
        widget.schedule.where((e) => e.status == PaymentStatus.overdue).length;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        border: Border.all(color: context.yucai.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _filterSeg(DebtScheduleFilter.all, '全部', widget.schedule.length, sem),
          _filterSeg(DebtScheduleFilter.pending, sem.sumPendingLabel, pending, sem),
          _filterSeg(DebtScheduleFilter.paid, sem.sumPaidLabel, paid, sem),
          _filterSeg(DebtScheduleFilter.overdue, sem.statusOverdueLabel, overdue,
              sem),
        ],
      ),
    );
  }

  Widget _filterSeg(
      DebtScheduleFilter f, String label, int count, DebtViewSemantics sem) {
    final active = _filter == f;
    final fg = active ? context.yucai.fg : context.yucai.muted;
    return InkWell(
      key: ValueKey('filterSegment-$label'),
      onTap: () => setState(() => _filter = f),
      borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
            horizontal: widget.isMobile ? 10 : 13, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          // 激活 chip 底 = 抬升 surface(亮=白 / 暗=卡面浅一档;原硬白在暗色
          // 下过亮)。黑阴影豁免(暗底不可见 = v2 暗色无阴影),见文件头豁免清单。
          color: active ? context.yucai.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm - 2),
          boxShadow: active
              ? [
                  const BoxShadow(
                    color: Color(0x1A1C1E21),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                color: fg,
              ),
            ),
            if (!widget.isMobile) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  // 未激活 count pill 底:原 #10000000(黑 6%)→ fg 6% 派生,
                  // 暗色下呈微亮底(黑透底在墨黑面上不可辨识)。
                  color: active
                      ? context.yucai.accentSoft
                      : context.yucai.fg.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    color: active ? context.yucai.accentDeep : context.yucai.muted,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _scheduleTable() {
    final sem = widget.sem;
    final entries = _filtered;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: context.yucai.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Table(
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: FlexColumnWidth(1.6),
            1: FlexColumnWidth(1),
            2: FlexColumnWidth(1),
            3: FlexColumnWidth(1),
            4: IntrinsicColumnWidth(),
            5: IntrinsicColumnWidth(),
          },
          children: [
            TableRow(
              decoration: BoxDecoration(
                color: context.yucai.surfaceAlt,
                border: Border(bottom: BorderSide(color: context.yucai.border)),
              ),
              children: [
                _tableHeader(sem.tableCol1Header, align: TextAlign.left),
                _tableHeader(sem.tableCol2Header, align: TextAlign.right),
                _tableHeader(sem.tableCol3Header, align: TextAlign.right),
                _tableHeader('合计', align: TextAlign.right),
                _tableHeader('状态', align: TextAlign.left),
                _tableHeader('操作', align: TextAlign.right),
              ],
            ),
            for (var i = 0; i < entries.length; i++)
              _scheduleRow(entries[i], i + 1, entries.length),
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
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w600,
            color: context.yucai.muted,
            fontFeatures: AppTypography.tabularFigures,
          )),
    );
  }

  /// 期次日期单元格:未还且 onEditDate 非空 → 可点改日(带小铅笔);
  /// 已还/回调为空 → 纯文本。
  Widget _dateCell(PaymentEntry e, DebtViewSemantics sem,
      {String? label, double fontSize = 12}) {
    final text = label ?? sharedFmtDate(e.paymentDate);
    final editable = widget.onEditDate != null && !e.paid;
    final style = TextStyle(
        fontSize: fontSize,
        color: context.yucai.muted,
        fontFeatures: AppTypography.tabularFigures);
    if (!editable) return Text(text, overflow: TextOverflow.ellipsis, style: style);
    return InkWell(
      key: ValueKey('editDate-${e.id}'),
      onTap: () => widget.onEditDate!(e),
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
                child: Text(text,
                    overflow: TextOverflow.ellipsis, style: style)),
            const SizedBox(width: 3),
            Icon(LucideIcons.pencilLine,
                size: 12, color: context.yucai.accent),
          ],
        ),
      ),
    );
  }

  TableRow _scheduleRow(PaymentEntry e, int idx, int total) {
    final isLast = idx == total;
    final isOverdue = e.status == PaymentStatus.overdue && !e.paid;
    final isPaid = e.paid;
    // 行分隔线 = 语义 border(原 v1 米白 #EFECE5 硬编码,暗色下会刺眼)。
    final border = BorderSide(color: context.yucai.border);
    final rowBg = isPaid
        ? context.yucai.surface
        : (isOverdue ? context.yucai.surface : null);
    final cellFg = isPaid ? context.yucai.muted : context.yucai.fg;
    final sem = widget.sem;
    return TableRow(
      decoration: BoxDecoration(
        color: rowBg,
        border: isLast ? null : Border(bottom: border),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Row(
            children: [
              Text('$idx',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isOverdue ? context.yucai.negative : cellFg,
                      fontFeatures: AppTypography.tabularFigures)),
              const SizedBox(width: 6),
              // Flexible:窄列(平板)下日期文本省略而非溢出(铅笔图标占位)。
              Flexible(child: _dateCell(e, sem)),
            ],
          ),
        ),
        _cellRight(sharedFmtSymbol(e.principalCents, widget.preferred),
            color: cellFg, bold: true),
        _cellRight(sharedFmtSymbol(e.interestCents, widget.preferred),
            color: cellFg),
        _cellRight(sharedFmtSymbol(e.totalCents, widget.preferred),
            color: isOverdue ? context.yucai.negative : cellFg, bold: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: _statusBadge(e, sem),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Align(
            alignment: Alignment.centerRight,
            child: _scheduleAction(e),
          ),
        ),
      ],
    );
  }

  Widget _cellRight(String text, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Text(text,
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
            color: color,
            fontFeatures: AppTypography.tabularFigures,
          )),
    );
  }

  Widget _scheduleCardList() {
    final entries = _filtered;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          _scheduleCard(entries[i], i + 1),
          if (i < entries.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _scheduleCard(PaymentEntry e, int idx) {
    final sem = widget.sem;
    final status = e.status;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        // 逾期卡底/描边 = negative 令牌 3%/20% 派生(原 v1 红 3%/20% 透底),
        // 暗色下跟随主题(暗色 negative 为提亮档,可辨识且不刺眼)。
        color: status == PaymentStatus.overdue
            ? context.yucai.negative.withValues(alpha: 0.03)
            : context.yucai.surface,
        border: Border.all(
            color: status == PaymentStatus.overdue
                ? context.yucai.negative.withValues(alpha: 0.20)
                : context.yucai.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: _dateCell(e, sem,
                    label: '第 $idx 期 · ${sharedFmtDate(e.paymentDate)}',
                    fontSize: 13),
              ),
              _statusBadge(e, sem),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                  child: _cardAmtCell(sem.tableCol2Header,
                      sharedFmtSymbol(e.principalCents, widget.preferred))),
              Expanded(
                  child: _cardAmtCell(sem.tableCol3Header,
                      sharedFmtSymbol(e.interestCents, widget.preferred))),
              Expanded(
                  child: _cardAmtCell(
                      '合计', sharedFmtSymbol(e.totalCents, widget.preferred),
                      total: true)),
            ],
          ),
          const SizedBox(height: 10),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(k, style: TextStyle(fontSize: 11, color: context.yucai.muted)),
        const SizedBox(height: 2),
        Text(v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: total ? FontWeight.w600 : FontWeight.w400,
                color: context.yucai.fg,
                fontFeatures: AppTypography.tabularFigures)),
      ],
    );
  }

  Widget _statusBadge(PaymentEntry e, DebtViewSemantics sem) {
    // badge 底 = positive/negative 令牌 10% 派生(原 v1 绿/红 10% 透底)。
    final (label, fg, bg, icon) = switch (e.status) {
      PaymentStatus.paid => (
          sem.statusPaidLabel,
          context.yucai.positive,
          context.yucai.positive.withValues(alpha: 0.10),
          LucideIcons.check
        ),
      PaymentStatus.pending => (
          sem.statusPendingLabel,
          context.yucai.muted,
          context.yucai.surfaceAlt,
          null
        ),
      PaymentStatus.overdue => (
          sem.statusOverdueLabel,
          context.yucai.negative,
          context.yucai.negative.withValues(alpha: 0.10),
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

  /// 操作列:已收·已还 → 「已确认/已结清」;待收·待还/逾期 → 行内确认(collection
  /// 已配置)或 dialog fallback。
  Widget _scheduleAction(PaymentEntry e) {
    final sem = widget.sem;
    // 多选模式:可标(过去未还)期次显示复选框,其余占位。
    if (_selecting) {
      if (!_markable(e)) return const SizedBox.shrink();
      return Checkbox(
        key: ValueKey('select-${e.id}'),
        value: _selectedIds.contains(e.id),
        onChanged: (_) => setState(() => _toggleSelect(e)),
      );
    }
    if (e.paid) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(sem.isReceivable ? LucideIcons.check : LucideIcons.check,
              size: 12, color: context.yucai.positive),
          const SizedBox(width: 4),
          Text(sem.schedulePaidLabel,
              style: TextStyle(fontSize: 11, color: context.yucai.muted)),
        ],
      );
    }
    final overdue = e.status == PaymentStatus.overdue;
    final hasCollection = widget.collectionAccountId != null &&
        widget.collectionAccountId!.isNotEmpty;
    final onPressed = hasCollection
        ? () => widget.onConfirmInline(e)
        : () => widget.onOpenDialog(e);
    // Wrap(非 Row):主/副按钮在窄列(平板 table cell)自动换行,避免溢出。
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.end,
      children: [
        TextButton.icon(
      onPressed: onPressed,
      // F27 FR-1② 豁免:逾期确认按钮底为 negative 状态身份彩底 —— 图标/前景
      // 固定白(双板可辨识);非逾期档走 accentDeep 语义。
      icon: Icon(LucideIcons.check,
          size: 12, color: overdue ? Colors.white : context.yucai.accentDeep),
      label: Text(sem.scheduleActionLabel),
      style: overdue
          ? TextButton.styleFrom(
              backgroundColor: context.yucai.negative,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 26),
              textStyle: const TextStyle(fontSize: 11),
            )
          : TextButton.styleFrom(
              foregroundColor: context.yucai.accentDeep,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(0, 26),
              textStyle: const TextStyle(fontSize: 11),
            ),
        ),
        if (widget.onMarkPaid != null && _markable(e))
          TextButton.icon(
            key: ValueKey('markPaid-${e.id}'),
            onPressed: () => widget.onMarkPaid!(e),
            icon: Icon(LucideIcons.flag,
                size: 12, color: context.yucai.muted),
            label: const Text('标记已还'),
            style: TextButton.styleFrom(
              foregroundColor: context.yucai.muted,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: const Size(0, 26),
              textStyle: const TextStyle(fontSize: 11),
            ),
          ),
        if (widget.onDismissReminder != null && !e.paid)
          TextButton.icon(
            key: ValueKey('dismissReminder-${e.id}'),
            onPressed: () => widget.onDismissReminder!(e),
            icon: Icon(LucideIcons.bellOff,
                size: 12, color: context.yucai.muted),
            label: const Text('不再提醒'),
            style: TextButton.styleFrom(
              foregroundColor: context.yucai.muted,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              minimumSize: const Size(0, 26),
              textStyle: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Side Panel ─────────────────────────

class DebtSideRowData {
  const DebtSideRowData({
    required this.k,
    required this.v,
    this.mono = false,
    this.valueColor,
    this.onTap,
  });
  final String k;
  final String v;
  final bool mono;
  final Color? valueColor;
  final VoidCallback? onTap;
}

/// side panel(对齐 OD .side-card):收款·还款账户卡 + 借款信息卡。
/// desktop(>1080)与 main Row 并列;mobile/窄屏追加到下方。
/// 两侧同结构,文案/标签由 [sem] 注入。账户名/尾号由调用方 lookup 传入。
class DebtDetailSidePanel extends StatelessWidget {
  const DebtDetailSidePanel({
    super.key,
    required this.sem,
    required this.debt,
    required this.preferred,
    required this.collectionName,
    required this.collectionTail,
    required this.receivableName,
    this.attachmentName,
    this.onOpenAttachment,
  });

  final DebtViewSemantics sem;
  final Debt debt;
  final String preferred;
  /// 收款·还款账户名(lookup 自账户缓存);null → 「未设置」。
  final String? collectionName;
  /// 收款·还款账户尾号;null → 不显「账户尾号」行。
  final String? collectionTail;
  /// 应收·负债账户名;null → 「—」。
  final String? receivableName;
  /// 合同文件名(本地附件 v1;null = 无附件,不显「合同文件」行)。
  final String? attachmentName;
  /// 打开合同文件(详情页提供:store 绝对路径 + url_launcher)。
  final VoidCallback? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final collectionRows = <DebtSideRowData>[
      DebtSideRowData(k: sem.sideCollectionToLabel, v: collectionName ?? '未设置'),
      if (collectionTail != null)
        DebtSideRowData(
            k: '账户尾号', v: '**** $collectionTail', mono: true),
      DebtSideRowData(k: sem.sideReceivableAccountLabel, v: receivableName ?? '—'),
    ];

    final hasContact = debt.contact.isNotEmpty;
    final contractRef = debt.contractRef;
    final hasContract = contractRef.isNotEmpty;
    final contractDisplay = hasContract
        ? (RegExp(r'\.[A-Za-z0-9]{2,5}$').hasMatch(contractRef)
            ? contractRef
            : '$contractRef.pdf')
        : '—';
    final loanRows = <DebtSideRowData>[
      DebtSideRowData(k: sem.sideCounterpartyLabel, v: debt.counterparty),
      DebtSideRowData(
          k: '联系方式',
          v: hasContact ? debt.contact : '—',
          mono: true,
          onTap: hasContact ? () => _launchTel(context, debt.contact) : null),
      // 担保人(2026-09 用户需求):可选字段,空 → 「—」占位行保持面板
      // 信息密度一致;联系方式非空时可点拨号(与上联系方式行同语义)。
      DebtSideRowData(k: '担保人', v: debt.guarantorName.isEmpty ? '—' : debt.guarantorName),
      DebtSideRowData(
          k: '担保人联系方式',
          v: debt.guarantorContact.isEmpty ? '—' : debt.guarantorContact,
          mono: true,
          onTap: debt.guarantorContact.isNotEmpty
              ? () => _launchTel(context, debt.guarantorContact)
              : null),
      DebtSideRowData(k: sem.sideLentDateLabel, v: sharedFmtDate(debt.startDate), mono: true),
      DebtSideRowData(k: '到期日期', v: sharedFmtDate(debt.dueDate), mono: true),
      DebtSideRowData(k: '摊还方法', v: sharedAmortLabel(debt.amortization)),
      DebtSideRowData(
        k: '合同/借据',
        v: contractDisplay,
        valueColor: hasContract ? context.yucai.accentDeep : null,
        onTap: hasContract ? () => _viewContract(context, contractRef) : null,
      ),
      // 合同文件(本地附件 v1):有附件才显示;点击由页面回调打开落盘文件。
      if (attachmentName != null)
        DebtSideRowData(
          k: '合同文件',
          v: attachmentName!,
          valueColor: context.yucai.accentDeep,
          onTap: onOpenAttachment,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DataCard(
          key: const ValueKey('sideCollectionCard'),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sideHeader(context, sem.sideCollectionIcon,
                  sem.sideCollectionCardTitle),
              const SizedBox(height: 14),
              _sideRows(context, collectionRows),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => AppToast.show(context, sem.sideRegisterToast,
                    type: ToastType.warning),
                icon: const Icon(LucideIcons.plus, size: 14),
                label: Text(sem.sideRegisterBtnLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.yucai.fg,
                  backgroundColor: context.yucai.surface,
                  side: BorderSide(color: context.yucai.border),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  minimumSize: const Size.fromHeight(34),
                  textStyle: const TextStyle(
                      fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        DataCard(
          key: const ValueKey('sideLoanCard'),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sideHeader(context, LucideIcons.info, '借款信息'),
              const SizedBox(height: 14),
              _sideRows(context, loanRows),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sideHeader(BuildContext context, IconData icon, String title) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: context.yucai.accent),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.yucai.fg,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback,
            )),
      ],
    );
  }

  Widget _sideRows(BuildContext context, List<DebtSideRowData> rows) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          _sideRow(context, rows[i]),
          if (i < rows.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 0),
              child: DebtDashedDivider(),
            ),
        ],
      ],
    );
  }

  Widget _sideRow(BuildContext context, DebtSideRowData data) {
    final valueText = Text(
      data.v,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: data.valueColor ?? context.yucai.fg,
        decoration: data.onTap != null ? TextDecoration.underline : null,
        // 下划线色 = accentDeep(原 AppColors.accentHover,亮值同 #047857)。
        decorationColor: data.valueColor ?? context.yucai.accentDeep,
        fontFamily: data.mono ? AppTypography.displayFamily : null,
        fontFamilyFallback: data.mono ? AppTypography.displayFallback : null,
        fontFeatures: AppTypography.tabularFigures,
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(data.k,
                style: TextStyle(fontSize: 13, color: context.yucai.muted)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: data.onTap == null
                ? valueText
                : InkWell(
                    onTap: data.onTap,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: valueText,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchTel(BuildContext context, String contact) async {
    final uri = Uri.parse('tel:$contact');
    try {
      final ok = await launchUrl(uri);
      if (!ok) {
        if (context.mounted) {
          AppToast.show(context, '拨打 $contact(无 tel handler,请手动)',
              type: ToastType.warning);
        }
      }
    } catch (_) {
      if (context.mounted) {
        AppToast.show(context, '拨打 $contact(系统不支持 tel:)',
            type: ToastType.warning);
      }
    }
  }

  Future<void> _viewContract(BuildContext context, String contractRef) async {
    final isUrl = Uri.tryParse(contractRef)?.hasAbsolutePath == true &&
        (contractRef.startsWith('http://') ||
            contractRef.startsWith('https://') ||
            contractRef.startsWith('file://'));
    if (isUrl) {
      try {
        final ok = await launchUrl(Uri.parse(contractRef));
        if (!ok && context.mounted) {
          AppToast.show(context, '无法打开合同链接', type: ToastType.warning);
        }
      } catch (_) {
        if (context.mounted) {
          AppToast.show(context, '无法打开合同链接', type: ToastType.warning);
        }
      }
    } else if (context.mounted) {
      AppToast.show(context, '查看合同「$contractRef」待接入',
          type: ToastType.warning);
    }
  }
}

/// side panel 行间 dashed 分隔线(对齐 OD .rl border-bottom:1px dashed)。
class DebtDashedDivider extends StatelessWidget {
  const DebtDashedDivider({
    super.key,
    this.color,
    this.dashWidth = 4,
    this.gapWidth = 3,
  });

  /// 虚线色;null → build 内解析 context.yucai.border(F4-P2:const 构造默认值
  /// 取不到 context,改可空 + 语义令牌回落;显式传色调用点不受影响)。
  final Color? color;
  final double dashWidth;
  final double gapWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _DashedLinePainter(
        color: color ?? context.yucai.border,
        dashWidth: dashWidth,
        gapWidth: gapWidth,
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter({
    required this.color,
    required this.dashWidth,
    required this.gapWidth,
  });
  final Color color;
  final double dashWidth;
  final double gapWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + dashWidth).clamp(0, size.width), 0),
        paint,
      );
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.dashWidth != dashWidth ||
      oldDelegate.gapWidth != gapWidth;
}

// ───────────────────────── RecordPayment / 确认收款 dialog ─────────────────────────

/// RecordPayment / 确认收款 dialog(对齐 OD .modal):金额(只读 amount-box)+
/// 账户下拉 + 确认。两侧同结构,文案由 [sem] 注入。
class DebtRecordDialog extends StatefulWidget {
  const DebtRecordDialog({
    super.key,
    required this.sem,
    required this.entry,
    required this.accounts,
    required this.preferred,
    required this.onSubmit,
  });

  final DebtViewSemantics sem;
  final PaymentEntry entry;
  final List<Account> accounts;
  final String preferred;
  final void Function(String accountId) onSubmit;

  @override
  State<DebtRecordDialog> createState() => _DebtRecordDialogState();
}

class _DebtRecordDialogState extends State<DebtRecordDialog> {
  late String _selectedAccountId;

  @override
  void initState() {
    super.initState();
    _selectedAccountId =
        widget.accounts.isNotEmpty ? widget.accounts.first.id : '';
  }

  @override
  Widget build(BuildContext context) {
    final sem = widget.sem;
    return AlertDialog(
      title: Text(sem.dialogTitle),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sem.dialogAmountLabel,
                style: TextStyle(fontSize: 12, color: context.yucai.muted)),
            const SizedBox(height: 7),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.yucai.accentSoft,
                border: Border.all(color: context.yucai.accentSoft),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Text(
                    sharedFmtSymbol(widget.entry.totalCents, widget.preferred),
                    style: TextStyle(
                        color: context.yucai.accent,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AppTypography.tabularFigures),
                  ),
                  const Spacer(),
                  Text(
                      '期次 · ${sharedFmtDate(widget.entry.paymentDate)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: context.yucai.accentDeep,
                          fontFeatures: AppTypography.tabularFigures)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(sem.dialogAccountLabel,
                style: TextStyle(fontSize: 12, color: context.yucai.muted)),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              value: _selectedAccountId.isEmpty ? null : _selectedAccountId,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide(color: context.yucai.border),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: widget.accounts.isEmpty
                  ? const [
                      DropdownMenuItem(
                        value: '',
                        child: Text('无可用账户'),
                      )
                    ]
                  : [
                      for (final a in widget.accounts)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text(
                              '${a.name}（余额 ${_fmtBalance(a.currentBalanceCents, a.currencyCode)}）'),
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
            backgroundColor: context.yucai.accent,
            // F27 FR-1①:accent 面提交按钮前景 → onAccent(暗=金底深墨)。
            foregroundColor: context.yucai.onAccent,
          ),
          child: Text(sem.dialogSubmitLabel),
        ),
      ],
    );
  }

  static String _fmtBalance(int cents, String currencyCode) {
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
