# Task Brief T2 — UI 接线(F46 R16 sprint-2)

**工作目录**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f46`(分支 feature/r16-f46;`yucai/client/`)。**流程**:先加载 sydusx-tdd。前置:T1(8f5f077a)LlmSettings/LlmMdaNarrator(经 MdaNarrator port)/NarrationFailure 已落。

## UI 事实源(必读)

**prototype v9**(docs/sydusx/products/yucai-client/prototype/v9/ui/):financial-report.html(AI 解读按钮+解读小节三态)与 settings.html(AI 分析师卡六行+免责对话框)。设计文案以 v9 逐字为准。

## 任务

1. **设置页卡**(`lib/settings/presentation/settings_page.dart`+可能新 widget 文件):「AI 分析师」卡照 TraySettings 卡范式——启用 Switch(未启用时配置行半透明禁用)/服务商 pills 智谱·OpenAI·DeepSeek·自定义(provider 切换预填 base_url+默认模型名 glm-4.6/gpt-4o-mini/deepseek-chat/空)/API Key obscured 输入+「仅存本机安全存储」描述/模型名输入/城市档位 segmented 一线·新一线·二三线/订阅名明文 Switch;全部走 LlmSettings 写入。
2. **免责对话框**(`lib/settings/widgets/llm_disclaimer_dialog.dart`,照 first_close_dialog 范式):首次开启启用开关时弹,四行文案照 v9 逐字;[取消]回弹开关不持久化,[我已知悉并启用]写 disclaimerAck+enabled。
3. **报告页**(`financial_report_page.dart`+`lib/report/presentation/widgets/analyst_note.dart`):page-head「AI 解读」次按钮(**仅 ValueListenableBuilder<LlmConfig>.ready 且 Loaded 态可见**);点击调 getIt<MdaNarrator>().narrate(doc, findings)——页面旁挂 `_AnalystState{idle/loading/done(text,model)/error(msg)}`;AnalystNote 小节挂诊断章节尾(三态+「由 {model} 生成」chip+免责脚注恒显+重新解读;期变更/重新生成→idle 清空);NarrationFailure→error 态+重试;调用期间 UI 不阻塞。
4. **测试**:设置卡(六行渲染/禁用态/取消回弹/ack 后不再弹/provider 预填);对话框文案逐字;报告页(按钮可见性两态/旁挂三态/清空语义/错误重试)——narrate 经注入缝或 getIt 注册替换(getIt.resetScope 或构造注入,择简)。

## 硬约束

零新依赖;presentation 不直接 import llm_http;Key 不入测试快照/日志;零裸色(v9 语义色映射);中文文案逐字 v9。

## 完成门

`flutter test test/report test/core/llm`+设置相关测试全绿+全量+analyze 基线零新增。commit `feat(llm): T2 设置卡+免责对话框+AI 解读按钮与解读小节(v9)`。回报:文件/测试数/commit/遗留。
