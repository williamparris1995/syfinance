import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/debt_view_semantics.dart';

/// 删除债权/债务二次确认。
///
/// 删除不可恢复(borrowedIn 剩余≠0 还会生成清账分录改变账户余额),
/// 列表卡「更多」菜单与 debt/receivable 详情页 AppBar「更多」共用本确认,
/// 杜绝单次误触即永久删除。
Future<bool> confirmDeleteDebt(
  BuildContext context,
  DebtViewSemantics sem,
  String counterparty,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(
      title: Text(sem.deleteConfirmTitle),
      content: SizedBox(
        width: 420,
        child: Text(
          '「$counterparty」删除后无法恢复，${sem.scheduleTitle}将一并删除；'
          '已记录的${sem.isReceivable ? '收款' : '还款'}交易保留。',
          style: TextStyle(fontSize: 13.5, color: context.yucai.muted, height: 1.6),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dctx, false),
          child: const Text('取消'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: context.yucai.negative,
          ),
          onPressed: () => Navigator.pop(dctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return ok ?? false;
}
