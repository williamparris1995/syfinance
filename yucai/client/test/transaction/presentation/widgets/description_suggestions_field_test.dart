// 反馈⑦(表单历史填写票):描述建议字段单元 + widget 测试。
//
// 改版口径(输入全显+聚焦前十+两列):
//  - 空查询 → 最近 10 条(kEmptyQueryLimit,聚焦唤起);
//  - 非空 → contains 大小写不敏感(含前缀)**全显无截断**(数据面由 DAO
//    缺省 200 封顶);查询首尾空白忽略;
//  - 面板两列(GridView,等宽,单条超长省略,高亮整格背景),封顶高度
//    + 内部滚动(>8 条匹配仍全在树中)。
//
// Widget [DescriptionSuggestionsField](RawAutocomplete):
//  - 聚焦空值 → 浮层弹最近 10 条;键入过滤;无匹配不弹;
//  - 鼠标点击选项 → 填入输入框;
//  - 键盘 ↓ 高亮第 2 格,回车填入;
//  - suggestions 为空 → 退化为普通输入框(不包 RawAutocomplete,零浮层)。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/transaction/presentation/widgets/description_suggestions_field.dart';

/// 12 条(> 聚焦前十,可断言第 11/12 不弹)。
const _recent = [
  '永辉超市',
  '美团外卖',
  '地铁通勤',
  '午餐',
  '山姆会员店',
  '星巴克',
  '滴滴出行',
  '水电燃气',
  '京东购物',
  'Apple Store',
  '瑞幸咖啡',
  '顺丰快递',
];

/// 20 条同前缀(> 旧 8 上限,断言全显 + 面板内部滚动)。
final _manyMatching = [for (var i = 0; i < 20; i++) '商户-$i'];

Future<void> _pumpField(WidgetTester tester, List<String> suggestions) async {
  final controller = TextEditingController();
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
          child: DescriptionSuggestionsField(
            controller: controller,
            suggestions: suggestions,
          ),
        ),
      ),
    ),
  ));
}

Finder get _field => find.byKey(const ValueKey('txn_form_payee_field'));

Future<void> _focusField(WidgetTester tester) async {
  await tester.tap(_field);
  await tester.pumpAndSettle();
}

