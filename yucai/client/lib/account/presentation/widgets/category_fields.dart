import 'package:flutter/material.dart';

import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/widgets/amount_input.dart';
import 'package:yucai_client/core/widgets/date_picker_input.dart';
import 'package:yucai_client/core/widgets/form_section.dart';

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
  return DropdownButtonFormField<int>(
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

/// 按 category 渲染专属字段 widget 列表。
/// [currencySymbol] 透传给所有 AmountInput（随币种变化，由 FormPage 传
/// currencySymbolOf(_currency)）。切币种 → setState → 重渲染 → 符号更新。
List<Widget> categoryFieldsWidget(
  AccountCategory c,
  CategoryFieldBundle b, {
  String currencySymbol = '¥',
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
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c), currencySymbol: currencySymbol),
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
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c), currencySymbol: currencySymbol),
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
      ];
    case AccountCategory.otherAsset:
    case AccountCategory.otherLiability:
      return [AmountInput(controller: b.primaryCentsCtrl, label: '金额', currencySymbol: currencySymbol)];
  }
}
