# 账户修改功能全面审计设计文档

**日期**: 2026-06-05
**参照标准**: YNAB / GNU Cash / Wallet 等消费级记账应用
**审计范围**: UI/UX、功能逻辑、数据结构、账户分类与布局

---

## 1. 维度 1：UI/UX 审计

### 1.1 🔴 严重问题

**P1: 复制功能实际不工作**
- 位置: `AccountsPage.tsx:375-379`
- `handleEditSubmit` 检查 `'id' in data`，Copy Sheet 提交时不带 `id`，导致 mutation 不执行
- 用户点击复制 → 填写 → 提交 → 静默失败，无任何反馈
- 行业标准: YNAB 复制时自动添加 "(Copy)" 后缀，允许用户修改后创建新账户

**P2: 无法清除已填写的可选字段**
- 前端空字符串 → `undefined` → 后端 `None` → 跳过更新
- 5-6 个可选字段（account_number, institution, credit_limit, billing_day, payment_due_day, interest_rate）永远无法清除
- 行业标准: JSON Merge Patch (RFC 7396) — `null` 表示清除，`undefined` 表示不修改
- 修复: DTO 使用 `Option<Option<T>>` 或前端显式发送 `null` 表示清除

**P3: 编辑模式不可变字段缺少解释**
- type/ownership/currency 在编辑模式被禁用且视觉变灰，但没有 tooltip 说明原因
- 行业标准: 不可编辑字段旁加 info icon，提示"货币一旦设定不可更改，因为影响已有交易记录"

### 1.2 🟡 设计缺陷

**P4: 两个创建入口不一致**
- `AccountWizard`（3步向导）和 `NewAccountPage`+`AccountForm`（单页）各自维护状态
- 向导手动 useState（无 Zod 验证），表单用 react-hook-form + Zod
- 验证规则、默认值、字段分组完全不同

**P5: 编辑入口不够直观**
- 列表页小铅笔图标触发 Sheet 编辑
- 行业标准: 点击账户名称进入详情页，编辑按钮在详情页顶部（YNAB 5.0 的模式）

**P6: 缺少变更确认**
- 编辑保存直接提交，不展示"你修改了什么"
- 金融应用应在保存前展示变更差异

### 1.3 🟢 做得好的

- 类型驱动的条件字段（CreditCard/Borrowed/Prepaid）展开逻辑正确
- Ownership（资产/收支）分类符合中国会计准则大体方向
- 编辑时只读展示当前余额，可改动的是初始余额
- 删除使用乐观更新+回滚

---

## 2. 维度 2：功能逻辑审计

### 2.1 🔴 严重问题

**P7: UpdateAccountDto "None = 不修改"设计**
- 所有可选字段使用 `if let Some(x) = dto.x` 模式
- 结合前端空字符串→undefined，导致无法清除可选字段
- 与 P2 是同一问题的前后端两面
- 修复: 区分 `null`（清除）和 `undefined`（不修改）语义

**P8: 修改初始余额无确认**
- `update_initial_balance` 直接修改字段并发出 `BalanceUpdated` 事件
- 当前余额 = initial_balance + net_change，改初始余额会立即改变显示余额
- 没有任何确认提示或警告
- 行业标准: YNAB 在修改开户余额时会说明"这将改变你的账户余额"

**P9: 更新时不检查名称唯一性**
- `create_account` 检查 `find_by_name` 防止重名
- `update_account` 的 `change_name` 不做任何名称冲突检查
- 可导致多个账户同名

### 2.2 🟡 设计缺陷

**P10: 负余额校验逻辑有限**
- 禁止 Cash/Bank/Investment/BorrowedOut/Prepaid 的初始余额为负
- 但交易可以让余额变负，校验只限制了创建时
- 初始余额的限制是否合理取决于用户场景（如表示欠款），需要重新审视

**P11: low_balance_threshold 绕过领域模型**
- `account_service.rs:163` 直接赋值 `account.low_balance_threshold = dto.low_balance_threshold`
- 其他所有字段通过 `update_*` 方法设置，违反 DDD 聚合根原则
- 应增加 `update_low_balance_threshold()` 方法

**P12: AccountStatus/OpenedAt 僵尸字段**
- 数据库有列，域模型有枚举，但无任何功能操作它们
- 前端无归档/隐藏入口，PostgreSQL 仓库不读取这些字段

