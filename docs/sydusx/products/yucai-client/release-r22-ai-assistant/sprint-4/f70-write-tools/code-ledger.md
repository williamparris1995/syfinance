# F70 code-ledger

> /sydusx-execute 任务台账(task done / fix-rounds / rulings)。批次:T1→T2→T3→T4 串行(SDD);评审由控制器另行安排,本表先落事实。

- **T1 写域契约+三写工具 ✅ done**(commit d418887b;write_action.dart sealed 三态 + write_executor.dart port/WriteOutcome 三态 + loop port 扩 appendToolOutcome + logWrite + transaction_add/update/delete 三提案器;test/assistant 331 绿;analyze 466 零新增;server diff 空)。零写双钉:mock repo verifyNever + 真库笔数不变。
- **T2 写执行器+确认门 bloc ✅ done**(commit 112c9330;WriteExecutorImpl[表单同管道+幂等集+审计+appendToolOutcome 中文紧凑单行] + bloc WriteApprovalMsg/Confirm/Cancel/Retry 三事件 + 卡态守卫 + 绕过负测组;test/assistant 362 绿 = 331+31;analyze 466;server diff 空)。执行期契约扩:TransactionUpdate 携 direction(见领域发现②)。
- **T3 确认卡与引导卡 UI ✅ done**(commit d8b9698c;write_approval_card 三形态×五状态徽标 + GuidanceCard + overlay 接线 + loop ToolGuidance 旁路;31 新增,test/assistant 393 绿;analyze 466;server diff 空)。
- **T4 写链帽石集成测+全门+覆盖表 ✅ done**(commit 见 git log;新文件 `test/assistant/integration/write_pipeline_integration_test.dart` 4 用例 = 九断言链:内存 drift 真库 + 真三写工具 registry + 脚本化 LlmStreamClient(首轮 transaction_add tool_call 分片拆段,次轮文本收尾)+ 真 AgentLoopServiceImpl + 真 AssistantPanelBloc + 真 WriteExecutorImpl(同 loop/同 audit 实例,镜像 DI 单例装配)。全门:flutter test 全量 **3264 绿 + 1 自跳过**(F66 engine_smoke 引擎夹具不在场,与本票无关;test/assistant 397 = 393+4)/ flutter analyze **466 == 基线零新增** / `git diff main -- yucai/server` **0 字节**;帽石测本机 4/4 首跑全绿)。零生产码改动(纯新增测试+本文档)。

## 需求覆盖对照表(T4 汇总;spec FR/NFR ↔ 测试)

测试根 `yucai/client/test/assistant/`(T1=domain 契约+三工具,T2=data/write_executor_impl_test + presentation bloc,T3=widgets/write_approval_card_test + overlay,T4=integration/write_pipeline_integration_test 帽石)。

