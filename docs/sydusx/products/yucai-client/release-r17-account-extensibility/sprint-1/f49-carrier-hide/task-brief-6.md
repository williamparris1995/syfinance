# Task Brief T6 — 卡详情分期区块(FR-4b)

## 上下文
worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f49`;客户端 `yucai/client`。
先读 feature 目录 `spec.md`(FR-4b 两场景)、`design.md`(单元6)。视觉基准:`docs/sydusx/products/yucai-client/prototype/v12/ui/f49-carrier-compare.html` 第三段「平安信用卡·详情页视角」(文本打开读结构与文案即可)。
现状:`account_detail_page.dart` 约 205-224 行已有按 `collectionAccountId == widget.id` 过滤的挂接债展示(F48 落的),你要把它增强为 spec 的分期区块形态。

## 任务(TDD)
`account/presentation/pages/account_detail_page.dart` 挂接面板增强:
- 每笔并入型分期一行:债权方(counterparty)/ muted「N 期 · 第 k 期 · 放款对应日出账」/ 右侧「剩余 ¥X」+「下一期 ¥Y · M/D 并入账单」/ 行尾「查看债务 →」跳 `/debts/:id`(路由照既有 debt 跳转先例)
- 区块标题「现金分期」;空态(无挂接)区块隐藏(维持现状语义)
- 数据:页面既有 debts 流;期次进度/下一期取自 payment schedule(既有 DAO/仓储方法,先查再用,勿新造查询)
- 主题令牌 context.yucai,数字 tabular;文案照 v12 原型

测试(account_detail_page 既有测试文件增测或新文件):
- 挂接 1 笔:行字段齐全(债权方/剩余/下一期)且点击发出 /debts/:id 导航
- 无挂接:区块不渲染

## 约束
只动 account_detail_page + 其测试;禁碰 accounts_page/debt 模块/repairs。中文注释,令牌零硬编码。

## 完成判据
两测绿;analyze 零新增;报告面板挂接点行号+改动清单。
