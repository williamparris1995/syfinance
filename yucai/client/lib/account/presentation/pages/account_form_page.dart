import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/account_presets.dart';
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
import 'package:yucai_client/debt/domain/debt_query.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/holding_query.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';

/// 账户表单页（创建 + 编辑 + 复制 seed）。
/// - [existing] == null：创建模式。
/// - [existing] != null 且 id 非空：编辑模式（预填字段，调 UpdateAccount）。
/// - [existing] != null 但 id == ''（复制 seed）：走创建，字段已 seed。
///
/// F52 FR-3（ADR-3）预填通道：[preset] 非 null = 经预设目录进入（花呗等），
/// initState 回填 creditCard 类别 + name/institution（preset 日期非 null 时
/// 连带账单日/还款日）；[preselectCreditCard] 仅预选信用卡类别，其余空。
/// 预填仅 initial 注入，全字段可编辑（角标「预设 · 可修改」只标识来源，
/// 提交不持久任何预设痕迹，零存储面）；额度留空由用户补（必填语义由
/// 既有校验/提交流程覆盖）。仅创建态生效，编辑/复制路径零 diff。
///
/// 布局对应原型 desktop-form-account.html：TypeTabs 顶部类型选择 +
/// 分区表单 + 按 category 动态字段（[categoryFieldsWidget]）+ 底部操作栏。
class AccountFormPage extends StatefulWidget {
  final Account? existing;

  /// F52：建户预设（account domain 目录常量）；null = 非预设进入。
  final AccountPreset? preset;

  /// F52：普通信用卡快捷入口 —— 仅预选 creditCard 类别，不预填任何字段。
  final bool preselectCreditCard;

  const AccountFormPage(
      {super.key, this.existing, this.preset, this.preselectCreditCard = false});

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

  // —— F51 FR-1/FR-2(ADR-3)挂接降级态:编辑态一次性检测既有挂接 ——
  // loan:挂接借入债列表 + 各债下一未还期投影(→ derivedLoanFields);
  // invest:挂接持仓列表(→ derivedInvestFields)。空列表 = 未挂接 = 不降级。
  List<Debt> _attachedDebts = const [];
  Map<String, DebtNextPeriod> _nextByDebtId = const {};
  List<Holding> _attachedHoldings = const [];

  // F51 评审 S4:检测完成位(编辑态 loan/investment 检测未决 → 禁保存)。
  // 防竞态:降级提交传 null(orAbsent 保留原列)依赖降级判定已定,若检测
  // 未决就放行保存,可能以「未降级」路径覆盖 loan 组列。编辑态类别不可切
  // (TypeTabs 编辑态 no-op),一次性检测无悬置;失败/未注册也算完成
  // (FR-4 静默不降级,仍可保存)。
  bool _attachmentCheckDone = false;

  // F52 FR-3:预设预填态位 —— initState 经 preset 回填时置 true,驱动头部
  // 角标「预设 · 可修改」与日期 hint;创建态切类别(clearAll)即弃预设态。
  bool _fromPreset = false;

  /// F52:日期空 + 预设来源时的提示行文案(白条类「账单日按激活日,建后可改」;
  /// 花呗日期已预填 → null 不显)。渲染在账单日/还款日行下方(muted 小字,
  /// 语义同 helperText;day picker 在 category_fields.dart,T2 不改该文件,
  /// 由本页在字段组尾部追加)。
  String? get _presetHint {
    final p = widget.preset;
    if (!_fromPreset || _category != AccountCategory.creditCard) return null;
    return (p != null && p.billingDay == null && p.hint.isNotEmpty)
        ? p.hint
        : null;
  }

  /// 保存按钮禁用条件:编辑态 loan/investment 且挂接检测未决(其余态恒可存)。
  bool get _saveBlockedByAttachmentCheck =>
      !_attachmentCheckDone &&
      _isEdit &&
      (_category == AccountCategory.loan ||
          _category == AccountCategory.investment);

