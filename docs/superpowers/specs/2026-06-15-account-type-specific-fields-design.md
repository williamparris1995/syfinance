# 账户类型专属字段 + 完整 UI 原型设计

**日期**: 2026-06-15
**状态**: 已确认
**范围**: Account 模块类型专属字段（25 字段）+ 表单/卡片/详情页完整 UI 原型；account 功能真实，transaction/holding 功能占位（待其他模块对接）
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

1. **固定列 nullable**（非 JSON/子实体）：25 字段加到 Account，nullable 用指针。类型安全 + 查询方便 + proto 强类型 + 符合 Mint/Quicken 主流。
2. **表单按 category 完全动态**：每类一套完整字段（非"基本信息+专属"两层）。金额/卡号/日期语义随 category。
3. **完整 UI 原型 + 占位策略**：account 相关功能真实（编辑/删除/复制/关闭 + 专属字段），transaction/holding 相关 UI 完整但数据占位（"待模块"提示）。

## Section 1: domain 字段（25 字段，固定列 nullable）

字段合并去重：`AprRate`→`InterestRate`、`Broker`→`Institution`(已有)、`CostBasisCents`→`PrincipalCents`。

### 通用字段
| 字段 | 类型 | 说明 |
|------|------|------|
| `LastFourDigits` | string | 卡号/账号尾号 |
| `OpeningDate` | *time.Time | 开户日期 |
| `Notes` | string | 备注 |

### 金融通用（跨 category 共享）
| 字段 | 类型 | category |
|------|------|----------|
| `InterestRate` | *float64 | 储蓄/定期/贷款/信用卡(APR) |
| `PrincipalCents` | int64 | 投资(成本)/定期/贷款(本金) |

### 信用卡专属
| 字段 | 类型 | 说明 |
|------|------|------|
| `CreditLimitCents` | int64 ✅已有 | 信用额度 |
| `BillingDay` | *int(1-31) | 账单日 |
| `RepaymentDay` | *int(1-31) | 还款日 |
| `AnnualFeeCents` | int64 | 年费 |

### 投资专属
| 字段 | 类型 | 说明 |
|------|------|------|
| `MarketValueCents` | int64 | 当前市值 |
| `ReturnRateYtd` | *float64 | 今年收益率(%) |

### 定期专属
| 字段 | 类型 | 说明 |
|------|------|------|
| `StartDate` | *time.Time | 起息日 |
| `MaturityDate` | *time.Time | 到期日 |
| `TermMonths` | *int | 期限(月) |

### 黄金外汇专属
| 字段 | 类型 | 说明 |
|------|------|------|
| `ProductType` | string | 品种(gold/usd/...) |
| `Quantity` | *float64 | 数量 |
| `BuyPriceCents` | int64 | 买入价 |
| `CurrentPriceCents` | int64 | 现价 |

### 固定资产专属
| 字段 | 类型 | 说明 |
|------|------|------|
| `PurchasePriceCents` | int64 | 买入价 |
| `CurrentValueCents` | int64 | 现估值 |
| `PurchaseDate` | *time.Time | 买入日期 |
| `DepreciationRate` | *float64 | 折旧率(%) |

### 贷款专属
| 字段 | 类型 | 说明 |
|------|------|------|
| `RemainingCents` | int64 | 剩余本金 |
| `MonthlyPaymentCents` | int64 | 月供 |
| `NextPaymentDate` | *time.Time | 下次还款 |

### 类型约定
- nullable 字段用指针（`*int`/`*float64`/`*time.Time`），区分"未填"和"零值"
- 金额统一 int64 cents
- 利率/收益率/折旧率用 `*float64`（百分比，3.85 = 3.85%）
- proto3 用 `optional` 关键字映射 nullable
- ent schema 加 nullable 列

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
| 贷款 | 机构 / **剩余** / 本金 / 利率(%) / 期限(月) / 月供 / 下次还款 |
| 其他资产/负债 | **金额** / 备注 |

**关键**：
- 金额字段语义随 category（AmountInput label 动态：初始余额/当前欠款/剩余/成本/买入价…），都存 `InitialBalanceCents`
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

卡片 hover 底部浮现操作图标行（或长按/右键菜单）：

| 操作 | 功能状态 |
|------|---------|
| 查看详情 | ✅ account 真实 + transaction 占位 |
| 编辑 | ✅ account 真实（编辑表单预填）|
| 记一笔 | 🔒 transaction 占位 |
| 转入/转出 | 🔒 transaction 占位 |
| 复制 | ✅ account 真实（创建表单预填）|
| 关闭/归档 | ✅ account 真实（状态切换）|
| 删除 | ✅ account 已有 |

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
| 25 专属字段（domain/proto/ent/表单/卡片/详情）| ✅ 真实 | account |
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
- 25 字段固定列（非 JSON/子实体）
- transaction/holding 功能占位，不实现真实数据
- 渐进式：本次 account 真实 + 占位，后续模块对接
