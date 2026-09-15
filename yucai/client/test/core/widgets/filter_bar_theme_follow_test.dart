// F27(R12 sprint-2)— FR-3 theme-follow 探针:FilterBar 选中 pill。
//
// 列表页统一筛选标签栏(core 共享 widget)在 F27 前选中 pill 写死 Colors.white
// —— FR-1① 判定为 accent 面前景,迁 context.yucai.onAccent 后,本探针断言其
// 随主题:暗 = 金底深墨 #1A1408,亮 = 翡翠绿底白 #FFFFFF(不削断言,双板各锚)。
// 未选中档锚 muted 语义,防迁移误伤普通前景。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/filter_bar.dart';

/// 探针只读色彩,不驱动交互(const 构造可用顶层 tear-off)。
void noop(int _) {}

Future<void> _pump(WidgetTester t, Brightness brightness) async {
  await t.pumpWidget(MaterialApp(
    theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
    home: const Scaffold(
      body: FilterBar<int>(
        tabs: [FilterTab(1, '全部'), FilterTab(2, '支出')],
        active: 1,
        onChanged: noop,
      ),
    ),
  ));
  await t.pumpAndSettle();
}
void main() {
  testWidgets('dark: 选中 pill 前景 = onAccent 金底深墨 #1A1408(F27 FR-1①)',
      (t) async {
    await _pump(t, Brightness.dark);

    expect(t.widget<Text>(find.text('全部')).style?.color,
        const Color(0xFF1A1408),
        reason: '暗色 accent 面(鎏金 #E8C07A)前景应为 onAccent 深墨');
    expect(t.widget<Text>(find.text('支出')).style?.color,
        const Color(0xFF8B93A3),
        reason: '未选中 pill 应走 muted 语义(暗档)');
  });

  testWidgets('light: 选中 pill 前景 = onAccent 绿底白 #FFFFFF(F27 FR-1①)',
      (t) async {
    await _pump(t, Brightness.light);

    expect(t.widget<Text>(find.text('全部')).style?.color,
        const Color(0xFFFFFFFF),
        reason: '亮色 accent 面(翡翠 #059669)前景应为 onAccent 白(等值迁移)');
    expect(t.widget<Text>(find.text('支出')).style?.color,
        const Color(0xFF64748B),
        reason: '未选中 pill 应走 muted 语义(亮档)');
  });
}
