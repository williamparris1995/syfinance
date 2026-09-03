// TDD RED → GREEN:F9-T1 共享分页条 PagerBar 的 widget 单测。
//
// F9 FR-1 / ADR-1:TxnPagerBar(F7,transactions_page 内)提升为
// core/widgets 通用 PagerBar,语义逐位不变 —— 本组 3 测**照搬** F7 的
// list_query_widgets_test pager 3 测(只改 import/引用,不改断言语义),
// 迁移后保绿即「泛化无漂移」的验收门。
//
// 覆盖:
//   - 第 1 页(pageIndex==0)禁用上一页;末页(hasMore==false)禁用下一页。
//   - loading(翻页请求中)双按钮禁用(防连点重复翻页)。
//   - 「第 N 页」文本指示 = pageIndex + 1;按钮回调。
//
// 主题:AppTheme.light() 注入 R8 语义令牌(context.yucai),禁裸色。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/theme/app_theme.dart';
import 'package:yucai_client/core/widgets/pager_bar.dart';

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
  // byTooltip 命中的是 Tooltip 节点,需上溯到宿主 IconButton 才能断言
  // onPressed 禁用态。
  IconButton buttonOf(WidgetTester tester, String tooltip) {
    return tester.widget<IconButton>(find.ancestor(
      of: find.byTooltip(tooltip),
      matching: find.byType(IconButton),
    ));
  }

  group('PagerBar (F9 泛化自 F7 TxnPagerBar, FR-1 语义不变(承 F7 FR-4))', () {
    testWidgets('第 1 页 + hasMore:上一页禁用、下一页可用并回调',
        (tester) async {
      var nextCalled = false;
      await tester.pumpWidget(_harness(PagerBar(
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
      await tester.pumpWidget(_harness(PagerBar(
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
      await tester.pumpWidget(_harness(PagerBar(
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
}
