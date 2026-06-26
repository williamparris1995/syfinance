import 'package:dartz/dartz.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';

abstract class DebtRepository {
  Future<Either<Failure, List<Debt>>> list();
  Future<Either<Failure, DebtDetail>> get(String id);
  Future<Either<Failure, Debt>> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex, // AmortizationMethod.index
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
  });
  Future<Either<Failure, Debt>> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
  });
  Future<Either<Failure, void>> delete(String id);
  Future<Either<Failure, PaymentEntry>> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
  });
  Future<Either<Failure, List<Debt>>> upcomingPayments(int daysAhead);
}
