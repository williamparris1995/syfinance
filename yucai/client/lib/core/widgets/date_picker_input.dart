import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 日期选择输入框：FormField<DateTime>，点击弹出 showDatePicker。
/// 对应 Task 12 设计规范 —— 参考 AmountInput 的 FormField 风格。
class DatePickerInput extends FormField<DateTime> {
  DatePickerInput({
    super.key,
    required String label,
    super.initialValue,
    super.onSaved,
    super.validator,
  }) : super(
          builder: (state) {
            return InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                errorText: state.errorText,
                suffixIcon:
                    const Icon(LucideIcons.calendar, size: 18),
              ),
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: state.context,
                    initialDate: state.value ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) state.didChange(picked);
                },
                child: Text(
                  state.value == null
                      ? '请选择日期'
                      : '${state.value!.year}-${state.value!.month.toString().padLeft(2, '0')}-${state.value!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: state.value == null
                        ? AppColors.muted
                        : AppColors.fg,
                  ),
                ),
              ),
            );
          },
        );
}
