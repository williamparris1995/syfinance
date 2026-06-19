# 御财交易模块重构设计

- **日期**: 2026-06-19
- **状态**: 设计已确认，待转实施计划
- **范围**: 范围 A（核心闭环）
- **分类模型**: 方案 A（account-as-category）
- **实施方法**: 方法 3（全栈按特性垂直切片）

## 1. 概述

御财 YuCai（复式记账 + 中国会计准则的个人理财应用，Go+PostgreSQL+gRPC 服务端 + Flutter 客户端）的交易模块重构。本期交付一个能端到端跑通的核心闭环：**分类 + 记账 + 列表 + 详情 + 统计 + 接入账户详情**，覆盖 Desktop / Tablet / Mobile 三尺寸。

界面参考 Open Design 生成的三尺寸原型（交易六页 + 分类管理三尺寸），功能参考行业规范（复式记账）、历史项目文档（docs/superpowers/specs/）和 Tauri 工程（src-tauri/）。

## 2. 现状（探索结论）

**服务端（yucai/server/internal/transaction/）**：DDD 四层骨架完整 —— Transaction 聚合 + TransactionEntry（int64 cents）+ DoubleEntryValidator（借贷 XOR + 平衡）+ 8 个用例（Record/Get/List/Update/Delete + SimpleIncome/Expense/Transfer）+ 增量余额维护 BalanceUpdater + 多租户 + 乐观锁 + DB CHECK XOR。ent schema + proto + handler 齐全。

**客户端（yucai/client/lib/）**：完全空白，只有 proto stub（还缺 `.pbgrpc.dart`）。account_detail_page 的「记一笔/转账/近期交易/收支统计」全是 `onPressed: null` 占位。

**缺**：统计聚合用例、Category 概念、SimpleExpense/Transfer 业务校验、wire ProviderSet 注册、FindAll N+1。

## 3. 设计决策：方案 A（account-as-category）

### 决策
支出/收入「分类」建模为 `AccountType=Expense/Income` 的账户（餐饮=Expense 账户，工资=Income 账户）。每笔交易是复式分录：餐饮支出 = 借「餐饮」(Expense) 贷「招商银行」(Asset)，就是现成的 `SimpleExpense`。

### 理由
御财是复式记账产品。复式记账约束下，独立 Category 表（方案 B）要么破坏余额闭环（分类不进分录，账户余额与分类累计两套并行），要么退化为方案 A 的超集（每分类配隐藏账户 + 冗余 Category 表）。方案 A 让复式规则、余额计算、统计、未来预算都共用一套账户体系，最省且最一致，与 Tauri 规划方向（"category absorbed into accounts"）一致。

**商户不是分类账户的职责**：商户是交易自身描述（`Transaction.description` / 未来 `payee` 字段），与分类正交。同属「餐饮」的多笔交易各自有不同 description（望江楼/美团/京东）。

### 不选方案 B 的根本原因
B 适用于流水记账产品（随手记/鲨鱼/挖财），那些产品不是复式记账。御财后端已按复式建好（DoubleEntryValidator/BalanceUpdater/AccountType 五要素/ChartOfAccounts），选 B 会让这套后端价值打折。

## 4. 切片地图（方法 3 + 共享基础层先行）

方法 3 纯特性切片会让各切片重造「分类查询/复式分录/御财组件/响应式布局」。实际结构：**切片 0（共享基础层，先行）+ 6 个特性切片**，每切片端到端可演示。

```
切片 0  共享基础层（地基，无可演示特性但先行）
        服务端: account 按 AccountType 查询 + 复式分录 helper + transaction wire 注册 + proto client grpc stub
        客户端: transaction/ 包骨架 + 御财共享组件 + 三尺寸响应式断点

切片 1  记一笔      SimpleExpense/Income/Transfer(已有+补校验) → 表单(三尺寸) → 落库 → 余额更新
切片 2  交易列表    ListTransactions(修N+1) + 筛选 + 按日分组 + 分页 → 表格/卡片(三尺寸)
切片 3  交易详情    GetTransaction + 同分类近期 → 复式分录展示(三尺寸)
切片 4  分类管理    account 扩展(CRUD+预置10类+parent_id二级+is_system) → 管理页(三尺寸)
切片 5  统计汇总    TransactionSummary RPC(月度收支/净额/日均/按日按分类) → 列表页4卡接真实数据
切片 6  接入详情    account_detail 占位→真实(记一笔/转账按钮+近期交易+收支统计4卡)
```

