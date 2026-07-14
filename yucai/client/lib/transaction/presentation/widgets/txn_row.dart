import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/tag/domain/tag_color.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 交易列表行。
///
/// **StatefulWidget**（非纯 layout row）：[_TxnRowState] 在 initState 为每张
/// card 缓存一次 GetTransactionTags 结果（[_tags]），rebuild 不重查；ListView
/// 元素复用时 didUpdateWidget 按 txn id 变化重拉并清 stale chips。失败/空 →
/// `_tags = []` 降级，列表照常渲染不阻塞。
///
/// - Desktop/Tablet：表格行 —— 日期 | 描述 | 分类 | 金额（借/贷方向染色）
/// - Mobile：卡片 —— 上行描述+日期，下行分类 chip + 金额
///
/// 账户列分支（Task 3 / P0-3）：
///   - 转账（两条 entry 且都是 asset 账户）：「转出 → 转入」双账户 + 箭头。
///     from = creditCents>0 的 entry（贷方=转出）/ to = debitCents>0（借方=转入）。
///   - 非转账（收入/支出）：单 asset 账户名 + 分类 chip（Expense 红 / Income 绿）。
///
/// 账户解析优先用 [accounts]（accountId → Account）。若未提供则退化为
/// [accountNameOf]，再退化为账号短 id。
class TxnRow extends StatefulWidget {
  const TxnRow({
    super.key,
    required this.txn,
    this.breakpoint,
    this.accounts = const <String, Account>{},
    this.accountNameOf,
    this.onTap,
    this.currencySymbol = '¥',
  });

  final Transaction txn;

  /// 显式断点；为 null 时从 [BuildContext] 读取。
  final Breakpoint? breakpoint;

  /// accountId → Account 缓存（调用方注入）。驱动转账分支与分类 chip。
  final Map<String, Account> accounts;

  /// accountId → 显示名（无 accounts 时的退化路径）。
  final String Function(String accountId)? accountNameOf;

  final VoidCallback? onTap;
  final String currencySymbol;

  Breakpoint _resolve(BuildContext ctx) => breakpoint ?? Breakpoints.of(ctx);

  TxnFlavour get _flavour => _inferFlavour(txn);

  /// 是否为转账：恰好两条 entry，且两端账户都能在 [accounts] 中解析为
  /// asset 类型（无 accounts 元信息时退化为「两条 entry 且平衡」）。
  bool get _isTransfer {
    if (txn.entries.length != 2) return false;
    if (accounts.isEmpty) return txn.isBalanced;
    final e0 = accounts[txn.entries[0].accountId];
    final e1 = accounts[txn.entries[1].accountId];
    // 两端都解析得到且都是 asset → 转账。任一端是 income/expense → 收支。
    if (e0 == null || e1 == null) return txn.isBalanced;
    return e0.accountType == AccountType.asset &&
        e1.accountType == AccountType.asset;
  }

  String _accountLabel(String id) {
    final acct = accounts[id];
    if (acct != null) return acct.name;
    final name = accountNameOf?.call(id);
    if (name != null) return name;
    return id.length > 6 ? '#${id.substring(0, 6)}' : '#$id';
  }

  @override
  State<TxnRow> createState() => _TxnRowState();
}

/// 持有 per-card tag 缓存：initState 加载一次 GetTransactionTags，rebuild
/// 不重查。didUpdateWidget 在 element 复用(LV.builder 回收)且 txn id 变化时
/// 重新拉取。失败/空 → `_tags = []` 降级，列表照常渲染不阻塞。
class _TxnRowState extends State<TxnRow> {
  List<Tag> _tags = const [];

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void didUpdateWidget(covariant TxnRow old) {
    super.didUpdateWidget(old);
    // ListView.builder 元素复用时，State 可能被套到不同 txn 上 —— id 变了先清 stale
    // chips 再重拉，避复用前几帧把 A 的 tags 渲染在 B 描述下（async id guard 防
    // stale *data* 写回，但 stale *display* 仍残留，故这里同步清空）。
    if (old.txn.id != widget.txn.id) {
      setState(() => _tags = const []);
      _loadTags();
    }
  }

  Future<void> _loadTags() async {
    final txnId = widget.txn.id;
    try {
      final result = await getIt<TagRepository>().getTransactionTags(txnId);
      if (!mounted || widget.txn.id != txnId) return;
      result.fold(
        (_) {
          // 失败降级：仅当当前持有 tags 时才 setState 清空，避 _tags 已是 const []
          // （初始值 / didUpdateWidget 已清）时无谓 rebuild。
          if (_tags.isNotEmpty) setState(() => _tags = const []);
        },
        (tags) => setState(() => _tags = tags),
      );
    } catch (_) {
      if (!mounted || widget.txn.id != txnId) return;
      if (_tags.isNotEmpty) setState(() => _tags = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bp = widget._resolve(context);
    return bp == Breakpoint.mobile
        ? _MobileRow(txn: widget.txn, row: widget, tags: _tags)
        : _TableRow(txn: widget.txn, row: widget, tags: _tags);
  }
}

/// 推断 flavour：平衡 + 两条 entry → transfer；否则 compound。
/// （与 domain value_objects.inferFlavour 同语义；本组件保留本地副本以避免
/// 在 widget 层引入 domain 之外的依赖循环。）
TxnFlavour _inferFlavour(Transaction txn) {
  if (txn.entries.length == 2 && txn.isBalanced) return TxnFlavour.transfer;
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

/// 账户首字母方块 + 名（转账两端 / 非转账单账户共用）。
class _AccountChip extends StatelessWidget {
  const _AccountChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    final ab = label.characters.isNotEmpty ? label.characters.first : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          alignment: Alignment.center,
          child: Text(ab,
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              style: const TextStyle(color: AppColors.fg, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

/// 分类 chip：Expense 红 / Income 绿 / 其他中性。
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.account});
  final Account? account;

  @override
  Widget build(BuildContext context) {
    if (account == null) return const SizedBox.shrink();
    final label = account!.category.label;
    final isIncomeType = account!.accountType == AccountType.income;
    final isExpenseType = account!.accountType == AccountType.expense;
    final fg = isIncomeType
        ? const Color(0xFF236B56)
        : (isExpenseType ? const Color(0xFFA0443E) : AppColors.muted);
    final bg = isIncomeType
        ? const Color(0x1A2D8A6E)
        : (isExpenseType ? const Color(0x1AC4544D) : AppColors.surfaceAlt);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
                color: AppColors.muted, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    color: fg, fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}

/// 转账双账户 widget：from → to + 箭头。
class _TransferAccounts extends StatelessWidget {
  const _TransferAccounts({required this.fromLabel, required this.toLabel});
  final String fromLabel;
  final String toLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: _AccountChip(label: fromLabel)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(LucideIcons.arrowRight, size: 14, color: AppColors.muted),
        ),
        Flexible(child: _AccountChip(label: toLabel)),
      ],
    );
  }
}

