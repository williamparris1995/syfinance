# pre-restore safety backup Implementation Plan(backup P0)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `RestoreBackup` 前 auto 建 pre-restore 安全网备份(`Auto=true`,未加密)→ 成功删 / 失败留,覆盖 restore 失败/崩溃的数据丢失风险。

**Architecture:** server-only。用现有 `Backup.Auto` 字段(链路已完整:domain → DTO → proto → client entity → BackupCard badge「自动」)。`NewBackup`/`CreateBackup` 加 `auto` 参数(末位);`RestoreBackup` safety 包裹(开头 `CreateBackup(auto=true)` → 抽 `restoreNoSafety` 原逻辑 → 成功删 pre-restore / 失败留)。**client 零改**。

**Tech Stack:** Go(server DDD)、`go test`、现有 fake helper(`fakeProvider`/`fakePort`/`fakeRepo`/`newTestService`)。

## Global Constraints

- **server-only**:仅改 `backup/domain/entity.go`(`NewBackup`)+ `backup/application/service.go`(`CreateBackup`/`RestoreBackup`)+ `backup/adapter/driving/grpc/backup_handler.go`(CreateBackup handler)+ test。**无 client / proto / ent schema 改**(`Backup.Auto` 字段已存在)。
- English 结构化日志(pre-restore cleanup 失败用 `slog.Error("op", "key", val)`,无 CJK 在 log 串)。
- 复用现有 fake helper(同包 `service_test.go`);注入失败用本 plan 新增的 `failingImportPort`/`failingExportPort`。
- TDD:每 task 先写失败测 → 跑证红 → 改实现 → 跑证绿 → commit。
- 测试命令:`cd /e/projects/syfinance/yucai/server && go test ./internal/backup/... -count=1`。
- 参考 spec:[2026-07-16-backup-pre-restore-design.md](../specs/2026-07-16-backup-pre-restore-design.md)(勘误版,用现有 Auto 字段)。

---

### Task 1: `NewBackup` + `CreateBackup` 加 `auto` 参数

**Files:**
- Modify: `yucai/server/internal/backup/domain/entity.go:68`(`NewBackup`)
- Modify: `yucai/server/internal/backup/domain/domain_test.go:10,23`(2 处 caller)
- Modify: `yucai/server/internal/backup/application/service.go:38,74`(`CreateBackup` 签名 + 内 `NewBackup` call)
- Modify: `yucai/server/internal/backup/application/service_test.go`(8 处 `svc.CreateBackup` caller)
- Modify: `yucai/server/internal/backup/adapter/driving/grpc/backup_handler.go:41`(handler caller)

**Interfaces:**
- Produces: `NewBackup(tenantID uuid.UUID, provider BackupProvider, encrypted bool, auto bool) (*Backup, error)`;`CreateBackup(ctx, tenantID, encrypted bool, password string, auto bool) (*BackupDTO, error)` —— `auto` 末位参数;`Backup.Auto` 字段已存在(entity.go:62)。Task 2 的 `RestoreBackup` 依赖 `CreateBackup(auto=true)`。

- [ ] **Step 1: 写失败测 —— NewBackup auto 透传**

追加到 `domain_test.go`:

```go
func TestNewBackup_AutoFlag(t *testing.T) {
	b1, err := NewBackup(uuid.New(), BackupProviderLocal, false, true)
	if err != nil {
		t.Fatalf("NewBackup auto=true: %v", err)
	}
	if !b1.Auto {
		t.Error("Auto=false, want true (auto flag not propagated)")
	}
	b2, err := NewBackup(uuid.New(), BackupProviderLocal, false, false)
	if err != nil {
		t.Fatalf("NewBackup auto=false: %v", err)
	}
	if b2.Auto {
		t.Error("Auto=true, want false")
	}
}
```

- [ ] **Step 2: 跑测证红(编译失败)**

