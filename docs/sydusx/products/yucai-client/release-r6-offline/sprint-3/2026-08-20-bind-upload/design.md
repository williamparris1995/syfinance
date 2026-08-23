---
feature: 2026-08-20-bind-upload
status: drafted
---

# Design — 绑定上传(envelope 导出 + UploadBackup + 绑定向导)

> 消费 [spec.md](spec.md)(confirmed,通路裁定 B)。server 锚点:RestoreBackup(service.go:134-218)=safety 快照→restoreNoSafety(download→checksum→decrypt→decompress→unmarshal→**purge 循环→import 循环**);envelope=BackupEnvelope{Version,TenantID,CreatedAt,Modules map};Import 吃 json.RawMessage→json.Unmarshal 进领域结构体(Go 忽略未知键)。

## Context

离线→上云的一次性迁移:client 导出 envelope → 新 RPC 原子上云 → 回切 server 权威。

## Goals / NonGoals

- **Goals**:server UploadBackup RPC(复用 D6 路径)/client 8 模块导出器/guard/绑定向导。
- **NonGoals**:合并(非空账号)/镜像(H)/加密上传(J 复用时对齐;v1 明文 envelope 经 TLS)/tag 联结(契约不含)。

## Decisions(ADRs)

### ADR-1 server:`UploadExternal` 服务方法照抄 restoreNoSafety 的 purge+import 段
- **Decision**:Service 增 `UploadExternal(ctx, tenantID, data []byte, password string)`:①`safety backup`(照抄 RestoreBackup 步骤1/3——空账号场景 purge 是空操作,快照是防御纵深,保留);②`json.Unmarshal(data)`→version 校验;③**`envelope.TenantID = 鉴权 tenantID`**(覆盖,防跨租户注入);④purge 循环+import 循环逐字照抄。**不落备份存储、不 compress**(client 直传明文 JSON,单次操作体积可接受)。password 参数保留 v1 不用(空=envelope 明文;对齐 J 的加密演进)。
- **Rationale**:最大复用 R5 加固;数据路径与 server 自产备份 restore 完全一致。
- **Alternatives**:①落盘成 backup 文件再走 RestoreBackup——多余一次存储往返,reject;②要求 client gzip——体积优化非必要。

### ADR-2 proto:`UploadBackup(UploadBackupRequest) → Empty`
- **Decision**:`message UploadBackupRequest { bytes data = 1; string password = 2; }`;handler 鉴权 tenant 解析→Service.UploadExternal。proto regen 走 `make gen-dart`(client stub 同步)。

### ADR-3 client:`LocalSnapshotExporter`(backup/data/)——8 模块手写 mapper
- **Decision**:`exportAll() → Uint8List(json)`:envelope{version:1, tenant_id:占位(server 覆盖), created_at:now, modules×8}。每模块 = DAO 全量行 → PascalCase json map 手写(与 server 领域结构体 marshal 同构:int 枚举/RFC3339Nano/嵌套:transaction.entries·debt.Schedule·budget.Items/goal.LinkedAccountIDs·LinkedDebtIDs 数组聚合/holding 两兄弟数组 holdings+transactions)。**字段清单以 D 轮 research 的 8 模块 payload 表为施工图**(account 47 字段等);Go 端忽略未知键→client 可多不可缺。幂等只读。
- **Rationale**:形状正确性是唯一硬点;手写映射直白可审查,round-trip 测试逐字段钉死。
- **Alternatives**:代码生成(从 Go struct 反射生 Dart mapper)——工具链成本超收益,reject。

### ADR-4 guard 与验证复用双源 repo
- **Decision**:guard/成功验证直接用现有 `AccountRepository.list`/`TransactionRepository.list`/`HoldingRepository.listHoldings`——**登录后 tracker.isGuest 已自动 false,这些调用天然走远端**(C 范式的意外红利,零新代码)。guard 判据=三面任一非空;验证=上传后三面条目数与本地一致。

### ADR-5 绑定流程:`BindingBloc` + `/binding` 向导页
- **Decision**:新路由 `/binding`(bind-only 守卫无需——向导自身检查 Authenticated);`BindingBloc` 状态机 `idle→guarding→blocked(非空)|uploading→success|failed(可重试)`;设置页登录按钮处监听 AuthBloc:Authenticated 且本地业务数据非空(drift counts>0)→ `context.push('/binding')`;本地空→直接在线(无向导)。向导 UI 三步(guard 结果→上传确认(明示单向覆盖语义)→进度/结果)。
- **Rationale**:独立 bloc/route 不污染 AuthBloc;触发点单一(设置页)。

