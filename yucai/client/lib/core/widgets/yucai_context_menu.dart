/// 反馈1b:桌面右键场景菜单(共享组件)。
///
/// [YucaiContextMenuRegion] 包住目标面(交易行/账户卡),鼠标右键按下
/// ([GestureDetector.onSecondaryTapDown])即在该位置弹菜单 —— 项数据复用
/// [YucaiMenuItemData](图标/文案/destructive 语义色),渲染走 [showMenu]
/// (自动钳制于窗口内,免手算翻转)+ design-v2 语义令牌(零裸色)。
///
/// 定位注意(F5 前车之鉴,同 accounts_page._showQuickMenu):**必须
/// useRootNavigator: true + 根 Overlay 尺寸** —— 分支 Navigator 的
/// Overlay 原点被侧栏+顶栏偏移,菜单会整体飞位;锚点取本次手势的
///即时 globalPosition,禁用跨触发缓存。
///
/// 作用域(反馈1b 任务书钉死):只挂两类先例面 —— 交易记录行与账户卡;
/// 不铺开全 app。左键交互不受影响(onSecondaryTapDown 只认右键,
/// 不进主键手势竞技场)。
library;

import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/yucai_menu.dart';

/// 右键场景菜单挂载区:右键在指针处弹出 [items]。
class YucaiContextMenuRegion extends StatelessWidget {
  const YucaiContextMenuRegion({
    super.key,
    required this.child,
    required this.items,
  });

  final Widget child;

  /// 菜单项;为空数组时不挂手势(右键无菜单的面零扰动)。
  final List<YucaiMenuItemData> items;

  Future<void> _show(BuildContext context, Offset anchor) async {
    // 根 Overlay:窗口坐标系(分支 Overlay 原点被 chrome 偏移,F5 教训)。
    final overlay = Overlay.of(context, rootOverlay: true)
        .context
        .findRenderObject() as RenderBox;
    final t = context.yucai;
    await showMenu<String>(
      context: context,
      useRootNavigator: true,
      position: RelativeRect.fromLTRB(
        anchor.dx,
        anchor.dy,
        overlay.size.width - anchor.dx,
        overlay.size.height - anchor.dy,
      ),
      // design-v2 令牌:菜单面走主题 popupMenuTheme(AppTheme 配好
      // surface/圆角/黑阴影豁免);项内图标/文案色全部 context.yucai
      // 语义令牌(零裸色)。
      items: [
        for (final item in items)
          PopupMenuItem<String>(
            value: item.label,
            enabled: item.enabled,
            child: Row(children: [
              Icon(item.icon,
                  size: 15,
                  color: item.enabled
                      ? (item.destructive ? t.negative : t.fg)
                      : t.muted),
              const SizedBox(width: 10),
              Text(item.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: item.enabled
                        ? (item.destructive ? t.negative : t.fg)
                        : t.muted,
                  )),
            ]),
          ),
      ],
    ).then((selected) {
      if (selected == null) return;
      items
          .firstWhere((i) => i.label == selected && i.enabled)
          .onTap
          ?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return child;
    return GestureDetector(
      // translucent:子树(行的 InkWell/卡片手势)照常命中,本层只添
      // 右键识别;不进主键竞技场 → 行点击/悬停既有测试零扰动。
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => _show(context, details.globalPosition),
      child: child,
    );
  }
}
