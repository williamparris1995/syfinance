# 账户模块重构与优化设计文档

**日期:** 2026-06-04  
**状态:** 已批准  
**作者:** Claude Code (brainstorming skill)  
**范围:** 数据结构修正、Category 引入、ChartOfAccounts、UI/UX 优化

---

## 1. 背景与目标

### 1.1 当前问题

经过全面分析，当前账户模块存在以下问题：

1. **Income/Expense 与资产账户在 UI 层面混淆**：用户创建账户时，Income/Expense 和 Cash/Bank 混在一起，导致用户创建"收入账户"后不理解为什么有余额字段
2. **缺少独立的 Category（分类）概念**：交易记录只能通过账户类型区分收入/支出，无法按用途（餐饮、交通、工资）统计
3. **parent_id 未完整实现**：数据库有字段，但 UI 和 Service 未实现层级展示
4. **缺少账户状态管理**：无法归档不常用账户
5. **报表展示不清晰**：未区分资产负债表（资产/负债/权益）和损益表（收入/费用）

### 1.2 设计目标

1. **保留复式记账原则**：后端保持严格的复式记账，AccountType 保留完整的五类账户
2. **引入 Category 标签层**：给交易打标签，用于统计和预算，不替代复式记账
3. **完善账户层级**：实现 parent_id 的完整功能
4. **优化用户界面**：区分"资产账户"和"损益科目"的创建流程
5. **引入 ChartOfAccounts**：支持会计准则模板

### 1.3 行业参考

- **GnuCash**：后端严格复式记账，完整的五类账户 + 无限层级
- **Firefly III**：前端友好的账户分类 + 独立的 Category 标签
- **钱迹**：极简的账户 + 分类设计，适合大众用户

**借鉴策略：后端保持 GnuCash 严格性，前端借鉴 Firefly III + 钱迹易用性。**

---

## 2. 领域模型设计

### 2.1 AccountType（保持不变）

```rust
// src-tauri/src/domain/aggregates/account.rs
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum AccountType {
    // 资产类
    Cash,        // 现金
    Bank,        // 银行存款
    CreditCard,  // 信用卡
    Investment,  // 投资
    BorrowedOut, // 借出款
    BorrowedIn,  // 借入款
    Prepaid,     // 储值卡
    Other,       // 其他
    // 损益类
    Income,      // 收入
    Expense,     // 费用
}
```

**关键决策：保留 Income/Expense。** 在复式记账中，收入/费用是合法的账户类型。问题在 UI 层面，不在数据结构。

### 2.2 新增 Category 领域模型

```rust
// src-tauri/src/domain/aggregates/category.rs
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum CategoryType {
    Income,  // 收入分类
    Expense, // 支出分类
}

#[derive(Debug, Clone)]
pub struct Category {
    pub id: Uuid,
    pub name: String,
    pub category_type: CategoryType,
    pub icon: String,
    pub color: String,
    pub parent_id: Option<Uuid>,    // 支持层级：餐饮 > 工作餐
    pub is_system: bool,            // true = 预设不可删除
    pub sort_order: i32,
    pub sync_metadata: SyncMetadata,
}
```

**设计原则：**
- Category 是**标签层**，不替代复式记账的分录
- 与 Transaction 关联，不直接修改账户余额
- 支持系统预设 + 用户自定义
- 支持层级结构（parent_id）

### 2.3 新增 ChartOfAccounts 领域模型

```rust
// src-tauri/src/domain/aggregates/chart_of_accounts.rs
#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum AccountingStandard {
    ChinaCAS,      // 中国企业会计准则
    International, // IFRS
    USGAAP,        // 美国GAAP
    Custom,        // 完全自定义
}

#[derive(Debug, Clone)]
pub struct ChartOfAccountsEntry {
    pub id: Uuid,
    pub standard: AccountingStandard,
    pub code: String,              // "1002" 或 "Assets.CurrentAssets.Cash"
    pub name: String,              // "银行存款"
    pub name_en: String,           // "Bank Deposits"
    pub account_type: AccountType, // 关联的账户类型
    pub parent_id: Option<Uuid>,
    pub level: u8,                 // 层级 1-4
    pub is_active: bool,
}
```

### 2.4 Account 模型扩展

