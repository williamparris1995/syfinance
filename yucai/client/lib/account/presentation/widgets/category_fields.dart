import 'package:flutter/material.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/amount_input.dart';
import 'package:yucai_client/core/widgets/date_picker_input.dart';
import 'package:yucai_client/core/widgets/form_section.dart';
import 'package:yucai_client/debt/domain/debt_query.dart';
import 'package:yucai_client/holding/domain/holding_query.dart';

/// 按 category 渲染的专属字段 controllers 集合。
/// 主金额统一进 primaryCentsCtrl（label 随 category），_submit 按 category 映射到
/// InvestCostCents/FixedPrincipalCents/GoldBuyPriceCents/EstatePurchasePriceCents/
/// LoanRemainingCents/InitialBalanceCents。
/// interestRateCtrl 多义：储蓄/定期/贷款/信用卡→InterestRate，投资→InvestReturnYtd，
/// 固定资产→EstateDepreciationRate。
class CategoryFieldBundle {
  CategoryFieldBundle()
      : primaryCentsCtrl = TextEditingController(text: '0'),
        institutionCtrl = TextEditingController(),
        cardNumberTailCtrl = TextEditingController(),
        interestRateCtrl = TextEditingController(),
        creditBillingDayCtrl = TextEditingController(),
        creditRepaymentDayCtrl = TextEditingController(),
        creditLimitCtrl = TextEditingController(),
        creditAnnualFeeCtrl = TextEditingController(),
        investMarketValueCtrl = TextEditingController(),
        fixedTermMonthsCtrl = TextEditingController(),
        goldProductTypeCtrl = TextEditingController(),
        goldQuantityCtrl = TextEditingController(),
        goldCurrentPriceCtrl = TextEditingController(),
        estateCurrentValueCtrl = TextEditingController(),
        loanOriginalCtrl = TextEditingController(),
        loanMonthlyCtrl = TextEditingController();

  final TextEditingController primaryCentsCtrl;
  final TextEditingController institutionCtrl;
  final TextEditingController cardNumberTailCtrl;
  final TextEditingController interestRateCtrl; // 利率/APR/收益率/折旧率（多义）
  final TextEditingController creditBillingDayCtrl;
  final TextEditingController creditRepaymentDayCtrl;
  final TextEditingController creditLimitCtrl;
  final TextEditingController creditAnnualFeeCtrl;
  final TextEditingController investMarketValueCtrl;
  final TextEditingController fixedTermMonthsCtrl;
  final TextEditingController goldProductTypeCtrl;
  final TextEditingController goldQuantityCtrl;
  final TextEditingController goldCurrentPriceCtrl;
  final TextEditingController estateCurrentValueCtrl;
  final TextEditingController loanOriginalCtrl;
  final TextEditingController loanMonthlyCtrl;

  // 日期值由 DatePickerInput（FormField<DateTime>）的 onSaved 收集到这里，
  // _submit 时读 bundle.<dateField>。编辑预填由 categoryFieldsWidget 的
  // initialValue 注入。
  DateTime? openingDate; // 储蓄开户日期
  DateTime? fixedStartDate; // 定期起息日
  DateTime? fixedMaturityDate; // 定期到期日
  DateTime? estatePurchaseDate; // 固定资产买入日期
  DateTime? loanNextPaymentDate; // 贷款下次还款日

  void dispose() {
    for (final c in [
      primaryCentsCtrl,
      institutionCtrl,
      cardNumberTailCtrl,
      interestRateCtrl,
      creditBillingDayCtrl,
      creditRepaymentDayCtrl,
      creditLimitCtrl,
      creditAnnualFeeCtrl,
      investMarketValueCtrl,
      fixedTermMonthsCtrl,
      goldProductTypeCtrl,
      goldQuantityCtrl,
      goldCurrentPriceCtrl,
      estateCurrentValueCtrl,
      loanOriginalCtrl,
      loanMonthlyCtrl,
    ]) {
      c.dispose();
    }
  }

