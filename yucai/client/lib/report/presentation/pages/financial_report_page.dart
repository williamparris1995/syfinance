/// F43 财务报告页(T5,/reports/full,ADR-5:单页滚动章节+变体 B 锚点)。
///
/// UI 事实源 = 原型 v7 financial-report.html(变体 B = 实现终态)+ F44
/// v8 增量(总览诊断摘要卡 + 第七章节「诊断与建议」):顶栏面包屑
/// 「报表分析 › 财务报告」;页头 = 标题/副题 + 月/年 segmented +
/// 上一期/下一期 + 期标签([ReportPeriod.label])+ 「生成报告」主按钮 +
/// F45 T2「导出」按钮(仅 Loaded;小菜单选 PDF/Markdown → 保存对话框 →
/// 成功 toast「打开」,页面 handler 注入缝接线,见 [createReportExportService]);
/// gen-zone = Initial 引导卡 / 四阶段进度(FR-8,>300ms 才展开阶段明细,
/// 判定在页面侧,见 [_progressGate] 注释);报告体 = 单页滚动章节 +
/// 右缘圆点锚点([SectionDotNav]:悬停标签/点击平滑滚动/滚动高亮当前章)。
///
/// 自适应章节(FR-3):预算执行/投资绩效 null → 章节与锚点一并缺席;
/// F44 诊断与建议章节(mda 恒非空语义,仅期外异常 null)挂链尾。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/export/report_export_service.dart';
import 'package:yucai_client/report/presentation/financial_report_bloc.dart';
import 'package:yucai_client/report/presentation/report_export_io.dart';
import 'package:yucai_client/report/presentation/widgets/budget_bars.dart';
import 'package:yucai_client/report/presentation/widgets/cashflow_table.dart';
import 'package:yucai_client/report/presentation/widgets/category_bars.dart';
import 'package:yucai_client/report/presentation/widgets/chart_helpers.dart';
import 'package:yucai_client/report/presentation/widgets/mda_section.dart';
import 'package:yucai_client/report/presentation/widgets/mda_summary_card.dart';
import 'package:yucai_client/report/presentation/widgets/notes_card.dart';
import 'package:yucai_client/report/presentation/widgets/overview_hero.dart';
import 'package:yucai_client/report/presentation/widgets/perf_cards.dart';
import 'package:yucai_client/report/presentation/widgets/section_anchor_bar.dart';

/// 财务报告页(/reports/full)。
class FinancialReportPage extends StatefulWidget {
  const FinancialReportPage({
    super.key,
    this.initialPeriod,
    this.exportService,
  });

  /// 初始报告期(测试注入固定期;缺省 = 当前自然月)。
  final ReportPeriod? initialPeriod;

  /// F45 T2:导出服务注入缝(测试以 fake 四缝替换;缺省 = 生产平台
  /// 接线,见 report_export_io.dart —— export 域保持纯 Dart)。
  final ReportExportService? exportService;

  @override
  State<FinancialReportPage> createState() => _FinancialReportPageState();
}

class _FinancialReportPageState extends State<FinancialReportPage> {
  // —— 报告期选择状态(页面本地;事件携带所选期下发 bloc)——
  late bool _yearly;
  late int _year;
  late int _month;

  // —— 报告体滚动/锚点 ——
  final _scroll = ScrollController();
  final List<GlobalKey> _chapterKeys = [];
  int _activeChapter = 0;

  // —— >300ms 进度门(FR-8):页面侧计时。
  // 选页面侧而非 bloc:bloc 保持纯状态机(零时钟依赖),页面持有一个
  // Timer 即可;Loading 会话开始时启动,300ms 后仍处 Loading 才展开四阶段
  // 步进明细(快速生成不闪进度,spec FR-8 验收锚点)。
  Timer? _progressGate;
  bool _loadingSession = false;
  bool _progressDetailVisible = false;

  // —— F45 T2:导出进行中(按钮禁用 + spinner;页面本地,不新 bloc)。——
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initialPeriod;
    if (init is ReportMonthly) {
      _yearly = false;
      _year = init.year;
      _month = init.month;
    } else if (init is ReportYearly) {
      _yearly = true;
      _year = init.year;
      _month = DateTime.now().month;
    } else {
      final now = DateTime.now();
      _yearly = false;
      _year = now.year;
      _month = now.month;
    }
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _progressGate?.cancel();
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  ReportPeriod get _period => _yearly
      ? ReportPeriod.yearly(_year)
      : ReportPeriod.monthly(_year, _month);

