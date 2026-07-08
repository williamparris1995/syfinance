import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

/// 复式分录展示 —— 对齐 OD `detail-transaction.html` col2 复式分录 card。
///
/// 每条分录一行（je-row）：借/贷 side 字（serif，借红/贷绿）+ 账户名 + 账户类型
/// 副标（「费用账户·Expense」/「资产账户·Asset」）+ 金额（mono，借红/贷绿）。
/// 行间 je-sep 分隔。底部 je-bal（借方/贷方合计 两列）+ je-foot（✓ 借贷平衡 差额）
/// + 可选 je-formula（会计等式 explainer，仅详情页开启）。
///
/// 表单预览不注入 [accountTypeOf]：副标退化为 entry.note（或省略），金额按 side
/// 着色（借红/贷绿）仍显示。
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

  /// accountId → 账户类型。详情页注入以生成账户类型副标 + 会计等式效果标签
  /// （Expense ↑ / Asset ↓ 等）。表单预览不注入，副标省略。
  final AccountType? Function(String accountId)? accountTypeOf;

  final String currencySymbol;

  /// 详情页 true：表下追加「会计等式」explainer（对齐 OD detail je-formula）。
  /// 表单预览 false：仅 je-row + je-bal + je-foot。
  final bool showAccountingFormula;

  @override
  Widget build(BuildContext context) {
    final totalDebit = entries.fold<int>(0, (s, e) => s + e.debitCents);
    final totalCredit = entries.fold<int>(0, (s, e) => s + e.creditCents);
    final balanced = totalDebit == totalCredit;

    return DataCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _TitleRow(),
          for (int i = 0; i < entries.length; i++) ...[
            _EntryRow(entry: entries[i], parent: this),
            if (i != entries.length - 1) const _JeSep(),
          ],
          _JeBal(
            debit: totalDebit,
            credit: totalCredit,
            parent: this,
          ),
          _JeFoot(
            balanced: balanced,
            diff: (totalDebit - totalCredit).abs(),
            currencySymbol: currencySymbol,
          ),
          if (showAccountingFormula)
            _FormulaBlock(parent: this, totalDebit: totalDebit),
        ],
      ),
    );
  }

  String _accountLabel(String id) =>
      accountNameOf?.call(id) ?? (id.length > 6 ? '#${id.substring(0, 6)}' : '#$id');
}

/// 格式化分→「¥380.00」。始终显示（0 → ¥0.00），用于合计/平衡/公式行。
String _fmt(int cents, String symbol) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '$symbol$yuan.$frac';
}

/// AccountType → OD 副标文案（「费用账户·Expense」）。null → null（副标省略）。
String? _accountTypeLabel(AccountType? type) {
  switch (type) {
    case AccountType.asset:
      return '资产账户 · Asset';
    case AccountType.expense:
      return '费用账户 · Expense';
    case AccountType.income:
      return '收入账户 · Income';
    case AccountType.liability:
      return '负债账户 · Liability';
    case AccountType.equity:
      return '权益账户 · Equity';
    case null:
      return null;
  }
}

