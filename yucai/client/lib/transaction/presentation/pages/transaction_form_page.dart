import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/date_picker_input.dart';
import 'package:yucai_client/core/widgets/time_picker_input.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';
import 'package:yucai_client/tag/domain/tag_color.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 记一笔表单页（支出 / 收入 / 转账）—— 严格对齐 OD `form-transaction.html`。
///
/// 布局（OD 基准）：
///   - **page-head**：返回链接 + h1(新增/编辑) + 取消 btn + 保存 btn-primary(gold ✓)。
///   - **2-col grid**（desktop ≥1200）：左 form(1fr 流体) + 右 preview(360px 固定,
///     sticky —— form 滚动时 preview 钉住)。mobile/tablet → 1-col 堆叠。
///   - LEFT：type tabs(3 分段) + amount hero(¥+46px mono+quick chips) + card1
///     「1 账户与分类」(numbered, 2-col field-grid, **3 mode 互斥**) + card2
///     「2 交易详情」(field-grid 日期/时间 + 商户 + 备注 + 标签 chip-row)。
///   - RIGHT：复式分录预览(**live 随 form 实时更新**：pv-head/body/bal-strip/
///     foot/note) + hint-card(💡 录入提示)。
///
/// account-as-category：分类下拉是按 [AccountType] 过滤的账户（支出→expense
/// 账户、收入→income 账户）。服务端 FindByAccountType 未在客户端 stub 中生成，
/// 故这里走 list() 客户端过滤 —— 同结果。
///
/// 标签 chip-row：真 tag 多选 + 持久化（ListTags 加载、编辑预选 GetTransactionTags、
/// 保存 diff → AddTag/RemoveTag）。色取自 [Tag.color]。
///
/// [bloc] 可选注入：生产留空，页面自建（触发账户加载）；测试传入预构造 bloc。
/// [initialAccountId] / [initialType]：从账户入口进入时预选账户 + 默认类型。
/// [existing]：编辑模式（提交走 [UpdateTransactionRequested]）。
class TransactionFormPage extends StatelessWidget {
  const TransactionFormPage({
    super.key,
    this.bloc,
    this.initialAccountId,
    this.initialType,
    this.existing,
  });

  final TransactionFormBloc? bloc;
  final String? initialAccountId;
  final TxnType? initialType;
  final Transaction? existing;

  @override
  Widget build(BuildContext context) {
    final injected = bloc;
    if (injected != null) {
      return BlocProvider<TransactionFormBloc>.value(
        value: injected,
        child: _TransactionFormView(
          initialAccountId: initialAccountId,
          initialType: initialType,
          existing: existing,
        ),
      );
    }
    return BlocProvider<TransactionFormBloc>(
      create: (_) {
        final b = TransactionFormBloc(
          getIt<TransactionRepository>(),
          getIt<AccountRepository>(),
        );
        b.add(const LoadAccountsRequested());
        return b;
      },
      child: _TransactionFormView(
        initialAccountId: initialAccountId,
        initialType: initialType,
        existing: existing,
      ),
    );
  }
}

/// 记一笔类型（支出/收入/转账）。对应 TypeTabs 顶部选择。
enum TxnType { expense, income, transfer }

extension TxnTypeX on TxnType {
  String get label {
    switch (this) {
      case TxnType.expense:
        return '支出';
      case TxnType.income:
        return '收入';
      case TxnType.transfer:
        return '转账';
    }
  }
}

class _TransactionFormView extends StatefulWidget {
  const _TransactionFormView({
    this.initialAccountId,
    this.initialType,
    this.existing,
  });

  final String? initialAccountId;
  final TxnType? initialType;
  final Transaction? existing;

  @override
  State<_TransactionFormView> createState() => _TransactionFormViewState();
}