  void _prevPeriod() => setState(() {
        if (_yearly) {
          _year--;
        } else if (_month == 1) {
          _month = 12;
          _year--;
        } else {
          _month--;
        }
      });

  void _nextPeriod() => setState(() {
        if (_yearly) {
          _year++;
        } else if (_month == 12) {
          _month = 1;
          _year++;
        } else {
          _month++;
        }
      });

  void _generate() =>
      context.read<FinancialReportBloc>().add(GenerateRequested(_period));

  // —— F45 T2:导出入口(page handler,照 settings `_showExportArchive`
  // 先例,不新 bloc;行为由导出测试逐条驱动)。——
  ReportExportService? _prodExportService;

  ReportExportService get _exporter => widget.exportService ??
      (_prodExportService ??= createReportExportService());

  Future<void> _export(ReportExportFormat format) async {
    final st = context.read<FinancialReportBloc>().state;
    if (_exporting || st is! FinancialReportLoaded) return; // 仅 Loaded。
    setState(() => _exporting = true);
    try {
      final path = await _exporter.exportAndSave(st.document, format);
      if (!mounted) return;
      if (path == null) return; // 用户取消:零副作用零提示(FR-1)。
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: const ValueKey('reportExportedToast'),
          content: const Text('报告已导出'),
          action: SnackBarAction(
            key: const ValueKey('reportExportOpenAction'),
            label: '打开',
            onPressed: () => _openExported(path),
          ),
        ),
      );
    } on Exception {
      // 错误兜底(渲染/对话框/落盘异常):toast,不误报成功。
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('导出失败,请重试')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  /// 打开已导出文件(launch 缝;失败 toast 兜底,照 debt_detail 先例)。
  /// url_launcher 可能抛 PlatformException —— 抛错视同失败(feedback
  /// _defaultLaunch S-4 同款),统一兜底 toast。
  Future<void> _openExported(String path) async {
    var ok = false;
    try {
      ok = await _exporter.openExported(path);
    } on Exception {
      ok = false;
    }
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('打开失败')));
  }

  // —— 状态副作用:进度门 + 生成完成后回顶(新报告从第一章读起)。——
  void _onState(FinancialReportState state) {
    final loading = state is FinancialReportLoading;
    if (loading && !_loadingSession) {
      // 进入 Loading 会话:计时 300ms 后展开步进(仍处 Loading 才生效)。
      _loadingSession = true;
      _progressDetailVisible = false;
      _progressGate?.cancel();
      _progressGate = Timer(const Duration(milliseconds: 300), () {
        if (mounted && _loadingSession) {
          setState(() => _progressDetailVisible = true);
        }
      });
    } else if (!loading && _loadingSession) {
      _loadingSession = false;
      _progressGate?.cancel();
      _progressDetailVisible = false;
    }
    if (state is FinancialReportLoaded) {
      _activeChapter = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  // —— 锚点:滚动高亮当前章(章顶越过阈值线 = 当前)。——
  void _onScroll() {
    var active = 0;
    for (var i = 0; i < _chapterKeys.length; i++) {
      final ctx = _chapterKeys[i].currentContext;
      final ro = ctx?.findRenderObject();
      if (ro is RenderBox && ro.attached && ro.hasSize) {
        if (ro.localToGlobal(Offset.zero).dy <= 200) active = i;
      }
    }
    if (active != _activeChapter) setState(() => _activeChapter = active);
  }

  void _scrollTo(int index) {
    final ctx = _chapterKeys[index].currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    }
    setState(() => _activeChapter = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      body: Column(
        children: [
          const _ReportTopBar(),
          Divider(height: 1, color: context.yucai.border),
          Expanded(
            child: BlocConsumer<FinancialReportBloc, FinancialReportState>(
              listener: (_, state) => _onState(state),
              builder: (context, state) => _body(context, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, FinancialReportState state) {
    final doc = state is FinancialReportLoaded ? state.document : null;
    final chapters = doc == null ? const <_ChapterSpec>[] : _chapters(doc);
    // 章节锚 key 池:只增不减,索引稳定。
    while (_chapterKeys.length < chapters.length) {
      _chapterKeys.add(GlobalKey());
    }

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.xl),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PageHead(
                    yearly: _yearly,
                    period: _period,
                    generating: state is FinancialReportLoading,
                    canExport: doc != null,
                    exporting: _exporting,
                    onScopeChanged: (yearly) => setState(() => _yearly = yearly),
                    onPrev: _prevPeriod,
                    onNext: _nextPeriod,
                    onGenerate: _generate,
                    onExportFormat: _export,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _GenZone(
                    state: state,
                    onGenerate: _generate,
                    detail: _progressDetailVisible,
                  ),
                  // 报告体淡入(原型 .report-body.show:gen-zone 收起后入场)。
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: doc == null
                        ? const SizedBox.shrink()
                        : KeyedSubtree(
                            key: ValueKey('reportBody-${doc.generatedAt}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < chapters.length; i++)
                                  Container(
                                    key: _chapterKeys[i],
                                    margin: const EdgeInsets.only(
                                        bottom: AppSpacing.lg),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _ChapterHead(
                                          no: (i + 1)
                                              .toString()
                                              .padLeft(2, '0'),
                                          title: chapters[i].title,
                                        ),
                                        const SizedBox(height: AppSpacing.sm),
                                        chapters[i].child,
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // 变体 B:右缘圆点锚点(仅 Loaded 出现)。
        if (doc != null)
          Positioned(
            right: 14,
            top: 0,
            bottom: 0,
            child: Center(
              child: SectionDotNav(
                labels: [for (final c in chapters) c.title],
                active: _activeChapter,
                onTap: _scrollTo,
              ),
            ),
          ),
      ],
    );
  }

  // ───────────────────────── 章节组装(自适应:null 章节缺席)─────────

  List<_ChapterSpec> _chapters(ReportDocument doc) {
    final noun = doc.period is ReportYearly ? '本年' : '本月';
    final mda = doc.mda;
    // 第七章「诊断与建议」锚点索引(变体 B 锚点链):前四章固定 +
    // 预算/投资自适应缺席;摘要卡「查看全部」锚滚目标。
    final mdaChapterIndex =
        4 + (doc.budget != null ? 1 : 0) + (doc.investment != null ? 1 : 0);
    // 摘要卡整体预构(section 与锚滚回调用一出生地绑定,null 缺席),
    // 免去 _overviewChapter 内跨参非空不变量。
    final mdaCard = mda == null
        ? null
        : MdaSummaryCard(
            section: mda, onViewAll: () => _scrollTo(mdaChapterIndex));
    return [
      _ChapterSpec('总览', _overviewChapter(doc, noun, mdaCard: mdaCard)),
      _ChapterSpec('资产负债', _balanceSheetChapter(doc)),
      _ChapterSpec('收支', _incomeChapter(doc, noun)),
      _ChapterSpec('现金流', _cashFlowChapter(doc)),
      // 自适应缺席(FR-3):null 章节不渲染,锚点同步缺席。
      if (doc.budget != null) _ChapterSpec('预算执行', _budgetChapter(doc)),
      if (doc.investment != null)
        _ChapterSpec('投资绩效', _investmentChapter(doc)),
      // F44 第七章节(mda 恒非空语义;仅期外异常 null → 整章缺席)。
      if (mda != null)
        _ChapterSpec('诊断与建议', MdaChapter(section: mda, doc: doc)),
    ];
  }

  Widget _overviewChapter(
    ReportDocument doc,
    String noun, {
    Widget? mdaCard,
  }) {
    final ov = doc.overview;
    final periodNoun = doc.period is ReportYearly ? '年度' : '月口径';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OverviewHero(overview: ov, periodLabel: doc.period.label),
        const SizedBox(height: AppSpacing.md),
        _MetricStrip(
          noun: noun,
          periodNoun: periodNoun,
          overview: ov,
          incomeCount: doc.incomeStatement.income.length,
          expenseCount: doc.incomeStatement.expense.length,
        ),
        const SizedBox(height: AppSpacing.md),
        _CashSlimCard(deltaCents: ov.cashDeltaCents),
        // F44 诊断摘要卡(sum-strip 后、附注卡前;mda null → 缺席)。
        if (mdaCard != null) ...[
          const SizedBox(height: AppSpacing.md),
          mdaCard,
        ],
        const SizedBox(height: AppSpacing.md),
        ReportNotesGrid(notes: ov.notes),
      ],
    );
  }

  Widget _balanceSheetChapter(ReportDocument doc) {
    final bs = doc.balanceSheet;
    // T5-R1:合计与资产负债率取 model 派生(构造期算好),渲染层零 fold。
    final assetsTotal = bs.assetsTotalCents;
    final liabTotal = bs.liabilitiesTotalCents;
    final ratio = bs.debtRatioPct;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, c) {
          final composition = <Widget>[
            _SectionCard(
              title: '资产构成 · 期末',
              totalCents: assetsTotal,
              child: CategoryBars(
                rows: bs.assets,
                barColor: context.yucai.accent,
                emptyText: '暂无资产',
              ),
            ),
            _SectionCard(
              title: '负债构成 · 期末',
              totalCents: liabTotal,
              child: Column(
                children: [
                  CategoryBars(
                    rows: bs.liabilities,
                    barColor: context.yucai.negative,
                    emptyText: '暂无负债',
                  ),
                  if (ratio != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.sm),
                      child: Text(
                        '资产负债率 ${ratio.toStringAsFixed(1)}% · 期末负债 / 期末资产',
                        style: TextStyle(
                            fontSize: 12, color: context.yucai.muted),
                      ),
                    ),
                ],
              ),
            ),
          ];
          if (c.maxWidth > 760) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: composition[0]),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: composition[1]),
              ],
            );
          }
          return Column(
            children: [
              composition[0],
              const SizedBox(height: AppSpacing.md),
              composition[1],
            ],
          );
        }),
        const SizedBox(height: AppSpacing.md),
        _ChangesTable(doc: doc),
      ],
    );
  }

  Widget _incomeChapter(ReportDocument doc, String noun) {
    final ist = doc.incomeStatement;
    final incomeTotal = ist.income.fold<int>(0, (s, r) => s + r.amountCents);
    final expenseTotal =
        ist.expense.fold<int>(0, (s, r) => s + r.amountCents);
    final prior = ist.priorComparison;

    final expenseCard = _SectionCard(
      title: '支出分类',
      totalCents: expenseTotal,
      child: CategoryBars(
        rows: ist.expense,
        barColor: context.yucai.negative,
        emptyText: '本期无支出',
      ),
    );
    final incomeCard = _SectionCard(
      title: '收入构成',
      totalCents: incomeTotal,
      child: CategoryBars(
        rows: ist.income,
        barColor: context.yucai.positive,
        amountColor: context.yucai.positive,
        emptyText: '本期无收入',
      ),
    );
    final summaryCard = _SectionCard(
      title: '摘要',
      totalCents: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryLine(label: '日均结余', value: fmtCents(ist.dailyAvgCents)),
          if (prior != null)
            _SummaryLine(
              label: prior.label,
              value: fmtPctSigned(prior.deltaPct),
              valueColor: prior.deltaPct >= 0
                  ? context.yucai.positive
                  : context.yucai.negative,
            )
          else
            Text('首期无对比数据',
                style:
                    TextStyle(fontSize: 13, color: context.yucai.muted)),
        ],
      ),
    );

    return LayoutBuilder(builder: (context, c) {
      if (c.maxWidth > 760) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: expenseCard),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  incomeCard,
                  const SizedBox(height: AppSpacing.md),
                  summaryCard,
                ],
              ),
            ),
          ],
        );
      }
      return Column(
        children: [
          expenseCard,
          const SizedBox(height: AppSpacing.md),
          incomeCard,
          const SizedBox(height: AppSpacing.md),
          summaryCard,
        ],
      );
    });
  }

  Widget _cashFlowChapter(ReportDocument doc) =>
      _SectionCard(title: '三类活动现金流', totalCents: null, child: CashFlowTable(section: doc.cashFlow));

  Widget _budgetChapter(ReportDocument doc) => _SectionCard(
        title: '预算执行 · ${doc.period.label}',
        totalCents: null,
        child: BudgetBars(items: doc.budget!.items),
      );

  Widget _investmentChapter(ReportDocument doc) =>
      PerfCards(section: doc.investment!);
}

