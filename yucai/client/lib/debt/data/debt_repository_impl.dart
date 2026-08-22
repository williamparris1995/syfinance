import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

@LazySingleton(as: DebtRepository)
class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl(this._remote, this._local, this._tracker);

  final DebtRemoteDataSource _remote;
  final DebtLocalDataSource _local;
  final SessionModeTracker _tracker;

  bool get _useLocal => _tracker.isGuest;

  @override
  Future<Either<Failure, List<Debt>>> list({DebtType? typeFilter}) =>
      _guard(() => _useLocal ? _local.list(typeFilter: typeFilter) : _remote.list(typeFilter: typeFilter));

  @override
  Future<Either<Failure, DebtDetail>> get(String id) =>
      _guard(() => _useLocal ? _local.get(id) : _remote.get(id));

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
    String contact = '',
    String contractRef = '',
    String? collectionAccountId,
  }) =>
      _guard(() => _useLocal ? _local.create(
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
            contact: contact,
            contractRef: contractRef,
            collectionAccountId: collectionAccountId,
          ) : _remote.create(
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
            contact: contact,
            contractRef: contractRef,
            collectionAccountId: collectionAccountId,
          ));

  @override
  Future<Either<Failure, Debt>> update({
    required String id,
    required String counterparty,
    required double interestRate,
    required int version,
    String contact = '',
    String contractRef = '',
    String? collectionAccountId,
  }) =>
      _guard(() => _useLocal ? _local.update(
            id: id,
            counterparty: counterparty,
            interestRate: interestRate,
            version: version,
            contact: contact,
            contractRef: contractRef,
            collectionAccountId: collectionAccountId,
          ) : _remote.update(
            id: id,
            counterparty: counterparty,
            interestRate: interestRate,
            version: version,
            contact: contact,
            contractRef: contractRef,
            collectionAccountId: collectionAccountId,
          ));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _guard(() => _useLocal ? _local.delete(id) : _remote.delete(id));

  @override
  Future<Either<Failure, PaymentEntry>> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
  }) =>
      _guard(() => _useLocal ? _local.recordPayment(
            debtId: debtId,
            scheduleEntryId: scheduleEntryId,
            fromAccountId: fromAccountId,
          ) : _remote.recordPayment(
            debtId: debtId,
            scheduleEntryId: scheduleEntryId,
            fromAccountId: fromAccountId,
          ));

  @override
  Future<Either<Failure, List<Debt>>> upcomingPayments(int daysAhead) =>
      _guard(() => _useLocal ? _local.upcomingPayments(daysAhead) : _remote.upcomingPayments(daysAhead));

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(ServerFailure(e.message ?? 'gRPC error'));
    } on Failure catch (f) {
      // Local data source failures pass through untouched.
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
