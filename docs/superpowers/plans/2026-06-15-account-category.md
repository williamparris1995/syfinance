# Account Category Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为账户模块新增 `category`（用户面向 9 类分类）字段，category 派生会计 `account_type`，全栈打通（Go 服务端 + Flutter 客户端），匹配原型表单与列表分组。

**Architecture:** category 是用户输入（固定 9 类枚举），account_type 由 category 派生（asset/liability）。后端 domain/ent/proto/mapper/service/handler 全链路加 category；前端 value_objects/entity/data 层/UI 加 category，TypeTabs 用 category + 显示说明，列表按 category 分组。

**Tech Stack:** Go + entGo ORM + gRPC (buf) + PostgreSQL（服务端 `yucai/server`）；Flutter + flutter_bloc + protobuf（客户端 `yucai/client`）。

**Design Spec:** [docs/superpowers/specs/2026-06-15-account-category-design.md](../specs/2026-06-15-account-category-design.md)

**生成命令（在 `yucai/` 目录执行）：**
- `make generate` — ent + wire 代码生成（`cd server && go generate ./...`）
- `make proto` — protobuf Go + Dart stubs（`buf generate`，一次生成两端）
- `make test` — Go 测试；`make flutter-test` — Flutter 测试

**字段号（proto）：** AccountDTO.category = 18；CreateAccountRequest.category = 12。

---

# Part A: 服务端（Tasks 1-7）

## Task 1: domain AccountCategory 类型

**Files:**
- Modify: `yucai/server/internal/account/domain/valueobject.go`
- Test: `yucai/server/internal/account/domain/domain_test.go`（追加）

- [ ] **Step 1: 写失败测试（AccountCategory 映射 + 往返）**

追加到 `domain_test.go`：

```go
func TestAccountCategoryToAccountType(t *testing.T) {
	cases := []struct {
		cat    AccountCategory
		want   AccountType
	}{
		{AccountCategorySavings, AccountTypeAsset},
		{AccountCategoryInvestment, AccountTypeAsset},
		{AccountCategoryFixedDeposit, AccountTypeAsset},
		{AccountCategoryGoldFx, AccountTypeAsset},
		{AccountCategoryRealEstate, AccountTypeAsset},
		{AccountCategoryOtherAsset, AccountTypeAsset},
		{AccountCategoryCreditCard, AccountTypeLiability},
		{AccountCategoryLoan, AccountTypeLiability},
		{AccountCategoryOtherLiability, AccountTypeLiability},
	}
	for _, c := range cases {
		if got := c.cat.ToAccountType(); got != c.want {
			t.Errorf("%s.ToAccountType()=%s, want %s", c.cat, got, c.want)
		}
	}
}

func TestAccountCategoryStringRoundTrip(t *testing.T) {
	for _, c := range []AccountCategory{
		AccountCategorySavings, AccountCategoryCreditCard, AccountCategoryInvestment,
		AccountCategoryFixedDeposit, AccountCategoryGoldFx, AccountCategoryRealEstate,
		AccountCategoryLoan, AccountCategoryOtherAsset, AccountCategoryOtherLiability,
	} {
		if ParseAccountCategory(c.String()) != c {
			t.Errorf("round-trip failed for %s", c.String())
		}
	}
	// 未知值兜底为 Savings
	if ParseAccountCategory("nonsense") != AccountCategorySavings {
		t.Error("unknown category should default to Savings")
	}
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd yucai/server && go test ./internal/account/domain/ -run TestAccountCategory -v`
Expected: FAIL（`AccountCategorySavings` undefined）

- [ ] **Step 3: 实现 AccountCategory**

追加到 `valueobject.go`（`AccountStatus` 块之后）：

