// AnchoredMenu 屏幕内自适应定位验证(dev 2026-10-08:更多菜单超窗):
//   正常位 —— 右缘放得下,向下/向右展开;
//   右缘   —— 放不下 menuWidth 时水平翻转(向左展开),菜单完整在窗内;
//   底缘   —— 下方放不下预估高时向上弹,菜单完整在窗内。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:design_kit/design_kit.dart';

const _items = [
  MenuItemData(label: '编辑', icon: Icons.edit),
  MenuItemData(label: '复制', icon: Icons.copy),
  MenuItemData(label: '删除账户', icon: Icons.delete_outlined, destructive: true),
];

Future<void> _pumpAt(WidgetTester t, Size win, Alignment alignment) async {
  t.view.physicalSize = win;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: alignment,
        child: AnchoredMenu(
          items: _items,
          builder: (_, open) => IconButton(
            tooltip: '更多操作',
            icon: const Icon(Icons.more_horiz),
            onPressed: open,
          ),
        ),
      ),
    ),
  ));
  await t.pumpAndSettle();
  await t.tap(find.byTooltip('更多操作'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('正常位:居中触发器,菜单向下展开且在窗内', (t) async {
    await _pumpAt(t, const Size(800, 600), Alignment.center);
    final rect = t.getRect(find.text('删除账户'));
    expect(rect.right <= 800, isTrue);
    expect(rect.bottom <= 600, isTrue);
    final btn = t.getRect(find.byTooltip('更多操作'));
    expect(rect.top > btn.bottom, isTrue, reason: '向下展开');
  });

  testWidgets('右缘:向左翻转,菜单不超窗右缘', (t) async {
    await _pumpAt(t, const Size(800, 600), Alignment.centerRight);
    final rect = t.getRect(find.text('删除账户'));
    final win = t.view;
    expect(rect.right <= win.physicalSize.width, isTrue,
        reason: '菜单项完整在窗内');
  });

  testWidgets('底缘:向上弹,菜单不超窗底', (t) async {
    await _pumpAt(t, const Size(800, 600), Alignment.bottomCenter);
    final rect = t.getRect(find.text('删除账户'));
    expect(rect.bottom <= 600, isTrue, reason: '向上弹后完整在窗内');
    final btn = t.getRect(find.byTooltip('更多操作'));
    expect(rect.bottom < btn.top, isTrue, reason: '菜单在按钮上方');
  });

  testWidgets('右下角:双向翻转,完整在窗内', (t) async {
    await _pumpAt(t, const Size(800, 600), Alignment.bottomRight);
    final rect = t.getRect(find.text('删除账户'));
    expect(rect.right <= 800, isTrue);
    expect(rect.bottom <= 600, isTrue);
  });
}
