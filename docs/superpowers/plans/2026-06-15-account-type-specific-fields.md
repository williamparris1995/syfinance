# 账户类型专属字段 + 动态表单 + 卡片操作 + 详情页 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为账户模型补全 26 个类型专属 nullable 字段（category 前缀命名，行业惯例 Mint/Quicken/随手记），创建/编辑表单按 category 完全动态切换字段集，账户卡片 + 详情页支持完整操作（编辑/复制/关闭/删除真实 + 记一笔/转账🔒占位），详情页 Hero 真实展示专属字段、统计/流水/持仓占位。

**Architecture:** 26 字段用**固定列 nullable**（指针）存 Account（非 JSON/子实体）。独占字段加 category 前缀（`credit_`/`invest_`/`fixed_`/`gold_`/`estate_`/`loan_`），共享字段（利率/卡号尾号/备注/开户日）通用名。domain 新增 `AccountProfile` 值对象统一 create/update 字段设置（避免大参数列表）。proto 用 `optional`（scalar）+ `google.protobuf.Timestamp`（日期）。表单按 category 条件渲染。account 操作真实；transaction/holding/payment_schedule UI 完整但占位。

**Tech Stack:** Go DDD + ent ORM + gRPC + Wire DI（`yucai/server`）；Flutter + flutter_bloc + go_router + protobuf（`yucai/client`）。

**Design Spec:** [docs/superpowers/specs/2026-06-15-account-type-specific-fields-design.md](../specs/2026-06-15-account-type-specific-fields-design.md)

**生成命令（在 `yucai/` 目录执行）:**
- `make generate` — ent + wire 代码生成（`cd server && go generate ./...`）
- `make proto` — protobuf Go + Dart stubs（一次生成两端）
- `make test` — Go 测试；`make flutter-test` — Flutter 测试（含 analyze）

---

## §字段总表（26 个新增字段，DRY 参考）

> 全 plan 引用此表。`CreditLimitCents` 已存在于 domain/ent/proto/DTO，**不重复新增**。所有新字段 nullable；string 用非指针（`""`=未填），数值/日期/整数用指针。命名：domain PascalCase / proto snake_case / Dart camelCase。

| # | domain | Go 类型 | ent | proto | Dart |
|---|---|---|---|---|---|
| 1 | `CardNumberTail` | `string` | `String().Optional().Default("")` | `optional string card_number_tail` | `String cardNumberTail` |
| 2 | `Notes` | `string` | `String().Optional().Default("")` | `optional string notes` | `String notes` |
| 3 | `OpeningDate` | `*time.Time` | `Time().Optional().Nillable()` | `.Timestamp opening_date` | `DateTime? openingDate` |
| 4 | `InterestRate` | `*float64` | `Float64().Optional().Nillable()` | `optional double interest_rate` | `double? interestRate` |
| 5 | `CreditBillingDay` | `*int` | `Int().Optional().Nillable()` | `optional int32 credit_billing_day` | `int? creditBillingDay` |
| 6 | `CreditRepaymentDay` | `*int` | `Int().Optional().Nillable()` | `optional int32 credit_repayment_day` | `int? creditRepaymentDay` |
| 7 | `CreditAnnualFeeCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 credit_annual_fee_cents` | `int? creditAnnualFeeCents` |
| 8 | `InvestCostCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 invest_cost_cents` | `int? investCostCents` |
| 9 | `InvestMarketValueCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 invest_market_value_cents` | `int? investMarketValueCents` |
| 10 | `InvestReturnYtd` | `*float64` | `Float64().Optional().Nillable()` | `optional double invest_return_ytd` | `double? investReturnYtd` |
| 11 | `FixedPrincipalCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 fixed_principal_cents` | `int? fixedPrincipalCents` |
| 12 | `FixedStartDate` | `*time.Time` | `Time().Optional().Nillable()` | `.Timestamp fixed_start_date` | `DateTime? fixedStartDate` |
| 13 | `FixedMaturityDate` | `*time.Time` | `Time().Optional().Nillable()` | `.Timestamp fixed_maturity_date` | `DateTime? fixedMaturityDate` |
| 14 | `FixedTermMonths` | `*int` | `Int().Optional().Nillable()` | `optional int32 fixed_term_months` | `int? fixedTermMonths` |
| 15 | `GoldProductType` | `string` | `String().Optional().Default("")` | `optional string gold_product_type` | `String goldProductType` |
| 16 | `GoldQuantity` | `*float64` | `Float64().Optional().Nillable()` | `optional double gold_quantity` | `double? goldQuantity` |
| 17 | `GoldBuyPriceCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 gold_buy_price_cents` | `int? goldBuyPriceCents` |
| 18 | `GoldCurrentPriceCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 gold_current_price_cents` | `int? goldCurrentPriceCents` |
| 19 | `EstatePurchasePriceCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 estate_purchase_price_cents` | `int? estatePurchasePriceCents` |
| 20 | `EstateCurrentValueCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 estate_current_value_cents` | `int? estateCurrentValueCents` |
| 21 | `EstatePurchaseDate` | `*time.Time` | `Time().Optional().Nillable()` | `.Timestamp estate_purchase_date` | `DateTime? estatePurchaseDate` |
| 22 | `EstateDepreciationRate` | `*float64` | `Float64().Optional().Nillable()` | `optional double estate_depreciation_rate` | `double? estateDepreciationRate` |
| 23 | `LoanOriginalCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 loan_original_cents` | `int? loanOriginalCents` |
| 24 | `LoanRemainingCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 loan_remaining_cents` | `int? loanRemainingCents` |
| 25 | `LoanMonthlyCents` | `*int64` | `Int64().Optional().Nillable()` | `optional int64 loan_monthly_cents` | `int? loanMonthlyCents` |
| 26 | `LoanNextPaymentDate` | `*time.Time` | `Time().Optional().Nillable()` | `.Timestamp loan_next_payment_date` | `DateTime? loanNextPaymentDate` |

**proto 字段号（连续，向后兼容）:**
- `AccountDTO`: 19–44（#1→19, #2→20, … #26→44）
- `CreateAccountRequest`: 13–38（#1→13, … #26→38）
- `UpdateAccountRequest`: `optional AccountStatus status = 9;` + #1→10 … #26→35

**domain 字段名清单（Go，复制用）:**
`CardNumberTail, Notes, OpeningDate, InterestRate, CreditBillingDay, CreditRepaymentDay, CreditAnnualFeeCents, InvestCostCents, InvestMarketValueCents, InvestReturnYtd, FixedPrincipalCents, FixedStartDate, FixedMaturityDate, FixedTermMonths, GoldProductType, GoldQuantity, GoldBuyPriceCents, GoldCurrentPriceCents, EstatePurchasePriceCents, EstateCurrentValueCents, EstatePurchaseDate, EstateDepreciationRate, LoanOriginalCents, LoanRemainingCents, LoanMonthlyCents, LoanNextPaymentDate`

---

## §设计决策（实现前必读）

1. **`AccountProfile` domain 值对象**：26 字段 + `Name/Icon/Color/ChartCode/Institution/CreditLimitCents/Status`，全用指针（`nil`=不提供/不更新）。domain 方法 `ApplyProfile(p *AccountProfile)` 统一 create 灌入 + update 应用，避免 `UpdateDetails` 扩到 30+ 参数。`UpdateDetails`（6 参数）保留兼容。
2. **关闭账户** = `Archive()`（`status=archived`，无 `deleted_at`，详情可查）；**删除账户** = `SoftDelete()`（`archived` + `deleted_at`，已有）。关闭通过 `UpdateAccountRequest.status=archived` 触发（扩 proto）。
3. **复制账户** = 客户端 seed 模式：打开 `AccountFormPage(existing: account.copyWith(id: '', version: 0))`，预填字段但走创建流程。无需服务端支持。
4. **主金额语义随 category**（spec §2）：AmountInput label 动态，存到对应字段（非统一 `InitialBalanceCents`）：
   - 储蓄/其他资产/其他负债/信用卡 → `InitialBalanceCents`（已有；信用卡 currentBalance 初始为负）
   - 投资 → `InvestCostCents`
   - 定期 → `FixedPrincipalCents`
   - 黄金外汇 → `GoldBuyPriceCents`
   - 固定资产 → `EstatePurchasePriceCents`
   - 贷款 → `LoanRemainingCents`（原始本金另填 `LoanOriginalCents`）
5. **利率字段语义随 category**（同一 `interestRateCtrl`，`_submit` 按 category 映射）：
   - 储蓄/定期/贷款/信用卡 → `InterestRate`
   - 投资 → `InvestReturnYtd`
   - 固定资产 → `EstateDepreciationRate`
6. **占位策略**：account 操作（编辑/复制/关闭/删除/Hero/详情路由）真实；记一笔/转账/统计/流水/持仓/还款计划 UI 完整但 disabled + "待 Transaction/Holding 模块"提示。
7. **函数参数 ≤5**：domain update 用 struct 传参（`AccountProfile`），不堆参数。

---

# Part A: 服务端（Tasks 1-7）

## Task 1: domain Account 加 26 字段 + AccountProfile 值对象 + ApplyProfile

**Files:**
- Modify: `yucai/server/internal/account/domain/entity.go`
- Test: `yucai/server/internal/account/domain/domain_test.go`（追加）

- [ ] **Step 1: 写失败测试**

追加到 `domain_test.go`：

```go
func TestApplyProfileSetsNullableFields(t *testing.T) {
	a, _ := NewAccountWithCategory(uuid.New(), "信用卡测试", AccountCategoryCreditCard, "CNY")
	rate := 18.25
	day := 9
	limit := int64(800000)
	tail := "2840"
	p := &AccountProfile{
		CardNumberTail:    &tail,
		InterestRate:      &rate,
		CreditBillingDay:  &day,
		CreditLimitCents:  &limit,
	}
	a.ApplyProfile(p)
	if a.CardNumberTail != "2840" {
		t.Errorf("CardNumberTail not set, got %q", a.CardNumberTail)
	}
	if a.InterestRate == nil || *a.InterestRate != 18.25 {
		t.Error("InterestRate not set")
	}
	if a.CreditBillingDay == nil || *a.CreditBillingDay != 9 {
		t.Error("CreditBillingDay not set")
	}
	if a.CreditLimitCents != 800000 {
		t.Errorf("CreditLimitCents not set, got %d", a.CreditLimitCents)
	}
}

func TestApplyProfileNilFieldsSkipped(t *testing.T) {
	a, _ := NewAccountWithCategory(uuid.New(), "贷款", AccountCategoryLoan, "CNY")
	a.ApplyProfile(&AccountProfile{}) // 全 nil，无 panic
	if a.InterestRate != nil || a.LoanRemainingCents != nil || a.CreditBillingDay != nil {
		t.Error("nil profile fields should leave account fields untouched")
	}
}

func TestArchiveSetsStatusWithoutDelete(t *testing.T) {
	a, _ := NewAccountWithCategory(uuid.New(), "x", AccountCategorySavings, "CNY")
	a.Archive()
	if a.Status != AccountStatusArchived {
		t.Error("Archive should set status to archived")
	}
	if a.DeletedAt != nil {
		t.Error("Archive must NOT set DeletedAt (that's SoftDelete)")
	}
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd yucai/server && go test ./internal/account/domain/ -run TestApplyProfile -v`
Expected: FAIL（`AccountProfile` undefined）

- [ ] **Step 3: 实现 26 字段 + AccountProfile + ApplyProfile**

`entity.go` — 在 `Account` struct 的 `CreditLimitCents` 字段之后、`Status` 之前，插入 26 字段（**完整**，含注释）：

```go
	CardNumberTail         string   // 卡号/账号尾号（金融类）
	Notes                  string   // 备注
	OpeningDate            *time.Time // 开户日期
	InterestRate           *float64 // 年化利率(%)：储蓄/定期/贷款利率、信用卡APR
	CreditBillingDay       *int     // 信用卡账单日（1-31）
	CreditRepaymentDay     *int     // 信用卡还款日（1-31）
	CreditAnnualFeeCents   *int64   // 信用卡年费
	InvestCostCents        *int64   // 投资投入成本
	InvestMarketValueCents *int64   // 投资当前市值
	InvestReturnYtd        *float64 // 投资今年收益率(%)
	FixedPrincipalCents    *int64   // 定期本金
	FixedStartDate         *time.Time // 定期起息日
	FixedMaturityDate      *time.Time // 定期到期日
	FixedTermMonths        *int     // 定期期限（月）
	GoldProductType        string   // 黄金外汇品种（如实物黄金/USD）
	GoldQuantity           *float64 // 黄金外汇持有数量
	GoldBuyPriceCents      *int64   // 黄金外汇买入价
	GoldCurrentPriceCents  *int64   // 黄金外汇现价
	EstatePurchasePriceCents *int64 // 固定资产买入价
	EstateCurrentValueCents  *int64 // 固定资产现估值
	EstatePurchaseDate     *time.Time // 固定资产买入日期
	EstateDepreciationRate *float64 // 固定资产折旧率(%)
	LoanOriginalCents      *int64   // 贷款原始本金
	LoanRemainingCents     *int64   // 贷款剩余本金
	LoanMonthlyCents       *int64   // 贷款月供
	LoanNextPaymentDate    *time.Time // 贷款下次还款日
```

在 `entity.go` 末尾（`IncrementVersion` 之后）加 `AccountProfile` + `ApplyProfile`：

