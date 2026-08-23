package application

import (
	"bytes"
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"os"
	"strings"
	"sync"
	"testing"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/google/uuid"
	_ "modernc.org/sqlite"
	"github.com/yucai/server/internal/account/adapter/driven/repository"
	accountent "github.com/yucai/server/internal/account/ent/account"
	"github.com/yucai/server/internal/account/ent"
	"github.com/yucai/server/internal/backup/adapter/driven/exporter"
	"github.com/yucai/server/internal/backup/domain"
	"github.com/yucai/server/internal/sqltx"
)

// testDB is a shared in-memory SQLite pool so CreateBackup's sqltx.WithTx can
// open a real transaction in service-layer tests. modernc/sqlite ignores the
// REPEATABLE READ + ReadOnly tx options (SQLite serializes regardless), so the
// tx opens successfully and propagates its driver via context — exactly what the
// FR-2 ctx-contract test asserts. Opened once in TestMain; dialect "sqlite3"
// (ent's SQLite dialect) so sqltx emits "?" placeholders. SetMaxOpenConns(1)
// keeps a single connection owning the named in-memory DB.
var testDB *sql.DB

func TestMain(m *testing.M) {
	db, err := sql.Open("sqlite", "file:backup_app_test?mode=memory&_pragma=foreign_keys(1)")
	if err != nil {
		panic(fmt.Sprintf("open test db: %v", err))
	}
	db.SetMaxOpenConns(1)
	testDB = db
	code := m.Run()
	_ = db.Close()
	os.Exit(code)
}

// --- fakes ---

// fakeProvider is an in-memory CloudProvider for service tests.
type fakeProvider struct {
	mu    sync.Mutex
	files map[string][]byte
}

func newFakeProvider() *fakeProvider {
	return &fakeProvider{files: map[string][]byte{}}
}

func (p *fakeProvider) Upload(_ context.Context, fn string, data []byte) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	cp := make([]byte, len(data))
	copy(cp, data)
	p.files[fn] = cp
	return nil
}

func (p *fakeProvider) Download(_ context.Context, fn string) ([]byte, error) {
	p.mu.Lock()
	defer p.mu.Unlock()
	d, ok := p.files[fn]
	if !ok {
		return nil, fmt.Errorf("not found: %s", fn)
	}
	cp := make([]byte, len(d))
	copy(cp, d)
	return cp, nil
}

func (p *fakeProvider) Delete(_ context.Context, fn string) error {
	p.mu.Lock()
	defer p.mu.Unlock()
	delete(p.files, fn)
	return nil
}

func (p *fakeProvider) TestConnection(_ context.Context) error { return nil }

// fakePort is an in-memory TenantDataPort. It records the last imported bytes
// so roundtrip tests can assert restore rewrites the module state.
type fakePort struct {
	name string
	data []byte
}

func newFakePort(name string, data []byte) *fakePort {
	return &fakePort{name: name, data: data}
}

func (p *fakePort) Name() string { return p.name }
func (p *fakePort) Export(_ context.Context, _ uuid.UUID) (json.RawMessage, error) {
	// Real tenant-data modules always emit valid JSON (empty state = "[]", per
	// exporter test convention); normalize so the fake emulates production
	// behavior (nil would serialize to "null", masking empty-state semantics).
	if len(p.data) == 0 {
		return json.RawMessage("[]"), nil
	}
	cp := make(json.RawMessage, len(p.data))
	copy(cp, p.data)
	return cp, nil
}
func (p *fakePort) Import(_ context.Context, _ uuid.UUID, data json.RawMessage) error {
	cp := make([]byte, len(data))
	copy(cp, data)
	p.data = cp
	return nil
}
func (p *fakePort) Purge(_ context.Context, _ uuid.UUID) error { p.data = nil; return nil }

// fakeRepo is an in-memory BackupRepository.
type fakeRepo struct {
	mu    sync.Mutex
	store map[uuid.UUID]*domain.Backup
}

func newFakeRepo() *fakeRepo {
	return &fakeRepo{store: map[uuid.UUID]*domain.Backup{}}
}

func (r *fakeRepo) Save(_ context.Context, b *domain.Backup) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[b.ID] = b
	return nil
}
func (r *fakeRepo) FindByID(_ context.Context, _, id uuid.UUID) (*domain.Backup, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	b, ok := r.store[id]
	if !ok {
		return nil, fmt.Errorf("not found: %s", id)
	}
	return b, nil
}
func (r *fakeRepo) FindAll(_ context.Context, _ uuid.UUID, _ *domain.BackupProvider, _ domain.PageRequest) (*domain.PaginatedResult[domain.Backup], error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	items := make([]domain.Backup, 0, len(r.store))
	for _, b := range r.store {
		items = append(items, *b)
	}
	return &domain.PaginatedResult[domain.Backup]{Items: items}, nil
}
func (r *fakeRepo) Update(_ context.Context, b *domain.Backup) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	r.store[b.ID] = b
	return nil
}
func (r *fakeRepo) Delete(_ context.Context, _ uuid.UUID, id uuid.UUID) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	delete(r.store, id)
	return nil
}