| 需求 | 场景 | 测试文件 | 用例名 |
| --- | --- | --- | --- |
| FR-1 记一笔 | 口述记账全流程(提案→确认前零落库→确认落库→审计 actor=agent) | `integration/write_pipeline_integration_test.dart`(帽石)+ `data/tools/transaction_add_tool_test.dart` + `data/write_executor_impl_test.dart` | 帽石 `记一笔全链①②③④⑤⑧…`(①requiresApproval ToolData 回填 LLM + pending 卡携解析后 id/名称摘要 ②确认前真库直查交易/分录/余额全零 ③确认后 DB 一行逐字段[金额 cents/科目借 acc-food/资产贷 acc-cash/note]+余额联动 ④logWrite 行 ⑤「已记:支出 ¥35.00 午饭」单行入下一轮 LLM 上下文 ⑧同 key 二次确认笔数不变)/ T1 `支出:账户/分类名称解析为 id,direction=out,金额元转 cents` + `收入:direction=in 分类解析到 income 账户` + `真实 repo:成功提案后交易笔数不变` + `mock repo verifyNever:账户仓储写方法零调用` / T2 `支出:recordExpense 落库(科目借/资产贷)+ 余额联动 + note + 审计` + `收入:recordIncome 方向分流(资产借/科目贷)` |
| FR-1 记一笔 | 幂等(同一确认重复触发不重复落库) | 帽石 + `data/write_executor_impl_test.dart` + `presentation/assistant_panel/assistant_panel_bloc_test.dart` + `widgets/write_approval_card_test.dart` | 帽石⑧(全链:DB 笔数/分录数/写审计行数三不变)/ T2 `同 key 重复触发:AlreadyExecuted 回放,零写/零注入/零重复审计` + `不同 key 同操作 = 两次独立执行(幂等按键不按内容)` / bloc `幂等负测:确认后再触发同 key 确认 → 状态守卫拒,executor 仍恰一次` / card `失败→重试 → RetryWriteRequested:同幂等键复用,卡回 confirmed`(失败不耗键) |
| FR-2 改一笔 | 改最近一笔(前后对比预览→确认→同管道更新) | 帽石 + `data/tools/transaction_update_tool_test.dart` + `data/write_executor_impl_test.dart` | 帽石 `改一笔全链⑥…`(脚本 update 提案→diff 卡 before ¥30.00/after ¥40.00 名称摘要→确认前逐分未动→确认后 DB 逐分重建[原位同 id/version+1/note 逐侧保留/余额联动再扣 1,000])/ T1 `无过滤 = 最近一笔:时间倒序首条且跳过转账` + `keyword 唯一命中(京东购物)→ 定位该笔` + `before = 定位笔现状;after = patch 覆盖后(名称展示)` + `真实 repo:提案后交易集合逐位不变` / T2 `改金额+描述:entries 全重建,note 逐侧保留,version 现读递增` + `改日期:patch.date 覆盖,其余字段现读随包(full-replace 语义)` |
| FR-3 删一笔 | 删除确认(destructive 强提示→确认→取消保留) | 帽石 + `data/tools/transaction_delete_tool_test.dart` + `data/write_executor_impl_test.dart` + `widgets/write_approval_card_test.dart` | 帽石 `删一笔全链⑦…`(destructive 位 + 目标摘要卡→确认前 1 行→确认后真库直查交易/分录零行 + 余额回滚)/ T1 `keyword 唯一命中 → action{transactionId} + destructive preview` + `真实 repo:提案后笔数不变` / T2 `同管道删除 + note 已删 + 审计行 + 余额回滚` / card `V3 删除强确认卡` 组(红警示+主位反转) |
| FR-4 查无实体新建引导 | 未知账户引导(澄清+跳表单,不代建) | `data/tools/transaction_add_tool_test.dart` + `data/agent_loop_impl_test.dart` + bloc + `widgets/write_approval_card_test.dart` + `widgets/assistant_overlay_host_test.dart` | T1 `account 未知 → ToolError(查无引导,FR-4;携 V4 结构标记)` / loop `unknown-account ToolError(结构标记)→ ToolCallEnd 后发 ToolGuidance…` / bloc `unknown-account 引导映射:ToolGuidance → GuidanceMsg(text+route);LLM 文本澄清照常并存`(断言零确认卡零执行)/ card `引导卡 GuidanceCard(v20 V4 查无实体引导)` 组 / overlay GuidanceMsg 分支接线 |
| FR-5 确认门 | 提示词不可绕过(代码层守卫) | T1 三工具零写组 + `data/agent_loop_impl_test.dart` + bloc + 帽石 | T1 `真实 repo:成功提案后交易笔数不变` ×3 工具 + mock verifyNever ×3 / loop `requiresApproval ToolData → ToolCallEnd 后发 WriteProposed(typed…)` + `action JSON 畸形 → 静默降级零 WriteProposed(零卡零写)` / bloc `绕过负测:提案到达只发 pending 卡,loop 流事件本身零 executor 调用` / 帽石②(全链确认前真库直查全零)+ ⑨(cancelled 后确认仍零写) |
| FR-5 确认门 | 新对话作废(确认后也不再执行) | bloc + loop | bloc `作废负测:新对话后旧 key 确认 → 查无此卡守卫拒,零执行` / loop `resetConversation 一并清空注入结果(新对话作废口径,FR-5)` |
| FR-5 确认门 | 同刻单卡(新写替换旧的)/取消即弃 | bloc + card + 帽石 | bloc `替换负测:新提案替换旧 pending(→superseded);旧 key 确认零执行,新 key 可确认` + `取消:pending → cancelled 零执行;取消后确认 → 守卫拒零执行` / card `superseded:已被新操作替换 chip`(v20 V5)+ 帽石⑨(取消后 DB 零写零写审计) |
| NFR-1 写路径同源 | 与表单完全相同 repository 管道(口径/余额/同步) | 帽石 + T2 真库组 | 帽石③(现金余额 1,000,000−3,500 联动)/⑥(改 30→40 再扣 1,000)/⑦(删除回滚至初始)三处余额直查断言 + 落库分录借贷侧断言(recordExpense 同构)/ T2 全 Add/Update/Delete 真库组(recordExpense→recordIncome→update 重建→delete 回滚,TransactionRepositoryImpl 同管道实证) |
| NFR-2 参数面约束 | 三工具各 ≤8 项,名称匹配不暴露内部 id | 三工具测 | `参数面 ≤8 项(NFR-2)`(add)+ `参数面 ≤8 项(NFR-2),不暴露内部 id 参数`(update/delete) |
| NFR-3 审计衔接 | 每次写执行记审计事件(先日志,F71 落表) | `data/audit_log_test.dart` + T2 + 帽石 | audit `logWrite (F70 NFR-3…)` 组(`ok line format: tool/status/entity/payload` + `error line: empty entity allowed` + `ASCII gate: CJK payloadSummary stripped`)/ T2 `全部审计行可打印 ASCII;中文 note 只进 appendToolOutcome` + 各路 status=ok/error 行断言 / 帽石④(logWrite 行含 entity=落库 id;全行 ASCII 门) |
| NFR-4 server 零改动 | git diff yucai/server 为空 | 非测试:全门 | `git diff main -- yucai/server` 0 字节 + server 子目录 status 干净(T1/T2/T3/T4 每票全门复测通过) |