```go
// AccountProfile 是账户可编辑字段的值对象（全指针，nil=不提供/不更新）。
// 用于统一 create 灌入 + update 应用，避免大参数列表。
type AccountProfile struct {
	Name                 *string
	Icon                 *string
	Color                *string
	ChartCode            *string
	Institution          *string
	CreditLimitCents     *int64
	Status               *AccountStatus
	CardNumberTail       *string
	Notes                *string
	OpeningDate          *time.Time
	InterestRate         *float64
	CreditBillingDay     *int
	CreditRepaymentDay   *int
	CreditAnnualFeeCents *int64
	InvestCostCents      *int64
	InvestMarketValueCents *int64
	InvestReturnYtd      *float64
	FixedPrincipalCents  *int64
	FixedStartDate       *time.Time
	FixedMaturityDate    *time.Time
	FixedTermMonths      *int
	GoldProductType      *string
	GoldQuantity         *float64
	GoldBuyPriceCents    *int64
	GoldCurrentPriceCents *int64
	EstatePurchasePriceCents *int64
	EstateCurrentValueCents *int64
	EstatePurchaseDate   *time.Time
	EstateDepreciationRate *float64
	LoanOriginalCents    *int64
	LoanRemainingCents   *int64
	LoanMonthlyCents     *int64
	LoanNextPaymentDate  *time.Time
}

// ApplyProfile 把非 nil 字段应用到账户。create 时全量灌入；update 时部分更新。
func (a *Account) ApplyProfile(p *AccountProfile) {
	if p == nil {
		return
	}
	if p.Name != nil { a.Name = strings.TrimSpace(*p.Name) }
	if p.Icon != nil { a.Icon = *p.Icon }
	if p.Color != nil { a.Color = *p.Color }
	if p.ChartCode != nil { a.ChartCode = *p.ChartCode }
	if p.Institution != nil { a.Institution = *p.Institution }
	if p.CreditLimitCents != nil { a.CreditLimitCents = *p.CreditLimitCents }
	if p.Status != nil { a.Status = *p.Status }
	if p.CardNumberTail != nil { a.CardNumberTail = *p.CardNumberTail }
	if p.Notes != nil { a.Notes = *p.Notes }
	if p.OpeningDate != nil { a.OpeningDate = p.OpeningDate }
	if p.InterestRate != nil { a.InterestRate = p.InterestRate }
	if p.CreditBillingDay != nil { a.CreditBillingDay = p.CreditBillingDay }
	if p.CreditRepaymentDay != nil { a.CreditRepaymentDay = p.CreditRepaymentDay }
	if p.CreditAnnualFeeCents != nil { a.CreditAnnualFeeCents = p.CreditAnnualFeeCents }
	if p.InvestCostCents != nil { a.InvestCostCents = p.InvestCostCents }
	if p.InvestMarketValueCents != nil { a.InvestMarketValueCents = p.InvestMarketValueCents }
	if p.InvestReturnYtd != nil { a.InvestReturnYtd = p.InvestReturnYtd }
	if p.FixedPrincipalCents != nil { a.FixedPrincipalCents = p.FixedPrincipalCents }
	if p.FixedStartDate != nil { a.FixedStartDate = p.FixedStartDate }
	if p.FixedMaturityDate != nil { a.FixedMaturityDate = p.FixedMaturityDate }
	if p.FixedTermMonths != nil { a.FixedTermMonths = p.FixedTermMonths }
	if p.GoldProductType != nil { a.GoldProductType = *p.GoldProductType }
	if p.GoldQuantity != nil { a.GoldQuantity = p.GoldQuantity }
	if p.GoldBuyPriceCents != nil { a.GoldBuyPriceCents = p.GoldBuyPriceCents }
	if p.GoldCurrentPriceCents != nil { a.GoldCurrentPriceCents = p.GoldCurrentPriceCents }
	if p.EstatePurchasePriceCents != nil { a.EstatePurchasePriceCents = p.EstatePurchasePriceCents }
	if p.EstateCurrentValueCents != nil { a.EstateCurrentValueCents = p.EstateCurrentValueCents }
	if p.EstatePurchaseDate != nil { a.EstatePurchaseDate = p.EstatePurchaseDate }
	if p.EstateDepreciationRate != nil { a.EstateDepreciationRate = p.EstateDepreciationRate }
	if p.LoanOriginalCents != nil { a.LoanOriginalCents = p.LoanOriginalCents }
	if p.LoanRemainingCents != nil { a.LoanRemainingCents = p.LoanRemainingCents }
	if p.LoanMonthlyCents != nil { a.LoanMonthlyCents = p.LoanMonthlyCents }
	if p.LoanNextPaymentDate != nil { a.LoanNextPaymentDate = p.LoanNextPaymentDate }
	a.UpdatedAt = time.Now()
}
```

> 旧 `UpdateDetails`（6 参数）保持不变（兼容旧调用；新代码用 `ApplyProfile`）。

- [ ] **Step 4: 运行确认通过**

Run: `cd yucai/server && go test ./internal/account/domain/ -v`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add yucai/server/internal/account/domain/entity.go yucai/server/internal/account/domain/domain_test.go
git commit -m "feat(account): domain 26 类型专属字段(category前缀) + AccountProfile/ApplyProfile"
```

---

## Task 2: ent schema 26 nullable 字段 + 生成

**Files:**
- Modify: `yucai/server/internal/account/ent/schema/account.go`

- [ ] **Step 1: 加 26 字段**

在 `Fields()` 的 `credit_limit_cents` 字段之后、`status` 之前插入（**完整**，含注释；参考字段总表）：

```go
		field.String("card_number_tail").Optional().Default("").Comment("Card/account last digits (financial types)"),
		field.String("notes").Optional().Default("").Comment("Free-form notes"),
		field.Time("opening_date").Optional().Nillable().Comment("Account opening date (financial types)"),
		field.Float64("interest_rate").Optional().Nillable().Comment("Annual rate %: savings/fixed/loan rate, credit card APR"),
		field.Int("credit_billing_day").Optional().Nillable().Comment("Credit card billing day (1-31)"),
		field.Int("credit_repayment_day").Optional().Nillable().Comment("Credit card repayment day (1-31)"),
		field.Int64("credit_annual_fee_cents").Optional().Nillable().Comment("Credit card annual fee in cents"),
		field.Int64("invest_cost_cents").Optional().Nillable().Comment("Investment total cost basis in cents"),
		field.Int64("invest_market_value_cents").Optional().Nillable().Comment("Investment current market value in cents"),
		field.Float64("invest_return_ytd").Optional().Nillable().Comment("Investment year-to-date return rate (%)"),
		field.Int64("fixed_principal_cents").Optional().Nillable().Comment("Fixed deposit principal in cents"),
		field.Time("fixed_start_date").Optional().Nillable().Comment("Fixed deposit start (value) date"),
		field.Time("fixed_maturity_date").Optional().Nillable().Comment("Fixed deposit maturity date"),
		field.Int("fixed_term_months").Optional().Nillable().Comment("Fixed deposit term in months"),
		field.String("gold_product_type").Optional().Default("").Comment("Gold/FX product type (e.g. gold, usd)"),
		field.Float64("gold_quantity").Optional().Nillable().Comment("Gold/FX holding quantity"),
		field.Int64("gold_buy_price_cents").Optional().Nillable().Comment("Gold/FX buy price in cents"),
		field.Int64("gold_current_price_cents").Optional().Nillable().Comment("Gold/FX current price in cents"),
		field.Int64("estate_purchase_price_cents").Optional().Nillable().Comment("Real estate purchase price in cents"),
		field.Int64("estate_current_value_cents").Optional().Nillable().Comment("Real estate current appraised value in cents"),
		field.Time("estate_purchase_date").Optional().Nillable().Comment("Real estate purchase date"),
		field.Float64("estate_depreciation_rate").Optional().Nillable().Comment("Real estate depreciation rate (%)"),
		field.Int64("loan_original_cents").Optional().Nillable().Comment("Loan original principal in cents"),
		field.Int64("loan_remaining_cents").Optional().Nillable().Comment("Loan remaining principal in cents"),
		field.Int64("loan_monthly_cents").Optional().Nillable().Comment("Loan monthly payment in cents"),
		field.Time("loan_next_payment_date").Optional().Nillable().Comment("Loan next payment date"),
```

- [ ] **Step 2: 生成 ent 代码**

Run: `cd yucai && make generate`
Expected: 无错误。

- [ ] **Step 3: 编译验证**

Run: `cd yucai/server && go build ./...`
Expected: 无错误。

- [ ] **Step 4: 提交**

```bash
git add yucai/server/internal/account/ent/schema/account.go yucai/server/internal/account/ent/
git commit -m "feat(account): ent schema 26 类型专属 nullable 字段(category前缀)"
```

---

## Task 3: proto 26 字段 + status + 生成（两端）

**Files:**
- Modify: `yucai/proto/account/v1/account.proto`

- [ ] **Step 1: 确认 Timestamp import**

`account.proto` 顶部 import 区确认有（若无则加）：`import "google/protobuf/timestamp.proto";`

- [ ] **Step 2: AccountDTO 加 26 字段（19-44）**

在 `AccountDTO`（`category = 18;` 之后，message 结束 `}` 之前）加：

```protobuf
  optional string card_number_tail = 19;
  optional string notes = 20;
  google.protobuf.Timestamp opening_date = 21;
  optional double interest_rate = 22;
  optional int32 credit_billing_day = 23;
  optional int32 credit_repayment_day = 24;
  optional int64 credit_annual_fee_cents = 25;
  optional int64 invest_cost_cents = 26;
  optional int64 invest_market_value_cents = 27;
  optional double invest_return_ytd = 28;
  optional int64 fixed_principal_cents = 29;
  google.protobuf.Timestamp fixed_start_date = 30;
  google.protobuf.Timestamp fixed_maturity_date = 31;
  optional int32 fixed_term_months = 32;
  optional string gold_product_type = 33;
  optional double gold_quantity = 34;
  optional int64 gold_buy_price_cents = 35;
  optional int64 gold_current_price_cents = 36;
  optional int64 estate_purchase_price_cents = 37;
  optional int64 estate_current_value_cents = 38;
  google.protobuf.Timestamp estate_purchase_date = 39;
  optional double estate_depreciation_rate = 40;
  optional int64 loan_original_cents = 41;
  optional int64 loan_remaining_cents = 42;
  optional int64 loan_monthly_cents = 43;
  google.protobuf.Timestamp loan_next_payment_date = 44;
```

- [ ] **Step 3: CreateAccountRequest 加 26 字段（13-38）**

在 `CreateAccountRequest`（`category = 12;` 之后）加：

```protobuf
  optional string card_number_tail = 13;
  optional string notes = 14;
  google.protobuf.Timestamp opening_date = 15;
  optional double interest_rate = 16;
  optional int32 credit_billing_day = 17;
  optional int32 credit_repayment_day = 18;
  optional int64 credit_annual_fee_cents = 19;
  optional int64 invest_cost_cents = 20;
  optional int64 invest_market_value_cents = 21;
  optional double invest_return_ytd = 22;
  optional int64 fixed_principal_cents = 23;
  google.protobuf.Timestamp fixed_start_date = 24;
  google.protobuf.Timestamp fixed_maturity_date = 25;
  optional int32 fixed_term_months = 26;
  optional string gold_product_type = 27;
  optional double gold_quantity = 28;
  optional int64 gold_buy_price_cents = 29;
  optional int64 gold_current_price_cents = 30;
  optional int64 estate_purchase_price_cents = 31;
  optional int64 estate_current_value_cents = 32;
  google.protobuf.Timestamp estate_purchase_date = 33;
  optional double estate_depreciation_rate = 34;
  optional int64 loan_original_cents = 35;
  optional int64 loan_remaining_cents = 36;
  optional int64 loan_monthly_cents = 37;
  google.protobuf.Timestamp loan_next_payment_date = 38;
```

- [ ] **Step 4: UpdateAccountRequest 加 status(9) + 26 字段（10-35）**

在 `UpdateAccountRequest`（`version = 8;` 之后）加：

```protobuf
  optional AccountStatus status = 9;
  optional string card_number_tail = 10;
  optional string notes = 11;
  google.protobuf.Timestamp opening_date = 12;
  optional double interest_rate = 13;
  optional int32 credit_billing_day = 14;
  optional int32 credit_repayment_day = 15;
  optional int64 credit_annual_fee_cents = 16;
  optional int64 invest_cost_cents = 17;
  optional int64 invest_market_value_cents = 18;
  optional double invest_return_ytd = 19;
  optional int64 fixed_principal_cents = 20;
  google.protobuf.Timestamp fixed_start_date = 21;
  google.protobuf.Timestamp fixed_maturity_date = 22;
  optional int32 fixed_term_months = 23;
  optional string gold_product_type = 24;
  optional double gold_quantity = 25;
  optional int64 gold_buy_price_cents = 26;
  optional int64 gold_current_price_cents = 27;
  optional int64 estate_purchase_price_cents = 28;
  optional int64 estate_current_value_cents = 29;
  google.protobuf.Timestamp estate_purchase_date = 30;
  optional double estate_depreciation_rate = 31;
  optional int64 loan_original_cents = 32;
  optional int64 loan_remaining_cents = 33;
  optional int64 loan_monthly_cents = 34;
  google.protobuf.Timestamp loan_next_payment_date = 35;
```

- [ ] **Step 5: 生成 Go + Dart stubs**

Run: `cd yucai && make proto`
Expected: 无错误。

- [ ] **Step 6: 编译验证**

Run: `cd yucai/server && go build ./...`
Expected: 无错误。

- [ ] **Step 7: 提交**

```bash
git add yucai/proto/account/v1/account.proto yucai/server/internal/proto/account/v1/ yucai/client/lib/proto/account/v1/
git commit -m "feat(account): proto 26 类型专属字段(category前缀) + UpdateAccountRequest.status"
```

---

## Task 4: application dto/commands 加 26 字段 + Profile 映射

**Files:**
- Modify: `yucai/server/internal/account/application/dto.go`
- Modify: `yucai/server/internal/account/application/command/commands.go`

- [ ] **Step 1: dto.go 确认 import time**

`dto.go` 顶部确认 `import "time"`，若无则加。

- [ ] **Step 2: CreateAccountRequest 加 26 字段**

在 `CreateAccountRequest` 的 `CreditLimitCents int64` 之后加（全指针；string 用 `*string` 与 AccountProfile 对齐）：

```go
	CardNumberTail         *string
	Notes                  *string
	OpeningDate            *time.Time
	InterestRate           *float64
	CreditBillingDay       *int
	CreditRepaymentDay     *int
	CreditAnnualFeeCents   *int64
	InvestCostCents        *int64
	InvestMarketValueCents *int64
	InvestReturnYtd        *float64
	FixedPrincipalCents    *int64
	FixedStartDate         *time.Time
	FixedMaturityDate      *time.Time
	FixedTermMonths        *int
	GoldProductType        *string
	GoldQuantity           *float64
	GoldBuyPriceCents      *int64
	GoldCurrentPriceCents  *int64
	EstatePurchasePriceCents *int64
	EstateCurrentValueCents *int64
	EstatePurchaseDate     *time.Time
	EstateDepreciationRate *float64
	LoanOriginalCents      *int64
	LoanRemainingCents     *int64
	LoanMonthlyCents       *int64
	LoanNextPaymentDate    *time.Time