```rust
// 新增字段
pub struct Account {
    // ... 现有字段 ...
    pub status: AccountStatus,           // 新增
    pub opened_at: Option<DateTime<Utc>>, // 新增
}

#[derive(Debug, Clone, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum AccountStatus {
    Active,    // 正常
    Archived,  // 归档（不常用但保留历史）
    Hidden,    // 隐藏（不显示在列表中）
}
```

### 2.5 Transaction 模型关联 Category

```rust
// src-tauri/src/domain/aggregates/transaction.rs
pub struct Transaction {
    pub id: Uuid,
    pub description: String,
    pub entries: Vec<TransactionEntry>,  // 复式记账分录（必须）
    pub category_id: Option<Uuid>,       // 新增：关联 Category（可选）
    pub tags: Vec<Tag>,
}
```

---

## 3. 数据流设计

### 3.1 创建账户流程

```
用户操作：创建"招商银行"账户

步骤 1：选择账户大类
├─ □ 资产/负债账户（装钱的盒子）
└─ □ 收入/费用科目（记账用）

步骤 2：选择账户类型
├─ □ 现金    □ 银行存款    □ 信用卡
├─ □ 投资    □ 借出款      □ 借入款
├─ □ 储值卡  □ 其他
└─ □ 收入    □ 费用        ← 仅在选"损益科目"时显示

步骤 3：填写详细信息
├─ 名称：招商银行
├─ 余额：5000
├─ 货币：CNY
├─ 图标：🏦
├─ 颜色：#3B82F6
├─ 科目：1002 银行存款      ← 关联 ChartOfAccounts
└─ 开户日：2024-01-01      ← 新增 opened_at

步骤 4：保存
└─ 创建 Account 记录
```

### 3.2 记录交易流程

```
用户操作：记录工资收入 5000 元

步骤 1：填写交易信息
├─ 描述：6月工资
├─ 日期：2026-06-01

步骤 2：填写分录（复式记账）
├─ 借：银行存款      5000   ← 资产账户（余额 +5000）
└─ 贷：工资收入      5000   ← 收入账户（累计 +5000）

步骤 3：选择 Category（可选，用于统计）
└─ 分类：▼ 收入 > 工资收入

步骤 4：系统处理
├─ 验证：借方 5000 = 贷方 5000 ✓
├─ 更新账户余额：
│   ├─ 银行存款余额：+5000
│   └─ 工资收入累计：+5000
├─ 记录 Category 关联：工资收入 +5000
└─ 保存 Transaction
```

### 3.3 余额计算逻辑

```rust
// 资产/负债账户：计算当前余额
// 收入/费用账户：计算累计发生额（指定期间内）

pub enum AccountBalanceDisplay {
    Balance(Money),           // 资产/负债：当前余额
    Cumulative(Money),        // 收入/费用：累计发生额
    Zero,                     // 未启用的账户
}

impl Account {
    pub fn get_display_balance(&self, period: Option<DateRange>) -> AccountBalanceDisplay {
        match self.account_type {
            AccountType::Cash | AccountType::Bank | AccountType::CreditCard 
            | AccountType::Investment | AccountType::BorrowedOut | AccountType::BorrowedIn 
            | AccountType::Prepaid | AccountType::Other => {
                AccountBalanceDisplay::Balance(self.calculate_current_balance())
            }
            AccountType::Income | AccountType::Expense => {
                let cumulative = self.calculate_cumulative_amount(period);
                AccountBalanceDisplay::Cumulative(cumulative)
            }
        }
    }
}
```

---

## 4. 数据库设计

### 4.1 新增 categories 表

```sql
CREATE TABLE categories (
    id BLOB PRIMARY KEY,
    name TEXT NOT NULL,
    category_type TEXT CHECK(category_type IN ('income', 'expense')) NOT NULL,
    icon TEXT DEFAULT '💰',
    color TEXT DEFAULT '#10B981',
    parent_id BLOB REFERENCES categories(id),
    is_system BOOLEAN DEFAULT FALSE,
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP,
    device_id TEXT,
    sync_vector INTEGER DEFAULT 0
);
```

### 4.2 新增 chart_of_accounts 表

