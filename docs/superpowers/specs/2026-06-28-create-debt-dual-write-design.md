# CreateDebt 双写(borrowedOut 借出 → 应收)· 设计

- **日期**: 2026-06-28
- **状态**: 设计已确认,待转实施计划
- **范围**: `CreateDebt` 在创建**借出债权(borrowedOut)**时,同步记一笔复式 transaction —— `credit` 资金来源账户(现金 −)+ `debit` 应收账户(`debt.account_id`,应收 +),金额 = 借出本金。使应收账户余额从创建起即 = 借出本金,根治「RecordPayment 减应收 → 负余额」bug。
- **分支**: 实施阶段从 main 开新分支(命名待定)
- **不含**: borrowedIn 双写、subtype 规则、已有数据回填、跨域 DB 事务、Update/Delete 双写

## 1. 背景

承接已 merge 的 RecordPayment 双写(`2026-06-28-credit-card-dual-track-sync-design.md`)。御财 debt 与 account 双轨断开的剩余缺口:

- `RecordPayment`(borrowedOut 确认收款)现已双写:`debit` 来源(现金 +)+ `credit` `debt.account_id`(应收 −)—— 会**减少**应收账户余额。
- 但 `CreateDebt`(borrowedOut 创建债权)**不双写**:`debt_handler.go:36` 只调 `service.CreateDebt`(生成 schedule + Save),应收账户余额保持初始 **0**。
- 结果:创建债权后应收 = 0 → RecordPayment 收款减应收 → **负数**(GUI 实测:招行大额存单 -50000)。已用 seed 手动 `UPDATE 应收账户余额 = debt.remaining` 临时修复**存量**,但**新建债权仍 0**(根因未治)。

根因:创建债权时没有先「建立」应收余额(借出本金)。

## 2. 决策(已确认)

- **只做 borrowedOut 双写**。borrowedOut(我借出钱)必有资金来源(现金从某账户出),复式要求必须记录现金那一头;这是真实 bug 驱动。
- **复式模型 = 资金来源账户 + 应收账户**(业界标准,见 §3)。`source_account_id` 对 borrowedOut **必填**(复式硬要求,非 optional)。
- **borrowedIn 不双写**(范围校正,见 §8)。信用卡/贷款债务账户余额由消费 transaction 驱动,无 bug 报告;mortgage/auto_loan 放款不进用户现金账户,强选 source 语义不自然。
- **失败处理:预验证 fail-fast + transaction 写 best-effort**(对称 RecordPayment)。
- **双写全在 handler 层**(`debt_handler.go`),`application.CreateDebt` 不变(对称 RecordPayment:双写在 handler,service 只管 debt)。

## 3. 业界标准(方案依据)

复式记账中「借出钱给他人」的标准分录(Beancount / GnuCash / YNAB 一致):

```
借出 1000 给朋友:
  Dr Assets:Receivables:张三   +1000   (应收 +,资产)
  Cr Assets:Checking           -1000   (现金 −,资产)   ← 必须有来源账户
```

铁律:借出 = 资产内部转移(现金 → 应收),**资金来源账户不可省**;应收是资产负债表资产,非收入。御财的 `enforce_double_entry` trigger 同样要求 debit = credit 平衡,故 source 不可缺。

与御财已实现的 RecordPayment borrowedOut(收款)互为逆操作:创建(现金− 应收+)↔ 收款(现金+ 应收−),两者协同后应收余额自洽。

## 4. 数据模型变更

| 层 | 变更 |
|---|---|
| proto `CreateDebtRequest` | 加 `string source_account_id`(borrowedOut 必填,borrowedIn 忽略) |
| application `CreateDebtRequest` | **不变**(source 在 handler 层解析使用,不进 service —— 对称 RecordPayment) |
| domain / ent | **无变更**(双写产物是一条独立 transaction,debt 表不动) |

## 5. 复式 entries(borrowedOut,source 非空时)

金额 = `req.TotalPrincipalCents`(借出本金,**一次性**,区别于 RecordPayment 按 schedule entry.total)。

```
borrowedOut(借出):
  credit source_account     (asset −,现金出)    ChartCode = source.ChartCode
  debit  debt.account_id    (asset 应收 +)      ChartCode = debtAcc.ChartCode
```

`buildCreateEntries(sourceAcc, debtAcc, principalCents)` 返回两条 `EntryInput`,方向与 RecordPayment 的 `buildPaymentEntries(borrowedOut)` 正好相反(创建=增,收款=减)。

## 6. 数据流(`debt_handler.go` CreateDebt)

1. 解析现状字段(tenant/account/date/...)。
2. **DebtType == BorrowedOut**:解析 `source_account_id`;**为空 → `InvalidArgument`**(必填)。
3. **borrowedOut 且 source 非空** → `validateSourceAccount`(新方法,§7):fail-fast,任一不过 → **debt 不创建**。
4. `service.CreateDebt`(生成 schedule + Save,现状不变)。
5. **borrowedOut 且 source 非空** → `recordCreateTransaction`(新方法,§7):best-effort 双写。
6. **DebtType == BorrowedIn**:忽略 `source_account_id`(即使传了也不用),不双写 —— 流程同现状。
7. 返回 `DebtResponse`(现状)。

