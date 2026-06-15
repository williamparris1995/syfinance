# 御财账户 Category（用户面向分类）设计

**日期**: 2026-06-15
**状态**: 已确认
**范围**: 账户模块新增 `category` 字段（用户面向分类），全栈（Go 服务端 + Flutter 客户端）

---

## 背景

御财账户模块的"分类"设计经历过两次变迁：

1. **旧 syfinance（Tauri/Rust）**：`AccountType` 直接是用户面向分类（`Cash/Bank/CreditCard/Investment/Loan/Other`），见 [2026-05-22-unified-account-model-design](./2026-05-22-unified-account-model-design.md)。
2. **yucai Go 迁移**：`AccountType` 改为会计 5 类型（`asset/liability/equity/income/expense`）—— 复式记账基础，但**丢失了用户面向分类**。
3. **现有 category 模块**（[Plan 08](../plans/2026-06-13-plan-08-category-currency.md)）：是**交易收支分类**（`income/expense`，用于 transactions/budgets），与账户无关。

原型 `screens/desktop-form-account.html` 要求账户有用户面向分类（储蓄/信用卡/投资/定期/黄金外汇/固定资产/贷款）。当前 domain 仅有会计 `AccountType`，表单 TypeTabs 只能显示会计 5 类型，与原型不一致，用户难以理解（"资产/负债/权益"对个人用户太抽象）。

### 行业调研结论
顶尖个人理财产品（Mint / YNAB / Quicken / Personal Capital / 随手记）的账户类型**全部是用户面向分类**（Checking/Savings/Credit Card/Investment/Loan/...），资产/负债（会计）是**派生属性**（从用户分类自动得出，用于净资产/报表）。**没有任何主流产品让用户单独选"会计类型"**。

## 目标

新增 `category` 字段（用户面向分类），完整匹配原型 + 行业惯例：
- 用户创建账户时选 `category`（固定 9 类）
- `account_type` 由 `category` 派生（复式记账用），不再暴露给用户
- 列表按 `category` 分组，表单 TypeTabs 显示 category + 说明/示例

## 非目标
- 不改 transaction/复式记账逻辑（`account_type` 保留）
- category **固定枚举**（不支持用户自定义，区别于交易 category 模块的自定义标签）
- 不动 equity/income/expense 账户（这些是系统/科目表账户，非用户创建）

---

## 1. category 枚举（9 类，固定）

| key | 中文 | account_type | 图标 | 色 | 说明（创建时显示）|
|-----|------|--------------|------|----|-------------------|
| `savings` | 储蓄 | asset | account_balance_wallet | 绿 #2d8a6e | 活期/定期、现金、数字钱包余额 |
| `credit_card` | 信用卡 | liability | credit_card | 蓝 #6b8cce | 信用卡、花呗、免息分期 |
| `investment` | 投资 | asset | trending_up | 金 #b08d57 | 证券、基金、理财、数字货币 |
| `fixed_deposit` | 定期 | asset | hourglass_bottom | 橄榄 #8a8a6b | 大额存单、结构性存款 |
| `gold_fx` | 黄金外汇 | asset | diamond | 金黄 #c9a03d | 实物黄金、外币 |
| `real_estate` | 固定资产 | asset | home | 紫 #8c7bb5 | 房产、车辆 |
| `loan` | 贷款 | liability | request_quote | 红 #c4544d | 房贷、车贷、消费贷 |
| `other_asset` | 其他资产 | asset | inventory_2 | 灰 #7a7770 | 古董、字画、收藏品、保险现金价值 |
| `other_liability` | 其他负债 | liability | pending_actions | 红 #c4544d | 其他欠款、应付款 |

**9 类全部能确定映射到 `asset`/`liability`**，category 派生 account_type 无歧义。`other_asset`/`other_liability` 兜底覆盖边缘资产（数字货币归 investment，古董/字画归 other_asset）。