```sql
CREATE TABLE chart_of_accounts (
    id BLOB PRIMARY KEY,
    standard TEXT CHECK(standard IN ('china_cas', 'international', 'us_gaap', 'custom')) NOT NULL,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    name_en TEXT,
    account_type TEXT NOT NULL,
    parent_id BLOB REFERENCES chart_of_accounts(id),
    level INTEGER CHECK(level BETWEEN 1 AND 4),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### 4.3 修改 accounts 表

```sql
-- 新增字段
ALTER TABLE accounts ADD COLUMN status TEXT DEFAULT 'active' 
    CHECK(status IN ('active', 'archived', 'hidden'));
ALTER TABLE accounts ADD COLUMN opened_at TIMESTAMP;
```

### 4.4 修改 transactions 表

```sql
-- 新增字段
ALTER TABLE transactions ADD COLUMN category_id BLOB REFERENCES categories(id);
```

---

## 5. API 设计

### 5.1 后端 Tauri 命令

```rust
// Category 管理
#[tauri::command]
async fn list_categories(
    category_type: Option<String>,
    include_deleted: bool,
) -> Result<Vec<CategoryDto>, Error>;

#[tauri::command]
async fn create_category(dto: CreateCategoryDto) -> Result<CategoryDto, Error>;

#[tauri::command]
async fn update_category(id: String, dto: UpdateCategoryDto) -> Result<CategoryDto, Error>;

#[tauri::command]
async fn delete_category(id: String) -> Result<(), Error>;

// ChartOfAccounts
#[tauri::command]
async fn list_chart_of_accounts(
    standard: Option<String>,
    account_type: Option<String>,
) -> Result<Vec<ChartOfAccountsEntryDto>, Error>;

#[tauri::command]
async fn get_accounting_standards() -> Result<Vec<String>, Error>;

// 修改后的账户命令
#[tauri::command]
async fn create_account(dto: CreateAccountDto) -> Result<AccountDto, Error>;
// CreateAccountDto 保持不变，仍支持所有 AccountType
// 前端通过向导界面引导用户区分"资产账户"和"损益科目"的创建流程

#[tauri::command]
async fn update_account_status(
    id: String, 
    status: AccountStatusDto,
) -> Result<AccountDto, Error>;
```

### 5.2 前端 API 封装

```typescript
// src/lib/tauri/category.ts
export interface CategoryDto {
  id: string;
  name: string;
  categoryType: 'income' | 'expense';
  icon: string;
  color: string;
  parentId: string | null;
  isSystem: boolean;
  sortOrder: number;
}

export const listCategories = (type?: 'income' | 'expense') => 
  invokeTauri<CategoryDto[]>('list_categories', { categoryType: type });

export const createCategory = (dto: CreateCategoryDto) => 
  invokeTauri<CategoryDto>('create_category', { dto });

// src/lib/tauri/chartOfAccounts.ts
export interface ChartOfAccountsEntryDto {
  id: string;
  standard: string;
  code: string;
  name: string;
  nameEn: string;
  accountType: string;
  level: number;
}

export const listChartOfAccounts = (standard?: string, accountType?: string) => 
  invokeTauri<ChartOfAccountsEntryDto[]>('list_chart_of_accounts', { standard, accountType });
```

---

## 6. UI/UX 设计

### 6.1 创建账户向导

```
创建账户（分步向导）

步骤 1/3：选择账户性质
┌─────────────────────────────────────┐
│ 你想创建什么类型的账户？              │
│                                      │
│  ┌──────────────┐  ┌──────────────┐ │
│  │  💰          │  │  📊          │ │
│  │  资产/负债    │  │  收入/费用    │ │
│  │  账户        │  │  科目        │ │
│  │              │  │              │ │
│  │  装钱的盒子   │  │  记账用的分类 │ │
│  └──────────────┘  └──────────────┘ │
│                                      │
│  提示：资产账户有余额，损益科目记录   │
│        累计发生额                    │
└─────────────────────────────────────┘

步骤 2/3：选择具体类型
（根据步骤 1 的选择显示不同选项）

