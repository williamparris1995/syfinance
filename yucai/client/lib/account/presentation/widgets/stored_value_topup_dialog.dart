/// 储值卡充值对话框(v6 原型落码):充值金额 + 付款账户 + 可选赠送。
///
/// 口径与原型「双记账预览」一致:
/// - 充值 = SimpleTransfer(借:储值卡 / 贷:付款账户),净资产不变;
/// - 赠送 = SimpleIncome(借:储值卡 / 贷:收入类目账户),计入其他收入;
/// - 消费时才计支出(正常记账选本卡为支付账户)。
///
/// 回调风格(照 CreditCardRepayDialog 范式),仓储接线集中在
/// [showStoredValueTopupDialog] 组合根,便于 widget 测试。
library;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/amount_input.dart';
import 'package:yucai_client/account/presentation/widgets/category_fields.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

/// 对话框本体:纯 UI + 校验,副作用经 [onTopup] 回调上抛。
class StoredValueTopupDialog extends StatefulWidget {
  const StoredValueTopupDialog({
    super.key,
    required this.card,
    required this.payAccounts,
    required this.incomeAccount,
    required this.currencySymbol,
    required this.onTopup,
  });

  final Account card;

  /// 付款账户候选(资产、active、同币种、非本卡,组合根过滤)。
  final List<Account> payAccounts;

  /// 赠送入账的收入类目账户;null → 赠送字段禁用(无收入类目可挂)。
  final Account? incomeAccount;

  final String currencySymbol;

  /// 提交:(充值金额, 付款账户, 赠送金额)。返回是否成功。
  final Future<bool> Function(int amountCents, String fromAccountId,
      int bonusCents) onTopup;

  @override
  State<StoredValueTopupDialog> createState() => _StoredValueTopupDialogState();
}

class _StoredValueTopupDialogState extends State<StoredValueTopupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _bonusCtrl = TextEditingController();
  String? _selectedPayId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.payAccounts.isNotEmpty) _selectedPayId = widget.payAccounts.first.id;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _bonusCtrl.dispose();
    super.dispose();
  }

  int? get _amountCents {
    final v = double.tryParse(_amountCtrl.text);
    return v == null ? null : (v * 100).round();
  }

  /// 赠送金额:空 = 0(无赠送);有值需 ≥ 0。
  int get _bonusCents {
    final v = double.tryParse(_bonusCtrl.text);
    return v == null || v <= 0 ? 0 : (v * 100).round();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await widget.onTopup(_amountCents!, _selectedPayId!, _bonusCents);
    if (!mounted) return;
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final payName = widget.payAccounts
        .where((a) => a.id == _selectedPayId)
        .map((a) => a.name)
        .firstOrNull;
    final bonus = _bonusCents;
    return AlertDialog(
      title: const Text('充值'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AmountInput(
                controller: _amountCtrl,
                label: '充值金额',
                currencySymbol: widget.currencySymbol,
                validator: (v) {
                  final c = _amountCents;
                  return c == null || c <= 0 ? '请输入大于 0 的金额' : null;
                },
              ),
              DropdownButtonFormField<String>(
                initialValue: _selectedPayId,
                decoration: const InputDecoration(labelText: '付款账户'),
                items: [
                  for (final a in widget.payAccounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _selectedPayId = v),
                validator: (v) => v == null ? '请选择付款账户' : null,
              ),
              const SizedBox(height: 12),
              AmountInput(
                controller: _bonusCtrl,
                label: widget.incomeAccount == null
                    ? '赠送金额(无收入类目,不可用)'
                    : '赠送金额(可选,计入「${widget.incomeAccount!.name}」)',
                currencySymbol: widget.currencySymbol,
                enabled: widget.incomeAccount != null,
              ),
              const SizedBox(height: 12),
              // 双记账预览(对齐 v6 原型:转账 + 可选赠送两行分录)。
              Text(
                '双记账预览\n'
                '充值 ${widget.currencySymbol}${(_amountCents ?? 0) / 100}  借 ${widget.card.name} / 贷 ${payName ?? '付款账户'}'
                '${bonus > 0 && widget.incomeAccount != null ? '\n赠送 ${widget.currencySymbol}${bonus / 100}  借 ${widget.card.name} / 贷 ${widget.incomeAccount!.name}' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submitting ? null : () { setState(() => _submitting = true); _submit().whenComplete(() { if (mounted) setState(() => _submitting = false); }); },
          child: const Text('确认充值'),
        ),
      ],
    );
  }
}

/// 组合根:过滤候选账户 + 接线 TransactionRepository(两笔交易:转账 + 赠送)。
Future<void> showStoredValueTopupDialog(
  BuildContext context,
  Account card,
  List<Account> allAccounts, {
  VoidCallback? onDone,
}) async {
  final pays = allAccounts
      .where((a) =>
          a.accountType == AccountType.asset &&
          a.id != card.id &&
          a.status == AccountStatus.active &&
          a.currencyCode == card.currencyCode)
      .toList();
  final income = allAccounts
      .where((a) =>
          a.accountType == AccountType.income &&
          a.status == AccountStatus.active)
      .firstOrNull;

  await showDialog<void>(
    context: context,
    builder: (_) => StoredValueTopupDialog(
      card: card,
      payAccounts: pays,
      incomeAccount: income,
      currencySymbol: currencySymbolOf(card.currencyCode),
      onTopup: (amountCents, fromAccountId, bonusCents) async {
        final txnRepo = GetIt.instance<TransactionRepository>();
        final r = await txnRepo.recordTransfer(RecordTransferParams(
          transactionDate: DateTime.now(),
          fromAccountId: fromAccountId,
          toAccountId: card.id,
          amountCents: amountCents,
          description: '储值充值 · ${card.name}',
        ));
        if (r.isLeft()) {
          if (context.mounted) {
            AppToast.show(context, '充值失败,请重试', type: ToastType.error);
          }
          return false;
        }
        if (bonusCents > 0 && income != null) {
          final rb = await txnRepo.recordIncome(RecordIncomeParams(
            transactionDate: DateTime.now(),
            assetAccountId: card.id,
            incomeAccountId: income.id,
            amountCents: bonusCents,
            description: '充值赠送 · ${card.name}',
          ));
          if (rb.isLeft()) {
            if (context.mounted) {
              AppToast.show(context, '充值已记录,赠送入账失败',
                  type: ToastType.error);
            }
            // 充值主体已成功,视为完成(赠送可手动补记)。
            onDone?.call();
            return true;
          }
        }
        if (context.mounted) {
          AppToast.show(context, '充值已记录', type: ToastType.success);
        }
        onDone?.call();
        return true;
      },
    ),
  );
}
