import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/transaction/data/transaction_remote_ds.dart';
import 'package:yucai_client/transaction/domain/entities/transaction_entity.dart';
import 'package:yucai_client/transaction/domain/repositories/transaction_repository.dart';
import 'package:yucai_client/transaction/domain/value_objects.dart';

@LazySingleton(as: TransactionRepository)
class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl(this._remote);

  final TransactionRemoteDataSource _remote;

  @override
  Future<Either<Failure, Transaction>> recordExpense(
          RecordExpenseParams params) =>
      _guard(() => _remote.recordExpense(params));

  @override
  Future<Either<Failure, Transaction>> recordIncome(
          RecordIncomeParams params) =>
      _guard(() => _remote.recordIncome(params));

  @override
  Future<Either<Failure, Transaction>> recordTransfer(
          RecordTransferParams params) =>
      _guard(() => _remote.recordTransfer(params));

  @override
  Future<Either<Failure, Transaction>> recordTransaction(
          RecordTransactionParams params) =>
      _guard(() => _remote.recordTransaction(params));

  @override
  Future<Either<Failure, List<Transaction>>> list(
          ListTransactionsParams params) =>
      _guard(() => _remote.list(params));

  @override
  Future<Either<Failure, Transaction>> getById(String id) =>
      _guard(() => _remote.getById(id));

  @override
  Future<Either<Failure, Transaction>> update(
          UpdateTransactionParams params) =>
      _guard(() => _remote.update(params));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _guard(() => _remote.delete(id));

  @override
  Future<Either<Failure, MonthlySummary>> summary(
    int year,
    int month, {
    String? accountId,
  }) {
    // The TransactionSummary RPC is added in Task 5.1 alongside the proto
    // redesign. Until then we throw — the trait signature is stable so
    // presentation code can be written against it, but any real call fails
    // loudly instead of silently doing nothing.
    throw UnimplementedError(
      'TransactionRepository.summary is deferred to Task 5.1 '
      '(TransactionSummary RPC not yet in proto).',
    );
  }

  /// Maps thrown GrpcError / exceptions to [Failure], wrapping the op in
  /// Either. Mirrors [AccountRepositoryImpl._guard].
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(_mapGrpcError(e));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  Failure _mapGrpcError(GrpcError e) {
    switch (e.code) {
      case StatusCode.unauthenticated:
        return AuthFailure(e.message ?? '凭证无效');
      case StatusCode.unavailable:
        return NetworkFailure(e.message ?? '无法连接服务器');
      case StatusCode.invalidArgument:
        return ValidationFailure(e.message ?? '参数错误');
      case StatusCode.failedPrecondition:
        return ServerFailure(e.message?.isNotEmpty == true ? e.message! : '操作无法完成');
      default:
        return ServerFailure(e.message ?? e.codeName);
    }
  }
}
