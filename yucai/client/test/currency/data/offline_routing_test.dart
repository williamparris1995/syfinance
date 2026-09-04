// F10 FR-2:currency 派生读源三态路由轻测 —— bound-offline 读走本地
// reference 表(种子币种),零远端调用(此前 isGuest 单布尔路由导致
// 绑定离线读全红)。
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:drift/native.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/session_mode/session_mode_tracker.dart';
import 'package:yucai_client/currency/data/currency_repository_impl.dart';
import 'package:yucai_client/currency/data/currency_remote_ds.dart';

class _MockRemote extends Mock implements CurrencyRemoteDataSource {}

void main() {
  late _MockRemote remote;
  late AppDatabase database;
  late SessionModeTracker tracker;
  late CurrencyRepositoryImpl repo;

  setUp(() {
    remote = _MockRemote();
    database = AppDatabase(NativeDatabase.memory());
    tracker = SessionModeTracker();
    repo = CurrencyRepositoryImpl(
        remote, CurrencyLocalDataSource(database), tracker);
  });

  tearDown(() => database.close());

  test('bound-offline(断网)→ 本地种子列表,零远端调用', () async {
    tracker
      ..isGuest = false
      ..online = false;
    final result = await repo.list();
    expect(result.isRight(), isTrue);
    verifyNoMoreInteractions(remote);
    result.fold(
      (_) => fail('expected Right'),
      (list) => expect(list.map((c) => c.code), contains('CNY')),
    );
  });
}
