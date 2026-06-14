import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// 金额输入框：左侧币种前缀 + 数字键盘 + 等宽对齐数字。
/// 对应设计规范 §3.3「AmountInput」。
class AmountInput extends StatelessWidget {
  const AmountInput({
    super.key,
    required this.controller,
    this.currencySymbol = '¥',
    this.label,
    this.hintText = '0.00',
    this.validator,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String currencySymbol;
  final String? label;
  final String hintText;
  final String? Function(String?)? validator;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
      ],
      style: const TextStyle(
        fontSize: 16,
        fontFeatures: AppTypography.tabularFigures,
      ),
      textAlign: TextAlign.right,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixText: '$currencySymbol ',
        prefixStyle: const TextStyle(
          color: AppColors.muted,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      validator: validator,
    );
  }
}