步骤 3/3：填写详细信息
（动态表单：资产账户显示余额/货币，损益科目不显示余额）
```

### 6.2 账户列表页优化

```
账户列表页
┌─────────────────────────────────────┐
│ 我的账户                    [+]     │
├─────────────────────────────────────┤
│ 📊 净资产：¥ 125,000               │
├─────────────────────────────────────┤
│ 💰 资产账户（5个）                  │
│                                      │
│ 招商银行          ¥ 50,000    [📈] │
│ 工商银行          ¥ 30,000    [📈] │
│ 现金钱包          ¥ 5,000     [📈] │
│ 股票账户          ¥ 40,000    [📈] │
│ 支付宝            ¥ 10,000    [📈] │
├─────────────────────────────────────┤
│ 💳 负债账户（2个）                  │
│                                      │
│ 招行信用卡        -¥ 5,000    [📉] │
│ 房贷              -¥ 15,000   [📉] │
├─────────────────────────────────────┤
│ 📈 收入科目（本月累计）              │
│                                      │
│ 工资收入          +¥ 15,000        │
│ 投资收益          +¥ 2,000         │
├─────────────────────────────────────┤
│ 📉 费用科目（本月累计）              │
│                                      │
│ 餐饮费用          -¥ 3,500         │
│ 交通费用          -¥ 1,200         │
└─────────────────────────────────────┘
```

### 6.3 交易表单优化

```
记录交易
┌─────────────────────────────────────┐
│ 描述：6月工资                        │
│ 日期：2026-06-01                     │
├─────────────────────────────────────┤
│ 分录                                 │
│ 借：银行存款        5000             │
│ 贷：工资收入        5000             │
│ 状态：✓ 已平衡                      │
├─────────────────────────────────────┤
│ 分类：▼ 收入 > 工资收入              │
├─────────────────────────────────────┤
│ 标签：#每月固定                      │
└─────────────────────────────────────┘
```

### 6.4 Category 管理页面

```
分类管理
┌─────────────────────────────────────┐
│ 收入分类              [+ 新增]      │
├─────────────────────────────────────┤
│ 💰 工资收入（系统）       [编辑]     │
│ 📈 投资收益（系统）       [编辑]     │
│ 💼 兼职收入（系统）       [编辑]     │
│ 🐱 宠物寄养（自定义）     [编辑] [🗑]│
├─────────────────────────────────────┤
│ 支出分类              [+ 新增]      │
├─────────────────────────────────────┤
│ 🍔 餐饮（系统）           [编辑]     │
│   ├─ 工作餐（系统）                  │
│   └─ 聚餐（系统）                    │
│ 🚗 交通（系统）           [编辑]     │
│ 🎮 游戏充值（自定义）     [编辑] [🗑]│
└─────────────────────────────────────┘
```

---

## 7. 数据库迁移策略

### 7.1 迁移步骤

```sql
-- Step 1：创建新表
CREATE TABLE categories (...);
CREATE TABLE chart_of_accounts (...);

-- Step 2：修改 accounts 表
ALTER TABLE accounts ADD COLUMN status TEXT DEFAULT 'active';
ALTER TABLE accounts ADD COLUMN opened_at TIMESTAMP;

-- Step 3：修改 transactions 表
ALTER TABLE transactions ADD COLUMN category_id BLOB REFERENCES categories(id);

-- Step 4：插入预设 Category 数据
INSERT INTO categories (id, name, category_type, icon, color, is_system, sort_order) VALUES
    (randomblob(16), '工资收入', 'income', '💰', '#10B981', TRUE, 1),
    (randomblob(16), '投资收益', 'income', '📈', '#3B82F6', TRUE, 2),
    (randomblob(16), '餐饮', 'expense', '🍔', '#F59E0B', TRUE, 1),
    (randomblob(16), '交通', 'expense', '🚗', '#06B6D4', TRUE, 2);

-- Step 5：插入预设 ChartOfAccounts 数据（中国准则）
INSERT INTO chart_of_accounts (id, standard, code, name, name_en, account_type, level) VALUES
    (randomblob(16), 'china_cas', '1001', '库存现金', 'Cash on Hand', 'Cash', 1),
    (randomblob(16), 'china_cas', '1002', '银行存款', 'Bank Deposits', 'Bank', 1),
    (randomblob(16), 'china_cas', '100201', '活期存款', 'Demand Deposits', 'Bank', 2),
    (randomblob(16), 'china_cas', '1101', '交易性金融资产', 'Trading Financial Assets', 'Investment', 1);

