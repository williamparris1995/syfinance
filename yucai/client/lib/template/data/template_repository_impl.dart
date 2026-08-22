import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/data/template_remote_ds.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';

@LazySingleton(as: TemplateRepository)
class TemplateRepositoryImpl implements TemplateRepository {
  TemplateRepositoryImpl(this._remote, this._local, this._tracker);

  final TemplateRemoteDataSource _remote;
  final TemplateLocalDataSource _local;
  final SessionModeTracker _tracker;

  bool get _useLocal => _tracker.isGuest;

  @override
  Future<Either<Failure, List<Template>>> list({bool? paused}) =>
      _guard(() => _useLocal ? _local.list(paused: paused) : _remote.list(paused: paused));

  @override
  Future<Either<Failure, Template>> create({
    required String name,
    String description = '',
    required int amountCents,
    TemplateDirection direction = TemplateDirection.unspecified,
    String? sourceAccountId,
    String? destinationAccountId,
    TemplateCycle cycle = TemplateCycle.unspecified,
    int cycleDays = 0,
    int billingDay = 0,
    String? startDate,
    String? endDate,
    bool autoRecord = false,
    String? category,
  }) =>
      _guard(() => _useLocal
          ? _local.create(
              name: name,
              description: description,
              amountCents: amountCents,
              direction: direction,
              sourceAccountId: sourceAccountId,
              destinationAccountId: destinationAccountId,
              cycle: cycle,
              cycleDays: cycleDays,
              billingDay: billingDay,
              startDate: startDate,
              endDate: endDate,
              autoRecord: autoRecord,
              category: category,
            )
          : _remote.create(
              name: name,
              description: description,
              amountCents: amountCents,
              direction: direction,
              sourceAccountId: sourceAccountId,
              destinationAccountId: destinationAccountId,
              cycle: cycle,
              cycleDays: cycleDays,
              billingDay: billingDay,
              startDate: startDate,
              endDate: endDate,
              autoRecord: autoRecord,
              category: category,
            ));

  @override
  Future<Either<Failure, Template>> update({
    required String id,
    required int version,
    String? name,
    String? description,
    int? amountCents,
    TemplateCycle? cycle,
    int? cycleDays,
    String? endDate,
    bool? autoRecord,
  }) =>
      _guard(() => _useLocal
          ? _local.update(
              id: id,
              version: version,
              name: name,
              description: description,
              amountCents: amountCents,
              cycle: cycle,
              cycleDays: cycleDays,
              endDate: endDate,
              autoRecord: autoRecord,
            )
          : _remote.update(
              id: id,
              version: version,
              name: name,
              description: description,
              amountCents: amountCents,
              cycle: cycle,
              cycleDays: cycleDays,
              endDate: endDate,
              autoRecord: autoRecord,
            ));

  @override
  Future<Either<Failure, void>> delete(String id) => _guard(() => _useLocal ? _local.delete(id) : _remote.delete(id));

  @override
  Future<Either<Failure, Template>> pause(String id) => _guard(() => _useLocal ? _local.pause(id) : _remote.pause(id));

  @override
  Future<Either<Failure, Template>> resume(String id) => _guard(() => _useLocal ? _local.resume(id) : _remote.resume(id));

  @override
  Future<Either<Failure, Template>> get(String id) => _guard(() => _useLocal ? _local.get(id) : _remote.get(id));

  @override
  Future<Either<Failure, RecordResult>> record(String templateId) =>
      _guard(() => _useLocal ? _local.record(templateId) : _remote.record(templateId));

  /// 统一 try/Either 包装(对齐 TagRepositoryImpl._guard / BackupRepositoryImpl._guard)。
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(_mapGrpcError(e));
    } on Failure catch (f) {
      // Local data source failures pass through untouched.
      return Left(f);
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  Failure _mapGrpcError(GrpcError e) {
    switch (e.code) {
      case StatusCode.unavailable:
        return NetworkFailure(e.message ?? '无法连接服务器');
      case StatusCode.invalidArgument:
        return ValidationFailure(e.message ?? '参数错误');
      default:
        return ServerFailure(e.message ?? e.codeName);
    }
  }
}
