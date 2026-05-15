# 财务管理系统 - 生产就绪改进设计

**版本**: 1.0  
**日期**: 2026-05-15  
**状态**: Approved  
**项目**: Personal Finance Management Application

---

## 文档目的

本设计文档定义了将财务管理系统从开发状态提升到生产就绪状态的完整方案。采用 Scrum 敏捷开发方法，分两个 Sprint 完成。

**目标受众**:
- 开发团队
- 项目经理
- QA 工程师
- 运维团队

---

## 执行摘要

### 项目背景

当前系统已完成核心财务功能开发（Phase 1），但存在以下生产阻塞问题：
- 无数据加密（安全风险）
- 无身份认证（同步 API 开放）
- 同步功能损坏（PostgreSQL 未集成）
- 用户体验差（需要理解复式记账）
- 通知服务未集成（提醒不触发）

### 解决方案

**方案 C：分阶段发布**
- **Sprint 1 (2天)**: 发布仅本地版本，解决安全和 UX 问题
- **Sprint 2 (3-5天)**: 启用多设备同步功能

### 关键里程碑

| 里程碑 | 日期 | 交付物 |
|--------|------|--------|
| Sprint 1 完成 | D+2 | 安全的本地版本 |
| Sprint 2 完成 | D+7 | 完整的生产版本 |
| 生产部署 | D+7 | 应用上线 |

---

## Sprint 1: 本地版本发布

### Sprint 目标

**用户故事**: 作为用户，我希望在单设备上安全地管理财务，无需担心数据泄露，并且能够快速记录收支。

**验收标准**:
- 数据库文件已加密
- 可以用简单表单记录收入/支出/转账
- 还款提醒正常触发
- 应用有结构化日志
- 同步功能已禁用

### Sprint Backlog

| ID | Task | 估时 | 优先级 | 依赖 |
|----|------|------|--------|------|
| T1.1 | 实现密钥派生（PBKDF2） | 2h | P0 | - |
| T1.2 | 集成 SQLite 加密 | 3h | P0 | T1.1 |
| T1.3 | 实现密钥链存储 | 2h | P0 | T1.1 |
| T1.4 | 创建简化交易 DTOs | 1h | P1 | - |
| T1.5 | 实现 create_income/expense/transfer | 4h | P1 | T1.4 |
| T1.6 | 创建简化交易表单 UI | 4h | P1 | T1.5 |
| T1.7 | 集成通知服务到提醒调度器 | 2h | P1 | - |
| T1.8 | 启动提醒调度器 | 1h | P1 | T1.7 |
| T1.9 | 集成 tracing 日志框架 | 2h | P1 | - |
| T1.10 | 修复 P0 Clippy 警告 | 3h | P1 | - |
| T1.11 | 禁用同步 UI | 0.5h | P2 | - |
| T1.12 | 测试加密功能 | 2h | P0 | T1.2, T1.3 |
| **总计** | | **26.5h** | | |

### 技术设计

#### 1. 数据加密层

**位置**: `src-tauri/src/infrastructure/encryption/`

**组件**:
```rust
// encryption/mod.rs
pub struct EncryptionService {
    cipher: Aes256Gcm,
}

impl EncryptionService {
    pub fn new(password: &str, salt: &[u8]) -> Result<Self>
    pub fn encrypt(&self, data: &[u8]) -> Result<Vec<u8>>
    pub fn decrypt(&self, data: &[u8]) -> Result<Vec<u8>>
}
```

**实现方案**:
- 使用 `sqlx` 的 `PRAGMA key` 支持 SQLite 加密
- 密钥派生：PBKDF2-HMAC-SHA256，100,000 次迭代
- 密钥存储：Windows Credential Manager / macOS Keychain
- 首次启动时要求用户设置主密码

**数据流**:
```
用户密码 → PBKDF2 → 256-bit密钥 → SQLite PRAGMA key
```

#### 2. 简化交易 API

**位置**: `src-tauri/src/application/dtos/simple_transaction_dto.rs`

