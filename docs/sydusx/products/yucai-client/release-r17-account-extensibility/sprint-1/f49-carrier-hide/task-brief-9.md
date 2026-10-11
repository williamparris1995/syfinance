# Task Brief T9 — 收口:grep 门 + 露出回归 + 全门(FR-6/收口)

## 上下文
worktree:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f49`;客户端 `yucai/client`。**前置:T2-T8 全部完成**。
先读 spec.md(FR-6/NFR-3)与 design.md(单元4 grep 门、Risks)。

## 任务
1. **grep 门脚本**:`yucai/client/tool/f49_visibility_gate.dart`(或 py/sh,照 tool/ 既有脚本风格):静态扫描 lib/**/presentation/** 中消费 accounts 流的列表/选择器渲染点,白名单文件清单外若出现「未包 AccountVisibility.userVisible 的账户直渲」→ 报错退出 1。先人工核对当前全绿,白名单=确属金额计算/非用户选择场景的位置(逐条注释理由)。
2. **FR-6 露出回归测**:①卡详情「还款计划」面板(AccountRepaymentPlanPanel 或其挂接位)在载体隐藏后仍渲染;②债务页「信用卡账单分期」分组仍渲染(既有测试若已覆盖,引证并补一条含 isSystem 载体的正向断言)。
3. **T1 评审遗留核对**:`AccountVisibility.userVisible` 生产调用点清单非空(T4 接线后 grep 呈报)。
4. **全门**(此任务独占运行,无并行):全量 `flutter test`(基线=2496+本票新增,全绿)+ `flutter analyze`(error 20 全 pbserver)+ 根 `make client-e2e`(worktree 内可用性若受限,回退:`cd yucai/client && flutter test integration_test` 照既有 e2e 管道;报告实际执行方式)。

## 约束
只新增门脚本+回归测;禁改生产代码(发现缺口→报告,由控制者裁决归属任务返工)。

## 完成判据
门脚本当前全绿+说明;两回归测绿;三道门结果全文尾行;`AccountVisibility` 调用点清单。