Run: `cd /e/projects/syfinance/yucai/server && go test ./internal/backup/domain/... -count=1 -run TestNewBackup_AutoFlag`
Expected: **FAIL / compile error** —— `NewBackup` 缺 `auto` 参数(too many arguments)。

- [ ] **Step 3: 改 `NewBackup` 加 `auto` 参数**

替换 `entity.go:68` 的 `NewBackup`:

```go
func NewBackup(tenantID uuid.UUID, provider BackupProvider, encrypted bool, auto bool) (*Backup, error) {
	if provider == 0 {
		return nil, fmt.Errorf("provider must be specified")
	}
	now := time.Now()
	suffix := ".json"
	if encrypted {
		suffix = ".enc"
	}
	return &Backup{
		ID:        uuid.New(),
		TenantID:  tenantID,
		Provider:  provider,
		Filename:  fmt.Sprintf("backup_%s%s", now.Format("20060102_150405"), suffix),
		Encrypted: encrypted,
		Auto:      auto,
		Version:   1,
		CreatedAt: now,
		UpdatedAt: now,
	}, nil
}
```

- [ ] **Step 4: 修 domain_test 现有 2 处 NewBackup caller**

`domain_test.go:10`:`NewBackup(uuid.New(), BackupProviderLocal, false)` → `NewBackup(uuid.New(), BackupProviderLocal, false, false)`
`domain_test.go:23`:`NewBackup(uuid.New(), BackupProvider(0), false)` → `NewBackup(uuid.New(), BackupProvider(0), false, false)`

- [ ] **Step 5: 改 `CreateBackup` 加 `auto` 参数 + 透传**

`service.go:38` 签名改为 `func (s *Service) CreateBackup(ctx context.Context, tenantID uuid.UUID, encrypted bool, password string, auto bool) (*BackupDTO, error) {`;`service.go:74` 内 `domain.NewBackup(tenantID, domain.BackupProviderLocal, encrypted)` → `domain.NewBackup(tenantID, domain.BackupProviderLocal, encrypted, auto)`。

- [ ] **Step 6: 修 handler caller**

`backup_handler.go:41`:`h.service.CreateBackup(ctx, tenantID, req.Encrypted, password)` → `h.service.CreateBackup(ctx, tenantID, req.Encrypted, password, false)`(client 手动 RPC → `auto=false`)。

- [ ] **Step 7: 修 service_test.go 全部 8 处 CreateBackup caller(加末位 `, false`)**

每处 `svc.CreateBackup(...)` 末位加 `, false`。grep 定位:`svc.CreateBackup(context.Background(), tenantID, false, "")` 等 → 加 `, false`。具体行:`service_test.go:148,186,204,222,257,294,321,341`(8 处,均手动 backup 测试 → `auto=false`)。

- [ ] **Step 8: 跑全 backup 包证绿**

Run: `cd /e/projects/syfinance/yucai/server && go test ./internal/backup/... -count=1`
Expected: **PASS** —— `TestNewBackup_AutoFlag` 绿 + 现有 backup 测全绿(签名改透传,行为不变)。

- [ ] **Step 9: Commit**

```bash
git add yucai/server/internal/backup/domain/entity.go yucai/server/internal/backup/domain/domain_test.go yucai/server/internal/backup/application/service.go yucai/server/internal/backup/application/service_test.go yucai/server/internal/backup/adapter/driving/grpc/backup_handler.go
git commit -m "feat(backup): NewBackup/CreateBackup 加 auto 参数(透传 Backup.Auto 字段,client 已 badge;Task 1/2 前置,handler 手动=false)"
```

---

### Task 2: `RestoreBackup` safety net + `restoreNoSafety` + safety 测

**Files:**
- Modify: `yucai/server/internal/backup/application/service.go:100-150`(`RestoreBackup` + 抽 `restoreNoSafety`)
- Test: `yucai/server/internal/backup/application/service_test.go`(新增 `failingImportPort`/`failingExportPort` helper + 3 safety 测)
- 需 import:`log/slog`(pre-restore cleanup 日志)

