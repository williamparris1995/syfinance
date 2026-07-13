# 本地备份 server 完整实现 · 设计 spec

- **日期**: 2026-07-13
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: 填充 server backup 骨架 —— CreateBackup 真序列化 + 加密 + 真实 restore + sizeBytes/checksum + proto password。proto + server(Go)+ 小 client 改(dialog 收 password)
- **前置**: client backup UI 已实现(4 task + final review,commit `496122e..9c87b9d53`),实测发现 server backup 是骨架 → 本 spec

## 1. 背景

client backup UI 跑通后实测两个 bug,**根因都在 server backup 是未完成骨架**(systematic-debugging Phase 1 确认):

- `application/service.go:37-40` CreateBackup placeholder:`backup.Checksum = ""; backup.SizeBytes = 0`(注释 "Real data serialization happens when the backup is actually written",但 FinalizeBackup 闲置无人调)
- `application/service.go:71-79` RestoreBackup **TODO stub**:`return nil`,password 收了不用
- proto `CreateBackupRequest{ bool encrypted }` 无 password 字段(server 不支持加密密码)
- `domain/repository.go` BackupRepository 只 CRUD metadata(无数据存取);`cloud/local.go` LocalProvider 只 Upload(无 Download/Delete)

client UI 正确反映 server 真实状态(sizeBytes=0 显示 0 KB;encrypted 只是 flag 无实际加密;创建无密码因 proto 无)。本 spec 让 server backup 真正可用。

## 2. 目标

CreateBackup 序列化 tenant 业务数据 → (可选)加密 → 存文件 + metadata(size/sha256);RestoreBackup 真实恢复(下载→解密→反序列化→写回 DB,全替换);DeleteBackup 删文件+metadata;proto 加 password。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| CreateBackup(序列化 + 加密 + Upload + Finalize + Save) | auto backup scheduler(手动 backup 先) |
| RestoreBackup(Download + 解密 + 反序列化 + 全替换写回) | 云备份 4 RPC(SaveCloudSettings/Test/Upload 独立 spec) |
| DeleteBackup(删文件 + metadata) | 多设备同步(SyncService 独立 spec) |
| LocalProvider Download/Delete + 文件存储 | 增量备份(首批全量) |
| proto `CreateBackupRequest.password` optional + regen | 备份压缩(首批明文/加密 JSON) |
| 各模块 ExportPort/ImportPort(DDD port) | 跨模块原子 restore(技术限制,见 §11) |
| 小 client 改:创建加密备份 dialog 收 password | |

## 4. 决策记录(brainstorm 拍板)

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | 序列化方式 | application 层 JSON(各模块 ExportPort) | DDD 友好,对齐项目 port 惯例(networth/goal/budget);DB-level SQL dump 不 DDD + ent tenant 过滤跨表复杂 |
| 2 | 范围 | 全量 per-tenant 业务 | "真正可用"需完整;MVP 核心不完整丢数据 |
| 3 | 加密 | 可选 AES-256-GCM,scrypt 派生 key | 业界标准;password 用户掌握;非加密明文 JSON(开发/透明) |
| 4 | restore | 全替换(删 tenant 业务 + 写入) | 标准备份语义;保留 tenant/user/auth 账号 |
| 5 | 原子性 | 非跨模块原子(per-module 事务) | ent 各模块独立 client 无共享 Tx;backup/restore 低频危险操作,confirm 警告兜底 |
| 6 | 全局表 | 不备份(currencies/rates/securities/snapshots/price_history) | 系统表 restore 时已在;snapshot/price scheduler 重算 |
| 7 | auto scheduler | defer | 手动 backup 先(auto 后续,需 Cron + settings 表) |

## 5. 架构(DDD 四层 + port)

