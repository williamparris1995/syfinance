// F65-T1 —— performance_range 只读工具(FR-2,报告口径区间绩效)。
//
// 入口形态(摸底结论):F43 汇编器(ReportAssemblyService)的区间计算
// 入口 = HoldingRepository.getPortfolioPerformance 的显式 rangeStart/
// rangeEnd 参数(_fetchPerformance 同款调用;repo 三态路由对显式区间
// **强制走本地引擎**,T2/T3 拍板)→ PortfolioPerformance.period
// (PeriodPerformance:期初/期末市值/净买入/估算收益/区间 TWR)。
// ReportAssemblyService.generate 本身只收自然月/年 ReportPeriod 且产
// 整份文档,不适配任意 {start,end} 窗口 —— 工具遂直连汇编器同款区间
// 入口(报告口径单一事实源),不复制计算。
//
// 输出:区间日期回显 + 期初/期末市值/净买入/估算收益(cents+元双口径)
// + 区间 TWR(累计 %)+ 口径说明字段。坏价/取数失败(period=null /
// Left)→ 自纠 ToolError;窗内三点全零 = 报告「本期无持仓」同语义 →
// 如实零值 + note,不编造。缺省窗口 = 年初至今(start=1月1日,
// end=今天;半缺省:start-only → 至今;end-only → 该年 1 月 1 日起)。
// 口径断言 = 与报告页同区间输出逐分一致(F43 既有测试 oracle 取数,
// tools_caliber_test 钉死,NFR-1)。
library;

import 'package:yucai_client/assistant/data/tools/tool_args.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/holding/domain/entities/performance_entity.dart';
import 'package:yucai_client/holding/domain/repositories/holding_repository.dart';

/// 区间绩效工具:F43 报告口径(期初/期末市值/净买入/估算收益/区间 TWR)。
class PerformanceRangeTool implements AssistantTool {
  PerformanceRangeTool(this._holdings, [this._clock]);

  final HoldingRepository _holdings;

  /// 「今天」缝(缺省窗口锚点;测试注入)。
  final DateTime Function()? _clock;

  @override
  String get name => 'performance_range';

  @override
  String get description =>
      'Portfolio performance for a date range, same caliber as the '
      'financial report investment section: beginning/ending market value, '
      'net buy (buys minus sells), estimated gain (end - begin - net buy) '
      'and cumulative time-weighted return (TWR) percent for the window. '
      'Values are replayed from trade prices (forward-fill), in CNY. '
      'Defaults to year-to-date (Jan 1 to today). Use for "how much did my '
      'investments return this year / between two dates". Not for '
      'single-holding detail or realized/unrealized split (use '
      'holdings_list).';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': {
          'start': {
            'type': 'string',
            'description':
                'Inclusive window start, ISO date YYYY-MM-DD '
                '(default Jan 1 of this year).',
          },
          'end': {
            'type': 'string',
            'description':
                'Inclusive window end, ISO date YYYY-MM-DD '
                '(default today).',
          },
        },
      };

  @override
  Future<ToolResult> execute(Map<String, Object> args) async {
    // ── 窗口解析(缺省年初至今;语义非法 → 自纠 ToolError)──
    final startRaw = lenientString(args['start']);
    final endRaw = lenientString(args['end']);
    DateTime? start;
    DateTime? end;
    if (startRaw != null) {
      start = DateTime.tryParse(startRaw);
      if (start == null) {
        return ToolError(
          'invalid start "$startRaw"; expected an ISO date like 2026-01-01',
        );
      }
    }
    if (endRaw != null) {
      end = DateTime.tryParse(endRaw);
      if (end == null) {
        return ToolError(
          'invalid end "$endRaw"; expected an ISO date like 2026-12-31',
        );
      }
    }
    final now = _clock?.call() ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    start ??= DateTime(end?.year ?? now.year, 1, 1);
    end ??= today;
    if (start.isAfter(end)) {
      return const ToolError('start is after end; swap the two dates and retry');
    }

    // ── F43 汇编器同款区间入口(显式区间 → 强制本地引擎;range 占位值
    //    不参与计算,与 ReportAssemblyService._fetchPerformance 逐字同款)──
    final result = await _holdings.getPortfolioPerformance(
      range: 'YEAR',
      baseCurrency: 'CNY',
      rangeStart: start,
      rangeEnd: end,
    );
    final perf = result.fold<PortfolioPerformance?>(
      (l) => null,
      (r) => r,
    );
    if (perf == null || perf.period == null) {
      // Left(取数失败)与坏价降级(period=null,报告隐藏投资章节同因)
      // 共用自纠消息 —— 文案细分记 backlog(镜像 F43 注释)。
      return const ToolError(
        'portfolio range performance is unavailable for this window '
        '(load failure or missing price data); suggest asking about '
        'holdings or net worth instead',
      );
    }
    final period = perf.period!;

    final noPosition = period.beginMvCents == 0 &&
        period.endMvCents == 0 &&
        period.netBuyCents == 0;

    return ToolData({
      'start': _isoDate(start),
      'end': _isoDate(end),
      'currency': perf.currency,
      'beginMvCents': period.beginMvCents,
      'beginMvYuan': yuan(period.beginMvCents),
      'endMvCents': period.endMvCents,
      'endMvYuan': yuan(period.endMvCents),
      'netBuyCents': period.netBuyCents,
      'netBuyYuan': yuan(period.netBuyCents),
      'estimatedGainCents': period.estimatedGainCents,
      'estimatedGainYuan': yuan(period.estimatedGainCents),
      // TWR null(数据降级)→ 字段缺席,不写 null 占位(LLM 见 absence)。
      if (period.twrPct != null) 'twrPct': period.twrPct!,
      'caliber': 'financial-report caliber: quantities replayed at trade '
          'prices (forward-fill), same source as the report investment '
          'section; TWR is the cumulative time-weighted return for the '
          'window (not annualized)',
      if (noPosition)
        'note': 'no position during this window (the report hides the '
            'investment section for such windows)',
    });
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
