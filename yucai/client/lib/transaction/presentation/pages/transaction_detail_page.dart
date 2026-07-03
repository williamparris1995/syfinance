import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/journal_entry.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 交易详情页（Task 3.2）。承接 TransactionBloc detail 状态 +
/// JournalEntry 复式分录组件（Task 0.6）+ 同分类近期交易列表。
///
/// 三尺寸（[ResponsiveLayout]）：
///   - Desktop ≥1200：三栏 —— 概要 / 复式分录 / 操作 + 同分类
///   - Tablet 600–1200：双栏 —— (概要+复式) / (操作+同分类)
///   - Mobile ≤600：卡片堆叠
///
/// 占位区（spec §11 UI 占位策略，🔒 待模块）：
///   - AA 分摊
///   - 同商户交易
///   - 预算联动（待 Budget 模块）
///
/// 遵循 [AccountDetailPage] 模式（AppBar 操作 / DataCard 卡片 / 灰显占位）。
class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({super.key, required this.id});

  final String id;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  List<Account> _accounts = const [];

  @override
  void initState() {
    super.initState();
    // Self-drive the detail load (mirrors account_detail_page's
    // GetAccountRequested dispatch in initState). Without this, a real route
    // entry — where no parent dispatches — renders a blank SizedBox.shrink.
    context.read<TransactionBloc>().add(LoadTransactionDetail(widget.id));
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    // router /transactions/:id 只 provide TransactionBloc,不 provide AccountRepository。
    // 直接 getIt 拿,避免 context.read<AccountRepository?>() 返回 null → accounts=[]
    // → 分录显示 #id(而非账户名)。
    try {
      final repo = GetIt.instance<AccountRepository>();
      final result = await repo.list();
      if (!mounted) return;
      result.fold((_) {}, (list) => setState(() => _accounts = list));
    } catch (_) {}
  }

  String _accountNameOf(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a.name;
    }
    return id.length > 6 ? '#${id.substring(0, 6)}' : '#$id';
  }

  AccountType? _accountTypeOf(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a.accountType;
    }
    return null;
  }

  /// Infers the amount colour from the account types touched by the entries
  /// (account-as-category: the Expense/Income account in the entry is the
  /// category leg and decides the cash-flow direction).
  ///
  ///   - any entry's account is `AccountType.expense` → 支出色 (negative/red)
  ///   - any entry's account is `AccountType.income`  → 收入色 (positive/green)
  ///   - only `asset` accounts (SimpleTransfer)        → 中性色 (fg)
  ///
  /// Replaces the prior `inferFlavour == compound ? 红 : 绿` heuristic, which
  /// mis-coloured SimpleIncome (借 asset / 贷 income) as red — an accounting
  /// semantic error. Unknown account types (e.g. accounts not yet loaded)
  /// fall back to neutral so we never show a wrong cash-flow colour.
  Color _amountColorOf(Transaction txn) {
    bool hasExpense = false;
    bool hasIncome = false;
    bool onlyAssetOrUnknown = true;
    for (final e in txn.entries) {
      final t = _accountTypeOf(e.accountId);
      if (t == AccountType.expense) {
        hasExpense = true;
        onlyAssetOrUnknown = false;
      } else if (t == AccountType.income) {
        hasIncome = true;
        onlyAssetOrUnknown = false;
      } else if (t != null && t != AccountType.asset) {
        onlyAssetOrUnknown = false;
      }
    }
    if (hasExpense) return AppColors.negative;
    if (hasIncome) return AppColors.positive;
    if (onlyAssetOrUnknown) return AppColors.fg;
    return AppColors.fg;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.fg,
        elevation: 0,
        title: const Text('交易详情'),
        actions: const [
          _AppBarActions(),
        ],
      ),
      body: BlocBuilder<TransactionBloc, TransactionState>(
        buildWhen: (p, c) =>
            c is TransactionDetailLoading ||
            c is TransactionDetailLoaded ||
            c is TransactionDetailError,
        builder: (context, state) {
          if (state is TransactionDetailLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TransactionDetailError) {
            return Center(child: Text(state.message));
          }
          if (state is TransactionDetailLoaded) {
            return _DetailContent(
              txn: state.transaction,
              recent: state.recent,
              accountNameOf: _accountNameOf,
              amountColorOf: _amountColorOf,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// AppBar 操作（编辑 / 复制 / 删除）。编辑/复制/删除当前为占位（form
/// 集成在后续切片），沿用 account_detail 的 🔒 占位惯例 —— 这里先按可
/// 触发的菜单项实现，真实导航待 form-page edit mode 接入。
class _AppBarActions extends StatelessWidget {
  const _AppBarActions();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionBloc, TransactionState>(
      buildWhen: (p, c) =>
          c is TransactionDetailLoaded || c is TransactionDetailLoading,
      builder: (context, state) {
        final loaded = state is TransactionDetailLoaded ? state : null;
        final txn = loaded?.transaction;
        return Row(
          children: [
            TextButton(
              onPressed: txn == null ? null : () => _edit(context),
              child: const Text('编辑'),
            ),
            TextButton(
              onPressed: txn == null ? null : () => _copy(context),
              child: const Text('复制'),
            ),
            TextButton(
              onPressed: txn == null ? null : () => _delete(context, txn),
              child: const Text('删除',
                  style: TextStyle(color: AppColors.negative)),
            ),
          ],
        );
      },
    );
  }

  void _edit(BuildContext context) {
    // 编辑入口待 transaction_form_page edit 模式接入（后续切片）。
    AppToast.show(context, '编辑待交易表单接入', type: ToastType.warning);
  }

  void _copy(BuildContext context) {
    AppToast.show(context, '复制待交易表单接入', type: ToastType.warning);
  }

  void _delete(BuildContext context, Transaction txn) {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('删除交易'),
        content: const Text('删除此交易？此操作不可恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.pop(dctx, true),
              child: const Text('删除')),
        ],
      ),
    ).then((ok) {
      if (ok == true && context.mounted) {
        // 删除 dispatch 待 delete 流接入（TransactionBloc 后续切片加
        // DeleteTransaction handler）。先 toast 占位。
        AppToast.show(context, '删除待后端接入', type: ToastType.warning);
      }
    });
  }
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.txn,
    required this.recent,
    required this.accountNameOf,
    required this.amountColorOf,
  });

  final Transaction txn;
  final List<Transaction> recent;
  final String Function(String accountId) accountNameOf;
  final Color Function(Transaction txn) amountColorOf;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _stack(context),
      tablet: _twoColumn(context),
      desktop: _threeColumn(context),
    );
  }

  // ───────────────────────── 区块组件 ─────────────────────────

  Widget _summary() {
    final flavour = inferFlavour(txn);
    final amountColor = amountColorOf(txn);
    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  txn.description.isEmpty ? '(无描述)' : txn.description,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(flavour.label,
                    style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _formatCents(txn.totalDebitCents, '¥'),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: amountColor,
              fontFeatures: AppTypography.tabularFigures,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _kvRow('日期', _formatDate(txn.transactionDate)),
          if (txn.entries.isNotEmpty)
            _kvRow('账户', accountNameOf(txn.entries.first.accountId)),
        ],
      ),
    );
  }

  Widget _journal() => JournalEntry(
        entries: txn.entries,
        accountNameOf: accountNameOf,
      );

  Widget _quickActions(BuildContext context) => DataCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('快捷操作',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            _actionBtn(context, '编辑', LucideIcons.pencil),
            _actionBtn(context, '复制', LucideIcons.copy),
            _actionBtn(context, '删除', LucideIcons.trash2),
          ],
        ),
      );

  Widget _recentPanel(BuildContext context) => DataCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('同分类近期',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.sm),
            if (recent.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('暂无同类交易',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ),
              )
            else
              // 紧凑行（TxnRow 的固定列宽在窄列会溢出；这里描述+金额双行）。
              for (final t in recent) _RecentRow(txn: t, nameOf: accountNameOf),
          ],
        ),
      );

  /// 三占位区：AA 分摊 / 同商户 / 预算联动（灰显 + 🔒，沿用 account_detail
  /// 占位模式）。功能不实装。
  Widget _placeholders() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _placeholderCard('AA 分摊', '待实现'),
          const SizedBox(height: AppSpacing.md),
          _placeholderCard('同商户交易', '待实现'),
          const SizedBox(height: AppSpacing.md),
          _placeholderCard('预算联动', '待 Budget 模块'),
        ],
      );

  Widget _placeholderCard(String title, String hint) => DataCard(
        child: Opacity(
          opacity: 0.55,
          child: Row(
            children: [
              const Text('🔒', style: TextStyle(fontSize: 16)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(hint,
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  // ───────────────────────── 三尺寸布局 ─────────────────────────

  /// Desktop：三栏。左：概要 + 复式；中：快捷操作 + 占位；右：同分类近期。
  Widget _threeColumn(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summary(),
                const SizedBox(height: AppSpacing.lg),
                _journal(),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _quickActions(context),
                const SizedBox(height: AppSpacing.lg),
                _placeholders(),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: _recentPanel(context),
          ),
        ],
      ),
    );
  }

  /// Tablet：双栏。左：概要 + 复式；右：快捷操作 + 同分类 + 占位。
  Widget _twoColumn(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _summary(),
                const SizedBox(height: AppSpacing.lg),
                _journal(),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _quickActions(context),
                const SizedBox(height: AppSpacing.lg),
                _recentPanel(context),
                const SizedBox(height: AppSpacing.lg),
                _placeholders(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Mobile：卡片堆叠。
  Widget _stack(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        _summary(),
        const SizedBox(height: AppSpacing.lg),
        _journal(),
        const SizedBox(height: AppSpacing.lg),
        _quickActions(context),
        const SizedBox(height: AppSpacing.lg),
        _recentPanel(context),
        const SizedBox(height: AppSpacing.lg),
        _placeholders(),
      ],
    );
  }

  // ───────────────────────── 工具 ─────────────────────────

  Widget _kvRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(label,
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12)),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: AppColors.fg, fontSize: 13)),
            ),
          ],
        ),
      );

  Widget _actionBtn(BuildContext context, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () => AppToast.show(context, '$label待交易表单接入',
              type: ToastType.warning),
          icon: Icon(icon, size: 16),
          label: Text(label),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.fg,
            backgroundColor: AppColors.bg,
            padding:
                const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.smBorder,
              side: BorderSide(color: AppColors.border),
            ),
          ),
        ),
      ),
    );
  }
}

String _formatCents(int cents, String symbol) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '$symbol $yuan.$frac';
}

String _formatDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 同分类近期交易的紧凑行。TxnRow 用固定列宽在详情页窄列会溢出，这里改为
/// 两行（描述 / 日期·账户 + 右侧金额），任意列宽下都不溢出。
class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.txn, required this.nameOf});

  final Transaction txn;
  final String Function(String accountId) nameOf;

  @override
  Widget build(BuildContext context) {
    final primaryAccount = txn.entries.isNotEmpty
        ? nameOf(txn.entries.first.accountId)
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.description.isEmpty ? '(无描述)' : txn.description,
                  style: const TextStyle(
                      color: AppColors.fg, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(txn.transactionDate)} · $primaryAccount',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            _formatCents(txn.totalDebitCents, '¥'),
            style: const TextStyle(
                color: AppColors.fg,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                fontFeatures: AppTypography.tabularFigures),
          ),
        ],
      ),
    );
  }
}
