# P0-2 Report 日期切换 · plan

> REQUIRED SUB-SKILL: subagent-driven-development。

**Goal**: report_page 加 `_selectedDate` + 日期 picker（回看历史月/年）。

## Task 1: report_page 日期选择

**Files**: [report_page.dart](../../yucai/client/lib/report/presentation/pages/report_page.dart) + test

- [ ] Step 1: `_selectedDate` field（默认 `DateTime.now()`）;`_load()` / `_loadMonthlyComparison()` 用 `_selectedDate` 替 `now`
- [ ] Step 2: `_ReportTopBar` 加日期选择按钮。month scope → `showDatePicker`（取年月,日忽略 → `'YYYY-MM'`）;year scope → year picker（选年）。按钮显示当前选中 `'2026 年 7 月'` / `'2026 年'`
- [ ] Step 3: 选日期 → `setState(() { _selectedDate = picked; _future = _load(); _monthlyComparison = _loadMonthlyComparison(); })`
- [ ] Step 4: test（默认 now 显示本月 / 选历史月 → summary 用 selectedDate 年月 / scope 切换重 load）
- [ ] Step 5: `flutter analyze`（22 基线）+ `flutter test`（不引入新 fail）+ `flutter build windows --debug`
- [ ] Step 6: commit `feat(report): historical date picker — P0-2`