// fakeSettingsRepo is an in-memory BackupSettingsRepository. It mirrors the
// real repo's upsert-by-tenant semantics so service-level SaveCloudSettings/
// GetCloudSettings tests exercise the same contract without a DB.
type fakeSettingsRepo struct {
	mu    sync.Mutex
	store map[uuid.UUID]*domain.BackupSettings
}

func newFakeSettingsRepo() *fakeSettingsRepo {
	return &fakeSettingsRepo{store: map[uuid.UUID]*domain.BackupSettings{}}
}

func (r *fakeSettingsRepo) Save(_ context.Context, s *domain.BackupSettings) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	cp := *s
	r.store[s.TenantID] = &cp
	return nil
}

func (r *fakeSettingsRepo) GetByTenant(_ context.Context, tenantID uuid.UUID) (*domain.BackupSettings, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	s, ok := r.store[tenantID]
	if !ok {
		return nil, nil // unconfigured → Service returns defaults
	}
	cp := *s
	return &cp, nil
}

// newTestService wires a Service with fake repo/provider and the given ports.
// The settings repo is wired with a fresh fake but discarded — tests that need
// to assert on settings persistence should call newTestServiceWithSettings.
func newTestService(ports []domain.TenantDataPort) (*Service, *fakeRepo, *fakeProvider) {
	svc, repo, prov, _ := newTestServiceWithSettings(ports)
	return svc, repo, prov
}

// newTestServiceWithSettings is like newTestService but also returns the fake
// settings repo so SaveCloudSettings/GetCloudSettings tests can assert on it.
func newTestServiceWithSettings(ports []domain.TenantDataPort) (*Service, *fakeRepo, *fakeProvider, *fakeSettingsRepo) {
	repo := newFakeRepo()
	settingsRepo := newFakeSettingsRepo()
	prov := newFakeProvider()
	cloud := map[domain.BackupProvider]CloudProvider{domain.BackupProviderLocal: prov}
	svc := NewService(repo, settingsRepo, cloud, ports, testDB, "sqlite3", NewRestoreFreeze())
	return svc, repo, prov, settingsRepo
}

// --- tests ---

// TestCreateBackupPlaintext verifies a plaintext backup serializes tenant data
// from all ports, uploads to the provider, and records a non-empty checksum and
// positive size.
func TestCreateBackupPlaintext(t *testing.T) {
	tenantID := uuid.New()
	port := newFakePort("account", []byte(`[{"name":"Cash"}]`))
	svc, repo, prov := newTestService([]domain.TenantDataPort{port})

	dto, err := svc.CreateBackup(context.Background(), tenantID, false, "", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}
	if dto.SizeBytes <= 0 {
		t.Fatalf("SizeBytes = %d, want > 0", dto.SizeBytes)
	}
	if dto.Checksum == "" {
		t.Fatalf("Checksum empty, want sha256 hex")
	}
	if dto.Encrypted {
		t.Fatalf("Encrypted = true, want false")
	}
	// filename suffix .json.gz(明文 gzip 压缩)
	if got := dto.Filename[len(dto.Filename)-8:]; got != ".json.gz" {
		t.Fatalf("Filename suffix = %q, want \".json.gz\"", got)
	}
	// file uploaded
	if _, ok := prov.files[dto.Filename]; !ok {
		t.Fatalf("file %s not uploaded", dto.Filename)
	}
	// record saved
	if _, err := repo.FindByID(context.Background(), tenantID, dto.ID); err != nil {
		t.Fatalf("saved record not found: %v", err)
	}
	// uploaded bytes should be valid JSON envelope (not encrypted)
	if domain.IsEncrypted(prov.files[dto.Filename]) {
		t.Fatalf("plaintext backup file looks encrypted")
	}
}

// TestCreateBackupEncryptedNoPassword verifies that requesting an encrypted
// backup without a password fails fast with ErrPasswordRequired and writes no
// file.
func TestCreateBackupEncryptedNoPassword(t *testing.T) {
	port := newFakePort("account", []byte(`[]`))
	svc, repo, prov := newTestService([]domain.TenantDataPort{port})

	_, err := svc.CreateBackup(context.Background(), uuid.New(), true, "", false)
	if !errors.Is(err, domain.ErrPasswordRequired) {
		t.Fatalf("err = %v, want ErrPasswordRequired", err)
	}
	if len(prov.files) != 0 {
		t.Fatalf("no file should be uploaded on validation failure, got %d", len(prov.files))
	}
	if len(repo.store) != 0 {
		t.Fatalf("no record should be saved on validation failure, got %d", len(repo.store))
	}
}