```

- [ ] **Step 3: UpdateAccountRequest 加 status + 26 字段**

在 `UpdateAccountRequest` 的 `CreditLimitCents int64` 之后加 `Status *domain.AccountStatus` + 与 Step2 相同的 26 字段块。

- [ ] **Step 4: AccountDTO 加 26 字段**

在 `AccountDTO` 的 `CreditLimitCents int64` 之后加（domain 类型，string 非指针）：

```go
	CardNumberTail         string
	Notes                  string
	OpeningDate            *time.Time
	InterestRate           *float64
	CreditBillingDay       *int
	CreditRepaymentDay     *int
	CreditAnnualFeeCents   *int64
	InvestCostCents        *int64
	InvestMarketValueCents *int64
	InvestReturnYtd        *float64
	FixedPrincipalCents    *int64
	FixedStartDate         *time.Time
	FixedMaturityDate      *time.Time
	FixedTermMonths        *int
	GoldProductType        string
	GoldQuantity           *float64
	GoldBuyPriceCents      *int64
	GoldCurrentPriceCents  *int64
	EstatePurchasePriceCents *int64
	EstateCurrentValueCents *int64
	EstatePurchaseDate     *time.Time
	EstateDepreciationRate *float64
	LoanOriginalCents      *int64
	LoanRemainingCents     *int64
	LoanMonthlyCents       *int64
	LoanNextPaymentDate    *time.Time
```

- [ ] **Step 5: AccountToDTO 加 26 行映射**

在 `AccountToDTO` 的 `CreditLimitCents: a.CreditLimitCents,` 之后加：

```go
		CardNumberTail:         a.CardNumberTail,
		Notes:                  a.Notes,
		OpeningDate:            a.OpeningDate,
		InterestRate:           a.InterestRate,
		CreditBillingDay:       a.CreditBillingDay,
		CreditRepaymentDay:     a.CreditRepaymentDay,
		CreditAnnualFeeCents:   a.CreditAnnualFeeCents,
		InvestCostCents:        a.InvestCostCents,
		InvestMarketValueCents: a.InvestMarketValueCents,
		InvestReturnYtd:        a.InvestReturnYtd,
		FixedPrincipalCents:    a.FixedPrincipalCents,
		FixedStartDate:         a.FixedStartDate,
		FixedMaturityDate:      a.FixedMaturityDate,
		FixedTermMonths:        a.FixedTermMonths,
		GoldProductType:        a.GoldProductType,
		GoldQuantity:           a.GoldQuantity,
		GoldBuyPriceCents:      a.GoldBuyPriceCents,
		GoldCurrentPriceCents:  a.GoldCurrentPriceCents,
		EstatePurchasePriceCents: a.EstatePurchasePriceCents,
		EstateCurrentValueCents: a.EstateCurrentValueCents,
		EstatePurchaseDate:     a.EstatePurchaseDate,
		EstateDepreciationRate: a.EstateDepreciationRate,
		LoanOriginalCents:      a.LoanOriginalCents,
		LoanRemainingCents:     a.LoanRemainingCents,
		LoanMonthlyCents:       a.LoanMonthlyCents,
		LoanNextPaymentDate:    a.LoanNextPaymentDate,
```

- [ ] **Step 6: 新增 CreateRequestToProfile / UpdateRequestToProfile helper**

在 `AccountToDTO` 之后加：

```go
// CreateRequestToProfile 把 CreateAccountRequest 的可编辑字段映射到 domain AccountProfile。
func CreateRequestToProfile(req CreateAccountRequest) *domain.AccountProfile {
	return &domain.AccountProfile{
		Name: strPtr(req.Name), Icon: strPtr(req.Icon), Color: strPtr(req.Color),
		ChartCode: strPtr(req.ChartCode), Institution: strPtr(req.Institution),
		CreditLimitCents: &req.CreditLimitCents,
		CardNumberTail: req.CardNumberTail, Notes: req.Notes, OpeningDate: req.OpeningDate,
		InterestRate: req.InterestRate, CreditBillingDay: req.CreditBillingDay,
		CreditRepaymentDay: req.CreditRepaymentDay, CreditAnnualFeeCents: req.CreditAnnualFeeCents,
		InvestCostCents: req.InvestCostCents, InvestMarketValueCents: req.InvestMarketValueCents,
		InvestReturnYtd: req.InvestReturnYtd, FixedPrincipalCents: req.FixedPrincipalCents,
		FixedStartDate: req.FixedStartDate, FixedMaturityDate: req.FixedMaturityDate,
		FixedTermMonths: req.FixedTermMonths, GoldProductType: req.GoldProductType,
		GoldQuantity: req.GoldQuantity, GoldBuyPriceCents: req.GoldBuyPriceCents,
		GoldCurrentPriceCents: req.GoldCurrentPriceCents,
		EstatePurchasePriceCents: req.EstatePurchasePriceCents,
		EstateCurrentValueCents: req.EstateCurrentValueCents,
		EstatePurchaseDate: req.EstatePurchaseDate, EstateDepreciationRate: req.EstateDepreciationRate,
		LoanOriginalCents: req.LoanOriginalCents, LoanRemainingCents: req.LoanRemainingCents,
		LoanMonthlyCents: req.LoanMonthlyCents, LoanNextPaymentDate: req.LoanNextPaymentDate,
	}
}

// UpdateRequestToProfile 把 UpdateAccountRequest 映射到 domain AccountProfile。
func UpdateRequestToProfile(req UpdateAccountRequest) *domain.AccountProfile {
	return &domain.AccountProfile{
		Name: strPtr(req.Name), Icon: strPtr(req.Icon), Color: strPtr(req.Color),
		ChartCode: strPtr(req.ChartCode), Institution: strPtr(req.Institution),
		CreditLimitCents: &req.CreditLimitCents, Status: req.Status,
		CardNumberTail: req.CardNumberTail, Notes: req.Notes, OpeningDate: req.OpeningDate,
		InterestRate: req.InterestRate, CreditBillingDay: req.CreditBillingDay,
		CreditRepaymentDay: req.CreditRepaymentDay, CreditAnnualFeeCents: req.CreditAnnualFeeCents,
		InvestCostCents: req.InvestCostCents, InvestMarketValueCents: req.InvestMarketValueCents,
		InvestReturnYtd: req.InvestReturnYtd, FixedPrincipalCents: req.FixedPrincipalCents,
		FixedStartDate: req.FixedStartDate, FixedMaturityDate: req.FixedMaturityDate,
		FixedTermMonths: req.FixedTermMonths, GoldProductType: req.GoldProductType,
		GoldQuantity: req.GoldQuantity, GoldBuyPriceCents: req.GoldBuyPriceCents,
		GoldCurrentPriceCents: req.GoldCurrentPriceCents,
		EstatePurchasePriceCents: req.EstatePurchasePriceCents,
		EstateCurrentValueCents: req.EstateCurrentValueCents,
		EstatePurchaseDate: req.EstatePurchaseDate, EstateDepreciationRate: req.EstateDepreciationRate,
		LoanOriginalCents: req.LoanOriginalCents, LoanRemainingCents: req.LoanRemainingCents,
		LoanMonthlyCents: req.LoanMonthlyCents, LoanNextPaymentDate: req.LoanNextPaymentDate,
	}
}

func strPtr(s string) *string { return &s }
```

- [ ] **Step 7: commands.go 同步加字段**

`CreateAccountCommand` 加 Step2 的 26 字段块；`UpdateAccountCommand` 加 `Status` + Step3 的字段块（保持与 Request 对称）。

- [ ] **Step 8: 编译验证**

Run: `cd yucai/server && go build ./...`
Expected: 无错误。

- [ ] **Step 9: 提交**

```bash
git add yucai/server/internal/account/application/dto.go yucai/server/internal/account/application/command/commands.go
git commit -m "feat(account): application dto/commands 加 26 字段 + Profile 映射 helper"
```

---

## Task 5: service CreateAccount/UpdateAccount 用 ApplyProfile + 关闭

**Files:**
- Modify: `yucai/server/internal/account/application/service.go`
- Test: `yucai/server/internal/account/application/service_test.go`（追加）

- [ ] **Step 1: 写失败测试**

追加到 `service_test.go`（对齐现有 mock helper 名 `newMockAccountRepo`/`newMockChartRepo`，若不同则按现有风格）：

```go
func TestCreateAccountPersistsTypeSpecificFields(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	rate := 1.9
	tail := "2840"
	req := CreateAccountRequest{
		TenantID: uuid.New(), Name: "招行储蓄", Category: domain.AccountCategorySavings, CurrencyCode: "CNY",
		CardNumberTail: &tail, InterestRate: &rate,
	}
	dto, err := svc.CreateAccount(context.Background(), req)
	if err != nil {
		t.Fatal(err)
	}
	if dto.CardNumberTail != "2840" || dto.InterestRate == nil || *dto.InterestRate != 1.9 {
		t.Errorf("type-specific fields not persisted: %+v", dto)
	}
}

func TestUpdateAccountClosesAccount(t *testing.T) {
	repo := newMockAccountRepo()
	svc := NewService(repo, newMockChartRepo())
	created, _ := svc.CreateAccount(context.Background(), CreateAccountRequest{
		TenantID: uuid.New(), Name: "x", Category: domain.AccountCategorySavings, CurrencyCode: "CNY",
	})
	archived := domain.AccountStatusArchived
	_, err := svc.UpdateAccount(context.Background(), UpdateAccountRequest{
		TenantID: created.TenantID, AccountID: created.ID, Version: created.Version, Status: &archived,
	})
	if err != nil {
		t.Fatal(err)
	}
	got, _ := svc.GetAccount(context.Background(), created.TenantID, created.ID)
	if got.Status != domain.AccountStatusArchived {
		t.Errorf("close via status=archived failed, got %v", got.Status)
	}
}
```

- [ ] **Step 2: 运行确认失败**

Run: `cd yucai/server && go test ./internal/account/application/ -run TestCreateAccountPersistsTypeSpecificFields -v`
Expected: FAIL

- [ ] **Step 3: CreateAccount 用 ApplyProfile**

`service.go` 的 `CreateAccount`：在 `NewAccountWithCategory(...)` 之后、`Save` 之前：

```go
	account.ApplyProfile(CreateRequestToProfile(req))
	ApplyCreateDefaults(account, req) // InitialBalance/Ownership 兜底（字段集与 ApplyProfile 不冲突）
```

- [ ] **Step 4: UpdateAccount 用 ApplyProfile + status 关闭**

`service.go` 的 `UpdateAccount`：把 `account.UpdateDetails(req.Name, ...)` 行替换为：

```go
	account.ApplyProfile(UpdateRequestToProfile(req))
	if req.Status != nil && *req.Status == domain.AccountStatusArchived {
		account.Archive()
	}
```

> 保留 `ValidateUpdateVersion` + `IncrementVersion` + `s.accountRepo.Update(ctx, account)` 不变。

- [ ] **Step 5: 运行确认通过**

Run: `cd yucai/server && go test ./internal/account/application/ -v`
Expected: PASS

- [ ] **Step 6: 提交**

```bash
git add yucai/server/internal/account/application/service.go yucai/server/internal/account/application/service_test.go
git commit -m "feat(account): service CreateAccount/UpdateAccount 用 ApplyProfile + status 关闭"
```

---

## Task 6: repo mapper 26 字段双向 + Save/Update SetXxx

**Files:**
- Modify: `yucai/server/internal/account/adapter/driven/repository/account_repo.go`

- [ ] **Step 1: toDomainAccount 加 26 字段映射**

在 `toDomainAccount` 的 `CreditLimitCents: a.CreditLimitCents,` 之后加（**完整**）：

```go
		CardNumberTail:         a.CardNumberTail,
		Notes:                  a.Notes,
		OpeningDate:            a.OpeningDate,
		InterestRate:           a.InterestRate,
		CreditBillingDay:       a.CreditBillingDay,
		CreditRepaymentDay:     a.CreditRepaymentDay,
		CreditAnnualFeeCents:   a.CreditAnnualFeeCents,
		InvestCostCents:        a.InvestCostCents,
		InvestMarketValueCents: a.InvestMarketValueCents,
		InvestReturnYtd:        a.InvestReturnYtd,
		FixedPrincipalCents:    a.FixedPrincipalCents,
		FixedStartDate:         a.FixedStartDate,
		FixedMaturityDate:      a.FixedMaturityDate,
		FixedTermMonths:        a.FixedTermMonths,
		GoldProductType:        a.GoldProductType,
		GoldQuantity:           a.GoldQuantity,
		GoldBuyPriceCents:      a.GoldBuyPriceCents,
		GoldCurrentPriceCents:  a.GoldCurrentPriceCents,
		EstatePurchasePriceCents: a.EstatePurchasePriceCents,
		EstateCurrentValueCents: a.EstateCurrentValueCents,
		EstatePurchaseDate:     a.EstatePurchaseDate,
		EstateDepreciationRate: a.EstateDepreciationRate,
		LoanOriginalCents:      a.LoanOriginalCents,
		LoanRemainingCents:     a.LoanRemainingCents,
		LoanMonthlyCents:       a.LoanMonthlyCents,
		LoanNextPaymentDate:    a.LoanNextPaymentDate,
```

- [ ] **Step 2: Save 加 26 SetXxx**

在 `Save` 的 builder 链 `SetCreditLimitCents(account.CreditLimitCents).` 之后加（nullable 用 `SetXxxPtr`，string 用 `SetXxx`）：

```go
		SetCardNumberTail(account.CardNumberTail).
		SetNotes(account.Notes).
		SetOpeningDatePtr(account.OpeningDate).
		SetInterestRatePtr(account.InterestRate).
		SetCreditBillingDayPtr(account.CreditBillingDay).
		SetCreditRepaymentDayPtr(account.CreditRepaymentDay).
		SetCreditAnnualFeeCentsPtr(account.CreditAnnualFeeCents).
		SetInvestCostCentsPtr(account.InvestCostCents).
		SetInvestMarketValueCentsPtr(account.InvestMarketValueCents).
		SetInvestReturnYtdPtr(account.InvestReturnYtd).
		SetFixedPrincipalCentsPtr(account.FixedPrincipalCents).
		SetFixedStartDatePtr(account.FixedStartDate).
		SetFixedMaturityDatePtr(account.FixedMaturityDate).
		SetFixedTermMonthsPtr(account.FixedTermMonths).
		SetGoldProductType(account.GoldProductType).
		SetGoldQuantityPtr(account.GoldQuantity).
		SetGoldBuyPriceCentsPtr(account.GoldBuyPriceCents).
		SetGoldCurrentPriceCentsPtr(account.GoldCurrentPriceCents).
		SetEstatePurchasePriceCentsPtr(account.EstatePurchasePriceCents).
		SetEstateCurrentValueCentsPtr(account.EstateCurrentValueCents).
		SetEstatePurchaseDatePtr(account.EstatePurchaseDate).
		SetEstateDepreciationRatePtr(account.EstateDepreciationRate).
		SetLoanOriginalCentsPtr(account.LoanOriginalCents).
		SetLoanRemainingCentsPtr(account.LoanRemainingCents).
		SetLoanMonthlyCentsPtr(account.LoanMonthlyCents).
		SetLoanNextPaymentDatePtr(account.LoanNextPaymentDate).
