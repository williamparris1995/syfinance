import 'package:equatable/equatable.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

class Debt extends Equatable {
  const Debt({
    required this.id,
    required this.accountId,
    required this.counterparty,
    required this.interestRate,
    required this.amortization,
    required this.startDate,
    required this.dueDate,
    required this.totalPrincipalCents,
    required this.remainingPrincipalCents,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    this.type = DebtType.borrowedIn,
    this.subtype = '',
    this.contact = '',
    this.contractRef = '',
    this.collectionAccountId,
    this.nextPaymentDate,
    this.nextPaymentAmountCents = 0,
    this.nextPaymentPeriodNo = 0,
    this.remainingTrendCents = 0,
  });

  final String id;
  final String accountId; // 关联 loan 账户
  final String counterparty; // 债权方
  final double interestRate; // 年利率 %
  final AmortizationMethod amortization;
  final DateTime startDate;
  final DateTime dueDate;
  final int totalPrincipalCents;
  final int remainingPrincipalCents;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  /// 债务方向:borrowedIn(借入/负债,默认)/ borrowedOut(借出/应收)。
  /// 默认 borrowedIn 以保持既有调用点(data mapper / 测试)无需改动即可编译。
  final DebtType type;

  /// 债务子类型(对应 DebtSubtypes / ReceivableSubtypes const 值,纯 String)。
  /// 默认 '' 以保持既有调用点(data mapper / 测试)无需改动即可编译。
  final String subtype;

  /// 应收/负债追踪字段(receivables 对齐,Task 8)。全部带默认值,
  /// 既有 borrowedIn seed / 测试调用点不传也编译过。borrowedIn 侧数据空/0,
  /// mapper 直传空/0,自动适配。
  final String contact; // 联系人/对方
  final String contractRef; // 合同/借条编号
  final String? collectionAccountId; // 回款关联账户('' → null)
  final DateTime? nextPaymentDate; // 下一期还款日(date-only string → DateTime)
  final int nextPaymentAmountCents; // 下一期还款金额(本+利)
  final int nextPaymentPeriodNo; // 下一期期数
  final int remainingTrendCents; // 剩余趋势(用于图表/预警,服务端算)

  /// 已还比例 (total-remaining)/total,0~1。total=0 时 0。
  double get progressRatio => totalPrincipalCents <= 0
      ? 0
      : (totalPrincipalCents - remainingPrincipalCents) /
          totalPrincipalCents;

  @override
  List<Object?> get props => [
        id,
        version,
        accountId,
        counterparty,
        interestRate,
        amortization,
        startDate,
        dueDate,
        totalPrincipalCents,
        remainingPrincipalCents,
        createdAt,
        updatedAt,
        type,
        subtype,
        contact,
        contractRef,
        collectionAccountId,
        nextPaymentDate,
        nextPaymentAmountCents,
        nextPaymentPeriodNo,
        remainingTrendCents,
      ];
}

class PaymentEntry extends Equatable {
  const PaymentEntry({
    required this.id,
    required this.paymentDate,
    required this.principalCents,
    required this.interestCents,
    required this.totalCents,
    required this.paid,
    required this.paidCents,
    required this.transactionId,
  });

  final String id;
  final DateTime paymentDate;
  final int principalCents;
  final int interestCents;
  final int totalCents;
  final bool paid;
  final int paidCents;
  final String transactionId; // '' = 未关联交易

  /// 状态:已还(paid)/逾期(!paid && date<now)/待还(!paid && date>=now)。
  PaymentStatus get status {
    if (paid) return PaymentStatus.paid;
    return paymentDate.isBefore(DateTime.now())
        ? PaymentStatus.overdue
        : PaymentStatus.pending;
  }

  @override
  List<Object?> get props => [id, paidCents];
}

class DebtDetail extends Equatable {
  const DebtDetail({required this.debt, required this.schedule});
  final Debt debt;
  final List<PaymentEntry> schedule;
  @override
  List<Object?> get props => [debt.id];
}