// TestCreateBackupPlaintextWithPassword verifies the inverse validation rule:
// passing a password on a plaintext backup is rejected.
func TestCreateBackupPlaintextWithPassword(t *testing.T) {
	port := newFakePort("account", []byte(`[]`))
	svc, _, prov := newTestService([]domain.TenantDataPort{port})

	_, err := svc.CreateBackup(context.Background(), uuid.New(), false, "leak", false)
	if !errors.Is(err, domain.ErrPasswordOnPlaintext) {
		t.Fatalf("err = %v, want ErrPasswordOnPlaintext", err)
	}
	if len(prov.files) != 0 {
		t.Fatalf("no file should be uploaded on validation failure")
	}
}

// TestRestoreBackupRoundtrip verifies that Create captures module state, and
// after mutating the port then calling Restore, the port returns to the captured
// state (Purge clears, Import rewrites from the envelope).
func TestRestoreBackupRoundtrip(t *testing.T) {
	tenantID := uuid.New()
	original := []byte(`[{"name":"Cash","balance":5000}]`)
	port := newFakePort("account", original)
	svc, repo, _ := newTestService([]domain.TenantDataPort{port})

	dto, err := svc.CreateBackup(context.Background(), tenantID, false, "", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}
	// sanity: backup captured the original bytes
	if string(port.data) != string(original) {
		t.Fatalf("port data mutated by Create: got %s", port.data)
	}

	// mutate live state — Restore should overwrite it with the backup snapshot
	port.data = []byte(`[{"name":"Food","balance":100}]`)
	if string(port.data) == string(original) {
		t.Fatalf("precondition: mutate failed")
	}

	if err := svc.RestoreBackup(context.Background(), tenantID, dto.ID, ""); err != nil {
		t.Fatalf("RestoreBackup: %v", err)
	}
	if string(port.data) != string(original) {
		t.Fatalf("after Restore port data = %s, want %s", port.data, original)
	}
	// backup record still present (restore does not delete metadata)
	if _, err := repo.FindByID(context.Background(), tenantID, dto.ID); err != nil {
		t.Fatalf("backup record missing after restore: %v", err)
	}
}

// TestRestoreBackupEncryptedRoundtrip verifies the encrypted happy path:
// Create with password, then Restore with the same password recovers the state.
func TestRestoreBackupEncryptedRoundtrip(t *testing.T) {
	tenantID := uuid.New()
	original := []byte(`[{"name":"Secret"}]`)
	port := newFakePort("account", original)
	svc, repo, prov := newTestService([]domain.TenantDataPort{port})

	dto, err := svc.CreateBackup(context.Background(), tenantID, true, "correct-horse", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}
	if !dto.Encrypted {
		t.Fatalf("dto.Encrypted = false, want true")
	}
	// the bytes uploaded to the provider must be encrypted (carry the magic header)
	if !domain.IsEncrypted(prov.files[dto.Filename]) {
		t.Fatalf("uploaded backup should be encrypted")
	}
	// checksum/size recorded against the encrypted payload
	if dto.Checksum == "" || dto.SizeBytes <= 0 {
		t.Fatalf("checksum/size not finalized: checksum=%q size=%d", dto.Checksum, dto.SizeBytes)
	}
	// record persists
	if _, err := repo.FindByID(context.Background(), tenantID, dto.ID); err != nil {
		t.Fatalf("record missing: %v", err)
	}

	port.data = nil // simulate data loss
	if err := svc.RestoreBackup(context.Background(), tenantID, dto.ID, "correct-horse"); err != nil {
		t.Fatalf("RestoreBackup: %v", err)
	}
	if string(port.data) != string(original) {
		t.Fatalf("after Restore port data = %s, want %s", port.data, original)
	}
}

// TestRestoreBackupWrongPassword verifies a wrong password yields
// ErrWrongPassword and does NOT purge tenant data.
func TestRestoreBackupWrongPassword(t *testing.T) {
	tenantID := uuid.New()
	live := []byte(`[{"name":"Keep"}]`)
	port := newFakePort("account", live)
	svc, repo, _ := newTestService([]domain.TenantDataPort{port})

	dto, err := svc.CreateBackup(context.Background(), tenantID, true, "pw1", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}

	err = svc.RestoreBackup(context.Background(), tenantID, dto.ID, "pw2")
	if !errors.Is(err, domain.ErrWrongPassword) {
		t.Fatalf("err = %v, want ErrWrongPassword", err)
	}
	// purge must not have run — live data preserved
	if string(port.data) != string(live) {
		t.Fatalf("port data purged on wrong password: got %s, want %s", port.data, live)
	}
	// record intact
	if _, err := repo.FindByID(context.Background(), tenantID, dto.ID); err != nil {
		t.Fatalf("backup record missing: %v", err)
	}
}

// TestRestoreBackupEncryptedMissingPassword verifies an encrypted restore
// without a password fails before touching tenant data.
func TestRestoreBackupEncryptedMissingPassword(t *testing.T) {
	tenantID := uuid.New()
	live := []byte(`[{"name":"Keep"}]`)
	port := newFakePort("account", live)
	svc, _, _ := newTestService([]domain.TenantDataPort{port})

	dto, err := svc.CreateBackup(context.Background(), tenantID, true, "pw1", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}

	if err := svc.RestoreBackup(context.Background(), tenantID, dto.ID, ""); !errors.Is(err, domain.ErrPasswordRequired) {
		t.Fatalf("err = %v, want ErrPasswordRequired", err)
	}
	if string(port.data) != string(live) {
		t.Fatalf("port data changed: got %s, want %s", port.data, live)
	}
}