子决策（已落入设计）：统计走服务端 RPC（切片 5）、分类管理扩 account 模块（切片 4）。

## 5. 服务端改动（按切片）

### 切片 0 · 共享基础层
- **account 实体加 3 字段**（新 migration `YYYYMMDD_account_category_fields.sql`）：`parent_id *uuid.UUID`（二级分类，nullable）、`is_system bool`（系统预置，default false）、`sort_order int`（排序，default 0）
- **account repo 加查询**：`FindByAccountType(tenantID, AccountType)` —— 分类下拉用，返回 Expense/Income 账户列表
- **transaction wire ProviderSet 注册**：补到 `cmd/wire`（TransactionService + repo + handler 注入）
- **proto client grpc stub**：生成 `transaction/v1/transaction.pbgrpc.dart`（当前只有 `.pb.dart`，对比 `auth/v1/auth.pbgrpc.dart`）

### 切片 1 · 记一笔（补业务校验）
- `SimpleTransfer`：加**币种一致性校验**（两账户 `currency_code` 不同则报错，参考 Tauri `create_transfer`）
- `SimpleExpense`：加**资产账户余额校验**（余额不足拒绝，参考 Tauri `create_expense`）

### 切片 2 · 交易列表
- **修 `FindAll` N+1**：当前按 AccountID 过滤先查 entry 表拿 txnIDs 再逐条加载分录；改为 transaction JOIN entry 单查 + ent eager load entries
- **`TransactionFilter` 扩展**：当前只有 AccountID/DateFrom/DateTo，加 `Type`（收入/支出/转账，按 SimpleXxx 模式或 entry 方向推断）

### 切片 3 · 交易详情
- `GetTransaction` 已有，复用
- 新增 `FindRecentByAccount(tenantID, accountID, limit)` —— 同分类近期交易（同 Expense/Income 账户的其他交易）

### 切片 4 · 分类管理
- account CRUD 扩展：`CreateCategory` / `UpdateCategory` / `DeleteCategory`（`is_system=true` 拒删）/ `ReorderCategories`
- **预置 10 个系统分类 seed**（per-tenant 注入）：支出 6（餐饮/交通/购物/娱乐/居家/医疗）+ 收入 4（工资/兼职/理财收益/红包），均 `is_system=true`

### 切片 5 · 统计汇总
- 新增 `TransactionSummary(tenantID, year, month, accountID?)` 用例 + RPC + repo 聚合查询
- 返回 `MonthlySummary`（见第 7 节）
- 服务端 SQL 聚合（entry `debit_cents`/`credit_cents` × 账户 AccountType 方向，复用 `BalanceCalculator` 逻辑）

### 切片 6 · 接入详情
- 服务端**无新改动**，复用 `ListTransactions(accountId)` + `TransactionSummary(accountID scope)`

### proto 新增汇总
- transaction：`TransactionSummary` RPC + `MonthlySummary`/`DailyItem` DTO；`ListTransactionsRequest` 加 `Type` 字段
- account：`FindByAccountType` + 4 个 Category CRUD RPC；AccountDTO 加 `parent_id`/`is_system`/`sort_order` 字段

## 6. 客户端结构 + 数据流 + 三尺寸响应式

### feature 包结构（遵循 account 模块先例：domain/data/presentation + flutter_bloc）
```
lib/transaction/
  domain/        entities(transaction_entity.dart: Transaction+Entry) / repositories(trait) / value_objects(EntryType, TxnType)
  data/          datasources/transaction_remote_ds.dart(gRPC) / repositories/impl / models(DTO↔entity)
  presentation/
    bloc/        transaction_bloc(列表/详情) · transaction_form_bloc(记一笔) · category_bloc(分类管理)
    pages/       transactions_page · transaction_form_page · transaction_detail_page · category_management_page
    widgets/     summary_card · filter_bar · txn_row · category_chip · journal_entry(复式分录) ← 切片0共享组件
lib/account/...  ← 复用：分类下拉=查 Expense/Income 账户，不新建 Category
```

