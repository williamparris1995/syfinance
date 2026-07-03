import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/form_section.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 债权表单页（创建 + 编辑模式）。结构对齐 [DebtFormPage]，语义换成
/// BorrowedOut（别人欠我 / 应收）。对齐 OD 原型 receivable-form.html / tablet /
/// mobile。
///
/// 与 [DebtFormPage] 的关键差异（这是本页存在的全部理由）：
///  1. **type 固定 `DebtType.borrowedOut`**：不渲染债务方向选择器；提交时
///     `CreateDebtParams(type: DebtType.borrowedOut)`（[DebtFormPage] 走默认
///     borrowedIn）。编辑模式同样保持 borrowedOut（债权编辑仍是债权）。
///  2. **关联账户 = asset 应收**（category `AccountCategory.otherAsset`）：
///     收回的本息计入此资产账户。`[DebtFormPage]` 关联 liability/loan 账户
///     （我欠别人的负债侧）；本页用 `category == otherAsset` 过滤（应收/其他资产）。
///  3. **Label 收款语义**：债务人 / 借出本金 / 收款计划预览 / 收款日 /
///     创建债权 / 保存（非 债权人 / 借款本金 / 还款计划 / 记账）。
///
/// 提交 → dispatch [CreateDebtRequested] / [UpdateDebtRequested] → 成功后 pop。
/// DebtBloc 由 router provide（Task 10）；本页 `context.read<DebtBloc>()`。
///
/// - [existing] == null：创建模式（dispatch CreateDebtRequested）。
/// - [existing] != null：编辑模式（预填字段，dispatch UpdateDebtRequested）。
///   对齐 `account_form_page.dart` / `DebtFormPage` 的 existing edit 模式。
///
/// 可选 [initialStartDate] / [initialDueDate] / [initialAccountId] 供测试
/// 直接 seed 表单状态，避免在 widget test 里驱动 showDatePicker（仅创建模式生效）。
class ReceivableFormPage extends StatefulWidget {
  const ReceivableFormPage({
    super.key,
    this.existing,
    this.initialStartDate,
    this.initialDueDate,
    this.initialAccountId,
    this.initialSourceAccountId,
  });

  /// 编辑模式传入的现有 Debt；null = 创建模式。
  final Debt? existing;
  final DateTime? initialStartDate;
  final DateTime? initialDueDate;
  final String? initialAccountId;
  /// 测试 seed:借出来源账户(仅创建模式生效,避免 dropdown 交互)。
  final String? initialSourceAccountId;

  @override
  State<ReceivableFormPage> createState() => _ReceivableFormPageState();
}

