/// F46 LLM 分析师 —— 脱敏聚合包构造(FR-2/ADR-4)。
///
/// 纯函数(零 IO):ReportDocument + MdaSection + LlmConfig → 结构化
/// Map,出口直接 [jsonEncode](llm_prompt user 消息)。字段照 design LLD;
/// 金额一律 mdaCny 口径(元两位小数字符串,「¥1,234.56」式)。
///
/// **负面清单(隐私红线,spec FR-2 排除项)**:
/// - accountId:收支构成的 [CategoryAmount.category] 是科目账户 id,
///   payload 只取展示名 [CategoryAmount.name](T5-R1 契约恒非空);
/// - 资产负债构成(账类代码+账户名)整段不进 payload(只带净资产三点);
/// - 交易描述:R5 finding 的 conclusion 内嵌交易描述且**无开关**,
///   整条排除(fail-closed:无法从自由文本外科摘除,宁缺勿泄);
/// - 模板名(订阅名):R4 finding 的 conclusion 以「订阅:名=月度等价」
///   粒度内嵌模板名,[LlmConfig.includeNames] 关闭时整条排除,开启时
///   原样放行(用户选择加入)。
///
/// 设计偏差记录:design LLD 的独立 `subscriptions?[]` 字段无法实现 ——
/// MdaNarrator port 只送 (doc, findings),模板行不跨缝;订阅名语义由
/// R4 finding 的 includeNames 两态承载(见上)。
library;

import 'package:yucai_client/core/llm/llm_settings.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// 构造脱敏聚合包(design LLD 字段逐条)。
Map<String, Object?> sanitizedPayload(
  ReportDocument doc,
  MdaSection mda,
  LlmConfig cfg,
) {
  return {
    'period': doc.period.label,
    'netWorth': {
      'start': mdaCny(doc.overview.netWorthStartCents),
      'end': mdaCny(doc.overview.netWorthEndCents),
      'changePct': doc.overview.netWorthChangePct,
    },
    'savingsRate': doc.overview.savingsRate,
    'income': _breakdown(
      doc.overview.incomeCents, doc.incomeStatement.income),
    'expense': _breakdown(
      doc.overview.expenseCents, doc.incomeStatement.expense),
    'cashFlow': {
      'operating': mdaCny(doc.cashFlow.operating.netCents),
      'investing': mdaCny(doc.cashFlow.investing.netCents),
      'financing': mdaCny(doc.cashFlow.financing.netCents),
    },
    'budget': {
      'items': [
        for (final item in doc.budget?.items ?? const <ReportBudgetItem>[])
          {
            'name': item.name,
            'actual': mdaCny(item.actualCents),
            'limit': mdaCny(item.limitCents),
            'pct': item.pct,
          },
      ],
    },
    if (doc.investment != null)
      'investment': {
        'mvStart': mdaCny(doc.investment!.mvStartCents),
        'mvEnd': mdaCny(doc.investment!.mvEndCents),
        'netBuy': mdaCny(doc.investment!.netBuyCents),
        'estGain': mdaCny(doc.investment!.estGainCents),
        'twrPct': doc.investment!.twr,
      },
    'findings': [
      for (final f in mda.findings)
        if (_findingAllowed(f, cfg, doc))
          {
            'severity': f.severity.name,
            'conclusion': f.conclusion,
            'advice': f.advice,
          },
    ],
    'cityTier': cfg.cityTier.label,
  };
}

/// 收支构成 → {total, byCategory[{name, amount, pct}]}。
///
/// total 取 overview 口径的期合计(与净资产/储蓄率同源,不重算行和);
/// 只取展示名(name 恒非空,T5-R1;防御性兜底占位,绝不回落 category
/// ——那是科目账户 id,负面清单第一项)。
Map<String, Object?> _breakdown(int totalCents, List<CategoryAmount> rows) => {
      'total': mdaCny(totalCents),
      'byCategory': [
        for (final r in rows)
          {
            'name': r.name?.trim().isNotEmpty == true ? r.name : '(未命名科目)',
            'amount': mdaCny(r.amountCents),
            'pct': r.pct,
          },
      ],
    };

/// 负面清单过滤:
/// - R5(交易描述内嵌)恒排除——无开关红线;
/// - R4(模板名内嵌)仅 includeNames 开启时放行;
/// - H1/H2(conclusion 在科目 name null/空时回退内嵌 category=
///   科目账户 id)——expense 构成任一行缺名即整条门禁(fail-closed,
///   评审 R1 Important:无法从自由文本外科摘除,宁缺勿泄);
/// - 其余规则结论只含数字与科目名,安全。
bool _findingAllowed(MdaFinding f, LlmConfig cfg, ReportDocument doc) =>
    switch (f.ruleId) {
      'R5' => false,
      'R4' => cfg.includeNames,
      'H1' || 'H2' => _expenseNamesComplete(doc),
      _ => true,
    };

/// expense 构成全部行都带非空展示名(H1/H2 放行前置)。
bool _expenseNamesComplete(ReportDocument doc) =>
    doc.incomeStatement.expense
        .every((r) => r.name != null && r.name!.trim().isNotEmpty);
