# 云备份 WebDAV · 设计 spec

- **日期**: 2026-07-15
- **状态**: spec(brainstorm 产物,待用户审 → writing-plans)
- **分支**: `holding-asset-management`
- **范围**: 云备份 client UI + server 填骨架(WebDAV real impl + backup_settings schema + cloud 4 RPC 填充)。backup/sync decompose 第二子项目(本地备份 done,云备份本 spec;多设备同步后续独立 spec)
- **前置**: 本地备份 client+server 已完成(e2e 三 bug 修复确认)。template 完整已完成。

## 1. 背景

server BackupService 云 4 RPC 全有 proto stub,**但都是骨架**:
- `UploadToCloud`(L225-246):`data := []byte{}` 空 placeholder(不序列化 backup data)
- `SaveCloudSettings`/`GetCloudSettings`(L271-280):TODO stub("persist to backup_settings table when schema added"),GetCloudSettings 返空
- `TestCloudConnection`(L247-268):用 cloudProviders map,WebDAVProvider 是 stub(backup server Task 3 加 stub Download/Delete)

client 无云备份 UI。proto stub 全有(`lib/proto/backup/v1/backup.pbgrpc.dart`)。

## 2. 目标

WebDAV 云备份可用:settings(WebDAV URL/user/password 存 schema)+ test(WebDAV 连接测试)+ upload(序列化 backup → WebDAV PUT)+ client settings 子页。

## 3. 范围边界

| 在范围 | 不在范围(defer) |
|---|---|
| WebDAV real HTTP impl(Go net/http:PUT/GET/DELETE/OPTIONS) | Dropbox/GoogleDrive/OneDrive(OAuth) |
| backup_settings ent schema(new table) | auto backup scheduler(周期自动云备份) |
| SaveCloudSettings/GetCloudSettings(persist) | cloud restore(从 WebDAV download + restore) |
| UploadToCloud(序列化 → WebDAV PUT) | WebDAV 目录浏览/选择 |
| TestCloudConnection(WebDAV OPTIONS) | WebDAV SSL 证书管理(MVP 用默认 TLS) |
| client /settings/cloud 子页(WebDAV form + test + upload) | 多设备同步(独立 spec) |

**零 proto 改动**(cloud 4 RPC + messages 全有)。**新 schema**(backup_settings table)。

## 4. 决策记录

| # | 决策 | 选定 | 理由 |
|---|---|---|---|
| 1 | provider | WebDAV only | self-hosted NAS/Nextcloud 最通用,无 OAuth;现有 stub |
| 2 | 范围 | 核心(settings+test+upload) | auto scheduler + cloud restore defer(YAGNI) |
| 3 | password 存储 | plain(server-side only) | MVP;GetCloudSettings 返空 password(不暴露);follow-up 加密 |
| 4 | WebDAV impl | Go net/http(非 WebDAV 库) | 标准 HTTP PUT/GET/DELETE/OPTIONS 够;无新依赖 |
| 5 | client 入口 | settings 子页 /settings/cloud | 对齐 backup/tag/template settings 模式 |

## 5. 架构

### server(填骨架)

| 层 | 组件 | 职责 |
|---|---|---|
| **ent schema** | `backup/ent/schema/backup_settings.go`(new) | backup_settings table(tenant_id/provider/webdav_url/webdav_username/webdav_password/auto_backup/auto_backup_interval_hours) |
| **domain** | `domain.CloudSettings` struct + BackupSettingsRepository interface | settings entity + repo interface(Save/Get by tenant) |
| **infrastructure** | `backup/adapter/driven/cloud/webdav.go`(rewrite from stub) | WebDAV real HTTP impl(Upload PUT/Download GET/Delete DELETE/TestConnection OPTIONS via net/http + Basic Auth) |
| **infrastructure** | `backup/adapter/driven/repository/backup_settings_repo.go`(new) | ent repo(Save/Get backup_settings) |
| **application** | `backup/application/service.go`(modify) | SaveCloudSettings/GetCloudSettings(persist)+ UploadToCloud(serialize → WebDAV upload)+ TestCloudConnection(real) |
| **wire** | providers.go + wire_gen.go(手改) | backup_settings repo + WebDAV real provider 注入 |

