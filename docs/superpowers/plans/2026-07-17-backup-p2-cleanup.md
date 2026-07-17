# backup P2 收尾 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 backup 补齐 P2 四项收尾 —— RestoreBackup sha256 完整性校验、全量 gzip 压缩(不向后兼容)、多模块+关联 e2e、client create dialog dispose 一致。

**Architecture:** server domain 层新增 `compress.go` 纯函数(gzip,对齐 `crypto.go` Encrypt/Decrypt 范式)+ 两个 sentinel error;application `service.go` 在 create/restore 数据流接入 Compress/Decompress + restoreNoSafety 加 checksum 校验;adapter/driving `backup_handler.go` mapError 加 `errors.Is` case;client `_showCreateDialog` 重构 async + try/finally dispose 对齐 `_showRestoreDialog`。零 proto / 零 ent schema / 零 wire 改动。

**Tech Stack:** Go(stdlib `compress/gzip` + `crypto/sha256`)+ Flutter(flutter_bloc + mocktail widget test)。

## Global Constraints

- **英文结构化日志**:slog,无 CJK 在 log 串(本 plan 无新日志点)。
- **wire 手维护**:本 plan **零 wire 改动**(只动 domain/application/adapter-driving/client,不碰 providers.go / wire_gen.go)。
- **proto 不改**:checksum 字段(field 5)全链路已有,**零 proto regen**。
- **DDD 边界**:Compress/Decompress/ErrBackupFormatOutdated 在 domain(compress.go);ErrChecksumMismatch 在 domain(port.go sentinel 块);service 在 application 接入;mapError 在 adapter/driving。
- **复用第一**:`compress.go` 镜像 `crypto.go`(Encrypt/Decrypt + ErrWrongPassword 同文件范式);`ErrBackupFormatOutdated` 与 Decompress 同文件,`ErrChecksumMismatch` 与 ErrPasswordRequired 同 var 块。
- **TDD**:每 task 先 failing test → 实现 → pass → commit。
- **中文 UI 直写**:M3 dialog 文案保持中文(与现有 `_showRestoreDialog` 一致)。
- **命令工作目录**:项目根 `e:\projects\syfinance`;server 在 `yucai/server/`,client 在 `yucai/client/`。

## File Structure

| 文件 | 责任 | 改动 |
|---|---|---|
| `yucai/server/internal/backup/domain/compress.go`(新)| gzip Compress/Decompress + ErrBackupFormatOutdated | Task 1 |
| `yucai/server/internal/backup/domain/compress_test.go`(新)| 纯函数 roundtrip 测 | Task 1 |
| `yucai/server/internal/backup/domain/port.go` | 加 ErrChecksumMismatch sentinel | Task 2 |
| `yucai/server/internal/backup/application/service.go` | restoreNoSafety checksum 校验(Task 2)+ CreateBackup Compress / restoreNoSafety Decompress(Task 3) | Task 2, 3 |
| `yucai/server/internal/backup/adapter/driving/grpc/backup_handler.go` | mapError 加 errors.Is case | Task 2, 3 |
| `yucai/server/internal/backup/domain/entity.go` | NewBackup suffix `.json`→`.json.gz` | Task 3 |
| `yucai/server/internal/backup/application/service_test.go` | checksum/gzip/多模块 test + 更新 suffix 断言 | Task 2, 3, 4 |
| `yucai/client/lib/backup/presentation/pages/backup_page.dart` | _showCreateDialog async + try/finally dispose | Task 5 |
| `yucai/client/test/backup/backup_page_test.dart`(新)| create flow widget test | Task 5 |

---

## Task 1: domain gzip Compress/Decompress + ErrBackupFormatOutdated

**Files:**
- Create: `yucai/server/internal/backup/domain/compress.go`
- Test: `yucai/server/internal/backup/domain/compress_test.go`

**Interfaces:**
- Consumes: stdlib `compress/gzip`, `bytes`, `io`
- Produces: `domain.Compress(data []byte) ([]byte, error)`, `domain.Decompress(data []byte) ([]byte, error)`, `domain.ErrBackupFormatOutdated error`

- [ ] **Step 1: Write the failing test**

Create `yucai/server/internal/backup/domain/compress_test.go`:

