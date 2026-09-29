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
      if (period.contains(e.date)) {
        byTxn.putIfAbsent(e.transactionId, () => []).add(e);
      }
    }

    final inflow = <_Activity, int>{};
    final outflow = <_Activity, int>{};
    // 明细列数据源(视觉对齐批次 2026-09-29):投资/融资活动的对手分类
    // 净额聚合(category → signed contribution)。经营对手 = 收支科目,
    // category 无语义,不聚合(明细走矩阵语义文案,见 cashflow_table)。
    final counterparties = <_Activity, Map<String, int>>{};
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
        if (activity != _Activity.operating) {
          final byCat = counterparties.putIfAbsent(activity, () => {});
          final key = cp.category ?? '未分类';
          byCat[key] = (byCat[key] ?? 0) + contribution;
        }
      }
    }

    final operating = _flow(_Activity.operating, inflow, outflow, counterparties);
    final investing = _flow(_Activity.investing, inflow, outflow, counterparties);
    final financing = _flow(_Activity.financing, inflow, outflow, counterparties);
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

  /// 现金账户判定(单一事实源,严格口径 spec Grill #2):**type 1(资产)
  /// 且 savings 账类** 的账户。
  ///
  /// 汇编服务的现金余额求和与本分类器的分录分类共用本谓词——两处口径
  /// 漂移会直接打穿勾稽不变式(netDelta≠Δcash → StateError 炸整份报告;
  /// 典型异常数据:income 科目被误挂 savings 账类,若只看 category 会被
  /// 当作现金侧抵消)。
  static bool isCashAccount(int accountType, String? category) =>
      accountType == 1 && category == 'savings';

  /// 分录所属账户是否现金(经 [isCashAccount] 单点判定)。
  static bool _isCash(LedgerEntryRow e) =>
      isCashAccount(e.accountType, e.category);

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
    Map<_Activity, Map<String, int>> counterparties,
  ) =>
      ActivityFlow.create(
        inflowCents: inflow[activity] ?? 0,
        outflowCents: outflow[activity] ?? 0,
        counterpartyCents:
            Map.unmodifiable(counterparties[activity] ?? const {}),
      );
}