**新增 DTOs**:
```rust
pub struct SimpleIncomeDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub account_id: Uuid,
    pub category_id: Uuid,
    pub description: String,
}

pub struct SimpleExpenseDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub account_id: Uuid,
    pub category_id: Uuid,
    pub description: String,
}

pub struct SimpleTransferDto {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub from_account_id: Uuid,
    pub to_account_id: Uuid,
    pub description: String,
}
```

**服务层方法** (`transaction_service.rs`):
```rust
impl TransactionService {
    pub async fn create_income(&self, dto: SimpleIncomeDto) -> Result<Uuid> {
        // 自动生成两个条目：
        // 借：账户（资产增加）
        // 贷：收入科目
    }
    
    pub async fn create_expense(&self, dto: SimpleExpenseDto) -> Result<Uuid> {
        // 借：支出科目
        // 贷：账户（资产减少）
    }
    
    pub async fn create_transfer(&self, dto: SimpleTransferDto) -> Result<Uuid> {
        // 借：目标账户
        // 贷：源账户
    }
}
```

#### 3. 通知服务集成

**位置**: `src-tauri/src/infrastructure/scheduler/reminder_scheduler.rs`

**集成点**:
```rust
impl ReminderScheduler {
    async fn check_reminders(&self) {
        let due_reminders = self.reminder_repo.find_due_reminders().await?;
        
        for reminder in due_reminders {
            self.notification_service.send_notification(
                &reminder.title,
                &reminder.message,
                reminder.due_date,
            ).await?;
            
            reminder.mark_as_notified();
            self.reminder_repo.update(&reminder).await?;
        }
    }
}
```

**启动集成** (`main.rs`):
```rust
let reminder_scheduler = ReminderScheduler::new(reminder_repo, notification_service);
tokio::spawn(async move {
    reminder_scheduler.start().await;
});
```

#### 4. 日志框架

**依赖**:
```toml
[dependencies]
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
tracing-appender = "0.2"
```

**配置** (`main.rs`):
```rust
fn init_logging() {
    let file_appender = tracing_appender::rolling::daily("logs", "finance-app.log");
    
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new("info"))
        .with(tracing_subscriber::fmt::layer().with_writer(file_appender))
        .init();
}
```

#### 5. Clippy 警告修复策略

**优先级分类**:
- **P0 - 必须修复**（可能导致 bug）:
  - `unused_must_use` - 忽略 Result
  - `clippy::unwrap_used` - 可能 panic
  - `clippy::expect_used` - 可能 panic

- **P1 - 应该修复**（代码质量）:
  - `dead_code` - 未使用的代码
  - `unused_imports` - 未使用的导入

**修复方法**:
```bash
cargo clippy --fix --allow-dirty --allow-staged
cargo clippy -- -W clippy::unwrap_used -W clippy::expect_used
```

#### 6. 禁用同步功能

**UI 变更** (`src/components/layout/Sidebar.tsx`):
```typescript
const menuItems = [
  { icon: Home, label: '首页', path: '/' },
  { icon: Wallet, label: '账户', path: '/accounts' },
  { icon: Receipt, label: '交易', path: '/transactions' },
  { icon: CreditCard, label: '借贷', path: '/debts' },
  { icon: BarChart3, label: '报表', path: '/reports' },
  { icon: Settings, label: '设置', path: '/settings' },
  // 移除同步菜单项
];
```

### Definition of Done

- [ ] 所有 P0 Clippy 警告已修复
- [ ] 数据库加密功能已测试（手动）
- [ ] 简化交易表单可用（收入/支出/转账）
- [ ] 还款提醒可以触发
- [ ] 日志文件正常生成
- [ ] 同步 UI 已隐藏
- [ ] 代码已提交到 `sprint-1` 分支
- [ ] Sprint Review 完成

---

## Sprint 2: 同步功能启用

### Sprint 目标

**用户故事**: 作为用户，我希望在多设备间安全同步数据，并且只有我的设备能访问。

**验收标准**:
- 可以注册设备并获得令牌
- 同步 API 需要身份认证
- 多设备同步测试通过
- 冲突解决正常工作

