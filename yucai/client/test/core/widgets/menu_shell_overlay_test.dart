import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/theme/app_theme.dart';

/// F5d 回归守卫:复现「壳层(侧栏+分支 Navigator)+ 卡片更多菜单」的环境,
/// 无头验证菜单必须贴着触发按钮弹出,而不是飞进左侧栏区域。
///
/// 背景:MenuAnchor.useRootOverlay:true 时,菜单渲染进根 Overlay,但锚点
/// 矩形按最近 Overlay 坐标系计算(OverlayPortal 的 childPaintTransform 不
/// 跨分支 Navigator 边界)→ 菜单整体左上飞进侧栏区。修复后统一用最近
/// Overlay(锚点+菜单同坐标系,自洽)。
void main() {
  const sidebarWidth = 236.0;
  const topbarHeight = 60.0;

  Future<Rect> pumpShellAndMeasure(
    WidgetTester t, {
    required bool useRootOverlay,
  }) async {
    t.view.devicePixelRatio = 1.0;
    t.view.physicalSize = const Size(1280, 720);
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    const buttonKey = ValueKey('moreBtn');
    await t.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Row(children: [
          // 侧栏(236px)
          Container(
            width: sidebarWidth,
            color: Colors.white,
            child: const Center(child: Text('侧栏')),
          ),
          // 内容区:顶栏 + 分支 Navigator(自带 Overlay,模拟壳层分支)
          Expanded(
            child: Column(children: [
              Container(height: topbarHeight, color: Colors.white),
              Expanded(
                child: Navigator(
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => Center(
                      child: MenuAnchor(
                        style: MenuStyle(
                          backgroundColor: const WidgetStatePropertyAll(
                              Color(0xFF141922)),
                          fixedSize:
                              const WidgetStatePropertyAll(Size(160, 0)),
                        ),
                        useRootOverlay: useRootOverlay,
                        menuChildren: const [
                          MenuItemButton(child: Text('编辑')),
                          MenuItemButton(child: Text('删除账户')),
                        ],
                        builder: (context, controller, child) => FilledButton(
                          key: buttonKey,
                          onPressed: () => controller.isOpen
                              ? controller.close()
                              : controller.open(),
                          child: const Text('更多'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    ));
    await t.pumpAndSettle();

    final btnRect = t.getRect(find.byKey(buttonKey));
    await t.tap(find.byKey(buttonKey));
    await t.pumpAndSettle();
    return t.getRect(find.text('编辑'));
  }

  Rect sidebarRegion(Rect r) =>
      Rect.fromLTWH(0, 0, sidebarWidth, r.bottom + 10);

  group('壳层内卡片菜单定位(F5d 回归守卫)', () {
    for (final useRoot in [true, false]) {
      testWidgets(
          'useRootOverlay=$useRoot: 菜单贴按钮,不飞进侧栏区',
          (t) async {
        final itemRect = await pumpShellAndMeasure(t, useRootOverlay: useRoot);
        final btnRect =
            t.getRect(find.byKey(const ValueKey('moreBtn')));

        // 菜单条目不得落入侧栏区域(x ≥ 236)。
        expect(
          itemRect.left >= sidebarWidth - 1,
          true,
          reason: 'useRootOverlay=$useRoot: 菜单 x=${itemRect.left} '
              '落入侧栏(0..$sidebarWidth) —— 跨 Overlay 坐标系脱节',
        );
        // 菜单应与按钮同屏相邻(水平方向 ±60,垂直在按钮附近)。
        expect((itemRect.center - btnRect.center).dx.abs(), lessThan(60),
            reason: 'useRootOverlay=$useRoot: 菜单水平漂移过大');
      });
    }

    testWidgets('golden: useRootOverlay=true 的实际渲染(漂移可视化)',
        (t) async {
      await pumpShellAndMeasure(t, useRootOverlay: true);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/menu_root_overlay_drift.png'),
      );
    });

    testWidgets('golden: useRootOverlay=false 的实际渲染(正确形态)',
        (t) async {
      await pumpShellAndMeasure(t, useRootOverlay: false);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/menu_nearest_overlay_ok.png'),
      );
    });
  });
}
