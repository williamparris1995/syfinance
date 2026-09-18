import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/recurrence/recurrence_rule.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule_editor.dart';

class Holder {
  RecurrenceRule? value;
}

Future<void> pumpEditor(
  WidgetTester tester,
  Holder holder, {
  RecurrenceRule initial = const RecurrenceRule(),
  RecurrenceAnchor anchor = RecurrenceAnchor.billingDay,
}) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: FilledButton(
            onPressed: () async {
              holder.value = await showRecurrenceRuleEditor(
                context,
                initial: initial,
                anchor: anchor,
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('预设「每季度」→ preview 与返回值 interval=3', (tester) async {
    final holder = Holder();
    await pumpEditor(tester, holder);
    // 初始规则 = 每月(裸);预设下拉当前显示「每月」(树中首个)。
    await tester.tap(find.text('每月').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('每季度').last);
    await tester.pumpAndSettle();
    expect(find.text('每 3 个月'), findsOneWidget); // preview 实时文案
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(holder.value?.cycle, RecurrenceCycle.monthly);
    expect(holder.value?.interval, 3);
    expect(holder.value?.monthlyMode, RecurrenceMonthlyMode.byDate);
  });

  testWidgets('预设「工作日」→ 全周掩码', (tester) async {
    final holder = Holder();
    await pumpEditor(tester, holder);
    await tester.tap(find.text('每月').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作日(周一至周五)').last);
    await tester.pumpAndSettle();
    expect(find.text('工作日(周一至周五)'), findsAtLeastNWidgets(1));
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(holder.value?.cycle, RecurrenceCycle.weekly);
    expect(holder.value?.weekdayMask, RecurrenceRule.maskWeekdays);
  });

  testWidgets('月度切换「按第 N 个星期几」显示第几个/星期下拉', (tester) async {
    await pumpEditor(tester, Holder());
    await tester.tap(find.text('按第 N 个星期几'));
    await tester.pumpAndSettle();
    expect(find.text('第 1 个'), findsOneWidget);
    expect(find.text('周一'), findsWidgets);
  });

  testWidgets('借贷锚点隐藏账单日选择,显示对齐说明', (tester) async {
    await pumpEditor(tester, Holder(), anchor: RecurrenceAnchor.startDate);
    expect(find.text('跟随起始日'), findsNothing);
    expect(find.textContaining('与起始日期对齐'), findsOneWidget);
  });

  testWidgets('取消返回 null', (tester) async {
    final holder = Holder();
    await pumpEditor(tester, holder);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(holder.value, isNull);
  });

  testWidgets('weekly 规则显示星期 chips 与提示', (tester) async {
    await pumpEditor(
      tester,
      Holder(),
      initial: const RecurrenceRule(cycle: RecurrenceCycle.weekly),
    );
    expect(find.text('重复于(星期)'), findsOneWidget);
    expect(find.text('不选则按起始日期的星期'), findsOneWidget);
    await tester.tap(find.text('周五'));
    await tester.pumpAndSettle();
    expect(find.text('不选则按起始日期的星期'), findsNothing);
  });

  testWidgets('preview 实时反映规则文案', (tester) async {
    await pumpEditor(
      tester,
      Holder(),
      initial: const RecurrenceRule(
        cycle: RecurrenceCycle.monthly,
        monthlyMode: RecurrenceMonthlyMode.byNthWeekday,
        nth: 5,
        weekdayMask: 1 << 4,
      ),
    );
    expect(find.text('每月最后一个周五'), findsOneWidget);
  });
}
