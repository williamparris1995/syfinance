import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/debt/data/receivables_summary_data_source.dart';
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';
import 'package:yucai_client/debt/domain/repositories/receivables_summary_repository.dart';

@LazySingleton(as: ReceivablesSummaryRepository)
class ReceivablesSummaryRepositoryImpl
    implements ReceivablesSummaryRepository {
  ReceivablesSummaryRepositoryImpl(this._remote);

  final ReceivablesSummaryDataSource _remote;

  @override
  Future<Either<Failure, ReceivablesSummary>> fetch() =>
      _guard(() => _remote.fetch());

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
  // 对齐 DebtRepositoryImpl._guard(同模块惯例)。
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
