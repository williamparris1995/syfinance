// F17-T2(spec FR-3,design ADR-3):拉取游标存储 —— drift 单行 sync_cursor
// 表(查库内无既有 kv/primitive 表先例后新增;读写 helper)。默认 0 =
// since 从头拉(重装/清库幂等重拉无害,design Risk 表「游标回退」)。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('未写入时读取默认 0(since=0 全量重拉,幂等无害)', () async {
    expect(await db.syncCursorDao.readLastPulledVersion(), 0);
  });

  test('写入后读回;重复写入覆盖(单行 upsert)', () async {
    await db.syncCursorDao.writeLastPulledVersion(7);
    expect(await db.syncCursorDao.readLastPulledVersion(), 7);

    await db.syncCursorDao.writeLastPulledVersion(9);
    expect(await db.syncCursorDao.readLastPulledVersion(), 9);

    // 单行不变量:表内恒恰一行。
    final rows = await db.select(db.syncCursors).get();
    expect(rows, hasLength(1));
    expect(rows.single.lastPulledVersion, 9);
  });
}
