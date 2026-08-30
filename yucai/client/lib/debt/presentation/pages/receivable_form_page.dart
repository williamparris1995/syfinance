import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
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
      _rateCtrl.text = (e.interestRate * 100)
            .toStringAsFixed(4)
            .replaceFirst(RegExp(r'0+$'), '')
            .replaceFirst(RegExp(r'\.$'), '');
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
  AmortizationPreviewData? _computePreview() {
    final p = double.tryParse(_principalCtrl.text) ?? 0;
    final annualRate = double.tryParse(_rateCtrl.text) ?? 0;
    final n = _monthsBetween(_startDate, _dueDate);
    if (p <= 0 || _startDate == null || _dueDate == null || n <= 0) return null;

    final r = annualRate / 100 / 12; // 月利率
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
        // 总利息：遍历全期（n 可能较大，但 N≤数百万 O(n) 可接受）。
        var b = p;
        var totalInterest = 0.0;
        for (var i = 0; i < n; i++) {
          totalInterest += b * r;
          b -= monthlyPrincipal;
        }
        final firstMonthly = monthlyPrincipal + p * r;
        return AmortizationPreviewData(
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
        final rows = <AmortizationPreviewRow>[];
        // 1 行（到期）。
        rows.add(AmortizationPreviewRow(
          index: 1,
          date: _addMonths(_startDate!, n),
          principal: p,
          interest: interest,
          isDue: true,
        ));
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
    // 输入为百分数(5=5%),存储小数 —— 对齐 debt 表单修复(此前漏 /100)。
    final rate = (double.tryParse(_rateCtrl.text) ?? 0) / 100;
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
      // OD 对齐:desktop/tablet topbar 仅承载 back,标题在 body `.page-head`(serif
      // 26 + sub)。mobile 无 page-head(节省纵向空间,step wizard 字段多),标题
      // 保留在 AppBar。find.text('编辑债权') findsOneWidget:desktop 由 page-head
      // 提供,mobile 由 AppBar title 提供,均唯一。
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Breakpoints.of(context) == Breakpoint.mobile
            ? Text(_isEdit ? '编辑债权' : '新建债权')
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
    // OD `.content` 内:`.page-head`(serif 标题 + sub)铺满 `.form-grid` 上方;
    // `.form-grid` = `1fr 372px`(desktop fixed 372 preview,gap 20)。
    // tablet(600-1200)preview 用 flex 响应(避免 600px 屏 fixed 372 挤压 form)。
    //
    // IntrinsicHeight 包 Row:SingleChildScrollView(vertical)给 Row 无限纵向,
    // CrossAxisAlignment.start 下 Expanded child 依赖 intrinsic 高度;
    // AmortizationPreview(含 gradient/shadow)在无限纵向下 intrinsic 计算为 0
    // → 不渲染。IntrinsicHeight 让 Row 取 form 列 intrinsic 高度(bounded),
    // preview 才渲染。
    final isDesktop = Breakpoints.of(context) == Breakpoint.desktop;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _pageHead(),
          const SizedBox(height: AppSpacing.md), // OD .page-head margin-bottom 20
          Form(
            key: _formKey,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                      flex: isDesktop ? 1 : 16, child: _formColumn()),
                  const SizedBox(width: AppSpacing.md), // OD .form-grid gap 20
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
    // mobile 标题在 AppBar(节省纵向空间,step wizard 字段多);无 page-head。
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

  /// OD `.page-head`:.page-title serif 26px letter-spacing -.01em(新建/编辑债权)
  /// + .page-sub 13px muted margin-top 5。compact(mobile):serif 20,无 sub。
  Widget _pageHead({bool compact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEdit ? '编辑债权' : '新建债权',
          style: TextStyle(
            fontFamily: AppTypography.displayFamily,
            fontFamilyFallback: AppTypography.displayFallback,
            fontSize: compact ? 20 : 26,
            letterSpacing: -0.01,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (!compact) ...[
          const SizedBox(height: 5), // OD .page-sub margin-top 5
          Text(
            _isEdit
                ? '编辑这笔债权 · 调整债务人 / 利率 / 收款账户'
                : '记录一笔借出 · 别人欠我的钱 · 自动生成收款计划',
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
            // OD .btn-primary(gold + white)—— mobile commit 按钮与 desktop 一致。
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
                : Text(_isEdit ? '保存' : '创建债权'),
          ),
      ],
    );
  }

  // ----- 表单列（desktop / tablet） -----
  // OD `.form-grid` form 列:3 个 `.sec` 卡(独立白卡)+ `.actions` 卡。.sec 间
  // margin-bottom 16。每个 _ODFormSection 已含 .sec 卡容器(surface + border +
  // radius 14 + shadow-sm + padding 20/22)+ .sec-head(金方块 sec-num + serif
  // sec-title + 右对齐 sec-sub)。
  Widget _formColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ODFormSection(
          num: '1',
          title: '基本信息',
          sub: '债务人 · 类型 · 关联账户',
          children: _basicInfoFields(),
        ),
        const SizedBox(height: 16), // OD .sec margin-bottom 16
        _ODFormSection(
          num: '2',
          title: '金额与利率',
          sub: '本金 · 年利率 · 摊还方法',
          children: _amountRateFields(),
        ),
        const SizedBox(height: 16),
        _ODFormSection(
          num: '3',
          title: '日期',
          sub: '借出日期 · 到期日期 · 决定期数',
          children: _dateFields(),
        ),
        const SizedBox(height: 16),
        _actionsCard(),
      ],
    );
  }

  /// OD `.actions`:独立白卡(surface + border + radius 14 + shadow-sm + padding
  /// 16/22),flex-end,gap 10。`.btn-ghost`(取消:surface + border + fg)+
  /// `.btn-primary`(创建债权:gold + white + check icon + 金色阴影)。
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
          // 取消 ghost:OD .btn-ghost。
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
          const SizedBox(width: 10), // OD .actions gap 10
          // 创建债权 primary:OD .btn-primary(gold + white + check icon)。
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
            label: Text(_isEdit ? '保存' : '创建债权'),
          ),
        ],
      ),
    );
  }

  // ----- 字段：基本信息（Step 1） -----
  // OD `.field`:label 上方块标签(12.5 w600 fg + req 红 `*` margin-bottom 7)
  // + `.input`(border 1 + radius 10 + padding 11/13 + font 14)+ 可选 `.hint`
  // (11.5 muted margin-top 6)。债务人 + 关联应收账户 OD `.grid-2c` 并排(gap 14)。
  // 字段间距由 _ODFormSection fieldSpacing 提供(OD .field margin-bottom 18)。
  List<Widget> _basicInfoFields() {
    return [
      // .grid-2c:债务人 + 关联应收账户(OD 并排)。
      _ODGrid2(children: [
        _ODField(
          label: '债务人（借入方）',
          required: true,
          hint: '对方按期归还本息，计入「应收账款」',
          child: TextFormField(
            key: const ValueKey('counterpartyField'),
            controller: _counterpartyCtrl,
            decoration: _odDec(hint: '姓名 / 企业名称'),
            validator: (v) => _required(v, '债务人'),
          ),
        ),
        _ODField(
          label: '关联应收账户',
          required: true,
          hint: '收回的本息计入此资产账户',
          child: DropdownButtonFormField<String>(
            key: const ValueKey('accountDropdown'),
            value: _accountId,
            decoration:
                _odDec(hint: _accountsLoading ? '加载中…' : '选择应收账户'),
            items: [
              for (final a in _accounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _accountId = v),
            validator: (v) => v == null || v.isEmpty ? '请选择关联应收账户' : null,
          ),
        ),
      ]),
      // 债权类型(4 卡):OD .radio-row.c4。
      _ODField(
        label: '债权类型',
        required: true,
        child: _ResponsiveRadioRow(
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
      ),
      // 借出来源账户(创建模式,borrowedOut 双写:现金来源 asset 非 otherAsset)。
      // 编辑模式不展示(UpdateDebt 不改账户关联)。
      if (!_isEdit)
        _ODField(
          label: '借出来源账户',
          required: true,
          child: DropdownButtonFormField<String>(
            value: _sourceAccountId,
            decoration: _odDec(hint: '选择来源账户'),
            items: [
              for (final a in _sourceAccounts)
                DropdownMenuItem(value: a.id, child: Text(a.name)),
            ],
            onChanged: (v) => setState(() => _sourceAccountId = v),
            validator: (v) => v == null || v.isEmpty ? '请选择借出来源账户' : null,
          ),
        ),
      // 回款关联账户(收回本息计入的 asset 账户)。创建模式必填(服务端 borrowedOut
      // 强制 collection_account_id;_submit 前置 toast 拦截);编辑可改。默认=来源。
      _ODField(
        label: '回款关联账户',
        required: !_isEdit,
        hint: '收回本息计入此资产账户',
        child: DropdownButtonFormField<String>(
          key: const ValueKey('collectionAccountDropdown'),
          value: _collectionAccountId,
          decoration: _odDec(hint: '选择回款账户'),
          items: [
            for (final a in _sourceAccounts)
              DropdownMenuItem(value: a.id, child: Text(a.name)),
          ],
          onChanged: (v) => setState(() => _collectionAccountId = v),
        ),
      ),
      // 联系方式 + 合同/借据编号(应收追踪,可选,Task 11)。.grid-2c 并排。
      _ODGrid2(children: [
        _ODField(
          label: '联系方式',
          child: TextFormField(
            key: const ValueKey('contactField'),
            controller: _contactCtrl,
            decoration: _odDec(hint: '电话 / 邮箱（可选）'),
          ),
        ),
        _ODField(
          label: '合同 / 借据编号',
          child: TextFormField(
            key: const ValueKey('contractRefField'),
            controller: _contractRefCtrl,
            decoration: _odDec(hint: '借条编号 / 合同号（可选）'),
          ),
        ),
      ]),
    ];
  }

  // ----- 字段：金额利率（Step 2） -----
  List<Widget> _amountRateFields() {
    return [
      // .grid-2c:借出本金(¥ 前缀 mono) + 年利率(% 后缀 mono + hint)。
      _ODGrid2(children: [
        _ODField(
          label: '借出本金',
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
            validator: (v) => _required(v, '借出本金'),
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
    // 期数 hint:基于 start/due 月差(OD #periods gold-press bold mono)。
    final periods = _monthsBetween(_startDate, _dueDate);
    return [
      _ODGrid2(children: [
        _ODField(
          label: '借出日期',
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
    // 与 debt form 共享同一深色 gradient 预览卡;语义切收款侧(sectionLabel
    // 收款计划预览 + 列头「期次 / 收款日」「收回本金 / 利息」+ 空态/底部文案)。
    // title = 债务人 · 债权类型 label(对齐 debt form 的 counterparty · subtype)。
    final counterparty = _counterpartyCtrl.text.trim().isEmpty
        ? '未命名'
        : _counterpartyCtrl.text.trim();
    final subtypeLabel = ReceivableSubtypes.labels[_subtypeKey] ?? '';
    return AmortizationPreview(
      title: '$counterparty · $subtypeLabel',
      sectionLabel: 'LIVE PREVIEW · 收款计划预览',
      dateColumnLabel: '期次 / 收款日',
      principalColumnLabel: '收回本金 / 利息',
      emptyHint: '填写借出本金与借出/到期日期后\n实时生成收款计划',
      footNote: '前 5 期预览 · 实际以收款记录为准',
      preview: _computePreview(),
    );
  }
}

// ===================== 私有 widgets =====================

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
        // OD `.radio label{padding:13px 6px;border-radius:11px}`
        // → vertical 13 / horizontal 6。
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 13),
        decoration: BoxDecoration(
          color: cardBg,
          border: Border.all(color: cardBorder, width: selected ? 1.4 : 1),
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  // OD `:checked box-shadow 0 0 0 3px rgba(gold,.12)`
                  // → spreadRadius 3 blur 0(0 0 0 = ring,等同 OD 写法)。
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

/// OD `.field`:label 上方块标签(12.5 w600 fg + req 红 `*` margin-bottom 7)
/// + input + 可选 `.hint`(11.5 muted margin-top 6)。receivable form 专用 OD 块
/// 标签(非全 app InputDecoration floating label)—— form 页 OD 对齐优先。
class _ODField extends StatelessWidget {
  const _ODField({
    required this.label,
    required this.child,
    this.required = false,
    this.hint,
  });

  final String label;
  final Widget child; // TextFormField / DropdownButtonFormField / RadioRow
  final bool required;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          // Text.rich(非 RichText)—— find.text/find.textContaining 匹配 Text
          // 子类,_ODField label 才能被 widget test 的 find.textContaining 命中。
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

/// OD `.input`/`.select` InputDecoration 工厂:border 1 border-color + radius 10
/// + padding 11/13 + font 14(placeholder muted)。聚焦金边(OD :focus border-color
/// gold;box-shadow ring Flutter 无法直接复刻,以金边近似)。prefix ¥ 金 w700,
/// suffix % muted。errorBorder 红(_submit toast 前置校验后 form.validate 兜底)。
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

/// OD `.input[type=date]`:label 由 _ODField 提供,本控件仅渲染带边框的日期行
/// (border radius 10 + padding 11/13)+ 右侧 calendar icon + mono 数字日期。
/// 无 InputDecoration(避免 floating label 偏离 OD 块标签)。
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

/// OD `.grid-2c`(2 等宽列 gap 14)。Breakpoints(MediaQuery)切换:
/// tablet/desktop → Row + Expanded(2 等宽列);mobile(≤600)→ Column 垂直堆叠
/// (OD @media max-width:1080 .form-grid 单列 → 字段堆叠)。避免窄屏 2-col 挤压
/// dropdown/input(原 FormRow 在 mobile 390px 每列 ~175px → dropdown overflow)。
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

/// OD `.radio-row.c4`/`.c3` 等宽列(gap 9)。Breakpoints(MediaQuery)切换:
/// tablet/desktop → Row + Expanded(等宽列,与 OD grid 等价);mobile(≤600)→
/// Wrap(卡自然宽 + 自动换行)。**不用 LayoutBuilder** —— wide layout 用
/// IntrinsicHeight 包 Row(preview Stack 需 bounded 高度),LayoutBuilder 不支持
/// intrinsic 计算 → 在 IntrinsicHeight 下会抛异常。MediaQuery 无此问题。
class _ResponsiveRadioRow extends StatelessWidget {
  const _ResponsiveRadioRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const gap = 9.0; // OD .radio-row gap 9
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

/// OD 对齐 receivable-form.html `.sec` + `.sec-head`:
///  - `.sec`:surface(#fff) + border + radius 14 + shadow-sm + padding 20/22。
///    每个 section 独立白卡。
///  - `.sec-head`:26×26 金(#b08d57)圆角 8 sec-num + 白字数字(mono 12.5 w700)
///    + sec-title serif 16px + sec-sub 12px muted margin-left:auto(右对齐)
///    + flex row gap 11 + margin-bottom 18 + padding-bottom 14 + border-bottom。
///  - `.field{margin-bottom:18px}` → 字段间距 18(fieldSpacing)。
///
/// receivable 专用,不改动 shared FormSection(account/debt form 仍用 §3.3)。
class _ODFormSection extends StatelessWidget {
  const _ODFormSection({
    required this.num,
    required this.title,
    required this.sub,
    required this.children,
    this.fieldSpacing = 18, // OD .field margin-bottom 18
  });

  final String num;
  final String title;
  final String sub;
  final List<Widget> children;
  final double fieldSpacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      // OD .sec padding 20 22。
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadius.lgBorder, // 14
        // OD --shadow-sm:0 1px 2px / 0 1px 3px rgba(28,30,33,.04)。
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A1C1E21), blurRadius: 3, offset: Offset(0, 1)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // sec-head:flex row, gap 11, mb 18, pb 14, border-bottom
          Container(
            padding: const EdgeInsets.only(bottom: 14),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.border, width: 1)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // sec-num:26×26 金色 圆角 8 + 白字(mono 12.5 w700)
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
                // sec-title:serif 16px
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback)),
                const SizedBox(width: 11),
                // sec-sub:右对齐(margin-left:auto)
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
          // 字段列(OD .field margin-bottom 18)
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) SizedBox(height: fieldSpacing),
          ],
        ],
      ),
    );
  }
}
