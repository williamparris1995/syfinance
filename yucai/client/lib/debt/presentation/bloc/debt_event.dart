import 'package:equatable/equatable.dart';

import 'package:yucai_client/debt/domain/value_objects.dart';

abstract class DebtEvent extends Equatable {
  const DebtEvent();
  @override
  List<Object?> get props => [];
}

/// 拉取债务列表。`typeFilter` 非空时只取该方向(borrowedIn/borrowedOut),
/// 为 null(默认)时不过滤 → 既有 debts_page「列出全部」行为保持不变。
class LoadDebtsRequested extends DebtEvent {
  const LoadDebtsRequested({this.typeFilter});
  final DebtType? typeFilter;
  @override
  List<Object?> get props => [typeFilter];
}

class LoadDebtRequested extends DebtEvent {
  const LoadDebtRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

/// Parameters for creating a debt. Mirrors [DebtRepository.create] but allows
/// the form to start with null dates that the UI fills in before submit.
class CreateDebtParams extends Equatable {
  const CreateDebtParams({
    required this.accountId,
    required this.counterparty,
    required this.interestRate,
    required this.amortizationIndex,
    required this.startDateOption,
    required this.dueDateOption,
    required this.totalPrincipalCents,
    this.type = DebtType.borrowedIn,
    this.subtype = '',
    this.sourceAccountId,
    this.contact = '',
    this.contractRef = '',
    this.guarantorName = '',
    this.guarantorContact = '',
    this.collectionAccountId,
    this.cycle = 2,
    this.interval = 1,
    this.weekdayMask = 0,
    this.monthlyMode = 0,
    this.nth = 0,
    this.termPeriods = 0,
    this.interestWaivedCents = 0,
    this.billingDay = 0,
    this.flatFeeCents = 0,
    // F50 债级开关:剩余本金是否计入挂接卡额度占用(默认 true)。
    this.countsTowardCardLimit = true,
    // F57 首期锚点(卡贷并入模式):true = 放款当期起扣(平安口径,首期 =
    // 放款日当天);false(默认)= 放款次月(现状)。生成期参数,物化进
    // 期表日期,不持久化为债字段(仅 local DS 消费,remote 不透传)。
    this.firstPeriodFromDisbursement = false,
  });
  final String accountId;
  final String counterparty;
  final double interestRate;
  final int amortizationIndex; // AmortizationMethod.index
  final DateTime? startDateOption;
  final DateTime? dueDateOption;
  final int totalPrincipalCents;
  /// 债务方向。默认 borrowedIn → 既有 debts_page/form 行为不变;
  /// receivables 表单显式传 borrowedOut。
  final DebtType type;
  /// 债务子类型(纯 String,无枚举映射)。默认 '' → 既有调用点编译不变。
  final String subtype;
  /// borrowedOut 双写:借出资金的来源账户(cash asset)。borrowedOut 必填;
  /// borrowedIn 忽略(不双写)。null → 空字符串 → 不双写。
  final String? sourceAccountId;
  /// 应收/负债追踪字段(receivables 对齐,Task 11)。全部带默认值,
  /// 既有 debts_page/debt_form_page 调用点不传也编译过。
  /// contact / contractRef 可选自由文本;collectionAccountId 为应收的回款
  /// 关联账户(borrowedOut 必填,服务端 application 层强制)。
  final String contact;
  final String contractRef;
  /// 担保人字段(2026-09 用户需求):可选自由文本,'' = 无。
  final String guarantorName;
  final String guarantorContact;
  final String? collectionAccountId;
  /// 周期规则(0 值 = 旧「按月」;cycle proto 序号 1-4,默认 2=monthly)。
  final int cycle;
  final int interval;
  final int weekdayMask;
  final int monthlyMode;
  final int nth;
  /// >0 = 按期数模式(N 期,due 由末个发生日推导);0 = 按到期日(默认)。
  final int termPeriods;
  /// 一次性利息减免(分,银行优惠;0 = 无)。
  final int interestWaivedCents;
  /// 卡贷(F48):月度账单日锚点 1-31(0 = 锚起始日旧行为)。普通债务恒 0。
  final int billingDay;
  /// 卡贷(F48):每期固定手续费(分,银行现金分期口径 = 按全额本金计;
  /// 0 = 常规摊销)。普通债务恒 0。
  final int flatFeeCents;
  /// F50 债级开关:剩余本金是否计入挂接卡额度占用(卡贷并账语义;默认
  /// true = 计入,备用金类独立额度置 false)。表单开关随保存携带。
  final bool countsTowardCardLimit;
  /// F57 首期锚点(卡贷并入模式):false = 放款次月(现状默认)/ true =
  /// 放款当期(平安口径,首期 = 放款日当天)。生成期参数,随创建携带;
  /// 独立账单模式不渲染选项,恒 false。
  final bool firstPeriodFromDisbursement;

