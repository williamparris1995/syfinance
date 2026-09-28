/// F45 报告导出 —— 布局树 VO + `build(ReportDocument)`(ADR-2)。
///
/// 一份 pdf-agnostic 布局树(`Section{title, blocks}`,Block =
/// text|kv|table|bars|note),由 ReportDocument 构建一次;PDF 渲染器与
/// Markdown 渲染器共吃 —— 同源保证的结构化落地(FR-5:这里是导出侧唯一
/// 允许「遍历 VO」的地方,两后端零数字计算)。
///
/// 章节顺序与报告页 `_chapters` 同序:总览(hero 数字+摘要+附注)→
/// 资产负债 → 收支 → 现金流 → 预算(null 缺席)→ 投资(null 缺席)→
/// 诊断(mda null 缺席)。
///
/// 纯 Dart:仅 import report domain(硬约束:零 flutter/material,
/// service 可被 presentation 调)。金额 int cents;展示格式化助手
/// ([fmtExportCents] 等)与 presentation 的 chart_helpers.fmtCents 同
/// 口径(那边 import flutter/material 不可跨层引用,故内联同实现,
/// 数值口径注释互指 —— 先例:mda_models.mdaYuan)。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// 导出布局文档(标题 + 章节列表)。
class ReportExportLayout {
  const ReportExportLayout({
    required this.title,
    required this.periodLabel,
    required this.sections,
  });

  /// 文档标题:「御财财务报告 2026 年 8 月」(Markdown # 行/PDF 首页大标题)。
  final String title;

  /// 报告期原标签(页脚「御财财务报告-{label} · 第 N 页」用)。
  final String periodLabel;

  /// 章节(与页面 `_chapters` 同序)。
  final List<ReportExportSection> sections;

  /// 遍历 [ReportDocument] 构建布局树(导出侧唯一遍历点)。
  static ReportExportLayout build(ReportDocument doc) {
    final sections = <ReportExportSection>[
      _overviewSection(doc),
      ReportExportSection(title: '资产负债', blocks: _balanceSheetSection(doc)),
      ReportExportSection(title: '收支', blocks: _incomeSection(doc)),
      ReportExportSection(title: '现金流', blocks: _cashFlowSection(doc)),
      if (doc.budget != null)
        ReportExportSection(
            title: '预算执行', blocks: _budgetSection(doc.budget!, doc.period)),
      if (doc.investment != null)
        ReportExportSection(
            title: '投资绩效', blocks: _investmentSection(doc.investment!)),
      if (doc.mda != null)
        ReportExportSection(
            title: '诊断与建议',
            blocks: _mdaSection(doc.mda!, doc)),
    ];
    return ReportExportLayout(
      title: '御财财务报告 ${doc.period.label}',
      periodLabel: doc.period.label,
      sections: sections,
    );
  }

  /// 总览:hero 数字(overview_hero 同源)→ 四卡摘要(_MetricStrip 同源)
  /// → 诊断摘要计数行(MdaSummaryCard 计数头同源)→ 附注(notes)。
  static ReportExportSection _overviewSection(ReportDocument doc) {
    final ov = doc.overview;
    final mda = doc.mda;
    final noun = doc.period is ReportYearly ? '本年' : '本月';
    // 净资产变动额 = 期末 − 期初(展示层镜像 overview_hero 同式;Overview
    // 无 delta 派生字段,与页面一致由展示侧现算,非业务聚合)。
    final netDelta = ov.netWorthEndCents - ov.netWorthStartCents;
    final changePct = ov.netWorthChangePct;
    return ReportExportSection(title: '总览', blocks: [
      ReportKvBlock(title: '净资产变动 · ${doc.period.label}', rows: [
        ReportExportKvRow(
            label: '期初净资产',
            value: fmtExportCents(ov.netWorthStartCents),
            tone: ReportExportTone.neutral),
        ReportExportKvRow(
            label: '期末净资产',
            value: fmtExportCents(ov.netWorthEndCents),
            tone: ReportExportTone.neutral),
        ReportExportKvRow(
            label: '净资产变动',
            value: changePct == null
                ? fmtExportCentsSigned(netDelta)
                : '${fmtExportCentsSigned(netDelta)} (${fmtExportPctSigned(changePct)})',
            tone: netDelta >= 0
                ? ReportExportTone.positive
                : ReportExportTone.negative),
        ReportExportKvRow(
            label: '现金及等价物净变动',
            value: fmtExportCentsSigned(ov.cashDeltaCents),
            tone: ov.cashDeltaCents >= 0
                ? ReportExportTone.positive
                : ReportExportTone.negative),
        const ReportExportKvRow(
            label: '本位币', value: 'CNY', tone: ReportExportTone.neutral),
      ]),
      ReportKvBlock(title: '摘要', rows: [
        ReportExportKvRow(
            label: '$noun收入',
            value: fmtExportCents(ov.incomeCents),
            tone: ReportExportTone.positive),
        ReportExportKvRow(
            label: '$noun支出',
            value: fmtExportCents(ov.expenseCents),
            tone: ReportExportTone.neutral),
        ReportExportKvRow(
            label: '$noun结余',
            value: fmtExportCentsSigned(ov.surplusCents),
            tone: ov.surplusCents >= 0
                ? ReportExportTone.positive
                : ReportExportTone.negative),
        ReportExportKvRow(
            label: '储蓄率',
            value: '${ov.savingsRate.toStringAsFixed(1)}%',
            tone: ov.savingsRate >= 0
                ? ReportExportTone.positive
                : ReportExportTone.negative),
      ]),
      if (mda != null)
        ReportTextBlock(
            text: '诊断摘要:${mda.riskCount} 风险 ${mda.warnCount} 提示 '
                '${mda.infoCount} 关注,详见「诊断与建议」章节'),
      for (final note in ov.notes)
        ReportNoteBlock(title: note.title, lines: note.lines),
    ]);
  }