### Sprint Backlog

| ID | Task | 估时 | 优先级 | 依赖 |
|----|------|------|--------|------|
| T2.1 | 实现 JWT 服务 | 3h | P0 | - |
| T2.2 | 实现设备注册 | 2h | P0 | T2.1 |
| T2.3 | 创建认证中间件 | 2h | P0 | T2.1 |
| T2.4 | 添加 devices 表迁移 | 1h | P0 | - |
| T2.5 | 修复 SyncService（集成 PG 仓储） | 6h | P0 | - |
| T2.6 | 实现冲突解决器 | 4h | P0 | T2.5 |
| T2.7 | 启动同步调度器 | 1h | P1 | T2.5 |
| T2.8 | 创建同步页面 UI | 4h | P1 | T2.2 |
| T2.9 | 实现手动同步命令 | 2h | P1 | T2.5 |
| T2.10 | 编写同步集成测试 | 6h | P1 | T2.6 |
| T2.11 | 配置生产环境 | 2h | P1 | - |
| T2.12 | 安全审计 | 3h | P0 | All |
| **总计** | | **36h** | | |

### 技术设计

#### 1. 同步 API 认证系统

**位置**: `src-tauri/src/infrastructure/auth/`

**JWT 服务**:
```rust
pub struct JwtService {
    secret: String,
    token_expiry: Duration,
}

impl JwtService {
    pub fn generate_device_token(&self, device_id: &str) -> Result<String> {
        let claims = Claims {
            sub: device_id.to_string(),
            exp: (Utc::now() + self.token_expiry).timestamp(),
            iat: Utc::now().timestamp(),
        };
        encode(&Header::default(), &claims, &EncodingKey::from_secret(self.secret.as_bytes()))
    }
    
    pub fn validate_token(&self, token: &str) -> Result<Claims>
}
```

**设备注册**:
```rust
pub struct DeviceRegistry {
    device_repo: Arc<dyn DeviceRepository>,
    jwt_service: Arc<JwtService>,
}

impl DeviceRegistry {
    pub async fn register_device(&self, device_name: &str) -> Result<(String, String)> {
        let device_id = Uuid::new_v4().to_string();
        let token = self.jwt_service.generate_device_token(&device_id)?;
        
        let device = Device {
            id: device_id.clone(),
            name: device_name.to_string(),
            token_hash: hash_token(&token),
            created_at: Utc::now(),
        };
        
        self.device_repo.create(&device).await?;
        Ok((device_id, token))
    }
}
```

**认证中间件** (`presentation/api/middleware/auth.rs`):
```rust
pub async fn auth_middleware(
    State(jwt_service): State<Arc<JwtService>>,
    mut req: Request<Body>,
    next: Next,
) -> Result<Response, StatusCode> {
    let auth_header = req.headers()
        .get(AUTHORIZATION)
        .and_then(|h| h.to_str().ok())
        .ok_or(StatusCode::UNAUTHORIZED)?;
    
    let token = auth_header
        .strip_prefix("Bearer ")
        .ok_or(StatusCode::UNAUTHORIZED)?;
    
    let claims = jwt_service
        .validate_token(token)
        .map_err(|_| StatusCode::UNAUTHORIZED)?;
    
    req.extensions_mut().insert(claims);
    Ok(next.run(req).await)
}
```

#### 2. PostgreSQL 仓储集成

**位置**: `src-tauri/src/infrastructure/sync/sync_service.rs`

**修复前**:
```rust
// ❌ 内存存储
pub struct SyncService {
    accounts: Arc<RwLock<Vec<Account>>>,
}
```

