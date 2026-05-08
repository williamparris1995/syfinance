# 架构分析报告

## 问题诊断

### 当前架构的根本问题

**问题1：Account vs Chart of Accounts 混淆**
- ❌ 当前：Account（账户）绑定了 chart_of_account_code
- ✅ 应该：TransactionEntry 绑定 chart_of_account_code
- **Account 应该是用户的实际账户**（银行卡、现金、信用卡）
- **Chart of Accounts 是会计科目**（资产、负债、收入、支出）

**问题2：TransactionEntry 已经有 chart_of_account_code**
- 看 `src-tauri/src/domain/value_objects/transaction_entry.rs:30`
- `pub chart_of_account_code: String`
- **这是正确的设计！**
- 但 Account 也有，导致混乱

**问题3：Dashboard 永远是 0 的问题**
- 当前所有 Account 都是用户账户
- 转账：用户账户A → 用户账户B
- 总资产 = A + B，转账前后不变
- **缺少收入/支出科目账户**

**问题4：缺少账户凭证信息**
- 银行卡号
- 信用卡号
- 账户备注

---

## 权威来源分析

### 1. GnuCash（最成熟的开源会计软件）

**核心设计**：
- **Account（账户）**：用户的实际账户（银行、现金、信用卡）
- **Chart of Accounts（会计科目表）**：会计分类体系（资产、负债、收入、支出）
- **Transaction（交易）**：包含多个 Entry
- **Entry（分录）**：每个 Entry 关联一个 Account + 一个 Chart of Account Code

**关键发现**：
```
Account ≠ Chart of Accounts
- Account: "招商银行储蓄卡"（用户的实际账户）
- Chart of Account: "1002 银行存款"（会计科目分类）
- Transaction Entry: 同时引用 Account + Chart Code
```

### 2. Double-Entry Ledger（复式记账标准实现）

**核心原则**：
```rust
// ✅ 正确的设计
pub struct Account {
    pub id: Uuid,
    pub name: String,              // "招商银行卡"
    pub account_type: AccountType, // Bank, Cash, CreditCard
    pub account_number: String,    // 银行卡号
    pub balance: Money,
    // ❌ 不应该有 chart_of_account_code
}

pub struct TransactionEntry {
    pub account_id: Uuid,          // 用户账户
    pub chart_of_account_code: String, // 会计科目（1002, 5401等）
    pub debit_amount: Option<Money>,
    pub credit_amount: Option<Money>,
}
```

**关键规则**：
1. Account 是用户的"钱包"（银行卡、现金、信用卡）
2. Chart of Accounts 是会计分类（收入、支出、资产、负债）
3. TransactionEntry 同时引用两者

---

## 三个方案对比

### 方案1：完全符合会计准则（GnuCash 模式）

**优点**：
- 符合国际会计准则
- 支持复杂的财务报表
- 适合企业级使用

**缺点**：
- 用户学习成本高
- 需要理解会计科目
- 重构工作量大（2-3天）

**数据模型**：
```rust
Account {
    id, name, account_type, account_number, balance
    // 移除 chart_of_account_code
}

TransactionEntry {
    account_id,              // 用户账户（可选，虚拟科目为null）
    chart_of_account_code,   // 会计科目（必填）
    debit/credit
}
```

**示例：午餐16元**
```
Entry 1: account_id=招商银行, chart_code=1002(银行存款), credit=16
Entry 2: account_id=null, chart_code=5401(餐饮费用), debit=16
```

---

### 方案2：混合模式（推荐）⭐

**优点**：
- 用户友好（不需要理解会计科目）
- 保留会计准则的核心（复式记账）
- 重构工作量中等（1-2天）

**缺点**：
- 不完全符合会计准则
- 报表功能受限

**数据模型**：
```rust
Account {
    id, name, account_type, account_number, balance
    default_chart_code  // 默认科目代码（可选）
}

Category {
    id, name, type(income/expense), chart_code
}

TransactionEntry {
    account_id,        // 用户账户（必填）
    category_id,       // 分类（可选）
    chart_code,        // 自动从Category或Account推导
    debit/credit
}
```

**示例：午餐16元**
```
Entry 1: account_id=招商银行, category=null, debit=16
Entry 2: account_id=null(虚拟), category=餐饮, credit=16
```

---

### 方案3：简化模式（最快实现）

**优点**：
- 用户最友好
- 重构工作量最小（半天）
- 适合个人用户

**缺点**：
- 不符合会计准则
- 无法生成专业财务报表

**数据模型**：
```rust
Account {
    id, name, account_type, balance
    // 完全移除 chart_of_account_code
}

Transaction {
    from_account_id,
    to_account_id,
    amount,
    category  // 简单的字符串分类
}
```

---

## 方案对比表

| 特性 | 方案1（专业） | 方案2（混合）⭐ | 方案3（简化） |
|------|------------|--------------|------------|
| 符合会计准则 | ✅ 完全符合 | ⚠️ 部分符合 | ❌ 不符合 |
| 用户友好度 | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| 重构工作量 | 2-3天 | 1-2天 | 0.5天 |
| Dashboard准确性 | ✅ 准确 | ✅ 准确 | ✅ 准确 |
| 专业报表 | ✅ 支持 | ⚠️ 基础支持 | ❌ 不支持 |
| 学习成本 | 高 | 中 | 低 |

---

## 最终决策

**选择：方案2（混合模式）**

**理由**：
1. 平衡了专业性和易用性
2. Dashboard 能正确显示收支
3. 用户不需要理解会计科目
4. 保留了扩展到专业模式的可能性

**目标用户**：个人用户

**重点功能**：
- 贷款管理
- 信用卡消费还款提醒
- 个税计算
- 收入支出分析
- 股票期权投资
- 自动化和AI集成
