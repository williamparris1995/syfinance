// F21-T1 — DataResetController(清空数据重新开始)单元测试。
//
// 覆盖 spec 三条硬语义:
// - FR-3 备份先行 fail-closed:备份写失败 → 抛出,库文件未删、库仍可用;
// - FR-4 清空:备份成功 → 关库 → 删主库文件 + -wal/-shm;
// - FR-4 exit 缝:exitApp 走注入的 ExitFn(测试不真退出)。
//
// 真链路:drift 内存库 + 真 LocalSnapshotExporter.exportAll + 真
// ArchiveCodec.encrypt;库文件集经注入缝指向临时目录(模拟测试库
// yucai_test.db 三件套),不解析真实路径 —— 生产默认解析(同
// AppDatabase 的 dart-define 逻辑)单列一测,用假 PathProvider 锚定。
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:yucai_client/backup/data/archive_codec.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/settings/data/data_reset_controller.dart';

/// 假 PathProvider:AppSupport 目录锚到临时目录(默认库文件解析测试用)。
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.supportPath);
  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

db.AccountsCompanion _accountRow(String id) => db.AccountsCompanion.insert(
      id: id,
      name: 'Cash',
      accountType: 1,
      category: 2,
      currencyCode: 'CNY',
      initialBalanceCents: 100,
      currentBalanceCents: 100,
      ownership: 1,
      icon: '',
      color: '',
      chartCode: '1001',
      isSystem: false,
      sortOrder: 0,
      institution: '',
      cardNumberTail: '',
      notes: '',
      goldProductType: '',
      status: 1,
      version: 3,
      createdAt: DateTime.utc(2026, 9, 14),
      updatedAt: DateTime.utc(2026, 9, 14),
    );

void main() {
  late db.AppDatabase database;
  late LocalSnapshotExporter exporter;
  late Directory tmp;
  late List<File> dbFiles; // 模拟测试库三件套(yucai_test.db/-wal/-shm)

  setUp(() async {
    database = db.AppDatabase(NativeDatabase.memory());
    exporter = LocalSnapshotExporter(database);
    tmp = await Directory.systemTemp.createTemp('yucai_f21_reset');
    final base = '${tmp.path}/yucai_test.db';
    dbFiles = [File(base), File('$base-wal'), File('$base-shm')];
    for (final f in dbFiles) {
      await f.writeAsBytes([1, 2, 3]); // 模拟既有库文件(含边车)
    }
    await database.accountDao.insertAccount(_accountRow('a1'));
  });

  tearDown(() async {
    try {
      await database.close();
    } catch (_) {}
    try {
      await tmp.delete(recursive: true);
    } catch (_) {}
  });

  DataResetController mk({
    ExitFn? exitFn,
    WriteBackupFn? writeBackup,
    DbFilesFn? dbFilesFn,
  }) =>
      DataResetController(
        database: database,
        exporter: exporter,
        exitFn: exitFn,
        writeBackup: writeBackup,
        dbFiles: dbFilesFn ?? () async => dbFiles,
      );

  test('stats():数据规模(账户/交易计数)', () async {
    final controller = mk();
    final stats = await controller.stats();
    expect(stats.accounts, 1);
    expect(stats.transactions, 0);
  });

  test('reset():备份先行(可解密)→ 关库 → 删主文件+-wal+-shm', () async {
    final controller = mk();
    final backupPath = '${tmp.path}/yucai-reset-backup.ycb';
    await controller.reset(backupPath: backupPath, password: 'pw-123');

    // 备份已写入,且用同一密码能解开并还原 envelope(真导出+真加密链)。
    final sealed = await File(backupPath).readAsBytes();
    final envelope =
        jsonDecode(utf8.decode(ArchiveCodec.decrypt(sealed, 'pw-123')))
            as Map<String, dynamic>;
    expect((envelope['modules']['account'] as List), hasLength(1));

    // 库已关闭(再查询抛 StateError),三件套全删(FR-4)。
    await expectLater(
        database.accountDao.getAllAccounts(), throwsStateError);
    for (final f in dbFiles) {
      expect(f.existsSync(), isFalse, reason: '${f.path} 应已删除');
    }
  });

  test('reset():备份写失败 → fail-closed,库文件未删、库仍可查询', () async {
    final controller = mk(
      writeBackup: (file, bytes) async {
        throw const FileSystemException('disk full');
      },
    );
    await expectLater(
      controller.reset(
          backupPath: '${tmp.path}/never.ycb', password: 'pw-123'),
      throwsA(isA<FileSystemException>()),
    );

    // fail-closed:没有任何清空副作用 —— 三件套仍在,库仍可正常查询。
    for (final f in dbFiles) {
      expect(f.existsSync(), isTrue, reason: '${f.path} 不应被删');
    }
    expect(await database.accountDao.getAllAccounts(), hasLength(1));
  });

  test('exitApp():走注入的 ExitFn 缝(不真退出进程)', () async {
    Object? caught;
    final controller = mk(
        exitFn: () => throw StateError('exit-seam-called'));
    try {
      controller.exitApp();
    } catch (e) {
      caught = e;
    }
    expect(caught, isA<StateError>());
  });

  test('默认库文件解析:与 AppDatabase 同名 dart-define,三件套齐', () async {
    // 假 PathProvider 锚定临时目录;dbFiles 缝未注入 → 走生产默认解析。
    final support = await Directory.systemTemp.createTemp('yucai_f21_path');
    addTearDown(() async {
      try {
        await support.delete(recursive: true);
      } catch (_) {}
    });
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _FakePathProvider(support.path);
    addTearDown(() => PathProviderPlatform.instance = previous);

    final resolved = await DataResetController.resolveDbFiles();
    // 同一解析规则:文件名 = AppDatabase.dbFileName(YUCAI_DB_FILE
    // dart-define;flutter test 未传 → 缺省 yucai.db),主文件 + -wal + -shm。
    final base = '${support.path}/${db.AppDatabase.dbFileName}';
    expect(db.AppDatabase.dbFileName, 'yucai.db');
    expect(resolved.map((f) => f.path).toList(),
        [base, '$base-wal', '$base-shm']);
  });
}
