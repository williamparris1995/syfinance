/// F44 规则诊断引擎 —— MD&A 模型(immutable VO,纯 Dart domain)。
///
/// 本文件为零外依赖纯核:仅 import 本模块 report_document(规则输入契约);
/// 阈值 [MdaThresholds] 单点定义(具名常量 + 行业依据注释,ADR-2)。
library;

import 'package:yucai_client/report/domain/report_document.dart';

/// 严重度:risk(风险)> warn(提示)> info(信息)。
///
/// 语义色映射(ADR-4):risk→既有警示红 / warn→既有黄 / info→中性,
/// 渲染层负责,本域只表达级别序。
enum MdaSeverity { risk, warn, info }

/// 单条诊断发现(FR-1):规则 id + 级别 + 中文结论(含溯源数字)+
/// 可执行建议 + 可选跳转路由。
class MdaFinding {
  const MdaFinding({
    required this.ruleId,
    required this.severity,
    required this.conclusion,
    required this.advice,
    this.actionLink,
  });

  /// 规则标识,如 'R1'(储蓄率)/ 'H2'(环比突增)。
  final String ruleId;

  /// 严重度。
  final MdaSeverity severity;

  /// 结论文案(中文,必须含溯源数字:阈值、金额、比例)。
  final String conclusion;

  /// 可执行建议。
  final String advice;

  /// 可选跳转路由(如 R4 闲置订阅 → 订阅中心 /accounts/subscriptions)。
  final String? actionLink;
}

/// 「诊断与建议」章节模型(FR-4):排序后的发现列表 + 三级计数汇总 +
/// 健康摘要 runway(渲染层零重算)。
///
/// 排序责任在引擎(按 severity 稳定排序);本 factory 只做计数汇总,
/// findings 按入参原序存储(设计如此,渲染层免再算)。
class MdaSection {
  const MdaSection({
    required this.findings,
    required this.riskCount,
    required this.warnCount,
    required this.infoCount,
    this.healthyRunwayMonths,
  });

  /// 计数汇总 factory(总览摘要卡吃 counts + top3,LLD 契约)。
  ///
  /// [healthyRunwayMonths] 为健康态第三指标(现金可支撑月数,R6 同口径
  /// [runwayMonths]);1 位小数构造期收口,无基数 → null。
  factory MdaSection.create({
    required List<MdaFinding> findings,
    double? healthyRunwayMonths,
  }) {
    var risk = 0, warn = 0, info = 0;
    for (final f in findings) {
      switch (f.severity) {
        case MdaSeverity.risk:
          risk++;
        case MdaSeverity.warn:
          warn++;
        case MdaSeverity.info:
          info++;
      }
    }
    return MdaSection(
      findings: findings,
      riskCount: risk,
      warnCount: warn,
      infoCount: info,
      healthyRunwayMonths:
          healthyRunwayMonths == null ? null : mdaRound1(healthyRunwayMonths),
    );
  }

  /// 发现列表(引擎已按 severity 排序)。
  final List<MdaFinding> findings;

  /// risk 级条数。
  final int riskCount;

  /// warn 级条数。
  final int warnCount;

  /// info 级条数。
  final int infoCount;

  /// 健康摘要:现金可支撑月数(1 位小数;trailing3m 无基数 → null)。
  /// T3 评审 round 1:健康卡三指标第三段(储蓄率/资产负债率在 doc,
  /// runway 不在 ReportDocument 契约,故随章节走)。
  final double? healthyRunwayMonths;
}

/// 阈值常量表(FR-2:单点定义 + 行业依据注释;用户可配置 = backlog)。
///
/// 全部具名 const,规则代码禁止内联裸数字;R17 重校时只改这里。
abstract final class MdaThresholds {
  /// 储蓄率 risk 线(10%):常见理财科普基线「至少存下 10%」,是
  /// 50/30/20 预算法储蓄目标的保守下沿。
  static const double savingsRiskBelow = 0.10;

  /// 储蓄率 warn 线(20%):50/30/20 法则的储蓄 20% 通用目标。
  static const double savingsWarnBelow = 0.20;

  /// 预算超支 risk 线(超支 ≥20%):预算管理惯例,超支两成以上视为
  /// 预算失效(额度系统性偏低)而非偶发噪声。
  static const double budgetOverrunRiskPct = 0.20;

  /// 资产负债率 warn 线(50%):个人财务稳健常用警戒线,过半资产
  /// 由负债支撑时偿付弹性开始受限。
  static const double debtWarnAt = 0.50;

  /// 资产负债率 risk 线(70%):个人负债率高压线(消费信贷授信内部
  /// 参考区间的上沿);房贷语境另见 R3 文案附注。
  static const double debtRiskAt = 0.70;

  /// runway warn 线(3 个月):应急备用金「3-6 个月基本生活费」建议
  /// 区间的下沿。
  static const int runwayWarnMonths = 3;

  /// runway risk 线(1 个月):现金不足一个月平均支出,现金流断裂
  /// 风险显著。
  static const int runwayRiskMonths = 1;

  /// 大额单笔:日均支出倍数线(3 倍):异常检测的 3 倍经验法则
  /// (3σ 启发的简化版),叠加占比门槛双保险。
  static const double largeSingleDayAvgX = 3;

  /// 大额单笔:当期总支出占比线(20%):单笔占比两成以上视为显著
  /// 集中,足以影响当期结构。
  static const double largeSingleSharePct = 0.20;

  /// 支出集中度 warn 线(40%):单一类别四成以上,构成多样性不足的
  /// 常用提示线。
  static const double concentrationPct = 0.40;

  /// 环比突增比例线(+50%):类别支出环比涨五成视为显著突变。
  static const double spikePct = 0.50;