/// 章节规格(标题 + 内容;标题同时供章节头与锚点标签)。
class _ChapterSpec {
  const _ChapterSpec(this.title, this.child);
  final String title;
  final Widget child;
}

// ───────────────────────── 顶栏:返回 + 面包屑「报表分析 › 财务报告」

class _ReportTopBar extends StatelessWidget {
  const _ReportTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      color: context.yucai.bg.withValues(alpha: 0.85),
      child: Row(children: [
        IconButton(
          tooltip: '返回',
          icon: Icon(LucideIcons.chevronLeft,
              size: 20, color: context.yucai.fg),
          style: IconButton.styleFrom(
            backgroundColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: context.yucai.accentSoft.withValues(alpha: 0.4),
            padding: EdgeInsets.zero,
            minimumSize: const Size(36, 36),
          ),
          onPressed: () => context.go('/reports'),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text('报表分析',
            style: TextStyle(fontSize: 14, color: context.yucai.muted)),
        const SizedBox(width: 6),
        Icon(LucideIcons.chevronRight, size: 14, color: context.yucai.muted),
        const SizedBox(width: 6),
        Text('财务报告',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.yucai.fg,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback,
            )),
      ]),
    );
  }
}

// ───────────────────────── 页头:标题 + 期控件 + 生成按钮(原型 .page-head)

