# 御财交易页移动端 · 设计

- **日期**: 2026-06-26
- **状态**: 设计已确认,待转实施计划
- **范围**: `transactions_page` 移动端三件套(交易卡 chip/时间 + 筛选底部 sheet + month-bar/可展开汇总)
- **分支**: main(新分支 `transactions-mobile`)
- **不含**: desktop/tablet 交易页(已有 `_TxCard` 表格)、交易详情/表单移动端、底部 tabbar+FAB(shell 层)

## 1. 概述

御财交易页 mobile 分支(`_MobileList`/`_MobileTxnCard`)已有基础,但:
- 交易卡副行仅「日期·账户」,无分类 chip/HH:MM/账户首字母方块
- 筛选用横向 `TxnFilterBar`(desktop 风格),mobile 应底部 sheet
- 无 month-bar(月份切换)/可展开汇总

OD `mobile/transactions.html` 定义了 mobile 三件套。本 spec 对齐。

## 2. 决策(已确认)

- 三件套全做:① mobile 交易卡(chip/时间) ② 筛选底部 sheet ③ month-bar + 可展开 sum-card
- 对齐 OD mobile transactions.html
- mobile 分支(`ResponsiveLayout.mobile`)用 `_MobileHeader` + `_MobileList`(改卡) + appbar filterBtn sheet,**替代** desktop `_Header`+`SummaryCard`+`TxnFilterBar`(mobile 隐藏这三个)
- 分类 chip 用 account-as-category(分类 = expense/income 账户的 `category.label`)
- 月份切换改 `_filter.month`(prev/next)
- 汇总展开用现有 `MonthlySummary`(income/expense/net/dailyAvg);储蓄率/已对账/较上月**无数据源 → 本期省略**

## 3. 三件套

### 3.1 mobile 交易卡(`_MobileTxnCard` 改)
- icon(`_TxIconBox` 42×42 圆角,expense 红/income 绿/transfer 金)
- 描述(`txn.description`)
- **副行重做**:
  - 非转账:**账户首字母方块**(17×17,账户名首字 + 类型色) + 账户名 · **HH:MM**(`transactionTime`)
  - 转账:转出 首字母方块+名 **→** 转入 首字母方块+名 · HH:MM
- **右侧重做**:
  - **分类 chip**(expense 红/income 绿/transfer 金,带 dot,文本 = `category.label` 或 flavour 中文)
  - 金额(`_formatCents` signed,色按 flavour)

### 3.2 mobile 筛选 sheet(新增 `_MobileFilterSheet`)
- mobile appbar **filterBtn**(icon) + 搜索 btn(icon)
- 点 filterBtn → scrim + 底部 sheet(`showModalBottomSheet`)
- sheet 内容: grip + h3「筛选交易」+
  - 交易类型 chip(全部/收入/支出/转账,单选)
  - 账户 chip(全部账户 + `accountOptions`,单选)
  - 分类 chip(全部分类 + `categoryOptions`,单选)
  - 月份 chip(`monthOptions`,单选)
  - 重置 + 应用按钮
- 复用 `_filter` state + `onFilterChanged`;mobile **隐藏横向 `TxnFilterBar`**

### 3.3 mobile month-bar + 可展开 sum-card(新增 `_MobileHeader`)
- **month-bar**: prev 箭头 + 月份文本(`YYYY年M月` + 「本月·共 N 笔」) + next 箭头(切 `_filter.month`,调 `onFilterChanged`)
- **sum-card**: 收入/支出/净额 三列(`MonthlySummary`) + 「查看月度明细」toggle 展开(sum-extra: **日均支出** `dailyAvgCents`;储蓄率/已对账/较上月无数据 → 省略)

## 4. 实现要点

- `ResponsiveLayout.mobile` 分支:`_MobileHeader`(替代 `_Header`+`SummaryCard`) + `_MobileList`(改卡) + mobile appbar(替代 `TxnFilterBar`)
- **mobile appbar**: 标题「交易管理」+ 搜索 btn + filterBtn + 创建 btn(+);导出移到更多菜单或省略(mobile 低频)
- `_MobileTxnCard`: 副行(首字母方块 + HH:MM) + 右侧(分类 chip + 金额)重做
- `_MobileFilterSheet`: `showModalBottomSheet`,复用 `_filter` + options
- month-bar: prev/next 调 `onFilterChanged`(`_filter` 的 month ±1)
- 数据源:`transactionTime`(HH:MM)、`account.category.label`(分类 chip)、`MonthlySummary`(汇总)

## 5. 御财 token(遵循)

OD mobile token(bg #f7f6f2 / card #fff / gold #b08d57 / income #2d8a6e / expense #c4544d / border #e6e3dc / serif Georgia / mono tabular-nums)与御财一致。

## 6. 测试(widget TDD)

- mobile 交易卡:分类 chip + HH:MM + 首字母方块 渲染(非转账/转账两分支)
- mobile 筛选 sheet:filterBtn tap → sheet 弹出 + chip 单选 + 应用 → sheet 关 + filter 更新
- mobile month-bar:prev/next tap → 月份文本变 + onFilterChanged 收到新 month
- mobile sum-card:三列(收入/支出/净额) + 展开日均支出

## 7. 范围边界

### 本期做
- `transactions_page` mobile 分支三件套(交易卡 + 筛选 sheet + month-bar/可展开汇总)

### 本期不做
- desktop/tablet 交易页(已有 `_TxCard` 表格,不动)
- 交易详情/表单移动端(单独 spec)
- 汇总展开高级字段(储蓄率/已对账/较上月,无数据源)
- 底部 tabbar + FAB(shell 层,单独 spec)

## 8. 原型参考

OD `yucai-transaction-trisize-9d3e` / `mobile/transactions.html`(视觉伴侣已展示)。
