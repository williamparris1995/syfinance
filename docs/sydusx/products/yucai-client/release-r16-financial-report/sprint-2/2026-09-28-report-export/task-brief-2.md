# Task Brief T2 — 导出入口接线(F45 R16 sprint-2)

**工作目录**:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r16-f45`(分支 feature/r16-f45;`yucai/client/`)。**流程**:先加载 sydusx-tdd。前置:T1(8a850efb)export 域+注入缝已落。

## 任务

1. **生产缝实现**(`lib/report/export/export_io.dart` 或就近):`FileSavePickerFn`→`FilePicker.saveFile`(dialogTitle「导出财务报告」,allowedExtensions+fileName 按 T1 defaultFileName+格式后缀——注意 FilePicker.saveFile 桌面单后缀形态,若格式切换需两步[先选格式再对话框]则采用:按钮弹出小菜单[PDF/Markdown]→再 saveFile);`WriteBytesFn`→File.writeAsBytes(桌面防御性自写照 settings 先例);`LaunchUrlFn`→url_launcher externalApplication;`FontSourceFn`→rootBundle.load(assets 字体)。
2. **报告页入口**:`financial_report_page.dart` page-head 加「导出」按钮(**仅 Loaded 态可用**;导出中禁用+spinner;错误 toast 兜底);导出成功 toast+「打开」动作(调 service.openExported,失败 toast)。不新 bloc(page handler,照 settings _showExportArchive 先例)。
3. **widget 测试**:按钮态(非 Loaded 隐藏/禁用)、格式菜单两格式、缝替换(fake save 返回路径→断言写入 bytes 非空+toast+打开调用)、取消零副作用、错误兜底。

## 完成门

`flutter test test/report` 全绿+全量绿+analyze 基线零新增。commit `feat(report): T2 导出入口——格式菜单+保存对话框+打开反馈(注入缝接线)`。回报:文件/测试数/commit/遗留。
