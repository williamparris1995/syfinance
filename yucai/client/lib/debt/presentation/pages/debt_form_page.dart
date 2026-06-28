import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/form_section.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 债务表单页（创建 + 编辑模式）。对齐 OD 原型 debt-form.html / tablet / mobile：
///
/// 提交 → dispatch [CreateDebtRequested] / [UpdateDebtRequested] → 成功后 pop 回 debts_page。
/// DebtBloc 通过 router provide（Task 9）；本页 `context.read<DebtBloc>()`。
///
/// - [existing] == null：创建模式（dispatch CreateDebtRequested）。
/// - [existing] != null：编辑模式（预填字段，dispatch UpdateDebtRequested）。
///   对齐 `account_form_page.dart` 的 existing edit 模式。
///
/// 可选 [initialStartDate] / [initialDueDate] / [initialAccountId] 供测试
/// 直接 seed 表单状态，避免在 widget test 里驱动 showDatePicker（仅创建模式生效）。
class DebtFormPage extends StatefulWidget {
  const DebtFormPage({
    super.key,
    this.existing,
    this.initialStartDate,
    this.initialDueDate,
    this.initialAccountId,
  });

  /// 编辑模式传入的现有 Debt；null = 创建模式。
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
  // 字段来自关联的 credit_card account；用户编辑后 _ccDirty 置 true，
  // 提交时回写 AccountRepository.update。
  final _ccBillingDayCtrl = TextEditingController();
  final _ccRepaymentDayCtrl = TextEditingController();
  final _ccLimitCtrl = TextEditingController();
  final _ccAnnualFeeCtrl = TextEditingController();
  bool _ccDirty = false;

  /// 债务子类型 key（DebtSubtypes.mortgage / autoLoan / creditCard / family /
  /// other）。存 **key**（非中文 label）—— 判断用 const，UI 显示 labels[key]。
  String _subtypeKey = DebtSubtypes.mortgage;
  AmortizationMethod _amortization = AmortizationMethod.equalPrincipalInterest;

  /// 关联 loan 账户。null = 未选。
  String? _accountId;
  DateTime? _startDate;
  DateTime? _dueDate;

  /// 全部 liability 账户（含 credit_card / loan / 其他负债）。
  /// 显示时按 subtype 过滤（_visibleAccounts）。
  List<Account> _accounts = const [];
  bool _accountsLoading = true;