> 漏项检查:spec ADDED 9 条需求(FR-1..5 + NFR-1..4)全部有对应测试/门,**零 BLOCKED**。FR-4「同意→跳转表单预填可推导字段」的预填面经 OQ-1 查证降级为 v1 只跳转(见领域发现③,spec 层面 FR-4 SHALL 文案的预填分支由 ADR-5 裁决承接,不算 BLOCKED)。

## 领域发现记档(T1-T4 执行期沉淀)

1. **分类 = account-as-category(账户即分类)**:御财的「分类」不是独立实体,而是 expense/income 型科目账户(type=5/4,proto 值域)—— 与记账表单下拉同源。写工具的 category 参数 = 名称在该科目账户池上的唯一解析(零/多命中 → ToolError 列候选澄清);执行时 categoryId 直接作为 expense/income AccountId 进分录(recordExpense 的 expenseAccountId)。帽石①③直证:口述「餐饮」→ acc-food 内部 id → 落库科目借方分录 accountId=acc-food。
2. **update = 全分录重建 + direction 契约扩展**:TransactionRepository.update 是全替换语义(非增量回放)—— 未改字段须现读随包,分录整体重建(表单 `_buildEntries` 镜像:expense=[科目借,资产贷]/income=[资产借,科目贷]),**entry note 逐侧保留**(否则全替换会把原 note 冲掉;帽石⑥ note 备注X 双侧保留直证)。执行器不注入 AccountRepository,借贷侧归属需要方向 → T2 执行期把 direction 提为 TransactionUpdate 契约字段(提案时由工具按分录+账户类型判定钉定;方向不可改 = 删旧建新,v1 不支持)。>2 条分录的复杂笔 fail-closed 拒重建(unsupportedEntryLayout)。
3. **预填无路由(OQ-1 查证回填,T1)**:记账表单路由 `/transactions/new` 仅支持 `extra=Transaction`(复制模式全字段预填),**无部分字段(金额/描述/分类/日期)预填入口**(initialAccountId/initialType 只经账户页直推 widget 构造,路由层不透传);账户创建无 `/accounts/new` 独立路由(=账户页内对话框)。→ v1 引导只跳转(裸开表单/账户页);预填 = 后续票(extra Map 透传或 query param)。F70-T3 引导卡 route=/accounts 即此查证的落地。
4. **审计 ASCII 门与中文 note 的双通道**(T2):审计日志串全可打印 ASCII(项目门禁),而会话注入需中文人类可读 —— 两者分离:logWrite 只进 English 结构化行(payload=WriteAction.toString,ASCII 过滤),中文紧凑单行「已记:支出 ¥35.00 午饭」只经 appendToolOutcome 进 LLM 上下文与 UI,不进日志串。帽石④⑤分别钉死两通道。
5. **幂等双层**(T2+帽石⑧):bloc 卡态守卫(仅 pending 可确认/仅 failed 可重试)是第一层 —— 重复确认在 executor 前被拒;executor 幂等集(key→entityId,成功才记录,失败不耗键)是第二层兜底(重试/竞态直达 executor 也不重复落库)。

