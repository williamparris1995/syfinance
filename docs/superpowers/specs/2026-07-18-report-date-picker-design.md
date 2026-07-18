# P0-2 Report 历史日期切换 · spec

- **日期**: 2026-07-18
- **范围**: report_page 加日期选择（用户选 year+month,非写死 `DateTime.now()`）。client-only。

## 背景
[report_page.dart](../../yucai/client/lib/report/presentation/pages/report_page.dart) `_load()` 写死 `DateTime.now()`（L50）→ 只能看本月/本年。加 `_selectedDate` + picker 可回看历史月/年。

## 设计
- `_selectedDate`（DateTime,默认 `DateTime.now()`）
- `_load()` / `_loadMonthlyComparison()` 用 `_selectedDate`（非 `now`）
- `_ReportTopBar` 加日期选择按钮：month scope → month picker（选年月）;year scope → year picker（选年）
- 选日期 → `setState(_selectedDate)` + reload `_load` + `_loadMonthlyComparison`

## 范围
client-only（report_page.dart）。零 server/proto/schema。
