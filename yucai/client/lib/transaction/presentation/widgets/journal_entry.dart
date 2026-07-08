import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 复式分录展示。
///
/// 以表格形式列出 [TransactionEntry]：账户 | 借 | 贷。末行附借贷平衡标注 ——
/// 借贷合计相等显示绿色「平衡」+ ✓，否则红色「不平衡 (差额 ¥X)」。
///
/// 详情页开启 [showAccountingFormula] 后，表下方追加「会计等式 explainer」
/// （借/贷账户 + 效果方向 + 等式平衡说明），对齐 OD detail 复式分录区。表单
/// 预览不开启，保持紧凑。
///
/// 金额单位：分（cents）。accountNameOf 由调用方注入（同 TxnRow）。
class JournalEntry extends StatelessWidget {
  const JournalEntry({
    super.key,
    required this.entries,
    this.accountNameOf,
    this.accountTypeOf,
    this.currencySymbol = '¥',
    this.showAccountingFormula = false,
  });

  final List<TransactionEntry> entries;

  /// accountId → 显示名。调用方注入。
  final String Function(String accountId)? accountNameOf;

  /// accountId → 账户类型。详情页注入以着色借/贷金额 + 生成效果方向标签
  /// （Expense ↑ / Asset ↓ 等）。表单预览不注入，金额保持中性色。
  final AccountType? Function(String accountId)? accountTypeOf;

  final String currencySymbol;

  /// 详情页 true：表下追加「会计等式」explainer（对齐 OD detail）。表单预览
  /// false：仅表格 + 平衡 badge。
  final bool showAccountingFormula;

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
          const Text('分笔明细 · 复式分录',
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
          if (showAccountingFormula) ...[
            const SizedBox(height: AppSpacing.sm),
            _FormulaBlock(parent: this, totalDebit: totalDebit),
          ],
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

/// 借/贷方向 → 会计效果短标签（Expense ↑ / Asset ↓ / Income ↑ …）。未知类型
/// 返回 null（公式行退化为只显示账户名 + 金额）。
String? _effectLabel(EntrySide side, AccountType? type) {
  switch (type) {
    case AccountType.asset:
      return side == EntrySide.debit ? 'Asset ↑' : 'Asset ↓';
    case AccountType.liability:
      return side == EntrySide.debit ? 'Liability ↑' : 'Liability ↓';
    case AccountType.equity:
      return side == EntrySide.debit ? 'Equity ↓' : 'Equity ↑';
    case AccountType.expense:
      return side == EntrySide.debit ? 'Expense ↑' : 'Expense ↓';
    case AccountType.income:
      return side == EntrySide.debit ? 'Income ↓' : 'Income ↑';
    case null:
      return null;
  }
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
    // 详情页注入 accountTypeOf 时，按 OD 给借/贷金额着色：
    //   借 expense / 贷 income / 贷 asset(资产减少) 等显色，其余中性。
    final type = parent.accountTypeOf?.call(entry.accountId);
    final side = entry.entrySide;
    Color? amountColor;
    if (parent.accountTypeOf != null && type != null) {
      if (side == EntrySide.debit && type == AccountType.expense) {
        amountColor = AppColors.negative;
      } else if (side == EntrySide.credit &&
          (type == AccountType.income || type == AccountType.asset)) {
        amountColor = AppColors.positive;
      }
    }
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
              style: TextStyle(
                  color: amountColor ?? AppColors.fg,
                  fontSize: 13,
                  fontWeight:
                      amountColor != null ? FontWeight.w600 : FontWeight.w400,
                  fontFeatures: AppTypography.tabularFigures),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _fmt(entry.creditCents, parent.currencySymbol),
              textAlign: TextAlign.right,
              style: TextStyle(
                  color: amountColor ?? AppColors.fg,
                  fontSize: 13,
                  fontWeight:
                      amountColor != null ? FontWeight.w600 : FontWeight.w400,
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
        ? '借贷平衡 · 差额 ${_fmt(diff, currencySymbol)}'
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

/// 会计等式 explainer（对齐 OD detail 复式分录 je-formula 区）。取首笔借方 +
/// 首笔贷方账户对照（多行复式时为简化，完整明细见表格）。无账户类型元数据时
/// 退化为「借 X = 贷 Y」同额陈述。
class _FormulaBlock extends StatelessWidget {
  const _FormulaBlock({required this.parent, required this.totalDebit});
  final JournalEntry parent;
  final int totalDebit;

  @override
  Widget build(BuildContext context) {
    if (parent.entries.isEmpty) return const SizedBox.shrink();
    TransactionEntry? debitEntry;
    TransactionEntry? creditEntry;
    for (final e in parent.entries) {
      if (debitEntry == null && e.debitCents > 0) debitEntry = e;
      if (creditEntry == null && e.creditCents > 0) creditEntry = e;
    }
    debitEntry ??= parent.entries.first;
    creditEntry ??= parent.entries.first;
    final debitName = parent._accountLabel(debitEntry.accountId);
    final creditName = parent._accountLabel(creditEntry.accountId);
    final debitType = parent.accountTypeOf?.call(debitEntry.accountId);
    final creditType = parent.accountTypeOf?.call(creditEntry.accountId);
    final debitEffect = _effectLabel(EntrySide.debit, debitType);
    final creditEffect = _effectLabel(EntrySide.credit, creditType);

    final debitTag = debitEffect == null
        ? '借「$debitName」'
        : '借「$debitName」($debitEffect)';
    final creditTag = creditEffect == null
        ? '贷「$creditName」'
        : '贷「$creditName」($creditEffect)';
    final amt = _fmt(totalDebit, parent.currencySymbol);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              const TextSpan(
                  text: '会计等式：',
                  style: TextStyle(
                      color: AppColors.fg, fontSize: 12, fontWeight: FontWeight.w600)),
              TextSpan(
                  text: '$debitTag $amt ＝ $creditTag $amt',
                  style: const TextStyle(
                      color: AppColors.fg,
                      fontSize: 12,
                      fontFeatures: AppTypography.tabularFigures)),
            ]),
          ),
          const SizedBox(height: 4),
          const Text(
            '借方合计与贷方合计相等，资产＝负债＋权益等式始终保持平衡。',
            style: TextStyle(color: AppColors.muted, fontSize: 11, height: 1.5),
          ),
        ],
      ),
    );
  }
}
