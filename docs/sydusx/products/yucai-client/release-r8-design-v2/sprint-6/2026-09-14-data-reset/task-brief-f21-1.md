# Task Brief F21-T1 — 清空数据全链

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f21`,客户端 `yucai/client/`。**TDD。**

## 先读(必读)
1. `docs/.../2026-09-14-data-reset/spec.md`
2. `lib/settings/presentation/settings_page.dart`(导出/导入存档区 :155-180 + _showExportArchive :337——**直接模板**:密码 dialog/FilePicker.saveFile/ArchiveCodec.encrypt;本功能在 data 区加第三行)
3. `lib/backup/data/archive_codec.dart`(YC1E 加密)+`local_snapshot_exporter.dart`(exportAll)
4. `lib/core/localdb/app_database.dart`(db 文件路径逻辑——YUCAI_DB_FILE dart-define 或默认 yucai.db;drift NativeDatabase 的 -wal/-shm)
5. `lib/core/session_mode/bound_marker.dart`(isBound——绑定态隐藏判定)
6. `integration_test/link_support.dart`(测试库守卫——**清空绝不能碰真实库**,同守卫)

## 交付物
### 1. 设置页入口+三步流(FR-1/2/3/4)
`settings_page.dart` data 区加「清空数据重新开始」行(negative 色,绑定态 `BoundMarker.isBound()` 为真时整行隐藏+注释)→ `_showResetData`:
- 步①警示 dialog:数据规模(db 查 accounts/transactions count)+ 三警示 +「我已了解风险」按钮(negative);
- 步②密码+位置:TextField 密码(照导出存档的密码 dialog 形态)+ 默认文件名 `yucai-reset-backup-yyyyMMdd-HHmm.ycb` + FilePicker.saveFile;**取消/失败→直接 return(中止)**;
- 步③最终确认:备份路径+「该密码用于日后找回」+红色「确认清空」;
- 执行:exportAll→ArchiveCodec.encrypt(密码)→写文件(失败→error dialog 中止)→ `getIt<AppDatabase>().close()` → 删 db 文件+`-wal`/`-shm`(若存在;**路径来自 AppDatabase 同款 dart-define 解析——抽小 helper 复用,或直接读同逻辑**;**NFR 守卫:YUCAI_DB_FILE 非 yucai_test.db 时……真实库就是要删的目标,不需要测试守卫——但集成测试用 test 路径**)→ 「已清空并备份到 <路径>;设置→导入存档+该密码 可找回;应用即将退出」→ `exit(0)`。
- 注释:进程重启论证(DI/getIt 热重置复杂);备份失败 fail-closed 论证。

### 2. TDD
- widget 测:入口渲染(guest)/绑定态隐藏/三步流(点「我已了解风险」→密码框→确认)/步②取消→不触清空(mock/注入缝——清空执行抽 `DataResetController`(新,注入 settings_page 或独立类)便于 mock;**文件写与 exit 抽缝**,exit 用 `Never Function()` 注入或 `ExitFn` typedef)。
- 集成/单测:DataResetController(真 drift 内存+真导出加密→临时文件→关删[测试库路径]断言);备份写失败→库未被删。
- settings_page 既有测试适配。

### 3. 门
`flutter test` 全量+analyze 0 新增+`make client-e2e F=integration_test/app_pages_test.dart` 抽验。

## 约束
R8 令牌;中文文案;不改既有导出/导入逻辑(复用);不 commit。完成后报告。
