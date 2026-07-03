import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// category → 显示色（accounts_page + account_detail_page 共用）。
///
/// 从两页各自的私有 `_categoryColor` 提取为顶层函数，避免重复 switch。
Color categoryColor(AccountCategory c) {
  switch (c) {
    case AccountCategory.savings:
      return AppColors.positive;
    case AccountCategory.creditCard:
      return const Color(0xFF6B8CCE);
    case AccountCategory.investment:
      return AppColors.accent;
    case AccountCategory.fixedDeposit:
      return const Color(0xFF8A8A6B);
    case AccountCategory.goldFx:
      return const Color(0xFFC9A03D);
    case AccountCategory.realEstate:
      return const Color(0xFF8C7BB5);
    case AccountCategory.loan:
      return AppColors.negative;
    case AccountCategory.otherAsset:
      return AppColors.muted;
    case AccountCategory.otherLiability:
      return AppColors.negative;
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
