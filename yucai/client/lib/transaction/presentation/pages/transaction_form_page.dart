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
import 'package:yucai_client/core/widgets/form_section.dart';
import 'package:yucai_client/core/widgets/time_picker_input.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_bloc.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_event.dart';
import 'package:yucai_client/transaction/presentation/bloc/transaction_form_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/journal_entry.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 记一笔表单页（支出 / 收入 / 转账），三尺寸响应式。
///
/// account-as-category：分类下拉是按 [AccountType] 过滤的账户（支出→expense
/// 账户、收入→income 账户）。Task 0.2 的服务端 FindByAccountType 尚未在
/// 客户端 proto stub 中生成（stubs 在该 RPC 之前生成），因此这里走 list()
/// 客户端过滤 —— 同样结果，无需重新生成 stub。
///
/// 标签区域为占位 UI（🔒 待 Tags 模块），不实装。
///
/// [bloc] 可选注入：生产路径留空，页面自行从 getIt 构造（并触发账户加载）；
/// 测试路径传入预构造的 bloc 以隔离 DI 与 gRPC。
///
/// [initialAccountId] / [initialType]：从账户入口（记一笔/转账）进入时预选
/// 当前账户 + 默认类型，省去用户在表单里重新挑账户的步骤。
///   - 支出/收入：预选「资产账户」= initialAccountId（仅当该账户是 Asset）。
///   - 转账：预选「转出账户」= initialAccountId。
/// 任一为 null/空时不预选（通用入口保持原行为）。
class TransactionFormPage extends StatelessWidget {
  const TransactionFormPage({
    super.key,
    this.bloc,
    this.initialAccountId,
    this.initialType,
    this.existing,
  });

  final TransactionFormBloc? bloc;

  /// 预选账户 id。支出/收入 → 资产账户字段；转账 → 转出账户字段。
  /// 页面在 initState 应用此值；若该 id 不在加载到的账户列表里（被删除/
  /// 类型不符），下拉会回落到「未选」而不报错。
  final String? initialAccountId;

  /// 预选交易类型 tab。null 默认支出。
  final TxnType? initialType;

  /// 编辑模式：传入既有交易则预填金额/描述/日期/类型/账户，提交走
  /// [UpdateTransactionRequested]（[TransactionRepository.update]）。null =
  /// 创建模式（默认）。仅支持 2-entry 的 SimpleExpense/Income/Transfer 形态；
  /// 复合多分录交易在路由层拦截，不进入此表单。
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
    // 页面级 bloc：两个 repo 从 getIt 注入。bloc 不经 injectable 注册，避免
    // 触发 build_runner 重新生成 DI config；与 router 现有 BlocProvider 模式一致。
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

  IconData get icon {
    switch (this) {
      case TxnType.expense:
        return LucideIcons.arrowDownLeft;
      case TxnType.income:
        return LucideIcons.arrowUpRight;
      case TxnType.transfer:
        return LucideIcons.arrowLeftRight;
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
  // Task 5：交易时间 HH:MM，默认当前时刻。提交时与 _date 拼成 RFC3339
  // transaction_time 落库；用户不调整时即记录「此刻」，保留旧行为。
  TimeOfDay _time = TimeOfDay.now();
  // 支出/收入：资产账户；转账：转出账户。从账户入口进入时预选当前账户
  //（initState 里赋值，避免在字段初始化时访问 widget）。
  String? _assetAccountId;
  String? _categoryAccountId; // 支出→expense 账户；收入→income 账户
  String? _toAccountId; // 转账：转入账户

  /// 编辑模式（widget.existing != null 时设置）。非空 → _submit 走
  /// UpdateTransactionRequested 而非 RecordXxx。
  String? _existingId;
  int _existingVersion = 0;
  bool _appliedExistingInference = false;

  bool get _isEdit => _existingId != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? TxnType.expense;
    _assetAccountId = widget.initialAccountId;
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
    }
  }

