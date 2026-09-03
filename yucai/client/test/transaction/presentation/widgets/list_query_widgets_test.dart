// TDD RED → GREEN:F7 T2 列表查询四件套的 UI widget 层。
//
// 覆盖:
//   - TxnFilterBar 搜索框(FR-2):**onSubmitted 提交**(逐键提交会导致整页
//     Loading 替换卸载 filter_bar、输入焦点丢失 —— fix round 1 改提交制);
//     连续输入+提交后仍可继续输入/回调收到完整词;清除钮离散提交;
//     未提交缓冲不因无关重建被清空;重置一并回默认并清空输入框。
//   - TxnFilterBar 排序控件(FR-3):点选四态 → 回调带对应 sortKey/sortDir;
//     按钮显示当前态。
//   - TxnPagerBar(FR-4):第 1 页禁上一页 / 末页禁下一页 / loading 双禁;
//     「第 N 页」文本;按钮回调。
//   - MobileFilterSheet:搜索 + 排序进草稿(逐键 onChanged 草稿模式,不动),
//     「应用筛选」一次性回传。
//
// 主题:AppTheme.light() 注入 R8 语义令牌(context.yucai),禁裸色。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/pages/transactions_page.dart';
import 'package:yucai_client/transaction/presentation/widgets/filter_bar.dart';

