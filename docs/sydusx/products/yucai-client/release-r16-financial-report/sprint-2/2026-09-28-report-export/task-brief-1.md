# Task Brief T1 — export 域+字体资产(F45 R16 sprint-2)

**工作目录**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f45`(分支 feature/r16-f45;`yucai/client/`)。**流程**:先加载 sydusx-tdd(ambiguous 则直读 C:/Users/BuHiYo-001/.agents/skills/sydusx-tdd/SKILL.md)。前置契约=lib/report/domain/report_document.dart(F43/F44,含 mda)。

## 任务

1. **资产与依赖(首步)**:
   - `assets/fonts/NotoSansSC-Regular.ttf`:**static 实例 ttf(非 variable font)**,来源 google/fonts(Noto Sans SC 静态版,~10MB;用 curl 下载后**冒烟校验**:文件头非 variable fvar 表+简单解析非空)。pubspec assets 段登记。
   - pubspec 依赖 `pdf`(选当前稳定 ^3.x,版本+理由注释照 pubspec 既有惯例;纯 Dart 零原生)。
2. **`lib/report/export/` 四文件**(design ADR-2/3):
   - `report_export_layout.dart` — 布局树 VO(Section{title,blocks}+Block=text/kv/table/bars/note,bars 带 severity 语义)+`build(ReportDocument)`(唯一遍历点:总览[hero 数字+摘要+附注]→资产负债→收支→现金流→预算→投资→诊断,与页面 `_chapters` 同序;文件名安全化助手)。
   - `pdf_report_renderer.dart` — 布局树→Uint8List:A4 MultiPage/页脚「御财财务报告-{label} · 第 N 页」/Noto 单例字体/章节 PageBreak(总览外)/表格与条形同构(severity 色深)。
   - `markdown_report_renderer.dart` — 布局树→String:#/## 标题+表格+bars 列表+附注引用块+severity 符号前缀(🔴/⚠/ℹ)。
   - `report_export_service.dart` — 编排:doc+format(pdf|md)→bytes/string+默认文件名;IO 全走注入缝(FileSavePickerFn/LaunchUrlFn typedef),零 FilePicker/url_launcher 直接依赖。
3. **测试**(`test/report/export/`):布局树全章节手算 oracle(数字与 VO 逐项/顺序/severity);Markdown 字符串断言(标题/表格/符号);PDF smoke(bytes 非空+页数≥章节数+pdf 包回读含字体与文本片段——pdf 包可加载生成的 bytes 校验);字体加载冒烟(渲染含「御财务报告储蓄率资产负债闲置订阅」无异常)。

## 硬约束

export 域仅 import report domain+pdf 包+dart 标准库(渲染器)/纯 Dart;零 flutter/material(service 可被 presentation 调);中文注释;cents。

## 完成门

`flutter test test/report/export` 全绿+全量绿+analyze 基线零新增(基线以 stash 实测)。commit `feat(report): T1 导出域——布局树+PDF/Markdown 双渲染器+Noto 资产(TDD)`。回报:文件/测试数/commit/资产来源与大小/遗留。
