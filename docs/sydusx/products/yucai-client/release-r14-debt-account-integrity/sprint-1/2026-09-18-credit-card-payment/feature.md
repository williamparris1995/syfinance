# Feature — F34 支出支付方式放开信用卡(R14 sprint-1)

> 2026-09-18。

## Description

现状:`transaction_form_page.dart` 账户选择器硬过滤 `accountType == asset`,信用卡等负债账户不能作为支付方式(用户需求 4)。分录推断逻辑已有「费用-其他类型」通用兜底(dr expense / cr 任意),改动集中在:支出类型放开 liability 账户可选、dr expense / cr credit-card 语义校验、余额/统计口径(信用卡余额向负债方向累积)、表单文案。纯 client。

## Stories

- [ ] S1: spec——可选账户口径(支出=资产+信用卡负债)、分录/余额语义、与信用卡还款流程的边界
- [ ] S2: 实现——picker 过滤放开 + 校验/口径
- [ ] S3: 测试——表单分录单测 + 记一笔 e2e(信用卡支付路径)+ 全量门

## Keywords

`信用卡支付` `支付方式` `credit-card` `payment` `支出` `expense` `transaction-form` `负债账户`
