import 'package:flutter/material.dart';

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
  switch (c) {
    case AccountCategory.savings:
      return Icons.account_balance_wallet_outlined;
    case AccountCategory.creditCard:
      return Icons.credit_card_outlined;
    case AccountCategory.investment:
      return Icons.trending_up;
    case AccountCategory.fixedDeposit:
      return Icons.hourglass_bottom;
    case AccountCategory.goldFx:
      return Icons.diamond_outlined;
    case AccountCategory.realEstate:
      return Icons.home_outlined;
    case AccountCategory.loan:
      return Icons.request_quote_outlined;
    case AccountCategory.otherAsset:
      return Icons.inventory_2_outlined;
    case AccountCategory.otherLiability:
      return Icons.pending_actions;
  }
}
