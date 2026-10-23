# Prototype v19 — F65 应用内 AI 助手(入口变体 + 聊天状态 + 端侧模型管理卡)

> tier: high-fi(design)· path: OD 管线(项目 `yucai-assistant-f65-d452` run `438d3337`,2026-10-23;**用户确认门待过——执行门:拍板后方可进 execute**)。
> 底版:design-output-v2/ab 套件(dashboard.html / settings.html fork)。

## 内容(F65 的 UI 事实源候选)

- **ui/assistant-entry-variants.html(入口形态四变体对比)**:V1 独立助手 FAB+400px 聊天浮层(工具状态条+打字指示,基线推荐标注在权衡行)/V2 FAB 跳转 /assistant 全页(双面板+跳转示意)/V3 并存(FAB 浮层+侧栏「助手」项)/V4 助手并入 R19 悬浮簇为次级成员(簇展开态);每段=标题+缩微仪表盘+权衡行;页内强制桌面布局。
- **ui/assistant-chat-states.html(六状态卡+模型管理卡)**:空态(欢迎+示例 chips)/流式中(光标+工具状态条)/澄清反问(双选项 chips)/超界说明(替代路径)/错误重试/模型下载中(进度+断点续传);下方 fork settings 骨架「AI 助手」卡(启用/Qwen3-4B 已就绪/本机引擎运行中/数据不出本机)+「下载中」对照卡;零端点零 Key 零云字样。

自检(run agent+控制器独立复核):硬编码色 0(色彩 100% var(--*) 令牌);金额千分位两位;亮暗切换+prefers-reduced-motion 守卫;标签闭合零缺口。

## Constraints(people / data / finance / process)

- **people**:单用户桌面键鼠,中文;聊天输入可聚焦;变体段可滚动。
- **data**:示例数据全合成,泛称(广发信用卡类),零真实 PII。
- **finance**:助手 v1 只读;回答金额千分位两位;澄清优先/禁编造体现在状态卡文案。
- **process**:四变体供用户拍板(呈现无视觉偏置);纯内嵌端侧(零云选项)为既定架构决策。

## Components(本版新增,登记于 components.md)

chat-floating-panel(聊天浮层)/tool-status-bar(工具状态条)/clarify-chips(澄清选项)/model-management-card(端侧模型管理卡)/assistant-fab(助手 FAB,两形态:独立/簇成员)。

## CURRENT

v19(F65 AI 助手原型,2026-10-23 生成;**用户拍板门待过**;v18 为 R21 表单 UX 存档)。