**P13: 复制功能逻辑断裂**
- 与 P1 同一问题：Copy Sheet 的 `onSubmit` 走 `handleEditSubmit`，但缺少 `id`，实际丢掉了创建 mutation

**P14: 预设模板名称硬编码中文**
- `account_service.rs:21-64` 中模板名 `"股票账户"` 等硬编码
- 前端使用 `t('accounts.templates.xxx')` i18n key
- 前后端名称不一致：前端翻译后创建的账户名 != 后端批量创建的名称

### 2.3 🟢 做得好的

- `ensure_not_deleted()` 在所有 setter 方法中被调用，防止修改已删除账户
- 三层验证架构（Zod → Domain → DB CHECK）层次清晰
- `touch()` 自动更新 `updated_at` 并清除 `synced_at`
- 删除使用乐观更新+回滚，用户体验好

---

## 3. 维度 3：数据结构审计

### 3.1 🔴 严重问题

**P15: DB "loan" 类型值是幽灵数据**
- 数据库 CHECK 约束允许 `'loan'`，但 Rust 枚举已移除 `Loan` 变体
- 如果数据库中存在旧 `loan` 行，`row_to_account` 返回 Decode Error，导致列表页崩溃
- 需要: 数据迁移将 `loan` → `borrowed_in`，并更新 CHECK 约束

**P16: Decimal 字段全用 TEXT 存储**
- `initial_balance`、`credit_limit`、`interest_rate`、`low_balance_threshold` 都是 TEXT
- 无法在 DB 层做数值比较/排序/聚合
- 每次读写需 Decimal ↔ String 互转
- 行业标准: SQLite 用整数分（如 YNAB 存储所有金额为整数分）

**P17: AccountDto 缺少 low_balance_threshold/status/opened_at**
- 前端 `AccountsPage:154` 引用 `account.low_balance_threshold`
- 但 `AccountDto` 的 `From<Account>` 实现没有序列化该字段
- 低余额警告可能从不工作
- status/opened_at 同样缺失

### 3.2 🟡 设计缺陷

**P18: created_at 是假的**
- `AccountDto::created_at = account.sync_metadata.updated_at`
- 没有真正的 `created_at` 列
- 行业标准: 所有金融产品区分创建时间和修改时间

**P19: billing_day/payment_due_day 类型链过长**
- string (前端) → i32 (DTO) → u8 (领域) → i64 (DB) → u8 (读回)
- Zod 验证字符串范围，领域验证整数范围，DB CHECK 验证整数范围
- 应统一为一层验证

**P20: UpdateAccountDto 中 currency_code 是多余的**
- 存在但服务层完全忽略
- `update_currency_code()` 永远返回 `CurrencyMismatch`
- 误导性字段，应该删除

**P21: PostgreSQL 仓库严重不完整**
- 8 个字段（account_number, institution, credit_limit, billing_day, payment_due_day, interest_rate, low_balance_threshold, chart_code）不被读取
- 未来启用 PG 同步会丢失数据

**P22: parent_id 无循环引用保护**
- DB 有 `parent_id REFERENCES accounts(id)` 但无环路检测
- 前端完全不使用层级展示
- "写了但没用"的字段

### 3.3 🟢 做得好的

- 软删除 `deleted_at` 时间戳模式，查询时 `WHERE deleted_at IS NULL` 过滤
- `SyncMetadata` 值对象封装元数据字段
- 余额计算 `compute_balances_for_all_accounts` 批量查询效率好
- `Money` 值对象保证金额和币种不分离

---

## 4. 维度 4：账户分类与 UI 布局

### 4.1 核心问题

**Ownership 两分法无法表达中国会计准则五大类**
- 当前: `Own` / `External` 两个值
- 会计准则: 资产 / 负债 / 所有者权益 / 成本 / 损益 五大类
- CreditCard（负债）和BorrowedIn（负债）被错误归入 `Own`
- 缺少"所有者权益"类别

**AccountWizard Step 1 预览硬编码不全**
- 代码第263行 `['Cash','Bank','CreditCard','Investment','Prepaid']` 只列5种
- Step 2 实际有8种（缺 BorrowedOut、BorrowedIn、Other）
- 预览与实际选择不一致

