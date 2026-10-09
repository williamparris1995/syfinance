# Sprint 1 — 治欠账三票

> /sydusx-portfolio 2026-10-09 立项。目标:R17 中不依赖预设层调研的三张独立小票先行落地,全部建立在 `b6205457`(e招贷解挂+独立账单)地基上。

## Sprint Goal

载体户退出用户视野、额度占用口径落地、双重表示规则化——三票各自独立可发,合起来完成「账户体系通电+对齐银行口径」的欠账面。

## Features

- [ ] **F49 isSystem 激活·载体户隐藏** — 卡贷自动建户置 isSystem=true(account_local_ds 现硬编码 false);账户页列表/建户相关下拉/聚合过滤 isSystem 载体户;净资产与账务不动。transaction 分类模块的 parentId+isSystem UI 为库内先例。 `claimed: zcode 2026-10-09`
- [ ] **F50 卡贷额度占用重落** — 重落 `794bc677`(实现 6 分钟后被 `8088dd36` 回退,原因未录;解挂后挂接卡仅平安/广发,灌水动因已消):已用/利用率计入 Σ挂接卡贷未出账剩余;口径(银行全额=本金+息费 vs 钱迹=本金)spec 拍板。
- [ ] **F51 loan·invest 双重表示规则化** — 账户挂债时 loan 字段组(loanOriginal/Remaining/Monthly/NextPaymentDate)只读降级、有 holding 挂接时 invest 字段组同理;表单提示「以债务/持仓数据为准」;不迁移不删列。

## status: pending
