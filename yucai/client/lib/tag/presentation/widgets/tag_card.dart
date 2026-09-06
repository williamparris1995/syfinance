import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/tag_color.dart';

/// 单条标签 card:color 圆点 + name + edit/delete icon。复用 DataCard。
///
/// [onOpen](F8 FR-3):整卡 tap 回调(跳交易列表带 tagId 反查);null = 不可
/// 点(编辑/删除按钮不受影响,命中测试在图标自身)。
class TagCard extends StatelessWidget {
  const TagCard({
    super.key,
    required this.tag,
    required this.onEdit,
    required this.onDelete,
    this.onOpen,
  });

  final Tag tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// 整卡 tap(F8 FR-3 标签反查入口);null = 无跳转语义。
  final VoidCallback? onOpen;

  /// 标签色:#RRGGBB 解析,失败回退主题 accent(F4-P2:fallback 注入令牌)。
  Color _color(BuildContext context) => tagColor(tag.color,
      fallback: context.yucai.accent);

  @override
  Widget build(BuildContext context) {
    return DataCard(
      onTap: onOpen,
      child: Row(
        children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: _color(context), shape: BoxShape.circle)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(tag.name, style: TextStyle(color: context.yucai.fg, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          IconButton(tooltip: '编辑', icon: Icon(LucideIcons.pencil, size: 18, color: context.yucai.muted), onPressed: onEdit),
          IconButton(tooltip: '删除', icon: Icon(LucideIcons.trash2, size: 18, color: context.yucai.muted), onPressed: onDelete),
        ],
      ),
    );
  }
}