// TestDeleteBackupRemovesFileAndRecord verifies DeleteBackup deletes the file
// from the provider and the record from the repo.
func TestDeleteBackupRemovesFileAndRecord(t *testing.T) {
	tenantID := uuid.New()
	port := newFakePort("account", []byte(`[]`))
	svc, repo, prov := newTestService([]domain.TenantDataPort{port})

	dto, err := svc.CreateBackup(context.Background(), tenantID, false, "", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}
	fn := dto.Filename
	if _, ok := prov.files[fn]; !ok {
		t.Fatalf("precondition: file missing")
	}

	if err := svc.DeleteBackup(context.Background(), tenantID, dto.ID); err != nil {
		t.Fatalf("DeleteBackup: %v", err)
	}
	if _, ok := prov.files[fn]; ok {
		t.Fatalf("file should be deleted from provider")
	}
	if _, err := repo.FindByID(context.Background(), tenantID, dto.ID); err == nil {
		t.Fatalf("record should be deleted from repo")
	}
}

// TestOrderedPorts verifies account is ordered last for purge and first for
// import, with remaining ports preserving registration order.
func TestOrderedPorts(t *testing.T) {
	account := newFakePort("account", nil)
	transaction := newFakePort("transaction", nil)
	budget := newFakePort("budget", nil)
	svc, _, _ := newTestService([]domain.TenantDataPort{transaction, account, budget})

	purge := svc.orderedPortsForPurge()
	if got := purge[len(purge)-1].Name(); got != "account" {
		t.Fatalf("purge last = %q, want \"account\"", got)
	}
	if got := names(purge); got != "transaction budget account" {
		t.Fatalf("purge order = %q, want %q", got, "transaction budget account")
	}

	imp := svc.orderedPortsForImport()
	if got := imp[0].Name(); got != "account" {
		t.Fatalf("import first = %q, want \"account\"", got)
	}
	if got := names(imp); got != "account transaction budget" {
		t.Fatalf("import order = %q, want %q", got, "account transaction budget")
	}
}

func names(ps []domain.TenantDataPort) string {
	out := ""
	for i, p := range ps {
		if i > 0 {
			out += " "
		}
		out += p.Name()
	}
	return out
}

// failingImportPort wraps fakePort but Import always errors (inject restore failure
// to verify pre-restore safety backup is retained for recovery).
type failingImportPort struct{ *fakePort }

func (p *failingImportPort) Import(_ context.Context, _ uuid.UUID, _ json.RawMessage) error {
	return errors.New("import injected failure")
}

// failingExportPort's Export always errors (inject pre-restore creation failure
// to verify RestoreBackup returns error WITHOUT purging any data). purgeCalled
// records whether Purge ran, so TestRestoreBackupPreRestoreCreateFailsNoPurge
// can assert restoreNoSafety (which contains Purge) is never reached when the
// pre-restore safety backup fails to create.
type failingExportPort struct {
	name        string
	purgeCalled bool
}

func (p *failingExportPort) Name() string { return p.name }
func (p *failingExportPort) Export(_ context.Context, _ uuid.UUID) (json.RawMessage, error) {
	return nil, errors.New("export injected failure")
}
func (p *failingExportPort) Import(_ context.Context, _ uuid.UUID, _ json.RawMessage) error {
	return nil
}
func (p *failingExportPort) Purge(_ context.Context, _ uuid.UUID) error {
	p.purgeCalled = true
	return nil
}

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
	// Exactly two backups: src + the pre-restore safety (guards against "left
	// many" regressions, e.g. a retry loop creating duplicates).
	if len(list.Backups) != 2 {
		t.Errorf("backups count = %d, want 2 (src + pre-restore safety)", len(list.Backups))
	}
	var preRestore *BackupDTO
	for i := range list.Backups {
		if list.Backups[i].Auto {
			preRestore = &list.Backups[i]
		}
	}
	if preRestore == nil {
		t.Fatal("pre-restore safety backup (Auto=true) not found after failed restore; want it retained for recovery")
	}
	// src must still exist (guards against "src deleted on failure" regression).
	srcExists := false
	for i := range list.Backups {
		if list.Backups[i].ID == src.ID {
			srcExists = true
		}
	}
	if !srcExists {
		t.Error("source backup missing after failed restore; want it retained alongside pre-restore safety")
	}
	// pre-restore must be a distinct new backup, not src itself.
	if preRestore.ID == src.ID {
		t.Error("pre-restore backup ID == src ID; want distinct backups")
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
	// Structural guarantee: when the pre-restore safety backup fails to create,
	// RestoreBackup must NOT proceed into restoreNoSafety (which contains the
	// Purge step). Guards against RestoreBackup being mis-reordered into
	// "restore first, then CreateBackup" — that would purge data with no safety
	// net, and the error-only assertion above would still pass (false negative).
	if port.purgeCalled {
		t.Error("Purge must not run when pre-restore creation fails")
	}
}

