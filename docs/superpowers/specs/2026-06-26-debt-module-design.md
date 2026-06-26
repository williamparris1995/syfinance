# 御财 Debt 债务模块 client 移植 · 设计

- **日期**: 2026-06-26
- **状态**: 设计已确认(OD 9 页 + 调研最佳实践),待转实施计划
- **范围**: Debt client 移植(列表/详情/创建/还款,三端响应式 desktop/tablet/mobile)
- **分支**: main(新分支 `debt-module`)
- **不含**: server debt(已有,不改)、snowball/avalanche 策略、提前还款模拟器(后续)

## 1. 概述

御财 server debt module **完整**(7 RPC + domain + ent payment_schedule),client 待移植(lib/ 无 debt)。调研业界(Debt Payoff Planner/YNAB/Tally)最佳实践:总债务概览 progress bar、摊还表、下次还款提醒、还款记账、进度可视化。

OD 设计 9 页(3 页 × desktop/tablet/mobile,御财 token)。本 spec 移植 Debt client:数据层(domain/data/bloc) + UI 层(debts/detail/form 三页,三端响应式)。

## 2. 决策(已确认)

- **全移植**(列表 + 详情 + 创建/编辑 + 还款记账)
- **三端响应式**(desktop/tablet/mobile,对齐 OD 9 页 + 御财 900/720 模式)
- **进度可视化**(progress bar 还清进度,调研最佳实践)
- **摊还表**(schedule 每期 本金/利息/合计/状态)
- **还款记账**(RecordPayment,关联 from_account)
- **到期提醒**(GetUpcomingPayments)
- **不含** snowball/avalanche 策略 + 提前还款模拟器(server 无,后续)

## 3. 数据模型(server debt proto,已有)

- **DebtDTO**:account_id(关联 loan 账户) + counterparty(债权方) + interest_rate(年利率) + amortization_method(等额本息 EQUAL_PRINCIPAL_INTEREST / 等额本金 EQUAL_PRINCIPAL / 一次性 LUMP_SUM) + start_date + due_date + total/remaining_principal_cents
- **PaymentEntryDTO**:payment_date + principal/interest/total_cents + paid(bool) + paid_cents + transaction_id
- **DebtDetailDTO**:debt + schedule[]
- **7 RPC**:CreateDebt / UpdateDebt / DeleteDebt / RecordPayment / GetDebt / ListDebts / GetUpcomingPayments

## 4. 数据层(client,对齐 account/transaction 模式)

- `domain/debt_entity.dart`:Debt + PaymentEntry + AmortizationMethod enum
- `data/debt_remote_ds.dart`:gRPC 7 RPC
- `data/debt_repository_impl.dart` + `debt_mapper.dart`
- `presentation/bloc/debt_bloc.dart`(LoadDebts / LoadDebt / CreateDebt / UpdateDebt / DeleteDebt / RecordPayment events + states)

## 5. UI 层(对齐 OD 9 页)

### 5.1 `debts_page`(列表)
- PageHeader + StatCard(总负债 / 剩余 / **已还比例 progress bar** / 下次还款)
- 债务卡(counterparty + 类型 badge[房贷/车贷/信用卡/亲友借款] + **剩余本金(大字)** + **progress bar 还清进度** + 利率 + 到期 + 下次还款 + 操作[详情/记账/更多])
- 三端:desktop 表格 / tablet 2 列卡 / mobile 单列卡 + 抽屉 sidebar + FAB

### 5.2 `debt_detail_page`(详情)
- Hero(深色金渐变 + **剩余本金(大字)** + **progress bar** + 较上月变动)
- StatCard 行(总本金 / 年利率 / 到期日 / 摊还方法 / 已还期数)
- **还款计划**(schedule):每期(日期 / 本金 / 利息 / 合计 / 状态[已还绿✓/待还中性/逾期红] / 操作[记账])
- 筛选(全部/待还/已还/逾期)
- RecordPayment(点待还期「记账」→ 从账户还款,关联 from_account)
- 三端:desktop 表 / tablet 表横向滚动 / mobile **卡列表**(每期一卡)+ 底部 sticky 记账 bar

### 5.3 `debt_form_page`(创建/编辑)
- 表单分区:债权方 + 类型 + 关联账户(loan) + 本金 + 利率 + 摊还方法(单选) + 起止日期
- **实时预览**(还款计划前 5 期,基于摊还 + 本金 + 利率)
- 三端:desktop 分区 / tablet 双列(表单 + 预览) / mobile **step wizard**(基本信息→金额利率→日期)+ 预览折叠

## 6. 路由

`/debts`, `/debts/:id`, `/debts/new`(对齐 account/transaction 模式)

## 7. 御财 token(遵循)

奶油白 #f7f6f2 / 御财金 #b08d57 / 深色 #1c1e21 / 收入绿 #2d8a6e / 支出红 #c4544d / 边框 #e6e3dc / serif Georgia / mono tabular-nums。进度条:金色已还 + 灰底。已还绿✓ / 待还中性 / 逾期红。

## 8. 测试(widget TDD)

- 列表:债务卡渲染 + progress bar + 类型 badge + 筛选
- 详情:Hero + StatCard + schedule 表/卡 + RecordPayment
- 表单:字段 + 摊还预览 + 创建 RPC
- 三端响应式(desktop/tablet/mobile,viewport test)

## 9. 范围边界

### 本期做
- Debt client 移植(列表/详情/创建/还款 + 三端响应式 + 数据层 + bloc)

### 本期不做
- server debt(已有,不改)
- snowball/avalanche 策略(server 无,后续)
- 提前还款模拟器(后续)
- 到期提醒推送(notification,后续)

## 10. 原型参考

OD `yucai-debt-prototype-a7fb`(9 页:debts/debt-detail/debt-form × desktop/tablet/mobile,视觉伴侣已展示)。
