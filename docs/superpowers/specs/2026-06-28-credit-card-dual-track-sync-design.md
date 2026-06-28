# 信用卡双轨同步(RecordPayment 双写)· 设计

- **日期**: 2026-06-28
- **状态**: 设计已确认,待转实施计划
- **范围**: RecordPayment(debt 还款 + receivable 收款)双写 —— 同时更新 debt schedule + 创建 transaction(复式)更新 account 余额
- **分支**: `credit-card-sync`(从 main `8bcb613`)
- **不含**: 消费产生 debt(交易驱动 debt)、account 余额驱动 debt、跨域 DB 事务

## 1. 背景

御财 debt 与 account **双轨断开**:
- `RecordPayment`(debt 还款 / receivable 确认收款)只标 debt schedule paid(`debt_handler.go:120` 注释 `"transaction creation handled here in future"` —— **TODO 未实现**),**不创建 transaction,不更新 account 余额**
- 信用卡消费(普通 transaction)→ 改 account 余额,**不产生 debt**

结果:debt.remaining 与 account.current_balance 各自演进,**不一致**。 subtype UI 验证时用户确认要"双轨 + 同步"。

## 2. 决策(已确认)

- **同步核心:还款双写**(用户选)。RecordPayment 同时:(1) 标 debt schedule paid(现状);(2) 创建 transaction(复式 entries)→ UpdateBalances 更新 account 余额。
- **消费不产生 debt**(account 余额独立,交易驱动)。本期只做还款双写。
- **失败处理:best-effort**(御财 service 独立无跨域事务)。debt.RecordPayment 先;transaction.RecordTransaction 后,失败 → log + toast 提示「债务已记录,账户扣减失败」。
- **receivable(确认收款)对称做**(同 spec):entries 方向按 debt.type。

## 3. 数据流(Design Section 1)

RecordPayment handler(`debt_handler.go`,补 line 120 TODO):
1. `debt.service.RecordPayment`(标 schedule paid —— 现状)
2. `transaction.service.RecordTransaction`(复式 entries,见 §4)→ `UpdateBalances` 自动更新 account 余额
3. 返回 TransactionID(debt 的 txnID + transaction 的)

**跨域注入**:debt handler 注入 `transaction.Service`(getIt/wire,同 server DI)。

## 4. 复式 entries(按 debt.type)

金额 = schedule entry.total(principal + interest cents)。

### 4.1 borrowedIn(我还债)
- credit `from_account`(asset-,我的储蓄/还款来源减)
- debit `debt.account_id`(liability-,欠款减。信用卡债务关联 credit_card account)
- 复式平衡(debit = credit = entry.total)

### 4.2 borrowedOut(我收款,确认收款)
- debit `from_account`(asset+,我的收款账户增。proto from_account_id = 收款入账账户)
- credit `debt.account_id`(asset 应收-,应收减。borrowedOut 关联 otherAsset 应收账户)
- 复式平衡(资产内部转移:应收 → 现金)

## 5. 细节(Design Section 2)

- **金额** = schedule entry.totalCents(principal + interest)
- **from_account**:req.from_account_id(RecordPayment 对话框用户选);验证 `AccountType.asset` + `current_balance ≥ entry.total`(borrowedIn 还款,余额不足 → error);borrowedOut 收款 from_account 也 asset
- **credit_card / 应收 account** = debt.account_id(债务关联账户)
- **失败处理**:best-effort —— debt paid 先;transaction 后,失败 log + toast「债务已记录,账户更新失败」(不回滚 debt)
- **UI**:RecordPayment 对话框(选 from_account)现状不变;提交后 from_account + debt.account_id 余额自动更新(双写结果);详情/列表反映新余额
- **货币**:`SimpleTransfer` 拒绝跨币种;`RecordTransaction` 复式应同币种(from_account + debt.account_id 同 currency,否则 error)

## 6. 测试

- **server**:RecordPayment(borrowedIn)创建 transaction(credit from + debit liability entries)+ 两 account 余额更新;RecordPayment(borrowedOut)创建 transaction(debit from + credit 应收 entries)+ 余额更新;余额不足 → error;跨币种 → error;transaction 失败 best-effort(debt paid 保留 + log)
- **client**:RecordPayment 后 account 余额刷新(详情/列表反映)

## 7. 范围边界(本期不做)

- 消费产生 debt(交易驱动 debt)—— 后续
- account 余额驱动 debt(余额 = 应还)—— 后续
- 跨域 DB 事务(debt + transaction 同 tx)—— best-effort 即可
- RecordPayment 之外的 debt 操作(Create/Update/Delete)双写 —— 后续(本期只 RecordPayment)

## 8. 参考

- 御财 transaction:`RecordTransaction`(复式 entries,asset/liability/income/expense)+ `UpdateBalances`(`transaction/application/service.go:33`)
- RecordPayment 现状:`debt_handler.go:110-132`(line 120 TODO transaction creation)