class _PageHead extends StatelessWidget {
  const _PageHead({
    required this.yearly,
    required this.period,
    required this.generating,
    required this.canExport,
    required this.exporting,
    required this.onScopeChanged,
    required this.onPrev,
    required this.onNext,
    required this.onGenerate,
    required this.onExportFormat,
  });

  final bool yearly;
  final ReportPeriod period;
  final bool generating;

  /// F45 T2:Loaded 态才有可导出文档(否则导出按钮整钮缺席)。
  final bool canExport;

  /// F45 T2:导出进行中(按钮禁用 + spinner)。
  final bool exporting;
  final ValueChanged<bool> onScopeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onGenerate;
  final ValueChanged<ReportExportFormat> onExportFormat;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 760;
      final controls = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModeSegmented(yearly: yearly, onChanged: onScopeChanged),
          const SizedBox(width: AppSpacing.sm),
          _PeriodNav(
            label: period.label,
            onPrev: onPrev,
            onNext: onNext,
          ),
          const SizedBox(width: AppSpacing.sm),
          _GenerateButton(onTap: onGenerate, loading: generating),
          // F45 T2:导出按钮(仅 Loaded;小菜单选格式,桌面单后缀形态)。
          if (canExport) ...[
            const SizedBox(width: AppSpacing.sm),
            _ExportButton(exporting: exporting, onFormat: onExportFormat),
          ],
        ],
      );
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('财务报告',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.yucai.fg,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
              )),
          const SizedBox(height: 4),
          Text('按月或按年,汇编一份完整的个人财务报告',
              style: TextStyle(fontSize: 13, color: context.yucai.muted)),
        ],
      );
      if (wide) {
        return Row(
          children: [
            title,
            const Spacer(),
            controls,
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: AppSpacing.sm),
          controls,
        ],
      );
    });
  }
}

