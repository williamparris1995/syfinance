import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/session_mode/bound_write_fallback.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/debt/data/debt_local_ds.dart';
import 'package:yucai_client/debt/data/debt_remote_ds.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

@LazySingleton(as: DebtRepository)
class DebtRepositoryImpl implements DebtRepository {
  DebtRepositoryImpl(this._remote, this._local, this._tracker, [this._mirror]);

  final DebtRemoteDataSource _remote;
  final DebtLocalDataSource _local;
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
  Future<Either<Failure, List<Debt>>> list({DebtType? typeFilter}) =>
      _guard(() => _useLocalDs ? _local.list(typeFilter: typeFilter) : _remote.list(typeFilter: typeFilter));

  @override
  Future<Either<Failure, DebtDetail>> get(String id) =>
      _guard(() => _useLocalDs ? _local.get(id) : _remote.get(id));

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
  }) =>
      _routedWrite(MirrorModule.debt,
          () => _remote.create(
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
            guarantorName: guarantorName,
            guarantorContact: guarantorContact,
            collectionAccountId: collectionAccountId,
            cycle: cycle,
            interval: interval,
            weekdayMask: weekdayMask,
            monthlyMode: monthlyMode,
            nth: nth,
            termPeriods: termPeriods,
            interestWaivedCents: interestWaivedCents,
          ),
          (markPending) => _local.create(
            markPending: markPending,
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
            guarantorName: guarantorName,
            guarantorContact: guarantorContact,
            collectionAccountId: collectionAccountId,
            cycle: cycle,
            interval: interval,
            weekdayMask: weekdayMask,
            monthlyMode: monthlyMode,
            nth: nth,
            termPeriods: termPeriods,
            interestWaivedCents: interestWaivedCents,
          ));

  @override
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
  }) =>
      _routedWrite(MirrorModule.debt,
          () => _remote.update(
            id: id,
            counterparty: counterparty,
            interestRate: interestRate,
            version: version,
            contact: contact,
            contractRef: contractRef,
            guarantorName: guarantorName,
            guarantorContact: guarantorContact,
            collectionAccountId: collectionAccountId,
            amortizationIndex: amortizationIndex,
            dueDate: dueDate,
            termPeriods: termPeriods,
            cycle: cycle,
            interval: interval,
            weekdayMask: weekdayMask,
            monthlyMode: monthlyMode,
            nth: nth,
            interestWaivedCents: interestWaivedCents,
          ),
          (markPending) => _local.update(
            markPending: markPending,
            id: id,
            counterparty: counterparty,
            interestRate: interestRate,
            version: version,
            contact: contact,
            contractRef: contractRef,
            guarantorName: guarantorName,
            guarantorContact: guarantorContact,
            collectionAccountId: collectionAccountId,
            amortizationIndex: amortizationIndex,
            dueDate: dueDate,
            termPeriods: termPeriods,
            cycle: cycle,
            interval: interval,
            weekdayMask: weekdayMask,
            monthlyMode: monthlyMode,
            nth: nth,
            interestWaivedCents: interestWaivedCents,
          ));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _routedWrite(MirrorModule.debt, () => _remote.delete(id),
          (markPending) => _local.delete(id, writeTombstone: markPending));

  @override
  Future<Either<Failure, PaymentEntry>> markEntryPaid({
    required String debtId,
    required String entryId,
  }) =>
      _routedWrite(MirrorModule.debt,
          () => _remote.markEntryPaid(debtId: debtId, entryId: entryId),
          (markPending) => _local.markEntryPaid(
            debtId: debtId,
            entryId: entryId,
            markPending: markPending,
          ));

  Future<Either<Failure, PaymentEntry>> setPaymentDate({
    required String debtId,
    required String entryId,
    required DateTime paymentDate,
  }) =>
      _routedWrite(MirrorModule.debt,
          () => _remote.setPaymentDate(
            debtId: debtId,
            entryId: entryId,
            paymentDate: paymentDate,
          ),
          (markPending) => _local.setPaymentDate(
            debtId: debtId,
            entryId: entryId,
            paymentDate: paymentDate,
            markPending: markPending,
          ));

  Future<Either<Failure, PaymentEntry>> recordPayment({
    required String debtId,
    required String scheduleEntryId,
    required String fromAccountId,
  }) =>
      _routedWrite(MirrorModule.debt,
          () => _remote.recordPayment(
            debtId: debtId,
            scheduleEntryId: scheduleEntryId,
            fromAccountId: fromAccountId,
          ),
          (markPending) => _local.recordPayment(
            markPending: markPending,
            debtId: debtId,
            scheduleEntryId: scheduleEntryId,
            fromAccountId: fromAccountId,
          ));

  @override
  Future<Either<Failure, List<Debt>>> upcomingPayments(int daysAhead) =>
      _guard(() => _useLocalDs ? _local.upcomingPayments(daysAhead) : _remote.upcomingPayments(daysAhead));

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
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
      return Left(ServerFailure(e.toString()));
    }
  }

  /// F10 FR-1b:unavailable → NetworkFailure 是写降级判定的前提(照
  /// holding 范式);仅取 unavailable 分支以最小化行为变化(holding 另有
  /// unauthenticated 映射,刻意不抄),其余错误保持既有 ServerFailure
  /// 分类,行为不变。
  Failure _mapGrpcError(GrpcError e) {
    if (e.code == StatusCode.unavailable) {
      return NetworkFailure(e.message ?? '无法连接服务器');
    }
    return ServerFailure(e.message ?? 'gRPC error');
  }
}