### client(DDD 四层)

| 层 | 组件 | 职责 |
|---|---|---|
| **domain** | `CloudSettings` entity + `CloudSettingsRepository` abstract | entity(url/user/password/autoBackup/interval)+ repo(save/get/testConnection/upload) |
| **data** | `CloudSettingsRemoteDataSource`(4 RPC)+ `CloudSettingsRepositoryImpl` | 4 RPC AuthRetryCaller + _guard + mapper |
| **presentation** | `CloudSettingsBloc`(event load/save/test/upload)+ `CloudSettingsPage` | settings 子页 WebDAV form + test button + upload button |
| **core** | router `/settings/cloud` + settings `_NavRow` + DI | route + settings tile + build_runner |

## 6. WebDAV real HTTP impl

`webdav.go` rewrite from stub。用 Go `net/http` + Basic Auth:

```go
type WebDAVProvider struct {
    baseURL    string
    username   string
    password   string
    client     *http.Client
}

func NewWebDAVProvider(url, user, pass string) *WebDAVProvider { ... }

// Upload: PUT {baseURL}/{filename} with data
func (p *WebDAVProvider) Upload(ctx, filename string, data []byte) error {
    req, _ := http.NewRequestWithContext(ctx, "PUT", p.baseURL+"/"+filename, bytes.NewReader(data))
    req.SetBasicAuth(p.username, p.password)
    resp, err := p.client.Do(req)
    // check resp.StatusCode (200/201/204 = OK)
}

// Download: GET {baseURL}/{filename}
func (p *WebDAVProvider) Download(ctx, filename string) ([]byte, error) { ... }

// Delete: DELETE {baseURL}/{filename}
func (p *WebDAVProvider) Delete(ctx, filename string) error { ... }

// TestConnection: OPTIONS {baseURL} (check 200 + DAV header)
func (p *WebDAVProvider) TestConnection(ctx context.Context) error { ... }
```

**WebDAVProvider 动态构造**(每个 tenant 不同 URL/user/pass):wire 注入 factory(`WebDAVProviderFactory`),application SaveCloudSettings 时从 settings 构造 provider。

## 7. backup_settings ent schema

```go
// backup/ent/schema/backup_settings.go
type BackupSettings struct {
    ent.Schema
}

func (BackupSettings) Fields() []ent.Field {
    return []ent.Field{
        field.UUID("tenant_id", uuid.UUID{}),
        field.Enum("provider").Values("local", "webdav"),
        field.String("webdav_url").Default(""),
        field.String("webdav_username").Default(""),
        field.String("webdav_password").Default(""),  // plain MVP
        field.Bool("auto_backup").Default(false),
        field.Int32("auto_backup_interval_hours").Default(0),
    }
}
```

ent regen(`go generate ./...`)+ migrate。

## 8. cloud 4 RPC 填充

### SaveCloudSettings
```
SaveCloudSettings(ctx, settings):
  1. backup_settings_repo.Save(ctx, settings)  // upsert by tenant_id
  2. return Empty
```

### GetCloudSettings
```
GetCloudSettings(ctx, tenantID):
  1. settings = backup_settings_repo.Get(ctx, tenantID)
  2. settings.WebDAVPassword = ""  // 不暴露 password
  3. return CloudSettingsResponse
```

### TestCloudConnection
```
TestCloudConnection(ctx, tenantID):
  1. settings = backup_settings_repo.Get(ctx, tenantID)
  2. provider = WebDAVProviderFactory(settings.WebDAVURL, user, pass)
  3. err = provider.TestConnection(ctx)  // OPTIONS
  4. return {success: err==nil, message: err.Error() or "连接成功"}
```

