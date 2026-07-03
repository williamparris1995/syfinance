import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';

/// 复式分录展示。
///
/// 以表格形式列出 [TransactionEntry]：账户 | 借 | 贷。末行附借贷平衡标注 ——
/// 借贷合计相等显示绿色「平衡」+ ✓，否则红色「不平衡 (差额 ¥X)」。
///
/// 金额单位：分（cents）。accountNameOf 由调用方注入（同 TxnRow）。
class JournalEntry extends StatelessWidget {
  const JournalEntry({
    super.key,
    required this.entries,
    this.accountNameOf,
    this.currencySymbol = '¥',
  });

  final List<TransactionEntry> entries;

  /// accountId → 显示名。调用方注入。
  final String Function(String accountId)? accountNameOf;

  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final totalDebit = entries.fold<int>(0, (s, e) => s + e.debitCents);
    final totalCredit = entries.fold<int>(0, (s, e) => s + e.creditCents);
    final balanced = totalDebit == totalCredit;

    return DataCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('分录',
              style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: AppSpacing.sm),
          _HeaderRow(),
          const Divider(height: 1, color: AppColors.border),
          for (final e in entries) _EntryRow(entry: e, parent: this),
          const Divider(height: 1, color: AppColors.border),
          _TotalsRow(debit: totalDebit, credit: totalCredit, parent: this),
          const SizedBox(height: AppSpacing.sm),
          _BalanceBadge(
            balanced: balanced,
            totalDebit: totalDebit,
            totalCredit: totalCredit,
            currencySymbol: currencySymbol,
          ),
        ],
      ),
    );
  }

  String _accountLabel(String id) =>
      accountNameOf?.call(id) ?? (id.length > 6 ? '#${id.substring(0, 6)}' : '#$id');
}

String _fmt(int cents, String symbol) {
  if (cents == 0) return '';
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '$symbol$yuan.$frac';
}

class _HeaderRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w500);
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('账户', style: style)),
          Expanded(flex: 3, child: Text('借', style: style, textAlign: TextAlign.right)),
          Expanded(flex: 3, child: Text('贷', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.parent});
  final TransactionEntry entry;
  final JournalEntry parent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parent._accountLabel(entry.accountId),
                    style: const TextStyle(
                        color: AppColors.fg, fontSize: 13)),
                if (entry.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(entry.note,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11)),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _fmt(entry.debitCents, parent.currencySymbol),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AppColors.fg,
                  fontSize: 13,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _fmt(entry.creditCents, parent.currencySymbol),
              textAlign: TextAlign.right,
              style: const TextStyle(
                  color: AppColors.fg,
                  fontSize: 13,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow(
      {required this.debit, required this.credit, required this.parent});
  final int debit;
  final int credit;
  final JournalEntry parent;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
        color: AppColors.fg,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        fontFeatures: AppTypography.tabularFigures);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Expanded(
              flex: 4,
              child: Text('合计',
                  style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500))),
          Expanded(
              flex: 3,
              child: Text(_fmt(debit, parent.currencySymbol),
                  textAlign: TextAlign.right, style: style)),
          Expanded(
              flex: 3,
              child: Text(_fmt(credit, parent.currencySymbol),
                  textAlign: TextAlign.right, style: style)),
        ],
      ),
    );
  }
}

class _BalanceBadge extends StatelessWidget {
  const _BalanceBadge({
    required this.balanced,
    required this.totalDebit,
    required this.totalCredit,
    required this.currencySymbol,
  });

  final bool balanced;
  final int totalDebit;
  final int totalCredit;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final diff = (totalDebit - totalCredit).abs();
    final color = balanced ? AppColors.positive : AppColors.negative;
    final label = balanced
        ? '借贷平衡'
        : '不平衡 · 差额 ${_fmt(diff, currencySymbol)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(balanced ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
              size: 14, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