  /// mobile step wizard 当前步（0/1/2）。
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
      // 编辑模式：预填所有可编辑字段（counterparty / 本金 / 利率 / 摊还 / 日期 /
      // 关联账户 / 子类型）。对齐 account_form_page 的 existing 预填。UpdateDebtParams
      // 仅回传 counterparty + interestRate + version，其余字段仅供预览一致性展示。
      _counterpartyCtrl.text = e.counterparty;
      _principalCtrl.text =
          (e.totalPrincipalCents / 100).toStringAsFixed(2);
      _rateCtrl.text = e.interestRate.toString();
      _amortization = e.amortization;
      _startDate = e.startDate;
      _dueDate = e.dueDate;
      _accountId = e.accountId;
      // 子类型 key 预填（空 → mortgage 默认，避免 const 判断落空）。
      _subtypeKey = e.subtype.isEmpty ? DebtSubtypes.mortgage : e.subtype;
    } else {
      // 创建模式：测试 seed 参数。
      _startDate = widget.initialStartDate;
      _dueDate = widget.initialDueDate;
      _accountId = widget.initialAccountId;
    }
    _loadAccounts();
    // 输入变化即重算预览（principal/rate/dates/amortization 都是 setState 触发）。
    _principalCtrl.addListener(() => setState(() {}));
    _rateCtrl.addListener(() => setState(() {}));
    // 信用卡字段编辑 → 标脏，提交时回写 account。
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
    // 对齐 transactions_page._loadAccounts：getIt<AccountRepository>()，
    // 避免依赖 router provide。
    try {
      final repo = GetIt.instance<AccountRepository>();
      final result = await repo.list();
      final list = result.fold((_) => const <Account>[], (l) => l);
      // 仅关联 loan / 其他负债 账户（债务挂载的负债侧账户）。
      if (!mounted) return;
      setState(() {
        _accounts =
            list.where((a) => a.accountType == AccountType.liability).toList();
        _accountsLoading = false;
        // 账户加载后若已有选中账户（编辑模式 / 测试 seed），回填信用卡字段。
        _refillCreditCardFields();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _accountsLoading = false);
    }
  }

  // ===================== 子类型 / 信用卡区 helpers =====================

  /// 当前是否信用卡子类型（const 判断，禁裸字符串）。
  bool get _isCreditCard => _subtypeKey == DebtSubtypes.creditCard;

  /// 按 subtype 过滤的可选账户。信用卡子类型 → 仅 credit_card category；
  /// 其他子类型 → 全部 liability（loan / 其他负债 / 信用卡均可挂载）。
  List<Account> get _visibleAccounts => _isCreditCard
      ? _accounts
          .where((a) => a.category == AccountCategory.creditCard)
          .toList()
      : _accounts;

  /// 当前选中的账户（可能不在 _visibleAccounts 内 —— 如编辑模式旧账户）。
  Account? get _selectedAccount =>
      _accounts.where((a) => a.id == _accountId).cast<Account?>().firstWhere(
            (_) => true,
            orElse: () => null,
          );

  /// 用选中账户的信用卡字段回填 4 个 controller（不触发 _ccDirty，因为这是
  /// 程序化回填而非用户编辑）。账户切换 / 加载完成时调用。
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
    // 程序化回填不算用户编辑 —— 复位脏标记（listener 已先触发）。
    _ccDirty = false;
  }

  /// 账户下拉 onChange：写回 _accountId + 回填信用卡字段。
  void _onAccountChanged(String? v) {
    setState(() {
      _accountId = v;
      _refillCreditCardFields();
    });
  }

  /// 提交时若信用卡字段有变 → 回写关联 credit_card account（best-effort）。
  /// 失败仅 log，不阻塞债务创建（对齐 data 层 getIt 模式）。
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
    } catch (_) {
      // best-effort：账户更新失败不阻断债务提交。
    }
    _ccDirty = false;
  }

  /// 「请先创建信用卡账户」提示 → 跳转 AccountFormPage（对齐 router 的
  /// BlocProvider<AccountBloc>(getIt) 模式，见 router.dart /accounts）。
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
    // 返回后重新拉账户列表（用户可能刚创建了信用卡账户）。
    if (!mounted) return;
    setState(() => _accountsLoading = true);
    _loadAccounts();
  }

  // ===================== 摊还预览（client-side） =====================

  /// 月数 = (due - start) 的整月差。due ≤ start → 0。
  int _monthsBetween(DateTime? a, DateTime? b) {
    if (a == null || b == null) return 0;
    final m = (b.year - a.year) * 12 + (b.month - a.month);
    return m <= 0 ? 0 : m;
  }

  /// 摊还预览数据。P≤0 或日期不全 → null（空态）。
  _Preview? _computePreview() {
    final p = double.tryParse(_principalCtrl.text) ?? 0;
    final annualRate = double.tryParse(_rateCtrl.text) ?? 0;
    final n = _monthsBetween(_startDate, _dueDate);
    if (p <= 0 || _startDate == null || _dueDate == null || n <= 0) return null;

    final r = annualRate / 100 / 12; // 月利率
    switch (_amortization) {
      case AmortizationMethod.equalPrincipalInterest:
        final pow = _pow(1 + r, n);
        final monthly = r > 0 ? p * r * pow / (pow - 1) : p / n;
        final rows = <_PreviewRow>[];
        var bal = p;
        for (var i = 1; i <= (n < 5 ? n : 5); i++) {
          final interest = bal * r;
          final principal = monthly - interest;
          bal -= principal;
          rows.add(_PreviewRow(
            index: i,
            date: _addMonths(_startDate!, i - 1),
            principal: principal,
            interest: interest,
          ));
        }
        final totalInterestAll = monthly * n - p;
        return _Preview(
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
        final rows = <_PreviewRow>[];
        var bal = p;
        for (var i = 1; i <= (n < 5 ? n : 5); i++) {
          final interest = bal * r;
          bal -= monthlyPrincipal;
          rows.add(_PreviewRow(
            index: i,
            date: _addMonths(_startDate!, i - 1),
            principal: monthlyPrincipal,
            interest: interest,
          ));
        }
        // 总利息：遍历全期（n 可能较大，但 N≤数百万 O(n) 可接受）。
        var b = p;
        var totalInterest = 0.0;
        for (var i = 0; i < n; i++) {
          totalInterest += b * r;
          b -= monthlyPrincipal;
        }
        final firstMonthly = monthlyPrincipal + p * r;
        return _Preview(
          label: '首月供',
          headlineAmount: firstMonthly,
          rows: rows,
          n: n,
          totalInterest: totalInterest,
          totalPayment: p + totalInterest,
          annualRate: annualRate,
        );
      case AmortizationMethod.lumpSum:
        // 到期一次性还本付息。
        final years = n / 12;
        final interest = p * annualRate / 100 * years;
        final rows = <_PreviewRow>[];
        // 1 行（到期）。
        rows.add(_PreviewRow(
          index: 1,
          date: _addMonths(_startDate!, n),
          principal: p,
          interest: interest,
          isDue: true,
        ));
        return _Preview(
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

  DateTime _addMonths(DateTime d, int months) {
    return DateTime(d.year, d.month + months, d.day);
  }

  // ===================== 提交 =====================

  Future<void> _submit() async {
    // 显式校验必要字段并 toast 提示（避免空 submit 无反应）。
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
    final rate = double.tryParse(_rateCtrl.text);
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
    // 在 await 前捕获 bloc，避免跨 async gap 用 BuildContext（lint）。
    final bloc = context.read<DebtBloc>();
    // 信用卡字段回写 account（best-effort，先于债务提交）。
    await _persistCreditCardFieldsIfNeeded();
    final e = _existing;
    if (e != null) {
      // 编辑模式：UpdateDebtParams 仅含 id / counterparty / interestRate / version
      // （对齐 debt_event.dart 签名 —— 后端暂不支持改本金/摊还/日期）。
      bloc.add(UpdateDebtRequested(UpdateDebtParams(
            id: e.id,
            counterparty: _counterpartyCtrl.text.trim(),
            interestRate: rate,
            version: e.version,
          )));
    } else {
      // 创建模式：CreateDebtParams 带 subtype（_subtypeKey 存的是 const key）。
      bloc.add(CreateDebtRequested(CreateDebtParams(
            accountId: _accountId!,
            counterparty: _counterpartyCtrl.text.trim(),
            interestRate: rate,
            amortizationIndex: _amortization.index,
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
        title: Text(_isEdit ? '编辑债务' : '新建债务'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      child: Form(
        key: _formKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 16, child: _formColumn()),
            const SizedBox(width: AppSpacing.lg),
            Expanded(flex: 10, child: _previewColumn()),
          ],
        ),
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
            child: submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(_isEdit ? '保存修改' : '确认创建'),
          ),
      ],
    );
  }

  // ----- 表单列（desktop / tablet） -----
  Widget _formColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FormSection(title: '1 · 基本信息', children: _basicInfoFields()),
        const SizedBox(height: AppSpacing.lg),
        FormSection(title: '2 · 金额与利率', children: _amountRateFields()),
        const SizedBox(height: AppSpacing.lg),
        FormSection(title: '3 · 借款日期', children: _dateFields()),
        const SizedBox(height: AppSpacing.xl),
        FormActions(
          submitLabel: _isEdit ? '保存修改' : '确认创建',
          submitting: false,
          onSubmit: _submit,
          onCancel: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  // ----- 字段：基本信息（Step 1） -----
  List<Widget> _basicInfoFields() {
    return [
      TextFormField(
        key: const ValueKey('counterpartyField'),
        controller: _counterpartyCtrl,
        decoration: const InputDecoration(
          labelText: '债权方 / 借出方',
          hintText: '如 招商银行 / 张三',
        ),
        validator: (v) => _required(v, '债权方'),
      ),
      const SizedBox(height: AppSpacing.md),
      // 债务子类型（5 卡）—— 选项来自 DebtSubtypes.all（const），禁硬编码字符串。
      // ValueKey / selected / onTap 全部基于 key（_subtypeKey 存 key）。
      const Text('债务类型',
          style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final key in DebtSubtypes.all)
            _RadioChip(
              key: ValueKey('debtType-$key'),
              label: DebtSubtypes.labels[key]!,
              selected: _subtypeKey == key,
              onTap: () => setState(() {
                _subtypeKey = key;
                // 切到/切离信用卡时复位信用卡字段脏标记与回填
                //（_visibleAccounts 随 _isCreditCard 变化，若当前选中账户
                // 不再可见，_accountId 保留 —— 编辑模式旧账户仍可读字段）。
                _refillCreditCardFields();
              }),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      // 关联账户下拉：信用卡子类型 → 仅 credit_card；其他 → 全部 liability。
      DropdownButtonFormField<String>(
        key: const ValueKey('accountDropdown'),
        decoration: InputDecoration(
            labelText: _isCreditCard ? '关联信用卡账户' : '关联账户'),
        value: _accountId,
        items: [
          for (final a in _visibleAccounts)
            DropdownMenuItem(value: a.id, child: Text(a.name)),
        ],
        hint: Text(_accountsLoading
            ? '加载中…'
            : (_isCreditCard ? '选择信用卡账户' : '选择 Loan 账户')),
        onChanged: _onAccountChanged,
        validator: (v) => v == null || v.isEmpty ? '请选择关联账户' : null,
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
      // 信用卡信息区（仅 subtype == DebtSubtypes.creditCard）。
      if (_isCreditCard) ...[
        const SizedBox(height: AppSpacing.lg),
        ..._creditCardFields(),
      ],
    ];
  }

  // ----- 字段：信用卡信息（账单日 / 还款日 / 额度 / 年费） -----
  // 字段来自关联 credit_card account，TextEditingController 预填 + 可编辑。
  // 提交时若 _ccDirty → AccountRepository.update 回写。
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
      FormRow(children: [
        TextFormField(
          key: const ValueKey('ccBillingDayField'),
          controller: _ccBillingDayCtrl,
          decoration: const InputDecoration(
            labelText: '账单日',
            hintText: '1-31',
          ),
          keyboardType: TextInputType.number,
        ),
        TextFormField(
          key: const ValueKey('ccRepaymentDayField'),
          controller: _ccRepaymentDayCtrl,
          decoration: const InputDecoration(
            labelText: '还款日',
            hintText: '1-31',
          ),
          keyboardType: TextInputType.number,
        ),
      ]),
      const SizedBox(height: AppSpacing.sm),
      FormRow(children: [
        TextFormField(
          key: const ValueKey('ccLimitField'),
          controller: _ccLimitCtrl,
          decoration: const InputDecoration(
            labelText: '信用额度',
            prefixText: '¥ ',
            hintText: '0.00',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        TextFormField(
          key: const ValueKey('ccAnnualFeeField'),
          controller: _ccAnnualFeeCtrl,
          decoration: const InputDecoration(
            labelText: '年费',
            prefixText: '¥ ',
            hintText: '0.00',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ]),
    ];
  }

  // ----- 字段：金额利率（Step 2） -----
  List<Widget> _amountRateFields() {
    return [
      FormRow(children: [
        TextFormField(
          key: const ValueKey('principalField'),
          controller: _principalCtrl,
          decoration: const InputDecoration(
            labelText: '借款本金',
            prefixText: '¥ ',
            hintText: '0.00',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) => _required(v, '借款本金'),
        ),
        TextFormField(
          key: const ValueKey('rateField'),
          controller: _rateCtrl,
          decoration: const InputDecoration(
            labelText: '年利率',
            suffixText: '%',
            hintText: '0.0',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) => _required(v, '年利率'),
        ),
      ]),
      const SizedBox(height: AppSpacing.md),
      const Text('摊还方法',
          style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final m in _amortizations)
            _RadioChip(
              key: ValueKey('amortization-${m.name}'),
              label: _amortizationLabel(m),
              selected: _amortization == m,
              onTap: () => setState(() => _amortization = m),
            ),
        ],
      ),
    ];
  }

  // ----- 字段：日期（Step 3） -----
  List<Widget> _dateFields() {
    return [
      FormRow(children: [
        _DateField(
          key: const ValueKey('startDatePicker'),
          label: '起始日期',
          value: _startDate,
          onChanged: (d) => setState(() => _startDate = d),
        ),
        _DateField(
          key: const ValueKey('dueDatePicker'),
          label: '到期日期',
          value: _dueDate,
          onChanged: (d) => setState(() => _dueDate = d),
        ),
      ]),
    ];
  }

  // ----- 预览列 -----
  Widget _previewColumn() {
    final preview = _computePreview();
    // 预览标题展示子类型 label（中文）—— _subtypeKey 存 key，labels[key] 取显示。
    final subtypeLabel = DebtSubtypes.labels[_subtypeKey] ?? '';
    return _AmortizationPreview(
      title: '$_counterpartyOrDefault · $subtypeLabel',
      preview: preview,
    );
  }

  String get _counterpartyOrDefault =>
      _counterpartyCtrl.text.trim().isEmpty
          ? '未命名'
          : _counterpartyCtrl.text.trim();
}

// ===================== 私有 widgets =====================

/// 摊还预览数据。
class _Preview {
  const _Preview({
    required this.label,
    required this.headlineAmount,
    required this.rows,
    required this.n,
    required this.totalInterest,
    required this.totalPayment,
    required this.annualRate,
  });
  final String label; // 月供 / 首月供 / 到期总额
  final double headlineAmount;
  final List<_PreviewRow> rows; // 前 5 期（lumpSum = 1 期）
  final int n; // 总期数
  final double totalInterest;
  final double totalPayment;
  final double annualRate;
}

class _PreviewRow {
  const _PreviewRow({
    required this.index,
    required this.date,
    required this.principal,
    required this.interest,
    this.isDue = false,
  });
  final int index;
  final DateTime date;
  final double principal;
  final double interest;
  final bool isDue;
}

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
              ? const Icon(Icons.check, size: 14, color: Colors.white)
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

/// 单选 chip（债务类型 / 摊还方法）。复用 TypeTabs 视觉（金选中态）。
class _RadioChip extends StatelessWidget {
  const _RadioChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? AppColors.accentSoft : AppColors.surface;
    final fg = selected ? AppColors.accentHover : AppColors.muted;
    final border = selected ? AppColors.accent : AppColors.border;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: AppRadius.smBorder,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// 日期字段（点击弹 showDatePicker）。不继承 DatePickerInput 是为了加 ValueKey
/// 与 onChanged 回写 state（DatePickerInput 用 onSaved，需 form.save 触发）。
class _DateField extends StatelessWidget {
  const _DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
      ),
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
        child: Text(
          value == null
              ? '请选择日期'
              : '${value!.year}-${value!.month.toString().padLeft(2, '0')}-${value!.day.toString().padLeft(2, '0')}',
          style: TextStyle(
            color: value == null ? AppColors.muted : AppColors.fg,
          ),
        ),
      ),
    );
  }
}

/// 深色实时预览卡（对齐 OD .preview）。preview == null → 空态。
class _AmortizationPreview extends StatelessWidget {
  const _AmortizationPreview({required this.title, required this.preview});

  final String title;
  final _Preview? preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('amortizationPreview'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F2228), Color(0xFF262A31)],
        ),
        borderRadius: AppRadius.lgBorder,
        boxShadow: [
          BoxShadow(
              color: Color(0x17000000), blurRadius: 34, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          if (preview == null) _empty() else _table(preview!),
          _foot(),
        ],
      ),
    );
  }

  Widget _header() {
    final p = preview;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x12FFFFFF))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LIVE PREVIEW · 还款计划预览',
              style: TextStyle(
                  color: Color(0xFF9AA0A8),
                  fontSize: 10.5,
                  letterSpacing: 2,
                  fontFamily: AppTypography.displayFamily)),
          const SizedBox(height: 7),
          Text(title,
              key: const ValueKey('previewTitle'),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  fontFamily: AppTypography.displayFamily)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(p == null ? '' : p.label,
                  style: const TextStyle(
                      color: Color(0xFF9AA0A8), fontSize: 11.5)),
              const SizedBox(width: 8),
              Text(
                p == null ? '—' : _fmtYuan(p.headlineAmount),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.01,
                    fontFeatures: AppTypography.tabularFigures),
              ),
            ],
          ),
          if (p != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 7,
              runSpacing: 4,
              children: [
                _tag('期数 ${p.n} 期'),
                _tag('总利息 ${_fmtYuan(p.totalInterest)}'),
                _tag('总还款 ${_fmtYuan(p.totalPayment)}'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tag(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0x12FFFFFF),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFC9CCD2),
                fontSize: 11,
                fontFeatures: AppTypography.tabularFigures)),
      );

  Widget _table(_Preview p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          // header row
          const Padding(
            padding:
                EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 8),
            child: Row(
              children: [
                Expanded(
                    flex: 4,
                    child: Text('期次 / 还款日',
                        style: TextStyle(
                            color: Color(0xFF6F747C),
                            fontSize: 10,
                            letterSpacing: 1,
                            fontFeatures: AppTypography.tabularFigures))),
                Expanded(
                    flex: 5,
                    child: Text('本金 / 利息',
                        style: TextStyle(
                            color: Color(0xFF6F747C),
                            fontSize: 10,
                            letterSpacing: 1))),
                Expanded(
                    flex: 4,
                    child: Text('合计',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                            color: Color(0xFF6F747C),
                            fontSize: 10,
                            letterSpacing: 1))),
              ],
            ),
          ),
          for (final row in p.rows) _row(row),
        ],
      ),
    );
  }

  Widget _row(_PreviewRow r) {
    final idx = r.isDue ? '到期' : r.index.toString().padLeft(2, '0');
    final total = r.principal + r.interest;
    final date =
        '${r.date.year}-${r.date.month.toString().padLeft(2, '0')}-${r.date.day.toString().padLeft(2, '0')}';
    return Container(
      key: ValueKey('previewRow-${r.index.toString().padLeft(2, '0')}'),
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0x0DFFFFFF)))),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(idx,
                    style: const TextStyle(
                        color: Color(0xFF6F747C),
                        fontSize: 11,
                        fontFeatures: AppTypography.tabularFigures)),
                Text(date,
                    style: const TextStyle(
                        color: Color(0xFF9AA0A8), fontSize: 10)),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmtYuan(r.principal),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        fontFeatures: AppTypography.tabularFigures)),
                Text('利息 ${_fmtYuan(r.interest)}',
                    style: const TextStyle(
                        color: Color(0xFF9AA0A8), fontSize: 10.5)),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(_fmtYuan(total),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    color: Color(0xFFE8C894),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFeatures: AppTypography.tabularFigures)),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return const Padding(
      key: ValueKey('previewEmpty'),
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.xl),
      child: Center(
        child: Text(
          '填写本金与起止日期后\n实时生成还款计划',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF7A7E85), fontSize: 12.5, height: 1.6),
        ),
      ),
    );
  }

  Widget _foot() {
    final p = preview;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg, vertical: AppSpacing.sm + 2),
      decoration: const BoxDecoration(
          border:
              Border(top: BorderSide(color: Color(0x12FFFFFF)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('前 5 期预览 · 实际以放款为准',
              style: TextStyle(color: Color(0xFF9AA0A8), fontSize: 11.5)),
          Text('年化 ${p == null ? '—' : '${p.annualRate.toStringAsFixed(1)}%'}',
              style: const TextStyle(
                  color: Color(0xFFE8C894),
                  fontSize: 11.5,
                  fontFeatures: AppTypography.tabularFigures)),
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
      return '一次性';
  }
}

/// 元（double）→ ¥ + 千分位 + 0 小数（对齐 OD fmt：Math.round + toLocaleString）。
String _fmtYuan(double v) {
  final n = v.round();
  final sign = n < 0 ? '-' : '';
  final abs = n.abs();
  final s = abs.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return '$sign¥$buf';
}
