/// 信用卡还款对话框(2026-09 用户需求):三种还款方式 + 储蓄卡付款 +
/// 「本期不再提醒」。回调风格(照 DebtRecordDialog 范式),仓储接线集中在
/// [showCreditCardRepayDialog] 组合根,便于 widget 测试。
///
/// 方式(T7 起全额/最低/分期的基数 = **上期账单应还** [statementDueCents],
/// 由组合根经共享推导 CreditCardStatementDue 算好注入,与还款日提醒源
/// 同一数字;账单日未设降级 = 当前欠款,文案「全额」维持):
/// - 全额还款:金额固定 = 应还(账单日已设时文案「全额(上期账单)」),
///   储蓄卡 SimpleTransfer(借:信用卡/贷:储蓄卡)。
/// - 最低还款:预填 ⌈10% × 应还⌉ 可改(0 < 金额 ≤ 当前欠款),提交后
///   自动挂失本期提醒。
/// - 分期还款:金额(预填 = 应还)+ 期数 + 年利率(必填)→ 复用债务模块
///   建分期债(subtype=credit_card 挂本卡,restructureOnly 跳过开账双写
///   防欠款翻倍);每期到期提醒/还款走债务期次既有链路。提交后自动挂失
///   本期提醒。
library;

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/localdb/app_database.dart'
    show AppDatabase;
import 'package:yucai_client/core/notifications/credit_card_statement.dart';
import 'package:yucai_client/core/notifications/reminder_dismissal_store.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/amount_input.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';

enum _RepayMode { full, minimum, installment }

/// 对话框本体:纯 UI + 校验,副作用经回调上抛。
class CreditCardRepayDialog extends StatefulWidget {
  const CreditCardRepayDialog({
    super.key,
    required this.card,
    required this.statementDueCents,
    required this.hasBillingDay,
    required this.savingsAccounts,
    required this.hasActiveInstallment,
    required this.onRepay,
    required this.onInstallment,
    required this.onDismissCycle,
  });

  final Account card;

  /// 上期账单应还(分,T7 口径):全额/最低/分期的基数。
  /// 账单日未设时降级 = 当前欠款(组合根保证)。
  final int statementDueCents;

  /// 账单日是否已设:已设 → 全额文案「全额(上期账单)」;未设 → 「全额」。
  final bool hasBillingDay;

  /// 储蓄卡候选(调用方已过滤 savings + active + 同币种)。
  final List<Account> savingsAccounts;

  /// 卡上已挂活跃借入债(分期/挂账)→ 禁用分期方式(账户 1:1 唯一)。
  final bool hasActiveInstallment;

  /// 全额/最低还款:转账储蓄卡 → 信用卡。成功返回 true。
  final Future<bool> Function(int amountCents, String fromAccountId) onRepay;

  /// 分期:建分期债(等额本息)。成功返回 true。
  final Future<bool> Function(
      int principalCents, int periods, double annualRate) onInstallment;

  /// 挂失本期催办(「不再提醒」)。
  final Future<void> Function() onDismissCycle;

  @override
  State<CreditCardRepayDialog> createState() => _CreditCardRepayDialogState();
}

class _CreditCardRepayDialogState extends State<CreditCardRepayDialog> {
  _RepayMode _mode = _RepayMode.full;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _periodsCtrl;
  late final TextEditingController _rateCtrl;
  String? _selectedSavingsId;
  bool _submitting = false;

  /// 负债 credit-正:欠款 = currentBalanceCents(>0)。
  /// 校验上限/概览展示用;T7 起还款基数另见 [_baseCents]。
  int get _debtCents => widget.card.currentBalanceCents;

  /// 还款基数(T7 口径)= 上期账单应还;账单日未设时组合根已降级为
  /// 当前欠款,故此值即对话框对外的「全额」数字,与提醒源同源。
  int get _baseCents => widget.statementDueCents;

