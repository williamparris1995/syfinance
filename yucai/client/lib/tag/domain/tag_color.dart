import 'package:flutter/material.dart';

/// `#RRGGBB` → [Color]。解析失败(或无 # 前缀)→ 回退调用方注入的 [fallback]。
///
/// 列表(txn_row)/ 详情(transaction_detail_page)/ 表单(transaction_form_page)
/// 三处 chip 共享,避 fallback 规则散落多处。
///
/// F4-P2:domain 层拿不到 context,回退色由 presentation 调用方注入
/// `context.yucai.accent`(暗色下自动切鎏金;原硬编码 accent 静态亮值会在
/// 暗色下漏翡翠绿)。
Color tagColor(String hex, {required Color fallback}) {
  try {
    final s = hex.startsWith('#') ? hex.substring(1) : hex;
    return Color(int.parse(s, radix: 16) + 0xFF000000);
  } catch (_) {
    return fallback;
  }
}
