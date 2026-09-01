import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/theme/app_theme.dart';

/// F5c:复现用户报告的「更多菜单漂移」。
///
/// 用户环境:Windows 125% 缩放(AppliedDPI=120, DPR=1.25)。若 MenuAnchor
/// 的定位在 DPR≠1 下存在系统偏差,本测试在 1.25 下应可确定性重现,
/// 并作为修复的回归守卫。
void main() {
  Future<Rect> pumpAndMeasure(
    WidgetTester t, {
    required double dpr,
    required Size logicalSize,
  }) async {
    t.view.devicePixelRatio = dpr;
    t.view.physicalSize = Size(
      logicalSize.width * dpr,
      logicalSize.height * dpr,
    );
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    const buttonKey = ValueKey('moreBtn');
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.dark(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.center,
          child: MenuAnchor(
            style: MenuStyle(
              backgroundColor:
                  const WidgetStatePropertyAll(Color(0xFF141922)),
              fixedSize: const WidgetStatePropertyAll(Size(160, 0)),
            ),
            menuChildren: const [
              MenuItemButton(child: Text('编辑')),
              MenuItemButton(child: Text('删除账户')),
            ],
            builder: (context, controller, child) => FilledButton(
              key: buttonKey,
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              child: const Text('更多'),
            ),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    final btnRect = t.getRect(find.byKey(buttonKey));
    await t.tap(find.byKey(buttonKey));
    await t.pumpAndSettle();

    // 菜单打开后取「编辑」条目的位置(菜单面板的第一个可见元素)。
    final itemRect = t.getRect(find.text('编辑'));

    // ignore: avoid_print
    print('DPR=$dpr logical=$logicalSize');
    // ignore: avoid_print
    print('  button: $btnRect');
    // ignore: avoid_print
    print('  menuItem(编辑): $itemRect');
    // ignore: avoid_print
    print('  offset(item - button): ${itemRect.topLeft - btnRect.topLeft}');
    return itemRect;
  }

  testWidgets('DPR 1.0: menu opens adjacent to the button', (t) async {
    final itemRect = await pumpAndMeasure(
      t,
      dpr: 1.0,
      logicalSize: const Size(1280, 720),
    );
    final btnRect = t.getRect(find.byKey(const ValueKey('moreBtn')));
    // 菜单应在按钮附近(同一屏内、垂直方向在按钮下方附近或上方翻转)。
    expect((itemRect.center - btnRect.center).distance, lessThan(300));
  });

  testWidgets('DPR 1.25 (用户环境): menu opens adjacent to the button',
      (t) async {
    final itemRect = await pumpAndMeasure(
      t,
      dpr: 1.25,
      logicalSize: const Size(1280, 720),
    );
    final btnRect = t.getRect(find.byKey(const ValueKey('moreBtn')));
    expect((itemRect.center - btnRect.center).distance, lessThan(300));
  });

  testWidgets('DPR 1.25 + 2560x1440 full window: menu adjacent to button',
      (t) async {
    final itemRect = await pumpAndMeasure(
      t,
      dpr: 1.25,
      logicalSize: const Size(2048, 1152),
    );
    final btnRect = t.getRect(find.byKey(const ValueKey('moreBtn')));
    expect((itemRect.center - btnRect.center).distance, lessThan(300));
  });
}
