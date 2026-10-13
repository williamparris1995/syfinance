import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/app/route_observer.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:design_kit/design_kit.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';
import 'package:yucai_client/core/widgets/detail_title_sync.dart';
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
///   - **page-head**:h1(交易名)。F59 FR-4:编辑金色主钮 + 更多菜单迁入右下
///     悬浮簇(编辑 primary + 复制/删除 muted;占位 toast 菜单项随菜单退场);
///     FR-7:返回链接退役,page 级回退统一走全局顶栏面包屑。
///   - **col1 交易概要**:大金额(¥ + 42px mono + chip) + TX-id + meta-list
///     (交易日期/支付方式/备注/对账状态)。OD meta-list **无「描述」行**(描述
///     即 h1 标题,不重复);「标签」行由 initState 并发 GetTransactionTags 渲染。
///   - **col2 复式分录**:[JournalEntry] 借/贷 + 借贷平衡 + 会计等式 explainer。
///   - **col3 快捷操作**:qa-items(编辑/复制/查看账单/删除[danger])—— 内容卡
///     (非导航 chrome),保留。
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

class _TransactionDetailPageState extends State<TransactionDetailPage>
    with RouteAware {
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 本页位于 transactions branch 的嵌套 Navigator(router /transactions/:id),
    // 编辑页(/transactions/:id/edit)push/pop 都在该 Navigator 上 —— pop 回来
    // 时 didPopNext 触发回拉(编辑保存后详情页自身金额/描述已变,不重拉则
    // 显示旧值)。照 transactions_page F14 #3 同款观察者。
    transactionsRouteObserver.subscribe(
        this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    // F59 FR-2:离开详情页清理注入标题(双保险之一;另一道 = AppShell
    // location-diff scrubber)。guarded getIt:测试 harness 未注册 port 时静默跳过。
    scheduleDetailTitleClear();
    transactionsRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    if (!mounted) return;
    // 重跑 initState 同组加载;编辑保存后 version 已 +1,再编辑基于新值。
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
    // F59 FR-4:page-head 编辑金钮 + 更多菜单退役 → 右下悬浮簇(见 [_dock]);
    // 恒渲染:loading/error/deleting 态簇仍在,全动作禁用(操作锚点恒定)。
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: Stack(
        children: [
          BlocConsumer<TransactionBloc, TransactionState>(
            listenWhen: (p, c) =>
                c is TransactionDeleted || c is TransactionDetailError,
            listener: (context, state) {
              if (state is TransactionDeleted) {
                AppToast.show(context, '已删除', type: ToastType.success);
                // 跨页刷新:删除已持久化,仪表盘/账户列表等驻留页重拉页面级缓存
                // (与表单保存成功同一通知器,照设置页导入存档 bump 先例)。
                GetIt.instance<DataRefreshNotifier>().bump();
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
                return Stack(
                  children: [
                    _PageShell(
                      child: _DetailContent(
                        txn: txn,
                        recent:
                            state is TransactionDetailLoaded ? state.recent : const [],
                        isDeleting: state is TransactionDeleting,
                        accountNameOf: _accountNameOf,
                        accountTypeOf: _accountTypeOf,
                        accountOf: _accountOf,
                        tags: _tags,
                      ),
                    ),
                    // 交易名经帧回调幂等注入顶栏当前级;放滚动容器外
                    //(深滚动时 ListView 子项可能离树,不可依赖)。
                    DetailTitleSync(
                        title: txn.description.isEmpty ? '(无描述)' : txn.description),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // F59 FR-1:右下角常驻竖排悬浮簇(AppSpacing.lg=28 边距,不随页面滚动移动)。
          Positioned(
              right: AppSpacing.lg, bottom: AppSpacing.lg, child: _dock()),
        ],
      ),
    );
  }

  /// F59 FR-4 悬浮簇操作映射(transaction 语义,原 page-head 操作集平铺):
  ///  - primary 编辑:push `/transactions/:id/edit`(原金主钮原样);
  ///  - muted 复制交易:push `/transactions/new` extra 携带源交易
  ///    (clone-to-new,与 col3 复制同语义);
  ///  - muted 删除交易:确认 dialog → [DeleteTransactionRequested]
  ///    (危险项渲染置顶,离主钮最远)。
  /// 未加载(loading/error)或删除进行中(isDeleting)全禁用。
  Widget _dock() {
    return BlocBuilder<TransactionBloc, TransactionState>(
      buildWhen: (p, c) =>
          c is TransactionDetailLoading ||
          c is TransactionDetailLoaded ||
          c is TransactionDetailError ||
          c is TransactionDeleting,
      builder: (context, state) {
        final txn = state is TransactionDetailLoaded
            ? state.transaction
            : (state is TransactionDeleting ? state.previous : null);
        final enabled = txn != null && state is! TransactionDeleting;
        return FloatingActionDock(
          primary: DockAction(
            icon: LucideIcons.pencil,
            tooltip: '编辑',
            onTap: enabled ? () => context.push('/transactions/${txn.id}/edit') : null,
          ),
          muted: [
            DockAction(
              icon: LucideIcons.copy,
              tooltip: '复制交易',
              onTap: enabled ? () => context.push('/transactions/new', extra: txn) : null,
            ),
            DockAction(
              icon: LucideIcons.trash2,
              tooltip: '删除交易',
              onTap: enabled ? () => _confirmDelete(txn) : null,
            ),
          ],
        );
      },
    );
  }

  /// dock 删除确认(文案与 col3 qa-item / 原菜单删除一致):确认 →
  /// dispatch DeleteTransactionRequested(删除后回列表走既有 listener)。
  void _confirmDelete(Transaction txn) {
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
            child: Text('删除',
                style: TextStyle(color: context.yucai.negative)),
          ),
        ],
      ),
    ).then((ok) {
      if (ok == true && mounted) {
        final state = context.read<TransactionBloc>().state;
        if (state is TransactionDeleting) return;
        context
            .read<TransactionBloc>()
            .add(DeleteTransactionRequested(txn.id));
      }
    });
  }
}

