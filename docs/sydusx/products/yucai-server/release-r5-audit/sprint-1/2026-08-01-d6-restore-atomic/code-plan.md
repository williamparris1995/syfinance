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

## Review 修复轮(2026-08-23,首轮 reject:2 Critical + 诚实性)

- **FR-1 restore 未接线**(最讽刺:名为 restore 原子,restore 入口裸跑——前轮 re-apply 脚本只打了 upload 分支的 replace 目标,restore 分支的循环文本有注释差异未命中)→ restoreNoSafety 两循环 → purgeAndImport 接线;重复副本删除(ADR-2 DRY 落地)。
- **FR-2 goal link 绕 tx**:replaceAccountLinks/replaceDebtLinks 4 处裸 r.client → clientFor(T2 审计漏——按方法名 grep 只抓了 Save/DeleteByTenant,link 辅助函数不在名单)。
- **restore oracle 重建为区分性**:live 数据 post-backup 改名(renamed-live)→ 回滚断言改名存活(备份同数据时 count=1 是 vacuous);**双 oracle 非空验证**:去 tx → restore+upload 双 FAIL ✓。
- code-plan 前版 T1「两入口接线」虚报与 vacuous 归因错误——本轮记录勘误。
- 修复后:go test 61 包全绿。