  /// 清空所有 controller + 日期字段（切 category 时调用）。
  void clearAll() {
    primaryCentsCtrl.text = '0';
    for (final c in [
      institutionCtrl,
      cardNumberTailCtrl,
      interestRateCtrl,
      creditBillingDayCtrl,
      creditRepaymentDayCtrl,
      creditLimitCtrl,
      creditAnnualFeeCtrl,
      investMarketValueCtrl,
      fixedTermMonthsCtrl,
      goldProductTypeCtrl,
      goldQuantityCtrl,
      goldCurrentPriceCtrl,
      estateCurrentValueCtrl,
      loanOriginalCtrl,
      loanMonthlyCtrl,
    ]) {
      c.clear();
    }
    openingDate = null;
    fixedStartDate = null;
    fixedMaturityDate = null;
    estatePurchaseDate = null;
    loanNextPaymentDate = null;
  }
}

/// 货币代码 → 符号（AmountInput 前缀用）。未知代码兜底 ¥（同 CNY）。
/// 切币种时 FormPage 传 currencySymbolOf(_currency) 给 categoryFieldsWidget，
/// 驱动 AmountInput 前缀随币种变化。
String currencySymbolOf(String code) {
  switch (code) {
    case 'USD':
      return '\$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'JPY':
      return '¥';
    case 'HKD':
      return 'HK\$';
    case 'AUD':
      return 'A\$';
    case 'SGD':
      return 'S\$';
    default:
      return '¥'; // CNY + 未知
  }
}

/// 主金额 label 按 category（spec §2 + 设计决策 4）。
String primaryAmountLabel(AccountCategory c) {
  switch (c) {
    case AccountCategory.creditCard:
      return '当前欠款';
    case AccountCategory.investment:
      return '投入成本';
    case AccountCategory.fixedDeposit:
      return '本金';
    case AccountCategory.goldFx:
      return '买入价';
    case AccountCategory.realEstate:
      return '买入价';
    case AccountCategory.loan:
      return '剩余本金';
    default:
      return '初始余额';
  }
}

/// 利率字段 label 按 category（设计决策 5）。
String rateLabel(AccountCategory c) {
  switch (c) {
    case AccountCategory.investment:
      return '今年收益率 (%)';
    case AccountCategory.realEstate:
      return '折旧率 (%)';
    case AccountCategory.creditCard:
      return 'APR 年化利率 (%)';
    default:
      return '利率 (%)';
  }
}

DropdownButtonFormField<int> _dayPicker(
    TextEditingController ctrl, String label) {
  // T8 预填修复:编辑态 controller 已由 account_form_page initState 写入
  // (数据不丢,提交一直读 controller),但下拉从未回读 → 显示空。此处经
  // initialValue 回读;空串/不可解析 → null(显示 label)。越界值(不在
  // 1-31 items,脏数据兜底)也钳 null,防 DropdownButton 选中项断言。
  final v = int.tryParse(ctrl.text);
  return DropdownButtonFormField<int>(
    initialValue: v != null && v >= 1 && v <= 31 ? v : null,
    decoration: InputDecoration(labelText: label),
    items: [
      for (var d = 1; d <= 31; d++) DropdownMenuItem(value: d, child: Text('$d日'))
    ],
    onChanged: (v) => ctrl.text = v.toString(),
  );
}

/// 数值 TextFormField（利率/期限/数量等）的可选校验器：
/// 空值允许（不填）；非空需可解析为 double，否则提示。
/// 防止格式错误输入静默 → _optDouble/_optInt 返回 null → 字段被丢弃。
String? optionalNumberValidator(String? v) {
  final t = v?.trim() ?? '';
  if (t.isEmpty) return null; // 空允许
  return double.tryParse(t) == null ? '请输入有效数字' : null;
}

// —— F51 FR-1/FR-2(ADR-3)降级只读态渲染助手 ——

/// 金额格式:千分位 + 两位小数(与详情页 _fmtSigned/SummaryCard 口径一致,
/// 如 ¥44,100.00)。负数保留负号(派生聚合为非负,防御性支持)。
String _fmtDerivedYuan(String symbol, int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  final yuan = abs ~/ 100;
  final frac = (abs % 100).toString().padLeft(2, '0');
  final s = yuan.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    buf.write(s[i]);
    final remain = s.length - 1 - i;
    if (remain > 0 && remain % 3 == 0) buf.write(',');
  }
  return '$sign$symbol$buf.$frac';
}

