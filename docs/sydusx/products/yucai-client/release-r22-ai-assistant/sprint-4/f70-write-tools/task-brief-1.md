# Task Brief T1 — 写域契约 + 三写工具

- worktree `.claude/worktrees/r22-f70`(分支 feature/r22-f70;F64-F67+F65 全在)。TDD;不碰 server/F46;**domain agent_loop.dart 扩一方法豁免**;DI 2g 段加三工具注册豁免。
- 必读:同目录 design.md(ADR-1..6/LLD)+spec FR-1..4;`lib/assistant/data/tools/`(F64/F65 八工具范式:名称解析/ToolError 自纠/双口径);`TransactionRepository` 的 create/update/delete 签名与 CreateTransactionParams 必填面(grep);分类解析路径(transaction 表单怎么定分类——AccountCategory 值域)。
- 任务:
  1. `domain/write_action.dart`:sealed WriteAction——TransactionAdd{direction(in|out),amountCents,description,accountId,categoryId,date}/TransactionUpdate{transactionId,patch(amountCents?/description?/categoryId?/accountId?/date? 至少一字段)}/TransactionDelete{transactionId};toString 全 ASCII。
  2. `domain/write_executor.dart`:abstract WriteExecutor{Future<WriteOutcome> execute(WriteAction,String idempotencyKey)};sealed WriteOutcome{WriteExecuted(entityId)/AlreadyExecuted/WriteFailed(reason)}。
  3. **loop port 扩** `void appendToolOutcome(String note)`(doc:确认执行结果注入会话,tool role 紧凑单行;impl 追加 _messages 不触发流)+单测。
  4. 三工具(`data/tools/`):入参全名称(账户/分类名称匹配+多候选 ToolError 列候选;金额元转 cents;日期缺省今天;direction 枚举自纠);update/delete 定位=内部先查询(描述关键词+时间窗/「最近一笔」=时间倒序第一条),多候选→ToolError 列前 3 让 LLM 问用户;**execute 一律返回 ToolData{requiresApproval:true, action:解析后 WriteAction(内部 id), preview 摘要 Map}**——零落库(ADR-1);单测覆盖解析/消歧/参数面/零写断言(mock repository verifyNever)。
  5. AssistantAuditLog 扩 `logWrite({tool,payloadSummary,entityId,ok})`(English,ASCII 门)。
  6. **OQ 查证**:grep transaction_form 路由与预填机制(query param/模板锚定),结论回填 design.md OQ-1。
- 验证门:`flutter test test/assistant/` 绿/analyze 459 零新增/server diff 空。commit `feat(assistant): F70-T1 写域契约+三写工具`。汇报:文件清单+测试数+分类解析路径说明+预填查证结论+commit hash。
