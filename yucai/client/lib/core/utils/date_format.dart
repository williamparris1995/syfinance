/// date-only 格式化工具(无 intl 依赖,跟随 accounts_page 风格)。

/// 格式化日期为 YYYY-MM-DD(null → '--')。
String formatDate(DateTime? d) {
  if (d == null) return '--';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