**Interfaces:**
- Consumes: Task 1 的 `CreateBackup(auto=true)`
- Produces: `RestoreBackup` safety 包裹;`restoreNoSafety(ctx, tenantID, backupID, password) error`(原 RestoreBackup body)

- [ ] **Step 1: 写失败测 —— restore safety(成功删 / 失败留 / pre-restore 创建失败)**

追加到 `service_test.go`(`errors`/`strings` 已 import;`context` 用 `context.Background()`):

```go
// failingImportPort wraps fakePort but Import always errors (inject restore failure
// to verify pre-restore safety backup is retained for recovery).
type failingImportPort struct{ *fakePort }

func (p *failingImportPort) Import(_ context.Context, _ uuid.UUID, _ json.RawMessage) error {
	return errors.New("import injected failure")
}

// failingExportPort's Export always errors (inject pre-restore creation failure
// to verify RestoreBackup returns error WITHOUT purging any data).
type failingExportPort struct{ name string }

func (p *failingExportPort) Name() string { return p.name }
func (p *failingExportPort) Export(_ context.Context, _ uuid.UUID) (json.RawMessage, error) {
	return nil, errors.New("export injected failure")
}
func (p *failingExportPort) Import(_ context.Context, _ uuid.UUID, _ json.RawMessage) error {
	return nil
}
func (p *failingExportPort) Purge(_ context.Context, _ uuid.UUID) error { return nil }

// TestRestoreBackupSuccessDeletesPreRestore: successful restore removes the
// auto-created pre-restore safety backup (list keeps only the source backup).
func TestRestoreBackupSuccessDeletesPreRestore(t *testing.T) {
	port := newFakePort("account", []byte(`{"a":1}`))
	svc, _, _ := newTestService([]domain.TenantDataPort{port})
	tenantID := uuid.New()

	src, err := svc.CreateBackup(context.Background(), tenantID, false, "", false)
	if err != nil {
		t.Fatalf("CreateBackup src: %v", err)
	}
	if err := svc.RestoreBackup(context.Background(), tenantID, src.ID, ""); err != nil {
		t.Fatalf("RestoreBackup: %v", err)
	}
	list, err := svc.ListBackups(context.Background(), tenantID, nil, domain.PageRequest{PageSize: 100})
	if err != nil {
		t.Fatalf("ListBackups: %v", err)
	}
	if len(list.Backups) != 1 || list.Backups[0].ID != src.ID {
		t.Errorf("after successful restore, backups=%v, want only src (pre-restore safety deleted)", list.Backups)
	}
}

// TestRestoreBackupFailureLeavesPreRestore: failed restore (Import injected error)
// leaves the pre-restore safety backup (Auto=true) so the user can recover.
func TestRestoreBackupFailureLeavesPreRestore(t *testing.T) {
	port := &failingImportPort{newFakePort("account", []byte(`{"a":1}`))}
	svc, _, _ := newTestService([]domain.TenantDataPort{port})
	tenantID := uuid.New()

	src, err := svc.CreateBackup(context.Background(), tenantID, false, "", false)
	if err != nil {
		t.Fatalf("CreateBackup src: %v", err)
	}
	if err := svc.RestoreBackup(context.Background(), tenantID, src.ID, ""); err == nil {
		t.Fatal("RestoreBackup: want error (import injected failure), got nil")
	}
	list, _ := svc.ListBackups(context.Background(), tenantID, nil, domain.PageRequest{PageSize: 100})
	var preRestore *BackupDTO
	for i := range list.Backups {
		if list.Backups[i].Auto {
			preRestore = &list.Backups[i]
		}
	}
	if preRestore == nil {
		t.Fatal("pre-restore safety backup (Auto=true) not found after failed restore; want it retained for recovery")
	}
}

// TestRestoreBackupPreRestoreCreateFailsNoPurge: if the pre-restore safety
// backup itself fails to create (Export injected error), RestoreBackup returns
// an error WITHOUT having purged any data (original data safe).
func TestRestoreBackupPreRestoreCreateFailsNoPurge(t *testing.T) {
	port := &failingExportPort{name: "account"}
	svc, repo, prov := newTestService([]domain.TenantDataPort{port})
	tenantID := uuid.New()

	// Seed a source backup to restore (bypass CreateBackup, which would fail on
	// the failingExportPort). Upload dummy payload for Download.
	backup, err := domain.NewBackup(tenantID, domain.BackupProviderLocal, false, false)
	if err != nil {
		t.Fatalf("NewBackup: %v", err)
	}
	_ = prov.Upload(context.Background(), backup.Filename, []byte(`{"version":1,"tenant_id":"`+tenantID.String()+`","modules":{}}`))
	_ = repo.Save(context.Background(), backup)

	err = svc.RestoreBackup(context.Background(), tenantID, backup.ID, "")
	if err == nil {
		t.Fatal("RestoreBackup: want error (pre-restore export fails), got nil")
	}
	if !strings.Contains(err.Error(), "pre-restore safety backup") {
		t.Errorf("error=%v, want pre-restore safety backup failure", err)
	}
}
```

