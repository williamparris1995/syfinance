# Rust代码生成规范和约束

**版本**: 1.0  
**日期**: 2026-05-12  
**适用范围**: 所有AI生成的Rust代码

---

## 1. 数据库访问规范

### 1.1 必须使用ORM框架

❌ **禁止**：硬编码SQL字段名
```rust
// 错误示例
let reminder = sqlx::query_as!(
    Reminder,
    r#"SELECT id, title, description FROM reminders WHERE id = ?"#,
    id
)
```

✅ **正确**：使用SeaORM
```rust
// 正确示例
use sea_orm::*;

let reminder = Reminders::find_by_id(id)
    .one(&db)
    .await?;
```

**理由**：
- 字段名修改时，编译器会报错（类型安全）
- 减少维护成本
- 自动处理类型转换

### 1.2 ORM选择

**推荐**: SeaORM（异步、类型安全、现代）

**依赖配置**：
```toml
[dependencies]
sea-orm = { version = "0.12", features = ["sqlx-sqlite", "runtime-tokio-native-tls", "macros"] }
```

---

## 2. 字符串硬编码规范

### 2.1 实现代码中禁止硬编码字符串

❌ **禁止**：手动字符串匹配
```rust
// 错误示例
impl Priority {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Low => "LOW",      // 硬编码
            Self::Normal => "NORMAL", // 硬编码
        }
    }
}
```

✅ **正确**：使用serde自动序列化
```rust
// 正确示例
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Priority {
    Low,     // 自动序列化为 "LOW"
    Normal,  // 自动序列化为 "NORMAL"
    High,
    Urgent,
}
```

### 2.2 必要的字符串使用常量

❌ **禁止**：魔法字符串
```rust
// 错误示例
if status == "SUCCESS" {  // 魔法字符串
    // ...
}
```

✅ **正确**：使用常量
```rust
// 正确示例
pub const STATUS_SUCCESS: &str = "SUCCESS";
pub const STATUS_FAILED: &str = "FAILED";

if status == STATUS_SUCCESS {
    // ...
}
```

### 2.3 测试代码例外

✅ **允许**：测试代码中可以有硬编码字符串
```rust
#[cfg(test)]
mod tests {
    #[test]
    fn test_priority_serialization() {
        let priority = Priority::Low;
        let json = serde_json::to_string(&priority).unwrap();
        assert_eq!(json, "\"LOW\"");  // 测试中允许硬编码
    }
}
```

---

## 3. 日志规范

### 3.1 必须使用tracing框架

❌ **禁止**：使用println!或log宏
```rust
// 错误示例
println!("Error: {}", e);  // 无上下文
log::error!("Failed");     // 缺少结构化信息
```

✅ **正确**：使用tracing
```rust
// 正确示例
use tracing::{info, warn, error, debug, instrument};

#[instrument]
pub async fn create_reminder(data: CreateReminderDto) -> Result<Reminder> {
    info!("Creating reminder");  // 自动包含函数名
    // ...
    error!(
        reminder_id = %reminder.id,
        "Failed to save reminder: {}",
        e
    );
}
```

### 3.2 日志必须包含上下文

**必需信息**：
- 模块/文件名（通过target或instrument自动添加）
- 关键ID（如entity_id）
- 操作名称
- 错误详情

**日志级别**：
- `error!`: 错误，需要立即关注
- `warn!`: 警告，可能有问题
- `info!`: 重要信息，业务操作
- `debug!`: 调试信息，开发时使用
- `trace!`: 详细追踪，性能分析

### 3.3 依赖配置

```toml
[dependencies]
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter", "json"] }
```

**初始化**（在main.rs）：
```rust
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

fn main() {
    tracing_subscriber::registry()
        .with(tracing_subscriber::EnvFilter::new(
            std::env::var("RUST_LOG").unwrap_or_else(|_| "info".into()),
        ))
        .with(tracing_subscriber::fmt::layer())
        .init();
    
    // ...
}
```

---

## 4. 错误处理规范

### 4.1 错误必须记录日志

❌ **禁止**：静默失败
```rust
// 错误示例
match do_something() {
    Ok(result) => result,
    Err(_) => return Err(MyError::Failed),  // 错误信息丢失
}
```

✅ **正确**：记录错误上下文
```rust
// 正确示例
match do_something() {
    Ok(result) => result,
    Err(e) => {
        error!(
            operation = "do_something",
            error = %e,
            "Operation failed"
        );
        return Err(MyError::Failed);
    }
}
```

### 4.2 使用anyhow或thiserror

**应用层**：使用anyhow（简单）
```rust
use anyhow::{Context, Result};

pub async fn create_reminder() -> Result<Reminder> {
    let data = fetch_data()
        .await
        .context("Failed to fetch data")?;  // 添加上下文
    // ...
}
```

**领域层**：使用thiserror（类型安全）
```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum ReminderError {
    #[error("Invalid priority: {0}")]
    InvalidPriority(String),
    
    #[error("Reminder not found: {0}")]
    NotFound(Uuid),
}
```

---

## 5. 类型安全规范

### 5.1 避免stringly-typed

