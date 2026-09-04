import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:drift/drift.dart' show Value;
import 'package:grpc/grpc.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/core/localdb/daos/tag_dao.dart';
import 'package:yucai_client/core/session_mode/bound_write_fallback.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/binding/data/bound_mirror.dart';
import 'package:yucai_client/tag/data/tag_remote_ds.dart';
import 'package:yucai_client/tag/domain/entities/tag_entity.dart';
import 'package:yucai_client/tag/domain/repositories/tag_repository.dart';

/// Guest-mode data source for the tag module (R6, C-paradigm): mirrors the
/// remote surface on drift. The transaction-tag junction is local-only
/// (absent from the backup contract) and is read/written as-is.
@LazySingleton()
class TagLocalDataSource {
  TagLocalDataSource(this._database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final db.AppDatabase _database;
  final Uuid _uuid;

  TagDao get _dao => _database.tagDao;

  Future<List<Tag>> list() async =>
      (await _dao.watchAllTags().first).map(_toEntity).toList();

  Future<Tag> create({required String name, required String color}) async {
    final id = _uuid.v4();
    final now = DateTime.now().toUtc();
    await _dao.insertTag(db.TagsCompanion.insert(
      id: id,
      name: name,
      color: color,
      version: 1,
      createdAt: now,
      updatedAt: now,
    ));
    return _toEntity((await _dao.getTagById(id))!);
  }

  Future<Tag> update({
    required String id,
    required String name,
    required String color,
    required int version,
  }) async {
    final row = await _dao.getTagById(id);
    if (row == null) throw const ServerFailure('标签不存在');
    if (row.version != version) {
      throw const ServerFailure('数据已过期，请刷新后重试');
    }
    await _dao.updateTag(db.TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      version: Value(row.version + 1),
      updatedAt: Value(DateTime.now().toUtc()),
    ));
    return _toEntity((await _dao.getTagById(id))!);
  }

  Future<void> delete(String id) async {
    if (await _dao.getTagById(id) == null) throw const ServerFailure('标签不存在');
    await _dao.deleteTagById(id);
  }

  Future<void> addTagToTransaction({
    required String tagId,
    required String transactionId,
  }) async {
    // Referential check (feature F): both sides must exist.
    if (await _dao.getTagById(tagId) == null) throw ServerFailure('标签不存在');
    final txn = await _database.transactionDao
        .getTransactionById(transactionId);
    if (txn == null) throw ServerFailure('交易不存在');
    // Idempotent: an existing junction row is a no-op success (accepted
    // difference — the server returns a notFound-shaped error).
    final existing = await _dao.watchTagIdsForTransaction(transactionId).first;
    if (existing.contains(tagId)) return;
    await _dao.insertTransactionTag(db.TransactionTagsCompanion.insert(
      transactionId: transactionId,
      tagId: tagId,
    ));
  }

  Future<void> removeTagFromTransaction({
    required String tagId,
    required String transactionId,
  }) =>
      _dao.deleteTransactionTag(transactionId, tagId);

  Future<List<Tag>> getTransactionTags(String transactionId) async {
    final tagIds = await _dao.watchTagIdsForTransaction(transactionId).first;
    final tags = <Tag>[];
    for (final id in tagIds) {
      final row = await _dao.getTagById(id);
      if (row != null) tags.add(_toEntity(row));
    }
    return tags;
  }

  Tag _toEntity(db.Tag row) =>
      Tag(id: row.id, name: row.name, color: row.color, version: row.version);
}

/// Dual-source tag repository (R6 C-paradigm): guest → local drift, other
/// sessions keep the remote path byte-for-byte.
@LazySingleton(as: TagRepository)
class TagRepositoryImpl implements TagRepository {
  TagRepositoryImpl(this._remote, this._local, this._tracker, [this._mirror]);

  final TagRemoteDataSource _remote;
  final TagLocalDataSource _local;
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
  Future<Either<Failure, List<Tag>>> list() =>
      _guard(() => _useLocalDs ? _local.list() : _remote.list());

  @override
  Future<Either<Failure, Tag>> create({required String name, required String color}) =>
      _routedWrite(MirrorModule.tag,
          () => _remote.create(name: name, color: color),
          () => _local.create(name: name, color: color));

  @override
  Future<Either<Failure, Tag>> update({
    required String id,
    required String name,
    required String color,
    required int version,
  }) =>
      _routedWrite(MirrorModule.tag,
          () => _remote.update(id: id, name: name, color: color, version: version),
          () => _local.update(id: id, name: name, color: color, version: version));

  @override
  Future<Either<Failure, void>> delete(String id) =>
      _routedWrite(MirrorModule.tag, () => _remote.delete(id), () => _local.delete(id));

  @override
  Future<Either<Failure, void>> addTagToTransaction({
    required String tagId,
    required String transactionId,
  }) =>
      _routedWrite(MirrorModule.tag,
          () => _remote.addTagToTransaction(tagId: tagId, transactionId: transactionId),
          () => _local.addTagToTransaction(tagId: tagId, transactionId: transactionId));

  @override
  Future<Either<Failure, void>> removeTagFromTransaction({
    required String tagId,
    required String transactionId,
  }) =>
      _routedWrite(MirrorModule.tag,
          () => _remote.removeTagFromTransaction(tagId: tagId, transactionId: transactionId),
          () => _local.removeTagFromTransaction(tagId: tagId, transactionId: transactionId));

  @override
  Future<Either<Failure, List<Tag>>> getTransactionTags(String transactionId) =>
      _guard(() => _useLocalDs
          ? _local.getTransactionTags(transactionId)
          : _remote.getTransactionTags(transactionId));

  /// 统一 try/Either 包装(对齐 BackupRepositoryImpl._guard)。
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
  /// TODO-F10T2:降级/离线写本地置 pending + 回网上行(本任务不做,锚点)。
  Future<Either<Failure, T>> _routedWrite<T>(MirrorModule m,
      Future<T> Function() remote, Future<T> Function() local) async {
    if (_useLocalDs) {
      return _mirrored(m, () => _guard(local));
    }
    return writeWithFallback(
      () => _mirrored(m, () => _guard(remote)),
      () => _guard(local),
    );
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
