import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/amortization_preview.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 债务表单页（创建 + 编辑模式）。对齐 OD 原型 debt-form.html / tablet / mobile。
///
/// 结构对齐 [ReceivableFormPage]（已 OD 对齐的骨架）：OD `.sec` 分区卡 +
/// `_RadioCard`（icon + label + desc）+ `AmortizationPreview` 深色实时预览 +
/// `_actionsCard`（sticky footer actionbar）。文案/字段/数据按 **debt 语义**
/// （借入）：债权方 / 借款本金 / 月供 / 还款计划 / 创建债务。
///
/// debt 专属(区别于 receivable):
///  - type 默认 `DebtType.borrowedIn`（不渲染方向选择器）。
///  - 关联账户 = liability loan/credit_card 账户（我欠别人的负债侧）。
///  - subtype = DebtSubtypes（房贷/车贷/信用卡/亲友借款/其他）。
///  - 信用卡子类型 → 信用卡信息区（账单日/还款日/额度/年费，回写 account）。
///
/// 提交 → dispatch [CreateDebtRequested] / [UpdateDebtRequested] → 成功后 pop。
/// DebtBloc 由 router provide；本页 `context.read<DebtBloc>()`。
class DebtFormPage extends StatefulWidget {
  const DebtFormPage({
    super.key,
    this.existing,
    this.initialStartDate,
    this.initialDueDate,
    this.initialAccountId,
  });

  final Debt? existing;
  final DateTime? initialStartDate;
  final DateTime? initialDueDate;
  final String? initialAccountId;

  @override
  State<DebtFormPage> createState() => _DebtFormPageState();
}