## 真壳手验移交注记(code-plan T4「真壳全流程」的用户验收面)

帽石集成测以真库+真执行器+真 bloc+脚本化 LLM 覆盖「记→改→删→取消」全链九断言;**带真引擎+真模型的端到端手验移交用户**(本地 llama-server + qwen3:latest,引擎/模型装配已由 F66/F67 全链测试覆盖,不在 CI 可复现范围):用户在真壳对助手口述「记一笔午饭 35 块,用现金」→ 确认卡出现并确认 → 交易页可见该笔(金额/分类/账户/余额与手记一致)→ 口述「把刚才那笔改成 40 块」→ diff 卡确认 → 口述「删了」→ destructive 卡确认后消失、余额回滚;中途取消一张卡验证零写。**用户实际使用即验收**(v20 原型已过用户确认门,OD run a1990b4f);手验发现问题走 F71 姊妹票或 fixlist,不阻塞本票合并。

## T4 装具要点(记档)

- **同 loop 实例双向缝**:WriteExecutorImpl 构造注入 AgentLoopService —— 帽石中 bloc/loop/executor 共用同一 AgentLoopServiceImpl 与 AssistantAuditLog(镜像 DI 单例),故⑤的 appendToolOutcome 落进同一会话上下文,由下一次 send 的 LLM 请求消息序列直接验证(`llm.requests.last.messages` 含恰一条「已记:」tool 消息,单行无换行)。
- **requiresApproval 契约在管线级的钉法**:不直调工具,而是解次轮请求里 tool 消息的 `<tool_data>` 定界 JSON(F64 帽石同款剥壳)—— 断言 requiresApproval=true + action 携解析后内部 id 与逐字段值,即「真 LLM 会在下一轮看到的两段执行契约形状」。
- **tool_call args 分片拆段**:add/update/delete 三轮脚本的 args JSON 均拆 2 段 argsDelta,钉流式拼装(SplayTreeMap 按 index 归并)非单发整串。
- **真库直查独立断言**:全部 DB 断言走 `database.transactionDao/accountDao` 直查(getAllTransactions/getAllEntries/getAllAccounts),不 import 工具结果对象、不经 repo 回读 —— 与提案 payload 互证余额联动/分录借贷侧/级联清理(NFR-1)。
- **消息序断言**:确认前断言 bloc 消息流 runtimeType 序 = [UserMsg, AssistantMsg, ToolStatusMsg, WriteApprovalMsg, AssistantMsg](前导文本→工具条 ok→pending 卡→收尾文本),一次钉死 loop 事件序(ToolCallStart/End(true)→WriteProposed)在 bloc 消费面的落位。

