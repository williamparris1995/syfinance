# Task Brief T2 — WriteExecutorImpl + bloc 扩展(确认门机制)

- worktree `.claude/worktrees/r22-f70`(T1 d418887b 已合入)。TDD;不碰 server/F46/T3 范围(UI)。
- 必读:design.md(ADR-1/2/3,LLD 确认流)+spec FR-5 全场景+T1 汇报要点(add=recordExpense/recordIncome[direction→expense/incomeAccountId=categoryId,assetAccountId=accountId];update=确认时 getById 现读 version+全分录重建;delete=repo.delete)。
- 任务:
  1. **`data/write_executor_impl.dart`** `@LazySingleton(as: WriteExecutor)`——构造注入 TransactionRepository+AgentLoopService(appendToolOutcome;loop 不依赖 executor 无环)+AssistantAuditLog+clock 缝;`execute(action,key)`:幂等集(key→entityId;重复=AlreadyExecuted 不再写);Add→按 direction record*;Update→getById(现读 version)→patch 重建 entries→update(version 冲突=WriteFailed(versionConflict));Delete→delete;每路 logWrite+成功 `appendToolOutcome('已记:支出 ¥35.00 午饭 招商银行')` 式紧凑单行(中文 note——进会话上下文与 UI,不进日志串;logWrite 参数 English);异常→WriteFailed(runtimeType 零 payload)。
  2. **bloc 扩展**(assistant_panel_bloc):PanelMessage 新型 `WriteApprovalMsg{idempotencyKey,action,preview(Map),status: pending/confirmed/cancelled/superseded/void/failed(reason)}`;events `ConfirmWriteRequested(key)`/`CancelWriteRequested(key)`/`RetryWriteRequested(key)`;loop ToolData 特判 requiresApproval→发 pending 卡(同刻单卡:旧 pending→superseded);确认→executor.execute→Executed/AlreadyExecuted→confirmed(+executor 已注 outcome,bloc 补本地确认消息文案);Failed→failed(重试=RetryWriteRequested,key 复用——失败不消耗幂等键);取消→cancelled;新对话→pending→void。三重守卫/合帧/重试语义与既有互不干扰(回归测)。
  3. **绕过负测(代码门)**:fake repo+fake executor 计数——仅经 bloc ConfirmWrite 事件可达写;直接构造任何其他路径(工具直调/loop 流事件/取消)零写调用(T1 已钉工具零写,T2 钉 bloc→executor 唯一通道+未确认零执行)。
  4. DI:2g/1m 补 WriteExecutor 注册;bloc 构造加 WriteExecutor 缝(既有注入面扩一)。
- 验证门:`flutter test test/assistant/` 全绿/analyze 零新增(基线以 466 记,差异说明)/server diff 空。commit `feat(assistant): F70-T2 写执行器+确认门 bloc 机制`。汇报:文件清单+测试数+幂等/作废/替换/绕过四负测断言摘要+commit hash。