/// 月/年 segmented(pill,照抄 report_page._PeriodSegmented 形态)。
class _ModeSegmented extends StatelessWidget {
  const _ModeSegmented({required this.yearly, required this.onChanged});

  final bool yearly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: context.yucai.bg,
        borderRadius: AppRadius.smBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(context, '月', !yearly, () => onChanged(false)),
          _segment(context, '年', yearly, () => onChanged(true)),
        ],
      ),
    );
  }

  Widget _segment(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? context.yucai.accent : Colors.transparent,
            borderRadius: AppRadius.smBorder,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: selected ? context.yucai.onAccent : context.yucai.muted,
            ),
          ),
        ),
      ),
    );
  }
}

/// 上一期/下一期 + 期标签(原型 .period-nav;图标钮照顶栏返回形态)。
class _PeriodNav extends StatelessWidget {
  const _PeriodNav(
      {required this.label, required this.onPrev, required this.onNext});

  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _arrow(context, LucideIcons.chevronLeft, '上一期', onPrev),
        SizedBox(
          width: 110,
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: context.yucai.fg,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
                fontFeatures: AppTypography.tabularFigures,
              )),
        ),
        _arrow(context, LucideIcons.chevronRight, '下一期', onNext),
      ],
    );
  }

  Widget _arrow(
      BuildContext context, IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: 18, color: context.yucai.muted),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: context.yucai.accentSoft.withValues(alpha: 0.4),
        padding: EdgeInsets.zero,
        minimumSize: const Size(32, 32),
      ),
      onPressed: onTap,
    );
  }
}

/// 「生成报告」主按钮(原型 .btn-primary:accent 底 + onAccent 字)。
/// 页头主按钮 key = generateReportButton;引导卡内副本由调用方换 key。
class _GenerateButton extends StatelessWidget {
  const _GenerateButton(
      {required this.onTap, required this.loading, this.buttonKey});