```

> 注：ent 对 `Optional().Nillable()` 的 `*T` 生成 `SetXxxPtr(*T)`；对 `Optional().Default("")` 的 string 生成 `SetXxx(string)`。执行后确认 setter 名：`grep -n "func.*Set.*Ptr\|func.*SetCardNumberTail\|func.*SetGoldProductType" yucai/server/internal/account/ent/account_create.go`，以生成为准。

- [ ] **Step 3: Update 加 26 SetXxx**

在 `Update` 的 builder 链 `SetCreditLimitCents(a.CreditLimitCents).` 之后加与 Step2 相同的 26 SetXxx 块。

- [ ] **Step 4: 编译 + repo 测试**

Run: `cd yucai/server && go build ./... && go test ./internal/account/... -count=1`
Expected: 编译 OK，测试 PASS。

- [ ] **Step 5: 提交**

```bash
git add yucai/server/internal/account/adapter/driven/repository/account_repo.go
git commit -m "feat(account): repo mapper 26 字段双向 + Save/Update SetXxx"
```

---

## Task 7: grpc handler 26 字段 + status 映射

**Files:**
- Modify: `yucai/server/internal/account/adapter/driving/grpc/account_handler.go`

- [ ] **Step 1: 加转换 helper**

在 handler 文件加（若无）：

```go
import "google.golang.org/protobuf/types/known/timestamppb"

func ts(t *timestamppb.Timestamp) *time.Time { if t == nil { return nil }; v := t.AsTime(); return &v }
func optTs(t *time.Time) *timestamppb.Timestamp { if t == nil { return nil }; return timestamppb.New(*t) }
func optStr(s string) *string { if s == "" { return nil }; return &s }
func i32ToInt(p *int32) *int { if p == nil { return nil }; v := int(*p); return &v }
func intToI32(p *int) *int32 { if p == nil { return nil }; v := int32(*p); return &v }
func statusPtr(p *pb.AccountStatus) *domain.AccountStatus {
	if p == nil { return nil }
	v := protoToAccountStatus(*p); return &v
}
```

- [ ] **Step 2: CreateAccount Request→application 映射加 26 字段**

在 CreateAccount 的 `application.CreateAccountRequest{...}` 构造中，`CreditLimitCents: req.GetCreditLimitCents(),` 之后加（proto optional scalar 是 `*T` 直接赋；int32→int 用 `i32ToInt`；Timestamp 用 `ts`）：

```go
		CardNumberTail: req.CardNumberTail,
		Notes:          req.Notes,
		OpeningDate:    ts(req.OpeningDate),
		InterestRate:   req.InterestRate,
		CreditBillingDay: i32ToInt(req.CreditBillingDay),
		CreditRepaymentDay: i32ToInt(req.CreditRepaymentDay),
		CreditAnnualFeeCents: req.CreditAnnualFeeCents,
		InvestCostCents: req.InvestCostCents,
		InvestMarketValueCents: req.InvestMarketValueCents,
		InvestReturnYtd: req.InvestReturnYtd,
		FixedPrincipalCents: req.FixedPrincipalCents,
		FixedStartDate: ts(req.FixedStartDate),
		FixedMaturityDate: ts(req.FixedMaturityDate),
		FixedTermMonths: i32ToInt(req.FixedTermMonths),
		GoldProductType: req.GoldProductType,
		GoldQuantity: req.GoldQuantity,
		GoldBuyPriceCents: req.GoldBuyPriceCents,
		GoldCurrentPriceCents: req.GoldCurrentPriceCents,
		EstatePurchasePriceCents: req.EstatePurchasePriceCents,
		EstateCurrentValueCents: req.EstateCurrentValueCents,
		EstatePurchaseDate: ts(req.EstatePurchaseDate),
		EstateDepreciationRate: req.EstateDepreciationRate,
		LoanOriginalCents: req.LoanOriginalCents,
		LoanRemainingCents: req.LoanRemainingCents,
		LoanMonthlyCents: req.LoanMonthlyCents,
		LoanNextPaymentDate: ts(req.LoanNextPaymentDate),
```

- [ ] **Step 3: UpdateAccount Request→application 映射加 status + 26 字段**

在 UpdateAccount 的 `application.UpdateAccountRequest{...}` 构造中，`CreditLimitCents: req.GetCreditLimitCents(),` 之后加 `Status: statusPtr(req.Status),` + 与 Step2 相同的 26 字段块。

- [ ] **Step 4: dtoToProto 加 26 字段**

在 `dtoToProto` 的 `CreditLimitCents: a.CreditLimitCents,` 之后加（domain `*int64`/`*float64`/`*string` 直接赋 proto optional 同类型；`*int`→`*int32` 用 `intToI32`；`*time.Time`→Timestamp 用 `optTs`；string 用 `optStr`）：

```go
		CardNumberTail: optStr(a.CardNumberTail),
		Notes:          optStr(a.Notes),
		OpeningDate:    optTs(a.OpeningDate),
		InterestRate:   a.InterestRate,
		CreditBillingDay: intToI32(a.CreditBillingDay),
		CreditRepaymentDay: intToI32(a.CreditRepaymentDay),
		CreditAnnualFeeCents: a.CreditAnnualFeeCents,
		InvestCostCents: a.InvestCostCents,
		InvestMarketValueCents: a.InvestMarketValueCents,
		InvestReturnYtd: a.InvestReturnYtd,
		FixedPrincipalCents: a.FixedPrincipalCents,
		FixedStartDate: optTs(a.FixedStartDate),
		FixedMaturityDate: optTs(a.FixedMaturityDate),
		FixedTermMonths: intToI32(a.FixedTermMonths),
		GoldProductType: optStr(a.GoldProductType),
		GoldQuantity: a.GoldQuantity,
		GoldBuyPriceCents: a.GoldBuyPriceCents,
		GoldCurrentPriceCents: a.GoldCurrentPriceCents,
		EstatePurchasePriceCents: a.EstatePurchasePriceCents,
		EstateCurrentValueCents: a.EstateCurrentValueCents,
		EstatePurchaseDate: optTs(a.EstatePurchaseDate),
		EstateDepreciationRate: a.EstateDepreciationRate,
		LoanOriginalCents: a.LoanOriginalCents,
		LoanRemainingCents: a.LoanRemainingCents,
		LoanMonthlyCents: a.LoanMonthlyCents,
		LoanNextPaymentDate: optTs(a.LoanNextPaymentDate),
```

- [ ] **Step 5: 编译 + 全量服务端测试**

Run: `cd yucai/server && go build ./... && go test ./... -count=1`
Expected: 全部 PASS。

- [ ] **Step 6: 提交**

```bash
git add yucai/server/internal/account/adapter/driving/grpc/account_handler.go
git commit -m "feat(account): grpc handler 26 字段 + status 双向映射"
```

---

# Part B: 客户端 data/domain（Tasks 8-11）

> 前置：Task 3 已 `make proto` 生成 Dart stubs（含 26 optional 字段 + status）。

## Task 8: value_objects/entity 加 26 字段 + copyWith

**Files:**
- Modify: `yucai/client/lib/account/domain/entities/account_entity.dart`

- [ ] **Step 1: entity 加 26 字段 + props + 构造默认值**

在 `Account` 类的 `creditLimitCents` 字段之后、`version` 之前加（参考字段总表 Dart 列）：

```dart
  final String cardNumberTail;   // 卡号/账号尾号（金融类）
  final String notes;            // 备注
  final DateTime? openingDate;   // 开户日期
  final double? interestRate;    // 年化利率(%): 储蓄/定期/贷款利率、信用卡APR
  final int? creditBillingDay;   // 信用卡账单日（1-31）
  final int? creditRepaymentDay; // 信用卡还款日（1-31）
  final int? creditAnnualFeeCents; // 信用卡年费
  final int? investCostCents;    // 投资投入成本
  final int? investMarketValueCents; // 投资当前市值
  final double? investReturnYtd; // 投资今年收益率(%)
  final int? fixedPrincipalCents; // 定期本金
  final DateTime? fixedStartDate; // 定期起息日
  final DateTime? fixedMaturityDate; // 定期到期日
  final int? fixedTermMonths;    // 定期期限（月）
  final String goldProductType;  // 黄金外汇品种
  final double? goldQuantity;    // 黄金外汇数量
  final int? goldBuyPriceCents;  // 黄金外汇买入价
  final int? goldCurrentPriceCents; // 黄金外汇现价
  final int? estatePurchasePriceCents; // 固定资产买入价
  final int? estateCurrentValueCents; // 固定资产现估值
  final DateTime? estatePurchaseDate; // 固定资产买入日期
  final double? estateDepreciationRate; // 固定资产折旧率(%)
  final int? loanOriginalCents;  // 贷款原始本金
  final int? loanRemainingCents; // 贷款剩余本金
  final int? loanMonthlyCents;   // 贷款月供
  final DateTime? loanNextPaymentDate; // 贷款下次还款日
```

构造函数加默认参数（nullable `null`，string `''`）：

```dart
    this.cardNumberTail = '',
    this.notes = '',
    this.openingDate, this.interestRate,
    this.creditBillingDay, this.creditRepaymentDay, this.creditAnnualFeeCents,
    this.investCostCents, this.investMarketValueCents, this.investReturnYtd,
    this.fixedPrincipalCents, this.fixedStartDate, this.fixedMaturityDate, this.fixedTermMonths,
    this.goldProductType = '', this.goldQuantity, this.goldBuyPriceCents, this.goldCurrentPriceCents,
    this.estatePurchasePriceCents, this.estateCurrentValueCents, this.estatePurchaseDate, this.estateDepreciationRate,
    this.loanOriginalCents, this.loanRemainingCents, this.loanMonthlyCents, this.loanNextPaymentDate,
```

`props` 列表末尾追加这 26 个字段名。

- [ ] **Step 2: 加 copyWith（编辑/复制 seed 用）**

在 `Account` 类加（含 26 新字段 + 既有字段；既有字段按现有 copyWith 补齐）：

```dart
  Account copyWith({
    String? id, String? name, AccountType? accountType, AccountCategory? category,
    String? currencyCode, int? initialBalanceCents, int? currentBalanceCents,
    Ownership? ownership, AccountStatus? status, String? icon, String? color,
    String? institution, int? creditLimitCents, int? version,
    String? cardNumberTail, String? notes, DateTime? openingDate, double? interestRate,
    int? creditBillingDay, int? creditRepaymentDay, int? creditAnnualFeeCents,
    int? investCostCents, int? investMarketValueCents, double? investReturnYtd,
    int? fixedPrincipalCents, DateTime? fixedStartDate, DateTime? fixedMaturityDate, int? fixedTermMonths,
    String? goldProductType, double? goldQuantity, int? goldBuyPriceCents, int? goldCurrentPriceCents,
    int? estatePurchasePriceCents, int? estateCurrentValueCents, DateTime? estatePurchaseDate, double? estateDepreciationRate,
    int? loanOriginalCents, int? loanRemainingCents, int? loanMonthlyCents, DateTime? loanNextPaymentDate,
  }) {
    return Account(
      id: id ?? this.id, name: name ?? this.name,
      accountType: accountType ?? this.accountType, category: category ?? this.category,
      currencyCode: currencyCode ?? this.currencyCode,
      initialBalanceCents: initialBalanceCents ?? this.initialBalanceCents,
      currentBalanceCents: currentBalanceCents ?? this.currentBalanceCents,
      ownership: ownership ?? this.ownership, status: status ?? this.status,
      icon: icon ?? this.icon, color: color ?? this.color,
      institution: institution ?? this.institution,
      creditLimitCents: creditLimitCents ?? this.creditLimitCents,
      version: version ?? this.version,
      cardNumberTail: cardNumberTail ?? this.cardNumberTail, notes: notes ?? this.notes,
      openingDate: openingDate ?? this.openingDate, interestRate: interestRate ?? this.interestRate,
      creditBillingDay: creditBillingDay ?? this.creditBillingDay,
      creditRepaymentDay: creditRepaymentDay ?? this.creditRepaymentDay,
      creditAnnualFeeCents: creditAnnualFeeCents ?? this.creditAnnualFeeCents,
      investCostCents: investCostCents ?? this.investCostCents,
      investMarketValueCents: investMarketValueCents ?? this.investMarketValueCents,
      investReturnYtd: investReturnYtd ?? this.investReturnYtd,
      fixedPrincipalCents: fixedPrincipalCents ?? this.fixedPrincipalCents,
      fixedStartDate: fixedStartDate ?? this.fixedStartDate,
      fixedMaturityDate: fixedMaturityDate ?? this.fixedMaturityDate,
      fixedTermMonths: fixedTermMonths ?? this.fixedTermMonths,
      goldProductType: goldProductType ?? this.goldProductType,
      goldQuantity: goldQuantity ?? this.goldQuantity,
      goldBuyPriceCents: goldBuyPriceCents ?? this.goldBuyPriceCents,
      goldCurrentPriceCents: goldCurrentPriceCents ?? this.goldCurrentPriceCents,
      estatePurchasePriceCents: estatePurchasePriceCents ?? this.estatePurchasePriceCents,
      estateCurrentValueCents: estateCurrentValueCents ?? this.estateCurrentValueCents,
      estatePurchaseDate: estatePurchaseDate ?? this.estatePurchaseDate,
      estateDepreciationRate: estateDepreciationRate ?? this.estateDepreciationRate,
      loanOriginalCents: loanOriginalCents ?? this.loanOriginalCents,
      loanRemainingCents: loanRemainingCents ?? this.loanRemainingCents,
      loanMonthlyCents: loanMonthlyCents ?? this.loanMonthlyCents,
      loanNextPaymentDate: loanNextPaymentDate ?? this.loanNextPaymentDate,
      createdAt: createdAt,
    );
  }
```

- [ ] **Step 3: 更新现有测试 Account(...) 构造**

Run: `cd yucai/client && grep -rn "Account(" test/` — 命名参数有默认值，多数无需改；位置参数调用需补。

- [ ] **Step 4: 编译 + analyze**

Run: `cd yucai/client && flutter analyze lib/account/domain`
Expected: 0 error。

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/domain/entities/account_entity.dart yucai/client/test/
git commit -m "feat(client): Account entity 加 26 类型专属字段(category前缀) + copyWith"
```

---

## Task 9: mapper toDomain 加 26 字段映射

**Files:**
- Modify: `yucai/client/lib/account/data/mappers/account_mapper.dart`