```go
package domain

import (
	"bytes"
	"errors"
	"testing"
)

func TestCompressDecompressRoundtrip(t *testing.T) {
	cases := [][]byte{
		[]byte(`{"version":1,"modules":{"account":[{"name":"Cash"}]}}`),
		[]byte(`[]`),
		[]byte(``),
		bytes.Repeat([]byte("abcdefgh"), 1000),
	}
	for i, in := range cases {
		out, err := Compress(in)
		if err != nil {
			t.Fatalf("case %d Compress: %v", i, err)
		}
		back, err := Decompress(out)
		if err != nil {
			t.Fatalf("case %d Decompress: %v", i, err)
		}
		if !bytes.Equal(back, in) {
			t.Fatalf("case %d roundtrip mismatch: got %q want %q", i, back, in)
		}
	}
}

func TestCompressShrinksRepetitiveInput(t *testing.T) {
	in := bytes.Repeat([]byte("abcdefgh"), 1000) // 8000 bytes
	out, err := Compress(in)
	if err != nil {
		t.Fatalf("Compress: %v", err)
	}
	if len(out) >= len(in) {
		t.Fatalf("compressed %d bytes -> %d, want smaller", len(in), len(out))
	}
}

func TestDecompressLegacyFormatErrors(t *testing.T) {
	// 旧未压缩备份(raw JSON,非 gzip)→ 不向后兼容 → ErrBackupFormatOutdated
	legacy := []byte(`{"version":1,"modules":{}}`)
	_, err := Decompress(legacy)
	if !errors.Is(err, ErrBackupFormatOutdated) {
		t.Fatalf("err = %v, want ErrBackupFormatOutdated", err)
	}
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd yucai/server && go test ./internal/backup/domain/... -count=1 -run TestCompress`
Expected: FAIL / compile error `undefined: Compress`

- [ ] **Step 3: Write minimal implementation**

Create `yucai/server/internal/backup/domain/compress.go`:

```go
package domain

import (
	"bytes"
	"compress/gzip"
	"errors"
	"io"
)

// ErrBackupFormatOutdated 旧格式(未 gzip)备份无法 restore(不向后兼容)。
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

// Decompress gunzip;非 gzip header(旧格式)→ ErrBackupFormatOutdated。
func Decompress(data []byte) ([]byte, error) {
	gr, err := gzip.NewReader(bytes.NewReader(data))
	if err != nil {
		// gzip header 错误 = 旧未压缩备份(不向后兼容,友好提示重建)。
		return nil, ErrBackupFormatOutdated
	}
	defer gr.Close()
	return io.ReadAll(gr)
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd yucai/server && go test ./internal/backup/domain/... -count=1 -run TestCompress`
Expected: PASS(3 tests: roundtrip / shrinks / legacy-format-errors)

- [ ] **Step 5: Run full domain package to confirm zero regression**

Run: `cd yucai/server && go test ./internal/backup/domain/... -count=1`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
cd yucai/server && git add internal/backup/domain/compress.go internal/backup/domain/compress_test.go
git commit -m "feat(backup/domain): gzip Compress/Decompress + ErrBackupFormatOutdated (P2 Task 1)"
```

---

## Task 2: M2 restoreNoSafety checksum 校验

**Files:**
- Modify: `yucai/server/internal/backup/domain/port.go:34-37`(sentinel var 块)
- Modify: `yucai/server/internal/backup/application/service.go:136-139`(restoreNoSafety download 后)
- Modify: `yucai/server/internal/backup/adapter/driving/grpc/backup_handler.go:251-260`(mapError)
- Test: `yucai/server/internal/backup/application/service_test.go`(追加)

**Interfaces:**
- Consumes: `domain.Backup.Checksum`(已有 field)、`crypto/sha256`(service.go 已 import)、`fmt`(已 import)
- Produces: `domain.ErrChecksumMismatch` sentinel;RestoreBackup 损坏/空 checksum → 返它

- [ ] **Step 1: Write the failing tests**

Append to `yucai/server/internal/backup/application/service_test.go`:

```go
// TestRestoreBackupChecksumMismatchRejects:篡改 provider 上的备份文件内容
// → restoreNoSafety 的 checksum 校验失败 → ErrChecksumMismatch;校验在 purge 前
// (live data 保留);pre-restore safety backup 保留(restore 失败 → 不删 safety)。
func TestRestoreBackupChecksumMismatchRejects(t *testing.T) {
	tenantID := uuid.New()
	live := []byte(`[{"name":"Keep"}]`)
	port := newFakePort("account", live)
	svc, repo, prov := newTestService([]domain.TenantDataPort{port})

	dto, err := svc.CreateBackup(context.Background(), tenantID, false, "", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}

	// 篡改 provider 上的文件(翻一字节,checksum 不再匹配)。
	original := prov.files[dto.Filename]
	tampered := make([]byte, len(original))
	copy(tampered, original)
	if len(tampered) > 0 {
		tampered[0] ^= 0xff
	}
	prov.files[dto.Filename] = tampered

	err = svc.RestoreBackup(context.Background(), tenantID, dto.ID, "")
	if !errors.Is(err, domain.ErrChecksumMismatch) {
		t.Fatalf("err = %v, want ErrChecksumMismatch", err)
	}
	// live data 未 purge(checksum 校验在 purge 前)。
	if string(port.data) != string(live) {
		t.Fatalf("port data purged on checksum mismatch: got %s, want %s", port.data, live)
	}
	// pre-restore safety backup 保留(restore 失败 → 不删 safety)。
	list, _ := svc.ListBackups(context.Background(), tenantID, nil, domain.PageRequest{PageSize: 100})
	if len(list.Backups) != 2 { // src + pre-restore safety
		t.Errorf("backups count = %d, want 2 (src + pre-restore safety retained)", len(list.Backups))
	}
	// src record 完好。
	if _, err := repo.FindByID(context.Background(), tenantID, dto.ID); err != nil {
		t.Fatalf("src backup record missing: %v", err)
	}
}