-- Step 6：迁移现有数据（应用层处理）
-- 将 Income/Expense 账户的交易关联到新创建的 Category
-- 然后软删除 Income/Expense 账户（保留历史数据）
```

### 7.2 应用层迁移脚本

```rust
async fn migrate_data(pool: &SqlitePool) -> Result<(), Error> {
    // 1. 备份数据
    backup_database(pool).await?;
    
    // 2. 在事务中执行迁移
    let mut tx = pool.begin().await?;
    
    // 3. 为每个 Income 账户创建 Category
    let income_categories = migrate_income_accounts(&mut tx).await?;
    
    // 4. 为每个 Expense 账户创建 Category
    let expense_categories = migrate_expense_accounts(&mut tx).await?;
    
    // 5. 更新交易记录
    migrate_transaction_categories(&mut tx, &income_categories, &expense_categories).await?;
    
    // 6. 软删除旧账户
    soft_delete_income_expense_accounts(&mut tx).await?;
    
    // 7. 验证数据完整性
    verify_migration(&mut tx).await?;
    
    tx.commit().await?;
    Ok(())
}
```

---

## 8. i18n 设计

### 8.1 新增翻译键

```json
// zh.json
{
  "account": {
    "createWizard": {
      "title": "创建账户",
      "step1Title": "选择账户性质",
      "assetAccount": "资产/负债账户",
      "assetAccountDesc": "装钱的盒子，如银行卡、现金、投资",
      "incomeExpenseAccount": "收入/费用科目",
      "incomeExpenseAccountDesc": "记账用的分类，如工资、餐饮",
      "step2Title": "选择账户类型",
      "step3Title": "填写详细信息"
    },
    "status": {
      "active": "正常",
      "archived": "归档",
      "hidden": "隐藏"
    },
    "balanceDisplay": {
      "balance": "余额",
      "cumulative": "累计",
      "thisMonth": "本月",
      "thisYear": "本年"
    }
  },
  "category": {
    "title": "分类管理",
    "incomeCategories": "收入分类",
    "expenseCategories": "支出分类",
    "system": "系统预设",
    "custom": "自定义",
    "addCategory": "新增分类",
    "editCategory": "编辑分类",
    "deleteCategory": "删除分类",
    "deleteConfirm": "确定要删除此分类吗？相关交易记录将保留，但不再关联此分类。"
  },
  "chartOfAccounts": {
    "title": "会计科目",
    "standard": "会计准则",
    "chinaCAS": "中国企业会计准则",
    "international": "国际财务报告准则",
    "usGAAP": "美国公认会计原则",
    "custom": "自定义",
    "code": "科目代码",
    "name": "科目名称"
  }
}
```

---

## 9. 测试策略

### 9.1 后端测试

- [ ] Category CRUD 测试
- [ ] ChartOfAccounts 查询测试
- [ ] 交易关联 Category 测试
- [ ] 账户状态变更测试
- [ ] 数据迁移脚本测试
- [ ] 余额计算逻辑测试（资产 vs 损益账户）

### 9.2 前端测试

- [ ] 创建账户向导测试
- [ ] Category 管理页面测试
- [ ] 交易表单 Category 选择测试
- [ ] 账户列表分类展示测试

---

## 10. 未来扩展

| 功能 | 说明 | 优先级 |
|------|------|--------|
| 预算与 Category 关联 | 按分类设置月度预算 | P2 |
| 多币种账户 | 账户可设置不同货币 | P2 |
| 报表导出 | 导出资产负债表、损益表 | P2 |
| 智能分类 | 根据交易描述自动匹配 Category | P3 |

---

## 11. 附录：与当前代码的对比

| 方面 | 当前实现 | 新设计 |
|------|----------|--------|
| AccountType | 包含 Income/Expense | 保持不变 |
| Category | ❌ 无 | ✅ 独立领域模型 |
| ChartOfAccounts | ⚠️ 只有字段 | ✅ 完整模型 + 模板 |
| AccountStatus | ❌ 无 | ✅ Active/Archived/Hidden |
| parent_id | ⚠️ 未实现 | ✅ 完整层级支持 |
| opened_at | ❌ 无 | ✅ 新增 |
| 交易关联 | 仅 entries | entries + category_id |
| UI 创建流程 | 单表单 | 分步向导 |
| 余额显示 | 统一显示 | 资产显示余额，损益显示累计 |
