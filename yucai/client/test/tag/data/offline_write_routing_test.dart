// F10 T1(2026-09-03):tag repo 三态写路由 + FR-1b 写降级行为钉。
// - boundRemote + NetworkFailure → 降级落本地;
// - boundRemote + 其他 Failure(校验)→ 不降级;
// - guest → 本地,零远端调用(R6 行为不变);
// - boundOfflineLocal(authOffline 离线冷启动,FR-2)→ 本地,零远端调用;
// - 读路径 boundRemote + NetworkFailure → 不降级照常 Left(读只由路由切本地)。
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/error/failures.dart';
import 'package:yucai_client/core/localdb/app_database.dart' hide Tag;
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/tag/data/tag_remote_ds.dart';
import 'package:yucai_client/tag/data/tag_repository_impl.dart';

class _MockRemote extends Mock implements TagRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late AppDatabase database;
  late SessionModeTracker tracker;
  late TagLocalDataSource local;
  late TagRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    database = AppDatabase(NativeDatabase.memory());
    local = TagLocalDataSource(database);
    tracker = SessionModeTracker();
    repo = TagRepositoryImpl(remote, local, tracker);
  });

  tearDown(() => database.close());

  test('boundRemote + NetworkFailure → 降级落本地(数据不丢)', () async {
    tracker.isGuest = false;
    when(() => remote.create(name: '日常', color: '#b08d57'))
        .thenThrow(const GrpcError.unavailable('down'));

    final result = await repo.create(name: '日常', color: '#b08d57');

    expect(result.isRight(), isTrue);
    verify(() => remote.create(name: '日常', color: '#b08d57')).called(1);
    expect((await local.list()).map((t) => t.name), contains('日常'));
  });

  test('boundRemote + 其他 Failure → 不降级,本地无写入', () async {
    tracker.isGuest = false;
    when(() => remote.create(name: '日常', color: '#b08d57'))
        .thenThrow(const GrpcError.invalidArgument('dup name'));

    final result = await repo.create(name: '日常', color: '#b08d57');

    expect(result.fold((l) => l, (_) => null), isA<ValidationFailure>());
    expect(await local.list(), isEmpty);
  });

  test('guest → 本地写,零远端调用(R6 行为不变)', () async {
    final result = await repo.create(name: '日常', color: '#b08d57');

    expect(result.isRight(), isTrue);
    verifyNoMoreInteractions(remote);
    expect((await local.list()).map((t) => t.name), contains('日常'));
  });

  test('boundOfflineLocal(authOffline 离线冷启动 FR-2)→ 本地,零远端调用',
      () async {
    tracker
      ..isGuest = false
      ..authOffline = true;
    final result = await repo.create(name: '日常', color: '#b08d57');

    expect(result.isRight(), isTrue);
    verifyNoMoreInteractions(remote);
    expect((await local.list()).map((t) => t.name), contains('日常'));
  });

  test('读路径 boundRemote + NetworkFailure → 不降级照常 Left(读只由路由切本地)',
      () async {
    tracker.isGuest = false;
    when(() => remote.list()).thenThrow(const GrpcError.unavailable('down'));

    final result = await repo.list();

    expect(result.fold((l) => l, (_) => null), isA<NetworkFailure>());
    verify(() => remote.list()).called(1);
  });
}
