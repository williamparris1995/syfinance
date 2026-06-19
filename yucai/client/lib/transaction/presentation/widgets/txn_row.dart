import 'package:flutter/material.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 交易列表行。
///
/// - Desktop/Tablet：表格行 —— 日期 | 描述 | 分类 | 金额（借/贷方向染色）
/// - Mobile：卡片 —— 上行描述+日期，下行分类 chip + 金额
///
/// [accountNameOf] 把 entry.accountId 解析为显示名（调用方注入，避免本组件
/// 依赖 account repository）。若未提供则显示账号短 id。
class TxnRow extends StatelessWidget {
  const TxnRow({
    super.key,
    required this.txn,
    this.breakpoint,
    this.accountNameOf,
    this.onTap,
    this.currencySymbol = '¥',
  });

  final Transaction txn;

  /// 显式断点；为 null 时从 [BuildContext] 读取。
  final Breakpoint? breakpoint;

  /// accountId → 显示名。调用方注入。
  final String Function(String accountId)? accountNameOf;

  final VoidCallback? onTap;
  final String currencySymbol;

  Breakpoint _resolve(BuildContext ctx) => breakpoint ?? Breakpoints.of(ctx);

  /// 派生本交易的整体 flavour（供金额染色）。
  /// 复式交易若同时有借有贷到非现金账户，归为 [TxnFlavour.compound]，金额按净额染色。
  TxnFlavour get _flavour => _inferFlavour(txn);

  @override
  Widget build(BuildContext context) {
    final bp = _resolve(context);
    return bp == Breakpoint.mobile
        ? _MobileRow(txn: txn, row: this)
        : _TableRow(txn: txn, row: this);
  }

  String _accountLabel(String id) {
    final name = accountNameOf?.call(id);
    if (name != null) return name;
    return id.length > 6 ? '#${id.substring(0, 6)}' : '#$id';
  }
}

/// 推断 flavour：取首条非空 entry 的 side 作为代表。复式多行 → compound。
TxnFlavour _inferFlavour(Transaction txn) {
  if (txn.entries.length != 2) return TxnFlavour.compound;
  // 简化：若两条都是 debit+credit 互配（典型收入/支出），看「钱从哪来」。
  // income: 钱进某资产账户 → 该资产 debit；expense: 钱出 → 该资产 credit。
  // 无账户元信息时退回 compound；UI 染色仅参考 net。
  final net = txn.totalDebitCents - txn.totalCreditCents;
  if (net.abs() == 0) return TxnFlavour.transfer;
  // 由调用方注入 accountNameOf 时通常无法在这里判断方向，保守归 compound。
  return TxnFlavour.compound;
}

Color _amountColor(TxnFlavour f) {
  switch (f) {
    case TxnFlavour.income:
      return AppColors.positive;
    case TxnFlavour.expense:
      return AppColors.negative;
    case TxnFlavour.transfer:
      return AppColors.fg;
    case TxnFlavour.compound:
      return AppColors.fg;
  }
}

String _formatDate(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _formatCents(int cents, String symbol, {bool signed = false}) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  final sign = signed && cents < 0 ? '-' : '';
  return '$sign$symbol$yuan.$frac';
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.txn, required this.row});
  final Transaction txn;
  final TxnRow row;

  @override
  Widget build(BuildContext context) {
    final flavour = row._flavour;
    final amount = txn.totalDebitCents; // 表格用主金额（借方合计）展示
    final primaryAccount = txn.entries.isNotEmpty
        ? row._accountLabel(txn.entries.first.accountId)
        : '';
    return InkWell(
      onTap: row.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(_formatDate(txn.transactionDate),
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                      fontFeatures: AppTypography.tabularFigures)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              flex: 3,
              child: Text(
                txn.description.isEmpty ? '(无描述)' : txn.description,
                style:
                    const TextStyle(color: AppColors.fg, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 120,
              child: Text(primaryAccount,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12),
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 120,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _formatCents(amount, row.currencySymbol, signed: true),
                  style: TextStyle(
                    color: _amountColor(flavour),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileRow extends StatelessWidget {
  const _MobileRow({required this.txn, required this.row});
  final Transaction txn;
  final TxnRow row;

  @override
  Widget build(BuildContext context) {
    final flavour = row._flavour;
    final amount = txn.totalDebitCents;
    final primaryAccount = txn.entries.isNotEmpty
        ? row._accountLabel(txn.entries.first.accountId)
        : '';
    return GestureDetector(
      onTap: row.onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.smBorder,
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description.isEmpty ? '(无描述)' : txn.description,
                    style: const TextStyle(
                        color: AppColors.fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatDate(txn.transactionDate)} · $primaryAccount',
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              _formatCents(amount, row.currencySymbol, signed: true),
              style: TextStyle(
                color: _amountColor(flavour),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
