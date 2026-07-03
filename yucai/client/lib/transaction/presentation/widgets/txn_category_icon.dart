import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 按 flavour 选基础 icon，income/expense 再按分类账户 name 细化到更贴合
/// 的分类 icon（御财模型里 income/expense 账户即分类，name 为分类名如
/// 「餐饮」「工资」）。未匹配细化的 → flavour 默认 icon。
///
/// 对齐 OD thin-stroke lucide baseline。transactions_page（列表 icon box）
/// 与 account_detail_page（交易记录 icon）共用，避免重复实现。
///
/// 关键词匹配大小写不敏感。
IconData txnCategoryIcon(TxnFlavour flavour, Account? category) {
  final name = (category?.name ?? '').toLowerCase();
  switch (flavour) {
    case TxnFlavour.income:
      if (_hasAny(name, ['工资', '薪', 'salary'])) return LucideIcons.banknote;
      if (_hasAny(name, ['利息', '收益', 'interest'])) return LucideIcons.percent;
      if (_hasAny(name, ['红包', '退款', 'refund'])) return LucideIcons.gift;
      return LucideIcons.coins;
    case TxnFlavour.expense:
      if (_hasAny(name, ['餐', '食', '饭', 'food', 'meal'])) {
        return LucideIcons.utensils;
      }
      if (_hasAny(name, ['咖啡', 'coffee', 'tea', '茶'])) return LucideIcons.coffee;
      if (_hasAny(name, ['购', '商', 'shop', 'shopping'])) {
        return LucideIcons.shoppingBag;
      }
      if (_hasAny(name, ['车', '交通', '出行', 'transport', 'taxi', 'bus', '地铁'])) {
        return LucideIcons.car;
      }
      if (_hasAny(name, ['娱乐', '游戏', 'entertainment', 'game'])) {
        return LucideIcons.gamepad2;
      }
      if (_hasAny(name, ['医', '药', 'health', 'medical'])) {
        return LucideIcons.heartPulse;
      }
      if (_hasAny(name, ['房', '租', 'rent', 'housing'])) {
        return LucideIcons.home;
      }
      if (_hasAny(name, ['教育', '学', '书', 'education', 'book'])) {
        return LucideIcons.graduationCap;
      }
      if (_hasAny(name, ['旅行', '旅游', 'travel', 'trip'])) {
        return LucideIcons.plane;
      }
      return LucideIcons.receipt;
    case TxnFlavour.transfer:
      return LucideIcons.arrowLeftRight;
    case TxnFlavour.compound:
      return LucideIcons.receipt;
  }
}

bool _hasAny(String haystack, List<String> needles) {
  for (final n in needles) {
    if (haystack.contains(n.toLowerCase())) return true;
  }
  return false;
}