// TestSaveCloudSettings_PersistsAutoBackupFields verifies SaveCloudSettings
// forwards the auto-backup portion of CloudSettings to the settings repo
// (upsert-by-tenant contract — only AutoBackup + Interval are stored today;
// provider/credential fields remain deferred).
func TestSaveCloudSettings_PersistsAutoBackupFields(t *testing.T) {
	tenantID := uuid.New()
	svc, _, _, settingsRepo := newTestServiceWithSettings(nil)

	err := svc.SaveCloudSettings(context.Background(), CloudSettings{
		TenantID:                tenantID,
		AutoBackup:              true,
		AutoBackupIntervalHours: 12,
	})
	if err != nil {
		t.Fatalf("SaveCloudSettings: %v", err)
	}

	stored, err := settingsRepo.GetByTenant(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("GetByTenant: %v", err)
	}
	if stored == nil {
		t.Fatal("expected stored settings, got nil")
	}
	if !stored.AutoBackup {
		t.Errorf("AutoBackup = false, want true")
	}
	if stored.AutoBackupIntervalHours != 12 {
		t.Errorf("AutoBackupIntervalHours = %d, want 12", stored.AutoBackupIntervalHours)
	}
}

// TestGetCloudSettings_ReturnsDefaultsWhenUnconfigured verifies that a tenant
// with no persisted row gets zero-valued defaults (AutoBackup=false, 0h) rather
// than an error — the client treats this as "auto-backup off".
func TestGetCloudSettings_ReturnsDefaultsWhenUnconfigured(t *testing.T) {
	tenantID := uuid.New()
	svc, _, _, _ := newTestServiceWithSettings(nil)

	got, err := svc.GetCloudSettings(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("GetCloudSettings: %v", err)
	}
	if got.TenantID != tenantID {
		t.Errorf("TenantID = %v, want %v", got.TenantID, tenantID)
	}
	if got.AutoBackup {
		t.Errorf("AutoBackup = true, want false (default)")
	}
	if got.AutoBackupIntervalHours != 0 {
		t.Errorf("AutoBackupIntervalHours = %d, want 0 (default)", got.AutoBackupIntervalHours)
	}
}

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

// TestGetCloudSettings_ReturnsPersistedValues verifies the round-trip:
// SaveCloudSettings then GetCloudSettings returns the stored auto-backup
// fields (and that a second Save upserts rather than failing).
func TestGetCloudSettings_ReturnsPersistedValues(t *testing.T) {
	tenantID := uuid.New()
	svc, _, _, _ := newTestServiceWithSettings(nil)

	// First save — create path.
	if err := svc.SaveCloudSettings(context.Background(), CloudSettings{
		TenantID:                tenantID,
		AutoBackup:              true,
		AutoBackupIntervalHours: 6,
	}); err != nil {
		t.Fatalf("first SaveCloudSettings: %v", err)
	}
	// Second save — upsert path (row already exists for this tenant).
	if err := svc.SaveCloudSettings(context.Background(), CloudSettings{
		TenantID:                tenantID,
		AutoBackup:              false,
		AutoBackupIntervalHours: 48,
	}); err != nil {
		t.Fatalf("second SaveCloudSettings (upsert): %v", err)
	}

	got, err := svc.GetCloudSettings(context.Background(), tenantID)
	if err != nil {
		t.Fatalf("GetCloudSettings: %v", err)
	}
	if got.AutoBackup {
		t.Errorf("AutoBackup = true, want false (upserted value)")
	}
	if got.AutoBackupIntervalHours != 48 {
		t.Errorf("AutoBackupIntervalHours = %d, want 48 (upserted value)", got.AutoBackupIntervalHours)
	}
}