  /// 编辑模式预填类型 + 账户：需要账户类型元数据来区分
  /// expense/income/transfer，故从 getIt 单独拉一次账户列表做推断（表单
  /// bloc 仍独立加载下拉选项）。失败/无类型时退化为按 entry 顺序占位。
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
    AccountType? typeOf(String id) =>
        accounts.firstWhere((a) => a.id == id, orElse: () => _anon(id)).accountType;
    // 借/贷腿
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
      _toAccountId = dr!.accountId; // 转入 = 借方
      _assetAccountId = cr!.accountId; // 转出 = 贷方
    } else if (dr != null && cr != null) {
      // 未知类型组合 → 退化为支出 tab + 借/贷账户占位（用户手动修正）。
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

  /// 金额元→分。空串/非法 → 0。
  int get _amountCents =>
      ((double.tryParse(_amountCtrl.text) ?? 0) * 100).round();

  void _addQuick(int yuanCents) {
    final cur = (double.tryParse(_amountCtrl.text) ?? 0) * 100;
    setState(() {
      _amountCtrl.text = ((cur + yuanCents) / 100).toStringAsFixed(2);
    });
  }

  void _clearAmount() {
    setState(() => _amountCtrl.clear());
  }

  /// 编辑模式提交用的替换分录（balanced 2-entry，按当前类型 + 选中账户 +
  /// 金额构造）。与 `_previewEntries` 同构但不附 note（update 走原始分录）。
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
    // 编辑模式：构造替换分录 → UpdateTransactionRequested（走 repo.update，
    // 服务端先冲销旧余额再应用新分录 + version 乐观锁）。
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

  /// Task 5：把表单日期 `_date` 与时间选择器 `_time` 拼成一个本地
  /// [DateTime]，再 `.toUtc().toIso8601String()` 得到服务器期望的 RFC3339
  /// `transaction_time`（例 `2026-06-19T05:45:00.000Z`）。用户没动时间选择器
  /// 时 `_time` 已是 `TimeOfDay.now()`，即「此刻」—— 等价于旧行为。
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

  /// 实时复式预览：根据当前类型 + 选中的账户 + 金额构造两条分录。
  /// Desktop 右栏 JournalEntry 渲染。账户未选/金额为 0 时返回空表，bento
  /// 仍显示，便于用户看到「需要补全」。
  List<TransactionEntry> _previewEntries(List<Account> accounts) {
    final amt = _amountCents;
    String nameOf(String? id) =>
        accounts.firstWhere((a) => a.id == id,
            orElse: () => Account(
                  id: id ?? '',
                  name: id ?? '',
                  accountType: AccountType.asset,
                  category: AccountCategory.savings,
                  currencyCode: 'CNY',
                  initialBalanceCents: 0,
                  currentBalanceCents: 0,
                  ownership: Ownership.personal,
                  status: AccountStatus.active,
                )).name;

    switch (_type) {
      case TxnType.expense:
        // 借=分类(expense) 贷=资产
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
        // 借=资产 贷=分类(income)
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
        // 借=转入 贷=转出
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
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(_isEdit ? '编辑交易' : '记一笔'),
      ),
      body: BlocConsumer<TransactionFormBloc, TransactionFormState>(
        listenWhen: (prev, curr) =>
            curr is TransactionFormSuccess || curr is TransactionFormError,
        listener: (context, state) {
          if (state is TransactionFormSuccess) {
            Navigator.of(context).pop(true);
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
              : (state is TransactionFormSubmitting ? state.accounts : const <Account>[]);
          final submitting = state is TransactionFormSubmitting;
          final inlineError =
              state is TransactionFormReady ? state.error : null;

          final form = _buildForm(accounts, submitting, inlineError);
          final preview = JournalEntry(
            entries: _previewEntries(accounts),
            accountNameOf: (id) => accounts
                .firstWhere((a) => a.id == id, orElse: () => _anon(id))
                .name,
            // 注入账户类型 → JournalEntry 副标显示「资产账户·Asset」/
            // 「费用账户·Expense」(对齐 OD pv-row acc span)。
            accountTypeOf: (id) => accounts
                .firstWhere((a) => a.id == id, orElse: () => _anon(id))
                .accountType,
          );

          return AbsorbPointer(
            absorbing: submitting,
            child: ResponsiveLayout(
              mobile: _singleColumn(form, preview),
              tablet: _singleColumn(form, preview),
              desktop: _twoColumn(form, preview),
            ),
          );
        },
      ),
    );
  }

  static Account _anon(String id) => Account(
        id: id,
        name: id.length > 6 ? '#${id.substring(0, 6)}' : '#$id',
        accountType: AccountType.asset,
        category: AccountCategory.savings,
        currencyCode: 'CNY',
        initialBalanceCents: 0,
        currentBalanceCents: 0,
        ownership: Ownership.personal,
        status: AccountStatus.active,
      );

  Widget _singleColumn(Widget form, Widget preview) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          form,
          const SizedBox(height: AppSpacing.lg),
          preview,
        ],
      ),
    );
  }

  Widget _twoColumn(Widget form, Widget preview) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.md, AppSpacing.xl, AppSpacing.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: form),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 2, child: preview),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(
      List<Account> accounts, bool submitting, String? inlineError) {
    final assetAccounts =
        accounts.where((a) => a.accountType == AccountType.asset).toList();
    final expenseAccounts =
        accounts.where((a) => a.accountType == AccountType.expense).toList();
    final incomeAccounts =
        accounts.where((a) => a.accountType == AccountType.income).toList();

    return FormCard(
      maxWidth: 760,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 交易类型（OD TypeTabs：colored dot + label + sub-caption）
            const Text('交易类型',
                style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: AppSpacing.sm),
            _FormTypeTabs(
              selected: _type,
              onChanged: (v) => setState(() {
                _type = v;
                // 切类型清空分类/转入选择，避免跨类型串号。
                _categoryAccountId = null;
                _toAccountId = null;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),

            // OD hero amount panel：¥ + 46px mono + quick chips
            _HeroAmount(
              controller: _amountCtrl,
              validator: (v) {
                final cents =
                    ((double.tryParse(v ?? '') ?? 0) * 100).round();
                return cents <= 0 ? '金额必须大于 0' : null;
              },
              onQuickAdd: _addQuick,
              onClear: _clearAmount,
            ),
            const SizedBox(height: AppSpacing.lg),

            // 1 账户与分类（numbered section）
            _NumberedSection(
              number: 1,
              title: '账户与分类',
              children: _accountCategoryFields(
                  assetAccounts, expenseAccounts, incomeAccounts, accounts),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 2 交易详情（numbered section）
            _NumberedSection(
              number: 2,
              title: '交易详情',
              children: [
                // 交易日期 + 交易时间并排（Task 5）。时间默认当前时刻，
                // 用户不调整即记「此刻」，等价旧行为。
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
                TextFormField(
                  controller: _payeeCtrl,
                  decoration: const InputDecoration(
                    labelText: '交易对象 / 商户',
                    hintText: '例如：永辉超市',
                  ),
                ),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    hintText: '可选',
                  ),
                ),
                // 标签占位（YAGNI：Tags 模块未实装，纯占位 UI）
                _tagsPlaceholder(),
              ],
            ),
            if (inlineError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(inlineError,
                  style: const TextStyle(color: AppColors.negative, fontSize: 13)),
            ],
            const SizedBox(height: AppSpacing.xl),
            FormActions(
              submitLabel: _isEdit ? '保存修改' : '保存',
              submitting: submitting,
              onSubmit: _submit,
              onCancel: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// 按当前类型构造账户/分类字段（填入「1 账户与分类」numbered section）。
  /// - 支出：转出账户(asset) + 支出分类(expense)
  /// - 收入：转入账户(asset) + 收入分类(income)
  /// - 转账：转出账户(asset) + 转入账户(asset)
  ///
  /// 每个字段 = 标签 + 类型 tag(资产/费用/收入) + 下拉 + 余额 hint。
  /// 字段间距由 [_NumberedSection.fieldSpacing] 统一控制。
  List<Widget> _accountCategoryFields(
    List<Account> assetAccounts,
    List<Account> expenseAccounts,
    List<Account> incomeAccounts,
    List<Account> allAccounts,
  ) {
    switch (_type) {
      case TxnType.expense:
        // account-as-category：支出 = 借支出分类(Expense) + 贷转出账户(Asset)。
        return [
          _accountField('转出账户', '如招商银行、现金', assetAccounts,
              _assetAccountId, (v) => setState(() => _assetAccountId = v),
              allAccounts: allAccounts),
          _accountField('支出分类', '如餐饮、交通', expenseAccounts,
              _categoryAccountId, (v) => setState(() => _categoryAccountId = v),
              allAccounts: allAccounts),
        ];
      case TxnType.income:
        return [
          _accountField('转入账户', '如招商银行、现金', assetAccounts,
              _assetAccountId, (v) => setState(() => _assetAccountId = v),
              allAccounts: allAccounts),
          _accountField('收入分类', '如工资、理财收益', incomeAccounts,
              _categoryAccountId, (v) => setState(() => _categoryAccountId = v),
              allAccounts: allAccounts),
        ];
      case TxnType.transfer:
        return [
          _accountField('转出账户', '钱从哪来', assetAccounts, _assetAccountId,
              (v) => setState(() => _assetAccountId = v),
              allAccounts: allAccounts),
          _accountField('转入账户', '钱到哪去', assetAccounts, _toAccountId,
              (v) => setState(() => _toAccountId = v),
              excludeId: _assetAccountId, allAccounts: allAccounts),
        ];
    }
  }

  /// 单个账户字段：标签 + 类型 tag + 下拉 + 余额 hint（对齐 OD field + bal-hint）。
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
    // 选中账户（用于余额 hint）—— 从 allAccounts 查（selected 可能不在 items
    // 里，如被 excludeId 排除的转账对侧）。
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
        // OD field>label：标题 + tag(资产/费用/收入)
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
          decoration: InputDecoration(labelText: title, hintText: hint),
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

  /// OD field>label .tag：资产(灰) / 费用·收入(金)。按 options 推断类型。
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

  /// OD bal-hint：资产账户「当前余额 ¥X」；expense「累计支出」/ income「累计收入」
  /// （lifetime，来自 currentBalanceCents）。
  /// OD 原型用「本月已支出/已入账」—— 月度分类汇总 backend 未返回，defer；
  /// 此处用累计值近似，保留 hint 语义（用户可感知账户余额/分类量级）。
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

  Widget _tagsPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.smBorder,
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.lock, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '标签 · 待 Tags 模块',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

}

// ───────────────────────── OD 对齐组件 ─────────────────────────

/// 分 → 「¥1,234.56」（千分位 + 两位小数）。表单余额 hint 用。
String _fmtCents(int cents) {
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  final yuanStr = yuan.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '¥$yuanStr.$frac';
}

/// OD type tabs：三等宽分段，每段 = colored dot + 标签 + sub-caption。
/// 支出(红·花出去的钱) / 收入(绿·收进来的钱) / 转账(金·账户间划转)。
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
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500)),
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

/// OD hero amount panel：label「交易金额」+ ¥(serif 30px) + 46px mono 输入 +
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
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
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

/// OD numbered section：序号 badge(金浅底) + 标题 + 字段列。
/// 对齐原型「1 账户与分类」「2 交易详情」。
class _NumberedSection extends StatelessWidget {
  const _NumberedSection({
    required this.number,
    required this.title,
    required this.children,
  });

  final int number;
  final String title;
  final List<Widget> children;

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
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
