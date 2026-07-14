import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';

/// 单条标签 card:color 圆点 + name + edit/delete icon。复用 DataCard。
class TagCard extends StatelessWidget {
  const TagCard({
    super.key,
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  final Tag tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  Color get _color => Color(int.parse(tag.color.substring(1), radix: 16) + 0xFF000000);

  @override
  Widget build(BuildContext context) {
    return DataCard(
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: _color, shape: BoxShape.circle)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(tag.name, style: const TextStyle(color: AppColors.fg, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          IconButton(tooltip: '编辑', icon: const Icon(LucideIcons.pencil, size: 18, color: AppColors.muted), onPressed: onEdit),
          IconButton(tooltip: '删除', icon: const Icon(LucideIcons.trash2, size: 18, color: AppColors.muted), onPressed: onDelete),
        ],
      ),
    );
  }
}
