# Sprint 2 — R16 财务报告:导出+AI 分析师(F45+F46)

> /sydusx-portfolio 2026-09-28 立项。组成承接:release 级拍板「页面+导出」(F45)+ F44 立项时用户构想评估决议「LLM 分析师立 F46,与 F45 同批」(BYOK/脱敏/免责方案入 F44 spec Scope boundary 存档)。

## Sprint Goal

用户可将生成的财务报告导出为可存档的规范文档(F45,与页面同源 ReportDocument 不二次计算),并可选接入 LLM 分析师(F46:BYOK 自带 Key、OpenAI 兼容端点、脱敏聚合包、叙述综合+多维建议+免责);两票均消费 F43/F44 的 ReportDocument+Findings 契约,零 proto/server 改动。

## Feature roster

- [ ] **feature F45** report-export — 报告导出(格式与渲染管线 spec 定:PDF/Markdown/HTML;报告页导出入口+保存/打开)
- [ ] **feature F46** llm-analyst — LLM 分析师(BYOK 设置+脱敏数据包+prompt 管线+免责声明+城市档位语境;消费 F44 narrative port;规则版恒本地不受影响)

## status: pending