/// 页面外壳：内容居中 + 最大宽 1320（对齐 OD .content max-width）。不含 AppBar
///（shell 已提供 topbar;F59 FR-7:返回链接退役,page 级回退走顶栏面包屑）。
class _PageShell extends StatelessWidget {
  const _PageShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.yucai.bg,
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
/// F4-P2:顶层函数无 context → 补形参穿线;三档语义色走 context.yucai。
Color amountColorOf(BuildContext context, Transaction txn,
    AccountType? Function(String) accountTypeOf) {
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
  if (hasExpense) return context.yucai.negative;
  if (hasIncome) return context.yucai.positive;
  if (onlyAssetOrUnknown) return context.yucai.fg;
  return context.yucai.fg;
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
      padding: EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          fontFamily: AppTypography.displayFamily,
          fontFamilyFallback: AppTypography.displayFallback,
          color: context.yucai.fg,
        ),
      ),
    );
  }

  // ───────────────────────── col1 交易概要 ─────────────────────────

  Widget _summary(BuildContext context) {
    final amountColor = amountColorOf(context, txn, accountTypeOf);
    final flavour = inferFlavour(txn);
    final isExpense = amountColor == context.yucai.negative;
    final chipColor =
        isExpense ? context.yucai.negative : context.yucai.positive;
    final chipLabel = isExpense
        ? '支出'
        : (amountColor == context.yucai.positive ? '收入' : flavour.label);
    final txnIdShort = txn.id.isEmpty
        ? ''
        : (txn.id.length > 12 ? txn.id.substring(0, 12) : txn.id);

    return DataCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.receipt,
                  size: 16, color: context.yucai.accent),
              const SizedBox(width: AppSpacing.sm),
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
                style: TextStyle(
                    color: context.yucai.muted,
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
                    color: context.yucai.muted,
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
              children: [
                Icon(LucideIcons.zap, size: 16, color: context.yucai.accent),
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
                        color: context.yucai.fg,
                      )),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                          text: '近期共 ',
                          style:
                              TextStyle(color: context.yucai.muted, fontSize: 12.5)),
                      TextSpan(
                          text: '$count',
                          style: TextStyle(
                              color: context.yucai.muted,
                              fontSize: 12.5,
                              fontFeatures: AppTypography.tabularFigures)),
                      TextSpan(
                          text: ' 笔 · 合计 ',
                          style:
                              TextStyle(color: context.yucai.muted, fontSize: 12.5)),
                      TextSpan(
                          text: _formatCents(sumCents, '¥'),
                          style: TextStyle(
                              color: context.yucai.fg,
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
              child: Text('查看全部 ›',
                  style: TextStyle(color: context.yucai.accent, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (recent.isEmpty)
          DataCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text('暂无同类交易',
                    style: TextStyle(color: context.yucai.muted, fontSize: 12)),
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
                    Divider(height: 1, color: context.yucai.border, indent: 16, endIndent: 16),
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
      // F59 FR-1:底部留白按钮数算 —— 满配簇高 171(编辑 52 + 间距 10 +
      // 分隔线 1 + 间距 10 + 复制 44 + 间距 10 + 删除 44)+ 底边距 28 +
      // 净空 54 = 253;顶部 16 = AppBar 让位后的呼吸位(8-16)。
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 16, AppSpacing.lg, 253),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _pageHead(context),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 115, child: _summary(context)),
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
      // 底部留白同 desktop(满配簇高 171 + 28 + 净空 54;见 _threeColumn)。
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 16, AppSpacing.lg, 253),
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
                    _summary(context),
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
      // 底部留白同 desktop(满配簇高 171 + 28 + 净空 54;见 _threeColumn)。
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, 14, AppSpacing.md, 253),
      children: [
        _pageHead(context),
        _summary(context),
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

  // F59 FR-7:返回链接(原 _back)退役 —— page 级回退统一走全局顶栏面包屑。

  void _edit(BuildContext context) {
    // 编辑 → /transactions/:id/edit。TransactionFormPage edit mode
    // (Update RPC + 任意分录编辑) 待 form_bloc 接入；当前 route 占位提示。
    context.push('/transactions/${txn.id}/edit');
  }

  void _copy(BuildContext context) {
    // 复制 → 新建表单(clone-to-new):extra 携带源交易,表单全字段预填,
    // 提交走创建(isCopy 模式,不携带原 id/版本)。
    context.push('/transactions/new', extra: txn);
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
            child: Text('删除',
                style: TextStyle(color: context.yucai.negative)),
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
          ? TransactionEntry(accountId: '', debitCents: 0, creditCents: 0)
          : txn.entries.first,
    ).note;
    // 标签行:tags 非空 → chip 行;空 → '—'(对齐 OD meta-list label/value 样式)。
    final Widget tagRow = tags.isEmpty
        ? _MetaRow('标签', '—', valueColor: context.yucai.muted)
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
      _MetaRow('对账状态', '待对账', valueColor: context.yucai.muted),
    ];
    return Column(
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i != rows.length - 1)
            Divider(height: 1, color: context.yucai.border),
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
                style: TextStyle(color: context.yucai.muted, fontSize: 13)),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              v,
              style: TextStyle(
                color: valueColor ?? context.yucai.fg,
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
                style: TextStyle(color: context.yucai.muted, fontSize: 13)),
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

  /// F4-P2:回退色注入主题 accent;方法补 context 穿线。
  Widget _chip(BuildContext context, Tag t) {
    final c = tagColor(t.color, fallback: context.yucai.accent);
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
      children: [for (final t in tags) _chip(context, t)],
    );
  }
}

// F59 FR-4:原 page-head 编辑金主钮(_GoldButton)与更多菜单(_MoreMenu)退役 ——
// 编辑/复制/删除迁入右下悬浮簇;「标记已对账/导出凭证」为占位 toast 项(无实
// 功能),随菜单退场,零功能丢失。

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
        ? context.yucai.negative.withValues(alpha: 0.10)
        : context.yucai.accentSoft;
    final iconColor = danger ? context.yucai.negative : context.yucai.accent;
    final titleColor = danger ? context.yucai.negative : context.yucai.fg;
    final borderColor = danger ? context.yucai.negative : context.yucai.border;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: context.yucai.surface,
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
                      style: TextStyle(
                          color: context.yucai.muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: context.yucai.muted),
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
      typeColor = context.yucai.negative;
    } else if (hasIncome) {
      typeIcon = LucideIcons.arrowUpLeft;
      typeColor = context.yucai.positive;
    } else {
      typeIcon = LucideIcons.arrowLeftRight;
      typeColor = context.yucai.muted;
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
                      style: TextStyle(
                          color: context.yucai.muted, fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            SizedBox(
              width: 44,
              child: Text(_formatDateShort(txn.transactionDate),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      color: context.yucai.muted,
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
