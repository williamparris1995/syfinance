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
        fixedStartDateCtrl = TextEditingController(),
        fixedMaturityDateCtrl = TextEditingController(),
        fixedTermMonthsCtrl = TextEditingController(),
        goldProductTypeCtrl = TextEditingController(),
        goldQuantityCtrl = TextEditingController(),
        goldCurrentPriceCtrl = TextEditingController(),
        estateCurrentValueCtrl = TextEditingController(),
        estatePurchaseDateCtrl = TextEditingController(),
        loanOriginalCtrl = TextEditingController(),
        loanMonthlyCtrl = TextEditingController(),
        loanNextPaymentDateCtrl = TextEditingController();

  final TextEditingController primaryCentsCtrl;
  final TextEditingController institutionCtrl;
  final TextEditingController cardNumberTailCtrl;
  final TextEditingController interestRateCtrl; // 利率/APR/收益率/折旧率（多义）
  final TextEditingController creditBillingDayCtrl;
  final TextEditingController creditRepaymentDayCtrl;
  final TextEditingController creditLimitCtrl;
  final TextEditingController creditAnnualFeeCtrl;
  final TextEditingController investMarketValueCtrl;
  final TextEditingController fixedStartDateCtrl;
  final TextEditingController fixedMaturityDateCtrl;
  final TextEditingController fixedTermMonthsCtrl;
  final TextEditingController goldProductTypeCtrl;
  final TextEditingController goldQuantityCtrl;
  final TextEditingController goldCurrentPriceCtrl;
  final TextEditingController estateCurrentValueCtrl;
  final TextEditingController estatePurchaseDateCtrl;
  final TextEditingController loanOriginalCtrl;
  final TextEditingController loanMonthlyCtrl;
  final TextEditingController loanNextPaymentDateCtrl;

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
      fixedStartDateCtrl,
      fixedMaturityDateCtrl,
      fixedTermMonthsCtrl,
      goldProductTypeCtrl,
      goldQuantityCtrl,
      goldCurrentPriceCtrl,
      estateCurrentValueCtrl,
      estatePurchaseDateCtrl,
      loanOriginalCtrl,
      loanMonthlyCtrl,
      loanNextPaymentDateCtrl,
    ]) {
      c.dispose();
    }
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

/// 按 category 渲染专属字段 widget 列表。
List<Widget> categoryFieldsWidget(AccountCategory c, CategoryFieldBundle b) {
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
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
        ),
        DatePickerInput(label: '开户日期'),
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
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        AmountInput(controller: b.creditLimitCtrl, label: '信用额度'),
        FormRow(children: [
          _dayPicker(b.creditBillingDayCtrl, '账单日'),
          _dayPicker(b.creditRepaymentDayCtrl, '还款日'),
        ]),
        AmountInput(controller: b.creditAnnualFeeCtrl, label: '年费'),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
        ),
      ];
    case AccountCategory.investment:
      return [
        TextFormField(
          controller: b.institutionCtrl,
          decoration: const InputDecoration(
              labelText: '机构（券商）', hintText: '如 华泰证券'),
        ),
        TextFormField(
          controller: b.cardNumberTailCtrl,
          decoration: const InputDecoration(labelText: '账号尾号'),
        ),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        AmountInput(controller: b.investMarketValueCtrl, label: '当前市值'),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
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
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
        ),
        DatePickerInput(label: '起息日'),
        DatePickerInput(label: '到期日'),
        TextFormField(
          controller: b.fixedTermMonthsCtrl,
          decoration: const InputDecoration(labelText: '期限（月）'),
          keyboardType: TextInputType.number,
        ),
      ];
    case AccountCategory.goldFx:
      return [
        TextFormField(
          controller: b.goldProductTypeCtrl,
          decoration: const InputDecoration(
              labelText: '品种', hintText: '如 实物黄金 / 美元 USD'),
        ),
        TextFormField(
          controller: b.goldQuantityCtrl,
          decoration: const InputDecoration(labelText: '数量'),
          keyboardType: TextInputType.number,
        ),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        AmountInput(controller: b.goldCurrentPriceCtrl, label: '现价'),
      ];
    case AccountCategory.realEstate:
      return [
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        AmountInput(controller: b.estateCurrentValueCtrl, label: '现估值'),
        DatePickerInput(label: '买入日期'),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
        ),
      ];
    case AccountCategory.loan:
      return [
        TextFormField(
          controller: b.institutionCtrl,
          decoration: const InputDecoration(labelText: '贷款机构'),
        ),
        AmountInput(controller: b.primaryCentsCtrl, label: primaryAmountLabel(c)),
        AmountInput(controller: b.loanOriginalCtrl, label: '原始本金'),
        TextFormField(
          controller: b.interestRateCtrl,
          decoration: InputDecoration(labelText: rateLabel(c)),
          keyboardType: TextInputType.number,
        ),
        TextFormField(
          controller: b.fixedTermMonthsCtrl,
          decoration: const InputDecoration(labelText: '期限（月）'),
          keyboardType: TextInputType.number,
        ),
        AmountInput(controller: b.loanMonthlyCtrl, label: '月供'),
        DatePickerInput(label: '下次还款日'),
      ];
    case AccountCategory.otherAsset:
    case AccountCategory.otherLiability:
      return [AmountInput(controller: b.primaryCentsCtrl, label: '金额')];
  }
}
