/// 报告附注卡(T5,01 章节尾部,原型 .notes-grid):口径说明 / 未包含项
/// 两卡(数据驱动:直接渲染 ReportDocument.overview.notes 列表——
/// 「未包含项」卡在无排除章节时由汇编层自然缺席)。
library;

import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// 附注卡网格(宽屏两列;窄屏单列;单条时占满)。
class ReportNotesGrid extends StatelessWidget {
  const ReportNotesGrid({super.key, required this.notes});

  final List<ReportNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 720 && notes.length > 1;
      final cards = [
        for (final note in notes) _NoteCard(note: note),
      ];
      if (wide) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1)
                const SizedBox(width: AppSpacing.md),
            ],
          ],
        );
      }
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            cards[i],
            if (i < cards.length - 1) const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    });
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final ReportNote note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(note.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.yucai.fg,
              )),
          const SizedBox(height: AppSpacing.sm),
          for (final line in note.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '· $line',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.8,
                  color: context.yucai.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
