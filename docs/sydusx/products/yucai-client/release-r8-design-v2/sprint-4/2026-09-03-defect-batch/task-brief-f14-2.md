# Task Brief F14-T2 — 测试债收口:goPage 迁移 + 三套件 tearDown 迁移

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f14`,客户端 `yucai/client/`。

## 交付物

1. **goPage 迁 link_support**:11 个 ui_* 测试文件逐字重复的 goPage helper(F9 ledger 记账,~200 行收口)——提取到 `integration_test/link_support.dart`(签名不变,中文注释注明来源与 F9 首次记账);11 文件改调共享版(删除本地副本);若各文件副本有微小漂移(参数/等待时长)——先 diff 全部副本,有漂移则统一或保参(默认参+可选参),注释裁决。
2. **三套件 tearDown 迁移**:`app_pages_test.dart`/`linked_transactions_test.dart` 的 tearDownAll 改用 `deleteTestDb()`(close 后删,Windows 句柄修复版);`full_audit_test.dart` **无 tearDownAll**(F6 查证)——补 `deleteTestDb()`。注意三文件现有删库代码删除;真实库安全(NFR-1 守卫在 resetTestDb,deleteTestDb 同守卫?查 link_support——若无守卫补上:YUCAI_DB_FILE 非 yucai_test.db 拒删)。
3. **验证**:11 个 ui 文件逐个单跑绿(-d windows --dart-define=YUCAI_DB_FILE=yucai_test.db,杀残留——**11 文件全跑,这是收口的回归保证**);三套件单跑绿;flutter test 全量;analyze。

## 约束
生产代码零改动;helper 行为逐位不变(等待时长等);不 commit。完成后报告(含副本漂移裁决)。
