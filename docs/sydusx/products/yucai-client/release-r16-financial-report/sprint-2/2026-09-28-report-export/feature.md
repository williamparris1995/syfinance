---
title: F45 report-export
keywords: [导出, 报告导出, PDF, Markdown, 存档, report-export]
---

# Feature — F45 报告导出(R16 sprint-2)

> 2026-09-28 立项。release 级拍板「页面+导出」;上游契约=F43/F44 ReportDocument(含 mda 章节)。

## Description

现状:财务报告仅应用内阅读(七章节+诊断摘要)。目标:将生成的报告导出为**可存档的规范文档**——格式与渲染管线(PDF 包直绘 vs HTML 模板+系统打印 vs Markdown)analysis grill 定;与页面同源(ReportDocument→导出渲染,数字零二次计算);报告页「导出」入口+桌面保存对话框+导出后打开。

## Stories(粗,analysis 细化)

- [ ] S1: 导出渲染器(格式/管线 grill 定;ReportDocument→文档)
- [ ] S2: 导出入口+保存对话框+打开
- [ ] S3: 测试与门

## Keywords

`导出` `报告导出` `PDF` `Markdown` `存档` `report-export`
