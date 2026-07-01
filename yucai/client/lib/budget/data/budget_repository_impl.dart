import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/budget/data/budget_remote_ds.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/domain/repositories/budget_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@LazySingleton(as: BudgetRepository)
class BudgetRepositoryImpl implements BudgetRepository {
  BudgetRepositoryImpl(this._remote);

  final BudgetRemoteDataSource _remote;

  @override
  Future<Either<Failure, List<BudgetView>>> listBudgets({bool activeOnly = false}) =>
      _guard(() => _remote.listBudgets(activeOnly: activeOnly));

  @override
  Future<Either<Failure, BudgetView>> getBudget(String id) =>
      _guard(() => _remote.getBudget(id));

  @override
  Future<Either<Failure, BudgetView>> getBudgetByMonth(String month) =>
      _guard(() => _remote.getBudgetByMonth(month));

  @override
  Future<Either<Failure, BudgetView>> createBudget({
    required String name,
    required String month,
    required String currencyCode,
    required List<({String accountId, int plannedAmountCents, String? notes})> items,
  }) =>
      _guard(() => _remote.createBudget(
            name: name,
            month: month,
            currencyCode: currencyCode,
            items: items,
          ));

  @override
  Future<Either<Failure, void>> deleteBudget(String id) =>
      _guard(() => _remote.deleteBudget(id));

  @override
  Future<Either<Failure, BudgetView>> addItem({
    required String budgetId,
    required String accountId,
    required int plannedAmountCents,
    String? notes,
  }) =>
      _guard(() => _remote.addItem(
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
      _guard(() => _remote.removeItem(
            budgetId: budgetId,
            itemId: itemId,
          ));

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
