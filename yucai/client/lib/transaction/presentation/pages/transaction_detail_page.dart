import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/tag/domain/tag_color.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/journal_entry.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 交易详情页（Task 3.2 + OD detail 对齐）。
///
/// OD `detail-transaction.html` 三栏 + 同分类近期：
///   - **page-head**:返回链接 + h1(交易名) + 编辑 btn-primary(gold) + 更多 menu。
///   - **col1 交易概要**:大金额(¥ + 42px mono + chip) + TX-id + meta-list
///     (交易日期/支付方式/备注/对账状态)。OD meta-list **无「描述」行**(描述
///     即 h1 标题,不重复);「标签」行由 initState 并发 GetTransactionTags 渲染。
///   - **col2 复式分录**:[JournalEntry] 借/贷 + 借贷平衡 + 会计等式 explainer。
///   - **col3 快捷操作**:qa-items(编辑/复制/查看账单/删除[danger])。
///   - **同分类近期交易**:rel-list(per-category lucide icon + 名称/日期/金额)。
///
/// CRUD:删除走 [DeleteTransactionRequested]（bloc → repo.delete + 余额冲销）；
/// 复制 → `/transactions/new`；编辑 → `/transactions/:id/edit`（form edit mode
/// 待 form_bloc 接入 Update RPC，当前 route 占位）。查看账单 → 资产账户详情。
class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({super.key, required this.id});

  final String id;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  List<Account> _accounts = const [];
  List<Tag> _tags = const [];

  @override
  void initState() {
    super.initState();
    // Self-drive the detail load (mirrors account_detail_page). Without this a
    // real route entry renders blank (no parent dispatches).
    context.read<TransactionBloc>().add(LoadTransactionDetail(widget.id));
    _loadAccounts();
    _loadTags();
  }

  /// 标签行:GetTransactionTags(widget.id) → _tags。失败/空 → `_tags = []`(标签
  /// 行显示 '—')。不再 DEFER 等 proto TransactionDTO.tags(client 并发查询即可)。
  Future<void> _loadTags() async {
    final txnId = widget.id;
    TagRepository? repo;
    try {
      repo = GetIt.instance<TagRepository>();
    } catch (_) {
      repo = null;
    }
    if (repo == null) return;
    try {
      final result = await repo.getTransactionTags(txnId);
      if (!mounted) return;
      result.fold((_) {}, (tags) => setState(() => _tags = tags));
    } catch (_) {}
  }

  Future<void> _loadAccounts() async {
    // 优先从树里读 RepositoryProvider<AccountRepository>（测试 harness 走这条）；
    // 路由层未 provide 时回退 getIt（生产路径）。
    AccountRepository? repo;
    try {
      repo = RepositoryProvider.of<AccountRepository>(context);
    } catch (_) {
      repo = null;
    }
    try {
      repo ??= GetIt.instance<AccountRepository>();
    } catch (_) {}
    if (repo == null) return;
    final result = await repo.list();
    if (!mounted) return;
    result.fold((_) {}, (list) => setState(() => _accounts = list));
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

  Account? _accountOf(String id) {
    for (final a in _accounts) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocConsumer<TransactionBloc, TransactionState>(
        listenWhen: (p, c) =>
            c is TransactionDeleted || c is TransactionDetailError,
        listener: (context, state) {
          if (state is TransactionDeleted) {
            AppToast.show(context, '已删除', type: ToastType.success);
            // pop with true so the originating list refreshes (OD detail 删除后回列表)。
            // GoRouter.maybeOf 让本页在无 GoRouter 的测试 harness 里也不抛。
            final router = GoRouter.maybeOf(context);
            if (router != null) {
              router.pop(true);
            } else {
              Navigator.of(context).maybePop(true);
            }
          } else if (state is TransactionDetailError) {
            AppToast.show(context, state.message, type: ToastType.error);
          }
        },
        buildWhen: (p, c) =>
            c is TransactionDetailLoading ||
            c is TransactionDetailLoaded ||
            c is TransactionDetailError ||
            c is TransactionDeleting,
        builder: (context, state) {
          if (state is TransactionDetailLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TransactionDetailError) {
            return _PageShell(child: Center(child: Text(state.message)));
          }
          final txn = state is TransactionDetailLoaded
              ? state.transaction
              : (state is TransactionDeleting ? state.previous : null);
          if (txn != null) {
            return _PageShell(
              child: _DetailContent(
                txn: txn,
                recent: state is TransactionDetailLoaded ? state.recent : const [],
                isDeleting: state is TransactionDeleting,
                accountNameOf: _accountNameOf,
                accountTypeOf: _accountTypeOf,
                accountOf: _accountOf,
                tags: _tags,
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}

/// 页面外壳：内容居中 + 最大宽 1320（对齐 OD .content max-width）。不含 AppBar
///（shell 已提供 topbar；返回走 page-head 的返回链接）。
class _PageShell extends StatelessWidget {
  const _PageShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bg,
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1320),
        child: child,
      ),
    );
  }
}

/// 金额色推断 —— account-as-category：分录里的 Expense/Income 账户决定现金方向。
///   - 任一分录账户 = Expense → 支出色(negative/红)
///   - 任一分录账户 = Income  → 收入色(positive/绿)
///   - 仅 Asset(SimpleTransfer) → 中性(fg)
Color amountColorOf(Transaction txn, AccountType? Function(String) accountTypeOf) {
  bool hasExpense = false;
  bool hasIncome = false;
  bool onlyAssetOrUnknown = true;
  for (final e in txn.entries) {
    final t = accountTypeOf(e.accountId);
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

/// 主交易的「支付方式」资产账户 —— expense/income 取贷方/借方资产腿，
/// SimpleTransfer 取贷方（转出账户）。
String _primaryAssetAccountId(Transaction txn) {
  for (final e in txn.entries) {
    if (e.creditCents > 0) return e.accountId;
  }
  return txn.entries.isNotEmpty ? txn.entries.first.accountId : '';
}

/// 首条非空 entry note（rel-row sub 的可选描述后缀）。
String _firstNoteOf(Transaction txn) {
  for (final e in txn.entries) {
    if (e.note.isNotEmpty) return e.note;
  }
  return '';
}

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.txn,
    required this.recent,
    required this.isDeleting,
    required this.accountNameOf,
    required this.accountTypeOf,
    required this.accountOf,
    this.tags = const [],
  });

  final Transaction txn;
  final List<Transaction> recent;
  final bool isDeleting;
  final String Function(String accountId) accountNameOf;
  final AccountType? Function(String accountId) accountTypeOf;
  final Account? Function(String accountId) accountOf;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _stack(context),
      tablet: _twoColumn(context),
      desktop: _threeColumn(context),
    );
  }

  // ───────────────────────── page-head ─────────────────────────

  Widget _pageHead(BuildContext context) {
    final title = txn.description.isEmpty ? '(无描述)' : txn.description;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () => _back(context),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.chevronLeft, size: 16, color: AppColors.muted),
                  SizedBox(width: 2),
                  Text('返回', style: TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
                color: AppColors.fg,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 编辑 btn-primary（gold 实心）
          _GoldButton(
            label: '编辑',
            icon: LucideIcons.pencil,
            onTap: isDeleting ? null : () => _edit(context),
          ),
          const SizedBox(width: 8),
          // 更多 menu（复制/标记已对账/导出凭证/删除）
          _MoreMenu(isDeleting: isDeleting, txn: txn),
        ],
      ),
    );
  }

  // ───────────────────────── col1 交易概要 ─────────────────────────

  Widget _summary() {
    final amountColor = amountColorOf(txn, accountTypeOf);
    final flavour = inferFlavour(txn);
    final isExpense = amountColor == AppColors.negative;
    final chipColor = isExpense ? AppColors.negative : AppColors.positive;
    final chipLabel = isExpense
        ? '支出'
        : (amountColor == AppColors.positive ? '收入' : flavour.label);
    final txnIdShort = txn.id.isEmpty
        ? ''
        : (txn.id.length > 12 ? txn.id.substring(0, 12) : txn.id);

    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(LucideIcons.receipt, size: 16, color: AppColors.accent),
              SizedBox(width: AppSpacing.sm),
              Text('交易概要',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback)),
            ],
          ),
          if (txnIdShort.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('TX-$txnIdShort',
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 11,
                    letterSpacing: 0.5,
                    fontFeatures: AppTypography.tabularFigures)),
          ],
          const SizedBox(height: AppSpacing.md),
          // 大金额 + chip。用 Wrap 而非 Row —— 窄列（tablet/压缩桌面）下 chip
          // 可自动换到下一行，避免 42px 数字 + chip 溢出。
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: 4,
            runSpacing: 6,
            children: [
              Text('¥',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.muted,
                    fontFamily: AppTypography.displayFamily,
                    fontFamilyFallback: AppTypography.displayFallback,
                  )),
              const SizedBox(width: 4),
              Text(
                _formatAmountBody(txn.totalDebitCents),
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: amountColor,
                  fontFeatures: AppTypography.tabularFigures,
                  fontFamily: AppTypography.displayFamily,
                  fontFamilyFallback: AppTypography.displayFallback,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: chipColor.withValues(alpha: 0.10),
                  border: Border.all(color: chipColor.withValues(alpha: 0.30)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: chipColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(chipLabel,
                        style: TextStyle(
                            color: chipColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // meta-list
          _MetaList(
            txn: txn,
            accountNameOf: accountNameOf,
            paymentAccountName: accountNameOf(_primaryAssetAccountId(txn)),
            tags: tags,
          ),
        ],
      ),
    );
  }

  // ───────────────────────── col2 复式分录 ─────────────────────────

  Widget _journal() => JournalEntry(
        entries: txn.entries,
        accountNameOf: accountNameOf,
        accountTypeOf: accountTypeOf,
        showAccountingFormula: true,
      );

  // ───────────────────────── col3 快捷操作 ─────────────────────────

  Widget _quickActions(BuildContext context) => DataCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(LucideIcons.zap, size: 16, color: AppColors.accent),
                SizedBox(width: AppSpacing.sm),
                Text('快捷操作',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _QaItem(
              icon: LucideIcons.pencil,
              title: '编辑交易',
              sub: '修改金额、分类或备注',
              onTap: isDeleting ? null : () => _edit(context),
            ),
            const SizedBox(height: 8),
            _QaItem(
              icon: LucideIcons.copy,
              title: '复制交易',
              sub: '基于此笔快速新建',
              onTap: isDeleting ? null : () => _copy(context),
            ),
            const SizedBox(height: 8),
            _QaItem(
              icon: LucideIcons.fileText,
              title: '查看账单',
              sub: accountNameOf(_primaryAssetAccountId(txn)),
              onTap: () => _viewAccount(context),
            ),
            const SizedBox(height: 8),
            _QaItem.danger(
              icon: LucideIcons.trash2,
              title: '删除交易',
              sub: '将生成冲销分录',
              onTap: isDeleting ? null : () => _delete(context),
            ),
          ],
        ),
      );

  // ───────────────────────── 同分类近期 ─────────────────────────

  Widget _recentPanel(BuildContext context) {
    final count = recent.length;
    final sumCents = recent.fold<int>(0, (s, t) => s + t.totalDebitCents);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('同分类近期交易',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback,
                        color: AppColors.fg,
                      )),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(children: [
                      const TextSpan(
                          text: '近期共 ',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      TextSpan(
                          text: '$count',
                          style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12.5,
                              fontFeatures: AppTypography.tabularFigures)),
                      const TextSpan(
                          text: ' 笔 · 合计 ',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12.5)),
                      TextSpan(
                          text: _formatCents(sumCents, '¥'),
                          style: const TextStyle(
                              color: AppColors.fg,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              fontFeatures: AppTypography.tabularFigures)),
                    ]),
                  ),
                ],
              ),
            ),
            InkWell(
              onTap: () => _viewAll(context),
              child: const Text('查看全部 ›',
                  style: TextStyle(color: AppColors.accent, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (recent.isEmpty)
          DataCard(
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('暂无同类交易',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ),
            ),
          )
        else
          DataCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (int i = 0; i < recent.length; i++) ...[
                  _RecentRow(
                    txn: recent[i],
                    nameOf: accountNameOf,
                    accountOf: accountOf,
                    accountTypeOf: accountTypeOf,
                  ),
                  if (i != recent.length - 1)
                    const Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
      ],
    );
  }

  // ───────────────────────── 三尺寸布局 ─────────────────────────

  /// Desktop:page-head + 3 栏(概要/复式/快捷) + 同分类全宽。
  Widget _threeColumn(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageHead(context),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 115, child: _summary()),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 100, child: _journal()),
              const SizedBox(width: AppSpacing.md),
              Expanded(flex: 82, child: _quickActions(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _recentPanel(context),
        ],
      ),
    );
  }

  /// Tablet:2 栏。左:概要 + 复式；右:快捷 + 同分类。
  Widget _twoColumn(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageHead(context),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _summary(),
                    const SizedBox(height: AppSpacing.md),
                    _journal(),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _quickActions(context),
                    const SizedBox(height: AppSpacing.md),
                    _recentPanel(context),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Mobile:卡片堆叠。
  Widget _stack(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      children: [
        _pageHead(context),
        _summary(),
        const SizedBox(height: AppSpacing.md),
        _journal(),
        const SizedBox(height: AppSpacing.md),
        _quickActions(context),
        const SizedBox(height: AppSpacing.md),
        _recentPanel(context),
      ],
    );
  }

  // ───────────────────────── CRUD ─────────────────────────

  void _back(BuildContext context) {
    if (context.canPop()) context.pop();
  }

  void _edit(BuildContext context) {
    // 编辑 → /transactions/:id/edit。TransactionFormPage edit mode
    // (Update RPC + 任意分录编辑) 待 form_bloc 接入；当前 route 占位提示。
    context.push('/transactions/${txn.id}/edit');
  }

  void _copy(BuildContext context) {
    // 复制 → 新建表单（clone-to-new）。全字段预填待 form 支持 extra 后补；
    // 当前导航到通用记一笔入口。
    context.push('/transactions/new');
  }

  void _viewAccount(BuildContext context) {
    final accId = _primaryAssetAccountId(txn);
    if (accId.isEmpty) {
      AppToast.show(context, '未关联资产账户', type: ToastType.warning);
      return;
    }
    context.push('/accounts/$accId');
  }

  void _viewAll(BuildContext context) {
    context.go('/transactions');
  }

  void _delete(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('删除交易'),
        content: Text('删除「${txn.description.isEmpty ? '此交易' : txn.description}」'
            '将生成一条冲销分录，撤销该笔借贷记录。此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('删除',
                style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true && context.mounted) {
        context.read<TransactionBloc>().add(DeleteTransactionRequested(txn.id));
      }
    });
  }
}