  /// 资产负债:资产/负债期末构成(bars)→ 资产负债率行 → 期初→期末变动表。
  static List<ReportExportBlock> _balanceSheetSection(ReportDocument doc) {
    final bs = doc.balanceSheet;
    final ratio = bs.debtRatioPct;
    return [
      _compositionBars(
          title: '资产构成 · 期末', rows: bs.assets, totalCents: bs.assetsTotalCents),
      _compositionBars(
          title: '负债构成 · 期末',
          rows: bs.liabilities,
          totalCents: bs.liabilitiesTotalCents),
      if (ratio != null)
        ReportTextBlock(
            text: '资产负债率 ${ratio.toStringAsFixed(1)}% · 期末负债 / 期末资产'),
      ReportTableBlock(
        title: '期初 → 期末 变动',
        header: const ['项目', '期初', '期末', '变动'],
        rows: [
          // 净资产汇总行(变动额 = 期末 − 期初,与页面 _ChangesTable 同式
          // 的展示现算,非业务聚合)。
          ReportExportTableRow(
            cells: [
              '净资产',
              fmtExportCents(doc.overview.netWorthStartCents),
              fmtExportCents(doc.overview.netWorthEndCents),
              fmtExportCentsSigned(
                  doc.overview.netWorthEndCents - doc.overview.netWorthStartCents),
            ],
            emphasized: true,
          ),
          for (final c in bs.changes)
            ReportExportTableRow(cells: [
              _categoryLabel(c.category),
              fmtExportCents(c.startCents),
              fmtExportCents(c.endCents),
              fmtExportCentsSigned(c.deltaCents),
            ]),
        ],
      ),
    ];
  }

  /// 分类构成 bars(name 优先,资产负债维度兜底转译账类代码;满条基准 =
  /// 首行金额,页面 CategoryBars「最大类满条」同构 —— 行序由汇编层降序保证)。
  static ReportBarsBlock _compositionBars({
    required String title,
    required List<CategoryAmount> rows,
    required int totalCents,
  }) =>
      ReportBarsBlock(
        title: title,
        totalCents: totalCents,
        bars: [
          for (final r in rows)
            ReportExportBar(
              label: (r.name == null || r.name!.isEmpty)
                  ? _categoryLabel(r.category)
                  : r.name!,
              amountCents: r.amountCents,
              sharePct: r.pct,
              maxCents: rows.isEmpty ? null : rows.first.amountCents,
            ),
        ],
      );

  /// 收支:支出分类/收入构成(bars)→ 摘要(日均结余 + 环比/首期)。
  static List<ReportExportBlock> _incomeSection(ReportDocument doc) {
    final ist = doc.incomeStatement;
    final prior = ist.priorComparison;
    return [
      _compositionBars(
        title: '支出分类',
        rows: ist.expense,
        // 合计为展示 fold(页面 _incomeChapter 同式;收支章节 VO 不带合计)。
        totalCents: ist.expense.fold<int>(0, (s, r) => s + r.amountCents),
      ),
      _compositionBars(
        title: '收入构成',
        rows: ist.income,
        totalCents: ist.income.fold<int>(0, (s, r) => s + r.amountCents),
      ),
      ReportKvBlock(title: '摘要', rows: [
        ReportExportKvRow(
            label: '日均结余',
            value: fmtExportCents(ist.dailyAvgCents),
            tone: ReportExportTone.neutral),
        if (prior != null)
          ReportExportKvRow(
              label: prior.label,
              value: fmtExportPctSigned(prior.deltaPct),
              tone: prior.deltaPct >= 0
                  ? ReportExportTone.positive
                  : ReportExportTone.negative)
        else
          const ReportExportKvRow(label: '对比期', value: '首期无对比数据'),
      ]),
    ];
  }

