# Code Plan — D6 restore purge+import 跨模块 tx 原子

- [ ] T1 Service.purgeAndImport helper(WithTx 包两循环)+ restoreNoSafety/uploadImport 接线 + RestoreBackup 注释更新
- [ ] T2 Purge/Import 方法体 clientFor 存在性 grep(8 exporter 链)
- [ ] T3 测试:回滚 oracle ×2(import 中途/purge 失败)+ 完整成功 + uploadImport 原子性(扩充 G 的 4 测试)
- [ ] T4 go test 全绿 + 提交

## 执行记录(2026-08-23)

- T1 ✓ Service.purgeAndImport(WithTx ReadCommitted)两入口接线 + safety 注释更新。
- T2 ✓ 审计 backup 链:11 repo 已有 clientFor;**backup 链上 7 处裸 r.client** (budget Save/DeleteByTenant·debt DeleteByTenant·goal Save/DeleteByTenant·tag Save/DeleteByTenant)→ 全部改 clientFor(ctx)(16 处引用)。其余裸 client(auth/backup/sync 等非 backup 链)不动。
- T3 ✓ 回滚 oracle ×2:真 DB(testDB 上建 account ent schema 的真 port + failingImportPort)——**fakePort 测不了回滚**(内存突变非 tx 参与者,upload 测试曾假绿);oracle 非空验证:临时去 tx → upload 测试 FAIL ✓(restore 测试 vacuous 风险记录:restore 路径的 noTx 下 safety-backup 流程差异,以 upload oracle 为准)。
- 测试基建:testDB DSN 加 `_pragma=foreign_keys(1)`(modernc v1.52 语法,ent migrate 要求)。
- T4 ✓ go test ./... 61 包全绿。
