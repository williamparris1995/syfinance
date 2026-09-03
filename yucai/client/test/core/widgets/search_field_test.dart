// TDD RED → GREEN:F9-T3 无 domain 依赖通用搜索框 SearchField 的 widget 单测。
//
// 来源:F7 的 TxnSearchField(transaction/presentation/widgets/filter_bar.dart)
// 依赖 transaction domain(命名/默认 hint),持仓/债务/账户页复用会造成跨模块
// presentation → transaction 的多余耦合(FR-3/4/5 各页搜索口径不同但控件形态
// 相同)。故按 T3 简报把「提交制搜索框」提取为 core/widgets 纯 UI 组件:
//   - 提交制:onSubmitted(回车/搜索键)与 suffix 清除钮才离散提交;
//   - 受控组件:[value] 为当前已提交的搜索词('' = 无),外部真正变更(重置)
//     时同步回输入框,无关重建不回写(保留未提交的输入缓冲)。
// 语义照搬 TxnSearchField 提交制(承 F7 fix round 1),逐位不变;本测试 3 组
// 断言即迁移保绿的验收门。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/search_field.dart';

Widget _harness(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('SearchField (F9-T3,提取自 F7 TxnSearchField 提交制语义)', () {
    testWidgets('回车/搜索键离散提交输入值', (tester) async {
      final commits = <String>[];
      await tester.pumpWidget(_harness(SearchField(
        value: '',
        onCommit: commits.add,
        hintText: '搜索 symbol / 名称…',
      )));

      await tester.enterText(find.byType(TextField), 'AAPL');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();

      expect(commits, ['AAPL']);
    });

    testWidgets('有文本时显示清除钮;点清除提交空串;无文本时无清除钮', (tester) async {
      final commits = <String>[];
      await tester.pumpWidget(_harness(SearchField(
        value: '',
        onCommit: commits.add,
      )));

      // 初始无文本 → 无清除钮。
      expect(find.byTooltip('清除搜索'), findsNothing);

      await tester.enterText(find.byType(TextField), '茅台');
      await tester.pump();
      expect(find.byTooltip('清除搜索'), findsOneWidget);

      await tester.tap(find.byTooltip('清除搜索'));
      await tester.pump();
      expect(commits, ['']);
      // 输入框已清空。
      expect(find.widgetWithText(TextField, '茅台'), findsNothing);
    });

    testWidgets('受控 value:外部真正变更时回写;无关重建不回写未提交缓冲', (tester) async {
      final key = GlobalKey();
      String value = '';
      late StateSetter setStateOuter;
      await tester.pumpWidget(_harness(StatefulBuilder(
        key: key,
        builder: (context, setState) {
          setStateOuter = setState;
          return SearchField(value: value, onCommit: (_) {});
        },
      )));

      // 输入未提交的草稿。
      await tester.enterText(find.byType(TextField), '草稿');
      await tester.pump();

      // 无关重建(value 未变):草稿保留。
      await tester.pumpWidget(_harness(StatefulBuilder(
        key: key,
        builder: (context, setState) {
          setStateOuter = setState;
          return SearchField(value: value, onCommit: (_) {});
        },
      )));
      expect(find.widgetWithText(TextField, '草稿'), findsOneWidget);

      // 外部真正变更 value(如筛选重置):回写输入框。
      setStateOuter(() => value = '已重置');
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, '已重置'), findsOneWidget);
    });

    testWidgets('hintText 展示(占位文案)', (tester) async {
      await tester.pumpWidget(_harness(const SearchField(
        value: '',
        hintText: '搜索账户名…',
      )));
      expect(find.text('搜索账户名…'), findsOneWidget);
    });
  });
}
