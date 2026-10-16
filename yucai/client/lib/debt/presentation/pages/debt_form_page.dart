import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/account_visibility.dart';
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
import 'package:yucai_client/core/widgets/detail_title_sync.dart';
import 'package:yucai_client/core/widgets/form_leave_guard.dart';
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
import 'package:yucai_client/debt/presentation/widgets/filtered_account_picker.dart';
import 'package:yucai_client/debt/presentation/widgets/product_scenario_picker.dart';
import 'package:yucai_client/transaction/presentation/widgets/responsive_layout.dart';

/// 债务表单页（创建 + 编辑模式）。对齐 OD 原型 debt-form.html / tablet / mobile;
/// F62 重做:场景卡首问 + 灰显过滤 + 载体户隐形 + 渐进披露三段 + 期供预览
/// (prototype/v18 ui/debt-form-ux.html 区块二)。
///
/// F62 信息架构(desgin ADR-1..5):
///  - 首问 = [ProductScenarioPicker] 4 场景卡(用户语言推导分类,角标露映射;
///    「更多类型」入口保底全枚举;编辑态按存量 subtype 反选)。
///  - 段①基本(债权方/本金/期数或到期日)+ 粗口径期供预览行(本金÷期数,
///    附「以保存后生成的期表为准」;desktop 另有既有 AmortizationPreview 侧栏)。
///  - 段②到账与还款(到账卡 [FilteredAccountPicker] 灰显过滤 / 起始日;
///    信用卡分期含挂卡/出账方式/首期锚点;信用卡消费分期含挂卡账户)。
///  - 段③高级默认折叠(利率方式/每期手续费/占用开关/担保人/附件,
///    折叠头「已收起 N 项」)。
///  - 载体户隐形(ADR-3):普通贷款无「关联账户」字段,保存时自动创建
///    isSystem 隐藏载体户;信用卡消费分期保留挂卡选择。
///  - isConflict 警示条仅编辑态渲染(存量冲突 = 数据修复入口);新建态
///    冲突不可能(灰显过滤从源头消除)。
///
/// 提交 → dispatch [CreateDebtRequested] / [UpdateDebtRequested] → 成功后 pop。
/// DebtBloc 由 router provide；本页 `context.read<DebtBloc>()`。
/// FormLeaveGuard/DetailTitleSync/守卫/提交流语义零改动(F62 仅 presentation)。
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
  /// F62:创建默认 = 场景一「借钱到银行卡」→ creditLoan(照原型 .scn.on 与
  /// DebtSubtypeAffinity.defaultSubtypeFor(loan)=credit_loan 的智能默认);
  /// 选择经 [ProductScenarioPicker](场景卡/二级/更多枚举)驱动。
  String _subtypeKey = DebtSubtypes.creditLoan;
  /// 用户手动碰过 subtype 即为 true：创建模式自动归位不再覆盖（F33 LLD ②）。
  bool _subtypeTouched = false;
  AmortizationMethod _amortization = AmortizationMethod.equalPrincipalInterest;
  /// F62 FR-4 段③高级默认折叠(渐进披露;折叠头「已收起 N 项」)。折叠用
  /// Offstage(字段保持挂载 → Form validator 照常参与提交校验,不弱化)。
  bool _advancedOpen = false;

  String? _accountId;
  DateTime? _startDate;
  DateTime? _dueDate;

  // ---- 周期规则(类 Google Calendar;lumpSum 不参与)与期数双模式 ----
  RecurrenceRule _rule = const RecurrenceRule();
  bool _byPeriods = false; // true = 按期数(N 期,due 自动推导)
  final _termPeriodsCtrl = TextEditingController(text: '12');
  // 卡贷(F48):挂接信用卡(并账卡)+ 每期手续费。
  String? _cardLoanCardId;
  // 出账方式(dev 2026-10-08,e招贷口径):false = 并入挂接卡账单(平安/
  // 广发现金分期);true = 独立账单 —— 每月账单日合并出账、还款日前整单
  // 还(招行 e招贷)。账单日/还款日落在挂靠贷款账户(creditBillingDay/
  // creditRepaymentDay 列),创建时随自动建户写入,编辑经账户表单修改。
  bool _cardLoanIndependent = false;
  // F50 债级开关:剩余本金是否计入挂接卡额度占用(默认开;仅挂接卡贷
  // 显示开关行,但状态对全部 subtype 持有 —— 编辑回填既有值,非卡贷恒
  // 默认 true,保存时原样透传)。
  bool _countsTowardCardLimit = true;
  // F57 首期锚点(并入模式卡贷,常驻单选):false = 放款次月(默认,现状,
  // 典型银行)/ true = 放款当期(平安口径,首期 = 放款日当天)。分歧是银行
  // 起扣惯例的真实差异,每笔创建都要回答(v15 形态 B,数据反转定案)。
  // 生成期参数:随创建透传、物化进期表日期,不持久化;独立账单模式不
  // 渲染本选项,消费点(getter)双重门控。
  bool _firstPeriodCurrent = false;
  final _clBillDayCtrl = TextEditingController();
  final _clRepayDayCtrl = TextEditingController();
  final _ccFeeCtrl = TextEditingController();
  // 一次性利息减免(元输入;存储为分)。
  final _waiverCtrl = TextEditingController();

  List<Account> _accounts = const [];
  // 借入到账账户(资产侧,可选):选择后创建时自动双记现金入账。
  List<Account> _assetAccounts = const [];
  // F62 灰显过滤候选池:全量账户经 userVisible 滤 isSystem 载体户 ——
  // 到账卡/挂卡 FilteredAccountPicker 的全量 items(不兼容项灰显保留)。
  List<Account> _pickerPool = const [];
  String? _disbursementAccountId;
  bool _accountsLoading = true;

  int _step = 0;
  bool _submitted = false;

  // ---- F59 FR-5(ADR-3):脏态追踪(首改即脏粗粒度)+ 三级面包屑注入串 ----

  /// 首改即脏:任一字段首次用户编辑置位;净态离开(系统返回/面包屑)零摩擦,
  /// 脏态经 FormLeaveGuard 弹「未保存的修改」确认。提交成功走程序化 pop
  /// (不经 canPop 判定)不受守卫影响。
  bool _dirty = false;

  /// 程序化回填抑制窗:编辑态预填(initState)/信用卡字段联动回填
  /// ([_refillCreditCardFields])期间 controller listener 触发不置脏
  /// —— 预填非用户编辑。
  bool _prefilling = false;

  /// 置脏(首改即脏):翻转时 setState 重建 FormLeaveGuard(PopScope 的
  /// canPop 随动)。已脏/抑制窗内直接返回。
  void _markDirty() {
    if (_prefilling || _dirty) return;
    setState(() => _dirty = true);
  }

  /// 三级面包屑注入串:创建 =「新建债务」(照 mobile AppBar 既有标题串);
  /// 编辑 =「编辑 · {债权方}」(existing 经路由加载完成构造,加载即有值)。
  String get _crumbTitle {
    final e = _existing;
    return e == null ? '新建债务' : '编辑 · ${e.counterparty}';
  }

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
      // F62:空存量 subtype 回落 creditLoan(场景一,与创建默认一致)。
      _subtypeKey = e.subtype.isEmpty ? DebtSubtypes.creditLoan : e.subtype;
      // 出账方式回填:无挂接卡 = 独立账单(e招贷口径,2026-10-08 解挂存量)。
      if (_subtypeKey == DebtSubtypes.cardLoan) {
        _cardLoanIndependent = (e.collectionAccountId ?? '').isEmpty;
      }
      // 卡贷编辑:回填挂接卡(collectionAccountId 语义 = 并账信用卡)。
      if (_subtypeKey == DebtSubtypes.cardLoan &&
          (e.collectionAccountId ?? '').isNotEmpty) {
        _cardLoanCardId = e.collectionAccountId;
      }
      // F50 编辑回填:既有开关值保持(独立账单卡贷虽不显示开关行,值也
      // 原样保留 —— 保存时透传不丢)。
      _countsTowardCardLimit = e.countsTowardCardLimit;
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
    // F59 FR-5:全字段首改即脏(controller 口径 —— 文本字段统一覆盖)。
    // 注册在编辑态预填之后 → initState 预填不置脏;运行期程序化回填走
    // [_prefilling] 抑制窗(见 _refillCreditCardFields)。
    for (final c in [
      _counterpartyCtrl,
      _principalCtrl,
      _rateCtrl,
      _ccBillingDayCtrl,
      _ccRepaymentDayCtrl,
      _ccLimitCtrl,
      _ccAnnualFeeCtrl,
      _guarantorNameCtrl,
      _guarantorContactCtrl,
      _termPeriodsCtrl,
      _clBillDayCtrl,
      _clRepayDayCtrl,
      _ccFeeCtrl,
      _waiverCtrl,
    ]) {
      c.addListener(_markDirty);
    }
  }

  @override
  void dispose() {
    // F59 FR-5:离开表单清注入标题(双保险之一;另一道 = shell scrubber
    // key-diff)。guarded getIt:stripped 测试 harness 未注册 port 时跳过。
    scheduleDetailTitleClear();
    _counterpartyCtrl.dispose();
    _principalCtrl.dispose();
    _rateCtrl.dispose();
    _ccBillingDayCtrl.dispose();
    _ccRepaymentDayCtrl.dispose();
    _ccLimitCtrl.dispose();
    _ccAnnualFeeCtrl.dispose();
    _termPeriodsCtrl.dispose();
    _ccFeeCtrl.dispose();
    _clBillDayCtrl.dispose();
    _clRepayDayCtrl.dispose();
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
        // F62:灰显过滤候选池(全量账户经 userVisible 滤 isSystem 载体户,
        // 资产在前 —— 兼容项先见;FR-3 载体不可见语义延续)。
        _pickerPool = AccountVisibility.userVisible(
            [..._assetAccounts, ...list.where((a) => a.accountType != AccountType.asset)]);
        _accountsLoading = false;
        _refillCreditCardFields();
        // 独立账单卡贷(如 e招贷)编辑:账单日/还款日回填自挂靠贷款账户
        //(账户列 creditBillingDay/creditRepaymentDay,账户编辑可改)。
        if (_isCardLoan && _cardLoanIndependent && _existing != null) {
          final acc = list
              .where((a) => a.id == _existing!.accountId)
              .firstOrNull;
          if (acc != null) {
            _clBillDayCtrl.text = acc.creditBillingDay?.toString() ?? '';
            _clRepayDayCtrl.text = acc.creditRepaymentDay?.toString() ?? '';
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _accountsLoading = false);
    }
  }

  // ===================== 子类型 / 信用卡区 helpers =====================

  bool get _isCreditCard => _subtypeKey == DebtSubtypes.creditCard;

  // ===================== 卡贷(F48)helpers =====================

  bool get _isCardLoan => _subtypeKey == DebtSubtypes.cardLoan;

  /// F50:额度占用开关行仅当「卡贷 + 并账模式 + 已挂接卡」显示 —— 独立
  /// 账单/未挂接卡的分期不存在「占卡额度」语义。
  bool get _showCardLimitSwitch =>
      _isCardLoan &&
      !_cardLoanIndependent &&
      (_cardLoanCardId ?? '').isNotEmpty;

  /// F50 债级开关行「计入挂接卡额度占用」:默认开;银行备用金类独立
  /// 额度、不占卡额度的分期可置关。值随表单保存写入(全链路透传)。
  /// 外壳用 Material + shape(SwitchListTile 须以 Material 为最近祖先,
  /// 否则 DecoratedBox 会盖掉水波纹并触发断言)。
  Widget _cardLimitSwitchField() {
    return Material(
      key: const ValueKey('countsTowardCardLimitRow'),
      color: context.yucai.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: context.yucai.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile(
        key: const ValueKey('countsTowardCardLimitSwitch'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 13),
        title: Text('计入挂接卡额度占用',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: context.yucai.fg)),
        subtitle: Text('银行备用金类独立额度、不占卡额度的分期可关闭',
            style: TextStyle(
                fontSize: 11.5, height: 1.4, color: context.yucai.muted)),
        value: _countsTowardCardLimit,
        onChanged: (v) {
          _markDirty(); // F59 FR-5
          setState(() => _countsTowardCardLimit = v);
        },
        // 照 template_form 自动记账开关先例(activeThumbColor,token 化 accent)。
        activeThumbColor: context.yucai.accent,
      ),
    );
  }

  /// 信用卡候选(挂接并账卡)。
  List<Account> get _cardAccounts => _accounts
      .where((a) => a.category == AccountCategory.creditCard)
      .toList();

  /// 卡贷生效规则:月度按日,锚放款日(起始日日号;普通路径沿用 [_rule])。
  RecurrenceRule get _effectiveRule => _isCardLoan
      ? RecurrenceRule(
          cycle: RecurrenceCycle.monthly,
          interval: 1,
          monthlyMode: RecurrenceMonthlyMode.byDate)
      : _rule;

  /// F57 首期锚点生效值:仅「创建态 + 卡贷 + 并入模式」消费 —— 编辑态排除
  /// (选项是生成期参数,编辑不重排守卫既有;同时堵 dueDate 脱钩通道:
  /// 编辑提交的 effectiveDue 取自 _effectiveDates,不得因锚点分叉),独立
  /// 账单无此分歧(切独立后残留的 true 不生效,生成行为与现状逐位一致)。
  bool get _firstPeriodFromDisbursement => !_isEdit &&
      _isCardLoan &&
      !_cardLoanIndependent &&
      _firstPeriodCurrent;

  /// F57 副行实例化日期(yyyy-MM-dd):当期 = 起始日本身;次月 =
  /// nextAfter(起始日, 卡贷生效规则)—— 与 DS 生成器同一 pinned 契约
  /// (byDate 次月推进 + 月末钳制)。起始日未选 → null(副行退化为口径描述)。
  String? _anchorDateLabel(bool current) {
    final s = _startDate;
    if (s == null) return null;
    final d = current
        ? DateTime.utc(s.year, s.month, s.day)
        : nextAfter(DateTime.utc(s.year, s.month, s.day), _effectiveRule);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  /// 卡贷名义年化 %(仅展示/落库):月费率 × 12(银行现金分期口径)。
  double get _cardLoanAnnualRatePct {
    final p = (double.tryParse(_principalCtrl.text) ?? 0) * 100;
    final fee = (double.tryParse(_ccFeeCtrl.text) ?? 0) * 100;
    if (p <= 0 || fee < 0) return 0;
    return fee / p * 12 * 100;
  }

  /// 每期手续费(分);空/非法 = 0。
  int _cardLoanFeeCents() =>
      ((double.tryParse(_ccFeeCtrl.text.trim()) ?? 0) * 100).round();

  /// F49 FR-3 → F62 演进:普通贷款「关联账户」字段整体退役(载体户隐形,
  /// ADR-3);唯一存留的手选账户 = 信用卡消费分期的挂卡账户(信用卡永非
  /// isSystem 载体,天然可见)。灰显过滤候选池 [_pickerPool] 同源
  /// userVisible(滤载体),见 _loadAccounts。

  Account? get _selectedAccount =>
      _accounts.where((a) => a.id == _accountId).cast<Account?>().firstWhere(
            (_) => true,
            orElse: () => null,
          );

  /// F62:下拉 value ⊆ items 不变量(F49 retention 语义延续)—— 候选池外
  /// 的存留值(测试/深链 seed 未列示账户,或加载间隙)渲染为空选择而非
  /// DropdownButton 断言;池就绪后(同 id 在列)自动恢复回显。
  String? _poolValue(String? id) =>
      (id != null && _pickerPool.any((a) => a.id == id)) ? id : null;

  void _refillCreditCardFields() {
    // F59 FR-5:账户联动回填是程序化写入(非用户编辑信用卡字段),经
    // 抑制窗不置脏(触发方 _onAccountChanged/subtype onTap 自身已置脏)。
    _prefilling = true;
    try {
      _refillCreditCardFieldsUnchecked();
    } finally {
      _prefilling = false;
    }
  }

  void _refillCreditCardFieldsUnchecked() {
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

  /// F33-T6 FR-4 → F62 收窄:当前选择是否构成 subtype × 账户类别不一致。
  /// 判定收敛在 [DebtSubtypeAffinity.isConflict](category null / other 恒 false)。
  /// F62:新建态经灰显过滤不可能冲突(ADR-2),警示条仅编辑态渲染 ——
  /// 存量冲突数据 = 数据修复入口(design Risks)。
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
    _markDirty(); // F59 FR-5:字段首改即脏
    setState(() {
      _accountId = v;
      _refillCreditCardFields();
    });
    // F33-T5 创建自动归位(design LLD ②):仅创建模式且用户未手动碰过 subtype
    // 时按账户类别联动默认值;编辑模式不归位(存量修正靠编辑自由改)。
    // F62 后唯一手选账户 = 信用卡消费分期挂卡(creditCard 恒 credit_card),
    // 联动实际为不动点 —— 逻辑保留(数据源 DebtSubtypeAffinity 不变)。
    if (_isEdit || _subtypeTouched) return;
    final d = DebtSubtypeAffinity.defaultSubtypeFor(
        _selectedAccount?.category.name);
    if (d != null) setState(() => _subtypeKey = d);
  }

  /// F62 FR-1:场景卡/二级/更多枚举选择 → subtype 推导(取代 10 术语卡
  /// 直选)。卡贷固定按期数;切走 credit_card 清空挂卡;**切入 credit_card
  /// 时仅保留信用卡类账户**(seed/编辑存量挂的 loan/资产户清空 —— 镜像旧
  /// debtType 直选语义:不兼容值不作灰显回显;评审 I-1;value ⊆ items 由
  /// [_poolValue] 双保险)。
  void _onScenarioSelected(String key) {
    _markDirty(); // F59 FR-5
    setState(() {
      _subtypeKey = key;
      _subtypeTouched = true;
      if (key == DebtSubtypes.cardLoan) _byPeriods = true;
      if (key != DebtSubtypes.creditCard ||
          _selectedAccount?.category != AccountCategory.creditCard) {
        _accountId = null;
      }
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
    if (mounted) {
      _markDirty(); // F59 FR-5:暂存新合同文件 = 用户编辑
      setState(() => _stagedFile = staged);
    }
  }

  /// 移除仅作用于编辑态已有附件;已暂存新文件时重新选择即替换。
  Future<void> _removeExistingAttachment() async {
    final e = _existing;
    if (e == null || _stagedFile != null) return;
    await GetIt.instance<ContractAttachmentStore>().remove(e.id);
    if (mounted) {
      _markDirty(); // F59 FR-5:移除既有附件 = 用户编辑
      setState(() => _existingAttachmentName = null);
    }
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
    // 卡贷(F48):每期 = 本金/N + 固定手续费(银行口径),与 DS 生成逐位一致。
    if (_isCardLoan) {
      final feeCents = _cardLoanFeeCents();
      final principalCents = (p * 100).round();
      final base = principalCents ~/ n;
      final rows = <AmortizationPreviewRow>[
        for (var i = 0; i < (n < 5 ? n : 5); i++)
          AmortizationPreviewRow(
            index: i + 1,
            date: dates[i],
            principal: (i == n - 1
                    ? principalCents - base * (n - 1)
                    : base) /
                100.0,
            interest: feeCents / 100.0,
          ),
      ];
      return AmortizationPreviewData(
        label: '每期入账单',
        headlineAmount: (base + feeCents) / 100.0,
        rows: rows,
        n: n,
        totalInterest: feeCents * n / 100.0,
        totalPayment: p + feeCents * n / 100.0,
        annualRate: _cardLoanAnnualRatePct,
      );
    }
    final rate = annualRate / 100;
    // 期利率 = 年利率 × 周期年化长度(月度单间隔 = rate/12,与旧口径一致)。
    final r = rate * periodYears(_effectiveRule);
    final waiver = _waiverCents();
    final monthly = _effectiveRule.cycle == RecurrenceCycle.monthly;

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

  /// F63 FR-2:可提交聚合(原 toast 逐条条件的合集;行内 validator 承载
  /// 原因句,提交钮随本门禁用 —— 空/缺选不弹 toast)。
  bool get _canSubmit {
    if (_counterpartyCtrl.text.trim().isEmpty) return false;
    if (_isCreditCard && (_accountId == null || _accountId!.isEmpty)) {
      return false;
    }
    if (_isCardLoan &&
        !_cardLoanIndependent &&
        (_cardLoanCardId == null || _cardLoanCardId!.isEmpty)) {
      return false;
    }
    if (_isCardLoan && _cardLoanIndependent && !_isEdit) {
      final bill = int.tryParse(_clBillDayCtrl.text);
      final repay = int.tryParse(_clRepayDayCtrl.text);
      if (bill == null || bill < 1 || bill > 31 ||
          repay == null || repay < 1 || repay > 31) {
        return false;
      }
    }
    final principal = double.tryParse(_principalCtrl.text) ?? 0;
    if (_principalCtrl.text.isEmpty || principal <= 0) return false;
    final rate = _isCardLoan
        ? _cardLoanAnnualRatePct / 100
        : (double.tryParse(_rateCtrl.text) ?? 0) / 100;
    if (!_isCardLoan && (_rateCtrl.text.isEmpty || rate < 0)) return false;
    if (!_isEdit && _disbursementAccountId == null) return false;
    if (_startDate == null) return false;
    if (_effectiveDates().isEmpty) return false;
    if (!_byPeriods && _dueDate!.isBefore(_startDate!)) return false;
    return true;
  }

  Future<void> _submit() async {
    // F63 FR-2:字段校验改行内 + 按钮门(原 toast 逐条报错退役)。
    if (!_canSubmit) return;
    // F62 ADR-3:普通贷款「关联账户」字段退役(载体户隐形,保存时自动建);
    // 信用卡消费分期(credit_card)仍需手选挂卡账户(债务落在真卡上)。
    final principal = double.tryParse(_principalCtrl.text) ?? 0;
    // 输入为百分数(如 5 表示 5%),存储为小数 0.05 —— 与预览公式同口径
    // (user-acceptance 修复:此前漏 /100,5% 被存成 500% 年化,期次利息 ×100)。
    // 卡贷年利率不手填,由月费率推导(名义年化 = 月费率 × 12)。
    final rate = _isCardLoan
        ? _cardLoanAnnualRatePct / 100
        : (double.tryParse(_rateCtrl.text) ?? 0) / 100;
    // 到账账户必选(创建):借款金额必须落到一个资产账户,否则后续还款会把
    // 还款账户扣成负数(账不平)。
    final dates = _effectiveDates();
    // 按期数模式:到期日 = 末个发生日(服务端按期数推导,此处供展示/编辑)。
    final effectiveDue = dates.last;

    if (!(_formKey.currentState?.validate() ?? false)) {
      // 段③高级默认折叠:必填字段(卡贷每期手续费等)校验失败时若无动作
      // = 无声死区 → 自动展开显露行内错误(R21 规范 E1 行内校验,不 toast
      // 弹射;评审 I-3)。
      if (!_advancedOpen) setState(() => _advancedOpen = true);
      return;
    }
    _formKey.currentState?.save();
    _submitted = true;
    final principalCents = (principal * 100).round();
    final bloc = context.read<DebtBloc>();
    await _persistCreditCardFieldsIfNeeded();
    final e = _existing;
    if (e != null) {
      // F49 FR-1 编辑切换同步(评审补,闭合中间态):编辑卡贷切换出账方式时
      // 同步其账户标记 —— 并入→独立:载体户 isSystem→false(转真实账户,
      // 账单日经「账户→编辑」补);独立→并入:isSystem→true 且清空账单日/
      // 还款日(转载体,账单语义随挂接卡走);无切换/非卡贷(含 subtype
      // 切走/切入卡贷)= 零动作(切入场景账户可能是用户手建真实账户,
      // 置位即误隐藏真账户)。
      //
      // 通道:AccountRepository.update 三态路由 —— guest/离线本地落库即
      // 生效;bound 在线远端 proto 无 is_system 字段 → 等价 no-op(NFR-1
      // 镜像边界,与建户置位同口径)。紧随(先于)债务更新 dispatch、
      // best-effort:失败不阻断债务保存。注意:启动 repair
      // (runF49CarrierHideRepair)为一次性 marker 门控的存量修复,不收敛
      // 切换同步失败的标记残留 —— 残留仅能再次切换(重走本路径)或手工
      // 账户编辑恢复。
      if (e.subtype == DebtSubtypes.cardLoan && _isCardLoan) {
        final wasIndependent = (e.collectionAccountId ?? '').isEmpty;
        final account =
            _accounts.where((a) => a.id == e.accountId).firstOrNull;
        if (account != null) {
          if (!wasIndependent && _cardLoanIndependent) {
            try {
              await getIt<AccountRepository>().update(UpdateAccountParams(
                id: account.id,
                version: account.version,
                isSystem: false,
              ));
            } catch (_) {}
          } else if (wasIndependent && !_cardLoanIndependent) {
            try {
              await getIt<AccountRepository>().update(UpdateAccountParams(
                id: account.id,
                version: account.version,
                isSystem: true,
                clearCreditScheduleDays: true,
              ));
            } catch (_) {}
          }
        }
      }
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
        // 卡贷:挂接卡可换(并账目标);排期本身不重排(DS 守卫)。独立账单
        // 模式 → 解挂(每期留贷款账户,账单制还款)。
        collectionAccountId: _isCardLoan
            ? (_cardLoanIndependent ? null : _cardLoanCardId)
            : e.collectionAccountId,
        amortizationIndex: _amortization.index,
        dueDate: effectiveDue,
        termPeriods: _byPeriods ? dates.length : 0,
        cycle: _effectiveRule.cycleInt,
        interval: _effectiveRule.interval,
        weekdayMask: _effectiveRule.weekdayMask,
        monthlyMode: _effectiveRule.monthlyModeInt,
        nth: _effectiveRule.nth,
        interestWaivedCents: _waiverCents(),
        // F50 债级开关随保存写入(编辑回填值或切换后的新值)。
        countsTowardCardLimit: _countsTowardCardLimit,
      )));
    } else {
      // 卡贷(F48):债务落在自动创建的贷款类负债户(用户不手选);失败则
      // 回滚提交态留在表单。F62 ADR-3:普通贷款同范式 —— 表单不再出现
      // 「关联账户」字段,accountId 空 → 自动创建隐藏载体户(isSystem 既有
      // 机制,复用卡贷建户路径);family 亲和 otherLiability(白名单数据源
      // DebtSubtypeAffinity),其余 loan —— 不制造编辑态存量冲突。
      // credit_card = 用户所选挂卡账户;深链/测试 seed 的 accountId 直用。
      var accountForParams = '';
      if (_isCardLoan) {
        final cp = _counterpartyCtrl.text.trim();
        final created = await getIt<AccountRepository>().create(
            CreateAccountParams(
          name: '${cp.isEmpty ? '卡贷' : cp} · 卡贷',
          accountType: AccountType.liability,
          category: AccountCategory.loan,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          ownership: Ownership.personal,
          notes: '信用卡贷款(卡贷)自动创建',
          // F49 FR-1 语义边界:并入模式 = 纯账务载体(银行 app 无此账户)
          // → isSystem=true,展示层隐藏、金额计算照常;独立账单模式 =
          // 真实账户(e招贷,账单制面板/repayBill 挂其详情页)→ false,
          // 永不隐藏。
          isSystem: !_cardLoanIndependent,
          // 独立账单(如 e招贷):账单日/还款日随建户写入 —— 详情账单制
          // 面板与一键整单还款据此启用。
          creditBillingDay: _cardLoanIndependent
              ? int.tryParse(_clBillDayCtrl.text)
              : null,
          creditRepaymentDay: _cardLoanIndependent
              ? int.tryParse(_clRepayDayCtrl.text)
              : null,
        ));
        var newId = '';
        created.fold((f) {
          newId = '';
          AppToast.show(context, f.displayMessage, type: ToastType.error);
        }, (a) => newId = a.id);
        if (newId.isEmpty) {
          setState(() => _submitted = false);
          return;
        }
        accountForParams = newId;
      } else if ((_accountId ?? '').isNotEmpty) {
        accountForParams = _accountId!;
      } else {
        final cp = _counterpartyCtrl.text.trim();
        final created = await getIt<AccountRepository>().create(
            CreateAccountParams(
          name: '${cp.isEmpty ? '债务' : cp} · 债务',
          accountType: AccountType.liability,
          category: _subtypeKey == DebtSubtypes.family
              ? AccountCategory.otherLiability
              : AccountCategory.loan,
          currencyCode: 'CNY',
          initialBalanceCents: 0,
          ownership: Ownership.personal,
          notes: '债务自动创建管理账户',
          // 载体户隐形(F62 FR-3):纯账务载体,展示层隐藏、金额计算照常。
          isSystem: true,
        ));
        var newId = '';
        created.fold((f) {
          newId = '';
          AppToast.show(context, f.displayMessage, type: ToastType.error);
        }, (a) => newId = a.id);
        if (newId.isEmpty) {
          setState(() => _submitted = false);
          return;
        }
        accountForParams = newId;
      }
      final effRule = _effectiveRule;
      bloc.add(CreateDebtRequested(CreateDebtParams(
        accountId: accountForParams,
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
        // 卡贷:collectionAccountId 语义 = 并账挂接的信用卡;独立账单
        // 模式 → null(每期留贷款账户,账单制还款)。
        collectionAccountId: _isCardLoan
            ? (_cardLoanIndependent ? null : _cardLoanCardId)
            : null,
        cycle: effRule.cycleInt,
        interval: effRule.interval,
        weekdayMask: effRule.weekdayMask,
        monthlyMode: effRule.monthlyModeInt,
        nth: effRule.nth,
        termPeriods: _byPeriods ? dates.length : 0,
        interestWaivedCents: _waiverCents(),
        billingDay: 0,
        flatFeeCents: _isCardLoan ? _cardLoanFeeCents() : 0,
        // F50 债级开关随创建写入(默认 true;备用金类可切关)。
        countsTowardCardLimit: _countsTowardCardLimit,
        // F57 首期锚点随创建透传(默认 false = 放款次月;独立模式恒 false)。
        firstPeriodFromDisbursement: _firstPeriodFromDisbursement,
      )));
    }
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '请输入$label' : null;

  // ===================== build =====================

  @override
  Widget build(BuildContext context) {
    // F59 FR-5:自带 AppBar 导航退役(BackButton/mobile 标题)—— 回退统一走
    // 顶栏面包屑 page 级 + 系统返回(经守卫);标题语义移交三级面包屑注入串
    // ([_crumbTitle],mobile 原标题串同源)。body 经 FormLeaveGuard 包裹:
    // 脏态任何离开路径弹确认,净态直走;提交成功的程序化 pop 不经 canPop
    // 判定,不受守卫影响。
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: FormLeaveGuard(
        isDirty: () => _dirty,
        child: Stack(
          children: [
            BlocListener<DebtBloc, DebtState>(
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
            // 三级面包屑注入串(新建/编辑两态);放滚动容器外(照 detail 页
            // 先例,深滚动不可依赖)。
            DetailTitleSync(title: _crumbTitle),
          ],
        ),
      ),
    );
  }

  // ----- desktop / tablet：双列（表单 | 预览）;表单列 = 渐进披露三段 -----
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

  // ----- mobile：step wizard(F62:三步映射三段,ADR-4;场景卡嵌第一步) -----
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
                  if (_step == 1) ..._settlementFields(),
                  if (_step == 2) ...[_advancedFold()],
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
            onPressed: (submitting || !_canSubmit) ? null : _submit,
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

  // ----- 表单列（desktop / tablet）:F62 三段渐进(基本 → 到账与还款 → 高级折叠) -----
  Widget _formColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ODFormSection(
          num: '1',
          title: '基本信息',
          sub: '场景 · 债权方 · 本金 · 期数',
          children: _basicInfoFields(),
        ),
        const SizedBox(height: 16),
        _ODFormSection(
          num: '2',
          title: '到账与还款',
          sub: '到账卡 · 起始日 · 挂卡(信用卡分期)',
          children: _settlementFields(),
        ),
        const SizedBox(height: 16),
        _advancedFold(),
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
            onPressed: _canSubmit ? _submit : null,
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

  // ----- 段① 基本(Step 1):场景卡首问 + 债权方/本金/期数 + 粗预览 -----
  List<Widget> _basicInfoFields() {
    return [
      // F62 FR-1 首问:产品场景卡(用户语言 → 分类推导;角标露映射;
      // 「更多类型」保底全枚举;编辑态按存量 subtype 反选)。
      _ODField(
        label: '这次借的是什么?',
        required: true,
        hint: '用生活语言作答即可,分类自动推导(角标可见)',
        child: ProductScenarioPicker(
          key: const ValueKey('scenarioPicker'),
          selectedSubtype: _subtypeKey,
          onSubtypeSelected: _onScenarioSelected,
        ),
      ),
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
      ]),
      ..._termFields(),
      // FR-4 期供实时预览(粗口径 = 本金 ÷ 期数;预览是反馈不是承诺,
      // 精算在保存后期表)。
      _roughPreviewRow(),
      // F33-T6 FR-4 → F62 退役收窄:警示条仅编辑态渲染(存量冲突 = 数据
      // 修复入口);新建态灰显过滤从源头消除冲突,不可能出现。
      if (_isEdit && _showSubtypeConflict) ...[
        const SizedBox(height: AppSpacing.sm),
        _subtypeConflictCallout(),
      ],
    ];
  }

  /// F62 FR-4:段①期供粗预览行(本金 ÷ 期数;附「以保存后生成的期表为准」)。
  Widget _roughPreviewRow() {
    final p = double.tryParse(_principalCtrl.text) ?? 0;
    final n = _byPeriods ? _termPeriods() : _effectiveDates().length;
    final per = (p > 0 && n > 0) ? p / n : null;
    final nLabel = n > 0 ? '$n' : '—';
    return Container(
      key: const ValueKey('roughPreviewRow'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: context.yucai.accentSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calculator,
                  size: 14, color: context.yucai.accentDeep),
              const SizedBox(width: 8),
              Text(
                per == null
                    ? '约 ¥—/期 · 共 $nLabel 期'
                    : '约 ¥${per.round()}/期 · 共 $nLabel 期',
                key: const ValueKey('roughPreviewAmount'),
                style: TextStyle(
                    color: context.yucai.accentDeep,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFeatures: AppTypography.tabularFigures),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            '按本金 ÷ 期数实时估算,不含利息;以保存后生成的期表为准',
            style: TextStyle(
                color: context.yucai.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
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

  // ===================== 段② 到账与还款(F62 FR-4/FR-5) =====================

  List<Widget> _settlementFields() {
    return [
      // 「钱到账到了哪张卡」(用户语言)= sourceAccount;灰显过滤仅亮资产类
      // active(ADR-2,冲突不可能选出)。
      _ODField(
        label: '钱到账到了哪张卡?',
        required: true,
        hint: '借款金额到账的资产账户(保证还款时账户不为负)',
        child: FilteredAccountPicker(
          key: const ValueKey('disbursementDropdown'),
          mode: FilteredAccountMode.disbursement,
          accounts: _pickerPool,
          value: _poolValue(_disbursementAccountId),
          hint: _accountsLoading ? '加载中…' : '选择到账的银行卡/资产账户',
          onChanged: (v) {
            _markDirty(); // F59 FR-5
            setState(() => _disbursementAccountId = v);
          },
        ),
      ),
      // F62 FR-3 载体户隐形说明(普通贷款;仅创建态 —— 编辑态债务已有
      // 载体,「保存时创建」文案失实 → 不渲染,评审 M-3)。
      if (!_isEdit && !_isCardLoan && !_isCreditCard)
        Padding(
          key: const ValueKey('carrierAutoNote'),
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.info, size: 13, color: context.yucai.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '没有「关联账户」要选 —— 系统将自动生成管理账户(保存时创建)',
                  style: TextStyle(
                      color: context.yucai.muted,
                      fontSize: 11.5,
                      height: 1.5),
                ),
              ),
            ],
          ),
        ),
      _ODField(
        label: '起始日期',
        required: true,
        child: _ODDateField(
          key: const ValueKey('startDatePicker'),
          value: _startDate,
          onChanged: (d) {
            _markDirty(); // F59 FR-5
            setState(() => _startDate = d);
          },
        ),
      ),
      // 卡贷(F48/FR-5):出账方式 / 挂卡 / 首期锚点(既有语义逐项保留)。
      if (_isCardLoan) ..._cardLoanSettlementFields(),
      // 信用卡消费分期(credit_card subtype,经「更多类型」可达):挂卡
      // 账户(灰显过滤:仅亮信用卡)+ 信用卡信息区在段③高级。
      if (_isCreditCard) ...[
        _ODField(
          label: '关联信用卡账户',
          required: true,
          hint: '这笔消费分期挂在哪张信用卡(账单随卡走)',
          child: FilteredAccountPicker(
            key: const ValueKey('accountDropdown'),
            mode: FilteredAccountMode.cardMount,
            accounts: _pickerPool,
            value: _poolValue(_accountId),
            hint: _accountsLoading ? '加载中…' : '选择信用卡账户',
            onChanged: _onAccountChanged,
            validator: (v) =>
                v == null || v.isEmpty ? '请选择关联信用卡账户' : null,
          ),
        ),
        if (_cardAccounts.isEmpty && !_accountsLoading)
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
      ],
    ];
  }

  // ===================== 卡贷(F48)段②字段组 =====================

  List<Widget> _cardLoanSettlementFields() {
    return [
      const SizedBox(height: AppSpacing.sm),
      // 出账方式(e招贷定案 2026-10-08):按银行行为问,不按金融概念问。
      _ODField(
        label: '出账方式',
        required: true,
        hint: '照抄银行 app:每期进信用卡账单,还是单出账单',
        child: _ResponsiveRadioRow(
          children: [
            _RadioCard(
              key: const ValueKey('cardLoanMode-merge'),
              icon: LucideIcons.creditCard,
              label: '并入信用卡账单',
              desc: '平安/广发现金分期',
              selected: !_cardLoanIndependent,
              onTap: () {
                _markDirty(); // F59 FR-5
                setState(() => _cardLoanIndependent = false);
              },
            ),
            _RadioCard(
              key: const ValueKey('cardLoanMode-independent'),
              icon: LucideIcons.receipt,
              label: '独立账单',
              desc: '如 e招贷 · 月度合并出账',
              selected: _cardLoanIndependent,
              onTap: () {
                _markDirty(); // F59 FR-5
                setState(() => _cardLoanIndependent = true);
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.sm),
      if (!_cardLoanIndependent)
        // F62 FR-2/FR-5:挂接卡选择器换灰显过滤(仅亮信用卡,其余灰显+原因)。
        _ODField(
          label: '挂接信用卡',
          required: true,
          hint: '每期金额自动并入该卡账单',
          child: FilteredAccountPicker(
            key: const ValueKey('cardLoanCardDropdown'),
            mode: FilteredAccountMode.cardMount,
            accounts: _pickerPool,
            value: _poolValue(_cardLoanCardId),
            hint: '选择信用卡账户',
            onChanged: (v) {
              _markDirty(); // F59 FR-5
              setState(() => _cardLoanCardId = v);
            },
            validator: (v) => v == null || v.isEmpty ? '请选择挂接的信用卡' : null,
          ),
        )
      else
        _ODField(
          label: '账单日',
          required: true,
          hint: '每月该日合并出账(如 e招贷 5 日)',
          child: TextFormField(
            key: const ValueKey('cardLoanBillDayField'),
            controller: _clBillDayCtrl,
            enabled: !_isEdit,
            decoration: _odDec(context, hint: '1-31'),
            keyboardType: TextInputType.number,
            // 编辑态字段禁用(存量经「账户→编辑」改),并入→独立切换后
            // 为空:validator 必须放行,否则 Form.validate 卡死提交
            // (F49 T10 编辑切换同步前置)。
            validator: _isEdit
                ? null
                : (v) {
                    final d = int.tryParse(v ?? '');
                    return d == null || d < 1 || d > 31 ? '账单日 1-31' : null;
                  },
          ),
        ),
      // F57 首期锚点(创建态 + 并入模式常驻,v15 形态 B):银行起扣惯例分歧
      // —— 典型银行放款次月起扣(默认,现状);平安当期起扣(首期 = 放款日
      // 当天)。副行以所选起始日实例化日期(8/2 起始 → 9/2 / 8/2),随起始日
      // 联动;独立账单模式(e招贷)无此分歧,不渲染;**编辑态整行隐藏** ——
      // 生成期参数不持久化、无法真实回填(显示默认态 = 伪造创建时选择),
      // 且编辑不重排守卫既有(区别于 F49 账单日/还款日 enabled:!_isEdit:
      // 那两列有账户列存量真值可显示)。
      if (!_cardLoanIndependent && !_isEdit) ...[
        const SizedBox(height: AppSpacing.sm),
        KeyedSubtree(
          key: const ValueKey('firstPeriodAnchorRow'),
          child: _ODField(
            label: '首期锚点',
            required: true,
            hint: '两种起扣惯例都存在:典型银行次月起扣,平安当期起扣',
            child: _ResponsiveRadioRow(
              children: [
                _RadioCard(
                  key: const ValueKey('firstPeriodAnchor-nextMonth'),
                  icon: LucideIcons.calendarClock,
                  label: '放款次月',
                  desc: _anchorDateLabel(false) == null
                      ? '默认 · 首期 = 放款日次月同日'
                      : '默认 · 首期 ${_anchorDateLabel(false)} 出账',
                  selected: !_firstPeriodCurrent,
                  onTap: () {
                    _markDirty(); // F59 FR-5
                    setState(() => _firstPeriodCurrent = false);
                  },
                ),
                _RadioCard(
                  key: const ValueKey('firstPeriodAnchor-current'),
                  icon: LucideIcons.zap,
                  label: '放款当期',
                  desc: _anchorDateLabel(true) == null
                      ? '平安口径 · 首期 = 放款日当天'
                      : '平安口径 · 首期 ${_anchorDateLabel(true)} 出账',
                  selected: _firstPeriodCurrent,
                  onTap: () {
                    _markDirty(); // F59 FR-5
                    setState(() => _firstPeriodCurrent = true);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
      if (_cardLoanIndependent) ...[
        const SizedBox(height: AppSpacing.sm),
        _ODField(
          label: '还款日',
          required: true,
          hint: '出账后该日前一次还清(如 e招贷 23 日)',
          child: TextFormField(
            key: const ValueKey('cardLoanRepayDayField'),
            controller: _clRepayDayCtrl,
            enabled: !_isEdit,
            decoration: _odDec(context, hint: '1-31'),
            keyboardType: TextInputType.number,
            // 同上(账单日):编辑态禁用字段不参与校验,切换后为空不阻断提交。
            validator: _isEdit
                ? null
                : (v) {
                    final d = int.tryParse(v ?? '');
                    return d == null || d < 1 || d > 31 ? '还款日 1-31' : null;
                  },
          ),
        ),
        if (_isEdit)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              '存量贷款的账单日/还款日在「账户 → 编辑」中修改',
              style: TextStyle(fontSize: 11.5, color: context.yucai.muted),
            ),
          ),
      ],
      Padding(
        key: const ValueKey('cardLoanAnchorHint'),
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          _cardLoanIndependent
              ? '每期于放款对应日(起始日每月同日)计入账单;每月账单日合并出账,还款日前一次还清,不占信用卡额度'
              : '每期于放款对应日(起始日每月同日)入卡占用额度,随该卡还款日一起还',
          style: TextStyle(fontSize: 11.5, color: context.yucai.muted),
        ),
      ),
      // 出账节奏提示(F57 联动;原日期区随起始日迁入段②)。
      Padding(
        key: const ValueKey('cardLoanScheduleHint'),
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          // F57:并入模式首期随锚点选项联动;独立模式/编辑态无锚点选项,
          // 保持既有中性表述(现状语义)。
          _cardLoanIndependent || _isEdit
              ? '出账节奏:首期 = 放款日的下个每月对应日,此后每月一期;到期日按末期推导'
              : _firstPeriodCurrent
                  ? '出账节奏:首期 = 放款日当天(锚点「放款当期」),此后每月一期;到期日按末期推导'
                  : '出账节奏:首期 = 放款日的下个每月对应日(锚点「放款次月」),此后每月一期;到期日按末期推导',
          style: TextStyle(fontSize: 11.5, color: context.yucai.muted, height: 1.5),
        ),
      ),
    ];
  }

  // ----- 段③ 高级(F62 FR-4:默认折叠,折叠头「已收起 N 项」) -----

  /// 高级段字段清单(动态按 subtype 组合;N = 清单长度)。
  List<Widget> _advancedChildren() {
    return [
      // 利率方式:非卡贷 = 年利率 + 摊还方法;卡贷 = 每期手续费(年利率由
      // 月费率推导,摊销固定,二者不手填)。
      if (!_isCardLoan) ...[
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
                  onTap: () {
                    _markDirty(); // F59 FR-5
                    setState(() => _amortization = m);
                  },
                ),
            ],
          ),
        ),
      ] else ...[
        _ODField(
          label: '每期手续费',
          required: true,
          hint: '银行现金分期口径,按全额本金每期收取',
          child: TextFormField(
            key: const ValueKey('cardLoanFeeField'),
            controller: _ccFeeCtrl,
            decoration:
                _odDec(context, prefix: '${currencySymbol('CNY')} ', hint: '0.00'),
            style: TextStyle(
                fontSize: 14,
                color: context.yucai.fg,
                fontFeatures: AppTypography.tabularFigures),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => _required(v, '每期手续费'),
            onChanged: (_) => setState(() {}),
          ),
        ),
        Padding(
          key: const ValueKey('cardLoanRateHint'),
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '名义年化 ${_cardLoanAnnualRatePct.toStringAsFixed(2)}%(月费率 × 12,银行现金分期口径;每期 = 本金/期数 + 手续费)',
            style:
                TextStyle(fontSize: 11.5, color: context.yucai.muted),
          ),
        ),
      ],
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
      // F50 债级开关行:仅挂接卡贷(并账 + 已选卡)显示,默认开。
      if (_showCardLimitSwitch) _cardLimitSwitchField(),
      // 信用卡信息区(仅 subtype == credit_card,经「更多类型」可达)。
      if (_isCreditCard) ..._creditCardFields(),
      // 担保人与合同(选填;合同文件保存在本机)。
      _guarantorContractFields(),
    ];
  }

  /// 高级折叠卡:折叠头「高级 + 已收起 N 项」(展开后「已展开」);折叠实现
  /// 用 Offstage —— 字段保持挂载,Form validator 照常参与提交校验(必填
  /// 语义零弱化),仅移出视觉主路径(渐进披露)。
  Widget _advancedFold() {
    final children = _advancedChildren();
    return Container(
      key: const ValueKey('advancedFold'),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const ValueKey('advancedFoldToggle'),
            onTap: () => setState(() => _advancedOpen = !_advancedOpen),
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                AnimatedRotation(
                  turns: _advancedOpen ? 0.25 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(LucideIcons.chevronRight,
                      size: 15, color: context.yucai.muted),
                ),
                const SizedBox(width: 9),
                const Text('高级',
                    style: TextStyle(
                        fontSize: 16,
                        fontFamily: AppTypography.displayFamily,
                        fontFamilyFallback: AppTypography.displayFallback)),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    _advancedOpen ? '已展开' : '已收起 ${children.length} 项',
                    key: ValueKey(
                        _advancedOpen ? 'advancedHintOpen' : 'advancedHintClosed'),
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 12, color: context.yucai.muted),
                  ),
                ),
              ],
            ),
          ),
          // 不用 AnimatedSize:desktop 表单列在 IntrinsicHeight(Row)内,
          // 动画中间态尺寸 ≠ intrinsic 高度 → 溢出断言(照 _ResponsiveRadioRow
          // 同裁定)。Offstage 直接切换:字段保持挂载,validator 照常参与。
          Offstage(
            offstage: !_advancedOpen,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i < children.length - 1)
                      const SizedBox(height: 18),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----- 期数或月供(段①:周期规则入口与期数双模式;起始日随段②) -----

  /// 当前生效的发生日序列(按期数模式含推导;空 = 输入不全)。
  List<DateTime> _effectiveDates() {
    if (_startDate == null) return const [];
    final term = _termPeriods();
    if (_byPeriods) {
      if (term <= 0) return const [];
      // F57 首期锚点(当期):首期 = 起始日本身,此后照既有逐月推进
      // (nextAfter 链式,月末钳制 pinned 契约)—— 预览与提交同源;次月 =
      // 现状 scheduleDatesFrom 原样。镜像 DS _cardLoanScheduleDates 分叉。
      if (_firstPeriodFromDisbursement) {
        return [
          DateTime.utc(_startDate!.year, _startDate!.month, _startDate!.day),
          ...occurrences(_startDate!, _effectiveRule, term - 1),
        ];
      }
      return scheduleDatesFrom(_effectiveRule, _startDate!, _startDate!, term);
    }
    if (_dueDate == null) return const [];
    return scheduleDatesFrom(_effectiveRule, _startDate!, _dueDate!, 0);
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
    if (rule != null) {
      _markDirty(); // F59 FR-5:改周期规则 = 用户编辑
      setState(() => _rule = rule);
    }
  }

  List<Widget> _termFields() {
    final dates = _effectiveDates();
    final periods = dates.length;
    final derivedDue = dates.isEmpty ? null : dates.last;
    return [
      // 周期规则入口(lumpSum 单期/卡贷不参与 —— 卡贷固定 = 月度按日锚账单日)。
      if (!_isCardLoan && _amortization != AmortizationMethod.lumpSum)
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
      if (!_isCardLoan && _amortization != AmortizationMethod.lumpSum) ...[
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<bool>(
          key: const ValueKey('termModeToggle'),
          segments: const [
            ButtonSegment(value: false, label: Text('按到期日')),
            ButtonSegment(value: true, label: Text('按期数')),
          ],
          selected: {_byPeriods},
          onSelectionChanged: (sel) {
            _markDirty(); // F59 FR-5
            setState(() => _byPeriods = sel.first);
          },
        ),
      ],
      if (!_isCardLoan || _byPeriods) ...[
        const SizedBox(height: AppSpacing.sm),
        _ODGrid2(children: [
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
                onChanged: (d) {
                  _markDirty(); // F59 FR-5
                  setState(() => _dueDate = d);
                },
              ),
            ),
        ]),
      ],
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

  // F62:三步标签映射三段(基本 / 到账与还款 / 高级)。
  static const _labels = ['基本', '到账与还款', '高级'];

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

/// 单选卡(摊还方法/出账方式/首期锚点)。对齐 OD .radio:32px icon tile(选中金实心)
/// + label + 可选 desc。复用 TypeTabs 金选中态视觉。
/// [onTap] == null → 禁用态视觉(当前无调用方传 null,保留通用禁用样式)。
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
          // F38:归一化 UTC 零点(同 date_picker_input 惯例)。
          if (picked != null) {
            onChanged(DateTime.utc(picked.year, picked.month, picked.day));
          }
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
