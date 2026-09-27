/// F44 T3 总览诊断摘要卡(原型 v8 .diag-card,两态)。
///
/// 有发现(任何 risk/warn/info > 0)= 计数头「诊断摘要 · N 风险 N 提示
/// N 关注」+「基于本期数据」chip + top-3 结论行(findings 序)+「查看
/// 全部 ↓」锚滚到第七章节([onViewAll] 由报告页接 _scrollTo(诊断章索引));
/// 零发现 = 单行健康徽章(pos-soft 底 + ✓ 圆点 + 计数文案)。
///
/// 语义色同 mda_section.dart(risk→negative/warn→warn/info→info,零新
/// 令牌);结论直出 Finding.conclusion(widget 不重算)。
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/presentation/widgets/mda_section.dart'
    show MdaSeverityUi, severityColor;

/// 总览摘要卡(插总览章节 sum-strip 后、附注卡前)。
class MdaSummaryCard extends StatelessWidget {
  const MdaSummaryCard({super.key, required this.section, required this.onViewAll});

  /// 诊断章节模型(吃 counts + top3,LLD 契约)。
  final MdaSection section;

  /// 「查看全部」锚滚回调(报告页滚到第七章节)。
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (section.findings.isEmpty) return _HealthyBadge(section: section);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '诊断摘要 · ${section.riskCount} 风险 '
                '${section.warnCount} 提示 ${section.infoCount} 关注',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.yucai.fg,
                ),
              ),
              const Spacer(),
              Text('基于本期数据',
                  style: TextStyle(fontSize: 11.5, color: context.yucai.muted)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: context.yucai.border),
          // top-3(按 findings 序;结论主行 + 建议副行,原型 .diag-row 的
          // diag-t/diag-s 双行形态,各单行截断)。
          for (var i = 0; i < section.findings.length && i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SevIcon(severity: section.findings[i].severity),
                  const SizedBox(width: AppSpacing.md - 2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          section.findings[i].conclusion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.yucai.fg,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          section.findings[i].advice,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.yucai.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Divider(height: 1, color: context.yucai.border),
          const SizedBox(height: AppSpacing.sm + 2),
          GestureDetector(
            key: const ValueKey('mdaViewAllLink'),
            onTap: onViewAll,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                '查看全部 ↓',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: context.yucai.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 零发现单行健康徽章(原型 .diag-ok:pos-soft 底 + ✓ 圆点 + 计数文案)。
class _HealthyBadge extends StatelessWidget {
  const _HealthyBadge({required this.section});

  final MdaSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 12),
      decoration: BoxDecoration(
        color: context.yucai.positive.withValues(alpha: 0.10),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: context.yucai.positive,
            ),
            child: Icon(LucideIcons.check,
                size: 14, color: context.yucai.onAccent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '本期诊断:${section.riskCount} 风险 ${section.warnCount} 提示 '
              '${section.infoCount} 关注 · 未发现需关注项 ✓',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: context.yucai.fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 严重度小图标(32×32 圆角,severity 语义色 13% 底;与第七章节同映射)。
class _SevIcon extends StatelessWidget {
  const _SevIcon({required this.severity});

  final MdaSeverity severity;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(context, severity);
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(severity.icon, size: 16, color: color),
    );
  }
}