  /// 现金流:三类活动四行表(经营/投资/融资/合计)→ 勾稽脚注。
  static List<ReportExportBlock> _cashFlowSection(ReportDocument doc) {
    final cf = doc.cashFlow;
    // 流入/流出合计为展示 fold(页面 CashFlowTable 同式)。
    final totalIn = cf.operating.inflowCents +
        cf.investing.inflowCents +
        cf.financing.inflowCents;
    final totalOut = cf.operating.outflowCents +
        cf.investing.outflowCents +
        cf.financing.outflowCents;
    ReportExportTableRow row(String name, ActivityFlow f) =>
        ReportExportTableRow(cells: [
          name,
          fmtExportCents(f.inflowCents),
          fmtExportCents(f.outflowCents),
          fmtExportCentsSigned(f.netCents),
        ]);
    return [
      ReportTableBlock(
        title: '三类活动现金流',
        header: const ['活动', '流入', '流出', '净额'],
        rows: [
          row('经营活动', cf.operating),
          row('投资活动', cf.investing),
          row('融资活动', cf.financing),
          ReportExportTableRow(
            cells: [
              '合计',
              fmtExportCents(totalIn),
              fmtExportCents(totalOut),
              fmtExportCentsSigned(cf.netDeltaCents),
            ],
            emphasized: true,
          ),
        ],
      ),
      ReportTextBlock(
          text: cf.reconciled
              ? '勾稽:三类活动净额合计 ${fmtExportCentsSigned(cf.netDeltaCents)},'
                  '与期末−期初现金余额一致。'
              : '勾稽:三类净额与期末−期初现金余额不一致,请检查账本数据。'),
    ];
  }

  /// 预算执行:bars 满条基准 = 额度(limit),severity 三档(页面
  /// BudgetBars._barColor 同构:超支=risk / ≥90%=warn / 正常=null)。
  static List<ReportExportBlock> _budgetSection(
      BudgetSection budget, ReportPeriod period) {
    return [
      ReportBarsBlock(
        title: '预算执行 · ${period.label}',
        showMax: true,
        bars: [
          for (final item in budget.items)
            ReportExportBar(
              label: item.name,
              amountCents: item.actualCents,
              sharePct: item.pct,
              maxCents: item.limitCents,
              severity: item.overran
                  ? MdaSeverity.risk
                  : (item.pct >= 90 ? MdaSeverity.warn : null),
            ),
        ],
      ),
    ];
  }

  /// 投资绩效:五数值 kv(页面 PerfCards 同源;TWR null sentinel → '—')。
  static List<ReportExportBlock> _investmentSection(InvestmentSection inv) {
    final twr = inv.twr;
    return [
      ReportKvBlock(title: '投资绩效', rows: [
        ReportExportKvRow(
            label: '期初市值',
            value: fmtExportCents(inv.mvStartCents),
            tone: ReportExportTone.neutral),
        ReportExportKvRow(
            label: '期末市值',
            value: fmtExportCents(inv.mvEndCents),
            tone: ReportExportTone.neutral),
        ReportExportKvRow(
            label: '当期净买入',
            value: fmtExportCents(inv.netBuyCents),
            tone: ReportExportTone.neutral),
        ReportExportKvRow(
            label: '估算收益',
            value: fmtExportCentsSigned(inv.estGainCents),
            tone: inv.estGainCents >= 0
                ? ReportExportTone.positive
                : ReportExportTone.negative),
        ReportExportKvRow(
            label: '区间 TWR',
            value: twr == null ? '—' : fmtExportPctSigned(twr),
            tone: twr == null
                ? ReportExportTone.neutral
                : (twr >= 0
                    ? ReportExportTone.positive
                    : ReportExportTone.negative)),
      ]),
    ];
  }