class _TransactionFormViewState extends State<_TransactionFormView> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _payeeCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late TxnType _type;
  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  String? _assetAccountId;
  String? _categoryAccountId; // 支出→expense 账户；收入→income 账户
  String? _toAccountId; // 转账：转入账户

  /// 真 tag chip-row 状态:当前选中 IDs + ListTags 全量 + 编辑模式原始快照(diff 基准)。
  Set<String> _selectedTagIds = {}; // 多选 toggle 的当前选中集合
  Set<String> _originalTagIds = {}; // 编辑模式:_loadTransactionTags 缓存,save diff 基准
  List<Tag> _allTags = const []; // ListTags 加载的可用 tag(驱动 chip-row 渲染)

  String? _existingId;
  int _existingVersion = 0;
  bool _appliedExistingInference = false;

  bool get _isEdit => _existingId != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? TxnType.expense;
    _assetAccountId = widget.initialAccountId;
    _loadTags();
    final ex = widget.existing;
    if (ex != null) {
      _existingId = ex.id;
      _existingVersion = ex.version;
      _amountCtrl.text = (ex.totalDebitCents / 100).toStringAsFixed(2);
      _payeeCtrl.text = ex.description;
      _date = ex.transactionDate;
      if (ex.transactionTime != null) {
        _time = TimeOfDay.fromDateTime(ex.transactionTime!);
      }
      _inferTypeAndAccountsFromExisting(ex);
      _loadTransactionTags(ex.id);
    }
  }

  /// ListTags → _allTags(驱动 chip-row 渲染)。失败静默降级(空 list → chip-row 不渲染)。
  Future<void> _loadTags() async {
    try {
      final result = await getIt<TagRepository>().list();
      result.fold((_) {}, (tags) {
        if (mounted) setState(() => _allTags = tags);
      });
    } catch (_) {}
  }

  /// 编辑模式:GetTransactionTags → _selectedTagIds(预选) + _originalTagIds(diff 基准)。
  Future<void> _loadTransactionTags(String txnId) async {
    try {
      final result = await getIt<TagRepository>().getTransactionTags(txnId);
      result.fold((_) {}, (tags) {
        final ids = tags.map((t) => t.id).toSet();
        if (mounted) {
          setState(() {
            _selectedTagIds = ids;
            _originalTagIds = {...ids};
          });
        }
      });
    } catch (_) {}
  }

  /// 同步 tag diff:[existingTagIds](原始) vs _selectedTagIds(当前) → AddTag/RemoveTag。
  /// 新建 transaction 传 existingTagIds={} → 全部 _selectedTagIds 为新增。
  /// 单次 RPC 失败静默(已持久化 transaction 不回滚;tag 为附属 metadata)。
  Future<void> _syncTags(String txnId,
      {required Set<String> existingTagIds}) async {
    final repo = getIt<TagRepository>();
    final toAdd = _selectedTagIds.difference(existingTagIds);
    final toRemove = existingTagIds.difference(_selectedTagIds);
    for (final tagId in toAdd) {
      try {
        await repo.addTagToTransaction(tagId: tagId, transactionId: txnId);
      } catch (_) {}
    }
    for (final tagId in toRemove) {
      try {
        await repo.removeTagFromTransaction(tagId: tagId, transactionId: txnId);
      } catch (_) {}
    }
  }

  Future<void> _inferTypeAndAccountsFromExisting(Transaction t) async {
    List<Account> accounts = const [];
    try {
      final repo = getIt<AccountRepository>();
      final result = await repo.list();
      result.fold((_) {}, (list) => accounts = list);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _applyInference(t, accounts));
  }

  void _applyInference(Transaction t, List<Account> accounts) {
    if (_appliedExistingInference) return;
    _appliedExistingInference = true;
    AccountType? typeOf(String id) => accounts
        .firstWhere((a) => a.id == id, orElse: () => _anon(id))
        .accountType;
    TransactionEntry? dr, cr;
    for (final e in t.entries) {
      if (dr == null && e.debitCents > 0) dr = e;
      if (cr == null && e.creditCents > 0) cr = e;
    }
    final drType = dr == null ? null : typeOf(dr.accountId);
    final crType = cr == null ? null : typeOf(cr.accountId);
    if (drType == AccountType.expense && crType == AccountType.asset) {
      _type = TxnType.expense;
      _categoryAccountId = dr!.accountId;
      _assetAccountId = cr!.accountId;
    } else if (drType == AccountType.asset && crType == AccountType.income) {
      _type = TxnType.income;
      _assetAccountId = dr!.accountId;
      _categoryAccountId = cr!.accountId;
    } else if (drType == AccountType.asset && crType == AccountType.asset) {
      _type = TxnType.transfer;
      _toAccountId = dr!.accountId;
      _assetAccountId = cr!.accountId;
    } else if (dr != null && cr != null) {
      _type = TxnType.expense;
      _categoryAccountId = dr.accountId;
      _assetAccountId = cr.accountId;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _payeeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int get _amountCents =>
      ((double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0) * 100)
          .round();

  /// 千分位 + 两位小数格式化（对齐 OD `fmt()`：1,126.00）。+1,000 chip 也能
  /// 显示千分位。解析时 [replaceAll] 去逗号，故可重复 +add。
  String _formatAmount(double yuan) {
    final rounded = (yuan * 100).round() / 100;
    final abs = rounded.abs();
    final yuanPart = abs.floor();
    final frac = ((abs - yuanPart) * 100).round().toString().padLeft(2, '0');
    final grouped = yuanPart.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '$grouped.$frac';
  }

  void _addQuick(int yuanCents) {
    final cur = (double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0) *
        100;
    setState(() {
      _amountCtrl.text = _formatAmount((cur + yuanCents) / 100);
    });
  }

  void _clearAmount() {
    setState(() => _amountCtrl.clear());
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTagIds.contains(tagId)) {
        _selectedTagIds.remove(tagId);
      } else {
        _selectedTagIds.add(tagId);
      }
    });
  }

  List<TransactionEntry> _buildEntries() {
    final amt = _amountCents;
    switch (_type) {
      case TxnType.expense:
        return [
          TransactionEntry(
              accountId: _categoryAccountId ?? '',
              debitCents: amt,
              creditCents: 0),
          TransactionEntry(
              accountId: _assetAccountId ?? '',
              debitCents: 0,
              creditCents: amt),
        ];
      case TxnType.income:
        return [
          TransactionEntry(
              accountId: _assetAccountId ?? '',
              debitCents: amt,
              creditCents: 0),
          TransactionEntry(
              accountId: _categoryAccountId ?? '',
              debitCents: 0,
              creditCents: amt),
        ];
      case TxnType.transfer:
        return [
          TransactionEntry(
              accountId: _toAccountId ?? '',
              debitCents: amt,
              creditCents: 0),
          TransactionEntry(
              accountId: _assetAccountId ?? '',
              debitCents: 0,
              creditCents: amt),
        ];
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final bloc = context.read<TransactionFormBloc>();
    final transactionTime = _transactionTimeRfc3339();
    if (_isEdit) {
      switch (_type) {
        case TxnType.expense:
          if (_assetAccountId == null || _categoryAccountId == null) return;
          break;
        case TxnType.income:
          if (_assetAccountId == null || _categoryAccountId == null) return;
          break;
        case TxnType.transfer:
          if (_assetAccountId == null || _toAccountId == null) return;
          break;
      }
      bloc.add(UpdateTransactionRequested(
        id: _existingId!,
        version: _existingVersion,
        transactionDate: _date,
        description: _payeeCtrl.text.trim(),
        entries: _buildEntries(),
      ));
      return;
    }
    switch (_type) {
      case TxnType.expense:
        if (_assetAccountId == null || _categoryAccountId == null) return;
        bloc.add(RecordExpenseRequested(
          transactionDate: _date,
          assetAccountId: _assetAccountId!,
          expenseAccountId: _categoryAccountId!,
          amountCents: _amountCents,
          description: _payeeCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
          transactionTime: transactionTime,
        ));
        break;
      case TxnType.income:
        if (_assetAccountId == null || _categoryAccountId == null) return;
        bloc.add(RecordIncomeRequested(
          transactionDate: _date,
          assetAccountId: _assetAccountId!,
          incomeAccountId: _categoryAccountId!,
          amountCents: _amountCents,
          description: _payeeCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
          transactionTime: transactionTime,
        ));
        break;
      case TxnType.transfer:
        if (_assetAccountId == null || _toAccountId == null) return;
        bloc.add(RecordTransferRequested(
          transactionDate: _date,
          fromAccountId: _assetAccountId!,
          toAccountId: _toAccountId!,
          amountCents: _amountCents,
          description: _payeeCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
          transactionTime: transactionTime,
        ));
        break;
    }
  }

  String _transactionTimeRfc3339() {
    final local = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    return local.toUtc().toIso8601String();
  }

  /// 实时复式预览分录（type/amount/account/category 变 → 重建）。preview widget
  /// 据此渲染借/贷/合计/平衡/sum 文案。entry.note 注入账户名（preview widget
  /// 副标回退用 note）。
  List<TransactionEntry> _previewEntries(List<Account> accounts) {
    final amt = _amountCents;
    String nameOf(String? id) => accounts
        .firstWhere((a) => a.id == id, orElse: () => _anon(id ?? ''))
        .name;
    switch (_type) {
      case TxnType.expense:
        return [
          TransactionEntry(
              accountId: _categoryAccountId ?? '',
              debitCents: amt,
              creditCents: 0,
              note: nameOf(_categoryAccountId)),
          TransactionEntry(
              accountId: _assetAccountId ?? '',
              debitCents: 0,
              creditCents: amt,
              note: nameOf(_assetAccountId)),
        ];
      case TxnType.income:
        return [
          TransactionEntry(
              accountId: _assetAccountId ?? '',
              debitCents: amt,
              creditCents: 0,
              note: nameOf(_assetAccountId)),
          TransactionEntry(
              accountId: _categoryAccountId ?? '',
              debitCents: 0,
              creditCents: amt,
              note: nameOf(_categoryAccountId)),
        ];
      case TxnType.transfer:
        return [
          TransactionEntry(
              accountId: _toAccountId ?? '',
              debitCents: amt,
              creditCents: 0,
              note: nameOf(_toAccountId)),
          TransactionEntry(
              accountId: _assetAccountId ?? '',
              debitCents: 0,
              creditCents: amt,
              note: nameOf(_assetAccountId)),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: BlocConsumer<TransactionFormBloc, TransactionFormState>(
        listenWhen: (prev, curr) =>
            curr is TransactionFormSuccess || curr is TransactionFormError,
        listener: (context, state) async {
          if (state is TransactionFormSuccess) {
            // transaction 已持久化 → 同步 tag diff(AddTag/RemoveTag)后再 pop。
            // 新建:_originalTagIds 为空(全部选中为新增);编辑:_originalTagIds
            // 为加载时快照。txnId 来自 bloc success(create 拿新 id / update 用 e.id)。
            final navigator = Navigator.of(context);
            final txnId = state.transactionId;
            if (txnId != null) {
              await _syncTags(txnId,
                  existingTagIds:
                      _isEdit ? _originalTagIds : const <String>{});
            }
            if (mounted) navigator.pop(true);
          } else if (state is TransactionFormError) {
            AppToast.show(context, state.message, type: ToastType.error);
          }
        },
        builder: (context, state) {
          if (state is TransactionFormLoading ||
              state is TransactionFormInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          final accounts = state is TransactionFormReady
              ? state.accounts
              : (state is TransactionFormSubmitting
                  ? state.accounts
                  : const <Account>[]);
          final submitting = state is TransactionFormSubmitting;
          final inlineError =
              state is TransactionFormReady ? state.error : null;

          return SafeArea(
            child: Column(
              children: [
                // page-head（固定顶部，不随内容滚动）—— OD .page-head。
                _PageHead(
                  title: _isEdit ? '编辑交易' : '记一笔',
                  submitting: submitting,
                  onCancel: () => Navigator.of(context).maybePop(),
                  onSubmit: _submit,
                ),
                const Divider(height: 1, color: AppColors.border),
                Expanded(
                  child: AbsorbPointer(
                    absorbing: submitting,
                    child: ResponsiveLayout(
                      mobile: _stacked(accounts, inlineError),
                      tablet: _stacked(accounts, inlineError),
                      desktop: _twoColumn(accounts, inlineError),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Account _anon(String id) => Account(
        id: id,
        name: id.isEmpty
            ? '(未选)'
            : (id.length > 6 ? '#${id.substring(0, 6)}' : '#$id'),
        accountType: AccountType.asset,
        category: AccountCategory.savings,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 0,
        ownership: Ownership.personal,
        status: AccountStatus.active,
      );

  // ───────────────────────── 响应式布局 ─────────────────────────

  /// Mobile/tablet：1-col 堆叠（form 各 card → preview → hint）。
  Widget _stacked(List<Account> accounts, String? inlineError) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildForm(accounts, inlineError),
              const SizedBox(height: AppSpacing.md),
              _buildPreview(accounts),
              const SizedBox(height: AppSpacing.md),
              const _HintCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Desktop：2-col —— 左 form(流体 1fr) 自行滚动 + 右 preview(360px 固定 sticky)
  /// 独立滚动。form 滚动时 preview 钉在顶部（OD position:sticky top:84px 语义）。
  Widget _twoColumn(List<Account> accounts, String? inlineError) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左：form（流体，可滚动）
              Expanded(
                child: SingleChildScrollView(
                  child: _buildForm(accounts, inlineError),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              // 右：preview + hint（固定 360px，与 form 独立滚动 → sticky）
              SizedBox(
                width: 360,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPreview(accounts),
                      const SizedBox(height: AppSpacing.md),
                      const _HintCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── LEFT: form ─────────────────────────

  Widget _buildForm(List<Account> accounts, String? inlineError) {
    final assetAccounts =
        accounts.where((a) => a.accountType == AccountType.asset).toList();
    final expenseAccounts =
        accounts.where((a) => a.accountType == AccountType.expense).toList();
    final incomeAccounts =
        accounts.where((a) => a.accountType == AccountType.income).toList();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // type tabs（OD .tabs —— 无外层标题，直接分段控件）
          _FormTypeTabs(
            selected: _type,
            onChanged: (v) => setState(() {
              _type = v;
              _categoryAccountId = null;
              _toAccountId = null;
            }),
          ),
          const SizedBox(height: AppSpacing.lg),

          // hero amount panel
          _HeroAmount(
            controller: _amountCtrl,
            validator: (v) {
              final cents = ((double.tryParse((v ?? '').replaceAll(',', '')) ??
                      0) *
                  100).round();
              return cents <= 0 ? '金额必须大于 0' : null;
            },
            onQuickAdd: _addQuick,
            onClear: _clearAmount,
          ),
          const SizedBox(height: AppSpacing.lg),

          // card1 「1 账户与分类」（2-col field-grid，3 mode 互斥）
          _OdCard(
            child: _NumberedSection(
              number: 1,
              title: '账户与分类',
              child: _accountCategoryGrid(
                  assetAccounts, expenseAccounts, incomeAccounts, accounts),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // card2 「2 交易详情」
          _OdCard(
            child: _NumberedSection(
              number: 2,
              title: '交易详情',
              child: _detailsFields(),
            ),
          ),
          if (inlineError != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(inlineError,
                style:
                    const TextStyle(color: AppColors.negative, fontSize: 13)),
          ],
        ],
      ),
    );
  }

  /// card1 字段 —— 按 type 切换 3 mode（互斥），每 mode = 2-col field-grid。
  Widget _accountCategoryGrid(
    List<Account> assetAccounts,
    List<Account> expenseAccounts,
    List<Account> incomeAccounts,
    List<Account> allAccounts,
  ) {
    final List<Widget> fields;
    switch (_type) {
      case TxnType.expense:
        fields = [
          _accountField('转出账户', '如招商银行、现金', assetAccounts,
              _assetAccountId, (v) => setState(() => _assetAccountId = v),
              allAccounts: allAccounts),
          _accountField('支出分类', '如餐饮、交通', expenseAccounts,
              _categoryAccountId, (v) => setState(() => _categoryAccountId = v),
              allAccounts: allAccounts),
        ];
        break;
      case TxnType.income:
        fields = [
          _accountField('转入账户', '如招商银行、现金', assetAccounts,
              _assetAccountId, (v) => setState(() => _assetAccountId = v),
              allAccounts: allAccounts),
          _accountField('收入分类', '如工资、理财收益', incomeAccounts,
              _categoryAccountId, (v) => setState(() => _categoryAccountId = v),
              allAccounts: allAccounts),
        ];
        break;
      case TxnType.transfer:
        fields = [
          _accountField('转出账户', '钱从哪来', assetAccounts, _assetAccountId,
              (v) => setState(() => _assetAccountId = v),
              allAccounts: allAccounts),
          _accountField('转入账户', '钱到哪去', assetAccounts, _toAccountId,
              (v) => setState(() => _toAccountId = v),
              excludeId: _assetAccountId, allAccounts: allAccounts),
        ];
        break;
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: fields[0]),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: fields[1]),
      ],
    );
  }

  /// 单个账户字段：label(标题 + 类型 tag) + 下拉 + bal-hint。
  Widget _accountField(
    String title,
    String hint,
    List<Account> options,
    String? selected,
    ValueChanged<String?> onChanged, {
    String? excludeId,
    required List<Account> allAccounts,
  }) {
    final items = options.where((a) => a.id != excludeId).toList();
    Account? selectedAcct;
    if (selected != null) {
      for (final a in allAccounts) {
        if (a.id == selected) {
          selectedAcct = a;
          break;
        }
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 12.5)),
            const SizedBox(width: 6),
            _accountFieldTag(options),
          ],
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          value: (selected != null && items.any((a) => a.id == selected))
              ? selected
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            border: OutlineInputBorder(
              borderRadius: AppRadius.smBorder,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.smBorder,
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.smBorder,
              borderSide: const BorderSide(color: AppColors.accent),
            ),
            hintText: hint,
          ),
          items: items
              .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
              .toList(),
          onChanged: onChanged,
          validator: (v) => (v == null || v.isEmpty) ? '请选择$title' : null,
        ),
        _balanceHint(selectedAcct),
      ],
    );
  }

  /// OD .field>label .tag：资产(灰) / 费用·收入(金)。按 options 推断类型。
  Widget _accountFieldTag(List<Account> options) {
    if (options.isEmpty) return const SizedBox.shrink();
    final type = options.first.accountType;
    final String label;
    final bool isAsset;
    switch (type) {
      case AccountType.asset:
        label = '资产';
        isAsset = true;
        break;
      case AccountType.expense:
        label = '费用';
        isAsset = false;
        break;
      case AccountType.income:
        label = '收入';
        isAsset = false;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: isAsset ? const Color(0xFFEEF0F3) : AppColors.accentSoft,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(
              color: isAsset ? const Color(0xFF56606B) : AppColors.accent,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5)),
    );
  }

  /// OD .bal-hint：资产「当前余额」/ expense「累计支出」/ income「累计收入」。
  /// 月度汇总 backend 未返回 → 用 lifetime currentBalanceCents 近似（保留语义）。
  Widget _balanceHint(Account? acct) {
    if (acct == null) return const SizedBox.shrink();
    final cents = acct.currentBalanceCents;
    final String label;
    switch (acct.accountType) {
      case AccountType.asset:
        label = '当前余额';
        break;
      case AccountType.expense:
        label = '累计支出';
        break;
      case AccountType.income:
        label = '累计收入';
        break;
      default:
        return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text('$label ',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          Text(_fmtCents(cents),
              style: const TextStyle(
                  color: AppColors.fg,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }

  /// card2 字段：field-grid(日期 | 时间) + 商户 + 备注 textarea + 标签 chip-row。
  Widget _detailsFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 交易日期 | 交易时间（field-grid 2-col，mono）
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DatePickerInput(
                label: '交易日期',
                initialValue: _date,
                onSaved: (v) => _date = v ?? DateTime.now(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TimePickerInput(
                label: '交易时间',
                initialTime: _time,
                onChanged: (t) => setState(() => _time = t),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // 交易对象 / 商户
        TextFormField(
          controller: _payeeCtrl,
          decoration: const InputDecoration(
            labelText: '交易对象 / 商户',
            hintText: '例如：永辉超市、美团外卖',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 备注 textarea
        TextFormField(
          controller: _noteCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '备注',
            hintText: '补充说明，例如聚餐人数、报销事由…',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        // 标签 chip-row（OD .tag-row —— 真 tag 多选 + 持久化）
        _tagsChipRow(),
      ],
    );
  }

  /// OD .tag-row：真 tag multi-select toggle。chip 背景/边框/文字色取自
  /// [Tag.color](#RRGGBB)；选中 = 实色背景 + ✓，未选 = 透明背景 + 彩色边框。
  /// _allTags 为空(ListTags 失败/无 tag)→ 整行不渲染(降级)。
  Widget _tagsChipRow() {
    if (_allTags.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Text('标签',
                style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
            SizedBox(width: 6),
            Text('（可多选）',
                style: TextStyle(color: Color(0xFFA8A298), fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in _allTags)
              _RealTagChip(
                tag: tag,
                on: _selectedTagIds.contains(tag.id),
                onTap: () => _toggleTag(tag.id),
              ),
          ],
        ),
      ],
    );
  }

  // ───────────────────────── RIGHT: preview ─────────────────────────

  Widget _buildPreview(List<Account> accounts) {
    return _FormJournalPreview(
      entries: _previewEntries(accounts),
      amountCents: _amountCents,
      accountNameOf: (id) =>
          accounts.firstWhere((a) => a.id == id, orElse: () => _anon(id)).name,
      accountTypeOf: (id) => accounts
          .firstWhere((a) => a.id == id, orElse: () => _anon(id))
          .accountType,
    );
  }
}

// ───────────────────────── OD 对齐组件 ─────────────────────────

/// 分 → 「¥1,234.56」（千分位 + 两位小数）。
String _fmtCents(int cents) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  final yuanStr = yuan.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '¥$yuanStr.$frac';
}

/// OD .card .card-pad：白底 + 14px 圆角 + 边框 + 极淡阴影 + 22×24 内边距。
/// 左列各 card（账户与分类 / 交易详情）的外壳。
class _OdCard extends StatelessWidget {
  const _OdCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x09000000),
              blurRadius: 20,
              offset: Offset(0, 6)),
        ],
      ),
      child: child,
    );
  }
}

/// OD .page-head：返回链接 + h1(serif 26px) + 右侧 actions(取消 btn + 保存
/// btn-primary gold ✓)。固定在顶部，不随内容滚动。
class _PageHead extends StatelessWidget {
  const _PageHead({
    required this.title,
    required this.submitting,
    required this.onCancel,
    required this.onSubmit,
  });

  final String title;
  final bool submitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.md),
      child: Row(
        children: [
          InkWell(
            onTap: onCancel,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(LucideIcons.chevronLeft,
                      size: 16, color: AppColors.muted),
                  SizedBox(width: 2),
                  Text('返回',
                      style:
                          TextStyle(color: AppColors.muted, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          DefaultTextStyle(
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback,
              color: AppColors.fg,
            ),
            child: Text(title),
          ),
          const Spacer(),
          // 取消 btn（OD .btn）
          _TextBtn(label: '取消', onTap: onCancel),
          const SizedBox(width: AppSpacing.sm),
          // 保存 btn-primary（gold 实心 + ✓ 图标）
          _GoldSaveBtn(onTap: submitting ? null : onSubmit),
        ],
      ),
    );
  }
}

class _TextBtn extends StatelessWidget {
  const _TextBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smBorder,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: AppRadius.smBorder,
        ),
        child: Text(label,
            style: const TextStyle(
                color: AppColors.fg, fontSize: 13.5, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _GoldSaveBtn extends StatelessWidget {
  const _GoldSaveBtn({required this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smBorder,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.accent : AppColors.accent.withValues(alpha: 0.5),
          border: Border.all(color: AppColors.accent),
          borderRadius: AppRadius.smBorder,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(LucideIcons.check, size: 16, color: Colors.white),
            SizedBox(width: 7),
            Text('保存',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// OD type tabs：三等宽分段，每段 = colored dot + 标签 + sub-caption。
class _FormTypeTabs extends StatelessWidget {
  const _FormTypeTabs({required this.selected, required this.onChanged});

  final TxnType selected;
  final ValueChanged<TxnType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final t in TxnType.values)
            Expanded(
              child: _TypeTab(
                type: t,
                selected: selected == t,
                onTap: () => onChanged(t),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeTab extends StatefulWidget {
  const _TypeTab({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final TxnType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_TypeTab> createState() => _TypeTabState();
}

class _TypeTabState extends State<_TypeTab> {
  bool _hover = false;

  (Color, String) get _styling {
    switch (widget.type) {
      case TxnType.expense:
        return (AppColors.negative, '花出去的钱');
      case TxnType.income:
        return (AppColors.positive, '收进来的钱');
      case TxnType.transfer:
        return (AppColors.accent, '账户间划转');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (dotColor, sub) = _styling;
    final selected = widget.selected;
    final fg = selected ? AppColors.fg : AppColors.muted;
    final subColor = selected ? AppColors.muted : const Color(0xFFA8A298);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.surface
                : (_hover ? AppColors.surfaceAlt : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 3,
                        offset: Offset(0, 1))
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: selected ? dotColor : subColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(widget.type.label,
                      style: TextStyle(
                          color: fg,
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500)),
                ],
              ),
              const SizedBox(height: 2),
              Text(sub, style: TextStyle(color: subColor, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

/// OD .amount-wrap：label「交易金额」+ ¥(serif 30px) + 46px mono 输入 +
/// quick chips(+50/+100/+500/+1,000/清零)。
class _HeroAmount extends StatelessWidget {
  const _HeroAmount({
    required this.controller,
    this.validator,
    this.onQuickAdd,
    this.onClear,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final void Function(int yuanCents)? onQuickAdd;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('交易金额',
              style: TextStyle(
                  color: AppColors.muted, fontSize: 12, letterSpacing: 0.6)),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              const Text('¥',
                  style: TextStyle(
                      fontFamily: AppTypography.displayFamily,
                      fontFamilyFallback: AppTypography.displayFallback,
                      fontSize: 30,
                      color: AppColors.muted)),
              Expanded(
                child: TextFormField(
                  key: const ValueKey('hero_amount'),
                  controller: controller,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^-?\d*\.?\d*')),
                  ],
                  style: const TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.02,
                    fontFeatures: AppTypography.tabularFigures,
                    color: AppColors.fg,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '0.00',
                    hintStyle: TextStyle(
                        color: Color(0xFFA8A298),
                        fontSize: 46,
                        fontWeight: FontWeight.w500),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  validator: validator,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('+50', () => onQuickAdd?.call(5000)),
              _chip('+100', () => onQuickAdd?.call(10000)),
              _chip('+500', () => onQuickAdd?.call(50000)),
              _chip('+1,000', () => onQuickAdd?.call(100000)),
              _chip('清零', onClear, isClear: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback? onTap, {bool isClear = false}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isClear ? AppColors.muted : AppColors.fg,
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ),
      ),
    );
  }
}

/// OD numbered section：序号 badge(金浅底) + 标题 + 单个 child（由调用方决定
/// 内部布局：card1 传 2-col Row；card2 传 field-stack Column）。
class _NumberedSection extends StatelessWidget {
  const _NumberedSection({
    required this.number,
    required this.title,
    required this.child,
  });

  final int number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.accentSoft,
                borderRadius: BorderRadius.circular(5),
              ),
              alignment: Alignment.center,
              child: Text('$number',
                  style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFeatures: AppTypography.tabularFigures)),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1)),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

/// OD .tag（card2 标签 chip-row 单元）：on/off toggle，色取自 [Tag.color]。
/// on = 实色背景 + 白字 + ✓；off = 透明背景 + 彩色边框/文字。
class _RealTagChip extends StatelessWidget {
  const _RealTagChip({
    required this.tag,
    required this.on,
    required this.onTap,
  });

  final Tag tag;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = tagColor(tag.color);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: on ? c : Colors.transparent,
            border: Border.all(color: c),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (on) ...[
                const Text('✓',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
              ],
              Text(tag.name,
                  style: TextStyle(
                    color: on ? Colors.white : c,
                    fontSize: 13,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

/// `#RRGGBB` → [Color] 解析见共享 [tagColor]（tag/domain/tag_color.dart）。

// ───────────────────────── RIGHT: 复式分录预览（live） ─────────────────────────

/// OD .preview card —— 复式分录预览（form 专用精简版，与 detail JournalEntry
/// 区别：标题「复式分录预览」+ pv-bal-strip 双列 + pv-foot sum/bal 并列 + pv-note
/// account-as-category 说明）。
///
/// **live 实时**：父页 setState（type/amount/account/category 变）→ 重建本 widget
/// → 借/贷/合计/平衡/sum 全部刷新。无独立 bloc，纯 props 驱动。
class _FormJournalPreview extends StatelessWidget {
  const _FormJournalPreview({
    required this.entries,
    required this.amountCents,
    required this.accountNameOf,
    required this.accountTypeOf,
  });

  final List<TransactionEntry> entries;
  final int amountCents;
  final String Function(String accountId) accountNameOf;
  final AccountType? Function(String accountId) accountTypeOf;

  @override
  Widget build(BuildContext context) {
    final totalDebit = entries.fold<int>(0, (s, e) => s + e.debitCents);
    final totalCredit = entries.fold<int>(0, (s, e) => s + e.creditCents);
    final balanced = totalDebit == totalCredit;
    final amtStr = _fmtCents(amountCents);

    // 借/贷腿（首借/首贷）
    TransactionEntry? dr, cr;
    for (final e in entries) {
      if (dr == null && e.debitCents > 0) dr = e;
      if (cr == null && e.creditCents > 0) cr = e;
    }
    final drName = dr == null ? '(未选)' : _labelOf(dr.accountId);
    final crName = cr == null ? '(未选)' : _labelOf(cr.accountId);
    final drTypeLabel = dr == null ? null : _typeLabel(accountTypeOf(dr.accountId));
    final crTypeLabel = cr == null ? null : _typeLabel(accountTypeOf(cr.accountId));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x09000000), blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // pv-head
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: const [
                Expanded(
                  child: Text('复式分录预览',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback: AppTypography.displayFallback,
                          color: AppColors.fg)),
                ),
                Text('DOUBLE-ENTRY',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        letterSpacing: 0.5,
                        fontFeatures: AppTypography.tabularFigures)),
              ],
            ),
          ),
          // pv-body：借 row + sep + 贷 row
          _PvRow(
              side: '借', sideColor: AppColors.negative, name: drName, typeLabel: drTypeLabel, amt: amtStr),
          const _PvSep(),
          _PvRow(
              side: '贷', sideColor: AppColors.positive, name: crName, typeLabel: crTypeLabel, amt: amtStr),
          // pv-bal-strip：借方合计 / 贷方合计 两列
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _BalCol(
                      label: '借方合计',
                      value: _fmtCents(totalDebit),
                      valueColor: AppColors.negative),
                ),
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(
                          left: BorderSide(color: AppColors.border)),
                    ),
                    child: _BalCol(
                        label: '贷方合计',
                        value: _fmtCents(totalCredit),
                        valueColor: AppColors.positive),
                  ),
                ),
              ],
            ),
          ),
          // pv-foot：sum 文案 + ✓ 借贷平衡
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: const BoxDecoration(
              color: AppColors.surfaceAlt,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '$drName +${_fmtBody(totalDebit)}　·　$crName −${_fmtBody(totalCredit)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12.5),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: balanced ? AppColors.positive : AppColors.negative,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        balanced ? LucideIcons.check : LucideIcons.alertTriangle,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(balanced ? '借贷平衡' : '不平衡',
                        style: TextStyle(
                            color: balanced
                                ? AppColors.positive
                                : AppColors.negative,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          // pv-note：account-as-category 说明
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'account-as-category 方案A：',
                        style: TextStyle(
                            color: AppColors.fg,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                const SizedBox(height: 4),
                Text(
                  '支出分类「$drName」本质是 Expense 类型账户。每笔交易生成一条借贷平衡的复式分录，确保资产 = 负债 + 权益始终成立。',
                  style: const TextStyle(
                      color: AppColors.muted, fontSize: 12, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _labelOf(String id) {
    final n = accountNameOf(id);
    if (n.isEmpty || n.startsWith('#')) return '(未选)';
    return n;
  }
}

/// OD .pv-row：side(借/贷 serif 17px) + acc(名 + 类型副标) + amt(mono 17px)。
class _PvRow extends StatelessWidget {
  const _PvRow({
    required this.side,
    required this.sideColor,
    required this.name,
    required this.typeLabel,
    required this.amt,
  });

  final String side;
  final Color sideColor;
  final String name;
  final String? typeLabel;
  final String amt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(side,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: AppTypography.displayFamily,
                    fontFamilyFallback: AppTypography.displayFallback,
                    fontSize: 17,
                    color: sideColor)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.fg)),
                if (typeLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(typeLabel!,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(amt,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: sideColor,
                  letterSpacing: -0.01,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

class _PvSep extends StatelessWidget {
  const _PvSep();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      height: 1,
      color: AppColors.border,
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
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  letterSpacing: 0.6)),
          const SizedBox(height: 3),
          Text(value,
              style: TextStyle(
                  color: valueColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

/// OD .hint-card：💡 录入提示（虚线边框灰底小字）。
class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border), // OD dashed；Flutter 无原生虚线边框，实线近似
        borderRadius: AppRadius.lgBorder,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.lightbulb,
              size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('录入提示',
                    style: TextStyle(
                        color: AppColors.fg,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
                SizedBox(height: 4),
                Text(
                  '金额支持小数与千分位；保存后该分录将自动过账至对应账户，并在月度报表与对账单中体现。',
                  style: TextStyle(
                      color: AppColors.muted, fontSize: 12.5, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// AccountType → OD 副标文案（「费用账户·Expense」）。null → null。
String? _typeLabel(AccountType? type) {
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

/// 分 → 「1,234.56」（千分位 + 两位小数），用于 pv-foot sum 文案。
String _fmtBody(int cents) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  final yuanStr = yuan.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '$yuanStr.$frac';
}
