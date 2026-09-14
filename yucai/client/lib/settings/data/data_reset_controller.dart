import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import 'package:yucai_client/backup/data/archive_codec.dart';
import 'package:yucai_client/backup/data/local_snapshot_exporter.dart';
import 'package:yucai_client/core/localdb/app_database.dart';

/// 进程退出缝(spec FR-4):生产 = `exit(0)`;测试注入抛哨兵/记录调用的
/// 假实现,避免单测真杀进程。返回 [Never] 表达「不回来」。
typedef ExitFn = Never Function();

/// 库文件集解析缝:返回主库文件 + `-wal`/`-shm` 边车(存在与否在删除时
/// 逐一判断)。测试注入临时目录路径,生产走 [DataResetController.resolveDbFiles]。
typedef DbFilesFn = Future<List<File>> Function();

/// 备份写文件缝:测试注入抛错实现以覆盖 fail-closed 分支。
typedef WriteBackupFn = Future<void> Function(File file, Uint8List bytes);

/// 清空数据重新开始(F21-T1)——执行面控制器。
///
/// 设置页三步确认流的第④步落点:备份先行(fail-closed)→ 关库 → 删库
/// 文件 → 由调用方提示后经 [exitApp] 退出进程。
///
/// **备份先行 fail-closed 论证(spec FR-3)**:执行顺序刻意为
/// 导出 → 加密 → 写备份文件 →(全部成功才)关库 → 删库文件。任何一步
/// 抛出即整体中止,关库/删库一行都不会执行——磁盘满/路径不可写/权限
/// 失败时用户数据原样保留,绝无「备份没写成却把库删了」的路径。
///
/// **进程重启论证(spec FR-4)**:清空后 DI/getIt 里仍持有大量围绕旧库的
/// 热状态(bloc / notifier / DAO / 后台 isolate 连接),进程内热重置需要
/// 逐一 reset 并保证零遗漏,复杂且易漏;直接 `exit(0)` 让用户重启后从空库
/// 全新走 configureDependencies 是最干净的路径。
class DataResetController {
  DataResetController({
    required AppDatabase database,
    required LocalSnapshotExporter exporter,
    ExitFn? exitFn,
    DbFilesFn? dbFiles,
    WriteBackupFn? writeBackup,
  })  : // 命名参数无法用 this._x 初始化私有字段(照 settings_page 同款形态)。
        _database = database, // ignore: prefer_initializing_formals
        _exporter = exporter, // ignore: prefer_initializing_formals
        _exit = exitFn ?? _defaultExit,
        _dbFiles = dbFiles ?? resolveDbFiles,
        _writeBackup = writeBackup ?? _defaultWriteBackup;

  final AppDatabase _database;
  final LocalSnapshotExporter _exporter;
  final ExitFn _exit;
  final DbFilesFn _dbFiles;
  final WriteBackupFn _writeBackup;

  static Never _defaultExit() => exit(0);

  /// flush: true —— 删除源库前强制落盘,避免「备份仍在 OS 页缓存、库
  /// 已删」的崩溃窗口。
  static Future<void> _defaultWriteBackup(File file, Uint8List bytes) =>
      file.writeAsBytes(bytes, flush: true);

  /// 生产默认库文件集解析:与 [AppDatabase._openConnection] 同一
  /// dart-define 事实源([AppDatabase.dbFileName])——集成测试跑
  /// `--dart-define=YUCAI_DB_FILE=yucai_test.db` 时这里删的就是测试库;
  /// 生产缺省 `yucai.db`,真实库正是本功能要删的目标(无需测试守卫)。
  static Future<List<File>> resolveDbFiles() async {
    final dir = await getApplicationSupportDirectory();
    final base = '${dir.path}/${AppDatabase.dbFileName}';
    return [File(base), File('$base-wal'), File('$base-shm')];
  }

  /// 数据规模(步① 警示 dialog 用):账户数 + 交易数。
  Future<({int accounts, int transactions})> stats() async => (
        accounts: (await _database.accountDao.getAllAccounts()).length,
        transactions:
            (await _database.transactionDao.getAllTransactions()).length,
      );

  /// 清空执行:备份先行 → 关库 → 删库文件(主文件 + `-wal`/`-shm`,若存在)。
  ///
  /// 任一步失败即抛出且**不做任何清空**(fail-closed,见类注释);调用方
  /// 捕获后中止流程并提示。备份复用导出存档既有链
  /// ([LocalSnapshotExporter.exportAll] + [ArchiveCodec.encrypt]),可用
  /// 「设置 → 导入存档 + 该密码」找回(spec FR-5,零新开发)。
  Future<void> reset({
    required String backupPath,
    required String password,
  }) async {
    // 1. 备份先行:导出 → 加密 → 写文件。任一失败 → 抛出,库原样保留。
    final envelope = await _exporter.exportAll();
    final sealed = ArchiveCodec.encrypt(envelope, password);
    await _writeBackup(File(backupPath), sealed);

    // 2. 备份已安全落盘,才开始清空:先关库(释放文件句柄,Windows 上
    //    不关直接删会失败 —— 同 link_support.deleteTestDb 的两步顺序)。
    await _database.close();

    // 3. 删库文件:三件套逐一「存在才删」,重启后 drift 按空库重建。
    for (final f in await _dbFiles()) {
      if (await f.exists()) await f.delete();
    }
  }

  /// 退出进程(经 [ExitFn] 缝;见类注释的进程重启论证)。
  Never exitApp() => _exit();
}
