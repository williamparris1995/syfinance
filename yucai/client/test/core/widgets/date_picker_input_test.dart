// F38 — DatePickerInput 归一化测试:选择器产出的 DateTime 必须是 UTC 零点
// (日期字段全链一致,消除本地/UTC 混用的 8 小时偏移)。
// 判别原理:本地时区(UTC+8)下,「本地零点」与「UTC 零点」的 epoch 不同,
// DateTime 相等性按 epoch 比较 —— 归一化缺失时断言失败。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/widgets/date_picker_input.dart';

void main() {
  testWidgets('F38:选择日期 → onSaved 收到 UTC 零点(civil 日期不变)',
      (t) async {
    final formKey = GlobalKey<FormState>();
    DateTime? saved;
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          key: formKey,
          child: DatePickerInput(
            label: '日期',
            initialValue: DateTime.utc(2026, 8, 1),
            onSaved: (v) => saved = v,
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('2026-08-01'), findsOneWidget);

    // 打开选择器(点击字段),直接点 OK(选中 initial 的 civil 日)。
    await t.tap(find.byType(InkWell).first);
    await t.pumpAndSettle();
    await t.tap(find.text('OK'));
    await t.pumpAndSettle();
    formKey.currentState!.save();

    // 归一化断言:UTC 零点(而非本地零点 —— 二者 epoch 相差 8 小时)。
    expect(saved, DateTime.utc(2026, 8, 1));
  });

  testWidgets('F38:显示恒为 civil 日期(YYYY-MM-DD,无时刻成分)', (t) async {
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Form(
          child: DatePickerInput(
            label: '日期',
            initialValue: DateTime.utc(2026, 8, 1),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.textContaining('T0'), findsNothing);
    expect(find.text('2026-08-01'), findsOneWidget);
  });
}
