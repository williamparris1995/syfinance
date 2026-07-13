# 本地备份 UI · 设计 spec

- **日期**: 2026-07-13
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: backup/sync decompose 第一个子项目 —— **本地备份 UI**(BackupService 本地 4 RPC),client DDD 四层新建
- **decompose**: backup/sync 巨型(14 RPC,3 子系统),本地备份先;云备份(4 RPC)+ 多设备同步(6 RPC)后续独立 spec

## 1. 背景

御财 backup/sync **server 全实现**(BackupService 8 RPC + SyncService 6 RPC = 14),client proto stub 全有但**无 UI**。memory `holding-asset-management-todo` 高优先级("后续模块 backup/sync UI > tag/template")。

backup/sync 巨型,按 brainstorming skill **decompose**:
- **本地备份**(BackupService 本地 4 RPC)—— 本 spec
- 云备份(BackupService 云 4 RPC:CloudSettings/Test/Upload)—— 后续
- 多设备同步(SyncService 6 RPC:Device/Push-Pull/Conflict)—— 后续

## 2. 目标

本地备份 client UI(创建/恢复/列表/删除),settings 子页,client DDD 四层新建。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| BackupService 本地 4 RPC(CreateBackup/RestoreBackup/ListBackups/DeleteBackup) | 云备份(4 RPC:CloudSettings/Test/Upload) |
| client DDD 四层(data/domain/presentation/core) | 多设备同步(SyncService 6 RPC) |
| settings 子页 /settings/backup + CRUD 交互 | auto-backup scheduler(client 只展示 auto 标记) |

**零 proto/server 改动**(BackupServiceClient stub + BackupDTO 全有)。

## 4. 决策记录(brainstorm 拍板)

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | decompose | 本地备份先(4 RPC) | backup/sync 14 RPC 巨型,decompose 单 spec |
| 2 | 导航 | settings 子页 `/settings/backup` | backup 低频设置型功能 |
| 3 | 页面 | 标准 CRUD list(header 创建 + card list + 每项操作) | 对齐御财 list 模式(debts/budget) |
| 4 | 改动 | client DDD 四层新建 | data/domain/presentation/core;零 proto/server |
| 5 | auto backup | 展示标记(server scheduler 创建标 auto) | client 不创建 auto(CreateBackupRequest 无 auto 字段),只展示 |
| 6 | encrypted | 创建时 dialog 选(CreateBackupRequest.encrypted) | 用户选加密与否 |

## 5. 架构(client DDD 四层)

| 层 | 组件 | 职责 |
|---|---|---|
| **data**(`lib/backup/data/`) | `BackupRemoteDataSource`(@LazySingleton)+ `BackupRepositoryImpl` + `backup_mapper.dart` | 4 RPC(AuthRetryCaller wrap,对齐 holding/debt)+ Either<Failure> + proto→entity |
| **domain**(`lib/backup/domain/`) | `Backup` entity(Equatable)+ `BackupRepository` abstract | entity(id/filename/sizeBytes/checksum/encrypted/auto/createdAt)+ repo 接口(list/create/restore/delete) |
| **presentation**(`lib/backup/presentation/`) | `BackupBloc`(@injectable)+ `BackupPage` + `BackupCard` | event(load/create/restore/delete)+ state(Loading/Loaded/Error)+ UI |
| **core** | DI(@injectable)+ router | /settings/backup route + build_runner |

**零 proto/server**(BackupServiceClient 8 method stub 全有;BackupDTO 字段全有)。

## 6. 页面结构 + 交互

### 6.1 BackupPage

- **Header**:标题"本地备份" + "立即备份" FilledButton
- **ListView**:`BackupCard[]`(对齐御财 list 卡片模式)
- **empty state**:"暂无备份,点击'立即备份'创建"
- **error state**:BackupError(msg) + retry button

### 6.2 BackupCard

- filename / sizeBytes(MB 格式)/ createdAt(日期)
- `auto` + `encrypted` chip 标签(BackupDTO.auto / encrypted)
- trailing:恢复(lucide `rotateCcw`)+ 删除(lucide `trash2`)icon button

### 6.3 交互

| 操作 | 流程 |
|---|---|
| **创建** | "立即备份" button → encrypted dialog("加密备份?"是/否)→ `CreateBackup(encrypted)` → 列表刷新 + toast |
| **恢复** | card restore icon → **confirm dialog**("⚠️ 恢复将覆盖当前所有数据,此操作不可逆,确定?")→ `RestoreBackup(id)` → toast"恢复成功,请重启应用" |
| **删除** | card delete icon → confirm("确定删除此备份?")→ `DeleteBackup(id)` → 列表刷新 |
| **in-progress** | AbsorbPointer + loading spinner(button / card) |

## 7. 降级 + 测试

**降级**:
| 场景 | 处理 |
|---|---|
| RPC fail(list/create/restore/delete) | `BackupError(msg)` + retry button |
| 空列表 | empty state |
| 操作 fail(restore/delete) | snackbar 错误信息,列表保持 |
| 创建/恢复/删除 in-progress | AbsorbPointer + spinner |

**测试**:
- **BackupBloc** test(mocktail `MockBackupRepository`;load/create/restore/delete + state 流)
- **widget test**(BackupPage:列表渲染 + 创建 dialog + 恢复/删除 confirm + empty/error state)
- **mapper test**(BackupDTO → Backup entity)
- **回归**:backup 新模块,零 cross-module 影响(现有测不破)

## 8. 风险

1. **恢复覆盖**(restore 覆盖当前数据)—— confirm 警告 + toast"请重启"(server restore 后数据需重载)
2. **encrypted 选项**(CreateBackupRequest.encrypted)—— dialog 选(bool)
3. **settings 集成**(router /settings/backup Branch + settings 页入口项)—— 对齐 settings shell(branch 8)
4. **backup 列表分页**(ListBackupsRequest.Page)—— PageSize 100 够(backup 少,不分页 UI)

## 9. 实施顺序(供 writing-plans,约 4 task)

```
Task 1  domain(Backup entity + BackupRepository abstract)+ data(BackupRemoteDataSource 4 RPC + BackupRepositoryImpl + mapper)+ 测(TDD)
Task 2  presentation:BackupBloc(event/state)+ 浸(mocktail)
Task 3  BackupPage + BackupCard + 交互(创建 encrypted dialog / 恢复 confirm / 删除 confirm / in-progress)+ widget test
Task 4  router /settings/backup + settings 入口项 + DI(@injectable)+ build_runner + 回归
```

## 10. backup/sync decompose 状态

| 子系统 | RPC | 状态 |
|---|---|---|
| **本地备份**(本 spec) | CreateBackup/RestoreBackup/ListBackups/DeleteBackup(4) | brainstorm done,待 plan/实现 |
| 云备份 | SaveCloudSettings/GetCloudSettings/TestCloudConnection/UploadToCloud(4) | 后续独立 spec |
| 多设备同步 | RegisterDevice/GetSyncStatus/PushChanges/PullChanges/ResolveConflict/ListConflicts(6) | 后续独立 spec |

## 11. 参考

- server proto:[backup.pb.go BackupDTO](../../yucai/server/internal/proto/backup/v1/backup.pb.go#L85)(id/provider/filename/sizeBytes/checksum/encrypted/auto/createdAt)+ BackupService 8 RPC
- client stub:[BackupServiceClient](../../yucai/client/lib/proto/backup/v1/backup.pbgrpc.dart)(8 method)
- memory:[[holding-asset-management-todo]](backup/sync 高优先级)/ [[yucai-dev-env]]