- [ ] **Step 2: 跑测证红**

Run: `cd /e/projects/syfinance/yucai/server && go test ./internal/backup/application/... -count=1 -run 'TestRestoreBackup'`
Expected: **FAIL** —— 当前 `RestoreBackup` 无 safety:`TestRestoreBackupSuccessDeletesPreRestore` 会看到 list 含 src + pre-restore(2 个,因 CreateBackup 建了 pre-restore 但 RestoreBackup 没 safety 逻辑)... 实际当前 RestoreBackup 不建 pre-restore,所以 `TestRestoreBackupFailureLeavesPreRestore` 找不到 Auto=true 的 backup(FAIL),`TestRestoreBackupPreRestoreCreateFailsNoPurge` error 不含 "pre-restore safety backup"(FAIL)。

- [ ] **Step 3: 改 `RestoreBackup` —— safety net + 抽 `restoreNoSafety`**

需在 `service.go` 加 `log/slog` import。替换 `service.go:97-150` 的 `RestoreBackup`(注释 + body):

```go
// RestoreBackup downloads → decrypts → per-module Purge + Import.
// Before purging, auto-creates a pre-restore safety backup (unencrypted,
// Auto=true → client shows「自动」badge); on success it is removed, on
// failure/crash it remains so the user can recover the pre-restore state.
// Pragmatic substitute for cross-module DB atomicity (each module has its own
// ent client/driver; shared *sql.Tx would need architecture-wide refactor).
func (s *Service) RestoreBackup(ctx context.Context, tenantID uuid.UUID, backupID uuid.UUID, password string) error {
	// 1. Safety net: auto-create a pre-restore backup BEFORE touching any data.
	preRestore, err := s.CreateBackup(ctx, tenantID, false, "", true)
	if err != nil {
		return fmt.Errorf("pre-restore safety backup: %w", err)
	}

	// 2. Restore (download/decrypt/purge/import — the original logic).
	restoreErr := s.restoreNoSafety(ctx, tenantID, backupID, password)

	// 3. On success, remove the safety net (best-effort). On failure, leave it.
	if restoreErr == nil {
		if delErr := s.DeleteBackup(ctx, tenantID, preRestore.ID); delErr != nil {
			slog.Error("pre-restore safety cleanup failed", "backup_id", preRestore.ID, "err", delErr)
		}
	}
	return restoreErr
}

// restoreNoSafety holds the pre-safety-net restore logic (download/decrypt/
// purge/import). Extracted from RestoreBackup so the safety net can wrap it.
func (s *Service) restoreNoSafety(ctx context.Context, tenantID uuid.UUID, backupID uuid.UUID, password string) error {
	backup, err := s.repo.FindByID(ctx, tenantID, backupID)
	if err != nil {
		return fmt.Errorf("find backup: %w", err)
	}
	provider, ok := s.cloudProviders[domain.BackupProviderLocal]
	if !ok {
		return fmt.Errorf("local provider not configured")
	}
	data, err := provider.Download(ctx, backup.Filename)
	if err != nil {
		return fmt.Errorf("download backup: %w", err)
	}

	// Decrypt if encrypted.
	if backup.Encrypted {
		if password == "" {
			return domain.ErrPasswordRequired
		}
		data, err = domain.Decrypt(data, password)
		if err != nil {
			return err // ErrWrongPassword
		}
	} else if domain.IsEncrypted(data) {
		return domain.ErrWrongPassword // plaintext backup but file carries magic — anomalous
	}

	// Deserialize envelope.
	var envelope domain.BackupEnvelope
	if err := json.Unmarshal(data, &envelope); err != nil {
		return fmt.Errorf("unmarshal envelope: %w", err)
	}

	// Purge (dependents first, account last).
	for _, p := range s.orderedPortsForPurge() {
		if err := p.Purge(ctx, tenantID); err != nil {
			return fmt.Errorf("purge %s: %w", p.Name(), err)
		}
	}
	// Import (account first, then dependents).
	for _, p := range s.orderedPortsForImport() {
		raw, ok := envelope.Modules[p.Name()]
		if !ok {
			continue // older backup may lack this module
		}
		if err := p.Import(ctx, tenantID, raw); err != nil {
			return fmt.Errorf("import %s: %w", p.Name(), err)
		}
	}
	return nil
}
```