### ADR-6 client DS:`backup_remote_ds` +`uploadBackup(Uint8List)`
- **Decision**:薄封装 `pb.UploadBackupRequest(data: bytes)`,经 `_retry`。

## HLD

```
server(backup 模块内):
  proto/backup/v1/backup.proto            +UploadBackupRequest/rpc
  adapter/driving/grpc/backup_handler.go  +UploadBackup(鉴权 tenant→service)
  application/service.go                  +UploadExternal(safety+purge+import)
  application/service_test.go             +单测(解析/tenant 覆盖/原子/空 envelope)
client:
  backup/data/local_snapshot_exporter.dart   新(8 模块 mapper,~600 行)
  backup/data/backup_remote_ds.dart         +uploadBackup
  binding/presentation/bloc/binding_bloc.dart 新(状态机)
  binding/presentation/pages/binding_page.dart 新(三步向导)
  app/router.dart                            +/binding 路由
  settings/presentation/settings_page.dart   登录成功→本地有数据→push /binding
  proto regen(make gen-dart)
```

## LLD 要点

### UploadExternal 伪码

```
safety := CreateBackup(auto=true)           // 照抄步骤1
err := func():
  envelope := json.Unmarshal(data)
  if envelope.Version != 1 → ErrBackupFormatOutdated
  envelope.TenantID = tenantID              // 鉴权覆盖
  for p in orderedPortsForPurge: p.Purge()
  for p in orderedPortsForImport:
    if raw ok := envelope.Modules[p.Name()]: p.Import(raw)
err==nil → DeleteBackup(safety)(best-effort)
```

### 导出器模块映射施工图(键名/形状对 D 轮 payload 表)

| 模块 | drift 行→json 要点 |
|---|---|
| account | `[]{ID,TenantID,...47 字段 PascalCase}`;DeletedAt 恒 null(本地硬删);ParentID 可空 |
| transaction | `[]{...,Entries:[{ID,TransactionID,AccountID,ChartOfAccountCode,DebitCents,CreditCents,Note}]}` |
| debt | `[]{...,Schedule:[...嵌套]}`;CollectionAccountID 可空 |
| budget | `[]{...,Items:[...]}`;Month 直存 |
| goal | `[]{...,LinkedAccountIDs:[uuid],LinkedDebtIDs:[uuid]}`(联结表聚合) |
| tag | `[]`平铺 |
| template | `[]`平铺(20 字段) |
| holding | `{holdings:[...],transactions:[...]}` 两兄弟数组 |

时间:RFC3339Nano(`toUtc().toIso8601String()` 与 Go time.Time JSON 互通[毫秒微差 Go 可解析])。

### BindingBloc 状态机

```
events: StartRequested/ConfirmUploadRequested/RetryRequested/DismissRequested
states: idle/guarding/blocked(原因)/uploading/success(验证摘要)/failed(原因)
guard=3 面远端 list;upload=exporter.exportAll→ds.uploadBackup;success=3 面条目比对
```

### 测试计划

- server:UploadExternal ×4(正常导入 purge+import 顺序/tenant 覆盖[伪 tenant 被改]/坏 JSON/version 不符;safety 快照行为[成功删/失败留])。
- client:exporter round-trip ×8(逐字段形状断言,重点 account 全字段/goal 聚合/holding 兄弟);BindingBloc 表驱动;backup_remote_ds.uploadBackup(mock grpc);设置页触发逻辑(本地空/非空两路)。
- 既有回归全套基线。

## Risks

- **R1 形状漂移**(client mapper vs server struct)——round-trip 逐字段测试+server 单测吃真实 client 形状样本;Go 忽略未知键降低缺键单向风险。
- **R2 时间格式精度**(ISO8601 毫秒 vs Go 期望 RFC3339)——Go time.Time UnmarshalJSON 接受 ISO8601 ✓(测试钉)。
- **R3 大数据量 RPC**(几 MB)——gRPC 默认 4MB 上限;个人理财数据量远低,记 accepted;超限时 future 分块。

## Migration

server proto 变更→`make gen-dart` regen(client stub);无 DB migration。

## Open Questions

1. 上传成功后的首连数据回填(远端→本地镜像初始化)归 H——G 只回切在线,本地保持导出时点(差异=上传后新写数据,server 权威)。
2. 向导视觉按 AppDesign 既有 page 惯例(执行时定)。