/// 解析一笔交易的账户列内容。
///   - 转账：[_AccountCellContent.transfer]（from → to）
///   - 非转账：单 asset 账户 + 对侧分类账户（供分类 chip）
class _AccountCellContent {
  _AccountCellContent.transfer(this.fromLabel, this.toLabel)
      : primaryLabel = fromLabel,
        categoryAccount = null;
  _AccountCellContent.single(this.primaryLabel, this.categoryAccount)
      : fromLabel = '',
        toLabel = '';

  final String primaryLabel;
  final String fromLabel;
  final String toLabel;
  final Account? categoryAccount;
  bool get isTransfer => fromLabel.isNotEmpty;
}

_AccountCellContent _resolveAccountCell(TxnRow row) {
  final txn = row.txn;
  if (row._isTransfer) {
    final fromEntry = txn.entries.firstWhere(
      (e) => e.creditCents > 0,
      orElse: () => txn.entries.first,
    );
    final toEntry = txn.entries.firstWhere(
      (e) => e.debitCents > 0,
      orElse: () => txn.entries.last,
    );
    return _AccountCellContent.transfer(
      row._accountLabel(fromEntry.accountId),
      row._accountLabel(toEntry.accountId),
    );
  }
  // 非转账：asset 账户为主账户；对侧（income/expense）为分类。
  Account? assetAccount;
  Account? otherAccount;
  String? assetId;
  for (final e in txn.entries) {
    final a = row.accounts[e.accountId];
    if (a == null) continue;
    if (a.accountType == AccountType.asset && assetAccount == null) {
      assetAccount = a;
      assetId = e.accountId;
    } else {
      otherAccount ??= a;
    }
  }
  final primaryLabel = assetId != null
      ? row._accountLabel(assetId)
      : (txn.entries.isNotEmpty
          ? row._accountLabel(txn.entries.first.accountId)
          : '');
  return _AccountCellContent.single(primaryLabel, otherAccount);
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.txn, required this.row, this.tags = const []});
  final Transaction txn;
  final TxnRow row;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final flavour = row._flavour;
    final amount = txn.totalDebitCents;
    final cell = _resolveAccountCell(row);
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    txn.description.isEmpty ? '(无描述)' : txn.description,
                    style:
                        const TextStyle(color: AppColors.fg, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _TxnTagChips(tags: tags),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 120,
              child: cell.isTransfer
                  ? _TransferAccounts(
                      fromLabel: cell.fromLabel, toLabel: cell.toLabel)
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: _AccountChip(label: cell.primaryLabel)),
                        if (cell.categoryAccount != null) ...[
                          const SizedBox(width: 6),
                          _CategoryChip(account: cell.categoryAccount),
                        ],
                      ],
                    ),
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
  const _MobileRow({required this.txn, required this.row, this.tags = const []});
  final Transaction txn;
  final TxnRow row;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final flavour = row._flavour;
    final amount = txn.totalDebitCents;
    final cell = _resolveAccountCell(row);
    // 副行：转账 from → to；非转账单账户（+ 分类 label 若有）。
    final secondary = cell.isTransfer
        ? '${cell.fromLabel} → ${cell.toLabel}'
        : (cell.primaryLabel.isEmpty
            ? ''
            : (cell.categoryAccount != null
                ? '${cell.primaryLabel} · ${cell.categoryAccount!.category.label}'
                : cell.primaryLabel));
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
                  if (cell.isTransfer)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: _AccountChip(label: cell.fromLabel)),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(LucideIcons.arrowRight,
                              size: 14, color: AppColors.muted),
                        ),
                        Flexible(child: _AccountChip(label: cell.toLabel)),
                      ],
                    )
                  else
                    Text(
                      '${_formatDate(txn.transactionDate)}${secondary.isEmpty ? '' : ' · $secondary'}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12),
                    ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _TxnTagChips(tags: tags),
                  ],
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

/// 列表 card 内的 tag chip 行：紧凑小号 chip,背景取 tag.color 0.15 alpha +
/// 同色文字。空列表(失败/无 tag)由调用方不渲染本组件,这里不再 guard。
class _TxnTagChips extends StatelessWidget {
  const _TxnTagChips({required this.tags});
  final List<Tag> tags;

  Widget _chip(Tag t) {
    final c = tagColor(t.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(t.name, style: TextStyle(color: c, fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 2,
      children: [for (final t in tags) _chip(t)],
    );
  }
}

/// `#RRGGBB` → [Color] 解析见共享 [tagColor](../../../tag/domain/tag_color.dart)。
