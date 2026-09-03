import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';

// ───────────────── F9 FR-1/ADR-1(承 F7 FR-4 语义):通用页码分页条 ─────────────────

/// 页码分页条:上一页/下一页 + 「第 N 页」指示。
///
/// **F9 FR-1/ADR-1 提升**:由 F7 交易套件的 `TxnPagerBar`(transactions_page
/// 内)泛化为 core/widgets 共享组件,各列表页(交易/账户详情内嵌交易/持仓等)
/// 复用;FR-1 语义不变(承 F7 FR-4),逐位零漂移(NFR-1)—— F7 的 pager 3 测
/// 随迁移保绿即验收门。
///
/// - 第 1 页(pageIndex==0)禁用上一页;末页(hasMore==false)禁用下一页;
///   [loading](翻页请求中)双禁防连点,并追加小 spinner。
/// - 单页(hasMore==false 且 pageIndex==0)由调用方整个隐藏(本条不自带
///   隐藏逻辑,与 F7 一致)。
/// - 颜色/排版走 R8 语义令牌([BuildContext.yucai]),禁裸色。
class PagerBar extends StatelessWidget {
  const PagerBar({
    super.key,
    required this.pageIndex,
    required this.hasMore,
    required this.onPrev,
    required this.onNext,
    this.loading = false,
  });

  /// 当前页码(0 起;显示「第 N 页」= pageIndex+1)。
  final int pageIndex;

  /// 是否还有下一页(来自 bloc 的 nextPageToken 非空)。
  final bool hasMore;

  /// 翻页请求进行中(如 TransactionsLoadingMore):双按钮禁用。
  final bool loading;

  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final onFirstPage = pageIndex <= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: '上一页',
          icon: const Icon(LucideIcons.chevronLeft, size: 18),
          onPressed: (onFirstPage || loading) ? null : onPrev,
        ),
        Text('第 ${pageIndex + 1} 页',
            style: TextStyle(
                color: context.yucai.muted,
                fontSize: 13,
                fontFeatures: AppTypography.tabularFigures)),
        IconButton(
          tooltip: '下一页',
          icon: const Icon(LucideIcons.chevronRight, size: 18),
          onPressed: (!hasMore || loading) ? null : onNext,
        ),
        if (loading)
          const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }
}