// ───────────────────────── 共用子组件 ─────────────────────────

/// 大金额的整数/小数拆分（42px num 行只显示数字，¥ 单独）。返回 "380.00" 形。
String _formatAmountBody(int cents) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '$yuan.$frac';
}

String _formatCents(int cents, String symbol) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  return '$symbol$yuan.$frac';
}

String _formatDateLine(DateTime d, DateTime? time) {
  final date =
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  if (time == null) return date;
  final hh = time.hour.toString().padLeft(2, '0');
  final mm = time.minute.toString().padLeft(2, '0');
  return '$date  $hh:$mm';
}

String _formatDateShort(DateTime d) =>
    '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

/// OD meta-list:6 行 KV（交易日期/商户/支付方式/备注/标签/对账状态）。
/// 御财模型对齐情况：
///   - **交易日期/支付方式/备注/对账状态**:已对齐（备注取 entry.note）。
///   - **描述/商户**:OD meta-list **无「描述」行**——交易名/描述即 page-head
///     h1 标题，不在 meta-list 重复（detail 4fix gap 1）。御财无独立 merchant
///     字段，故也不单列「商户」行。
///   - **标签（chip tags）**:page initState 并发 GetTransactionTags → chip 行
///     （不依赖 proto TransactionDTO.tags,失败/空显示 '—'）。
///   - **对账状态**:模块未接入，固定「待对账」诚实占位。
class _MetaList extends StatelessWidget {
  const _MetaList({
    required this.txn,
    required this.accountNameOf,
    required this.paymentAccountName,
    this.tags = const [],
  });

