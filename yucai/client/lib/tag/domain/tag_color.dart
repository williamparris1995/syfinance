import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';

/// `#RRGGBB` → [Color]。解析失败(或无 # 前缀)→ 回退 [AppColors.accent]。
///
/// 列表(txn_row)/ 详情(transaction_detail_page)/ 表单(transaction_form_page)
/// 三处 chip 共享,避 fallback 规则散落多处。
Color tagColor(String hex) {
  try {
    final s = hex.startsWith('#') ? hex.substring(1) : hex;
    return Color(int.parse(s, radix: 16) + 0xFF000000);
  } catch (_) {
    return AppColors.accent;
  }
}
