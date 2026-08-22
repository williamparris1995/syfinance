import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/budget/data/budget_remote_ds.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/budget/data/budget_local_ds.dart';

@LazySingleton(as: BudgetRepository)
class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl(this._remote, this._local, this._tracker);

  final BudgetRemoteDataSource _remote;
  final BudgetLocalDataSource _local;
  final SessionModeTracker _tracker;

  bool get _useLocal => _tracker.isGuest;

  @override
  Future<Either<Failure, List<BudgetView>>> listBudgets({bool activeOnly = false}) =>
      _guard(() => _useLocal ? _local.listBudgets(activeOnly: activeOnly) : _remote.listBudgets(activeOnly: activeOnly));

  @override
  Future<Either<Failure, BudgetView>> getBudget(String id) =>
      _guard(() => _useLocal ? _local.getBudget(id) : _remote.getBudget(id));

  @override
  Future<Either<Failure, BudgetView>> getBudgetByMonth(String month) =>
      _guard(() => _useLocal ? _local.getBudgetByMonth(month) : _remote.getBudgetByMonth(month));

  @override
  Future<Either<Failure, BudgetView>> createBudget({
    required String name,
    required String month,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  }) =>
      _guard(() => _useLocal ? _local.createBudget(
            name: name,
            month: month,
            currencyCode: currencyCode,
            items: items,
          ) : _remote.createBudget(
            name: name,
            month: month,
            currencyCode: currencyCode,
            items: items,
          ));

  @override
  Future<Either<Failure, void>> deleteBudget(String id) =>
      _guard(() => _useLocal ? _local.deleteBudget(id) : _remote.deleteBudget(id));

  @override
  Future<Either<Failure, BudgetView>> addItem({
    required String budgetId,
    required String accountId,
    required int plannedAmountCents,
    String? notes,
  }) =>
      _guard(() => _useLocal ? _local.addItem(
            budgetId: budgetId,
            accountId: accountId,
            plannedAmountCents: plannedAmountCents,
            notes: notes,
          ) : _remote.addItem(
            budgetId: budgetId,
            accountId: accountId,
            plannedAmountCents: plannedAmountCents,
            notes: notes,
          ));

  @override
  Future<Either<Failure, BudgetView>> removeItem({
    required String budgetId,
    required String itemId,
  }) =>
      _guard(() => _useLocal ? _local.removeItem(
            budgetId: budgetId,
            itemId: itemId,
          ) : _remote.removeItem(
            budgetId: budgetId,
            itemId: itemId,
          ));

  @override
  Future<Either<Failure, BudgetView>> updateBudget({
    required String id,
    required String name,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  }) =>
      _guard(() => _useLocal ? _local.updateBudget(
            id: id,
            name: name,
            currencyCode: currencyCode,
            items: items,
          ) : _remote.updateBudget(
            id: id,
            name: name,
            currencyCode: currencyCode,
            items: items,
          ));

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
