import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/core/recurrence/next_after.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule_editor.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule_text.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/amortization_preview.dart';
import 'package:get_it/get_it.dart';
import 'package:yucai_client/core/data_refresh.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/debt/data/contract_attachment_store.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_bloc.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_event.dart';
import 'package:yucai_client/debt/presentation/bloc/debt_state.dart';
import 'package:yucai_client/debt/presentation/widgets/debt_guarantor_contract_fields.dart';
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
    // 借入创建的到账账户(资产侧,必选);测试/深链可预置。
    this.initialDisbursementAccountId,
  });

  final Debt? existing;
  final DateTime? initialStartDate;
  final DateTime? initialDueDate;
  final String? initialAccountId;
  final String? initialDisbursementAccountId;

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

  // 担保人与合同文件(2026-09 用户需求,可选)。
  final _guarantorNameCtrl = TextEditingController();
  final _guarantorContactCtrl = TextEditingController();
  StagedContractFile? _stagedFile; // 选中即暂存(源文件可能临时失效)
  String? _existingAttachmentName; // 编辑态已有附件名(null = 无)

  /// 债务子类型 key（DebtSubtypes.*）。存 key —— 判断用 const，UI 显示 labels[key]。
  String _subtypeKey = DebtSubtypes.mortgage;
  /// 用户手动碰过 subtype 即为 true：创建模式自动归位不再覆盖（F33 LLD ②）。
  bool _subtypeTouched = false;
  AmortizationMethod _amortization = AmortizationMethod.equalPrincipalInterest;

  String? _accountId;
  DateTime? _startDate;
  DateTime? _dueDate;

  // ---- 周期规则(类 Google Calendar;lumpSum 不参与)与期数双模式 ----
  RecurrenceRule _rule = const RecurrenceRule();
  bool _byPeriods = false; // true = 按期数(N 期,due 自动推导)
  final _termPeriodsCtrl = TextEditingController(text: '12');
  // 一次性利息减免(元输入;存储为分)。
  final _waiverCtrl = TextEditingController();

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
    AmortizationMethod.interestFirst,
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
      _rule = e.rule;
      if (e.interestWaivedCents > 0) {
        _waiverCtrl.text = (e.interestWaivedCents / 100).toStringAsFixed(2);
      }
      _accountId = e.accountId;
      _subtypeKey = e.subtype.isEmpty ? DebtSubtypes.mortgage : e.subtype;
      _guarantorNameCtrl.text = e.guarantorName;
      _guarantorContactCtrl.text = e.guarantorContact;
    } else {
      _startDate = widget.initialStartDate;
      _dueDate = widget.initialDueDate;
      _accountId = widget.initialAccountId;
      _disbursementAccountId = widget.initialDisbursementAccountId;
    }
    _loadAccounts();
    if (_isEdit) _loadAttachment();
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
    _termPeriodsCtrl.dispose();
    _waiverCtrl.dispose();
    _guarantorNameCtrl.dispose();
    _guarantorContactCtrl.dispose();
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

  /// F33-T6 FR-4:当前选择是否构成 subtype × 账户类别不一致。
  /// 判定收敛在 [DebtSubtypeAffinity.isConflict](category null / other 恒 false)。
  bool get _showSubtypeConflict => DebtSubtypeAffinity.isConflict(
      _selectedAccount?.category.name, _subtypeKey);

  /// 冲突非阻断警示条。形态复用 design-v2「callout.warn 提示卡」
  /// (prototype/v3 ui/subtype-affinity.html 定稿):warn 10% 混 surface 软底 +
  /// warn 30% 描边 + warn 图标 + 标题(可照常保存 pill)+ 正文。
  /// 色值全走 context.yucai 令牌 alpha 组合,无新 hex;纯提示,不参与校验。
  Widget _subtypeConflictCallout() {
    final warn = context.yucai.warn;
    return Container(
      key: const ValueKey('subtypeConflictCallout'),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        // color-mix(in srgb, warn 10%, surface) 语义:surface 基底叠 warn alpha。
        color:
            Color.alphaBlend(warn.withValues(alpha: 0.10), context.yucai.surface),
        border: Border.all(color: warn.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.helpCircle, size: 18, color: warn),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text('分类与关联账户通常不一致',
                          style: TextStyle(
                              color: context.yucai.fg,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(
                        border: Border.all(color: context.yucai.border),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text('可照常保存',
                          style: TextStyle(
                              color: context.yucai.muted, fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '「${DebtSubtypes.labels[_subtypeKey] ?? _subtypeKey}」一般不挂在'
                  '当前类型的账户下。如属特殊情况(如房抵消费贷),忽略本提示继续即可。',
                  style: TextStyle(
                      color: context.yucai.muted,
                      fontSize: 12.5,
                      height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onAccountChanged(String? v) {
    setState(() {
      _accountId = v;
      _refillCreditCardFields();
    });
    // F33-T5 创建自动归位(design LLD ②):仅创建模式且用户未手动碰过 subtype
    // 时按账户类别联动默认值;编辑模式不归位(存量修正靠编辑自由改)。
    if (_isEdit || _subtypeTouched) return;
    final d = DebtSubtypeAffinity.defaultSubtypeFor(
        _selectedAccount?.category.name);
    if (d != null) setState(() => _subtypeKey = d);
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

  // ===================== 合同文件(本地附件 v1) =====================

  Future<void> _loadAttachment() async {
    // 测试 harness 可能不注册 GetIt;缺注册 = 无已有附件,吞错保持表单可用。
    try {
      final a = await GetIt.instance<ContractAttachmentStore>()
          .forDebt(_existing!.id);
      if (mounted) setState(() => _existingAttachmentName = a?.originalName);
    } catch (_) {}
  }

  Future<void> _pickContractFile() async {
    final res = await FilePicker.pickFiles(
      dialogTitle: '选择合同文件',
      allowMultiple: false,
    );
    final f = res?.files.singleOrNull;
    if (f == null || f.path == null) return;
    final staged =
        await GetIt.instance<ContractAttachmentStore>().stage(f.path!, f.name);
    if (mounted) setState(() => _stagedFile = staged);
  }

  /// 移除仅作用于编辑态已有附件;已暂存新文件时重新选择即替换。
  Future<void> _removeExistingAttachment() async {
    final e = _existing;
    if (e == null || _stagedFile != null) return;
    await GetIt.instance<ContractAttachmentStore>().remove(e.id);
    if (mounted) setState(() => _existingAttachmentName = null);
  }

  /// 提交成功后把暂存文件绑定到债务 id(创建态 id 由 bloc.lastCreated 提供)。
  Future<void> _bindAttachment(String debtId) async {
    final staged = _stagedFile;
    if (staged == null) return;
    await GetIt.instance<ContractAttachmentStore>().bind(debtId, staged);
    _stagedFile = null;
  }

  Widget _guarantorContractFields() => DebtGuarantorContractFields(
        guarantorNameCtrl: _guarantorNameCtrl,
        guarantorContactCtrl: _guarantorContactCtrl,
        attachmentLabel: _stagedFile?.originalName ?? _existingAttachmentName,
        onPickFile: _pickContractFile,
        onRemoveFile: (_existingAttachmentName != null && _stagedFile == null)
            ? _removeExistingAttachment
            : null,
      );

  // ===================== 摊还预览（client-side） =====================

  AmortizationPreviewData? _computePreview() {
    final p = double.tryParse(_principalCtrl.text) ?? 0;
    final annualRate = double.tryParse(_rateCtrl.text) ?? 0;
    if (p <= 0 || _startDate == null) return null;
    final dates = _effectiveDates();
    if (dates.isEmpty) return null;
    final n = dates.length;
    final rate = annualRate / 100;
    // 期利率 = 年利率 × 周期年化长度(月度单间隔 = rate/12,与旧口径一致)。
    final r = rate * periodYears(_rule);
    final waiver = _waiverCents();
    final monthly = _rule.cycle == RecurrenceCycle.monthly;

    switch (_amortization) {
      case AmortizationMethod.equalPrincipalInterest:
        final pow = _pow(1 + r, n);
        final per = r > 0 ? p * r * pow / (pow - 1) : p / n;
        // 全序列利息 → 减免 → 行渲染/合计。
        final interests = <double>[];
        var bal = p;
        for (var i = 0; i < n; i++) {
          interests.add(bal * r);
          bal -= (per - interests[i]);
        }
        _applyWaiver(interests, waiver.toDouble());
        final rows = <AmortizationPreviewRow>[
          for (var i = 0; i < (n < 5 ? n : 5); i++)
            AmortizationPreviewRow(
              index: i + 1,
              date: dates[i],
              principal: per - interests[i],
              interest: interests[i],
            ),
        ];
        final totalInterestAll = interests.fold(0.0, (a, b) => a + b);
        return AmortizationPreviewData(
          label: monthly ? '月供' : '每期还款',
          headlineAmount: per,
          rows: rows,
          n: n,
          totalInterest: totalInterestAll,
          totalPayment: p + totalInterestAll,
          annualRate: annualRate,
        );
      case AmortizationMethod.equalPrincipal:
        final perPrincipal = p / n;
        final interests = <double>[];
        var b = p;
        for (var i = 0; i < n; i++) {
          interests.add(b * r);
          b -= perPrincipal;
        }
        _applyWaiver(interests, waiver.toDouble());
        final rows = <AmortizationPreviewRow>[
          for (var i = 0; i < (n < 5 ? n : 5); i++)
            AmortizationPreviewRow(
              index: i + 1,
              date: dates[i],
              principal: perPrincipal,
              interest: interests[i],
            ),
        ];
        final totalInterest = interests.fold(0.0, (a, b) => a + b);
        final first = perPrincipal + interests.first;
        return AmortizationPreviewData(
          label: monthly ? '首月供' : '首期还款',
          headlineAmount: first,
          rows: rows,
          n: n,
          totalInterest: totalInterest,
          totalPayment: p + totalInterest,
          annualRate: annualRate,
        );
      case AmortizationMethod.interestFirst:
        // 先息后本:每期利息 = 全本金 × 期利率;末期还本。
        final perInterest = p * r;
        final interestsIf = [for (var i = 0; i < n; i++) perInterest];
        _applyWaiver(interestsIf, waiver / 100);
        final rowsIf = <AmortizationPreviewRow>[
          for (var i = 0; i < (n < 5 ? n : 5); i++)
            AmortizationPreviewRow(
              index: i + 1,
              date: dates[i],
              principal: i == n - 1 ? p : 0,
              interest: interestsIf[i],
            ),
        ];
        final totalInterestIf = interestsIf.fold(0.0, (a, b) => a + b);
        return AmortizationPreviewData(
          label: '每期利息',
          headlineAmount: perInterest,
          rows: rowsIf,
          n: n,
          totalInterest: totalInterestIf,
          totalPayment: p + totalInterestIf,
          annualRate: annualRate,
        );
      case AmortizationMethod.lumpSum:
        // 月度沿用旧 months/12;其余周期按实际天数 /365(镜像 server)。
        final last = dates.last;
        double years;
        if (monthly) {
          years = monthsBetween(_startDate!, last) / 12.0;
        } else {
          years = last.difference(_startDate!).inDays / 365;
          if (years <= 0) years = periodYears(_rule) * n;
        }
        final interest = (p * rate * years - waiver / 100).clamp(0.0, double.maxFinite);
        final rows = <AmortizationPreviewRow>[
          AmortizationPreviewRow(
            index: 1,
            date: last,
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

  /// 一次性减免 → 最早几期依次扣减(元序列;镜像 server earliest-first)。
  void _applyWaiver(List<double> interests, double waiver) {
    if (waiver <= 0) return;
    var left = waiver;
    for (var i = 0; i < interests.length && left > 0; i++) {
      final take = interests[i] > left ? left : interests[i];
      interests[i] -= take;
      left -= take;
    }
  }

  double _pow(double base, int exp) {
    var r = 1.0;
    for (var i = 0; i < exp; i++) {
      r *= base;
    }
    return r;
  }

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
    // 到账账户必选(创建):借款金额必须落到一个资产账户,否则后续还款会把
    // 还款账户扣成负数(账不平)。
    if (!_isEdit && _disbursementAccountId == null) {
      AppToast.show(context, '请选择到账账户(借款金额到账的账户)',
          type: ToastType.warning);
      return;
    }
    if (_startDate == null) {
      AppToast.show(context, '请选择起始日期', type: ToastType.warning);
      return;
    }
    final dates = _effectiveDates();
    if (dates.isEmpty) {
      AppToast.show(
          context,
          _byPeriods ? '请输入有效的期数' : '请选择晚于起始日期的到期日期',
          type: ToastType.warning);
      return;
    }
    if (!_byPeriods && _dueDate!.isBefore(_startDate!)) {
      AppToast.show(context, '到期日期需晚于起始日期', type: ToastType.warning);
      return;
    }
    // 按期数模式:到期日 = 末个发生日(服务端按期数推导,此处供展示/编辑)。
    final effectiveDue = dates.last;

    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();
    _submitted = true;
    final principalCents = (principal * 100).round();
    final bloc = context.read<DebtBloc>();
    await _persistCreditCardFieldsIfNeeded();
    final e = _existing;
    if (e != null) {
      // 编辑允许改规则/摊销/期限(Google-Calendar 式:已发生期次冻结,
      // 未来按剩余本金重排 —— 服务端 UpdateDebt 处理)。
      bloc.add(UpdateDebtRequested(UpdateDebtParams(
        id: e.id,
        counterparty: _counterpartyCtrl.text.trim(),
        interestRate: rate,
        version: e.version,
        // F33-T5 编辑解禁:显式携带当前选中 subtype(FR-1 存量修正)。
        subtype: _subtypeKey,
        guarantorName: _guarantorNameCtrl.text.trim(),
        guarantorContact: _guarantorContactCtrl.text.trim(),
        amortizationIndex: _amortization.index,
        dueDate: effectiveDue,
        termPeriods: _byPeriods ? dates.length : 0,
        cycle: _rule.cycleInt,
        interval: _rule.interval,
        weekdayMask: _rule.weekdayMask,
        monthlyMode: _rule.monthlyModeInt,
        nth: _rule.nth,
        interestWaivedCents: _waiverCents(),
      )));
    } else {
      bloc.add(CreateDebtRequested(CreateDebtParams(
        accountId: _accountId!,
        counterparty: _counterpartyCtrl.text.trim(),
        interestRate: rate,
        amortizationIndex: _amortization.index,
        sourceAccountId: _disbursementAccountId,
        startDateOption: _startDate,
        dueDateOption: effectiveDue,
        totalPrincipalCents: principalCents,
        subtype: _subtypeKey,
        guarantorName: _guarantorNameCtrl.text.trim(),
        guarantorContact: _guarantorContactCtrl.text.trim(),
        cycle: _rule.cycleInt,
        interval: _rule.interval,
        weekdayMask: _rule.weekdayMask,
        monthlyMode: _rule.monthlyModeInt,
        nth: _rule.nth,
        termPeriods: _byPeriods ? dates.length : 0,
        interestWaivedCents: _waiverCents(),
      )));
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '请输入$label' : null;

  // ===================== build =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Breakpoints.of(context) == Breakpoint.mobile
            ? Text(_isEdit ? '编辑债务' : '新建债务')
            : const SizedBox.shrink(),
        backgroundColor: context.yucai.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: BlocListener<DebtBloc, DebtState>(
        listenWhen: (prev, curr) => _submitted &&
            (curr is DebtsLoaded || curr is DebtError),
        listener: (context, state) async {
          if (state is DebtError) {
            // 写失败不再静默:toast 提示后留在表单,用户可改后重试。
            _submitted = false;
            AppToast.show(context, state.message, type: ToastType.error);
            return;
          }
          _submitted = false;
          // 跨页广播:账户页负债/总览数字随之刷新(债务账户余额变动)。
          try {
            getIt<DataRefreshNotifier>().bump();
          } catch (_) {}
          // 创建态新债务 id 来自 bloc.lastCreated(绑定本地合同附件用)。
          // 附件绑定是本地 best-effort:任何失败(历史 FK 版本表/磁盘/占用)
          // 都不得阻断 pop —— 债务本体已保存成功(「上传卡住」缺陷根因)。
          final bloc = context.read<DebtBloc>();
          final debtId = _existing?.id ?? bloc.lastCreated?.id;
          try {
            if (debtId != null) await _bindAttachment(debtId);
          } catch (_) {}
          if (context.mounted) Navigator.of(context).pop(true);
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
                  if (_step == 2) ...[
                    ..._dateFields(),
                    const SizedBox(height: 18),
                    _guarantorContractFields(),
                  ],
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
            style: TextStyle(color: context.yucai.muted, fontSize: 13),
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
              backgroundColor: context.yucai.accent,
              // F27 FR-1①:accent 面提交按钮前景 → onAccent(暗=金底深墨)。
              foregroundColor: context.yucai.onAccent,
              disabledBackgroundColor: context.yucai.accent.withValues(alpha: 0.5),
            ),
            child: submitting
                ? SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.yucai.onAccent),
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
        _ODFormSection(
          num: '4',
          title: '担保人与合同',
          sub: '全部选填 · 合同文件保存在本机',
          children: [_guarantorContractFields()],
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
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.lgBorder,
        boxShadow: const [
          // 深灰黑阴影豁免(暗底不可见 = v2 暗色无阴影),保原值。
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
              foregroundColor: context.yucai.fg,
              backgroundColor: context.yucai.surface,
              side: BorderSide(color: context.yucai.border),
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
              backgroundColor: context.yucai.accent,
              // F27 FR-1①:accent 面提交按钮前景 → onAccent(暗=金底深墨)。
              foregroundColor: context.yucai.onAccent,
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
            decoration: _odDec(context, hint: '例如：招商银行 / 张三'),
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
            decoration: _odDec(context,
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
          label: '到账账户',
          required: true,
          hint: '借款金额到账的资产账户(必选:保证还款时账户不为负)',
          child: DropdownButtonFormField<String>(
            key: const ValueKey('disbursementDropdown'),
            value: _disbursementAccountId,
            isExpanded: true,
            decoration: _odDec(context, hint: '选择到账的银行卡/资产账户'),
            items: [
              for (final a in _assetAccounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _disbursementAccountId = v),
          ),
        ),
      ]),
      _ODField(
        label: '利息减免(选填)',
        hint: '银行一次性优惠,从最早几期利息中扣减',
        child: TextFormField(
          key: const ValueKey('waiverField'),
          controller: _waiverCtrl,
          decoration: _odDec(context, prefix: '${currencySymbol('CNY')} ', hint: '0.00'),
          style: TextStyle(
              fontSize: 14,
              color: context.yucai.fg,
              fontFeatures: AppTypography.tabularFigures),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      // 债务类型(5 卡):OD .radio-row.c5。icon + label(无 desc,对齐 OD 类型卡)。
      _ODField(
        label: '债务类型',
        required: true,
        child: _ResponsiveRadioRow(
          children: [
            for (final key in DebtSubtypes.all)
              _RadioCard(
                key: ValueKey('debtType-$key'),
                iconKey: ValueKey('debtTypeIcon-$key'),
                icon: _debtTypeIcon(key),
                label: DebtSubtypes.labels[key]!,
                selected: _subtypeKey == key,
                // F33-T5:创建+编辑都可选;触碰后创建模式不再自动归位。
                onTap: () => setState(() {
                      _subtypeKey = key;
                      _subtypeTouched = true;
                      // 切到 credit_card 时 _visibleAccounts 收窄为信用卡
                      // 账户,已选非信用卡账户失效 → 清空保持下拉
                      // value ⊆ items(design.md「归位 × 信用卡过滤交互」)。
                      if (_accountId != null &&
                          !_visibleAccounts
                              .any((a) => a.id == _accountId)) {
                        _accountId = null;
                      }
                      _refillCreditCardFields();
                    }),
              ),
          ],
        ),
      ),
      // F33-T6 FR-4:subtype × 账户类别不一致 → 非阻断警示条(callout.warn,
      // 判定 isConflict:category null / other 恒 false → 永不显示)。
      if (_showSubtypeConflict) ...[
        const SizedBox(height: AppSpacing.sm),
        _subtypeConflictCallout(),
      ],
      // 信用卡子类型 + 无 credit_card 账户 → 提示去账户管理创建。
      if (_isCreditCard && _visibleAccounts.isEmpty && !_accountsLoading)
        Padding(
          key: const ValueKey('createCreditCardHint'),
          padding: const EdgeInsets.only(top: AppSpacing.sm),
          child: GestureDetector(
            onTap: _goCreateCreditCardAccount,
            child: Text(
              '尚未找到信用卡账户，点此去账户管理创建',
              style: TextStyle(
                  color: context.yucai.accent,
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
      Text('💳 信用卡信息',
          key: ValueKey('creditCardSection'),
          style: TextStyle(
              color: context.yucai.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8)),
      const SizedBox(height: AppSpacing.sm),
      _ODGrid2(children: [
        TextFormField(
          key: const ValueKey('ccBillingDayField'),
          controller: _ccBillingDayCtrl,
          decoration: _odDec(context, hint: '账单日 1-31'),
          keyboardType: TextInputType.number,
        ),
        TextFormField(
          key: const ValueKey('ccRepaymentDayField'),
          controller: _ccRepaymentDayCtrl,
          decoration: _odDec(context, hint: '还款日 1-31'),
          keyboardType: TextInputType.number,
        ),
      ]),
      const SizedBox(height: AppSpacing.sm),
      _ODGrid2(children: [
        TextFormField(
          key: const ValueKey('ccLimitField'),
          controller: _ccLimitCtrl,
          decoration: _odDec(context, prefix: '${currencySymbol('CNY')} ', hint: '信用额度 0.00'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        TextFormField(
          key: const ValueKey('ccAnnualFeeField'),
          controller: _ccAnnualFeeCtrl,
          decoration: _odDec(context, prefix: '${currencySymbol('CNY')} ', hint: '年费 0.00'),
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
                _odDec(context, prefix: '${currencySymbol('CNY')} ', hint: '0.00'),
            style: TextStyle(
                fontSize: 14,
                color: context.yucai.fg,
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
            decoration: _odDec(context, suffix: '%', hint: '0.0'),
            style: TextStyle(
                fontSize: 14,
                color: context.yucai.fg,
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

  // ----- 字段：日期（Step 3;含周期规则入口与期数双模式） -----

  /// 当前生效的发生日序列(按期数模式含推导;空 = 输入不全)。
  List<DateTime> _effectiveDates() {
    if (_startDate == null) return const [];
    final term = _termPeriods();
    if (_byPeriods) {
      if (term <= 0) return const [];
      return scheduleDatesFrom(_rule, _startDate!, _startDate!, term);
    }
    if (_dueDate == null) return const [];
    return scheduleDatesFrom(_rule, _startDate!, _dueDate!, 0);
  }

  int _termPeriods() => int.tryParse(_termPeriodsCtrl.text.trim()) ?? 0;

  /// 利息减免(分);空/非法 = 0。
  int _waiverCents() =>
      ((double.tryParse(_waiverCtrl.text.trim()) ?? 0) * 100).round();

  Future<void> _pickDebtRule() async {
    final rule = await showRecurrenceRuleEditor(
      context,
      initial: _rule,
      anchor: RecurrenceAnchor.startDate, // 借贷按日期锚定起始日
    );
    if (rule != null) setState(() => _rule = rule);
  }

  List<Widget> _dateFields() {
    final dates = _effectiveDates();
    final periods = dates.length;
    final derivedDue = dates.isEmpty ? null : dates.last;
    return [
      // 周期规则入口(lumpSum 单期不参与)。
      if (_amortization != AmortizationMethod.lumpSum)
        _ODField(
          label: '周期',
          required: true,
          child: InkWell(
            key: const ValueKey('debtRuleEntry'),
            onTap: _pickDebtRule,
            child: InputDecorator(
              decoration: _odDec(context).copyWith(
                  suffixIcon: Icon(LucideIcons.chevronRight,
                      size: 16, color: context.yucai.muted)),
              child: Text(
                recurrenceRuleText(_rule),
                style:
                    TextStyle(color: context.yucai.fg, fontSize: 13.5),
              ),
            ),
          ),
        ),
      if (_amortization != AmortizationMethod.lumpSum) ...[
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<bool>(
          key: const ValueKey('termModeToggle'),
          segments: const [
            ButtonSegment(value: false, label: Text('按到期日')),
            ButtonSegment(value: true, label: Text('按期数')),
          ],
          selected: {_byPeriods},
          onSelectionChanged: (sel) => setState(() => _byPeriods = sel.first),
        ),
      ],
      const SizedBox(height: AppSpacing.sm),
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
        if (_byPeriods)
          _ODField(
            label: '期数',
            required: true,
            hint: derivedDue == null ? null : '到期 ${_fmtDate(derivedDue)}',
            child: TextFormField(
              key: const ValueKey('termPeriodsField'),
              controller: _termPeriodsCtrl,
              decoration: _odDec(context, hint: '例如：12'),
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
          )
        else
          _ODField(
            label: '到期日期',
            required: true,
            hint: periods > 0 ? '共 $periods 期' : null,
            child: _ODDateField(
              key: const ValueKey('dueDatePicker'),
              value: _dueDate,
              onChanged: (d) => setState(() => _dueDate = d),
            ),
          ),
      ]),
    ];
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border(bottom: BorderSide(color: context.yucai.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < 3; i++) ...[
            _dot(context, i == current, i < current, _labels[i]),
            if (i < 2)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: Divider(color: context.yucai.border, thickness: 1),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _dot(BuildContext context, bool active, bool done, String label) {
    final color = active
        ? context.yucai.accent
        : (done ? context.yucai.positive : context.yucai.border);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: active ? context.yucai.accent : context.yucai.surface,
            border: Border.all(color: color, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          // 完成态 check 白字:done 且非 active 时落在 surface 上,亮板沿原
          // 样(白,现状),暗板墨面上可辨识 —— 豁免双板共用。
          child: done
              ? const Icon(LucideIcons.check, size: 14, color: Colors.white) // 豁免:step-dot done 档白 check(surface 底,历史裁定;亮档辨识靠 positive 描边——存量瑕疵票在案)
              : Text(
                  // active 序号在 accent 底上 → onAccent(暗=鎏金深墨)。
                  '${_labels.indexOf(label) + 1}',
                  style: TextStyle(
                    color: active ? context.yucai.onAccent : context.yucai.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
              color: active ? context.yucai.fg : context.yucai.muted,
              fontSize: 12,
              fontWeight: active ? FontWeight.w600 : FontWeight.w400,
            )),
      ],
    );
  }
}

/// 单选卡(债务类型 9 / 摊还方法 3)。对齐 OD .radio:32px icon tile(选中金实心)
/// + label + 可选 desc。复用 TypeTabs 金选中态视觉。
/// [onTap] == null → 禁用态视觉(当前无调用方传 null,保留通用禁用样式)。
class _RadioCard extends StatelessWidget {
  const _RadioCard({
    super.key,
    this.iconKey,
    required this.icon,
    required this.label,
    this.desc,
    required this.selected,
    required this.onTap,
  });

  final Key? iconKey; // F33-T6:icon key(测试断言 9 类 subtype 图标不漏项)。
  final IconData icon;
  final String label;
  final String? desc;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final cardBg = selected ? context.yucai.accentSoft : context.yucai.surface;
    final cardBorder = selected ? context.yucai.accent : context.yucai.border;
    final tileBg = selected ? context.yucai.accent : context.yucai.accentSoft;
    // F27 FR-1①:选中 icon tile 为 accent 面 → onAccent(暗=金底深墨)。
    final tileFg = selected ? context.yucai.onAccent : context.yucai.accentDeep;
    final labelColor = disabled
        ? context.yucai.muted.withValues(alpha: 0.7)
        : (selected ? context.yucai.accentDeep : context.yucai.fg);
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
                    color: context.yucai.accent.withValues(alpha: 0.12),
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
              child: Icon(icon, key: iconKey, size: 17, color: tileFg),
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
                  style: TextStyle(
                    color: context.yucai.muted,
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
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.yucai.fg,
              ),
              children: [
                TextSpan(text: label),
                if (required)
                  TextSpan(
                      text: ' *', style: TextStyle(color: context.yucai.negative)),
              ],
            ),
          ),
        ),
        child,
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(hint!,
                style: TextStyle(
                    color: context.yucai.muted, fontSize: 11.5, height: 1.4)),
          ),
      ],
    );
  }
}

/// OD `.input`/`.select` InputDecoration 工厂。
/// F4-P2:顶层工厂无 context → 补形参穿线(调用点全量更新);
/// 配色全部令牌化,暗色跟随主题。
InputDecoration _odDec(
  BuildContext context, {
  String? hint,
  String? prefix,
  String? suffix,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: context.yucai.muted, fontSize: 14),
    prefixText: prefix,
    prefixStyle: TextStyle(
        color: context.yucai.accent, fontWeight: FontWeight.w700, fontSize: 14),
    suffixText: suffix,
    suffixStyle: TextStyle(color: context.yucai.muted, fontSize: 13),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    filled: true,
    fillColor: context.yucai.surface,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.yucai.border, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.yucai.accent, width: 1),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.yucai.negative, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: context.yucai.negative, width: 1),
    ),
    errorStyle: TextStyle(color: context.yucai.negative, fontSize: 11.5),
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
            color: context.yucai.surface,
            border: Border.all(color: context.yucai.border, width: 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: has ? context.yucai.fg : context.yucai.muted,
                    fontSize: 14,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
              Icon(LucideIcons.calendar, size: 16, color: context.yucai.muted),
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
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: AppRadius.lgBorder,
        boxShadow: const [
          // 深灰黑阴影豁免(暗底不可见 = v2 暗色无阴影),保原值。
          BoxShadow(
              color: Color(0x0A1C1E21), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: context.yucai.border, width: 1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: context.yucai.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
              alignment: Alignment.center,
              child: Text(
                num,
                style: TextStyle(
                  // F27 FR-1①:accent 面序号块前景 → onAccent(暗=金底深墨)。
                  color: context.yucai.onAccent,
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
                      style: TextStyle(
                          fontSize: 12, color: context.yucai.muted)),
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
    case AmortizationMethod.interestFirst:
      return '先息后本';
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
    case AmortizationMethod.interestFirst:
      return LucideIcons.landmark;
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
    case AmortizationMethod.interestFirst:
      return '每期付息 到期一次还本';
  }
}

/// 债务类型 icon(对齐 OD debt-form.html .radio svg:home/car/creditCard/users/help;
/// F33-T6 补 4 新类:handCoins/calendarClock/shoppingBag/briefcase,
/// 均已核对 lucide_icons_flutter 3.1.14+2 包内 static const 命名)。
IconData _debtTypeIcon(String key) {
  switch (key) {
    case DebtSubtypes.mortgage:
      return LucideIcons.home;
    case DebtSubtypes.autoLoan:
      return LucideIcons.car;
    case DebtSubtypes.creditLoan:
      return LucideIcons.handCoins;
    case DebtSubtypes.cashInstallment:
      return LucideIcons.calendarClock;
    case DebtSubtypes.consumptionLoan:
      return LucideIcons.shoppingBag;
    case DebtSubtypes.businessLoan:
      return LucideIcons.briefcase;
    case DebtSubtypes.creditCard:
      return LucideIcons.creditCard;
    case DebtSubtypes.family:
      return LucideIcons.users;
    case DebtSubtypes.other:
    default:
      return LucideIcons.helpCircle;
  }
}