❌ **禁止**：使用String表示枚举
```rust
// 错误示例
pub struct Reminder {
    pub priority: String,  // 应该是enum
}
```

✅ **正确**：使用强类型
```rust
// 正确示例
pub enum Priority {
    Low,
    Normal,
    High,
    Urgent,
}

pub struct Reminder {
    pub priority: Priority,
}
```

### 5.2 使用newtype模式

对于有特殊含义的基础类型，使用newtype：
```rust
// 正确示例
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct DeviceId(Uuid);

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
pub struct SequenceNumber(u64);
```

---

## 6. 序列化规范

### 6.1 统一使用serde

所有需要序列化的类型必须derive Serialize/Deserialize：
```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MyStruct {
    // ...
}
```

### 6.2 enum序列化格式

**字符串enum**：使用rename_all
```rust
#[derive(Serialize, Deserialize)]
#[serde(rename_all = "SCREAMING_SNAKE_CASE")]
pub enum Status {
    Success,    // 序列化为 "SUCCESS"
    Failed,     // 序列化为 "FAILED"
}
```

**带数据的enum**：使用tag
```rust
#[derive(Serialize, Deserialize)]
#[serde(tag = "type", content = "data")]
pub enum Event {
    Created { id: Uuid },
    Updated { id: Uuid, changes: Vec<String> },
}
```

---

## 7. 测试规范

### 7.1 测试覆盖率要求

- 领域层：100%
- 应用层：80%
- 基础设施层：60%

### 7.2 测试命名

```rust
#[cfg(test)]
mod tests {
    #[test]
    fn test_priority_serializes_to_screaming_snake_case() {
        // 测试名称清晰描述测试内容
    }
    
    #[test]
    fn should_return_error_when_priority_is_invalid() {
        // 使用should_when模式
    }
}
```

---

## 8. 代码组织规范

### 8.1 模块结构

```
src/
├── domain/              # 领域层（纯业务逻辑）
│   ├── aggregates/      # 聚合根
│   ├── value_objects/   # 值对象
│   ├── services/        # 领域服务
│   └── constants.rs     # 领域常量
├── application/         # 应用层
│   ├── services/        # 应用服务
│   └── dtos/           # 数据传输对象
├── infrastructure/      # 基础设施层
│   ├── repositories/    # 仓储实现
│   ├── entities/        # ORM实体（SeaORM生成）
│   └── ...
└── presentation/        # 表示层
```

### 8.2 导入顺序

```rust
// 1. 标准库
use std::collections::HashMap;

// 2. 外部crate
use serde::{Deserialize, Serialize};
use uuid::Uuid;

// 3. 本地模块
use crate::domain::value_objects::Money;
```

---

## 9. 性能规范

### 9.1 避免不必要的克隆

❌ **避免**：
```rust
fn process(data: Vec<String>) {  // 获取所有权
    // ...
}
```

✅ **推荐**：
```rust
fn process(data: &[String]) {  // 借用
    // ...
}
```

### 9.2 使用Cow避免克隆

```rust
use std::borrow::Cow;

fn process(data: Cow<str>) -> String {
    if needs_modification {
        data.into_owned() + " modified"
    } else {
        data.into_owned()
    }
}
```

---

## 10. 文档规范

### 10.1 公共API必须有文档

```rust
/// Creates a new reminder with the specified priority.
///
/// # Arguments
///
/// * `title` - The reminder title
/// * `priority` - The priority level
///
/// # Returns
///
/// Returns `Ok(Reminder)` on success, or `ReminderError` on failure.
///
/// # Examples
///
/// ```
/// let reminder = Reminder::new("Pay bills", Priority::High)?;
/// ```
pub fn new(title: String, priority: Priority) -> Result<Self, ReminderError> {
    // ...
}
```

---

## 11. 校验清单

在提交代码前，必须通过以下检查：

```bash
# 1. 编译检查
cargo check

# 2. Clippy检查（无警告）
cargo clippy -- -D warnings

# 3. 格式化检查
cargo fmt -- --check

# 4. 测试
cargo test

# 5. 文档生成
cargo doc --no-deps
```

---

## 12. 违规示例和修复

### 示例1：硬编码字段名

**违规代码**：
```rust
sqlx::query!("SELECT id, title FROM reminders")
```

**修复**：
```rust
Reminders::find().all(&db).await?
```

### 示例2：硬编码字符串

**违规代码**：
```rust
if status == "SUCCESS" { }
```

**修复**：
```rust
if status == Status::Success { }
```

### 示例3：无日志上下文

**违规代码**：
```rust
println!("Error: {}", e);
```

**修复**：
```rust
error!(error = %e, "Failed to process reminder");
```

---

## 附录：自动化工具配置

### Clippy配置（clippy.toml）

```toml
# 禁止硬编码字符串比较
disallowed-methods = [
    { path = "std::string::String::as_str", reason = "use enum instead" },
]

# 要求文档
missing-docs = "warn"
```

### Rustfmt配置（rustfmt.toml）

```toml
edition = "2021"
max_width = 100
use_field_init_shorthand = true
```

---

**文档结束**
