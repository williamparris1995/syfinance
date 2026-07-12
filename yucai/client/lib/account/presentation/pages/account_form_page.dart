import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/account/presentation/widgets/category_fields.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/form_section.dart';
import 'package:yucai_client/core/widgets/type_tabs.dart';

/// 账户表单页（创建 + 编辑 + 复制 seed）。
/// - [existing] == null：创建模式。
/// - [existing] != null 且 id 非空：编辑模式（预填字段，调 UpdateAccount）。
/// - [existing] != null 但 id == ''（复制 seed）：走创建，字段已 seed。
///
/// 布局对应原型 desktop-form-account.html：TypeTabs 顶部类型选择 +
/// 分区表单 + 按 category 动态字段（[categoryFieldsWidget]）+ 底部操作栏。
class AccountFormPage extends StatefulWidget {
  final Account? existing;

  const AccountFormPage({super.key, this.existing});

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _bundle = CategoryFieldBundle();
  String _currency = 'CNY';
  AccountCategory _category = AccountCategory.savings;
  Ownership _ownership = Ownership.personal;
  bool _submitted = false;

  Account? get _existing => widget.existing;
  bool get _isEdit => _existing != null && _existing!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = _existing;
    if (e == null) return;
    // 编辑或复制 seed：预填所有共享字段 + 该 category 专属字段。
    _nameCtrl.text = e.name;
    _currency = e.currencyCode;
    _category = e.category;
    _ownership = e.ownership;
    _bundle.primaryCentsCtrl.text =
        (_primaryCentsOf(e) / 100).toStringAsFixed(2);
    _bundle.institutionCtrl.text = e.institution;
    _bundle.cardNumberTailCtrl.text = e.cardNumberTail;
    _bundle.interestRateCtrl.text = _rateOf(e)?.toString() ?? '';
    _bundle.creditBillingDayCtrl.text = e.creditBillingDay?.toString() ?? '';
    _bundle.creditRepaymentDayCtrl.text =
        e.creditRepaymentDay?.toString() ?? '';
    // M1: 编辑必须预填 creditLimitCents，否则 Update 无条件覆盖会清零额度。
    _bundle.creditLimitCtrl.text =
        (e.creditLimitCents / 100).toStringAsFixed(2);
    _bundle.creditAnnualFeeCtrl.text = e.creditAnnualFeeCents == null
        ? ''
        : (e.creditAnnualFeeCents! / 100).toStringAsFixed(2);
    _bundle.investMarketValueCtrl.text = e.investMarketValueCents == null
        ? ''
        : (e.investMarketValueCents! / 100).toStringAsFixed(2);
    _bundle.fixedTermMonthsCtrl.text = e.fixedTermMonths?.toString() ?? '';
    _bundle.goldProductTypeCtrl.text = e.goldProductType;
    _bundle.goldQuantityCtrl.text = e.goldQuantity?.toString() ?? '';
    _bundle.goldCurrentPriceCtrl.text = e.goldCurrentPriceCents == null
        ? ''
        : (e.goldCurrentPriceCents! / 100).toStringAsFixed(2);
    _bundle.estateCurrentValueCtrl.text = e.estateCurrentValueCents == null
        ? ''
        : (e.estateCurrentValueCents! / 100).toStringAsFixed(2);
    _bundle.loanOriginalCtrl.text = e.loanOriginalCents == null
        ? ''
        : (e.loanOriginalCents! / 100).toStringAsFixed(2);
    _bundle.loanMonthlyCtrl.text = e.loanMonthlyCents == null
        ? ''
        : (e.loanMonthlyCents! / 100).toStringAsFixed(2);
    // 日期预填（DatePickerInput 通过 initialValue 注入，onSaved 回写 bundle）。
    _bundle.openingDate = e.openingDate;
    _bundle.fixedStartDate = e.fixedStartDate;
    _bundle.fixedMaturityDate = e.fixedMaturityDate;
    _bundle.estatePurchaseDate = e.estatePurchaseDate;
    _bundle.loanNextPaymentDate = e.loanNextPaymentDate;
    _notesCtrl.text = e.notes;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    _bundle.dispose();
    super.dispose();
  }

  /// 主金额按 category 反查：投资→InvestCost，定期→FixedPrincipal，
  /// 黄金→GoldBuyPrice，固定资产→EstatePurchasePrice，贷款→LoanRemaining，
  /// 其余→InitialBalance。
  int _primaryCentsOf(Account e) {
    switch (e.category) {
      case AccountCategory.investment:
        return e.investCostCents ?? 0;
      case AccountCategory.fixedDeposit:
        return e.fixedPrincipalCents ?? 0;
      case AccountCategory.goldFx:
        return e.goldBuyPriceCents ?? 0;
      case AccountCategory.realEstate:
        return e.estatePurchasePriceCents ?? 0;
      case AccountCategory.loan:
        return e.loanRemainingCents ?? 0;
      default:
        return e.initialBalanceCents;
    }
  }

  /// 利率字段反查：投资→InvestReturnYtd，固定资产→EstateDepreciationRate，
  /// 其余→InterestRate。
  double? _rateOf(Account e) {
    switch (e.category) {
      case AccountCategory.investment:
        return e.investReturnYtd;
      case AccountCategory.realEstate:
        return e.estateDepreciationRate;
      default:
        return e.interestRate;
    }
  }

  int? _optInt(TextEditingController c) =>
      c.text.trim().isEmpty ? null : int.tryParse(c.text);
  double? _optDouble(TextEditingController c) =>
      c.text.trim().isEmpty ? null : double.tryParse(c.text);

  /// 元（double）→ 分（int）。空串 → null（不修改）。
  int? _yuanToCents(TextEditingController c) {
    final v = double.tryParse(c.text);
    return v == null ? null : (v * 100).round();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    // 触发 DatePickerInput（FormField<DateTime>）的 onSaved，回写 bundle 日期字段。
    _formKey.currentState!.save();
    _submitted = true;

    final primaryCents =
        ((double.tryParse(_bundle.primaryCentsCtrl.text) ?? 0) * 100).round();
    final rate = _optDouble(_bundle.interestRateCtrl);
    final interestRate = (_category == AccountCategory.investment ||
            _category == AccountCategory.realEstate)
        ? null
        : rate;
    final investReturnYtd =
        _category == AccountCategory.investment ? rate : null;
    final estateDepreciationRate =
        _category == AccountCategory.realEstate ? rate : null;

    if (_isEdit) {
      final bloc = context.read<AccountBloc>();
      // 刷新 version：ListAccounts 缓存的 version 可能因交易记账/历史编辑而过期，
      // 直接提交会触发乐观锁冲突（Aborted: optimistic lock conflict），表现为
      // "编辑账户现值无法保存"。GetAccount 取 server 最新 version 再提交。
      bloc.add(GetAccountRequested(_existing!.id));
      var version = _existing!.version;
      try {
        final s = await bloc.stream
            .firstWhere((st) =>
                st is AccountDetailLoaded && st.account.id == _existing!.id)
            .timeout(const Duration(seconds: 2));
        version = (s as AccountDetailLoaded).account.version;
      } catch (_) {
        // 超时或错误：回退缓存 version（最坏再次乐观锁冲突，由 bloc 错误态提示）
      }
      bloc.add(UpdateAccountRequested(_buildUpdate(
        primaryCents,
        interestRate,
        investReturnYtd,
        estateDepreciationRate,
        version: version,
      )));
    } else {
      context.read<AccountBloc>().add(CreateAccountRequested(_buildCreate(
            primaryCents,
            interestRate,
            investReturnYtd,
            estateDepreciationRate,
          )));
    }
  }

  UpdateAccountParams _buildUpdate(
    int primary,
    double? rate,
    double? retYtd,
    double? dep, {
    required int version,
  }) {
    return UpdateAccountParams(
      id: _existing!.id,
      version: version,
      name: _nameCtrl.text.trim(),
      institution: _bundle.institutionCtrl.text.trim(),
      cardNumberTail: _bundle.cardNumberTailCtrl.text.trim(),
      notes: _notesCtrl.text.trim(),
      // M1: creditLimitCents 非 optional 标量，必须无条件回传（预填防清零）。
      creditLimitCents: _yuanToCents(_bundle.creditLimitCtrl) ?? 0,
      interestRate: rate,
      investReturnYtd: retYtd,
      estateDepreciationRate: dep,
      investCostCents:
          _category == AccountCategory.investment ? primary : null,
      fixedPrincipalCents:
          _category == AccountCategory.fixedDeposit ? primary : null,
      goldBuyPriceCents: _category == AccountCategory.goldFx ? primary : null,
      estatePurchasePriceCents:
          _category == AccountCategory.realEstate ? primary : null,
      loanRemainingCents:
          _category == AccountCategory.loan ? primary : null,
      creditBillingDay: _optInt(_bundle.creditBillingDayCtrl),
      creditRepaymentDay: _optInt(_bundle.creditRepaymentDayCtrl),
      creditAnnualFeeCents: _yuanToCents(_bundle.creditAnnualFeeCtrl),
      investMarketValueCents: _yuanToCents(_bundle.investMarketValueCtrl),
      fixedTermMonths: _optInt(_bundle.fixedTermMonthsCtrl),
      goldProductType: _bundle.goldProductTypeCtrl.text.trim(),
      goldQuantity: _optDouble(_bundle.goldQuantityCtrl),
      goldCurrentPriceCents: _yuanToCents(_bundle.goldCurrentPriceCtrl),
      estateCurrentValueCents: _yuanToCents(_bundle.estateCurrentValueCtrl),
      loanOriginalCents: _yuanToCents(_bundle.loanOriginalCtrl),
      loanMonthlyCents: _yuanToCents(_bundle.loanMonthlyCtrl),
      openingDate: _bundle.openingDate,
      fixedStartDate: _bundle.fixedStartDate,
      fixedMaturityDate: _bundle.fixedMaturityDate,
      estatePurchaseDate: _bundle.estatePurchaseDate,
      loanNextPaymentDate: _bundle.loanNextPaymentDate,
    );
  }

  CreateAccountParams _buildCreate(
    int primary,
    double? rate,
    double? retYtd,
    double? dep,
  ) {
    return CreateAccountParams(
      name: _nameCtrl.text.trim(),
      accountType: _category.accountType,
      category: _category,
      currencyCode: _currency,
      initialBalanceCents: _initialCentsForCreate(_category, primary),
      ownership: _ownership,
      notes: _notesCtrl.text.trim(),
      institution: _bundle.institutionCtrl.text.trim(),
      cardNumberTail: _bundle.cardNumberTailCtrl.text.trim(),
      creditLimitCents: _yuanToCents(_bundle.creditLimitCtrl) ?? 0,
      interestRate: rate,
      investReturnYtd: retYtd,
      estateDepreciationRate: dep,
      investCostCents:
          _category == AccountCategory.investment ? primary : null,
      fixedPrincipalCents:
          _category == AccountCategory.fixedDeposit ? primary : null,
      goldBuyPriceCents: _category == AccountCategory.goldFx ? primary : null,
      estatePurchasePriceCents:
          _category == AccountCategory.realEstate ? primary : null,
      loanRemainingCents:
          _category == AccountCategory.loan ? primary : null,
      creditBillingDay: _optInt(_bundle.creditBillingDayCtrl),
      creditRepaymentDay: _optInt(_bundle.creditRepaymentDayCtrl),
      creditAnnualFeeCents: _yuanToCents(_bundle.creditAnnualFeeCtrl),
      investMarketValueCents: _yuanToCents(_bundle.investMarketValueCtrl),
      fixedTermMonths: _optInt(_bundle.fixedTermMonthsCtrl),
      goldProductType: _bundle.goldProductTypeCtrl.text.trim(),
      goldQuantity: _optDouble(_bundle.goldQuantityCtrl),
      goldCurrentPriceCents: _yuanToCents(_bundle.goldCurrentPriceCtrl),
      estateCurrentValueCents: _yuanToCents(_bundle.estateCurrentValueCtrl),
      loanOriginalCents: _yuanToCents(_bundle.loanOriginalCtrl),
      loanMonthlyCents: _yuanToCents(_bundle.loanMonthlyCtrl),
      openingDate: _bundle.openingDate,
      fixedStartDate: _bundle.fixedStartDate,
      fixedMaturityDate: _bundle.fixedMaturityDate,
      estatePurchaseDate: _bundle.estatePurchaseDate,
      loanNextPaymentDate: _bundle.loanNextPaymentDate,
    );
  }

  /// 创建模式主金额映射：投资/定期/黄金/固定资产/贷款 走专属字段（initial=0），
  /// 其余走 InitialBalance。
  int _initialCentsForCreate(AccountCategory c, int primary) {
    switch (c) {
      case AccountCategory.investment:
      case AccountCategory.fixedDeposit:
      case AccountCategory.goldFx:
      case AccountCategory.realEstate:
      case AccountCategory.loan:
        return 0;
      default:
        return primary;
    }
  }

  /// 动态标题右侧的资产/负债 badge（对齐 OD dynTitle pill）。
  Widget _kindBadge(AccountCategory c) {
    final isAsset = c.accountType != AccountType.liability;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.accentSoft,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isAsset ? '资产' : '负债',
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.accentHover),
      ),
    );
  }

  static const _categoryOptions = <TypeOption<AccountCategory>>[
    TypeOption(AccountCategory.savings, '储蓄', LucideIcons.landmark),
    TypeOption(AccountCategory.creditCard, '信用卡', LucideIcons.creditCard),
    TypeOption(AccountCategory.investment, '投资', LucideIcons.trendingUp),
    TypeOption(AccountCategory.fixedDeposit, '定期', LucideIcons.hourglass),
    TypeOption(AccountCategory.goldFx, '黄金外汇', LucideIcons.gem),
    TypeOption(AccountCategory.realEstate, '固定资产', LucideIcons.building2),
    TypeOption(AccountCategory.loan, '贷款', LucideIcons.landmark),
    TypeOption(AccountCategory.otherAsset, '其他资产', LucideIcons.wallet),
    TypeOption(AccountCategory.otherLiability, '其他负债', LucideIcons.wallet),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(_isEdit ? '编辑账户' : '新建账户'),
      ),
      body: BlocListener<AccountBloc, AccountState>(
        // 创建/更新成功 → bloc 经内部 reload 转为 AccountsLoaded；返回列表。
        // 用 _submitted 标志排除首次进入时的 AccountsLoaded；状态流含中间态
        // AccountLoading，不能直接用 prev is AccountFormSubmitting 判断。
        listenWhen: (prev, curr) =>
            _submitted && curr is AccountsLoaded && prev is! AccountsLoaded,
        listener: (context, state) {
          _submitted = false;
          Navigator.of(context).pop(true);
        },
        child: BlocBuilder<AccountBloc, AccountState>(
          builder: (context, state) {
            final submitting = state is AccountFormSubmitting;
            return AbsorbPointer(
              absorbing: submitting,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                child: FormCard(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('账户类型',
                            style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                        const SizedBox(height: AppSpacing.sm),
                        TypeTabs<AccountCategory>(
                          options: _categoryOptions,
                          selected: _category,
                          // 编辑模式切 category 会错乱主金额映射（如投资↔贷款），
                          // 因此不更新 state；创建/复制清空 bundle 后切。
                          onChanged: (v) {
                            if (_isEdit) return;
                            setState(() {
                              _category = v;
                              _bundle.clearAll();
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: AppColors.accentSoft,
                            border: Border.all(color: const Color(0xFFE8DCC4)),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(LucideIcons.info,
                                  size: 15, color: AppColors.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: '${_category.description}  '),
                                    const TextSpan(
                                        text: '示例:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.accentHover)),
                                    TextSpan(text: _category.example),
                                  ]),
                                  style: const TextStyle(
                                      color: Color(0xFF7A6433),
                                      fontSize: 13,
                                      height: 1.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: AppSpacing.lg),
                        FormSection(
                          title: '基本信息',
                          children: [
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(
                                labelText: '账户名称',
                                hintText: '例如：招商银行储蓄卡',
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? '请输入账户名称'
                                  : null,
                            ),
                            FormRow(children: [
                              DropdownButtonFormField<String>(
                                decoration:
                                    const InputDecoration(labelText: '币种'),
                                value: _currency,
                                items: const [
                                  'CNY', 'USD', 'HKD', 'EUR',
                                  'JPY', 'GBP', 'AUD', 'SGD'
                                ]
                                    .map((c) => DropdownMenuItem(
                                        value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _currency = v ?? 'CNY'),
                              ),
                              DropdownButtonFormField<Ownership>(
                                decoration: const InputDecoration(
                                    labelText: '归属'),
                                value: _ownership,
                                items: Ownership.values
                                    .map((o) => DropdownMenuItem(
                                        value: o, child: Text(o.label)))
                                    .toList(),
                                onChanged: (v) => setState(() =>
                                    _ownership = v ?? Ownership.personal),
                              ),
                            ]),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FormSection(
                          title: '${_category.label}信息',
                          trailing: _kindBadge(_category),
                          children: categoryFieldsWidget(_category, _bundle,
                              currencySymbol: currencySymbolOf(_currency)),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FormSection(
                          title: '备注',
                          children: [
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: '补充说明,如账户用途、关联卡片、还款提醒等(可选)',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FormActions(
                          submitLabel: _isEdit ? '保存修改' : '确认创建',
                          submitting: submitting,
                          onSubmit: _submit,
                          onCancel: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
