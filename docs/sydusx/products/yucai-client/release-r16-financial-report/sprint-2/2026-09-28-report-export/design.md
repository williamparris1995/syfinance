# Design: F45 报告导出

prototype: none(本票唯一 UI=报告页 page-head「导出」按钮+toast,复用 v8 既有 page-head 按钮形态与 AppToast 惯例,零新布局面——照 F41 prototype:none 先例;管线为主)

## Context

- 上游:[spec.md](spec.md)(FR-1..5/NFR-1..3);F43/F44 ReportDocument(含 mda)为唯一输入契约。
- 调查事实:报告页零 fl_chart(全 Container/表格)→pdf 同构;保存先例 settings_page.dart:574(FilePicker.saveFile+自写+toast);打开先例 debt_detail_page.dart:70(launchUrl+exists+兜底)+注入缝范式 feedback_launcher;printing.layoutHtml Windows 缺位(HTML 否决依据)。
- 约束:新依赖仅 pdf(纯 Dart);零 proto/server。

## Goals / Non-Goals

**Goals**:PDF(pdf 直绘)+Markdown 双格式导出;同源保证;入口/保存/打开闭环。
**Non-Goals**:HTML/打印对话框/share_plus/子集字体/导出历史(spec Scope boundary)。

## Decisions(ADRs)

- **ADR-1 PDF 管线=pdf 包直绘+bundle 全量 Noto Sans SC**。alternatives 否决:HTML+printing(桌面 layoutHtml 缺位)/字体子集(动态字 tofu)/运行时 msyh.ttc(许可+ttc 解析坑)。**字体只带 Regular 一支 static ttf(~10MB)**:粗细层次用字号+颜色区分(财报素净风格),避免 Bold 再加 10MB;**必须 static 实例 ttf(非 variable font)**——pdf 包 ttf 解析对 variable 支持不稳,资产获取注明来源(google/fonts 静态版)。
- **ADR-2 一份布局树,两个后端**:`ReportExportLayout`(pdf-agnostic 纯 Dart 布局树:Section{title,blocks},Block=text|kv|table|bars|note)由 ReportDocument 构建一次;PDF 渲染器(布局树→pdf bytes)与 Markdown 渲染器(布局树→string)共吃——**同源保证的结构化落地**(FR-5:布局树构建是唯一允许"遍历 VO"的地方,两后端零数字计算)。
- **ADR-3 导出器域位置=`lib/report/export/`**:布局树+两渲染器+编排 service 纯 Dart(渲染器仅 import pdf 包+report domain);presentation 只加按钮与 handler。**无新 bloc**(导出是瞬时动作非状态机):page handler+按钮禁用 spinner,照 settings `_showExportArchive` 先例。
- **ADR-4 文件 IO 与打开走注入缝**:`ReportExportService.saveBytes/writeString` 与 `launchUrlFn`(照 feedback_launcher LaunchUrlFn)可测;FilePicker.saveFile 在 service 外包一层 FileSavePickerFn 缝(测试零 FilePicker 依赖)。
- **ADR-5 测试策略=布局树内容断言+bytes 层 smoke**:布局树单测覆盖全部章节/数字(手算 oracle);PDF bytes 层断言非空+页数+字体嵌入(smoke,不做 byte-golden——pdf 元数据含时间戳不稳定);Markdown 直接字符串断言(可 golden);NFR-2 计时。

## HLD

```
lib/report/export/
  report_export_layout.dart      # 布局树 VO+build(ReportDocument)→Layout
  pdf_report_renderer.dart       # Layout→Uint8List(pdf 包;A4 分页/页脚期+页码/Noto 字体)
  markdown_report_renderer.dart  # Layout→String(标题层级/表格/引用块)
  report_export_service.dart     # 编排:doc+format→bytes/string+默认文件名;IO 缝注入
lib/report/presentation/pages/financial_report_page.dart  # 「导出」按钮(Loaded 态)+handler+toast+打开
yucai/client/pubspec.yaml        # +pdf ^3.x(版本钉死注释)+assets/fonts/
yucai/client/assets/fonts/NotoSansSC-Regular.ttf          # static 实例全量(~10MB)
```

依赖方向:export→report domain(仅);presentation→export+domain;pdf 包仅在 export 内。

## LLD(契约)

- `ReportExportLayout.build(doc)` 遍历顺序:总览(hero 数字+摘要卡+附注)→资产负债→收支→现金流→预算→投资→诊断(分组)——与页面 `_chapters` 同序;Block.bars{label,amountCents,sharePct,maxCents?} 支持预算三档色(布局树带 severity 语义,PDF 用色深/Markdown 用符号 ✅⚠ 表示)。
- PDF:`pw.Document`+`pw.MultiPage`(A4,页脚 `御财财务报告-{label} · 第 N 页`);Noto 字体 `pw.Font.ttf(ByteData)` 单例加载;章节 `pw.Header`+分页 `pw.PageBreak`(新章节起新页,总览除外)。
- 文件名安全化:period.label→去除路径非法字符(如「2026年08月」)。
- Markdown:`# 御财财务报告 {label}`+`## 章节标题`+表格 `| | |`+bars→`- label amount (pct%)`+附注 `> 引用块`+诊断 severity→`⚠/ℹ/🔴` 前缀。

## Risks / Trade-offs

- [字体资产获取] static ttf 需正确来源(google/fonts 静态版非 variable)——execute 首步校验字形覆盖(渲染冒烟文本含「御财务报告储蓄率资产负债闲置订阅」)。
- [pdf 元数据时间戳] bytes 不做 golden(ADR-5)。
- [10MB 资产入 git] 一次性,与 tray_icon 同惯例;发版安装包 +~10MB(用户知情拍板)。
- [大账本 PDF] 渲染 O(章节) 与账本规模无关(吃快照),NFR-2 计时钉。

## Migration Plan

纯新增+pubspec/资产;回滚=移除按钮+export 目录+依赖。

## Open Questions

(无)