### UploadToCloud
```
UploadToCloud(ctx, tenantID, backupID):
  1. backup = backup_repo.FindByID(backupID)
  2. data = localProvider.Download(backup.Filename)  // 本地序列化 backup data
  3. settings = backup_settings_repo.Get(tenantID)
  4. provider = WebDAVProviderFactory(settings.url, user, pass)
  5. provider.Upload(backup.Filename, data)  // WebDAV PUT
  6. return BackupDTO
```

## 9. client UI

### CloudSettingsPage(`/settings/cloud`)
- WebDAV form:URL TextField + username TextField + password TextField(obscure)
- auto_backup Switch + interval(hours)
- 「测试连接」FilledButton(TestCloudConnection → SnackBar 结果)
- 「上传到云端」FilledButton(选择本地备份 → UploadToCloud → SnackBar)
- BlocListener → SnackBar(ActionSuccess/Error)

### CloudSettingsBloc
- event:LoadCloudSettingsRequested / SaveCloudSettingsRequested(settings) / TestConnectionRequested / UploadToCloudRequested(backupId)
- state:Initial / Loading / Loaded(settings) / Submitting / ActionSuccess(message) / Error(message)

### router + settings
- router `/settings/cloud` 子路由(BlocProvider<CloudSettingsBloc>)
- settings_page 加「云备份」_NavRow tile(backup+标签管理+周期模板+云备份 四 tile)

## 10. 测试

### server
- **WebDAV provider test**(httptest mock server:PUT/GET/DELETE/OPTIONS)
- **backup_settings repo test**(enttest SQLite:Save/Get)
- **application test**(SaveCloudSettings/GetCloudSettings/TestCloudConnection/UploadToCloud + mock providers)
- **handler test**(4 cloud RPC)

### client
- **CloudSettingsBloc test**(load/save/test/upload + state 流)
- **CloudSettingsPage widget test**(form 渲染 + test/upload button)
- **回归**:server go test exit 0;client flutter test(1 预存 fail)+ analyze 22 基线

## 11. 风险

1. **WebDAV 兼容性**(不同 NAS/Nextcloud/Synology 实现差异)—— MVP 用标准 HTTP PUT/GET/DELETE/OPTIONS;非标 WebDAV 扩展 defer
2. **password plain 存储**(MVP,server-side only;GetCloudSettings 返空 password;follow-up 加密 AES)
3. **WebDAV TLS 证书**(自签名 NAS cert)—— MVP 用默认 http.Client(skip verify option?follow-up)
4. **UploadToCloud 序列化**(复用 LocalProvider.Download 拿 backup data,非重新序列化)—— 对齐本地备份 data 格式
5. **ent schema 新表**(backup_settings;migrate idempotent)
6. **wire 手改**(WebDAVProviderFactory + backup_settings_repo 注入)
7. **WebDAVProvider 动态构造**(每 tenant 不同 URL/user/pass;factory pattern,wire 注入 factory 非 singleton)

## 12. 参考

- proto:[backup.proto cloud 4 RPC + messages](../../yucai/proto/backup/v1/backup.proto)(SaveCloudSettingsRequest/CloudSettingsResponse/TestConnectionRequest/Response/UploadRequest)
- server 骨架:[backup/application/service.go](../../yucai/server/internal/backup/application/service.go) L224-280(UploadToCloud/SaveCloudSettings/GetCloudSettings/TestCloudConnection)
- 现有 provider:[cloud/webdav.go](../../yucai/server/internal/backup/adapter/driven/cloud/webdav.go)(stub,本 spec rewrite)
- 范式:本地备份 server([2026-07-13-backup-server-design.md](2026-07-13-backup-server-design.md),fill 骨架 + port + scheduler)+ tag client([2026-07-13-tag-ui-design.md](2026-07-13-tag-ui-design.md),DDD 四层 + settings 子页)
- memory:[[holding-asset-management-todo]](云备份 follow-up)
