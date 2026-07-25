> **ℹ️ 云备份 / 多设备同步已取消 — 2026-07-25**: 本文涉及的云备份与多设备同步内容均已下架(御财 server+Postgres 已集中持久化数据,client 直连服务器,无需云盘备份或多端同步);本地备份 / auto-backup 相关描述仍然有效。

# backup P2 收尾 · 设计 spec(checksum 校验 + gzip 压缩 + 真 DB e2e + dispose 一致性)

- **日期**: 2026-07-17
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: 待定(从 main `bf8cc29`;近期 backup P0/P1 全程在 main commit,延续 main-driven 工作流)
- **范围**: backup P2 四子项收尾 —— M2 RestoreBackup checksum 完整性校验 + gzip 全量压缩 + 真 DB e2e(关联数据 roundtrip)+ M3 client dispose 一致性。**本地聚焦**(云备份 / 多设备同步 cancelled)。

## 1. 背景

backup 模块 P0(pre-restore safety net,`8d651a2`)+ P1(auto backup scheduler,`bf8cc29`)已完成。memory `holding-asset-management-todo` 列 P2 剩余四项:

- **M2 RestoreBackup checksum 校验**:`CreateBackup` 已算 sha256 存入 `Backup.Checksum`(对加密后数据,[service.go:88-89](../../yucai/server/internal/backup/application/service.go#L88-L89)),`BackupDTO` 全链路有 checksum 字段;但 `restoreNoSafety` download 后**完全不校验**([service.go:127-177](../../yucai/server/internal/backup/application/service.go#L127-L177):download→decrypt→unmarshal→purge/import,无对比)→ 文件静默损坏(磁盘错误 / bit rot / 部分写入 / 篡改)会直接 restore 进库,checksum 字段形同虚设。
- **gzip 压缩**:envelope 直接 `json.Marshal` → upload,无压缩;备份含 snapshot 时序历史 + 8 模块(account/transaction/debt/budget/goal/holding/template/tag),体积可优化。
- **真 DB e2e**:基础 e2e 已做(memory:0KB / 加密 / 错密码三 bug 修,DB verify 28 accounts/7 holdings/22 txns),但**关联数据**(goal `linked_account_id` / budget items / debt schedules / tags + txn-tag 关联)roundtrip 未覆盖。
- **M3 controller dispose 一致性**:`_showRestoreDialog` 的 `passwordController` 有 `try/finally dispose`([backup_page.dart:101,152-154](../../yucai/client/lib/backup/presentation/pages/backup_page.dart#L101));`_showCreateDialog` 加密分支的 `ctrl`([:59](../../yucai/client/lib/backup/presentation/pages/backup_page.dart#L59))**不 dispose**(memory 记:曾试同步 dispose crash teardown race → 当时改靠 GC 兜底)。

## 2. 目标

- **M2**:restore 时校验备份完整性,损坏/篡改 → 拒绝(pre-restore safety net 已兜底,拒绝不丢数据)。
- **gzip**:全量 gzip 压缩,减小备份体积(**不向后兼容**,旧未压缩备份失效)。
- **e2e**:验证 backup→restore 跨模块**关联数据**完整性(goal links / budget items / debt schedules / tags)。
- **M3**:create / restore dialog 的 TextEditingController dispose 行为一致。

## 3. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | M2 校验点 | download 后、decrypt 前,对**密文**算 sha256 对比 `backup.Checksum` | checksum 创建时即对加密后数据算;校验密文不依赖密码,覆盖传输/存储损坏;加密备份的 GCM tag 只防密文篡改、不防明文 JSON 合法但内容被改的静默损坏 |
| 2 | M2 失败策略 | 不匹配 → 拒绝 restore,返 `ErrChecksumMismatch`;**空 checksum 也视为 mismatch** | 数据完整性优先;pre-restore safety net 已兜底(拒绝不丢数据);client 复用现有 error snackbar,无新 UI;空 checksum = 数据不完整,严格拒绝 |
| 3 | gzip 向后兼容 | **不向后兼容**,全量 gzip | dev 阶段本地优先应用未发布,DB 现有备份为测试数据可丢弃;最简(restore 端无分支);旧备份 restore 失败时返明确 error(非 gunzip 原始错误,友好提示重建) |
| 4 | gzip 与 checksum 顺序 | gzip 在 encrypt 内层;checksum 仍对最外层密文 | checksum 逻辑零改动,M2 与 gzip 互相独立不冲突;checksum 继续覆盖传输/存储完整性 |
| 5 | gzip 触发 | 无开关,所有 backup 都 gzip | 简化 create/restore 数据流;备份含 snapshot 历史 + 8 模块,体积收益明显(典型 JSON 文本 gzip 比 5-10×) |
| 6 | e2e 形式 | enttest SQLite 自动测 + 真 DB grpcurl 手动清单 | 自动测保证 CI 回归;真 DB 验证关联完整性(memory 既有模式) |
| 7 | M3 方案 | `_showCreateDialog` 重构 async/await + try/finally dispose | 镜像 `_showRestoreDialog` 已验证安全的 dispose 模式;若 memory 记录的 teardown race 复现 → fallback `WidgetsBinding.addPostFrameCallback` deferred dispose |

## 4. 范围边界

| 在范围 | 不在范围(defer / cancelled) |
|---|---|
| M2:`restoreNoSafety` 加 sha256 校验 + `ErrChecksumMismatch` | 云备份 / 多设备同步(cancelled) |
| gzip:`domain/compress.go`(Compress/Decompress)+ service 接入 | filename 冲突(已 P0 修)、pre-restore safety(已 P0)、auto scheduler(已 P1) |
| gzip:不向后兼容(旧备份失效 + 友好 error) | 备份加密算法改动(已 AES-256-GCM + scrypt) |
| 真 DB e2e:goal links / budget items / debt schedules / tags roundtrip | 压缩级别调优 / 并行压缩(默认 `gzip.DefaultCompression` 足够) |
| M3:`_showCreateDialog` dispose 对齐 restore | client 新 UI(M2 错误复用现有 snackbar) |
| `NewBackup` suffix `.json`→`.json.gz` | proto 改动(checksum 字段全链路已有) |

## 5. 架构

| 层 | 组件 | 改动 |
|---|---|---|
| **domain**(新)| `compress.go` | `Compress([]byte) ([]byte, error)` + `Decompress([]byte) ([]byte, error)`(gzip stdlib 纯函数,对齐 `crypto.go` Encrypt/Decrypt 范式)+ `ErrChecksumMismatch` / `ErrBackupFormatOutdated` 错误定义 |
| **domain**(改)| `entity.go` `NewBackup` | 明文 suffix `.json` → `.json.gz`(encrypted 仍 `.enc`,gzip 在密文内层) |
| **application**(改)| `service.go` `CreateBackup` | marshal 后、encrypt 前调 `domain.Compress` |
| **application**(改)| `service.go` `restoreNoSafety` | download 后加 checksum 校验;decrypt 后加 `domain.Decompress` |
| **application**(改)| `service_test.go` | checksum mismatch 拒绝 + gzip roundtrip + 关联数据 e2e |
| **client**(改)| `backup_page.dart` `_showCreateDialog` | `.then()` 链 → async/await,加密分支 `ctrl` try/finally dispose |
| **proto** | 无 | `BackupDTO.checksum` field 5 全链路已有,无 regen |

## 6. 核心改动

### 6.1 M2 — restoreNoSafety checksum 校验

[service.go:127-139](../../yucai/server/internal/backup/application/service.go#L127-L139),download 后、decrypt 前插入:

```go
data, err := provider.Download(ctx, backup.Filename)
if err != nil {
    return fmt.Errorf("download backup: %w", err)
}

// 校验密文完整性(防传输/存储损坏 + 静默篡改)。
got := sha256.Sum256(data)
if backup.Checksum == "" || fmt.Sprintf("%x", got) != backup.Checksum {
    return domain.ErrChecksumMismatch
}

// 之后 decrypt / unmarshal 不变。
```

`ErrChecksumMismatch` 定义在 [port.go](../../yucai/server/internal/backup/domain/port.go) 的 sentinel error var 块(与 `ErrPasswordRequired` / `ErrPasswordOnPlaintext` 同块;`ErrWrongPassword` 在 `crypto.go`)。backup handler 的 `mapError`([backup_handler.go:251](../../yucai/server/internal/backup/adapter/driving/grpc/backup_handler.go#L251))用 `errors.Is` 匹配 sentinel(非字符串匹配)→ 需加 `errors.Is(err, domain.ErrChecksumMismatch)` case 映射为 `codes.FailedPrecondition`(数据损坏,区别于 password 类的 `codes.InvalidArgument`);不加则落 default `codes.Internal`(client 只见「backup service error」通用消息)。

### 6.2 gzip — create/restore 数据流

**domain/compress.go**(新,对齐 `crypto.go`):

```go
package domain

import (
    "bytes"
    "compress/gzip"
    "errors"
    "io"
)

// ErrBackupFormatOutdated 旧格式(未 gzip)备份无法 restore。
var ErrBackupFormatOutdated = errors.New("backup format outdated, please recreate")

// Compress gzip-压缩(所有 backup 统一压缩,不向后兼容)。
func Compress(data []byte) ([]byte, error) {
    var buf bytes.Buffer
    gw := gzip.NewWriter(&buf)
    if _, err := gw.Write(data); err != nil {
        return nil, err
    }
    if err := gw.Close(); err != nil {
        return nil, err
    }
    return buf.Bytes(), nil
}

// Decompress gunzip;旧格式(非 gzip)→ ErrBackupFormatOutdated。
func Decompress(data []byte) ([]byte, error) {
    gr, err := gzip.NewReader(bytes.NewReader(data))
    if err != nil {
        // gzip header 错误 = 旧未压缩备份(不向后兼容)。
        return nil, ErrBackupFormatOutdated
    }
    defer gr.Close()
    return io.ReadAll(gr)
}
```

**service.go `CreateBackup`**([:63-74](../../yucai/server/internal/backup/application/service.go#L63-L74)),marshal 后、encrypt 前加 Compress:

```go
data, err := json.Marshal(envelope)
if err != nil {
    return nil, fmt.Errorf("marshal envelope: %w", err)
}

// gzip 压缩(encrypt 内层,checksum 仍对最外层密文)。
if data, err = domain.Compress(data); err != nil {
    return nil, fmt.Errorf("compress backup: %w", err)
}

// 2. Optional encryption(不变)。
if encrypted {
    data, err = domain.Encrypt(data, password)
    ...
}
```

**service.go `restoreNoSafety`**,checksum 校验后、decrypt 后、unmarshal 前加 Decompress:

```go
// checksum 校验(§6.1)...
// decrypt(不变)...

// gunzip(encrypt 内层,decrypt 后)。
data, err = domain.Decompress(data)
if err != nil {
    return err // ErrBackupFormatOutdated(旧格式)
}

// unmarshal(不变)。
var envelope domain.BackupEnvelope
if err := json.Unmarshal(data, &envelope); err != nil {
    ...
}
```

**entity.go `NewBackup`**([:73-76](../../yucai/server/internal/backup/domain/entity.go#L73-L76))suffix:

```go
suffix := ".json.gz"
if encrypted {
    suffix = ".enc"
}
```

### 6.3 真 DB e2e — 关联数据 roundtrip

`application/service_test.go` 新增 `TestRestoreBackupWithRelations`(或扩展现有 roundtrip):

- **fixture**(8 模块建关联数据):
  - goal with `linked_account_id`(指向一个 investment account)
  - budget items(category = expense account,account-as-category)
  - debt schedule(关联 debt account)
  - tag + transaction-tag 关联(tagging 模块)
  - holding + trade(关联 from_account 双写)
- **验证**:backup → restore → 逐模块 assert 数据完整 + **关联字段**仍指向正确实体(goal.linked_account_id 对应 account、budget category 对应 expense account、txn-tag 关联等)。
- **顺序保证**:依赖 `orderedPortsForImport`(account first)—— 验证 goal/budget/tag import 时 account 已就位。

真 DB grpcurl 手动清单(写入 spec 实现 task,e2e 步骤照 memory 既有模式):
1. dev DB 建关联数据(goal/budget/debt/tag)
2. `CreateBackup`(encrypted + plaintext 各一)
3. `RestoreBackup`
4. DB 查验关联字段未丢

### 6.4 M3 — create dialog dispose 一致

[backup_page.dart:33-96](../../yucai/client/lib/backup/presentation/pages/backup_page.dart#L33-L96) `_showCreateDialog` 从 `.then()` 链重构为 async/await,加密分支 `ctrl` 用 try/finally dispose(镜像 `_showRestoreDialog`):

```dart
Future<void> _showCreateDialog() async {
  final encrypted = await showDialog<bool>(
    context: context,
    builder: (dctx) => AlertDialog(/* 三选:取消/不加密/加密 */),
  );
  if (encrypted == null || !mounted) return;

  String password = '';
  if (encrypted) {
    final ctrl = TextEditingController();
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dctx) => AlertDialog(/* 密码 TextField(ctrl) */),
      );
      if (ok != true || !mounted) return;
      password = ctrl.text;
    } finally {
      ctrl.dispose();
    }
    if (password.isEmpty) { /* SnackBar */ return; }
  }
  if (!mounted) return;
  context.read<BackupBloc>().add(CreateBackupRequested(encrypted, password));
}
```

**fallback**(若 memory 记的 teardown race 复现):finally 内改 `WidgetsBinding.instance.addPostFrameCallback((_) => ctrl.dispose())` 延迟到帧后,避开 dialog teardown 同步路径。

## 7. 数据流

**create**(新):
```
export(8 模块) → marshal envelope → Compress(gzip) → [Encrypt](若加密)
              → checksum(sha256 of 密文) → upload → Save(record)
```

**restore**(新):
```
download → checksum 校验(密文 vs backup.Checksum,不匹配→ErrChecksumMismatch)
        → [Decrypt](若加密) → Decompress(gunzip,旧格式→ErrBackupFormatOutdated)
        → unmarshal → purge(dependents first, account last) → import(account first)
```

checksum 校验最外层密文 → gzip 在其内层 → 二者独立,M2 与 gzip 改动互不影响。

## 8. 测试

- **domain**:
  - `Compress`/`Decompress` roundtrip(压缩→解压 byte-identical)
  - `Decompress` 非 gzip 输入 → `ErrBackupFormatOutdated`
  - `Compress` 不同输入产生不同输出;空输入合法
- **application**(`service_test.go`,enttest SQLite):
  - checksum 不匹配(篡改下载字节)→ restore 拒绝 `ErrChecksumMismatch` + pre-restore safety backup 保留
  - 空 checksum → 拒绝(mismatch)
  - gzip roundtrip:CreateBackup → RestoreBackup 数据 byte 等价(含 encrypted + plaintext 两组合)
  - 关联数据 e2e(§6.3):goal/budget/debt/tag 关联字段 restore 后完整
- **client**(widget test):
  - `_showCreateDialog` 加密流程正确触发 `CreateBackupRequested`
  - controller 正确 dispose(无 leak;pumpAndSettle 验证)

## 9. 风险

1. **不向后兼容后果**:DB 现有未压缩备份 restore 会失败(`ErrBackupFormatOutdated`)。spec 注明;用户确认 DB 现有备份可丢弃(dev 测试数据)。建议实现 task 附带提示用户重建备份。
2. **M3 teardown race**:首选 try/finally(镜像已验证的 restore dialog);若 memory 记录的 crash 复现 → post-frame deferred dispose。
3. **gzip + 加密叠加组合**:明文 `.json.gz`、加密 `.enc`(gzip 在密文内层,外层扩展名不变)。单测覆盖「明文+压缩」「加密+压缩」两组合的 roundtrip。
4. **e2e 关联完整性依赖 import 顺序**:goal.linked_account / budget category(account-as-category)/ tag-txn 关联要求 account 先 import —— 现有 `orderedPortsForImport`(account first)已保证,测试验证(若关联丢 → 暴露 ordering bug)。
5. **checksum 校验增加 restore 耗时**:sha256 对备份文件(典型 KB-MB 级)开销可忽略;不引入流式处理复杂度。
6. **mapError 加 case**:backup handler `mapError`([:251](../../yucai/server/internal/backup/adapter/driving/grpc/backup_handler.go#L251))用 `errors.Is` 匹配 sentinel error(现仅 password 三类 → `codes.InvalidArgument`,其余 → `codes.Internal`)。新增 `ErrChecksumMismatch` / `ErrBackupFormatOutdated` 必须加对应 `errors.Is` case(建议 `codes.FailedPrecondition`:数据/格式状态问题),否则落 default `codes.Internal` → client 只见「backup service error」通用消息,无法区分损坏 vs 旧格式。client 现有 error snackbar 显示 `err.Error()` 文本,无新 UI。

## 10. 参考

- backup server spec:[2026-07-13-backup-server-design.md](2026-07-13-backup-server-design.md)(checksum/size inline + crypto + TenantDataPort)
- pre-restore safety spec:[2026-07-16-backup-pre-restore-design.md](2026-07-16-backup-pre-restore-design.md)(RestoreBackup safety net)
- auto backup scheduler spec:[2026-07-16-backup-auto-scheduler-design.md](2026-07-16-backup-auto-scheduler-design.md)(P1,CloudSettings 持久化)
- memory:`holding-asset-management-todo`(P2 defer 清单)、`yucai-wire-handmaintained`(wire/ent 手维护,本 spec 零 schema/wire 改动)
- domain crypto 范式:[crypto.go](../../yucai/server/internal/backup/domain/crypto.go)(Compress/Decompress 对齐 Encrypt/Decrypt)