// TestRestoreBackupEmptyChecksumRejects:空 checksum(数据不完整)→ ErrChecksumMismatch。
func TestRestoreBackupEmptyChecksumRejects(t *testing.T) {
	tenantID := uuid.New()
	port := newFakePort("account", []byte(`[{"name":"X"}]`))
	svc, repo, _ := newTestService([]domain.TenantDataPort{port})

	dto, err := svc.CreateBackup(context.Background(), tenantID, false, "", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}
	// 手动清空 checksum(模拟不完整记录)。
	b, _ := repo.FindByID(context.Background(), tenantID, dto.ID)
	b.Checksum = ""
	_ = repo.Save(context.Background(), b)

	err = svc.RestoreBackup(context.Background(), tenantID, dto.ID, "")
	if !errors.Is(err, domain.ErrChecksumMismatch) {
		t.Fatalf("err = %v, want ErrChecksumMismatch (empty checksum)", err)
	}
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd yucai/server && go test ./internal/backup/application/... -count=1 -run 'TestRestoreBackupChecksumMismatch|TestRestoreBackupEmptyChecksum'`
Expected: FAIL / compile error `undefined: domain.ErrChecksumMismatch`

- [ ] **Step 3: Add ErrChecksumMismatch sentinel to port.go**

Modify `yucai/server/internal/backup/domain/port.go:34-37` — the existing var block currently is:

```go
var (
	ErrPasswordRequired    = errors.New("password required for encrypted backup")
	ErrPasswordOnPlaintext = errors.New("password not allowed for plaintext backup")
)
```

Replace with:

```go
var (
	ErrPasswordRequired    = errors.New("password required for encrypted backup")
	ErrPasswordOnPlaintext = errors.New("password not allowed for plaintext backup")
	ErrChecksumMismatch    = errors.New("backup checksum mismatch")
)
```

- [ ] **Step 4: Add checksum check to restoreNoSafety**

Modify `yucai/server/internal/backup/application/service.go` — in `restoreNoSafety`, after the download error check (currently lines 136-139) and before `// Decrypt if encrypted.`:

Current:
```go
	data, err := provider.Download(ctx, backup.Filename)
	if err != nil {
		return fmt.Errorf("download backup: %w", err)
	}

	// Decrypt if encrypted.
```

Replace with:
```go
	data, err := provider.Download(ctx, backup.Filename)
	if err != nil {
		return fmt.Errorf("download backup: %w", err)
	}

	// 校验密文完整性(防传输/存储损坏 + 静默篡改)。checksum 创建时对加密后
	// 数据算,此处对下载的密文算 sha256 比对;空 checksum = 数据不完整。
	got := sha256.Sum256(data)
	if backup.Checksum == "" || fmt.Sprintf("%x", got) != backup.Checksum {
		return domain.ErrChecksumMismatch
	}

	// Decrypt if encrypted.
```

(`crypto/sha256` 与 `fmt` 已在 service.go import。)

- [ ] **Step 5: Add mapError case in backup_handler.go**

Modify `yucai/server/internal/backup/adapter/driving/grpc/backup_handler.go:251-260` — current mapError:

```go
func mapError(err error) error {
	switch {
	case errors.Is(err, domain.ErrPasswordRequired),
		errors.Is(err, domain.ErrPasswordOnPlaintext),
		errors.Is(err, domain.ErrWrongPassword):
		return status.Error(codes.InvalidArgument, err.Error())
	default:
		return status.Errorf(codes.Internal, "backup service error: %v", err)
	}
}
```

Replace with:

```go
func mapError(err error) error {
	switch {
	case errors.Is(err, domain.ErrChecksumMismatch):
		return status.Error(codes.FailedPrecondition, err.Error())
	case errors.Is(err, domain.ErrPasswordRequired),
		errors.Is(err, domain.ErrPasswordOnPlaintext),
		errors.Is(err, domain.ErrWrongPassword):
		return status.Error(codes.InvalidArgument, err.Error())
	default:
		return status.Errorf(codes.Internal, "backup service error: %v", err)
	}
}
```

(`codes.FailedPrecondition` — `google.golang.org/grpc/codes` 已 import。mapError 无单测覆盖,build 验证。)

- [ ] **Step 6: Run the new tests to verify they pass**

Run: `cd yucai/server && go test ./internal/backup/application/... -count=1 -run 'TestRestoreBackupChecksumMismatch|TestRestoreBackupEmptyChecksum'`
Expected: PASS(2 tests)

- [ ] **Step 7: Run full backup suite + build to confirm zero regression**

Run: `cd yucai/server && go test ./internal/backup/... -count=1 && go build ./...`
Expected: PASS(现有 TestRestoreBackupPreRestoreCreateFailsNoPurge 等不受影响 —— 它们在 pre-restore CreateBackup 阶段就 return,不到 checksum 校验)

- [ ] **Step 8: Commit**

```bash
cd yucai/server && git add internal/backup/domain/port.go internal/backup/application/service.go internal/backup/application/service_test.go internal/backup/adapter/driving/grpc/backup_handler.go
git commit -m "feat(backup): M2 restoreNoSafety checksum 校验 + ErrChecksumMismatch->FailedPrecondition (P2 Task 2)"
```

---

## Task 3: gzip 接入 create/restore 数据流

**Depends on:** Task 1(Compress/Decompress/ErrBackupFormatOutdated)、Task 2(restoreNoSafety 已加 checksum 校验)

**Files:**
- Modify: `yucai/server/internal/backup/application/service.go`(CreateBackup Compress + restoreNoSafety Decompress)
- Modify: `yucai/server/internal/backup/domain/entity.go:73-76`(NewBackup suffix)
- Modify: `yucai/server/internal/backup/adapter/driving/grpc/backup_handler.go:251-260`(mapError 加 ErrBackupFormatOutdated)
- Test: `yucai/server/internal/backup/application/service_test.go`(追加 gzip test + 更新现有 suffix 断言)

**Interfaces:**
- Consumes: `domain.Compress`, `domain.Decompress`, `domain.ErrBackupFormatOutdated`(Task 1)
- Produces: create 出的备份文件 gzip 压缩;restore 旧格式 → ErrBackupFormatOutdated;明文 suffix `.json.gz`

- [ ] **Step 1: Update existing TestCreateBackupPlaintext suffix assertion**

Modify `yucai/server/internal/backup/application/service_test.go` — `TestCreateBackupPlaintext` currently asserts (around line 209-212):

```go
	// filename suffix .json
	if got := dto.Filename[len(dto.Filename)-5:]; got != ".json" {
		t.Fatalf("Filename suffix = %q, want \".json\"", got)
	}
```

Replace with:

```go
	// filename suffix .json.gz(明文 gzip 压缩)
	if got := dto.Filename[len(dto.Filename)-8:]; got != ".json.gz" {
		t.Fatalf("Filename suffix = %q, want \".json.gz\"", got)
	}
```

- [ ] **Step 2: Add bytes + crypto/sha256 imports to service_test.go**

Modify `yucai/server/internal/backup/application/service_test.go` import block (currently lines 3-14) — add `bytes` and `crypto/sha256`:

```go
import (
	"bytes"
	"context"
	"crypto/sha256"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/backup/domain"
)
```

- [ ] **Step 3: Write the failing tests**

Append to `service_test.go`:

```go
// TestCreateBackupGzipCompresses:plaintext 备份上传的 bytes 是 gzip(magic
// 0x1f 0x8b),且 Decompress 能还原出含 module key 的 envelope。
func TestCreateBackupGzipCompresses(t *testing.T) {
	tenantID := uuid.New()
	port := newFakePort("account", bytes.Repeat([]byte(`{"name":"Cash"},`), 100))
	svc, _, prov := newTestService([]domain.TenantDataPort{port})

	dto, err := svc.CreateBackup(context.Background(), tenantID, false, "", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}
	uploaded := prov.files[dto.Filename]
	if len(uploaded) < 2 || uploaded[0] != 0x1f || uploaded[1] != 0x8b {
		t.Fatalf("uploaded bytes not gzip: first two = %x, want 1f8b", uploaded[:2])
	}
	raw, err := domain.Decompress(uploaded)
	if err != nil {
		t.Fatalf("Decompress uploaded: %v", err)
	}
	if !bytes.Contains(raw, []byte(`"account"`)) {
		t.Fatalf("decompressed payload missing module key: %s", raw)
	}
}

// TestRestoreBackupLegacyFormatRejects:手动构造旧格式(未 gzip)backup,算
// 正确 checksum 让 checksum 校验通过 → 走到 Decompress → ErrBackupFormatOutdated。
func TestRestoreBackupLegacyFormatRejects(t *testing.T) {
	tenantID := uuid.New()
	port := newFakePort("account", []byte(`[]`))
	svc, repo, prov := newTestService([]domain.TenantDataPort{port})

	backup, err := domain.NewBackup(tenantID, domain.BackupProviderLocal, false, false)
	if err != nil {
		t.Fatalf("NewBackup: %v", err)
	}
	legacy := []byte(`{"version":1,"tenant_id":"` + tenantID.String() + `","modules":{"account":[]}}`)
	sum := sha256.Sum256(legacy)
	backup.Checksum = fmt.Sprintf("%x", sum)
	_ = prov.Upload(context.Background(), backup.Filename, legacy)
	_ = repo.Save(context.Background(), backup)

	err = svc.RestoreBackup(context.Background(), tenantID, backup.ID, "")
	if !errors.Is(err, domain.ErrBackupFormatOutdated) {
		t.Fatalf("err = %v, want ErrBackupFormatOutdated", err)
	}
}
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `cd yucai/server && go test ./internal/backup/application/... -count=1 -run 'TestCreateBackupGzipCompresses|TestRestoreBackupLegacyFormatRejects|TestCreateBackupPlaintext'`
Expected: FAIL(TestCreateBackupGzipCompresses: uploaded 不是 gzip;TestCreateBackupPlaintext: suffix 仍是 .json — Step 1 改了断言但实现还没改)

- [ ] **Step 5: Add Compress to CreateBackup**

Modify `yucai/server/internal/backup/application/service.go` `CreateBackup` — after `json.Marshal(envelope)` and before the encryption block (currently lines 63-68):

Current:
```go
	data, err := json.Marshal(envelope)
	if err != nil {
		return nil, fmt.Errorf("marshal envelope: %w", err)
	}

	// 2. Optional encryption.
	if encrypted {
```

Replace with:
```go
	data, err := json.Marshal(envelope)
	if err != nil {
		return nil, fmt.Errorf("marshal envelope: %w", err)
	}

	// gzip 压缩(encrypt 内层,checksum 仍对最外层密文)。
	if data, err = domain.Compress(data); err != nil {
		return nil, fmt.Errorf("compress backup: %w", err)
	}

	// 2. Optional encryption.
	if encrypted {
```

- [ ] **Step 6: Add Decompress to restoreNoSafety**

Modify `service.go` `restoreNoSafety` — after the decrypt block (after `} else if domain.IsEncrypted(data) { return ... }`) and before `// Deserialize envelope.`:

Current:
```go
	} else if domain.IsEncrypted(data) {
		return domain.ErrWrongPassword // plaintext backup but file carries magic — anomalous
	}

	// Deserialize envelope.
	var envelope domain.BackupEnvelope
```

Replace with:
```go
	} else if domain.IsEncrypted(data) {
		return domain.ErrWrongPassword // plaintext backup but file carries magic — anomalous
	}

	// gunzip(encrypt 内层,decrypt 后;旧格式 → ErrBackupFormatOutdated)。
	if data, err = domain.Decompress(data); err != nil {
		return err
	}

	// Deserialize envelope.
	var envelope domain.BackupEnvelope
```

- [ ] **Step 7: Update NewBackup suffix**

Modify `yucai/server/internal/backup/domain/entity.go:73-76` in `NewBackup`:

Current:
```go
	now := time.Now()
	suffix := ".json"
	if encrypted {
		suffix = ".enc"
	}
```

Replace with:
```go
	now := time.Now()
	suffix := ".json.gz"
	if encrypted {
		suffix = ".enc"
	}
```

- [ ] **Step 8: Add ErrBackupFormatOutdated to mapError**

Modify `yucai/server/internal/backup/adapter/driving/grpc/backup_handler.go` mapError(Task 2 后的版本)—— 把 `ErrBackupFormatOutdated` 并入 `FailedPrecondition` case:

Current (Task 2 后):
```go
	case errors.Is(err, domain.ErrChecksumMismatch):
		return status.Error(codes.FailedPrecondition, err.Error())
```

Replace with:
```go
	case errors.Is(err, domain.ErrChecksumMismatch),
		errors.Is(err, domain.ErrBackupFormatOutdated):
		return status.Error(codes.FailedPrecondition, err.Error())
```

- [ ] **Step 9: Run gzip + suffix tests to verify they pass**

Run: `cd yucai/server && go test ./internal/backup/application/... -count=1 -run 'TestCreateBackupGzipCompresses|TestRestoreBackupLegacyFormatRejects|TestCreateBackupPlaintext'`
Expected: PASS

- [ ] **Step 10: Run full backup suite + build to confirm zero regression**

Run: `cd yucai/server && go test ./internal/backup/... -count=1 && go build ./...`
Expected: PASS(encrypted/plaintext roundtrip 自动适配 gzip:Create 压缩、Restore 解压,数据 byte 等价)

- [ ] **Step 11: Commit**

```bash
cd yucai/server && git add internal/backup/application/service.go internal/backup/application/service_test.go internal/backup/domain/entity.go internal/backup/adapter/driving/grpc/backup_handler.go
git commit -m "feat(backup): gzip 全量压缩 create/restore + .json.gz suffix (不向后兼容, P2 Task 3)"
```

---

## Task 4: 多模块 gzip+checksum roundtrip + 真 DB e2e 手动清单

**Depends on:** Task 1-3(完整 create/restore gzip+checksum 流程)

**Files:**
- Test: `yucai/server/internal/backup/application/service_test.go`(追加多模块回归测)
- 文档:真 DB e2e 手动清单(本 task Step 6,记入 progress ledger,非自动化)

**Interfaces:**
- Consumes: 完整 CreateBackup/RestoreBackup(gzip + encrypt + checksum + pre-restore safety)
- Produces: 多模块回归测 + 真 DB 关联完整性手动验证清单

- [ ] **Step 1: Write the failing test**

Append to `service_test.go`:

```go
// TestRestoreBackupMultiModuleRoundtrip:8 模块(模拟 account..tag)经 gzip +
// encrypt + checksum + pre-restore safety 全流程,验证 restore 后各模块数据各自
// 还原到 backup 快照(关联字段如 linked_account_id/category 在各模块 JSON 内
// 随 restore 还原,顺序由 orderedPortsForImport 保证 account 先 import)。
func TestRestoreBackupMultiModuleRoundtrip(t *testing.T) {
	tenantID := uuid.New()
	modules := map[string][]byte{
		"account":     []byte(`[{"id":"a1","name":"Cash"}]`),
		"transaction": []byte(`[{"id":"t1","desc":"buy","account_id":"a1"}]`),
		"debt":        []byte(`[{"id":"d1","account_id":"a1"}]`),
		"budget":      []byte(`[{"id":"b1","category":"a1"}]`),
		"goal":        []byte(`[{"id":"g1","linked_account_id":"a1"}]`),
		"holding":     []byte(`[{"id":"h1","from_account_id":"a1"}]`),
		"template":    []byte(`[{"id":"tp1","category":"a1"}]`),
		"tag":         []byte(`[{"id":"tg1","name":"vip"}]`),
	}
	var ports []domain.TenantDataPort
	var fakes []*fakePort
	originals := map[string][]byte{}
	for name, data := range modules {
		fp := newFakePort(name, data)
		fakes = append(fakes, fp)
		ports = append(ports, fp)
		originals[name] = data
	}
	svc, _, _ := newTestService(ports)

	// 加密备份(覆盖 gzip + encrypt + checksum 全链路)。
	dto, err := svc.CreateBackup(context.Background(), tenantID, true, "pw", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}

	// mutate 所有模块(模拟数据漂移)。
	for _, fp := range fakes {
		fp.data = []byte(`[{"mutated":true}]`)
	}

	if err := svc.RestoreBackup(context.Background(), tenantID, dto.ID, "pw"); err != nil {
		t.Fatalf("RestoreBackup: %v", err)
	}

	// 各模块还原到 original(关联字段在 JSON 内随还原)。
	for _, fp := range fakes {
		if string(fp.data) != string(originals[fp.name]) {
			t.Errorf("module %q after restore = %s, want %s", fp.name, fp.data, originals[fp.name])
		}
	}
}
```

- [ ] **Step 2: Run test — it should already PASS (regression guard)**

Run: `cd yucai/server && go test ./internal/backup/application/... -count=1 -run TestRestoreBackupMultiModuleRoundtrip`
Expected: PASS(此为 characterization/regression 测,验证 Task 1-3 的多模块集成;若 FAIL 说明 gzip/checksum 改动破坏了多模块 roundtrip)

- [ ] **Step 3: Run full backup suite + build**

Run: `cd yucai/server && go test ./internal/backup/... -count=1 && go build ./...`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
cd yucai/server && git add internal/backup/application/service_test.go
git commit -m "test(backup): 多模块 gzip+checksum roundtrip 回归测 (P2 Task 4)"
```

- [ ] **Step 5: 真 DB e2e 手动清单(关联完整性)—— 记入 progress ledger**

此步骤为**手动验证**(非自动化,对齐 memory `holding-asset-management-todo` 的"真 DB e2e"模式)。把以下清单写入 `.superpowers/sdd/progress.md` 的 backup P2 section,供用户在 dev 环境执行:

```
## 真 DB e2e 手动清单(backup P2 关联完整性)

前置:podman start yucai-pg;server 起(bash background,绝对路径 cd):
  export DATABASE_URL='postgresql://yucai:yucai@localhost:5432/yucai?sslmode=disable'
  export JWT_SECRET='<dev secret>' && export GRPC_PORT=9090 && ./bin/server.exe
client:flutter run -d windows

1. client 建关联数据:
   - account(savings/investment 各一)
   - goal(linked_account = investment account)
   - budget item(category = expense account)
   - debt(关联 debt account + schedule)
   - tag + 给一笔 transaction 打 tag
   - holding + trade(from_account 双写)
2. grpcurl CreateBackup(encrypted + plaintext 各一):
   grpcurl -plaintext -d '{"encrypted":false}' \
     -H "authorization: Bearer <token>" localhost:9090 yucai.backup.v1.BackupService/CreateBackup
   记录 backup_id + checksum
3. client 改/删部分关联数据(模拟损坏/漂移)
4. grpcurl RestoreBackup:{"backup_id":"<id>"}(加密的带 password)
5. DB 查验关联完整恢复:
   psql yucai -c "select linked_account_id from goals; select category from budget_items;
                  select account_id from debts; select * from transaction_tags;"
   预期:goal.linked_account_id 指向正确 account、budget category、debt account、
        txn-tag 关联均恢复
6. (checksum 验证)手动改备份文件一字节 → RestoreBackup → 期望
   FailedPrecondition "backup checksum mismatch"
7. (旧格式验证)若 DB 残留旧未压缩备份 → RestoreBackup → 期望
   FailedPrecondition "backup format outdated, please recreate"
```

- [ ] **Step 6: (可选)push progress ledger 更新**

```bash
# .superpowers/sdd/progress.md 是 gitignored 本地文件,无需 commit
echo "backup P2 Task 4 真 DB e2e 清单已记入"
```

---

## Task 5: M3 client _showCreateDialog dispose 一致

**Files:**
- Modify: `yucai/client/lib/backup/presentation/pages/backup_page.dart:33-96,259`(`_showCreateDialog` async + try/finally + onPressed 调用点)
- Test: `yucai/client/test/backup/backup_page_test.dart`(新)

**Interfaces:**
- Modifies: `_showCreateDialog` signature `void` → `Future<void>`;topbar `onPressed` 改块形式 `() { _showCreateDialog(); }`
- 依赖:`BackupBloc`(`Bloc<BackupEvent, BackupState>`,@injectable)、`CreateBackupRequested(this.encrypted, this.password)`(positional const)、`BackupsLoaded(this.backups)`(positional)

**注意(TDD 形态):** M3 是纯重构(行为不变:加密创建流程仍 dispatch `CreateBackupRequested`)。本 task 的 widget test 是 **characterization test** —— 先对当前 `.then()` 实现跑通(锁定行为),再重构 async+dispose,行为保持 green。controller dispose 正确性靠 `finally` 结构保证(见 spec §6.4 fallback 说明)。

- [ ] **Step 1: Write the characterization widget test**

Create `yucai/client/test/backup/backup_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:yucai_client/backup/presentation/bloc/backup_bloc.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_event.dart';
import 'package:yucai_client/backup/presentation/bloc/backup_state.dart';
import 'package:yucai_client/backup/presentation/pages/backup_page.dart';

class MockBackupBloc extends Mock implements BackupBloc {}

void main() {
  testWidgets('create encrypted backup flow dispatches CreateBackupRequested',
      (tester) async {
    final bloc = MockBackupBloc();
    when(() => bloc.state).thenReturn(BackupsLoaded([]));
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(
      BlocProvider<BackupBloc>.value(
        value: bloc,
        child: const MaterialApp(home: BackupPage()),
      ),
    );
    await tester.pump();

    // 立即备份 → 三选 dialog → 加密
    await tester.tap(find.text('立即备份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('加密'));
    await tester.pumpAndSettle();

    // 输入密码 → 确认
    await tester.enterText(find.byType(TextField), 'secret');
    await tester.tap(find.text('确认'));
    await tester.pumpAndSettle();

    verify(() => bloc.add(const CreateBackupRequested(true, 'secret'))).called(1);
  });
}
```

- [ ] **Step 2: Run test — verify it PASSES against current `.then()` implementation**

Run: `cd yucai/client && flutter test test/backup/backup_page_test.dart`
Expected: PASS(锁定当前行为;若 FAIL 先排查 mock setup,不要动生产代码)

- [ ] **Step 3: Refactor _showCreateDialog to async + try/finally dispose**

Modify `yucai/client/lib/backup/presentation/pages/backup_page.dart` — replace the entire current `_showCreateDialog` method (lines 33-96, the `void _showCreateDialog() { showDialog<bool>(...).then((encrypted) async {...}) }` form) with:

```dart
  /// 创建备份：encrypted 三选 dialog（取消 / 不加密 / 加密）。
  /// 加密时第二步收 password（TextField obscureText，空则 SnackBar 提示）。
  /// CreateBackupRequest{encrypted, password}：非加密传空串。
  /// 加密分支的 TextEditingController 用 try/finally dispose（对齐
  /// _showRestoreDialog,避免 leak;memory 记曾因同步 dispose crash → 若
  /// teardown race 复现改 WidgetsBinding.addPostFrameCallback deferred dispose)。
  Future<void> _showCreateDialog() async {
    final encrypted = await showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('创建备份'),
        content: const Text('是否加密备份文件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, null),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('不加密'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('加密'),
          ),
        ],
      ),
    );
    if (encrypted == null || !mounted) return;

    String password = '';
    if (encrypted) {
      final ctrl = TextEditingController();
      try {
        final ok = await showDialog<bool>(
          context: context,
          builder: (dctx) => AlertDialog(
            title: const Text('加密备份'),
            content: TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: '密码',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dctx, true),
                child: const Text('确认'),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        password = ctrl.text;
      } finally {
        ctrl.dispose();
      }
      if (password.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('密码不能为空')));
        return;
      }
    }
    if (!mounted) return;
    context.read<BackupBloc>().add(CreateBackupRequested(encrypted, password));
  }