**AccountForm 扁平选择器无分组**
- 一个 Select 下拉10种类型，没有层级
- 用户无法直观区分资产/负债/收支

### 4.2 选择方案: 方案 B — Ownership 扩展为三类

**数据模型变更:**
```
Ownership::Own        → 资产类 (Cash, Bank, Investment, BorrowedOut, Prepaid, Other)
Ownership::Liability  → 负债类 (CreditCard, BorrowedIn)    [新增]
Ownership::External   → 收支类 (Income, Expense)
```

**UI 布局变更:**

向导 Step 1 改为三选一卡片:
1. 🏦 资产账户 — 现金、银行、投资、预付卡、借出款项
2. 💳 负债账户 — 信用卡、借入款项
3. 📊 收支账户 — 收入、支出

向导 Step 2 和编辑模式 Select 使用分组下拉（Radix SelectGroup）:
- 资产类 → Cash, Bank, Investment, Prepaid, BorrowedOut, Other
- 负债类 → CreditCard, BorrowedIn
- 收支类 → Income, Expense

**净资产 = 资产 - 负债**，不需要单独的"所有者权益"账户类型。由应用自动计算并展示在首页总览区域（如总资产、总负债、净资产三行摘要卡片）。

**前端 ownership 筛选逻辑同步更新:**
- `AccountsPage` 中 `list_accounts_by_ownership` 需要处理新的 `Liability` 类型
- 类型过滤按钮组从 `资产/收支` 变为 `资产/负债/收支`
- AccountWizard Step 1 从两卡片变为三卡片
- AccountForm 的 ownership toggle 从双按钮变为三按钮（或编辑模式下只读展示现有分类）

**DB 迁移:**
- 新增 `ownership` 值 `'liability'`
- 将现有 `CreditCard`/`BorrowedIn` 账户的 `ownership` 从 `'own'` 改为 `'liability'`
- 更新 CHECK 约束

**余额验证调整:**
- `Liability` 类型的初始余额允许为负（信用卡透支、借款）
- `Own` 类型的初始余额仍不允许为负（除了调整后的规则）

---

## 5. 优先级排序

| 优先级 | 编号 | 问题 | 影响面 | 状态 |
|--------|------|------|--------|------|
| P0 | P1 | 复制功能不工作 | 功能完全不可用 | ✅ Sprint 1 |
| P0 | P17 | AccountDto 缺字段导致低余额警告失效 | 功能完全不可用 | ✅ Sprint 1 |
| P0 | P15 | DB "loan" 幽灵数据导致潜在崩溃 | 数据完整性 | ✅ Sprint 1 |
| P1 | P2/P7 | 无法清除可选字段 | 用户无法删除已填信息 | ✅ Sprint 1 |
| P1 | P8 | 修改初始余额无确认 | 金融安全 | ✅ Sprint 1 |
| P1 | 维度4 | Ownership 三类扩展 | 会计概念正确性 | ✅ Sprint 1 |
| P1 | P23 | 列表页缺少总资产/总负债/净资产摘要 | 用户核心信息需求 | ✅ Sprint 1 |
| P1 | P24 | 列表页类型扁平排列不匹配三类模型 | 信息架构 | ✅ Sprint 1 |
| P1 | P26/P31/P32 | 删除无确认弹窗无级联说明 | 操作安全性 | ✅ Sprint 1 |
| P2 | P3/P30 | 不可变字段无解释 | UX | ✅ Sprint 1 |
| P2 | P9 | 更新时不检查名称唯一性 | 数据一致性 | ✅ Sprint 1 |
| P2 | P11 | low_balance_threshold 绕过领域模型 | DDD 原则 | ✅ Sprint 1 |
| P2 | P14 | 后端模板名称硬编码中文 | i18n | ✅ Sprint 2 |
| P2 | P18 | created_at 是假的 | 数据完整性 | ✅ Sprint 2 |
| P2 | P4/P28 | 向导预览不全 | 代码维护+UX一致性 | ✅ Sprint 2 |
| P3 | P12 | AccountStatus/OpenedAt 僵尸 | 未来功能 | ✅ Sprint 3 |
| P3 | P20 | currency_code 多余字段 | 代码清洁 | ✅ Sprint 3 |
| P3 | P22 | parent_id 无保护 | 未来风险 | ✅ Sprint 3 |
| P3 | P5 | 编辑入口不够直观 | UX 改进 | 🔜 延期 |
| P3 | P6 | 缺少变更确认 | UX 改进 | 🔜 延期 |
| P3 | P10 | 负余额校验逻辑需重新审视 | 业务规则 | 🔜 延期 |
| P3 | P13 | 复制功能同 P1 | 同一问题 | ✅ Sprint 1 |
| P3 | P16 | Decimal TEXT 存储 | 数据完整性 | 🔜 延期 |
| P3 | P19 | 类型链过长 | 代码质量 | 🔜 延期 |
| P3 | P21 | PG 仓库不完整 | 未来风险 | 🔜 延期 |