  final VoidCallback onTap;
  final bool loading;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: MouseRegion(
        cursor: loading ? SystemMouseCursors.basic : SystemMouseCursors.click,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 140),
          opacity: loading ? 0.55 : 1,
          child: Container(
            key: buttonKey ?? const ValueKey('generateReportButton'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: context.yucai.accent,
              borderRadius: AppRadius.smBorder,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.fileText,
                    size: 15, color: context.yucai.onAccent),
                const SizedBox(width: 6),
                Text('生成报告',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.yucai.onAccent,
                    )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// F45 T2「导出」按钮(次级形态:surface 底 + border;仅 Loaded 渲染)。
/// 小菜单选格式(PDF/Markdown)→ 再弹保存对话框(桌面单后缀形态:
/// 格式切换在菜单先行,对话框锁定单扩展名);导出中禁用 + spinner。
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.exporting, required this.onFormat});

  final bool exporting;
  final ValueChanged<ReportExportFormat> onFormat;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ReportExportFormat>(
      key: const ValueKey('reportExportButton'),
      tooltip: '导出报告',
      enabled: !exporting, // 导出中禁用:菜单不再弹。
      onSelected: onFormat,
      itemBuilder: (_) => const [
        PopupMenuItem(
          key: ValueKey('reportExportFormatPdf'),
          value: ReportExportFormat.pdf,
          child: Text('PDF'),
        ),
        PopupMenuItem(
          key: ValueKey('reportExportFormatMarkdown'),
          value: ReportExportFormat.markdown,
          child: Text('Markdown'),
        ),
      ],
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 140),
        opacity: exporting ? 0.55 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: context.yucai.surface,
            borderRadius: AppRadius.smBorder,
            border: Border.all(color: context.yucai.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 导出中:spinner 顶替下载图标(_GenerateButton loading 同构)。
              if (exporting)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: context.yucai.accent),
                )
              else
                Icon(LucideIcons.download, size: 15, color: context.yucai.fg),
              const SizedBox(width: 6),
              Text('导出',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.fg,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── gen-zone:Initial 引导 / 进度 / 错误
/// 生成区(原型 .gen-zone):固定最小高度防跳动;[detail] = >300ms 门后
/// 的四阶段步进展开(FR-8);Loaded → 收起(SizedBox.shrink)交棒报告体。
class _GenZone extends StatelessWidget {
  const _GenZone({
    required this.state,
    required this.onGenerate,
    required this.detail,
  });

  final FinancialReportState state;
  final VoidCallback onGenerate;
  final bool detail;

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (state is FinancialReportLoading) {
      child = detail
          ? _ProgressCard(state: state as FinancialReportLoading)
          : const _ProgressCompactHint();
    } else if (state is FinancialReportError) {
      child = _ErrorCard(message: (state as FinancialReportError).message);
    } else if (state is FinancialReportInitial) {
      child = _IdleCard(onGenerate: onGenerate);
    } else {
      return const SizedBox.shrink();
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      alignment: Alignment.topCenter,
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

/// Initial 引导卡(原型 .gen-idle):说明 + 卡内次级生成按钮。
class _IdleCard extends StatelessWidget {
  const _IdleCard({required this.onGenerate});

  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    return _ZoneCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('报告尚未生成',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: context.yucai.fg,
              )),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '选择报告期后点击「生成报告」,将读取账本、回放余额、汇编章节并计算绩效,生成六章节完整报告。',
            style: TextStyle(fontSize: 12.5, color: context.yucai.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerLeft,
            child: _GenerateButton(
              onTap: onGenerate,
              loading: false,
              buttonKey: const ValueKey('generateReportIdleButton'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 紧凑生成提示(<300ms 阶段:不闪步进,仅一行轻提示,等高防跳)。
class _ProgressCompactHint extends StatelessWidget {
  const _ProgressCompactHint();

  @override
  Widget build(BuildContext context) {
    return _ZoneCard(
      minimumHeight: 132,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: context.yucai.accent),
          ),
          const SizedBox(width: 10),
          Text('正在生成报告…',
              style: TextStyle(fontSize: 13, color: context.yucai.muted)),
        ],
      ),
    );
  }
}

/// 错误卡(FR-8 scenario 3):固定中文文案 + 「重试」(→ RetryRequested,
/// bloc 取 Error 态报告期重生成同报告)。
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _ZoneCard(
      child: Row(
        children: [
          Icon(LucideIcons.circleAlert,
              size: 20, color: context.yucai.negative),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(message,
                style: TextStyle(fontSize: 13.5, color: context.yucai.fg)),
          ),
          const SizedBox(width: AppSpacing.sm),
          TextButton(
            key: const ValueKey('reportRetryButton'),
            onPressed: () => context
                .read<FinancialReportBloc>()
                .add(const RetryRequested()),
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 四阶段步进卡(原型 .gen-prog:标题行「正在生成 · 阶段」+ n/4 chip +
/// 步进行;当前=accent 高亮,完成=accent 实心打勾,未至=描边序号)。
/// 不用无限脉冲动画——保 pumpAndSettle 可收敛(测试确定性优先)。
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.state});

  final FinancialReportLoading state;

  static const _names = ['读取账本', '回放余额', '汇编章节', '计算绩效'];

  @override
  Widget build(BuildContext context) {
    final index = state.phase.index;
    return _ZoneCard(
      minimumHeight: 132,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text.rich(TextSpan(
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.yucai.muted),
                  children: [
                    const TextSpan(text: '正在生成 · '),
                    TextSpan(
                      text: _names[index.clamp(0, _names.length - 1)],
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: context.yucai.fg),
                    ),
                  ],
                )),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: context.yucai.accentSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${index + 1}/4',
                  key: const ValueKey('reportProgressStepNo'),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.accentDeep,
                    fontFeatures: AppTypography.tabularFigures,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              for (var i = 0; i < _names.length; i++)
                Expanded(
                  child: _Step(
                    no: i + 1,
                    name: _names[i],
                    state: i < index
                        ? _StepState.done
                        : (i == index ? _StepState.current : _StepState.todo),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _StepState { todo, current, done }

class _Step extends StatelessWidget {
  const _Step({
    required this.no,
    required this.name,
    required this.state,
  });

  final int no;
  final String name;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final done = state == _StepState.done;
    final current = state == _StepState.current;
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? context.yucai.accent : Colors.transparent,
            border: Border.all(
              color: done || current
                  ? context.yucai.accent
                  : context.yucai.border,
              width: 2,
            ),
          ),
          child: done
              ? Icon(LucideIcons.check,
                  size: 14, color: context.yucai.onAccent)
              : Center(
                  child: Text(
                    '$no',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          current ? context.yucai.accent : context.yucai.muted,
                      fontFeatures: AppTypography.tabularFigures,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: done || current ? FontWeight.w600 : FontWeight.w400,
            color: done || current ? context.yucai.fg : context.yucai.muted,
          ),
        ),
      ],
    );
  }
}

/// 章节头(原型 .ch-head:序号 chip + 标题 + 尾部分隔线)。
class _ChapterHead extends StatelessWidget {
  const _ChapterHead({required this.no, required this.title});

  final String no;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: context.yucai.accentSoft,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            no,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: context.yucai.accentDeep,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: context.yucai.fg,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback,
            )),
        const SizedBox(width: 10),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }
}