```

- [ ] **Step 4: Update topbar onPressed call site (signature changed to Future<void>)**

Modify `backup_page.dart` `_topbar()` — the FilledButton.icon `onPressed`(around line 258-259)currently:

```dart
          FilledButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('立即备份'),
          ),
```

Replace with(块形式保持 `void` 返回,匹配 `VoidCallback?`):

```dart
          FilledButton.icon(
            onPressed: () { _showCreateDialog(); },
            icon: const Icon(LucideIcons.plus, size: 18),
            label: const Text('立即备份'),
          ),
```

- [ ] **Step 5: Run test to verify refactor preserved behavior**

Run: `cd yucai/client && flutter test test/backup/backup_page_test.dart`
Expected: PASS(create encrypted flow 仍 dispatch `CreateBackupRequested(true, 'secret')`)

- [ ] **Step 6: Run flutter analyze + full client test(基线 4 fail 不变)**

Run: `cd yucai/client && flutter analyze`
Expected: 0 新 error(基线 22 全 `*.pbserver.dart` 不变)

Run: `cd yucai/client && flutter test`
Expected: 新 backup_page_test PASS;基线 4 预存 fail(account_detail_page_test + app_shell_test + receivable_detail_page_test)不变,无新回归

- [ ] **Step 7: Commit**

```bash
cd yucai/client && git add lib/backup/presentation/pages/backup_page.dart test/backup/backup_page_test.dart
git commit -m "fix(backup/client): _showCreateDialog async + try/finally dispose 对齐 restore (M3, P2 Task 5)"
```

---

## Self-Review(plan 作者自检,执行前)

**1. Spec coverage:**
- §3 决策 1(checksum 对密文)→ Task 2 Step 4 ✓
- §3 决策 2(失败拒绝 + 空 checksum mismatch)→ Task 2 Step 4 + test TestRestoreBackupEmptyChecksumRejects ✓
- §3 决策 3(gzip 不向后兼容)→ Task 1 Decompress ErrBackupFormatOutdated + Task 3 TestRestoreBackupLegacyFormatRejects ✓
- §3 决策 4(gzip 在 encrypt 内层,checksum 不变)→ Task 3 Step 5/6 顺序 ✓
- §3 决策 6(e2e enttest + grpcurl)→ Task 4 ✓
- §3 决策 7(M3 async + try/finally,post-frame fallback)→ Task 5 ✓
- mapError FailedPrecondition → Task 2 Step 5 + Task 3 Step 8 ✓
- NewBackup suffix → Task 3 Step 7 ✓

**2. Placeholder scan:** 无 TBD/TODO;所有代码步骤含完整代码;test 含完整断言。✓

**3. Type consistency:**
- `Compress`/`Decompress`/`ErrBackupFormatOutdated`(Task 1)→ Task 3/4 引用一致 ✓
- `ErrChecksumMismatch`(Task 2 port.go)→ Task 2 service/handler/test 引用一致 ✓
- `CreateBackupRequested(true, 'secret')`(client event positional const)→ Task 5 test verify 一致 ✓
- `BackupsLoaded([])`(state positional)→ Task 5 test 一致 ✓

**4. 已知执行风险(已在 task 内说明):**
- Task 2 Step 7:TestRestoreBackupPreRestoreCreateFailsNoPurge 不受影响(在 pre-restore CreateBackup 阶段 return)✓
- Task 3 Step 1:更新 TestCreateBackupPlaintext suffix 断言(实现改前 test 会 fail,Step 4 预期 FAIL)✓
- Task 5:async 签名 → onPressed 块形式(Step 4)✓
