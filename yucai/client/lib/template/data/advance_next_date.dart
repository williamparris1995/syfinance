/// 周期模板 nextDate 推进(兼容适配层)。
///
/// 历史:本文件曾是推进算法的 client oracle(FR-5);周期规则统一后算法
/// 本体移至共享内核 `core/recurrence/next_after.dart`(与 server
/// internal/shared/domain/recurrence 同用例集),此处仅做 int 参数 →
/// RecurrenceRule 的薄适配,保留旧签名供既有调用方与测试使用。
/// 语义:c cycle 1=weekly/2=monthly/3=yearly/4=custom(按天);月度带
/// billingDay 钳制月末;yearly 2/29 → 2/28;custom 按 cycleDays(≤0 视为 1)。
library;

import 'package:yucai_client/core/recurrence/next_after.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule.dart';

DateTime advanceNextDate(
  DateTime current, {
  required int cycle,
  int cycleDays = 0,
  int billingDay = 0,
  int interval = 0,
  int weekdayMask = 0,
  int monthlyMode = 0,
  int nth = 0,
}) =>
    nextAfter(
      current,
      RecurrenceRule.fromInts(
        cycle: cycle,
        cycleDays: cycleDays,
        billingDay: billingDay,
        interval: interval,
        weekdayMask: weekdayMask,
        monthlyMode: monthlyMode,
        nth: nth,
      ),
    );
