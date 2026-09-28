# Spec — F46 LLM 分析师(R16 sprint-2)

> analysis 2026-09-28。grill 决策①用户确认(手动触发+旁挂呈现+首启用免责);调查实证:设置家法(ThemeSettings 镜像+secure storage)/TraySettings 卡范式/F22 免责对话框先例/首个出站 HTTP(dart:io 零依赖)/LLM 输出纯文本(prompt 约束,零 markdown 渲染依赖)。

## 需求(FR)

### Requirement: FR-1 设置卡与首次启用免责
设置页 SHALL 新增「AI 分析师」卡(照 TraySettings 卡范式):启用开关/端点(智谱·OpenAI·DeepSeek·自定义 base_url 四选)/API Key(obscure 输入,存 flutter_secure_storage)/模型名(预设默认可改)/城市规模档位(一线/新一线/二三线,LLM 语境用)/订阅名明文开关(默认关)。**首次开启启用开关时弹完整免责对话框**(照 F22 范式:脱敏范围+外发目的地+「AI 输出仅供参考,非投资建议」),确认才生效,取消则开关回弹。
- [ ] FR-1
  #### Scenario:
  - GIVEN 未启用 WHEN 开启开关 THEN 免责对话框弹出;点取消 THEN 开关回弹未启用,无持久化
  - GIVEN 已读过免责 WHEN 再次改配置 THEN 不再弹(免责确认持久化)

### Requirement: FR-2 脱敏数据包
系统 SHALL 从 ReportDocument+MdaSection 构造脱敏聚合包(结构化 JSON):期标签/净资产与变动/收入支出构成(科目名+金额+率)/现金流三类/预算执行/投资绩效/诊断 Findings(conclusion+advice)/城市档位;**排除**:账户名、交易描述、模板名(订阅名明文开关开启时以「订阅:名称=月度等价」级别加入)、任何身份信息。构造为纯函数可测。
- [ ] FR-2
  #### Scenario:
  - GIVEN 任意报告 WHEN 构造 payload THEN JSON 序列化文本不含账户名/交易描述/身份字段(负面清单断言),订阅名按开关出现/缺席

### Requirement: FR-3 LLM 调用管线
`LlmMdaNarrator implements MdaNarrator` SHALL 以 dart:io HttpClient 调 OpenAI 兼容 `POST {base_url}/chat/completions`(Bearer Key):系统提示钉死「你是个人财务分析师;仅基于给定结构化数据解读,**不得计算或编造任何数字**(引用数字只能来自数据);中文;分节:总体评价/主要风险/可执行建议;纯文本,不用 Markdown 标记」;用户消息=脱敏包 JSON;超时(30s)与 HTTP/解析错误降级为空串或错误态;**数字事实由本地规则/快照供给**。
- [ ] FR-3
  #### Scenario:
  - GIVEN fake HTTP 缝返回合法响应 THEN narrate 返回正文文本(解析 content 字段)
  - GIVEN fake 缝超时/非 200/缺 content THEN 返回空串或抛可捕获错误(调用方走错误态),绝不 crash

### Requirement: FR-4 报告页触发与呈现
报告页 SHALL 提供「AI 解读」按钮(**仅 LlmSettings 启用且配置完整时可见**, Loaded 态):点击即调用(旁挂加载态 spinner)→诊断章节尾部「分析师解读」小节:纯文本叙述+「由 {模型名} 生成」标签+免责脚注(「AI 输出仅供参考,非投资建议」)+「重新解读」;**旁挂页面 state,不入 ReportDocument**;重新生成报告(期变更/重新生成)清空解读;失败→小节内错误态+重试。
- [ ] FR-4
  #### Scenario:
  - GIVEN 启用+Loaded WHEN 点「AI 解读」THEN spinner→小节呈现文本+模型标签+免责脚注
  - GIVEN 已有解读 WHEN 重新生成报告 THEN 解读清空(快照不被污染),需重新点
  - GIVEN 调用失败 THEN 小节显示错误+「重试」,规则诊断章节不受影响

### Requirement: FR-5 降级链与隐私红线
未启用/未配置→入口隐藏;断网/失败→错误态可重试;**API Key 仅存 secure storage,任何日志/错误信息不得含 Key 或完整 payload**;规则诊断恒本地零网络。
- [ ] FR-5
  #### Scenario:
  - GIVEN Key 已配置 THEN 仓储读写仅经 secure storage;错误消息只含状态码/端点域名,无 Key

### Requirement: NFR-1 零新依赖
不新增任何 package(HTTP=dart:io,prompt/payload=纯 Dart,设置=既有 secure storage)。
- [ ] NFR-1
### Requirement: NFR-2 UI 不阻塞
LLM 调用期间 UI 可用(异步,报告滚动/导出不受影响);超时上限 30s。
- [ ] NFR-2
### Requirement: NFR-3 门
flutter 全绿+analyze 基线零新增+client-e2e(设置卡可达性;真实 LLM 调用不进 e2e,全部走注入缝)+proto/server 零 diff。
- [ ] NFR-3

## Scope boundary(排除项:owner+已权衡理由)

| 排除 | owner/拍板 | 理由(成本已权衡) |
|---|---|---|
| 自动随报告生成解读 | 用户 2026-09-28(按推荐) | 静默外发违隐私红线;LLM 秒级延迟拖垮本地 2s 出报告;手动=显式确认 |
| Markdown 渲染 LLM 输出 | 调查+YAGNI | 零先例,新依赖与家法相悖;prompt 约束纯文本 |
| 流式输出(SSE) | YAGNI | 一次性响应简单;v2 需要时再加 |
| 多套 prompt 模板/角色切换 | YAGNI | 单一系统提示钉死口径 |
| 外部城市物价数据 API | F44 决议延续 | LLM 世界知识+档位,零依赖 |
| Key 云同步/多 profile | YAGNI | 单设备单配置 |

## Feasibility(裁决)

- **Technical: 可行** — 全先例映射(设置/卡/对话框/注入缝);首个出站 HTTP 零冲突;OpenAI 兼容协议三家一致。
- **Economic: 可行** — 零新依赖;工作量中等(设置卡+脱敏构造+narrator+小节 UI)。
- **Operational: 可行** — 默认关闭=零行为变化;回滚=移除卡与按钮;narrator 降级空串保底。

## Grill record(2026-09-28)

1. **手动触发+旁挂呈现+首启用免责** — 挑战:手动触发像外挂插件,自动随报告更「分析师一体化」;防御:自动=静默外发违 spec 隐私红线+2-10s LLM 延迟拖垮本地秒开体验;旁挂保 FR-2 快照纯本地三态一致;用户「按推荐」确认。设置卡视觉/免责文案细节入 design 原型确认。