  final Transaction txn;
  final String Function(String accountId) accountNameOf;
  final String paymentAccountName;
  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    final note = txn.entries.firstWhere(
      (e) => e.note.isNotEmpty,
      orElse: () => txn.entries.isEmpty
          ? const TransactionEntry(accountId: '', debitCents: 0, creditCents: 0)
          : txn.entries.first,
    ).note;
    // 标签行:tags 非空 → chip 行;空 → '—'(对齐 OD meta-list label/value 样式)。
    final Widget tagRow = tags.isEmpty
        ? const _MetaRow('标签', '—', valueColor: AppColors.muted)
        : _MetaRowWidget(
            label: '标签',
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _DetailTagChips(tags: tags),
            ),
          );
    final rows = <Widget>[
      _MetaRow('交易日期', _formatDateLine(txn.transactionDate, txn.transactionTime),
          mono: true),
      _MetaRow('支付方式', paymentAccountName.isEmpty ? '—' : paymentAccountName),
      _MetaRow('备注', note.isEmpty ? '—' : note),
      tagRow,
      _MetaRow('对账状态', '待对账', valueColor: AppColors.muted),
    ];
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i != rows.length - 1)
            const Divider(height: 1, color: AppColors.border),
        ],
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow(this.k, this.v, {this.mono = false, this.valueColor});
  final String k;
  final String v;
  final bool mono;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(k,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                color: valueColor ?? AppColors.fg,
                fontSize: 14,
                fontFeatures: mono ? AppTypography.tabularFigures : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// [_MetaRow] 的 Widget-value 变体:label 同样 80px 灰,右侧放任意 child
/// (用于标签行的 chip wrap)。对齐 _MetaRow 布局/间距。
class _MetaRowWidget extends StatelessWidget {
  const _MetaRowWidget({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// 详情标签行 chip wrap:只读(非 toggle),背景取 tag.color 0.15 alpha + 同色
/// 文字。比列表(_TxnTagChips)略大,适配详情 meta-list 阅读字号。
class _DetailTagChips extends StatelessWidget {
  const _DetailTagChips({required this.tags});
  final List<Tag> tags;

  Widget _chip(Tag t) {
    final c = tagColor(t.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(t.name, style: TextStyle(color: c, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final t in tags) _chip(t)],
    );
  }
}

/// `#RRGGBB` → [Color] 解析见共享 [tagColor]（tag/domain/tag_color.dart）。

/// gold 实心按钮（page-head 编辑）。
class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.icon, this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: enabled ? AppColors.accent : AppColors.accent.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// 更多菜单（⋯ → 复制/标记已对账/导出凭证/删除）。用 PopupMenu。
/// 触发器对齐 OD `.btn.icon-only`:38×38 white bg + border + radius（detail
/// 4fix gap 3)——原先透明无框,与 OD btn 样式不一致。
class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.isDeleting, required this.txn});
  final bool isDeleting;
  final Transaction txn;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: '更多',
      shape: RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
      itemBuilder: (ctx) => [
        _item('copy', '复制交易', LucideIcons.copy, AppColors.fg),
        _item('reconcile', '标记已对账', LucideIcons.check, AppColors.fg),
        _item('export', '导出凭证', LucideIcons.download, AppColors.fg),
        const PopupMenuDivider(),
        _item('delete', '删除交易', LucideIcons.trash2, AppColors.negative),
      ],
      onSelected: (v) {
        switch (v) {
          case 'copy':
            context.push('/transactions/new');
            break;
          case 'reconcile':
            AppToast.show(context, '对账功能待接入', type: ToastType.warning);
            break;
          case 'export':
            AppToast.show(context, '导出凭证待接入', type: ToastType.warning);
            break;
          case 'delete':
            _confirmDelete(context);
            break;
        }
      },
      // 用 child(非 icon)承接自定义触发器:OD .btn.icon-only 样式。
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.smBorder,
        ),
        alignment: Alignment.center,
        child: const Icon(LucideIcons.moreHorizontal,
            size: 18, color: AppColors.fg),
      ),
    );
  }

  PopupMenuEntry<String> _item(
      String value, String label, IconData icon, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 13.5)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('删除交易'),
        content: Text('删除「${txn.description.isEmpty ? '此交易' : txn.description}」'
            '将生成一条冲销分录，撤销该笔借贷记录。此操作不可撤销。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('删除',
                style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true && context.mounted && !isDeleting) {
        context
            .read<TransactionBloc>()
            .add(DeleteTransactionRequested(txn.id));
      }
    });
  }
}

