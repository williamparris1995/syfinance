> **ℹ️ 云备份 / 多设备同步已取消 — 2026-07-25**: 本文涉及的云备份与多设备同步内容均已下架(御财 server+Postgres 已集中持久化数据,client 直连服务器,无需云盘备份或多端同步);本地备份 / auto-backup 相关描述仍然有效。

# 备份与恢复模块实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现端到端加密备份系统，支持本地自动备份、多云盘上传（WebDAV/Dropbox/Google Drive/OneDrive）、恢复差异对比

**Architecture:** BackupService 核心负责序列化→压缩→加密→存储→上传；CloudProvider trait 统一云存储接口；前端独立 BackupPage 提供状态概览、云盘配置、备份历史管理

**Tech Stack:** Rust (flate2, reqwest, aes-gcm, base64), React, TypeScript, TanStack React Query, shadcn/ui

---

## 文件结构

```
src-tauri/src/
├── infrastructure/backup/
│   ├── mod.rs                          # 模块导出
│   ├── backup_service.rs               # 核心备份逻辑（序列化、压缩、加密、文件I/O）
│   ├── cloud_provider.rs              # CloudProvider trait + CloudError + CloudBackupInfo
│   ├── webdav_provider.rs             # WebDAV 实现（覆盖 NextCloud/Synology/坚果云/Box/自定义）
│   ├── dropbox_provider.rs            # Dropbox API v2 stub
│   ├── google_drive_provider.rs       # Google Drive API v3 stub
│   └── onedrive_provider.rs           # OneDrive Graph API stub
├── presentation/tauri_commands/
│   └── backup_commands.rs             # Tauri 命令（create_backup, restore, list, configure_cloud 等）
├── migrations/
│   └── 20260529000001_create_cloud_settings.sql

src/
├── pages/BackupPage.tsx               # 独立备份页面
├── components/CloudConfigDialog.tsx    # 云盘配置对话框（含提供商选择器）
├── components/RestoreDialog.tsx       # 恢复差异对比对话框
├── lib/tauri/backup.ts                # 前端 Tauri API 客户端
└── hooks/useBackup.ts                 # 备份状态管理 Hook
```

---

### Task 1: 添加 Cargo 依赖和数据库迁移

**Files:**
- Modify: `src-tauri/Cargo.toml`
- Create: `src-tauri/migrations/20260529000001_create_cloud_settings.sql`

- [ ] **Step 1: 添加 Rust 依赖**

在 `src-tauri/Cargo.toml` 的 `[dependencies]` 末尾添加：

```toml
# 备份相关
flate2 = "1"
base64 = "0.22"
```

- [ ] **Step 2: 创建 cloud_settings 迁移**

创建 `src-tauri/migrations/20260529000001_create_cloud_settings.sql`：

```sql
CREATE TABLE IF NOT EXISTS cloud_settings (
    provider TEXT NOT NULL,
    server_url TEXT,
    port INTEGER,
    username TEXT,
    password TEXT,
    remote_path TEXT,
    access_token TEXT,
    refresh_token TEXT,
    auto_upload TEXT NOT NULL DEFAULT 'on_backup',
    enabled BOOLEAN NOT NULL DEFAULT true,
    last_upload_at TEXT,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

- [ ] **Step 3: 验证编译**

Run: `cd src-tauri && cargo check`
Expected: 编译成功

- [ ] **Step 4: 提交**

```bash
git add src-tauri/Cargo.toml src-tauri/migrations/20260529000001_create_cloud_settings.sql
git commit -m "feat(backup): add flate2/base64 deps and cloud_settings migration"
```

---

### Task 2: CloudProvider trait 和错误类型

**Files:**
- Create: `src-tauri/src/infrastructure/backup/mod.rs`
- Create: `src-tauri/src/infrastructure/backup/cloud_provider.rs`
- Modify: `src-tauri/src/infrastructure/mod.rs`

- [ ] **Step 1: 创建模块文件**

创建 `src-tauri/src/infrastructure/backup/mod.rs`：

```rust
pub mod backup_service;
pub mod cloud_provider;
pub mod webdav_provider;
pub mod dropbox_provider;
pub mod google_drive_provider;
pub mod onedrive_provider;

