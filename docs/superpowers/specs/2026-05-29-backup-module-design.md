> **ℹ️ 云备份 / 多设备同步已取消 — 2026-07-25**: 本文涉及的云备份与多设备同步内容均已下架(御财 server+Postgres 已集中持久化数据,client 直连服务器,无需云盘备份或多端同步);本地备份 / auto-backup 相关描述仍然有效。

# 备份与恢复模块设计规格

**日期**: 2026-05-29
**版本**: 1.0
**状态**: 已确认

---

## 1. 概述

为 Finance App 实现端到端加密备份系统，支持本地自动备份和多云盘上传（WebDAV/Dropbox/Google Drive/OneDrive）。备份文件经过 gzip 压缩和 AES-256-GCM 加密，恢复时提供差异对比供用户选择合并策略。

### 核心需求

- 端到端加密备份（AES-256-GCM），利用已有 EncryptionService
- gzip 压缩，减小备份文件体积（预计压缩率 60-80%）
- 本地自动备份到 app 数据目录
- 多云盘自动上传，支持 8 种云服务提供商
- 恢复时显示差异摘要，用户选择覆盖/合并策略
- 恢复前自动创建当前数据备份，支持回退

---

## 2. 系统架构

```
┌─────────────────────────────────────┐
│  BackupPage (React)                 │  独立页面，侧边栏入口（设置之上）
│  状态概览 / 云盘配置 / 备份历史列表  │
├─────────────────────────────────────┤
│  Tauri Commands                     │  backup_commands.rs
│  create_backup / restore / list     │
│  configure_cloud / test_connection  │
├─────────────────────────────────────┤
│  BackupService (Rust)               │  核心逻辑
│  序列化 → 压缩 → 加密 → 存储 → 上传 │
├─────────────────────────────────────┤
│  CloudProvider trait                │  统一云存储接口
│  WebDAV / Dropbox / Google / One    │
├─────────────────────────────────────┤
│  本地文件系统                        │  %APPDATA%/finance-app/backups/
└─────────────────────────────────────┘
```

### 数据流

**备份流程:**
```
SQLite 全表 → JSON 序列化 → gzip 压缩 → AES-256-GCM 加密 → 本地 .enc 文件 → 云盘上传
```

**恢复流程:**
```
读取 .enc 文件（本地或云盘） → 解密 → gzip 解压 → JSON 解析
→ 与本地数据对比生成差异摘要 → 用户选择策略 → 写入 SQLite
→ 自动创建恢复前备份
```

---

## 3. 备份文件格式

```json
{
  "version": "1.0",
  "encrypted": true,
  "compressed": true,
  "salt": "<hex-encoded 32-byte salt>",
  "data": "<base64-encoded AES-256-GCM ciphertext of gzipped JSON>",
  "created_at": "2026-05-29T08:00:00Z",
  "checksum": "sha256:<hex>",
  "metadata": {
    "device_id": "uuid",
    "accounts": 10,
    "transactions": 163,
    "debts": 3,
    "budgets": 2,
    "goals": 5,
    "tags": 7
  }
}
```

- `salt`: 用于密钥派生的随机盐，恢复时需要
- `checksum`: 未加密原始数据的 SHA-256 校验和，用于验证解密完整性
- `metadata`: 未加密的概要信息，恢复前可预览内容而无需密码
- 文件扩展名: `.enc`
- 文件命名: `backup_YYYYMMDD_HHmm.enc`

---

## 4. 云盘提供商

### 4.1 CloudProvider trait

```rust
pub trait CloudProvider: Send + Sync {
    fn name(&self) -> &str;
    fn test_connection(&self) -> Result<(), CloudError>;
    fn upload(&self, local_path: &Path, remote_name: &str) -> Result<(), CloudError>;
    fn download(&self, remote_name: &str, local_path: &Path) -> Result<(), CloudError>;
    fn list_backups(&self) -> Result<Vec<CloudBackupInfo>, CloudError>;
    fn delete(&self, remote_name: &str) -> Result<(), CloudError>;
}
```

### 4.2 支持的提供商

| 提供商 | 协议 | 默认地址 | 端口 | 认证方式 |
|--------|------|----------|------|----------|
| 自定义 WebDAV | WebDAV | （用户填写） | 443 | 用户名+密码 |
| NextCloud | WebDAV | `{server}/remote.php/dav/files/` | 443 | 用户名+应用密码 |
| Synology | WebDAV | `{server}:5006/` | 5006 | 用户名+密码 |
| 坚果云 | WebDAV | `dav.jianguoyun.com/dav/` | 443 | 邮箱+应用密码 |
| Dropbox | Dropbox API | `api.dropboxapi.com` | 443 | OAuth 2.0 |
| Google Drive | Google API | `www.googleapis.com` | 443 | OAuth 2.0 |
| OneDrive | Graph API | `graph.microsoft.com` | 443 | OAuth 2.0 |
| Box | WebDAV | `dav.box.com/dav/` | 443 | 用户名+密码 |

### 4.3 配置持久化