## 2. category 与 account_type 关系

- **category 是用户输入**（主），**account_type 由 category 派生**（系统映射，见上表）
- `account_type` 仍存库（复式记账/transaction 用），但**不再让用户选**
- `NewAccount`/`CreateAccount` 接收 category，内部根据映射设 account_type
- 表单 TypeTabs 只暴露 category（去掉 AccountType 选择）

## 3. 数据模型

### 3.1 domain（`server/internal/account/domain/valueobject.go`）

```go
// AccountCategory 是用户面向的账户分类（区别于会计 AccountType）。
type AccountCategory int

const (
    AccountCategorySavings AccountCategory = iota + 1
    AccountCategoryCreditCard
    AccountCategoryInvestment
    AccountCategoryFixedDeposit
    AccountCategoryGoldFx
    AccountCategoryRealEstate
    AccountCategoryLoan
    AccountCategoryOtherAsset
    AccountCategoryOtherLiability
)

func (c AccountCategory) String() string { /* "savings", "credit_card", ... */ }
func ParseAccountCategory(s string) AccountCategory { /* 反向，默认 Savings */ }

// ToAccountType 按 9 类映射表派生会计类型。
func (c AccountCategory) ToAccountType() AccountType {
    switch c {
    case AccountCategoryCreditCard, AccountCategoryLoan, AccountCategoryOtherLiability:
        return AccountTypeLiability
    default: // savings/investment/fixed_deposit/gold_fx/real_estate/other_asset
        return AccountTypeAsset
    }
}

// Description 返回创建表单显示的示例文案。
func (c AccountCategory) Description() string { /* "活期/定期、现金、数字钱包余额" ... */ }
```

### 3.2 domain entity（`server/internal/account/domain/entity.go`）

`Account` 加 `Category AccountCategory` 字段。`NewAccount` 签名改为接收 `category AccountCategory`，内部 `AccountType: category.ToAccountType()`（仍保留 account_type 入参为兼容，或校验一致）。

### 3.3 ent schema（`server/internal/account/ent/schema/account.go`）

```go
field.Enum("category").
    Values("savings", "credit_card", "investment", "fixed_deposit",
           "gold_fx", "real_estate", "loan", "other_asset", "other_liability").
    Default("savings").
    Comment("User-facing account category; drives account_type"),
```

`ent` 代码重新生成（`go generate ./...`）。`Schema.Create` 自动迁移加列（default `savings`）。

### 3.4 proto（`yucai/proto/account/v1/account.proto`）

```protobuf
enum AccountCategory {
  ACCOUNT_CATEGORY_UNSPECIFIED = 0;
  ACCOUNT_CATEGORY_SAVINGS = 1;
  ACCOUNT_CATEGORY_CREDIT_CARD = 2;
  ACCOUNT_CATEGORY_INVESTMENT = 3;
  ACCOUNT_CATEGORY_FIXED_DEPOSIT = 4;
  ACCOUNT_CATEGORY_GOLD_FX = 5;
  ACCOUNT_CATEGORY_REAL_ESTATE = 6;
  ACCOUNT_CATEGORY_LOAN = 7;
  ACCOUNT_CATEGORY_OTHER_ASSET = 8;
  ACCOUNT_CATEGORY_OTHER_LIABILITY = 9;
}

message AccountDTO {
  // ... existing fields ...
  AccountCategory category = 14; // 新增（字段号按现有最大+1）
}
message CreateAccountRequest {
  // ... existing fields ...
  AccountCategory category = 12; // 新增
}
```

protoc 重新生成 `account.pb.go` / `account_grpc.pb.go`（服务端 + Flutter 客户端）。

## 4. 后端改动清单

