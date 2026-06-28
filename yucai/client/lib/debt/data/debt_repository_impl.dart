import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

@LazySingleton(as: DebtRepository)
class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl(this._remote);

  final DebtRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<Debt>>> list({DebtType? typeFilter}) =>
      _guard(() => _remote.list(typeFilter: typeFilter));

  @override
  Future<Either<Failure, DebtDetail>> get(String id) =>
      _guard(() => _remote.get(id));

  @override
  Future<Either<Failure, Debt>> create({
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationIndex,
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
    required DebtType type,
    String subtype = '',
    String? sourceAccountId,
  }) =>
      _guard(() => _remote.create(
            accountId: accountId,
            counterparty: counterparty,
            interestRate: interestRate,
            amortizationIndex: amortizationIndex,
            startDate: startDate,
            dueDate: dueDate,
            totalPrincipalCents: totalPrincipalCents,
            type: type,
            subtype: subtype,
            sourceAccountId: sourceAccountId,
          ));

  @override
  Future<Either<Failure, Debt>> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
  }) =>
      _guard(() => _remote.update(
            id: id,
            counterparty: counterparty,
            interestRate: interestRate,
            version: version,
          ));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _guard(() => _remote.delete(id));

  @override
  Future<Either<Failure, PaymentEntry>> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
  }) =>
      _guard(() => _remote.recordPayment(
            debtId: debtId,
            scheduleEntryId: scheduleEntryId,
            fromAccountId: fromAccountId,
          ));

  @override
  Future<Either<Failure, List<Debt>>> upcomingPayments(int daysAhead) =>
      _guard(() => _remote.upcomingPayments(daysAhead));

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(ServerFailure(e.message ?? 'gRPC error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