| 层 | 组件 | 职责 |
|---|---|---|
| **domain**(`backup/domain/`) | 新增 `crypto.go`(Encrypt/Decrypt 纯函数)+ `TenantDataPort` interface | AES-GCM + scrypt 纯函数;port 接口(Name/Export/Import/Purge) |
| **application**(`backup/application/`) | 改 `service.go` CreateBackup/RestoreBackup/DeleteBackup + 新 `ports.go` | 序列化聚合/加密/Upload/Finalize;restore Download/解密/Purge+Import;持 `[]TenantDataPort` |
| **infrastructure**(`backup/adapter/driven/`) | `cloud/local.go` 加 Download/Delete;各模块加 `TenantDataPort` 实现 | 文件读写;各模块 export/import tenant 数据 |
| **proto** | `CreateBackupRequest` 加 `optional string password = 2` | encrypted 备份收密码;regen Go + Dart stub |
| **wire** | 注入各模块 TenantDataPort 到 backup Service | port 模式(backup 不 import 各模块) |
| **client**(小改) | create dialog encrypted 时收 password | proto regen 后,加密选项收密码 |

**port 模式**:backup application 定义 `TenantDataPort` interface,各模块(account/transaction/debt/budget/goal/holding/template/tag/currency-prefs)提供实现,wire 注入 `[]TenantDataPort`。backup 不 import 各模块(DDD 边界,对齐 networth/goal AccountMarketValueSource、budget entryFunc)。

## 6. 数据范围(模块清单 + Export/ImportPort)

**备份的 per-tenant 业务数据**(每个模块一个 TenantDataPort):

| 模块 | 表 | Export 顺序 | Purge 顺序(反序避 FK) |
|---|---|---|---|
| account | accounts(含 categories,parent_id 自引用) | accounts | accounts(子先父后,或 cascade) |
| transaction | transactions + transaction_entries | transactions, entries | entries → transactions |
| debt | debt_details + payment_schedules | debts, schedules | schedules → debts |
| budget | budgets + budget_items | budgets, items | items → budgets |
| goal | goals + goal_account_links + goal_debt_links | goal, links | links → goals |
| holding | holdings + holding_transactions | holdings, holding_txns | holding_txns → holdings(securities 全局,holding 引用 security_id 已存在) |
| template | transaction_templates | templates | templates |
| tag | tags(若 per-tenant;全局则不备份) | tags | tags |

**JSON 聚合格式**:
```json
{
  "version": 1,
  "tenant_id": "<uuid>",
  "created_at": "<RFC3339>",
  "modules": {
    "account": [<accounts json>],
    "transaction": {"transactions": [...], "entries": [...]},
    "debt": {"debts": [...], "schedules": [...]},
    ...
  }
}
```

**不备份**(全局/派生/client):currencies / currency_rates / securities / security_price_history / holding_snapshots / holding_lots / users / tenants / auth sessions / backup records 自身 / **tenant base currency(client-side flutter_secure_storage,非 server 数据,restore 不影响)**。

## 7. 序列化

各模块 TenantDataPort.Export(ctx, tenantID) → `json.RawMessage`(模块自定义结构,含其表数据)。backup application 聚合成 §6 的 envelope JSON → `[]byte`。

序列化用各模块现有 domain entity(已在 repo 层 toDomain 转换)。Export 调 repo.FindAll(tenantID)(全量,不分页;tenant 数据量个人级可控)。

## 8. 加密(AES-256-GCM + scrypt)

**纯函数**(domain/crypto.go):
```go
func Encrypt(plaintext []byte, password string) (ciphertext []byte, err error)
func Decrypt(ciphertext []byte, password string) (plaintext []byte, err error)
```

**文件格式**(加密):
```
[magic:4B "YC1E"]  // 版本/魔数(区分加密 vs 明文)
[salt:32B]
[nonce:12B]
[AES-GCM ciphertext + 16B tag]
```

**参数**:scrypt(N=32768, r=8, p=1, keyLen=32);AES-256-GCM(standard library `crypto/aes` + `crypto/cipher`)。salt/nonce 每次加密随机(`crypto/rand`)。

**非加密**:明文 JSON(无 magic 头,直接 JSON;Decrypt 检测 magic 判断是否加密)。

**密码错**:AES-GCM Open 失败 → ErrWrongPassword(→ InvalidArgument)。

## 9. 存储(LocalProvider)

`cloud/local.go` 加:
- `Download(ctx, filename) ([]byte, error)` —— 读 baseDir/filename
- `Delete(ctx, filename) error` —— 删文件(不存在不报错)