  @override
  void initState() {
    super.initState();
    // 金额预填:全额基数(最低/分期切换时再按需重填)。
    _amountCtrl = TextEditingController(
        text: (_baseCents / 100).toStringAsFixed(2));
    _periodsCtrl = TextEditingController(text: '12');
    _rateCtrl = TextEditingController();
    _selectedSavingsId = widget.savingsAccounts.isNotEmpty
        ? widget.savingsAccounts.first.id
        : null;
    _amountCtrl.addListener(() => setState(() {}));
    _periodsCtrl.addListener(() => setState(() {}));
    _rateCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _periodsCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  int? get _amountCents {
    final v = double.tryParse(_amountCtrl.text);
    return v == null ? null : (v * 100).round();
  }

  double? get _annualRate => double.tryParse(_rateCtrl.text.trim());

  Account? get _selectedSavings => widget.savingsAccounts
      .where((a) => a.id == _selectedSavingsId)
      .firstOrNull;

  /// 余额不足拦截(全额/最低):所选储蓄卡余额 < 金额。
  bool get _insufficient {
    if (_mode == _RepayMode.installment) return false;
    final amt = _amountCents;
    final s = _selectedSavings;
    if (amt == null || s == null) return false;
    return s.currentBalanceCents < amt;
  }

  /// 等额本息每期应还(分,预览用;落库由债务模块计算口径为准)。
  int? get _perPeriodCents {
    final p = _amountCents;
    final n = int.tryParse(_periodsCtrl.text.trim());
    final r = _annualRate;
    if (p == null || p <= 0 || n == null || n <= 0 || r == null || r <= 0) {
      return null;
    }
    final mr = r / 100 / 12;
    final factor = _pow(1 + mr, n);
    if (factor - 1 == 0) return null;
    return (p * mr * factor / (factor - 1)).round();
  }

  static double _pow(double base, int exp) {
    var r = 1.0;
    for (var i = 0; i < exp; i++) {
      r *= base;
    }
    return r;
  }

  String? _amountValidator(String? v) {
    final amt = _amountCents;
    if (amt == null || amt <= 0) return '请输入有效金额';
    if (amt > _debtCents) return '金额不能超过当前欠款';
    return null;
  }

  String? _rateValidator(String? v) {
    final t = v?.trim() ?? '';
    if (t.isEmpty) return '分期需填写年利率';
    final r = double.tryParse(t);
    if (r == null || r < 0) return '请输入有效年利率';
    return null;
  }

  bool get _canSubmit {
    if (_submitting) return false;
    switch (_mode) {
      case _RepayMode.full:
        // 应还为 0(上期账单已还清)→ 全额无可还,禁止提交 0 元转账。
        return _baseCents > 0 && _selectedSavings != null && !_insufficient;
      case _RepayMode.minimum:
        return _selectedSavings != null && !_insufficient;
      case _RepayMode.installment:
        final amt = _amountCents;
        final n = int.tryParse(_periodsCtrl.text.trim());
        return amt != null &&
            amt > 0 &&
            amt <= _debtCents &&
            n != null &&
            n > 0 &&
            _annualRate != null &&
            _annualRate! >= 0;
    }
  }

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    try {
      switch (_mode) {
        case _RepayMode.full:
        case _RepayMode.minimum:
          final ok = await widget
              .onRepay(_amountCents!, _selectedSavingsId!)
              .timeout(const Duration(seconds: 15));
          if (!mounted) return;
          if (!ok) {
            AppToast.show(context, '还款失败，请稍后重试', type: ToastType.error);
            return;
          }
          if (_mode == _RepayMode.minimum) {
            // 最低还款 = 已与银行安排,本期催办挂失。
            await widget.onDismissCycle();
          }
          if (!mounted) return;
          AppToast.show(context, '还款成功', type: ToastType.success);
        case _RepayMode.installment:
          final ok = await widget
              .onInstallment(
                  _amountCents!, int.parse(_periodsCtrl.text.trim()), _annualRate!)
              .timeout(const Duration(seconds: 15));
          if (!mounted) return;
          if (!ok) {
            AppToast.show(context, '分期创建失败，请稍后重试', type: ToastType.error);
            return;
          }
          await widget.onDismissCycle();
          if (!mounted) return;
          final per = _perPeriodCents;
          AppToast.show(
              context,
              per == null
                  ? '分期计划已创建'
                  : '分期计划已创建，每期约 ¥${(per / 100).toStringAsFixed(2)}',
              type: ToastType.success);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        AppToast.show(context, '操作超时，请稍后重试', type: ToastType.error);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _dismissCycleOnly() async {
    await widget.onDismissCycle();
    if (!mounted) return;
    AppToast.show(context, '本期欠款已标记不再提醒', type: ToastType.success);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final symbol = currencySymbol(widget.card.currencyCode);
    // 概览示当前总欠款;还款基数(全额只读金额)= 上期账单应还,两数分开。
    final debtYuan = _groupedYuan(_debtCents);
    final baseYuan = _groupedYuan(_baseCents);
    return AlertDialog(
      title: const Text('信用卡还款'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 卡片与欠款概览。
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: context.yucai.accentSoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.card.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text('当前欠款 $symbol$debtYuan',
                      style: TextStyle(
                          fontSize: 13,
                          color: context.yucai.accentDeep,
                          fontFeatures: AppTypography.tabularFigures)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // 还款方式三选一(账单日已设 → 全额示「全额(上期账单)」)。
            SegmentedButton<_RepayMode>(
              segments: [
                ButtonSegment(
                    value: _RepayMode.full,
                    label: Text(widget.hasBillingDay ? '全额(上期账单)' : '全额')),
                const ButtonSegment(
                    value: _RepayMode.minimum, label: Text('最低')),
                ButtonSegment(
                  value: _RepayMode.installment,
                  enabled: !widget.hasActiveInstallment,
                  label: const Text('分期')),
              ],
              selected: {_mode},
              onSelectionChanged: (s) {
                setState(() {
                  _mode = s.first;
                  // 各方式金额预填:全额/分期=应还基数,最低=10% × 应还。
                  _amountCtrl.text = _mode == _RepayMode.minimum
                      ? ((_baseCents * 0.10).ceil() / 100).toStringAsFixed(2)
                      : (_baseCents / 100).toStringAsFixed(2);
                });
              },
            ),
            if (widget.hasActiveInstallment) ...[
              const SizedBox(height: 6),
              Text('该卡已有挂账分期/债务，不能再创建分期',
                  style: TextStyle(fontSize: 11, color: context.yucai.negative)),
            ],
            const SizedBox(height: 12),
            // 金额(全额只读 = 应还基数;最低/分期可改)。
            _mode == _RepayMode.full
                ? _readonlyAmount(symbol, baseYuan)
                : AmountInput(
                    key: const ValueKey('repayAmountField'),
                    controller: _amountCtrl,
                    label: _mode == _RepayMode.minimum ? '还款金额（最低可还）' : '分期金额',
                    currencySymbol: symbol,
                    validator: _amountValidator,
                  ),
            if (_mode == _RepayMode.minimum)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('已预填最低还款（10%），可修改；未还部分继续计息',
                    style: TextStyle(fontSize: 11, color: context.yucai.muted)),
              ),
            // 分期专属:期数 + 年利率(必填) + 预览。
            if (_mode == _RepayMode.installment) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('repayPeriodsField'),
                      initialValue: 12,
                      decoration:
                          const InputDecoration(labelText: '分期期数'),
                      items: const [
                        DropdownMenuItem(value: 3, child: Text('3 期')),
                        DropdownMenuItem(value: 6, child: Text('6 期')),
                        DropdownMenuItem(value: 9, child: Text('9 期')),
                        DropdownMenuItem(value: 12, child: Text('12 期')),
                        DropdownMenuItem(value: 18, child: Text('18 期')),
                        DropdownMenuItem(value: 24, child: Text('24 期')),
                      ],
                      onChanged: (v) =>
                          _periodsCtrl.text = (v ?? 12).toString(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      key: const ValueKey('repayRateField'),
                      controller: _rateCtrl,
                      keyboardType: TextInputType.number,
                      validator: _rateValidator,
                      decoration: const InputDecoration(
                          labelText: '年利率 (%)', hintText: '如 3.6'),
                    ),
                  ),
                ],
              ),
              if (_perPeriodCents != null) ...[
                const SizedBox(height: 8),
                Text(
                  '每期约 $symbol${(_perPeriodCents! / 100).toStringAsFixed(2)} · '
                  '总手续费约 $symbol${((_perPeriodCents! * int.parse(_periodsCtrl.text.trim()) - _amountCents!) / 100).toStringAsFixed(2)}（等额本息）',
                  style: TextStyle(
                      fontSize: 12,
                      color: context.yucai.accentDeep,
                      fontFeatures: AppTypography.tabularFigures),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('分期后按期从债务模块还款，每期到期自动提醒',
                    style: TextStyle(fontSize: 11, color: context.yucai.muted)),
              ),
            ],
            // 储蓄卡付款账户(分期不当期扣款,不显示)。
            if (_mode != _RepayMode.installment) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: const ValueKey('repaySavingsField'),
                initialValue: _selectedSavingsId,
                decoration: const InputDecoration(labelText: '付款储蓄卡'),
                items: widget.savingsAccounts.isEmpty
                    ? const [
                        DropdownMenuItem(value: '', child: Text('无可用储蓄卡'))
                      ]
                    : [
                        for (final a in widget.savingsAccounts)
                          DropdownMenuItem(
                            value: a.id,
                            child: Text(
                                '${a.name}（余额 ${_fmtBalance(a.currentBalanceCents, a.currencyCode)}）'),
                          ),
                      ],
                onChanged: (v) {
                  if (v != null && v.isNotEmpty) {
                    setState(() => _selectedSavingsId = v);
                  }
                },
              ),
              if (_insufficient)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('所选储蓄卡余额不足，无法支付',
                      key: const ValueKey('repayInsufficientHint'),
                      style: TextStyle(
                          fontSize: 12, color: context.yucai.negative)),
                ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _dismissCycleOnly,
                icon: const Icon(LucideIcons.bellOff, size: 15),
                label: const Text('本期不再提醒',
                    style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          key: const ValueKey('repaySubmitBtn'),
          onPressed: _canSubmit ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: context.yucai.accent,
            foregroundColor: context.yucai.onAccent,
          ),
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('还款'),
        ),
      ],
    );
  }

  /// 千分位两位小数(「三处同数」呈现对齐:面板应答大字/催办/对话框同形态;
  /// 既有表单预填仍用无分组小数,输入态不掺逗号)。
  static String _groupedYuan(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final frac = (abs % 100).toString().padLeft(2, '0');
    final src = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < src.length; i++) {
      if (i > 0 && (src.length - i) % 3 == 0) buf.write(',');
      buf.write(src[i]);
    }
    return '$sign$buf.$frac';
  }

  Widget _readonlyAmount(String symbol, String baseYuan) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: context.yucai.border),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          children: [
            Text('还款金额',
                style: TextStyle(fontSize: 12, color: context.yucai.muted)),
            const Spacer(),
            Text('$symbol$baseYuan',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.accent,
                    fontFeatures: AppTypography.tabularFigures)),
          ],
        ),
      );

  static String _fmtBalance(int cents, String currencyCode) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    return '$sign${currencySymbol(currencyCode)}$yuan.$fen';
  }
}