  /// 环比突增额占比线(当期总支出 5%):双门槛防小基数误报——
  /// 涨五成但绝对额不足总支出 5% 的类别不报。
  static const double spikeSharePct = 0.05;

  /// 闲置订阅 grace 宽限(7 天):nextDate 落在期末后一周内视为
  /// 「即将扣费」,不按闲置报(跨期入账/自动扣费延迟防御)。
  static const int idleGraceDays = 7;
}

/// 现金可支撑月数 = cashEnd ÷(trailing3m ÷ 3)——R6 阈值判定与健康摘要
/// 共用的**单点口径**(T3 评审 round 1:公式不复制,两处同源)。
///
/// 返回原始 double(R6 阈值比较用原值);展示收口 1 位小数由
/// [MdaSection.create] 负责。trailing3m ≤ 0 → null(无基数,不除零)。
double? runwayMonths({
  required int cashEndCents,
  required int trailing3mExpenseCents,
}) {
  if (trailing3mExpenseCents <= 0) return null;
  return cashEndCents / (trailing3mExpenseCents / 3);
}

/// 补充输入行:支出/收入订阅模板的 MD&A 视图(FR-1/FR-3)。
///
/// 纯 domain VO(T2 汇编层由 ReportLedgerStore.templateRows() 投影
/// 填充):[expectedDates] 为 adapter 预推演的**期内**应扣日(date-only,
/// 推演逻辑留 data 侧,复用 core/recurrence 口径);[expense] 为
/// direction==expense 谓词(income/transfer 模板不进闲置口径)。
class TemplateRowVO {
  const TemplateRowVO({
    required this.id,
    required this.name,
    required this.expense,
    required this.amountCents,
    required this.paused,
    required this.autoRecord,
    required this.nextDate,
    required this.lastRecordedDate,
    required this.expectedDates,
  });

  /// 模板 id。
  final String id;

  /// 模板名称。
  final String name;

  /// 是否支出方向(direction==expense)。
  final bool expense;

  /// 单期金额(int cents)。
  final int amountCents;

  /// 是否暂停。
  final bool paused;

  /// 是否自动记账。
  final bool autoRecord;

  /// 下一笔预计日期(date-only;无 → null)。
  final DateTime? nextDate;

  /// 最近一次记账日期(date-only;从未记过 → null)。
  final DateTime? lastRecordedDate;

  /// 报告期内应扣日(预推演,升序 date-only;期内无应扣日 → 空)。
  final List<DateTime> expectedDates;
}

/// 补充输入行:大额单笔候选的 MD&A 视图(R5)。
///
/// [expenseCents] = 该笔交易 expense 科目 debit 合计(T2 adapter 算);
/// 交易级(非分录级)。
class LargeTxnVO {
  const LargeTxnVO({
    required this.transactionId,
    required this.date,
    required this.description,
    required this.expenseCents,
  });

  /// 交易 id。
  final String transactionId;

  /// 交易日期(date-only)。
  final DateTime date;

  /// 描述(本地交易行描述,port 投影补齐)。
  final String description;

  /// 单笔支出额(int cents)。
  final int expenseCents;
}

/// MD&A 补充输入(FR-1/ADR-3):汇编层顺带产出,不新增读取。
///
/// [priorExpense] 为 H2 专用降级口径:ReportDocument 只带当期构成 +
/// priorComparison 汇总,无前期分类构成,故环比类别比较由汇编层
/// 同通道(既有 entries)喂前期构成。
class MdaSupplement {
  const MdaSupplement({
    required this.templates,
    required this.transactions,
    required this.trailing3mExpenseCents,
    required this.cashStartCents,
    required this.cashEndCents,
    required this.priorExpense,
  });

  /// 支出/收入订阅模板视图(含期内应扣日预推演)。
  final List<TemplateRowVO> templates;

  /// 当期交易级支出投影(R5 大额单笔候选)。
  final List<LargeTxnVO> transactions;

  /// 近三个完整月支出合计(int cents;R6 月均 = ÷3)。
  final int trailing3mExpenseCents;

  /// 期初现金及等价物(replay savings 类账户合计)。
  final int cashStartCents;

  /// 期末现金及等价物。
  final int cashEndCents;

  /// 前期(月报=上月;年报=上年)支出分类构成(H2 环比口径)。
  final List<CategoryAmount> priorExpense;
}

/// 分 → 「1,234.56」式元字符串(千分位 + 2 位小数,负数带 -)。
///
/// 口径对齐 core/notifications/due_reminder_policy.dart 的 formatYuan
/// (通知/记账文案同款);mda 为纯 domain 不跨模块 import,故内联同
/// 实现(数值口径注释互指)。
String mdaYuan(int cents) {
  final neg = cents < 0;
  final s = (cents.abs() / 100).toStringAsFixed(2);
  final dot = s.indexOf('.');
  final intPart = dot < 0 ? s : s.substring(0, dot);
  final frac = dot < 0 ? '' : s.substring(dot);
  final grouped = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    final posFromRight = intPart.length - i;
    grouped.write(intPart[i]);
    if (posFromRight > 1 && (posFromRight - 1) % 3 == 0) {
      grouped.write(',');
    }
  }
  return '${neg ? '-' : ''}$grouped$frac';
}

/// 分 → 「-¥1,234.56」式人民币字符串(负号在货币符号前,结论文案用)。
String mdaCny(int cents) =>
    cents < 0 ? '-¥${mdaYuan(cents.abs())}' : '¥${mdaYuan(cents)}';

/// 数值四舍五入保留 1 位小数(pct/月数等结论文案统一口径,
/// 对齐 report_document 的派生字段精度)。
double mdaRound1(double v) => (v * 10).round() / 10;
