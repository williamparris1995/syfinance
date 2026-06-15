import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/amount_input.dart';
import 'package:yucai_client/core/widgets/form_section.dart';
import 'package:yucai_client/core/widgets/type_tabs.dart';

/// 新建账户表单（独立全屏页面，push 自账户列表）。
/// 布局对应原型 desktop-form-account.html：TypeTabs 顶部类型选择 +
/// 分区表单 + 金额输入 + 底部操作栏。
/// 共享列表页的 [AccountBloc]，创建成功后列表自动刷新。
class AccountFormPage extends StatefulWidget {
  const AccountFormPage({super.key});

  @override
  State<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends State<AccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'CNY');
  final _balanceCtrl = TextEditingController(text: '0');
  AccountCategory _category = AccountCategory.savings;
  Ownership _ownership = Ownership.personal;
  bool _submitted = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _currencyCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  static const _categoryOptions = <TypeOption<AccountCategory>>[
    TypeOption(AccountCategory.savings, '储蓄', Icons.account_balance_wallet_outlined),
    TypeOption(AccountCategory.creditCard, '信用卡', Icons.credit_card_outlined),
    TypeOption(AccountCategory.investment, '投资', Icons.trending_up),
    TypeOption(AccountCategory.fixedDeposit, '定期', Icons.hourglass_bottom),
    TypeOption(AccountCategory.goldFx, '黄金外汇', Icons.diamond_outlined),
    TypeOption(AccountCategory.realEstate, '固定资产', Icons.home_outlined),
    TypeOption(AccountCategory.loan, '贷款', Icons.request_quote_outlined),
    TypeOption(AccountCategory.otherAsset, '其他资产', Icons.inventory_2_outlined),
    TypeOption(AccountCategory.otherLiability, '其他负债', Icons.pending_actions),
  ];

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _submitted = true;
    final balanceYuan = double.tryParse(_balanceCtrl.text) ?? 0;
    context.read<AccountBloc>().add(
          CreateAccountRequested(
            CreateAccountParams(
              name: _nameCtrl.text.trim(),
              accountType: _category.accountType,
              category: _category,
              currencyCode: _currencyCtrl.text.trim().toUpperCase(),
              initialBalanceCents: (balanceYuan * 100).round(),
              ownership: _ownership,
            ),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('新建账户'),
      ),
      body: BlocListener<AccountBloc, AccountState>(
        // 创建成功 → bloc 经内部 reload 转为 AccountsLoaded；返回列表。
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
                          onChanged: (v) => setState(() => _category = v),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(_category.description,
                            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                        const SizedBox(height: AppSpacing.lg),
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
                              TextFormField(
                                controller: _currencyCtrl,
                                decoration: const InputDecoration(
                                  labelText: '币种',
                                  hintText: 'CNY',
                                ),
                                textCapitalization:
                                    TextCapitalization.characters,
                                validator: (v) => (v == null || v.trim().isEmpty)
                                    ? '请输入币种'
                                    : null,
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
                            AmountInput(
                              controller: _balanceCtrl,
                              label: '初始余额',
                              validator: (v) =>
                                  double.tryParse(v ?? '') == null
                                      ? '请输入有效金额'
                                      : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FormActions(
                          submitLabel: '确认创建',
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