Upload 已有(写文件)。baseDir 配置(默认 `./backups` 或 env `BACKUP_DIR`,wire 注入)。

Backup metadata(DB):id/tenant/provider/filename/sizeBytes/checksum/encrypted/auto/createdAt。文件 = baseDir/filename。

## 10. CreateBackup 流程

```
CreateBackup(ctx, tenantID, encrypted, password):
  1. data = 聚合各 TenantDataPort.Export(tenantID) → envelope JSON []byte
  2. if encrypted:
       if password == "": return ErrPasswordRequired (→ InvalidArgument)
       data = Encrypt(data, password)
     else:
       if password != "": return ErrPasswordOnPlaintext (→ InvalidArgument)  // 防误用
  3. backup = domain.NewBackup(tenantID, LOCAL, encrypted)
  4. LocalProvider.Upload(backup.Filename, data)
  5. FinalizeBackup: checksum = sha256(data); sizeBytes = len(data); backup.Update
  6. repo.Save(backup)
  7. return BackupToDTO(backup)
```

Filename:`backup_<ts>.json`(非加密)/ `backup_<ts>.enc`(加密)。修正 domain.NewBackup(现在硬编码 .enc)按 encrypted 选后缀。

## 11. RestoreBackup 流程(全替换,非跨模块原子)

```
RestoreBackup(ctx, tenantID, backupID, password):
  1. backup = repo.FindByID(backupID)
  2. data = LocalProvider.Download(backup.Filename)
  3. if backup.Encrypted:
       if password == "": return ErrPasswordRequired
       data, err = Decrypt(data, password)  // 错密码 → ErrWrongPassword
     else:
       data = data  // 明文(若带 magic 头则报错,防混淆)
  4. envelope = parse JSON(data)
  5. restore:
       Phase A — Purge(各 TenantDataPort.Purge(tenantID),删 tenant 业务数据,按 §6 反序避 FK)
       Phase B — Import(各 TenantDataPort.Import(tenantID, envelope.modules[name]),按 §6 正序避 FK)
  6. return nil
```

**原子性 trade-off**:各模块 Purge/Import 内部可事务(per-module ent Tx),但**跨模块非原子**(ent 各模块独立 client 无共享 Tx)。若 Phase B 某模块失败,该 tenant 数据已部分删/写 → 报错,用户重试(再 restore)或手动清理。

**缓解**:
- client restore confirm 已警告「⚠️ 覆盖当前数据,不可逆」
- server log 详细(每模块 Purge/Import 成功/失败)
- 失败返回明确错误(哪模块失败)
- follow-up:跨模块原子(raw sql.Tx 共享,各 repo 接 Tx)— defer

**Import 幂等**:Import 前 Purge 已清,Import 纯插入(同 ID)。若中途失败,重试整个 restore(Purge 再清 + Import 再写)。

## 12. DeleteBackup 流程

```
DeleteBackup(ctx, tenantID, backupID):
  1. backup = repo.FindByID(backupID)  // 取 filename
  2. LocalProvider.Delete(backup.Filename)  // 文件不存在不报错
  3. repo.Delete(tenantID, backupID)
```

## 13. proto 改动

`proto/backup/v1/backup.proto`:
```proto
message CreateBackupRequest {
  bool encrypted = 1;
  optional string password = 2;  // 新增,encrypted=true 时必填
}
```

regen:
- Go:`cd yucai/server && buf generate --template buf.gen.go.yaml`(无网 fallback:protoc + protoc-gen-go/-grpc)
- Dart:`cd yucai && make gen-dart`(**protoc_plugin 25.0.0**)

Go `CreateBackupRequest.Password` 变 `*string`(proto3 optional)。handler `req.Password`(解引用 + nil 检查)。

client stub:`CreateBackupRequest{encrypted, password}`,`hasPassword()`。

## 14. 小 client 改(create dialog 收 password)