| 文件 | 改动 |
|------|------|
| `domain/valueobject.go` | 新增 `AccountCategory` 类型 + 9 常量 + `String/Parse/ToAccountType/Description` |
| `domain/entity.go` | `Account` 加 `Category`；`NewAccount` 接收 category、派生 account_type |
| `application/dto.go` | `CreateAccountRequest`/`AccountDTO`/`AccountToDTO`/`ApplyCreateDefaults` 加 Category |
| `application/command/commands.go` | `CreateAccountCommand` 加 Category |
| `application/service.go` | 创建逻辑：category → 派生 account_type |
| `adapter/driving/grpc/account_handler.go` | CreateAccount 解析 proto category → domain；响应映射 category |
| `adapter/driven/repository/account_repo.go` | ent ↔ domain mapper 加 category 双向映射 |
| `ent/schema/account.go` | 加 `category` enum 字段 |
| `ent/*`（生成） | 重新生成 |
| `proto/account/v1/account.proto` | `AccountCategory` enum + DTO/Request 加字段 |

## 5. 前端改动清单

| 文件 | 改动 |
|------|------|
| `account/domain/value_objects.dart` | `AccountCategory` enum（9 值）+ `label`/`description`/`color`/`icon` + proto 映射 |
| `account/domain/entities/account_entity.dart` | `Account` 加 `category` 字段 |
| `account/data/account_mapper.dart` | category 双向映射（proto ↔ domain）|
| `account/data/account_remote_data_source.dart` | CreateAccount 传 category；响应读 category |
| `account/data/account_repository_impl.dart` | CreateAccountParams 透传 category |
| `account/domain/repositories/account_repository.dart` | `CreateAccountParams` 加 category |
| `account/domain/usecases/create_account_usecase.dart` | 透传 |
| `account/presentation/pages/account_form_page.dart` | TypeTabs 改用 `AccountCategory`（9 类）+ 选中后显示 description；移除 account_type 选择 |
| `account/presentation/pages/accounts_page.dart` | 按 category 分组（9 类，只显示有账户的）+ FilterBar 按 category 筛选 |
| proto 生成（`proto/account/v1/account.pb.dart`）| 重新生成 |

## 6. 数据迁移

已有账户按 `account_type` 推断默认 `category`：

| account_type | 默认 category |
|--------------|---------------|
| asset | savings |
| liability | loan |
| equity / income / expense | other_asset |

ent `Schema.Create` 自动加列（`DEFAULT 'savings'`），已有行填默认值。用户可后续编辑调整（编辑账户功能后续 sprint）。

## 7. 测试

### 后端
- `domain/valueobject_test.go`：`ToAccountType` 9 类映射 + `String/Parse` 往返 + `Description`
- `domain/entity_test.go`：`NewAccount(category)` 正确派生 account_type
- `application/service_test.go`：CreateAccount 传 category → 落库 account_type 正确
- `adapter/driven/repository_test.go`：category 持久化往返

### 前端
- `value_objects_test.dart`：AccountCategory 9 值 label/description/proto 映射
- `account_mapper_test.dart`：category 双向映射
- `account_bloc_test.dart`：CreateAccount 携带 category

## 8. 兼容性与约束

- `account_type` 字段**保留**（不破坏 transaction/复式记账/chart of accounts）
- category 固定枚举（扩展需加枚举值 + 迁移，ent enum 扩展是 ADD COLUMN 级别）
- 不影响 equity/income/expense 系统账户
- 表单不再暴露 account_type（category 派生），但 domain/proto 仍保留 account_type 字段（兼容）

## 9. UI 交互（前端）

- **表单 TypeTabs**：横向可滚动 9 个 category chip（图标 + 中文名），选中态御财金浅底
- **选中后**：TypeTabs 下方一行显示该 category 的 description/示例（如选「投资」→ "证券、基金、理财、数字货币"）
- **账户列表**：按 category 分组（SectionHeader 显示 category 中文名 + 图标 + 合计），只渲染有账户的 category；FilterBar pill 按 category 筛选（全部 + 9 类）
- **卡片**：类型色图标块按 category 色（见 §1 色）