### 数据流
`TransactionRemoteDS (gRPC .pbgrpc.dart) → RepositoryImpl → Bloc → Page`，与 account 模块完全同构。

### 三尺寸响应式（切片 0 共享层）
- **断点**：`≤600 Mobile` / `600–1200 Tablet` / `≥1200 Desktop`（LayoutBuilder + MediaQuery，**业务逻辑共享，只布局变**）

| 页面 | Desktop (≥1200) | Tablet (600–1200) | Mobile (≤600) |
|------|-----------------|-------------------|---------------|
| 导航 | 220px 固定深色侧栏 | 56px 窄图标侧栏 | 底部 tab bar + FAB |
| 列表 | 表格 5 列 + 汇总卡横排 | 紧凑表格 + 汇总卡 | 卡片堆叠 + 汇总卡可折叠 |
| 表单 | 左右双栏(含右栏复式预览) | 单栏 | 单栏 + 底部 sheet 选账户/分类 |
| 详情 | 三栏(概要+分录+操作) | 双栏 | 卡片堆叠 |

### 关键复用
- **分类下拉** = `AccountBloc.loadByType(Expense/Income)`，复用 account 模块，不新建 Category 表
- **金额输入** 复用 account 的 `amount_input.dart`（已有 currencySymbol 参数）
- **复式分录展示** = 新建 `journal_entry.dart` 共享组件（借/贷/平衡标注），三尺寸共用

### 切片 6 · 接入 account_detail
account_detail_page 当前 `onPressed: null` 占位变为：
- 「记一笔/转账」按钮 → `push(TransactionFormPage)`
- 「近期交易」panel → `TransactionBloc.loadByAccount(id)`
- 「收支统计」4 卡 → `TransactionSummary(accountId scope)`
- 「快捷操作·记一笔/转账」→ 同上

## 7. 统计模型（切片 5）

`MonthlySummary` 按分类账户拆分每日收支（account-as-category 优势：每日每个 Income/Expense 账户的收支可直接聚合）：

```
MonthlySummary {
  IncomeCents, ExpenseCents, NetCents, DailyAvgCents   // 月汇总
  ByDay []DailyItem {
    Date
    TotalIncome, TotalExpense                          // 每日收支合计
    ByCategory []{                                     // 按 Income/Expense 账户拆分
      AccountID, Name, AccountType
      Amount                                           // 该分类当日收支
    }
  }
}
```

「每日存款利息」= 利息 Income 账户当日贷方；「每日理财收益」= 理财收益账户当日贷方；「每日工资」= 工资账户当日贷方 —— 都在交易聚合范围内。

**市值变动（股票每日涨跌）不在本期** —— 属于投资/Holding 模块（持仓 × 市价快照），account 已有 `investMarketValueCents` 字段预留。

## 8. 测试策略（TDD）

**服务端（Go）**：
- domain 单元：分类账户校验、`TransactionSummary` 聚合逻辑、复式校验补强
- service 单元：`SimpleTransfer` 币种校验、`SimpleExpense` 余额校验、统计聚合
- integration：扩 `transaction_integration_test.go`，覆盖分类 CRUD + 统计 RPC + 新 filter

**客户端（Flutter）**：
- bloc 单元：TransactionBloc / FormBloc / CategoryBloc 状态流转
- widget 测试：**三尺寸响应式断言**（同页面传 Mobile/Tablet/Desktop 断点，验证布局差异）
- repository 单元：mock datasource

**每切片 TDD 顺序**：写测试 → 实现 → 通过 → 集成。

## 9. 风险与对策

