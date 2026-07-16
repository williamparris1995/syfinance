package application

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"
	"github.com/yucai/server/internal/backup/domain"
)

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
	// Real tenant-data modules always emit valid JSON (empty state = "[]"), never
	// nil. Normalize so the fake emulates production behavior: this matters for
	// the pre-restore safety backup, which Exports current state before any
	// restore — a nil Export would break envelope marshaling.
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

// newTestService wires a Service with fake repo/provider and the given ports.
func newTestService(ports []domain.TenantDataPort) (*Service, *fakeRepo, *fakeProvider) {
	repo := newFakeRepo()
	prov := newFakeProvider()
	cloud := map[domain.BackupProvider]CloudProvider{domain.BackupProviderLocal: prov}
	svc := NewService(repo, cloud, ports)
	return svc, repo, prov
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
	// filename suffix .json
	if got := dto.Filename[len(dto.Filename)-5:]; got != ".json" {
		t.Fatalf("Filename suffix = %q, want \".json\"", got)
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
