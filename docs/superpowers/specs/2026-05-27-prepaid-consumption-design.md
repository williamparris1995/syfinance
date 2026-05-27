# 储值消费功能设计文档

**日期**: 2026-05-27
**状态**: 已确认
**范围**: 储值充值+消费（周期性消费后续独立设计）

## 概述

在现有双记账系统中支持"先充值、后消费"的储值账户。适用于健身卡、预付费卡、平台余额、API Token、话费等场景。采用账户扩展模式（方案A），对齐 `debt_details` 的设计模式。

## 1. 数据模型

### 1.1 accounts 表变更

在 `account_type` 枚举中新增 `prepaid` 类型：

```
现有: cash | bank | credit_card | investment | loan | borrowed_out | borrowed_in | other | income | expense
新增: prepaid（储值账户）
```

储值账户的 `ownership` 为 `'own'`，`chart_code` 映射到新增的 1123 预付账款科目。

`accounts` 表新增字段：
- `low_balance_threshold` DECIMAL(20,2) NULL — 每个储值账户独立设置低余额预警阈值

### 1.2 top_up_records 扩展表

1:1 关联充值交易，记录充值明细。对齐 `debt_details` 的扩展模式。

```
top_up_records
├── id                  TEXT PK
├── account_id          TEXT FK → accounts.id       -- 储值账户
├── transaction_id      TEXT FK → transactions.id   -- 关联的充值交易
├── paid_amount         DECIMAL(20,2)               -- 实际支付金额
├── bonus_amount        DECIMAL(20,2) DEFAULT 0     -- 赠送金额
├── total_credited      DECIMAL(20,2)               -- 实际入账 = paid + bonus
├── top_up_date         DATE                        -- 充值日期
├── expiry_date         DATE NULL                   -- 有效期（可选）
├── source_account_id   TEXT FK → accounts.id       -- 付款来源账户
├── description         TEXT                        -- 备注
├── created_at          DATETIME
└── updated_at          DATETIME
```

### 1.3 chart_of_accounts 新增科目

遵循 CAS（中国企业会计准则）编码规范：

```
1123  预付账款            L2  资产  借方  (parent: 1000)
112301  储值卡            L3  资产  借方  (parent: 1123)
112302  平台余额          L3  资产  借方  (parent: 1123)
112303  话费              L3  资产  借方  (parent: 1123)

4901  其他收入（已有）     L2  收入  贷方
490101  赠送/优惠收入      L3  收入  贷方  (parent: 4901)
```

## 2. 交易流程（双记账）

### 2.1 普通充值（充1000，无赠送）

一笔交易，两条分录：

| 账户 | 科目 | 借方 | 贷方 |
|------|------|------|------|
| 健身卡 (prepaid) | 1123 预付账款 | 1000 | |
| 招商银行 (bank) | 1002 银行存款 | | 1000 |

同时创建 `top_up_record`: paid=1000, bonus=0, total=1000

### 2.2 充值送优惠（充1000送200）

一笔交易，三条分录：

| 账户 | 科目 | 借方 | 贷方 |
|------|------|------|------|
| 健身卡 (prepaid) | 1123 预付账款 | 1200 | |
| 招商银行 (bank) | 1002 银行存款 | | 1000 |
| 赠送收入 (income) | 4901 其他收入 | | 200 |

`top_up_record`: paid=1000, bonus=200, total=1200

赠送金额作为"其他收入"即时确认（做法A），符合 CAS 确实收到的额外价值原则。IFRS 15 的消费时分摊方式对个人理财过于复杂，不采用。

### 2.3 储值消费（健身卡消费50）

一笔交易，两条分录，复用现有 `create_simple_expense`：

| 账户 | 科目 | 借方 | 贷方 |
|------|------|------|------|
| 健身运动 (expense) | 5404 娱乐费用 | 50 | |
| 健身卡 (prepaid) | 1123 预付账款 | | 50 |

余额自动通过 `compute_balances_for_all_accounts` 计算，无需额外逻辑。

### 2.4 超额校验

在 `create_simple_expense` 中新增校验：当付款账户类型为 `prepaid` 时，查询当前余额。若余额 < 消费金额，拒绝交易并返回错误提示。

### 2.5 低余额预警

复用现有 `reminders` 表，新增 `reminder_type: "prepaid_low_balance"`。

触发时机：每次储值消费成功后，检查余额是否低于该账户的 `low_balance_threshold`。若低于阈值且该账户不存在未完成的 `prepaid_low_balance` 提醒，则创建新提醒（避免重复创建）。