class _ReceivableFormPageState extends State<ReceivableFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _counterpartyCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();
  // 应收追踪字段(Task 11):联系方式 / 合同借据编号(可选自由文本)。
  final _contactCtrl = TextEditingController();
  final _contractRefCtrl = TextEditingController();

  /// 债权子类型 key（ReceivableSubtypes.personal / business / family / other）。
  /// 存 **key**（非中文 label）—— 判断用 const，UI 显示 labels[key]。提交时
  /// 透传 CreateDebtParams.subtype。债权无信用卡，不驱动任何字段（区别于
  /// DebtFormPage 的 credit-card 区块）。
  String _subtypeKey = ReceivableSubtypes.business;
  AmortizationMethod _amortization = AmortizationMethod.equalPrincipalInterest;

  /// 关联应收账户（asset / otherAsset）。null = 未选。
  String? _accountId;
  /// borrowedOut 双写:借出资金来源账户（cash asset,非应收）。null = 未选。
  String? _sourceAccountId;
  /// 回款关联账户(应收收回本息计入的 asset 账户)。null = 未选。
  /// 与 _accountId(关联应收账户)区分:_accountId 是 receivable 自身挂账的
  /// otherAsset 账户;collectionAccountId 是回款流入的现金/储蓄账户(可空,
  /// 后续收款记录时再指定)。对齐 proto DebtDTO.collection_account_id。
  String? _collectionAccountId;
  DateTime? _startDate;
  DateTime? _dueDate;

  /// 应收账户候选（AccountRepository.list filter category == otherAsset）。
  List<Account> _accounts = const [];
  /// 来源账户候选（asset 且 category != otherAsset:储蓄/投资等流动资产）。
  List<Account> _sourceAccounts = const [];
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
      // 关联账户）。对齐 DebtFormPage 的 existing 预填。UpdateDebtParams 仅
      // 回传 counterparty + interestRate + version，其余字段仅供预览一致性展示。
      _counterpartyCtrl.text = e.counterparty;
      _principalCtrl.text =
          (e.totalPrincipalCents / 100).toStringAsFixed(2);
      _rateCtrl.text = e.interestRate.toString();
      _amortization = e.amortization;
      _startDate = e.startDate;
      _dueDate = e.dueDate;
      _accountId = e.accountId;
      // 子类型 key 预填（空 → business 默认，避免 const 判断落空）。
      _subtypeKey = e.subtype.isEmpty ? ReceivableSubtypes.business : e.subtype;
      // 应收追踪字段(Task 11):contact / contractRef / collectionAccountId
      // 预填,使编辑模式可见当前值。空 collectionAccountId(null)→ dropdown 无选中。
      _contactCtrl.text = e.contact;
      _contractRefCtrl.text = e.contractRef;
      _collectionAccountId = e.collectionAccountId;
    } else {
      // 创建模式：测试 seed 参数。
      _startDate = widget.initialStartDate;
      _dueDate = widget.initialDueDate;
      _accountId = widget.initialAccountId;
      _sourceAccountId = widget.initialSourceAccountId;
      // collectionAccountId 创建模式默认 = 来源账户(借出资金同账户回款,
      // 常见场景);用户可改。null = 未选 → submit 时校验拦截。
      _collectionAccountId = _sourceAccountId;
    }
    _loadAccounts();
    _loadSourceAccounts();
    // 输入变化即重算预览（principal/rate/dates/amortization 都是 setState 触发）。
    _principalCtrl.addListener(() => setState(() {}));
    _rateCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _counterpartyCtrl.dispose();
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _contactCtrl.dispose();
    _contractRefCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    // 对齐 DebtFormPage._loadAccounts：getIt<AccountRepository>()，
    // 避免依赖 router provide。
    //
    // 关键差异：DebtFormPage 过滤 `accountType == liability`（我欠别人的负债）；
    // 本页过滤 `category == otherAsset`（应收 / 其他资产 —— 收回的本息计入的
    // 资产侧账户）。category 粒度比 accountType 更精确：otherAsset 是应收账款
    // 归属的具体分类（label「其他资产」，含「古董、字画、收藏品、保险现金价值」
    // 及应收语义），accountType.asset 会带上储蓄/投资等无关资产。
    try {
      final repo = GetIt.instance<AccountRepository>();
      final result = await repo.list();
      final list = result.fold((_) => const <Account>[], (l) => l);
      if (!mounted) return;
      setState(() {
        _accounts = list
            .where((a) => a.category == AccountCategory.otherAsset)
            .toList();
        _accountsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _accountsLoading = false);
    }
  }

  Future<void> _loadSourceAccounts() async {
    // 来源账户 = 流动资产（储蓄/投资/黄金等 asset），排除应收（otherAsset）。
    // 借出本金从这类账户扣减；应收账户不应作为自己的来源。
    try {
      final repo = GetIt.instance<AccountRepository>();
      final result = await repo.list();
      final list = result.fold((_) => const <Account>[], (l) => l);
      if (!mounted) return;
      setState(() {
        _sourceAccounts = list
            .where((a) =>
                a.accountType == AccountType.asset &&
                a.category != AccountCategory.otherAsset)
            .toList();
      });
    } catch (_) {
      // 加载失败静默（_sourceAccounts 保持空，提交时校验会拦截）。
    }
  }

  // ===================== 收款计划预览（client-side） =====================

  /// 月数 = (due - start) 的整月差。due ≤ start → 0。
  int _monthsBetween(DateTime? a, DateTime? b) {
    if (a == null || b == null) return 0;
    final m = (b.year - a.year) * 12 + (b.month - a.month);
    return m <= 0 ? 0 : m;
  }

  /// 收款计划预览数据。P≤0 或日期不全 → null（空态）。
  /// 数学与 DebtFormPage 完全一致（同一套摊还公式），仅 label 换成收款语义。
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
          label: '每期收款',
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
          label: '首期收款',
          headlineAmount: firstMonthly,
          rows: rows,
          n: n,
          totalInterest: totalInterest,
          totalPayment: p + totalInterest,
          annualRate: annualRate,
        );
      case AmortizationMethod.lumpSum:
        // 到期一次性收回本息。
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

  void _submit() {
    // 显式校验必要字段并 toast 提示（避免空 submit 无反应）。
    // Label 收款语义：债务人为空 → 「请填写债务人」。
    if (_counterpartyCtrl.text.trim().isEmpty) {
      AppToast.show(context, '请填写债务人', type: ToastType.warning);
      return;
    }
    if (_accountId == null) {
      AppToast.show(context, '请选择关联应收账户', type: ToastType.warning);
      return;
    }
    final principal = double.tryParse(_principalCtrl.text) ?? 0;
    if (_principalCtrl.text.isEmpty || principal <= 0) {
      AppToast.show(context, '请输入借出本金', type: ToastType.warning);
      return;
    }
    final rate = double.tryParse(_rateCtrl.text);
    if (_rateCtrl.text.isEmpty || rate == null || rate < 0) {
      AppToast.show(context, '请输入年利率', type: ToastType.warning);
      return;
    }
    if (_startDate == null) {
      AppToast.show(context, '请选择借出日期', type: ToastType.warning);
      return;
    }
    if (_dueDate == null) {
      AppToast.show(context, '请选择到期日期', type: ToastType.warning);
      return;
    }
    if (_dueDate!.isBefore(_startDate!)) {
      AppToast.show(context, '到期日期需晚于借出日期', type: ToastType.warning);
      return;
    }
    // 来源账户仅在创建模式校验：编辑模式不改账户关联（UpdateDebt 不动账户）。
    if (!_isEdit && _sourceAccountId == null) {
      AppToast.show(context, '请选择借出来源账户', type: ToastType.warning);
      return;
    }
    // 回款关联账户:创建模式必填(对齐服务端 borrowedOut 强制 collection_account_id;
    // 若空,服务端 application 层会拒绝,这里前置拦截给出更友好的中文 toast)。
    if (!_isEdit && (_collectionAccountId == null || _collectionAccountId!.isEmpty)) {
      AppToast.show(context, '请选择回款关联账户', type: ToastType.warning);
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();
    _submitted = true;
    final principalCents = (principal * 100).round();
    final e = _existing;
    if (e != null) {
      // 编辑模式:UpdateDebtParams 回传 id / counterparty / interestRate / version
      // + Task 11 应收追踪字段(contact / contractRef / collectionAccountId)。
      // 后端暂不支持改本金/摊还/日期;type 保持 borrowedOut(债权编辑仍是债权)。
      context.read<DebtBloc>().add(UpdateDebtRequested(UpdateDebtParams(
            id: e.id,
            counterparty: _counterpartyCtrl.text.trim(),
            interestRate: rate,
            version: e.version,
            contact: _contactCtrl.text.trim(),
            contractRef: _contractRefCtrl.text.trim(),
            collectionAccountId: _collectionAccountId,
          )));
    } else {
      // 创建模式：type 显式 borrowedOut（Task 6 的 CreateDebtParams.type）。
      // 这是从 DebtFormPage 的关键差异 —— 后者走默认 borrowedIn。
      // subtype 来自 _subtypeKey（const key），透传到 params.subtype（Task 6）。
      // Task 11:contact / contractRef / collectionAccountId 透传(应收追踪字段)。
      // collectionAccountId 已在上方校验非空(创建模式必填)。
      context.read<DebtBloc>().add(CreateDebtRequested(CreateDebtParams(
            accountId: _accountId!,
            counterparty: _counterpartyCtrl.text.trim(),
            interestRate: rate,
            amortizationIndex: _amortization.index,
            startDateOption: _startDate,
            dueDateOption: _dueDate,
            totalPrincipalCents: principalCents,
            type: DebtType.borrowedOut,
            subtype: _subtypeKey,
            sourceAccountId: _sourceAccountId,
            contact: _contactCtrl.text.trim(),
            contractRef: _contractRefCtrl.text.trim(),
            collectionAccountId: _collectionAccountId,
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
        title: Text(_isEdit ? '编辑债权' : '新建债权'),
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
                : Text(_isEdit ? '保存' : '创建债权'),
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
        FormSection(title: '3 · 借出与到期日期', children: _dateFields()),
        const SizedBox(height: AppSpacing.xl),
        FormActions(
          submitLabel: _isEdit ? '保存' : '创建债权',
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
          labelText: '债务人（借入方）',
          hintText: '姓名 / 企业名称',
        ),
        validator: (v) => _required(v, '债务人'),
      ),
      const SizedBox(height: AppSpacing.md),
      // 债权类型（4 卡：私人 / 商业 / 亲友 / 其他）—— 选项来自
      // ReceivableSubtypes.all（const），禁硬编码字符串。ValueKey / selected /
      // onTap 全部基于 key（_subtypeKey 存 key），UI 显示 labels[key]。
      const Text('债权类型',
          style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final key in ReceivableSubtypes.all)
            _RadioCard(
              key: ValueKey('receivableType-$key'),
              icon: _receivableTypeIcon(key),
              label: ReceivableSubtypes.labels[key]!,
              selected: _subtypeKey == key,
              onTap: () => setState(() => _subtypeKey = key),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.md),
      // 关联应收账户下拉（asset / otherAsset）。与 DebtFormPage 的 liability
      // 过滤对称 —— 这里过滤 category == otherAsset。
      DropdownButtonFormField<String>(
        key: const ValueKey('accountDropdown'),
        decoration: const InputDecoration(labelText: '关联应收账户'),
        value: _accountId,
        items: [
          for (final a in _accounts)
            DropdownMenuItem(value: a.id, child: Text(a.name)),
        ],
        hint: Text(_accountsLoading ? '加载中…' : '选择应收账户'),
        onChanged: (v) => setState(() => _accountId = v),
        validator: (v) => v == null || v.isEmpty ? '请选择关联应收账户' : null,
      ),
      const SizedBox(height: AppSpacing.md),
      // 借出来源账户（borrowedOut 双写:现金来源,asset 非 otherAsset）。
      // 编辑模式不展示/不校验来源（UpdateDebt 不改账户关联），仅创建模式需要。
      if (_isEdit)
        const SizedBox.shrink()
      else
        DropdownButtonFormField<String>(
          value: _sourceAccountId,
          decoration: const InputDecoration(labelText: '借出来源账户'),
          items: [
            for (final a in _sourceAccounts)
              DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          hint: const Text('选择来源账户'),
          onChanged: (v) => setState(() => _sourceAccountId = v),
          validator: (v) => v == null || v.isEmpty ? '请选择借出来源账户' : null,
        ),
      const SizedBox(height: AppSpacing.md),
      // 应收追踪字段(Task 11 对齐 OD):联系方式(可选自由文本)。
      TextFormField(
        key: const ValueKey('contactField'),
        controller: _contactCtrl,
        decoration: const InputDecoration(
          labelText: '联系方式',
          hintText: '电话 / 邮箱（可选）',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      // 合同/借据编号(可选自由文本)。
      TextFormField(
        key: const ValueKey('contractRefField'),
        controller: _contractRefCtrl,
        decoration: const InputDecoration(
          labelText: '合同 / 借据编号',
          hintText: '借条编号 / 合同号（可选）',
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      // 回款关联账户(收回本息计入的 asset 账户)。复用 _sourceAccounts 候选
      // (asset 非 otherAsset:储蓄/投资等)—— 回款流入现金账户,与借出资金来源
      // 同池。创建模式必填(对齐 OD + 服务端 borrowedOut 强制 collection_account_id);
      // 编辑模式可改(UpdateDebt 透传)。默认 = 来源账户(initState 预设),用户可改。
      // 注:若改用「所有 asset active 列表」(含 otherAsset),下拉会包含应收账户
      // 自身,语义混乱 → 限定流动资产池更合理。
      DropdownButtonFormField<String>(
        key: const ValueKey('collectionAccountDropdown'),
        value: _collectionAccountId,
        decoration: const InputDecoration(labelText: '回款关联账户'),
        items: [
          for (final a in _sourceAccounts)
            DropdownMenuItem(value: a.id, child: Text(a.name)),
        ],
        hint: const Text('选择回款账户（收回本息计入）'),
        onChanged: (v) => setState(() => _collectionAccountId = v),
        // 不在 dropdown validator 强制必填:编辑模式 collection 可为 null
        // (解除关联),创建模式的必填校验在 _submit() 前置 _collectionAccountId
        // 判空 + AppToast 拦截(给出更友好的中文提示,且服务端 application 层
        // 对 borrowedOut 二次强制)。validator 强制必填会让编辑模式(预填 null)
        // 的 form.validate() 始终失败。
      ),
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
            labelText: '借出本金',
            prefixText: '¥ ',
            hintText: '0.00',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (v) => _required(v, '借出本金'),
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
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
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
    ];
  }

  // ----- 字段：日期（Step 3） -----
  List<Widget> _dateFields() {
    return [
      FormRow(children: [
        _DateField(
          key: const ValueKey('startDatePicker'),
          label: '借出日期',
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
    final subtypeLabel = ReceivableSubtypes.labels[_subtypeKey] ?? '';
    return _CollectionPreview(
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

/// 收款计划预览数据。
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
  final String label; // 每期收款 / 首期收款 / 到期总额
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
/// step 标签换收款语义（基本信息 / 金额利率 / 日期）—— 与 DebtFormPage 同结构。
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

/// 单选卡(债权类型 4 / 摊还方法 3)。对齐 OD .radio:32px icon tile(选中金实心)
/// + label + 可选 desc。复用 TypeTabs 金选中态视觉。
///
/// 与旧 `_RadioChip` 的差异:加 32px icon tile(选中 gold 实心,未选 gold-soft
/// 描边),可选 desc(摊还方法用),卡内纵向居中。类型 4 卡 desc == null(仅 icon +
/// label),摊还 3 卡 desc 非空(等额本息「每期合计相同」等)。
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
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardBg = selected ? const Color(0xFFFBF7EF) : AppColors.surface;
    final cardBorder = selected ? AppColors.accent : AppColors.border;
    // icon tile:选中金实心(白图标),未选 gold-soft 底 + gold-press 图标。
    final tileBg =
        selected ? AppColors.accent : AppColors.accentSoft;
    final tileFg = selected ? Colors.white : AppColors.accentHover;
    final labelColor = selected ? AppColors.accentHover : AppColors.fg;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
        suffixIcon: const Icon(LucideIcons.calendar, size: 18),
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
/// Label 收款语义：收款计划预览 / 收回本金 / 利息收入。
class _CollectionPreview extends StatelessWidget {
  const _CollectionPreview({required this.title, required this.preview});

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
          const Text('LIVE PREVIEW · 收款计划预览',
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
            _sumGrid(p),
          ],
        ],
      ),
    );
  }

  /// 2×2 汇总网格(对齐 OD .pv-sum):月供/期供(gold) / 总利息收入(green) /
  /// 期数 / 总还款(本息)(gold)。替代旧 `_tag` 文字标签 —— 数字 + 标签更清晰。
  /// 深色卡内嵌:cell 半透明白底 + 分隔线,与下方 rows 视觉一致。
  ///
  /// 多币种(Task 11 concern):`_fmtYuan` 硬编 ¥。本预览是深色实时计算卡,
  /// 金额符号暂保留 ¥(对齐 OD 原型惯例 + 多数 receivable 用例为本币)。
  /// 若后续需多币种,把 `_fmtYuan` 改 currencySymbol(preferred currency code)
  /// 并在此注入 CurrencyBloc —— 见 task-11-report.md concerns。
  Widget _sumGrid(_Preview p) {
    return Container(
      key: const ValueKey('previewSumGrid'),
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      decoration: BoxDecoration(
        color: const Color(0x0EFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x12FFFFFF)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _sumCell('月供 / 期供', _fmtYuan(p.headlineAmount),
                      valueColor: const Color(0xFFE8C894))),
              Container(
                  width: 1,
                  height: 38,
                  color: const Color(0x12FFFFFF)),
              Expanded(
                child: _sumCell('总利息收入', _fmtYuan(p.totalInterest),
                    valueColor: const Color(0xFF7FC9A8)),
              ),
            ],
          ),
          Container(height: 1, color: const Color(0x12FFFFFF)),
          Row(
            children: [
              Expanded(child: _sumCell('期数', '${p.n} 期')),
              Container(
                  width: 1, height: 38, color: const Color(0x12FFFFFF)),
              Expanded(
                child: _sumCell('总还款（本息）', _fmtYuan(p.totalPayment),
                    valueColor: const Color(0xFFE8C894)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sumCell(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Color(0xFF9AA0A8),
                  fontSize: 10,
                  letterSpacing: 0.4)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                color: valueColor ?? Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.01,
                fontFeatures: AppTypography.tabularFigures,
              )),
        ],
      ),
    );
  }

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
                    child: Text('期次 / 收款日',
                        style: TextStyle(
                            color: Color(0xFF6F747C),
                            fontSize: 10,
                            letterSpacing: 1,
                            fontFeatures: AppTypography.tabularFigures))),
                Expanded(
                    flex: 5,
                    child: Text('收回本金 / 利息收入',
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
                Text('利息收入 ${_fmtYuan(r.interest)}',
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
          '填写借出本金与借出/到期日期后\n实时生成收款计划',
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
          const Text('前 5 期预览 · 实际以收款为准',
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

/// 摊还方法 icon(对齐 OD .radio .ri svg:趋势上升 / 柱状递减 / 圆环)。
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

/// 摊还方法 desc(对齐 OD .radio .rd 文案)。type 卡无 desc,仅摊还 3 卡用。
String _amortizationDesc(AmortizationMethod m) {
  switch (m) {
    case AmortizationMethod.equalPrincipalInterest:
      return '每期合计相同';
    case AmortizationMethod.equalPrincipal:
      return '本金相同 利息递减';
    case AmortizationMethod.lumpSum:
      return '到期一次结清';
  }
}

/// 债权类型 icon(对齐 OD .radio .ri svg:私人 user / 商业 briefcase /
/// 亲友 users / 其他 helpCircle)。key 来自 ReceivableSubtypes const。
IconData _receivableTypeIcon(String key) {
  switch (key) {
    case ReceivableSubtypes.personal:
      return LucideIcons.user;
    case ReceivableSubtypes.business:
      return LucideIcons.briefcase;
    case ReceivableSubtypes.family:
      return LucideIcons.users;
    case ReceivableSubtypes.other:
    default:
      return LucideIcons.helpCircle;
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
