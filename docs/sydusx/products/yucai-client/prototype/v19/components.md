# v19 Components — F65 AI 助手原型组件登记

> 续 v18(表单 UX)之后新增;既有套件组件(sidebar/topbar/card/btn-primary/dock 等)沿用不重登。

- **chat-floating-panel** — 聊天浮层(V1/V3 形态;宽 ~400px 右下锚定)。状态:头部(御财助手·本机运行)/消息流/输入行。token 对齐:卡片类+浮层阴影令牌。位置:assistant-entry-variants.html V1/V3、assistant-chat-states.html 六状态卡。
- **tool-status-bar** — 工具调用状态条(「正在查询净资产… · 已用 0.4s」)。状态:运行中/完成。位置:两页。
- **clarify-chips** — 澄清反问选项 chips(可点样式两枚)。位置:chat-states 状态 3。
- **model-management-card** — 端侧模型管理卡(fork settings 卡风格)。状态:已就绪(启用开关/版本/占用/引擎运行中)/下载中(进度条+暂停续传)。位置:chat-states 下半。
- **assistant-fab** — 助手 FAB。两形态:独立(错位于记一笔簇旁,V1-V3)/悬浮簇次级成员「问助手」(V4)。位置:entry-variants。