/// OD qa-item:icon-tile(rounded square, accentSoft bg, gold icon) + title + sub
/// + chevron。danger 变体用红。
class _QaItem extends StatelessWidget {
  const _QaItem({
    required this.icon,
    required this.title,
    required this.sub,
    this.onTap,
  }) : danger = false;

  const _QaItem.danger({
    required this.icon,
    required this.title,
    required this.sub,
    this.onTap,
  }) : danger = true;

  final IconData icon;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tileColor = danger
        ? AppColors.negative.withValues(alpha: 0.10)
        : AppColors.accentSoft;
    final iconColor = danger ? AppColors.negative : AppColors.accent;
    final titleColor = danger ? AppColors.negative : AppColors.fg;
    final borderColor = danger ? AppColors.negative : AppColors.border;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: tileColor,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: titleColor)),
                  const SizedBox(height: 1),
                  Text(sub,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

/// OD rel-row:rel-ic(per-category lucide) + 名称/sub + 日期 + 金额(着色)。
class _RecentRow extends StatelessWidget {
  const _RecentRow({
    required this.txn,
    required this.nameOf,
    required this.accountOf,
    required this.accountTypeOf,
  });

  final Transaction txn;
  final String Function(String accountId) nameOf;
  final Account? Function(String accountId) accountOf;
  final AccountType? Function(String accountId) accountTypeOf;

  @override
  Widget build(BuildContext context) {
    // icon 按 type 区分(用户明确要求,非 per-category):任一分录账户 = Expense →
    // 支出(arrowDownLeft 红);Income → 收入(arrowUpLeft 绿);仅 Asset →
    // 转账(arrowLeftRight 灰)。icon 背景色 + 金额色 同步按 type。
    bool hasExpense = false;
    bool hasIncome = false;
    for (final e in txn.entries) {
      final t = accountTypeOf(e.accountId);
      if (t == AccountType.expense) {
        hasExpense = true;
      } else if (t == AccountType.income) {
        hasIncome = true;
      }
    }
    final IconData typeIcon;
    final Color typeColor;
    if (hasExpense) {
      typeIcon = LucideIcons.arrowDownLeft;
      typeColor = AppColors.negative;
    } else if (hasIncome) {
      typeIcon = LucideIcons.arrowUpLeft;
      typeColor = AppColors.positive;
    } else {
      typeIcon = LucideIcons.arrowLeftRight;
      typeColor = AppColors.muted;
    }
    // 账户显示(用户要求,OD rel-row 无账户):sub 显示支付账户名(主资产腿/贷方),
    // 若有 entry note 追加在后,如「招商银行 · 部门聚餐」。
    final paymentAccountId = _primaryAssetAccountId(txn);
    final paymentName =
        accountOf(paymentAccountId)?.name ?? nameOf(paymentAccountId);
    final note = _firstNoteOf(txn);
    final sub = note.isEmpty ? paymentName : '$paymentName · $note';

    return InkWell(
      onTap: () => context.push('/transactions/${txn.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(typeIcon, size: 16, color: typeColor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description.isEmpty ? '(无描述)' : txn.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 1),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 44,
              child: Text(_formatDateShort(txn.transactionDate),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                      fontFeatures: AppTypography.tabularFigures)),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 90,
              child: Text(
                _formatCents(txn.totalDebitCents, '¥'),
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: typeColor,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