---

## 5. 维度 5：页面设计审计

### 5.1 账户列表页

**当前问题：**
- P23: 缺少总资产/总负债/净资产汇总卡片 — 用户无法一目了然看到整体财务状况
- P24: 10种类型扁平排列，没有按「资产/负债/收支」大组分类 — 与维度4三类模型不匹配
- P25: 每行操作按钮过多（5个小图标）— 可读性差，移动端尤其拥挤
- P26: 删除使用行内确认（确认/取消文字按钮），无账户名确认 — 易误触
- P27: 搜索和过滤区域扁平拥挤 — 缺乏空间层次

**改进设计：**
- 顶部增加「总资产/总负债/净资产」三张摘要卡片，数值实时计算
- 分类过滤从类型10选1改为 Ownership 三类下拉（全部/资产/负债/收支）
- 表格按「资产类/负债类/收支类」三层分组，每组有颜色编码的小标题
- 操作列精简为「编辑」文字按钮，不再堆叠5个图标按钮
- 删除改为正式 Dialog 确认弹窗（见 5.4）

### 5.2 创建账户页面

**当前问题：**
- P4（同维度1）: 两个创建入口不一致 — AccountWizard (3步向导) 与 NewAccountPage + AccountForm (单页表单) 各自维护状态
- P28: 向导 Step 1 预览标签只列5种类型，Step 2 有8种 — 不一致
- P29: 向导 Step 3 未复用 AccountForm 组件 — 手动 useState 验证逻辑重复

**改进设计：**
- 删除 `NewAccountPage`，统一使用 AccountWizard 作为唯一创建入口
- Step 1 改为三张卡片：🏦资产 / 💳负债 / 📊收支（匹配维度4三类模型）
- Step 1 预览标签与 Step 2 选项完全一致，所有子类型都列出
- Step 3 复用 AccountForm 组件（增加 `mode="create"` + `ownership`/`accountType` 预填）
- 货币选择器从「高级选项」移到 Step 3 核心区域（因为它影响余额显示）

### 5.3 编辑账户页面

**当前问题：**
- P3（同维度1）: 编辑使用右侧 Sheet，不可变字段（type/ownership/currency）被禁用且变灰，无解释
- P30: Sheet 宽度受限（sm:max-w-lg），移动端体验差，字段拥挤
- P8（同维度2）: 修改初始余额无确认警告

**改进设计：**
- Sheet → 路由页面（/accounts/:id/edit），空间更充分
- 顶部信息卡展示不可变字段（类型/所有权/币种），币种旁有 ℹ 提示"设定后不可修改"
- 当前余额只读展示：大字体 + 颜色（正数绿/负数红）+ 说明"由初始余额和交易记录自动计算"
- 初始余额修改前显示黄色警告：「⚠ 修改初始余额将影响当前余额」
- 可选字段增加清除按钮（×），清除时发送 `null` 而非 `undefined`

### 5.4 删除流程

**当前问题：**
- P26: 行内确认只出现「确认」「取消」文字按钮
- P31: 无账户名确认 — 用户可能不知道删的是哪个
- P32: 无级联影响说明 — 不告知交易记录会怎样

**改进设计：**
- 使用 Dialog 确认弹窗：
  - 标题：「删除账户」
  - 内容：「确定要删除"<账户名>"吗？该账户的 N 笔交易记录将保留，但账户将被标记为已删除。」
  - 按钮：[取消] [确认删除（红色 destructive variant）]
  - 删除进行中：按钮显示 spinner 并禁用
- 保留乐观更新+回滚策略，错误时 toast 提示