> 比 RecordPayment 简单:req 自带 `AccountID` + `DebtType` + `TotalPrincipalCents`,**无需 `GetDebt` re-fetch**(RecordPayment 因 debt 已存在、req 无 account_id 才必须 GetDebt)。

## 7. 验证与失败处理

**`validateSourceAccount`**(对称 `validateFromAccount`,fail-fast,在 `service.CreateDebt` 之前):

| 检查 | 不通过 → |
|---|---|
| source 账户存在 | `NotFound` |
| source 是 `AccountTypeAsset` | `InvalidArgument` |
| source 与 `req.AccountID`(应收账户)同币种 | `InvalidArgument` |
| source ≠ `req.AccountID`(防自转) | `InvalidArgument` |
| source `CurrentBalanceCents ≥ TotalPrincipalCents`(借出要有钱) | `FailedPrecondition` |

> 余额检查是 RecordPayment 的镜像:RecordPayment 查 borrowedIn 的 from(还钱要扣);CreateDebt 查 borrowedOut 的 source(借出要有钱)。

**`recordCreateTransaction`**(对称 `recordPaymentTransaction`,best-effort):debt 创建后,`accountLookup.FindByID` 取 source + debt.account 的 ChartCode → `buildCreateEntries` → `transactionSvc.RecordTransaction`;任一步失败 → `slog.Error`(English structured,字段 `operation=debt.CreateDebt.recordCreateTransaction` / `debt_id` / `source_account_id` / `debt_account_id` / `amount_cents` / `error`)+ 吞掉。debt 已创建,**不回滚**(与 RecordPayment 一致;不做跨域 DB 事务)。

## 8. 范围校正记录(为什么不做 borrowedIn)

初版设计曾扩到「两个 DebtType + subtype 规则 + 房车贷双写」,经反思判定为**过度设计**,收缩到只做 borrowedOut:

- **无 bug 驱动**:GUI 问题与 memory TODO 仅涉及 borrowedOut;borrowedIn 账户余额由消费 transaction 驱动,无报告异常。
- **mortgage/auto_loan 语义不自然**:放款直付卖家/4S,不进用户现金账户;御财亦无对应房产/车辆资产账户。
- **与既有设计冲突**:「消费驱动 debt、account 余额独立」(RecordPayment spec §2),borrowedIn 双写有双重计算风险。
- 若将来确有「借入现金进账户」的真实需求,再单独评估 borrowedIn 双写(届时 source 对该 subtype 必填,复式 `debit source + credit 负债`)。

## 9. 前端 UI(Flutter)

只改 `ReceivableFormPage`(borrowedOut 表单):
- 加「资金来源账户」选择器(asset 账户下拉,**必选**)。
- 提交时传 `source_account_id`;创建成功后刷新 source + 应收账户余额(反映双写结果:现金减、应收增)。
- `DebtFormPage`(borrowedIn)**不动**。

## 10. 测试

**server**(扩 `debt_integration_test.go` 或 handler 测试):
- borrowedOut + source → 创建 transaction(credit source + debit 应收)+ source 余额减、应收余额增
- borrowedOut source 缺省 → `InvalidArgument`,debt 不创建
- borrowedIn → 不建 transaction(仅 debt;即使传 source 也忽略)
- 预验证各失败分支 → debt 不创建:source 不存在(`NotFound`)/ 非 asset / 跨币种 / 自转(`InvalidArgument`)/ 余额不足(`FailedPrecondition`)
- transaction 写失败 → best-effort(debt 创建保留 + log)

**client**:`ReceivableFormPage` 创建后 source + 应收账户余额刷新。

## 11. 范围边界(本期不做)

- borrowedIn 双写(见 §8)
- 已有数据回填:王五异常(招行大额存单通用 asset 关联 borrowedOut,应收应专用 otherAsset 账户)+ seed 临时修复的账户 → **单独清理任务**,本期只保证**新建**债权正确
- 跨域 DB 事务(debt + transaction 同 tx)—— best-effort 即可
- `UpdateDebt` / `DeleteDebt` 双写 —— 后续
- `RecordPayment` 已实现,本期不动

## 12. 参考

- RecordPayment 双写 spec:`docs/superpowers/specs/2026-06-28-credit-card-dual-track-sync-design.md`
- RecordPayment 双写 plan:`docs/superpowers/plans/2026-06-28-credit-card-dual-track-sync.md`
- 参考实现:`debt_handler.go` — `validateFromAccount`(:180)、`recordPaymentTransaction`(:240)、`buildPaymentEntries`(:300)
- transaction service:`RecordTransaction` + `UpdateBalances`(`transaction/application/service.go:33`)
- DebtType 语义:`debt/domain/valueobject.go:40`(BorrowedIn = 负债,BorrowedOut = 应收)
