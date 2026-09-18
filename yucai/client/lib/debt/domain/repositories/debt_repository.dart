import 'package:dartz/dartz.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

abstract class DebtRepository {
  /// 列出债务。`typeFilter` 非空时只返回该方向(borrowedIn / borrowedOut)。
  Future<Either<Failure, List<Debt>>> list({DebtType? typeFilter});
  Future<Either<Failure, DebtDetail>> get(String id);
  Future<Either<Failure, Debt>> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex, // AmortizationMethod.index
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
    required DebtType type,
    String subtype = '',
    String? sourceAccountId,
    String contact = '',
    String contractRef = '',
    String guarantorName = '',
    String guarantorContact = '',
    String? collectionAccountId,
    int cycle = 2,
    int interval = 1,
    int weekdayMask = 0,
    int monthlyMode = 0,
    int nth = 0,
    int termPeriods = 0,
    int interestWaivedCents = 0,
  });
  Future<Either<Failure, Debt>> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
    String contact = '',
    String contractRef = '',
    String guarantorName = '',
    String guarantorContact = '',
    String? collectionAccountId,
    int? amortizationIndex,
    DateTime? dueDate,
    int termPeriods = 0,
    int? cycle,
    int? interval,
    int? weekdayMask,
    int? monthlyMode,
    int? nth,
    int? interestWaivedCents,
  });
  Future<Either<Failure, void>> delete(String id);

  /// 标记已还(历史还款,不记账;已还期次拒绝)。
  Future<Either<Failure, PaymentEntry>> markEntryPaid({
    required String debtId,
    required String entryId,
  });
  Future<Either<Failure, PaymentEntry>> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
  });

  /// 单期改日(未还期次;已还期次冻结,目标日期撞已有期次会被拒绝)。
  Future<Either<Failure, PaymentEntry>> setPaymentDate({
    required String debtId,
    required String entryId,
    required DateTime paymentDate,
  });
  Future<Either<Failure, List<Debt>>> upcomingPayments(int daysAhead);
}