class _DebtFormPageState extends State<DebtFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _counterpartyCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  // ---- 信用卡信息区字段（subtype == DebtSubtypes.creditCard 时显示）。
  final _ccBillingDayCtrl = TextEditingController();
  final _ccRepaymentDayCtrl = TextEditingController();
  final _ccLimitCtrl = TextEditingController();
  final _ccAnnualFeeCtrl = TextEditingController();
  bool _ccDirty = false;

  /// 债务子类型 key（DebtSubtypes.*）。存 key —— 判断用 const，UI 显示 labels[key]。
  String _subtypeKey = DebtSubtypes.mortgage;
  AmortizationMethod _amortization = AmortizationMethod.equalPrincipalInterest;

  String? _accountId;
  DateTime? _startDate;
  DateTime? _dueDate;

  List<Account> _accounts = const [];
  // 借入到账账户(资产侧,可选):选择后创建时自动双记现金入账。
  List<Account> _assetAccounts = const [];
  String? _disbursementAccountId;
  bool _accountsLoading = true;

  int _step = 0;
  bool _submitted = false;

  Debt? get _existing => widget.existing;
  bool get _isEdit => _existing != null;

  static const _amortizations = <AmortizationMethod>[
    AmortizationMethod.equalPrincipalInterest,
    AmortizationMethod.equalPrincipal,
    AmortizationMethod.lumpSum,
  ];

  @override
  void initState() {
    super.initState();
    final e = _existing;
    if (e != null) {
      _counterpartyCtrl.text = e.counterparty;
      _principalCtrl.text = (e.totalPrincipalCents / 100).toStringAsFixed(2);
      // 存储为小数(0.05),输入框按百分数回显(5)。
      _rateCtrl.text = (e.interestRate * 100)
          .toStringAsFixed(4)
          .replaceFirst(RegExp(r'0+$'), '')
          .replaceFirst(RegExp(r'\.$'), '');
      _amortization = e.amortization;
      _startDate = e.startDate;
      _dueDate = e.dueDate;
      _accountId = e.accountId;
      _subtypeKey = e.subtype.isEmpty ? DebtSubtypes.mortgage : e.subtype;
    } else {
      _startDate = widget.initialStartDate;
      _dueDate = widget.initialDueDate;
      _accountId = widget.initialAccountId;
    }
    _loadAccounts();
    _principalCtrl.addListener(() => setState(() {}));
    _rateCtrl.addListener(() => setState(() {}));
    void markCcDirty() => _ccDirty = true;
    _ccBillingDayCtrl.addListener(markCcDirty);
    _ccRepaymentDayCtrl.addListener(markCcDirty);
    _ccLimitCtrl.addListener(markCcDirty);
    _ccAnnualFeeCtrl.addListener(markCcDirty);
  }

  @override
  void dispose() {
    _counterpartyCtrl.dispose();
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _ccBillingDayCtrl.dispose();
    _ccRepaymentDayCtrl.dispose();
    _ccLimitCtrl.dispose();
    _ccAnnualFeeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final repo = GetIt.instance<AccountRepository>();
      final result = await repo.list();
      final list = result.fold((_) => const <Account>[], (l) => l);
      if (!mounted) return;
      setState(() {
        _accounts =
            list.where((a) => a.accountType == AccountType.liability).toList();
        _assetAccounts =
            list.where((a) => a.accountType == AccountType.asset).toList();
        _accountsLoading = false;
        _refillCreditCardFields();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _accountsLoading = false);
    }
  }

  // ===================== 子类型 / 信用卡区 helpers =====================

  bool get _isCreditCard => _subtypeKey == DebtSubtypes.creditCard;

  List<Account> get _visibleAccounts => _isCreditCard
      ? _accounts
          .where((a) => a.category == AccountCategory.creditCard)
          .toList()
      : _accounts;

  Account? get _selectedAccount =>
      _accounts.where((a) => a.id == _accountId).cast<Account?>().firstWhere(
            (_) => true,
            orElse: () => null,
          );

  void _refillCreditCardFields() {
    final a = _selectedAccount;
    if (a == null) return;
    _ccBillingDayCtrl.text = a.creditBillingDay?.toString() ?? '';
    _ccRepaymentDayCtrl.text = a.creditRepaymentDay?.toString() ?? '';
    _ccLimitCtrl.text = a.creditLimitCents > 0
        ? (a.creditLimitCents / 100).toStringAsFixed(2)
        : '';
    _ccAnnualFeeCtrl.text = a.creditAnnualFeeCents != null &&
            a.creditAnnualFeeCents! > 0
        ? (a.creditAnnualFeeCents! / 100).toStringAsFixed(2)
        : '';
    _ccDirty = false;
  }

  void _onAccountChanged(String? v) {
    setState(() {
      _accountId = v;
      _refillCreditCardFields();
    });
  }

  Future<void> _persistCreditCardFieldsIfNeeded() async {
    if (!_isCreditCard || !_ccDirty) return;
    final a = _selectedAccount;
    if (a == null) return;
    final limitCents =
        (double.tryParse(_ccLimitCtrl.text) ?? 0).round() * 100;
    final annualFeeCents =
        (double.tryParse(_ccAnnualFeeCtrl.text) ?? 0).round() * 100;
    try {
      await GetIt.instance<AccountRepository>().update(UpdateAccountParams(
        id: a.id,
        version: a.version,
        creditBillingDay: int.tryParse(_ccBillingDayCtrl.text),
        creditRepaymentDay: int.tryParse(_ccRepaymentDayCtrl.text),
        creditLimitCents: limitCents,
        creditAnnualFeeCents: annualFeeCents,
      ));
    } catch (_) {}
    _ccDirty = false;
  }

  Future<void> _goCreateCreditCardAccount() async {
    final ctx = context;
    await Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider<AccountBloc>(
          create: (_) => GetIt.instance<AccountBloc>(),
          child: const AccountFormPage(),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _accountsLoading = true);
    _loadAccounts();
  }

  // ===================== 摊还预览（client-side） =====================

  int _monthsBetween(DateTime? a, DateTime? b) {
    if (a == null || b == null) return 0;
    final m = (b.year - a.year) * 12 + (b.month - a.month);
    return m <= 0 ? 0 : m;
  }

  AmortizationPreviewData? _computePreview() {
    final p = double.tryParse(_principalCtrl.text) ?? 0;
    final annualRate = double.tryParse(_rateCtrl.text) ?? 0;
    final n = _monthsBetween(_startDate, _dueDate);
    if (p <= 0 || _startDate == null || _dueDate == null || n <= 0) return null;

    final r = annualRate / 100 / 12;
    switch (_amortization) {
      case AmortizationMethod.equalPrincipalInterest:
        final pow = _pow(1 + r, n);
        final monthly = r > 0 ? p * r * pow / (pow - 1) : p / n;
        final rows = <AmortizationPreviewRow>[];
        var bal = p;
        for (var i = 1; i <= (n < 5 ? n : 5); i++) {
          final interest = bal * r;
          final principal = monthly - interest;
          bal -= principal;
          rows.add(AmortizationPreviewRow(
            index: i,
            date: _addMonths(_startDate!, i - 1),
            principal: principal,
            interest: interest,
          ));
        }
        final totalInterestAll = monthly * n - p;
        return AmortizationPreviewData(
          label: '月供',
          headlineAmount: monthly,
          rows: rows,
          n: n,
          totalInterest: totalInterestAll,
          totalPayment: p + totalInterestAll,
          annualRate: annualRate,
        );
      case AmortizationMethod.equalPrincipal:
        final monthlyPrincipal = p / n;
        final rows = <AmortizationPreviewRow>[];
        var bal = p;
        for (var i = 1; i <= (n < 5 ? n : 5); i++) {
          final interest = bal * r;
          bal -= monthlyPrincipal;
          rows.add(AmortizationPreviewRow(
            index: i,
            date: _addMonths(_startDate!, i - 1),
            principal: monthlyPrincipal,
            interest: interest,
          ));
        }
        var b = p;
        var totalInterest = 0.0;
        for (var i = 0; i < n; i++) {
          totalInterest += b * r;
          b -= monthlyPrincipal;
        }
        final firstMonthly = monthlyPrincipal + p * r;
        return AmortizationPreviewData(
          label: '首月供',
          headlineAmount: firstMonthly,
          rows: rows,
          n: n,
          totalInterest: totalInterest,
          totalPayment: p + totalInterest,
          annualRate: annualRate,
        );
      case AmortizationMethod.lumpSum:
        final years = n / 12;
        final interest = p * annualRate / 100 * years;
        final rows = <AmortizationPreviewRow>[
          AmortizationPreviewRow(
            index: 1,
            date: _addMonths(_startDate!, n),
            principal: p,
            interest: interest,
            isDue: true,
          ),
        ];
        return AmortizationPreviewData(
          label: '到期总额',
          headlineAmount: p + interest,
          rows: rows,
          n: n,
          totalInterest: interest,
          totalPayment: p + interest,
          annualRate: annualRate,
        );
    }
  }

  double _pow(double base, int exp) {
    var r = 1.0;
    for (var i = 0; i < exp; i++) {
      r *= base;
    }
    return r;
  }

  DateTime _addMonths(DateTime d, int months) =>
      DateTime(d.year, d.month + months, d.day);

  // ===================== 提交 =====================

  Future<void> _submit() async {
    if (_counterpartyCtrl.text.trim().isEmpty) {
      AppToast.show(context, '请填写债权方', type: ToastType.warning);
      return;
    }
    if (_accountId == null) {
      AppToast.show(context, '请选择关联账户', type: ToastType.warning);
      return;
    }
    final principal = double.tryParse(_principalCtrl.text) ?? 0;
    if (_principalCtrl.text.isEmpty || principal <= 0) {
      AppToast.show(context, '请输入借款本金', type: ToastType.warning);
      return;
    }
    // 输入为百分数(如 5 表示 5%),存储为小数 0.05 —— 与预览公式同口径
    // (user-acceptance 修复:此前漏 /100,5% 被存成 500% 年化,期次利息 ×100)。
    final rate = (double.tryParse(_rateCtrl.text) ?? 0) / 100;
    if (_rateCtrl.text.isEmpty || rate == null || rate < 0) {
      AppToast.show(context, '请输入年利率', type: ToastType.warning);
      return;
    }
    if (_startDate == null) {
      AppToast.show(context, '请选择起始日期', type: ToastType.warning);
      return;
    }
    if (_dueDate == null) {
      AppToast.show(context, '请选择到期日期', type: ToastType.warning);
      return;
    }
    if (_dueDate!.isBefore(_startDate!)) {
      AppToast.show(context, '到期日期需晚于起始日期', type: ToastType.warning);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();
    _submitted = true;
    final principalCents = (principal * 100).round();
    final bloc = context.read<DebtBloc>();
    await _persistCreditCardFieldsIfNeeded();
    final e = _existing;
    if (e != null) {
      bloc.add(UpdateDebtRequested(UpdateDebtParams(
        id: e.id,
        counterparty: _counterpartyCtrl.text.trim(),
        interestRate: rate,
        version: e.version,
      )));
    } else {
      bloc.add(CreateDebtRequested(CreateDebtParams(
        accountId: _accountId!,
        counterparty: _counterpartyCtrl.text.trim(),
        interestRate: rate,
        amortizationIndex: _amortization.index,
        sourceAccountId: _disbursementAccountId,
        startDateOption: _startDate,
        dueDateOption: _dueDate,
        totalPrincipalCents: principalCents,
        subtype: _subtypeKey,
      )));
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '请输入$label' : null;

  // ===================== build =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Breakpoints.of(context) == Breakpoint.mobile
            ? Text(_isEdit ? '编辑债务' : '新建债务')
            : const SizedBox.shrink(),
        backgroundColor: AppColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: BlocListener<DebtBloc, DebtState>(
        listenWhen: (prev, curr) =>
            _submitted && curr is DebtsLoaded && prev is! DebtsLoaded,
        listener: (context, state) {
          _submitted = false;
          Navigator.of(context).pop(true);
        },
        child: BlocBuilder<DebtBloc, DebtState>(
          builder: (context, state) {
            final submitting = state is DebtSubmitting;
            return AbsorbPointer(
              absorbing: submitting,
              child: ResponsiveLayout(
                mobile: _mobileLayout(submitting),
                tablet: _wideLayout(submitting),
                desktop: _wideLayout(submitting),
              ),
            );
          },
        ),
      ),
    );
  }

  // ----- desktop / tablet：双列（表单 | 预览） -----
  Widget _wideLayout(bool submitting) {
    final isDesktop = Breakpoints.of(context) == Breakpoint.desktop;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHead(),
          const SizedBox(height: AppSpacing.md),
          Form(
            key: _formKey,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: isDesktop ? 1 : 16, child: _formColumn()),
                  const SizedBox(width: AppSpacing.md),
                  if (isDesktop)
                    SizedBox(width: 372, child: _previewColumn())
                  else
                    Expanded(flex: 10, child: _previewColumn()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- mobile：step wizard -----
  Widget _mobileLayout(bool submitting) {
    return Column(
      children: [
        _StepIndicator(current: _step),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_step == 0) ..._basicInfoFields(),
                  if (_step == 1) ..._amountRateFields(),
                  if (_step == 2) ..._dateFields(),
                  const SizedBox(height: AppSpacing.lg),
                  _stepActions(submitting),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// OD `.page-head`:serif 26px 标题(新建/编辑债务)+ sub 13px muted。
  Widget _pageHead({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEdit ? '编辑债务' : '新建债务',
          style: TextStyle(
            fontFamily: AppTypography.displayFamily,
            fontFamilyFallback: AppTypography.displayFallback,
            fontSize: compact ? 20 : 26,
            letterSpacing: -0.01,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 5),
          Text(
            _isEdit
                ? '编辑这笔债务 · 调整债权方 / 利率 / 关联账户'
                : '记录一笔借款 · 我欠别人的钱 · 自动生成还款计划',
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ],
      ],
    );
  }

  Widget _stepActions(bool submitting) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_step > 0)
          TextButton(
            key: const ValueKey('prevStepButton'),
            onPressed: submitting ? null : () => setState(() => _step--),
            child: const Text('上一步'),
          )
        else
          const SizedBox(width: 0),
        if (_step < 2)
          FilledButton(
            key: const ValueKey('nextStepButton'),
            onPressed: submitting ? null : () => setState(() => _step++),
            child: const Text('下一步'),
          )
        else
          FilledButton(
            key: const ValueKey('submitButton'),
            onPressed: submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.5),
            ),
            child: submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isEdit ? '保存' : '创建债务'),
          ),
      ],
    );
  }

  // ----- 表单列（desktop / tablet） -----
  Widget _formColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ODFormSection(
          num: '1',
          title: '基本信息',
          sub: '债权方 · 类型 · 关联账户',
          children: _basicInfoFields(),
        ),
        const SizedBox(height: 16),
        _ODFormSection(
          num: '2',
          title: '金额与利率',
          sub: '本金 · 年利率 · 摊还方法',
          children: _amountRateFields(),
        ),
        const SizedBox(height: 16),
        _ODFormSection(
          num: '3',
          title: '借款日期',
          sub: '起止日期决定还款期数',
          children: _dateFields(),
        ),
        const SizedBox(height: 16),
        _actionsCard(),
      ],
    );
  }

  /// OD `.actions`:独立白卡(surface + border + radius 14 + shadow-sm + padding
  /// 16/22),flex-end,gap 10。`.btn-ghost`(取消)+ `.btn-primary`(创建债务 gold)。
  Widget _actionsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A1C1E21), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.fg,
              backgroundColor: AppColors.surface,
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            child: const Text('取消'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            key: const ValueKey('submitButton'),
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            icon: const Icon(LucideIcons.check, size: 16),
            label: Text(_isEdit ? '保存' : '创建债务'),
          ),
        ],
      ),
    );
  }

  // ----- 字段：基本信息（Step 1） -----
  List<Widget> _basicInfoFields() {
    return [
      _ODGrid2(children: [
        _ODField(
          label: '债权方 / 借出方',
          required: true,
          hint: '向谁借的钱',
          child: TextFormField(
            key: const ValueKey('counterpartyField'),
            controller: _counterpartyCtrl,
            decoration: _odDec(hint: '如 招商银行 / 张三'),
            validator: (v) => _required(v, '债权方'),
          ),
        ),
        _ODField(
          label: _isCreditCard ? '关联信用卡账户' : '关联账户',
          required: true,
          hint: '债务挂载的 Loan 账户',
          child: DropdownButtonFormField<String>(
            key: const ValueKey('accountDropdown'),
            value: _accountId,
            isExpanded: true,
            decoration: _odDec(
                hint: _accountsLoading
                    ? '加载中…'
                    : (_isCreditCard ? '选择信用卡账户' : '选择 Loan 账户')),
            items: [
              for (final a in _visibleAccounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: _onAccountChanged,
            validator: (v) => v == null || v.isEmpty ? '请选择关联账户' : null,
          ),
        ),
        _ODField(
          label: '到账账户(可选)',
          hint: '借款现金自动入账的资产账户',
          child: DropdownButtonFormField<String>(
            key: const ValueKey('disbursementDropdown'),
            value: _disbursementAccountId,
            isExpanded: true,
            decoration: _odDec(hint: '选择资产账户(不选则不自动入账)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('不自动入账')),
              for (final a in _assetAccounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _disbursementAccountId = v),
          ),
        ),
      ]),
      // 债务类型(5 卡):OD .radio-row.c5。icon + label(无 desc,对齐 OD 类型卡)。
      _ODField(
        label: '债务类型',
        required: true,
        child: _ResponsiveRadioRow(
          children: [
            for (final key in DebtSubtypes.all)
              _RadioCard(
                key: ValueKey('debtType-$key'),
                icon: _debtTypeIcon(key),
                label: DebtSubtypes.labels[key]!,
                selected: _subtypeKey == key,
                // 编辑模式:UpdateDebtParams 不携带 subtype,chips 只读显示。
                onTap: _isEdit
                    ? null
                    : () => setState(() {
                          _subtypeKey = key;
                          _refillCreditCardFields();
                        }),
              ),
          ],
        ),
      ),
      if (_isEdit)
        const Padding(
          key: ValueKey('subtypeReadonlyHint'),
          padding: EdgeInsets.only(top: 4),
          child: Text(
            '编辑模式不可更改债务类型',
            style: TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ),
      // 信用卡子类型 + 无 credit_card 账户 → 提示去账户管理创建。
      if (_isCreditCard && _visibleAccounts.isEmpty && !_accountsLoading)
        Padding(
          key: const ValueKey('createCreditCardHint'),
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: GestureDetector(
            onTap: _goCreateCreditCardAccount,
            child: const Text(
              '尚未找到信用卡账户，点此去账户管理创建',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  decoration: TextDecoration.underline),
            ),
          ),
        ),
      // 信用卡信息区(仅 subtype == DebtSubtypes.creditCard)。
      if (_isCreditCard) ...[
        const SizedBox(height: AppSpacing.md),
        ..._creditCardFields(),
      ],
    ];
  }

  // ----- 字段：信用卡信息（账单日 / 还款日 / 额度 / 年费） -----
  List<Widget> _creditCardFields() {
    return [
      const Text('💳 信用卡信息',
          key: ValueKey('creditCardSection'),
          style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
      const SizedBox(height: AppSpacing.sm),
      _ODGrid2(children: [
        TextFormField(
          key: const ValueKey('ccBillingDayField'),
          controller: _ccBillingDayCtrl,
          decoration: _odDec(hint: '账单日 1-31'),
          keyboardType: TextInputType.number,
        ),
        TextFormField(
          key: const ValueKey('ccRepaymentDayField'),
          controller: _ccRepaymentDayCtrl,
          decoration: _odDec(hint: '还款日 1-31'),
          keyboardType: TextInputType.number,
        ),
      ]),
      const SizedBox(height: AppSpacing.sm),
      _ODGrid2(children: [
        TextFormField(
          key: const ValueKey('ccLimitField'),
          controller: _ccLimitCtrl,
          decoration: _odDec(prefix: '${currencySymbol('CNY')} ', hint: '信用额度 0.00'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        TextFormField(
          key: const ValueKey('ccAnnualFeeField'),
          controller: _ccAnnualFeeCtrl,
          decoration: _odDec(prefix: '${currencySymbol('CNY')} ', hint: '年费 0.00'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ]),
    ];
  }

  // ----- 字段：金额利率（Step 2） -----
  List<Widget> _amountRateFields() {
    return [
      _ODGrid2(children: [
        _ODField(
          label: '借款本金',
          required: true,
          child: TextFormField(
            key: const ValueKey('principalField'),
            controller: _principalCtrl,
            decoration:
                _odDec(prefix: '${currencySymbol('CNY')} ', hint: '0.00'),
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.fg,
                fontFeatures: AppTypography.tabularFigures),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => _required(v, '借款本金'),
          ),
        ),
        _ODField(
          label: '年利率',
          required: true,
          hint: '亲友无息借款可填 0',
          child: TextFormField(
            key: const ValueKey('rateField'),
            controller: _rateCtrl,
            decoration: _odDec(suffix: '%', hint: '0.0'),
            style: const TextStyle(
                fontSize: 14,
                color: AppColors.fg,
                fontFeatures: AppTypography.tabularFigures),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => _required(v, '年利率'),
          ),
        ),
      ]),
      // 摊还方法(3 卡 + desc):OD .radio-row.c3。
      _ODField(
        label: '摊还方法',
        required: true,
        child: _ResponsiveRadioRow(
          children: [
            for (final m in _amortizations)
              _RadioCard(
                key: ValueKey('amortization-${m.name}'),
                icon: _amortizationIcon(m),
                label: _amortizationLabel(m),
                desc: _amortizationDesc(m),
                selected: _amortization == m,
                onTap: () => setState(() => _amortization = m),
              ),
          ],
        ),
      ),
    ];
  }

  // ----- 字段：日期（Step 3） -----
  List<Widget> _dateFields() {
    final periods = _monthsBetween(_startDate, _dueDate);
    return [
      _ODGrid2(children: [
        _ODField(
          label: '起始日期',
          required: true,
          child: _ODDateField(
            key: const ValueKey('startDatePicker'),
            value: _startDate,
            onChanged: (d) => setState(() => _startDate = d),
          ),
        ),
        _ODField(
          label: '到期日期',
          required: true,
          hint: periods > 0 ? '期数 $periods 期（按月）' : null,
          child: _ODDateField(
            key: const ValueKey('dueDatePicker'),
            value: _dueDate,
            onChanged: (d) => setState(() => _dueDate = d),
          ),
        ),
      ]),
    ];
  }

  // ----- 预览列 -----
  Widget _previewColumn() {
    final preview = _computePreview();
    final subtypeLabel = DebtSubtypes.labels[_subtypeKey] ?? '';
    return AmortizationPreview(
      title: '$_counterpartyOrDefault · $subtypeLabel',
      sectionLabel: 'LIVE PREVIEW · 还款计划预览',
      emptyHint: '填写借款本金与起止日期后\n实时生成还款计划',
      footNote: '前 5 期预览 · 实际以放款为准',
      preview: preview,
    );
  }

  String get _counterpartyOrDefault =>
      _counterpartyCtrl.text.trim().isEmpty
          ? '未命名'
          : _counterpartyCtrl.text.trim();
}

// ===================== 私有 widgets =====================

/// mobile step wizard 顶部进度指示（3 圆点 + 连线）。
class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.current});
  final int current;

  static const _labels = ['基本信息', '金额利率', '日期'];

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('stepIndicator'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            _dot(i == current, i < current, _labels[i]),
            if (i < 2)
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Divider(color: AppColors.border, thickness: 1),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _dot(bool active, bool done, String label) {
    final color = active
        ? AppColors.accent
        : (done ? AppColors.positive : AppColors.border);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: active ? AppColors.accent : AppColors.surface,
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
              : Text(
                  '${_labels.indexOf(label) + 1}',
                  style: TextStyle(
                    color: active ? Colors.white : AppColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              color: active ? AppColors.fg : AppColors.muted,
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            )),
      ],
    );
  }
}

/// 单选卡(债务类型 5 / 摊还方法 3)。对齐 OD .radio:32px icon tile(选中金实心)
/// + label + 可选 desc。复用 TypeTabs 金选中态视觉。
/// [onTap] == null → 禁用态(只读显示,编辑模式 subtype 不可更改)。
class _RadioCard extends StatelessWidget {
  const _RadioCard({
    super.key,
    required this.icon,
    required this.label,
    this.desc,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String? desc;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final cardBg = selected ? const Color(0xFFFBF7EF) : AppColors.surface;
    final cardBorder = selected ? AppColors.accent : AppColors.border;
    final tileBg = selected ? AppColors.accent : AppColors.accentSoft;
    final tileFg = selected ? Colors.white : AppColors.accentHover;
    final labelColor = disabled
        ? AppColors.muted.withValues(alpha: 0.7)
        : (selected ? AppColors.accentHover : AppColors.fg);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: cardBorder, width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.12),
                    blurRadius: 0,
                    spreadRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tileBg,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 17, color: tileFg),
            ),
            const SizedBox(height: 7),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                )),
            if (desc != null) ...[
              const SizedBox(height: 2),
              Text(desc!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 10.5,
                    height: 1.3,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

/// OD `.field`:label 上方块标签(12.5 w600 fg + req 红 `*`)+ input + 可选 hint。
class _ODField extends StatelessWidget {
  const _ODField({
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
  });

  final String label;
  final Widget child;
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.fg,
              ),
              children: [
                TextSpan(text: label),
                if (required)
                  const TextSpan(
                      text: ' *', style: TextStyle(color: AppColors.negative)),
              ],
            ),
          ),
        ),
        child,
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(hint!,
                style: const TextStyle(
                    color: AppColors.muted, fontSize: 11.5, height: 1.4)),
          ),
      ],
    );
  }
}

