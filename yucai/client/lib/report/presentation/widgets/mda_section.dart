/// F44 T3 「诊断与建议」第七章节(FR-4;原型 v8 #ch-7)。
///
/// 形态照 prototype v8:三计数 chip(0 风险/N 提示/M 关注)→ 按 severity
/// 分组(风险>warn>info,引擎已排序;空组不渲染组头)→ 每条 Finding 卡
/// = 严重度图标 + 结论 + 建议 + (actionLink)「前往订阅中心 →」跳转按钮;
/// 零发现 = 居中健康卡(通过项摘要从 doc 取数:储蓄率/资产负债率)。
///
/// 语义色零新令牌(NFR-3/ADR-4):risk→negative / warn→warn / info→
/// info(图标)/中性(尾 chip),全部走 context.yucai。文案直出
/// Finding.conclusion/advice 字符串(widget 不重算)。
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// severity 展示映射(原型 v8:风险/提示/关注;mda presentation 共用,
/// mda_summary_card.dart 复用)。
extension MdaSeverityUi on MdaSeverity {
  /// 中文级别名(chip/组头用)。
  String get label => switch (this) {
        MdaSeverity.risk => '风险',
        MdaSeverity.warn => '提示',
        MdaSeverity.info => '关注',
      };

  /// 图标(risk=八角警 / warn=三角警 / info=i)。
  IconData get icon => switch (this) {
        MdaSeverity.risk => LucideIcons.octagonAlert,
        MdaSeverity.warn => LucideIcons.triangleAlert,
        MdaSeverity.info => LucideIcons.info,
      };
}

/// 「诊断与建议」章节体(挂报告页 _chapters 链第七章;doc.mda null 时
/// 由页面侧整章缺席,本组件恒收到非空 section)。
class MdaChapter extends StatelessWidget {
  const MdaChapter({super.key, required this.section, required this.doc});

  /// 诊断章节模型(findings 已按 severity 排序 + 三级计数)。
  final MdaSection section;

  /// 报告快照(健康态通过项摘要取数:储蓄率/资产负债率)。
  final ReportDocument doc;

  @override
  Widget build(BuildContext context) {
    if (section.findings.isEmpty) return _HealthyCard(doc: doc);

    final groups = <MdaSeverity, List<MdaFinding>>{
      for (final s in MdaSeverity.values) s: <MdaFinding>[],
    };
    for (final f in section.findings) {
      groups[f.severity]!.add(f);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 章节头三计数 chip(原型 .ch-head 内 chip ×3)。
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _CountChip(count: section.riskCount, severity: MdaSeverity.risk),
            _CountChip(count: section.warnCount, severity: MdaSeverity.warn),
            _CountChip(count: section.infoCount, severity: MdaSeverity.info),
          ],
        ),
        // 分组列表:空组不渲染组头(原型 .f-group 语义)。
        for (final s in MdaSeverity.values)
          if (groups[s]!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('${s.label} · ${groups[s]!.length}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2,
                  color: context.yucai.muted,
                )),
            const SizedBox(height: AppSpacing.sm),
            for (final f in groups[s]!)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md - 2),
                child: _FindingCard(finding: f),
              ),
          ],
      ],
    );
  }
}

/// 三计数 chip(count>0 → severity 色调;0 → 中性描边,照原型 .chip 默认态)。
class _CountChip extends StatelessWidget {
  const _CountChip({required this.count, required this.severity});

  final int count;
  final MdaSeverity severity;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    final color = severityColor(context, severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.yucai.border),
      ),
      child: Text(
        '$count ${severity.label}',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: active ? color : context.yucai.muted,
          fontFeatures: AppTypography.tabularFigures,
        ),
      ),
    );
  }
}

/// 单条 Finding 卡(原型 .fcard:严重度图标 + 结论/建议 + 尾 severity chip)。
class _FindingCard extends StatelessWidget {
  const _FindingCard({required this.finding});

  final MdaFinding finding;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(context, finding.severity);
    final link = finding.actionLink;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(finding.severity.icon, size: 16, color: color),
          ),
          const SizedBox(width: AppSpacing.md - 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finding.conclusion,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: context.yucai.fg,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  finding.advice,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    color: context.yucai.muted,
                  ),
                ),
                if (link != null) ...[
                  const SizedBox(height: AppSpacing.sm + 2),
                  GestureDetector(
                    key: const ValueKey('mdaActionLink'),
                    onTap: () => context.push(link),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Text(
                        '前往订阅中心 →',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: context.yucai.accent,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _SeverityChip(severity: finding.severity),
        ],
      ),
    );
  }
}

/// 尾部 severity 标签 chip(risk/warn 色调,info 中性;原型 .chip.warn)。
class _SeverityChip extends StatelessWidget {
  const _SeverityChip({required this.severity});

  final MdaSeverity severity;

  @override
  Widget build(BuildContext context) {
    final tinted = severity != MdaSeverity.info;
    final color = severityColor(context, severity);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: tinted ? color.withValues(alpha: 0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: context.yucai.border),
      ),
      child: Text(
        severity.label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: tinted ? color : context.yucai.muted,
        ),
      ),
    );
  }
}

/// 零发现健康卡(原型 .ch7-healthy:居中 ✓ 圆徽 + 标题 + 通过项摘要行)。
///
/// 通过项摘要从 doc 取数(渲染层零计算):储蓄率 = overview.savingsRate;
/// 资产负债率 = balanceSheet.debtRatioPct(资产合计 ≤ 0 → null,该段
/// 省略)。「现金可支撑月数」依赖 MdaSupplement(trailing3m/cashEnd),
/// 不在 ReportDocument 契约内(T2 已定稿,不碰 domain)——遗留台账:
/// 待后续票给 mda 增健康摘要字段后补第三段。
class _HealthyCard extends StatelessWidget {
  const _HealthyCard({required this.doc});

  final ReportDocument doc;

  @override
  Widget build(BuildContext context) {
    final ratio = doc.balanceSheet.debtRatioPct;
    final passed = [
      '储蓄率 ${doc.overview.savingsRate.toStringAsFixed(1)}%',
      if (ratio != null) '资产负债率 ${ratio.toStringAsFixed(1)}%',
    ].join('、');
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.yucai.positive.withValues(alpha: 0.12),
            ),
            child: Icon(LucideIcons.check,
                size: 20, color: context.yucai.positive),
          ),
          const SizedBox(height: AppSpacing.sm + 2),
          Text('本期诊断未发现需关注项',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.yucai.fg,
              )),
          const SizedBox(height: 6),
          Text(
            '$passed,均在健康区间',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: context.yucai.muted,
            ),
          ),
        ],
      ),
    );
  }
}

/// severity → 语义色(ADR-4,零新令牌):risk→negative / warn→warn /
/// info→info;调用方自行决定 info 的中性降级处(chip)。mda presentation
/// 共用(mda_summary_card.dart 复用)。
Color severityColor(BuildContext context, MdaSeverity severity) =>
    switch (severity) {
      MdaSeverity.risk => context.yucai.negative,
      MdaSeverity.warn => context.yucai.warn,
      MdaSeverity.info => context.yucai.info,
    };
