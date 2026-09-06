import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';

/// 单条备份卡片：filename + auto/encrypted chips + size·date + 恢复/删除 icon。
/// 复用 DataCard（白底/圆角/阴影/hover）。对齐御财 list 卡片模式（_BudgetCard）。
class BackupCard extends StatelessWidget {
  const BackupCard({
    super.key,
    required this.backup,
    required this.onRestore,
    required this.onDelete,
  });

  final Backup backup;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return DataCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  backup.filename,
                  style: TextStyle(
                    color: context.yucai.fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (backup.auto || backup.encrypted) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (backup.auto) _chip(context, '自动'),
                      if (backup.encrypted) _chip(context, '加密'),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${backup.sizeDisplay} · ${_fmtDate(backup.createdAt)}',
                  style: TextStyle(color: context.yucai.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '恢复',
            icon: Icon(LucideIcons.rotateCcw,
                size: 18, color: context.yucai.muted),
            onPressed: onRestore,
          ),
          IconButton(
            tooltip: '删除',
            icon: Icon(LucideIcons.trash2,
                size: 18, color: context.yucai.muted),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.yucai.accentSoft,
        borderRadius: AppRadius.smBorder,
      ),
      child: Text(
        label,
        style: TextStyle(color: context.yucai.fg, fontSize: 11),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '--';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
