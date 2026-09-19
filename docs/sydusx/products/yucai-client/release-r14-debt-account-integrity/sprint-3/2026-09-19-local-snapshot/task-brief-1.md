# Task Brief — F39 guest 本地快照闭环(TDD)

## 既有设施(全部已存在,复用第一)
- `LocalSnapshotExporter.exportAll()` → 全模块 envelope JSON bytes(注入就绪,清空数据流程同款)。
- `ArchiveImporter.importAll(envelopeJson)` → 清空并整批替换本地库;完成后必须 `getIt<DataRefreshNotifier>().bump()`(照 settings_page 导入存档 hotfix 模式)。
- app_meta 标记门控模式:照 repairs.dart(`f36_liability_balance_repair_v1`)。
- 设置页:`lib/settings/presentation/settings_page.dart`(已有 导出存档/导入存档 按钮,新section与其并列)。

## 任务
1. **新服务** `lib/settings/data/local_snapshot_service.dart`(或 backup/data/ 下,自行判断归属并说明):注入 AppDatabase + LocalSnapshotExporter + ArchiveImporter。
   - `runDailyIfDue()`:app_meta 键 `local_snapshot_last_date`;今天已跑 → 直接返回。否则 `runNow()` 后把标记置为今天(UTC 日期)。全 try/catch 静默(照 repair 惯例,失败不影响启动)。
   - `runNow()`:exportAll() → 写文件 `<appSupport>/local_backups/snapshot-YYYYMMDD-HHMMSS.json`(Directory.create recursive);按文件名倒序保留**最近 7 份**,更旧的删除。
   - `listSnapshots()`:返回 `{fileName, sizeBytes, modified}` 列表(倒序)。
   - `restoreFrom(fileName)`:读文件 bytes → **确认逻辑在 UI 层**;service 里 importAll(bytes) → 返回。
   - `deleteSnapshot(fileName)`:删除文件;**安全约束**:仅允许删除 `local_backups/` 目录内、文件名匹配 `snapshot-*.json` 的文件(防路径穿越)。
2. **启动挂载**:settings_page 或 main 的初始化钩子处(侦察现有 main() 初始化顺序,选择 configureDependencies 完成后的合适位置)调用 `runDailyIfDue()`——fire-and-forget,不阻塞首屏。
3. **设置页 UI**:新 section「本地快照」(与导出/导入存档并列):显示快照列表(文件名+大小+修改时间)+ 「立即快照」按钮 + 每行「恢复」「删除」操作;恢复需确认对话框(「恢复将覆盖当前所有数据,不可逆」);操作后 DataRefreshNotifier.bump() + toast。
4. **DI**:服务注册照 injections 惯例(手工注册或 injectable 注解,与文件归属一致并说明)。

## TDD
测试文件 `test/settings/data/local_snapshot_service_test.dart`(照 template_local_ds_test 的临时库风格):
1. runNow 生成 1 份快照文件(内容可被 ArchiveImporter 解析——可断言文件非空+首字节为 `{`);同日重复 runDailyIfDue 不重复生成。
2. 生成 9 份(改文件时间戳模拟)→ runDailyIfDue → 仅剩 7 份且保留最新。
3. restoreFrom:预置快照 → 先改库(插入一条标记数据)→ restoreFrom → 库回到快照状态(importAll 语义)。
GREEN 后回归 `flutter test test/settings/ test/core/localdb/` + analyze 零新增。

## 约束
**禁止 git stash/checkout/restore**;只动 上述新文件 + settings_page.dart + 测试;勿提交 git;English 注释与日志(用户可见文案中文)。
工作目录:`C:/Users/BuHiYo-001/Desktop/projects/desktop/syfinance/.claude/worktrees/r14-f39`
完成后报告:改动文件、RED→GREEN 证据、回归结果、DI 归属选择说明;BLOCKED 即停。