- [ ] **Step 1: toDomain 加 26 字段映射**

在 `AccountMapper.toDomain` 的 `creditLimitCents: dto.creditLimitCents.toInt(),` 之后加（**完整**；proto optional scalar 用 `hasX()` 守卫；Timestamp 用 `.toDateTime()`；Int64 用 `.toInt()`）：

```dart
      cardNumberTail: dto.hasCardNumberTail() ? dto.cardNumberTail : '',
      notes: dto.hasNotes() ? dto.notes : '',
      openingDate: dto.hasOpeningDate() ? dto.openingDate.toDateTime() : null,
      interestRate: dto.hasInterestRate() ? dto.interestRate : null,
      creditBillingDay: dto.hasCreditBillingDay() ? dto.creditBillingDay : null,
      creditRepaymentDay: dto.hasCreditRepaymentDay() ? dto.creditRepaymentDay : null,
      creditAnnualFeeCents: dto.hasCreditAnnualFeeCents() ? dto.creditAnnualFeeCents.toInt() : null,
      investCostCents: dto.hasInvestCostCents() ? dto.investCostCents.toInt() : null,
      investMarketValueCents: dto.hasInvestMarketValueCents() ? dto.investMarketValueCents.toInt() : null,
      investReturnYtd: dto.hasInvestReturnYtd() ? dto.investReturnYtd : null,
      fixedPrincipalCents: dto.hasFixedPrincipalCents() ? dto.fixedPrincipalCents.toInt() : null,
      fixedStartDate: dto.hasFixedStartDate() ? dto.fixedStartDate.toDateTime() : null,
      fixedMaturityDate: dto.hasFixedMaturityDate() ? dto.fixedMaturityDate.toDateTime() : null,
      fixedTermMonths: dto.hasFixedTermMonths() ? dto.fixedTermMonths : null,
      goldProductType: dto.hasGoldProductType() ? dto.goldProductType : '',
      goldQuantity: dto.hasGoldQuantity() ? dto.goldQuantity : null,
      goldBuyPriceCents: dto.hasGoldBuyPriceCents() ? dto.goldBuyPriceCents.toInt() : null,
      goldCurrentPriceCents: dto.hasGoldCurrentPriceCents() ? dto.goldCurrentPriceCents.toInt() : null,
      estatePurchasePriceCents: dto.hasEstatePurchasePriceCents() ? dto.estatePurchasePriceCents.toInt() : null,
      estateCurrentValueCents: dto.hasEstateCurrentValueCents() ? dto.estateCurrentValueCents.toInt() : null,
      estatePurchaseDate: dto.hasEstatePurchaseDate() ? dto.estatePurchaseDate.toDateTime() : null,
      estateDepreciationRate: dto.hasEstateDepreciationRate() ? dto.estateDepreciationRate : null,
      loanOriginalCents: dto.hasLoanOriginalCents() ? dto.loanOriginalCents.toInt() : null,
      loanRemainingCents: dto.hasLoanRemainingCents() ? dto.loanRemainingCents.toInt() : null,
      loanMonthlyCents: dto.hasLoanMonthlyCents() ? dto.loanMonthlyCents.toInt() : null,
      loanNextPaymentDate: dto.hasLoanNextPaymentDate() ? dto.loanNextPaymentDate.toDateTime() : null,
```

> 注：proto optional int32（`creditBillingDay` 等）getter 返回 `int`；optional int64（`investCostCents` 等）返回 Int64，需 `.toInt()`；optional double 返回 `double`；Timestamp `.toDateTime()`。生成代码名以 `account.pb.dart` 为准。

- [ ] **Step 2: 编译 + analyze**

Run: `cd yucai/client && flutter analyze lib/account/data`
Expected: 0 error。

- [ ] **Step 3: 提交**

```bash
git add yucai/client/lib/account/data/mappers/account_mapper.dart
git commit -m "feat(client): mapper toDomain 加 26 类型专属字段映射"
```

---

## Task 10: remote_ds + repository + params（create 加字段 + update/get 新方法）

**Files:**
- Modify: `yucai/client/lib/account/domain/repositories/account_repository.dart`
- Modify: `yucai/client/lib/account/data/account_repository_impl.dart`
- Modify: `yucai/client/lib/account/data/account_remote_ds.dart`

- [ ] **Step 1: CreateAccountParams 加 institution/creditLimit + 26 字段**

`account_repository.dart` — `CreateAccountParams` 字段声明 + 构造默认值加（既有缺的 institution/creditLimitCents 也补）：

```dart
  final String institution;
  final int creditLimitCents;
  final String cardNumberTail;
  final String notes;
  final DateTime? openingDate;
  final double? interestRate;
  final int? creditBillingDay;
  final int? creditRepaymentDay;
  final int? creditAnnualFeeCents;
  final int? investCostCents;
  final int? investMarketValueCents;
  final double? investReturnYtd;
  final int? fixedPrincipalCents;
  final DateTime? fixedStartDate;
  final DateTime? fixedMaturityDate;
  final int? fixedTermMonths;
  final String goldProductType;
  final double? goldQuantity;
  final int? goldBuyPriceCents;
  final int? goldCurrentPriceCents;
  final int? estatePurchasePriceCents;
  final int? estateCurrentValueCents;
  final DateTime? estatePurchaseDate;
  final double? estateDepreciationRate;
  final int? loanOriginalCents;
  final int? loanRemainingCents;
  final int? loanMonthlyCents;
  final DateTime? loanNextPaymentDate;
```

构造默认：`this.institution = '', this.creditLimitCents = 0, this.cardNumberTail = '', this.notes = '', this.goldProductType = ''`，其余 nullable `null`。

- [ ] **Step 2: 新建 UpdateAccountParams**

`account_repository.dart` 加：

```dart
class UpdateAccountParams {
  final String id;
  final int version;
  final String name, icon, color, institution, cardNumberTail, notes, goldProductType;
  final int creditLimitCents;
  final AccountStatus? status; // null=不改；archived=关闭
  final DateTime? openingDate, fixedStartDate, fixedMaturityDate, estatePurchaseDate, loanNextPaymentDate;
  final double? interestRate, investReturnYtd, goldQuantity, estateDepreciationRate;
  final int? creditBillingDay, creditRepaymentDay, creditAnnualFeeCents,
      investCostCents, investMarketValueCents, fixedPrincipalCents, fixedTermMonths,
      goldBuyPriceCents, goldCurrentPriceCents, estatePurchasePriceCents,
      estateCurrentValueCents, loanOriginalCents, loanRemainingCents, loanMonthlyCents;

  const UpdateAccountParams({
    required this.id, required this.version,
    this.name = '', this.icon = '', this.color = '', this.institution = '',
    this.cardNumberTail = '', this.notes = '', this.goldProductType = '',
    this.creditLimitCents = 0, this.status,
    this.openingDate, this.interestRate, this.creditBillingDay, this.creditRepaymentDay,
    this.creditAnnualFeeCents, this.investCostCents, this.investMarketValueCents, this.investReturnYtd,
    this.fixedPrincipalCents, this.fixedStartDate, this.fixedMaturityDate, this.fixedTermMonths,
    this.goldQuantity, this.goldBuyPriceCents, this.goldCurrentPriceCents,
    this.estatePurchasePriceCents, this.estateCurrentValueCents, this.estatePurchaseDate, this.estateDepreciationRate,
    this.loanOriginalCents, this.loanRemainingCents, this.loanMonthlyCents, this.loanNextPaymentDate,
  });
}
```

- [ ] **Step 3: AccountRepository 接口加 update/get**

```dart
  Future<Either<Failure, Account>> getById(String id);
  Future<Either<Failure, Account>> update(UpdateAccountParams params);
```

- [ ] **Step 4: remote_ds create 加字段 + update/get 方法**

`account_remote_ds.dart` — 加 `_ts` helper（Timestamp 导入包以生成 import 为准，常见 `package:google/protobuf/timestamp.pb.dart`）：

```dart
tspb.Timestamp _ts(DateTime d) => tspb.Timestamp.fromDateTime(d);
```

`create()` 构造 `CreateAccountRequest` 后，按 nullable 设置 26 字段（示例模式，全部按此套）：

```dart
    if (params.cardNumberTail.isNotEmpty) req.cardNumberTail = params.cardNumberTail;
    if (params.notes.isNotEmpty) req.notes = params.notes;
    if (params.openingDate != null) req.openingDate = _ts(params.openingDate!);
    if (params.interestRate != null) req.interestRate = params.interestRate;
    if (params.creditBillingDay != null) req.creditBillingDay = params.creditBillingDay!;
    if (params.creditRepaymentDay != null) req.creditRepaymentDay = params.creditRepaymentDay!;
    if (params.creditAnnualFeeCents != null) req.creditAnnualFeeCents = Int64(params.creditAnnualFeeCents!);
    if (params.investCostCents != null) req.investCostCents = Int64(params.investCostCents!);
    if (params.investMarketValueCents != null) req.investMarketValueCents = Int64(params.investMarketValueCents!);
    if (params.investReturnYtd != null) req.investReturnYtd = params.investReturnYtd;
    if (params.fixedPrincipalCents != null) req.fixedPrincipalCents = Int64(params.fixedPrincipalCents!);
    if (params.fixedStartDate != null) req.fixedStartDate = _ts(params.fixedStartDate!);
    if (params.fixedMaturityDate != null) req.fixedMaturityDate = _ts(params.fixedMaturityDate!);
    if (params.fixedTermMonths != null) req.fixedTermMonths = params.fixedTermMonths!;
    if (params.goldProductType.isNotEmpty) req.goldProductType = params.goldProductType;
    if (params.goldQuantity != null) req.goldQuantity = params.goldQuantity;
    if (params.goldBuyPriceCents != null) req.goldBuyPriceCents = Int64(params.goldBuyPriceCents!);
    if (params.goldCurrentPriceCents != null) req.goldCurrentPriceCents = Int64(params.goldCurrentPriceCents!);
    if (params.estatePurchasePriceCents != null) req.estatePurchasePriceCents = Int64(params.estatePurchasePriceCents!);
    if (params.estateCurrentValueCents != null) req.estateCurrentValueCents = Int64(params.estateCurrentValueCents!);
    if (params.estatePurchaseDate != null) req.estatePurchaseDate = _ts(params.estatePurchaseDate!);
    if (params.estateDepreciationRate != null) req.estateDepreciationRate = params.estateDepreciationRate;
    if (params.loanOriginalCents != null) req.loanOriginalCents = Int64(params.loanOriginalCents!);
    if (params.loanRemainingCents != null) req.loanRemainingCents = Int64(params.loanRemainingCents!);
    if (params.loanMonthlyCents != null) req.loanMonthlyCents = Int64(params.loanMonthlyCents!);
    if (params.loanNextPaymentDate != null) req.loanNextPaymentDate = _ts(params.loanNextPaymentDate!);
```

> CreateAccountRequest 构造时也传 `institution: params.institution, creditLimitCents: Int64(params.creditLimitCents)`。

加 `getById` + `update` 方法（`update` 内构造 UpdateAccountRequest 后套用与 create 相同的 26 字段赋值块 + `if (params.status != null) req.status = params.status!.toProto()`）：

```dart
  Future<Account> getById(String id) async {
    return _retry.call(() async {
      final res = await _client.getAccount(pb.GetAccountRequest(id: id));
      return _mapper.toDomain(res.account);
    });
  }

  Future<Account> update(UpdateAccountParams params) async {
    return _retry.call(() async {
      final req = pb.UpdateAccountRequest(
        id: params.id, version: Int64(params.version),
        name: params.name, icon: params.icon, color: params.color,
        institution: params.institution,
        creditLimitCents: Int64(params.creditLimitCents),
      );
      if (params.status != null) req.status = params.status!.toProto();
      if (params.cardNumberTail.isNotEmpty) req.cardNumberTail = params.cardNumberTail;
      // ...（与 create 相同的 26 字段赋值块，params.X 同名）
      final res = await _client.updateAccount(req);
      return _mapper.toDomain(res.account);
    });
  }
```

> `GetAccountRequest`/`UpdateAccountRequest`/响应取 `.account` 字段名以生成 pb 为准。

- [ ] **Step 5: repository_impl 加 update/get**

```dart
  @override
  Future<Either<Failure, Account>> getById(String id) => _guard(() => _remoteDs.getById(id));
  @override
  Future<Either<Failure, Account>> update(UpdateAccountParams params) => _guard(() => _remoteDs.update(params));
```

- [ ] **Step 6: 编译 + analyze**

Run: `cd yucai/client && flutter analyze lib/account`
Expected: 0 error。

- [ ] **Step 7: 提交**

```bash
git add yucai/client/lib/account/domain/repositories/account_repository.dart yucai/client/lib/account/data/account_repository_impl.dart yucai/client/lib/account/data/account_remote_ds.dart
git commit -m "feat(client): remote_ds/repo create 加 26 字段 + update/get 新方法 + UpdateAccountParams"
```

---

## Task 11: usecases update/get + bloc Update/Get events

**Files:**
- Create: `yucai/client/lib/account/domain/usecases/get_account_usecase.dart`
- Create: `yucai/client/lib/account/domain/usecases/update_account_usecase.dart`
- Modify: `yucai/client/lib/account/presentation/bloc/account_event.dart`
- Modify: `yucai/client/lib/account/presentation/bloc/account_state.dart`
- Modify: `yucai/client/lib/account/presentation/bloc/account_bloc.dart`

- [ ] **Step 1: 新建 GetAccountUseCase**

```dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@injectable
class GetAccountUseCase {
  GetAccountUseCase(this._repo);
  final AccountRepository _repo;
  Future<Either<Failure, Account>> call(String id) => _repo.getById(id);
}
```

- [ ] **Step 2: 新建 UpdateAccountUseCase**

```dart
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/core/error/failures.dart';

@injectable
class UpdateAccountUseCase {
  UpdateAccountUseCase(this._repo);
  final AccountRepository _repo;
  Future<Either<Failure, Account>> call(UpdateAccountParams params) => _repo.update(params);
}
```

- [ ] **Step 3: event 加 UpdateAccountRequested + GetAccountRequested**

```dart
class UpdateAccountRequested extends AccountEvent {
  final UpdateAccountParams params;
  const UpdateAccountRequested(this.params);
  @override List<Object?> get props => [params];
}

class GetAccountRequested extends AccountEvent {
  final String id;
  const GetAccountRequested(this.id);
  @override List<Object?> get props => [id];
}
```

- [ ] **Step 4: state 加 AccountDetailLoaded**

