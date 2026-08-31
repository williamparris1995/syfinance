import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 时间选择输入框（Task 5）：点击弹出 [showTimePicker]。
///
/// 风格对齐 [DatePickerInput] —— `InputDecorator` + `InkWell` + 后缀图标。
/// 属于「详情」分区里「交易日期」旁边的「交易时间」字段，用于让用户为
/// 记一笔附加 HH:MM 时间，提交时与日期拼成 RFC3339 `transaction_time`。
///
/// 与 [DatePickerInput] 不同的是，时间选择不参与 `Form.validate/save`
/// 生命周期：值由父级通过 [onChanged] 直接拿走（TimeOfDay 不适合塞进
/// FormField<void> 的泛型状态里），默认值由父级传入 `initialTime`。
class TimePickerInput extends StatelessWidget {
  const TimePickerInput({
    super.key,
    required this.label,
    required this.initialTime,
    this.onChanged,
  });

  final String label;

  /// 当前展示的时间。父级持有真正的状态（默认 `TimeOfDay.now()`）。
  final TimeOfDay initialTime;

  /// 用户选了新时间（取消选择器不触发）。
  final ValueChanged<TimeOfDay>? onChanged;

  String _format(BuildContext context, TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    // 不使用 MaterialLocalizations 时钟 12h 文案 —— 记一笔要的是 HH:MM。
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(LucideIcons.clock, size: 18),
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: initialTime,
            helpText: label,
          );
          if (picked != null) onChanged?.call(picked);
        },
        child: Text(
          _format(context, initialTime),
          style: TextStyle(color: context.yucai.fg),
        ),
      ),
    );
  }
}