```go
// AccountCategory 是用户面向的账户分类（区别于会计 AccountType）。
// 固定 9 类，匹配原型 + 行业惯例（Mint/YNAB/Quicken）。
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

func (c AccountCategory) String() string {
	switch c {
	case AccountCategorySavings:
		return "savings"
	case AccountCategoryCreditCard:
		return "credit_card"
	case AccountCategoryInvestment:
		return "investment"
	case AccountCategoryFixedDeposit:
		return "fixed_deposit"
	case AccountCategoryGoldFx:
		return "gold_fx"
	case AccountCategoryRealEstate:
		return "real_estate"
	case AccountCategoryLoan:
		return "loan"
	case AccountCategoryOtherAsset:
		return "other_asset"
	case AccountCategoryOtherLiability:
		return "other_liability"
	default:
		return "savings"
	}
}

func ParseAccountCategory(s string) AccountCategory {
	switch s {
	case "credit_card":
		return AccountCategoryCreditCard
	case "investment":
		return AccountCategoryInvestment
	case "fixed_deposit":
		return AccountCategoryFixedDeposit
	case "gold_fx":
		return AccountCategoryGoldFx
	case "real_estate":
		return AccountCategoryRealEstate
	case "loan":
		return AccountCategoryLoan
	case "other_asset":
		return AccountCategoryOtherAsset
	case "other_liability":
		return AccountCategoryOtherLiability
	default:
		return AccountCategorySavings
	}
}

// ToAccountType 按 9 类映射表派生会计类型（复式记账用）。
func (c AccountCategory) ToAccountType() AccountType {
	switch c {
	case AccountCategoryCreditCard, AccountCategoryLoan, AccountCategoryOtherLiability:
		return AccountTypeLiability
	default:
		return AccountTypeAsset
	}
}

// Description 返回创建表单显示的示例文案。
func (c AccountCategory) Description() string {
	switch c {
	case AccountCategorySavings:
		return "活期/定期、现金、数字钱包余额"
	case AccountCategoryCreditCard:
		return "信用卡、花呗、免息分期"
	case AccountCategoryInvestment:
		return "证券、基金、理财、数字货币"
	case AccountCategoryFixedDeposit:
		return "大额存单、结构性存款"
	case AccountCategoryGoldFx:
		return "实物黄金、外币"
	case AccountCategoryRealEstate:
		return "房产、车辆"
	case AccountCategoryLoan:
		return "房贷、车贷、消费贷"
	case AccountCategoryOtherAsset:
		return "古董、字画、收藏品、保险现金价值"
	case AccountCategoryOtherLiability:
		return "其他欠款、应付款"
	default:
		return ""
	}
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd yucai/server && go test ./internal/account/domain/ -run TestAccountCategory -v`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/server/internal/account/domain/valueobject.go yucai/server/internal/account/domain/domain_test.go
git commit -m "feat(account): domain AccountCategory 类型（9 类 + ToAccountType/Description）"
```

---

## Task 2: domain entity Account.Category + NewAccount 改

**Files:**
- Modify: `yucai/server/internal/account/domain/entity.go`
- Test: `yucai/server/internal/account/domain/domain_test.go`

- [ ] **Step 1: 写失败测试（NewAccount 按 category 派生 account_type）**

追加到 `domain_test.go`：

```go
func TestNewAccountDerivesTypeFromCategory(t *testing.T) {
	a, err := NewAccountWithCategory(uuid.New(), "测试信用卡", AccountCategoryCreditCard, "CNY")
	if err != nil {
		t.Fatal(err)
	}
	if a.AccountType != AccountTypeLiability {
		t.Errorf("credit_card category should derive liability, got %s", a.AccountType)
	}
	if a.Category != AccountCategoryCreditCard {
		t.Error("category not stored")
	}
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd yucai/server && go test ./internal/account/domain/ -run TestNewAccountDerives -v`
Expected: FAIL（`NewAccountWithCategory` undefined）

- [ ] **Step 3: 实现**

`entity.go`：在 `Account` struct 加字段（`AccountType` 下方）：

```go
	AccountType         AccountType
	Category            AccountCategory // 新增：用户面向分类，派生 AccountType
```

新增构造函数（保留旧 `NewAccount` 兼容，内部委托）：

```go
// NewAccountWithCategory 按 category 创建账户，account_type 由 category 派生。
func NewAccountWithCategory(tenantID uuid.UUID, name string, category AccountCategory, currencyCode string) (*Account, error) {
	name = strings.TrimSpace(name)
	if name == "" {
		return nil, fmt.Errorf("account name must not be empty")
	}
	if category < AccountCategorySavings || category > AccountCategoryOtherLiability {
		return nil, fmt.Errorf("invalid account category")
	}
	currencyCode = strings.TrimSpace(strings.ToUpper(currencyCode))
	if currencyCode == "" {
		currencyCode = "CNY"
	}
	return &Account{
		ID:           uuid.New(),
		TenantID:     tenantID,
		Name:         name,
		AccountType:  category.ToAccountType(),
		Category:     category,
		CurrencyCode: currencyCode,
		Status:       AccountStatusActive,
		Version:      1,
		CreatedAt:    time.Now(),
		UpdatedAt:    time.Now(),
	}, nil
}
```

> 旧 `NewAccount(tenantID, name, accountType, currencyCode)` 保留（chart of accounts 等系统账户仍用 account_type 直接创建，无 category）。

- [ ] **Step 4: 运行确认通过**

Run: `cd yucai/server && go test ./internal/account/domain/ -v`
Expected: PASS（所有 domain 测试）

- [ ] **Step 5: 提交**

```bash
git add yucai/server/internal/account/domain/entity.go yucai/server/internal/account/domain/domain_test.go
git commit -m "feat(account): entity Account.Category + NewAccountWithCategory（category 派生 type）"
```

---

## Task 3: ent schema category 字段 + 生成

**Files:**
- Modify: `yucai/server/internal/account/ent/schema/account.go`

- [ ] **Step 1: 加 category enum 字段**

在 `Fields()` 的 `account_type` 字段之后加：

```go
		field.Enum("category").
			Values("savings", "credit_card", "investment", "fixed_deposit",
				"gold_fx", "real_estate", "loan", "other_asset", "other_liability").
			Default("savings").
			Comment("User-facing account category; drives account_type"),
```

- [ ] **Step 2: 生成 ent 代码**

Run: `cd yucai && make generate`
Expected: 无错误，`ent/account/` 下生成 `category.go` 等。

- [ ] **Step 3: 编译验证**

Run: `cd yucai/server && go build ./...`
Expected: 无错误。

- [ ] **Step 4: 提交**

```bash
git add yucai/server/internal/account/ent/schema/account.go yucai/server/internal/account/ent/
git commit -m "feat(account): ent schema category enum（9 类，default savings）"
```

---

## Task 4: proto AccountCategory enum + 字段 + 生成

**Files:**
- Modify: `yucai/proto/account/v1/account.proto`

- [ ] **Step 1: 加 enum + DTO/Request 字段**

在 `AccountStatus` enum 之后加：

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
```

`AccountDTO` 末尾加（字段号 18，现有最大 17）：

```protobuf
  AccountCategory category = 18;
```

`CreateAccountRequest` 末尾加（字段号 12，现有最大 11）：

```protobuf
  AccountCategory category = 12;
```

- [ ] **Step 2: 生成 Go + Dart stubs**

Run: `cd yucai && make proto`
Expected: 无错误，重新生成 `server/internal/proto/account/v1/*.pb.go` + `client/lib/proto/account/v1/*.pb.dart`。

- [ ] **Step 3: 编译验证（两端）**

Run: `cd yucai/server && go build ./...`
Expected: 无错误（proto 生成后可能暂时未用，编译 OK）。

- [ ] **Step 4: 提交**

```bash
git add yucai/proto/account/v1/account.proto yucai/server/internal/proto/account/v1/ yucai/client/lib/proto/account/v1/
git commit -m "feat(account): proto AccountCategory enum + DTO/Request category 字段"
```

---

## Task 5: application dto/commands 加 Category

**Files:**
- Modify: `yucai/server/internal/account/application/dto.go`
- Modify: `yucai/server/internal/account/application/command/commands.go`

- [ ] **Step 1: dto.go 改动**

`CreateAccountRequest` 加字段（`AccountType` 下方）：

```go
	AccountType         domain.AccountType
	Category            domain.AccountCategory // 新增
```

`AccountDTO` 加字段：

```go
	AccountType         domain.AccountType
	Category            domain.AccountCategory // 新增
```

`AccountToDTO` 映射：

```go
		AccountType:         a.AccountType,
		Category:            a.Category, // 新增
```

`ApplyCreateDefaults` 无需改（category 在 NewAccountWithCategory 设，不经 defaults）。

- [ ] **Step 2: commands.go 改动**

`CreateAccountCommand` 加字段：

```go
	AccountType         domain.AccountType
	Category            domain.AccountCategory // 新增
```

- [ ] **Step 3: 编译验证**

Run: `cd yucai/server && go build ./...`
Expected: 无错误。

- [ ] **Step 4: 提交**

```bash
git add yucai/server/internal/account/application/dto.go yucai/server/internal/account/application/command/commands.go
git commit -m "feat(account): application dto/commands 加 Category"
```

---

## Task 6: service CreateAccount 用 category

**Files:**
- Modify: `yucai/server/internal/account/application/service.go`

- [ ] **Step 1: 改 CreateAccount 用 NewAccountWithCategory**

`service.go` 的 `CreateAccount`，将：

```go
	account, err := domain.NewAccount(req.TenantID, req.Name, req.AccountType, req.CurrencyCode)
```

改为：

```go
	account, err := domain.NewAccountWithCategory(req.TenantID, req.Name, req.Category, req.CurrencyCode)
```

- [ ] **Step 2: 编译验证**

Run: `cd yucai/server && go build ./...`
Expected: 无错误。

- [ ] **Step 3: 提交**

```bash
git add yucai/server/internal/account/application/service.go
git commit -m "feat(account): service CreateAccount 用 category 派生 account_type"
```

---

## Task 7: repo mapper category 双向映射

**Files:**
- Modify: `yucai/server/internal/account/adapter/driven/repository/account_repo.go`

- [ ] **Step 1: Save 加 SetCategory**

`Save` 的 builder 链（`SetAccountType` 之后）加：

```go
		SetAccountType(accountent.AccountType(a.AccountType.String())).
		SetCategory(accountent.Category(a.Category.String())). // 新增
```

- [ ] **Step 2: toDomainAccount 加 Category**

`toDomainAccount` 的 result（`AccountType` 之后）加：

```go
		AccountType:         domain.ParseAccountType(string(a.AccountType)),
		Category:            domain.ParseAccountCategory(string(a.Category)), // 新增
```

- [ ] **Step 3: 编译 + 运行 repo 测试**

Run: `cd yucai/server && go build ./... && go test ./internal/account/... -v -count=1`
Expected: 编译 OK，测试 PASS。

- [ ] **Step 4: 提交**

```bash
git add yucai/server/internal/account/adapter/driven/repository/account_repo.go
git commit -m "feat(account): repo mapper category 双向映射"
```

---

## Task 8: handler 透传 category（CreateAccount + DTO 响应）

**Files:**
- Modify: `yucai/server/internal/account/adapter/driving/grpc/account_handler.go`

- [ ] **Step 1: 读现有 handler 的 CreateAccount + toProtoAccount 模式**

Run: `cd yucai/server && grep -n "CreateAccount\|AccountType\|toProto\|func.*Handler" internal/account/adapter/driving/grpc/account_handler.go`
（确认 CreateAccount 解析 Request→application.Request 的位置 + DTO→proto DTO 的映射函数）

- [ ] **Step 2: CreateAccount 解析加 category**

在 handler 的 CreateAccount 中，构造 `application.CreateAccountRequest` 时加（参考现有 AccountType 映射模式）：

```go
		Category: mapProtoCategoryToDomain(req.GetCategory()),
```

并在 handler 文件加映射 helper（或复用现有 enum 映射风格）：

```go
func mapProtoCategoryToDomain(c pb.AccountCategory) domain.AccountCategory {
	return domain.ParseAccountCategory(accountCategoryName(c))
}
// accountCategoryName 返回 proto enum 的字符串名（savings/credit_card/...），
// 复用现有 AccountType 的 proto→string 映射模式（参考 handler 中 AccountType 处理）。
```

> 具体 helper 写法对齐 handler 中现有 `AccountType` 的 proto↔string 处理（可能已有 `protoAccountType`/`domainAccountType` helper，category 仿写）。

- [ ] **Step 3: DTO→proto 响应映射加 category**

在 handler 的 `toProtoAccount`（或同名函数）映射 AccountDTO→pb.AccountDTO 时加：

```go
		Category: mapDomainCategoryToProto(a.Category),
```

- [ ] **Step 4: 编译 + 全量服务端测试**

Run: `cd yucai/server && go build ./... && go test ./... -count=1`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add yucai/server/internal/account/adapter/driving/grpc/account_handler.go
git commit -m "feat(account): grpc handler 透传 category（CreateAccount + DTO）"
```

---

# Part B: 客户端（Tasks 9-13）

> 前置：Task 4 已 `make proto` 生成 Dart stubs（`client/lib/proto/account/v1/account.pb.dart` 含 `AccountCategory` enum）。

## Task 9: 前端 value_objects AccountCategory

**Files:**
- Modify: `yucai/client/lib/account/domain/value_objects.dart`
- Test: `yucai/client/test/account/domain/value_objects_test.dart`（新建或追加）

- [ ] **Step 1: 写失败测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/account/domain/value_objects.dart';

void main() {
  test('AccountCategory 有 9 个值 + label/description', () {
    expect(AccountCategory.values.length, 9);
    expect(AccountCategory.savings.label, '储蓄');
    expect(AccountCategory.creditCard.accountType, AccountType.liability);
    expect(AccountCategory.investment.accountType, AccountType.asset);
    expect(AccountCategory.savings.description, contains('活期'));
  });

  test('所有 category 都能派生 asset 或 liability', () {
    for (final c in AccountCategory.values) {
      expect(c.accountType, isIn([AccountType.asset, AccountType.liability]));
    }
  });
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd yucai/client && flutter test test/account/domain/value_objects_test.dart`
Expected: FAIL（`AccountCategory` undefined）

- [ ] **Step 3: 实现 AccountCategory enum**

在 `value_objects.dart`（`AccountStatus` 之后）加：

```dart
/// 用户面向账户分类（9 类，匹配原型 + 行业惯例）。
/// category 派生会计 [AccountType]（复式记账用），不暴露给用户。
enum AccountCategory {
  savings,
  creditCard,
  investment,
  fixedDeposit,
  goldFx,
  realEstate,
  loan,
  otherAsset,
  otherLiability,
}

extension AccountCategoryX on AccountCategory {
  String get label {
    switch (this) {
      case AccountCategory.savings: return '储蓄';
      case AccountCategory.creditCard: return '信用卡';
      case AccountCategory.investment: return '投资';
      case AccountCategory.fixedDeposit: return '定期';
      case AccountCategory.goldFx: return '黄金外汇';
      case AccountCategory.realEstate: return '固定资产';
      case AccountCategory.loan: return '贷款';
      case AccountCategory.otherAsset: return '其他资产';
      case AccountCategory.otherLiability: return '其他负债';
    }
  }

  String get description {
    switch (this) {
      case AccountCategory.savings: return '活期/定期、现金、数字钱包余额';
      case AccountCategory.creditCard: return '信用卡、花呗、免息分期';
      case AccountCategory.investment: return '证券、基金、理财、数字货币';
      case AccountCategory.fixedDeposit: return '大额存单、结构性存款';
      case AccountCategory.goldFx: return '实物黄金、外币';
      case AccountCategory.realEstate: return '房产、车辆';
      case AccountCategory.loan: return '房贷、车贷、消费贷';
      case AccountCategory.otherAsset: return '古董、字画、收藏品、保险现金价值';
      case AccountCategory.otherLiability: return '其他欠款、应付款';
    }
  }

  /// 派生会计类型（复式记账用）。
  AccountType get accountType {
    switch (this) {
      case AccountCategory.creditCard:
      case AccountCategory.loan:
      case AccountCategory.otherLiability:
        return AccountType.liability;
      default:
        return AccountType.asset;
    }
  }

  // proto 映射见 mapper（Task 10）
}
```

- [ ] **Step 4: 运行确认通过**

Run: `cd yucai/client && flutter test test/account/domain/value_objects_test.dart`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/domain/value_objects.dart yucai/client/test/account/domain/value_objects_test.dart
git commit -m "feat(client): value_objects AccountCategory（9 类 + label/description/accountType）"
```

---

## Task 10: 前端 data 层（entity + mapper + remote_ds + repo + params）

**Files:**
- Modify: `yucai/client/lib/account/domain/entities/account_entity.dart`
- Modify: `yucai/client/lib/account/data/mappers/account_mapper.dart`
- Modify: `yucai/client/lib/account/data/account_remote_ds.dart`
- Modify: `yucai/client/lib/account/domain/repositories/account_repository.dart`（CreateAccountParams）
- Modify: `yucai/client/lib/account/domain/usecases/create_account_usecase.dart`

- [ ] **Step 1: entity 加 category 字段**

`account_entity.dart` 的 `Account` 加字段（`accountType` 下方）+ props 加 `category`：

```dart
  final AccountType accountType;
  final AccountCategory category; // 新增
```

构造函数加 `required this.category`，`props` 列表加 `category`。

> 注意：现有测试中构造 `Account(...)` 需补 `category` 参数（如 `category: AccountCategory.savings`）。

- [ ] **Step 2: mapper 加 category 双向映射**

`account_mapper.dart`：domain→proto 加 `category: _categoryToProto(a.category)`；proto→domain 加 `category: _categoryFromProto(pb.category)`。加 helper：

```dart
pb.AccountCategory _categoryToProto(AccountCategory c) {
  switch (c) {
    case AccountCategory.savings: return pb.AccountCategory.ACCOUNT_CATEGORY_SAVINGS;
    case AccountCategory.creditCard: return pb.AccountCategory.ACCOUNT_CATEGORY_CREDIT_CARD;
    case AccountCategory.investment: return pb.AccountCategory.ACCOUNT_CATEGORY_INVESTMENT;
    case AccountCategory.fixedDeposit: return pb.AccountCategory.ACCOUNT_CATEGORY_FIXED_DEPOSIT;
    case AccountCategory.goldFx: return pb.AccountCategory.ACCOUNT_CATEGORY_GOLD_FX;
    case AccountCategory.realEstate: return pb.AccountCategory.ACCOUNT_CATEGORY_REAL_ESTATE;
    case AccountCategory.loan: return pb.AccountCategory.ACCOUNT_CATEGORY_LOAN;
    case AccountCategory.otherAsset: return pb.AccountCategory.ACCOUNT_CATEGORY_OTHER_ASSET;
    case AccountCategory.otherLiability: return pb.AccountCategory.ACCOUNT_CATEGORY_OTHER_LIABILITY;
  }
}

AccountCategory _categoryFromProto(pb.AccountCategory c) {
  switch (c) {
    case pb.AccountCategory.ACCOUNT_CATEGORY_CREDIT_CARD: return AccountCategory.creditCard;
    case pb.AccountCategory.ACCOUNT_CATEGORY_INVESTMENT: return AccountCategory.investment;
    case pb.AccountCategory.ACCOUNT_CATEGORY_FIXED_DEPOSIT: return AccountCategory.fixedDeposit;
    case pb.AccountCategory.ACCOUNT_CATEGORY_GOLD_FX: return AccountCategory.goldFx;
    case pb.AccountCategory.ACCOUNT_CATEGORY_REAL_ESTATE: return AccountCategory.realEstate;
    case pb.AccountCategory.ACCOUNT_CATEGORY_LOAN: return AccountCategory.loan;
    case pb.AccountCategory.ACCOUNT_CATEGORY_OTHER_ASSET: return AccountCategory.otherAsset;
    case pb.AccountCategory.ACCOUNT_CATEGORY_OTHER_LIABILITY: return AccountCategory.otherLiability;
    default: return AccountCategory.savings;
  }
}
```

- [ ] **Step 3: remote_ds CreateAccount 传 category**

`account_remote_ds.dart` 的 CreateAccount 构造 `CreateAccountRequest` 加 `category: _categoryToProto(params.category)`（参考现有 accountType 传法）。

- [ ] **Step 4: CreateAccountParams 加 category**

`account_repository.dart` 的 `CreateAccountParams` 加 `final AccountCategory category;` + 构造参数。

- [ ] **Step 5: usecase 透传（无需改，CreateAccountParams 透传）**

确认 `create_account_usecase.dart` 调 `repo.create(params)`，params 含 category，自动透传。

- [ ] **Step 6: 更新现有测试（Account 构造 + CreateAccountParams 补 category）**

所有测试中 `Account(...)` 和 `CreateAccountParams(...)` 补 `category: AccountCategory.savings`（或按测试语义）。`registerFallbackValue(CreateAccountParams(...))` 也补。

- [ ] **Step 7: 编译 + 测试**

Run: `cd yucai/client && flutter analyze lib && flutter test`
Expected: 0 error，测试 PASS。

- [ ] **Step 8: 提交**

```bash
git add yucai/client/lib/account/
git commit -m "feat(client): data 层 category 全链路（entity/mapper/remote_ds/params）"
```

---

## Task 11: AccountFormPage TypeTabs 用 category + 显示说明

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_form_page.dart`

- [ ] **Step 1: 改 TypeTabs 用 AccountCategory**

`account_form_page.dart`：
- State 字段 `_type`（AccountType）改为 `_category`（AccountCategory），默认 `AccountCategory.savings`
- TypeTabs options 改为 9 类 category（带图标）：

```dart
static const _categoryOptions = <TypeOption<AccountCategory>>[
  TypeOption(AccountCategory.savings, '储蓄', Icons.account_balance_wallet_outlined),
  TypeOption(AccountCategory.creditCard, '信用卡', Icons.credit_card_outlined),
  TypeOption(AccountCategory.investment, '投资', Icons.trending_up),
  TypeOption(AccountCategory.fixedDeposit, '定期', Icons.hourglass_bottom),
  TypeOption(AccountCategory.goldFx, '黄金外汇', Icons.diamond_outlined),
  TypeOption(AccountCategory.realEstate, '固定资产', Icons.home_outlined),
  TypeOption(AccountCategory.loan, '贷款', Icons.request_quote_outlined),
  TypeOption(AccountCategory.otherAsset, '其他资产', Icons.inventory_2_outlined),
  TypeOption(AccountCategory.otherLiability, '其他负债', Icons.pending_actions),
];
```

- [ ] **Step 2: TypeTabs 下方显示选中 category 的 description**

在 TypeTabs 之后加：

```dart
const SizedBox(height: AppSpacing.sm),
Text(_category.description,
    style: const TextStyle(color: AppColors.muted, fontSize: 12)),
```

- [ ] **Step 3: _submit 用 category**

`_submit` 改为构造 `CreateAccountParams(... category: _category ...)`，移除 accountType（params 不再有 accountType，由 category 派生）。

> 若 `CreateAccountParams` 仍有 `accountType` 字段（兼容），传 `_category.accountType`；若已移除，只传 category。

- [ ] **Step 4: 编译 + analyze**

Run: `cd yucai/client && flutter analyze lib`
Expected: 0 error。

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_form_page.dart
git commit -m "feat(client): AccountFormPage TypeTabs 用 category + 显示说明"
```

---

## Task 12: AccountsPage 按 category 分组 + 筛选

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/accounts_page.dart`

- [ ] **Step 1: 分组改用 category**

`_groupByType` 改为按 `AccountCategory` 分组（或新增 `_groupByCategory`）。`_GroupBlock` 的 `type` 参数改为 `AccountCategory`，标题用 `category.label` + 图标 + 颜色（按 category）。

- [ ] **Step 2: 筛选改用 category**

`_filter` 类型改 `AccountCategory?`。FilterBar tabs 改为 `[全部] + AccountCategory.values`（label 用 category.label）。

- [ ] **Step 3: 卡片图标/色按 category**

`_AccountCard` 的 `_typeColor`/`_typeIcon` 改为按 `AccountCategory`（9 类各自色/图标，见 spec §1）。

- [ ] **Step 4: 编译 + analyze**

Run: `cd yucai/client && flutter analyze lib`
Expected: 0 error。

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/accounts_page.dart
git commit -m "feat(client): AccountsPage 按 category 分组 + 筛选 + 卡片类型色"
```

---

# Part C: 验证（Task 13）

## Task 13: 全栈验证

- [ ] **Step 1: 服务端全量测试**

Run: `cd yucai && make test`
Expected: 全部 PASS（domain/service/repo）。

- [ ] **Step 2: 客户端 analyze + 测试**

Run: `cd yucai && make flutter-test`（含 flutter analyze 前置）
Expected: 0 error，全部测试 PASS。

- [ ] **Step 3: 重启全栈验证**

- 确保容器运行（`podman ps`，Postgres + Redis）
- 重启 Go 服务端：`cd yucai/server && DATABASE_URL=... JWT_SECRET=... go run ./cmd/server`（ent Schema.Create 自动加 category 列，已有账户 default savings）
- 重启 Flutter 客户端：`cd yucai/client && flutter run -d windows --dart-define=SERVER_HOST=localhost --dart-define=SERVER_PORT=9090 --dart-define=USE_TLS=false`

- [ ] **Step 4: 手动验证（在客户端操作）**

1. 账户管理 → 新建账户 → TypeTabs 应显示 **9 类 category**（储蓄/信用卡/投资/定期/黄金外汇/固定资产/贷款/其他资产/其他负债），选中后下方显示**说明示例**
2. 创建「投资」类账户（如"证券账户"）→ 服务端 CreateAccount OK → 列表「投资」分组出现卡片，图标金色 trending_up
3. 创建「信用卡」类账户 → 列表「信用卡」分组，余额为负债色（红）
4. 筛选标签按 category（全部 + 9 类）切换正常
5. 查 DB 确认：`podman exec yucai-pg psql -U yucai -d yucai -c "SELECT name, category, account_type FROM accounts;"` → category 落库 + account_type 由 category 派生（投资→asset，信用卡→liability）
6. 已有账户（gsys 等）category 默认 savings

- [ ] **Step 5: 提交（如有验证修复）**

```bash
git add -A
git commit -m "test(account): 全栈验证 category（9 类 + 派生 account_type）"
```

---

## Self-Review 结果

- **Spec 覆盖**：§1 枚举(Task 1) ✓、§2 关系(Task 2/6) ✓、§3 数据模型(Task 1-4) ✓、§4 后端改动(Task 1-8) ✓、§5 前端改动(Task 9-12) ✓、§6 迁移(Task 3/13 ent default) ✓、§7 测试(Task 1/9/13) ✓、§9 UI(Task 11/12) ✓
- **类型一致**：`AccountCategory` 9 值在 domain/proto/前端 enum 一致；`NewAccountWithCategory` / `ToAccountType` / `accountType` getter 命名统一；proto 字段号 18/12 不冲突。
- **无 placeholder**：所有代码步骤含完整代码；Task 8 handler 因依赖现有 helper 模式，给出 grep 定位 + 仿写指引（非占位）。