proto regen 后,client `backup_page.dart` `_showCreateDialog`:
- 当前:encrypted 三选(取消/不加密/加密),加密不收密码
- 改:选「加密」→ 第二步 dialog 收 password(TextField obscureText)+ 确认 → `CreateBackupRequested(encrypted: true, password: ...)`
- `CreateBackupRequested` event 加 `password` 字段;bloc → repo → remote_ds 传 `CreateBackupRequest(password:)`

非加密流程不变(直接创建)。

## 15. defer

- auto backup scheduler(手动先;auto 需 Cron + CloudSettings.auto_backup 字段已存 + scheduler 创建 auto=true 的 Backup)
- 跨模块原子 restore(raw sql.Tx 共享)
- 备份压缩(gzip)
- 增量备份
- 云备份 4 RPC + 多设备同步(独立 spec)
- restore 后 client 自动刷新数据(当前 toast「请重启」;重启重连拉新数据)

## 16. 测试

- **domain crypto**(`crypto_test.go`):Encrypt→Decrypt roundtrip;错密码 → ErrWrongPassword;明文/加密文件格式(magic 头);scrypt 参数。
- **application service**(`service_test.go`):CreateBackup(序列化 + 加密 + Upload + Finalize + Save,mock LocalProvider + fake TenantDataPort);RestoreBackup(Download + 解密 + Purge + Import + 失败路径);DeleteBackup。enttest SQLite + fake LocalProvider(内存 map)。
- **TenantDataPort 各模块**:各模块 export/import roundtrip(enttest,小数据);Purge 清空;FK 顺序。
- **handler**(`backup_handler_test.go`):CreateBackup(encrypted + password / 缺 password InvalidArgument);RestoreBackup(错密码 InvalidArgument);DeleteBackup。
- **e2e**:grpcurl 创建 → list(验 size/checksum 非 0)→ restore → 验证数据回来(DB 查)。
- **client**:create dialog 加密收 password(widget test);proto regen 后 stub 编译。

## 17. 风险

1. **restore 非原子**(跨模块)—— §11 trade-off;confirm 警告 + server log + follow-up 原子。
2. **FK 删除顺序**—— 各模块 Purge 内部按子表→父表;跨模块顺序(transaction/debt/budget/goal/holding 依赖 account,Purge account 前 dependents 已删?account Purge 应最后或 cascade)→ **Plan 须定 Purge 顺序:先依赖模块(transaction/debt/budget/goal/holding/template),最后 account**。
3. **holding 引用 securities**(全局)—— 备份 holdings 含 security_id;restore 时 securities 全局已存在(seed);若 security 不存在 → holding restore 失败 → spec 假设 dev/prod securities 一致(全局 seed)。
4. **ent 跨模块无共享 Tx**—— restore 非原子(§11)。各模块 ent client 独立(共享 DB schema,无 cross edges)。
5. **大 tenant 序列化**—— 全量 JSON 个人数据可控(MB 级);不分页(Export FindAll 全量)。超大 tenant follow-up 流式。
6. **加密文件版本**—— magic 头 "YC1E" 版本 1;未来算法变 v2(Detect + 迁移)。
7. **wire 手改**—— backup Service 加 `[]TenantDataPort` 参数;wire_gen.go 手改(镜像现有 provider 声明顺序,见 memory `yucai-wire-handmaintained`)。
8. **proto regen**—— CreateBackupRequest.password optional;Go `*string` + Dart `hasPassword`;protoc_plugin 25.0.0(Dart)。

## 18. 参考

- client backup UI spec:[2026-07-13-backup-local-design.md](2026-07-13-backup-local-design.md)(已完成)
- server backup 现状:`internal/backup/application/service.go`(CreateBackup placeholder L37-40 / RestoreBackup TODO L71-79 / FinalizeBackup 闲置 L51-68)、`domain/entity.go`(Backup metadata)、`domain/repository.go`(BackupRepository CRUD only)、`adapter/driven/cloud/local.go`(Upload only)、`adapter/driven/repository/backup_repo.go`(ent repo)
- proto:[backup.proto](../../yucai/proto/backup/v1/backup.proto)
- memory:[[holding-asset-management-todo]](backup/sync decompose)/ [[yucai-wire-handmaintained]](wire 手改)/ [[yucai-dev-env]](proto regen 25.0.0)