  /// 诊断与建议:零发现 = 健康两行;有发现 = 按 severity 分组
  /// (引擎已排序,分组头「风险 · N」镜像页面 MdaChapter 组头)。
  static List<ReportExportBlock> _mdaSection(MdaSection mda, ReportDocument doc) {
    if (mda.findings.isEmpty) {
      final ratio = doc.balanceSheet.debtRatioPct;
      final runway = mda.healthyRunwayMonths;
      final passed = [
        '储蓄率 ${doc.overview.savingsRate.toStringAsFixed(1)}%',
        if (ratio != null) '资产负债率 ${ratio.toStringAsFixed(1)}%',
        if (runway != null) '现金可支撑约 ${runway.toStringAsFixed(1)} 个月',
      ].join('、');
      return [
        const ReportTextBlock(text: '本期诊断未发现需关注项'),
        ReportTextBlock(text: '$passed,均在健康区间'),
      ];
    }
    final blocks = <ReportExportBlock>[];
    // 按 severity 值序(risk→warn→info)分组;空组不输出组头(页面同构)。
    for (final s in MdaSeverity.values) {
      final group = mda.findings.where((f) => f.severity == s).toList();
      if (group.isEmpty) continue;
      blocks.add(ReportTextBlock(text: '${_severityLabel(s)} · ${group.length}'));
      for (final f in group) {
        blocks.add(ReportTextBlock(
          text: '${f.conclusion}\n建议:${f.advice}',
          severity: s,
        ));
      }
    }
    return blocks;
  }

  /// severity 中文级别名(mda presentation MdaSeverityUi.label 同词表;
  /// export 不 import presentation,内联同实现,修改须两侧同步)。
  static String _severityLabel(MdaSeverity s) => switch (s) {
        MdaSeverity.risk => '风险',
        MdaSeverity.warn => '提示',
        MdaSeverity.info => '关注',
      };

  /// 账类代码 → 中文标签(account/domain/value_objects.AccountCategoryX.label
  /// 同表内联 —— export 硬约束不 import account 模块,先例:mdaYuan 内联
  /// formatYuan;新增账类须两侧同步)。非账类串(收支维度科目 id)原样返回。
  static String _categoryLabel(String code) => switch (code) {
        'savings' => '储蓄',
        'creditCard' => '信用卡',
        'investment' => '投资',
        'fixedDeposit' => '定期',
        'goldFx' => '黄金外汇',
        'realEstate' => '固定资产',
        'loan' => '贷款',
        'otherAsset' => '其他资产',
        'otherLiability' => '其他负债',
        'storedValue' => '储值卡',
        _ => code,
      };
}

/// 单章节(标题 + 内容块序列)。
class ReportExportSection {
  const ReportExportSection({required this.title, required this.blocks});

  /// 章节标题(锚点/目录同源)。
  final String title;

  /// 内容块(有序)。
  final List<ReportExportBlock> blocks;
}

/// 内容块基类(text|kv|table|bars|note,ADR-2)。
sealed class ReportExportBlock {
  const ReportExportBlock();
}

/// 值语义着色(展示提示,无业务含义;PDF 按此取色深,Markdown 忽略)。
enum ReportExportTone { neutral, positive, negative }

/// 文本段:脚注(勾稽/资产负债率)/ 诊断摘要行 / 诊断分组头与发现行。
///
/// [severity] 驱动双渲染器语义表达:PDF 用色深(risk 红 / warn 黄 /
/// info 灰蓝),Markdown 用符号前缀(🔴/⚠/ℹ)。
class ReportTextBlock extends ReportExportBlock {
  const ReportTextBlock({required this.text, this.severity});

  /// 正文(可含换行:诊断发现 = 结论 + 「建议:…」两行)。
  final String text;

  /// 严重度语义(诊断发现行;普通文本 null)。
  final MdaSeverity? severity;
}

/// 键值组:hero 数字 / 总览四卡摘要 / 收支摘要 / 投资五卡。
class ReportKvBlock extends ReportExportBlock {
  const ReportKvBlock({this.title, required this.rows});

  /// 组标题(卡片标题,如「净资产变动 · 2026 年 8 月」)。
  final String? title;

  /// 键值行(有序)。
  final List<ReportExportKvRow> rows;
}

/// 单键值行(label + 展示值 + 着色)。
class ReportExportKvRow {
  const ReportExportKvRow({
    required this.label,
    required this.value,
    this.tone = ReportExportTone.neutral,
  });

  final String label;

  /// 展示值(布局期已格式化,渲染器零数字计算)。
  final String value;

  final ReportExportTone tone;

  @override
  bool operator ==(Object other) =>
      other is ReportExportKvRow &&
      other.label == label &&
      other.value == value &&
      other.tone == tone;

  @override
  int get hashCode => Object.hash(label, value, tone);
}

/// 附注块(口径说明/未包含项;Markdown 引用块)。
class ReportNoteBlock extends ReportExportBlock {
  const ReportNoteBlock({required this.title, required this.lines});

  final String title;
  final List<String> lines;
}