  @override
  List<Object?> get props => [
        accountId,
        counterparty,
        interestRate,
        amortizationIndex,
        startDateOption,
        dueDateOption,
        totalPrincipalCents,
        type,
        subtype,
        sourceAccountId,
        contact,
        contractRef,
        guarantorName,
        guarantorContact,
        collectionAccountId,
        cycle,
        interval,
        weekdayMask,
        monthlyMode,
        nth,
        termPeriods,
        interestWaivedCents,
        billingDay,
        flatFeeCents,
        countsTowardCardLimit,
        firstPeriodFromDisbursement,
      ];
}

class CreateDebtRequested extends DebtEvent {
  const CreateDebtRequested(this.params);
  final CreateDebtParams params;
  @override
  List<Object?> get props => [params];
}

class UpdateDebtParams extends Equatable {
  const UpdateDebtParams({
    required this.id,
    required this.counterparty,
    required this.interestRate,
    required this.version,
    this.subtype = '',
    this.contact = '',
    this.contractRef = '',
    this.guarantorName = '',
    this.guarantorContact = '',
    this.collectionAccountId,
    this.amortizationIndex,
    this.dueDate,
    this.termPeriods = 0,
    this.cycle,
    this.interval,
    this.weekdayMask,
    this.monthlyMode,
    this.nth,
    this.interestWaivedCents,
    // F50 债级开关:编辑保存写入(表单加载已回填既有值;非卡贷路径恒
    // 默认 true,既有调用点编译/行为不变)。
    this.countsTowardCardLimit = true,
  });
  final String id;
  final String counterparty;
  final double interestRate;
  final int version;
  /// 债务子类型(F33-T4)。与 create 的「创建时定死」语义不同:update 侧
  /// **空串 = 不修改**(新旧 client 兼容),守卫在 DS 层(local 落
  /// Value.absent;远端直传由服务端按同语义处理)。
  final String subtype;
  /// 应收/负债追踪字段(receivables 对齐,Task 11)。全部带默认值,
  /// 既有 debts_page/debt_form_page 编辑调用点不传也编译过。
  /// 与服务端 UpdateDebt 语义一致:空 Contact/ContractRef 清字段,
  /// nil CollectionAccountID 解除关联。
  final String contact;
  final String contractRef;
  /// 担保人字段(2026-09 用户需求):与服务端 UpdateDebt 同语义,空串清字段。
  final String guarantorName;
  final String guarantorContact;
  final String? collectionAccountId;
  /// 影响期次的编辑(Google-Calendar 式:已发生期次冻结,未来重排)。
  /// null/0 = 保持现状(旧调用方行为不变)。
  final int? amortizationIndex;
  final DateTime? dueDate;
  final int termPeriods;
  final int? cycle;
  final int? interval;
  final int? weekdayMask;
  final int? monthlyMode;
  final int? nth;
  /// 一次性利息减免(分):null = 保持现状;set = 替换(0 清零)。
  final int? interestWaivedCents;
  /// F50 债级开关:剩余本金是否计入挂接卡额度占用。表单编辑随保存携带
  /// (回填值或切换后的新值);本地私有列,remote 不透传。
  final bool countsTowardCardLimit;

  @override
  List<Object?> get props =>
      [id, counterparty, interestRate, version, subtype, contact, contractRef, guarantorName, guarantorContact, collectionAccountId, amortizationIndex, dueDate, termPeriods, cycle, interval, weekdayMask, monthlyMode, nth, interestWaivedCents, countsTowardCardLimit];
}

class UpdateDebtRequested extends DebtEvent {
  const UpdateDebtRequested(this.params);
  final UpdateDebtParams params;
  @override
  List<Object?> get props => [params];
}

class DeleteDebtRequested extends DebtEvent {
  const DeleteDebtRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class MarkEntryPaidRequested extends DebtEvent {
  const MarkEntryPaidRequested({required this.debtId, required this.entryId});
  final String debtId;
  final String entryId;

  @override
  List<Object?> get props => [debtId, entryId];
}

class SetPaymentDateRequested extends DebtEvent {
  const SetPaymentDateRequested({
    required this.debtId,
    required this.entryId,
    required this.paymentDate,
  });
  final String debtId;
  final String entryId;
  final DateTime paymentDate;

  @override
  List<Object?> get props => [debtId, entryId, paymentDate];
}

class RecordPaymentRequested extends DebtEvent {
  const RecordPaymentRequested({
    required this.debtId,
    required this.scheduleEntryId,
    required this.fromAccountId,
  });
  final String debtId;
  final String scheduleEntryId;
  final String fromAccountId;

  @override
  List<Object?> get props => [debtId, scheduleEntryId, fromAccountId];
}
