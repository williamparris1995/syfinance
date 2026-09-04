import 'package:dartz/dartz.dart';
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/reference_dao.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/currency/data/currency_remote_ds.dart';
import 'package:yucai_client/currency/domain/entities/currency_entity.dart';
import 'package:yucai_client/currency/domain/repositories/currency_repository.dart';

/// Guest-mode data source for the currency module (R6 ADR-5): reads the
/// local reference table and seeds a static ISO subset on first (empty)
/// read — guests have no server to pull from; a bound session's remote list
/// overwrites the seed values.
@LazySingleton()
class CurrencyLocalDataSource {
  CurrencyLocalDataSource(this._database);

  final db.AppDatabase _database;

  ReferenceDao get _dao => _database.referenceDao;

  /// Static fallback rates are intentionally 1.0 (stale placeholder); the UI
  /// treats non-CNY rates as approximate until the first online refresh.
  static const _seed = <(String, String, String)>[
    ('CNY', '人民币', '¥'),
    ('USD', '美元', r'$'),
    ('EUR', '欧元', '€'),
    ('GBP', '英镑', '£'),
    ('JPY', '日元', '¥'),
    ('HKD', '港币', r'$'),
    ('TWD', '新台币', r'$'),
    ('KRW', '韩元', '₩'),
    ('SGD', '新加坡元', r'$'),
    ('AUD', '澳元', r'$'),
  ];

  Future<List<Currency>> list() async {
    var rows = await _dao.watchActiveCurrencies().first;
    if (rows.isEmpty) {
      await _seedAll();
      rows = await _dao.watchActiveCurrencies().first;
    }
    return rows
        .map((r) => Currency(
              code: r.code,
              name: r.name,
              symbol: r.symbol,
              exchangeRate: r.exchangeRate,
              isActive: r.isActive,
            ))
        .toList();
  }

  Future<void> _seedAll() async {
    // One transaction: a mid-batch failure must not leave a partial seed.
    await _database.transaction(() async {
      for (final (code, name, symbol) in _seed) {
        await _dao.insertCurrency(db.CurrenciesCompanion.insert(
          code: code,
          name: name,
          symbol: symbol,
          exchangeRate: 1.0,
          isActive: true,
        ));
      }
    });
  }
}

/// Dual-source currency repository (R6 C-paradigm). The guard is upgraded to
/// the account-style GrpcError classification + local Failure passthrough
/// (the old impl collapsed everything into ServerFailure).
@LazySingleton(as: CurrencyRepository)
class CurrencyRepositoryImpl implements CurrencyRepository {
  CurrencyRepositoryImpl(this._remote, this._local, this._tracker);

  final CurrencyRemoteDataSource _remote;
  final CurrencyLocalDataSource _local;
  final SessionModeTracker _tracker;

  /// F10 FR-1/FR-2:三态数据路由(与 8 个双源 repo 同款判定)。guest 或
  /// bound-offline(断网 / 离线冷启动)走本地 reference 表;仅绑定在线走
  /// 远端(在线行为与 R6 的 `_tracker.isGuest` 逐位一致)。读源:仅路由
  /// 切换,读不做 NetworkFailure 降级。
  bool get _useLocalDs {
    final route = _tracker.resolveDataRoute();
    return route == DataRoute.guestLocal || route == DataRoute.boundOfflineLocal;
  }

  @override
  Future<Either<Failure, List<Currency>>> list() =>
      _guard(() => _useLocalDs ? _local.list() : _remote.list());

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() op) async {
    try {
      return Right(await op());
    } on GrpcError catch (e) {
      return Left(_mapGrpcError(e));
    } on Failure catch (f) {
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