void main() {
  // ───────── 纯函数:内存过滤口径 ─────────

  test('空查询 → 最近 10 条(聚焦唤起)', () {
    expect(filterDescriptionSuggestions(_recent, ''), _recent.take(10));
    // 首尾空白等同空查询。
    expect(filterDescriptionSuggestions(_recent, '   '), _recent.take(10));
    // 历史不足 10 条时全给。
    expect(filterDescriptionSuggestions(_recent.take(4).toList(), ''),
        _recent.take(4));
  });

  test('非空查询 → contains 大小写不敏感(前缀是子集)', () {
    expect(filterDescriptionSuggestions(_recent, '午'), ['午餐']);
    expect(filterDescriptionSuggestions(_recent, '超市'), ['永辉超市']);
    // 大小写不敏感:小写查询命中大写建议(及反向)。
    expect(filterDescriptionSuggestions(_recent, 'apple'), ['Apple Store']);
    expect(filterDescriptionSuggestions(_recent, 'STORE'), ['Apple Store']);
  });

  test('匹配无截断(20 条匹配全显 —— 旧 8 上限已取消)', () {
    expect(filterDescriptionSuggestions(_manyMatching, '商户').length, 20);
    expect(filterDescriptionSuggestions(_manyMatching, '商户').first, '商户-0');
    expect(filterDescriptionSuggestions(_manyMatching, '商户').last, '商户-19');
  });

  test('无匹配 → 空表(不弹)', () {
    expect(filterDescriptionSuggestions(_recent, '不存在的商户'), isEmpty);
  });

  test('空历史 → 恒空', () {
    expect(filterDescriptionSuggestions(const [], ''), isEmpty);
    expect(filterDescriptionSuggestions(const [], 'x'), isEmpty);
  });

  // ───────── widget:浮层交互 ─────────

  testWidgets('聚焦空值弹最近 10 条(第 11/12 条不弹)', (tester) async {
    await _pumpField(tester, _recent);
    await _focusField(tester);
    expect(find.text('永辉超市'), findsOneWidget);
    expect(find.text('滴滴出行'), findsOneWidget);
    expect(find.text('Apple Store'), findsOneWidget); // 第 10 条
    expect(find.text('瑞幸咖啡'), findsNothing); // 第 11 条
    expect(find.text('顺丰快递'), findsNothing); // 第 12 条
  });

  testWidgets('面板两列:相邻两条同行(GridView 等宽双列)', (tester) async {
    await _pumpField(tester, _recent);
    await _focusField(tester);
    expect(find.byType(GridView), findsOneWidget);
    // 第 1/2 条(线性 index 0/1)应落在同一行:dy 相同、dx 不同(左右格)。
    final a = tester.getTopLeft(find.text('永辉超市'));
    final b = tester.getTopLeft(find.text('美团外卖'));
    expect(a.dy, b.dy);
    expect(a.dx, lessThan(b.dx));
    // 第 3 条另起一行。
    final c = tester.getTopLeft(find.text('地铁通勤'));
    expect(c.dy, greaterThan(a.dy));
  });

  testWidgets('匹配超 8 条全显 + 面板封顶内部滚动', (tester) async {
    await _pumpField(tester, _manyMatching);
    await _focusField(tester);
    await tester.enterText(_field, '商户');
    await tester.pumpAndSettle();
    // 无截断:20 条匹配全部进面板(GridView 懒加载,数据面以 childCount
    // 断言 —— 可视区外格子不挂树属正常)。
    final grid = tester.widget<GridView>(find.byType(GridView));
    final delegate = grid.childrenDelegate as SliverChildBuilderDelegate;
    expect(delegate.childCount, 20);
    // 可见条目已超旧 8 上限(前 10 条 = 5 行双列,均在可视区内挂树)。
    for (var i = 0; i < 10; i++) {
      expect(find.text('商户-$i'), findsOneWidget);
    }
    // 封顶高度生效:内容超高 → 内部可滚(maxScrollExtent > 0)。
    final scrollableFinder = find.descendant(
        of: find.byType(GridView), matching: find.byType(Scrollable));
    final scrollable = tester.state<ScrollableState>(scrollableFinder);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    // 滚到底:末条真实存在(全显非虚报 childCount)。
    await tester.scrollUntilVisible(find.text('商户-19'), 120,
        scrollable: scrollableFinder);
    await tester.pumpAndSettle();
    expect(find.text('商户-19'), findsOneWidget);
  });

  testWidgets('键入过滤 contains,无匹配收起浮层', (tester) async {
    await _pumpField(tester, _recent);
    await _focusField(tester);
    await tester.enterText(_field, '午');
    await tester.pumpAndSettle();
    expect(find.text('午餐'), findsOneWidget);
    expect(find.text('永辉超市'), findsNothing);
    // 无匹配 → 浮层隐藏。
    await tester.enterText(_field, '不存在的商户');
    await tester.pumpAndSettle();
    expect(find.text('午餐'), findsNothing);
  });

  testWidgets('鼠标点击建议 → 填入输入框', (tester) async {
    await _pumpField(tester, _recent);
    await _focusField(tester);
    await tester.tap(find.text('美团外卖'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(_field).controller!.text, '美团外卖');
  });

  testWidgets('键盘 ↓ 高亮第 2 格,回车填入', (tester) async {
    await _pumpField(tester, _recent);
    await _focusField(tester);
    // ↓ 移动键盘高亮(RawAutocomplete Shortcuts:1 → 第 2 格 = 右列首行)。
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    // 回车 = IME done(桌面端 enter→done 由平台层翻译;框架层测试用
    // receiveAction 模拟,见 EditableText doc sendKeyEvent 不触发 onSubmitted)。
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(_field).controller!.text, '美团外卖');
    // 选中后浮层收起(_select → hide)。
    expect(find.text('永辉超市'), findsNothing);
  });

  testWidgets('空历史 → 退化普通输入框(无 RawAutocomplete,聚焦零浮层)',
      (tester) async {
    await _pumpField(tester, const []);
    expect(find.byType(RawAutocomplete<String>), findsNothing);
    final plain = find.byType(TextFormField);
    expect(plain, findsOneWidget);
    await tester.tap(plain);
    await tester.pumpAndSettle();
    await tester.enterText(plain, '手输无建议');
    await tester.pumpAndSettle();
    expect(find.text('手输无建议'), findsOneWidget);
  });
}