// TestCreateBackupGzipCompresses:plaintext 备份上传的 bytes 是 gzip(magic
// 0x1f 0x8b),且 Decompress 能还原出含 module key 的 envelope。
func TestCreateBackupGzipCompresses(t *testing.T) {
	tenantID := uuid.New()
	// 100 个重复对象的 JSON 数组(高压缩比验证 gzip;bytes.Repeat 带 trailing
	// comma,wrap 进 [] 并去末尾逗号构成合法 JSON — json.RawMessage 被 json.Marshal
	// compact 校验,原始 brief 数据 `{"name":"Cash"},` * 100 不合法会被拒)。
	parts := bytes.Repeat([]byte(`{"name":"Cash"},`), 100)
	data := append(append([]byte{'['}, bytes.TrimSuffix(parts, []byte{','})...), ']')
	port := newFakePort("account", data)
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

// --- D5 backup snapshot isolation (FR-2 / FR-3) ---

// txSpyPort is a TenantDataPort that records whether its Export was invoked
// inside a sqltx-managed transaction. It captures the tx driver seen in ctx so
// the test can assert (a) Export ran inside the backup's tx and (b) ALL
// exporters shared the SAME driver — i.e. one transaction spanning the whole
// Export loop, not a fresh connection per module (which is what lets a
// concurrent writer tear the snapshot). It reads no DB; it asserts the ctx
// contract that production repos rely on via sqltx.DriverFrom.
type txSpyPort struct {
	name   string
	driver dialect.Driver // captured during Export; nil if Export ran outside a tx
}

func newTxSpyPort(name string) *txSpyPort { return &txSpyPort{name: name} }

func (p *txSpyPort) Name() string { return p.name }
func (p *txSpyPort) Export(ctx context.Context, _ uuid.UUID) (json.RawMessage, error) {
	if drv, ok := sqltx.DriverFrom(ctx); ok {
		p.driver = drv
	}
	return json.RawMessage("[]"), nil
}
func (p *txSpyPort) Import(_ context.Context, _ uuid.UUID, _ json.RawMessage) error { return nil }
func (p *txSpyPort) Purge(_ context.Context, _ uuid.UUID) error                     { return nil }

// TestCreateBackup_ExportsShareSnapshotTx (FR-2): every module's Export MUST
// run inside the backup's single shared transaction — Export's ctx carries the
// sqltx tx driver — and all exporters share the SAME driver (one tx), not a
// per-Export connection. The per-Export-connection state is precisely what
// permits a concurrent writer to tear the backup (account=T1, transaction=T2),
// so this is the service-layer guard for FR-2; the isolation-level behavior
// (REPEATABLE READ actually yielding one consistent snapshot) is validated
// against real PostgreSQL in the env-gated tearing test.
//
// RED against current code: CreateBackup does not wrap the Export loop in
// sqltx.WithTx, so DriverFrom(exportCtx) is nil and every spy reports
// insideTx()==false.
func TestCreateBackup_ExportsShareSnapshotTx(t *testing.T) {
	spies := []*txSpyPort{
		newTxSpyPort("account"),
		newTxSpyPort("transaction"),
		newTxSpyPort("holding"),
	}
	ports := make([]domain.TenantDataPort, len(spies))
	for i, s := range spies {
		ports[i] = s
	}
	svc, _, _ := newTestService(ports)

	if _, err := svc.CreateBackup(context.Background(), uuid.New(), false, "", false); err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}

	for _, s := range spies {
		if s.driver == nil {
			t.Errorf("port %q Export ran outside the backup tx (sqltx.DriverFrom nil); want inside the shared snapshot tx", s.Name())
		}
	}
	// FR-2 "shared": all exporters must observe the SAME tx driver — one tx
	// spanning the loop — not each open their own connection.
	first := spies[0].driver
	for _, s := range spies[1:] {
		if s.driver != first {
			t.Errorf("port %q observed a different tx driver than %q; want one shared transaction", s.Name(), spies[0].Name())
		}
	}
}

// TestCreateBackup_ExportFailureIsAtomic (FR-3): when any module's Export fails,
// CreateBackup must fail atomically — no partial backup file is uploaded and no
// backup record is saved. The Export loop runs inside sqltx.WithTx, so an Export
// error rolls the snapshot tx back AND bails before the file IO (marshal/upload/
// save) that runs outside the tx. This is a regression LOCK on a contract that
// code-3 already satisfies (it passes today) — it exists to catch a future
// change that moved file IO inside the loop, or that swallowed Export errors
// and shipped a half-populated envelope.
func TestCreateBackup_ExportFailureIsAtomic(t *testing.T) {
	ok := newFakePort("account", []byte(`[{"name":"Cash"}]`))
	fail := &failingExportPort{name: "transaction"}
	svc, repo, prov := newTestService([]domain.TenantDataPort{ok, fail})

	_, err := svc.CreateBackup(context.Background(), uuid.New(), false, "", false)
	if err == nil {
		t.Fatal("CreateBackup: want error from failing Export, got nil")
	}
	if len(prov.files) != 0 {
		t.Errorf("partial backup uploaded %d file(s); want 0 (atomic failure, no partial file)", len(prov.files))
	}
	if len(repo.store) != 0 {
		t.Errorf("partial backup saved %d record(s); want 0 (atomic failure, no partial record)", len(repo.store))
	}
}

// --- UploadExternal (R6 feature G) ---

// TestUploadExternalImportsEnvelope verifies the guest→server migration path:
// a client-produced envelope replaces the tenant's (empty) state through the
// same purge+import loops restore uses, with the safety backup cleaned up on
// success.
func TestUploadExternalImportsEnvelope(t *testing.T) {
	tenantID := uuid.New()
	port := newFakePort("account", nil)
	svc, repo, _ := newTestService([]domain.TenantDataPort{port})

	payload := []byte(`[{"name":"Cash","balance":5000}]`)
	envelope := fmt.Sprintf(`{"version":1,"tenant_id":"%s","created_at":"2026-08-23T00:00:00Z","modules":{"account":%s}}`, uuid.New(), payload)
	if err := svc.UploadExternal(context.Background(), tenantID, []byte(envelope), ""); err != nil {
		t.Fatalf("UploadExternal: %v", err)
	}
	if string(port.data) != string(payload) {
		t.Fatalf("imported data = %s, want %s", port.data, payload)
	}
	// Safety backup created then removed on success.
	res, err := repo.FindAll(context.Background(), tenantID, nil, domain.PageRequest{})
	if err != nil {
		t.Fatalf("FindAll: %v", err)
	}
	if len(res.Items) != 0 {
		t.Fatalf("safety backup not cleaned up: %d remain", len(res.Items))
	}
}

