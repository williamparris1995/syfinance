import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:injectable/injectable.dart' as _inj;
import 'package:drift/drift.dart' show Value;
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db hide Debt;
import 'package:yucai_client/core/localdb/daos/debt_dao.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/debt/data/receivables_summary_data_source.dart';
import 'package:yucai_client/debt/domain/entities/receivables_summary.dart';
import 'package:yucai_client/debt/domain/repositories/receivables_summary_repository.dart';

@LazySingleton(as: ReceivablesSummaryRepository)
class ReceivablesSummaryRepositoryImpl
    implements ReceivablesSummaryRepository {
  ReceivablesSummaryRepositoryImpl(this._remote, this._db, this._tracker);

  final ReceivablesSummaryDataSource _remote;
  final db.AppDatabase _db;
  final SessionModeTracker _tracker;

  /// F10 FR-1/FR-2:三态数据路由(与 8 个双源 repo 同款判定)。guest 或
  /// bound-offline(断网 / 离线冷启动)走本地聚合;仅绑定在线走远端。
  /// 派生读源:仅路由切换,读不做 NetworkFailure 降级。
  bool get _useLocalDs {
    final route = _tracker.resolveDataRoute();
    return route == DataRoute.guestLocal || route == DataRoute.boundOfflineLocal;
  }

  @override
  Future<Either<Failure, ReceivablesSummary>> fetch() =>
      _guard(() => _useLocalDs ? _localFetch() : _remote.fetch());

  /// Guest aggregation over borrowedOut debts + their schedules (review
  /// E-#1): the core money fields mirror the server; trend fields carry the
  /// same values as their totals (no historical scheduler guest-side).
  Future<ReceivablesSummary> _localFetch() async {
    final debts = await _db.debtDao.watchAllDebts().first;
    final receivables =
        debts.where((d) => d.debtType == 2).toList(); // borrowedOut
    var principal = 0, collected = 0, pendingInterest = 0;
    var overdueCount = 0, overdueAmount = 0;
    DateTime? nextDate;
    var nextAmount = 0;
    var nextCounterparty = '';
    var nextPeriod = 0;
    for (final d in receivables) {
      principal += d.totalPrincipalCents;
      final schedule = await _db.debtDao.getScheduleByDebt(d.id);
      var period = 0;
      for (final s in schedule) {
        period++;
        collected += s.paidCents;
        if (!s.paid) {
          pendingInterest += s.interestCents;
          if (s.paymentDate.isBefore(DateTime.now().toUtc())) {
            overdueCount++;
            overdueAmount += s.totalCents;
          }
          if (nextDate == null || s.paymentDate.isBefore(nextDate)) {
            nextDate = s.paymentDate;
            nextAmount = s.totalCents;
            nextCounterparty = d.counterparty;
            nextPeriod = period;
          }
        }
      }
    }
    final remaining = principal - collected;
    return ReceivablesSummary(
      totalPrincipalCents: principal,
      totalRemainingCents: remaining,
      totalCollectedCents: collected,
      pendingInterestCents: pendingInterest,
      count: receivables.length,
      overdueCount: overdueCount,
      overdueAmountCents: overdueAmount,
      principalTrendCents: principal,
      remainingTrendCents: remaining,
      nextPaymentDate: nextDate,
      nextPaymentAmountCents: nextAmount,
      nextPaymentCounterparty: nextCounterparty,
      nextPaymentPeriodNo: nextPeriod,
    );
  }

  // Maps thrown GrpcError/exceptions to Failure, wrapping the op in Either.
  // 对齐 DebtRepositoryImpl._guard(同模块惯例)。
  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(ServerFailure(e.message ?? 'gRPC error'));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