/// OD `.input`/`.select` InputDecoration 工厂。
InputDecoration _odDec({
  String? hint,
  String? prefix,
  String? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
    prefixText: prefix,
    prefixStyle: const TextStyle(
        color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 14),
    suffixText: suffix,
    suffixStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    filled: true,
    fillColor: AppColors.surface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.accent, width: 1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.negative, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.negative, width: 1),
    ),
    errorStyle: const TextStyle(color: AppColors.negative, fontSize: 11.5),
  );
}

/// OD `.input[type=date]`:label 由 _ODField 提供,本控件仅渲染带边框的日期行。
class _ODDateField extends StatelessWidget {
  const _ODDateField({super.key, required this.value, required this.onChanged});

  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final has = value != null;
    final text = has
        ? '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}'
        : '请选择日期';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: has ? AppColors.fg : AppColors.muted,
                    fontSize: 14,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
              const Icon(LucideIcons.calendar, size: 16, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// OD `.grid-2c`(2 等宽列 gap 14)。mobile → Column 垂直堆叠。
class _ODGrid2 extends StatelessWidget {
  const _ODGrid2({required this.children, this.spacing = 14});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (children.length <= 1) return children.first;
    if (Breakpoints.of(context) == Breakpoint.mobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const SizedBox(height: 18),
          ],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) SizedBox(width: spacing),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// OD `.radio-row.c4`/`.c3` 等宽列(gap 9)。mobile → Wrap(自然宽 + 自动换行)。
/// 不用 LayoutBuilder —— wide layout 用 IntrinsicHeight 包 Row(preview Stack
/// 需 bounded 高度),LayoutBuilder 在 IntrinsicHeight 下会抛异常。
class _ResponsiveRadioRow extends StatelessWidget {
  const _ResponsiveRadioRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = 9.0;
    if (Breakpoints.of(context) == Breakpoint.mobile) {
      return Wrap(spacing: gap, runSpacing: gap, children: children);
    }
    final n = children.length;
    return Row(
      children: [
        for (var i = 0; i < n; i++) ...[
          if (i > 0) const SizedBox(width: gap),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

/// OD `.sec` + `.sec-head` 分区卡(对齐 receivable_form _ODFormSection)。
class _ODFormSection extends StatelessWidget {
  const _ODFormSection({
    required this.num,
    required this.title,
    required this.sub,
    required this.children,
    this.fieldSpacing = 18,
  });

  final String num;
  final String title;
  final String sub;
  final List<Widget> children;
  final double fieldSpacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder,
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A1C1E21), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 14),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    num,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback)),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(sub,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) SizedBox(height: fieldSpacing),
          ],
        ],
      ),
    );
  }
}

