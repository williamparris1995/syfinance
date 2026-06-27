# 御财债权模块(BorrowedOut)· 设计

- **日期**: 2026-06-27
- **状态**: 设计已确认(OD 9 页),待转实施计划
- **范围**: 债权 client 移植(独立 /receivables 页 + server debt type 扩展 BorrowedOut)
- **分支**: main(新分支 `receivables-module`)
- **不含**: BorrowedIn/CreditCard type UI(type 字段支持,default BORROWED_IN,UI 后续)

## 1. 概述

御财 Debt module 只覆盖「我欠别人」(account_id 关联 liability)。债权(BorrowedOut 别人欠我 = 应收)需 **debt type 扩展** + 独立 /receivables 页(对称债务,收款而非还款)。

OD 设计 9 页(3 页 × desktop/tablet/mobile,御财 token)。本 spec 扩展 debt type(server proto/ent)+ 债权 client(独立页 receivables/detail/form)。

## 2. 决策(已确认)

- **独立 /receivables 页**(不 type tab 复用 debts_page)—— 清晰分离债权/债务
- **debt type 字段**:DebtType enum(BORROWED_IN 我借入/BORROWED_OUT 我借出),default BORROWED_IN
- **本期只 BorrowedOut UI**(债权);type 字段支持 BORROWED_IN(default,现有债务自动)
- **account 关联**:BorrowedOut → asset 应收账户(category otherAsset)
- **收款语义**:BorrowedOut 的 RecordPayment =「确认收款」(别人还我 → to 我的收款账户)

## 3. server 扩展(debt type)

### 3.1 proto
- `enum DebtType { DEBT_TYPE_UNSPECIFIED=0; BORROWED_IN=1; BORROWED_OUT=2; }`
- `DebtDTO` 加 `DebtType debt_type = 13;`
- `CreateDebtRequest` 加 `DebtType debt_type = 8;`
- `ListDebtsRequest` 加 optional `DebtType type_filter = 2;`(按 type 筛)

### 3.2 ent
- `debt_details` schema 加 `debt_type` field(string,默认 "borrowed_in")
- migrate(加 column,default borrowed_in,现有行自动 borrowed_in)

### 3.3 service
- `CreateDebt` 接 debt_type;`ListDebts` optional type filter
- handler DTO ↔ domain type 映射

## 4. client(债权,对称 debt module)

### 4.1 domain
- `value_objects.dart` 加 `DebtType { borrowedIn, borrowedOut }`
- `debt_entity.dart` Debt 加 `DebtType type` field
- `debt_repository.dart` ListDebts 加 optional typeFilter

### 4.2 data
- `debt_mapper.dart` DebtType proto ↔ domain 映射
- `debt_remote_ds.dart` create/list 传 type
- `debt_repository_impl.dart` typeFilter 透传

### 4.3 bloc
- `debt_event.dart` LoadDebtsRequested 加 optional DebtType typeFilter
- 复用 DebtBloc(债权/债务同 bloc,不同 typeFilter)

### 4.4 UI(独立 /receivables 页,对齐 OD 9 页)
- **receivables_page.dart**:总应收概览(progress bar 已收比例)+ 债权卡(债务人/剩余应收/进度/收款/操作)+ 三端响应式
- **receivable_detail_page.dart**:Hero + StatCard + 收款计划(已收绿/待收/逾期红)+ 确认收款(RecordPayment 收款)
- **receivable_form_page.dart**:type=BorrowedOut + 债务人 + 应收账户 asset + 金额/利率/摊还/日期 + 摊还预览 + step wizard mobile

### 4.5 router
- `/receivables` branch(branch 4 债权)+ `/receivables/:id` + `/receivables/new`
- AppShell nav 加债权(branch 4)
- BlocProvider<DebtBloc> + CurrencyBloc(MultiBlocProvider)

## 5. 收款语义(对称还款)

- 债务(BorrowedIn):RecordPayment = 我还钱(from 我的账户 → to 债权人)
- **债权(BorrowedOut):RecordPayment = 确认收款**(from 债务人 → to 我的收款账户)
- proto RecordPayment 复用(debt_id + schedule_entry_id + from_account_id),语义「收款」(UI label)
- schedule entry paid = 已收(别人已还这期)

## 6. 御财 token(遵循)

奶油白/金/深色/绿/红/serif/mono tabular-nums。进度条 金色已收 + 灰底。已收绿✓/待收中性/逾期红。

## 7. 测试(widget TDD)

- 债权列表:债权卡 + progress + 收款操作
- 收款详情:Hero + StatCard + 收款 schedule + 确认收款 RecordPayment
- 创建债权:type BorrowedOut + 应收账户 + 摊还预览
- server:CreateDebt type + ListDebts type filter + ent migrate

## 8. 范围边界

### 本期做
- server debt type 扩展(proto/ent/service/migrate)
- client 债权(独立 /receivables 页 3 页 + domain/data/bloc typeFilter + router/nav)

### 本期不做
- BorrowedIn/CreditCard type UI(字段支持,UI 后续)
- 债权到账通知(notification,后续)
- 提前收款模拟器(后续)

## 9. 原型参考

OD `yucai-receivables-prototype-558f`(9 页:receivables/receivable-detail/receivable-form × desktop/tablet/mobile,视觉伴侣已展示)。