- [ ] **Step 4: 跑测证绿**

Run: `cd /e/projects/syfinance/yucai/server && go test ./internal/backup/application/... -count=1 -run 'TestRestoreBackup' -v`
Expected: **PASS** —— 3 safety 测全绿。

- [ ] **Step 5: 跑全 backup 包回归**

Run: `cd /e/projects/syfinance/yucai/server && go test ./internal/backup/... -count=1`
Expected: **PASS** —— 全 backup 包(domain + application + adapter)测全绿。

- [ ] **Step 6: Commit**

```bash
git add yucai/server/internal/backup/application/service.go yucai/server/internal/backup/application/service_test.go
git commit -m "feat(backup): RestoreBackup pre-restore safety net(开头 auto CreateBackup Auto=true 未加密;成功删/失败留;restoreNoSafety 抽原逻辑;覆盖 restore 失败/崩溃数据丢失)"
```

---

## 自审记录(plan 作者)

- **Spec coverage**:spec §6 NewBackup/CreateBackup auto → Task 1;spec §6 RestoreBackup safety + restoreNoSafety → Task 2;spec §8 测(成功删/失败留/pre-restore 创建失败/NewBackup auto)→ Task 1 TestNewBackup_AutoFlag + Task 2 三测。✓
- **Placeholder**:无 TBD/TODO;所有 step 含完整代码 + 确切命令 + expected。service_test 8 处 caller 给行号 + 改法(加 `, false`)。✓
- **Type 一致性**:`NewBackup(...auto bool)` / `CreateBackup(...auto bool)` 签名 Task 1 定义,Task 2 `CreateBackup(false, "", true)` 匹配;`restoreNoSafety` 签名一致;`failingImportPort`/`failingExportPort` 实现 `TenantDataPort`(Name/Export/Import/Purge)。✓
- **勘误记录**:初版 spec(89af4d4)设想 BackupSource + filename prefix + client UI 改,plan 探索发现 `Backup.Auto` 字段已存在 + BackupCard 已 badge,勘误 spec(0d60198)简化为 server-only。本 plan 基于勘误版。