  Account? get _existing => widget.existing;
  bool get _isEdit => _existing != null && _existing!.id.isNotEmpty;

  /// loan 组降级:编辑态 loan 账户存在挂接借入债(债侧是事实源)。
  bool get _loanDegraded =>
      _isEdit &&
      _category == AccountCategory.loan &&
      _attachedDebts.isNotEmpty;

  /// invest 组降级:编辑态 investment 账户存在挂接持仓(持仓侧是事实源)。
  bool get _investDegraded =>
      _isEdit &&
      _category == AccountCategory.investment &&
      _attachedHoldings.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = _existing;
    if (e == null) {
      // F52 FR-3(ADR-3):预设预填仅创建态注入 —— preset 回填 creditCard
      // 类别 + name/institution(日期非 null 连带账单日/还款日);额度留空
      // 待用户补。preselectCreditCard(普通信用卡入口)仅预选类别。
      // 纯 initial 注入:提交链路(_buildCreate)读控制器零改动,不持久
      // 任何预设痕迹(零存储面);编辑/复制 seed 路径不进此分支,零 diff。
      final p = widget.preset;
      if (p != null) {
        _category = AccountCategory.creditCard;
        _nameCtrl.text = p.name;
        _bundle.institutionCtrl.text = p.institution;
        if (p.billingDay != null) {
          _bundle.creditBillingDayCtrl.text = p.billingDay.toString();
        }
        if (p.repaymentDay != null) {
          _bundle.creditRepaymentDayCtrl.text = p.repaymentDay.toString();
        }
        _fromPreset = true;
      } else if (widget.preselectCreditCard) {
        _category = AccountCategory.creditCard;
      }
      return;
    }
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
    // F51:编辑态一次性检测既有挂接(新建态无既有挂接,不检测)。
    _detectAttachments();
  }

  /// F51 FR-1/FR-2:编辑态挂接检测(一次性取,经 getIt 仓库 —— 表单测试
  /// harness 须注册 mock,库内坑记忆;照 account_detail_page 的 F35 先例
  /// list(typeFilter: borrowedIn) → accountId 过滤 → 逐债 get 取期表)。
  /// 失败/未注册静默不降级(FR-4:无挂接行为不变,不因取数失败卡表单)。
  Future<void> _detectAttachments() async {
    final e = _existing;
    if (!_isEdit || e == null) return;
    try {
      if (_category == AccountCategory.loan) {
        final repo = GetIt.instance<DebtRepository>();
        final r = await repo.list(typeFilter: DebtType.borrowedIn);
        final linked = r.fold(
          (_) => <Debt>[],
          (l) => l.where((d) => d.accountId == e.id).toList(),
        );
        final next = <String, DebtNextPeriod>{};
        for (final d in linked) {
          final det = await repo.get(d.id);
          det.fold((_) {}, (detail) {
            // 期表 → 下一未还期投影(debtNextPeriod 唯一实现,复用第一)。
            final np = debtNextPeriod(detail.schedule);
            if (np != null) next[d.id] = np;
          });
        }
        if (mounted) {
          setState(() {
            _attachedDebts = linked;
            _nextByDebtId = next;
            _attachmentCheckDone = true; // S4:检测落定,解锁保存。
          });
        }
      } else if (_category == AccountCategory.investment) {
        final r = await GetIt.instance<HoldingRepository>()
            .listHoldings(accountId: e.id);
        // S4:成功/失败都算检测完成(失败按 FR-4 静默不降级,保存照常)。
        if (mounted) {
          setState(() {
            r.fold((_) {}, (list) => _attachedHoldings = list);
            _attachmentCheckDone = true;
          });
        }
      }
    } catch (_) {
      // getIt 未注册(测试 harness)/仓库异常:静默保持可编辑(FR-4)。
      if (mounted) setState(() => _attachmentCheckDone = true);
    }
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
  /// 信用卡→CurrentBalance（「当前欠款」，负债 credit-正），其余→InitialBalance。
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
      case AccountCategory.creditCard:
        return e.currentBalanceCents;
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
    // F51 FR-2:invest 降级态 ytd 不写列(持仓侧无同义字段,读侧以持仓为准)。
    final investReturnYtd = _investDegraded
        ? null
        : (_category == AccountCategory.investment ? rate : null);
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
      // F51 FR-1/FR-2:降级态组列传 null → DS orAbsent 保留原列值
      // (account_local_ds :144/:158-161 实证),债/持仓侧是唯一事实源。
      investCostCents: _investDegraded
          ? null
          : (_category == AccountCategory.investment ? primary : null),
      fixedPrincipalCents:
          _category == AccountCategory.fixedDeposit ? primary : null,
      goldBuyPriceCents: _category == AccountCategory.goldFx ? primary : null,
      estatePurchasePriceCents:
          _category == AccountCategory.realEstate ? primary : null,
      loanRemainingCents: _loanDegraded
          ? null
          : (_category == AccountCategory.loan ? primary : null),
      // 信用卡「当前欠款」编辑：走 currentBalanceCents 手工覆盖通道
      // （负债 credit-正，欠款=正数）。此前该金额无映射被静默丢弃 → 编辑无效。
      currentBalanceCents:
          _category == AccountCategory.creditCard ? primary : null,
      creditBillingDay: _optInt(_bundle.creditBillingDayCtrl),
      creditRepaymentDay: _optInt(_bundle.creditRepaymentDayCtrl),
      creditAnnualFeeCents: _yuanToCents(_bundle.creditAnnualFeeCtrl),
      investMarketValueCents: _investDegraded
          ? null
          : _yuanToCents(_bundle.investMarketValueCtrl),
      fixedTermMonths: _optInt(_bundle.fixedTermMonthsCtrl),
      goldProductType: _bundle.goldProductTypeCtrl.text.trim(),
      goldQuantity: _optDouble(_bundle.goldQuantityCtrl),
      goldCurrentPriceCents: _yuanToCents(_bundle.goldCurrentPriceCtrl),
      estateCurrentValueCents: _yuanToCents(_bundle.estateCurrentValueCtrl),
      loanOriginalCents: _loanDegraded
          ? null
          : _yuanToCents(_bundle.loanOriginalCtrl),
      loanMonthlyCents: _loanDegraded
          ? null
          : _yuanToCents(_bundle.loanMonthlyCtrl),
      openingDate: _bundle.openingDate,
      fixedStartDate: _bundle.fixedStartDate,
      fixedMaturityDate: _bundle.fixedMaturityDate,
      estatePurchaseDate: _bundle.estatePurchaseDate,
      loanNextPaymentDate:
          _loanDegraded ? null : _bundle.loanNextPaymentDate,
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
        color: context.yucai.accentSoft,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isAsset ? '资产' : '负债',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.yucai.accentDeep),
      ),
    );
  }

  /// F52 FR-3:预设来源角标 —— muted chip「预设 · 可修改」。仅标识预填
  /// 来源(非锁定态,ADR-3 全字段可编辑),不参与提交、零持久。
  Widget _presetBadge() {
    return Container(
      key: const ValueKey('accountPresetBadge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: context.yucai.surfaceAlt,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '预设 · 可修改',
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.yucai.muted),
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
    TypeOption(AccountCategory.storedValue, '储值卡', LucideIcons.gift),
  ];

  /// 创建模式下的分叉引导(dev 反馈:用户面对「信用卡/贷款」二选一全靠猜)。
  /// 心智口诀:银行每月告诉你「该还多少」→ 债务;只是一个余额 → 账户。
  Widget? get _categoryGuidance {
    if (_isEdit) return null;
    switch (_category) {
      case AccountCategory.loan:
        return Container(
          key: const ValueKey('loanGuidanceCard'),
          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.yucai.accentSoft,
            border: Border.all(color: context.yucai.accentSoft),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.lightbulb,
                  size: 16, color: context.yucai.accent),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text:
                                '房贷、车贷、现金分期、e招贷这类有固定还款计划的借款,建议从 '),
                        TextSpan(
                            text: '债务 → 借入',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: context.yucai.accentDeep)),
                        const TextSpan(
                            text:
                                ' 创建:自动生成还款计划、到期提醒,支持按期或按账单还款。此处仅适合只记总额、不记计划的贷款。'),
                      ]),
                      style: TextStyle(
                          color: context.yucai.muted,
                          fontSize: 12.5,
                          height: 1.6),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () => context.push('/debts/new'),
                      icon: const Icon(LucideIcons.arrowRight, size: 14),
                      label: const Text('去债务创建',
                          style: TextStyle(fontSize: 12.5)),
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      case AccountCategory.creditCard:
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Text(
            '卡上的现金分期 / e招贷属于独立授信借款,请从 债务 → 借入(卡贷) 创建',
            style: TextStyle(color: context.yucai.muted, fontSize: 12),
          ),
        );
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
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
                        // F52:表单头部「账户类型」行 —— 预设预填态右挂
                        // muted 角标「预设 · 可修改」(仅标识来源,可编辑)。
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('账户类型',
                                style: TextStyle(
                                    color: context.yucai.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.8)),
                            if (_fromPreset) _presetBadge(),
                          ],
                        ),
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
                              // F52:切类别即弃预设态(预填已随 clearAll 清空),
                              // 角标/hint 不再悬挂。
                              _fromPreset = false;
                            });
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: context.yucai.accentSoft,
                            border: Border.all(color: context.yucai.accentSoft),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(LucideIcons.info,
                                  size: 15, color: context.yucai.accent),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(children: [
                                    TextSpan(text: '${_category.description}  '),
                                    TextSpan(
                                        text: '示例:',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: context.yucai.accentDeep)),
                                    TextSpan(text: _category.example),
                                  ]),
                                  // F4-P2 fix:示例正文原 v1 暗金 #7A6433
                                  // (accentSoft 面上的说明文字)→ muted 令牌。
                                  style: TextStyle(
                                      color: context.yucai.muted,
                                      fontSize: 13,
                                      height: 1.55),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_categoryGuidance != null) _categoryGuidance!,
                        Divider(height: 1, color: context.yucai.border),
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
                          // F51:挂接降级态传派生值 → 字段组只读渲染
                          // (loan:derivedLoanFields;invest:derivedInvestFields)。
                          // F52:字段组尾部追加预设 hint 行(日期空+预设来源,
                          // 见 _presetHint;白条类「账单日按激活日,建后可改」)。
                          children: [
                            ...categoryFieldsWidget(_category, _bundle,
                                currencySymbol: currencySymbolOf(_currency),
                                primaryReadOnly: _isEdit &&
                                    _category == AccountCategory.savings,
                                loanDerived: _loanDegraded
                                    ? derivedLoanFields(
                                        _attachedDebts, _nextByDebtId)
                                    : null,
                                investDerived: _investDegraded
                                    ? derivedInvestFields(_attachedHoldings)
                                    : null),
                            if (_presetHint != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  _presetHint!,
                                  key: const ValueKey('accountPresetHint'),
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.yucai.muted),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FormSection(
                          title: '备注',
                          children: [
                            TextFormField(
                              controller: _notesCtrl,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: '补充说明，例如：账户用途、关联卡片、还款提醒等(可选)',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FormActions(
                          submitLabel: _isEdit ? '保存修改' : '确认创建',
                          submitting: submitting,
                          // S4:挂接检测未决禁保存(仅编辑态 loan/investment,
                          // 见 _saveBlockedByAttachmentCheck)。
                          disabled: _saveBlockedByAttachmentCheck,
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
