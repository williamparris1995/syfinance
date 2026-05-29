# Phase 6: 端到端加密实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现端到端加密基础设施，包括密钥管理、加密命令、设置 UI

**Architecture:** 基于已有 EncryptionService，添加 OS keychain 集成、Tauri 命令暴露、前端设置页面

**Tech Stack:** Rust (aes-gcm, pbkdf2, keyring), React, TypeScript

---

## 已完成

- ✅ EncryptionService 核心 (AES-256-GCM, PBKDF2 key derivation)
- ✅ 加密依赖 (aes-gcm, pbkdf2, sha2, keyring, hex)

## 文件结构映射

### 新增/修改文件
```
src-tauri/src/
├── application/services/encryption_service.rs  # 应用层加密服务
├── presentation/tauri_commands/encryption_commands.rs  # Tauri 命令
src/
├── components/EncryptionSetup.tsx               # 加密设置向导
├── pages/SettingsPage.tsx                       # 添加加密设置区
├── lib/tauri/encryption.ts                      # 前端 API
├── hooks/useEncryption.ts                       # 加密 Hook
```

---

## Task 1: 实现密钥管理服务

**Files:**
- Create: `src-tauri/src/application/services/encryption_service.rs`

- [ ] **Step 1: 创建应用层加密服务**

封装 OS keychain 操作：
- `setup_encryption(password)` - 从密码派生密钥，salt 存数据库，密钥存 keychain
- `unlock_encryption(password)` - 验证密码，获取密钥
- `lock_encryption()` - 清除内存中的密钥
- `is_encryption_enabled()` - 检查是否已启用加密
- `encrypt_field(data)` - 加密单个字段
- `decrypt_field(data)` - 解密单个字段

- [ ] **Step 2: 注册到 application services**

更新 `application/services/mod.rs` 和 `main.rs`。

- [ ] **Step 3: 添加数据库迁移**

创建 encryption_settings 表存储 salt 和配置。

- [ ] **Step 4: 提交**

## Task 2: 添加加密 Tauri 命令

**Files:**
- Create: `src-tauri/src/presentation/tauri_commands/encryption_commands.rs`

- [ ] **Step 1: 创建 Tauri 命令**

暴露 setup_encryption, unlock_encryption, lock_encryption, get_encryption_status 命令。

- [ ] **Step 2: 注册命令**

更新 `main.rs` 和 `presentation/tauri_commands/mod.rs`。

- [ ] **Step 3: 提交**

## Task 3: 前端加密 API 和 Hook

**Files:**
- Create: `src/lib/tauri/encryption.ts`
- Create: `src/hooks/useEncryption.ts`

- [ ] **Step 1: 创建前端 API 客户端**

封装 Tauri 命令调用。

- [ ] **Step 2: 创建加密 Hook**

管理加密状态（enabled, locked/unlocked）。

- [ ] **Step 3: 提交**

## Task 4: 加密设置 UI

**Files:**
- Modify: `src/pages/SettingsPage.tsx`
- Create: `src/components/EncryptionSetup.tsx`

- [ ] **Step 1: 在设置页添加加密区域**

显示当前加密状态，启用/禁用按钮。

- [ ] **Step 2: 创建加密设置向导**

密码输入、确认、强度指示器。

- [ ] **Step 3: 添加 i18n**

- [ ] **Step 4: 提交**

---

## Phase 6 完成检查清单

- [ ] 加密服务使用 OS keychain 管理密钥
- [ ] Tauri 命令正确暴露加密操作
- [ ] 前端 Hook 管理加密状态
- [ ] 设置 UI 显示加密状态并支持启用/禁用
- [ ] 代码已提交
