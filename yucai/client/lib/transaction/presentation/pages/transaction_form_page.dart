import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/amount_input.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/date_picker_input.dart';
import 'package:yucai_client/core/widgets/form_section.dart';
import 'package:yucai_client/core/widgets/type_tabs.dart';
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
  });

  final TransactionFormBloc? bloc;

  /// 预选账户 id。支出/收入 → 资产账户字段；转账 → 转出账户字段。
  /// 页面在 initState 应用此值；若该 id 不在加载到的账户列表里（被删除/
  /// 类型不符），下拉会回落到「未选」而不报错。
  final String? initialAccountId;

  /// 预选交易类型 tab。null 默认支出。
  final TxnType? initialType;

  @override
  Widget build(BuildContext context) {
    final injected = bloc;
    if (injected != null) {
      return BlocProvider<TransactionFormBloc>.value(
        value: injected,
        child: _TransactionFormView(
          initialAccountId: initialAccountId,
          initialType: initialType,
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
        return Icons.south_east;
      case TxnType.income:
        return Icons.north_east;
      case TxnType.transfer:
        return Icons.swap_horiz;
    }
  }
}

class _TransactionFormView extends StatefulWidget {
  const _TransactionFormView({this.initialAccountId, this.initialType});

  final String? initialAccountId;
  final TxnType? initialType;

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
  // 支出/收入：资产账户；转账：转出账户。从账户入口进入时预选当前账户
  //（initState 里赋值，避免在字段初始化时访问 widget）。
  String? _assetAccountId;
  String? _categoryAccountId; // 支出→expense 账户；收入→income 账户
  String? _toAccountId; // 转账：转入账户

  @override
  void initState() {
    super.initState();
    _type = widget.initialType ?? TxnType.expense;
    _assetAccountId = widget.initialAccountId;
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final bloc = context.read<TransactionFormBloc>();
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
        ));
        break;
    }
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

  static const _typeOptions = <TypeOption<TxnType>>[
    TypeOption(TxnType.expense, '支出', Icons.south_east),
    TypeOption(TxnType.income, '收入', Icons.north_east),
    TypeOption(TxnType.transfer, '转账', Icons.swap_horiz),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('记一笔'),
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
            Text('交易类型',
                style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
            const SizedBox(height: AppSpacing.sm),
            TypeTabs<TxnType>(
              options: _typeOptions,
              selected: _type,
              onChanged: (v) => setState(() {
                _type = v;
                // 切类型清空分类/转入选择，避免跨类型串号。
                _categoryAccountId = null;
                _toAccountId = null;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: AppSpacing.lg),

            // 金额 + 快捷 chips
            FormSection(
              title: '金额',
              children: [
                AmountInput(
                  controller: _amountCtrl,
                  label: '金额',
                  validator: (v) {
                    final cents =
                        ((double.tryParse(v ?? '') ?? 0) * 100).round();
                    return cents <= 0 ? '金额必须大于 0' : null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _quickChip('+50', () => _addQuick(5000)),
                    _quickChip('+100', () => _addQuick(10000)),
                    _quickChip('+500', () => _addQuick(50000)),
                    _quickChip('+1000', () => _addQuick(100000)),
                    _quickChip('清零', _clearAmount, isClear: true),
                  ],
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // 账户 / 分类（按类型切换）
            ..._accountCategorySections(
                assetAccounts, expenseAccounts, incomeAccounts),
            const SizedBox(height: AppSpacing.lg),

            // 日期 / 交易对象 / 备注
            FormSection(
              title: '详情',
              children: [
                DatePickerInput(
                  label: '交易日期',
                  initialValue: _date,
                  onSaved: (v) => _date = v ?? DateTime.now(),
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
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // 标签占位（YAGNI：Tags 模块未实装，纯占位 UI）
            _tagsPlaceholder(),
            if (inlineError != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(inlineError,
                  style: const TextStyle(color: AppColors.negative, fontSize: 13)),
            ],
            const SizedBox(height: AppSpacing.xl),
            FormActions(
              submitLabel: '保存',
              submitting: submitting,
              onSubmit: _submit,
              onCancel: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  /// 按当前类型构造账户/分类分区。
  /// - 支出：资产账户 + expense 分类
  /// - 收入：资产账户 + income 分类
  /// - 转账：转出资产账户 + 转入资产账户
  List<Widget> _accountCategorySections(
    List<Account> assetAccounts,
    List<Account> expenseAccounts,
    List<Account> incomeAccounts,
  ) {
    switch (_type) {
      case TxnType.expense:
        return [
          _accountSection('账户', '从哪个账户支出', assetAccounts, _assetAccountId,
              (v) => setState(() => _assetAccountId = v)),
          const SizedBox(height: AppSpacing.lg),
          _accountSection('分类', '支出类别', expenseAccounts,
              _categoryAccountId, (v) => setState(() => _categoryAccountId = v)),
        ];
      case TxnType.income:
        return [
          _accountSection('账户', '收入入账到哪个账户', assetAccounts, _assetAccountId,
              (v) => setState(() => _assetAccountId = v)),
          const SizedBox(height: AppSpacing.lg),
          _accountSection('分类', '收入类别', incomeAccounts, _categoryAccountId,
              (v) => setState(() => _categoryAccountId = v)),
        ];
      case TxnType.transfer:
        return [
          _accountSection('转出账户', '钱从哪来', assetAccounts, _assetAccountId,
              (v) => setState(() => _assetAccountId = v)),
          const SizedBox(height: AppSpacing.lg),
          _accountSection('转入账户', '钱到哪去', assetAccounts, _toAccountId,
              (v) => setState(() => _toAccountId = v),
              excludeId: _assetAccountId),
        ];
    }
  }

  Widget _accountSection(
    String title,
    String hint,
    List<Account> options,
    String? selected,
    ValueChanged<String?> onChanged, {
    String? excludeId,
  }) {
    final items = options.where((a) => a.id != excludeId).toList();
    return FormSection(
      title: title,
      children: [
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
      ],
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
          const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
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

  Widget _quickChip(String label, VoidCallback onTap, {bool isClear = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isClear ? AppColors.surfaceAlt : AppColors.accentSoft,
          border: Border.all(
              color: isClear ? AppColors.border : AppColors.accent),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isClear ? AppColors.muted : AppColors.accentHover,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
