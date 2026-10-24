# Task Brief T4 — 设置卡「AI 助手」+ 接线

- worktree 同 T1。TDD;不碰 server/F46/其他模块业务;settings 页既有结构**只加一卡**;与 T1/T2 并行(不碰 tools/、不碰 assistant/presentation——bloc 属 T2)。
- 必读:design.md(ADR-4)+spec FR-3 两场景+prototype **v19/ui/assistant-chat-states.html**(卡的视觉事实源:启用开关/模型行/引擎行/说明行/下载中对照卡);`lib/settings/` 既有设置页结构与卡组件先例(grep 既有设置卡 widget 形态);F46 报告卡的表单范式。
- 任务:
  1. **`lib/assistant/presentation/widgets/model_management_card.dart`**(或照 settings 页惯例选位):「AI 助手」独立卡——
     - 启用开关(AssistantSettings.setConfig{enabled},中文行内确认无需弹窗);
     - 模型行:绑 `ModelManagerPort.state`(ValueListenable):notDownloaded→「下载模型(约 2.4GB)」按钮+说明「数据全程不出本机」;downloading→进度条(received/total+百分比+速度)+暂停按钮;paused→「继续下载」+已收;error(network/corrupt)→状态+重试(corrupt 重试=从零,文案区分);ready→「Qwen3-4B · 已就绪 · 占用 X.XGB」+删除按钮(删除需确认——destructive,对话框或行内两步);
     - 引擎行:绑 `EngineManager.state`(stopped/starting 运行中转圈小图标/ready「运行中」/error 态);
     - 全部文案照 v19 措辞基调;design-v2 令牌零裸色;测试用 fake 状态各态渲染断言。
  2. **settings 页挂卡**:既有设置页结构对应分组加一行入口或直嵌卡(照 v19 是设置页内独立卡;看页面实现选阻力小且一致的形态,汇报说明)。
  3. **DI**:2g/1m 段补 presenter 侧注册(widget 一般不自注册——按仓内 settings 组件装配惯例;若无惯例则卡构造全依赖注入由页面 getIt 取)。
- 测试:widget 测(fake 两状态流转:各 ModelState 态的渲染与按钮回调[download/pause/resume/retry/delete 真调 fake port 且确认门]/启用开关落盘/引擎各态);照 v19 状态面全覆盖(空态=notDownloaded 即引导)。
- 验证门:`flutter test test/assistant/` 绿(并行 WIP 抖动排除复跑注明)/analyze 零新增/server diff 空。commit `feat(assistant): F65-T4 端侧模型管理卡+设置页挂载`。汇报:文件清单+测试数+挂卡形态+commit hash。
