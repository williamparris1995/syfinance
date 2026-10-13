// FloatingActionDock 契约钉死(原型 v16 形态 B / F58 design ADR-2):
//   次序 —— secondary 逆序叠于 primary 之上(primary 恒最下);
//   禁用 —— onTap=null 不可触发且降饱和视觉存在;
//   令牌 —— accentGradient 空时 primary 回落 accent 纯色;非空走
//           LinearGradient + actionShadow;次级钮 surface/border/muted;
//   可达 —— 每钮 tooltip;Tab 焦点 + Enter 触发。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:design_kit/design_kit.dart';

/// 测试注入令牌(任意注入值,只验证缝的传导)。
const _tokens = DesignTokens(
  surface: Color(0xFF0B1220),
  border: Color(0xFF334155),
  fg: Color(0xFFE2E8F0),
  muted: Color(0xFF94A3B8),
  accent: Color(0xFFB45309),
  positive: Color(0xFF059669),
  negative: Color(0xFFE11D48),
);

Future<void> _pumpDock(
  WidgetTester t, {
  List<Color> gradient = const [],
  List<BoxShadow> shadow = const [],
  Color? primaryForeground,
  required DockAction primary,
  List<DockAction> secondary = const [],
}) async {
  await t.pumpWidget(MaterialApp(
    theme: ThemeData(extensions: [
      _tokens.copyWith(accentGradient: gradient, actionShadow: shadow),
    ]),
    home: Scaffold(
      body: Align(
        alignment: Alignment.bottomRight,
        child: FloatingActionDock(
          primary: primary,
          secondary: secondary,
          primaryForeground: primaryForeground,
        ),
      ),
    ),
  ));
}

/// primary 钮 = 圆形装饰的那个 Ink;次级钮 = 带 borderRadius 的 Ink。
Finder _primaryInk() => find.descendant(
      of: find.byType(FloatingActionDock),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Ink &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );

Finder _secondaryInk() => find.descendant(
      of: find.byType(FloatingActionDock),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Ink &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius != null,
      ),
    );

