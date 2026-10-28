// F72-T2 —— 审计「已记:」族摘要 → 记一笔三要素解析器(spec FR-4,
// design ADR-3)。
//
// 「以此再记一笔」的确定性解析面:自家 note 格式
// 「已记:支出 ¥35.00 午饭」(WriteExecutorImpl._writeNote 单点构造,与
// appendToolOutcome 会话注入/审计 summary 同串同源)→ 方向/金额/描述。
//
// - **只解析三要素**(简报钉定):账户/分类串中无、不从 note 猜 —— 提案时
//   由 bloc 按默认推导取名,再经 transaction_add_tool 的 execute 全套
//   名称→id 消歧(ToolError 照常可出)。
// - **改/删族零解析**(ADR-3):「已改:」「已删:」前缀不命中 → null(目标
//   交易已变,重跑必错 —— 只读);失败行素材缺失的 ASCII 机器串回退形态
//   同样 null。
// - 纯函数零依赖(除 write_action 方向枚举);金额元串复用 yuan() 同源
//   口径(两位小数 + 千分位逗号),parse 侧剥逗号四舍五入到 cents(镜像
//   parseYuanToCents)。**格式漂移防线** = 与 _writeNote 的成对往返测
//   (生成→解析→字段相等;见 note_parser_test)。
library;

import 'package:yucai_client/assistant/domain/write_action.dart';

/// 「已记:」族 note 的三要素解析结果(方向/金额/描述)。
class AddActionFromNote {
  const AddActionFromNote({
    required this.direction,
    required this.amountCents,
    required this.description,
  });

  /// 收支方向(支出/收入 → outflow/inflow)。
  final WriteDirection direction;

  /// 金额(cents;恒正 —— TransactionAdd 不变量)。
  final int amountCents;

  /// 描述(note 金额后的整段;可为空串)。
  final String description;

  /// note 头(「已记:」)+ 方向词 + ¥金额(两位小数,可含千分位逗号,
  /// 可带负号 —— 负/零额解析后由恒正守卫拒);描述 = 金额后的整段
  /// (trim;空描述 = _flat 首尾去空后的合法形态)。
  static final RegExp _pattern = RegExp(
    r'^已记:(支出|收入)\s+¥(-?[\d,]+(?:\.\d+)?)\s*(.*)$',
  );

  /// 确定性解析:不命中格式 / 金额垃圾 / 金额 ≤ 0 → null(调用方转
  /// ErrorMsg,零卡零写)。
  static AddActionFromNote? parse(String note) {
    final match = _pattern.firstMatch(note.trim());
    if (match == null) return null;
    final direction = match.group(1) == '支出'
        ? WriteDirection.outflow
        : WriteDirection.inflow;
    final yuan = double.tryParse(match.group(2)!.replaceAll(',', ''));
    if (yuan == null) return null;
    final cents = (yuan * 100).round();
    if (cents <= 0) return null; // 恒正式不变量(与工具层 parseYuanToCents 同守卫)
    return AddActionFromNote(
      direction: direction,
      amountCents: cents,
      description: match.group(3)!.trim(),
    );
  }
}