## test 门覆盖率实测(2026-10-27,HEAD d029234a,评审 PASS 后)

命令 `flutter test --coverage test/assistant/`(仅 assistant 套件注入,lcov DA 行覆盖汇总 `lib/assistant/**`,35 文件):**404 绿 + 1 自跳过**(F66 engine_smoke 夹具不在场)/ **lib/assistant 总行覆盖 94.2%(2605/2764)** / flutter analyze **466 == 基线零新增** / `git diff main -- yucai/server` **0 字节**(NFR-4 复测)。

F70 写面分文件(全部 ≥80%,无本票热点):

| 文件 | 行覆盖 | 未覆盖行定性 |
| --- | --- | --- |
| data/tools/transaction_add_tool.dart | 94.6%(53/56) | 155-157:direction 对应分类池全空时的引导 ToolError(空库冷启动分支) |
| data/tools/transaction_update_tool.dart | 100%(59/59) | — |
| data/tools/transaction_delete_tool.dart | 100%(20/20) | — |
| data/tools/write_tool_support.dart | 100%(101/101) | — |
| data/write_executor_impl.dart | 97.8%(87/89) | 199/219:update 非 ServerFailure 映射 + delete 失败映射各 1 行(失败面由 mock 组另路覆盖) |
| data/agent_loop_impl.dart | 96.5%(110/114) | 265-276:args JSON FormatException/TypeError/crash 三重兜底 catch;344:Uri host 回退 |
| presentation/widgets/write_approval_card.dart | 99.2%(378/381) | 334-335:failed 终态 update/delete 标题分支(add 已覆盖);481:failed 态取消钮条件分支 |
| presentation/assistant_panel/assistant_panel_bloc.dart | 86.1%(260/302) | 55-202:事件类 equatable props/toString 样板行;368/371 copyWith failureReason 保留;550/552 onError 防御路径(loop 契约保证终态);862 流式合并段 |
| domain/write_action.dart | 84.9%(45/53) | 构造防御 ArgumentError(工具层上游已守卫)+ toString 覆写 |
| domain/write_executor.dart(port) | 40.0%(4/10) | 6 行 = WriteOutcome 三态 toString 覆写;port 本体与接缝全覆盖 |

<80% 判定:全模块仅 3 文件,均**非 F70 写面**——`data/process_launcher.dart` 0%(0/23,F66 引擎域真 OS 进程启杀 Process.start/taskkill,CI 无夹具,engine_smoke 自跳过同因)/ `domain/write_executor.dart` 40%(toString 样板,见上表)/ `domain/model_manager_port.dart` 53.8%(ModelManifest ==/hashCode/toString,F66/F67 域)。**F70 写面零 <80% 热点**,未覆盖行全部为防御分支或 Dart 样板,无功能缺口。

## test 门验收清单(spec 9 需求 / 7 Scenario 逐行,grep 实数)