每个储值账户的阈值通过 `accounts.low_balance_threshold` 字段独立设置（类似信用卡的 `credit_limit`）。

## 3. 后端架构

### 3.1 文件变更清单

遵循现有 DDD 分层结构：

```
domain/
├── aggregates/
│   └── account.rs              ← 修改: AccountType 新增 Prepaid
├── value_objects/
│   └── top_up_record.rs        ← 新增: 充值记录值对象

application/
├── dtos/
│   └── prepaid_dto.rs          ← 新增: TopUpRequest / TopUpResponse DTO
├── services/
│   ├── prepaid_service.rs      ← 新增: 充值/余额校验/低余额预警
│   └── transaction_service.rs  ← 修改: 消费时校验 prepaid 余额

infrastructure/
├── repositories/
│   └── prepaid_repository.rs   ← 新增: top_up_records CRUD

presentation/
├── tauri_commands/
│   └── prepaid_commands.rs     ← 新增: Tauri 命令入口

migrations/
└── 20260527000001_add_prepaid_support.sql  ← 新增
```

### 3.2 PrepaidService 核心方法

```rust
impl PrepaidService {
    // 充值：创建交易 + top_up_record
    async fn top_up(
        account_id, source_account_id,
        paid_amount, bonus_amount,
        expiry_date, description
    ) -> Result<(Transaction, TopUpRecord)>

    // 检查余额是否充足
    async fn check_balance_sufficient(account_id, amount) -> Result<bool>

    // 检查并创建低余额提醒
    async fn check_low_balance_alert(account_id) -> Result<Option<Reminder>>

    // 获取充值记录列表
    async fn get_top_up_records(account_id) -> Result<Vec<TopUpRecord>>

    // 获取储值账户明细
    async fn get_prepaid_detail(account_id) -> Result<PrepaidDetail>
}
```

### 3.3 transaction_service 修改点

在 `create_simple_expense` 中新增 prepaid 分支：

```rust
// 消费前：超额校验
if source_account.account_type == AccountType::Prepaid {
    let balance = compute_balance(source_account.id)?;
    if balance < amount {
        return Err("储值余额不足");
    }
}

// 消费后：低余额预警检查
if source_account.account_type == AccountType::Prepaid {
    prepaid_service.check_low_balance_alert(source_account.id).await?;
}
```

## 4. 前端 UI

### 4.1 变更总览

**修改现有组件：**
- `AccountForm` — 新增 prepaid 类型选项 + `low_balance_threshold` 字段
- `SimpleTransactionForm` — 支出类型中付款账户可选中 prepaid 账户
- `AccountsPage` — 储值账户显示余额和低余额警告色

**新增组件：**
- `TopUpDialog` — 充值对话框（付款账户、充值金额、赠送金额、有效期、备注）
- `PrepaidDetailPanel` — 储值明细面板（余额概览 + 充值记录 + 消费记录）

**不新增独立页面。** 储值功能融入现有账户和交易流程，保持 UI 简洁。

### 4.2 账户列表中的储值卡片

每个储值账户显示：
- 图标 + 名称 + 科目编码
- 当前余额（正常绿色，低于阈值红色）
- 低余额阈值
- "充值"按钮 → 打开 TopUpDialog
- "明细"按钮 → 打开 PrepaidDetailPanel

### 4.3 充值对话框 (TopUpDialog)

表单字段：
- 付款账户（下拉选择，显示余额）
- 充值金额（必填）
- 赠送金额（可选，默认0）
- 有效期（可选，日期选择器）
- 备注（可选）

底部预览：实际入账 = 充值金额 + 赠送金额

### 4.4 储值明细面板 (PrepaidDetailPanel)

顶部三个指标卡：当前余额、累计充值、累计消费
下方 Tab 切换：充值记录 / 消费记录

充值记录每条显示：描述、日期、来源账户、入账金额、实付/赠送明细、有效期

### 4.5 报表集成

**月度支出报表**：储值消费按消费类别正常计入（无需改动报表逻辑），来源列标注"XX(储值)"。

**新增储值账户汇总表**：在 ReportsPage 新增一个 Tab 或折叠面板，按储值账户展示当前余额、本月消费、本月充值、状态（正常/低余额）。

## 5. 数据库迁移

单次迁移包含：
1. `accounts` 表新增 `low_balance_threshold DECIMAL(20,2) NULL` 列
2. 创建 `top_up_records` 表（含外键约束）
3. `chart_of_accounts` 新增 1123 及其 L3 子科目、490101 赠送收入科目
4. `reminders` 的 `reminder_type` CHECK 约束（如有）需新增 `prepaid_low_balance`
