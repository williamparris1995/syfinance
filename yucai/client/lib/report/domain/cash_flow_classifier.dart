/// F43 财务报告 —— 现金流分类器(表驱动规则矩阵,FR-5/ADR-4)。
///
/// 现金 = 仅 savings 类账户(严格口径);对手方归类:
/// - income(4)/expense(5) 科目 → 经营;
/// - 投资类资产 category ∈ {investment, fixedDeposit, goldFx,
///   storedValue, realEstate, otherAsset} → 投资;
/// - 负债(2)/权益(3) → 融资;
/// - 现金↔现金 → 内部抵消不计;非现金×非现金(如储值卡消费)→ 不计。
///
/// 配对方式:按 transactionId 分组一条交易的借贷双方(设计如此)——
/// 「现金科目条目 + 对手条目」在同一组内配对,不依赖分录行的冗余对手
/// 字段。金额归属:对手条目对现金的贡献 = credit − debit(复式记账
/// 借贷平衡的镜像,正=现金流入、负=流出),对拆分多对手交易同样精确。
///
/// 勾稽不变式(spec FR-5):三类净额之和 == 期末现金 − 期初现金,
/// 不等抛 [StateError](消息含两侧数值)——期初/期末现金由调用方经
/// BalanceReplay 对 savings 账户求和后传入。
library;

import 'package:yucai_client/report/domain/report_document.dart';
import 'package:yucai_client/report/domain/report_ledger_store.dart';

/// 三类活动代号(矩阵输出维)。
enum _Activity { operating, investing, financing }

/// 现金流分类器:无状态纯函数。
class CashFlowClassifier {
  const CashFlowClassifier();

  /// 对报告期 [period] 内的分录做现金流分类,返回现金流章节。
  ///
  /// [cashStartCents]/[cashEndCents] = 期初/期末现金余额(Σ savings
  /// 账户,回放口径),仅用于勾稽 assert;分类本身只看期内分录。
  CashFlowSection classify({
    required List<LedgerEntryRow> entries,
    required ReportPeriod period,
    required int cashStartCents,
    required int cashEndCents,
  }) {
    // 按 transactionId 分组(保持组内对手遍历顺序稳定即可)。
    final byTxn = <String, List<LedgerEntryRow>>{};
    for (final e in entries) {
      final inPeriod = !e.date.isBefore(period.start) &&
          !e.date.isAfter(period.endInclusive);
      if (inPeriod) {
        byTxn.putIfAbsent(e.transactionId, () => []).add(e);
      }
    }

    final inflow = <_Activity, int>{};
    final outflow = <_Activity, int>{};
    for (final group in byTxn.values) {
      final hasCash = group.any((e) => _isCash(e));
      // 非现金×非现金 → 整笔不计(如储值卡消费)。
      if (!hasCash) continue;
      for (final cp in group) {
        if (_isCash(cp)) continue; // 现金↔现金部分内部抵消,不产生活动流
        final activity = _counterpartyActivity(cp);
        if (activity == null) continue; // 未知对手类型 → 不计(勾稽会兜底)
        // 对手条目镜像贡献:credit−debit,正=现金流入、负=流出。
        final contribution = cp.creditCents - cp.debitCents;
        if (contribution >= 0) {
          inflow[activity] = (inflow[activity] ?? 0) + contribution;
        } else {
          outflow[activity] = (outflow[activity] ?? 0) - contribution;
        }
      }
    }

    final operating = _flow(_Activity.operating, inflow, outflow);
    final investing = _flow(_Activity.investing, inflow, outflow);
    final financing = _flow(_Activity.financing, inflow, outflow);
    final netDelta =
        operating.netCents + investing.netCents + financing.netCents;

    // 勾稽不变式(ADR-4):三类净额之和 == 期末现金 − 期初现金。
    final cashDelta = cashEndCents - cashStartCents;
    if (netDelta != cashDelta) {
      throw StateError(
        '现金流勾稽失败:三类活动净额之和 $netDelta ≠ 期末−期初现金 '
        '$cashDelta(期初 $cashStartCents / 期末 $cashEndCents)',
      );
    }

    return CashFlowSection(
      operating: operating,
      investing: investing,
      financing: financing,
      netDeltaCents: netDelta,
      reconciled: true,
    );
  }

  /// 现金判定:仅 savings 类账户(严格口径,spec Grill #2)。
  static bool _isCash(LedgerEntryRow e) => e.category == 'savings';

  /// 对手条目 → 活动归类(矩阵唯一事实源)。
  ///
  /// 类型 1(资产)非 savings 的 category 恰为六个投资类代码的全体,
  /// 故按类型路由等价于按矩阵逐项匹配,且对 category 缺失行稳健。
  static _Activity? _counterpartyActivity(LedgerEntryRow cp) {
    switch (cp.accountType) {
      case 4: // income
      case 5: // expense
        return _Activity.operating;
      case 2: // liability
      case 3: // equity
        return _Activity.financing;
      case 1: // asset:非现金资产 = 投资类(六 category 全集)
        return _isCash(cp) ? null : _Activity.investing;
      default:
        return null;
    }
  }

  /// 由累计流入/流出构造单类活动流(net 在 factory 内算)。
  static ActivityFlow _flow(
    _Activity activity,
    Map<_Activity, int> inflow,
    Map<_Activity, int> outflow,
  ) =>
      ActivityFlow.create(
        inflowCents: inflow[activity] ?? 0,
        outflowCents: outflow[activity] ?? 0,
      );
}