1. **proto client grpc stub 缺失**（`.pbgrpc.dart` 未生成）→ 切片 0 必须先生成，对策：buf 生成配置补 transaction，对比 auth 生成方式
2. **FindAll N+1 修复回归** → 改 ent 查询后，现有 `ListTransactions` 需回归测试
3. **account 扩展字段 migration 向后兼容** → `parent_id=null` / `is_system=false` / `sort_order=0` 默认值，现有账户不受影响
4. **预置分类 seed 多租户** → per-tenant 注入（首次创建 tenant 时），非全局共享
5. **客户端不手动构造复式 entries** → 记一笔调 `SimpleExpense/Income/Transfer` RPC（服务端生成分录），客户端只传金额+账户+分类

## 10. 数据迁移

- migration 1：`account` 加 `parent_id`(nullable) / `is_system`(default false) / `sort_order`(default 0)
- migration 2：预置分类 seed（per-tenant 注入 10 个 `is_system=true` 分类账户）
- 现有交易**不受影响**（entries 已有 account_id，分类账户就是 Expense/Income 账户）

## 11. 范围边界 + UI 占位策略

### 本期实装（范围 A 核心闭环）
分类（account-as-category）+ 交易三页三尺寸 + 分类管理三尺寸 + 统计（按分类每日）+ 接入 account_detail。

### 页面先行：后续模块 UI 占位（功能不实装）
UI 按三尺寸原型**完整画**，含下列后续模块的区域，但这些区域**功能占位**（灰显 / 🔒 / 「待 X 模块」标记，沿用 account_detail_page 现有占位模式），不实装后端逻辑，留 todo 等模块对接：

| 占位区域 | 所在页面 | 占位形态 | 对接模块 |
|---------|---------|---------|---------|
| 标签 Tags | 交易表单/详情 | 标签区域显示但提交不持久化，🔒「待 Tags 模块」 | Tags 模块（未来） |
| AA 分摊 | 交易详情 | 「分笔明细」下方「AA 分摊 · 待实现」占位卡 | 分摊模型（未来） |
| 同商户交易 | 交易详情 | 「同分类近期交易」旁「同商户 · 待实现」占位 | merchant 字段（未来） |
| 预算联动 | 交易详情/分类管理 | 「餐饮月度预算 · 待 Budget 模块」占位 | Budget 模块（未来） |
| 投资市值变动 | 投资账户详情 | 「持仓/市值 · 待 Holding 模块」占位（account_detail 已有） | Holding 模块（未来） |

**注意区分**：「同分类近期交易」是本期实装（切片 3，查同 Expense/Income 账户）；「同商户交易」是占位（需 merchant 字段，未来）。

## 12. 未来迭代（本期 UI 占位，功能待对接）

以下模块本期只做 UI 占位，功能在各自模块完成后对接：

1. **标签 Tags** —— 交易挂多标签、按标签筛选、标签管理。需 Tag 模型（多对多）+ transaction 加 tag 关联
2. **AA 分摊** —— 一笔交易在多人间分摊。需分摊模型（参与人 + 比例/金额）
3. **同商户聚合** —— 按商户查交易、商户画像。需 `Transaction.payee/merchant` 字段 + 聚合查询
4. **预算联动** —— 分类预算 vs 实际、超支提醒。需 Budget 模块（预算项 + 周期）+ 与分类账户余额对比
5. **投资市值变动** —— 持仓、市价快照、每日涨跌、收益曲线。需 Holding 模块（持仓 + 市价）+ 与 investMarketValueCents 联动

## 13. 三尺寸原型参考（Open Design）

- **交易模块**（项目 `yucai-transaction-trisize-9d3e`）：Desktop 根级 transactions/form-transaction/detail-transaction.html + Mobile `mobile/` 子目录三页；Tablet 见旧项目 `yucai-transaction-tablet-prototype-abb9`
- **分类管理**（项目 `yucai-category-management-db5f`）：desktop.html / tablet.html / mobile.html + index.html 总览

原型已核对：御财 token 一致（奶油白 #f7f6f2 / 御财金 #b08d57 / 深色侧栏 #1c1e21 / 收入绿 #2d8a6e / 支出红 #c4544d）、方案 A 落地（表单字段标注「转出账户(资产)/支出分类(费用)/收入分类(收入)」+ 复式预览借贷平衡、详情分录「借餐饮(Expense)」、分类管理列表显示本月金额=账户余额 + 二级分类）。
