# Design: F70 确认门写工具

prototype: v20 —— 用户拍板 2026-10-27(六形态整体确认:V1 新增预览/V2 前后对比/V3 destructive 强确认/V4 查无引导/V5 替换作废/V6 失败重试;OD run a1990b4f;CURRENT→v20)

## Context

- spec:[spec.md](spec.md)(两拍板:支出+收入 v1/全部确认零例外);F65 面板/bloc/八只读工具已合 main;F71 审计表为姊妹票。
- 架构事实:TransactionRepository create/update/delete 全链既有(表单同管道);loop 工具循环为同步执行模型(无挂起语义)。

## Goals / Non-Goals

- **Goals**:三写工具+确认门全机制+幂等+引导;写路径同源;审计事件先日志后 F71。
- **Non-Goals**:照 spec Out of scope(转账/直建账户/免确认/批量/非交易写/F71 表)。

## Decisions(ADRs)

- **ADR-1 写工具两段执行(propose→execute),确认门在代码层** — 写工具 `execute()` 不落库,返回 `ToolData{requiresApproval:true, action:WriteAction}`;loop 轮次正常收口(工具结果回填 LLM「已生成待确认操作」);**实际落库由独立 `WriteExecutor`(bloc 确认回调触发)执行**,带幂等键守卫。代码门=WriteExecutor 只从确认回调可达(私有 key/回调注入,测试钉死零绕过)。alternatives:工具内挂起等待(hack 流模型)/模态对话框内直接执行(散逻辑)。
- **ADR-2 确认执行结果注入会话上下文** — 确认执行后,经 loop port 新扩 `appendToolOutcome(note)`(tool role 消息追加入内存会话)——后续对话 LLM 知晓已记账(「刚才记了多少」可答);UI 侧同时追加本地确认消息。port 扩方法照 F65 resetConversation 先例。
- **ADR-3 幂等键=确认实例 uuid+已执行集** — 每张确认卡持唯一 key;WriteExecutor 维护 executedKeys(会话内);重复触发=返回已执行结果不重复落库。
- **ADR-4 定位=复用只读面** — 改/删定位经 transactions_search(名称/时间/最近 N 笔);多候选→助手列候选让用户说哪一个(澄清原则);不暴露内部 id。
- **ADR-5 引导跳转=go_router 既有表单路由** — 「要新建吗?」→ 跳 /transaction-form/new 或 /accounts/new;**预填若表单无现成入口则 v1 不预填**(记 OQ,预填=后续票)。
- **ADR-6 审计事件先日志** — AssistantAuditLog 扩 `logWrite(tool,payloadSummary,entityId,ok)`(English);`AgentAuditEvent` 值类型按 F71 契约预留(F71 落表时消费)。
- **ADR-7 确认卡=PanelMessage 新型态** — bloc 扩 `WriteApprovalMsg{action,前后数据,状态 pending/confirmed/cancelled}`;同刻单卡(新写请求替换旧的,旧的标 superseded);新对话=作废;渲染形态(内嵌卡/底部卡)照 v20 用户拍板。

## HLD

```
lib/assistant/
  domain/
    write_action.dart     // sealed WriteAction{TransactionAdd/Update/Delete fields} + 定位引用
    write_executor.dart   // abstract WriteExecutor{execute(action, idempotencyKey)}(仅确认回调可达)
  data/
    write_executor_impl.dart // TransactionRepository 调用+幂等集+审计事件+appendToolOutcome
    tools/
      transaction_add_tool.dart / transaction_update_tool.dart / transaction_delete_tool.dart
  presentation/(F65 扩展)
    assistant_panel_bloc  — WriteApproval 消息型态+ConfirmWrite/CancelWrite 事件+作废/替换语义
    widgets/              — write_approval_card(三形态照 v20)
```

## LLD

- **WriteAction**:Add{direction,amountCents,description,accountId?,categoryId?,date}/Update{ref(交易定位 id 内部解析),patch{...}}/Delete{ref}。工具入参用名称,execute 前经 repository 解析为内部 id(解析失败→ToolError 自纠列候选)。
- **确认流**:工具→ToolData{requiresApproval,action(含解析后 id)}→loop 回填 LLM「已生成待确认」→bloc 收 ToolData 特判→WriteApprovalMsg(pending)→用户确认→`writeExecutor.execute(action,key)`→成功:msg 转 confirmed+loop.appendToolOutcome+审计;取消:msg 转 cancelled;替换/新对话:superseded/void。
- **绕过负测**:WriteExecutor 构造私有(仅 DI+bloc 回调路径);测试断言未经确认回调任何路径零 repository 写调用。

## Risks / Trade-offs

- [4B 解析口述参数错误(金额/账户名)] — 确认卡即防线(用户看到解析结果才确认);解析歧义→澄清原则。
- [确认后执行失败(账户删了等竞态)] — executor 错误→confirmed 卡转 error+重试按钮;幂等键不消耗。
- [appendToolOutcome 上下文膨胀] — 单行紧凑 note(「已记:支出 ¥35 午饭 招行卡」),不回填完整 payload。
- [表单预填缺口] — OQ 回填;v1 引导只跳转。

## Migration Plan

纯新增+port 扩两方法(appendToolOutcome/resetConversation 先例);零迁移零新依赖;回滚=删 write 三文件+DI+bloc 扩展。

## Open Questions

- ~~表单预填入口现状~~ **已查证回填(T1,2026-10-27)**:记账表单路由 `/transactions/new` 仅支持 `extra=Transaction`(复制模式全字段预填,router.dart);**无部分字段(金额/描述/分类/日期)预填入口** —— `TransactionFormPage` 的 `initialAccountId`/`initialType` 预选参数只经账户页**直推 widget 构造**可达,路由层不透传 query param 也不映射 extra Map;账户/分类侧无 `/accounts/new` 独立路由(创建=页面内对话框)。→ **v1 引导只跳转**(裸开表单,ADR-5 预填分支生效);预填=后续票(可经 extra 扩 Map 透传或新增 query param)。
- v20 确认卡形态拍板(用户)。