pub use backup_service::BackupService;
pub use cloud_provider::{CloudProvider, CloudError, CloudBackupInfo};
```

- [ ] **Step 2: 定义 CloudProvider trait**

创建 `src-tauri/src/infrastructure/backup/cloud_provider.rs`：

```rust
use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, thiserror::Error)]
pub enum CloudError {
    #[error("connection failed: {0}")]
    ConnectionFailed(String),
    #[error("authentication failed: {0}")]
    AuthFailed(String),
    #[error("upload failed: {0}")]
    UploadFailed(String),
    #[error("download failed: {0}")]
    DownloadFailed(String),
    #[error("not configured")]
    NotConfigured,
    #[error("network error: {0}")]
    NetworkError(String),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudBackupInfo {
    pub name: String,
    pub size: u64,
    pub last_modified: Option<String>,
}

pub trait CloudProvider: Send + Sync {
    fn name(&self) -> &str;
    fn test_connection(&self) -> Result<(), CloudError>;
    fn upload(&self, local_path: &Path, remote_name: &str) -> Result<(), CloudError>;
    fn download(&self, remote_name: &str, local_path: &Path) -> Result<(), CloudError>;
    fn list_backups(&self) -> Result<Vec<CloudBackupInfo>, CloudError>;
    fn delete(&self, remote_name: &str) -> Result<(), CloudError>;
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CloudPreset {
    pub id: &'static str,
    pub name: &'static str,
    pub protocol: &'static str,
    pub default_server: &'static str,
    pub default_port: u16,
    pub use_https: bool,
    pub auth_type: &'static str,
}

pub fn get_presets() -> Vec<CloudPreset> {
    vec![
        CloudPreset { id: "webdav", name: "Custom WebDAV", protocol: "webdav", default_server: "", default_port: 443, use_https: true, auth_type: "password" },
        CloudPreset { id: "nextcloud", name: "NextCloud", protocol: "webdav", default_server: "/remote.php/dav/files/", default_port: 443, use_https: true, auth_type: "app_password" },
        CloudPreset { id: "synology", name: "Synology", protocol: "webdav", default_server: "", default_port: 5006, use_https: false, auth_type: "password" },
        CloudPreset { id: "jianguoyun", name: "Nutstore", protocol: "webdav", default_server: "https://dav.jianguoyun.com/dav/", default_port: 443, use_https: true, auth_type: "app_password" },
        CloudPreset { id: "box", name: "Box", protocol: "webdav", default_server: "https://dav.box.com/dav/", default_port: 443, use_https: true, auth_type: "password" },
        CloudPreset { id: "dropbox", name: "Dropbox", protocol: "dropbox", default_server: "https://api.dropboxapi.com", default_port: 443, use_https: true, auth_type: "oauth2" },
        CloudPreset { id: "google_drive", name: "Google Drive", protocol: "google_drive", default_server: "https://www.googleapis.com", default_port: 443, use_https: true, auth_type: "oauth2" },
        CloudPreset { id: "onedrive", name: "OneDrive", protocol: "onedrive", default_server: "https://graph.microsoft.com", default_port: 443, use_https: true, auth_type: "oauth2" },
    ]
}
```

- [ ] **Step 3: 注册 backup 模块**

在 `src-tauri/src/infrastructure/mod.rs` 添加：

```rust
pub mod backup;
```

- [ ] **Step 4: 验证编译**

Run: `cd src-tauri && cargo check`

- [ ] **Step 5: 提交**

```bash
git add src-tauri/src/infrastructure/backup/ src-tauri/src/infrastructure/mod.rs
git commit -m "feat(backup): add CloudProvider trait, error types, and provider presets"
```

---

### Task 3: BackupService 核心

**Files:**
- Create: `src-tauri/src/infrastructure/backup/backup_service.rs`

核心职责：序列化 → gzip 压缩 → AES-256-GCM 加密 → 本地文件写入。读取时反向操作。支持差异计算。

关键结构：
- `BackupService { pool, backup_dir }` — 持有数据库连接和备份目录路径
- `BackupFile` — 备份文件 JSON 格式（version, encrypted, compressed, salt, data, checksum, metadata）
- `BackupData` — 解密后的数据（6 个表的数据）
- `DiffSummary / TableDiff` — 差异计算结果
- `BackupInfo` — 备份文件信息（文件名、大小、时间、元数据、是否在云端）

关键方法：
- `create_backup(encryption_service)` — 导出全表→压缩→加密→写文件
- `list_backups()` — 扫描备份目录
- `read_backup_metadata(filename)` — 读取文件头（无需密码）
- `decrypt_backup_data(backup, encryption_service)` — 解密+解压
- `compute_diff(backup_data)` — 与本地数据对比
- `delete_backup(filename)` — 删除文件

压缩使用 `flate2::GzEncoder`/`GzDecoder`，加密使用已有的 `EncryptionService`，校验使用 `sha2::Sha256`。

- [ ] **Step 1: 实现 BackupService**

创建 `src-tauri/src/infrastructure/backup/backup_service.rs`（完整代码见设计规格 Section 3 的格式）

- [ ] **Step 2: 验证编译**

Run: `cd src-tauri && cargo check`

- [ ] **Step 3: 提交**

```bash
git add src-tauri/src/infrastructure/backup/backup_service.rs
git commit -m "feat(backup): add BackupService with compress, encrypt, diff, and file management"
```

---

### Task 4: WebDAV CloudProvider 实现

**Files:**
- Create: `src-tauri/src/infrastructure/backup/webdav_provider.rs`
- Create: `src-tauri/src/infrastructure/backup/dropbox_provider.rs`
- Create: `src-tauri/src/infrastructure/backup/google_drive_provider.rs`
- Create: `src-tauri/src/infrastructure/backup/onedrive_provider.rs`

WebDAV 使用 `reqwest` HTTP 客户端：
- `PUT` 上传文件
- `GET` 下载文件
- `PROPFIND` 列出文件
- `DELETE` 删除文件
- Basic Auth 认证

OAuth 提供商（Dropbox/Google Drive/OneDrive）先创建 stub 实现，所有方法返回 `CloudError::NotConfigured`，后续独立开发。

- [ ] **Step 1: 实现 WebDAV provider**

- [ ] **Step 2: 创建 OAuth provider stubs**

- [ ] **Step 3: 验证编译**

Run: `cd src-tauri && cargo check`

- [ ] **Step 4: 提交**

```bash
git add src-tauri/src/infrastructure/backup/webdav_provider.rs src-tauri/src/infrastructure/backup/dropbox_provider.rs src-tauri/src/infrastructure/backup/google_drive_provider.rs src-tauri/src/infrastructure/backup/onedrive_provider.rs
git commit -m "feat(backup): add WebDAV provider and OAuth provider stubs"
```

---

### Task 5: Tauri 备份命令

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/backup_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/mod.rs`
- Modify: `src-tauri/src/main.rs`

暴露命令：
- `create_backup` / `list_backups` / `get_backup_metadata` / `get_backup_diff` / `delete_backup`
- `get_cloud_presets` / `get_cloud_settings` / `save_cloud_settings`
- `test_cloud_connection` / `upload_to_cloud` / `list_cloud_backups`

State 结构持有 `SqlitePool`、`PathBuf`（备份目录）、`Arc<EncryptionAppService>`。

- [ ] **Step 1: 创建 backup_commands.rs**

- [ ] **Step 2: 注册到 mod.rs 和 main.rs**

- [ ] **Step 3: 验证编译**

Run: `cd src-tauri && cargo check`

- [ ] **Step 4: 提交**

```bash
git add src-tauri/src/presentation/tauri_commands/backup_commands.rs src-tauri/src/presentation/tauri_commands/mod.rs src-tauri/src/main.rs
git commit -m "feat(backup): add Tauri commands for backup/restore/cloud operations"
```

---

### Task 6: 前端 API 客户端和 Hook

**Files:**
- Create: `src/lib/tauri/backup.ts`
- Create: `src/hooks/useBackup.ts`

`backup.ts` 封装所有 Tauri invoke 调用，导出类型安全接口。
`useBackup.ts` 使用 TanStack React Query 管理 backups/cloudPresets/cloudSettings queries 和 createBackup/deleteBackup/saveCloudSettings/testConnection/uploadToCloud mutations。

- [ ] **Step 1: 创建 API 客户端**

- [ ] **Step 2: 创建 useBackup Hook**

- [ ] **Step 3: 提交**

```bash
git add src/lib/tauri/backup.ts src/hooks/useBackup.ts
git commit -m "feat(backup): add frontend API client and useBackup hook"
```

---

### Task 7: BackupPage 主页面 + 路由 + 侧边栏

**Files:**
- Create: `src/pages/BackupPage.tsx`
- Modify: `src/router.tsx`
- Modify: `src/components/layout/Sidebar.tsx`

页面结构：
1. 标题 + 「立即备份」按钮
2. 三张状态卡片（加密/云端/数量）
3. 云盘配置区 + 配置按钮
4. 备份历史列表

侧边栏在 Settings 之上添加 Backup 入口（`HardDrive` icon, `/backup`）。

- [ ] **Step 1: 创建 BackupPage.tsx**

- [ ] **Step 2: 添加路由**

- [ ] **Step 3: 添加侧边栏入口**

- [ ] **Step 4: 提交**

```bash
git add src/pages/BackupPage.tsx src/router.tsx src/components/layout/Sidebar.tsx
git commit -m "feat(backup): add BackupPage with status overview, cloud config, and backup history"
```

---

### Task 8: CloudConfigDialog 云盘配置对话框

**Files:**
- Create: `src/components/CloudConfigDialog.tsx`
- Modify: `src/pages/BackupPage.tsx`

- 8 个提供商图标网格（4x2），选中高亮
- WebDAV 类型：服务器/端口/用户名/密码输入框
- OAuth 类型：「授权」按钮
- 上传频率选择
- 「测试连接」+「保存」

- [ ] **Step 1: 创建 CloudConfigDialog.tsx**

- [ ] **Step 2: 集成到 BackupPage**

- [ ] **Step 3: 提交**

```bash
git add src/components/CloudConfigDialog.tsx src/pages/BackupPage.tsx
git commit -m "feat(backup): add CloudConfigDialog with multi-provider selector"
```

---

### Task 9: RestoreDialog 恢复对话框

**Files:**
- Create: `src/components/RestoreDialog.tsx`
- Modify: `src/pages/BackupPage.tsx`

- 备份文件信息 + 解密状态
- 差异摘要（新增/删除/修改）
- 分类明细表
- 冲突处理选项（radio: 保留较新/使用备份/保留本地）
- 「开始恢复」+ 安全提示

- [ ] **Step 1: 创建 RestoreDialog.tsx**

- [ ] **Step 2: 集成到 BackupPage**

- [ ] **Step 3: 提交**

```bash
git add src/components/RestoreDialog.tsx src/pages/BackupPage.tsx
git commit -m "feat(backup): add RestoreDialog with diff comparison and conflict resolution"
```

---

### Task 10: i18n 和验证

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`

- [ ] **Step 1: 添加 i18n 键**

添加 `nav.backup`、`backup.*` 覆盖所有 BackupPage/CloudConfigDialog/RestoreDialog 文本。

- [ ] **Step 2: 运行 lint**

Run: `pnpm lint`

- [ ] **Step 3: 运行类型检查**

Run: `pnpm type-check`

- [ ] **Step 4: 运行 Rust 检查**

Run: `cd src-tauri && make check`

- [ ] **Step 5: 提交**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat(backup): add i18n keys for backup module in en and zh"
```
