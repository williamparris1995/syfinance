# 账户类型专属字段 + 完整 UI 原型设计

**日期**: 2026-06-15（2026-06-16 修订字段命名）
**状态**: 已确认
**范围**: Account 模块类型专属字段（26 字段，category 前缀命名）+ 表单/卡片/详情页完整 UI 原型；account 功能真实，transaction/holding 功能占位（待其他模块对接）
**前置**: [账户 category 设计](2026-06-15-account-category-design.md)（已完成，9 类 category）

## 目标

1. 补全 Account 模型的类型专属字段（行业惯例 Mint/Quicken/随手记），使不同 category 的账户有差异化字段（信用卡额度/账单日、贷款利率/月供、投资收益率、定期到期日等）
2. 创建表单按 category 完全动态切换字段集（非"基本信息+专属"两层，而是每类一套完整字段）
3. 账户卡片 + 详情页支持完整操作（编辑/删除/记账/转账/复制/关闭）+ 详情展示（Hero + 统计/流水/持仓占位）
4. 调用 open-design 设计完整 UI 原型（form 9 类 / accounts 卡片操作 / detail 详情页）

## 行业调研

### 账户操作（Mint/YNAB/Quicken/随手记/Personal Capital）
查看详情、编辑、删除、记账、转入/转出、对账、复制、关闭/归档、隐藏

### 详情页内容
- Hero（余额 + 类型 + 专属字段）
- 余额趋势图（日/月）— 依赖每日余额快照
- 交易流水 — 依赖 transaction
- 收支统计（分类/月度）— 依赖 transaction
- 持仓（投资）/还款计划（贷款）— 依赖 holding/payment_schedule

### 字段存储最佳实践
- 账户级别元数据（额度/账单日/利率/到期日）→ **固定列 nullable**（Mint/Quicken/随手记主流）
- 复杂关联（投资持仓/贷款分期）→ 子实体（holding/payment_schedule，yucai 已有模块）
- 纯 JSON 极少见（仅 GnuCash slots）

## 设计决策

1. **固定列 nullable**（非 JSON/子实体）：26 字段加到 Account，nullable 用指针。类型安全 + 查询方便 + proto 强类型 + 符合 Mint/Quicken 主流。
2. **category 前缀命名 + 注释（2026-06-16 修订）**：独占字段加 category 前缀（`credit_`/`invest_`/`fixed_`/`gold_`/`estate_`/`loan_`），看名即知归属与用途，避免 `BuyPriceCents`(黄金) vs `PurchasePriceCents`(固定资产) 这类同名混淆；跨 category 共享字段（利率/卡号尾号/备注/开户日）保持通用名。原 `PrincipalCents`（投资成本/定期本金/贷款本金三义）拆为 `InvestCostCents`/`FixedPrincipalCents`/`LoanOriginalCents`。每字段附中文注释。
3. **表单按 category 完全动态**：每类一套完整字段（非"基本信息+专属"两层）。金额/卡号/日期语义随 category。
4. **完整 UI 原型 + 占位策略**：account 相关功能真实（编辑/删除/复制/关闭 + 专属字段），transaction/holding 相关 UI 完整但数据占位（"待模块"提示）。

## Section 1: domain 字段（26 字段，固定列 nullable，category 前缀命名）

> 26 = 新增字段数（`CreditLimitCents` 已存在于 domain/ent/proto，不重复计）。命名：domain PascalCase / proto snake_case（见各表 proto 列）。

### 共享字段（跨 category）
| 字段(domain) | proto | Go 类型 | 说明 |
|------|------|------|------|
| `CardNumberTail` | `card_number_tail` | string | 卡号/账号尾号（金融类：储蓄/信用卡/投资/定期/贷款） |
| `Notes` | `notes` | string | 备注（全部 category） |
| `OpeningDate` | `opening_date` | *time.Time | 开户日期（金融类） |
| `InterestRate` | `interest_rate` | *float64 | 年化利率(%)：储蓄=存款利率、定期=存期利率、贷款=贷款利率、信用卡=APR |

### 信用卡专属（`credit_`）
| 字段(domain) | proto | Go 类型 | 说明 |
|------|------|------|------|
| `CreditLimitCents` | `credit_limit_cents` | int64 ✅已有 | 信用额度 |
| `CreditBillingDay` | `credit_billing_day` | *int(1-31) | 账单日 |
| `CreditRepaymentDay` | `credit_repayment_day` | *int(1-31) | 还款日 |
| `CreditAnnualFeeCents` | `credit_annual_fee_cents` | *int64 | 年费 |

