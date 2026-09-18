import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/bound_write_fallback.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/data/template_remote_ds.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/domain/repositories/template_repository.dart';

@LazySingleton(as: TemplateRepository)
class TemplateRepositoryImpl implements TemplateRepository {
  TemplateRepositoryImpl(this._remote, this._local, this._tracker, [this._mirror]);

  final TemplateRemoteDataSource _remote;
  final TemplateLocalDataSource _local;
  final SessionModeTracker _tracker;
  final BoundMirror? _mirror;

  /// F10 FR-1:三态数据路由(guestLocal / boundRemote / boundOfflineLocal)。
  /// guest 或 bound-offline 走本地;仅绑定在线走远端(在线行为与 R6 的
  /// `_useLocal => isGuest` 逐位一致)。
  bool get _useLocalDs {
    final route = _tracker.resolveDataRoute();
    return route == DataRoute.guestLocal || route == DataRoute.boundOfflineLocal;
  }

  @override
  Future<Either<Failure, List<Template>>> list({bool? paused}) =>
      _guard(() => _useLocalDs ? _local.list(paused: paused) : _remote.list(paused: paused));

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
    int interval = 0,
    int weekdayMask = 0,
    int monthlyMode = 0,
    int nth = 0,
    String? startDate,
    String? endDate,
    bool autoRecord = false,
    String? category,
  }) =>
      _routedWrite(MirrorModule.template,
          () => _remote.create(
              name: name,
              description: description,
              amountCents: amountCents,
              direction: direction,
              sourceAccountId: sourceAccountId,
              destinationAccountId: destinationAccountId,
              cycle: cycle,
              cycleDays: cycleDays,
              billingDay: billingDay,
              interval: interval,
              weekdayMask: weekdayMask,
              monthlyMode: monthlyMode,
              nth: nth,
              startDate: startDate,
              endDate: endDate,
              autoRecord: autoRecord,
              category: category,
            ),
          (markPending) => _local.create(
              markPending: markPending,
              name: name,
              description: description,
              amountCents: amountCents,
              direction: direction,
              sourceAccountId: sourceAccountId,
              destinationAccountId: destinationAccountId,
              cycle: cycle,
              cycleDays: cycleDays,
              billingDay: billingDay,
              interval: interval,
              weekdayMask: weekdayMask,
              monthlyMode: monthlyMode,
              nth: nth,
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
    int? billingDay,
    int? interval,
    int? weekdayMask,
    int? monthlyMode,
    int? nth,
    String? endDate,
    bool? autoRecord,
  }) =>
      _routedWrite(MirrorModule.template,
          () => _remote.update(
              id: id,
              version: version,
              name: name,
              description: description,
              amountCents: amountCents,
              cycle: cycle,
              cycleDays: cycleDays,
              billingDay: billingDay,
              interval: interval,
              weekdayMask: weekdayMask,
              monthlyMode: monthlyMode,
              nth: nth,
              endDate: endDate,
              autoRecord: autoRecord,
            ),
          (markPending) => _local.update(
              markPending: markPending,
              id: id,
              version: version,
              name: name,
              description: description,
              amountCents: amountCents,
              cycle: cycle,
              cycleDays: cycleDays,
              billingDay: billingDay,
              interval: interval,
              weekdayMask: weekdayMask,
              monthlyMode: monthlyMode,
              nth: nth,
              endDate: endDate,
              autoRecord: autoRecord,
            ));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _routedWrite(MirrorModule.template, () => _remote.delete(id),
          (markPending) => _local.delete(id, writeTombstone: markPending));

  @override
  Future<Either<Failure, Template>> pause(String id) =>
      _routedWrite(MirrorModule.template, () => _remote.pause(id),
          (markPending) => _local.pause(id, markPending: markPending));

  @override
  Future<Either<Failure, Template>> resume(String id) =>
      _routedWrite(MirrorModule.template, () => _remote.resume(id),
          (markPending) => _local.resume(id, markPending: markPending));

  @override
  Future<Either<Failure, Template>> get(String id) =>
      _guard(() => _useLocalDs ? _local.get(id) : _remote.get(id));

  @override
  Future<Either<Failure, RecordResult>> record(String templateId) =>
      _routedWrite(MirrorModule.template, () => _remote.record(templateId),
          (markPending) => _local.record(templateId, markPending: markPending));

  /// 统一 try/Either 包装(对齐 TagRepositoryImpl._guard / BackupRepositoryImpl._guard)。
  /// Bound-state mirror hook (R6 H): after a SUCCESSFUL REMOTE
  /// write, refresh this module's local mirror (fire-and-forget).
  Future<Either<Failure, T>> _mirrored<T>(MirrorModule m,
      Future<Either<Failure, T>> Function() body) async {
    final r = await body();
    if (r.isRight() && !_useLocalDs && _mirror != null) {
      unawaited(_mirror.refreshModule(m));
    }
    return r;
  }

  /// F10 FR-1/FR-1b:三态写路由 + 远端失败降级(照 transaction 范式)。
  /// guest/bound-offline 直接本地;boundRemote 先远端(Right 触发镜像刷新,
  /// 与 R6 逐位一致),NetworkFailure 降级本地落库(FR-1b 双保险)且不触发
  /// 镜像刷新(防 delete-all+rebuild 抹掉未上行本地行);其他失败原样 Left。
  Future<Either<Failure, T>> _routedWrite<T>(MirrorModule m,
      Future<T> Function() remote,
      Future<T> Function(bool markPending) local) async {
    switch (_tracker.resolveDataRoute()) {
      case DataRoute.guestLocal:
        // guest 行 synced(无上行语义,R6 行为不变;缺省不传 = false)。
        return _mirrored(m, () => _guard(() => local(false)));
      case DataRoute.boundOfflineLocal:
        // 离线写本地,行 pending 待回网上行(FR-3,T2 落地)。
        return _mirrored(m, () => _guard(() => local(true)));
      case DataRoute.boundRemote:
        // 在线先远端(Right 触发镜像刷新,与 R6 逐位一致);NetworkFailure
        // 降级本地落库置 pending(FR-1b 双保险,同为 bound 路由)。
        return writeWithFallback(
          () => _mirrored(m, () => _guard(remote)),
          () => _guard(() => local(true)),
        );
    }
  }

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
