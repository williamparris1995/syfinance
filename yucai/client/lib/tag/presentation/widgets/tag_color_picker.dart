import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/tag/domain/tag_color.dart';

/// 预置色板 7 色(spec §6.3)。选中态:圆点 + check overlay。
class TagColorPicker extends StatelessWidget {
  const TagColorPicker({super.key, required this.selected, required this.onChanged});

  final String selected; // #RRGGBB
  final ValueChanged<String> onChanged;

  static const _colors = <String>[
    '#b08d57', // 金
    '#2e7d32', // 绿
    '#c0392b', // 红
    '#1976d2', // 蓝
    '#7b1fa2', // 紫
    '#f57c00', // 橙
    '#54504a', // 灰
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _colors.map((c) {
        final isSel = c == selected;
        return GestureDetector(
          onTap: () => onChanged(c),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: tagColor(c),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSel ? AppColors.fg : Colors.transparent,
                width: 2,
              ),
            ),
            child: isSel
                ? const Icon(LucideIcons.check, color: Colors.white, size: 16)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
