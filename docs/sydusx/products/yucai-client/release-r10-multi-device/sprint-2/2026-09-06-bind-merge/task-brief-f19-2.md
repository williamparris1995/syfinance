# Task Brief F19-T2 — 合并全链 e2e + 全量门

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r10-f19`,客户端 `yucai/client/`。T1(6119ba58)已就绪。

## 先读(必读)
1. `docs/.../2026-09-06-bind-merge/{spec.md FR-6,design.md ADR-5}`
2. `integration_test/link_offline_sync_e2e_test.dart`(fake 能力现状:push 落 log/listConflicts/resolveConflict;**需扩:预置 server 数据**——fake 初始化时可注入 server 端已有行+push 存在性检测模拟或直接用 conflictEntityIds 机制)
3. T1 的 binding_bloc(合并链——e2e 直接驱动 BindingBloc 或经 UI;选**直接驱动 bloc**(注入 fake port),UI 已有 widget 测——注释取舍)

## 交付物
### 1. e2e 合并全链(FR-6)
`integration_test/link_bind_merge_e2e_test.dart`(新,Makefile E2E_FILES 尾追加):
- **场景① 空账号绑定=纯上传**:本地种数据→驱动 BindingBloc(guard→readyToUpload→confirm)→断言 fake 收到全量批次(200 拆分序)→本地全 synced→markBound→设备注册。
- **场景② 非空合并(不同 id 并集)**:fake 预置 server 端账户行(设备 X 的)→本地种不同 id 数据→guard→readyToMerge(摘要含 server 计数)→confirm→push 全量(server 行不同 id 不冲突)→refreshAll 后本地=并集(server 行+本地行都在)→success。
- **场景③ 残留冲突(同 id 不同内容)**:fake 预置与本地同 id 不同 payload 的行(模拟曾绑同账号)→confirm→push 命中 fake 冲突机制(conflictEntityIds 或预置行+检测)→断言:本地行标 synced(确认)+success 带冲突计数+badge 冲突态数据。
- **场景④ 断点续传**:第 1 批成功+第 2 批 fake 返回 unavailable→failed(canResume)→fake 恢复→retry→只推剩余(mock fake 记录批序列断言)→success。
- fake 扩展:`presetServerRows`(初始化注入 push 时模拟存在性——不同 id 忽略/同 id 同 payload 短路/同 id 不同 payload 入 conflicts)——或最简:复用 conflictEntityIds + 预置 log 行;实现者按 fake 架构选,注释取舍。

### 2. 全量门
- `flutter test` 全量(≥1579)+analyze
- `make client-e2e`(13 文件)+`client-e2e-ui F=integration_test/ui_boot_subscription_test.dart` 抽验
- `go test ./...`(保险)

## 约束
生产代码零改动(fake/e2e/Makefile 尾追加);中文注释;不 commit。完成后报告。