/// 组合根:过滤储蓄卡候选、检查挂账分期、算上期账单应还(T7 共享推导,
/// 与还款日提醒源同一数字)、接线仓储与挂失存储。
/// [allAccounts] 由调用方(账户页/详情页)从既有账户列表传入。
Future<void> showCreditCardRepayDialog(
  BuildContext context,
  Account card,
  List<Account> allAccounts, {
  VoidCallback? onDone,
}) async {
  final savings = allAccounts
      .where((a) =>
          a.category == AccountCategory.savings &&
          a.status == AccountStatus.active &&
          a.currencyCode == card.currencyCode)
      .toList();

  final debtRepo = GetIt.instance<DebtRepository>();
  var hasInstallment = false;
  final res = await debtRepo.list(typeFilter: DebtType.borrowedIn);
  res.fold((_) {}, (list) {
    hasInstallment = list.any((d) =>
        d.accountId == card.id && d.remainingPrincipalCents > 0);
  });

  // T7:还款基数 = 上期账单应还(core 共享推导;account→core import 合法)。
  // 账单日未设 → 推导内降级 = 当前欠款,对话框文案「全额」维持。
  final statementDueCents = await CreditCardStatementDue.compute(
    db: GetIt.instance<AppDatabase>(),
    accountId: card.id,
    accountType: card.accountType.index + 1, // 域枚举序 +1 = 契约 int
    currentBalanceCents: card.currentBalanceCents,
    billingDay: card.creditBillingDay,
  );

  final dialog = CreditCardRepayDialog(
    card: card,
    statementDueCents: statementDueCents,
    hasBillingDay: card.creditBillingDay != null,
    savingsAccounts: savings,
    hasActiveInstallment: hasInstallment,
    onRepay: (amountCents, fromAccountId) async {
      final txnRepo = GetIt.instance<TransactionRepository>();
      final r = await txnRepo.recordTransfer(RecordTransferParams(
        transactionDate: DateTime.now(),
        fromAccountId: fromAccountId,
        toAccountId: card.id,
        amountCents: amountCents,
        description: '信用卡还款',
        note: '信用卡还款 · ${card.name}',
      ));
      return r.isRight();
    },
    onInstallment: (principalCents, periods, annualRate) async {
      // 按期数建债:服务端/本地都按 N 期推导 due(末个发生日)。
      final start = DateTime.now();
      var m = DateTime(start.year, start.month, start.day);
      for (var i = 0; i < periods; i++) {
        m = DateTime(m.year, m.month + 1, m.day);
      }
      final r = await debtRepo.create(
        accountId: card.id,
        counterparty: '${card.name}分期',
        interestRate: annualRate / 100,
        amortizationIndex: AmortizationMethod.equalPrincipalInterest.index,
        startDate: start,
        dueDate: m,
        totalPrincipalCents: principalCents,
        type: DebtType.borrowedIn,
        subtype: DebtSubtypes.creditCard,
        termPeriods: periods,
        restructureOnly: true,
      );
      return r.isRight();
    },
    onDismissCycle: () async {
      final store = ReminderDismissalStore(GetIt.instance<AppDatabase>());
      final now = DateTime.now();
      await store.dismiss(creditCardCycleEntryId(card.id, now));
    },
  );

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (_) => dialog,
  );
  onDone?.call();
}