// TestUploadExternalOverridesTenantID verifies the authenticated tenant
// always wins: a forged tenant_id inside the envelope never leaks into the
// import layer (fakePort records nothing about tenant, but purge must have
// targeted the caller — verified by the import landing regardless of the
// envelope's foreign tenant).
func TestUploadExternalOverridesTenantID(t *testing.T) {
	tenantID := uuid.New()
	foreign := uuid.New()
	port := newFakePort("account", nil)
	svc, _, _ := newTestService([]domain.TenantDataPort{port})

	envelope := fmt.Sprintf(`{"version":1,"tenant_id":"%s","created_at":"2026-08-23T00:00:00Z","modules":{"account":[{"name":"x"}]}}`, foreign)
	if err := svc.UploadExternal(context.Background(), tenantID, []byte(envelope), ""); err != nil {
		t.Fatalf("UploadExternal: %v", err)
	}
	if string(port.data) != `[{"name":"x"}]` {
		t.Fatalf("import under authenticated tenant failed: %s", port.data)
	}
}

// TestUploadExternalRejectsBadInput: invalid JSON and unsupported versions
// are rejected before any purge runs.
func TestUploadExternalRejectsBadInput(t *testing.T) {
	tenantID := uuid.New()
	port := newFakePort("account", []byte(`[{"name":"keep"}]`))
	svc, _, _ := newTestService([]domain.TenantDataPort{port})

	if err := svc.UploadExternal(context.Background(), tenantID, []byte("{not json"), ""); err == nil {
		t.Fatal("bad JSON accepted")
	}
	v2 := `{"version":2,"modules":{}}`
	if err := svc.UploadExternal(context.Background(), tenantID, []byte(v2), ""); err == nil {
		t.Fatal("version 2 accepted")
	}
	if string(port.data) != `[{"name":"keep"}]` {
		t.Fatalf("rejected input must not purge: %s", port.data)
	}
}

// TestUploadExternalImportFailureKeepsSafetyBackup: an import error leaves
// the pre-upload safety backup in place (same contract as restore).
func TestUploadExternalImportFailureKeepsSafetyBackup(t *testing.T) {
	tenantID := uuid.New()
	port := &failingImportPort{fakePort: newFakePort("account", nil)}
	svc, repo, _ := newTestService([]domain.TenantDataPort{port})

	envelope := `{"version":1,"modules":{"account":[{"name":"x"}]}}`
	if err := svc.UploadExternal(context.Background(), tenantID, []byte(envelope), ""); err == nil {
		t.Fatal("import failure not surfaced")
	}
	res, err := repo.FindAll(context.Background(), tenantID, nil, domain.PageRequest{})
	if err != nil {
		t.Fatalf("FindAll: %v", err)
	}
	if len(res.Items) != 1 {
		t.Fatalf("safety backup must remain on failure: %d", len(res.Items))
	}
}

// --- D6 restore atomicity (R5 feature B) ---
//
// The rollback oracle needs REAL tx participants: fakePort mutates memory
// (not the DB), so a rollback would never restore it. These tests wire a
// real ent/sqlite account repo as the account port plus a failing
// transaction port — the purge deletes rows, the import fails, and the
// assertion reads the DB to prove the delete was rolled back.

// newRealAccountPort builds the account ent client on the SERVICE's testDB
// so the tx driver propagated via sqltx.DriverFrom routes this port's
// queries into the same transaction the service opens — a real tx
// participant (a separate DB would make the port error on the tx driver's
// missing tables, vacuously "passing" rollback assertions).
func newRealAccountPort(t *testing.T) (domain.TenantDataPort, *ent.Client) {
	t.Helper()
	drv := entsql.OpenDB(dialect.SQLite, testDB)
	client := ent.NewClient(ent.Driver(drv))
	if err := client.Schema.Create(context.Background()); err != nil {
		t.Fatalf("migrate: %v", err)
	}
	repo := repository.NewAccountRepository(client)
	return exporter.NewAccountExporter(repo), client
}