/// 借/贷方向 × 账户类型 → 英文效果短标签（Expense ↑ / Asset ↓ …）。用于公式行 1。
/// 未知类型返回 null。
String? _effectLabel(EntrySide side, AccountType? type) {
  switch (type) {
    case AccountType.asset:
      return side == EntrySide.debit ? 'Asset ↑' : 'Asset ↓';
    case AccountType.liability:
      return side == EntrySide.debit ? 'Liability ↓' : 'Liability ↑';
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

/// 借/贷方向 × 账户类型 → 中文效果（资产增加/资产减少/费用增加…）。用于公式行 2。
/// null → null（退化为通用平衡陈述）。
String? _effectLabelZh(EntrySide side, AccountType? type) {
  switch (type) {
    case AccountType.asset:
      return side == EntrySide.debit ? '资产增加' : '资产减少';
    case AccountType.liability:
      return side == EntrySide.debit ? '负债减少' : '负债增加';
    case AccountType.equity:
      return side == EntrySide.debit ? '权益减少' : '权益增加';
    case AccountType.expense:
      return side == EntrySide.debit ? '费用增加' : '费用减少';
    case AccountType.income:
      return side == EntrySide.debit ? '收入减少' : '收入增加';
    case null:
      return null;
  }
}

/// OD card-title:gold list icon + 「分笔明细 · 复式分录」(serif) + 右侧
/// 「DOUBLE-ENTRY」(mono small muted)，底部 border。
class _TitleRow extends StatelessWidget {
  const _TitleRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: const [
          Icon(LucideIcons.list, size: 18, color: AppColors.accent),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '分笔明细 · 复式分录',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
                color: AppColors.fg,
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            'DOUBLE-ENTRY',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              letterSpacing: 0.5,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// OD je-row:side(借/贷,serif,借红贷绿) + acc(账户名 + 类型副标) + amt(mono,借红贷绿)。
class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.parent});
  final TransactionEntry entry;
  final JournalEntry parent;

  @override
  Widget build(BuildContext context) {
    final side = entry.entrySide;
    final isDebit = side == EntrySide.debit;
    // OD:借行 amt=expense(红),贷行 amt=income(绿) —— 纯按 side 着色,与账户类型无关。
    final sideColor = isDebit ? AppColors.negative : AppColors.positive;
    final type = parent.accountTypeOf?.call(entry.accountId);
    final typeLabel = _accountTypeLabel(type);
    final amt = _fmt(entry.amountCents, parent.currencySymbol);

    // 副标:详情页有账户类型 → 类型标签;否则退化为 entry.note(表单预览)。
    final String? subtitle =
        typeLabel ?? (entry.note.isNotEmpty ? entry.note : null);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              side.label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
                fontSize: 18,
                color: sideColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  parent._accountLabel(entry.accountId),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.fg,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            amt,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: sideColor,
              letterSpacing: -0.01,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// OD je-sep:行间 1px 分隔(左右 24 缩进)。
class _JeSep extends StatelessWidget {
  const _JeSep();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      height: 1,
      color: AppColors.border,
    );
  }
}

/// OD je-bal:借方合计 / 贷方合计 两列(居中,中间竖分隔)。借方红 / 贷方绿。
class _JeBal extends StatelessWidget {
  const _JeBal({
    required this.debit,
    required this.credit,
    required this.parent,
  });
  final int debit;
  final int credit;
  final JournalEntry parent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _BalCol(
              label: '借方合计',
              value: _fmt(debit, parent.currencySymbol),
              valueColor: AppColors.negative,
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                border:
                    Border(left: BorderSide(color: AppColors.border)),
              ),
              child: _BalCol(
                label: '贷方合计',
                value: _fmt(credit, parent.currencySymbol),
                valueColor: AppColors.positive,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalCol extends StatelessWidget {
  const _BalCol({
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.muted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: valueColor,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// OD je-foot:✓(绿圆 tick) + 借贷平衡 借贷差额 ¥0.00。surfaceAlt 底,居中。
class _JeFoot extends StatelessWidget {
  const _JeFoot({
    required this.balanced,
    required this.diff,
    required this.currencySymbol,
  });

  final bool balanced;
  final int diff;
  final String currencySymbol;

  @override
  Widget build(BuildContext context) {
    final color = balanced ? AppColors.positive : AppColors.negative;
    final label = balanced
        ? '借贷平衡　借贷差额 ${_fmt(diff, currencySymbol)}'
        : '不平衡　借贷差额 ${_fmt(diff, currencySymbol)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              balanced ? LucideIcons.check : LucideIcons.alertTriangle,
              size: 12,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// OD je-formula:会计等式 explainer(灰底小字)。行 1 = 借「X」(Effect) ¥amt ＝
/// 贷「Y」(Effect) ¥amt;行 2 = 该分录使[效果] ¥amt,[效果] ¥amt,权益等式平衡。
///
/// 取首笔借方 + 首笔贷方对照(多行复式简化,完整明细见上方分录)。无账户类型
/// 元数据时退化为通用平衡陈述。
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
    final debitEffectZh = _effectLabelZh(EntrySide.debit, debitType);
    final creditEffectZh = _effectLabelZh(EntrySide.credit, creditType);
    final amt = _fmt(totalDebit, parent.currencySymbol);

    final debitTag = debitEffect == null
        ? '借「$debitName」'
        : '借「$debitName」($debitEffect)';
    final creditTag = creditEffect == null
        ? '贷「$creditName」'
        : '贷「$creditName」($creditEffect)';

    // OD 行 2 顺序:贷方效果(资产减…)在前,借方效果(费用增…)在后。
    final line2 = (debitEffectZh != null && creditEffectZh != null)
        ? '该分录使$creditEffectZh $amt，$debitEffectZh $amt，权益等式始终保持平衡。'
        : '借方合计与贷方合计相等，资产＝负债＋权益等式始终保持平衡。';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '会计等式：',
                style: TextStyle(
                  color: AppColors.fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              TextSpan(
                text: '$debitTag $amt ＝ $creditTag $amt',
                style: const TextStyle(
                  color: AppColors.fg,
                  fontSize: 12,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          Text(
            line2,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
