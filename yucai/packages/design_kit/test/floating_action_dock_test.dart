// FloatingActionDock 契约钉死(原型 v17 模型 C' / F59 design ADR-1):
//   三段 —— Column 自上而下 = [...muted.reversed, 分隔线?, ...secondary.reversed,
//           primary];muted 逆序置顶(危险项离主钮最远)、primary 恒最下;间距恒 10;
//   分隔线 —— muted 非空才有:恰一条 1px 高 × 宽 20、水平居中、色 = tokens.border;
//   全圆 —— secondary/muted 44 全圆(半径 = 边长一半,v16 方圆 12 废除);
//   淡显 —— muted 钮 Opacity = dimmedOpacity 令牌(低于正常钮)但可点可获焦,
//           hover(mouse enter)与键盘焦点恢复满透明度,失焦/离开回淡;
//   禁用 —— onTap = null 不可触发不获焦,与淡显共用 dimmedOpacity 降权,
//           两者叠加时以禁用为准(恒淡,hover 也不恢复);
//   令牌 —— accentGradient 空时 primary 回落 accent 纯色;非空走
//           LinearGradient + actionShadow;次级两段钮 surface/border/muted;
//   可达 —— 每钮 tooltip;Tab 焦点 + Enter 触发(禁用钮被焦点序跳过)。
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:design_kit/design_kit.dart';

/// 测试注入令牌(任意注入值,只验证缝的传导;dimmedOpacity 特意用 0.4,
/// 证明淡显/禁用透明度经令牌缝传导而非组件内写死)。
const _tokens = DesignTokens(
  surface: Color(0xFF0B1220),
  border: Color(0xFF334155),
  fg: Color(0xFFE2E8F0),
  muted: Color(0xFF94A3B8),
  accent: Color(0xFFB45309),
  positive: Color(0xFF059669),
  negative: Color(0xFFE11D48),
  dimmedOpacity: 0.4,
);

Future<void> _pumpDock(
  WidgetTester t, {
  List<Color> gradient = const [],
  List<BoxShadow> shadow = const [],
  Color? primaryForeground,
  required DockAction primary,
  List<DockAction> secondary = const [],
  List<DockAction> muted = const [],
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
          muted: muted,
          primaryForeground: primaryForeground,
        ),
      ),
    ),
  ));
}

/// primary 钮 = 圆形装饰(shape)的那个 Ink。
Finder _primaryInk() => find.descendant(
      of: find.byType(FloatingActionDock),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Ink &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle,
      ),
    );

/// 次级两段钮(secondary/muted)= 带 borderRadius 的 Ink(C' 全圆)。
Finder _tierInk() => find.descendant(
      of: find.byType(FloatingActionDock),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Ink &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).borderRadius != null,
      ),
    );

/// 内置分隔线 = 1px 高 × 宽 20 的 Container(色 = tokens.border;
/// Container 把 width/height 折进 tightFor 约束,故按约束钉)。
Finder _divider() => find.descendant(
      of: find.byType(FloatingActionDock),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints == const BoxConstraints.tightFor(width: 20, height: 1),
      ),
    );

/// 某钮最外层降权 Opacity(每钮恰一层)。
Opacity _opacityOf(WidgetTester t, IconData icon) => t.widget<Opacity>(
      find.ancestor(of: find.byIcon(icon), matching: find.byType(Opacity)),
    );