**修复后**:
```rust
// ✅ PostgreSQL 仓储
pub struct SyncService {
    pg_account_repo: Arc<PostgresAccountRepository>,
    pg_transaction_repo: Arc<PostgresTransactionRepository>,
    pg_debt_repo: Arc<PostgresDebtRepository>,
    conflict_resolver: Arc<ConflictResolver>,
}

impl SyncService {
    pub async fn sync_accounts(
        &self,
        device_id: &str,
        local_accounts: Vec<Account>,
    ) -> Result<Vec<Account>> {
        let server_accounts = self.pg_account_repo.find_all().await?;
        let conflicts = self.detect_conflicts(&local_accounts, &server_accounts);
        let resolved = self.conflict_resolver.resolve(conflicts)?;
        
        for account in &resolved.to_upload {
            self.pg_account_repo.upsert(account).await?;
        }
        
        Ok(resolved.to_download)
    }
}
```

#### 3. 冲突解决策略

**位置**: `src-tauri/src/infrastructure/sync/conflict_resolver.rs`

**Last Write Wins 实现**:
```rust
pub struct ConflictResolver;

impl ConflictResolver {
    pub fn resolve(&self, conflicts: Vec<Conflict<Account>>) -> Result<Resolution<Account>> {
        let mut to_upload = Vec::new();
        let mut to_download = Vec::new();
        
        for conflict in conflicts {
            match conflict {
                Conflict::LocalNewer(account) => to_upload.push(account),
                Conflict::ServerNewer(account) => to_download.push(account),
                Conflict::BothModified { local, server } => {
                    // 比较 updated_at 时间戳
                    if local.updated_at > server.updated_at {
                        to_upload.push(local);
                    } else {
                        to_download.push(server);
                    }
                }
            }
        }
        
        Ok(Resolution { to_upload, to_download })
    }
}
```

#### 4. 数据库迁移

**新增表**: `devices`

```sql
-- migrations/20260515_add_devices_table.sql
CREATE TABLE devices (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    token_hash TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_sync TIMESTAMP,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_devices_token_hash ON devices(token_hash);
```

#### 5. 前端同步 UI

**位置**: `src/pages/SyncPage.tsx`

**功能**:
- 设备注册表单
- 手动同步按钮
- 同步状态显示
- 自动同步间隔设置

#### 6. 集成测试

**位置**: `src-tauri/tests/integration/sync_test.rs`

**关键场景**:
```rust
#[tokio::test]
async fn test_sync_accounts_no_conflict() {
    // 设备A创建账户 → 同步 → 设备B同步 → 验证
}

#[tokio::test]
async fn test_sync_conflict_last_write_wins() {
    // 两设备修改同一账户 → 同步 → 验证较新版本胜出
}
```

### Definition of Done

- [ ] 设备注册流程可用
- [ ] 同步 API 需要认证
- [ ] 多设备同步测试通过（至少 2 设备）
- [ ] 冲突解决测试通过
- [ ] 集成测试全部通过
- [ ] 安全检查清单完成
- [ ] 生产环境配置文档完成
- [ ] 代码已合并到 `main` 分支
- [ ] Sprint Review 完成
- [ ] 准备发布

---

## Scrum 工件

### Product Backlog

| ID | User Story | Story Points | Sprint | 优先级 |
|----|-----------|--------------|--------|--------|
| US-1 | 作为用户，我希望我的财务数据被加密存储，以保护隐私 | 5 | Sprint 1 | P0 |
| US-2 | 作为用户，我希望快速记录收入/支出，无需理解复式记账 | 8 | Sprint 1 | P0 |
| US-3 | 作为用户，我希望收到还款提醒，避免逾期 | 3 | Sprint 1 | P1 |
| US-4 | 作为用户，我希望在多设备间同步数据 | 13 | Sprint 2 | P0 |
| US-5 | 作为用户，我希望同步是安全的，只有我的设备能访问 | 8 | Sprint 2 | P0 |

### Sprint 时间线

```
Day 1-2: Sprint 1
├── 数据加密实现
├── 简化交易 API
├── 通知服务集成
├── 日志框架
└── Sprint Review

Day 3-7: Sprint 2
├── JWT 认证系统
├── PostgreSQL 集成
├── 冲突解决器
├── 同步 UI
├── 集成测试
├── 安全审计
└── Sprint Review + 发布准备
```

### 每日站会（Daily Scrum）

**时间**: 每天固定时间，15分钟  
**参与者**: 开发团队  
**格式**:
1. 昨天完成了什么？
2. 今天计划做什么？
3. 有什么阻碍？