/// 日期格式 yyyy-MM-dd(与 DatePickerInput 展示同式)。
String _fmtDerivedDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// 降级组头提示条(F51):形态照 account_form_page 的 cat-hint banner
/// (accentSoft 软底 + info 图标 + muted 正文),纯提示不参与校验。
class _DegradedCallout extends StatelessWidget {
  const _DegradedCallout(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('degradedCallout:$text'),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: context.yucai.accentSoft,
        border: Border.all(color: context.yucai.accentSoft),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 15, color: context.yucai.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: context.yucai.muted, fontSize: 12.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// 派生只读行:label + 值(两端对齐,值用 tabular 数字粗体)。
/// [value] null 时显「—」(月供无未还期 / invest ytd 持仓侧无同义字段)。
class _DerivedRow extends StatelessWidget {
  const _DerivedRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13.5,
                  color: context.yucai.muted,
                  fontWeight: FontWeight.w500)),
          Text(value ?? '—',
              style: TextStyle(
                  fontSize: 14.5,
                  color: context.yucai.fg,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AppTypography.tabularFigures)),
        ],
      ),
    );
  }
}

/// 按 category 渲染专属字段 widget 列表。
/// [currencySymbol] 透传给所有 AmountInput（随币种变化，由 FormPage 传
/// currencySymbolOf(_currency)）。切币种 → setState → 重渲染 → 符号更新。
/// [primaryReadOnly] 编辑态储蓄卡的「初始余额」置只读 —— 余额只随交易流水
/// 变化，update 链路无 initialBalance 字段（编辑本就无效），只读+提示消除
/// 「改了存不上」的困惑；创建/复制模式仍可输入。
///
/// F51 FR-1/FR-2(ADR-3):[loanDerived]/[investDerived] 非 null = 挂接降级态
/// (loan 账户挂借入债 / invest 账户挂持仓)—— 对应字段组渲染为派生只读行 +
/// 组头提示条「以债务/持仓数据为准」;FormPage 提交时组列传 null(orAbsent
/// 保留原列值)。共享字段(机构/尾号/利率/期限等)保留可编辑,不在管控范围。
List<Widget> categoryFieldsWidget(
  AccountCategory c,
  CategoryFieldBundle b, {
  String currencySymbol = '¥',
  bool primaryReadOnly = false,
  DerivedLoanFields? loanDerived,
  DerivedInvestFields? investDerived,
}) {
  switch (c) {
    case AccountCategory.savings:
      return [
        TextFormField(
          controller: b.institutionCtrl,
          decoration: const InputDecoration(labelText: '开户机构'),
        ),
        TextFormField(
          controller: b.cardNumberTailCtrl,
          decoration: const InputDecoration(labelText: '卡号后四位'),
        ),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c), currencySymbol: currencySymbol, enabled: !primaryReadOnly),
        if (primaryReadOnly)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '初始余额创建后不可修改；当前余额随交易流水自动变化',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
          validator: optionalNumberValidator,
        ),
        DatePickerInput(
          label: '开户日期',
          initialValue: b.openingDate,
          onSaved: (v) => b.openingDate = v,
        ),
      ];
    case AccountCategory.creditCard:
      return [
        TextFormField(
          controller: b.institutionCtrl,
          decoration: const InputDecoration(labelText: '发卡机构'),
        ),
        TextFormField(
          controller: b.cardNumberTailCtrl,
          decoration: const InputDecoration(labelText: '卡号尾号'),
        ),
        AmountInput(
            key: const ValueKey('accountPrimaryAmount'),
            controller: b.primaryCentsCtrl,
            label: primaryAmountLabel(c),
            currencySymbol: currencySymbol),
        AmountInput(controller: b.creditLimitCtrl, label: '信用额度', currencySymbol: currencySymbol),
        FormRow(children: [
          _dayPicker(b.creditBillingDayCtrl, '账单日'),
          _dayPicker(b.creditRepaymentDayCtrl, '还款日'),
        ]),
        AmountInput(controller: b.creditAnnualFeeCtrl, label: '年费', currencySymbol: currencySymbol),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
          validator: optionalNumberValidator,
        ),
      ];
    case AccountCategory.investment:
      // F51 FR-2:挂持仓降级 —— 成本/市值显 Σ持仓派生值,ytd 显「—」
      // (持仓侧无同义字段,不造新数字);机构/尾号保留可编辑。
      if (investDerived != null) {
        return [
          const _DegradedCallout('以持仓数据为准，请在持仓页维护'),
          TextFormField(
            controller: b.institutionCtrl,
            decoration: const InputDecoration(
                labelText: '机构（券商）', hintText: '例如：华泰证券'),
          ),
          TextFormField(
            controller: b.cardNumberTailCtrl,
            decoration: const InputDecoration(labelText: '账号尾号'),
          ),
          _DerivedRow('投入成本',
              _fmtDerivedYuan(currencySymbol, investDerived.totalCostCents)),
          _DerivedRow('当前市值',
              _fmtDerivedYuan(currencySymbol, investDerived.totalMarketValueCents)),
          const _DerivedRow('今年收益率 (%)', null),
        ];
      }
      return [
        TextFormField(
          controller: b.institutionCtrl,
          decoration: const InputDecoration(
              labelText: '机构（券商）', hintText: '例如：华泰证券'),
        ),
        TextFormField(
          controller: b.cardNumberTailCtrl,
          decoration: const InputDecoration(labelText: '账号尾号'),
        ),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c), currencySymbol: currencySymbol),
        AmountInput(controller: b.investMarketValueCtrl, label: '当前市值', currencySymbol: currencySymbol),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
          validator: optionalNumberValidator,
        ),
      ];
    case AccountCategory.fixedDeposit:
      return [
        TextFormField(
          controller: b.institutionCtrl,
          decoration: const InputDecoration(labelText: '机构'),
        ),
        TextFormField(
          controller: b.cardNumberTailCtrl,
          decoration: const InputDecoration(labelText: '账号尾号'),
        ),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c), currencySymbol: currencySymbol),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
          validator: optionalNumberValidator,
        ),
        DatePickerInput(
          label: '起息日',
          initialValue: b.fixedStartDate,
          onSaved: (v) => b.fixedStartDate = v,
        ),
        DatePickerInput(
          label: '到期日',
          initialValue: b.fixedMaturityDate,
          onSaved: (v) => b.fixedMaturityDate = v,
        ),
        TextFormField(
          controller: b.fixedTermMonthsCtrl,
          decoration: const InputDecoration(labelText: '期限（月）'),
          keyboardType: TextInputType.number,
          validator: optionalNumberValidator,
        ),
      ];
    case AccountCategory.goldFx:
      return [
        TextFormField(
          controller: b.goldProductTypeCtrl,
          decoration: const InputDecoration(
              labelText: '品种', hintText: '例如：实物黄金 / 美元 USD'),
        ),
        TextFormField(
          controller: b.goldQuantityCtrl,
          decoration: const InputDecoration(labelText: '数量'),
          keyboardType: TextInputType.number,
          validator: optionalNumberValidator,
        ),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c), currencySymbol: currencySymbol),
        AmountInput(controller: b.goldCurrentPriceCtrl, label: '现价', currencySymbol: currencySymbol),
      ];
    case AccountCategory.realEstate:
      return [
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c), currencySymbol: currencySymbol),
        AmountInput(controller: b.estateCurrentValueCtrl, label: '现估值', currencySymbol: currencySymbol),
        DatePickerInput(
          label: '买入日期',
          initialValue: b.estatePurchaseDate,
          onSaved: (v) => b.estatePurchaseDate = v,
        ),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
          validator: optionalNumberValidator,
        ),
      ];
    case AccountCategory.loan:
      // F51 FR-1:挂借入债降级 —— 四字段(总额/剩余/月供/下期)只读显
      // derivedLoanFields 派生值;机构/利率/期限/账单日保留可编辑(非 loan
      // 组列)。月供/下期无未还期 → null → 「—」。
      if (loanDerived != null) {
        return [
          const _DegradedCallout('以债务数据为准，请在债务页维护'),
          TextFormField(
            controller: b.institutionCtrl,
            decoration: const InputDecoration(labelText: '贷款机构'),
          ),
          _DerivedRow('贷款总额',
              _fmtDerivedYuan(currencySymbol, loanDerived.totalPrincipalCents)),
          _DerivedRow('剩余本金', _fmtDerivedYuan(
              currencySymbol, loanDerived.remainingPrincipalCents)),
          _DerivedRow('月供', loanDerived.nextPaymentCents == null
              ? null
              : _fmtDerivedYuan(
                  currencySymbol, loanDerived.nextPaymentCents!)),
          _DerivedRow('下次还款日', loanDerived.nextPaymentDate == null
              ? null
              : _fmtDerivedDate(loanDerived.nextPaymentDate!)),
          TextFormField(
            controller: b.interestRateCtrl,
            decoration: InputDecoration(labelText: rateLabel(c)),
            keyboardType: TextInputType.number,
            validator: optionalNumberValidator,
          ),
          TextFormField(
            controller: b.fixedTermMonthsCtrl,
            decoration: const InputDecoration(labelText: '期限（月）'),
            keyboardType: TextInputType.number,
            validator: optionalNumberValidator,
          ),
          _dayPicker(b.creditBillingDayCtrl, '账单日(选填)'),
          _dayPicker(b.creditRepaymentDayCtrl, '还款日(选填)'),
          // F51 评审 S5:降级态同样可编辑账单日/还款日(非 loan 组列),
          // 补回与可编辑态一致的账单制说明文字(此前遗漏致两态说明不对齐)。
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '账单制贷款(如 e招贷):每月账单日合并出账,还款日前一次还清。'
              '填写后账户详情按账单制显示;留空则按普通贷款逐期还款。',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
        ];
      }
      return [
        TextFormField(
          controller: b.institutionCtrl,
          decoration: const InputDecoration(labelText: '贷款机构'),
        ),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c), currencySymbol: currencySymbol),
        AmountInput(controller: b.loanOriginalCtrl, label: '原始本金', currencySymbol: currencySymbol),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
          validator: optionalNumberValidator,
        ),
        TextFormField(
          controller: b.fixedTermMonthsCtrl,
          decoration: const InputDecoration(labelText: '期限（月）'),
          keyboardType: TextInputType.number,
          validator: optionalNumberValidator,
        ),
        AmountInput(controller: b.loanMonthlyCtrl, label: '月供', currencySymbol: currencySymbol),
        DatePickerInput(
          label: '下次还款日',
          initialValue: b.loanNextPaymentDate,
          onSaved: (v) => b.loanNextPaymentDate = v,
        ),
        // 账单制(独立账单卡贷,如 e招贷):复用信用卡账单日/还款日列,
        // 提交链路本就无条件携带 creditBillingDay/creditRepaymentDay。
        _dayPicker(b.creditBillingDayCtrl, '账单日(选填)'),
        _dayPicker(b.creditRepaymentDayCtrl, '还款日(选填)'),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '账单制贷款(如 e招贷):每月账单日合并出账,还款日前一次还清。'
            '填写后账户详情按账单制显示;留空则按普通贷款逐期还款。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ];
    case AccountCategory.otherAsset:
    case AccountCategory.otherLiability:
      return [AmountInput(controller: b.primaryCentsCtrl, label: '金额', currencySymbol: currencySymbol)];
    case AccountCategory.storedValue:
      return [
        TextFormField(
          controller: b.institutionCtrl,
          decoration: const InputDecoration(labelText: '商户名称'),
        ),
        TextFormField(
          controller: b.cardNumberTailCtrl,
          decoration: const InputDecoration(labelText: '卡号尾号'),
        ),
        AmountInput(
          controller: b.primaryCentsCtrl,
          label: primaryAmountLabel(c),
          currencySymbol: currencySymbol,
          enabled: !primaryReadOnly,
        ),
      ];
  }
}