/// 通用章节卡(标题 + 可选合计 chip + 内容;原型 .card 内 .card-head)。
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, this.totalCents, required this.child});

  final String title;
  final int? totalCents;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: context.yucai.fg,
                  )),
              const Spacer(),
              if (totalCents != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('合计 ',
                        style: TextStyle(
                            fontSize: 11.5, color: context.yucai.muted)),
                    Text(fmtCents(totalCents!),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.yucai.muted,
                          fontFeatures: AppTypography.tabularFigures,
                        )),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(height: 1, color: context.yucai.border),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

/// 总览四卡条(收入/支出/结余/储蓄率;原型 .sum-strip.four)。
class _MetricStrip extends StatelessWidget {
  const _MetricStrip({
    required this.noun,
    required this.periodNoun,
    required this.overview,
    required this.incomeCount,
    required this.expenseCount,
  });

  final String noun;
  final String periodNoun;
  final OverviewSection overview;
  final int incomeCount;
  final int expenseCount;

  @override
  Widget build(BuildContext context) {
    final surplusColor = overview.surplusCents >= 0
        ? context.yucai.positive
        : context.yucai.negative;
    final cards = <Widget>[
      _MetricCard(
        label: '$noun收入',
        chip: periodNoun == '年度' ? '年度' : '月口径',
        value: fmtCents(overview.incomeCents),
        valueColor: context.yucai.positive,
        foot: '共 $incomeCount 个收入科目',
      ),
      _MetricCard(
        label: '$noun支出',
        chip: '$expenseCount 大类',
        value: fmtCents(overview.expenseCents),
        foot: '= Σ支出科目(现金口径)',
      ),
      _MetricCard(
        label: '$noun结余',
        chip: '= 收入 − 支出',
        value: fmtCentsSigned(overview.surplusCents),
        valueColor: surplusColor,
        foot: '结余率 ${overview.savingsRate.toStringAsFixed(1)}%',
      ),
      _MetricCard(
        label: '储蓄率',
        chip: periodNoun,
        value: '${overview.savingsRate.toStringAsFixed(1)}%',
        valueColor: overview.savingsRate >= 0
            ? context.yucai.positive
            : context.yucai.negative,
        foot: '结余 ${fmtCentsSigned(overview.surplusCents)} / 收入 '
            '${fmtCents(overview.incomeCents)}',
      ),
    ];
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth > 760;
      if (wide) {
        return Row(
          children: [
            for (var i = 0; i < cards.length; i++) ...[
              Expanded(child: cards[i]),
              if (i < cards.length - 1) const SizedBox(width: AppSpacing.md),
            ],
          ],
        );
      }
      return Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.md,
        children: [for (final card in cards) SizedBox(width: 260, child: card)],
      );
    });
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.chip,
    required this.value,
    required this.foot,
    this.valueColor,
  });

  final String label;
  final String chip;
  final String value;
  final String foot;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: context.yucai.muted,
                  )),
              const Spacer(),
              Text(chip,
                  style: TextStyle(
                      fontSize: 11, color: context.yucai.muted)),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: valueColor ?? context.yucai.fg,
                letterSpacing: -0.3,
                fontFamily: AppTypography.displayFamily,
                fontFamilyFallback: AppTypography.displayFallback,
                fontFeatures: AppTypography.tabularFigures,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(foot,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: context.yucai.muted)),
        ],
      ),
    );
  }
}

