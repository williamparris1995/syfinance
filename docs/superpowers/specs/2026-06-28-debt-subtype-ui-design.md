# 债务子类型驱动 UI(debt subtype UI)· 设计

- **日期**: 2026-06-28
- **状态**: 设计已确认(mockup 通过),待转实施计划
- **范围**: debt_form 子类型持久化 + 信用卡子类型驱动字段(联动 account);receivable_form 子类型持久化
- **分支**: `debt-subtype-ui`(从 main `c09a7f5`)
- **不含**: 信用卡账单周期交易/分期;房贷/车贷特殊字段;subtype 的 i18n

## 1. 背景

债权模块(BorrowedOut)已交付 merge main。现有 debt/receivable form 有**子类型标签**:
- debt_form(borrowedIn):`['房贷','车贷','信用卡','亲友借款','其他']`
- receivable_form(borrowedOut):`['私人','商业','亲友','其他']`

问题:这些标签是**纯 UI 状态**(`_debtType` String),**提交时不持久化**(debt_details 无字段),**不驱动字段**(选什么都不影响表单)。

行业调研(Mint/Monarch/银行 app/随手记/挖财):子类型**驱动字段** —— 选「信用卡」出现账单日/还款日/额度/利用率;信用卡字段挂在**账户**上(account 属性)。

## 2. 决策(已确认)

1. **范围**:只信用卡子类型驱动特殊字段(行业重点);房贷/车贷/亲友保持基础(amortization 已覆盖房贷/车贷的本金/利率/期)
2. **架构:A 账户联动** —— 信用卡字段留 account(已有 `credit_billing_day`/`credit_repayment_day`/`credit_limit_cents`/`credit_annual_fee_cents`),debt_form 选信用卡 + 关联 credit_card account → 显示/编辑该 account 字段(提交 `AccountRepository.updateAccount` 同步)。**不重复字段**。
3. **const 常量(强制)**:subtype 用**英文语义 key**(const 声明),**不硬编码字符串,不在判断条件用裸字符串**。

## 3. 数据模型

### 3.1 debt_details 加 subtype
- ent 加 `subtype` String field(Optional, default 空)。存**英文语义 key**。
- server Go const(集中声明):
  ```go
  const (
      DebtSubtypeMortgage  = "mortgage"
      DebtSubtypeAutoLoan  = "auto_loan"
      DebtSubtypeCreditCard = "credit_card"
      DebtSubtypeFamily    = "family"
      DebtSubtypeOther     = "other"
  )
  // 借出方向
  const (
      ReceivableSubtypePersonal = "personal"
      ReceivableSubtypeBusiness = "business"
      // family / other 复用上面
  )
  ```

### 3.2 client const 常量类
```dart
abstract final class DebtSubtypes {          // borrowedIn
  static const mortgage = 'mortgage';
  static const autoLoan = 'auto_loan';
  static const creditCard = 'credit_card';   // 判断用这个 const
  static const family = 'family';
  static const other = 'other';
  static const all = [mortgage, autoLoan, creditCard, family, other];
  static const labels = {mortgage: '房贷', autoLoan: '车贷', creditCard: '信用卡', family: '亲友借款', other: '其他'};
}
abstract final class ReceivableSubtypes {    // borrowedOut
  static const personal = 'personal';
  static const business = 'business';
  static const family = 'family';
  static const other = 'other';
  static const all = [personal, business, family, other];
  static const labels = {personal: '私人', business: '商业', family: '亲友', other: '其他'};
}
```
- **判断用 const**:`if (subtype == DebtSubtypes.creditCard)` —— 禁止裸 `'信用卡'`
- **form 选项**:`DebtSubtypes.all` + `DebtSubtypes.labels`(不再硬编码 `['房贷',...]`)

### 3.3 account 信用卡字段(已有,不动)
account ent schema 已有:`credit_limit_cents` / `credit_billing_day` / `credit_repayment_day` / `credit_annual_fee_cents`。

### 3.4 贯通(对称 debt_type Task 1-6 模式)
- proto:DebtDTO + CreateDebtRequest 加 `string subtype`
- domain:Debt entity 加 subtype
- mapper/remote_ds/repo_impl/bloc 透传 subtype
- server service/handler + ent 读写 subtype

## 4. form 行为

### 4.1 debt_form(borrowedIn)
- 子类型选项 = `DebtSubtypes.all` + `DebtSubtypes.labels`(const)
- **驱动**:`subtype == DebtSubtypes.creditCard` → 显示「💳 信用卡信息」区:
  - account 选择聚焦 credit_card category(只列信用卡账户;无则提示新建卡入口)
  - 信用卡字段(账单日/还款日/额度/年费)= 选中 credit_card account 的字段,**可编辑**(提交时 `AccountRepository.updateAccount` 同步到 account)
- 其他 subtype(房贷/车贷/亲友/其他)→ 基础字段(现状,无信用卡区)
- 提交:CreateDebt(subtype) + 若信用卡字段变 → updateAccount

### 4.2 receivable_form(borrowedOut)
- 子类型持久化(`ReceivableSubtypes` const),选项用 const
- **不驱动字段**(债权无信用卡)

## 5. 详情页 / 列表 / 测试

### 5.1 详情页(debt_detail_page)
信用卡债务(`subtype == DebtSubtypes.creditCard`)→ StatRow 加「信用卡」卡片:
- 账单日 / 还款日 / 额度 / **利用率**(from account)
- 利用率 = `currentBalance / creditLimit`,颜色码:绿 <30% / 黄 <70% / 红 ≥70%(行业 utilization)

### 5.2 列表卡片(debts_page / receivables_page)
子类型 badge 改用**持久化 subtype**(`DebtSubtypes.labels[subtype]`),替代现有 `_inferBadge`(从 counterparty 关键字推断 —— 不准)。

### 5.3 测试
- server:subtype 持久化(CreateDebt/ListDebts)+ 信用卡 account 字段读写
- client domain:Debt.subtype + const 常量类
- form:选信用卡子类型 → 信用卡字段区出现 + 提交 updateAccount;其他子类型不出现
- detail:信用卡债务显示账单日/额度/利用率
- 负向:非信用卡债务不显示信用卡区

## 6. 范围边界(本期不做)

- 信用卡账单周期交易明细(账单/分期)—— 后续
- 房贷/车贷特殊字段(行业无强需求,YAGNI)
- subtype 的 i18n(御财 client 中文 const,i18n 后续)

## 7. 参考

行业调研(web_search_prime 知识库,非实时):
- **Mint/Monarch/YNAB**:信用卡 utilization(statement vs current,due date,min payment),net worth dashboard
- **随手记/挖财/贝多多**:应收/应付账户(借出=资产,借入=负债),借贷对象,还款关联
- **Splitwise/LendingClub**:借贷分类(active/pending/history),onboarding/offer/schedule