/// 派一只鼠标并悬停到目标中心(hover 恢复断言用)。
Future<TestGesture> _hoverAt(WidgetTester t, Finder target) async {
  final gesture = await t.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer();
  await gesture.moveTo(t.getCenter(target));
  await t.pump();
  return gesture;
}

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
    // 尺寸:primary 52 圆,次级钮 44 全圆(总视觉含描边;渲染序 =
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
    final secDeco = t.widget<Ink>(_tierInk().first).decoration! as BoxDecoration;
    expect(secDeco.color, _tokens.surface);
    expect((secDeco.border as Border).top.color, _tokens.border);
    expect(t.widget<Icon>(find.byIcon(Icons.edit)).color, _tokens.muted);
  });

  testWidgets("C' 三段:muted 置顶、分隔线隔断、secondary 中段、primary 居底;间距恒 10", (t) async {
    await _pumpDock(
      t,
      primary: DockAction(icon: Icons.add_circle, tooltip: '记一笔', onTap: () {}),
      secondary: const [
        DockAction(icon: Icons.edit, tooltip: '编辑', onTap: null),
        DockAction(icon: Icons.more_horiz, tooltip: '更多', onTap: null),
      ],
      muted: const [
        DockAction(icon: Icons.copy, tooltip: '复制', onTap: null),
        DockAction(icon: Icons.delete_outline, tooltip: '删除', onTap: null),
      ],
    );
    // 渲染自上而下应为 删除/复制/分隔线/更多/编辑/记一笔:
    // muted 逆序置顶(末项「删除」最上,离 primary 最远),primary 恒最下。
    double dy(IconData icon) => t.getTopLeft(find.byIcon(icon)).dy;
    expect(dy(Icons.delete_outline) < dy(Icons.copy), isTrue,
        reason: 'muted 末项渲染最上');
    expect(dy(Icons.copy) < dy(Icons.more_horiz), isTrue,
        reason: 'muted 整段在 secondary 之上');
    expect(dy(Icons.more_horiz) < dy(Icons.edit), isTrue,
        reason: 'secondary 末项在其首项之上');
    expect(dy(Icons.edit) < dy(Icons.add_circle), isTrue, reason: 'primary 恒最下');
    // 分隔线夹在 muted 与 secondary 之间,上下间距同为 10(间距恒定);
    // 间距按钮盒(Ink)口径量,不按内部 20px 图标(图标居中有 12px 内衬)。
    final copyInk =
        find.ancestor(of: find.byIcon(Icons.copy), matching: find.byType(Ink)).first;
    final moreInk = find
        .ancestor(of: find.byIcon(Icons.more_horiz), matching: find.byType(Ink))
        .first;
    final dividerTop = t.getTopLeft(_divider()).dy;
    final dividerBottom = t.getBottomLeft(_divider()).dy;
    expect(dividerTop - t.getBottomLeft(copyInk).dy, 10,
        reason: 'muted 末项与分隔线间距 10');
    expect(t.getTopLeft(moreInk).dy - dividerBottom, 10,
        reason: '分隔线与 secondary 末项间距 10');
    // muted 钮构造同次级令牌:surface 底 + border 描边 + muted 图标
    final mutedDeco = t.widget<Ink>(find
            .ancestor(of: find.byIcon(Icons.copy), matching: find.byType(Ink))
            .first)
        .decoration! as BoxDecoration;
    expect(mutedDeco.color, _tokens.surface);
    expect((mutedDeco.border as Border).top.color, _tokens.border);
    expect(t.widget<Icon>(find.byIcon(Icons.copy)).color, _tokens.muted);
  });

  testWidgets('分隔线条件渲染:muted 空 → 无;muted 非空 → 恰一条 1×20 居中、色 = tokens.border', (t) async {
    await _pumpDock(
      t,
      primary: DockAction(icon: Icons.add_circle, tooltip: '主', onTap: () {}),
      secondary: const [DockAction(icon: Icons.edit, tooltip: '编辑', onTap: null)],
      muted: const [],
    );
    expect(_divider(), findsNothing, reason: 'muted 空:不渲染分隔线');

    await _pumpDock(
      t,
      primary: DockAction(icon: Icons.add_circle, tooltip: '主', onTap: () {}),
      muted: const [DockAction(icon: Icons.delete_outline, tooltip: '删除', onTap: null)],
    );
    expect(_divider(), findsOneWidget, reason: 'muted 非空:恰一条');
    expect(t.getSize(_divider()), const Size(20, 1), reason: '1px 高 × 宽 20');
    expect(t.widget<Container>(_divider()).color, _tokens.border,
        reason: '分隔线颜色走 tokens.border 缝');
    // 水平居中:分隔线中心与最宽的 primary(52)中心对齐
    expect(
      t.getCenter(_divider()).dx,
      t.getCenter(_primaryInk()).dx,
      reason: '分隔线水平居中于簇',
    );
  });

  testWidgets('muted 淡显:Opacity = 令牌 dimmedOpacity(低于正常钮);hover 恢复、离开回淡', (t) async {
    await _pumpDock(
      t,
      primary: DockAction(icon: Icons.add_circle, tooltip: '记一笔', onTap: () {}),
      secondary: [
        DockAction(icon: Icons.edit, tooltip: '编辑', onTap: () {}),
      ],
      muted: [
        DockAction(icon: Icons.copy, tooltip: '复制', onTap: () {}),
      ],
    );
    // 正常钮满透明;淡显钮低于正常且恰为令牌注入值(缝传导非写死)
    expect(_opacityOf(t, Icons.edit).opacity, 1, reason: 'secondary 正常亮度');
    expect(_opacityOf(t, Icons.copy).opacity, _tokens.dimmedOpacity,
        reason: 'muted 淡显 = dimmedOpacity 令牌');
    expect(_opacityOf(t, Icons.copy).opacity,
        lessThan(_opacityOf(t, Icons.edit).opacity),
        reason: '淡显低于正常钮');
    // 鼠标移入恢复满透明度,移出回淡(mouse enter/exit 联动)
    final gesture = await _hoverAt(t, find.byIcon(Icons.copy));
    expect(_opacityOf(t, Icons.copy).opacity, 1, reason: 'hover 恢复满透明度');
    await gesture.moveTo(const Offset(1, 1));
    await t.pump();
    expect(_opacityOf(t, Icons.copy).opacity, _tokens.dimmedOpacity,
        reason: '离开后回淡');
    // 淡显=视觉淡但可点:点击照常触发
    var fired = 0;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: FloatingActionDock(
          primary: DockAction(icon: Icons.add_circle, tooltip: '主', onTap: () {}),
          muted: [
            DockAction(icon: Icons.copy, tooltip: '复制', onTap: () => fired++),
          ],
        ),
      ),
    ));
    await t.tap(find.byIcon(Icons.copy), warnIfMissed: false);
    await t.pumpAndSettle();
    expect(fired, 1, reason: '淡显钮可点(区别于禁用)');
  });

  testWidgets('淡显钮键盘可达:Tab 获焦恢复满透明度、失焦回淡、Enter 触发', (t) async {
    final fired = <String>[];
    await _pumpDock(
      t,
      primary: DockAction(
          icon: Icons.add_circle, tooltip: '记一笔', onTap: () => fired.add('记一笔')),
      secondary: [
        DockAction(icon: Icons.edit, tooltip: '编辑', onTap: () => fired.add('编辑')),
      ],
      muted: [
        DockAction(icon: Icons.copy, tooltip: '复制', onTap: () => fired.add('复制')),
        DockAction(
            icon: Icons.delete_outline, tooltip: '删除', onTap: () => fired.add('删除')),
      ],
    );
    // 初始全淡(焦点未至)
    expect(_opacityOf(t, Icons.delete_outline).opacity, _tokens.dimmedOpacity);
    expect(_opacityOf(t, Icons.copy).opacity, _tokens.dimmedOpacity);
    // 首个 Tab 落在渲染最上的「删除」(muted 末项):焦点态视觉不淡
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(_opacityOf(t, Icons.delete_outline).opacity, 1,
        reason: '焦点恢复满透明度(NFR-2)');
    // 再 Tab 到「复制」:新焦点钮恢复,旧焦点钮失焦回淡
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(_opacityOf(t, Icons.copy).opacity, 1);
    expect(_opacityOf(t, Icons.delete_outline).opacity, _tokens.dimmedOpacity,
        reason: '失焦回淡');
    // Enter 触发当前焦点钮(淡显钮键盘可点)
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pumpAndSettle();
    expect(fired, ['复制']);
  });

  testWidgets('禁用叠加:muted 钮 onTap=null 不可点且 hover 不恢复(以禁用为准)', (t) async {
    await _pumpDock(
      t,
      primary: DockAction(icon: Icons.add_circle, tooltip: '记一笔', onTap: () {}),
      muted: const [
        DockAction(icon: Icons.delete_outline, tooltip: '删除'), // onTap 缺省 null
      ],
    );
    await t.tap(find.byIcon(Icons.delete_outline), warnIfMissed: false);
    await t.pumpAndSettle();
    // 禁用不可点 + 恒淡:hover 也不恢复满透明度(禁用语义优先于淡显恢复)
    final gesture = await _hoverAt(t, find.byIcon(Icons.delete_outline));
    expect(_opacityOf(t, Icons.delete_outline).opacity, _tokens.dimmedOpacity,
        reason: '禁用叠加淡显:hover 不恢复,以禁用为准');
    await gesture.removePointer();
  });

  testWidgets('secondary/muted 全圆:borderRadius = 边长一半(44 → 22),v16 方圆 12 废除', (t) async {
    await _pumpDock(
      t,
      primary: DockAction(icon: Icons.add_circle, tooltip: '记一笔', onTap: () {}),
      secondary: const [DockAction(icon: Icons.edit, tooltip: '编辑', onTap: null)],
      muted: const [DockAction(icon: Icons.copy, tooltip: '复制', onTap: null)],
    );
    // 次级两段(secondary+muted)各钮:44 全圆,半径 = 边长一半
    expect(_tierInk(), findsNWidgets(2));
    for (final finder in [_tierInk().at(0), _tierInk().at(1)]) {
      final deco = t.widget<Ink>(finder).decoration! as BoxDecoration;
      final radius = deco.borderRadius as BorderRadius;
      expect(radius.topLeft, const Radius.circular(44 / 2),
          reason: '全圆:四角半径 = 边长一半');
      expect(radius.topLeft, isNot(const Radius.circular(12)),
          reason: 'v16 方圆 12 已废除');
      expect(t.getSize(finder), const Size(44, 44));
    }
    // primary 仍为 52 圆(shape 通道,不受影响)
    expect(t.getSize(_primaryInk()), const Size(52, 52));
  });

  testWidgets('onTap=null 禁用:不可触发且降饱和视觉存在(与淡显共用 dimmedOpacity)', (t) async {
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
    expect(t.widget<Opacity>(dimmed).opacity, _tokens.dimmedOpacity,
        reason: '禁用降权透明度走 dimmedOpacity 令牌');
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