// ===================== 纯函数 helpers =====================

String _amortizationLabel(AmortizationMethod m) {
  switch (m) {
    case AmortizationMethod.equalPrincipalInterest:
      return '等额本息';
    case AmortizationMethod.equalPrincipal:
      return '等额本金';
    case AmortizationMethod.lumpSum:
      return '一次性还本付息';
  }
}

/// 摊还方法 icon(对齐 OD .radio svg:趋势上升 / 柱状递减 / 圆环)。
IconData _amortizationIcon(AmortizationMethod m) {
  switch (m) {
    case AmortizationMethod.equalPrincipalInterest:
      return LucideIcons.trendingUp;
    case AmortizationMethod.equalPrincipal:
      return LucideIcons.barChart3;
    case AmortizationMethod.lumpSum:
      return LucideIcons.circle;
  }
}

/// 摊还方法 desc(对齐 OD .radio .rd 文案)。
String _amortizationDesc(AmortizationMethod m) {
  switch (m) {
    case AmortizationMethod.equalPrincipalInterest:
      return '月供恒定 前期利息多';
    case AmortizationMethod.equalPrincipal:
      return '月供递减 总利息更少';
    case AmortizationMethod.lumpSum:
      return '到期还本付息 无月供';
  }
}

/// 债务类型 icon(对齐 OD debt-form.html .radio svg:home/car/creditCard/users/help)。
IconData _debtTypeIcon(String key) {
  switch (key) {
    case DebtSubtypes.mortgage:
      return LucideIcons.home;
    case DebtSubtypes.autoLoan:
      return LucideIcons.car;
    case DebtSubtypes.creditCard:
      return LucideIcons.creditCard;
    case DebtSubtypes.family:
      return LucideIcons.users;
    case DebtSubtypes.other:
    default:
      return LucideIcons.helpCircle;
  }
}
