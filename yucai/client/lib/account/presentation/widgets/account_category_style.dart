import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// category → 显示色（accounts_page + account_detail_page 共用）。
///
/// 从两页各自的私有 `_categoryColor` 提取为顶层函数，避免重复 switch。
///
/// F4-P2 裁决:储蓄/投资/贷款/其他负债等语义位直接走 context.yucai 令牌
/// （暗色跟随主题提亮）;creditCard/fixedDeposit/goldFx/realEstate 为类目
/// 身份色 —— 中饱和中间调,墨黑底上对比 ≥4.5:1 且不刺眼,满足豁免标准
/// （暗色下可辨识且不刺眼）,保原值不迁（注释列出,见 feature.md 豁免清单）。
Color categoryColor(BuildContext context, AccountCategory c) {
  switch (c) {
    case AccountCategory.savings:
      return context.yucai.positive;
    case AccountCategory.creditCard:
      return const Color(0xFF6B8CCE); // 身份色:信用卡蓝(双板共用)
    case AccountCategory.investment:
      return context.yucai.accent;
    case AccountCategory.fixedDeposit:
      return const Color(0xFF8A8A6B); // 身份色:定期橄榄(双板共用)
    case AccountCategory.goldFx:
      return const Color(0xFFC9A03D); // 身份色:黄金金黄(双板共用)
    case AccountCategory.realEstate:
      return const Color(0xFF8C7BB5); // 身份色:房产紫(双板共用)
    case AccountCategory.loan:
      return context.yucai.negative;
    case AccountCategory.otherAsset:
      return context.yucai.muted;
    case AccountCategory.otherLiability:
      return context.yucai.negative;
  }
}

/// category → 图标（accounts_page + account_detail_page 共用）。
IconData categoryIcon(AccountCategory c) {
  // 对齐 OD thin-stroke lucide baseline + account_detail_page 既有映射。
  switch (c) {
    case AccountCategory.savings:
      return LucideIcons.landmark;
    case AccountCategory.creditCard:
      return LucideIcons.creditCard;
    case AccountCategory.investment:
      return LucideIcons.trendingUp;
    case AccountCategory.fixedDeposit:
      return LucideIcons.hourglass;
    case AccountCategory.goldFx:
      return LucideIcons.gem;
    case AccountCategory.realEstate:
      return LucideIcons.building2;
    case AccountCategory.loan:
      return LucideIcons.landmark;
    case AccountCategory.otherAsset:
      return LucideIcons.wallet;
    case AccountCategory.otherLiability:
      return LucideIcons.wallet;
  }
}