云盘配置存储在 `encryption_settings` 同级的 `cloud_settings` 表中：

```sql
CREATE TABLE cloud_settings (
    provider TEXT NOT NULL,         -- 'webdav', 'nextcloud', 'dropbox', etc.
    server_url TEXT,
    port INTEGER,
    username TEXT,
    password TEXT,                  -- 使用 EncryptionAppService 加密；未启用加密时使用设备固定密钥
    remote_path TEXT,
    access_token TEXT,              -- OAuth 提供商使用
    refresh_token TEXT,
    auto_upload TEXT NOT NULL DEFAULT 'on_backup',  -- 'on_backup', 'daily', 'manual'
    enabled BOOLEAN NOT NULL DEFAULT true,
    last_upload_at TEXT,
    updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
```

---

## 5. 恢复差异对比

### 5.1 差异计算

恢复时，解密备份后与本地数据逐表对比：

```rust
pub struct DiffSummary {
    pub added: Vec<EntityDiff>,      // 备份中有，本地没有
    pub removed: Vec<EntityDiff>,    // 本地有，备份中没有
    pub modified: Vec<EntityDiff>,   // 两边都有但 updated_at 不同
}
```

### 5.2 差异摘要展示

恢复对话框显示：
- **总览**: 新增 N 条 / 删除 N 条 / 修改 N 条
- **分类明细表**: 按数据类型（账户/交易/债务/预算/目标/标签）分别显示本地数量、备份数量、差异数
- **冲突处理选项**: 用户选择如何处理 5 条修改记录
  - 保留较新的（按 updated_at 自动选择）
  - 使用备份版本
  - 保留本地版本

### 5.3 安全措施

- 恢复前自动创建当前数据备份（`pre_restore_YYYYMMDD_HHmm.enc`）
- 恢复操作在事务中执行，失败时回滚
- 恢复后提示用户验证数据

---

## 6. UI 设计

### 6.1 独立备份页面 (BackupPage)

位置: 侧边栏，设置入口之上

页面结构:
1. **顶部操作栏**: 「立即备份」按钮
2. **状态概览**: 三张卡片 — 加密状态 / 云端连接 / 备份数量
3. **云盘配置区**: 当前提供商信息 + 配置按钮
4. **备份历史列表**: 每行显示文件名、大小、时间、来源（本地/云端）、操作（恢复/删除）

### 6.2 WebDAV 配置对话框

- 提供商图标网格选择（8 个选项）
- 选择后自动填充: 服务器地址、端口、协议、认证方式
- Dropbox/Google/OneDrive 切换为 OAuth 授权按钮
- 「测试连接」按钮验证配置
- 上传频率选择: 每次备份后 / 每天一次 / 仅手动

### 6.3 恢复对话框

- 备份文件信息 + 解密状态
- 差异摘要（新增/删除/修改）
- 分类明细表
- 冲突处理选项
- 开始恢复按钮 + 安全提示

---

## 7. 自动备份调度

- 默认频率: 每天一次（可配置）
- 触发条件: 定时器 + 应用启动时检查是否超过间隔
- 备份保留策略: 保留最近 30 份，超出自动清理最旧的
- WebDAV 上传: 根据配置频率自动或手动

---

## 8. 依赖

### Rust 新增

- `flate2` — gzip 压缩/解压
- `reqwest` — HTTP 客户端（已有，WebDAV 使用）
- OAuth 相关: 对于 Dropbox/Google/OneDrive，使用各自的 REST API（通过 reqwest）

### 前端新增

- `BackupPage.tsx` — 独立备份页面
- `CloudConfigDialog.tsx` — 云盘配置对话框
- `RestoreDialog.tsx` — 恢复差异对比对话框
- `lib/tauri/backup.ts` — 前端 API 客户端
- `hooks/useBackup.ts` — 备份状态管理 Hook

---

## 9. 文件结构

```
src-tauri/src/
├── application/services/backup_service.rs    # 核心备份逻辑
├── infrastructure/
│   ├── backup/
│   │   ├── mod.rs
│   │   ├── local_storage.rs                 # 本地文件管理
│   │   ├── cloud_provider.rs                # CloudProvider trait
│   │   ├── webdav_provider.rs               # WebDAV 实现
│   │   ├── dropbox_provider.rs              # Dropbox API 实现
│   │   ├── google_drive_provider.rs         # Google Drive API 实现
│   │   └── onedrive_provider.rs             # OneDrive Graph API 实现
│   └── repositories/backup_repository.rs    # 备份元数据仓库
├── presentation/tauri_commands/
│   └── backup_commands.rs                   # Tauri 命令
├── domain/aggregates/backup_record.rs        # 备份记录聚合
└── migrations/20260529000001_create_cloud_settings.sql

src/
├── pages/BackupPage.tsx                      # 独立备份页面
├── components/
│   ├── CloudConfigDialog.tsx                 # 云盘配置
│   └── RestoreDialog.tsx                     # 恢复对话框
├── lib/tauri/backup.ts                       # 前端 API
└── hooks/useBackup.ts                        # 备份 Hook
```