void main() {
  testWidgets('渲染 primary + N secondary;secondary 逆序在上、primary 最下;尺寸 52/44、间距 10', (t) async {
    await _pumpDock(
      t,
      primary: DockAction(icon: Icons.add_circle, tooltip: '记一笔', onTap: () {}),
      secondary: const [
        DockAction(icon: Icons.edit, tooltip: '编辑', onTap: null),
        DockAction(icon: Icons.currency_exchange, tooltip: '转账', onTap: null),
        DockAction(icon: Icons.more_horiz, tooltip: '更多', onTap: null),
      ],
    );
    // 每钮 tooltip 存在
    for (final tip in const ['记一笔', '编辑', '转账', '更多']) {
      expect(find.byTooltip(tip), findsOneWidget, reason: 'tooltip: $tip');
    }
    // 列表 [编辑,转账,更多] 自下而上 → 渲染自上而下应为 更多/转账/编辑/记一笔
    double dy(IconData icon) => t.getTopLeft(find.byIcon(icon)).dy;
    expect(dy(Icons.more_horiz) < dy(Icons.currency_exchange), isTrue,
        reason: 'secondary 末项渲染最上');
    expect(dy(Icons.currency_exchange) < dy(Icons.edit), isTrue);
    expect(dy(Icons.edit) < dy(Icons.add_circle), isTrue, reason: 'primary 恒最下');
    // 尺寸:primary 52 圆,secondary 44 方圆(总视觉含描边;渲染序 =
    // 列序逆序 + primary 收底),间距恒 10
    final inks = find.descendant(
      of: find.byType(FloatingActionDock),
      matching: find.byWidgetPredicate(
          (w) => w is Ink && w.decoration is BoxDecoration),
    );
    expect(inks, findsNWidgets(4));
    expect(t.getSize(inks.at(0)), const Size(44, 44));
    expect(t.getSize(inks.at(3)), const Size(52, 52));
    for (var i = 1; i < 4; i++) {
      expect(t.getTopLeft(inks.at(i)).dy - t.getBottomLeft(inks.at(i - 1)).dy, 10);
    }
    // 次级钮令牌:surface 底 + border 描边 + muted 图标
    final secDeco = t.widget<Ink>(_secondaryInk().first).decoration! as BoxDecoration;
    expect(secDeco.color, _tokens.surface);
    expect((secDeco.border as Border).top.color, _tokens.border);
    expect(t.widget<Icon>(find.byIcon(Icons.edit)).color, _tokens.muted);
  });

  testWidgets('onTap=null 禁用:不可触发且降饱和视觉存在', (t) async {
    var fired = 0;
    await _pumpDock(
      t,
      primary: DockAction(icon: Icons.add_circle, tooltip: '记一笔', onTap: () => fired++),
      secondary: const [DockAction(icon: Icons.edit, tooltip: '编辑')], // onTap 缺省 null
    );
    await t.tap(find.byIcon(Icons.edit), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(fired, 0, reason: '禁用钮不触发回调');
    final dimmed = find.ancestor(
        of: find.byIcon(Icons.edit), matching: find.byType(Opacity));
    expect(dimmed, findsOneWidget, reason: '降饱和视觉存在');
    expect(t.widget<Opacity>(dimmed).opacity, lessThan(1));
    // 禁用钮被 Tab 焦点序跳过:首个 Tab 直达唯一可用的 primary,Enter 触发
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(fired, 1, reason: 'Tab 跳过禁用钮,焦点落在 primary');
  });

  testWidgets('accentGradient 空:primary 回落 accent 纯色而非渐变', (t) async {
    const shadow = [BoxShadow(color: Color(0x66000000), offset: Offset(0, 6))];
    await _pumpDock(
      t,
      shadow: shadow,
      primary: DockAction(icon: Icons.add_circle, tooltip: '主', onTap: () {}),
    );
    final deco = t.widget<Ink>(_primaryInk()).decoration! as BoxDecoration;
    expect(deco.gradient, isNull, reason: '空渐变回落纯色,不得残留 LinearGradient');
    expect(deco.color, _tokens.accent);
    expect(deco.boxShadow, shadow, reason: 'actionShadow 经令牌缝传导');
  });

  testWidgets('accentGradient 非空:primary 为 LinearGradient 且色序=令牌', (t) async {
    const grad = [Color(0xFFB8860B), Color(0xFFFFD700)];
    await _pumpDock(
      t,
      gradient: grad,
      primary: DockAction(icon: Icons.add_circle, tooltip: '主', onTap: () {}),
    );
    final deco = t.widget<Ink>(_primaryInk()).decoration! as BoxDecoration;
    expect(deco.gradient, isA<LinearGradient>());
    expect((deco.gradient as LinearGradient).colors, grad);
    expect(deco.color, isNull, reason: '渐变时不叠纯色兜底');
  });

  testWidgets('primaryForeground 缺省白,注入则覆盖', (t) async {
    await _pumpDock(
      t,
      primary: DockAction(icon: Icons.add_circle, tooltip: '主', onTap: () {}),
    );
    expect(t.widget<Icon>(find.byIcon(Icons.add_circle)).color, Colors.white);

    await _pumpDock(
      t,
      primaryForeground: const Color(0xFF1A1408),
      primary: DockAction(icon: Icons.add_circle, tooltip: '主', onTap: () {}),
    );
    expect(t.widget<Icon>(find.byIcon(Icons.add_circle)).color, const Color(0xFF1A1408));
  });

  testWidgets('键盘可达:Tab 焦点 + Enter 触发(焦点次序随渲染次序)', (t) async {
    final fired = <String>[];
    await _pumpDock(
      t,
      primary: DockAction(
          icon: Icons.add_circle, tooltip: '记一笔', onTap: () => fired.add('记一笔')),
      secondary: [
        DockAction(icon: Icons.edit, tooltip: '编辑', onTap: () => fired.add('编辑')),
        DockAction(icon: Icons.more_horiz, tooltip: '更多', onTap: () => fired.add('更多')),
      ],
    );
    // 首个 Tab 落在渲染最上的「更多」(secondary 末项),Enter 触发
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(fired, ['更多']);
    // 继续两 Tab 经「编辑」到 primary,Enter 触发
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(fired, ['更多', '记一笔']);
  });
}