```dart
class AccountDetailLoaded extends AccountState {
  final Account account;
  const AccountDetailLoaded(this.account);
  @override List<Object?> get props => [account];
}
```

- [ ] **Step 5: bloc 注入 Get/Update usecase + handler**

构造函数加注入 `_get`/`_update`，`on<GetAccountRequested>(_onGet)` + `on<UpdateAccountRequested>(_onUpdate)`：

```dart
  Future<void> _onGet(GetAccountRequested event, Emitter<AccountState> emit) async {
    emit(AccountLoading);
    final res = await _get(event.id);
    res.fold((f) => emit(AccountError(f.message)), (a) => emit(AccountDetailLoaded(a)));
  }

  Future<void> _onUpdate(UpdateAccountRequested event, Emitter<AccountState> emit) async {
    final res = await _update(event.params);
    res.fold((f) => emit(AccountError(f.message)), (_) => add(LoadAccountsRequested()));
  }
```

- [ ] **Step 6: 重新生成 injectable**

Run: `cd yucai/client && flutter pub run build_runner build --delete-conflicting-outputs`
Expected: 无错误。

- [ ] **Step 7: 编译 + analyze + 测试**

Run: `cd yucai/client && flutter analyze lib/account && flutter test`
Expected: 0 error，测试 PASS。

- [ ] **Step 8: 提交**

```bash
git add yucai/client/lib/account/domain/usecases/get_account_usecase.dart yucai/client/lib/account/domain/usecases/update_account_usecase.dart yucai/client/lib/account/presentation/bloc/ yucai/client/lib/injection.config.dart
git commit -m "feat(client): usecase update/get + bloc Update/Get events/states"
```

---

# Part C: 客户端 UI（Tasks 12-15）

## Task 12: DatePickerInput + category 字段表单组件

**Files:**
- Create: `yucai/client/lib/core/widgets/date_picker_input.dart`
- Create: `yucai/client/lib/account/presentation/widgets/category_fields.dart`

- [ ] **Step 1: 新建 DatePickerInput**

`date_picker_input.dart`（参考 `amount_input.dart` FormField 风格）：

```dart
import 'package:flutter/material.dart';
import 'package:yucai_client/core/theme/app_design.dart';

class DatePickerInput extends FormField<DateTime> {
  DatePickerInput({
    super.key,
    required String label,
    DateTime? initialValue,
    super.onSaved,
    super.validator,
  }) : super(
          initialValue: initialValue,
          builder: (state) {
            return InputDecorator(
              decoration: InputDecoration(
                labelText: label,
                errorText: state.errorText,
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: state.context,
                    initialDate: state.value ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) state.didChange(picked);
                },
                child: Text(
                  state.value == null
                      ? '请选择日期'
                      : '${state.value!.year}-${state.value!.month.toString().padLeft(2, '0')}-${state.value!.day.toString().padLeft(2, '0')}',
                  style: TextStyle(color: state.value == null ? AppColors.muted : AppColors.text),
                ),
              ),
            );
          },
        );
}
```

- [ ] **Step 2: 新建 category 字段表单组件**

`category_fields.dart` — `CategoryFieldBundle`（controllers）+ `primaryAmountLabel` + `categoryFieldsWidget`（按 category 渲染专属字段）。

```dart
import 'package:flutter/material.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/widgets/amount_input.dart';
import 'package:yucai_client/core/widgets/date_picker_input.dart';
import 'package:yucai_client/core/widgets/form_section.dart';

/// 按 category 渲染的专属字段 controllers 集合。
/// 主金额统一进 primaryCentsCtrl（label 随 category），_submit 按 category 映射到
/// InvestCostCents/FixedPrincipalCents/GoldBuyPriceCents/EstatePurchasePriceCents/LoanRemainingCents/InitialBalanceCents。
/// interestRateCtrl 多义：储蓄/定期/贷款/信用卡→InterestRate，投资→InvestReturnYtd，固定资产→EstateDepreciationRate。
class CategoryFieldBundle {
  final TextEditingController primaryCentsCtrl;
  final TextEditingController institutionCtrl;
  final TextEditingController cardNumberTailCtrl;
  final TextEditingController interestRateCtrl; // 利率/APR/收益率/折旧率（多义，_submit 按 category 映射）
  final TextEditingController creditBillingDayCtrl;
  final TextEditingController creditRepaymentDayCtrl;
  final TextEditingController creditLimitCtrl;
  final TextEditingController creditAnnualFeeCtrl;
  final TextEditingController investMarketValueCtrl;
  final TextEditingController fixedStartDateCtrl;
  final TextEditingController fixedMaturityDateCtrl;
  final TextEditingController fixedTermMonthsCtrl;
  final TextEditingController goldProductTypeCtrl;
  final TextEditingController goldQuantityCtrl;
  final TextEditingController goldCurrentPriceCtrl;
  final TextEditingController estateCurrentValueCtrl;
  final TextEditingController estatePurchaseDateCtrl;
  final TextEditingController loanOriginalCtrl;
  final TextEditingController loanMonthlyCtrl;
  final TextEditingController loanNextPaymentDateCtrl;

  CategoryFieldBundle()
      : primaryCentsCtrl = TextEditingController(text: '0'),
        institutionCtrl = TextEditingController(),
        cardNumberTailCtrl = TextEditingController(),
        interestRateCtrl = TextEditingController(),
        creditBillingDayCtrl = TextEditingController(),
        creditRepaymentDayCtrl = TextEditingController(),
        creditLimitCtrl = TextEditingController(),
        creditAnnualFeeCtrl = TextEditingController(),
        investMarketValueCtrl = TextEditingController(),
        fixedStartDateCtrl = TextEditingController(),
        fixedMaturityDateCtrl = TextEditingController(),
        fixedTermMonthsCtrl = TextEditingController(),
        goldProductTypeCtrl = TextEditingController(),
        goldQuantityCtrl = TextEditingController(),
        goldCurrentPriceCtrl = TextEditingController(),
        estateCurrentValueCtrl = TextEditingController(),
        estatePurchaseDateCtrl = TextEditingController(),
        loanOriginalCtrl = TextEditingController(),
        loanMonthlyCtrl = TextEditingController(),
        loanNextPaymentDateCtrl = TextEditingController();

  void dispose() {
    for (final c in [primaryCentsCtrl, institutionCtrl, cardNumberTailCtrl, interestRateCtrl,
      creditBillingDayCtrl, creditRepaymentDayCtrl, creditLimitCtrl, creditAnnualFeeCtrl,
      investMarketValueCtrl, fixedStartDateCtrl, fixedMaturityDateCtrl, fixedTermMonthsCtrl,
      goldProductTypeCtrl, goldQuantityCtrl, goldCurrentPriceCtrl, estateCurrentValueCtrl,
      estatePurchaseDateCtrl, loanOriginalCtrl, loanMonthlyCtrl, loanNextPaymentDateCtrl]) {
      c.dispose();
    }
  }
}

/// 主金额 label 按 category（spec §2 + 设计决策 4）。
String primaryAmountLabel(AccountCategory c) {
  switch (c) {
    case AccountCategory.creditCard: return '当前欠款';
    case AccountCategory.investment: return '投入成本';
    case AccountCategory.fixedDeposit: return '本金';
    case AccountCategory.goldFx: return '买入价';
    case AccountCategory.realEstate: return '买入价';
    case AccountCategory.loan: return '剩余本金';
    default: return '初始余额';
  }
}

/// 利率字段 label 按 category（设计决策 5）。
String rateLabel(AccountCategory c) {
  switch (c) {
    case AccountCategory.investment: return '今年收益率 (%)';
    case AccountCategory.realEstate: return '折旧率 (%)';
    case AccountCategory.creditCard: return 'APR 年化利率 (%)';
    default: return '利率 (%)';
  }
}

DropdownButtonFormField<int> _dayPicker(TextEditingController ctrl, String label) {
  return DropdownButtonFormField<int>(
    decoration: InputDecoration(labelText: label),
    items: [for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d日'))],
    onChanged: (v) => ctrl.text = v.toString(),
  );
}

/// 按 category 渲染专属字段 widget 列表。
List<Widget> categoryFieldsWidget(AccountCategory c, CategoryFieldBundle b) {
  switch (c) {
    case AccountCategory.savings:
      return [
        TextFormField(controller: b.institutionCtrl, decoration: const InputDecoration(labelText: '开户机构')),
        TextFormField(controller: b.cardNumberTailCtrl, decoration: const InputDecoration(labelText: '卡号后四位')),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        TextFormField(controller: b.interestRateCtrl, decoration: InputDecoration(labelText: rateLabel(c)), keyboardType: TextInputType.number),
        DatePickerInput(label: '开户日期'),
      ];
    case AccountCategory.creditCard:
      return [
        TextFormField(controller: b.institutionCtrl, decoration: const InputDecoration(labelText: '发卡机构')),
        TextFormField(controller: b.cardNumberTailCtrl, decoration: const InputDecoration(labelText: '卡号尾号')),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        AmountInput(controller: b.creditLimitCtrl, label: '信用额度'),
        FormRow(children: [
          _dayPicker(b.creditBillingDayCtrl, '账单日'),
          _dayPicker(b.creditRepaymentDayCtrl, '还款日'),
        ]),
        AmountInput(controller: b.creditAnnualFeeCtrl, label: '年费'),
        TextFormField(controller: b.interestRateCtrl, decoration: InputDecoration(labelText: rateLabel(c)), keyboardType: TextInputType.number),
      ];
    case AccountCategory.investment:
      return [
        TextFormField(controller: b.institutionCtrl, decoration: const InputDecoration(labelText: '机构（券商）', hintText: '如 华泰证券')),
        TextFormField(controller: b.cardNumberTailCtrl, decoration: const InputDecoration(labelText: '账号尾号')),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        AmountInput(controller: b.investMarketValueCtrl, label: '当前市值'),
        TextFormField(controller: b.interestRateCtrl, decoration: InputDecoration(labelText: rateLabel(c)), keyboardType: TextInputType.number),
      ];
    case AccountCategory.fixedDeposit:
      return [
        TextFormField(controller: b.institutionCtrl, decoration: const InputDecoration(labelText: '机构')),
        TextFormField(controller: b.cardNumberTailCtrl, decoration: const InputDecoration(labelText: '账号尾号')),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        TextFormField(controller: b.interestRateCtrl, decoration: InputDecoration(labelText: rateLabel(c)), keyboardType: TextInputType.number),
        DatePickerInput(label: '起息日'),
        DatePickerInput(label: '到期日'),
        TextFormField(controller: b.fixedTermMonthsCtrl, decoration: const InputDecoration(labelText: '期限（月）'), keyboardType: TextInputType.number),
      ];
    case AccountCategory.goldFx:
      return [
        TextFormField(controller: b.goldProductTypeCtrl, decoration: const InputDecoration(labelText: '品种', hintText: '如 实物黄金 / 美元 USD')),
        TextFormField(controller: b.goldQuantityCtrl, decoration: const InputDecoration(labelText: '数量'), keyboardType: TextInputType.number),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        AmountInput(controller: b.goldCurrentPriceCtrl, label: '现价'),
      ];
    case AccountCategory.realEstate:
      return [
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        AmountInput(controller: b.estateCurrentValueCtrl, label: '现估值'),
        DatePickerInput(label: '买入日期'),
        TextFormField(controller: b.interestRateCtrl, decoration: InputDecoration(labelText: rateLabel(c)), keyboardType: TextInputType.number),
      ];
    case AccountCategory.loan:
      return [
        TextFormField(controller: b.institutionCtrl, decoration: const InputDecoration(labelText: '贷款机构')),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        AmountInput(controller: b.loanOriginalCtrl, label: '原始本金'),
        TextFormField(controller: b.interestRateCtrl, decoration: InputDecoration(labelText: rateLabel(c)), keyboardType: TextInputType.number),
        TextFormField(controller: b.fixedTermMonthsCtrl, decoration: const InputDecoration(labelText: '期限（月）'), keyboardType: TextInputType.number),
        AmountInput(controller: b.loanMonthlyCtrl, label: '月供'),
        DatePickerInput(label: '下次还款日'),
      ];
    case AccountCategory.otherAsset:
    case AccountCategory.otherLiability:
      return [AmountInput(controller: b.primaryCentsCtrl, label: '金额')];
  }
}
```

- [ ] **Step 3: 编译 + analyze**

Run: `cd yucai/client && flutter analyze lib/core/widgets lib/account/presentation/widgets`
Expected: 0 error。

- [ ] **Step 4: 提交**

```bash
git add yucai/client/lib/core/widgets/date_picker_input.dart yucai/client/lib/account/presentation/widgets/category_fields.dart
git commit -m "feat(client): DatePickerInput + 按 category 动态字段组件"
```

---

## Task 13: AccountFormPage 编辑模式 + category 动态字段 + _submit 映射

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/account_form_page.dart`

- [ ] **Step 1: 加编辑模式入参**

```dart
class AccountFormPage extends StatefulWidget {
  final Account? existing; // null=创建；非 null=编辑（id='' 表示复制 seed）
  const AccountFormPage({super.key, this.existing});
  @override State<AccountFormPage> createState() => _AccountFormPageState();
}
```

- [ ] **Step 2: State 加 bundle + 预填 + isEdit + 反查 helper**

```dart
  final _bundle = CategoryFieldBundle();
  Account? get _existing => widget.existing;
  bool get _isEdit => _existing != null && _existing!.id.isNotEmpty;

  @override
  void initState() {
    super.initState();
    final e = _existing;
    if (e != null) {
      _nameCtrl.text = e.name;
      _currency = e.currencyCode;
      _category = e.category;
      _ownership = e.ownership;
      _bundle.primaryCentsCtrl.text = (_primaryCentsOf(e) / 100).toStringAsFixed(2);
      _bundle.institutionCtrl.text = e.institution;
      _bundle.cardNumberTailCtrl.text = e.cardNumberTail;
      _bundle.interestRateCtrl.text = _rateOf(e)?.toString() ?? '';
      _bundle.creditBillingDayCtrl.text = e.creditBillingDay?.toString() ?? '';
      _bundle.creditRepaymentDayCtrl.text = e.creditRepaymentDay?.toString() ?? '';
      _bundle.creditLimitCtrl.text = (e.creditLimitCents / 100).toStringAsFixed(2);
      _bundle.creditAnnualFeeCtrl.text = e.creditAnnualFeeCents == null ? '' : (e.creditAnnualFeeCents! / 100).toStringAsFixed(2);
      _bundle.investMarketValueCtrl.text = e.investMarketValueCents == null ? '' : (e.investMarketValueCents! / 100).toStringAsFixed(2);
      _bundle.fixedTermMonthsCtrl.text = e.fixedTermMonths?.toString() ?? '';
      _bundle.goldProductTypeCtrl.text = e.goldProductType;
      _bundle.goldQuantityCtrl.text = e.goldQuantity?.toString() ?? '';
      _bundle.goldCurrentPriceCtrl.text = e.goldCurrentPriceCents == null ? '' : (e.goldCurrentPriceCents! / 100).toStringAsFixed(2);
      _bundle.estateCurrentValueCtrl.text = e.estateCurrentValueCents == null ? '' : (e.estateCurrentValueCents! / 100).toStringAsFixed(2);
      _bundle.loanOriginalCtrl.text = e.loanOriginalCents == null ? '' : (e.loanOriginalCents! / 100).toStringAsFixed(2);
      _bundle.loanMonthlyCtrl.text = e.loanMonthlyCents == null ? '' : (e.loanMonthlyCents! / 100).toStringAsFixed(2);
    }
  }

  @override
  void dispose() { _nameCtrl.dispose(); _bundle.dispose(); super.dispose(); }

  // 主金额反查（编辑预填）
  int _primaryCentsOf(Account e) {
    switch (e.category) {
      case AccountCategory.investment: return e.investCostCents ?? 0;
      case AccountCategory.fixedDeposit: return e.fixedPrincipalCents ?? 0;
      case AccountCategory.goldFx: return e.goldBuyPriceCents ?? 0;
      case AccountCategory.realEstate: return e.estatePurchasePriceCents ?? 0;
      case AccountCategory.loan: return e.loanRemainingCents ?? 0;
      default: return e.initialBalanceCents;
    }
  }
  // 利率反查（设计决策 5）
  double? _rateOf(Account e) {
    switch (e.category) {
      case AccountCategory.investment: return e.investReturnYtd;
      case AccountCategory.realEstate: return e.estateDepreciationRate;
      default: return e.interestRate;
    }
  }