### 投资专属（`invest_`）
| 字段(domain) | proto | Go 类型 | 说明 |
|------|------|------|------|
| `InvestCostCents` | `invest_cost_cents` | *int64 | 投入成本（买入总成本） |
| `InvestMarketValueCents` | `invest_market_value_cents` | *int64 | 当前市值 |
| `InvestReturnYtd` | `invest_return_ytd` | *float64 | 今年收益率(%) |

### 定期专属（`fixed_`）
| 字段(domain) | proto | Go 类型 | 说明 |
|------|------|------|------|
| `FixedPrincipalCents` | `fixed_principal_cents` | *int64 | 本金 |
| `FixedStartDate` | `fixed_start_date` | *time.Time | 起息日 |
| `FixedMaturityDate` | `fixed_maturity_date` | *time.Time | 到期日 |
| `FixedTermMonths` | `fixed_term_months` | *int | 期限(月) |

### 黄金外汇专属（`gold_`）
| 字段(domain) | proto | Go 类型 | 说明 |
|------|------|------|------|
| `GoldProductType` | `gold_product_type` | string | 品种（如实物黄金/美元 USD） |
| `GoldQuantity` | `gold_quantity` | *float64 | 持有数量 |
| `GoldBuyPriceCents` | `gold_buy_price_cents` | *int64 | 买入价 |
| `GoldCurrentPriceCents` | `gold_current_price_cents` | *int64 | 现价 |

### 固定资产专属（`estate_`）
| 字段(domain) | proto | Go 类型 | 说明 |
|------|------|------|------|
| `EstatePurchasePriceCents` | `estate_purchase_price_cents` | *int64 | 买入价 |
| `EstateCurrentValueCents` | `estate_current_value_cents` | *int64 | 现估值 |
| `EstatePurchaseDate` | `estate_purchase_date` | *time.Time | 买入日期 |
| `EstateDepreciationRate` | `estate_depreciation_rate` | *float64 | 折旧率(%) |

### 贷款专属（`loan_`）
| 字段(domain) | proto | Go 类型 | 说明 |
|------|------|------|------|
| `LoanOriginalCents` | `loan_original_cents` | *int64 | 原始贷款本金 |
| `LoanRemainingCents` | `loan_remaining_cents` | *int64 | 剩余本金 |
| `LoanMonthlyCents` | `loan_monthly_cents` | *int64 | 月供 |
| `LoanNextPaymentDate` | `loan_next_payment_date` | *time.Time | 下次还款日 |

### 类型约定
- nullable 字段用指针（`*int`/`*float64`/`*time.Time`/`*int64`），区分"未填"和"零值"
- string 字段非指针（`""`=未填）：`CardNumberTail`/`Notes`/`GoldProductType`
- 金额统一 *int64 cents（`CreditLimitCents` 已有的 int64 保留不动）
- 利率/收益率/折旧率用 `*float64`（百分比，3.85 = 3.85%）
- proto3 用 `optional` 关键字映射 nullable scalar；日期用 `google.protobuf.Timestamp`
- ent schema：指针字段 `Optional().Nillable()`，string 字段 `Optional().Default("")`

## Section 2: 表单按 category 完全动态字段集

**通用字段**（所有 category）：账户名称*、币种(select)、备注

**category 字段模板**：

| category | 字段集 |
|----------|--------|
| 储蓄 | 机构(select) / 卡号尾号 / **初始余额**(AmountInput) / 利率(%) / 开户日期 |
| 信用卡 | 机构 / 卡号尾号 / **当前欠款** / 信用额度 / 账单日(select 1-31) / 还款日(select) / 年费 / APR(%) |
| 投资 | 机构(券商) / 账号尾号 / **成本** / 市值 / 今年收益率(%) |
| 定期 | 机构 / 账号尾号 / **本金** / 利率(%) / 起息日 / 到期日 / 期限(月) |
| 黄金外汇 | 品种 / 数量 / **买入价** / 现价 |
| 固定资产 | **买入价** / 现估值 / 买入日期 / 折旧率(%) |
| 贷款 | 机构 / **剩余** / 原始本金 / 利率(%) / 期限(月) / 月供 / 下次还款 |
| 其他资产/负债 | **金额** / 备注 |

