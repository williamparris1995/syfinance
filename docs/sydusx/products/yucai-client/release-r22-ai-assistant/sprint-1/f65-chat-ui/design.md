# Design: F65 聊天 UI 闭环

prototype: v19 —— 用户拍板 2026-10-23(入口=**V1 独立助手 FAB+400px 右下聊天浮层**;六状态卡+端侧模型管理卡整体确认;`prototype/CURRENT`→v19,OD run 438d3337)。

## Context

- spec:[spec.md](spec.md)(FR-1..5/NFR-1..4,纯内嵌定案版);F64 地基已合 main(事件流/注册表/AssistantSettings 骨架)。
- 架构:client DDD 四层+flutter_bloc;**依赖序:F66(边车+provider 收窄)→F67(模型管理)→F65 本票**(sprint 重构 2026-10-23;本票 design 先行完成,execute 排在 F66/F67 后)。

## Goals / Non-Goals

- **Goals**:F65 全部 FR/NFR——聊天浮层(V1 形态)/五工具/模型管理卡 UI/澄清原则一般化/口径断言全量。
- **Non-Goals**:照 spec Out of scope(历史持久化/标签金额过滤/XIRR/技能包/云选项/写操作);引擎与下载内核=F66/F67。

## Decisions(ADRs)

- **ADR-1 入口=V1 独立助手 FAB+聊天浮层(用户拍板)** — rationale:就地问最快答,与桌面记账主场景契合;浮层 400px 右下锚定,不占路由。alternatives:V2 全页(空间完整但离上下文)/V3 并存(冗余)/V4 簇成员(统一但入口降级)——四变体经 OD 对比页用户终拍(挑战=spec 基线原为侧栏页+用户中途改定 FAB 主入口方向;辩护=spec FR-1 明文允许变体替换基线)。**无新路由无侧栏项**;「新对话」按钮在浮层头部(spec FR-4)。
- **ADR-2 会话状态=AssistantPanelBloc(家法)** — 订阅 AgentLoopService 事件流;TextDelta 高频增量 ~30ms 缓冲合帧防卡顿;消息 view-model sealed:UserMsg/AssistantMsg(增量聚合)/ToolStatusMsg/ErrorMsg/GuideMsg(未就绪引导)。
- **ADR-3 五工具结构照 F64 范式** — data/tools/ 新增五件+注册表登记;performance_range 直接 import report/domain 汇编器(同 F64 工具 import debt/domain 先例,无新 port)。
- **ADR-4 模型管理卡=设置页新卡** — 纯 UI 面+接线 F66/F67 的引擎/下载状态 port(spec FR-3;零端点零 Key 零云)。
- **ADR-5 澄清原则=system prompt 常量修订** — F64 五要素扩为一般化原则(歧义先问/超界明局限+替代/禁编造);常量断言+回放钉(FR-5)。
- **ADR-6 原生薄 UI** — 不接任何 IM/chat SDK(用户拍板;Sydusx IM SDK 查证不存在,IM SDK 品类错配)。

## HLD

```
lib/assistant/
  presentation/
    assistant_panel/  — AssistantPanelBloc + AssistantOverlayHost(FAB+浮层宿主,R19 dock 同屏错位)
    widgets/          — chat-floating-panel/tool-status-bar/clarify-chips/guide-panel
  data/tools/         — holdings_list/transactions_search/budgets_status/goals_list/performance_range
lib/settings(既有页)  — AI 助手卡 widget(模型管理卡,照 v19)
core/di               — F66 后接线:引擎状态 port/模型管理 port → 卡与浮层引导态
```

依赖:presentation→domain(AgentLoopService 事件流);tools→各域 domain port+F43 汇编器;无新路由。

## LLD

- **AssistantPanelBloc**:events=SendRequested(text)/RetryRequested/NewConversation/ClearGuide;state=messages 列表+sendState(idle/streaming/awaitTool/error/guideNotReady);订阅 loop.send() 事件流→TextDelta 缓冲 30ms flush→AssistantMsg 增量;ToolCallStart/End→ToolStatusMsg(「正在查询净资产…」);Done→streaming→idle;AssistantError→ErrorMsg(重试可用)。
- **AssistantOverlayHost**:全局右下 FAB(独立,错位于 R19 FloatingActionDock——dock 右下锚定时助手 FAB 位于其正上方 56px 间距,令牌定);点击 toggle 浮层;浮层宽 400px 照 v19。
- **五工具 schema 要点**:holdings_list{}(面板口径:成本/市值/浮盈+百分比);transactions_search{start?,end?,account?,category?,keyword?,direction?,page?,page_size≤50};budgets_status{}(各预算执行度+超支标记);goals_list{}(进度+预计达成);performance_range{start?,end? 缺省年初至今}(期初/期末市值/净买入/估算收益/TWR,报告口径)。
- **prompt 常量修订**:五要素→七要素(歧义先问给选项/超界明局限给最近路径);`identical` 断言+集成回放(歧义场景先澄清再执行)。

## Risks / Trade-offs

- [浮层与 dock 同屏遮挡(窄屏)] → 错位 56px+令牌间距;窄屏降级=浮层全宽(照 v19 移动规则页内已压桌面,e2e 覆盖主桌面态)。
- [TextDelta 高频渲染卡顿] → 30ms 缓冲合帧;widget 测钉。
- [F66/F67 未落地时 F65 无法端到端] → 依赖序既定;开发期 mock 引擎状态 port 单测先行。
- [performance_range 汇编器区间参数语义] → 与报告页同 range 语义复用;口径断言同区间比对。

## Migration Plan

纯新增(浮层+卡+五工具);无路由/drift/proto 变更;F66 将收窄 AssistantConfig(provider 退役)——本票 UI 不依赖 provider 概念。回滚=移除 FAB 宿主+卡+工具注册行。

## Open Questions

- F66 引擎状态 port 形态(轮询 vs 流)——F66 design 定,本票消费。