```

- [ ] **Step 3: 切 category 清空 bundle**

TypeTabs `onChanged`：

```dart
  onChanged: (v) => setState(() {
    _category = v;
    _bundle.primaryCentsCtrl.text = '0';
    for (final c in [_bundle.interestRateCtrl, _bundle.creditBillingDayCtrl, _bundle.creditRepaymentDayCtrl,
      _bundle.creditLimitCtrl, _bundle.creditAnnualFeeCtrl, _bundle.investMarketValueCtrl,
      _bundle.fixedTermMonthsCtrl, _bundle.goldProductTypeCtrl, _bundle.goldQuantityCtrl,
      _bundle.goldCurrentPriceCtrl, _bundle.estateCurrentValueCtrl, _bundle.loanOriginalCtrl,
      _bundle.loanMonthlyCtrl, _bundle.institutionCtrl, _bundle.cardNumberTailCtrl]) {
      c.clear();
    }
  }),
```

- [ ] **Step 4: FormSection('基本信息') 后加 category 动态字段块**

```dart
const SizedBox(height: AppSpacing.lg),
FormSection(title: '${_category.label}信息', children: categoryFieldsWidget(_category, _bundle)),
```

- [ ] **Step 5: _submit 按 category 映射主金额/利率 + 区分创建/编辑**

```dart
  int? _optInt(TextEditingController c) => c.text.trim().isEmpty ? null : int.tryParse(c.text);
  double? _optDouble(TextEditingController c) => c.text.trim().isEmpty ? null : double.tryParse(c.text);
  int? _yuanToCents(TextEditingController c) { final v = double.tryParse(c.text); return v == null ? null : (v * 100).round(); }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    _submitted = true;
    final primaryCents = ((double.tryParse(_bundle.primaryCentsCtrl.text) ?? 0) * 100).round();
    final rate = _optDouble(_bundle.interestRateCtrl);
    // 利率按 category 映射（设计决策 5）
    final interestRate = (_category == AccountCategory.investment || _category == AccountCategory.realEstate) ? null : rate;
    final investReturnYtd = _category == AccountCategory.investment ? rate : null;
    final estateDepreciationRate = _category == AccountCategory.realEstate ? rate : null;

    if (_isEdit) {
      context.read<AccountBloc>().add(UpdateAccountRequested(_buildUpdate(primaryCents, interestRate, investReturnYtd, estateDepreciationRate)));
    } else {
      context.read<AccountBloc>().add(CreateAccountRequested(_buildCreate(primaryCents, interestRate, investReturnYtd, estateDepreciationRate)));
    }
  }

  UpdateAccountParams _buildUpdate(int primary, double? rate, double? retYtd, double? dep) {
    return UpdateAccountParams(
      id: _existing!.id, version: _existing!.version,
      name: _nameCtrl.text.trim(), institution: _bundle.institutionCtrl.text.trim(),
      cardNumberTail: _bundle.cardNumberTailCtrl.text.trim(),
      creditLimitCents: _yuanToCents(_bundle.creditLimitCtrl) ?? 0,
      interestRate: rate, investReturnYtd: retYtd, estateDepreciationRate: dep,
      // 主金额按 category（设计决策 4）
      investCostCents: _category == AccountCategory.investment ? primary : null,
      fixedPrincipalCents: _category == AccountCategory.fixedDeposit ? primary : null,
      goldBuyPriceCents: _category == AccountCategory.goldFx ? primary : null,
      estatePurchasePriceCents: _category == AccountCategory.realEstate ? primary : null,
      loanRemainingCents: _category == AccountCategory.loan ? primary : null,
      creditBillingDay: _optInt(_bundle.creditBillingDayCtrl),
      creditRepaymentDay: _optInt(_bundle.creditRepaymentDayCtrl),
      creditAnnualFeeCents: _yuanToCents(_bundle.creditAnnualFeeCtrl),
      investMarketValueCents: _yuanToCents(_bundle.investMarketValueCtrl),
      fixedTermMonths: _optInt(_bundle.fixedTermMonthsCtrl),
      goldProductType: _bundle.goldProductTypeCtrl.text.trim(),
      goldQuantity: _optDouble(_bundle.goldQuantityCtrl),
      goldCurrentPriceCents: _yuanToCents(_bundle.goldCurrentPriceCtrl),
      estateCurrentValueCents: _yuanToCents(_bundle.estateCurrentValueCtrl),
      loanOriginalCents: _yuanToCents(_bundle.loanOriginalCtrl),
      loanMonthlyCents: _yuanToCents(_bundle.loanMonthlyCtrl),
    );
  }

  CreateAccountParams _buildCreate(int primary, double? rate, double? retYtd, double? dep) {
    return CreateAccountParams(
      name: _nameCtrl.text.trim(), accountType: _category.accountType, category: _category,
      currencyCode: _currency,
      initialBalanceCents: _initialCentsForCreate(_category, primary),
      ownership: _ownership,
      institution: _bundle.institutionCtrl.text.trim(),
      cardNumberTail: _bundle.cardNumberTailCtrl.text.trim(),
      creditLimitCents: _yuanToCents(_bundle.creditLimitCtrl) ?? 0,
      interestRate: rate, investReturnYtd: retYtd, estateDepreciationRate: dep,
      investCostCents: _category == AccountCategory.investment ? primary : null,
      fixedPrincipalCents: _category == AccountCategory.fixedDeposit ? primary : null,
      goldBuyPriceCents: _category == AccountCategory.goldFx ? primary : null,
      estatePurchasePriceCents: _category == AccountCategory.realEstate ? primary : null,
      loanRemainingCents: _category == AccountCategory.loan ? primary : null,
      creditBillingDay: _optInt(_bundle.creditBillingDayCtrl),
      creditRepaymentDay: _optInt(_bundle.creditRepaymentDayCtrl),
      creditAnnualFeeCents: _yuanToCents(_bundle.creditAnnualFeeCtrl),
      investMarketValueCents: _yuanToCents(_bundle.investMarketValueCtrl),
      fixedTermMonths: _optInt(_bundle.fixedTermMonthsCtrl),
      goldProductType: _bundle.goldProductTypeCtrl.text.trim(),
      goldQuantity: _optDouble(_bundle.goldQuantityCtrl),
      goldCurrentPriceCents: _yuanToCents(_bundle.goldCurrentPriceCtrl),
      estateCurrentValueCents: _yuanToCents(_bundle.estateCurrentValueCtrl),
      loanOriginalCents: _yuanToCents(_bundle.loanOriginalCtrl),
      loanMonthlyCents: _yuanToCents(_bundle.loanMonthlyCtrl),
    );
  }

  // 创建时 initialBalanceCents 按 category（主金额在专属字段的不进 initial）
  int _initialCentsForCreate(AccountCategory c, int primary) {
    switch (c) {
      case AccountCategory.investment: case AccountCategory.fixedDeposit:
      case AccountCategory.goldFx: case AccountCategory.realEstate: case AccountCategory.loan:
        return 0;
      default: return primary;
    }
  }
```

> 日期字段（openingDate/fixedStartDate 等）因用 `DatePickerInput`（FormField，非 controller），_submit 时需通过 FormKey 保存或在 FormSection 内用 FormField onSaved 收集。简化：本版日期字段先用 controller 版（DatePickerInput 内部不绑 controller，可改为接受 onSaved 回调存入 state 字段）。**实现提示**：给 `_AccountFormPageState` 加 `DateTime? _openingDate, _fixedStartDate, ...` state 字段，DatePickerInput 包一层 onSaved 赋值；_submit 时传这些 state。若为减负先跳过日期持久化（仅文本字段），在 Task 16 验证时补。

- [ ] **Step 6: AppBar/submit label 动态**

AppBar title: `_isEdit ? '编辑账户' : '新建账户'`。FormActions submitLabel: `_isEdit ? '保存修改' : '确认创建'`。BlocListener（`_submitted && curr is AccountsLoaded && prev is! AccountsLoaded`）对 update 同样适用，保持不变。

- [ ] **Step 7: 编译 + analyze**

Run: `cd yucai/client && flutter analyze lib/account/presentation/pages/account_form_page.dart`
Expected: 0 error。

- [ ] **Step 8: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_form_page.dart
git commit -m "feat(client): AccountFormPage 编辑模式 + category 动态字段 + 主金额/利率映射"
```

---

## Task 14: AccountsPage 卡片操作菜单（编辑/复制/关闭/删除 + 🔒占位）

**Files:**
- Modify: `yucai/client/lib/account/presentation/pages/accounts_page.dart`

- [ ] **Step 1: _AccountCard 加操作回调 + PopupMenuButton**

`_AccountCard` 加 `onEdit/onDuplicate/onClose/onDelete` 回调字段 + 构造参数。在 `ac-top` Row 右侧（色块后）加：

```dart
PopupMenuButton<String>(
  icon: const Icon(Icons.more_horiz, size: 18, color: AppColors.muted),
  itemBuilder: (_) => const [
    PopupMenuItem(value: 'detail', child: Text('查看详情')),
    PopupMenuItem(value: 'edit', child: Text('编辑')),
    PopupMenuItem(value: 'copy', child: Text('复制')),
    PopupMenuItem(value: 'record', enabled: false, child: Text('记一笔（待交易模块）')),
    PopupMenuItem(value: 'transfer', enabled: false, child: Text('转账（待交易模块）')),
    PopupMenuItem(value: 'close', child: Text('关闭账户')),
    PopupMenuItem(value: 'delete', child: Text('删除账户')),
  ],
  onSelected: (v) {
    switch (v) {
      case 'detail': context.go('/accounts/${account.id}');
      case 'edit': onEdit?.call();
      case 'copy': onDuplicate?.call();
      case 'close': onClose?.call();
      case 'delete': onDelete?.call();
    }
  },
),
```

> 需 `import 'package:go_router/go_router.dart';`。

- [ ] **Step 2: _GroupBlock 透传回调 + AccountsPage 实现**

`_GroupBlock` 加 `onEdit/onDuplicate/onClose/onDelete` 参数透传给 `_AccountCard`。`_AccountsPageState` 构造卡片处传：

```dart
_AccountCard(
  account: a, formatCents: _formatCents, barFraction: _barFraction(a),
  onEdit: () => _openEditForm(a),
  onDuplicate: () => _openCopyForm(a),
  onClose: () => _confirmClose(a),
  onDelete: () => _confirmDelete(a),
)
```

回调实现：

```dart
  void _openEditForm(Account a) {
    Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AccountFormPage(existing: a))).then((ok) {
      if (ok == true) AppToast.show(context, '账户已更新', AppToastType.success);
    });
  }

  void _openCopyForm(Account a) {
    // seed 模式：预填但 id 清空 → 创建
    Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AccountFormPage(existing: a.copyWith(id: '', version: 0))),
    ).then((ok) {
      if (ok == true) AppToast.show(context, '账户已复制', AppToastType.success);
    });
  }

  void _confirmClose(Account a) {
    showDialog<bool>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('关闭账户'),
        content: Text('关闭「${a.name}」？关闭后账户归档，详情仍可查看。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(dctx, true), child: const Text('关闭')),
        ],
      ),
    ).then((ok) {
      if (ok == true) {
        setState(() => _pendingIds.add(a.id));
        context.read<AccountBloc>().add(UpdateAccountRequested(
          UpdateAccountParams(id: a.id, version: a.version, status: AccountStatus.archived),
        ));
      }
    });
  }
```

- [ ] **Step 3: _pendingIds 替代单 bool _deleting**

State 字段 `_deleting`（bool）→ `final _pendingIds = <String>{};`。BlocConsumer listener：

```dart
listener: (context, state) {
  if (state is AccountError && _pendingIds.isNotEmpty) {
    AppToast.show(context, state.message, AppToastType.error);
    setState(_pendingIds.clear);
  } else if (state is AccountsLoaded && _pendingIds.isNotEmpty) {
    AppToast.show(context, '操作完成', AppToastType.success);
    setState(_pendingIds.clear);
  }
},
```

`_confirmDelete` 里 `_deleting = true` → `setState(() => _pendingIds.add(account.id));`。

- [ ] **Step 4: 编译 + analyze**

Run: `cd yucai/client && flutter analyze lib/account/presentation/pages/accounts_page.dart`
Expected: 0 error。