/// 条形组:资产负债期末构成 / 支出分类 / 收入构成 / 预算执行。
///
/// [severity] 语义仅预算执行使用(超支=risk / 临界≥90%=warn / 正常=null),
/// PDF 用色深、Markdown 用符号;构成类 bars 恒 null。
class ReportBarsBlock extends ReportExportBlock {
  const ReportBarsBlock({
    this.title,
    this.totalCents,
    this.showMax = false,
    required this.bars,
  });

  /// 组标题(卡片标题)。
  final String? title;

  /// 组合计(int cents,标题侧展示;渲染器零 fold)。
  final int? totalCents;

  /// 是否在每行金额旁展示满条基准(预算「actual / limit」形态)。
  final bool showMax;

  final List<ReportExportBar> bars;
}

/// 单条形行(构成/预算同构)。
class ReportExportBar {
  const ReportExportBar({
    required this.label,
    required this.amountCents,
    required this.sharePct,
    this.maxCents,
    this.severity,
  });

  final String label;

  /// 金额(int cents;条形几何与文本由渲染器按此出)。
  final int amountCents;

  /// 展示占比 %(1 位小数;VO 派生 pct 直出)。
  final double sharePct;

  /// 满条基准(构成=最大行金额;预算=额度 limit)。
  final int? maxCents;

  /// 三档色语义(预算行;构成行 null)。
  final MdaSeverity? severity;

  @override
  bool operator ==(Object other) =>
      other is ReportExportBar &&
      other.label == label &&
      other.amountCents == amountCents &&
      other.sharePct == sharePct &&
      other.maxCents == maxCents &&
      other.severity == severity;

  @override
  int get hashCode =>
      Object.hash(label, amountCents, sharePct, maxCents, severity);
}

/// 表格块:期初→期末变动表 / 三类活动现金流表。
class ReportTableBlock extends ReportExportBlock {
  const ReportTableBlock({
    this.title,
    required this.header,
    required this.rows,
  });

  final String? title;

  /// 表头(列名)。
  final List<String> header;

  final List<ReportExportTableRow> rows;
}

/// 单表格行(展示串已格式化;[emphasized] 合计/汇总行)。
class ReportExportTableRow {
  const ReportExportTableRow({required this.cells, this.emphasized = false});

  final List<String> cells;
  final bool emphasized;

  @override
  bool operator ==(Object other) =>
      other is ReportExportTableRow &&
      other.emphasized == emphasized &&
      _listEq(other.cells, cells);

  @override
  int get hashCode => Object.hashAll(cells);

  static bool _listEq(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ───────────────────────── 展示格式化(与 chart_helpers 同口径)─────────

/// 整数千分位分组(取绝对值,忽略符号;chart_helpers.groupInt 同实现)。
String _groupInt(int n) {
  final s = n.abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// int cents → '¥1,234.56'(负数 '-¥…';不带正号,语义性 '+' 用
/// [fmtExportCentsSigned])。与 presentation/chart_helpers.fmtCents 同
/// 口径(那边 import flutter 不可被纯 Dart export 引用,故内联同实现,
/// 修改须两侧同步 —— 先例:mda_models.mdaYuan)。
String fmtExportCents(int cents) {
  final neg = cents < 0;
  final abs = cents.abs();
  return '${neg ? '-' : ''}¥${_groupInt(abs ~/ 100)}.'
      '${(abs % 100).toString().padLeft(2, '0')}';
}

/// 带符号金额:正 '+¥…' / 负与零原样(fmtCentsSigned 同口径)。
String fmtExportCentsSigned(int cents) =>
    cents > 0 ? '+${fmtExportCents(cents)}' : fmtExportCents(cents);

/// 1 位小数百分比带符号:'5.2' → '+5.2%'(fmtPctSigned 同口径;pct 值
/// 已在 model factory 按 1 位小数收口)。
String fmtExportPctSigned(double pct) =>
    '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(1)}%';

/// 报告期 → 文件名安全段(FR-1 默认文件名「御财财务报告-{段}.pdf」)。
///
/// 安全化 = 去路径非法字符(Windows `\ / : * ? " < > |` 与控制符)与
/// 空白;月报月份补零对齐 spec 示例「2026年08月」(period.label 为
/// 「2026 年 8 月」带空格不补零形态)。
String safeFileStem(ReportPeriod period) {
  final raw = period is ReportMonthly
      ? '${period.year}年${period.month.toString().padLeft(2, '0')}月'
      : period.label; // 「2025 年度」
  return raw.replaceAll(RegExp(r'[\\/:*?"<>|\p{Cc}\s]'), '');
}
