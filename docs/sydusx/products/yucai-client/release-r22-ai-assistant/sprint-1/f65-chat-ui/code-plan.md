# F65 code-plan

> /sydusx-execute 2026-10-24(rebase main 6ce28f3f 后)。批次:[T1∥T2∥T4]→[T3]→[T5];SDD;UI 照 prototype/CURRENT v19。

- [ ] T1 全量只读工具×5 — holdings_list(面板口径)/transactions_search(六项过滤+分页)/budgets_status/goals_list/performance_range(包 F43 汇编器报告口径);口径断言扩八工具参数化
- [ ] T2 AssistantPanelBloc — loop 事件流订阅+TextDelta 30ms 合帧+消息 view-model sealed+未就绪引导+错误重试+新对话(port 扩 resetConversation)
- [ ] T4 设置卡+接线 — 「AI 助手」端侧模型管理卡(绑定 ModelManagerPort/EngineManager 状态)+DI 注册
- [ ] T3 浮层宿主与渲染 — 全局右下助手 FAB(R19 dock 错位)+400px 聊天浮层(流式/工具条/引擎动效/新对话/引导态)+浮层打开预热;widget 测
- [ ] T5 prompt 七要素+全门+e2e+覆盖表