- [ ] **Step 5: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/accounts_page.dart
git commit -m "feat(client): AccountsPage 卡片操作菜单（查看/编辑/复制/关闭/删除 + 🔒记一笔/转账占位）"
```

---

## Task 15: AccountDetailPage 详情页（Hero 真实 + 统计/流水/持仓占位 + 操作）

**Files:**
- Create: `yucai/client/lib/account/presentation/pages/account_detail_page.dart`
- Modify: `yucai/client/lib/app/router.dart`

- [ ] **Step 1: 新建 AccountDetailPage**

`account_detail_page.dart` — 接收 `id`，`initState` 触发 `GetAccountRequested`，展示 Hero（专属字段 chip）+ 占位统计/流水/持仓 + 操作按钮。

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/account/presentation/bloc/account_bloc.dart';
import 'package:yucai_client/account/presentation/bloc/account_event.dart';
import 'package:yucai_client/account/presentation/bloc/account_state.dart';
import 'package:yucai_client/account/presentation/pages/account_form_page.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/data_card.dart';

class AccountDetailPage extends StatefulWidget {
  final String id;
  const AccountDetailPage({super.key, required this.id});
  @override State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>().add(GetAccountRequested(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: const Text('账户详情'),
        actions: [
          BlocBuilder<AccountBloc, AccountState>(
            buildWhen: (p, c) => c is AccountDetailLoaded || c is AccountLoading,
            builder: (context, state) {
              final a = state is AccountDetailLoaded ? state.account : null;
              return Row(children: [
                TextButton(onPressed: a == null ? null : () => _edit(a), child: const Text('编辑')),
                TextButton(onPressed: null, child: const Text('记一笔🔒')),
                TextButton(onPressed: null, child: const Text('转账🔒')),
                PopupMenuButton<String>(
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'copy', child: Text('复制账户')),
                    PopupMenuItem(value: 'close', child: Text('关闭账户')),
                    PopupMenuItem(value: 'delete', child: Text('删除账户')),
                  ],
                  onSelected: (v) { if (a == null) return; switch (v) {
                    case 'copy': _copy(a); case 'close': _close(a); case 'delete': _delete(a);
                  }},
                ),
              ]);
            },
          ),
        ],
      ),
      body: BlocBuilder<AccountBloc, AccountState>(
        builder: (context, state) {
          if (state is AccountLoading) return const Center(child: CircularProgressIndicator());
          if (state is AccountError) return Center(child: Text(state.message));
          if (state is AccountDetailLoaded) return _body(state.account);
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _body(Account a) => ListView(padding: const EdgeInsets.all(AppSpacing.lg), children: [
    _hero(a),
    const SizedBox(height: AppSpacing.lg),
    _statsRow(),
    const SizedBox(height: AppSpacing.lg),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: _panel('近期交易', '待 Transaction 模块接入')),
      const SizedBox(width: AppSpacing.lg),
      Expanded(child: _panel('收支统计', '待 Transaction 模块接入')),
    ]),
    const SizedBox(height: AppSpacing.lg),
    if (a.category == AccountCategory.investment) _panel('持仓列表', '待 Holding 模块接入')
    else if (a.category == AccountCategory.loan) _panel('还款计划', '待 payment_schedule 模块接入')
    else const SizedBox.shrink(),
  ]);

  Widget _hero(Account a) => DataCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Icon(_categoryIcon(a.category), color: AppColors.accent, size: 28),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        Text('${a.institution.isEmpty ? "—" : a.institution} · ${a.currencyCode} · ${a.category.label}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12)),
      ])),
    ]),
    const SizedBox(height: AppSpacing.lg),
    Text(_fmt(a.currentBalanceCents), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600,
        color: a.currentBalanceCents < 0 ? AppColors.negative : AppColors.text)),
    const SizedBox(height: AppSpacing.md),
    Wrap(spacing: 8, runSpacing: 8, children: _specificChips(a)),
  ]));

  // category 专属字段 chip（只展示非空）
  List<Widget> _specificChips(Account a) {
    final chips = <_Chip>[];
    void add(String label, String? v) { if (v != null && v.isNotEmpty) chips.add(_Chip(label, v)); }
    void addNum(String label, int? cents) { if (cents != null && cents != 0) chips.add(_Chip(label, '¥${(cents/100).toStringAsFixed(2)}')); }
    void addRate(String label, double? r) { if (r != null) chips.add(_Chip(label, '$r%')); }
    void addDay(String label, int? d) { if (d != null) chips.add(_Chip(label, '$d日')); }
    void addDate(String label, DateTime? d) { if (d != null) chips.add(_Chip(label, _fmtDate(d))); }
    addNum('信用额度', a.creditLimitCents == 0 ? null : a.creditLimitCents);
    addDay('账单日', a.creditBillingDay);
    addDay('还款日', a.creditRepaymentDay);
    addRate('利率', a.interestRate);
    addNum('年费', a.creditAnnualFeeCents);
    addNum('市值', a.investMarketValueCents);
    addRate('今年收益率', a.investReturnYtd);
    addNum('成本', a.investCostCents);
    addNum('定期本金', a.fixedPrincipalCents);
    addDate('起息日', a.fixedStartDate);
    addDate('到期日', a.fixedMaturityDate);
    addDay('期限(月)', a.fixedTermMonths);
    add('品种', a.goldProductType.isEmpty ? null : a.goldProductType);
    if (a.goldQuantity != null) chips.add(_Chip('数量', a.goldQuantity.toString()));
    addNum('买入价', a.goldBuyPriceCents);
    addNum('现价', a.goldCurrentPriceCents);
    addNum('买入价', a.estatePurchasePriceCents);
    addNum('现估值', a.estateCurrentValueCents);
    addDate('买入日期', a.estatePurchaseDate);
    addRate('折旧率', a.estateDepreciationRate);
    addNum('原始本金', a.loanOriginalCents);
    addNum('剩余本金', a.loanRemainingCents);
    addNum('月供', a.loanMonthlyCents);
    addDate('下次还款', a.loanNextPaymentDate);
    return chips.map((c) => Chip(label: Text('${c.label}: ${c.value}', style: const TextStyle(fontSize: 12)))).toList();
  }

  Widget _statsRow() => Row(children: ['本月收入', '本月支出', '净值变动', '交易数'].map((t) =>
    Expanded(child: DataCard(child: Column(children: [
      const Text('—', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(t, style: const TextStyle(color: AppColors.muted, fontSize: 11)),
      const Text('待交易模块', style: TextStyle(color: AppColors.muted, fontSize: 10)),
    ])))).toList());

  Widget _panel(String title, String hint) => DataCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
    const SizedBox(height: AppSpacing.md),
    Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(hint, style: const TextStyle(color: AppColors.muted, fontSize: 12)))),
  ]));

  void _edit(Account a) => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AccountFormPage(existing: a))).then((ok) {
    if (ok == true) { AppToast.show(context, '账户已更新', AppToastType.success); context.read<AccountBloc>().add(GetAccountRequested(widget.id)); }
  });
  void _copy(Account a) => Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => AccountFormPage(existing: a.copyWith(id: '', version: 0)))).then((ok) {
    if (ok == true) AppToast.show(context, '账户已复制', AppToastType.success);
  });
  void _close(Account a) {
    showDialog<bool>(context: context, builder: (dctx) => AlertDialog(
      title: const Text('关闭账户'), content: Text('关闭「${a.name}」？'),
      actions: [TextButton(onPressed: ()=>Navigator.pop(dctx,false), child: const Text('取消')),
                TextButton(onPressed: ()=>Navigator.pop(dctx,true), child: const Text('关闭'))],
    )).then((ok) { if (ok == true) context.read<AccountBloc>().add(
      UpdateAccountRequested(UpdateAccountParams(id: a.id, version: a.version, status: AccountStatus.archived))); });
  }
  void _delete(Account a) {
    showDialog<bool>(context: context, builder: (dctx) => AlertDialog(
      title: const Text('删除账户'), content: Text('删除「${a.name}」？此操作不可恢复。'),
      actions: [TextButton(onPressed: ()=>Navigator.pop(dctx,false), child: const Text('取消')),
                TextButton(onPressed: ()=>Navigator.pop(dctx,true), child: const Text('删除'))],
    )).then((ok) { if (ok == true) { context.read<AccountBloc>().add(DeleteAccountRequested(a.id)); context.pop(); } });
  }

  IconData _categoryIcon(AccountCategory c) => Icons.account_balance_wallet_outlined; // 复用 accounts_page._categoryIcon 或提取公共
  String _fmt(int cents) => '¥${(cents/100).toStringAsFixed(2)}';
  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}

class _Chip { final String label; final String value; _Chip(this.label, this.value); }
```

- [ ] **Step 2: router.dart 加 /accounts/:id 路由**

branch1（`/accounts`）改为带子路由：

```dart
StatefulShellBranch(routes: [
  GoRoute(
    path: '/accounts',
    builder: (context, state) => BlocProvider<AccountBloc>(
      create: (_) => getIt<AccountBloc>()..add(LoadAccountsRequested()),
      child: const AccountsPage(),
    ),
    routes: [
      GoRoute(
        path: ':id',
        builder: (context, state) => BlocProvider<AccountBloc>(
          create: (_) => getIt<AccountBloc>(),
          child: AccountDetailPage(id: state.pathParameters['id']!),
        ),
      ),
    ],
  ),
]),
```

> redirect 守卫 `startsWith('/accounts')` 已覆盖 `/accounts/:id`，无需改。

- [ ] **Step 3: 编译 + analyze**

Run: `cd yucai/client && flutter analyze lib/account/presentation/pages/account_detail_page.dart lib/app/router.dart`
Expected: 0 error。

- [ ] **Step 4: 提交**

```bash
git add yucai/client/lib/account/presentation/pages/account_detail_page.dart yucai/client/lib/app/router.dart
git commit -m "feat(client): AccountDetailPage（Hero 真实 + 统计/流水/持仓占位 + 操作）+ /accounts/:id 路由"
```

---

# Part D: 验证（Task 16）

## Task 16: 全栈验证

- [ ] **Step 1: 服务端全量测试**

Run: `cd yucai && make test`
Expected: 全部 PASS（domain/service/repo）。

- [ ] **Step 2: 客户端 analyze + 测试**

Run: `cd yucai && make flutter-test`
Expected: 0 error，全部测试 PASS。

- [ ] **Step 3: 重启全栈验证**

- 确保容器运行（`podman ps`，Postgres + Redis）
- 重启 Go 服务端（`cd yucai/server && go run ./cmd/server`，env 含 DATABASE_URL/JWT_SECRET；ent Schema.Create 自动加 26 nullable 列，已有账户字段为 NULL）
- 重启 Flutter 客户端（`cd yucai/client && flutter run -d windows --dart-define=...`）

- [ ] **Step 4: 手动验证（客户端操作）**

1. 新建账户 → 选「信用卡」→ 表单显示专属字段（发卡机构/卡号尾号/当前欠款/信用额度/账单日/还款日/年费/APR）；切「贷款」→ 切换（贷款机构/剩余本金/原始本金/利率/期限/月供/下次还款日）；切「黄金外汇」→ 品种/数量/买入价/现价
2. 创建「信用卡」填专属字段 → 服务端 OK → 详情页 Hero 展示信用额度/账单日/还款日/APR chip
3. 卡片 `⋯` 菜单 → 7 项（查看详情/编辑/复制/记一笔🔒/转账🔒/关闭/删除）；编辑 → 表单预填 → 改利率保存 → 详情刷新
4. 复制 → 表单预填（id 清空）→ 保存创建新账户
5. 关闭账户 → 确认 → status=archived；删除账户 → 确认 → 软删
6. 查看详情 → `/accounts/:id` → Hero 真实专属字段 + 统计/流水/持仓「待 Transaction/Holding 模块」占位
7. 查 DB：`podman exec yucai-pg psql -U yucai -d yucai -c "SELECT name, category, interest_rate, credit_billing_day, loan_remaining_cents FROM accounts;"` → 专属字段落库
8. 已有账户 26 字段为 NULL（迁移后默认）

- [ ] **Step 5: 提交（如有验证修复）**

```bash
git add -A
git commit -m "test(account): 全栈验证 26 类型专属字段 + 动态表单 + 卡片操作 + 详情页"
```

- [ ] **Step 6: graphify 更新**

Run: `graphify update .`（保持知识图谱最新，AST-only）。

---

## Self-Review 结果

- **Spec 覆盖**:
  - §domain 26 字段（category 前缀命名）→ Task 1（26 新增 + CreditLimitCents 复用）✓
  - §表单按 category 动态 → Task 12（category_fields）+ Task 13（form page 动态）✓
  - §卡片操作（查看/编辑/复制/关闭/删除真实 + 记一笔/转账🔒）→ Task 14 ✓
  - §详情页（Hero 真实 + 统计/流水/持仓占位 + 操作）→ Task 15 ✓
  - §功能对接策略（account 真实 + transaction/holding 占位）→ Task 14/15 占位标注 ✓
  - §固定列 nullable → Task 1/2/3（指针 + ent Nillable + proto optional）✓
  - §主金额语义随 category → 设计决策 4 + Task 13 `_primaryCentsOf`/`_initialCentsForCreate`（InvestCost/FixedPrincipal/GoldBuyPrice/EstatePurchasePrice/LoanRemaining）✓
  - §利率语义随 category → 设计决策 5 + Task 12 `rateLabel` + Task 13 `_rateOf`（InterestRate/InvestReturnYtd/EstateDepreciationRate）✓
- **类型一致**:
  - 26 字段名在 domain/ent/proto/dart 四层一致（字段总表）✓
  - proto 字段号：DTO 19-44 / Create 13-38 / Update status=9 + 10-35 不冲突 ✓
  - `AccountProfile`/`ApplyProfile`/`CreateRequestToProfile`/`UpdateRequestToProfile` 命名统一 ✓
  - client `UpdateAccountParams`/`UpdateAccountRequested`/`UpdateAccountUseCase` 命名统一 ✓
  - helper `ts/optTs/optStr/i32ToInt/intToI32/statusPtr` 在 handler 集中定义 ✓
  - 主金额映射：create 用 `_initialCentsForCreate` + 专属字段；edit 用专属字段（不进 initial）✓
- **无 placeholder**:
  - 所有代码步骤含完整代码或完整字段清单（引用字段总表，非省略）✓
  - Task 7/9/10 的 proto getter/setter 名标注"以生成 pb 为准"+ 给 grep 确认命令 ✓
  - Task 13 日期字段（DatePickerInput 是 FormField 非 controller）标注实现提示（state 字段 + onSaved），非占位 ✓
- **已知执行风险（执行时验证，非计划缺陷）**:
  1. ent `Optional().Nillable()` setter 名 → Task 6 Step2 grep 确认
  2. proto optional scalar Dart `hasX()`/getter → Task 9 已用守卫
  3. Timestamp Dart 导入包名 → Task 10 Step4 标注以生成 import 为准
  4. `make proto`/`make generate` 在 yucai 根执行
  5. Task 13 日期持久化需 state 字段 + onSaved（DatePickerInput 当前是 FormField），Task 16 验证时确认日期落库
