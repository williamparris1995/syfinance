import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 按 flavour 选基础 icon，income/expense 再按分类账户 name **或** 交易描述
/// 细化到更贴合的分类 icon（御财模型里 income/expense 账户即分类，name 为分
/// 类名如「餐饮」「工资」）。未匹配细化的 → flavour 默认 icon。
///
/// 关键词同时匹配 [category].name 与 [description]（交易名称/商户）：这样在
/// 「同分类近期交易」里(同 category,不同商户名)也能给出差异化 icon —— 例如
/// 分类=「餐饮」但交易名含「星巴克/咖啡」→ coffee icon(对齐 OD rel-row 的
/// per-merchant icon 变化,而非全列表同一 icon)。分类名优先级等价于描述。
///
/// 对齐 OD thin-stroke lucide baseline。transactions_page（列表 icon box）
/// 与 transaction_detail_page（rel-row）共用，避免重复实现。
///
/// 关键词匹配大小写不敏感。
IconData txnCategoryIcon(
  TxnFlavour flavour,
  Account? category, {
  String description = '',
}) {
  final cat = (category?.name ?? '').toLowerCase();
  final desc = description.toLowerCase();
  bool has(List<String> needles) {
    for (final n in needles) {
      final nl = n.toLowerCase();
      if (cat.contains(nl) || desc.contains(nl)) return true;
    }
    return false;
  }

  switch (flavour) {
    case TxnFlavour.income:
      if (has(['工资', '薪', 'salary'])) return LucideIcons.banknote;
      if (has(['利息', '收益', 'interest'])) return LucideIcons.percent;
      if (has(['红包', '退款', 'refund'])) return LucideIcons.gift;
      return LucideIcons.coins;
    case TxnFlavour.expense:
      if (has(['餐', '食', '饭', '外卖', 'food', 'meal'])) {
        return LucideIcons.utensils;
      }
      if (has(['咖啡', '星巴克', 'coffee', 'tea', '茶', '奶茶'])) {
        return LucideIcons.coffee;
      }
      if (has(['购', '商', 'shop', 'shopping'])) {
        return LucideIcons.shoppingBag;
      }
      if (has(['车', '交通', '出行', 'transport', 'taxi', 'bus', '地铁'])) {
        return LucideIcons.car;
      }
      if (has(['娱乐', '游戏', 'entertainment', 'game'])) {
        return LucideIcons.gamepad2;
      }
      if (has(['医', '药', 'health', 'medical'])) {
        return LucideIcons.heartPulse;
      }
      if (has(['房', '租', 'rent', 'housing'])) {
        return LucideIcons.home;
      }
      if (has(['教育', '学', '书', 'education', 'book'])) {
        return LucideIcons.graduationCap;
      }
      if (has(['旅行', '旅游', 'travel', 'trip'])) {
        return LucideIcons.plane;
      }
      return LucideIcons.receipt;
    case TxnFlavour.transfer:
      return LucideIcons.arrowLeftRight;
    case TxnFlavour.compound:
      return LucideIcons.receipt;
  }
}