| 需求 | Scenario | 代验用例(测试文件实名在册) | 判定 |
| --- | --- | --- | --- |
| FR-1 | 口述记账全流程(spec L15) | 帽石 `记一笔全链①②③④⑤⑧`(integration/write_pipeline_integration_test.dart:232:①提案卡解析后 id/摘要 ②确认前真库直查交易/分录/余额全零 ③确认后 DB 逐字段+余额联动 ④logWrite 行 ⑤「已记:」注入下轮 ⑧幂等)+ add_tool `支出:账户/分类名称解析为 id…`/`收入:direction=in…` + executor `支出:recordExpense 落库…`/`收入:recordIncome 方向分流` | ✓ |
| FR-1 | 幂等(spec L20) | 帽石⑧ + executor `同 key 重复触发:AlreadyExecuted 回放,零写/零注入/零重复审计`/`不同 key 同操作 = 两次独立执行` + bloc `幂等负测:确认后再触发同 key 确认 → 状态守卫拒` + card `失败→重试 → RetryWriteRequested:同幂等键复用` | ✓ |
| FR-2 | 改最近一笔(spec L28) | 帽石 `改一笔全链⑥`(before ¥30.00/after ¥40.00 diff 卡) + update_tool `无过滤 = 最近一笔:时间倒序首条且跳过转账`/`keyword 唯一命中(京东购物)`/`before = 定位笔现状;after = patch 覆盖后` + executor `改金额+描述:entries 全重建,note 逐侧保留`/`改日期:patch.date 覆盖…full-replace 语义` | ✓ |
| FR-3 | 删除确认(spec L35) | 帽石 `删一笔全链⑦`(destructive 卡→确认→分录级联+余额回滚) + delete_tool `keyword 唯一命中 → action{transactionId} + destructive preview` + executor `同管道删除 + note 已删 + 审计行 + 余额回滚` + card `红警示条「删除后不可恢复」`/`按钮主位反转` + 帽石 `取消⑨`(取消保留) | ✓ |
| FR-4 | 未知账户引导(spec L42) | add_tool `account 未知 → ToolError(查无引导,FR-4;携 V4 结构标记+请求金额)`/`category 未知 → ToolError 携 V4 引导标记` + loop `unknown-account ToolError(结构标记)→ ToolCallEnd 后发 ToolGuidance` + bloc `unknown-account 引导映射:ToolGuidance → GuidanceMsg(text+route)` + card `新建账户 → GoRouter 跳 /accounts(路由意图断言,ADR-5)` + overlay `引导卡(V4)与 LLM 文本澄清、工具 pill 并存互不干扰`(跳转即验收面:预填降级由 OQ-1/ADR-5 承接,见领域发现③,不算缺口) | ✓(跳转面)/注 |
| FR-5 | 提示词不可绕过(spec L49) | 三工具 `mock repo verifyNever:…零调用` ×3 + `真实 repo:成功提案后…不变` ×3 + loop `action JSON 畸形 → 静默降级零 WriteProposed(零卡零写)` + bloc `绕过负测:提案到达只发 pending 卡,loop 流事件本身零 executor 调用` + 帽石②⑨ | ✓ |
| FR-5 | 新对话作废(spec L54) | bloc `作废负测:新对话后旧 key 确认 → 查无此卡守卫拒,零执行` + loop `resetConversation 一并清空注入结果(新对话作废口径,FR-5)` | ✓ |
| NFR-1 | 写路径同源(无 Scenario,SHALL) | 帽石③⑥⑦ 余额直查断言 + 分录借贷侧断言;T2 真库组(recordExpense→recordIncome→update 重建→delete 回滚全走 TransactionRepositoryImpl) | ✓ |
| NFR-2 | 参数面约束(无 Scenario,SHALL) | `参数面 ≤8 项(NFR-2)`(add)+ `参数面 ≤8 项(NFR-2),不暴露内部 id 参数`(update/delete) | ✓ |
| NFR-3 | 审计衔接(无 Scenario,SHALL) | audit_log `ok line format: tool/status/entity/payload`/`error line: empty entity allowed`/`ASCII gate: CJK payloadSummary stripped` + executor `全部审计行可打印 ASCII;中文 note 只进 appendToolOutcome` + 帽石④ | ✓ |
| NFR-4 | server 零改动(无 Scenario,SHALL) | 本门实测 `git diff main -- yucai/server` = 0 字节(merge-base 98ce8339) | ✓ |

真壳手验(带真引擎+真模型的端到端口述「记→改→删→取消」)= 移交用户,注记见上文「真壳手验移交注记」;用户实际使用即验收,手验问题走 F71/fixlist 不阻塞合并。**7/7 Scenario + 4/4 NFR 全代验通过,零真缺口,test 门 PASS。**
