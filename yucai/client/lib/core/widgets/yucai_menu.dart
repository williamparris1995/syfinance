import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// v2 卡片操作菜单统一样式（MenuAnchor）。
///
/// 所有卡片「更多」菜单统一走 MenuAnchor 锚定按钮本体 —— 自动翻转/钳制于
/// 窗口内，杜绝手算坐标（F4 前 accounts 卡用陈旧长按锚点导致菜单飞位、
/// debt 卡用底部抽屉在桌面端观感错位）。
MenuStyle yucaiMenuStyle(BuildContext context) {
  return MenuStyle(
    backgroundColor: WidgetStatePropertyAll(context.yucai.surface),
    surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
    shadowColor: const WidgetStatePropertyAll(Color(0x1F000000)),
    elevation: const WidgetStatePropertyAll(6),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    ),
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(36)),
  );
}
