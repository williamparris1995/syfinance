# Task Brief T2 — AssistantPanelBloc(会话状态编排)

- worktree 同 T1。TDD;不碰 server/F46/其他模块;**assistant/domain/agent_loop.dart 允许本票扩一个方法**(见下),其余 domain 契约不动;与 T1/T4 并行,不碰 tools/ 与 settings。
- 必读:design.md(ADR-2/LLD bloc 节)+spec FR-1/FR-4 场景;`lib/assistant/data/agent_loop_impl.dart`(事件流与内存会话);F64 的 agent_loop_impl_test(fake 范式);任一既有 bloc(bloc_test 范式)。
- 任务:
  1. **domain port 扩一方法**:`AgentLoopService` 加 `void resetConversation()`(doc:清空内存会话,下次 send 重新注入 system prompt);impl 照做+单测(清空后 system prompt 仍队首注入一次)。
  2. **`lib/assistant/presentation/assistant_panel/assistant_panel_bloc.dart`**:events=SendRequested(text)/RetryRequested/NewConversationClicked;state=消息列表 `List<PanelMessage>`+`sendState{idle,streaming,awaitTool,error,guideNotReady}`;**PanelMessage sealed**(presentation 内 view-model):UserMsg(text)/AssistantMsg(累积 text)/ToolStatusMsg(name,ok)/ErrorMsg(text,retryable)/GuideMsg(kind:notEnabled|modelNotReady|engineStarting)。
     - send:config 不 ready→GuideMsg(notEnabled)+guideNotReady(**零 LLM 调用**);ModelState 非 ready→GuideMsg(modelNotReady)(绑 ModelManagerPort.state 查询);EngineState.starting→GuideMsg(engineStarting);否则订阅 loop.send():TextDelta **30ms 缓冲合帧**(Duration 可注入,测试 0)→AssistantMsg 增量;ToolCallStart/End→ToolStatusMsg;Done→idle;AssistantError→ErrorMsg(可重试)。
     - retry:重发最后一条 UserMsg(历史保 ErrorMsg 之上追加,不删错)。
     - 新对话:loop.resetConversation()+清空消息列表+idle。
  3. **DI 不接**(T3/T4 接线);bloc 构造注入 AgentLoopService+AssistantSettings(listenable 或 getter)+ModelManagerPort 状态 ValueListenable+EngineManager 状态——全缝。
- 测试(bloc_test):流式合帧(fake 时间或 Duration.zero)/工具条插入序/错误可重试(重试再走全流程)/未启用引导零调用/模型未就绪引导/starting 引导/新对话清空+reset 被调/会话保序。
- 验证门:`flutter test test/assistant/` 绿(遇并行 WIP 编译抖动排除复跑注明)/analyze 零新增/server diff 空。commit `feat(assistant): F65-T2 会话面板 bloc`。汇报:文件清单+测试数+commit hash。