**关键 — 主金额语义随 category，存到对应字段（非统一存 InitialBalanceCents）**：
| category | AmountInput label | 存到字段 |
|----------|------------------|---------|
| 储蓄 / 其他资产 / 其他负债 | 初始余额 / 金额 | `InitialBalanceCents`（已有） |
| 信用卡 | 当前欠款 | `InitialBalanceCents`（currentBalance 初始为负） |
| 投资 | 成本 | `InvestCostCents` |
| 定期 | 本金 | `FixedPrincipalCents` |
| 黄金外汇 | 买入价 | `GoldBuyPriceCents` |
| 固定资产 | 买入价 | `EstatePurchasePriceCents` |
| 贷款 | 剩余本金 | `LoanRemainingCents`（原始本金另填 `LoanOriginalCents`） |

- 卡号/开户日期按 category 显示（金融类有，实物类无）
- 机构按 category（金融类有，实物类无）

**UI 组件**：
- 金额 → `AmountInput`（复用）
- 日期 → 新增 `DatePickerInput`
- 账单日/还款日 → DropdownButtonFormField（1-31）
- 机构 → DropdownButtonFormField（常用银行 + 其他）
- 利率/收益率/数量/折旧率 → 数字 TextFormField

**交互**：切 category → 字段集即时切换，已填专属字段不跨 category 保留（切走清空）。

## Section 3: 卡片操作按钮

卡片右上角操作菜单（`⋯` PopupMenu）：

| 操作 | 功能状态 |
|------|---------|
| 查看详情 | ✅ account 真实 + transaction 占位 |
| 编辑 | ✅ account 真实（编辑表单预填）|
| 记一笔 | 🔒 transaction 占位 |
| 转入/转出 | 🔒 transaction 占位 |
| 复制 | ✅ account 真实（创建表单预填，seed 模式）|
| 关闭/归档 | ✅ account 真实（status=archived）|
| 删除 | ✅ account 已有（软删 deleted_at）|

🔒 项禁用 + tooltip「待 Transaction 模块」。

## Section 4: 详情页 `/accounts/:id`

```
顶栏：账户管理 / {账户名}     [编辑] [记一笔🔒] [转账🔒] [⋯ 更多(复制/关闭/删除)]
├── Hero 卡（category 专属字段全展示：额度/账单日/利率/到期日/收益率…）
├── 快速统计行（4 StatCard：本月收入/支出/净值/交易数）🔒 transaction 占位
├── 两栏：
│   ├── 左：交易流水（近期交易 + 查看全部）🔒 transaction 占位
│   └── 右：收支统计（分类饼图）🔒 transaction 占位
└── 类型专属面板：
    ├── 投资 → 持仓列表 🔒 holding 占位
    └── 贷款 → 还款计划 🔒 payment_schedule 占位
```

**功能状态**：
- ✅ 真实：Hero（专属字段）、编辑/复制/关闭/删除、路由 `/accounts/:id`、操作按钮
- 🔒 占位（UI 完整，数据空 + "待模块"提示）：统计、交易流水、持仓、还款计划

## 功能对接策略

| 功能 | 本次 | 依赖 |
|------|------|------|
| 26 专属字段（domain/proto/ent/表单/卡片/详情）| ✅ 真实 | account |
| 编辑/复制/关闭/删除 | ✅ 真实 | account |
| 详情页 Hero + 路由 | ✅ 真实 | account |
| 记一笔/转账/交易流水/收支统计 | 🔒 UI 占位 | transaction 模块（后续）|
| 持仓面板 | 🔒 UI 占位 | holding 客户端（后续）|
| 还款计划面板 | 🔒 UI 占位 | payment_schedule 客户端（后续）|
| 余额趋势/每日快照 | 🔒 UI 占位 | 每日快照表（后续）|

## open-design 原型

调用 open-design MCP 设计完整原型：
1. **form-account**（9 类 category 动态字段集）
2. **accounts 卡片**（操作按钮行）
3. **detail-account**（Hero + 统计/流水/持仓占位 + 操作）

## 约束

- 不改动 category 设计（已完成）
- 26 字段固定列（非 JSON/子实体），category 前缀命名
- transaction/holding 功能占位，不实现真实数据
- 渐进式：本次 account 真实 + 占位，后续模块对接
