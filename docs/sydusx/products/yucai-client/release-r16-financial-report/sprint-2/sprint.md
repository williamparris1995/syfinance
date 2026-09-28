# Sprint 2 — R16 财务报告:导出+AI 分析师(F45+F46)

> /sydusx-portfolio 2026-09-28 立项。组成承接:release 级拍板「页面+导出」(F45)+ F44 立项时用户构想评估决议「LLM 分析师立 F46,与 F45 同批」(BYOK/脱敏/免责方案入 F44 spec Scope boundary 存档)。

## Sprint Goal

用户可将生成的财务报告导出为可存档的规范文档(F45,与页面同源 ReportDocument 不二次计算),并可选接入 LLM 分析师(F46:BYOK 自带 Key、OpenAI 兼容端点、脱敏聚合包、叙述综合+多维建议+免责);两票均消费 F43/F44 的 ReportDocument+Findings 契约,零 proto/server 改动。

## Feature roster

- [x] **feature F45** report-export — 报告导出(PDF[pdf 直绘+Noto 全量字体]+Markdown 双格式;格式菜单+保存对话框+打开反馈) ✅ done(2026-09-28,ff 合并:grill 一决策[PDF 直绘+Noto 全量~10MB+Markdown,HTML 否决因 printing 桌面缺位]→design[prototype:none,一份布局树两后端同源]→execute T1-T3[两回合两轴评审+修复:正则 unicode 真 bug RED 修复+PDF ToUnicode 文本锚点断言+OFL 许可+exists 前置]→feature 门 PASS[零 blocker];门:2304 测全绿/e2e 15 套件/analyze 446/PDF 233ms<2s/proto 零 diff;新依赖仅 pdf 纯 Dart+xml 被动 major;backlog:展示聚合 VO 收口/格式化拷贝抽 core/FR-5 import 面单测)
- [x] **feature F46** llm-analyst — LLM 分析师 ✅ done(2026-09-28,ff 合并:grill[手动触发+旁挂+首启用免责]→design[ADR-6+prototype v9 两页 OD run c1b24569]→execute T1-T3[两回合评审+修复:H1/H2 空名隐私门禁/整体 30s deadline/输入失焦提交/**智谱端点缺 /v4 feature 门 HIGH 修复**]→feature 门 REJECT→PASS;门:2393 测全绿/e2e 15 套件/analyze 446/零新依赖;隐私:负面清单红线断言+Key 仅 secure storage+错误消息零 Key 零 payload)

## status: done(F45+F46 双票收官=sprint-2 功能 done 2026-09-28)