Widget _harness(Widget child, {Size size = const Size(1440, 900)}) {
  return MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(size: size),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('TxnFilterBar 搜索框 (FR-2)', () {
    testWidgets(
        '逐键输入不提交(修复:逐键整页重载致焦点丢失),提交动作回调整词',
        (tester) async {
      TxnFilterState? captured;
      await tester.pumpWidget(_harness(TxnFilterBar(
        state: const TxnFilterState(),
        onChanged: (s) => captured = s,
      )));

      // 连续两次输入(未提交):onChanged 不应被触发。
      await tester.enterText(find.byType(TextField), '午');
      await tester.pump();
      expect(captured, isNull, reason: '逐键输入不应逐键提交(列表筛选条)');
      await tester.enterText(find.byType(TextField), '午餐');
      await tester.pump();
      expect(captured, isNull);

      // 提交动作(回车/完成键):回调收到完整词。
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(captured?.searchText, '午餐', reason: '提交动作应携带完整输入词');

      // 提交后仍可继续输入并再次提交(焦点/控制器不被提交重载打断)。
      await tester.enterText(find.byType(TextField), '晚餐');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pump();
      expect(captured?.searchText, '晚餐');
    });

    testWidgets('清除钮 → 离散提交 searchText 归 null', (tester) async {
      TxnFilterState? captured;
      await tester.pumpWidget(_harness(TxnFilterBar(
        state: const TxnFilterState(searchText: '午餐'),
        onChanged: (s) => captured = s,
      )));

      // 非空输入时渲染 suffix 清除钮。
      final clear = find.byIcon(LucideIcons.x);
      expect(clear, findsOneWidget);
      await tester.tap(clear);
      await tester.pump();

      expect(captured?.searchText, isNull, reason: '清除后不应再视为过滤');
    });

    testWidgets('未提交的输入缓冲不因无关重建被清空(账户下拉变更不打断输入)', (tester) async {
      // 场景:用户输入到一半,另一个筛选维度(账户下拉)先变化触发重建 ——
      // 未提交的搜索缓冲应保留在输入框里。
      var state = const TxnFilterState();
      late StateSetter setSheetState;
      await tester.pumpWidget(_harness(StatefulBuilder(
        builder: (context, setState) {
          setSheetState = setState;
          return TxnFilterBar(
            state: state,
            onChanged: (s) => state = s,
            accountOptions: const [FilterOption('a1', '招商银行')],
          );
        },
      )));

      await tester.enterText(find.byType(TextField), '午');
      await tester.pump();

      // 模拟用户改账户下拉(父级以同 searchText 重建,value 未变)。
      setSheetState(() {});
      await tester.pump();

      // 输入缓冲仍在(uncommitted buffer 不被回写覆盖)。
      expect(find.widgetWithText(TextField, '午'), findsOneWidget,
          reason: '无关重建不应清空未提交的搜索输入');
    });

    testWidgets('重置按钮 → 搜索/排序一并回默认', (tester) async {
      TxnFilterState? captured;
      await tester.pumpWidget(_harness(TxnFilterBar(
        state: const TxnFilterState(
          searchText: '午餐',
          sortKey: TxnSortKey.amount,
          sortDir: TxnSortDir.asc,
        ),
        onChanged: (s) => captured = s,
      )));

      await tester.tap(find.text('重置'));
      await tester.pump();

      expect(captured?.searchText, isNull);
      expect(captured?.sortKey, TxnSortKey.date);
      expect(captured?.sortDir, TxnSortDir.desc);
    });

    testWidgets('重置后输入框被清空(value 外部变更回写)', (tester) async {
      var state = const TxnFilterState(searchText: '午餐');
      await tester.pumpWidget(_harness(StatefulBuilder(
        builder: (context, setState) => TxnFilterBar(
          state: state,
          onChanged: (s) => setState(() => state = s),
        ),
      )));
      expect(find.widgetWithText(TextField, '午餐'), findsOneWidget);

      await tester.tap(find.text('重置'));
      await tester.pump();

      expect(find.widgetWithText(TextField, ''), findsOneWidget,
          reason: '外部重置应把输入框同步回空');
    });
  });

  group('TxnFilterBar 排序控件 (FR-3)', () {
    Future<void> pumpBar(WidgetTester tester, TxnFilterState initial,
        void Function(TxnFilterState) onChanged) async {
      await tester.pumpWidget(_harness(TxnFilterBar(
        state: initial,
        onChanged: onChanged,
      )));
    }

    testWidgets('当前态显示在按钮上(默认 日期降序)', (tester) async {
      await pumpBar(tester, const TxnFilterState(), (_) {});
      expect(find.text('日期降序'), findsOneWidget);
    });

    testWidgets('点选 金额降序 → 回调 amount/desc', (tester) async {
      TxnFilterState? captured;
      await pumpBar(tester, const TxnFilterState(), (s) => captured = s);

      await tester.tap(find.text('日期降序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('金额降序'));
      await tester.pumpAndSettle();

      expect(captured?.sortKey, TxnSortKey.amount);
      expect(captured?.sortDir, TxnSortDir.desc);
    });

    testWidgets('点选 金额升序 → 回调 amount/asc', (tester) async {
      TxnFilterState? captured;
      await pumpBar(tester, const TxnFilterState(), (s) => captured = s);

      await tester.tap(find.text('日期降序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('金额升序'));
      await tester.pumpAndSettle();

      expect(captured?.sortKey, TxnSortKey.amount);
      expect(captured?.sortDir, TxnSortDir.asc);
    });

    testWidgets('点选 日期升序 → 回调 date/asc', (tester) async {
      TxnFilterState? captured;
      await pumpBar(
          tester,
          const TxnFilterState(
              sortKey: TxnSortKey.amount, sortDir: TxnSortDir.desc),
          (s) => captured = s);

      await tester.tap(find.text('金额降序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日期升序'));
      await tester.pumpAndSettle();

      expect(captured?.sortKey, TxnSortKey.date);
      expect(captured?.sortDir, TxnSortDir.asc);
    });

    testWidgets('点选当前态同项 → 回调仍触发(date/desc 幂等)', (tester) async {
      TxnFilterState? captured;
      await pumpBar(tester, const TxnFilterState(), (s) => captured = s);

      await tester.tap(find.text('日期降序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('日期升序'));
      await tester.pumpAndSettle();

      expect(captured?.sortKey, TxnSortKey.date);
      expect(captured?.sortDir, TxnSortDir.asc);
    });
  });

  group('TxnPagerBar (FR-4)', () {
    // byTooltip 命中的是 Tooltip 节点,需上溯到宿主 IconButton 才能断言
    // onPressed 禁用态。
    IconButton buttonOf(WidgetTester tester, String tooltip) {
      return tester.widget<IconButton>(find.ancestor(
        of: find.byTooltip(tooltip),
        matching: find.byType(IconButton),
      ));
    }

    testWidgets('第 1 页 + hasMore:上一页禁用、下一页可用并回调',
        (tester) async {
      var nextCalled = false;
      await tester.pumpWidget(_harness(TxnPagerBar(
        pageIndex: 0,
        hasMore: true,
        onPrev: () {},
        onNext: () => nextCalled = true,
      )));

      expect(buttonOf(tester, '上一页').onPressed, isNull,
          reason: '第 1 页禁用上一页');

      await tester.tap(find.byTooltip('下一页'));
      await tester.pump();
      expect(nextCalled, isTrue);
    });

    testWidgets('末页(hasMore=false):下一页禁用、上一页可用并回调,显示第 N 页',
        (tester) async {
      var prevCalled = false;
      await tester.pumpWidget(_harness(TxnPagerBar(
        pageIndex: 2,
        hasMore: false,
        onPrev: () => prevCalled = true,
        onNext: () {},
      )));

      expect(buttonOf(tester, '下一页').onPressed, isNull,
          reason: '末页禁用下一页');

      expect(find.text('第 3 页'), findsOneWidget,
          reason: '页码指示 = pageIndex+1');

      await tester.tap(find.byTooltip('上一页'));
      await tester.pump();
      expect(prevCalled, isTrue);
    });

    testWidgets('loading 中双按钮禁用(防连点重复翻页)', (tester) async {
      await tester.pumpWidget(_harness(TxnPagerBar(
        pageIndex: 1,
        hasMore: true,
        loading: true,
        onPrev: () => fail('loading 中上一页不应可点'),
        onNext: () => fail('loading 中下一页不应可点'),
      )));

      expect(buttonOf(tester, '上一页').onPressed, isNull);
      expect(buttonOf(tester, '下一页').onPressed, isNull);
      expect(find.text('第 2 页'), findsOneWidget);
    });
  });

  group('MobileFilterSheet 搜索+排序 (FR-2/3 mobile 草稿)', () {
    testWidgets('输入搜索 + 选排序 → 「应用筛选」一次性回传', (tester) async {
      TxnFilterState? applied;
      await tester.pumpWidget(_harness(
        MobileFilterSheet(
          initial: const TxnFilterState(),
          accountOptions: const [],
          categoryOptions: const [],
          monthOptions: const [],
          onApply: (s) => applied = s,
        ),
        size: const Size(375, 900),
      ));

      await tester.enterText(find.byType(TextField), '地铁');
      await tester.pump();

      await tester.tap(find.text('日期降序'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('金额升序'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('应用筛选'));
      await tester.pumpAndSettle();

      expect(applied?.searchText, '地铁');
      expect(applied?.sortKey, TxnSortKey.amount);
      expect(applied?.sortDir, TxnSortDir.asc);
    });
  });
}
