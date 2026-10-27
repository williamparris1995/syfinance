/// 银行还款计划表粘贴解析(v15,2026-10-27「抄一次银行计划」模式)。
///
/// 背景:参数推算的期表无法复现银行口径(利率券/贴息/按日计息/舍入,
/// 2026-10 平安优惠与融e借贴息实证)。治本 = 把银行 App 的还款计划表
/// 每期「本金/利息/优惠」抄进期表,之后自动并入分毫不差。
///
/// 解析口径(行内以空白/制表符/逗号分隔):
///   - 首个可解析为日期的 token 之前的内容视为表头/序号,忽略;
///   - 日期:yyyy-M-d / yyyy/M/d / yyyy.M.d;
///   - 数字列依次为:本金 利息 [优惠](元,支持千分位逗号会被分隔符
///     吞掉,不支持千分位;小数两位内);
///   - 无日期的行(纯表头/合计行)整行忽略。
/// 解析结果按日期升序;同日多行取最后一行(银行表分页重复场景)。
library;

class BankPlanRow {
  const BankPlanRow({
    required this.date,
    required this.principalCents,
    required this.interestCents,
    this.discountCents = 0,
  });

  final DateTime date;
  final int principalCents;
  final int interestCents;
  final int discountCents;

  int get totalCents => principalCents + interestCents;
}

/// 解析粘贴文本;无法解析出任何行的日期 → 抛 [FormatException]。
List<BankPlanRow> parseBankPlan(String text) {
  final rows = <String, BankPlanRow>{};
  for (final rawLine in text.split(RegExp(r'[\r\n]+'))) {
    final line = rawLine.trim();
    if (line.isEmpty) continue;
    final tokens =
        line.split(RegExp(r'[\s,，\t]+')).where((t) => t.isNotEmpty).toList();
    DateTime? date;
    var dateIdx = -1;
    for (var i = 0; i < tokens.length; i++) {
      final d = _parseDate(tokens[i]);
      if (d != null) {
        date = d;
        dateIdx = i;
        break;
      }
    }
    if (date == null) continue; // 表头/合计行
    final nums = <int>[];
    for (var i = dateIdx + 1; i < tokens.length && nums.length < 3; i++) {
      final n = _parseYuan(tokens[i]);
      if (n == null) break; // 日期后首个非数字 = 行尾杂项,停止
      nums.add(n);
    }
    if (nums.isEmpty) continue;
    final principal = nums[0];
    final interest = nums.length > 1 ? nums[1] : 0;
    final discount = nums.length > 2 ? nums[2] : 0;
    rows['${date.year}-${date.month}-${date.day}'] = BankPlanRow(
      date: date,
      principalCents: principal,
      interestCents: interest,
      discountCents: discount,
    );
  }
  if (rows.isEmpty) {
    throw const FormatException('未解析到任何期次行(需要含日期与金额)');
  }
  final out = rows.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  return out;
}

DateTime? _parseDate(String t) {
  final m = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(t);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return null;
  return DateTime.utc(y, mo, d);
}

/// 元字符串 → 分;「1075.18」→107518;「1,075.18」千分位由分隔阶段
/// 拆碎,不支持;负数拒绝。
int? _parseYuan(String t) {
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(t);
  if (m == null) return null;
  final yuan = int.parse(m.group(1)!);
  final frac = m.group(2) ?? '0';
  final cents = int.parse(frac.padRight(2, '0'));
  return yuan * 100 + cents;
}
