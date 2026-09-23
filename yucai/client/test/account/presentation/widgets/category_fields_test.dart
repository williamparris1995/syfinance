import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/widgets/category_fields.dart';

void main() {
  group('currencySymbolOf', () {
    test('maps supported currency codes to symbols', () {
      expect(currencySymbolOf('CNY'), '¥');
      expect(currencySymbolOf('USD'), '\$');
      expect(currencySymbolOf('EUR'), '€');
      expect(currencySymbolOf('GBP'), '£');
      expect(currencySymbolOf('JPY'), '¥');
      expect(currencySymbolOf('HKD'), 'HK\$');
      expect(currencySymbolOf('AUD'), 'A\$');
      expect(currencySymbolOf('SGD'), 'S\$');
    });

    test('falls back to ¥ for unknown codes', () {
      expect(currencySymbolOf('UNKNOWN'), '¥');
      expect(currencySymbolOf(''), '¥');
    });
  });

  test('categoryFieldsWidget accepts currencySymbol param (drives AmountInput prefix)', () {
    // 签名级验证：currencySymbol 是命名可选参数（默认 ¥），各 category 都能渲染不抛异常。
    // AmountInput 前缀随 currencySymbol 变化由 FormPage setState → 重渲染驱动（集成层验证）。
    final bundle = CategoryFieldBundle();
    for (final c in AccountCategory.values) {
      final widgetsUsd = categoryFieldsWidget(c, bundle, currencySymbol: '\$');
      final widgetsDefault = categoryFieldsWidget(c, bundle);
      expect(widgetsUsd, isNotEmpty, reason: '$c 应有字段');
      expect(widgetsDefault, hasSameLengthAs(widgetsUsd), reason: '$c 字段数不应随符号变');
    }
    bundle.dispose();
  });

  // ───── T8 A:账单日/还款日下拉编辑预填(展示 bug:controller 有值但下拉空) ─────
  //
  // account_form_page 编辑态已把 "5"/"27" 写进 controller(数据不丢,提交读
  // controller),但 _dayPicker 未设 value → 显示空。修复 = value 回读
  // controller(空串/不可解析/越界 → null → 显示 label,不炸)。

  group('_dayPicker 预填(T8)', () {
    Future<void> pumpCreditFields(WidgetTester tester, CategoryFieldBundle bundle) {
      return tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Form(
            child: SingleChildScrollView(
              child: Column(
                children: categoryFieldsWidget(AccountCategory.creditCard, bundle),
              ),
            ),
          ),
        ),
      ));
    }

    /// 两个日选择下拉(账单日/还款日)的 FormField 当前值(树序)。
    List<int?> dayPickerValues(WidgetTester tester) => tester
        .stateList<FormFieldState<int>>(find.byType(DropdownButtonFormField<int>))
        .map((s) => s.value)
        .toList();

    testWidgets('编辑预填 5/27 → 两下拉显示「5日」「27日」且字段值回读 controller', (tester) async {
      final bundle = CategoryFieldBundle()
        ..creditBillingDayCtrl.text = '5'
        ..creditRepaymentDayCtrl.text = '27';
      addTearDown(bundle.dispose);
      await pumpCreditFields(tester, bundle);

      // 下拉按钮区显示选中项文本(菜单未展开,只有选中项的 Text 挂载)。
      expect(find.text('5日'), findsOneWidget, reason: '账单日下拉应显示预填「5日」');
      expect(find.text('27日'), findsOneWidget, reason: '还款日下拉应显示预填「27日」');
      // 字段值回读 controller(FormRow 顺序:账单日在前、还款日在后)。
      expect(dayPickerValues(tester), [5, 27]);
    });

    testWidgets('创建态空 controller → 无选中(字段值 null,不炸)', (tester) async {
      final bundle = CategoryFieldBundle();
      addTearDown(bundle.dispose);
      await pumpCreditFields(tester, bundle);

      // 空串 → 解析 null → 无选中:显示 label 占位而非任何「N日」。
      expect(dayPickerValues(tester), [null, null]);
      for (var d = 1; d <= 31; d++) {
        expect(find.text('$d日'), findsNothing, reason: '空 controller 不应有选中项');
      }
    });

    testWidgets('越界/不可解析文本(脏数据)→ 无选中兜底,不触发 items 断言', (tester) async {
      final bundle = CategoryFieldBundle()
        ..creditBillingDayCtrl.text = '99' // 越界(不在 1-31 items)
        ..creditRepaymentDayCtrl.text = 'abc'; // 不可解析
      addTearDown(bundle.dispose);
      await pumpCreditFields(tester, bundle);

      // 选中值必须落在 items(1-31)内,越界/脏值兜底 null 防 assert。
      expect(dayPickerValues(tester), [null, null]);
      expect(find.text('99日'), findsNothing);
    });
  });
}

/// 匹配器：两个集合长度相同。
Matcher hasSameLengthAs(Object expected) =>
    predicate<List<Object>>((a) => a.length == (expected as List).length,
        'has same length as $expected');