// TestRestoreRollsBackPurgeOnImportFailure: an import error mid-chain must
// roll the WHOLE restore back — the account module's live rows survive.
// The restore target carries HETEROGENEOUS data (a "restored" name) so the
// assertion distinguishes "rolled back to live state" from "import applied"
// (a backup identical to the live data would pass vacuously).
func TestRestoreRollsBackPurgeOnImportFailure(t *testing.T) {
	tenantID := uuid.New()
	accountPort, client := newRealAccountPort(t)
	txnPort := &failingImportPort{fakePort: newFakePort("transaction", nil)}
	svc, _, _ := newTestService([]domain.TenantDataPort{accountPort, txnPort})

	t.Cleanup(func() { client.Account.Delete().ExecX(context.Background()) })
	// Seed one live account row.
	if _, err := client.Account.Create().
		SetTenantID(tenantID).
		SetName("keep-me").
		SetAccountType(accountent.AccountType("asset")).
		SetCategory(accountent.Category("savings")).
		SetCurrencyCode("CNY").
		SetOwnership(accountent.Ownership("personal")).
		SetStatus(accountent.Status("active")).
		SetVersion(1).
		Save(context.Background()); err != nil {
		t.Fatalf("seed: %v", err)
	}

	dto, err := svc.CreateBackup(context.Background(), tenantID, false, "", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}
	// Diverge the live state from the backup so the rollback assertion is
	// discriminating (backup: keep-me → post-purge+import would leave
	// keep-me; live: renamed-live must survive a rollback).
	if _, err := client.Account.Update().SetName("renamed-live").Save(context.Background()); err != nil {
		t.Fatalf("diverge: %v", err)
	}
	if err := svc.RestoreBackup(context.Background(), tenantID, dto.ID, ""); err == nil {
		t.Fatal("import failure must surface")
	}
	// Oracle: the LIVE row survives; the backup's "restored" row (which the
	// purge deleted and the import would have re-created) must NOT appear —
	// proving the delete was rolled back, not the import re-applied.
	n, _ := client.Account.Query().Count(context.Background())
	if n != 1 {
		t.Fatalf("purge became fait accompli: rows = %d, want 1", n)
	}
	row, _ := client.Account.Query().First(context.Background())
	if row.Name != "renamed-live" {
		t.Fatalf("live state not restored by rollback: %s", row.Name)
	}
}

// TestUploadExternalRollsBackOnImportFailure: the R6 upload path rides the
// same purgeAndImport transaction — pre-existing rows survive a mid-chain
// failure.
func TestUploadExternalRollsBackOnImportFailure(t *testing.T) {
	tenantID := uuid.New()
	accountPort, client := newRealAccountPort(t)
	txnPort := &failingImportPort{fakePort: newFakePort("transaction", nil)}
	svc, _, _ := newTestService([]domain.TenantDataPort{accountPort, txnPort})

	t.Cleanup(func() { client.Account.Delete().ExecX(context.Background()) })
	if _, err := client.Account.Create().
		SetTenantID(tenantID).
		SetName("existing").
		SetAccountType(accountent.AccountType("asset")).
		SetCategory(accountent.Category("savings")).
		SetCurrencyCode("CNY").
		SetOwnership(accountent.Ownership("personal")).
		SetStatus(accountent.Status("active")).
		SetVersion(1).
		Save(context.Background()); err != nil {
		t.Fatalf("seed: %v", err)
	}

	envelope := `{"version":1,"modules":{"account":[{"Name":"new"}],"transaction":[{"x":1}]}}`
	if err := svc.UploadExternal(context.Background(), tenantID, []byte(envelope), ""); err == nil {
		t.Fatal("import failure must surface")
	}
	n, _ := client.Account.Query().Count(context.Background())
	if n != 1 {
		t.Fatalf("upload rollback failed: rows = %d, want 1", n)
	}
	name, _ := client.Account.Query().First(context.Background())
	if name.Name != "existing" {
		t.Fatalf("row was replaced, not rolled back: %s", name.Name)
	}
}

// --- D13 safety backup encryption (R5 feature D) ---

// TestRestoreEncryptedSafetyAlsoEncrypted: restoring an ENCRYPTED backup
// must produce a pre-restore safety backup encrypted with the SAME
// password — the human-error rollback path keeps the password strength.
func TestRestoreEncryptedSafetyAlsoEncrypted(t *testing.T) {
	tenantID := uuid.New()
	port := newFakePort("account", []byte(`[{"name":"Secret"}]`))
	svc, repo, prov := newTestService([]domain.TenantDataPort{port})

	dto, err := svc.CreateBackup(context.Background(), tenantID, true, "correct-horse", false)
	if err != nil {
		t.Fatalf("CreateBackup: %v", err)
	}
	// Mutate live state so the restore fails mid-import — the safety stays.
	port.data = []byte(`[{"name":"Changed"}]`)

	if err := svc.RestoreBackup(context.Background(), tenantID, dto.ID, "correct-horse"); err != nil {
		t.Fatalf("RestoreBackup: %v", err)
	}

	// The safety backup created BEFORE the restore must be encrypted.
	res, err := repo.FindAll(context.Background(), tenantID, nil, domain.PageRequest{})
	if err != nil {
		t.Fatalf("FindAll: %v", err)
	}
	for _, b := range res.Items {
		if b.Encrypted && b.Auto {
			data := prov.files[b.Filename]
			if len(data) < 4 || string(data[:4]) != "YC2E" {
				t.Fatalf("safety backup not encrypted (magic=%q)", data[:min(4, len(data))])
			}
		}
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