**记录位置**: `docs/scrum/daily-standup-YYYY-MM-DD.md`

### Sprint Review

**Sprint 1 Review**:
- 演示数据加密功能
- 演示简化交易表单
- 演示还款提醒
- 收集反馈

**Sprint 2 Review**:
- 演示设备注册
- 演示多设备同步
- 演示冲突解决
- 准备发布

### Sprint Retrospective

**讨论内容**:
- 什么做得好？
- 什么需要改进？
- 下个 Sprint 的行动项

**记录位置**: `docs/scrum/retrospective-sprint-N.md`

---

## 安全检查清单

### Sprint 1
- [ ] SQLite 数据库已加密
- [ ] 主密码强度验证（至少 8 位）
- [ ] 密钥安全存储在系统密钥链
- [ ] 日志不包含敏感信息

### Sprint 2
- [ ] JWT secret 使用强随机值（至少 256 位）
- [ ] PostgreSQL 连接使用 TLS
- [ ] 设备令牌存储使用哈希（bcrypt）
- [ ] API 速率限制（防止暴力破解）
- [ ] 输入验证（防止 SQL 注入）
- [ ] CORS 配置（仅允许应用域名）
- [ ] 错误消息不泄露敏感信息

---

## 环境配置

### 开发环境
```bash
# .env.development
DATABASE_URL=sqlite://./data/finance.db
POSTGRES_URL=postgresql://localhost:5432/finance_sync
JWT_SECRET=dev_secret_change_in_production
SYNC_INTERVAL_MINUTES=15
LOG_LEVEL=debug
```

### 生产环境
```bash
# .env.production
DATABASE_URL=sqlite://./data/finance.db
POSTGRES_URL=postgresql://your-server:5432/finance_sync
JWT_SECRET=<generate-strong-secret>
SYNC_INTERVAL_MINUTES=15
LOG_LEVEL=info
```

---

## 风险管理

### 已识别风险

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| 加密实现错误导致数据丢失 | 中 | 高 | 充分测试，提供数据备份功能 |
| 同步冲突解决不当 | 中 | 中 | 详细的集成测试，用户可手动解决 |
| PostgreSQL 服务器不可用 | 低 | 中 | 本地优先，离线模式可用 |
| JWT 密钥泄露 | 低 | 高 | 密钥轮换机制，监控异常访问 |
| 时间紧迫导致质量问题 | 高 | 中 | 优先级明确，P0 任务优先 |

---

## 测试策略

### Sprint 1 测试

**单元测试**:
- 密钥派生函数
- 简化交易 DTO 转换
- 提醒调度逻辑

**手动测试**:
- 设置主密码并重启应用
- 创建收入/支出/转账
- 验证还款提醒触发
- 检查日志文件生成

### Sprint 2 测试

**单元测试**:
- JWT 生成和验证
- 冲突解决算法

**集成测试**:
- 设备注册流程
- 多设备同步（无冲突）
- 多设备同步（有冲突）
- 认证失败场景

**安全测试**:
- 无效令牌访问
- 过期令牌访问
- SQL 注入尝试

---

## 部署计划

### 部署前检查

- [ ] 所有测试通过
- [ ] 安全检查清单完成
- [ ] 生产环境配置就绪
- [ ] 数据库备份机制测试
- [ ] 回滚计划准备

### 部署步骤

1. 备份当前生产数据（如有）
2. 部署 PostgreSQL 数据库
3. 运行数据库迁移
4. 配置环境变量
5. 部署应用程序
6. 验证核心功能
7. 监控日志和错误

### 回滚计划

如果出现严重问题：
1. 停止新版本应用
2. 恢复数据库备份
3. 部署旧版本应用
4. 通知用户

---

## 文档维护

**负责人**: 开发团队  
**更新频率**: 每个 Sprint 结束后  
**最后更新**: 2026-05-15

**变更日志**:
- 2026-05-15: 初始版本创建

---

**END OF DESIGN DOCUMENT**