/// 现金及等价物净变动 slim 卡(原型 .cash-slim)。
class _CashSlimCard extends StatelessWidget {
  const _CashSlimCard({required this.deltaCents});

  final int deltaCents;

  @override
  Widget build(BuildContext context) {
    final color =
        deltaCents >= 0 ? context.yucai.positive : context.yucai.negative;
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 14),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('现金及等价物净变动',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.yucai.fg,
                    )),
                const SizedBox(height: 2),
                Text('经营 + 投资 + 融资 三类活动净额',
                    style: TextStyle(
                        fontSize: 12, color: context.yucai.muted)),
              ],
            ),
          ),
          Text(
            fmtCentsSigned(deltaCents),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
              fontFamily: AppTypography.displayFamily,
              fontFamilyFallback: AppTypography.displayFallback,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

/// 期初 → 期末 变动表(原型 .mv-table):净资产汇总行 + 分类变动行。
class _ChangesTable extends StatelessWidget {
  const _ChangesTable({required this.doc});

  final ReportDocument doc;

  @override
  Widget build(BuildContext context) {
    final ov = doc.overview;
    return _SectionCard(
      title: '期初 → 期末 变动',
      totalCents: null,
      child: Column(
        children: [
          _head(context),
          _row(
            context,
            label: '净资产',
            start: ov.netWorthStartCents,
            end: ov.netWorthEndCents,
            strong: true,
          ),
          for (final change in doc.balanceSheet.changes)
            _row(
              context,
              label: categoryLabelOf(change.category),
              start: change.startCents,
              end: change.endCents,
              delta: change.deltaCents, // T5-R1:model 派生,不重算
            ),
        ],
      ),
    );
  }

  Widget _head(BuildContext context) => _grid(
        context,
        Row(children: [
          Expanded(child: _label(context, '项目', header: true)),
          Expanded(child: _num(context, '期初', header: true)),
          Expanded(child: _num(context, '期末', header: true)),
          Expanded(child: _num(context, '变动', header: true)),
        ]),
      );

  Widget _row(
    BuildContext context, {
    required String label,
    required int start,
    required int end,
    int? delta, // 缺省 = 净资产汇总行(OverviewSection 无 delta 派生,现算)
    bool strong = false,
  }) {
    final d = delta ?? end - start;
    return _grid(
      context,
      Row(children: [
        Expanded(child: _label(context, label, strong: strong)),
        Expanded(child: _num(context, fmtCents(start))),
        Expanded(child: _num(context, fmtCents(end))),
        Expanded(
          child: _num(
            context,
            fmtCentsSigned(d),
            color: d >= 0 ? context.yucai.positive : context.yucai.negative,
          ),
        ),
      ]),
    );
  }

  Widget _grid(BuildContext context, Widget row) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: row,
      );

  Widget _label(BuildContext context, String text,
          {bool header = false, bool strong = false}) =>
      Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: header || strong ? FontWeight.w600 : FontWeight.w500,
          color: header ? context.yucai.muted : context.yucai.fg,
        ),
      );

  Widget _num(BuildContext context, String text,
      {bool header = false, Color? color}) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: header ? context.yucai.muted : (color ?? context.yucai.fg),
        fontFeatures: AppTypography.tabularFigures,
      ),
    );
  }
}

/// 摘要行(label + value 着色)。
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(label,
              style: TextStyle(fontSize: 13, color: context.yucai.muted)),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? context.yucai.fg,
            fontFeatures: AppTypography.tabularFigures,
          ),
        ),
      ],
    );
  }
}

/// gen-zone 卡片壳(surface 底 + border + 圆角 + 可选最小高度防跳)。
class _ZoneCard extends StatelessWidget {
  const _ZoneCard({required this.child, this.minimumHeight});

  final Widget child;
  final double? minimumHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: minimumHeight == null
          ? null
          : BoxConstraints(minHeight: minimumHeight!),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: child,
    );
  }
}
