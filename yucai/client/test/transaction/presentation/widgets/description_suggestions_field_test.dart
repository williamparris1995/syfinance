// 反馈⑦(表单历史填写票):描述建议字段单元 + widget 测试。
//
// 纯函数 [filterDescriptionSuggestions]:
//  - 空查询 → 最近 3 条(kEmptyQueryLimit,聚焦唤起);
//  - 非空 → contains 大小写不敏感(含前缀),上限 8(kTypedQueryLimit);
//  - 查询首尾空白忽略。
//
// Widget [DescriptionSuggestionsField](RawAutocomplete):
//  - 聚焦空值 → 浮层弹最近 3 条;键入过滤;无匹配不弹;
//  - 鼠标点击选项 → 填入输入框;
//  - 键盘 ↓ 高亮第 2 项,回车填入;
//  - suggestions 为空 → 退化为普通输入框(不包 RawAutocomplete,零浮层)。
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/transaction/presentation/widgets/description_suggestions_field.dart';

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
];

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

  test('空查询 → 最近 3 条(聚焦唤起,不弹全量)', () {
    expect(filterDescriptionSuggestions(_recent, ''), _recent.take(3));
    // 首尾空白等同空查询。
    expect(filterDescriptionSuggestions(_recent, '   '), _recent.take(3));
  });

  test('非空查询 → contains 大小写不敏感(前缀是子集)', () {
    expect(filterDescriptionSuggestions(_recent, '午'), ['午餐']);
    expect(filterDescriptionSuggestions(_recent, '超市'), ['永辉超市']);
    // 大小写不敏感:小写查询命中大写建议(及反向)。
    expect(filterDescriptionSuggestions(_recent, 'apple'), ['Apple Store']);
    expect(filterDescriptionSuggestions(_recent, 'STORE'), ['Apple Store']);
  });

  test('匹配上限 8 条(即便历史更多)', () {
    final many = [for (var i = 0; i < 20; i++) '商户-$i'];
    expect(filterDescriptionSuggestions(many, '商户').length, 8);
    expect(filterDescriptionSuggestions(many, '商户').first, '商户-0');
  });

  test('无匹配 → 空表(不弹)', () {
    expect(filterDescriptionSuggestions(_recent, '不存在的商户'), isEmpty);
  });

  test('空历史 → 恒空', () {
    expect(filterDescriptionSuggestions(const [], ''), isEmpty);
    expect(filterDescriptionSuggestions(const [], 'x'), isEmpty);
  });

  // ───────── widget:浮层交互 ─────────

  testWidgets('聚焦空值弹最近 3 条(第 4 条不弹)', (tester) async {
    await _pumpField(tester, _recent);
    await _focusField(tester);
    expect(find.text('永辉超市'), findsOneWidget);
    expect(find.text('美团外卖'), findsOneWidget);
    expect(find.text('地铁通勤'), findsOneWidget);
    expect(find.text('午餐'), findsNothing);
    expect(find.text('山姆会员店'), findsNothing);
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

  testWidgets('键盘 ↓ 高亮第 2 项,回车填入', (tester) async {
    await _pumpField(tester, _recent);
    await _focusField(tester);
    // ↓ 移动键盘高亮(RawAutocomplete Shortcuts:1 → 第 2 项)。
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
