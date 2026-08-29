// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountTypeMeta = const VerificationMeta(
    'accountType',
  );
  @override
  late final GeneratedColumn<int> accountType = GeneratedColumn<int>(
    'account_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<int> category = GeneratedColumn<int>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _initialBalanceCentsMeta =
      const VerificationMeta('initialBalanceCents');
  @override
  late final GeneratedColumn<int> initialBalanceCents = GeneratedColumn<int>(
    'initial_balance_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentBalanceCentsMeta =
      const VerificationMeta('currentBalanceCents');
  @override
  late final GeneratedColumn<int> currentBalanceCents = GeneratedColumn<int>(
    'current_balance_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ownershipMeta = const VerificationMeta(
    'ownership',
  );
  @override
  late final GeneratedColumn<int> ownership = GeneratedColumn<int>(
    'ownership',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chartCodeMeta = const VerificationMeta(
    'chartCode',
  );
  @override
  late final GeneratedColumn<String> chartCode = GeneratedColumn<String>(
    'chart_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentIdMeta = const VerificationMeta(
    'parentId',
  );
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
    'parent_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isSystemMeta = const VerificationMeta(
    'isSystem',
  );
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
    'is_system',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_system" IN (0, 1))',
    ),
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _institutionMeta = const VerificationMeta(
    'institution',
  );
  @override
  late final GeneratedColumn<String> institution = GeneratedColumn<String>(
    'institution',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditLimitCentsMeta = const VerificationMeta(
    'creditLimitCents',
  );
  @override
  late final GeneratedColumn<int> creditLimitCents = GeneratedColumn<int>(
    'credit_limit_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _cardNumberTailMeta = const VerificationMeta(
    'cardNumberTail',
  );
  @override
  late final GeneratedColumn<String> cardNumberTail = GeneratedColumn<String>(
    'card_number_tail',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _openingDateMeta = const VerificationMeta(
    'openingDate',
  );
  @override
  late final GeneratedColumn<DateTime> openingDate = GeneratedColumn<DateTime>(
    'opening_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _interestRateMeta = const VerificationMeta(
    'interestRate',
  );
  @override
  late final GeneratedColumn<double> interestRate = GeneratedColumn<double>(
    'interest_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creditBillingDayMeta = const VerificationMeta(
    'creditBillingDay',
  );
  @override
  late final GeneratedColumn<int> creditBillingDay = GeneratedColumn<int>(
    'credit_billing_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creditRepaymentDayMeta =
      const VerificationMeta('creditRepaymentDay');
  @override
  late final GeneratedColumn<int> creditRepaymentDay = GeneratedColumn<int>(
    'credit_repayment_day',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _creditAnnualFeeCentsMeta =
      const VerificationMeta('creditAnnualFeeCents');
  @override
  late final GeneratedColumn<int> creditAnnualFeeCents = GeneratedColumn<int>(
    'credit_annual_fee_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _investCostCentsMeta = const VerificationMeta(
    'investCostCents',
  );
  @override
  late final GeneratedColumn<int> investCostCents = GeneratedColumn<int>(
    'invest_cost_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _investMarketValueCentsMeta =
      const VerificationMeta('investMarketValueCents');
  @override
  late final GeneratedColumn<int> investMarketValueCents = GeneratedColumn<int>(
    'invest_market_value_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _investReturnYtdMeta = const VerificationMeta(
    'investReturnYtd',
  );
  @override
  late final GeneratedColumn<double> investReturnYtd = GeneratedColumn<double>(
    'invest_return_ytd',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fixedPrincipalCentsMeta =
      const VerificationMeta('fixedPrincipalCents');
  @override
  late final GeneratedColumn<int> fixedPrincipalCents = GeneratedColumn<int>(
    'fixed_principal_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fixedStartDateMeta = const VerificationMeta(
    'fixedStartDate',
  );
  @override
  late final GeneratedColumn<DateTime> fixedStartDate =
      GeneratedColumn<DateTime>(
        'fixed_start_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _fixedMaturityDateMeta = const VerificationMeta(
    'fixedMaturityDate',
  );
  @override
  late final GeneratedColumn<DateTime> fixedMaturityDate =
      GeneratedColumn<DateTime>(
        'fixed_maturity_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _fixedTermMonthsMeta = const VerificationMeta(
    'fixedTermMonths',
  );
  @override
  late final GeneratedColumn<int> fixedTermMonths = GeneratedColumn<int>(
    'fixed_term_months',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goldProductTypeMeta = const VerificationMeta(
    'goldProductType',
  );
  @override
  late final GeneratedColumn<String> goldProductType = GeneratedColumn<String>(
    'gold_product_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goldQuantityMeta = const VerificationMeta(
    'goldQuantity',
  );
  @override
  late final GeneratedColumn<double> goldQuantity = GeneratedColumn<double>(
    'gold_quantity',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goldBuyPriceCentsMeta = const VerificationMeta(
    'goldBuyPriceCents',
  );
  @override
  late final GeneratedColumn<int> goldBuyPriceCents = GeneratedColumn<int>(
    'gold_buy_price_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _goldCurrentPriceCentsMeta =
      const VerificationMeta('goldCurrentPriceCents');
  @override
  late final GeneratedColumn<int> goldCurrentPriceCents = GeneratedColumn<int>(
    'gold_current_price_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _estatePurchasePriceCentsMeta =
      const VerificationMeta('estatePurchasePriceCents');
  @override
  late final GeneratedColumn<int> estatePurchasePriceCents =
      GeneratedColumn<int>(
        'estate_purchase_price_cents',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _estateCurrentValueCentsMeta =
      const VerificationMeta('estateCurrentValueCents');
  @override
  late final GeneratedColumn<int> estateCurrentValueCents =
      GeneratedColumn<int>(
        'estate_current_value_cents',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _estatePurchaseDateMeta =
      const VerificationMeta('estatePurchaseDate');
  @override
  late final GeneratedColumn<DateTime> estatePurchaseDate =
      GeneratedColumn<DateTime>(
        'estate_purchase_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _estateDepreciationRateMeta =
      const VerificationMeta('estateDepreciationRate');
  @override
  late final GeneratedColumn<double> estateDepreciationRate =
      GeneratedColumn<double>(
        'estate_depreciation_rate',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _loanOriginalCentsMeta = const VerificationMeta(
    'loanOriginalCents',
  );
  @override
  late final GeneratedColumn<int> loanOriginalCents = GeneratedColumn<int>(
    'loan_original_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loanRemainingCentsMeta =
      const VerificationMeta('loanRemainingCents');
  @override
  late final GeneratedColumn<int> loanRemainingCents = GeneratedColumn<int>(
    'loan_remaining_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loanMonthlyCentsMeta = const VerificationMeta(
    'loanMonthlyCents',
  );
  @override
  late final GeneratedColumn<int> loanMonthlyCents = GeneratedColumn<int>(
    'loan_monthly_cents',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _loanNextPaymentDateMeta =
      const VerificationMeta('loanNextPaymentDate');
  @override
  late final GeneratedColumn<DateTime> loanNextPaymentDate =
      GeneratedColumn<DateTime>(
        'loan_next_payment_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<int> status = GeneratedColumn<int>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    accountType,
    category,
    currencyCode,
    initialBalanceCents,
    currentBalanceCents,
    ownership,
    icon,
    color,
    chartCode,
    parentId,
    isSystem,
    sortOrder,
    institution,
    creditLimitCents,
    cardNumberTail,
    notes,
    openingDate,
    interestRate,
    creditBillingDay,
    creditRepaymentDay,
    creditAnnualFeeCents,
    investCostCents,
    investMarketValueCents,
    investReturnYtd,
    fixedPrincipalCents,
    fixedStartDate,
    fixedMaturityDate,
    fixedTermMonths,
    goldProductType,
    goldQuantity,
    goldBuyPriceCents,
    goldCurrentPriceCents,
    estatePurchasePriceCents,
    estateCurrentValueCents,
    estatePurchaseDate,
    estateDepreciationRate,
    loanOriginalCents,
    loanRemainingCents,
    loanMonthlyCents,
    loanNextPaymentDate,
    status,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Account> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('account_type')) {
      context.handle(
        _accountTypeMeta,
        accountType.isAcceptableOrUnknown(
          data['account_type']!,
          _accountTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accountTypeMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('initial_balance_cents')) {
      context.handle(
        _initialBalanceCentsMeta,
        initialBalanceCents.isAcceptableOrUnknown(
          data['initial_balance_cents']!,
          _initialBalanceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_initialBalanceCentsMeta);
    }
    if (data.containsKey('current_balance_cents')) {
      context.handle(
        _currentBalanceCentsMeta,
        currentBalanceCents.isAcceptableOrUnknown(
          data['current_balance_cents']!,
          _currentBalanceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentBalanceCentsMeta);
    }
    if (data.containsKey('ownership')) {
      context.handle(
        _ownershipMeta,
        ownership.isAcceptableOrUnknown(data['ownership']!, _ownershipMeta),
      );
    } else if (isInserting) {
      context.missing(_ownershipMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('chart_code')) {
      context.handle(
        _chartCodeMeta,
        chartCode.isAcceptableOrUnknown(data['chart_code']!, _chartCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_chartCodeMeta);
    }
    if (data.containsKey('parent_id')) {
      context.handle(
        _parentIdMeta,
        parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta),
      );
    }
    if (data.containsKey('is_system')) {
      context.handle(
        _isSystemMeta,
        isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta),
      );
    } else if (isInserting) {
      context.missing(_isSystemMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    if (data.containsKey('institution')) {
      context.handle(
        _institutionMeta,
        institution.isAcceptableOrUnknown(
          data['institution']!,
          _institutionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_institutionMeta);
    }
    if (data.containsKey('credit_limit_cents')) {
      context.handle(
        _creditLimitCentsMeta,
        creditLimitCents.isAcceptableOrUnknown(
          data['credit_limit_cents']!,
          _creditLimitCentsMeta,
        ),
      );
    }
    if (data.containsKey('card_number_tail')) {
      context.handle(
        _cardNumberTailMeta,
        cardNumberTail.isAcceptableOrUnknown(
          data['card_number_tail']!,
          _cardNumberTailMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_cardNumberTailMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    if (data.containsKey('opening_date')) {
      context.handle(
        _openingDateMeta,
        openingDate.isAcceptableOrUnknown(
          data['opening_date']!,
          _openingDateMeta,
        ),
      );
    }
    if (data.containsKey('interest_rate')) {
      context.handle(
        _interestRateMeta,
        interestRate.isAcceptableOrUnknown(
          data['interest_rate']!,
          _interestRateMeta,
        ),
      );
    }
    if (data.containsKey('credit_billing_day')) {
      context.handle(
        _creditBillingDayMeta,
        creditBillingDay.isAcceptableOrUnknown(
          data['credit_billing_day']!,
          _creditBillingDayMeta,
        ),
      );
    }
    if (data.containsKey('credit_repayment_day')) {
      context.handle(
        _creditRepaymentDayMeta,
        creditRepaymentDay.isAcceptableOrUnknown(
          data['credit_repayment_day']!,
          _creditRepaymentDayMeta,
        ),
      );
    }
    if (data.containsKey('credit_annual_fee_cents')) {
      context.handle(
        _creditAnnualFeeCentsMeta,
        creditAnnualFeeCents.isAcceptableOrUnknown(
          data['credit_annual_fee_cents']!,
          _creditAnnualFeeCentsMeta,
        ),
      );
    }
    if (data.containsKey('invest_cost_cents')) {
      context.handle(
        _investCostCentsMeta,
        investCostCents.isAcceptableOrUnknown(
          data['invest_cost_cents']!,
          _investCostCentsMeta,
        ),
      );
    }
    if (data.containsKey('invest_market_value_cents')) {
      context.handle(
        _investMarketValueCentsMeta,
        investMarketValueCents.isAcceptableOrUnknown(
          data['invest_market_value_cents']!,
          _investMarketValueCentsMeta,
        ),
      );
    }
    if (data.containsKey('invest_return_ytd')) {
      context.handle(
        _investReturnYtdMeta,
        investReturnYtd.isAcceptableOrUnknown(
          data['invest_return_ytd']!,
          _investReturnYtdMeta,
        ),
      );
    }
    if (data.containsKey('fixed_principal_cents')) {
      context.handle(
        _fixedPrincipalCentsMeta,
        fixedPrincipalCents.isAcceptableOrUnknown(
          data['fixed_principal_cents']!,
          _fixedPrincipalCentsMeta,
        ),
      );
    }
    if (data.containsKey('fixed_start_date')) {
      context.handle(
        _fixedStartDateMeta,
        fixedStartDate.isAcceptableOrUnknown(
          data['fixed_start_date']!,
          _fixedStartDateMeta,
        ),
      );
    }
    if (data.containsKey('fixed_maturity_date')) {
      context.handle(
        _fixedMaturityDateMeta,
        fixedMaturityDate.isAcceptableOrUnknown(
          data['fixed_maturity_date']!,
          _fixedMaturityDateMeta,
        ),
      );
    }
    if (data.containsKey('fixed_term_months')) {
      context.handle(
        _fixedTermMonthsMeta,
        fixedTermMonths.isAcceptableOrUnknown(
          data['fixed_term_months']!,
          _fixedTermMonthsMeta,
        ),
      );
    }
    if (data.containsKey('gold_product_type')) {
      context.handle(
        _goldProductTypeMeta,
        goldProductType.isAcceptableOrUnknown(
          data['gold_product_type']!,
          _goldProductTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_goldProductTypeMeta);
    }
    if (data.containsKey('gold_quantity')) {
      context.handle(
        _goldQuantityMeta,
        goldQuantity.isAcceptableOrUnknown(
          data['gold_quantity']!,
          _goldQuantityMeta,
        ),
      );
    }
    if (data.containsKey('gold_buy_price_cents')) {
      context.handle(
        _goldBuyPriceCentsMeta,
        goldBuyPriceCents.isAcceptableOrUnknown(
          data['gold_buy_price_cents']!,
          _goldBuyPriceCentsMeta,
        ),
      );
    }
    if (data.containsKey('gold_current_price_cents')) {
      context.handle(
        _goldCurrentPriceCentsMeta,
        goldCurrentPriceCents.isAcceptableOrUnknown(
          data['gold_current_price_cents']!,
          _goldCurrentPriceCentsMeta,
        ),
      );
    }
    if (data.containsKey('estate_purchase_price_cents')) {
      context.handle(
        _estatePurchasePriceCentsMeta,
        estatePurchasePriceCents.isAcceptableOrUnknown(
          data['estate_purchase_price_cents']!,
          _estatePurchasePriceCentsMeta,
        ),
      );
    }
    if (data.containsKey('estate_current_value_cents')) {
      context.handle(
        _estateCurrentValueCentsMeta,
        estateCurrentValueCents.isAcceptableOrUnknown(
          data['estate_current_value_cents']!,
          _estateCurrentValueCentsMeta,
        ),
      );
    }
    if (data.containsKey('estate_purchase_date')) {
      context.handle(
        _estatePurchaseDateMeta,
        estatePurchaseDate.isAcceptableOrUnknown(
          data['estate_purchase_date']!,
          _estatePurchaseDateMeta,
        ),
      );
    }
    if (data.containsKey('estate_depreciation_rate')) {
      context.handle(
        _estateDepreciationRateMeta,
        estateDepreciationRate.isAcceptableOrUnknown(
          data['estate_depreciation_rate']!,
          _estateDepreciationRateMeta,
        ),
      );
    }
    if (data.containsKey('loan_original_cents')) {
      context.handle(
        _loanOriginalCentsMeta,
        loanOriginalCents.isAcceptableOrUnknown(
          data['loan_original_cents']!,
          _loanOriginalCentsMeta,
        ),
      );
    }
    if (data.containsKey('loan_remaining_cents')) {
      context.handle(
        _loanRemainingCentsMeta,
        loanRemainingCents.isAcceptableOrUnknown(
          data['loan_remaining_cents']!,
          _loanRemainingCentsMeta,
        ),
      );
    }
    if (data.containsKey('loan_monthly_cents')) {
      context.handle(
        _loanMonthlyCentsMeta,
        loanMonthlyCents.isAcceptableOrUnknown(
          data['loan_monthly_cents']!,
          _loanMonthlyCentsMeta,
        ),
      );
    }
    if (data.containsKey('loan_next_payment_date')) {
      context.handle(
        _loanNextPaymentDateMeta,
        loanNextPaymentDate.isAcceptableOrUnknown(
          data['loan_next_payment_date']!,
          _loanNextPaymentDateMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      accountType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_type'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      initialBalanceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}initial_balance_cents'],
      )!,
      currentBalanceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_balance_cents'],
      )!,
      ownership: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ownership'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      chartCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chart_code'],
      )!,
      parentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_id'],
      ),
      isSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_system'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      institution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}institution'],
      )!,
      creditLimitCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_limit_cents'],
      ),
      cardNumberTail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}card_number_tail'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      openingDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}opening_date'],
      ),
      interestRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}interest_rate'],
      ),
      creditBillingDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_billing_day'],
      ),
      creditRepaymentDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_repayment_day'],
      ),
      creditAnnualFeeCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_annual_fee_cents'],
      ),
      investCostCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}invest_cost_cents'],
      ),
      investMarketValueCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}invest_market_value_cents'],
      ),
      investReturnYtd: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}invest_return_ytd'],
      ),
      fixedPrincipalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fixed_principal_cents'],
      ),
      fixedStartDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fixed_start_date'],
      ),
      fixedMaturityDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fixed_maturity_date'],
      ),
      fixedTermMonths: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fixed_term_months'],
      ),
      goldProductType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gold_product_type'],
      )!,
      goldQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gold_quantity'],
      ),
      goldBuyPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gold_buy_price_cents'],
      ),
      goldCurrentPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gold_current_price_cents'],
      ),
      estatePurchasePriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estate_purchase_price_cents'],
      ),
      estateCurrentValueCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estate_current_value_cents'],
      ),
      estatePurchaseDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}estate_purchase_date'],
      ),
      estateDepreciationRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}estate_depreciation_rate'],
      ),
      loanOriginalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}loan_original_cents'],
      ),
      loanRemainingCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}loan_remaining_cents'],
      ),
      loanMonthlyCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}loan_monthly_cents'],
      ),
      loanNextPaymentDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}loan_next_payment_date'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}status'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }
}

class Account extends DataClass implements Insertable<Account> {
  final String id;
  final String name;
  final int accountType;
  final int category;
  final String currencyCode;
  final int initialBalanceCents;
  final int currentBalanceCents;
  final int ownership;
  final String icon;
  final String color;
  final String chartCode;
  final String? parentId;
  final bool isSystem;
  final int sortOrder;
  final String institution;
  final int? creditLimitCents;
  final String cardNumberTail;
  final String notes;
  final DateTime? openingDate;
  final double? interestRate;
  final int? creditBillingDay;
  final int? creditRepaymentDay;
  final int? creditAnnualFeeCents;
  final int? investCostCents;
  final int? investMarketValueCents;
  final double? investReturnYtd;
  final int? fixedPrincipalCents;
  final DateTime? fixedStartDate;
  final DateTime? fixedMaturityDate;
  final int? fixedTermMonths;
  final String goldProductType;
  final double? goldQuantity;
  final int? goldBuyPriceCents;
  final int? goldCurrentPriceCents;
  final int? estatePurchasePriceCents;
  final int? estateCurrentValueCents;
  final DateTime? estatePurchaseDate;
  final double? estateDepreciationRate;
  final int? loanOriginalCents;
  final int? loanRemainingCents;
  final int? loanMonthlyCents;
  final DateTime? loanNextPaymentDate;
  final int status;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Account({
    required this.id,
    required this.name,
    required this.accountType,
    required this.category,
    required this.currencyCode,
    required this.initialBalanceCents,
    required this.currentBalanceCents,
    required this.ownership,
    required this.icon,
    required this.color,
    required this.chartCode,
    this.parentId,
    required this.isSystem,
    required this.sortOrder,
    required this.institution,
    this.creditLimitCents,
    required this.cardNumberTail,
    required this.notes,
    this.openingDate,
    this.interestRate,
    this.creditBillingDay,
    this.creditRepaymentDay,
    this.creditAnnualFeeCents,
    this.investCostCents,
    this.investMarketValueCents,
    this.investReturnYtd,
    this.fixedPrincipalCents,
    this.fixedStartDate,
    this.fixedMaturityDate,
    this.fixedTermMonths,
    required this.goldProductType,
    this.goldQuantity,
    this.goldBuyPriceCents,
    this.goldCurrentPriceCents,
    this.estatePurchasePriceCents,
    this.estateCurrentValueCents,
    this.estatePurchaseDate,
    this.estateDepreciationRate,
    this.loanOriginalCents,
    this.loanRemainingCents,
    this.loanMonthlyCents,
    this.loanNextPaymentDate,
    required this.status,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['account_type'] = Variable<int>(accountType);
    map['category'] = Variable<int>(category);
    map['currency_code'] = Variable<String>(currencyCode);
    map['initial_balance_cents'] = Variable<int>(initialBalanceCents);
    map['current_balance_cents'] = Variable<int>(currentBalanceCents);
    map['ownership'] = Variable<int>(ownership);
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<String>(color);
    map['chart_code'] = Variable<String>(chartCode);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['is_system'] = Variable<bool>(isSystem);
    map['sort_order'] = Variable<int>(sortOrder);
    map['institution'] = Variable<String>(institution);
    if (!nullToAbsent || creditLimitCents != null) {
      map['credit_limit_cents'] = Variable<int>(creditLimitCents);
    }
    map['card_number_tail'] = Variable<String>(cardNumberTail);
    map['notes'] = Variable<String>(notes);
    if (!nullToAbsent || openingDate != null) {
      map['opening_date'] = Variable<DateTime>(openingDate);
    }
    if (!nullToAbsent || interestRate != null) {
      map['interest_rate'] = Variable<double>(interestRate);
    }
    if (!nullToAbsent || creditBillingDay != null) {
      map['credit_billing_day'] = Variable<int>(creditBillingDay);
    }
    if (!nullToAbsent || creditRepaymentDay != null) {
      map['credit_repayment_day'] = Variable<int>(creditRepaymentDay);
    }
    if (!nullToAbsent || creditAnnualFeeCents != null) {
      map['credit_annual_fee_cents'] = Variable<int>(creditAnnualFeeCents);
    }
    if (!nullToAbsent || investCostCents != null) {
      map['invest_cost_cents'] = Variable<int>(investCostCents);
    }
    if (!nullToAbsent || investMarketValueCents != null) {
      map['invest_market_value_cents'] = Variable<int>(investMarketValueCents);
    }
    if (!nullToAbsent || investReturnYtd != null) {
      map['invest_return_ytd'] = Variable<double>(investReturnYtd);
    }
    if (!nullToAbsent || fixedPrincipalCents != null) {
      map['fixed_principal_cents'] = Variable<int>(fixedPrincipalCents);
    }
    if (!nullToAbsent || fixedStartDate != null) {
      map['fixed_start_date'] = Variable<DateTime>(fixedStartDate);
    }
    if (!nullToAbsent || fixedMaturityDate != null) {
      map['fixed_maturity_date'] = Variable<DateTime>(fixedMaturityDate);
    }
    if (!nullToAbsent || fixedTermMonths != null) {
      map['fixed_term_months'] = Variable<int>(fixedTermMonths);
    }
    map['gold_product_type'] = Variable<String>(goldProductType);
    if (!nullToAbsent || goldQuantity != null) {
      map['gold_quantity'] = Variable<double>(goldQuantity);
    }
    if (!nullToAbsent || goldBuyPriceCents != null) {
      map['gold_buy_price_cents'] = Variable<int>(goldBuyPriceCents);
    }
    if (!nullToAbsent || goldCurrentPriceCents != null) {
      map['gold_current_price_cents'] = Variable<int>(goldCurrentPriceCents);
    }
    if (!nullToAbsent || estatePurchasePriceCents != null) {
      map['estate_purchase_price_cents'] = Variable<int>(
        estatePurchasePriceCents,
      );
    }
    if (!nullToAbsent || estateCurrentValueCents != null) {
      map['estate_current_value_cents'] = Variable<int>(
        estateCurrentValueCents,
      );
    }
    if (!nullToAbsent || estatePurchaseDate != null) {
      map['estate_purchase_date'] = Variable<DateTime>(estatePurchaseDate);
    }
    if (!nullToAbsent || estateDepreciationRate != null) {
      map['estate_depreciation_rate'] = Variable<double>(
        estateDepreciationRate,
      );
    }
    if (!nullToAbsent || loanOriginalCents != null) {
      map['loan_original_cents'] = Variable<int>(loanOriginalCents);
    }
    if (!nullToAbsent || loanRemainingCents != null) {
      map['loan_remaining_cents'] = Variable<int>(loanRemainingCents);
    }
    if (!nullToAbsent || loanMonthlyCents != null) {
      map['loan_monthly_cents'] = Variable<int>(loanMonthlyCents);
    }
    if (!nullToAbsent || loanNextPaymentDate != null) {
      map['loan_next_payment_date'] = Variable<DateTime>(loanNextPaymentDate);
    }
    map['status'] = Variable<int>(status);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      name: Value(name),
      accountType: Value(accountType),
      category: Value(category),
      currencyCode: Value(currencyCode),
      initialBalanceCents: Value(initialBalanceCents),
      currentBalanceCents: Value(currentBalanceCents),
      ownership: Value(ownership),
      icon: Value(icon),
      color: Value(color),
      chartCode: Value(chartCode),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      isSystem: Value(isSystem),
      sortOrder: Value(sortOrder),
      institution: Value(institution),
      creditLimitCents: creditLimitCents == null && nullToAbsent
          ? const Value.absent()
          : Value(creditLimitCents),
      cardNumberTail: Value(cardNumberTail),
      notes: Value(notes),
      openingDate: openingDate == null && nullToAbsent
          ? const Value.absent()
          : Value(openingDate),
      interestRate: interestRate == null && nullToAbsent
          ? const Value.absent()
          : Value(interestRate),
      creditBillingDay: creditBillingDay == null && nullToAbsent
          ? const Value.absent()
          : Value(creditBillingDay),
      creditRepaymentDay: creditRepaymentDay == null && nullToAbsent
          ? const Value.absent()
          : Value(creditRepaymentDay),
      creditAnnualFeeCents: creditAnnualFeeCents == null && nullToAbsent
          ? const Value.absent()
          : Value(creditAnnualFeeCents),
      investCostCents: investCostCents == null && nullToAbsent
          ? const Value.absent()
          : Value(investCostCents),
      investMarketValueCents: investMarketValueCents == null && nullToAbsent
          ? const Value.absent()
          : Value(investMarketValueCents),
      investReturnYtd: investReturnYtd == null && nullToAbsent
          ? const Value.absent()
          : Value(investReturnYtd),
      fixedPrincipalCents: fixedPrincipalCents == null && nullToAbsent
          ? const Value.absent()
          : Value(fixedPrincipalCents),
      fixedStartDate: fixedStartDate == null && nullToAbsent
          ? const Value.absent()
          : Value(fixedStartDate),
      fixedMaturityDate: fixedMaturityDate == null && nullToAbsent
          ? const Value.absent()
          : Value(fixedMaturityDate),
      fixedTermMonths: fixedTermMonths == null && nullToAbsent
          ? const Value.absent()
          : Value(fixedTermMonths),
      goldProductType: Value(goldProductType),
      goldQuantity: goldQuantity == null && nullToAbsent
          ? const Value.absent()
          : Value(goldQuantity),
      goldBuyPriceCents: goldBuyPriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(goldBuyPriceCents),
      goldCurrentPriceCents: goldCurrentPriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(goldCurrentPriceCents),
      estatePurchasePriceCents: estatePurchasePriceCents == null && nullToAbsent
          ? const Value.absent()
          : Value(estatePurchasePriceCents),
      estateCurrentValueCents: estateCurrentValueCents == null && nullToAbsent
          ? const Value.absent()
          : Value(estateCurrentValueCents),
      estatePurchaseDate: estatePurchaseDate == null && nullToAbsent
          ? const Value.absent()
          : Value(estatePurchaseDate),
      estateDepreciationRate: estateDepreciationRate == null && nullToAbsent
          ? const Value.absent()
          : Value(estateDepreciationRate),
      loanOriginalCents: loanOriginalCents == null && nullToAbsent
          ? const Value.absent()
          : Value(loanOriginalCents),
      loanRemainingCents: loanRemainingCents == null && nullToAbsent
          ? const Value.absent()
          : Value(loanRemainingCents),
      loanMonthlyCents: loanMonthlyCents == null && nullToAbsent
          ? const Value.absent()
          : Value(loanMonthlyCents),
      loanNextPaymentDate: loanNextPaymentDate == null && nullToAbsent
          ? const Value.absent()
          : Value(loanNextPaymentDate),
      status: Value(status),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Account.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      accountType: serializer.fromJson<int>(json['accountType']),
      category: serializer.fromJson<int>(json['category']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      initialBalanceCents: serializer.fromJson<int>(
        json['initialBalanceCents'],
      ),
      currentBalanceCents: serializer.fromJson<int>(
        json['currentBalanceCents'],
      ),
      ownership: serializer.fromJson<int>(json['ownership']),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<String>(json['color']),
      chartCode: serializer.fromJson<String>(json['chartCode']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      institution: serializer.fromJson<String>(json['institution']),
      creditLimitCents: serializer.fromJson<int?>(json['creditLimitCents']),
      cardNumberTail: serializer.fromJson<String>(json['cardNumberTail']),
      notes: serializer.fromJson<String>(json['notes']),
      openingDate: serializer.fromJson<DateTime?>(json['openingDate']),
      interestRate: serializer.fromJson<double?>(json['interestRate']),
      creditBillingDay: serializer.fromJson<int?>(json['creditBillingDay']),
      creditRepaymentDay: serializer.fromJson<int?>(json['creditRepaymentDay']),
      creditAnnualFeeCents: serializer.fromJson<int?>(
        json['creditAnnualFeeCents'],
      ),
      investCostCents: serializer.fromJson<int?>(json['investCostCents']),
      investMarketValueCents: serializer.fromJson<int?>(
        json['investMarketValueCents'],
      ),
      investReturnYtd: serializer.fromJson<double?>(json['investReturnYtd']),
      fixedPrincipalCents: serializer.fromJson<int?>(
        json['fixedPrincipalCents'],
      ),
      fixedStartDate: serializer.fromJson<DateTime?>(json['fixedStartDate']),
      fixedMaturityDate: serializer.fromJson<DateTime?>(
        json['fixedMaturityDate'],
      ),
      fixedTermMonths: serializer.fromJson<int?>(json['fixedTermMonths']),
      goldProductType: serializer.fromJson<String>(json['goldProductType']),
      goldQuantity: serializer.fromJson<double?>(json['goldQuantity']),
      goldBuyPriceCents: serializer.fromJson<int?>(json['goldBuyPriceCents']),
      goldCurrentPriceCents: serializer.fromJson<int?>(
        json['goldCurrentPriceCents'],
      ),
      estatePurchasePriceCents: serializer.fromJson<int?>(
        json['estatePurchasePriceCents'],
      ),
      estateCurrentValueCents: serializer.fromJson<int?>(
        json['estateCurrentValueCents'],
      ),
      estatePurchaseDate: serializer.fromJson<DateTime?>(
        json['estatePurchaseDate'],
      ),
      estateDepreciationRate: serializer.fromJson<double?>(
        json['estateDepreciationRate'],
      ),
      loanOriginalCents: serializer.fromJson<int?>(json['loanOriginalCents']),
      loanRemainingCents: serializer.fromJson<int?>(json['loanRemainingCents']),
      loanMonthlyCents: serializer.fromJson<int?>(json['loanMonthlyCents']),
      loanNextPaymentDate: serializer.fromJson<DateTime?>(
        json['loanNextPaymentDate'],
      ),
      status: serializer.fromJson<int>(json['status']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'accountType': serializer.toJson<int>(accountType),
      'category': serializer.toJson<int>(category),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'initialBalanceCents': serializer.toJson<int>(initialBalanceCents),
      'currentBalanceCents': serializer.toJson<int>(currentBalanceCents),
      'ownership': serializer.toJson<int>(ownership),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<String>(color),
      'chartCode': serializer.toJson<String>(chartCode),
      'parentId': serializer.toJson<String?>(parentId),
      'isSystem': serializer.toJson<bool>(isSystem),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'institution': serializer.toJson<String>(institution),
      'creditLimitCents': serializer.toJson<int?>(creditLimitCents),
      'cardNumberTail': serializer.toJson<String>(cardNumberTail),
      'notes': serializer.toJson<String>(notes),
      'openingDate': serializer.toJson<DateTime?>(openingDate),
      'interestRate': serializer.toJson<double?>(interestRate),
      'creditBillingDay': serializer.toJson<int?>(creditBillingDay),
      'creditRepaymentDay': serializer.toJson<int?>(creditRepaymentDay),
      'creditAnnualFeeCents': serializer.toJson<int?>(creditAnnualFeeCents),
      'investCostCents': serializer.toJson<int?>(investCostCents),
      'investMarketValueCents': serializer.toJson<int?>(investMarketValueCents),
      'investReturnYtd': serializer.toJson<double?>(investReturnYtd),
      'fixedPrincipalCents': serializer.toJson<int?>(fixedPrincipalCents),
      'fixedStartDate': serializer.toJson<DateTime?>(fixedStartDate),
      'fixedMaturityDate': serializer.toJson<DateTime?>(fixedMaturityDate),
      'fixedTermMonths': serializer.toJson<int?>(fixedTermMonths),
      'goldProductType': serializer.toJson<String>(goldProductType),
      'goldQuantity': serializer.toJson<double?>(goldQuantity),
      'goldBuyPriceCents': serializer.toJson<int?>(goldBuyPriceCents),
      'goldCurrentPriceCents': serializer.toJson<int?>(goldCurrentPriceCents),
      'estatePurchasePriceCents': serializer.toJson<int?>(
        estatePurchasePriceCents,
      ),
      'estateCurrentValueCents': serializer.toJson<int?>(
        estateCurrentValueCents,
      ),
      'estatePurchaseDate': serializer.toJson<DateTime?>(estatePurchaseDate),
      'estateDepreciationRate': serializer.toJson<double?>(
        estateDepreciationRate,
      ),
      'loanOriginalCents': serializer.toJson<int?>(loanOriginalCents),
      'loanRemainingCents': serializer.toJson<int?>(loanRemainingCents),
      'loanMonthlyCents': serializer.toJson<int?>(loanMonthlyCents),
      'loanNextPaymentDate': serializer.toJson<DateTime?>(loanNextPaymentDate),
      'status': serializer.toJson<int>(status),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Account copyWith({
    String? id,
    String? name,
    int? accountType,
    int? category,
    String? currencyCode,
    int? initialBalanceCents,
    int? currentBalanceCents,
    int? ownership,
    String? icon,
    String? color,
    String? chartCode,
    Value<String?> parentId = const Value.absent(),
    bool? isSystem,
    int? sortOrder,
    String? institution,
    Value<int?> creditLimitCents = const Value.absent(),
    String? cardNumberTail,
    String? notes,
    Value<DateTime?> openingDate = const Value.absent(),
    Value<double?> interestRate = const Value.absent(),
    Value<int?> creditBillingDay = const Value.absent(),
    Value<int?> creditRepaymentDay = const Value.absent(),
    Value<int?> creditAnnualFeeCents = const Value.absent(),
    Value<int?> investCostCents = const Value.absent(),
    Value<int?> investMarketValueCents = const Value.absent(),
    Value<double?> investReturnYtd = const Value.absent(),
    Value<int?> fixedPrincipalCents = const Value.absent(),
    Value<DateTime?> fixedStartDate = const Value.absent(),
    Value<DateTime?> fixedMaturityDate = const Value.absent(),
    Value<int?> fixedTermMonths = const Value.absent(),
    String? goldProductType,
    Value<double?> goldQuantity = const Value.absent(),
    Value<int?> goldBuyPriceCents = const Value.absent(),
    Value<int?> goldCurrentPriceCents = const Value.absent(),
    Value<int?> estatePurchasePriceCents = const Value.absent(),
    Value<int?> estateCurrentValueCents = const Value.absent(),
    Value<DateTime?> estatePurchaseDate = const Value.absent(),
    Value<double?> estateDepreciationRate = const Value.absent(),
    Value<int?> loanOriginalCents = const Value.absent(),
    Value<int?> loanRemainingCents = const Value.absent(),
    Value<int?> loanMonthlyCents = const Value.absent(),
    Value<DateTime?> loanNextPaymentDate = const Value.absent(),
    int? status,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Account(
    id: id ?? this.id,
    name: name ?? this.name,
    accountType: accountType ?? this.accountType,
    category: category ?? this.category,
    currencyCode: currencyCode ?? this.currencyCode,
    initialBalanceCents: initialBalanceCents ?? this.initialBalanceCents,
    currentBalanceCents: currentBalanceCents ?? this.currentBalanceCents,
    ownership: ownership ?? this.ownership,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    chartCode: chartCode ?? this.chartCode,
    parentId: parentId.present ? parentId.value : this.parentId,
    isSystem: isSystem ?? this.isSystem,
    sortOrder: sortOrder ?? this.sortOrder,
    institution: institution ?? this.institution,
    creditLimitCents: creditLimitCents.present
        ? creditLimitCents.value
        : this.creditLimitCents,
    cardNumberTail: cardNumberTail ?? this.cardNumberTail,
    notes: notes ?? this.notes,
    openingDate: openingDate.present ? openingDate.value : this.openingDate,
    interestRate: interestRate.present ? interestRate.value : this.interestRate,
    creditBillingDay: creditBillingDay.present
        ? creditBillingDay.value
        : this.creditBillingDay,
    creditRepaymentDay: creditRepaymentDay.present
        ? creditRepaymentDay.value
        : this.creditRepaymentDay,
    creditAnnualFeeCents: creditAnnualFeeCents.present
        ? creditAnnualFeeCents.value
        : this.creditAnnualFeeCents,
    investCostCents: investCostCents.present
        ? investCostCents.value
        : this.investCostCents,
    investMarketValueCents: investMarketValueCents.present
        ? investMarketValueCents.value
        : this.investMarketValueCents,
    investReturnYtd: investReturnYtd.present
        ? investReturnYtd.value
        : this.investReturnYtd,
    fixedPrincipalCents: fixedPrincipalCents.present
        ? fixedPrincipalCents.value
        : this.fixedPrincipalCents,
    fixedStartDate: fixedStartDate.present
        ? fixedStartDate.value
        : this.fixedStartDate,
    fixedMaturityDate: fixedMaturityDate.present
        ? fixedMaturityDate.value
        : this.fixedMaturityDate,
    fixedTermMonths: fixedTermMonths.present
        ? fixedTermMonths.value
        : this.fixedTermMonths,
    goldProductType: goldProductType ?? this.goldProductType,
    goldQuantity: goldQuantity.present ? goldQuantity.value : this.goldQuantity,
    goldBuyPriceCents: goldBuyPriceCents.present
        ? goldBuyPriceCents.value
        : this.goldBuyPriceCents,
    goldCurrentPriceCents: goldCurrentPriceCents.present
        ? goldCurrentPriceCents.value
        : this.goldCurrentPriceCents,
    estatePurchasePriceCents: estatePurchasePriceCents.present
        ? estatePurchasePriceCents.value
        : this.estatePurchasePriceCents,
    estateCurrentValueCents: estateCurrentValueCents.present
        ? estateCurrentValueCents.value
        : this.estateCurrentValueCents,
    estatePurchaseDate: estatePurchaseDate.present
        ? estatePurchaseDate.value
        : this.estatePurchaseDate,
    estateDepreciationRate: estateDepreciationRate.present
        ? estateDepreciationRate.value
        : this.estateDepreciationRate,
    loanOriginalCents: loanOriginalCents.present
        ? loanOriginalCents.value
        : this.loanOriginalCents,
    loanRemainingCents: loanRemainingCents.present
        ? loanRemainingCents.value
        : this.loanRemainingCents,
    loanMonthlyCents: loanMonthlyCents.present
        ? loanMonthlyCents.value
        : this.loanMonthlyCents,
    loanNextPaymentDate: loanNextPaymentDate.present
        ? loanNextPaymentDate.value
        : this.loanNextPaymentDate,
    status: status ?? this.status,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      accountType: data.accountType.present
          ? data.accountType.value
          : this.accountType,
      category: data.category.present ? data.category.value : this.category,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      initialBalanceCents: data.initialBalanceCents.present
          ? data.initialBalanceCents.value
          : this.initialBalanceCents,
      currentBalanceCents: data.currentBalanceCents.present
          ? data.currentBalanceCents.value
          : this.currentBalanceCents,
      ownership: data.ownership.present ? data.ownership.value : this.ownership,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      chartCode: data.chartCode.present ? data.chartCode.value : this.chartCode,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      institution: data.institution.present
          ? data.institution.value
          : this.institution,
      creditLimitCents: data.creditLimitCents.present
          ? data.creditLimitCents.value
          : this.creditLimitCents,
      cardNumberTail: data.cardNumberTail.present
          ? data.cardNumberTail.value
          : this.cardNumberTail,
      notes: data.notes.present ? data.notes.value : this.notes,
      openingDate: data.openingDate.present
          ? data.openingDate.value
          : this.openingDate,
      interestRate: data.interestRate.present
          ? data.interestRate.value
          : this.interestRate,
      creditBillingDay: data.creditBillingDay.present
          ? data.creditBillingDay.value
          : this.creditBillingDay,
      creditRepaymentDay: data.creditRepaymentDay.present
          ? data.creditRepaymentDay.value
          : this.creditRepaymentDay,
      creditAnnualFeeCents: data.creditAnnualFeeCents.present
          ? data.creditAnnualFeeCents.value
          : this.creditAnnualFeeCents,
      investCostCents: data.investCostCents.present
          ? data.investCostCents.value
          : this.investCostCents,
      investMarketValueCents: data.investMarketValueCents.present
          ? data.investMarketValueCents.value
          : this.investMarketValueCents,
      investReturnYtd: data.investReturnYtd.present
          ? data.investReturnYtd.value
          : this.investReturnYtd,
      fixedPrincipalCents: data.fixedPrincipalCents.present
          ? data.fixedPrincipalCents.value
          : this.fixedPrincipalCents,
      fixedStartDate: data.fixedStartDate.present
          ? data.fixedStartDate.value
          : this.fixedStartDate,
      fixedMaturityDate: data.fixedMaturityDate.present
          ? data.fixedMaturityDate.value
          : this.fixedMaturityDate,
      fixedTermMonths: data.fixedTermMonths.present
          ? data.fixedTermMonths.value
          : this.fixedTermMonths,
      goldProductType: data.goldProductType.present
          ? data.goldProductType.value
          : this.goldProductType,
      goldQuantity: data.goldQuantity.present
          ? data.goldQuantity.value
          : this.goldQuantity,
      goldBuyPriceCents: data.goldBuyPriceCents.present
          ? data.goldBuyPriceCents.value
          : this.goldBuyPriceCents,
      goldCurrentPriceCents: data.goldCurrentPriceCents.present
          ? data.goldCurrentPriceCents.value
          : this.goldCurrentPriceCents,
      estatePurchasePriceCents: data.estatePurchasePriceCents.present
          ? data.estatePurchasePriceCents.value
          : this.estatePurchasePriceCents,
      estateCurrentValueCents: data.estateCurrentValueCents.present
          ? data.estateCurrentValueCents.value
          : this.estateCurrentValueCents,
      estatePurchaseDate: data.estatePurchaseDate.present
          ? data.estatePurchaseDate.value
          : this.estatePurchaseDate,
      estateDepreciationRate: data.estateDepreciationRate.present
          ? data.estateDepreciationRate.value
          : this.estateDepreciationRate,
      loanOriginalCents: data.loanOriginalCents.present
          ? data.loanOriginalCents.value
          : this.loanOriginalCents,
      loanRemainingCents: data.loanRemainingCents.present
          ? data.loanRemainingCents.value
          : this.loanRemainingCents,
      loanMonthlyCents: data.loanMonthlyCents.present
          ? data.loanMonthlyCents.value
          : this.loanMonthlyCents,
      loanNextPaymentDate: data.loanNextPaymentDate.present
          ? data.loanNextPaymentDate.value
          : this.loanNextPaymentDate,
      status: data.status.present ? data.status.value : this.status,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('accountType: $accountType, ')
          ..write('category: $category, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('initialBalanceCents: $initialBalanceCents, ')
          ..write('currentBalanceCents: $currentBalanceCents, ')
          ..write('ownership: $ownership, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('chartCode: $chartCode, ')
          ..write('parentId: $parentId, ')
          ..write('isSystem: $isSystem, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('institution: $institution, ')
          ..write('creditLimitCents: $creditLimitCents, ')
          ..write('cardNumberTail: $cardNumberTail, ')
          ..write('notes: $notes, ')
          ..write('openingDate: $openingDate, ')
          ..write('interestRate: $interestRate, ')
          ..write('creditBillingDay: $creditBillingDay, ')
          ..write('creditRepaymentDay: $creditRepaymentDay, ')
          ..write('creditAnnualFeeCents: $creditAnnualFeeCents, ')
          ..write('investCostCents: $investCostCents, ')
          ..write('investMarketValueCents: $investMarketValueCents, ')
          ..write('investReturnYtd: $investReturnYtd, ')
          ..write('fixedPrincipalCents: $fixedPrincipalCents, ')
          ..write('fixedStartDate: $fixedStartDate, ')
          ..write('fixedMaturityDate: $fixedMaturityDate, ')
          ..write('fixedTermMonths: $fixedTermMonths, ')
          ..write('goldProductType: $goldProductType, ')
          ..write('goldQuantity: $goldQuantity, ')
          ..write('goldBuyPriceCents: $goldBuyPriceCents, ')
          ..write('goldCurrentPriceCents: $goldCurrentPriceCents, ')
          ..write('estatePurchasePriceCents: $estatePurchasePriceCents, ')
          ..write('estateCurrentValueCents: $estateCurrentValueCents, ')
          ..write('estatePurchaseDate: $estatePurchaseDate, ')
          ..write('estateDepreciationRate: $estateDepreciationRate, ')
          ..write('loanOriginalCents: $loanOriginalCents, ')
          ..write('loanRemainingCents: $loanRemainingCents, ')
          ..write('loanMonthlyCents: $loanMonthlyCents, ')
          ..write('loanNextPaymentDate: $loanNextPaymentDate, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    accountType,
    category,
    currencyCode,
    initialBalanceCents,
    currentBalanceCents,
    ownership,
    icon,
    color,
    chartCode,
    parentId,
    isSystem,
    sortOrder,
    institution,
    creditLimitCents,
    cardNumberTail,
    notes,
    openingDate,
    interestRate,
    creditBillingDay,
    creditRepaymentDay,
    creditAnnualFeeCents,
    investCostCents,
    investMarketValueCents,
    investReturnYtd,
    fixedPrincipalCents,
    fixedStartDate,
    fixedMaturityDate,
    fixedTermMonths,
    goldProductType,
    goldQuantity,
    goldBuyPriceCents,
    goldCurrentPriceCents,
    estatePurchasePriceCents,
    estateCurrentValueCents,
    estatePurchaseDate,
    estateDepreciationRate,
    loanOriginalCents,
    loanRemainingCents,
    loanMonthlyCents,
    loanNextPaymentDate,
    status,
    version,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.name == this.name &&
          other.accountType == this.accountType &&
          other.category == this.category &&
          other.currencyCode == this.currencyCode &&
          other.initialBalanceCents == this.initialBalanceCents &&
          other.currentBalanceCents == this.currentBalanceCents &&
          other.ownership == this.ownership &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.chartCode == this.chartCode &&
          other.parentId == this.parentId &&
          other.isSystem == this.isSystem &&
          other.sortOrder == this.sortOrder &&
          other.institution == this.institution &&
          other.creditLimitCents == this.creditLimitCents &&
          other.cardNumberTail == this.cardNumberTail &&
          other.notes == this.notes &&
          other.openingDate == this.openingDate &&
          other.interestRate == this.interestRate &&
          other.creditBillingDay == this.creditBillingDay &&
          other.creditRepaymentDay == this.creditRepaymentDay &&
          other.creditAnnualFeeCents == this.creditAnnualFeeCents &&
          other.investCostCents == this.investCostCents &&
          other.investMarketValueCents == this.investMarketValueCents &&
          other.investReturnYtd == this.investReturnYtd &&
          other.fixedPrincipalCents == this.fixedPrincipalCents &&
          other.fixedStartDate == this.fixedStartDate &&
          other.fixedMaturityDate == this.fixedMaturityDate &&
          other.fixedTermMonths == this.fixedTermMonths &&
          other.goldProductType == this.goldProductType &&
          other.goldQuantity == this.goldQuantity &&
          other.goldBuyPriceCents == this.goldBuyPriceCents &&
          other.goldCurrentPriceCents == this.goldCurrentPriceCents &&
          other.estatePurchasePriceCents == this.estatePurchasePriceCents &&
          other.estateCurrentValueCents == this.estateCurrentValueCents &&
          other.estatePurchaseDate == this.estatePurchaseDate &&
          other.estateDepreciationRate == this.estateDepreciationRate &&
          other.loanOriginalCents == this.loanOriginalCents &&
          other.loanRemainingCents == this.loanRemainingCents &&
          other.loanMonthlyCents == this.loanMonthlyCents &&
          other.loanNextPaymentDate == this.loanNextPaymentDate &&
          other.status == this.status &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> accountType;
  final Value<int> category;
  final Value<String> currencyCode;
  final Value<int> initialBalanceCents;
  final Value<int> currentBalanceCents;
  final Value<int> ownership;
  final Value<String> icon;
  final Value<String> color;
  final Value<String> chartCode;
  final Value<String?> parentId;
  final Value<bool> isSystem;
  final Value<int> sortOrder;
  final Value<String> institution;
  final Value<int?> creditLimitCents;
  final Value<String> cardNumberTail;
  final Value<String> notes;
  final Value<DateTime?> openingDate;
  final Value<double?> interestRate;
  final Value<int?> creditBillingDay;
  final Value<int?> creditRepaymentDay;
  final Value<int?> creditAnnualFeeCents;
  final Value<int?> investCostCents;
  final Value<int?> investMarketValueCents;
  final Value<double?> investReturnYtd;
  final Value<int?> fixedPrincipalCents;
  final Value<DateTime?> fixedStartDate;
  final Value<DateTime?> fixedMaturityDate;
  final Value<int?> fixedTermMonths;
  final Value<String> goldProductType;
  final Value<double?> goldQuantity;
  final Value<int?> goldBuyPriceCents;
  final Value<int?> goldCurrentPriceCents;
  final Value<int?> estatePurchasePriceCents;
  final Value<int?> estateCurrentValueCents;
  final Value<DateTime?> estatePurchaseDate;
  final Value<double?> estateDepreciationRate;
  final Value<int?> loanOriginalCents;
  final Value<int?> loanRemainingCents;
  final Value<int?> loanMonthlyCents;
  final Value<DateTime?> loanNextPaymentDate;
  final Value<int> status;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.accountType = const Value.absent(),
    this.category = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.initialBalanceCents = const Value.absent(),
    this.currentBalanceCents = const Value.absent(),
    this.ownership = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.chartCode = const Value.absent(),
    this.parentId = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.institution = const Value.absent(),
    this.creditLimitCents = const Value.absent(),
    this.cardNumberTail = const Value.absent(),
    this.notes = const Value.absent(),
    this.openingDate = const Value.absent(),
    this.interestRate = const Value.absent(),
    this.creditBillingDay = const Value.absent(),
    this.creditRepaymentDay = const Value.absent(),
    this.creditAnnualFeeCents = const Value.absent(),
    this.investCostCents = const Value.absent(),
    this.investMarketValueCents = const Value.absent(),
    this.investReturnYtd = const Value.absent(),
    this.fixedPrincipalCents = const Value.absent(),
    this.fixedStartDate = const Value.absent(),
    this.fixedMaturityDate = const Value.absent(),
    this.fixedTermMonths = const Value.absent(),
    this.goldProductType = const Value.absent(),
    this.goldQuantity = const Value.absent(),
    this.goldBuyPriceCents = const Value.absent(),
    this.goldCurrentPriceCents = const Value.absent(),
    this.estatePurchasePriceCents = const Value.absent(),
    this.estateCurrentValueCents = const Value.absent(),
    this.estatePurchaseDate = const Value.absent(),
    this.estateDepreciationRate = const Value.absent(),
    this.loanOriginalCents = const Value.absent(),
    this.loanRemainingCents = const Value.absent(),
    this.loanMonthlyCents = const Value.absent(),
    this.loanNextPaymentDate = const Value.absent(),
    this.status = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AccountsCompanion.insert({
    required String id,
    required String name,
    required int accountType,
    required int category,
    required String currencyCode,
    required int initialBalanceCents,
    required int currentBalanceCents,
    required int ownership,
    required String icon,
    required String color,
    required String chartCode,
    this.parentId = const Value.absent(),
    required bool isSystem,
    required int sortOrder,
    required String institution,
    this.creditLimitCents = const Value.absent(),
    required String cardNumberTail,
    required String notes,
    this.openingDate = const Value.absent(),
    this.interestRate = const Value.absent(),
    this.creditBillingDay = const Value.absent(),
    this.creditRepaymentDay = const Value.absent(),
    this.creditAnnualFeeCents = const Value.absent(),
    this.investCostCents = const Value.absent(),
    this.investMarketValueCents = const Value.absent(),
    this.investReturnYtd = const Value.absent(),
    this.fixedPrincipalCents = const Value.absent(),
    this.fixedStartDate = const Value.absent(),
    this.fixedMaturityDate = const Value.absent(),
    this.fixedTermMonths = const Value.absent(),
    required String goldProductType,
    this.goldQuantity = const Value.absent(),
    this.goldBuyPriceCents = const Value.absent(),
    this.goldCurrentPriceCents = const Value.absent(),
    this.estatePurchasePriceCents = const Value.absent(),
    this.estateCurrentValueCents = const Value.absent(),
    this.estatePurchaseDate = const Value.absent(),
    this.estateDepreciationRate = const Value.absent(),
    this.loanOriginalCents = const Value.absent(),
    this.loanRemainingCents = const Value.absent(),
    this.loanMonthlyCents = const Value.absent(),
    this.loanNextPaymentDate = const Value.absent(),
    required int status,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       accountType = Value(accountType),
       category = Value(category),
       currencyCode = Value(currencyCode),
       initialBalanceCents = Value(initialBalanceCents),
       currentBalanceCents = Value(currentBalanceCents),
       ownership = Value(ownership),
       icon = Value(icon),
       color = Value(color),
       chartCode = Value(chartCode),
       isSystem = Value(isSystem),
       sortOrder = Value(sortOrder),
       institution = Value(institution),
       cardNumberTail = Value(cardNumberTail),
       notes = Value(notes),
       goldProductType = Value(goldProductType),
       status = Value(status),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Account> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? accountType,
    Expression<int>? category,
    Expression<String>? currencyCode,
    Expression<int>? initialBalanceCents,
    Expression<int>? currentBalanceCents,
    Expression<int>? ownership,
    Expression<String>? icon,
    Expression<String>? color,
    Expression<String>? chartCode,
    Expression<String>? parentId,
    Expression<bool>? isSystem,
    Expression<int>? sortOrder,
    Expression<String>? institution,
    Expression<int>? creditLimitCents,
    Expression<String>? cardNumberTail,
    Expression<String>? notes,
    Expression<DateTime>? openingDate,
    Expression<double>? interestRate,
    Expression<int>? creditBillingDay,
    Expression<int>? creditRepaymentDay,
    Expression<int>? creditAnnualFeeCents,
    Expression<int>? investCostCents,
    Expression<int>? investMarketValueCents,
    Expression<double>? investReturnYtd,
    Expression<int>? fixedPrincipalCents,
    Expression<DateTime>? fixedStartDate,
    Expression<DateTime>? fixedMaturityDate,
    Expression<int>? fixedTermMonths,
    Expression<String>? goldProductType,
    Expression<double>? goldQuantity,
    Expression<int>? goldBuyPriceCents,
    Expression<int>? goldCurrentPriceCents,
    Expression<int>? estatePurchasePriceCents,
    Expression<int>? estateCurrentValueCents,
    Expression<DateTime>? estatePurchaseDate,
    Expression<double>? estateDepreciationRate,
    Expression<int>? loanOriginalCents,
    Expression<int>? loanRemainingCents,
    Expression<int>? loanMonthlyCents,
    Expression<DateTime>? loanNextPaymentDate,
    Expression<int>? status,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (accountType != null) 'account_type': accountType,
      if (category != null) 'category': category,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (initialBalanceCents != null)
        'initial_balance_cents': initialBalanceCents,
      if (currentBalanceCents != null)
        'current_balance_cents': currentBalanceCents,
      if (ownership != null) 'ownership': ownership,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (chartCode != null) 'chart_code': chartCode,
      if (parentId != null) 'parent_id': parentId,
      if (isSystem != null) 'is_system': isSystem,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (institution != null) 'institution': institution,
      if (creditLimitCents != null) 'credit_limit_cents': creditLimitCents,
      if (cardNumberTail != null) 'card_number_tail': cardNumberTail,
      if (notes != null) 'notes': notes,
      if (openingDate != null) 'opening_date': openingDate,
      if (interestRate != null) 'interest_rate': interestRate,
      if (creditBillingDay != null) 'credit_billing_day': creditBillingDay,
      if (creditRepaymentDay != null)
        'credit_repayment_day': creditRepaymentDay,
      if (creditAnnualFeeCents != null)
        'credit_annual_fee_cents': creditAnnualFeeCents,
      if (investCostCents != null) 'invest_cost_cents': investCostCents,
      if (investMarketValueCents != null)
        'invest_market_value_cents': investMarketValueCents,
      if (investReturnYtd != null) 'invest_return_ytd': investReturnYtd,
      if (fixedPrincipalCents != null)
        'fixed_principal_cents': fixedPrincipalCents,
      if (fixedStartDate != null) 'fixed_start_date': fixedStartDate,
      if (fixedMaturityDate != null) 'fixed_maturity_date': fixedMaturityDate,
      if (fixedTermMonths != null) 'fixed_term_months': fixedTermMonths,
      if (goldProductType != null) 'gold_product_type': goldProductType,
      if (goldQuantity != null) 'gold_quantity': goldQuantity,
      if (goldBuyPriceCents != null) 'gold_buy_price_cents': goldBuyPriceCents,
      if (goldCurrentPriceCents != null)
        'gold_current_price_cents': goldCurrentPriceCents,
      if (estatePurchasePriceCents != null)
        'estate_purchase_price_cents': estatePurchasePriceCents,
      if (estateCurrentValueCents != null)
        'estate_current_value_cents': estateCurrentValueCents,
      if (estatePurchaseDate != null)
        'estate_purchase_date': estatePurchaseDate,
      if (estateDepreciationRate != null)
        'estate_depreciation_rate': estateDepreciationRate,
      if (loanOriginalCents != null) 'loan_original_cents': loanOriginalCents,
      if (loanRemainingCents != null)
        'loan_remaining_cents': loanRemainingCents,
      if (loanMonthlyCents != null) 'loan_monthly_cents': loanMonthlyCents,
      if (loanNextPaymentDate != null)
        'loan_next_payment_date': loanNextPaymentDate,
      if (status != null) 'status': status,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AccountsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? accountType,
    Value<int>? category,
    Value<String>? currencyCode,
    Value<int>? initialBalanceCents,
    Value<int>? currentBalanceCents,
    Value<int>? ownership,
    Value<String>? icon,
    Value<String>? color,
    Value<String>? chartCode,
    Value<String?>? parentId,
    Value<bool>? isSystem,
    Value<int>? sortOrder,
    Value<String>? institution,
    Value<int?>? creditLimitCents,
    Value<String>? cardNumberTail,
    Value<String>? notes,
    Value<DateTime?>? openingDate,
    Value<double?>? interestRate,
    Value<int?>? creditBillingDay,
    Value<int?>? creditRepaymentDay,
    Value<int?>? creditAnnualFeeCents,
    Value<int?>? investCostCents,
    Value<int?>? investMarketValueCents,
    Value<double?>? investReturnYtd,
    Value<int?>? fixedPrincipalCents,
    Value<DateTime?>? fixedStartDate,
    Value<DateTime?>? fixedMaturityDate,
    Value<int?>? fixedTermMonths,
    Value<String>? goldProductType,
    Value<double?>? goldQuantity,
    Value<int?>? goldBuyPriceCents,
    Value<int?>? goldCurrentPriceCents,
    Value<int?>? estatePurchasePriceCents,
    Value<int?>? estateCurrentValueCents,
    Value<DateTime?>? estatePurchaseDate,
    Value<double?>? estateDepreciationRate,
    Value<int?>? loanOriginalCents,
    Value<int?>? loanRemainingCents,
    Value<int?>? loanMonthlyCents,
    Value<DateTime?>? loanNextPaymentDate,
    Value<int>? status,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AccountsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      category: category ?? this.category,
      currencyCode: currencyCode ?? this.currencyCode,
      initialBalanceCents: initialBalanceCents ?? this.initialBalanceCents,
      currentBalanceCents: currentBalanceCents ?? this.currentBalanceCents,
      ownership: ownership ?? this.ownership,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      chartCode: chartCode ?? this.chartCode,
      parentId: parentId ?? this.parentId,
      isSystem: isSystem ?? this.isSystem,
      sortOrder: sortOrder ?? this.sortOrder,
      institution: institution ?? this.institution,
      creditLimitCents: creditLimitCents ?? this.creditLimitCents,
      cardNumberTail: cardNumberTail ?? this.cardNumberTail,
      notes: notes ?? this.notes,
      openingDate: openingDate ?? this.openingDate,
      interestRate: interestRate ?? this.interestRate,
      creditBillingDay: creditBillingDay ?? this.creditBillingDay,
      creditRepaymentDay: creditRepaymentDay ?? this.creditRepaymentDay,
      creditAnnualFeeCents: creditAnnualFeeCents ?? this.creditAnnualFeeCents,
      investCostCents: investCostCents ?? this.investCostCents,
      investMarketValueCents:
          investMarketValueCents ?? this.investMarketValueCents,
      investReturnYtd: investReturnYtd ?? this.investReturnYtd,
      fixedPrincipalCents: fixedPrincipalCents ?? this.fixedPrincipalCents,
      fixedStartDate: fixedStartDate ?? this.fixedStartDate,
      fixedMaturityDate: fixedMaturityDate ?? this.fixedMaturityDate,
      fixedTermMonths: fixedTermMonths ?? this.fixedTermMonths,
      goldProductType: goldProductType ?? this.goldProductType,
      goldQuantity: goldQuantity ?? this.goldQuantity,
      goldBuyPriceCents: goldBuyPriceCents ?? this.goldBuyPriceCents,
      goldCurrentPriceCents:
          goldCurrentPriceCents ?? this.goldCurrentPriceCents,
      estatePurchasePriceCents:
          estatePurchasePriceCents ?? this.estatePurchasePriceCents,
      estateCurrentValueCents:
          estateCurrentValueCents ?? this.estateCurrentValueCents,
      estatePurchaseDate: estatePurchaseDate ?? this.estatePurchaseDate,
      estateDepreciationRate:
          estateDepreciationRate ?? this.estateDepreciationRate,
      loanOriginalCents: loanOriginalCents ?? this.loanOriginalCents,
      loanRemainingCents: loanRemainingCents ?? this.loanRemainingCents,
      loanMonthlyCents: loanMonthlyCents ?? this.loanMonthlyCents,
      loanNextPaymentDate: loanNextPaymentDate ?? this.loanNextPaymentDate,
      status: status ?? this.status,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (accountType.present) {
      map['account_type'] = Variable<int>(accountType.value);
    }
    if (category.present) {
      map['category'] = Variable<int>(category.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (initialBalanceCents.present) {
      map['initial_balance_cents'] = Variable<int>(initialBalanceCents.value);
    }
    if (currentBalanceCents.present) {
      map['current_balance_cents'] = Variable<int>(currentBalanceCents.value);
    }
    if (ownership.present) {
      map['ownership'] = Variable<int>(ownership.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (chartCode.present) {
      map['chart_code'] = Variable<String>(chartCode.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (institution.present) {
      map['institution'] = Variable<String>(institution.value);
    }
    if (creditLimitCents.present) {
      map['credit_limit_cents'] = Variable<int>(creditLimitCents.value);
    }
    if (cardNumberTail.present) {
      map['card_number_tail'] = Variable<String>(cardNumberTail.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (openingDate.present) {
      map['opening_date'] = Variable<DateTime>(openingDate.value);
    }
    if (interestRate.present) {
      map['interest_rate'] = Variable<double>(interestRate.value);
    }
    if (creditBillingDay.present) {
      map['credit_billing_day'] = Variable<int>(creditBillingDay.value);
    }
    if (creditRepaymentDay.present) {
      map['credit_repayment_day'] = Variable<int>(creditRepaymentDay.value);
    }
    if (creditAnnualFeeCents.present) {
      map['credit_annual_fee_cents'] = Variable<int>(
        creditAnnualFeeCents.value,
      );
    }
    if (investCostCents.present) {
      map['invest_cost_cents'] = Variable<int>(investCostCents.value);
    }
    if (investMarketValueCents.present) {
      map['invest_market_value_cents'] = Variable<int>(
        investMarketValueCents.value,
      );
    }
    if (investReturnYtd.present) {
      map['invest_return_ytd'] = Variable<double>(investReturnYtd.value);
    }
    if (fixedPrincipalCents.present) {
      map['fixed_principal_cents'] = Variable<int>(fixedPrincipalCents.value);
    }
    if (fixedStartDate.present) {
      map['fixed_start_date'] = Variable<DateTime>(fixedStartDate.value);
    }
    if (fixedMaturityDate.present) {
      map['fixed_maturity_date'] = Variable<DateTime>(fixedMaturityDate.value);
    }
    if (fixedTermMonths.present) {
      map['fixed_term_months'] = Variable<int>(fixedTermMonths.value);
    }
    if (goldProductType.present) {
      map['gold_product_type'] = Variable<String>(goldProductType.value);
    }
    if (goldQuantity.present) {
      map['gold_quantity'] = Variable<double>(goldQuantity.value);
    }
    if (goldBuyPriceCents.present) {
      map['gold_buy_price_cents'] = Variable<int>(goldBuyPriceCents.value);
    }
    if (goldCurrentPriceCents.present) {
      map['gold_current_price_cents'] = Variable<int>(
        goldCurrentPriceCents.value,
      );
    }
    if (estatePurchasePriceCents.present) {
      map['estate_purchase_price_cents'] = Variable<int>(
        estatePurchasePriceCents.value,
      );
    }
    if (estateCurrentValueCents.present) {
      map['estate_current_value_cents'] = Variable<int>(
        estateCurrentValueCents.value,
      );
    }
    if (estatePurchaseDate.present) {
      map['estate_purchase_date'] = Variable<DateTime>(
        estatePurchaseDate.value,
      );
    }
    if (estateDepreciationRate.present) {
      map['estate_depreciation_rate'] = Variable<double>(
        estateDepreciationRate.value,
      );
    }
    if (loanOriginalCents.present) {
      map['loan_original_cents'] = Variable<int>(loanOriginalCents.value);
    }
    if (loanRemainingCents.present) {
      map['loan_remaining_cents'] = Variable<int>(loanRemainingCents.value);
    }
    if (loanMonthlyCents.present) {
      map['loan_monthly_cents'] = Variable<int>(loanMonthlyCents.value);
    }
    if (loanNextPaymentDate.present) {
      map['loan_next_payment_date'] = Variable<DateTime>(
        loanNextPaymentDate.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<int>(status.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('accountType: $accountType, ')
          ..write('category: $category, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('initialBalanceCents: $initialBalanceCents, ')
          ..write('currentBalanceCents: $currentBalanceCents, ')
          ..write('ownership: $ownership, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('chartCode: $chartCode, ')
          ..write('parentId: $parentId, ')
          ..write('isSystem: $isSystem, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('institution: $institution, ')
          ..write('creditLimitCents: $creditLimitCents, ')
          ..write('cardNumberTail: $cardNumberTail, ')
          ..write('notes: $notes, ')
          ..write('openingDate: $openingDate, ')
          ..write('interestRate: $interestRate, ')
          ..write('creditBillingDay: $creditBillingDay, ')
          ..write('creditRepaymentDay: $creditRepaymentDay, ')
          ..write('creditAnnualFeeCents: $creditAnnualFeeCents, ')
          ..write('investCostCents: $investCostCents, ')
          ..write('investMarketValueCents: $investMarketValueCents, ')
          ..write('investReturnYtd: $investReturnYtd, ')
          ..write('fixedPrincipalCents: $fixedPrincipalCents, ')
          ..write('fixedStartDate: $fixedStartDate, ')
          ..write('fixedMaturityDate: $fixedMaturityDate, ')
          ..write('fixedTermMonths: $fixedTermMonths, ')
          ..write('goldProductType: $goldProductType, ')
          ..write('goldQuantity: $goldQuantity, ')
          ..write('goldBuyPriceCents: $goldBuyPriceCents, ')
          ..write('goldCurrentPriceCents: $goldCurrentPriceCents, ')
          ..write('estatePurchasePriceCents: $estatePurchasePriceCents, ')
          ..write('estateCurrentValueCents: $estateCurrentValueCents, ')
          ..write('estatePurchaseDate: $estatePurchaseDate, ')
          ..write('estateDepreciationRate: $estateDepreciationRate, ')
          ..write('loanOriginalCents: $loanOriginalCents, ')
          ..write('loanRemainingCents: $loanRemainingCents, ')
          ..write('loanMonthlyCents: $loanMonthlyCents, ')
          ..write('loanNextPaymentDate: $loanNextPaymentDate, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChartOfAccountsTable extends ChartOfAccounts
    with TableInfo<$ChartOfAccountsTable, ChartOfAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChartOfAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountTypeMeta = const VerificationMeta(
    'accountType',
  );
  @override
  late final GeneratedColumn<int> accountType = GeneratedColumn<int>(
    'account_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentCodeMeta = const VerificationMeta(
    'parentCode',
  );
  @override
  late final GeneratedColumn<String> parentCode = GeneratedColumn<String>(
    'parent_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _balanceDirectionMeta = const VerificationMeta(
    'balanceDirection',
  );
  @override
  late final GeneratedColumn<int> balanceDirection = GeneratedColumn<int>(
    'balance_direction',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    code,
    name,
    level,
    accountType,
    parentCode,
    balanceDirection,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chart_of_accounts';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChartOfAccount> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    } else if (isInserting) {
      context.missing(_levelMeta);
    }
    if (data.containsKey('account_type')) {
      context.handle(
        _accountTypeMeta,
        accountType.isAcceptableOrUnknown(
          data['account_type']!,
          _accountTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_accountTypeMeta);
    }
    if (data.containsKey('parent_code')) {
      context.handle(
        _parentCodeMeta,
        parentCode.isAcceptableOrUnknown(data['parent_code']!, _parentCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_parentCodeMeta);
    }
    if (data.containsKey('balance_direction')) {
      context.handle(
        _balanceDirectionMeta,
        balanceDirection.isAcceptableOrUnknown(
          data['balance_direction']!,
          _balanceDirectionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_balanceDirectionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  ChartOfAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChartOfAccount(
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      )!,
      accountType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}account_type'],
      )!,
      parentCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_code'],
      )!,
      balanceDirection: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}balance_direction'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ChartOfAccountsTable createAlias(String alias) {
    return $ChartOfAccountsTable(attachedDatabase, alias);
  }
}

class ChartOfAccount extends DataClass implements Insertable<ChartOfAccount> {
  final String code;
  final String name;
  final int level;
  final int accountType;
  final String parentCode;
  final int balanceDirection;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ChartOfAccount({
    required this.code,
    required this.name,
    required this.level,
    required this.accountType,
    required this.parentCode,
    required this.balanceDirection,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['level'] = Variable<int>(level);
    map['account_type'] = Variable<int>(accountType);
    map['parent_code'] = Variable<String>(parentCode);
    map['balance_direction'] = Variable<int>(balanceDirection);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ChartOfAccountsCompanion toCompanion(bool nullToAbsent) {
    return ChartOfAccountsCompanion(
      code: Value(code),
      name: Value(name),
      level: Value(level),
      accountType: Value(accountType),
      parentCode: Value(parentCode),
      balanceDirection: Value(balanceDirection),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ChartOfAccount.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChartOfAccount(
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      level: serializer.fromJson<int>(json['level']),
      accountType: serializer.fromJson<int>(json['accountType']),
      parentCode: serializer.fromJson<String>(json['parentCode']),
      balanceDirection: serializer.fromJson<int>(json['balanceDirection']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'level': serializer.toJson<int>(level),
      'accountType': serializer.toJson<int>(accountType),
      'parentCode': serializer.toJson<String>(parentCode),
      'balanceDirection': serializer.toJson<int>(balanceDirection),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ChartOfAccount copyWith({
    String? code,
    String? name,
    int? level,
    int? accountType,
    String? parentCode,
    int? balanceDirection,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ChartOfAccount(
    code: code ?? this.code,
    name: name ?? this.name,
    level: level ?? this.level,
    accountType: accountType ?? this.accountType,
    parentCode: parentCode ?? this.parentCode,
    balanceDirection: balanceDirection ?? this.balanceDirection,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ChartOfAccount copyWithCompanion(ChartOfAccountsCompanion data) {
    return ChartOfAccount(
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      level: data.level.present ? data.level.value : this.level,
      accountType: data.accountType.present
          ? data.accountType.value
          : this.accountType,
      parentCode: data.parentCode.present
          ? data.parentCode.value
          : this.parentCode,
      balanceDirection: data.balanceDirection.present
          ? data.balanceDirection.value
          : this.balanceDirection,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChartOfAccount(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('level: $level, ')
          ..write('accountType: $accountType, ')
          ..write('parentCode: $parentCode, ')
          ..write('balanceDirection: $balanceDirection, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    code,
    name,
    level,
    accountType,
    parentCode,
    balanceDirection,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChartOfAccount &&
          other.code == this.code &&
          other.name == this.name &&
          other.level == this.level &&
          other.accountType == this.accountType &&
          other.parentCode == this.parentCode &&
          other.balanceDirection == this.balanceDirection &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ChartOfAccountsCompanion extends UpdateCompanion<ChartOfAccount> {
  final Value<String> code;
  final Value<String> name;
  final Value<int> level;
  final Value<int> accountType;
  final Value<String> parentCode;
  final Value<int> balanceDirection;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ChartOfAccountsCompanion({
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.level = const Value.absent(),
    this.accountType = const Value.absent(),
    this.parentCode = const Value.absent(),
    this.balanceDirection = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChartOfAccountsCompanion.insert({
    required String code,
    required String name,
    required int level,
    required int accountType,
    required String parentCode,
    required int balanceDirection,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : code = Value(code),
       name = Value(name),
       level = Value(level),
       accountType = Value(accountType),
       parentCode = Value(parentCode),
       balanceDirection = Value(balanceDirection),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<ChartOfAccount> custom({
    Expression<String>? code,
    Expression<String>? name,
    Expression<int>? level,
    Expression<int>? accountType,
    Expression<String>? parentCode,
    Expression<int>? balanceDirection,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (level != null) 'level': level,
      if (accountType != null) 'account_type': accountType,
      if (parentCode != null) 'parent_code': parentCode,
      if (balanceDirection != null) 'balance_direction': balanceDirection,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChartOfAccountsCompanion copyWith({
    Value<String>? code,
    Value<String>? name,
    Value<int>? level,
    Value<int>? accountType,
    Value<String>? parentCode,
    Value<int>? balanceDirection,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ChartOfAccountsCompanion(
      code: code ?? this.code,
      name: name ?? this.name,
      level: level ?? this.level,
      accountType: accountType ?? this.accountType,
      parentCode: parentCode ?? this.parentCode,
      balanceDirection: balanceDirection ?? this.balanceDirection,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (accountType.present) {
      map['account_type'] = Variable<int>(accountType.value);
    }
    if (parentCode.present) {
      map['parent_code'] = Variable<String>(parentCode.value);
    }
    if (balanceDirection.present) {
      map['balance_direction'] = Variable<int>(balanceDirection.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChartOfAccountsCompanion(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('level: $level, ')
          ..write('accountType: $accountType, ')
          ..write('parentCode: $parentCode, ')
          ..write('balanceDirection: $balanceDirection, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionDateMeta = const VerificationMeta(
    'transactionDate',
  );
  @override
  late final GeneratedColumn<DateTime> transactionDate =
      GeneratedColumn<DateTime>(
        'transaction_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _transactionTimeMeta = const VerificationMeta(
    'transactionTime',
  );
  @override
  late final GeneratedColumn<DateTime> transactionTime =
      GeneratedColumn<DateTime>(
        'transaction_time',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transactionDate,
    transactionTime,
    description,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Transaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('transaction_date')) {
      context.handle(
        _transactionDateMeta,
        transactionDate.isAcceptableOrUnknown(
          data['transaction_date']!,
          _transactionDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionDateMeta);
    }
    if (data.containsKey('transaction_time')) {
      context.handle(
        _transactionTimeMeta,
        transactionTime.isAcceptableOrUnknown(
          data['transaction_time']!,
          _transactionTimeMeta,
        ),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      transactionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}transaction_date'],
      )!,
      transactionTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}transaction_time'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final String id;
  final DateTime transactionDate;
  final DateTime? transactionTime;
  final String description;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Transaction({
    required this.id,
    required this.transactionDate,
    this.transactionTime,
    required this.description,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['transaction_date'] = Variable<DateTime>(transactionDate);
    if (!nullToAbsent || transactionTime != null) {
      map['transaction_time'] = Variable<DateTime>(transactionTime);
    }
    map['description'] = Variable<String>(description);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      transactionDate: Value(transactionDate),
      transactionTime: transactionTime == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionTime),
      description: Value(description),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Transaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<String>(json['id']),
      transactionDate: serializer.fromJson<DateTime>(json['transactionDate']),
      transactionTime: serializer.fromJson<DateTime?>(json['transactionTime']),
      description: serializer.fromJson<String>(json['description']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'transactionDate': serializer.toJson<DateTime>(transactionDate),
      'transactionTime': serializer.toJson<DateTime?>(transactionTime),
      'description': serializer.toJson<String>(description),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Transaction copyWith({
    String? id,
    DateTime? transactionDate,
    Value<DateTime?> transactionTime = const Value.absent(),
    String? description,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Transaction(
    id: id ?? this.id,
    transactionDate: transactionDate ?? this.transactionDate,
    transactionTime: transactionTime.present
        ? transactionTime.value
        : this.transactionTime,
    description: description ?? this.description,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      transactionDate: data.transactionDate.present
          ? data.transactionDate.value
          : this.transactionDate,
      transactionTime: data.transactionTime.present
          ? data.transactionTime.value
          : this.transactionTime,
      description: data.description.present
          ? data.description.value
          : this.description,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('transactionTime: $transactionTime, ')
          ..write('description: $description, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionDate,
    transactionTime,
    description,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.transactionDate == this.transactionDate &&
          other.transactionTime == this.transactionTime &&
          other.description == this.description &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<String> id;
  final Value<DateTime> transactionDate;
  final Value<DateTime?> transactionTime;
  final Value<String> description;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.transactionDate = const Value.absent(),
    this.transactionTime = const Value.absent(),
    this.description = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionsCompanion.insert({
    required String id,
    required DateTime transactionDate,
    this.transactionTime = const Value.absent(),
    required String description,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       transactionDate = Value(transactionDate),
       description = Value(description),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Transaction> custom({
    Expression<String>? id,
    Expression<DateTime>? transactionDate,
    Expression<DateTime>? transactionTime,
    Expression<String>? description,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionDate != null) 'transaction_date': transactionDate,
      if (transactionTime != null) 'transaction_time': transactionTime,
      if (description != null) 'description': description,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionsCompanion copyWith({
    Value<String>? id,
    Value<DateTime>? transactionDate,
    Value<DateTime?>? transactionTime,
    Value<String>? description,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TransactionsCompanion(
      id: id ?? this.id,
      transactionDate: transactionDate ?? this.transactionDate,
      transactionTime: transactionTime ?? this.transactionTime,
      description: description ?? this.description,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (transactionDate.present) {
      map['transaction_date'] = Variable<DateTime>(transactionDate.value);
    }
    if (transactionTime.present) {
      map['transaction_time'] = Variable<DateTime>(transactionTime.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('transactionDate: $transactionDate, ')
          ..write('transactionTime: $transactionTime, ')
          ..write('description: $description, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionEntriesTable extends TransactionEntries
    with TableInfo<$TransactionEntriesTable, TransactionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _chartOfAccountCodeMeta =
      const VerificationMeta('chartOfAccountCode');
  @override
  late final GeneratedColumn<String> chartOfAccountCode =
      GeneratedColumn<String>(
        'chart_of_account_code',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _debitCentsMeta = const VerificationMeta(
    'debitCents',
  );
  @override
  late final GeneratedColumn<int> debitCents = GeneratedColumn<int>(
    'debit_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _creditCentsMeta = const VerificationMeta(
    'creditCents',
  );
  @override
  late final GeneratedColumn<int> creditCents = GeneratedColumn<int>(
    'credit_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    transactionId,
    accountId,
    chartOfAccountCode,
    debitCents,
    creditCents,
    note,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('chart_of_account_code')) {
      context.handle(
        _chartOfAccountCodeMeta,
        chartOfAccountCode.isAcceptableOrUnknown(
          data['chart_of_account_code']!,
          _chartOfAccountCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_chartOfAccountCodeMeta);
    }
    if (data.containsKey('debit_cents')) {
      context.handle(
        _debitCentsMeta,
        debitCents.isAcceptableOrUnknown(data['debit_cents']!, _debitCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_debitCentsMeta);
    }
    if (data.containsKey('credit_cents')) {
      context.handle(
        _creditCentsMeta,
        creditCents.isAcceptableOrUnknown(
          data['credit_cents']!,
          _creditCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_creditCentsMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    } else if (isInserting) {
      context.missing(_noteMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      chartOfAccountCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}chart_of_account_code'],
      )!,
      debitCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}debit_cents'],
      )!,
      creditCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}credit_cents'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      )!,
    );
  }

  @override
  $TransactionEntriesTable createAlias(String alias) {
    return $TransactionEntriesTable(attachedDatabase, alias);
  }
}

class TransactionEntry extends DataClass
    implements Insertable<TransactionEntry> {
  final String id;
  final String transactionId;
  final String accountId;
  final String chartOfAccountCode;
  final int debitCents;
  final int creditCents;
  final String note;
  const TransactionEntry({
    required this.id,
    required this.transactionId,
    required this.accountId,
    required this.chartOfAccountCode,
    required this.debitCents,
    required this.creditCents,
    required this.note,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['transaction_id'] = Variable<String>(transactionId);
    map['account_id'] = Variable<String>(accountId);
    map['chart_of_account_code'] = Variable<String>(chartOfAccountCode);
    map['debit_cents'] = Variable<int>(debitCents);
    map['credit_cents'] = Variable<int>(creditCents);
    map['note'] = Variable<String>(note);
    return map;
  }

  TransactionEntriesCompanion toCompanion(bool nullToAbsent) {
    return TransactionEntriesCompanion(
      id: Value(id),
      transactionId: Value(transactionId),
      accountId: Value(accountId),
      chartOfAccountCode: Value(chartOfAccountCode),
      debitCents: Value(debitCents),
      creditCents: Value(creditCents),
      note: Value(note),
    );
  }

  factory TransactionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionEntry(
      id: serializer.fromJson<String>(json['id']),
      transactionId: serializer.fromJson<String>(json['transactionId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      chartOfAccountCode: serializer.fromJson<String>(
        json['chartOfAccountCode'],
      ),
      debitCents: serializer.fromJson<int>(json['debitCents']),
      creditCents: serializer.fromJson<int>(json['creditCents']),
      note: serializer.fromJson<String>(json['note']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'transactionId': serializer.toJson<String>(transactionId),
      'accountId': serializer.toJson<String>(accountId),
      'chartOfAccountCode': serializer.toJson<String>(chartOfAccountCode),
      'debitCents': serializer.toJson<int>(debitCents),
      'creditCents': serializer.toJson<int>(creditCents),
      'note': serializer.toJson<String>(note),
    };
  }

  TransactionEntry copyWith({
    String? id,
    String? transactionId,
    String? accountId,
    String? chartOfAccountCode,
    int? debitCents,
    int? creditCents,
    String? note,
  }) => TransactionEntry(
    id: id ?? this.id,
    transactionId: transactionId ?? this.transactionId,
    accountId: accountId ?? this.accountId,
    chartOfAccountCode: chartOfAccountCode ?? this.chartOfAccountCode,
    debitCents: debitCents ?? this.debitCents,
    creditCents: creditCents ?? this.creditCents,
    note: note ?? this.note,
  );
  TransactionEntry copyWithCompanion(TransactionEntriesCompanion data) {
    return TransactionEntry(
      id: data.id.present ? data.id.value : this.id,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      chartOfAccountCode: data.chartOfAccountCode.present
          ? data.chartOfAccountCode.value
          : this.chartOfAccountCode,
      debitCents: data.debitCents.present
          ? data.debitCents.value
          : this.debitCents,
      creditCents: data.creditCents.present
          ? data.creditCents.value
          : this.creditCents,
      note: data.note.present ? data.note.value : this.note,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionEntry(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('accountId: $accountId, ')
          ..write('chartOfAccountCode: $chartOfAccountCode, ')
          ..write('debitCents: $debitCents, ')
          ..write('creditCents: $creditCents, ')
          ..write('note: $note')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    transactionId,
    accountId,
    chartOfAccountCode,
    debitCents,
    creditCents,
    note,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionEntry &&
          other.id == this.id &&
          other.transactionId == this.transactionId &&
          other.accountId == this.accountId &&
          other.chartOfAccountCode == this.chartOfAccountCode &&
          other.debitCents == this.debitCents &&
          other.creditCents == this.creditCents &&
          other.note == this.note);
}

class TransactionEntriesCompanion extends UpdateCompanion<TransactionEntry> {
  final Value<String> id;
  final Value<String> transactionId;
  final Value<String> accountId;
  final Value<String> chartOfAccountCode;
  final Value<int> debitCents;
  final Value<int> creditCents;
  final Value<String> note;
  final Value<int> rowid;
  const TransactionEntriesCompanion({
    this.id = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.chartOfAccountCode = const Value.absent(),
    this.debitCents = const Value.absent(),
    this.creditCents = const Value.absent(),
    this.note = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionEntriesCompanion.insert({
    required String id,
    required String transactionId,
    required String accountId,
    required String chartOfAccountCode,
    required int debitCents,
    required int creditCents,
    required String note,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       transactionId = Value(transactionId),
       accountId = Value(accountId),
       chartOfAccountCode = Value(chartOfAccountCode),
       debitCents = Value(debitCents),
       creditCents = Value(creditCents),
       note = Value(note);
  static Insertable<TransactionEntry> custom({
    Expression<String>? id,
    Expression<String>? transactionId,
    Expression<String>? accountId,
    Expression<String>? chartOfAccountCode,
    Expression<int>? debitCents,
    Expression<int>? creditCents,
    Expression<String>? note,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (transactionId != null) 'transaction_id': transactionId,
      if (accountId != null) 'account_id': accountId,
      if (chartOfAccountCode != null)
        'chart_of_account_code': chartOfAccountCode,
      if (debitCents != null) 'debit_cents': debitCents,
      if (creditCents != null) 'credit_cents': creditCents,
      if (note != null) 'note': note,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? transactionId,
    Value<String>? accountId,
    Value<String>? chartOfAccountCode,
    Value<int>? debitCents,
    Value<int>? creditCents,
    Value<String>? note,
    Value<int>? rowid,
  }) {
    return TransactionEntriesCompanion(
      id: id ?? this.id,
      transactionId: transactionId ?? this.transactionId,
      accountId: accountId ?? this.accountId,
      chartOfAccountCode: chartOfAccountCode ?? this.chartOfAccountCode,
      debitCents: debitCents ?? this.debitCents,
      creditCents: creditCents ?? this.creditCents,
      note: note ?? this.note,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (chartOfAccountCode.present) {
      map['chart_of_account_code'] = Variable<String>(chartOfAccountCode.value);
    }
    if (debitCents.present) {
      map['debit_cents'] = Variable<int>(debitCents.value);
    }
    if (creditCents.present) {
      map['credit_cents'] = Variable<int>(creditCents.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionEntriesCompanion(')
          ..write('id: $id, ')
          ..write('transactionId: $transactionId, ')
          ..write('accountId: $accountId, ')
          ..write('chartOfAccountCode: $chartOfAccountCode, ')
          ..write('debitCents: $debitCents, ')
          ..write('creditCents: $creditCents, ')
          ..write('note: $note, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtsTable extends Debts with TableInfo<$DebtsTable, Debt> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _counterpartyMeta = const VerificationMeta(
    'counterparty',
  );
  @override
  late final GeneratedColumn<String> counterparty = GeneratedColumn<String>(
    'counterparty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _interestRateMeta = const VerificationMeta(
    'interestRate',
  );
  @override
  late final GeneratedColumn<double> interestRate = GeneratedColumn<double>(
    'interest_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amortizationMethodMeta =
      const VerificationMeta('amortizationMethod');
  @override
  late final GeneratedColumn<int> amortizationMethod = GeneratedColumn<int>(
    'amortization_method',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPrincipalCentsMeta =
      const VerificationMeta('totalPrincipalCents');
  @override
  late final GeneratedColumn<int> totalPrincipalCents = GeneratedColumn<int>(
    'total_principal_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _debtTypeMeta = const VerificationMeta(
    'debtType',
  );
  @override
  late final GeneratedColumn<int> debtType = GeneratedColumn<int>(
    'debt_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subtypeMeta = const VerificationMeta(
    'subtype',
  );
  @override
  late final GeneratedColumn<String> subtype = GeneratedColumn<String>(
    'subtype',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contactMeta = const VerificationMeta(
    'contact',
  );
  @override
  late final GeneratedColumn<String> contact = GeneratedColumn<String>(
    'contact',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contractRefMeta = const VerificationMeta(
    'contractRef',
  );
  @override
  late final GeneratedColumn<String> contractRef = GeneratedColumn<String>(
    'contract_ref',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _collectionAccountIdMeta =
      const VerificationMeta('collectionAccountId');
  @override
  late final GeneratedColumn<String> collectionAccountId =
      GeneratedColumn<String>(
        'collection_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    counterparty,
    interestRate,
    amortizationMethod,
    startDate,
    dueDate,
    totalPrincipalCents,
    debtType,
    subtype,
    contact,
    contractRef,
    collectionAccountId,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debts';
  @override
  VerificationContext validateIntegrity(
    Insertable<Debt> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('counterparty')) {
      context.handle(
        _counterpartyMeta,
        counterparty.isAcceptableOrUnknown(
          data['counterparty']!,
          _counterpartyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_counterpartyMeta);
    }
    if (data.containsKey('interest_rate')) {
      context.handle(
        _interestRateMeta,
        interestRate.isAcceptableOrUnknown(
          data['interest_rate']!,
          _interestRateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_interestRateMeta);
    }
    if (data.containsKey('amortization_method')) {
      context.handle(
        _amortizationMethodMeta,
        amortizationMethod.isAcceptableOrUnknown(
          data['amortization_method']!,
          _amortizationMethodMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amortizationMethodMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('total_principal_cents')) {
      context.handle(
        _totalPrincipalCentsMeta,
        totalPrincipalCents.isAcceptableOrUnknown(
          data['total_principal_cents']!,
          _totalPrincipalCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPrincipalCentsMeta);
    }
    if (data.containsKey('debt_type')) {
      context.handle(
        _debtTypeMeta,
        debtType.isAcceptableOrUnknown(data['debt_type']!, _debtTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_debtTypeMeta);
    }
    if (data.containsKey('subtype')) {
      context.handle(
        _subtypeMeta,
        subtype.isAcceptableOrUnknown(data['subtype']!, _subtypeMeta),
      );
    } else if (isInserting) {
      context.missing(_subtypeMeta);
    }
    if (data.containsKey('contact')) {
      context.handle(
        _contactMeta,
        contact.isAcceptableOrUnknown(data['contact']!, _contactMeta),
      );
    } else if (isInserting) {
      context.missing(_contactMeta);
    }
    if (data.containsKey('contract_ref')) {
      context.handle(
        _contractRefMeta,
        contractRef.isAcceptableOrUnknown(
          data['contract_ref']!,
          _contractRefMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contractRefMeta);
    }
    if (data.containsKey('collection_account_id')) {
      context.handle(
        _collectionAccountIdMeta,
        collectionAccountId.isAcceptableOrUnknown(
          data['collection_account_id']!,
          _collectionAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Debt map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Debt(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      counterparty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}counterparty'],
      )!,
      interestRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}interest_rate'],
      )!,
      amortizationMethod: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amortization_method'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      )!,
      totalPrincipalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_principal_cents'],
      )!,
      debtType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}debt_type'],
      )!,
      subtype: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subtype'],
      )!,
      contact: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contact'],
      )!,
      contractRef: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}contract_ref'],
      )!,
      collectionAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}collection_account_id'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DebtsTable createAlias(String alias) {
    return $DebtsTable(attachedDatabase, alias);
  }
}

class Debt extends DataClass implements Insertable<Debt> {
  final String id;
  final String accountId;
  final String counterparty;
  final double interestRate;
  final int amortizationMethod;
  final DateTime startDate;
  final DateTime dueDate;
  final int totalPrincipalCents;
  final int debtType;
  final String subtype;
  final String contact;
  final String contractRef;
  final String? collectionAccountId;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Debt({
    required this.id,
    required this.accountId,
    required this.counterparty,
    required this.interestRate,
    required this.amortizationMethod,
    required this.startDate,
    required this.dueDate,
    required this.totalPrincipalCents,
    required this.debtType,
    required this.subtype,
    required this.contact,
    required this.contractRef,
    this.collectionAccountId,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['counterparty'] = Variable<String>(counterparty);
    map['interest_rate'] = Variable<double>(interestRate);
    map['amortization_method'] = Variable<int>(amortizationMethod);
    map['start_date'] = Variable<DateTime>(startDate);
    map['due_date'] = Variable<DateTime>(dueDate);
    map['total_principal_cents'] = Variable<int>(totalPrincipalCents);
    map['debt_type'] = Variable<int>(debtType);
    map['subtype'] = Variable<String>(subtype);
    map['contact'] = Variable<String>(contact);
    map['contract_ref'] = Variable<String>(contractRef);
    if (!nullToAbsent || collectionAccountId != null) {
      map['collection_account_id'] = Variable<String>(collectionAccountId);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DebtsCompanion toCompanion(bool nullToAbsent) {
    return DebtsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      counterparty: Value(counterparty),
      interestRate: Value(interestRate),
      amortizationMethod: Value(amortizationMethod),
      startDate: Value(startDate),
      dueDate: Value(dueDate),
      totalPrincipalCents: Value(totalPrincipalCents),
      debtType: Value(debtType),
      subtype: Value(subtype),
      contact: Value(contact),
      contractRef: Value(contractRef),
      collectionAccountId: collectionAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(collectionAccountId),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Debt.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Debt(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      counterparty: serializer.fromJson<String>(json['counterparty']),
      interestRate: serializer.fromJson<double>(json['interestRate']),
      amortizationMethod: serializer.fromJson<int>(json['amortizationMethod']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      dueDate: serializer.fromJson<DateTime>(json['dueDate']),
      totalPrincipalCents: serializer.fromJson<int>(
        json['totalPrincipalCents'],
      ),
      debtType: serializer.fromJson<int>(json['debtType']),
      subtype: serializer.fromJson<String>(json['subtype']),
      contact: serializer.fromJson<String>(json['contact']),
      contractRef: serializer.fromJson<String>(json['contractRef']),
      collectionAccountId: serializer.fromJson<String?>(
        json['collectionAccountId'],
      ),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'counterparty': serializer.toJson<String>(counterparty),
      'interestRate': serializer.toJson<double>(interestRate),
      'amortizationMethod': serializer.toJson<int>(amortizationMethod),
      'startDate': serializer.toJson<DateTime>(startDate),
      'dueDate': serializer.toJson<DateTime>(dueDate),
      'totalPrincipalCents': serializer.toJson<int>(totalPrincipalCents),
      'debtType': serializer.toJson<int>(debtType),
      'subtype': serializer.toJson<String>(subtype),
      'contact': serializer.toJson<String>(contact),
      'contractRef': serializer.toJson<String>(contractRef),
      'collectionAccountId': serializer.toJson<String?>(collectionAccountId),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Debt copyWith({
    String? id,
    String? accountId,
    String? counterparty,
    double? interestRate,
    int? amortizationMethod,
    DateTime? startDate,
    DateTime? dueDate,
    int? totalPrincipalCents,
    int? debtType,
    String? subtype,
    String? contact,
    String? contractRef,
    Value<String?> collectionAccountId = const Value.absent(),
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Debt(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    counterparty: counterparty ?? this.counterparty,
    interestRate: interestRate ?? this.interestRate,
    amortizationMethod: amortizationMethod ?? this.amortizationMethod,
    startDate: startDate ?? this.startDate,
    dueDate: dueDate ?? this.dueDate,
    totalPrincipalCents: totalPrincipalCents ?? this.totalPrincipalCents,
    debtType: debtType ?? this.debtType,
    subtype: subtype ?? this.subtype,
    contact: contact ?? this.contact,
    contractRef: contractRef ?? this.contractRef,
    collectionAccountId: collectionAccountId.present
        ? collectionAccountId.value
        : this.collectionAccountId,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Debt copyWithCompanion(DebtsCompanion data) {
    return Debt(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      counterparty: data.counterparty.present
          ? data.counterparty.value
          : this.counterparty,
      interestRate: data.interestRate.present
          ? data.interestRate.value
          : this.interestRate,
      amortizationMethod: data.amortizationMethod.present
          ? data.amortizationMethod.value
          : this.amortizationMethod,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      totalPrincipalCents: data.totalPrincipalCents.present
          ? data.totalPrincipalCents.value
          : this.totalPrincipalCents,
      debtType: data.debtType.present ? data.debtType.value : this.debtType,
      subtype: data.subtype.present ? data.subtype.value : this.subtype,
      contact: data.contact.present ? data.contact.value : this.contact,
      contractRef: data.contractRef.present
          ? data.contractRef.value
          : this.contractRef,
      collectionAccountId: data.collectionAccountId.present
          ? data.collectionAccountId.value
          : this.collectionAccountId,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Debt(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('counterparty: $counterparty, ')
          ..write('interestRate: $interestRate, ')
          ..write('amortizationMethod: $amortizationMethod, ')
          ..write('startDate: $startDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('totalPrincipalCents: $totalPrincipalCents, ')
          ..write('debtType: $debtType, ')
          ..write('subtype: $subtype, ')
          ..write('contact: $contact, ')
          ..write('contractRef: $contractRef, ')
          ..write('collectionAccountId: $collectionAccountId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    counterparty,
    interestRate,
    amortizationMethod,
    startDate,
    dueDate,
    totalPrincipalCents,
    debtType,
    subtype,
    contact,
    contractRef,
    collectionAccountId,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Debt &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.counterparty == this.counterparty &&
          other.interestRate == this.interestRate &&
          other.amortizationMethod == this.amortizationMethod &&
          other.startDate == this.startDate &&
          other.dueDate == this.dueDate &&
          other.totalPrincipalCents == this.totalPrincipalCents &&
          other.debtType == this.debtType &&
          other.subtype == this.subtype &&
          other.contact == this.contact &&
          other.contractRef == this.contractRef &&
          other.collectionAccountId == this.collectionAccountId &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DebtsCompanion extends UpdateCompanion<Debt> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> counterparty;
  final Value<double> interestRate;
  final Value<int> amortizationMethod;
  final Value<DateTime> startDate;
  final Value<DateTime> dueDate;
  final Value<int> totalPrincipalCents;
  final Value<int> debtType;
  final Value<String> subtype;
  final Value<String> contact;
  final Value<String> contractRef;
  final Value<String?> collectionAccountId;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DebtsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.counterparty = const Value.absent(),
    this.interestRate = const Value.absent(),
    this.amortizationMethod = const Value.absent(),
    this.startDate = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.totalPrincipalCents = const Value.absent(),
    this.debtType = const Value.absent(),
    this.subtype = const Value.absent(),
    this.contact = const Value.absent(),
    this.contractRef = const Value.absent(),
    this.collectionAccountId = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtsCompanion.insert({
    required String id,
    required String accountId,
    required String counterparty,
    required double interestRate,
    required int amortizationMethod,
    required DateTime startDate,
    required DateTime dueDate,
    required int totalPrincipalCents,
    required int debtType,
    required String subtype,
    required String contact,
    required String contractRef,
    this.collectionAccountId = const Value.absent(),
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       counterparty = Value(counterparty),
       interestRate = Value(interestRate),
       amortizationMethod = Value(amortizationMethod),
       startDate = Value(startDate),
       dueDate = Value(dueDate),
       totalPrincipalCents = Value(totalPrincipalCents),
       debtType = Value(debtType),
       subtype = Value(subtype),
       contact = Value(contact),
       contractRef = Value(contractRef),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Debt> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? counterparty,
    Expression<double>? interestRate,
    Expression<int>? amortizationMethod,
    Expression<DateTime>? startDate,
    Expression<DateTime>? dueDate,
    Expression<int>? totalPrincipalCents,
    Expression<int>? debtType,
    Expression<String>? subtype,
    Expression<String>? contact,
    Expression<String>? contractRef,
    Expression<String>? collectionAccountId,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (counterparty != null) 'counterparty': counterparty,
      if (interestRate != null) 'interest_rate': interestRate,
      if (amortizationMethod != null) 'amortization_method': amortizationMethod,
      if (startDate != null) 'start_date': startDate,
      if (dueDate != null) 'due_date': dueDate,
      if (totalPrincipalCents != null)
        'total_principal_cents': totalPrincipalCents,
      if (debtType != null) 'debt_type': debtType,
      if (subtype != null) 'subtype': subtype,
      if (contact != null) 'contact': contact,
      if (contractRef != null) 'contract_ref': contractRef,
      if (collectionAccountId != null)
        'collection_account_id': collectionAccountId,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? counterparty,
    Value<double>? interestRate,
    Value<int>? amortizationMethod,
    Value<DateTime>? startDate,
    Value<DateTime>? dueDate,
    Value<int>? totalPrincipalCents,
    Value<int>? debtType,
    Value<String>? subtype,
    Value<String>? contact,
    Value<String>? contractRef,
    Value<String?>? collectionAccountId,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DebtsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      counterparty: counterparty ?? this.counterparty,
      interestRate: interestRate ?? this.interestRate,
      amortizationMethod: amortizationMethod ?? this.amortizationMethod,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      totalPrincipalCents: totalPrincipalCents ?? this.totalPrincipalCents,
      debtType: debtType ?? this.debtType,
      subtype: subtype ?? this.subtype,
      contact: contact ?? this.contact,
      contractRef: contractRef ?? this.contractRef,
      collectionAccountId: collectionAccountId ?? this.collectionAccountId,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (counterparty.present) {
      map['counterparty'] = Variable<String>(counterparty.value);
    }
    if (interestRate.present) {
      map['interest_rate'] = Variable<double>(interestRate.value);
    }
    if (amortizationMethod.present) {
      map['amortization_method'] = Variable<int>(amortizationMethod.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (totalPrincipalCents.present) {
      map['total_principal_cents'] = Variable<int>(totalPrincipalCents.value);
    }
    if (debtType.present) {
      map['debt_type'] = Variable<int>(debtType.value);
    }
    if (subtype.present) {
      map['subtype'] = Variable<String>(subtype.value);
    }
    if (contact.present) {
      map['contact'] = Variable<String>(contact.value);
    }
    if (contractRef.present) {
      map['contract_ref'] = Variable<String>(contractRef.value);
    }
    if (collectionAccountId.present) {
      map['collection_account_id'] = Variable<String>(
        collectionAccountId.value,
      );
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebtsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('counterparty: $counterparty, ')
          ..write('interestRate: $interestRate, ')
          ..write('amortizationMethod: $amortizationMethod, ')
          ..write('startDate: $startDate, ')
          ..write('dueDate: $dueDate, ')
          ..write('totalPrincipalCents: $totalPrincipalCents, ')
          ..write('debtType: $debtType, ')
          ..write('subtype: $subtype, ')
          ..write('contact: $contact, ')
          ..write('contractRef: $contractRef, ')
          ..write('collectionAccountId: $collectionAccountId, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PaymentScheduleEntriesTable extends PaymentScheduleEntries
    with TableInfo<$PaymentScheduleEntriesTable, PaymentScheduleEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PaymentScheduleEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _debtIdMeta = const VerificationMeta('debtId');
  @override
  late final GeneratedColumn<String> debtId = GeneratedColumn<String>(
    'debt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES debts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _paymentDateMeta = const VerificationMeta(
    'paymentDate',
  );
  @override
  late final GeneratedColumn<DateTime> paymentDate = GeneratedColumn<DateTime>(
    'payment_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _principalCentsMeta = const VerificationMeta(
    'principalCents',
  );
  @override
  late final GeneratedColumn<int> principalCents = GeneratedColumn<int>(
    'principal_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _interestCentsMeta = const VerificationMeta(
    'interestCents',
  );
  @override
  late final GeneratedColumn<int> interestCents = GeneratedColumn<int>(
    'interest_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalCentsMeta = const VerificationMeta(
    'totalCents',
  );
  @override
  late final GeneratedColumn<int> totalCents = GeneratedColumn<int>(
    'total_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidCentsMeta = const VerificationMeta(
    'paidCents',
  );
  @override
  late final GeneratedColumn<int> paidCents = GeneratedColumn<int>(
    'paid_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _paidMeta = const VerificationMeta('paid');
  @override
  late final GeneratedColumn<bool> paid = GeneratedColumn<bool>(
    'paid',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("paid" IN (0, 1))',
    ),
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    debtId,
    paymentDate,
    principalCents,
    interestCents,
    totalCents,
    paidCents,
    paid,
    transactionId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'payment_schedule_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PaymentScheduleEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('debt_id')) {
      context.handle(
        _debtIdMeta,
        debtId.isAcceptableOrUnknown(data['debt_id']!, _debtIdMeta),
      );
    } else if (isInserting) {
      context.missing(_debtIdMeta);
    }
    if (data.containsKey('payment_date')) {
      context.handle(
        _paymentDateMeta,
        paymentDate.isAcceptableOrUnknown(
          data['payment_date']!,
          _paymentDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paymentDateMeta);
    }
    if (data.containsKey('principal_cents')) {
      context.handle(
        _principalCentsMeta,
        principalCents.isAcceptableOrUnknown(
          data['principal_cents']!,
          _principalCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_principalCentsMeta);
    }
    if (data.containsKey('interest_cents')) {
      context.handle(
        _interestCentsMeta,
        interestCents.isAcceptableOrUnknown(
          data['interest_cents']!,
          _interestCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_interestCentsMeta);
    }
    if (data.containsKey('total_cents')) {
      context.handle(
        _totalCentsMeta,
        totalCents.isAcceptableOrUnknown(data['total_cents']!, _totalCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_totalCentsMeta);
    }
    if (data.containsKey('paid_cents')) {
      context.handle(
        _paidCentsMeta,
        paidCents.isAcceptableOrUnknown(data['paid_cents']!, _paidCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_paidCentsMeta);
    }
    if (data.containsKey('paid')) {
      context.handle(
        _paidMeta,
        paid.isAcceptableOrUnknown(data['paid']!, _paidMeta),
      );
    } else if (isInserting) {
      context.missing(_paidMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PaymentScheduleEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PaymentScheduleEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      debtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}debt_id'],
      )!,
      paymentDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}payment_date'],
      )!,
      principalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}principal_cents'],
      )!,
      interestCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}interest_cents'],
      )!,
      totalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_cents'],
      )!,
      paidCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_cents'],
      )!,
      paid: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}paid'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      ),
    );
  }

  @override
  $PaymentScheduleEntriesTable createAlias(String alias) {
    return $PaymentScheduleEntriesTable(attachedDatabase, alias);
  }
}

class PaymentScheduleEntry extends DataClass
    implements Insertable<PaymentScheduleEntry> {
  final String id;
  final String debtId;
  final DateTime paymentDate;
  final int principalCents;
  final int interestCents;
  final int totalCents;
  final int paidCents;
  final bool paid;
  final String? transactionId;
  const PaymentScheduleEntry({
    required this.id,
    required this.debtId,
    required this.paymentDate,
    required this.principalCents,
    required this.interestCents,
    required this.totalCents,
    required this.paidCents,
    required this.paid,
    this.transactionId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['debt_id'] = Variable<String>(debtId);
    map['payment_date'] = Variable<DateTime>(paymentDate);
    map['principal_cents'] = Variable<int>(principalCents);
    map['interest_cents'] = Variable<int>(interestCents);
    map['total_cents'] = Variable<int>(totalCents);
    map['paid_cents'] = Variable<int>(paidCents);
    map['paid'] = Variable<bool>(paid);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    return map;
  }

  PaymentScheduleEntriesCompanion toCompanion(bool nullToAbsent) {
    return PaymentScheduleEntriesCompanion(
      id: Value(id),
      debtId: Value(debtId),
      paymentDate: Value(paymentDate),
      principalCents: Value(principalCents),
      interestCents: Value(interestCents),
      totalCents: Value(totalCents),
      paidCents: Value(paidCents),
      paid: Value(paid),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
    );
  }

  factory PaymentScheduleEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PaymentScheduleEntry(
      id: serializer.fromJson<String>(json['id']),
      debtId: serializer.fromJson<String>(json['debtId']),
      paymentDate: serializer.fromJson<DateTime>(json['paymentDate']),
      principalCents: serializer.fromJson<int>(json['principalCents']),
      interestCents: serializer.fromJson<int>(json['interestCents']),
      totalCents: serializer.fromJson<int>(json['totalCents']),
      paidCents: serializer.fromJson<int>(json['paidCents']),
      paid: serializer.fromJson<bool>(json['paid']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'debtId': serializer.toJson<String>(debtId),
      'paymentDate': serializer.toJson<DateTime>(paymentDate),
      'principalCents': serializer.toJson<int>(principalCents),
      'interestCents': serializer.toJson<int>(interestCents),
      'totalCents': serializer.toJson<int>(totalCents),
      'paidCents': serializer.toJson<int>(paidCents),
      'paid': serializer.toJson<bool>(paid),
      'transactionId': serializer.toJson<String?>(transactionId),
    };
  }

  PaymentScheduleEntry copyWith({
    String? id,
    String? debtId,
    DateTime? paymentDate,
    int? principalCents,
    int? interestCents,
    int? totalCents,
    int? paidCents,
    bool? paid,
    Value<String?> transactionId = const Value.absent(),
  }) => PaymentScheduleEntry(
    id: id ?? this.id,
    debtId: debtId ?? this.debtId,
    paymentDate: paymentDate ?? this.paymentDate,
    principalCents: principalCents ?? this.principalCents,
    interestCents: interestCents ?? this.interestCents,
    totalCents: totalCents ?? this.totalCents,
    paidCents: paidCents ?? this.paidCents,
    paid: paid ?? this.paid,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
  );
  PaymentScheduleEntry copyWithCompanion(PaymentScheduleEntriesCompanion data) {
    return PaymentScheduleEntry(
      id: data.id.present ? data.id.value : this.id,
      debtId: data.debtId.present ? data.debtId.value : this.debtId,
      paymentDate: data.paymentDate.present
          ? data.paymentDate.value
          : this.paymentDate,
      principalCents: data.principalCents.present
          ? data.principalCents.value
          : this.principalCents,
      interestCents: data.interestCents.present
          ? data.interestCents.value
          : this.interestCents,
      totalCents: data.totalCents.present
          ? data.totalCents.value
          : this.totalCents,
      paidCents: data.paidCents.present ? data.paidCents.value : this.paidCents,
      paid: data.paid.present ? data.paid.value : this.paid,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PaymentScheduleEntry(')
          ..write('id: $id, ')
          ..write('debtId: $debtId, ')
          ..write('paymentDate: $paymentDate, ')
          ..write('principalCents: $principalCents, ')
          ..write('interestCents: $interestCents, ')
          ..write('totalCents: $totalCents, ')
          ..write('paidCents: $paidCents, ')
          ..write('paid: $paid, ')
          ..write('transactionId: $transactionId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    debtId,
    paymentDate,
    principalCents,
    interestCents,
    totalCents,
    paidCents,
    paid,
    transactionId,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PaymentScheduleEntry &&
          other.id == this.id &&
          other.debtId == this.debtId &&
          other.paymentDate == this.paymentDate &&
          other.principalCents == this.principalCents &&
          other.interestCents == this.interestCents &&
          other.totalCents == this.totalCents &&
          other.paidCents == this.paidCents &&
          other.paid == this.paid &&
          other.transactionId == this.transactionId);
}

class PaymentScheduleEntriesCompanion
    extends UpdateCompanion<PaymentScheduleEntry> {
  final Value<String> id;
  final Value<String> debtId;
  final Value<DateTime> paymentDate;
  final Value<int> principalCents;
  final Value<int> interestCents;
  final Value<int> totalCents;
  final Value<int> paidCents;
  final Value<bool> paid;
  final Value<String?> transactionId;
  final Value<int> rowid;
  const PaymentScheduleEntriesCompanion({
    this.id = const Value.absent(),
    this.debtId = const Value.absent(),
    this.paymentDate = const Value.absent(),
    this.principalCents = const Value.absent(),
    this.interestCents = const Value.absent(),
    this.totalCents = const Value.absent(),
    this.paidCents = const Value.absent(),
    this.paid = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PaymentScheduleEntriesCompanion.insert({
    required String id,
    required String debtId,
    required DateTime paymentDate,
    required int principalCents,
    required int interestCents,
    required int totalCents,
    required int paidCents,
    required bool paid,
    this.transactionId = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       debtId = Value(debtId),
       paymentDate = Value(paymentDate),
       principalCents = Value(principalCents),
       interestCents = Value(interestCents),
       totalCents = Value(totalCents),
       paidCents = Value(paidCents),
       paid = Value(paid);
  static Insertable<PaymentScheduleEntry> custom({
    Expression<String>? id,
    Expression<String>? debtId,
    Expression<DateTime>? paymentDate,
    Expression<int>? principalCents,
    Expression<int>? interestCents,
    Expression<int>? totalCents,
    Expression<int>? paidCents,
    Expression<bool>? paid,
    Expression<String>? transactionId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (debtId != null) 'debt_id': debtId,
      if (paymentDate != null) 'payment_date': paymentDate,
      if (principalCents != null) 'principal_cents': principalCents,
      if (interestCents != null) 'interest_cents': interestCents,
      if (totalCents != null) 'total_cents': totalCents,
      if (paidCents != null) 'paid_cents': paidCents,
      if (paid != null) 'paid': paid,
      if (transactionId != null) 'transaction_id': transactionId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PaymentScheduleEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? debtId,
    Value<DateTime>? paymentDate,
    Value<int>? principalCents,
    Value<int>? interestCents,
    Value<int>? totalCents,
    Value<int>? paidCents,
    Value<bool>? paid,
    Value<String?>? transactionId,
    Value<int>? rowid,
  }) {
    return PaymentScheduleEntriesCompanion(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      paymentDate: paymentDate ?? this.paymentDate,
      principalCents: principalCents ?? this.principalCents,
      interestCents: interestCents ?? this.interestCents,
      totalCents: totalCents ?? this.totalCents,
      paidCents: paidCents ?? this.paidCents,
      paid: paid ?? this.paid,
      transactionId: transactionId ?? this.transactionId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (debtId.present) {
      map['debt_id'] = Variable<String>(debtId.value);
    }
    if (paymentDate.present) {
      map['payment_date'] = Variable<DateTime>(paymentDate.value);
    }
    if (principalCents.present) {
      map['principal_cents'] = Variable<int>(principalCents.value);
    }
    if (interestCents.present) {
      map['interest_cents'] = Variable<int>(interestCents.value);
    }
    if (totalCents.present) {
      map['total_cents'] = Variable<int>(totalCents.value);
    }
    if (paidCents.present) {
      map['paid_cents'] = Variable<int>(paidCents.value);
    }
    if (paid.present) {
      map['paid'] = Variable<bool>(paid.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PaymentScheduleEntriesCompanion(')
          ..write('id: $id, ')
          ..write('debtId: $debtId, ')
          ..write('paymentDate: $paymentDate, ')
          ..write('principalCents: $principalCents, ')
          ..write('interestCents: $interestCents, ')
          ..write('totalCents: $totalCents, ')
          ..write('paidCents: $paidCents, ')
          ..write('paid: $paid, ')
          ..write('transactionId: $transactionId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReminderLogsTable extends ReminderLogs
    with TableInfo<$ReminderLogsTable, ReminderLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _entryIdMeta = const VerificationMeta(
    'entryId',
  );
  @override
  late final GeneratedColumn<String> entryId = GeneratedColumn<String>(
    'entry_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<int> tier = GeneratedColumn<int>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sentDateMeta = const VerificationMeta(
    'sentDate',
  );
  @override
  late final GeneratedColumn<String> sentDate = GeneratedColumn<String>(
    'sent_date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, entryId, tier, sentDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entry_id')) {
      context.handle(
        _entryIdMeta,
        entryId.isAcceptableOrUnknown(data['entry_id']!, _entryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entryIdMeta);
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('sent_date')) {
      context.handle(
        _sentDateMeta,
        sentDate.isAcceptableOrUnknown(data['sent_date']!, _sentDateMeta),
      );
    } else if (isInserting) {
      context.missing(_sentDateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {entryId, tier, sentDate},
  ];
  @override
  ReminderLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      entryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entry_id'],
      )!,
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tier'],
      )!,
      sentDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sent_date'],
      )!,
    );
  }

  @override
  $ReminderLogsTable createAlias(String alias) {
    return $ReminderLogsTable(attachedDatabase, alias);
  }
}

class ReminderLog extends DataClass implements Insertable<ReminderLog> {
  final int id;
  final String entryId;
  final int tier;
  final String sentDate;
  const ReminderLog({
    required this.id,
    required this.entryId,
    required this.tier,
    required this.sentDate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entry_id'] = Variable<String>(entryId);
    map['tier'] = Variable<int>(tier);
    map['sent_date'] = Variable<String>(sentDate);
    return map;
  }

  ReminderLogsCompanion toCompanion(bool nullToAbsent) {
    return ReminderLogsCompanion(
      id: Value(id),
      entryId: Value(entryId),
      tier: Value(tier),
      sentDate: Value(sentDate),
    );
  }

  factory ReminderLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderLog(
      id: serializer.fromJson<int>(json['id']),
      entryId: serializer.fromJson<String>(json['entryId']),
      tier: serializer.fromJson<int>(json['tier']),
      sentDate: serializer.fromJson<String>(json['sentDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entryId': serializer.toJson<String>(entryId),
      'tier': serializer.toJson<int>(tier),
      'sentDate': serializer.toJson<String>(sentDate),
    };
  }

  ReminderLog copyWith({
    int? id,
    String? entryId,
    int? tier,
    String? sentDate,
  }) => ReminderLog(
    id: id ?? this.id,
    entryId: entryId ?? this.entryId,
    tier: tier ?? this.tier,
    sentDate: sentDate ?? this.sentDate,
  );
  ReminderLog copyWithCompanion(ReminderLogsCompanion data) {
    return ReminderLog(
      id: data.id.present ? data.id.value : this.id,
      entryId: data.entryId.present ? data.entryId.value : this.entryId,
      tier: data.tier.present ? data.tier.value : this.tier,
      sentDate: data.sentDate.present ? data.sentDate.value : this.sentDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderLog(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('tier: $tier, ')
          ..write('sentDate: $sentDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entryId, tier, sentDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderLog &&
          other.id == this.id &&
          other.entryId == this.entryId &&
          other.tier == this.tier &&
          other.sentDate == this.sentDate);
}

class ReminderLogsCompanion extends UpdateCompanion<ReminderLog> {
  final Value<int> id;
  final Value<String> entryId;
  final Value<int> tier;
  final Value<String> sentDate;
  const ReminderLogsCompanion({
    this.id = const Value.absent(),
    this.entryId = const Value.absent(),
    this.tier = const Value.absent(),
    this.sentDate = const Value.absent(),
  });
  ReminderLogsCompanion.insert({
    this.id = const Value.absent(),
    required String entryId,
    required int tier,
    required String sentDate,
  }) : entryId = Value(entryId),
       tier = Value(tier),
       sentDate = Value(sentDate);
  static Insertable<ReminderLog> custom({
    Expression<int>? id,
    Expression<String>? entryId,
    Expression<int>? tier,
    Expression<String>? sentDate,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entryId != null) 'entry_id': entryId,
      if (tier != null) 'tier': tier,
      if (sentDate != null) 'sent_date': sentDate,
    });
  }

  ReminderLogsCompanion copyWith({
    Value<int>? id,
    Value<String>? entryId,
    Value<int>? tier,
    Value<String>? sentDate,
  }) {
    return ReminderLogsCompanion(
      id: id ?? this.id,
      entryId: entryId ?? this.entryId,
      tier: tier ?? this.tier,
      sentDate: sentDate ?? this.sentDate,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entryId.present) {
      map['entry_id'] = Variable<String>(entryId.value);
    }
    if (tier.present) {
      map['tier'] = Variable<int>(tier.value);
    }
    if (sentDate.present) {
      map['sent_date'] = Variable<String>(sentDate.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderLogsCompanion(')
          ..write('id: $id, ')
          ..write('entryId: $entryId, ')
          ..write('tier: $tier, ')
          ..write('sentDate: $sentDate')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalAmountCentsMeta = const VerificationMeta(
    'totalAmountCents',
  );
  @override
  late final GeneratedColumn<int> totalAmountCents = GeneratedColumn<int>(
    'total_amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    month,
    totalAmountCents,
    currencyCode,
    isActive,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<Budget> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('total_amount_cents')) {
      context.handle(
        _totalAmountCentsMeta,
        totalAmountCents.isAcceptableOrUnknown(
          data['total_amount_cents']!,
          _totalAmountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalAmountCentsMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      totalAmountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_amount_cents'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final String id;
  final String name;
  final String month;
  final int totalAmountCents;
  final String currencyCode;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Budget({
    required this.id,
    required this.name,
    required this.month,
    required this.totalAmountCents,
    required this.currencyCode,
    required this.isActive,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['month'] = Variable<String>(month);
    map['total_amount_cents'] = Variable<int>(totalAmountCents);
    map['currency_code'] = Variable<String>(currencyCode);
    map['is_active'] = Variable<bool>(isActive);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      name: Value(name),
      month: Value(month),
      totalAmountCents: Value(totalAmountCents),
      currencyCode: Value(currencyCode),
      isActive: Value(isActive),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Budget.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      month: serializer.fromJson<String>(json['month']),
      totalAmountCents: serializer.fromJson<int>(json['totalAmountCents']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'month': serializer.toJson<String>(month),
      'totalAmountCents': serializer.toJson<int>(totalAmountCents),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'isActive': serializer.toJson<bool>(isActive),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Budget copyWith({
    String? id,
    String? name,
    String? month,
    int? totalAmountCents,
    String? currencyCode,
    bool? isActive,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Budget(
    id: id ?? this.id,
    name: name ?? this.name,
    month: month ?? this.month,
    totalAmountCents: totalAmountCents ?? this.totalAmountCents,
    currencyCode: currencyCode ?? this.currencyCode,
    isActive: isActive ?? this.isActive,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      month: data.month.present ? data.month.value : this.month,
      totalAmountCents: data.totalAmountCents.present
          ? data.totalAmountCents.value
          : this.totalAmountCents,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('month: $month, ')
          ..write('totalAmountCents: $totalAmountCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('isActive: $isActive, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    month,
    totalAmountCents,
    currencyCode,
    isActive,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.name == this.name &&
          other.month == this.month &&
          other.totalAmountCents == this.totalAmountCents &&
          other.currencyCode == this.currencyCode &&
          other.isActive == this.isActive &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> month;
  final Value<int> totalAmountCents;
  final Value<String> currencyCode;
  final Value<bool> isActive;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.month = const Value.absent(),
    this.totalAmountCents = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.isActive = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    required String id,
    required String name,
    required String month,
    required int totalAmountCents,
    required String currencyCode,
    required bool isActive,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       month = Value(month),
       totalAmountCents = Value(totalAmountCents),
       currencyCode = Value(currencyCode),
       isActive = Value(isActive),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Budget> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? month,
    Expression<int>? totalAmountCents,
    Expression<String>? currencyCode,
    Expression<bool>? isActive,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (month != null) 'month': month,
      if (totalAmountCents != null) 'total_amount_cents': totalAmountCents,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (isActive != null) 'is_active': isActive,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? month,
    Value<int>? totalAmountCents,
    Value<String>? currencyCode,
    Value<bool>? isActive,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      month: month ?? this.month,
      totalAmountCents: totalAmountCents ?? this.totalAmountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      isActive: isActive ?? this.isActive,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (totalAmountCents.present) {
      map['total_amount_cents'] = Variable<int>(totalAmountCents.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('month: $month, ')
          ..write('totalAmountCents: $totalAmountCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('isActive: $isActive, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetItemsTable extends BudgetItems
    with TableInfo<$BudgetItemsTable, BudgetItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _budgetIdMeta = const VerificationMeta(
    'budgetId',
  );
  @override
  late final GeneratedColumn<String> budgetId = GeneratedColumn<String>(
    'budget_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES budgets (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _plannedAmountCentsMeta =
      const VerificationMeta('plannedAmountCents');
  @override
  late final GeneratedColumn<int> plannedAmountCents = GeneratedColumn<int>(
    'planned_amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actualAmountCentsMeta = const VerificationMeta(
    'actualAmountCents',
  );
  @override
  late final GeneratedColumn<int> actualAmountCents = GeneratedColumn<int>(
    'actual_amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    budgetId,
    accountId,
    plannedAmountCents,
    actualAmountCents,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budget_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('budget_id')) {
      context.handle(
        _budgetIdMeta,
        budgetId.isAcceptableOrUnknown(data['budget_id']!, _budgetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_budgetIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('planned_amount_cents')) {
      context.handle(
        _plannedAmountCentsMeta,
        plannedAmountCents.isAcceptableOrUnknown(
          data['planned_amount_cents']!,
          _plannedAmountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_plannedAmountCentsMeta);
    }
    if (data.containsKey('actual_amount_cents')) {
      context.handle(
        _actualAmountCentsMeta,
        actualAmountCents.isAcceptableOrUnknown(
          data['actual_amount_cents']!,
          _actualAmountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actualAmountCentsMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BudgetItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      budgetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      plannedAmountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}planned_amount_cents'],
      )!,
      actualAmountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_amount_cents'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
    );
  }

  @override
  $BudgetItemsTable createAlias(String alias) {
    return $BudgetItemsTable(attachedDatabase, alias);
  }
}

class BudgetItem extends DataClass implements Insertable<BudgetItem> {
  final String id;
  final String budgetId;
  final String accountId;
  final int plannedAmountCents;
  final int actualAmountCents;
  final String notes;
  const BudgetItem({
    required this.id,
    required this.budgetId,
    required this.accountId,
    required this.plannedAmountCents,
    required this.actualAmountCents,
    required this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['budget_id'] = Variable<String>(budgetId);
    map['account_id'] = Variable<String>(accountId);
    map['planned_amount_cents'] = Variable<int>(plannedAmountCents);
    map['actual_amount_cents'] = Variable<int>(actualAmountCents);
    map['notes'] = Variable<String>(notes);
    return map;
  }

  BudgetItemsCompanion toCompanion(bool nullToAbsent) {
    return BudgetItemsCompanion(
      id: Value(id),
      budgetId: Value(budgetId),
      accountId: Value(accountId),
      plannedAmountCents: Value(plannedAmountCents),
      actualAmountCents: Value(actualAmountCents),
      notes: Value(notes),
    );
  }

  factory BudgetItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetItem(
      id: serializer.fromJson<String>(json['id']),
      budgetId: serializer.fromJson<String>(json['budgetId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      plannedAmountCents: serializer.fromJson<int>(json['plannedAmountCents']),
      actualAmountCents: serializer.fromJson<int>(json['actualAmountCents']),
      notes: serializer.fromJson<String>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'budgetId': serializer.toJson<String>(budgetId),
      'accountId': serializer.toJson<String>(accountId),
      'plannedAmountCents': serializer.toJson<int>(plannedAmountCents),
      'actualAmountCents': serializer.toJson<int>(actualAmountCents),
      'notes': serializer.toJson<String>(notes),
    };
  }

  BudgetItem copyWith({
    String? id,
    String? budgetId,
    String? accountId,
    int? plannedAmountCents,
    int? actualAmountCents,
    String? notes,
  }) => BudgetItem(
    id: id ?? this.id,
    budgetId: budgetId ?? this.budgetId,
    accountId: accountId ?? this.accountId,
    plannedAmountCents: plannedAmountCents ?? this.plannedAmountCents,
    actualAmountCents: actualAmountCents ?? this.actualAmountCents,
    notes: notes ?? this.notes,
  );
  BudgetItem copyWithCompanion(BudgetItemsCompanion data) {
    return BudgetItem(
      id: data.id.present ? data.id.value : this.id,
      budgetId: data.budgetId.present ? data.budgetId.value : this.budgetId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      plannedAmountCents: data.plannedAmountCents.present
          ? data.plannedAmountCents.value
          : this.plannedAmountCents,
      actualAmountCents: data.actualAmountCents.present
          ? data.actualAmountCents.value
          : this.actualAmountCents,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetItem(')
          ..write('id: $id, ')
          ..write('budgetId: $budgetId, ')
          ..write('accountId: $accountId, ')
          ..write('plannedAmountCents: $plannedAmountCents, ')
          ..write('actualAmountCents: $actualAmountCents, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    budgetId,
    accountId,
    plannedAmountCents,
    actualAmountCents,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetItem &&
          other.id == this.id &&
          other.budgetId == this.budgetId &&
          other.accountId == this.accountId &&
          other.plannedAmountCents == this.plannedAmountCents &&
          other.actualAmountCents == this.actualAmountCents &&
          other.notes == this.notes);
}

class BudgetItemsCompanion extends UpdateCompanion<BudgetItem> {
  final Value<String> id;
  final Value<String> budgetId;
  final Value<String> accountId;
  final Value<int> plannedAmountCents;
  final Value<int> actualAmountCents;
  final Value<String> notes;
  final Value<int> rowid;
  const BudgetItemsCompanion({
    this.id = const Value.absent(),
    this.budgetId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.plannedAmountCents = const Value.absent(),
    this.actualAmountCents = const Value.absent(),
    this.notes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetItemsCompanion.insert({
    required String id,
    required String budgetId,
    required String accountId,
    required int plannedAmountCents,
    required int actualAmountCents,
    required String notes,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       budgetId = Value(budgetId),
       accountId = Value(accountId),
       plannedAmountCents = Value(plannedAmountCents),
       actualAmountCents = Value(actualAmountCents),
       notes = Value(notes);
  static Insertable<BudgetItem> custom({
    Expression<String>? id,
    Expression<String>? budgetId,
    Expression<String>? accountId,
    Expression<int>? plannedAmountCents,
    Expression<int>? actualAmountCents,
    Expression<String>? notes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (budgetId != null) 'budget_id': budgetId,
      if (accountId != null) 'account_id': accountId,
      if (plannedAmountCents != null)
        'planned_amount_cents': plannedAmountCents,
      if (actualAmountCents != null) 'actual_amount_cents': actualAmountCents,
      if (notes != null) 'notes': notes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetItemsCompanion copyWith({
    Value<String>? id,
    Value<String>? budgetId,
    Value<String>? accountId,
    Value<int>? plannedAmountCents,
    Value<int>? actualAmountCents,
    Value<String>? notes,
    Value<int>? rowid,
  }) {
    return BudgetItemsCompanion(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      accountId: accountId ?? this.accountId,
      plannedAmountCents: plannedAmountCents ?? this.plannedAmountCents,
      actualAmountCents: actualAmountCents ?? this.actualAmountCents,
      notes: notes ?? this.notes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (budgetId.present) {
      map['budget_id'] = Variable<String>(budgetId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (plannedAmountCents.present) {
      map['planned_amount_cents'] = Variable<int>(plannedAmountCents.value);
    }
    if (actualAmountCents.present) {
      map['actual_amount_cents'] = Variable<int>(actualAmountCents.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetItemsCompanion(')
          ..write('id: $id, ')
          ..write('budgetId: $budgetId, ')
          ..write('accountId: $accountId, ')
          ..write('plannedAmountCents: $plannedAmountCents, ')
          ..write('actualAmountCents: $actualAmountCents, ')
          ..write('notes: $notes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalsTable extends Goals with TableInfo<$GoalsTable, Goal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalTypeMeta = const VerificationMeta(
    'goalType',
  );
  @override
  late final GeneratedColumn<int> goalType = GeneratedColumn<int>(
    'goal_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetAmountCentsMeta = const VerificationMeta(
    'targetAmountCents',
  );
  @override
  late final GeneratedColumn<int> targetAmountCents = GeneratedColumn<int>(
    'target_amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentAmountCentsMeta =
      const VerificationMeta('currentAmountCents');
  @override
  late final GeneratedColumn<int> currentAmountCents = GeneratedColumn<int>(
    'current_amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  @override
  late final GeneratedColumn<DateTime> deadline = GeneratedColumn<DateTime>(
    'deadline',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isCompletedMeta = const VerificationMeta(
    'isCompleted',
  );
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
    'is_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_completed" IN (0, 1))',
    ),
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    goalType,
    targetAmountCents,
    currentAmountCents,
    currencyCode,
    deadline,
    notes,
    isCompleted,
    completedAt,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Goal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('goal_type')) {
      context.handle(
        _goalTypeMeta,
        goalType.isAcceptableOrUnknown(data['goal_type']!, _goalTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_goalTypeMeta);
    }
    if (data.containsKey('target_amount_cents')) {
      context.handle(
        _targetAmountCentsMeta,
        targetAmountCents.isAcceptableOrUnknown(
          data['target_amount_cents']!,
          _targetAmountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetAmountCentsMeta);
    }
    if (data.containsKey('current_amount_cents')) {
      context.handle(
        _currentAmountCentsMeta,
        currentAmountCents.isAcceptableOrUnknown(
          data['current_amount_cents']!,
          _currentAmountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentAmountCentsMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    if (data.containsKey('is_completed')) {
      context.handle(
        _isCompletedMeta,
        isCompleted.isAcceptableOrUnknown(
          data['is_completed']!,
          _isCompletedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_isCompletedMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Goal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Goal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      goalType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}goal_type'],
      )!,
      targetAmountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_amount_cents'],
      )!,
      currentAmountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_amount_cents'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deadline'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      isCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_completed'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class Goal extends DataClass implements Insertable<Goal> {
  final String id;
  final String name;
  final int goalType;
  final int targetAmountCents;
  final int currentAmountCents;
  final String currencyCode;
  final DateTime? deadline;
  final String notes;
  final bool isCompleted;
  final DateTime? completedAt;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Goal({
    required this.id,
    required this.name,
    required this.goalType,
    required this.targetAmountCents,
    required this.currentAmountCents,
    required this.currencyCode,
    this.deadline,
    required this.notes,
    required this.isCompleted,
    this.completedAt,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['goal_type'] = Variable<int>(goalType);
    map['target_amount_cents'] = Variable<int>(targetAmountCents);
    map['current_amount_cents'] = Variable<int>(currentAmountCents);
    map['currency_code'] = Variable<String>(currencyCode);
    if (!nullToAbsent || deadline != null) {
      map['deadline'] = Variable<DateTime>(deadline);
    }
    map['notes'] = Variable<String>(notes);
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      name: Value(name),
      goalType: Value(goalType),
      targetAmountCents: Value(targetAmountCents),
      currentAmountCents: Value(currentAmountCents),
      currencyCode: Value(currencyCode),
      deadline: deadline == null && nullToAbsent
          ? const Value.absent()
          : Value(deadline),
      notes: Value(notes),
      isCompleted: Value(isCompleted),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Goal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Goal(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      goalType: serializer.fromJson<int>(json['goalType']),
      targetAmountCents: serializer.fromJson<int>(json['targetAmountCents']),
      currentAmountCents: serializer.fromJson<int>(json['currentAmountCents']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      deadline: serializer.fromJson<DateTime?>(json['deadline']),
      notes: serializer.fromJson<String>(json['notes']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'goalType': serializer.toJson<int>(goalType),
      'targetAmountCents': serializer.toJson<int>(targetAmountCents),
      'currentAmountCents': serializer.toJson<int>(currentAmountCents),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'deadline': serializer.toJson<DateTime?>(deadline),
      'notes': serializer.toJson<String>(notes),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Goal copyWith({
    String? id,
    String? name,
    int? goalType,
    int? targetAmountCents,
    int? currentAmountCents,
    String? currencyCode,
    Value<DateTime?> deadline = const Value.absent(),
    String? notes,
    bool? isCompleted,
    Value<DateTime?> completedAt = const Value.absent(),
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Goal(
    id: id ?? this.id,
    name: name ?? this.name,
    goalType: goalType ?? this.goalType,
    targetAmountCents: targetAmountCents ?? this.targetAmountCents,
    currentAmountCents: currentAmountCents ?? this.currentAmountCents,
    currencyCode: currencyCode ?? this.currencyCode,
    deadline: deadline.present ? deadline.value : this.deadline,
    notes: notes ?? this.notes,
    isCompleted: isCompleted ?? this.isCompleted,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Goal copyWithCompanion(GoalsCompanion data) {
    return Goal(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      goalType: data.goalType.present ? data.goalType.value : this.goalType,
      targetAmountCents: data.targetAmountCents.present
          ? data.targetAmountCents.value
          : this.targetAmountCents,
      currentAmountCents: data.currentAmountCents.present
          ? data.currentAmountCents.value
          : this.currentAmountCents,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      notes: data.notes.present ? data.notes.value : this.notes,
      isCompleted: data.isCompleted.present
          ? data.isCompleted.value
          : this.isCompleted,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Goal(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('goalType: $goalType, ')
          ..write('targetAmountCents: $targetAmountCents, ')
          ..write('currentAmountCents: $currentAmountCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('deadline: $deadline, ')
          ..write('notes: $notes, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAt: $completedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    goalType,
    targetAmountCents,
    currentAmountCents,
    currencyCode,
    deadline,
    notes,
    isCompleted,
    completedAt,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Goal &&
          other.id == this.id &&
          other.name == this.name &&
          other.goalType == this.goalType &&
          other.targetAmountCents == this.targetAmountCents &&
          other.currentAmountCents == this.currentAmountCents &&
          other.currencyCode == this.currencyCode &&
          other.deadline == this.deadline &&
          other.notes == this.notes &&
          other.isCompleted == this.isCompleted &&
          other.completedAt == this.completedAt &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class GoalsCompanion extends UpdateCompanion<Goal> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> goalType;
  final Value<int> targetAmountCents;
  final Value<int> currentAmountCents;
  final Value<String> currencyCode;
  final Value<DateTime?> deadline;
  final Value<String> notes;
  final Value<bool> isCompleted;
  final Value<DateTime?> completedAt;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.goalType = const Value.absent(),
    this.targetAmountCents = const Value.absent(),
    this.currentAmountCents = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.deadline = const Value.absent(),
    this.notes = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsCompanion.insert({
    required String id,
    required String name,
    required int goalType,
    required int targetAmountCents,
    required int currentAmountCents,
    required String currencyCode,
    this.deadline = const Value.absent(),
    required String notes,
    required bool isCompleted,
    this.completedAt = const Value.absent(),
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       goalType = Value(goalType),
       targetAmountCents = Value(targetAmountCents),
       currentAmountCents = Value(currentAmountCents),
       currencyCode = Value(currencyCode),
       notes = Value(notes),
       isCompleted = Value(isCompleted),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Goal> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? goalType,
    Expression<int>? targetAmountCents,
    Expression<int>? currentAmountCents,
    Expression<String>? currencyCode,
    Expression<DateTime>? deadline,
    Expression<String>? notes,
    Expression<bool>? isCompleted,
    Expression<DateTime>? completedAt,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (goalType != null) 'goal_type': goalType,
      if (targetAmountCents != null) 'target_amount_cents': targetAmountCents,
      if (currentAmountCents != null)
        'current_amount_cents': currentAmountCents,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (deadline != null) 'deadline': deadline,
      if (notes != null) 'notes': notes,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (completedAt != null) 'completed_at': completedAt,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? goalType,
    Value<int>? targetAmountCents,
    Value<int>? currentAmountCents,
    Value<String>? currencyCode,
    Value<DateTime?>? deadline,
    Value<String>? notes,
    Value<bool>? isCompleted,
    Value<DateTime?>? completedAt,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      goalType: goalType ?? this.goalType,
      targetAmountCents: targetAmountCents ?? this.targetAmountCents,
      currentAmountCents: currentAmountCents ?? this.currentAmountCents,
      currencyCode: currencyCode ?? this.currencyCode,
      deadline: deadline ?? this.deadline,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (goalType.present) {
      map['goal_type'] = Variable<int>(goalType.value);
    }
    if (targetAmountCents.present) {
      map['target_amount_cents'] = Variable<int>(targetAmountCents.value);
    }
    if (currentAmountCents.present) {
      map['current_amount_cents'] = Variable<int>(currentAmountCents.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<DateTime>(deadline.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('goalType: $goalType, ')
          ..write('targetAmountCents: $targetAmountCents, ')
          ..write('currentAmountCents: $currentAmountCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('deadline: $deadline, ')
          ..write('notes: $notes, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('completedAt: $completedAt, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalAccountLinksTable extends GoalAccountLinks
    with TableInfo<$GoalAccountLinksTable, GoalAccountLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalAccountLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _linkedIdMeta = const VerificationMeta(
    'linkedId',
  );
  @override
  late final GeneratedColumn<String> linkedId = GeneratedColumn<String>(
    'linked_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [goalId, linkedId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_account_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalAccountLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('linked_id')) {
      context.handle(
        _linkedIdMeta,
        linkedId.isAcceptableOrUnknown(data['linked_id']!, _linkedIdMeta),
      );
    } else if (isInserting) {
      context.missing(_linkedIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {goalId, linkedId};
  @override
  GoalAccountLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalAccountLink(
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      )!,
      linkedId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_id'],
      )!,
    );
  }

  @override
  $GoalAccountLinksTable createAlias(String alias) {
    return $GoalAccountLinksTable(attachedDatabase, alias);
  }
}

class GoalAccountLink extends DataClass implements Insertable<GoalAccountLink> {
  final String goalId;
  final String linkedId;
  const GoalAccountLink({required this.goalId, required this.linkedId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['goal_id'] = Variable<String>(goalId);
    map['linked_id'] = Variable<String>(linkedId);
    return map;
  }

  GoalAccountLinksCompanion toCompanion(bool nullToAbsent) {
    return GoalAccountLinksCompanion(
      goalId: Value(goalId),
      linkedId: Value(linkedId),
    );
  }

  factory GoalAccountLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalAccountLink(
      goalId: serializer.fromJson<String>(json['goalId']),
      linkedId: serializer.fromJson<String>(json['linkedId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'goalId': serializer.toJson<String>(goalId),
      'linkedId': serializer.toJson<String>(linkedId),
    };
  }

  GoalAccountLink copyWith({String? goalId, String? linkedId}) =>
      GoalAccountLink(
        goalId: goalId ?? this.goalId,
        linkedId: linkedId ?? this.linkedId,
      );
  GoalAccountLink copyWithCompanion(GoalAccountLinksCompanion data) {
    return GoalAccountLink(
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      linkedId: data.linkedId.present ? data.linkedId.value : this.linkedId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalAccountLink(')
          ..write('goalId: $goalId, ')
          ..write('linkedId: $linkedId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(goalId, linkedId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalAccountLink &&
          other.goalId == this.goalId &&
          other.linkedId == this.linkedId);
}

class GoalAccountLinksCompanion extends UpdateCompanion<GoalAccountLink> {
  final Value<String> goalId;
  final Value<String> linkedId;
  final Value<int> rowid;
  const GoalAccountLinksCompanion({
    this.goalId = const Value.absent(),
    this.linkedId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalAccountLinksCompanion.insert({
    required String goalId,
    required String linkedId,
    this.rowid = const Value.absent(),
  }) : goalId = Value(goalId),
       linkedId = Value(linkedId);
  static Insertable<GoalAccountLink> custom({
    Expression<String>? goalId,
    Expression<String>? linkedId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (goalId != null) 'goal_id': goalId,
      if (linkedId != null) 'linked_id': linkedId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalAccountLinksCompanion copyWith({
    Value<String>? goalId,
    Value<String>? linkedId,
    Value<int>? rowid,
  }) {
    return GoalAccountLinksCompanion(
      goalId: goalId ?? this.goalId,
      linkedId: linkedId ?? this.linkedId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (linkedId.present) {
      map['linked_id'] = Variable<String>(linkedId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalAccountLinksCompanion(')
          ..write('goalId: $goalId, ')
          ..write('linkedId: $linkedId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalDebtLinksTable extends GoalDebtLinks
    with TableInfo<$GoalDebtLinksTable, GoalDebtLink> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalDebtLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES goals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _linkedIdMeta = const VerificationMeta(
    'linkedId',
  );
  @override
  late final GeneratedColumn<String> linkedId = GeneratedColumn<String>(
    'linked_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [goalId, linkedId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_debt_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalDebtLink> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('linked_id')) {
      context.handle(
        _linkedIdMeta,
        linkedId.isAcceptableOrUnknown(data['linked_id']!, _linkedIdMeta),
      );
    } else if (isInserting) {
      context.missing(_linkedIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {goalId, linkedId};
  @override
  GoalDebtLink map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalDebtLink(
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      )!,
      linkedId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_id'],
      )!,
    );
  }

  @override
  $GoalDebtLinksTable createAlias(String alias) {
    return $GoalDebtLinksTable(attachedDatabase, alias);
  }
}

class GoalDebtLink extends DataClass implements Insertable<GoalDebtLink> {
  final String goalId;
  final String linkedId;
  const GoalDebtLink({required this.goalId, required this.linkedId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['goal_id'] = Variable<String>(goalId);
    map['linked_id'] = Variable<String>(linkedId);
    return map;
  }

  GoalDebtLinksCompanion toCompanion(bool nullToAbsent) {
    return GoalDebtLinksCompanion(
      goalId: Value(goalId),
      linkedId: Value(linkedId),
    );
  }

  factory GoalDebtLink.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalDebtLink(
      goalId: serializer.fromJson<String>(json['goalId']),
      linkedId: serializer.fromJson<String>(json['linkedId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'goalId': serializer.toJson<String>(goalId),
      'linkedId': serializer.toJson<String>(linkedId),
    };
  }

  GoalDebtLink copyWith({String? goalId, String? linkedId}) => GoalDebtLink(
    goalId: goalId ?? this.goalId,
    linkedId: linkedId ?? this.linkedId,
  );
  GoalDebtLink copyWithCompanion(GoalDebtLinksCompanion data) {
    return GoalDebtLink(
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      linkedId: data.linkedId.present ? data.linkedId.value : this.linkedId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalDebtLink(')
          ..write('goalId: $goalId, ')
          ..write('linkedId: $linkedId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(goalId, linkedId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalDebtLink &&
          other.goalId == this.goalId &&
          other.linkedId == this.linkedId);
}

class GoalDebtLinksCompanion extends UpdateCompanion<GoalDebtLink> {
  final Value<String> goalId;
  final Value<String> linkedId;
  final Value<int> rowid;
  const GoalDebtLinksCompanion({
    this.goalId = const Value.absent(),
    this.linkedId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalDebtLinksCompanion.insert({
    required String goalId,
    required String linkedId,
    this.rowid = const Value.absent(),
  }) : goalId = Value(goalId),
       linkedId = Value(linkedId);
  static Insertable<GoalDebtLink> custom({
    Expression<String>? goalId,
    Expression<String>? linkedId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (goalId != null) 'goal_id': goalId,
      if (linkedId != null) 'linked_id': linkedId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalDebtLinksCompanion copyWith({
    Value<String>? goalId,
    Value<String>? linkedId,
    Value<int>? rowid,
  }) {
    return GoalDebtLinksCompanion(
      goalId: goalId ?? this.goalId,
      linkedId: linkedId ?? this.linkedId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (linkedId.present) {
      map['linked_id'] = Variable<String>(linkedId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalDebtLinksCompanion(')
          ..write('goalId: $goalId, ')
          ..write('linkedId: $linkedId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagsTable extends Tags with TableInfo<$TagsTable, Tag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<String> color = GeneratedColumn<String>(
    'color',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    color,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<Tag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
        _colorMeta,
        color.isAcceptableOrUnknown(data['color']!, _colorMeta),
      );
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Tag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Tag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      color: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TagsTable createAlias(String alias) {
    return $TagsTable(attachedDatabase, alias);
  }
}

class Tag extends DataClass implements Insertable<Tag> {
  final String id;
  final String name;
  final String color;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['color'] = Variable<String>(color);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TagsCompanion toCompanion(bool nullToAbsent) {
    return TagsCompanion(
      id: Value(id),
      name: Value(name),
      color: Value(color),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Tag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Tag(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      color: serializer.fromJson<String>(json['color']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'color': serializer.toJson<String>(color),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Tag copyWith({
    String? id,
    String? name,
    String? color,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Tag(
    id: id ?? this.id,
    name: name ?? this.name,
    color: color ?? this.color,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Tag copyWithCompanion(TagsCompanion data) {
    return Tag(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      color: data.color.present ? data.color.value : this.color,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Tag(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, color, version, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Tag &&
          other.id == this.id &&
          other.name == this.name &&
          other.color == this.color &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TagsCompanion extends UpdateCompanion<Tag> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> color;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TagsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.color = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagsCompanion.insert({
    required String id,
    required String name,
    required String color,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       color = Value(color),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Tag> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? color,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (color != null) 'color': color,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? color,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TagsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (color.present) {
      map['color'] = Variable<String>(color.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('color: $color, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionTagsTable extends TransactionTags
    with TableInfo<$TransactionTagsTable, TransactionTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES transactions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _tagIdMeta = const VerificationMeta('tagId');
  @override
  late final GeneratedColumn<String> tagId = GeneratedColumn<String>(
    'tag_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tags (id) ON DELETE CASCADE',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [transactionId, tagId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_transactionIdMeta);
    }
    if (data.containsKey('tag_id')) {
      context.handle(
        _tagIdMeta,
        tagId.isAcceptableOrUnknown(data['tag_id']!, _tagIdMeta),
      );
    } else if (isInserting) {
      context.missing(_tagIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {transactionId, tagId};
  @override
  TransactionTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionTag(
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      )!,
      tagId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag_id'],
      )!,
    );
  }

  @override
  $TransactionTagsTable createAlias(String alias) {
    return $TransactionTagsTable(attachedDatabase, alias);
  }
}

class TransactionTag extends DataClass implements Insertable<TransactionTag> {
  final String transactionId;
  final String tagId;
  const TransactionTag({required this.transactionId, required this.tagId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['transaction_id'] = Variable<String>(transactionId);
    map['tag_id'] = Variable<String>(tagId);
    return map;
  }

  TransactionTagsCompanion toCompanion(bool nullToAbsent) {
    return TransactionTagsCompanion(
      transactionId: Value(transactionId),
      tagId: Value(tagId),
    );
  }

  factory TransactionTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionTag(
      transactionId: serializer.fromJson<String>(json['transactionId']),
      tagId: serializer.fromJson<String>(json['tagId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'transactionId': serializer.toJson<String>(transactionId),
      'tagId': serializer.toJson<String>(tagId),
    };
  }

  TransactionTag copyWith({String? transactionId, String? tagId}) =>
      TransactionTag(
        transactionId: transactionId ?? this.transactionId,
        tagId: tagId ?? this.tagId,
      );
  TransactionTag copyWithCompanion(TransactionTagsCompanion data) {
    return TransactionTag(
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      tagId: data.tagId.present ? data.tagId.value : this.tagId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTag(')
          ..write('transactionId: $transactionId, ')
          ..write('tagId: $tagId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(transactionId, tagId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionTag &&
          other.transactionId == this.transactionId &&
          other.tagId == this.tagId);
}

class TransactionTagsCompanion extends UpdateCompanion<TransactionTag> {
  final Value<String> transactionId;
  final Value<String> tagId;
  final Value<int> rowid;
  const TransactionTagsCompanion({
    this.transactionId = const Value.absent(),
    this.tagId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionTagsCompanion.insert({
    required String transactionId,
    required String tagId,
    this.rowid = const Value.absent(),
  }) : transactionId = Value(transactionId),
       tagId = Value(tagId);
  static Insertable<TransactionTag> custom({
    Expression<String>? transactionId,
    Expression<String>? tagId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (transactionId != null) 'transaction_id': transactionId,
      if (tagId != null) 'tag_id': tagId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionTagsCompanion copyWith({
    Value<String>? transactionId,
    Value<String>? tagId,
    Value<int>? rowid,
  }) {
    return TransactionTagsCompanion(
      transactionId: transactionId ?? this.transactionId,
      tagId: tagId ?? this.tagId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (tagId.present) {
      map['tag_id'] = Variable<String>(tagId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTagsCompanion(')
          ..write('transactionId: $transactionId, ')
          ..write('tagId: $tagId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TransactionTemplatesTable extends TransactionTemplates
    with TableInfo<$TransactionTemplatesTable, TransactionTemplate> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionTemplatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _directionMeta = const VerificationMeta(
    'direction',
  );
  @override
  late final GeneratedColumn<int> direction = GeneratedColumn<int>(
    'direction',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceAccountIdMeta = const VerificationMeta(
    'sourceAccountId',
  );
  @override
  late final GeneratedColumn<String> sourceAccountId = GeneratedColumn<String>(
    'source_account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationAccountIdMeta =
      const VerificationMeta('destinationAccountId');
  @override
  late final GeneratedColumn<String> destinationAccountId =
      GeneratedColumn<String>(
        'destination_account_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _cycleMeta = const VerificationMeta('cycle');
  @override
  late final GeneratedColumn<int> cycle = GeneratedColumn<int>(
    'cycle',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cycleDaysMeta = const VerificationMeta(
    'cycleDays',
  );
  @override
  late final GeneratedColumn<int> cycleDays = GeneratedColumn<int>(
    'cycle_days',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _billingDayMeta = const VerificationMeta(
    'billingDay',
  );
  @override
  late final GeneratedColumn<int> billingDay = GeneratedColumn<int>(
    'billing_day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nextDateMeta = const VerificationMeta(
    'nextDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextDate = GeneratedColumn<DateTime>(
    'next_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autoRecordMeta = const VerificationMeta(
    'autoRecord',
  );
  @override
  late final GeneratedColumn<bool> autoRecord = GeneratedColumn<bool>(
    'auto_record',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_record" IN (0, 1))',
    ),
  );
  static const VerificationMeta _pausedMeta = const VerificationMeta('paused');
  @override
  late final GeneratedColumn<bool> paused = GeneratedColumn<bool>(
    'paused',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("paused" IN (0, 1))',
    ),
  );
  static const VerificationMeta _lastTransactionIdMeta = const VerificationMeta(
    'lastTransactionId',
  );
  @override
  late final GeneratedColumn<String> lastTransactionId =
      GeneratedColumn<String>(
        'last_transaction_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    description,
    amountCents,
    direction,
    sourceAccountId,
    destinationAccountId,
    cycle,
    cycleDays,
    billingDay,
    nextDate,
    startDate,
    endDate,
    autoRecord,
    paused,
    lastTransactionId,
    category,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transaction_templates';
  @override
  VerificationContext validateIntegrity(
    Insertable<TransactionTemplate> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_descriptionMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('direction')) {
      context.handle(
        _directionMeta,
        direction.isAcceptableOrUnknown(data['direction']!, _directionMeta),
      );
    } else if (isInserting) {
      context.missing(_directionMeta);
    }
    if (data.containsKey('source_account_id')) {
      context.handle(
        _sourceAccountIdMeta,
        sourceAccountId.isAcceptableOrUnknown(
          data['source_account_id']!,
          _sourceAccountIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceAccountIdMeta);
    }
    if (data.containsKey('destination_account_id')) {
      context.handle(
        _destinationAccountIdMeta,
        destinationAccountId.isAcceptableOrUnknown(
          data['destination_account_id']!,
          _destinationAccountIdMeta,
        ),
      );
    }
    if (data.containsKey('cycle')) {
      context.handle(
        _cycleMeta,
        cycle.isAcceptableOrUnknown(data['cycle']!, _cycleMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleMeta);
    }
    if (data.containsKey('cycle_days')) {
      context.handle(
        _cycleDaysMeta,
        cycleDays.isAcceptableOrUnknown(data['cycle_days']!, _cycleDaysMeta),
      );
    } else if (isInserting) {
      context.missing(_cycleDaysMeta);
    }
    if (data.containsKey('billing_day')) {
      context.handle(
        _billingDayMeta,
        billingDay.isAcceptableOrUnknown(data['billing_day']!, _billingDayMeta),
      );
    } else if (isInserting) {
      context.missing(_billingDayMeta);
    }
    if (data.containsKey('next_date')) {
      context.handle(
        _nextDateMeta,
        nextDate.isAcceptableOrUnknown(data['next_date']!, _nextDateMeta),
      );
    } else if (isInserting) {
      context.missing(_nextDateMeta);
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    } else if (isInserting) {
      context.missing(_startDateMeta);
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('auto_record')) {
      context.handle(
        _autoRecordMeta,
        autoRecord.isAcceptableOrUnknown(data['auto_record']!, _autoRecordMeta),
      );
    } else if (isInserting) {
      context.missing(_autoRecordMeta);
    }
    if (data.containsKey('paused')) {
      context.handle(
        _pausedMeta,
        paused.isAcceptableOrUnknown(data['paused']!, _pausedMeta),
      );
    } else if (isInserting) {
      context.missing(_pausedMeta);
    }
    if (data.containsKey('last_transaction_id')) {
      context.handle(
        _lastTransactionIdMeta,
        lastTransactionId.isAcceptableOrUnknown(
          data['last_transaction_id']!,
          _lastTransactionIdMeta,
        ),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TransactionTemplate map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TransactionTemplate(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      direction: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}direction'],
      )!,
      sourceAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_account_id'],
      )!,
      destinationAccountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_account_id'],
      ),
      cycle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycle'],
      )!,
      cycleDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}cycle_days'],
      )!,
      billingDay: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}billing_day'],
      )!,
      nextDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_date'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      )!,
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      autoRecord: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_record'],
      )!,
      paused: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}paused'],
      )!,
      lastTransactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_transaction_id'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TransactionTemplatesTable createAlias(String alias) {
    return $TransactionTemplatesTable(attachedDatabase, alias);
  }
}

class TransactionTemplate extends DataClass
    implements Insertable<TransactionTemplate> {
  final String id;
  final String name;
  final String description;
  final int amountCents;
  final int direction;
  final String sourceAccountId;
  final String? destinationAccountId;
  final int cycle;
  final int cycleDays;
  final int billingDay;
  final DateTime nextDate;
  final DateTime startDate;
  final DateTime? endDate;
  final bool autoRecord;
  final bool paused;
  final String? lastTransactionId;
  final String category;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TransactionTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.amountCents,
    required this.direction,
    required this.sourceAccountId,
    this.destinationAccountId,
    required this.cycle,
    required this.cycleDays,
    required this.billingDay,
    required this.nextDate,
    required this.startDate,
    this.endDate,
    required this.autoRecord,
    required this.paused,
    this.lastTransactionId,
    required this.category,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['description'] = Variable<String>(description);
    map['amount_cents'] = Variable<int>(amountCents);
    map['direction'] = Variable<int>(direction);
    map['source_account_id'] = Variable<String>(sourceAccountId);
    if (!nullToAbsent || destinationAccountId != null) {
      map['destination_account_id'] = Variable<String>(destinationAccountId);
    }
    map['cycle'] = Variable<int>(cycle);
    map['cycle_days'] = Variable<int>(cycleDays);
    map['billing_day'] = Variable<int>(billingDay);
    map['next_date'] = Variable<DateTime>(nextDate);
    map['start_date'] = Variable<DateTime>(startDate);
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['auto_record'] = Variable<bool>(autoRecord);
    map['paused'] = Variable<bool>(paused);
    if (!nullToAbsent || lastTransactionId != null) {
      map['last_transaction_id'] = Variable<String>(lastTransactionId);
    }
    map['category'] = Variable<String>(category);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TransactionTemplatesCompanion toCompanion(bool nullToAbsent) {
    return TransactionTemplatesCompanion(
      id: Value(id),
      name: Value(name),
      description: Value(description),
      amountCents: Value(amountCents),
      direction: Value(direction),
      sourceAccountId: Value(sourceAccountId),
      destinationAccountId: destinationAccountId == null && nullToAbsent
          ? const Value.absent()
          : Value(destinationAccountId),
      cycle: Value(cycle),
      cycleDays: Value(cycleDays),
      billingDay: Value(billingDay),
      nextDate: Value(nextDate),
      startDate: Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      autoRecord: Value(autoRecord),
      paused: Value(paused),
      lastTransactionId: lastTransactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastTransactionId),
      category: Value(category),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TransactionTemplate.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TransactionTemplate(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String>(json['description']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      direction: serializer.fromJson<int>(json['direction']),
      sourceAccountId: serializer.fromJson<String>(json['sourceAccountId']),
      destinationAccountId: serializer.fromJson<String?>(
        json['destinationAccountId'],
      ),
      cycle: serializer.fromJson<int>(json['cycle']),
      cycleDays: serializer.fromJson<int>(json['cycleDays']),
      billingDay: serializer.fromJson<int>(json['billingDay']),
      nextDate: serializer.fromJson<DateTime>(json['nextDate']),
      startDate: serializer.fromJson<DateTime>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      autoRecord: serializer.fromJson<bool>(json['autoRecord']),
      paused: serializer.fromJson<bool>(json['paused']),
      lastTransactionId: serializer.fromJson<String?>(
        json['lastTransactionId'],
      ),
      category: serializer.fromJson<String>(json['category']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String>(description),
      'amountCents': serializer.toJson<int>(amountCents),
      'direction': serializer.toJson<int>(direction),
      'sourceAccountId': serializer.toJson<String>(sourceAccountId),
      'destinationAccountId': serializer.toJson<String?>(destinationAccountId),
      'cycle': serializer.toJson<int>(cycle),
      'cycleDays': serializer.toJson<int>(cycleDays),
      'billingDay': serializer.toJson<int>(billingDay),
      'nextDate': serializer.toJson<DateTime>(nextDate),
      'startDate': serializer.toJson<DateTime>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'autoRecord': serializer.toJson<bool>(autoRecord),
      'paused': serializer.toJson<bool>(paused),
      'lastTransactionId': serializer.toJson<String?>(lastTransactionId),
      'category': serializer.toJson<String>(category),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TransactionTemplate copyWith({
    String? id,
    String? name,
    String? description,
    int? amountCents,
    int? direction,
    String? sourceAccountId,
    Value<String?> destinationAccountId = const Value.absent(),
    int? cycle,
    int? cycleDays,
    int? billingDay,
    DateTime? nextDate,
    DateTime? startDate,
    Value<DateTime?> endDate = const Value.absent(),
    bool? autoRecord,
    bool? paused,
    Value<String?> lastTransactionId = const Value.absent(),
    String? category,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TransactionTemplate(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    amountCents: amountCents ?? this.amountCents,
    direction: direction ?? this.direction,
    sourceAccountId: sourceAccountId ?? this.sourceAccountId,
    destinationAccountId: destinationAccountId.present
        ? destinationAccountId.value
        : this.destinationAccountId,
    cycle: cycle ?? this.cycle,
    cycleDays: cycleDays ?? this.cycleDays,
    billingDay: billingDay ?? this.billingDay,
    nextDate: nextDate ?? this.nextDate,
    startDate: startDate ?? this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    autoRecord: autoRecord ?? this.autoRecord,
    paused: paused ?? this.paused,
    lastTransactionId: lastTransactionId.present
        ? lastTransactionId.value
        : this.lastTransactionId,
    category: category ?? this.category,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TransactionTemplate copyWithCompanion(TransactionTemplatesCompanion data) {
    return TransactionTemplate(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description: data.description.present
          ? data.description.value
          : this.description,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      direction: data.direction.present ? data.direction.value : this.direction,
      sourceAccountId: data.sourceAccountId.present
          ? data.sourceAccountId.value
          : this.sourceAccountId,
      destinationAccountId: data.destinationAccountId.present
          ? data.destinationAccountId.value
          : this.destinationAccountId,
      cycle: data.cycle.present ? data.cycle.value : this.cycle,
      cycleDays: data.cycleDays.present ? data.cycleDays.value : this.cycleDays,
      billingDay: data.billingDay.present
          ? data.billingDay.value
          : this.billingDay,
      nextDate: data.nextDate.present ? data.nextDate.value : this.nextDate,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      autoRecord: data.autoRecord.present
          ? data.autoRecord.value
          : this.autoRecord,
      paused: data.paused.present ? data.paused.value : this.paused,
      lastTransactionId: data.lastTransactionId.present
          ? data.lastTransactionId.value
          : this.lastTransactionId,
      category: data.category.present ? data.category.value : this.category,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTemplate(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('amountCents: $amountCents, ')
          ..write('direction: $direction, ')
          ..write('sourceAccountId: $sourceAccountId, ')
          ..write('destinationAccountId: $destinationAccountId, ')
          ..write('cycle: $cycle, ')
          ..write('cycleDays: $cycleDays, ')
          ..write('billingDay: $billingDay, ')
          ..write('nextDate: $nextDate, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('autoRecord: $autoRecord, ')
          ..write('paused: $paused, ')
          ..write('lastTransactionId: $lastTransactionId, ')
          ..write('category: $category, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    amountCents,
    direction,
    sourceAccountId,
    destinationAccountId,
    cycle,
    cycleDays,
    billingDay,
    nextDate,
    startDate,
    endDate,
    autoRecord,
    paused,
    lastTransactionId,
    category,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TransactionTemplate &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.amountCents == this.amountCents &&
          other.direction == this.direction &&
          other.sourceAccountId == this.sourceAccountId &&
          other.destinationAccountId == this.destinationAccountId &&
          other.cycle == this.cycle &&
          other.cycleDays == this.cycleDays &&
          other.billingDay == this.billingDay &&
          other.nextDate == this.nextDate &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.autoRecord == this.autoRecord &&
          other.paused == this.paused &&
          other.lastTransactionId == this.lastTransactionId &&
          other.category == this.category &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TransactionTemplatesCompanion
    extends UpdateCompanion<TransactionTemplate> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> description;
  final Value<int> amountCents;
  final Value<int> direction;
  final Value<String> sourceAccountId;
  final Value<String?> destinationAccountId;
  final Value<int> cycle;
  final Value<int> cycleDays;
  final Value<int> billingDay;
  final Value<DateTime> nextDate;
  final Value<DateTime> startDate;
  final Value<DateTime?> endDate;
  final Value<bool> autoRecord;
  final Value<bool> paused;
  final Value<String?> lastTransactionId;
  final Value<String> category;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TransactionTemplatesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.direction = const Value.absent(),
    this.sourceAccountId = const Value.absent(),
    this.destinationAccountId = const Value.absent(),
    this.cycle = const Value.absent(),
    this.cycleDays = const Value.absent(),
    this.billingDay = const Value.absent(),
    this.nextDate = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.autoRecord = const Value.absent(),
    this.paused = const Value.absent(),
    this.lastTransactionId = const Value.absent(),
    this.category = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TransactionTemplatesCompanion.insert({
    required String id,
    required String name,
    required String description,
    required int amountCents,
    required int direction,
    required String sourceAccountId,
    this.destinationAccountId = const Value.absent(),
    required int cycle,
    required int cycleDays,
    required int billingDay,
    required DateTime nextDate,
    required DateTime startDate,
    this.endDate = const Value.absent(),
    required bool autoRecord,
    required bool paused,
    this.lastTransactionId = const Value.absent(),
    required String category,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       description = Value(description),
       amountCents = Value(amountCents),
       direction = Value(direction),
       sourceAccountId = Value(sourceAccountId),
       cycle = Value(cycle),
       cycleDays = Value(cycleDays),
       billingDay = Value(billingDay),
       nextDate = Value(nextDate),
       startDate = Value(startDate),
       autoRecord = Value(autoRecord),
       paused = Value(paused),
       category = Value(category),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TransactionTemplate> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<int>? amountCents,
    Expression<int>? direction,
    Expression<String>? sourceAccountId,
    Expression<String>? destinationAccountId,
    Expression<int>? cycle,
    Expression<int>? cycleDays,
    Expression<int>? billingDay,
    Expression<DateTime>? nextDate,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<bool>? autoRecord,
    Expression<bool>? paused,
    Expression<String>? lastTransactionId,
    Expression<String>? category,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (amountCents != null) 'amount_cents': amountCents,
      if (direction != null) 'direction': direction,
      if (sourceAccountId != null) 'source_account_id': sourceAccountId,
      if (destinationAccountId != null)
        'destination_account_id': destinationAccountId,
      if (cycle != null) 'cycle': cycle,
      if (cycleDays != null) 'cycle_days': cycleDays,
      if (billingDay != null) 'billing_day': billingDay,
      if (nextDate != null) 'next_date': nextDate,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (autoRecord != null) 'auto_record': autoRecord,
      if (paused != null) 'paused': paused,
      if (lastTransactionId != null) 'last_transaction_id': lastTransactionId,
      if (category != null) 'category': category,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TransactionTemplatesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? description,
    Value<int>? amountCents,
    Value<int>? direction,
    Value<String>? sourceAccountId,
    Value<String?>? destinationAccountId,
    Value<int>? cycle,
    Value<int>? cycleDays,
    Value<int>? billingDay,
    Value<DateTime>? nextDate,
    Value<DateTime>? startDate,
    Value<DateTime?>? endDate,
    Value<bool>? autoRecord,
    Value<bool>? paused,
    Value<String?>? lastTransactionId,
    Value<String>? category,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return TransactionTemplatesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      direction: direction ?? this.direction,
      sourceAccountId: sourceAccountId ?? this.sourceAccountId,
      destinationAccountId: destinationAccountId ?? this.destinationAccountId,
      cycle: cycle ?? this.cycle,
      cycleDays: cycleDays ?? this.cycleDays,
      billingDay: billingDay ?? this.billingDay,
      nextDate: nextDate ?? this.nextDate,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      autoRecord: autoRecord ?? this.autoRecord,
      paused: paused ?? this.paused,
      lastTransactionId: lastTransactionId ?? this.lastTransactionId,
      category: category ?? this.category,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (direction.present) {
      map['direction'] = Variable<int>(direction.value);
    }
    if (sourceAccountId.present) {
      map['source_account_id'] = Variable<String>(sourceAccountId.value);
    }
    if (destinationAccountId.present) {
      map['destination_account_id'] = Variable<String>(
        destinationAccountId.value,
      );
    }
    if (cycle.present) {
      map['cycle'] = Variable<int>(cycle.value);
    }
    if (cycleDays.present) {
      map['cycle_days'] = Variable<int>(cycleDays.value);
    }
    if (billingDay.present) {
      map['billing_day'] = Variable<int>(billingDay.value);
    }
    if (nextDate.present) {
      map['next_date'] = Variable<DateTime>(nextDate.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (autoRecord.present) {
      map['auto_record'] = Variable<bool>(autoRecord.value);
    }
    if (paused.present) {
      map['paused'] = Variable<bool>(paused.value);
    }
    if (lastTransactionId.present) {
      map['last_transaction_id'] = Variable<String>(lastTransactionId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionTemplatesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('amountCents: $amountCents, ')
          ..write('direction: $direction, ')
          ..write('sourceAccountId: $sourceAccountId, ')
          ..write('destinationAccountId: $destinationAccountId, ')
          ..write('cycle: $cycle, ')
          ..write('cycleDays: $cycleDays, ')
          ..write('billingDay: $billingDay, ')
          ..write('nextDate: $nextDate, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('autoRecord: $autoRecord, ')
          ..write('paused: $paused, ')
          ..write('lastTransactionId: $lastTransactionId, ')
          ..write('category: $category, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HoldingsTable extends Holdings with TableInfo<$HoldingsTable, Holding> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoldingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _securityIdMeta = const VerificationMeta(
    'securityId',
  );
  @override
  late final GeneratedColumn<String> securityId = GeneratedColumn<String>(
    'security_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _avgCostCentsMeta = const VerificationMeta(
    'avgCostCents',
  );
  @override
  late final GeneratedColumn<int> avgCostCents = GeneratedColumn<int>(
    'avg_cost_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    securityId,
    quantity,
    avgCostCents,
    version,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holdings';
  @override
  VerificationContext validateIntegrity(
    Insertable<Holding> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('security_id')) {
      context.handle(
        _securityIdMeta,
        securityId.isAcceptableOrUnknown(data['security_id']!, _securityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_securityIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('avg_cost_cents')) {
      context.handle(
        _avgCostCentsMeta,
        avgCostCents.isAcceptableOrUnknown(
          data['avg_cost_cents']!,
          _avgCostCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_avgCostCentsMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Holding map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Holding(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      securityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}security_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      avgCostCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}avg_cost_cents'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $HoldingsTable createAlias(String alias) {
    return $HoldingsTable(attachedDatabase, alias);
  }
}

class Holding extends DataClass implements Insertable<Holding> {
  final String id;
  final String accountId;
  final String securityId;
  final double quantity;
  final int avgCostCents;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Holding({
    required this.id,
    required this.accountId,
    required this.securityId,
    required this.quantity,
    required this.avgCostCents,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['security_id'] = Variable<String>(securityId);
    map['quantity'] = Variable<double>(quantity);
    map['avg_cost_cents'] = Variable<int>(avgCostCents);
    map['version'] = Variable<int>(version);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  HoldingsCompanion toCompanion(bool nullToAbsent) {
    return HoldingsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      securityId: Value(securityId),
      quantity: Value(quantity),
      avgCostCents: Value(avgCostCents),
      version: Value(version),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Holding.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Holding(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      securityId: serializer.fromJson<String>(json['securityId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      avgCostCents: serializer.fromJson<int>(json['avgCostCents']),
      version: serializer.fromJson<int>(json['version']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'securityId': serializer.toJson<String>(securityId),
      'quantity': serializer.toJson<double>(quantity),
      'avgCostCents': serializer.toJson<int>(avgCostCents),
      'version': serializer.toJson<int>(version),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Holding copyWith({
    String? id,
    String? accountId,
    String? securityId,
    double? quantity,
    int? avgCostCents,
    int? version,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Holding(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    securityId: securityId ?? this.securityId,
    quantity: quantity ?? this.quantity,
    avgCostCents: avgCostCents ?? this.avgCostCents,
    version: version ?? this.version,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Holding copyWithCompanion(HoldingsCompanion data) {
    return Holding(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      securityId: data.securityId.present
          ? data.securityId.value
          : this.securityId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      avgCostCents: data.avgCostCents.present
          ? data.avgCostCents.value
          : this.avgCostCents,
      version: data.version.present ? data.version.value : this.version,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Holding(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('securityId: $securityId, ')
          ..write('quantity: $quantity, ')
          ..write('avgCostCents: $avgCostCents, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    securityId,
    quantity,
    avgCostCents,
    version,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Holding &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.securityId == this.securityId &&
          other.quantity == this.quantity &&
          other.avgCostCents == this.avgCostCents &&
          other.version == this.version &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class HoldingsCompanion extends UpdateCompanion<Holding> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> securityId;
  final Value<double> quantity;
  final Value<int> avgCostCents;
  final Value<int> version;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const HoldingsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.securityId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.avgCostCents = const Value.absent(),
    this.version = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HoldingsCompanion.insert({
    required String id,
    required String accountId,
    required String securityId,
    required double quantity,
    required int avgCostCents,
    required int version,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       securityId = Value(securityId),
       quantity = Value(quantity),
       avgCostCents = Value(avgCostCents),
       version = Value(version),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Holding> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? securityId,
    Expression<double>? quantity,
    Expression<int>? avgCostCents,
    Expression<int>? version,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (securityId != null) 'security_id': securityId,
      if (quantity != null) 'quantity': quantity,
      if (avgCostCents != null) 'avg_cost_cents': avgCostCents,
      if (version != null) 'version': version,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HoldingsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? securityId,
    Value<double>? quantity,
    Value<int>? avgCostCents,
    Value<int>? version,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return HoldingsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      securityId: securityId ?? this.securityId,
      quantity: quantity ?? this.quantity,
      avgCostCents: avgCostCents ?? this.avgCostCents,
      version: version ?? this.version,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (securityId.present) {
      map['security_id'] = Variable<String>(securityId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (avgCostCents.present) {
      map['avg_cost_cents'] = Variable<int>(avgCostCents.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoldingsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('securityId: $securityId, ')
          ..write('quantity: $quantity, ')
          ..write('avgCostCents: $avgCostCents, ')
          ..write('version: $version, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HoldingTransactionsTable extends HoldingTransactions
    with TableInfo<$HoldingTransactionsTable, HoldingTransaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoldingTransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _securityIdMeta = const VerificationMeta(
    'securityId',
  );
  @override
  late final GeneratedColumn<String> securityId = GeneratedColumn<String>(
    'security_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tradeTypeMeta = const VerificationMeta(
    'tradeType',
  );
  @override
  late final GeneratedColumn<int> tradeType = GeneratedColumn<int>(
    'trade_type',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceCentsMeta = const VerificationMeta(
    'priceCents',
  );
  @override
  late final GeneratedColumn<int> priceCents = GeneratedColumn<int>(
    'price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountCentsMeta = const VerificationMeta(
    'amountCents',
  );
  @override
  late final GeneratedColumn<int> amountCents = GeneratedColumn<int>(
    'amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _feeCentsMeta = const VerificationMeta(
    'feeCents',
  );
  @override
  late final GeneratedColumn<int> feeCents = GeneratedColumn<int>(
    'fee_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _realizedPnlCentsMeta = const VerificationMeta(
    'realizedPnlCents',
  );
  @override
  late final GeneratedColumn<int> realizedPnlCents = GeneratedColumn<int>(
    'realized_pnl_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tradeDateMeta = const VerificationMeta(
    'tradeDate',
  );
  @override
  late final GeneratedColumn<DateTime> tradeDate = GeneratedColumn<DateTime>(
    'trade_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _transactionIdMeta = const VerificationMeta(
    'transactionId',
  );
  @override
  late final GeneratedColumn<String> transactionId = GeneratedColumn<String>(
    'transaction_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    accountId,
    securityId,
    tradeType,
    quantity,
    priceCents,
    amountCents,
    feeCents,
    realizedPnlCents,
    tradeDate,
    transactionId,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holding_transactions';
  @override
  VerificationContext validateIntegrity(
    Insertable<HoldingTransaction> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('security_id')) {
      context.handle(
        _securityIdMeta,
        securityId.isAcceptableOrUnknown(data['security_id']!, _securityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_securityIdMeta);
    }
    if (data.containsKey('trade_type')) {
      context.handle(
        _tradeTypeMeta,
        tradeType.isAcceptableOrUnknown(data['trade_type']!, _tradeTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_tradeTypeMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('price_cents')) {
      context.handle(
        _priceCentsMeta,
        priceCents.isAcceptableOrUnknown(data['price_cents']!, _priceCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_priceCentsMeta);
    }
    if (data.containsKey('amount_cents')) {
      context.handle(
        _amountCentsMeta,
        amountCents.isAcceptableOrUnknown(
          data['amount_cents']!,
          _amountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountCentsMeta);
    }
    if (data.containsKey('fee_cents')) {
      context.handle(
        _feeCentsMeta,
        feeCents.isAcceptableOrUnknown(data['fee_cents']!, _feeCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_feeCentsMeta);
    }
    if (data.containsKey('realized_pnl_cents')) {
      context.handle(
        _realizedPnlCentsMeta,
        realizedPnlCents.isAcceptableOrUnknown(
          data['realized_pnl_cents']!,
          _realizedPnlCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_realizedPnlCentsMeta);
    }
    if (data.containsKey('trade_date')) {
      context.handle(
        _tradeDateMeta,
        tradeDate.isAcceptableOrUnknown(data['trade_date']!, _tradeDateMeta),
      );
    } else if (isInserting) {
      context.missing(_tradeDateMeta);
    }
    if (data.containsKey('transaction_id')) {
      context.handle(
        _transactionIdMeta,
        transactionId.isAcceptableOrUnknown(
          data['transaction_id']!,
          _transactionIdMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    } else if (isInserting) {
      context.missing(_notesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HoldingTransaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HoldingTransaction(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      securityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}security_id'],
      )!,
      tradeType: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}trade_type'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      priceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_cents'],
      )!,
      amountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_cents'],
      )!,
      feeCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fee_cents'],
      )!,
      realizedPnlCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}realized_pnl_cents'],
      )!,
      tradeDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}trade_date'],
      )!,
      transactionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}transaction_id'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HoldingTransactionsTable createAlias(String alias) {
    return $HoldingTransactionsTable(attachedDatabase, alias);
  }
}

class HoldingTransaction extends DataClass
    implements Insertable<HoldingTransaction> {
  final String id;
  final String accountId;
  final String securityId;
  final int tradeType;
  final double quantity;
  final int priceCents;
  final int amountCents;
  final int feeCents;
  final int realizedPnlCents;
  final DateTime tradeDate;
  final String? transactionId;
  final String notes;
  final DateTime createdAt;
  const HoldingTransaction({
    required this.id,
    required this.accountId,
    required this.securityId,
    required this.tradeType,
    required this.quantity,
    required this.priceCents,
    required this.amountCents,
    required this.feeCents,
    required this.realizedPnlCents,
    required this.tradeDate,
    this.transactionId,
    required this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['account_id'] = Variable<String>(accountId);
    map['security_id'] = Variable<String>(securityId);
    map['trade_type'] = Variable<int>(tradeType);
    map['quantity'] = Variable<double>(quantity);
    map['price_cents'] = Variable<int>(priceCents);
    map['amount_cents'] = Variable<int>(amountCents);
    map['fee_cents'] = Variable<int>(feeCents);
    map['realized_pnl_cents'] = Variable<int>(realizedPnlCents);
    map['trade_date'] = Variable<DateTime>(tradeDate);
    if (!nullToAbsent || transactionId != null) {
      map['transaction_id'] = Variable<String>(transactionId);
    }
    map['notes'] = Variable<String>(notes);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HoldingTransactionsCompanion toCompanion(bool nullToAbsent) {
    return HoldingTransactionsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      securityId: Value(securityId),
      tradeType: Value(tradeType),
      quantity: Value(quantity),
      priceCents: Value(priceCents),
      amountCents: Value(amountCents),
      feeCents: Value(feeCents),
      realizedPnlCents: Value(realizedPnlCents),
      tradeDate: Value(tradeDate),
      transactionId: transactionId == null && nullToAbsent
          ? const Value.absent()
          : Value(transactionId),
      notes: Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory HoldingTransaction.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HoldingTransaction(
      id: serializer.fromJson<String>(json['id']),
      accountId: serializer.fromJson<String>(json['accountId']),
      securityId: serializer.fromJson<String>(json['securityId']),
      tradeType: serializer.fromJson<int>(json['tradeType']),
      quantity: serializer.fromJson<double>(json['quantity']),
      priceCents: serializer.fromJson<int>(json['priceCents']),
      amountCents: serializer.fromJson<int>(json['amountCents']),
      feeCents: serializer.fromJson<int>(json['feeCents']),
      realizedPnlCents: serializer.fromJson<int>(json['realizedPnlCents']),
      tradeDate: serializer.fromJson<DateTime>(json['tradeDate']),
      transactionId: serializer.fromJson<String?>(json['transactionId']),
      notes: serializer.fromJson<String>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'accountId': serializer.toJson<String>(accountId),
      'securityId': serializer.toJson<String>(securityId),
      'tradeType': serializer.toJson<int>(tradeType),
      'quantity': serializer.toJson<double>(quantity),
      'priceCents': serializer.toJson<int>(priceCents),
      'amountCents': serializer.toJson<int>(amountCents),
      'feeCents': serializer.toJson<int>(feeCents),
      'realizedPnlCents': serializer.toJson<int>(realizedPnlCents),
      'tradeDate': serializer.toJson<DateTime>(tradeDate),
      'transactionId': serializer.toJson<String?>(transactionId),
      'notes': serializer.toJson<String>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HoldingTransaction copyWith({
    String? id,
    String? accountId,
    String? securityId,
    int? tradeType,
    double? quantity,
    int? priceCents,
    int? amountCents,
    int? feeCents,
    int? realizedPnlCents,
    DateTime? tradeDate,
    Value<String?> transactionId = const Value.absent(),
    String? notes,
    DateTime? createdAt,
  }) => HoldingTransaction(
    id: id ?? this.id,
    accountId: accountId ?? this.accountId,
    securityId: securityId ?? this.securityId,
    tradeType: tradeType ?? this.tradeType,
    quantity: quantity ?? this.quantity,
    priceCents: priceCents ?? this.priceCents,
    amountCents: amountCents ?? this.amountCents,
    feeCents: feeCents ?? this.feeCents,
    realizedPnlCents: realizedPnlCents ?? this.realizedPnlCents,
    tradeDate: tradeDate ?? this.tradeDate,
    transactionId: transactionId.present
        ? transactionId.value
        : this.transactionId,
    notes: notes ?? this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  HoldingTransaction copyWithCompanion(HoldingTransactionsCompanion data) {
    return HoldingTransaction(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      securityId: data.securityId.present
          ? data.securityId.value
          : this.securityId,
      tradeType: data.tradeType.present ? data.tradeType.value : this.tradeType,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      priceCents: data.priceCents.present
          ? data.priceCents.value
          : this.priceCents,
      amountCents: data.amountCents.present
          ? data.amountCents.value
          : this.amountCents,
      feeCents: data.feeCents.present ? data.feeCents.value : this.feeCents,
      realizedPnlCents: data.realizedPnlCents.present
          ? data.realizedPnlCents.value
          : this.realizedPnlCents,
      tradeDate: data.tradeDate.present ? data.tradeDate.value : this.tradeDate,
      transactionId: data.transactionId.present
          ? data.transactionId.value
          : this.transactionId,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HoldingTransaction(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('securityId: $securityId, ')
          ..write('tradeType: $tradeType, ')
          ..write('quantity: $quantity, ')
          ..write('priceCents: $priceCents, ')
          ..write('amountCents: $amountCents, ')
          ..write('feeCents: $feeCents, ')
          ..write('realizedPnlCents: $realizedPnlCents, ')
          ..write('tradeDate: $tradeDate, ')
          ..write('transactionId: $transactionId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    accountId,
    securityId,
    tradeType,
    quantity,
    priceCents,
    amountCents,
    feeCents,
    realizedPnlCents,
    tradeDate,
    transactionId,
    notes,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HoldingTransaction &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.securityId == this.securityId &&
          other.tradeType == this.tradeType &&
          other.quantity == this.quantity &&
          other.priceCents == this.priceCents &&
          other.amountCents == this.amountCents &&
          other.feeCents == this.feeCents &&
          other.realizedPnlCents == this.realizedPnlCents &&
          other.tradeDate == this.tradeDate &&
          other.transactionId == this.transactionId &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class HoldingTransactionsCompanion extends UpdateCompanion<HoldingTransaction> {
  final Value<String> id;
  final Value<String> accountId;
  final Value<String> securityId;
  final Value<int> tradeType;
  final Value<double> quantity;
  final Value<int> priceCents;
  final Value<int> amountCents;
  final Value<int> feeCents;
  final Value<int> realizedPnlCents;
  final Value<DateTime> tradeDate;
  final Value<String?> transactionId;
  final Value<String> notes;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const HoldingTransactionsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.securityId = const Value.absent(),
    this.tradeType = const Value.absent(),
    this.quantity = const Value.absent(),
    this.priceCents = const Value.absent(),
    this.amountCents = const Value.absent(),
    this.feeCents = const Value.absent(),
    this.realizedPnlCents = const Value.absent(),
    this.tradeDate = const Value.absent(),
    this.transactionId = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HoldingTransactionsCompanion.insert({
    required String id,
    required String accountId,
    required String securityId,
    required int tradeType,
    required double quantity,
    required int priceCents,
    required int amountCents,
    required int feeCents,
    required int realizedPnlCents,
    required DateTime tradeDate,
    this.transactionId = const Value.absent(),
    required String notes,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       accountId = Value(accountId),
       securityId = Value(securityId),
       tradeType = Value(tradeType),
       quantity = Value(quantity),
       priceCents = Value(priceCents),
       amountCents = Value(amountCents),
       feeCents = Value(feeCents),
       realizedPnlCents = Value(realizedPnlCents),
       tradeDate = Value(tradeDate),
       notes = Value(notes),
       createdAt = Value(createdAt);
  static Insertable<HoldingTransaction> custom({
    Expression<String>? id,
    Expression<String>? accountId,
    Expression<String>? securityId,
    Expression<int>? tradeType,
    Expression<double>? quantity,
    Expression<int>? priceCents,
    Expression<int>? amountCents,
    Expression<int>? feeCents,
    Expression<int>? realizedPnlCents,
    Expression<DateTime>? tradeDate,
    Expression<String>? transactionId,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (securityId != null) 'security_id': securityId,
      if (tradeType != null) 'trade_type': tradeType,
      if (quantity != null) 'quantity': quantity,
      if (priceCents != null) 'price_cents': priceCents,
      if (amountCents != null) 'amount_cents': amountCents,
      if (feeCents != null) 'fee_cents': feeCents,
      if (realizedPnlCents != null) 'realized_pnl_cents': realizedPnlCents,
      if (tradeDate != null) 'trade_date': tradeDate,
      if (transactionId != null) 'transaction_id': transactionId,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HoldingTransactionsCompanion copyWith({
    Value<String>? id,
    Value<String>? accountId,
    Value<String>? securityId,
    Value<int>? tradeType,
    Value<double>? quantity,
    Value<int>? priceCents,
    Value<int>? amountCents,
    Value<int>? feeCents,
    Value<int>? realizedPnlCents,
    Value<DateTime>? tradeDate,
    Value<String?>? transactionId,
    Value<String>? notes,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return HoldingTransactionsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      securityId: securityId ?? this.securityId,
      tradeType: tradeType ?? this.tradeType,
      quantity: quantity ?? this.quantity,
      priceCents: priceCents ?? this.priceCents,
      amountCents: amountCents ?? this.amountCents,
      feeCents: feeCents ?? this.feeCents,
      realizedPnlCents: realizedPnlCents ?? this.realizedPnlCents,
      tradeDate: tradeDate ?? this.tradeDate,
      transactionId: transactionId ?? this.transactionId,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (securityId.present) {
      map['security_id'] = Variable<String>(securityId.value);
    }
    if (tradeType.present) {
      map['trade_type'] = Variable<int>(tradeType.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (priceCents.present) {
      map['price_cents'] = Variable<int>(priceCents.value);
    }
    if (amountCents.present) {
      map['amount_cents'] = Variable<int>(amountCents.value);
    }
    if (feeCents.present) {
      map['fee_cents'] = Variable<int>(feeCents.value);
    }
    if (realizedPnlCents.present) {
      map['realized_pnl_cents'] = Variable<int>(realizedPnlCents.value);
    }
    if (tradeDate.present) {
      map['trade_date'] = Variable<DateTime>(tradeDate.value);
    }
    if (transactionId.present) {
      map['transaction_id'] = Variable<String>(transactionId.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoldingTransactionsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('securityId: $securityId, ')
          ..write('tradeType: $tradeType, ')
          ..write('quantity: $quantity, ')
          ..write('priceCents: $priceCents, ')
          ..write('amountCents: $amountCents, ')
          ..write('feeCents: $feeCents, ')
          ..write('realizedPnlCents: $realizedPnlCents, ')
          ..write('tradeDate: $tradeDate, ')
          ..write('transactionId: $transactionId, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CurrenciesTable extends Currencies
    with TableInfo<$CurrenciesTable, Currency> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CurrenciesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _codeMeta = const VerificationMeta('code');
  @override
  late final GeneratedColumn<String> code = GeneratedColumn<String>(
    'code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exchangeRateMeta = const VerificationMeta(
    'exchangeRate',
  );
  @override
  late final GeneratedColumn<double> exchangeRate = GeneratedColumn<double>(
    'exchange_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    code,
    name,
    symbol,
    exchangeRate,
    isActive,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'currencies';
  @override
  VerificationContext validateIntegrity(
    Insertable<Currency> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('code')) {
      context.handle(
        _codeMeta,
        code.isAcceptableOrUnknown(data['code']!, _codeMeta),
      );
    } else if (isInserting) {
      context.missing(_codeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('exchange_rate')) {
      context.handle(
        _exchangeRateMeta,
        exchangeRate.isAcceptableOrUnknown(
          data['exchange_rate']!,
          _exchangeRateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exchangeRateMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    } else if (isInserting) {
      context.missing(_isActiveMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {code};
  @override
  Currency map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Currency(
      code: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      exchangeRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}exchange_rate'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
    );
  }

  @override
  $CurrenciesTable createAlias(String alias) {
    return $CurrenciesTable(attachedDatabase, alias);
  }
}

class Currency extends DataClass implements Insertable<Currency> {
  final String code;
  final String name;
  final String symbol;
  final double exchangeRate;
  final bool isActive;
  const Currency({
    required this.code,
    required this.name,
    required this.symbol,
    required this.exchangeRate,
    required this.isActive,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['code'] = Variable<String>(code);
    map['name'] = Variable<String>(name);
    map['symbol'] = Variable<String>(symbol);
    map['exchange_rate'] = Variable<double>(exchangeRate);
    map['is_active'] = Variable<bool>(isActive);
    return map;
  }

  CurrenciesCompanion toCompanion(bool nullToAbsent) {
    return CurrenciesCompanion(
      code: Value(code),
      name: Value(name),
      symbol: Value(symbol),
      exchangeRate: Value(exchangeRate),
      isActive: Value(isActive),
    );
  }

  factory Currency.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Currency(
      code: serializer.fromJson<String>(json['code']),
      name: serializer.fromJson<String>(json['name']),
      symbol: serializer.fromJson<String>(json['symbol']),
      exchangeRate: serializer.fromJson<double>(json['exchangeRate']),
      isActive: serializer.fromJson<bool>(json['isActive']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'code': serializer.toJson<String>(code),
      'name': serializer.toJson<String>(name),
      'symbol': serializer.toJson<String>(symbol),
      'exchangeRate': serializer.toJson<double>(exchangeRate),
      'isActive': serializer.toJson<bool>(isActive),
    };
  }

  Currency copyWith({
    String? code,
    String? name,
    String? symbol,
    double? exchangeRate,
    bool? isActive,
  }) => Currency(
    code: code ?? this.code,
    name: name ?? this.name,
    symbol: symbol ?? this.symbol,
    exchangeRate: exchangeRate ?? this.exchangeRate,
    isActive: isActive ?? this.isActive,
  );
  Currency copyWithCompanion(CurrenciesCompanion data) {
    return Currency(
      code: data.code.present ? data.code.value : this.code,
      name: data.name.present ? data.name.value : this.name,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      exchangeRate: data.exchangeRate.present
          ? data.exchangeRate.value
          : this.exchangeRate,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Currency(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('symbol: $symbol, ')
          ..write('exchangeRate: $exchangeRate, ')
          ..write('isActive: $isActive')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(code, name, symbol, exchangeRate, isActive);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Currency &&
          other.code == this.code &&
          other.name == this.name &&
          other.symbol == this.symbol &&
          other.exchangeRate == this.exchangeRate &&
          other.isActive == this.isActive);
}

class CurrenciesCompanion extends UpdateCompanion<Currency> {
  final Value<String> code;
  final Value<String> name;
  final Value<String> symbol;
  final Value<double> exchangeRate;
  final Value<bool> isActive;
  final Value<int> rowid;
  const CurrenciesCompanion({
    this.code = const Value.absent(),
    this.name = const Value.absent(),
    this.symbol = const Value.absent(),
    this.exchangeRate = const Value.absent(),
    this.isActive = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CurrenciesCompanion.insert({
    required String code,
    required String name,
    required String symbol,
    required double exchangeRate,
    required bool isActive,
    this.rowid = const Value.absent(),
  }) : code = Value(code),
       name = Value(name),
       symbol = Value(symbol),
       exchangeRate = Value(exchangeRate),
       isActive = Value(isActive);
  static Insertable<Currency> custom({
    Expression<String>? code,
    Expression<String>? name,
    Expression<String>? symbol,
    Expression<double>? exchangeRate,
    Expression<bool>? isActive,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (code != null) 'code': code,
      if (name != null) 'name': name,
      if (symbol != null) 'symbol': symbol,
      if (exchangeRate != null) 'exchange_rate': exchangeRate,
      if (isActive != null) 'is_active': isActive,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CurrenciesCompanion copyWith({
    Value<String>? code,
    Value<String>? name,
    Value<String>? symbol,
    Value<double>? exchangeRate,
    Value<bool>? isActive,
    Value<int>? rowid,
  }) {
    return CurrenciesCompanion(
      code: code ?? this.code,
      name: name ?? this.name,
      symbol: symbol ?? this.symbol,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      isActive: isActive ?? this.isActive,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (code.present) {
      map['code'] = Variable<String>(code.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (exchangeRate.present) {
      map['exchange_rate'] = Variable<double>(exchangeRate.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CurrenciesCompanion(')
          ..write('code: $code, ')
          ..write('name: $name, ')
          ..write('symbol: $symbol, ')
          ..write('exchangeRate: $exchangeRate, ')
          ..write('isActive: $isActive, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RateHistoriesTable extends RateHistories
    with TableInfo<$RateHistoriesTable, RateHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RateHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rateDateMeta = const VerificationMeta(
    'rateDate',
  );
  @override
  late final GeneratedColumn<DateTime> rateDate = GeneratedColumn<DateTime>(
    'rate_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exchangeRateMeta = const VerificationMeta(
    'exchangeRate',
  );
  @override
  late final GeneratedColumn<double> exchangeRate = GeneratedColumn<double>(
    'exchange_rate',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    currencyCode,
    rateDate,
    exchangeRate,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rate_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<RateHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('rate_date')) {
      context.handle(
        _rateDateMeta,
        rateDate.isAcceptableOrUnknown(data['rate_date']!, _rateDateMeta),
      );
    } else if (isInserting) {
      context.missing(_rateDateMeta);
    }
    if (data.containsKey('exchange_rate')) {
      context.handle(
        _exchangeRateMeta,
        exchangeRate.isAcceptableOrUnknown(
          data['exchange_rate']!,
          _exchangeRateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_exchangeRateMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RateHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RateHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      rateDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}rate_date'],
      )!,
      exchangeRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}exchange_rate'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $RateHistoriesTable createAlias(String alias) {
    return $RateHistoriesTable(attachedDatabase, alias);
  }
}

class RateHistory extends DataClass implements Insertable<RateHistory> {
  final String id;
  final String currencyCode;
  final DateTime rateDate;
  final double exchangeRate;
  final DateTime createdAt;
  const RateHistory({
    required this.id,
    required this.currencyCode,
    required this.rateDate,
    required this.exchangeRate,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['currency_code'] = Variable<String>(currencyCode);
    map['rate_date'] = Variable<DateTime>(rateDate);
    map['exchange_rate'] = Variable<double>(exchangeRate);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  RateHistoriesCompanion toCompanion(bool nullToAbsent) {
    return RateHistoriesCompanion(
      id: Value(id),
      currencyCode: Value(currencyCode),
      rateDate: Value(rateDate),
      exchangeRate: Value(exchangeRate),
      createdAt: Value(createdAt),
    );
  }

  factory RateHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RateHistory(
      id: serializer.fromJson<String>(json['id']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      rateDate: serializer.fromJson<DateTime>(json['rateDate']),
      exchangeRate: serializer.fromJson<double>(json['exchangeRate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'rateDate': serializer.toJson<DateTime>(rateDate),
      'exchangeRate': serializer.toJson<double>(exchangeRate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  RateHistory copyWith({
    String? id,
    String? currencyCode,
    DateTime? rateDate,
    double? exchangeRate,
    DateTime? createdAt,
  }) => RateHistory(
    id: id ?? this.id,
    currencyCode: currencyCode ?? this.currencyCode,
    rateDate: rateDate ?? this.rateDate,
    exchangeRate: exchangeRate ?? this.exchangeRate,
    createdAt: createdAt ?? this.createdAt,
  );
  RateHistory copyWithCompanion(RateHistoriesCompanion data) {
    return RateHistory(
      id: data.id.present ? data.id.value : this.id,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      rateDate: data.rateDate.present ? data.rateDate.value : this.rateDate,
      exchangeRate: data.exchangeRate.present
          ? data.exchangeRate.value
          : this.exchangeRate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RateHistory(')
          ..write('id: $id, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('rateDate: $rateDate, ')
          ..write('exchangeRate: $exchangeRate, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, currencyCode, rateDate, exchangeRate, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RateHistory &&
          other.id == this.id &&
          other.currencyCode == this.currencyCode &&
          other.rateDate == this.rateDate &&
          other.exchangeRate == this.exchangeRate &&
          other.createdAt == this.createdAt);
}

class RateHistoriesCompanion extends UpdateCompanion<RateHistory> {
  final Value<String> id;
  final Value<String> currencyCode;
  final Value<DateTime> rateDate;
  final Value<double> exchangeRate;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const RateHistoriesCompanion({
    this.id = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.rateDate = const Value.absent(),
    this.exchangeRate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RateHistoriesCompanion.insert({
    required String id,
    required String currencyCode,
    required DateTime rateDate,
    required double exchangeRate,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       currencyCode = Value(currencyCode),
       rateDate = Value(rateDate),
       exchangeRate = Value(exchangeRate),
       createdAt = Value(createdAt);
  static Insertable<RateHistory> custom({
    Expression<String>? id,
    Expression<String>? currencyCode,
    Expression<DateTime>? rateDate,
    Expression<double>? exchangeRate,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (rateDate != null) 'rate_date': rateDate,
      if (exchangeRate != null) 'exchange_rate': exchangeRate,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RateHistoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? currencyCode,
    Value<DateTime>? rateDate,
    Value<double>? exchangeRate,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return RateHistoriesCompanion(
      id: id ?? this.id,
      currencyCode: currencyCode ?? this.currencyCode,
      rateDate: rateDate ?? this.rateDate,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (rateDate.present) {
      map['rate_date'] = Variable<DateTime>(rateDate.value);
    }
    if (exchangeRate.present) {
      map['exchange_rate'] = Variable<double>(exchangeRate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RateHistoriesCompanion(')
          ..write('id: $id, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('rateDate: $rateDate, ')
          ..write('exchangeRate: $exchangeRate, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SecuritiesTable extends Securities
    with TableInfo<$SecuritiesTable, Security> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SecuritiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _symbolMeta = const VerificationMeta('symbol');
  @override
  late final GeneratedColumn<String> symbol = GeneratedColumn<String>(
    'symbol',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _securityTypeMeta = const VerificationMeta(
    'securityType',
  );
  @override
  late final GeneratedColumn<String> securityType = GeneratedColumn<String>(
    'security_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exchangeMeta = const VerificationMeta(
    'exchange',
  );
  @override
  late final GeneratedColumn<String> exchange = GeneratedColumn<String>(
    'exchange',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentPriceCentsMeta = const VerificationMeta(
    'currentPriceCents',
  );
  @override
  late final GeneratedColumn<int> currentPriceCents = GeneratedColumn<int>(
    'current_price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    symbol,
    name,
    securityType,
    exchange,
    currencyCode,
    currentPriceCents,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'securities';
  @override
  VerificationContext validateIntegrity(
    Insertable<Security> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('symbol')) {
      context.handle(
        _symbolMeta,
        symbol.isAcceptableOrUnknown(data['symbol']!, _symbolMeta),
      );
    } else if (isInserting) {
      context.missing(_symbolMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('security_type')) {
      context.handle(
        _securityTypeMeta,
        securityType.isAcceptableOrUnknown(
          data['security_type']!,
          _securityTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_securityTypeMeta);
    }
    if (data.containsKey('exchange')) {
      context.handle(
        _exchangeMeta,
        exchange.isAcceptableOrUnknown(data['exchange']!, _exchangeMeta),
      );
    } else if (isInserting) {
      context.missing(_exchangeMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('current_price_cents')) {
      context.handle(
        _currentPriceCentsMeta,
        currentPriceCents.isAcceptableOrUnknown(
          data['current_price_cents']!,
          _currentPriceCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentPriceCentsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Security map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Security(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      symbol: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symbol'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      securityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}security_type'],
      )!,
      exchange: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exchange'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      currentPriceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_price_cents'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SecuritiesTable createAlias(String alias) {
    return $SecuritiesTable(attachedDatabase, alias);
  }
}

class Security extends DataClass implements Insertable<Security> {
  final String id;
  final String symbol;
  final String name;
  final String securityType;
  final String exchange;
  final String currencyCode;
  final int currentPriceCents;
  final DateTime createdAt;
  const Security({
    required this.id,
    required this.symbol,
    required this.name,
    required this.securityType,
    required this.exchange,
    required this.currencyCode,
    required this.currentPriceCents,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['symbol'] = Variable<String>(symbol);
    map['name'] = Variable<String>(name);
    map['security_type'] = Variable<String>(securityType);
    map['exchange'] = Variable<String>(exchange);
    map['currency_code'] = Variable<String>(currencyCode);
    map['current_price_cents'] = Variable<int>(currentPriceCents);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SecuritiesCompanion toCompanion(bool nullToAbsent) {
    return SecuritiesCompanion(
      id: Value(id),
      symbol: Value(symbol),
      name: Value(name),
      securityType: Value(securityType),
      exchange: Value(exchange),
      currencyCode: Value(currencyCode),
      currentPriceCents: Value(currentPriceCents),
      createdAt: Value(createdAt),
    );
  }

  factory Security.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Security(
      id: serializer.fromJson<String>(json['id']),
      symbol: serializer.fromJson<String>(json['symbol']),
      name: serializer.fromJson<String>(json['name']),
      securityType: serializer.fromJson<String>(json['securityType']),
      exchange: serializer.fromJson<String>(json['exchange']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      currentPriceCents: serializer.fromJson<int>(json['currentPriceCents']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'symbol': serializer.toJson<String>(symbol),
      'name': serializer.toJson<String>(name),
      'securityType': serializer.toJson<String>(securityType),
      'exchange': serializer.toJson<String>(exchange),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'currentPriceCents': serializer.toJson<int>(currentPriceCents),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Security copyWith({
    String? id,
    String? symbol,
    String? name,
    String? securityType,
    String? exchange,
    String? currencyCode,
    int? currentPriceCents,
    DateTime? createdAt,
  }) => Security(
    id: id ?? this.id,
    symbol: symbol ?? this.symbol,
    name: name ?? this.name,
    securityType: securityType ?? this.securityType,
    exchange: exchange ?? this.exchange,
    currencyCode: currencyCode ?? this.currencyCode,
    currentPriceCents: currentPriceCents ?? this.currentPriceCents,
    createdAt: createdAt ?? this.createdAt,
  );
  Security copyWithCompanion(SecuritiesCompanion data) {
    return Security(
      id: data.id.present ? data.id.value : this.id,
      symbol: data.symbol.present ? data.symbol.value : this.symbol,
      name: data.name.present ? data.name.value : this.name,
      securityType: data.securityType.present
          ? data.securityType.value
          : this.securityType,
      exchange: data.exchange.present ? data.exchange.value : this.exchange,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      currentPriceCents: data.currentPriceCents.present
          ? data.currentPriceCents.value
          : this.currentPriceCents,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Security(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('securityType: $securityType, ')
          ..write('exchange: $exchange, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('currentPriceCents: $currentPriceCents, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    symbol,
    name,
    securityType,
    exchange,
    currencyCode,
    currentPriceCents,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Security &&
          other.id == this.id &&
          other.symbol == this.symbol &&
          other.name == this.name &&
          other.securityType == this.securityType &&
          other.exchange == this.exchange &&
          other.currencyCode == this.currencyCode &&
          other.currentPriceCents == this.currentPriceCents &&
          other.createdAt == this.createdAt);
}

class SecuritiesCompanion extends UpdateCompanion<Security> {
  final Value<String> id;
  final Value<String> symbol;
  final Value<String> name;
  final Value<String> securityType;
  final Value<String> exchange;
  final Value<String> currencyCode;
  final Value<int> currentPriceCents;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SecuritiesCompanion({
    this.id = const Value.absent(),
    this.symbol = const Value.absent(),
    this.name = const Value.absent(),
    this.securityType = const Value.absent(),
    this.exchange = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.currentPriceCents = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SecuritiesCompanion.insert({
    required String id,
    required String symbol,
    required String name,
    required String securityType,
    required String exchange,
    required String currencyCode,
    required int currentPriceCents,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       symbol = Value(symbol),
       name = Value(name),
       securityType = Value(securityType),
       exchange = Value(exchange),
       currencyCode = Value(currencyCode),
       currentPriceCents = Value(currentPriceCents),
       createdAt = Value(createdAt);
  static Insertable<Security> custom({
    Expression<String>? id,
    Expression<String>? symbol,
    Expression<String>? name,
    Expression<String>? securityType,
    Expression<String>? exchange,
    Expression<String>? currencyCode,
    Expression<int>? currentPriceCents,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (symbol != null) 'symbol': symbol,
      if (name != null) 'name': name,
      if (securityType != null) 'security_type': securityType,
      if (exchange != null) 'exchange': exchange,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (currentPriceCents != null) 'current_price_cents': currentPriceCents,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SecuritiesCompanion copyWith({
    Value<String>? id,
    Value<String>? symbol,
    Value<String>? name,
    Value<String>? securityType,
    Value<String>? exchange,
    Value<String>? currencyCode,
    Value<int>? currentPriceCents,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SecuritiesCompanion(
      id: id ?? this.id,
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      securityType: securityType ?? this.securityType,
      exchange: exchange ?? this.exchange,
      currencyCode: currencyCode ?? this.currencyCode,
      currentPriceCents: currentPriceCents ?? this.currentPriceCents,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (symbol.present) {
      map['symbol'] = Variable<String>(symbol.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (securityType.present) {
      map['security_type'] = Variable<String>(securityType.value);
    }
    if (exchange.present) {
      map['exchange'] = Variable<String>(exchange.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (currentPriceCents.present) {
      map['current_price_cents'] = Variable<int>(currentPriceCents.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SecuritiesCompanion(')
          ..write('id: $id, ')
          ..write('symbol: $symbol, ')
          ..write('name: $name, ')
          ..write('securityType: $securityType, ')
          ..write('exchange: $exchange, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('currentPriceCents: $currentPriceCents, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SecurityPriceHistoriesTable extends SecurityPriceHistories
    with TableInfo<$SecurityPriceHistoriesTable, SecurityPriceHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SecurityPriceHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _securityIdMeta = const VerificationMeta(
    'securityId',
  );
  @override
  late final GeneratedColumn<String> securityId = GeneratedColumn<String>(
    'security_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceDateMeta = const VerificationMeta(
    'priceDate',
  );
  @override
  late final GeneratedColumn<DateTime> priceDate = GeneratedColumn<DateTime>(
    'price_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceCentsMeta = const VerificationMeta(
    'priceCents',
  );
  @override
  late final GeneratedColumn<int> priceCents = GeneratedColumn<int>(
    'price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    securityId,
    priceDate,
    priceCents,
    currencyCode,
    source,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'security_price_histories';
  @override
  VerificationContext validateIntegrity(
    Insertable<SecurityPriceHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('security_id')) {
      context.handle(
        _securityIdMeta,
        securityId.isAcceptableOrUnknown(data['security_id']!, _securityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_securityIdMeta);
    }
    if (data.containsKey('price_date')) {
      context.handle(
        _priceDateMeta,
        priceDate.isAcceptableOrUnknown(data['price_date']!, _priceDateMeta),
      );
    } else if (isInserting) {
      context.missing(_priceDateMeta);
    }
    if (data.containsKey('price_cents')) {
      context.handle(
        _priceCentsMeta,
        priceCents.isAcceptableOrUnknown(data['price_cents']!, _priceCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_priceCentsMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SecurityPriceHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SecurityPriceHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      securityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}security_id'],
      )!,
      priceDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}price_date'],
      )!,
      priceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_cents'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SecurityPriceHistoriesTable createAlias(String alias) {
    return $SecurityPriceHistoriesTable(attachedDatabase, alias);
  }
}

class SecurityPriceHistory extends DataClass
    implements Insertable<SecurityPriceHistory> {
  final String id;
  final String securityId;
  final DateTime priceDate;
  final int priceCents;
  final String currencyCode;
  final String source;
  final DateTime createdAt;
  const SecurityPriceHistory({
    required this.id,
    required this.securityId,
    required this.priceDate,
    required this.priceCents,
    required this.currencyCode,
    required this.source,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['security_id'] = Variable<String>(securityId);
    map['price_date'] = Variable<DateTime>(priceDate);
    map['price_cents'] = Variable<int>(priceCents);
    map['currency_code'] = Variable<String>(currencyCode);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SecurityPriceHistoriesCompanion toCompanion(bool nullToAbsent) {
    return SecurityPriceHistoriesCompanion(
      id: Value(id),
      securityId: Value(securityId),
      priceDate: Value(priceDate),
      priceCents: Value(priceCents),
      currencyCode: Value(currencyCode),
      source: Value(source),
      createdAt: Value(createdAt),
    );
  }

  factory SecurityPriceHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SecurityPriceHistory(
      id: serializer.fromJson<String>(json['id']),
      securityId: serializer.fromJson<String>(json['securityId']),
      priceDate: serializer.fromJson<DateTime>(json['priceDate']),
      priceCents: serializer.fromJson<int>(json['priceCents']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'securityId': serializer.toJson<String>(securityId),
      'priceDate': serializer.toJson<DateTime>(priceDate),
      'priceCents': serializer.toJson<int>(priceCents),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SecurityPriceHistory copyWith({
    String? id,
    String? securityId,
    DateTime? priceDate,
    int? priceCents,
    String? currencyCode,
    String? source,
    DateTime? createdAt,
  }) => SecurityPriceHistory(
    id: id ?? this.id,
    securityId: securityId ?? this.securityId,
    priceDate: priceDate ?? this.priceDate,
    priceCents: priceCents ?? this.priceCents,
    currencyCode: currencyCode ?? this.currencyCode,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
  );
  SecurityPriceHistory copyWithCompanion(SecurityPriceHistoriesCompanion data) {
    return SecurityPriceHistory(
      id: data.id.present ? data.id.value : this.id,
      securityId: data.securityId.present
          ? data.securityId.value
          : this.securityId,
      priceDate: data.priceDate.present ? data.priceDate.value : this.priceDate,
      priceCents: data.priceCents.present
          ? data.priceCents.value
          : this.priceCents,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SecurityPriceHistory(')
          ..write('id: $id, ')
          ..write('securityId: $securityId, ')
          ..write('priceDate: $priceDate, ')
          ..write('priceCents: $priceCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    securityId,
    priceDate,
    priceCents,
    currencyCode,
    source,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SecurityPriceHistory &&
          other.id == this.id &&
          other.securityId == this.securityId &&
          other.priceDate == this.priceDate &&
          other.priceCents == this.priceCents &&
          other.currencyCode == this.currencyCode &&
          other.source == this.source &&
          other.createdAt == this.createdAt);
}

class SecurityPriceHistoriesCompanion
    extends UpdateCompanion<SecurityPriceHistory> {
  final Value<String> id;
  final Value<String> securityId;
  final Value<DateTime> priceDate;
  final Value<int> priceCents;
  final Value<String> currencyCode;
  final Value<String> source;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const SecurityPriceHistoriesCompanion({
    this.id = const Value.absent(),
    this.securityId = const Value.absent(),
    this.priceDate = const Value.absent(),
    this.priceCents = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SecurityPriceHistoriesCompanion.insert({
    required String id,
    required String securityId,
    required DateTime priceDate,
    required int priceCents,
    required String currencyCode,
    required String source,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       securityId = Value(securityId),
       priceDate = Value(priceDate),
       priceCents = Value(priceCents),
       currencyCode = Value(currencyCode),
       source = Value(source),
       createdAt = Value(createdAt);
  static Insertable<SecurityPriceHistory> custom({
    Expression<String>? id,
    Expression<String>? securityId,
    Expression<DateTime>? priceDate,
    Expression<int>? priceCents,
    Expression<String>? currencyCode,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (securityId != null) 'security_id': securityId,
      if (priceDate != null) 'price_date': priceDate,
      if (priceCents != null) 'price_cents': priceCents,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SecurityPriceHistoriesCompanion copyWith({
    Value<String>? id,
    Value<String>? securityId,
    Value<DateTime>? priceDate,
    Value<int>? priceCents,
    Value<String>? currencyCode,
    Value<String>? source,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return SecurityPriceHistoriesCompanion(
      id: id ?? this.id,
      securityId: securityId ?? this.securityId,
      priceDate: priceDate ?? this.priceDate,
      priceCents: priceCents ?? this.priceCents,
      currencyCode: currencyCode ?? this.currencyCode,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (securityId.present) {
      map['security_id'] = Variable<String>(securityId.value);
    }
    if (priceDate.present) {
      map['price_date'] = Variable<DateTime>(priceDate.value);
    }
    if (priceCents.present) {
      map['price_cents'] = Variable<int>(priceCents.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SecurityPriceHistoriesCompanion(')
          ..write('id: $id, ')
          ..write('securityId: $securityId, ')
          ..write('priceDate: $priceDate, ')
          ..write('priceCents: $priceCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DebtProgressSnapshotsTable extends DebtProgressSnapshots
    with TableInfo<$DebtProgressSnapshotsTable, DebtProgressSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DebtProgressSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _debtIdMeta = const VerificationMeta('debtId');
  @override
  late final GeneratedColumn<String> debtId = GeneratedColumn<String>(
    'debt_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snapshotDateMeta = const VerificationMeta(
    'snapshotDate',
  );
  @override
  late final GeneratedColumn<DateTime> snapshotDate = GeneratedColumn<DateTime>(
    'snapshot_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalPrincipalCentsMeta =
      const VerificationMeta('totalPrincipalCents');
  @override
  late final GeneratedColumn<int> totalPrincipalCents = GeneratedColumn<int>(
    'total_principal_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingPrincipalCentsMeta =
      const VerificationMeta('remainingPrincipalCents');
  @override
  late final GeneratedColumn<int> remainingPrincipalCents =
      GeneratedColumn<int>(
        'remaining_principal_cents',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _paidTotalCentsMeta = const VerificationMeta(
    'paidTotalCents',
  );
  @override
  late final GeneratedColumn<int> paidTotalCents = GeneratedColumn<int>(
    'paid_total_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    debtId,
    snapshotDate,
    totalPrincipalCents,
    remainingPrincipalCents,
    paidTotalCents,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'debt_progress_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<DebtProgressSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('debt_id')) {
      context.handle(
        _debtIdMeta,
        debtId.isAcceptableOrUnknown(data['debt_id']!, _debtIdMeta),
      );
    } else if (isInserting) {
      context.missing(_debtIdMeta);
    }
    if (data.containsKey('snapshot_date')) {
      context.handle(
        _snapshotDateMeta,
        snapshotDate.isAcceptableOrUnknown(
          data['snapshot_date']!,
          _snapshotDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotDateMeta);
    }
    if (data.containsKey('total_principal_cents')) {
      context.handle(
        _totalPrincipalCentsMeta,
        totalPrincipalCents.isAcceptableOrUnknown(
          data['total_principal_cents']!,
          _totalPrincipalCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalPrincipalCentsMeta);
    }
    if (data.containsKey('remaining_principal_cents')) {
      context.handle(
        _remainingPrincipalCentsMeta,
        remainingPrincipalCents.isAcceptableOrUnknown(
          data['remaining_principal_cents']!,
          _remainingPrincipalCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingPrincipalCentsMeta);
    }
    if (data.containsKey('paid_total_cents')) {
      context.handle(
        _paidTotalCentsMeta,
        paidTotalCents.isAcceptableOrUnknown(
          data['paid_total_cents']!,
          _paidTotalCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_paidTotalCentsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DebtProgressSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DebtProgressSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      debtId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}debt_id'],
      )!,
      snapshotDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snapshot_date'],
      )!,
      totalPrincipalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_principal_cents'],
      )!,
      remainingPrincipalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remaining_principal_cents'],
      )!,
      paidTotalCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}paid_total_cents'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DebtProgressSnapshotsTable createAlias(String alias) {
    return $DebtProgressSnapshotsTable(attachedDatabase, alias);
  }
}

class DebtProgressSnapshot extends DataClass
    implements Insertable<DebtProgressSnapshot> {
  final String id;
  final String debtId;
  final DateTime snapshotDate;
  final int totalPrincipalCents;
  final int remainingPrincipalCents;
  final int paidTotalCents;
  final DateTime createdAt;
  const DebtProgressSnapshot({
    required this.id,
    required this.debtId,
    required this.snapshotDate,
    required this.totalPrincipalCents,
    required this.remainingPrincipalCents,
    required this.paidTotalCents,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['debt_id'] = Variable<String>(debtId);
    map['snapshot_date'] = Variable<DateTime>(snapshotDate);
    map['total_principal_cents'] = Variable<int>(totalPrincipalCents);
    map['remaining_principal_cents'] = Variable<int>(remainingPrincipalCents);
    map['paid_total_cents'] = Variable<int>(paidTotalCents);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DebtProgressSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return DebtProgressSnapshotsCompanion(
      id: Value(id),
      debtId: Value(debtId),
      snapshotDate: Value(snapshotDate),
      totalPrincipalCents: Value(totalPrincipalCents),
      remainingPrincipalCents: Value(remainingPrincipalCents),
      paidTotalCents: Value(paidTotalCents),
      createdAt: Value(createdAt),
    );
  }

  factory DebtProgressSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DebtProgressSnapshot(
      id: serializer.fromJson<String>(json['id']),
      debtId: serializer.fromJson<String>(json['debtId']),
      snapshotDate: serializer.fromJson<DateTime>(json['snapshotDate']),
      totalPrincipalCents: serializer.fromJson<int>(
        json['totalPrincipalCents'],
      ),
      remainingPrincipalCents: serializer.fromJson<int>(
        json['remainingPrincipalCents'],
      ),
      paidTotalCents: serializer.fromJson<int>(json['paidTotalCents']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'debtId': serializer.toJson<String>(debtId),
      'snapshotDate': serializer.toJson<DateTime>(snapshotDate),
      'totalPrincipalCents': serializer.toJson<int>(totalPrincipalCents),
      'remainingPrincipalCents': serializer.toJson<int>(
        remainingPrincipalCents,
      ),
      'paidTotalCents': serializer.toJson<int>(paidTotalCents),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DebtProgressSnapshot copyWith({
    String? id,
    String? debtId,
    DateTime? snapshotDate,
    int? totalPrincipalCents,
    int? remainingPrincipalCents,
    int? paidTotalCents,
    DateTime? createdAt,
  }) => DebtProgressSnapshot(
    id: id ?? this.id,
    debtId: debtId ?? this.debtId,
    snapshotDate: snapshotDate ?? this.snapshotDate,
    totalPrincipalCents: totalPrincipalCents ?? this.totalPrincipalCents,
    remainingPrincipalCents:
        remainingPrincipalCents ?? this.remainingPrincipalCents,
    paidTotalCents: paidTotalCents ?? this.paidTotalCents,
    createdAt: createdAt ?? this.createdAt,
  );
  DebtProgressSnapshot copyWithCompanion(DebtProgressSnapshotsCompanion data) {
    return DebtProgressSnapshot(
      id: data.id.present ? data.id.value : this.id,
      debtId: data.debtId.present ? data.debtId.value : this.debtId,
      snapshotDate: data.snapshotDate.present
          ? data.snapshotDate.value
          : this.snapshotDate,
      totalPrincipalCents: data.totalPrincipalCents.present
          ? data.totalPrincipalCents.value
          : this.totalPrincipalCents,
      remainingPrincipalCents: data.remainingPrincipalCents.present
          ? data.remainingPrincipalCents.value
          : this.remainingPrincipalCents,
      paidTotalCents: data.paidTotalCents.present
          ? data.paidTotalCents.value
          : this.paidTotalCents,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DebtProgressSnapshot(')
          ..write('id: $id, ')
          ..write('debtId: $debtId, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('totalPrincipalCents: $totalPrincipalCents, ')
          ..write('remainingPrincipalCents: $remainingPrincipalCents, ')
          ..write('paidTotalCents: $paidTotalCents, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    debtId,
    snapshotDate,
    totalPrincipalCents,
    remainingPrincipalCents,
    paidTotalCents,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DebtProgressSnapshot &&
          other.id == this.id &&
          other.debtId == this.debtId &&
          other.snapshotDate == this.snapshotDate &&
          other.totalPrincipalCents == this.totalPrincipalCents &&
          other.remainingPrincipalCents == this.remainingPrincipalCents &&
          other.paidTotalCents == this.paidTotalCents &&
          other.createdAt == this.createdAt);
}

class DebtProgressSnapshotsCompanion
    extends UpdateCompanion<DebtProgressSnapshot> {
  final Value<String> id;
  final Value<String> debtId;
  final Value<DateTime> snapshotDate;
  final Value<int> totalPrincipalCents;
  final Value<int> remainingPrincipalCents;
  final Value<int> paidTotalCents;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const DebtProgressSnapshotsCompanion({
    this.id = const Value.absent(),
    this.debtId = const Value.absent(),
    this.snapshotDate = const Value.absent(),
    this.totalPrincipalCents = const Value.absent(),
    this.remainingPrincipalCents = const Value.absent(),
    this.paidTotalCents = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DebtProgressSnapshotsCompanion.insert({
    required String id,
    required String debtId,
    required DateTime snapshotDate,
    required int totalPrincipalCents,
    required int remainingPrincipalCents,
    required int paidTotalCents,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       debtId = Value(debtId),
       snapshotDate = Value(snapshotDate),
       totalPrincipalCents = Value(totalPrincipalCents),
       remainingPrincipalCents = Value(remainingPrincipalCents),
       paidTotalCents = Value(paidTotalCents),
       createdAt = Value(createdAt);
  static Insertable<DebtProgressSnapshot> custom({
    Expression<String>? id,
    Expression<String>? debtId,
    Expression<DateTime>? snapshotDate,
    Expression<int>? totalPrincipalCents,
    Expression<int>? remainingPrincipalCents,
    Expression<int>? paidTotalCents,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (debtId != null) 'debt_id': debtId,
      if (snapshotDate != null) 'snapshot_date': snapshotDate,
      if (totalPrincipalCents != null)
        'total_principal_cents': totalPrincipalCents,
      if (remainingPrincipalCents != null)
        'remaining_principal_cents': remainingPrincipalCents,
      if (paidTotalCents != null) 'paid_total_cents': paidTotalCents,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DebtProgressSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? debtId,
    Value<DateTime>? snapshotDate,
    Value<int>? totalPrincipalCents,
    Value<int>? remainingPrincipalCents,
    Value<int>? paidTotalCents,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return DebtProgressSnapshotsCompanion(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      totalPrincipalCents: totalPrincipalCents ?? this.totalPrincipalCents,
      remainingPrincipalCents:
          remainingPrincipalCents ?? this.remainingPrincipalCents,
      paidTotalCents: paidTotalCents ?? this.paidTotalCents,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (debtId.present) {
      map['debt_id'] = Variable<String>(debtId.value);
    }
    if (snapshotDate.present) {
      map['snapshot_date'] = Variable<DateTime>(snapshotDate.value);
    }
    if (totalPrincipalCents.present) {
      map['total_principal_cents'] = Variable<int>(totalPrincipalCents.value);
    }
    if (remainingPrincipalCents.present) {
      map['remaining_principal_cents'] = Variable<int>(
        remainingPrincipalCents.value,
      );
    }
    if (paidTotalCents.present) {
      map['paid_total_cents'] = Variable<int>(paidTotalCents.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DebtProgressSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('debtId: $debtId, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('totalPrincipalCents: $totalPrincipalCents, ')
          ..write('remainingPrincipalCents: $remainingPrincipalCents, ')
          ..write('paidTotalCents: $paidTotalCents, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalProgressSnapshotsTable extends GoalProgressSnapshots
    with TableInfo<$GoalProgressSnapshotsTable, GoalProgressSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalProgressSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snapshotDateMeta = const VerificationMeta(
    'snapshotDate',
  );
  @override
  late final GeneratedColumn<DateTime> snapshotDate = GeneratedColumn<DateTime>(
    'snapshot_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentAmountCentsMeta =
      const VerificationMeta('currentAmountCents');
  @override
  late final GeneratedColumn<int> currentAmountCents = GeneratedColumn<int>(
    'current_amount_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    goalId,
    snapshotDate,
    currentAmountCents,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_progress_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalProgressSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('snapshot_date')) {
      context.handle(
        _snapshotDateMeta,
        snapshotDate.isAcceptableOrUnknown(
          data['snapshot_date']!,
          _snapshotDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotDateMeta);
    }
    if (data.containsKey('current_amount_cents')) {
      context.handle(
        _currentAmountCentsMeta,
        currentAmountCents.isAcceptableOrUnknown(
          data['current_amount_cents']!,
          _currentAmountCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentAmountCentsMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalProgressSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalProgressSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      )!,
      snapshotDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snapshot_date'],
      )!,
      currentAmountCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_amount_cents'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $GoalProgressSnapshotsTable createAlias(String alias) {
    return $GoalProgressSnapshotsTable(attachedDatabase, alias);
  }
}

class GoalProgressSnapshot extends DataClass
    implements Insertable<GoalProgressSnapshot> {
  final String id;
  final String goalId;
  final DateTime snapshotDate;
  final int currentAmountCents;
  final DateTime createdAt;
  const GoalProgressSnapshot({
    required this.id,
    required this.goalId,
    required this.snapshotDate,
    required this.currentAmountCents,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['goal_id'] = Variable<String>(goalId);
    map['snapshot_date'] = Variable<DateTime>(snapshotDate);
    map['current_amount_cents'] = Variable<int>(currentAmountCents);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GoalProgressSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return GoalProgressSnapshotsCompanion(
      id: Value(id),
      goalId: Value(goalId),
      snapshotDate: Value(snapshotDate),
      currentAmountCents: Value(currentAmountCents),
      createdAt: Value(createdAt),
    );
  }

  factory GoalProgressSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalProgressSnapshot(
      id: serializer.fromJson<String>(json['id']),
      goalId: serializer.fromJson<String>(json['goalId']),
      snapshotDate: serializer.fromJson<DateTime>(json['snapshotDate']),
      currentAmountCents: serializer.fromJson<int>(json['currentAmountCents']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'goalId': serializer.toJson<String>(goalId),
      'snapshotDate': serializer.toJson<DateTime>(snapshotDate),
      'currentAmountCents': serializer.toJson<int>(currentAmountCents),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  GoalProgressSnapshot copyWith({
    String? id,
    String? goalId,
    DateTime? snapshotDate,
    int? currentAmountCents,
    DateTime? createdAt,
  }) => GoalProgressSnapshot(
    id: id ?? this.id,
    goalId: goalId ?? this.goalId,
    snapshotDate: snapshotDate ?? this.snapshotDate,
    currentAmountCents: currentAmountCents ?? this.currentAmountCents,
    createdAt: createdAt ?? this.createdAt,
  );
  GoalProgressSnapshot copyWithCompanion(GoalProgressSnapshotsCompanion data) {
    return GoalProgressSnapshot(
      id: data.id.present ? data.id.value : this.id,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      snapshotDate: data.snapshotDate.present
          ? data.snapshotDate.value
          : this.snapshotDate,
      currentAmountCents: data.currentAmountCents.present
          ? data.currentAmountCents.value
          : this.currentAmountCents,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalProgressSnapshot(')
          ..write('id: $id, ')
          ..write('goalId: $goalId, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('currentAmountCents: $currentAmountCents, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, goalId, snapshotDate, currentAmountCents, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalProgressSnapshot &&
          other.id == this.id &&
          other.goalId == this.goalId &&
          other.snapshotDate == this.snapshotDate &&
          other.currentAmountCents == this.currentAmountCents &&
          other.createdAt == this.createdAt);
}

class GoalProgressSnapshotsCompanion
    extends UpdateCompanion<GoalProgressSnapshot> {
  final Value<String> id;
  final Value<String> goalId;
  final Value<DateTime> snapshotDate;
  final Value<int> currentAmountCents;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const GoalProgressSnapshotsCompanion({
    this.id = const Value.absent(),
    this.goalId = const Value.absent(),
    this.snapshotDate = const Value.absent(),
    this.currentAmountCents = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalProgressSnapshotsCompanion.insert({
    required String id,
    required String goalId,
    required DateTime snapshotDate,
    required int currentAmountCents,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       goalId = Value(goalId),
       snapshotDate = Value(snapshotDate),
       currentAmountCents = Value(currentAmountCents),
       createdAt = Value(createdAt);
  static Insertable<GoalProgressSnapshot> custom({
    Expression<String>? id,
    Expression<String>? goalId,
    Expression<DateTime>? snapshotDate,
    Expression<int>? currentAmountCents,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (goalId != null) 'goal_id': goalId,
      if (snapshotDate != null) 'snapshot_date': snapshotDate,
      if (currentAmountCents != null)
        'current_amount_cents': currentAmountCents,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalProgressSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? goalId,
    Value<DateTime>? snapshotDate,
    Value<int>? currentAmountCents,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return GoalProgressSnapshotsCompanion(
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      currentAmountCents: currentAmountCents ?? this.currentAmountCents,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (snapshotDate.present) {
      map['snapshot_date'] = Variable<DateTime>(snapshotDate.value);
    }
    if (currentAmountCents.present) {
      map['current_amount_cents'] = Variable<int>(currentAmountCents.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalProgressSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('goalId: $goalId, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('currentAmountCents: $currentAmountCents, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HoldingSnapshotsTable extends HoldingSnapshots
    with TableInfo<$HoldingSnapshotsTable, HoldingSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoldingSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _holdingIdMeta = const VerificationMeta(
    'holdingId',
  );
  @override
  late final GeneratedColumn<String> holdingId = GeneratedColumn<String>(
    'holding_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _securityIdMeta = const VerificationMeta(
    'securityId',
  );
  @override
  late final GeneratedColumn<String> securityId = GeneratedColumn<String>(
    'security_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountIdMeta = const VerificationMeta(
    'accountId',
  );
  @override
  late final GeneratedColumn<String> accountId = GeneratedColumn<String>(
    'account_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snapshotDateMeta = const VerificationMeta(
    'snapshotDate',
  );
  @override
  late final GeneratedColumn<DateTime> snapshotDate = GeneratedColumn<DateTime>(
    'snapshot_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _marketValueCentsMeta = const VerificationMeta(
    'marketValueCents',
  );
  @override
  late final GeneratedColumn<int> marketValueCents = GeneratedColumn<int>(
    'market_value_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _unrealizedPnlCentsMeta =
      const VerificationMeta('unrealizedPnlCents');
  @override
  late final GeneratedColumn<int> unrealizedPnlCents = GeneratedColumn<int>(
    'unrealized_pnl_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currencyCodeMeta = const VerificationMeta(
    'currencyCode',
  );
  @override
  late final GeneratedColumn<String> currencyCode = GeneratedColumn<String>(
    'currency_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    holdingId,
    securityId,
    accountId,
    snapshotDate,
    marketValueCents,
    unrealizedPnlCents,
    currencyCode,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holding_snapshots';
  @override
  VerificationContext validateIntegrity(
    Insertable<HoldingSnapshot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('holding_id')) {
      context.handle(
        _holdingIdMeta,
        holdingId.isAcceptableOrUnknown(data['holding_id']!, _holdingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_holdingIdMeta);
    }
    if (data.containsKey('security_id')) {
      context.handle(
        _securityIdMeta,
        securityId.isAcceptableOrUnknown(data['security_id']!, _securityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_securityIdMeta);
    }
    if (data.containsKey('account_id')) {
      context.handle(
        _accountIdMeta,
        accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta),
      );
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('snapshot_date')) {
      context.handle(
        _snapshotDateMeta,
        snapshotDate.isAcceptableOrUnknown(
          data['snapshot_date']!,
          _snapshotDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotDateMeta);
    }
    if (data.containsKey('market_value_cents')) {
      context.handle(
        _marketValueCentsMeta,
        marketValueCents.isAcceptableOrUnknown(
          data['market_value_cents']!,
          _marketValueCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_marketValueCentsMeta);
    }
    if (data.containsKey('unrealized_pnl_cents')) {
      context.handle(
        _unrealizedPnlCentsMeta,
        unrealizedPnlCents.isAcceptableOrUnknown(
          data['unrealized_pnl_cents']!,
          _unrealizedPnlCentsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_unrealizedPnlCentsMeta);
    }
    if (data.containsKey('currency_code')) {
      context.handle(
        _currencyCodeMeta,
        currencyCode.isAcceptableOrUnknown(
          data['currency_code']!,
          _currencyCodeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currencyCodeMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HoldingSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HoldingSnapshot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      holdingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holding_id'],
      )!,
      securityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}security_id'],
      )!,
      accountId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_id'],
      )!,
      snapshotDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snapshot_date'],
      )!,
      marketValueCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}market_value_cents'],
      )!,
      unrealizedPnlCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}unrealized_pnl_cents'],
      )!,
      currencyCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}currency_code'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $HoldingSnapshotsTable createAlias(String alias) {
    return $HoldingSnapshotsTable(attachedDatabase, alias);
  }
}

class HoldingSnapshot extends DataClass implements Insertable<HoldingSnapshot> {
  final String id;
  final String holdingId;
  final String securityId;
  final String accountId;
  final DateTime snapshotDate;
  final int marketValueCents;
  final int unrealizedPnlCents;
  final String currencyCode;
  final DateTime createdAt;
  const HoldingSnapshot({
    required this.id,
    required this.holdingId,
    required this.securityId,
    required this.accountId,
    required this.snapshotDate,
    required this.marketValueCents,
    required this.unrealizedPnlCents,
    required this.currencyCode,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['holding_id'] = Variable<String>(holdingId);
    map['security_id'] = Variable<String>(securityId);
    map['account_id'] = Variable<String>(accountId);
    map['snapshot_date'] = Variable<DateTime>(snapshotDate);
    map['market_value_cents'] = Variable<int>(marketValueCents);
    map['unrealized_pnl_cents'] = Variable<int>(unrealizedPnlCents);
    map['currency_code'] = Variable<String>(currencyCode);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HoldingSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return HoldingSnapshotsCompanion(
      id: Value(id),
      holdingId: Value(holdingId),
      securityId: Value(securityId),
      accountId: Value(accountId),
      snapshotDate: Value(snapshotDate),
      marketValueCents: Value(marketValueCents),
      unrealizedPnlCents: Value(unrealizedPnlCents),
      currencyCode: Value(currencyCode),
      createdAt: Value(createdAt),
    );
  }

  factory HoldingSnapshot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HoldingSnapshot(
      id: serializer.fromJson<String>(json['id']),
      holdingId: serializer.fromJson<String>(json['holdingId']),
      securityId: serializer.fromJson<String>(json['securityId']),
      accountId: serializer.fromJson<String>(json['accountId']),
      snapshotDate: serializer.fromJson<DateTime>(json['snapshotDate']),
      marketValueCents: serializer.fromJson<int>(json['marketValueCents']),
      unrealizedPnlCents: serializer.fromJson<int>(json['unrealizedPnlCents']),
      currencyCode: serializer.fromJson<String>(json['currencyCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'holdingId': serializer.toJson<String>(holdingId),
      'securityId': serializer.toJson<String>(securityId),
      'accountId': serializer.toJson<String>(accountId),
      'snapshotDate': serializer.toJson<DateTime>(snapshotDate),
      'marketValueCents': serializer.toJson<int>(marketValueCents),
      'unrealizedPnlCents': serializer.toJson<int>(unrealizedPnlCents),
      'currencyCode': serializer.toJson<String>(currencyCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HoldingSnapshot copyWith({
    String? id,
    String? holdingId,
    String? securityId,
    String? accountId,
    DateTime? snapshotDate,
    int? marketValueCents,
    int? unrealizedPnlCents,
    String? currencyCode,
    DateTime? createdAt,
  }) => HoldingSnapshot(
    id: id ?? this.id,
    holdingId: holdingId ?? this.holdingId,
    securityId: securityId ?? this.securityId,
    accountId: accountId ?? this.accountId,
    snapshotDate: snapshotDate ?? this.snapshotDate,
    marketValueCents: marketValueCents ?? this.marketValueCents,
    unrealizedPnlCents: unrealizedPnlCents ?? this.unrealizedPnlCents,
    currencyCode: currencyCode ?? this.currencyCode,
    createdAt: createdAt ?? this.createdAt,
  );
  HoldingSnapshot copyWithCompanion(HoldingSnapshotsCompanion data) {
    return HoldingSnapshot(
      id: data.id.present ? data.id.value : this.id,
      holdingId: data.holdingId.present ? data.holdingId.value : this.holdingId,
      securityId: data.securityId.present
          ? data.securityId.value
          : this.securityId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      snapshotDate: data.snapshotDate.present
          ? data.snapshotDate.value
          : this.snapshotDate,
      marketValueCents: data.marketValueCents.present
          ? data.marketValueCents.value
          : this.marketValueCents,
      unrealizedPnlCents: data.unrealizedPnlCents.present
          ? data.unrealizedPnlCents.value
          : this.unrealizedPnlCents,
      currencyCode: data.currencyCode.present
          ? data.currencyCode.value
          : this.currencyCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HoldingSnapshot(')
          ..write('id: $id, ')
          ..write('holdingId: $holdingId, ')
          ..write('securityId: $securityId, ')
          ..write('accountId: $accountId, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('marketValueCents: $marketValueCents, ')
          ..write('unrealizedPnlCents: $unrealizedPnlCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    holdingId,
    securityId,
    accountId,
    snapshotDate,
    marketValueCents,
    unrealizedPnlCents,
    currencyCode,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HoldingSnapshot &&
          other.id == this.id &&
          other.holdingId == this.holdingId &&
          other.securityId == this.securityId &&
          other.accountId == this.accountId &&
          other.snapshotDate == this.snapshotDate &&
          other.marketValueCents == this.marketValueCents &&
          other.unrealizedPnlCents == this.unrealizedPnlCents &&
          other.currencyCode == this.currencyCode &&
          other.createdAt == this.createdAt);
}

class HoldingSnapshotsCompanion extends UpdateCompanion<HoldingSnapshot> {
  final Value<String> id;
  final Value<String> holdingId;
  final Value<String> securityId;
  final Value<String> accountId;
  final Value<DateTime> snapshotDate;
  final Value<int> marketValueCents;
  final Value<int> unrealizedPnlCents;
  final Value<String> currencyCode;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const HoldingSnapshotsCompanion({
    this.id = const Value.absent(),
    this.holdingId = const Value.absent(),
    this.securityId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.snapshotDate = const Value.absent(),
    this.marketValueCents = const Value.absent(),
    this.unrealizedPnlCents = const Value.absent(),
    this.currencyCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HoldingSnapshotsCompanion.insert({
    required String id,
    required String holdingId,
    required String securityId,
    required String accountId,
    required DateTime snapshotDate,
    required int marketValueCents,
    required int unrealizedPnlCents,
    required String currencyCode,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       holdingId = Value(holdingId),
       securityId = Value(securityId),
       accountId = Value(accountId),
       snapshotDate = Value(snapshotDate),
       marketValueCents = Value(marketValueCents),
       unrealizedPnlCents = Value(unrealizedPnlCents),
       currencyCode = Value(currencyCode),
       createdAt = Value(createdAt);
  static Insertable<HoldingSnapshot> custom({
    Expression<String>? id,
    Expression<String>? holdingId,
    Expression<String>? securityId,
    Expression<String>? accountId,
    Expression<DateTime>? snapshotDate,
    Expression<int>? marketValueCents,
    Expression<int>? unrealizedPnlCents,
    Expression<String>? currencyCode,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (holdingId != null) 'holding_id': holdingId,
      if (securityId != null) 'security_id': securityId,
      if (accountId != null) 'account_id': accountId,
      if (snapshotDate != null) 'snapshot_date': snapshotDate,
      if (marketValueCents != null) 'market_value_cents': marketValueCents,
      if (unrealizedPnlCents != null)
        'unrealized_pnl_cents': unrealizedPnlCents,
      if (currencyCode != null) 'currency_code': currencyCode,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HoldingSnapshotsCompanion copyWith({
    Value<String>? id,
    Value<String>? holdingId,
    Value<String>? securityId,
    Value<String>? accountId,
    Value<DateTime>? snapshotDate,
    Value<int>? marketValueCents,
    Value<int>? unrealizedPnlCents,
    Value<String>? currencyCode,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return HoldingSnapshotsCompanion(
      id: id ?? this.id,
      holdingId: holdingId ?? this.holdingId,
      securityId: securityId ?? this.securityId,
      accountId: accountId ?? this.accountId,
      snapshotDate: snapshotDate ?? this.snapshotDate,
      marketValueCents: marketValueCents ?? this.marketValueCents,
      unrealizedPnlCents: unrealizedPnlCents ?? this.unrealizedPnlCents,
      currencyCode: currencyCode ?? this.currencyCode,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (holdingId.present) {
      map['holding_id'] = Variable<String>(holdingId.value);
    }
    if (securityId.present) {
      map['security_id'] = Variable<String>(securityId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<String>(accountId.value);
    }
    if (snapshotDate.present) {
      map['snapshot_date'] = Variable<DateTime>(snapshotDate.value);
    }
    if (marketValueCents.present) {
      map['market_value_cents'] = Variable<int>(marketValueCents.value);
    }
    if (unrealizedPnlCents.present) {
      map['unrealized_pnl_cents'] = Variable<int>(unrealizedPnlCents.value);
    }
    if (currencyCode.present) {
      map['currency_code'] = Variable<String>(currencyCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoldingSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('holdingId: $holdingId, ')
          ..write('securityId: $securityId, ')
          ..write('accountId: $accountId, ')
          ..write('snapshotDate: $snapshotDate, ')
          ..write('marketValueCents: $marketValueCents, ')
          ..write('unrealizedPnlCents: $unrealizedPnlCents, ')
          ..write('currencyCode: $currencyCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HoldingLotsTable extends HoldingLots
    with TableInfo<$HoldingLotsTable, HoldingLot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HoldingLotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _holdingIdMeta = const VerificationMeta(
    'holdingId',
  );
  @override
  late final GeneratedColumn<String> holdingId = GeneratedColumn<String>(
    'holding_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _securityIdMeta = const VerificationMeta(
    'securityId',
  );
  @override
  late final GeneratedColumn<String> securityId = GeneratedColumn<String>(
    'security_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acquiredDateMeta = const VerificationMeta(
    'acquiredDate',
  );
  @override
  late final GeneratedColumn<DateTime> acquiredDate = GeneratedColumn<DateTime>(
    'acquired_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _acquiredTradeIdMeta = const VerificationMeta(
    'acquiredTradeId',
  );
  @override
  late final GeneratedColumn<String> acquiredTradeId = GeneratedColumn<String>(
    'acquired_trade_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priceCentsMeta = const VerificationMeta(
    'priceCents',
  );
  @override
  late final GeneratedColumn<int> priceCents = GeneratedColumn<int>(
    'price_cents',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remainingQuantityMeta = const VerificationMeta(
    'remainingQuantity',
  );
  @override
  late final GeneratedColumn<double> remainingQuantity =
      GeneratedColumn<double>(
        'remaining_quantity',
        aliasedName,
        false,
        type: DriftSqlType.double,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    holdingId,
    securityId,
    acquiredDate,
    acquiredTradeId,
    priceCents,
    quantity,
    remainingQuantity,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'holding_lots';
  @override
  VerificationContext validateIntegrity(
    Insertable<HoldingLot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('holding_id')) {
      context.handle(
        _holdingIdMeta,
        holdingId.isAcceptableOrUnknown(data['holding_id']!, _holdingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_holdingIdMeta);
    }
    if (data.containsKey('security_id')) {
      context.handle(
        _securityIdMeta,
        securityId.isAcceptableOrUnknown(data['security_id']!, _securityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_securityIdMeta);
    }
    if (data.containsKey('acquired_date')) {
      context.handle(
        _acquiredDateMeta,
        acquiredDate.isAcceptableOrUnknown(
          data['acquired_date']!,
          _acquiredDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_acquiredDateMeta);
    }
    if (data.containsKey('acquired_trade_id')) {
      context.handle(
        _acquiredTradeIdMeta,
        acquiredTradeId.isAcceptableOrUnknown(
          data['acquired_trade_id']!,
          _acquiredTradeIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_acquiredTradeIdMeta);
    }
    if (data.containsKey('price_cents')) {
      context.handle(
        _priceCentsMeta,
        priceCents.isAcceptableOrUnknown(data['price_cents']!, _priceCentsMeta),
      );
    } else if (isInserting) {
      context.missing(_priceCentsMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    } else if (isInserting) {
      context.missing(_quantityMeta);
    }
    if (data.containsKey('remaining_quantity')) {
      context.handle(
        _remainingQuantityMeta,
        remainingQuantity.isAcceptableOrUnknown(
          data['remaining_quantity']!,
          _remainingQuantityMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remainingQuantityMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HoldingLot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HoldingLot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      holdingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}holding_id'],
      )!,
      securityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}security_id'],
      )!,
      acquiredDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}acquired_date'],
      )!,
      acquiredTradeId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}acquired_trade_id'],
      )!,
      priceCents: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}price_cents'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      remainingQuantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}remaining_quantity'],
      )!,
    );
  }

  @override
  $HoldingLotsTable createAlias(String alias) {
    return $HoldingLotsTable(attachedDatabase, alias);
  }
}

class HoldingLot extends DataClass implements Insertable<HoldingLot> {
  final String id;
  final String holdingId;
  final String securityId;
  final DateTime acquiredDate;
  final String acquiredTradeId;
  final int priceCents;
  final double quantity;
  final double remainingQuantity;
  const HoldingLot({
    required this.id,
    required this.holdingId,
    required this.securityId,
    required this.acquiredDate,
    required this.acquiredTradeId,
    required this.priceCents,
    required this.quantity,
    required this.remainingQuantity,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['holding_id'] = Variable<String>(holdingId);
    map['security_id'] = Variable<String>(securityId);
    map['acquired_date'] = Variable<DateTime>(acquiredDate);
    map['acquired_trade_id'] = Variable<String>(acquiredTradeId);
    map['price_cents'] = Variable<int>(priceCents);
    map['quantity'] = Variable<double>(quantity);
    map['remaining_quantity'] = Variable<double>(remainingQuantity);
    return map;
  }

  HoldingLotsCompanion toCompanion(bool nullToAbsent) {
    return HoldingLotsCompanion(
      id: Value(id),
      holdingId: Value(holdingId),
      securityId: Value(securityId),
      acquiredDate: Value(acquiredDate),
      acquiredTradeId: Value(acquiredTradeId),
      priceCents: Value(priceCents),
      quantity: Value(quantity),
      remainingQuantity: Value(remainingQuantity),
    );
  }

  factory HoldingLot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HoldingLot(
      id: serializer.fromJson<String>(json['id']),
      holdingId: serializer.fromJson<String>(json['holdingId']),
      securityId: serializer.fromJson<String>(json['securityId']),
      acquiredDate: serializer.fromJson<DateTime>(json['acquiredDate']),
      acquiredTradeId: serializer.fromJson<String>(json['acquiredTradeId']),
      priceCents: serializer.fromJson<int>(json['priceCents']),
      quantity: serializer.fromJson<double>(json['quantity']),
      remainingQuantity: serializer.fromJson<double>(json['remainingQuantity']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'holdingId': serializer.toJson<String>(holdingId),
      'securityId': serializer.toJson<String>(securityId),
      'acquiredDate': serializer.toJson<DateTime>(acquiredDate),
      'acquiredTradeId': serializer.toJson<String>(acquiredTradeId),
      'priceCents': serializer.toJson<int>(priceCents),
      'quantity': serializer.toJson<double>(quantity),
      'remainingQuantity': serializer.toJson<double>(remainingQuantity),
    };
  }

  HoldingLot copyWith({
    String? id,
    String? holdingId,
    String? securityId,
    DateTime? acquiredDate,
    String? acquiredTradeId,
    int? priceCents,
    double? quantity,
    double? remainingQuantity,
  }) => HoldingLot(
    id: id ?? this.id,
    holdingId: holdingId ?? this.holdingId,
    securityId: securityId ?? this.securityId,
    acquiredDate: acquiredDate ?? this.acquiredDate,
    acquiredTradeId: acquiredTradeId ?? this.acquiredTradeId,
    priceCents: priceCents ?? this.priceCents,
    quantity: quantity ?? this.quantity,
    remainingQuantity: remainingQuantity ?? this.remainingQuantity,
  );
  HoldingLot copyWithCompanion(HoldingLotsCompanion data) {
    return HoldingLot(
      id: data.id.present ? data.id.value : this.id,
      holdingId: data.holdingId.present ? data.holdingId.value : this.holdingId,
      securityId: data.securityId.present
          ? data.securityId.value
          : this.securityId,
      acquiredDate: data.acquiredDate.present
          ? data.acquiredDate.value
          : this.acquiredDate,
      acquiredTradeId: data.acquiredTradeId.present
          ? data.acquiredTradeId.value
          : this.acquiredTradeId,
      priceCents: data.priceCents.present
          ? data.priceCents.value
          : this.priceCents,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      remainingQuantity: data.remainingQuantity.present
          ? data.remainingQuantity.value
          : this.remainingQuantity,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HoldingLot(')
          ..write('id: $id, ')
          ..write('holdingId: $holdingId, ')
          ..write('securityId: $securityId, ')
          ..write('acquiredDate: $acquiredDate, ')
          ..write('acquiredTradeId: $acquiredTradeId, ')
          ..write('priceCents: $priceCents, ')
          ..write('quantity: $quantity, ')
          ..write('remainingQuantity: $remainingQuantity')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    holdingId,
    securityId,
    acquiredDate,
    acquiredTradeId,
    priceCents,
    quantity,
    remainingQuantity,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HoldingLot &&
          other.id == this.id &&
          other.holdingId == this.holdingId &&
          other.securityId == this.securityId &&
          other.acquiredDate == this.acquiredDate &&
          other.acquiredTradeId == this.acquiredTradeId &&
          other.priceCents == this.priceCents &&
          other.quantity == this.quantity &&
          other.remainingQuantity == this.remainingQuantity);
}

class HoldingLotsCompanion extends UpdateCompanion<HoldingLot> {
  final Value<String> id;
  final Value<String> holdingId;
  final Value<String> securityId;
  final Value<DateTime> acquiredDate;
  final Value<String> acquiredTradeId;
  final Value<int> priceCents;
  final Value<double> quantity;
  final Value<double> remainingQuantity;
  final Value<int> rowid;
  const HoldingLotsCompanion({
    this.id = const Value.absent(),
    this.holdingId = const Value.absent(),
    this.securityId = const Value.absent(),
    this.acquiredDate = const Value.absent(),
    this.acquiredTradeId = const Value.absent(),
    this.priceCents = const Value.absent(),
    this.quantity = const Value.absent(),
    this.remainingQuantity = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HoldingLotsCompanion.insert({
    required String id,
    required String holdingId,
    required String securityId,
    required DateTime acquiredDate,
    required String acquiredTradeId,
    required int priceCents,
    required double quantity,
    required double remainingQuantity,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       holdingId = Value(holdingId),
       securityId = Value(securityId),
       acquiredDate = Value(acquiredDate),
       acquiredTradeId = Value(acquiredTradeId),
       priceCents = Value(priceCents),
       quantity = Value(quantity),
       remainingQuantity = Value(remainingQuantity);
  static Insertable<HoldingLot> custom({
    Expression<String>? id,
    Expression<String>? holdingId,
    Expression<String>? securityId,
    Expression<DateTime>? acquiredDate,
    Expression<String>? acquiredTradeId,
    Expression<int>? priceCents,
    Expression<double>? quantity,
    Expression<double>? remainingQuantity,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (holdingId != null) 'holding_id': holdingId,
      if (securityId != null) 'security_id': securityId,
      if (acquiredDate != null) 'acquired_date': acquiredDate,
      if (acquiredTradeId != null) 'acquired_trade_id': acquiredTradeId,
      if (priceCents != null) 'price_cents': priceCents,
      if (quantity != null) 'quantity': quantity,
      if (remainingQuantity != null) 'remaining_quantity': remainingQuantity,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HoldingLotsCompanion copyWith({
    Value<String>? id,
    Value<String>? holdingId,
    Value<String>? securityId,
    Value<DateTime>? acquiredDate,
    Value<String>? acquiredTradeId,
    Value<int>? priceCents,
    Value<double>? quantity,
    Value<double>? remainingQuantity,
    Value<int>? rowid,
  }) {
    return HoldingLotsCompanion(
      id: id ?? this.id,
      holdingId: holdingId ?? this.holdingId,
      securityId: securityId ?? this.securityId,
      acquiredDate: acquiredDate ?? this.acquiredDate,
      acquiredTradeId: acquiredTradeId ?? this.acquiredTradeId,
      priceCents: priceCents ?? this.priceCents,
      quantity: quantity ?? this.quantity,
      remainingQuantity: remainingQuantity ?? this.remainingQuantity,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (holdingId.present) {
      map['holding_id'] = Variable<String>(holdingId.value);
    }
    if (securityId.present) {
      map['security_id'] = Variable<String>(securityId.value);
    }
    if (acquiredDate.present) {
      map['acquired_date'] = Variable<DateTime>(acquiredDate.value);
    }
    if (acquiredTradeId.present) {
      map['acquired_trade_id'] = Variable<String>(acquiredTradeId.value);
    }
    if (priceCents.present) {
      map['price_cents'] = Variable<int>(priceCents.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (remainingQuantity.present) {
      map['remaining_quantity'] = Variable<double>(remainingQuantity.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HoldingLotsCompanion(')
          ..write('id: $id, ')
          ..write('holdingId: $holdingId, ')
          ..write('securityId: $securityId, ')
          ..write('acquiredDate: $acquiredDate, ')
          ..write('acquiredTradeId: $acquiredTradeId, ')
          ..write('priceCents: $priceCents, ')
          ..write('quantity: $quantity, ')
          ..write('remainingQuantity: $remainingQuantity, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $ChartOfAccountsTable chartOfAccounts = $ChartOfAccountsTable(
    this,
  );
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $TransactionEntriesTable transactionEntries =
      $TransactionEntriesTable(this);
  late final $DebtsTable debts = $DebtsTable(this);
  late final $PaymentScheduleEntriesTable paymentScheduleEntries =
      $PaymentScheduleEntriesTable(this);
  late final $ReminderLogsTable reminderLogs = $ReminderLogsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $BudgetItemsTable budgetItems = $BudgetItemsTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $GoalAccountLinksTable goalAccountLinks = $GoalAccountLinksTable(
    this,
  );
  late final $GoalDebtLinksTable goalDebtLinks = $GoalDebtLinksTable(this);
  late final $TagsTable tags = $TagsTable(this);
  late final $TransactionTagsTable transactionTags = $TransactionTagsTable(
    this,
  );
  late final $TransactionTemplatesTable transactionTemplates =
      $TransactionTemplatesTable(this);
  late final $HoldingsTable holdings = $HoldingsTable(this);
  late final $HoldingTransactionsTable holdingTransactions =
      $HoldingTransactionsTable(this);
  late final $CurrenciesTable currencies = $CurrenciesTable(this);
  late final $RateHistoriesTable rateHistories = $RateHistoriesTable(this);
  late final $SecuritiesTable securities = $SecuritiesTable(this);
  late final $SecurityPriceHistoriesTable securityPriceHistories =
      $SecurityPriceHistoriesTable(this);
  late final $DebtProgressSnapshotsTable debtProgressSnapshots =
      $DebtProgressSnapshotsTable(this);
  late final $GoalProgressSnapshotsTable goalProgressSnapshots =
      $GoalProgressSnapshotsTable(this);
  late final $HoldingSnapshotsTable holdingSnapshots = $HoldingSnapshotsTable(
    this,
  );
  late final $HoldingLotsTable holdingLots = $HoldingLotsTable(this);
  late final AccountDao accountDao = AccountDao(this as AppDatabase);
  late final TransactionDao transactionDao = TransactionDao(
    this as AppDatabase,
  );
  late final DebtDao debtDao = DebtDao(this as AppDatabase);
  late final BudgetDao budgetDao = BudgetDao(this as AppDatabase);
  late final GoalDao goalDao = GoalDao(this as AppDatabase);
  late final TagDao tagDao = TagDao(this as AppDatabase);
  late final TemplateDao templateDao = TemplateDao(this as AppDatabase);
  late final HoldingDao holdingDao = HoldingDao(this as AppDatabase);
  late final ReferenceDao referenceDao = ReferenceDao(this as AppDatabase);
  late final DerivedDao derivedDao = DerivedDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    accounts,
    chartOfAccounts,
    transactions,
    transactionEntries,
    debts,
    paymentScheduleEntries,
    reminderLogs,
    budgets,
    budgetItems,
    goals,
    goalAccountLinks,
    goalDebtLinks,
    tags,
    transactionTags,
    transactionTemplates,
    holdings,
    holdingTransactions,
    currencies,
    rateHistories,
    securities,
    securityPriceHistories,
    debtProgressSnapshots,
    goalProgressSnapshots,
    holdingSnapshots,
    holdingLots,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transactions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transaction_entries', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'debts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('payment_schedule_entries', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'budgets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('budget_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('goal_account_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('goal_debt_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'transactions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transaction_tags', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tags',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('transaction_tags', kind: UpdateKind.delete)],
    ),
  ]);
  @override
  DriftDatabaseOptions get options =>
      const DriftDatabaseOptions(storeDateTimeAsText: true);
}

typedef $$AccountsTableCreateCompanionBuilder =
    AccountsCompanion Function({
      required String id,
      required String name,
      required int accountType,
      required int category,
      required String currencyCode,
      required int initialBalanceCents,
      required int currentBalanceCents,
      required int ownership,
      required String icon,
      required String color,
      required String chartCode,
      Value<String?> parentId,
      required bool isSystem,
      required int sortOrder,
      required String institution,
      Value<int?> creditLimitCents,
      required String cardNumberTail,
      required String notes,
      Value<DateTime?> openingDate,
      Value<double?> interestRate,
      Value<int?> creditBillingDay,
      Value<int?> creditRepaymentDay,
      Value<int?> creditAnnualFeeCents,
      Value<int?> investCostCents,
      Value<int?> investMarketValueCents,
      Value<double?> investReturnYtd,
      Value<int?> fixedPrincipalCents,
      Value<DateTime?> fixedStartDate,
      Value<DateTime?> fixedMaturityDate,
      Value<int?> fixedTermMonths,
      required String goldProductType,
      Value<double?> goldQuantity,
      Value<int?> goldBuyPriceCents,
      Value<int?> goldCurrentPriceCents,
      Value<int?> estatePurchasePriceCents,
      Value<int?> estateCurrentValueCents,
      Value<DateTime?> estatePurchaseDate,
      Value<double?> estateDepreciationRate,
      Value<int?> loanOriginalCents,
      Value<int?> loanRemainingCents,
      Value<int?> loanMonthlyCents,
      Value<DateTime?> loanNextPaymentDate,
      required int status,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$AccountsTableUpdateCompanionBuilder =
    AccountsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> accountType,
      Value<int> category,
      Value<String> currencyCode,
      Value<int> initialBalanceCents,
      Value<int> currentBalanceCents,
      Value<int> ownership,
      Value<String> icon,
      Value<String> color,
      Value<String> chartCode,
      Value<String?> parentId,
      Value<bool> isSystem,
      Value<int> sortOrder,
      Value<String> institution,
      Value<int?> creditLimitCents,
      Value<String> cardNumberTail,
      Value<String> notes,
      Value<DateTime?> openingDate,
      Value<double?> interestRate,
      Value<int?> creditBillingDay,
      Value<int?> creditRepaymentDay,
      Value<int?> creditAnnualFeeCents,
      Value<int?> investCostCents,
      Value<int?> investMarketValueCents,
      Value<double?> investReturnYtd,
      Value<int?> fixedPrincipalCents,
      Value<DateTime?> fixedStartDate,
      Value<DateTime?> fixedMaturityDate,
      Value<int?> fixedTermMonths,
      Value<String> goldProductType,
      Value<double?> goldQuantity,
      Value<int?> goldBuyPriceCents,
      Value<int?> goldCurrentPriceCents,
      Value<int?> estatePurchasePriceCents,
      Value<int?> estateCurrentValueCents,
      Value<DateTime?> estatePurchaseDate,
      Value<double?> estateDepreciationRate,
      Value<int?> loanOriginalCents,
      Value<int?> loanRemainingCents,
      Value<int?> loanMonthlyCents,
      Value<DateTime?> loanNextPaymentDate,
      Value<int> status,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get initialBalanceCents => $composableBuilder(
    column: $table.initialBalanceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentBalanceCents => $composableBuilder(
    column: $table.currentBalanceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ownership => $composableBuilder(
    column: $table.ownership,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chartCode => $composableBuilder(
    column: $table.chartCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditLimitCents => $composableBuilder(
    column: $table.creditLimitCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cardNumberTail => $composableBuilder(
    column: $table.cardNumberTail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get openingDate => $composableBuilder(
    column: $table.openingDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get interestRate => $composableBuilder(
    column: $table.interestRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditBillingDay => $composableBuilder(
    column: $table.creditBillingDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditRepaymentDay => $composableBuilder(
    column: $table.creditRepaymentDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditAnnualFeeCents => $composableBuilder(
    column: $table.creditAnnualFeeCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get investCostCents => $composableBuilder(
    column: $table.investCostCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get investMarketValueCents => $composableBuilder(
    column: $table.investMarketValueCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get investReturnYtd => $composableBuilder(
    column: $table.investReturnYtd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fixedPrincipalCents => $composableBuilder(
    column: $table.fixedPrincipalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fixedStartDate => $composableBuilder(
    column: $table.fixedStartDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fixedMaturityDate => $composableBuilder(
    column: $table.fixedMaturityDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fixedTermMonths => $composableBuilder(
    column: $table.fixedTermMonths,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goldProductType => $composableBuilder(
    column: $table.goldProductType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get goldQuantity => $composableBuilder(
    column: $table.goldQuantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goldBuyPriceCents => $composableBuilder(
    column: $table.goldBuyPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goldCurrentPriceCents => $composableBuilder(
    column: $table.goldCurrentPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estatePurchasePriceCents => $composableBuilder(
    column: $table.estatePurchasePriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estateCurrentValueCents => $composableBuilder(
    column: $table.estateCurrentValueCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get estatePurchaseDate => $composableBuilder(
    column: $table.estatePurchaseDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get estateDepreciationRate => $composableBuilder(
    column: $table.estateDepreciationRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loanOriginalCents => $composableBuilder(
    column: $table.loanOriginalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loanRemainingCents => $composableBuilder(
    column: $table.loanRemainingCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get loanMonthlyCents => $composableBuilder(
    column: $table.loanMonthlyCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get loanNextPaymentDate => $composableBuilder(
    column: $table.loanNextPaymentDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get initialBalanceCents => $composableBuilder(
    column: $table.initialBalanceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentBalanceCents => $composableBuilder(
    column: $table.currentBalanceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ownership => $composableBuilder(
    column: $table.ownership,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chartCode => $composableBuilder(
    column: $table.chartCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentId => $composableBuilder(
    column: $table.parentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isSystem => $composableBuilder(
    column: $table.isSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditLimitCents => $composableBuilder(
    column: $table.creditLimitCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cardNumberTail => $composableBuilder(
    column: $table.cardNumberTail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get openingDate => $composableBuilder(
    column: $table.openingDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get interestRate => $composableBuilder(
    column: $table.interestRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditBillingDay => $composableBuilder(
    column: $table.creditBillingDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditRepaymentDay => $composableBuilder(
    column: $table.creditRepaymentDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditAnnualFeeCents => $composableBuilder(
    column: $table.creditAnnualFeeCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get investCostCents => $composableBuilder(
    column: $table.investCostCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get investMarketValueCents => $composableBuilder(
    column: $table.investMarketValueCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get investReturnYtd => $composableBuilder(
    column: $table.investReturnYtd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fixedPrincipalCents => $composableBuilder(
    column: $table.fixedPrincipalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fixedStartDate => $composableBuilder(
    column: $table.fixedStartDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fixedMaturityDate => $composableBuilder(
    column: $table.fixedMaturityDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fixedTermMonths => $composableBuilder(
    column: $table.fixedTermMonths,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goldProductType => $composableBuilder(
    column: $table.goldProductType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get goldQuantity => $composableBuilder(
    column: $table.goldQuantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goldBuyPriceCents => $composableBuilder(
    column: $table.goldBuyPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goldCurrentPriceCents => $composableBuilder(
    column: $table.goldCurrentPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estatePurchasePriceCents => $composableBuilder(
    column: $table.estatePurchasePriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estateCurrentValueCents => $composableBuilder(
    column: $table.estateCurrentValueCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get estatePurchaseDate => $composableBuilder(
    column: $table.estatePurchaseDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get estateDepreciationRate => $composableBuilder(
    column: $table.estateDepreciationRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loanOriginalCents => $composableBuilder(
    column: $table.loanOriginalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loanRemainingCents => $composableBuilder(
    column: $table.loanRemainingCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get loanMonthlyCents => $composableBuilder(
    column: $table.loanMonthlyCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get loanNextPaymentDate => $composableBuilder(
    column: $table.loanNextPaymentDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get initialBalanceCents => $composableBuilder(
    column: $table.initialBalanceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentBalanceCents => $composableBuilder(
    column: $table.currentBalanceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ownership =>
      $composableBuilder(column: $table.ownership, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get chartCode =>
      $composableBuilder(column: $table.chartCode, builder: (column) => column);

  GeneratedColumn<String> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<String> get institution => $composableBuilder(
    column: $table.institution,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creditLimitCents => $composableBuilder(
    column: $table.creditLimitCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get cardNumberTail => $composableBuilder(
    column: $table.cardNumberTail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get openingDate => $composableBuilder(
    column: $table.openingDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get interestRate => $composableBuilder(
    column: $table.interestRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creditBillingDay => $composableBuilder(
    column: $table.creditBillingDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creditRepaymentDay => $composableBuilder(
    column: $table.creditRepaymentDay,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creditAnnualFeeCents => $composableBuilder(
    column: $table.creditAnnualFeeCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get investCostCents => $composableBuilder(
    column: $table.investCostCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get investMarketValueCents => $composableBuilder(
    column: $table.investMarketValueCents,
    builder: (column) => column,
  );

  GeneratedColumn<double> get investReturnYtd => $composableBuilder(
    column: $table.investReturnYtd,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fixedPrincipalCents => $composableBuilder(
    column: $table.fixedPrincipalCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fixedStartDate => $composableBuilder(
    column: $table.fixedStartDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get fixedMaturityDate => $composableBuilder(
    column: $table.fixedMaturityDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fixedTermMonths => $composableBuilder(
    column: $table.fixedTermMonths,
    builder: (column) => column,
  );

  GeneratedColumn<String> get goldProductType => $composableBuilder(
    column: $table.goldProductType,
    builder: (column) => column,
  );

  GeneratedColumn<double> get goldQuantity => $composableBuilder(
    column: $table.goldQuantity,
    builder: (column) => column,
  );

  GeneratedColumn<int> get goldBuyPriceCents => $composableBuilder(
    column: $table.goldBuyPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get goldCurrentPriceCents => $composableBuilder(
    column: $table.goldCurrentPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estatePurchasePriceCents => $composableBuilder(
    column: $table.estatePurchasePriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estateCurrentValueCents => $composableBuilder(
    column: $table.estateCurrentValueCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get estatePurchaseDate => $composableBuilder(
    column: $table.estatePurchaseDate,
    builder: (column) => column,
  );

  GeneratedColumn<double> get estateDepreciationRate => $composableBuilder(
    column: $table.estateDepreciationRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get loanOriginalCents => $composableBuilder(
    column: $table.loanOriginalCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get loanRemainingCents => $composableBuilder(
    column: $table.loanRemainingCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get loanMonthlyCents => $composableBuilder(
    column: $table.loanMonthlyCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get loanNextPaymentDate => $composableBuilder(
    column: $table.loanNextPaymentDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AccountsTable,
          Account,
          $$AccountsTableFilterComposer,
          $$AccountsTableOrderingComposer,
          $$AccountsTableAnnotationComposer,
          $$AccountsTableCreateCompanionBuilder,
          $$AccountsTableUpdateCompanionBuilder,
          (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
          Account,
          PrefetchHooks Function()
        > {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> accountType = const Value.absent(),
                Value<int> category = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<int> initialBalanceCents = const Value.absent(),
                Value<int> currentBalanceCents = const Value.absent(),
                Value<int> ownership = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<String> chartCode = const Value.absent(),
                Value<String?> parentId = const Value.absent(),
                Value<bool> isSystem = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<String> institution = const Value.absent(),
                Value<int?> creditLimitCents = const Value.absent(),
                Value<String> cardNumberTail = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime?> openingDate = const Value.absent(),
                Value<double?> interestRate = const Value.absent(),
                Value<int?> creditBillingDay = const Value.absent(),
                Value<int?> creditRepaymentDay = const Value.absent(),
                Value<int?> creditAnnualFeeCents = const Value.absent(),
                Value<int?> investCostCents = const Value.absent(),
                Value<int?> investMarketValueCents = const Value.absent(),
                Value<double?> investReturnYtd = const Value.absent(),
                Value<int?> fixedPrincipalCents = const Value.absent(),
                Value<DateTime?> fixedStartDate = const Value.absent(),
                Value<DateTime?> fixedMaturityDate = const Value.absent(),
                Value<int?> fixedTermMonths = const Value.absent(),
                Value<String> goldProductType = const Value.absent(),
                Value<double?> goldQuantity = const Value.absent(),
                Value<int?> goldBuyPriceCents = const Value.absent(),
                Value<int?> goldCurrentPriceCents = const Value.absent(),
                Value<int?> estatePurchasePriceCents = const Value.absent(),
                Value<int?> estateCurrentValueCents = const Value.absent(),
                Value<DateTime?> estatePurchaseDate = const Value.absent(),
                Value<double?> estateDepreciationRate = const Value.absent(),
                Value<int?> loanOriginalCents = const Value.absent(),
                Value<int?> loanRemainingCents = const Value.absent(),
                Value<int?> loanMonthlyCents = const Value.absent(),
                Value<DateTime?> loanNextPaymentDate = const Value.absent(),
                Value<int> status = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion(
                id: id,
                name: name,
                accountType: accountType,
                category: category,
                currencyCode: currencyCode,
                initialBalanceCents: initialBalanceCents,
                currentBalanceCents: currentBalanceCents,
                ownership: ownership,
                icon: icon,
                color: color,
                chartCode: chartCode,
                parentId: parentId,
                isSystem: isSystem,
                sortOrder: sortOrder,
                institution: institution,
                creditLimitCents: creditLimitCents,
                cardNumberTail: cardNumberTail,
                notes: notes,
                openingDate: openingDate,
                interestRate: interestRate,
                creditBillingDay: creditBillingDay,
                creditRepaymentDay: creditRepaymentDay,
                creditAnnualFeeCents: creditAnnualFeeCents,
                investCostCents: investCostCents,
                investMarketValueCents: investMarketValueCents,
                investReturnYtd: investReturnYtd,
                fixedPrincipalCents: fixedPrincipalCents,
                fixedStartDate: fixedStartDate,
                fixedMaturityDate: fixedMaturityDate,
                fixedTermMonths: fixedTermMonths,
                goldProductType: goldProductType,
                goldQuantity: goldQuantity,
                goldBuyPriceCents: goldBuyPriceCents,
                goldCurrentPriceCents: goldCurrentPriceCents,
                estatePurchasePriceCents: estatePurchasePriceCents,
                estateCurrentValueCents: estateCurrentValueCents,
                estatePurchaseDate: estatePurchaseDate,
                estateDepreciationRate: estateDepreciationRate,
                loanOriginalCents: loanOriginalCents,
                loanRemainingCents: loanRemainingCents,
                loanMonthlyCents: loanMonthlyCents,
                loanNextPaymentDate: loanNextPaymentDate,
                status: status,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int accountType,
                required int category,
                required String currencyCode,
                required int initialBalanceCents,
                required int currentBalanceCents,
                required int ownership,
                required String icon,
                required String color,
                required String chartCode,
                Value<String?> parentId = const Value.absent(),
                required bool isSystem,
                required int sortOrder,
                required String institution,
                Value<int?> creditLimitCents = const Value.absent(),
                required String cardNumberTail,
                required String notes,
                Value<DateTime?> openingDate = const Value.absent(),
                Value<double?> interestRate = const Value.absent(),
                Value<int?> creditBillingDay = const Value.absent(),
                Value<int?> creditRepaymentDay = const Value.absent(),
                Value<int?> creditAnnualFeeCents = const Value.absent(),
                Value<int?> investCostCents = const Value.absent(),
                Value<int?> investMarketValueCents = const Value.absent(),
                Value<double?> investReturnYtd = const Value.absent(),
                Value<int?> fixedPrincipalCents = const Value.absent(),
                Value<DateTime?> fixedStartDate = const Value.absent(),
                Value<DateTime?> fixedMaturityDate = const Value.absent(),
                Value<int?> fixedTermMonths = const Value.absent(),
                required String goldProductType,
                Value<double?> goldQuantity = const Value.absent(),
                Value<int?> goldBuyPriceCents = const Value.absent(),
                Value<int?> goldCurrentPriceCents = const Value.absent(),
                Value<int?> estatePurchasePriceCents = const Value.absent(),
                Value<int?> estateCurrentValueCents = const Value.absent(),
                Value<DateTime?> estatePurchaseDate = const Value.absent(),
                Value<double?> estateDepreciationRate = const Value.absent(),
                Value<int?> loanOriginalCents = const Value.absent(),
                Value<int?> loanRemainingCents = const Value.absent(),
                Value<int?> loanMonthlyCents = const Value.absent(),
                Value<DateTime?> loanNextPaymentDate = const Value.absent(),
                required int status,
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => AccountsCompanion.insert(
                id: id,
                name: name,
                accountType: accountType,
                category: category,
                currencyCode: currencyCode,
                initialBalanceCents: initialBalanceCents,
                currentBalanceCents: currentBalanceCents,
                ownership: ownership,
                icon: icon,
                color: color,
                chartCode: chartCode,
                parentId: parentId,
                isSystem: isSystem,
                sortOrder: sortOrder,
                institution: institution,
                creditLimitCents: creditLimitCents,
                cardNumberTail: cardNumberTail,
                notes: notes,
                openingDate: openingDate,
                interestRate: interestRate,
                creditBillingDay: creditBillingDay,
                creditRepaymentDay: creditRepaymentDay,
                creditAnnualFeeCents: creditAnnualFeeCents,
                investCostCents: investCostCents,
                investMarketValueCents: investMarketValueCents,
                investReturnYtd: investReturnYtd,
                fixedPrincipalCents: fixedPrincipalCents,
                fixedStartDate: fixedStartDate,
                fixedMaturityDate: fixedMaturityDate,
                fixedTermMonths: fixedTermMonths,
                goldProductType: goldProductType,
                goldQuantity: goldQuantity,
                goldBuyPriceCents: goldBuyPriceCents,
                goldCurrentPriceCents: goldCurrentPriceCents,
                estatePurchasePriceCents: estatePurchasePriceCents,
                estateCurrentValueCents: estateCurrentValueCents,
                estatePurchaseDate: estatePurchaseDate,
                estateDepreciationRate: estateDepreciationRate,
                loanOriginalCents: loanOriginalCents,
                loanRemainingCents: loanRemainingCents,
                loanMonthlyCents: loanMonthlyCents,
                loanNextPaymentDate: loanNextPaymentDate,
                status: status,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AccountsTable,
      Account,
      $$AccountsTableFilterComposer,
      $$AccountsTableOrderingComposer,
      $$AccountsTableAnnotationComposer,
      $$AccountsTableCreateCompanionBuilder,
      $$AccountsTableUpdateCompanionBuilder,
      (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
      Account,
      PrefetchHooks Function()
    >;
typedef $$ChartOfAccountsTableCreateCompanionBuilder =
    ChartOfAccountsCompanion Function({
      required String code,
      required String name,
      required int level,
      required int accountType,
      required String parentCode,
      required int balanceDirection,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ChartOfAccountsTableUpdateCompanionBuilder =
    ChartOfAccountsCompanion Function({
      Value<String> code,
      Value<String> name,
      Value<int> level,
      Value<int> accountType,
      Value<String> parentCode,
      Value<int> balanceDirection,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ChartOfAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $ChartOfAccountsTable> {
  $$ChartOfAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get parentCode => $composableBuilder(
    column: $table.parentCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get balanceDirection => $composableBuilder(
    column: $table.balanceDirection,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChartOfAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $ChartOfAccountsTable> {
  $$ChartOfAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get parentCode => $composableBuilder(
    column: $table.parentCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get balanceDirection => $composableBuilder(
    column: $table.balanceDirection,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChartOfAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChartOfAccountsTable> {
  $$ChartOfAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<int> get accountType => $composableBuilder(
    column: $table.accountType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get parentCode => $composableBuilder(
    column: $table.parentCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get balanceDirection => $composableBuilder(
    column: $table.balanceDirection,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ChartOfAccountsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChartOfAccountsTable,
          ChartOfAccount,
          $$ChartOfAccountsTableFilterComposer,
          $$ChartOfAccountsTableOrderingComposer,
          $$ChartOfAccountsTableAnnotationComposer,
          $$ChartOfAccountsTableCreateCompanionBuilder,
          $$ChartOfAccountsTableUpdateCompanionBuilder,
          (
            ChartOfAccount,
            BaseReferences<
              _$AppDatabase,
              $ChartOfAccountsTable,
              ChartOfAccount
            >,
          ),
          ChartOfAccount,
          PrefetchHooks Function()
        > {
  $$ChartOfAccountsTableTableManager(
    _$AppDatabase db,
    $ChartOfAccountsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChartOfAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChartOfAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChartOfAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> level = const Value.absent(),
                Value<int> accountType = const Value.absent(),
                Value<String> parentCode = const Value.absent(),
                Value<int> balanceDirection = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChartOfAccountsCompanion(
                code: code,
                name: name,
                level: level,
                accountType: accountType,
                parentCode: parentCode,
                balanceDirection: balanceDirection,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String code,
                required String name,
                required int level,
                required int accountType,
                required String parentCode,
                required int balanceDirection,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ChartOfAccountsCompanion.insert(
                code: code,
                name: name,
                level: level,
                accountType: accountType,
                parentCode: parentCode,
                balanceDirection: balanceDirection,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChartOfAccountsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChartOfAccountsTable,
      ChartOfAccount,
      $$ChartOfAccountsTableFilterComposer,
      $$ChartOfAccountsTableOrderingComposer,
      $$ChartOfAccountsTableAnnotationComposer,
      $$ChartOfAccountsTableCreateCompanionBuilder,
      $$ChartOfAccountsTableUpdateCompanionBuilder,
      (
        ChartOfAccount,
        BaseReferences<_$AppDatabase, $ChartOfAccountsTable, ChartOfAccount>,
      ),
      ChartOfAccount,
      PrefetchHooks Function()
    >;
typedef $$TransactionsTableCreateCompanionBuilder =
    TransactionsCompanion Function({
      required String id,
      required DateTime transactionDate,
      Value<DateTime?> transactionTime,
      required String description,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TransactionsTableUpdateCompanionBuilder =
    TransactionsCompanion Function({
      Value<String> id,
      Value<DateTime> transactionDate,
      Value<DateTime?> transactionTime,
      Value<String> description,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TransactionsTableReferences
    extends BaseReferences<_$AppDatabase, $TransactionsTable, Transaction> {
  $$TransactionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionEntriesTable, List<TransactionEntry>>
  _transactionEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.transactionEntries,
        aliasName: $_aliasNameGenerator(
          db.transactions.id,
          db.transactionEntries.transactionId,
        ),
      );

  $$TransactionEntriesTableProcessedTableManager get transactionEntriesRefs {
    final manager = $$TransactionEntriesTableTableManager(
      $_db,
      $_db.transactionEntries,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TransactionTagsTable, List<TransactionTag>>
  _transactionTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactionTags,
    aliasName: $_aliasNameGenerator(
      db.transactions.id,
      db.transactionTags.transactionId,
    ),
  );

  $$TransactionTagsTableProcessedTableManager get transactionTagsRefs {
    final manager = $$TransactionTagsTableTableManager(
      $_db,
      $_db.transactionTags,
    ).filter((f) => f.transactionId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionTagsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get transactionTime => $composableBuilder(
    column: $table.transactionTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionEntriesRefs(
    Expression<bool> Function($$TransactionEntriesTableFilterComposer f) f,
  ) {
    final $$TransactionEntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionEntries,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionEntriesTableFilterComposer(
            $db: $db,
            $table: $db.transactionEntries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> transactionTagsRefs(
    Expression<bool> Function($$TransactionTagsTableFilterComposer f) f,
  ) {
    final $$TransactionTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionTags,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionTagsTableFilterComposer(
            $db: $db,
            $table: $db.transactionTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get transactionTime => $composableBuilder(
    column: $table.transactionTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get transactionDate => $composableBuilder(
    column: $table.transactionDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get transactionTime => $composableBuilder(
    column: $table.transactionTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> transactionEntriesRefs<T extends Object>(
    Expression<T> Function($$TransactionEntriesTableAnnotationComposer a) f,
  ) {
    final $$TransactionEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.transactionEntries,
          getReferencedColumn: (t) => t.transactionId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TransactionEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.transactionEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> transactionTagsRefs<T extends Object>(
    Expression<T> Function($$TransactionTagsTableAnnotationComposer a) f,
  ) {
    final $$TransactionTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionTags,
      getReferencedColumn: (t) => t.transactionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactionTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionsTable,
          Transaction,
          $$TransactionsTableFilterComposer,
          $$TransactionsTableOrderingComposer,
          $$TransactionsTableAnnotationComposer,
          $$TransactionsTableCreateCompanionBuilder,
          $$TransactionsTableUpdateCompanionBuilder,
          (Transaction, $$TransactionsTableReferences),
          Transaction,
          PrefetchHooks Function({
            bool transactionEntriesRefs,
            bool transactionTagsRefs,
          })
        > {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DateTime> transactionDate = const Value.absent(),
                Value<DateTime?> transactionTime = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion(
                id: id,
                transactionDate: transactionDate,
                transactionTime: transactionTime,
                description: description,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DateTime transactionDate,
                Value<DateTime?> transactionTime = const Value.absent(),
                required String description,
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TransactionsCompanion.insert(
                id: id,
                transactionDate: transactionDate,
                transactionTime: transactionTime,
                description: description,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({transactionEntriesRefs = false, transactionTagsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (transactionEntriesRefs) db.transactionEntries,
                    if (transactionTagsRefs) db.transactionTags,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (transactionEntriesRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          TransactionEntry
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._transactionEntriesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionEntriesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (transactionTagsRefs)
                        await $_getPrefetchedData<
                          Transaction,
                          $TransactionsTable,
                          TransactionTag
                        >(
                          currentTable: table,
                          referencedTable: $$TransactionsTableReferences
                              ._transactionTagsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TransactionsTableReferences(
                                db,
                                table,
                                p0,
                              ).transactionTagsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.transactionId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionsTable,
      Transaction,
      $$TransactionsTableFilterComposer,
      $$TransactionsTableOrderingComposer,
      $$TransactionsTableAnnotationComposer,
      $$TransactionsTableCreateCompanionBuilder,
      $$TransactionsTableUpdateCompanionBuilder,
      (Transaction, $$TransactionsTableReferences),
      Transaction,
      PrefetchHooks Function({
        bool transactionEntriesRefs,
        bool transactionTagsRefs,
      })
    >;
typedef $$TransactionEntriesTableCreateCompanionBuilder =
    TransactionEntriesCompanion Function({
      required String id,
      required String transactionId,
      required String accountId,
      required String chartOfAccountCode,
      required int debitCents,
      required int creditCents,
      required String note,
      Value<int> rowid,
    });
typedef $$TransactionEntriesTableUpdateCompanionBuilder =
    TransactionEntriesCompanion Function({
      Value<String> id,
      Value<String> transactionId,
      Value<String> accountId,
      Value<String> chartOfAccountCode,
      Value<int> debitCents,
      Value<int> creditCents,
      Value<String> note,
      Value<int> rowid,
    });

final class $$TransactionEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $TransactionEntriesTable,
          TransactionEntry
        > {
  $$TransactionEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.transactionEntries.transactionId,
          db.transactions.id,
        ),
      );

  $$TransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<String>('transaction_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionEntriesTable> {
  $$TransactionEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get chartOfAccountCode => $composableBuilder(
    column: $table.chartOfAccountCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get debitCents => $composableBuilder(
    column: $table.debitCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get creditCents => $composableBuilder(
    column: $table.creditCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionEntriesTable> {
  $$TransactionEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get chartOfAccountCode => $composableBuilder(
    column: $table.chartOfAccountCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get debitCents => $composableBuilder(
    column: $table.debitCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get creditCents => $composableBuilder(
    column: $table.creditCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionEntriesTable> {
  $$TransactionEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get chartOfAccountCode => $composableBuilder(
    column: $table.chartOfAccountCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get debitCents => $composableBuilder(
    column: $table.debitCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get creditCents => $composableBuilder(
    column: $table.creditCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionEntriesTable,
          TransactionEntry,
          $$TransactionEntriesTableFilterComposer,
          $$TransactionEntriesTableOrderingComposer,
          $$TransactionEntriesTableAnnotationComposer,
          $$TransactionEntriesTableCreateCompanionBuilder,
          $$TransactionEntriesTableUpdateCompanionBuilder,
          (TransactionEntry, $$TransactionEntriesTableReferences),
          TransactionEntry,
          PrefetchHooks Function({bool transactionId})
        > {
  $$TransactionEntriesTableTableManager(
    _$AppDatabase db,
    $TransactionEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> transactionId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> chartOfAccountCode = const Value.absent(),
                Value<int> debitCents = const Value.absent(),
                Value<int> creditCents = const Value.absent(),
                Value<String> note = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionEntriesCompanion(
                id: id,
                transactionId: transactionId,
                accountId: accountId,
                chartOfAccountCode: chartOfAccountCode,
                debitCents: debitCents,
                creditCents: creditCents,
                note: note,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String transactionId,
                required String accountId,
                required String chartOfAccountCode,
                required int debitCents,
                required int creditCents,
                required String note,
                Value<int> rowid = const Value.absent(),
              }) => TransactionEntriesCompanion.insert(
                id: id,
                transactionId: transactionId,
                accountId: accountId,
                chartOfAccountCode: chartOfAccountCode,
                debitCents: debitCents,
                creditCents: creditCents,
                note: note,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transactionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transactionId,
                                referencedTable:
                                    $$TransactionEntriesTableReferences
                                        ._transactionIdTable(db),
                                referencedColumn:
                                    $$TransactionEntriesTableReferences
                                        ._transactionIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransactionEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionEntriesTable,
      TransactionEntry,
      $$TransactionEntriesTableFilterComposer,
      $$TransactionEntriesTableOrderingComposer,
      $$TransactionEntriesTableAnnotationComposer,
      $$TransactionEntriesTableCreateCompanionBuilder,
      $$TransactionEntriesTableUpdateCompanionBuilder,
      (TransactionEntry, $$TransactionEntriesTableReferences),
      TransactionEntry,
      PrefetchHooks Function({bool transactionId})
    >;
typedef $$DebtsTableCreateCompanionBuilder =
    DebtsCompanion Function({
      required String id,
      required String accountId,
      required String counterparty,
      required double interestRate,
      required int amortizationMethod,
      required DateTime startDate,
      required DateTime dueDate,
      required int totalPrincipalCents,
      required int debtType,
      required String subtype,
      required String contact,
      required String contractRef,
      Value<String?> collectionAccountId,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DebtsTableUpdateCompanionBuilder =
    DebtsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> counterparty,
      Value<double> interestRate,
      Value<int> amortizationMethod,
      Value<DateTime> startDate,
      Value<DateTime> dueDate,
      Value<int> totalPrincipalCents,
      Value<int> debtType,
      Value<String> subtype,
      Value<String> contact,
      Value<String> contractRef,
      Value<String?> collectionAccountId,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$DebtsTableReferences
    extends BaseReferences<_$AppDatabase, $DebtsTable, Debt> {
  $$DebtsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<
    $PaymentScheduleEntriesTable,
    List<PaymentScheduleEntry>
  >
  _paymentScheduleEntriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.paymentScheduleEntries,
        aliasName: $_aliasNameGenerator(
          db.debts.id,
          db.paymentScheduleEntries.debtId,
        ),
      );

  $$PaymentScheduleEntriesTableProcessedTableManager
  get paymentScheduleEntriesRefs {
    final manager = $$PaymentScheduleEntriesTableTableManager(
      $_db,
      $_db.paymentScheduleEntries,
    ).filter((f) => f.debtId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _paymentScheduleEntriesRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DebtsTableFilterComposer extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get interestRate => $composableBuilder(
    column: $table.interestRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amortizationMethod => $composableBuilder(
    column: $table.amortizationMethod,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPrincipalCents => $composableBuilder(
    column: $table.totalPrincipalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get debtType => $composableBuilder(
    column: $table.debtType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contact => $composableBuilder(
    column: $table.contact,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contractRef => $composableBuilder(
    column: $table.contractRef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get collectionAccountId => $composableBuilder(
    column: $table.collectionAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> paymentScheduleEntriesRefs(
    Expression<bool> Function($$PaymentScheduleEntriesTableFilterComposer f) f,
  ) {
    final $$PaymentScheduleEntriesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.paymentScheduleEntries,
          getReferencedColumn: (t) => t.debtId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PaymentScheduleEntriesTableFilterComposer(
                $db: $db,
                $table: $db.paymentScheduleEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DebtsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get interestRate => $composableBuilder(
    column: $table.interestRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amortizationMethod => $composableBuilder(
    column: $table.amortizationMethod,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPrincipalCents => $composableBuilder(
    column: $table.totalPrincipalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get debtType => $composableBuilder(
    column: $table.debtType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subtype => $composableBuilder(
    column: $table.subtype,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contact => $composableBuilder(
    column: $table.contact,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contractRef => $composableBuilder(
    column: $table.contractRef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get collectionAccountId => $composableBuilder(
    column: $table.collectionAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DebtsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtsTable> {
  $$DebtsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get counterparty => $composableBuilder(
    column: $table.counterparty,
    builder: (column) => column,
  );

  GeneratedColumn<double> get interestRate => $composableBuilder(
    column: $table.interestRate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amortizationMethod => $composableBuilder(
    column: $table.amortizationMethod,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<int> get totalPrincipalCents => $composableBuilder(
    column: $table.totalPrincipalCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get debtType =>
      $composableBuilder(column: $table.debtType, builder: (column) => column);

  GeneratedColumn<String> get subtype =>
      $composableBuilder(column: $table.subtype, builder: (column) => column);

  GeneratedColumn<String> get contact =>
      $composableBuilder(column: $table.contact, builder: (column) => column);

  GeneratedColumn<String> get contractRef => $composableBuilder(
    column: $table.contractRef,
    builder: (column) => column,
  );

  GeneratedColumn<String> get collectionAccountId => $composableBuilder(
    column: $table.collectionAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> paymentScheduleEntriesRefs<T extends Object>(
    Expression<T> Function($$PaymentScheduleEntriesTableAnnotationComposer a) f,
  ) {
    final $$PaymentScheduleEntriesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.paymentScheduleEntries,
          getReferencedColumn: (t) => t.debtId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$PaymentScheduleEntriesTableAnnotationComposer(
                $db: $db,
                $table: $db.paymentScheduleEntries,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$DebtsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebtsTable,
          Debt,
          $$DebtsTableFilterComposer,
          $$DebtsTableOrderingComposer,
          $$DebtsTableAnnotationComposer,
          $$DebtsTableCreateCompanionBuilder,
          $$DebtsTableUpdateCompanionBuilder,
          (Debt, $$DebtsTableReferences),
          Debt,
          PrefetchHooks Function({bool paymentScheduleEntriesRefs})
        > {
  $$DebtsTableTableManager(_$AppDatabase db, $DebtsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DebtsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DebtsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> counterparty = const Value.absent(),
                Value<double> interestRate = const Value.absent(),
                Value<int> amortizationMethod = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime> dueDate = const Value.absent(),
                Value<int> totalPrincipalCents = const Value.absent(),
                Value<int> debtType = const Value.absent(),
                Value<String> subtype = const Value.absent(),
                Value<String> contact = const Value.absent(),
                Value<String> contractRef = const Value.absent(),
                Value<String?> collectionAccountId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtsCompanion(
                id: id,
                accountId: accountId,
                counterparty: counterparty,
                interestRate: interestRate,
                amortizationMethod: amortizationMethod,
                startDate: startDate,
                dueDate: dueDate,
                totalPrincipalCents: totalPrincipalCents,
                debtType: debtType,
                subtype: subtype,
                contact: contact,
                contractRef: contractRef,
                collectionAccountId: collectionAccountId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String counterparty,
                required double interestRate,
                required int amortizationMethod,
                required DateTime startDate,
                required DateTime dueDate,
                required int totalPrincipalCents,
                required int debtType,
                required String subtype,
                required String contact,
                required String contractRef,
                Value<String?> collectionAccountId = const Value.absent(),
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DebtsCompanion.insert(
                id: id,
                accountId: accountId,
                counterparty: counterparty,
                interestRate: interestRate,
                amortizationMethod: amortizationMethod,
                startDate: startDate,
                dueDate: dueDate,
                totalPrincipalCents: totalPrincipalCents,
                debtType: debtType,
                subtype: subtype,
                contact: contact,
                contractRef: contractRef,
                collectionAccountId: collectionAccountId,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$DebtsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({paymentScheduleEntriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (paymentScheduleEntriesRefs) db.paymentScheduleEntries,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (paymentScheduleEntriesRefs)
                    await $_getPrefetchedData<
                      Debt,
                      $DebtsTable,
                      PaymentScheduleEntry
                    >(
                      currentTable: table,
                      referencedTable: $$DebtsTableReferences
                          ._paymentScheduleEntriesRefsTable(db),
                      managerFromTypedResult: (p0) => $$DebtsTableReferences(
                        db,
                        table,
                        p0,
                      ).paymentScheduleEntriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.debtId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$DebtsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebtsTable,
      Debt,
      $$DebtsTableFilterComposer,
      $$DebtsTableOrderingComposer,
      $$DebtsTableAnnotationComposer,
      $$DebtsTableCreateCompanionBuilder,
      $$DebtsTableUpdateCompanionBuilder,
      (Debt, $$DebtsTableReferences),
      Debt,
      PrefetchHooks Function({bool paymentScheduleEntriesRefs})
    >;
typedef $$PaymentScheduleEntriesTableCreateCompanionBuilder =
    PaymentScheduleEntriesCompanion Function({
      required String id,
      required String debtId,
      required DateTime paymentDate,
      required int principalCents,
      required int interestCents,
      required int totalCents,
      required int paidCents,
      required bool paid,
      Value<String?> transactionId,
      Value<int> rowid,
    });
typedef $$PaymentScheduleEntriesTableUpdateCompanionBuilder =
    PaymentScheduleEntriesCompanion Function({
      Value<String> id,
      Value<String> debtId,
      Value<DateTime> paymentDate,
      Value<int> principalCents,
      Value<int> interestCents,
      Value<int> totalCents,
      Value<int> paidCents,
      Value<bool> paid,
      Value<String?> transactionId,
      Value<int> rowid,
    });

final class $$PaymentScheduleEntriesTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $PaymentScheduleEntriesTable,
          PaymentScheduleEntry
        > {
  $$PaymentScheduleEntriesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DebtsTable _debtIdTable(_$AppDatabase db) => db.debts.createAlias(
    $_aliasNameGenerator(db.paymentScheduleEntries.debtId, db.debts.id),
  );

  $$DebtsTableProcessedTableManager get debtId {
    final $_column = $_itemColumn<String>('debt_id')!;

    final manager = $$DebtsTableTableManager(
      $_db,
      $_db.debts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_debtIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PaymentScheduleEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PaymentScheduleEntriesTable> {
  $$PaymentScheduleEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get paymentDate => $composableBuilder(
    column: $table.paymentDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get principalCents => $composableBuilder(
    column: $table.principalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get interestCents => $composableBuilder(
    column: $table.interestCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidCents => $composableBuilder(
    column: $table.paidCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnFilters(column),
  );

  $$DebtsTableFilterComposer get debtId {
    final $$DebtsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtId,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableFilterComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentScheduleEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PaymentScheduleEntriesTable> {
  $$PaymentScheduleEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get paymentDate => $composableBuilder(
    column: $table.paymentDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get principalCents => $composableBuilder(
    column: $table.principalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get interestCents => $composableBuilder(
    column: $table.interestCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidCents => $composableBuilder(
    column: $table.paidCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get paid => $composableBuilder(
    column: $table.paid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnOrderings(column),
  );

  $$DebtsTableOrderingComposer get debtId {
    final $$DebtsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtId,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableOrderingComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentScheduleEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PaymentScheduleEntriesTable> {
  $$PaymentScheduleEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get paymentDate => $composableBuilder(
    column: $table.paymentDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get principalCents => $composableBuilder(
    column: $table.principalCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get interestCents => $composableBuilder(
    column: $table.interestCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalCents => $composableBuilder(
    column: $table.totalCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paidCents =>
      $composableBuilder(column: $table.paidCents, builder: (column) => column);

  GeneratedColumn<bool> get paid =>
      $composableBuilder(column: $table.paid, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => column,
  );

  $$DebtsTableAnnotationComposer get debtId {
    final $$DebtsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.debtId,
      referencedTable: $db.debts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DebtsTableAnnotationComposer(
            $db: $db,
            $table: $db.debts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PaymentScheduleEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PaymentScheduleEntriesTable,
          PaymentScheduleEntry,
          $$PaymentScheduleEntriesTableFilterComposer,
          $$PaymentScheduleEntriesTableOrderingComposer,
          $$PaymentScheduleEntriesTableAnnotationComposer,
          $$PaymentScheduleEntriesTableCreateCompanionBuilder,
          $$PaymentScheduleEntriesTableUpdateCompanionBuilder,
          (PaymentScheduleEntry, $$PaymentScheduleEntriesTableReferences),
          PaymentScheduleEntry,
          PrefetchHooks Function({bool debtId})
        > {
  $$PaymentScheduleEntriesTableTableManager(
    _$AppDatabase db,
    $PaymentScheduleEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PaymentScheduleEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PaymentScheduleEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PaymentScheduleEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> debtId = const Value.absent(),
                Value<DateTime> paymentDate = const Value.absent(),
                Value<int> principalCents = const Value.absent(),
                Value<int> interestCents = const Value.absent(),
                Value<int> totalCents = const Value.absent(),
                Value<int> paidCents = const Value.absent(),
                Value<bool> paid = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentScheduleEntriesCompanion(
                id: id,
                debtId: debtId,
                paymentDate: paymentDate,
                principalCents: principalCents,
                interestCents: interestCents,
                totalCents: totalCents,
                paidCents: paidCents,
                paid: paid,
                transactionId: transactionId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String debtId,
                required DateTime paymentDate,
                required int principalCents,
                required int interestCents,
                required int totalCents,
                required int paidCents,
                required bool paid,
                Value<String?> transactionId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PaymentScheduleEntriesCompanion.insert(
                id: id,
                debtId: debtId,
                paymentDate: paymentDate,
                principalCents: principalCents,
                interestCents: interestCents,
                totalCents: totalCents,
                paidCents: paidCents,
                paid: paid,
                transactionId: transactionId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PaymentScheduleEntriesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({debtId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (debtId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.debtId,
                                referencedTable:
                                    $$PaymentScheduleEntriesTableReferences
                                        ._debtIdTable(db),
                                referencedColumn:
                                    $$PaymentScheduleEntriesTableReferences
                                        ._debtIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PaymentScheduleEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PaymentScheduleEntriesTable,
      PaymentScheduleEntry,
      $$PaymentScheduleEntriesTableFilterComposer,
      $$PaymentScheduleEntriesTableOrderingComposer,
      $$PaymentScheduleEntriesTableAnnotationComposer,
      $$PaymentScheduleEntriesTableCreateCompanionBuilder,
      $$PaymentScheduleEntriesTableUpdateCompanionBuilder,
      (PaymentScheduleEntry, $$PaymentScheduleEntriesTableReferences),
      PaymentScheduleEntry,
      PrefetchHooks Function({bool debtId})
    >;
typedef $$ReminderLogsTableCreateCompanionBuilder =
    ReminderLogsCompanion Function({
      Value<int> id,
      required String entryId,
      required int tier,
      required String sentDate,
    });
typedef $$ReminderLogsTableUpdateCompanionBuilder =
    ReminderLogsCompanion Function({
      Value<int> id,
      Value<String> entryId,
      Value<int> tier,
      Value<String> sentDate,
    });

class $$ReminderLogsTableFilterComposer
    extends Composer<_$AppDatabase, $ReminderLogsTable> {
  $$ReminderLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sentDate => $composableBuilder(
    column: $table.sentDate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReminderLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReminderLogsTable> {
  $$ReminderLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entryId => $composableBuilder(
    column: $table.entryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sentDate => $composableBuilder(
    column: $table.sentDate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReminderLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReminderLogsTable> {
  $$ReminderLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entryId =>
      $composableBuilder(column: $table.entryId, builder: (column) => column);

  GeneratedColumn<int> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get sentDate =>
      $composableBuilder(column: $table.sentDate, builder: (column) => column);
}

class $$ReminderLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReminderLogsTable,
          ReminderLog,
          $$ReminderLogsTableFilterComposer,
          $$ReminderLogsTableOrderingComposer,
          $$ReminderLogsTableAnnotationComposer,
          $$ReminderLogsTableCreateCompanionBuilder,
          $$ReminderLogsTableUpdateCompanionBuilder,
          (
            ReminderLog,
            BaseReferences<_$AppDatabase, $ReminderLogsTable, ReminderLog>,
          ),
          ReminderLog,
          PrefetchHooks Function()
        > {
  $$ReminderLogsTableTableManager(_$AppDatabase db, $ReminderLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReminderLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> entryId = const Value.absent(),
                Value<int> tier = const Value.absent(),
                Value<String> sentDate = const Value.absent(),
              }) => ReminderLogsCompanion(
                id: id,
                entryId: entryId,
                tier: tier,
                sentDate: sentDate,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String entryId,
                required int tier,
                required String sentDate,
              }) => ReminderLogsCompanion.insert(
                id: id,
                entryId: entryId,
                tier: tier,
                sentDate: sentDate,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReminderLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReminderLogsTable,
      ReminderLog,
      $$ReminderLogsTableFilterComposer,
      $$ReminderLogsTableOrderingComposer,
      $$ReminderLogsTableAnnotationComposer,
      $$ReminderLogsTableCreateCompanionBuilder,
      $$ReminderLogsTableUpdateCompanionBuilder,
      (
        ReminderLog,
        BaseReferences<_$AppDatabase, $ReminderLogsTable, ReminderLog>,
      ),
      ReminderLog,
      PrefetchHooks Function()
    >;
typedef $$BudgetsTableCreateCompanionBuilder =
    BudgetsCompanion Function({
      required String id,
      required String name,
      required String month,
      required int totalAmountCents,
      required String currencyCode,
      required bool isActive,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$BudgetsTableUpdateCompanionBuilder =
    BudgetsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> month,
      Value<int> totalAmountCents,
      Value<String> currencyCode,
      Value<bool> isActive,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$BudgetsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetsTable, Budget> {
  $$BudgetsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$BudgetItemsTable, List<BudgetItem>>
  _budgetItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.budgetItems,
    aliasName: $_aliasNameGenerator(db.budgets.id, db.budgetItems.budgetId),
  );

  $$BudgetItemsTableProcessedTableManager get budgetItemsRefs {
    final manager = $$BudgetItemsTableTableManager(
      $_db,
      $_db.budgetItems,
    ).filter((f) => f.budgetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_budgetItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalAmountCents => $composableBuilder(
    column: $table.totalAmountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> budgetItemsRefs(
    Expression<bool> Function($$BudgetItemsTableFilterComposer f) f,
  ) {
    final $$BudgetItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetItems,
      getReferencedColumn: (t) => t.budgetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetItemsTableFilterComposer(
            $db: $db,
            $table: $db.budgetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalAmountCents => $composableBuilder(
    column: $table.totalAmountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<int> get totalAmountCents => $composableBuilder(
    column: $table.totalAmountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> budgetItemsRefs<T extends Object>(
    Expression<T> Function($$BudgetItemsTableAnnotationComposer a) f,
  ) {
    final $$BudgetItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.budgetItems,
      getReferencedColumn: (t) => t.budgetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgetItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          Budget,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (Budget, $$BudgetsTableReferences),
          Budget,
          PrefetchHooks Function({bool budgetItemsRefs})
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<int> totalAmountCents = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                id: id,
                name: name,
                month: month,
                totalAmountCents: totalAmountCents,
                currencyCode: currencyCode,
                isActive: isActive,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String month,
                required int totalAmountCents,
                required String currencyCode,
                required bool isActive,
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                id: id,
                name: name,
                month: month,
                totalAmountCents: totalAmountCents,
                currencyCode: currencyCode,
                isActive: isActive,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BudgetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({budgetItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (budgetItemsRefs) db.budgetItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (budgetItemsRefs)
                    await $_getPrefetchedData<
                      Budget,
                      $BudgetsTable,
                      BudgetItem
                    >(
                      currentTable: table,
                      referencedTable: $$BudgetsTableReferences
                          ._budgetItemsRefsTable(db),
                      managerFromTypedResult: (p0) => $$BudgetsTableReferences(
                        db,
                        table,
                        p0,
                      ).budgetItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.budgetId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      Budget,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (Budget, $$BudgetsTableReferences),
      Budget,
      PrefetchHooks Function({bool budgetItemsRefs})
    >;
typedef $$BudgetItemsTableCreateCompanionBuilder =
    BudgetItemsCompanion Function({
      required String id,
      required String budgetId,
      required String accountId,
      required int plannedAmountCents,
      required int actualAmountCents,
      required String notes,
      Value<int> rowid,
    });
typedef $$BudgetItemsTableUpdateCompanionBuilder =
    BudgetItemsCompanion Function({
      Value<String> id,
      Value<String> budgetId,
      Value<String> accountId,
      Value<int> plannedAmountCents,
      Value<int> actualAmountCents,
      Value<String> notes,
      Value<int> rowid,
    });

final class $$BudgetItemsTableReferences
    extends BaseReferences<_$AppDatabase, $BudgetItemsTable, BudgetItem> {
  $$BudgetItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BudgetsTable _budgetIdTable(_$AppDatabase db) =>
      db.budgets.createAlias(
        $_aliasNameGenerator(db.budgetItems.budgetId, db.budgets.id),
      );

  $$BudgetsTableProcessedTableManager get budgetId {
    final $_column = $_itemColumn<String>('budget_id')!;

    final manager = $$BudgetsTableTableManager(
      $_db,
      $_db.budgets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_budgetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$BudgetItemsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetItemsTable> {
  $$BudgetItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get plannedAmountCents => $composableBuilder(
    column: $table.plannedAmountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualAmountCents => $composableBuilder(
    column: $table.actualAmountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$BudgetsTableFilterComposer get budgetId {
    final $$BudgetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.budgetId,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableFilterComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetItemsTable> {
  $$BudgetItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get plannedAmountCents => $composableBuilder(
    column: $table.plannedAmountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualAmountCents => $composableBuilder(
    column: $table.actualAmountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$BudgetsTableOrderingComposer get budgetId {
    final $$BudgetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.budgetId,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableOrderingComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetItemsTable> {
  $$BudgetItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get plannedAmountCents => $composableBuilder(
    column: $table.plannedAmountCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualAmountCents => $composableBuilder(
    column: $table.actualAmountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$BudgetsTableAnnotationComposer get budgetId {
    final $$BudgetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.budgetId,
      referencedTable: $db.budgets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BudgetsTableAnnotationComposer(
            $db: $db,
            $table: $db.budgets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$BudgetItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetItemsTable,
          BudgetItem,
          $$BudgetItemsTableFilterComposer,
          $$BudgetItemsTableOrderingComposer,
          $$BudgetItemsTableAnnotationComposer,
          $$BudgetItemsTableCreateCompanionBuilder,
          $$BudgetItemsTableUpdateCompanionBuilder,
          (BudgetItem, $$BudgetItemsTableReferences),
          BudgetItem,
          PrefetchHooks Function({bool budgetId})
        > {
  $$BudgetItemsTableTableManager(_$AppDatabase db, $BudgetItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> budgetId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<int> plannedAmountCents = const Value.absent(),
                Value<int> actualAmountCents = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetItemsCompanion(
                id: id,
                budgetId: budgetId,
                accountId: accountId,
                plannedAmountCents: plannedAmountCents,
                actualAmountCents: actualAmountCents,
                notes: notes,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String budgetId,
                required String accountId,
                required int plannedAmountCents,
                required int actualAmountCents,
                required String notes,
                Value<int> rowid = const Value.absent(),
              }) => BudgetItemsCompanion.insert(
                id: id,
                budgetId: budgetId,
                accountId: accountId,
                plannedAmountCents: plannedAmountCents,
                actualAmountCents: actualAmountCents,
                notes: notes,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BudgetItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({budgetId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (budgetId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.budgetId,
                                referencedTable: $$BudgetItemsTableReferences
                                    ._budgetIdTable(db),
                                referencedColumn: $$BudgetItemsTableReferences
                                    ._budgetIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$BudgetItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetItemsTable,
      BudgetItem,
      $$BudgetItemsTableFilterComposer,
      $$BudgetItemsTableOrderingComposer,
      $$BudgetItemsTableAnnotationComposer,
      $$BudgetItemsTableCreateCompanionBuilder,
      $$BudgetItemsTableUpdateCompanionBuilder,
      (BudgetItem, $$BudgetItemsTableReferences),
      BudgetItem,
      PrefetchHooks Function({bool budgetId})
    >;
typedef $$GoalsTableCreateCompanionBuilder =
    GoalsCompanion Function({
      required String id,
      required String name,
      required int goalType,
      required int targetAmountCents,
      required int currentAmountCents,
      required String currencyCode,
      Value<DateTime?> deadline,
      required String notes,
      required bool isCompleted,
      Value<DateTime?> completedAt,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$GoalsTableUpdateCompanionBuilder =
    GoalsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> goalType,
      Value<int> targetAmountCents,
      Value<int> currentAmountCents,
      Value<String> currencyCode,
      Value<DateTime?> deadline,
      Value<String> notes,
      Value<bool> isCompleted,
      Value<DateTime?> completedAt,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$GoalsTableReferences
    extends BaseReferences<_$AppDatabase, $GoalsTable, Goal> {
  $$GoalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GoalAccountLinksTable, List<GoalAccountLink>>
  _goalAccountLinksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.goalAccountLinks,
    aliasName: $_aliasNameGenerator(db.goals.id, db.goalAccountLinks.goalId),
  );

  $$GoalAccountLinksTableProcessedTableManager get goalAccountLinksRefs {
    final manager = $$GoalAccountLinksTableTableManager(
      $_db,
      $_db.goalAccountLinks,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _goalAccountLinksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$GoalDebtLinksTable, List<GoalDebtLink>>
  _goalDebtLinksRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.goalDebtLinks,
    aliasName: $_aliasNameGenerator(db.goals.id, db.goalDebtLinks.goalId),
  );

  $$GoalDebtLinksTableProcessedTableManager get goalDebtLinksRefs {
    final manager = $$GoalDebtLinksTableTableManager(
      $_db,
      $_db.goalDebtLinks,
    ).filter((f) => f.goalId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_goalDebtLinksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetAmountCents => $composableBuilder(
    column: $table.targetAmountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentAmountCents => $composableBuilder(
    column: $table.currentAmountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> goalAccountLinksRefs(
    Expression<bool> Function($$GoalAccountLinksTableFilterComposer f) f,
  ) {
    final $$GoalAccountLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalAccountLinks,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalAccountLinksTableFilterComposer(
            $db: $db,
            $table: $db.goalAccountLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> goalDebtLinksRefs(
    Expression<bool> Function($$GoalDebtLinksTableFilterComposer f) f,
  ) {
    final $$GoalDebtLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalDebtLinks,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalDebtLinksTableFilterComposer(
            $db: $db,
            $table: $db.goalDebtLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetAmountCents => $composableBuilder(
    column: $table.targetAmountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentAmountCents => $composableBuilder(
    column: $table.currentAmountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get goalType =>
      $composableBuilder(column: $table.goalType, builder: (column) => column);

  GeneratedColumn<int> get targetAmountCents => $composableBuilder(
    column: $table.targetAmountCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentAmountCents => $composableBuilder(
    column: $table.currentAmountCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
    column: $table.isCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> goalAccountLinksRefs<T extends Object>(
    Expression<T> Function($$GoalAccountLinksTableAnnotationComposer a) f,
  ) {
    final $$GoalAccountLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalAccountLinks,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalAccountLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.goalAccountLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> goalDebtLinksRefs<T extends Object>(
    Expression<T> Function($$GoalDebtLinksTableAnnotationComposer a) f,
  ) {
    final $$GoalDebtLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.goalDebtLinks,
      getReferencedColumn: (t) => t.goalId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalDebtLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.goalDebtLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalsTable,
          Goal,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (Goal, $$GoalsTableReferences),
          Goal,
          PrefetchHooks Function({
            bool goalAccountLinksRefs,
            bool goalDebtLinksRefs,
          })
        > {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> goalType = const Value.absent(),
                Value<int> targetAmountCents = const Value.absent(),
                Value<int> currentAmountCents = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<DateTime?> deadline = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<bool> isCompleted = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                name: name,
                goalType: goalType,
                targetAmountCents: targetAmountCents,
                currentAmountCents: currentAmountCents,
                currencyCode: currencyCode,
                deadline: deadline,
                notes: notes,
                isCompleted: isCompleted,
                completedAt: completedAt,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int goalType,
                required int targetAmountCents,
                required int currentAmountCents,
                required String currencyCode,
                Value<DateTime?> deadline = const Value.absent(),
                required String notes,
                required bool isCompleted,
                Value<DateTime?> completedAt = const Value.absent(),
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion.insert(
                id: id,
                name: name,
                goalType: goalType,
                targetAmountCents: targetAmountCents,
                currentAmountCents: currentAmountCents,
                currencyCode: currencyCode,
                deadline: deadline,
                notes: notes,
                isCompleted: isCompleted,
                completedAt: completedAt,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GoalsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({goalAccountLinksRefs = false, goalDebtLinksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (goalAccountLinksRefs) db.goalAccountLinks,
                    if (goalDebtLinksRefs) db.goalDebtLinks,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (goalAccountLinksRefs)
                        await $_getPrefetchedData<
                          Goal,
                          $GoalsTable,
                          GoalAccountLink
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._goalAccountLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(
                                db,
                                table,
                                p0,
                              ).goalAccountLinksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (goalDebtLinksRefs)
                        await $_getPrefetchedData<
                          Goal,
                          $GoalsTable,
                          GoalDebtLink
                        >(
                          currentTable: table,
                          referencedTable: $$GoalsTableReferences
                              ._goalDebtLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$GoalsTableReferences(
                                db,
                                table,
                                p0,
                              ).goalDebtLinksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.goalId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalsTable,
      Goal,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (Goal, $$GoalsTableReferences),
      Goal,
      PrefetchHooks Function({
        bool goalAccountLinksRefs,
        bool goalDebtLinksRefs,
      })
    >;
typedef $$GoalAccountLinksTableCreateCompanionBuilder =
    GoalAccountLinksCompanion Function({
      required String goalId,
      required String linkedId,
      Value<int> rowid,
    });
typedef $$GoalAccountLinksTableUpdateCompanionBuilder =
    GoalAccountLinksCompanion Function({
      Value<String> goalId,
      Value<String> linkedId,
      Value<int> rowid,
    });

final class $$GoalAccountLinksTableReferences
    extends
        BaseReferences<_$AppDatabase, $GoalAccountLinksTable, GoalAccountLink> {
  $$GoalAccountLinksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GoalsTable _goalIdTable(_$AppDatabase db) => db.goals.createAlias(
    $_aliasNameGenerator(db.goalAccountLinks.goalId, db.goals.id),
  );

  $$GoalsTableProcessedTableManager get goalId {
    final $_column = $_itemColumn<String>('goal_id')!;

    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GoalAccountLinksTableFilterComposer
    extends Composer<_$AppDatabase, $GoalAccountLinksTable> {
  $$GoalAccountLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get linkedId => $composableBuilder(
    column: $table.linkedId,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalsTableFilterComposer get goalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalAccountLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalAccountLinksTable> {
  $$GoalAccountLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get linkedId => $composableBuilder(
    column: $table.linkedId,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalsTableOrderingComposer get goalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalAccountLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalAccountLinksTable> {
  $$GoalAccountLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get linkedId =>
      $composableBuilder(column: $table.linkedId, builder: (column) => column);

  $$GoalsTableAnnotationComposer get goalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalAccountLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalAccountLinksTable,
          GoalAccountLink,
          $$GoalAccountLinksTableFilterComposer,
          $$GoalAccountLinksTableOrderingComposer,
          $$GoalAccountLinksTableAnnotationComposer,
          $$GoalAccountLinksTableCreateCompanionBuilder,
          $$GoalAccountLinksTableUpdateCompanionBuilder,
          (GoalAccountLink, $$GoalAccountLinksTableReferences),
          GoalAccountLink,
          PrefetchHooks Function({bool goalId})
        > {
  $$GoalAccountLinksTableTableManager(
    _$AppDatabase db,
    $GoalAccountLinksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalAccountLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalAccountLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalAccountLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> goalId = const Value.absent(),
                Value<String> linkedId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalAccountLinksCompanion(
                goalId: goalId,
                linkedId: linkedId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String goalId,
                required String linkedId,
                Value<int> rowid = const Value.absent(),
              }) => GoalAccountLinksCompanion.insert(
                goalId: goalId,
                linkedId: linkedId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GoalAccountLinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({goalId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (goalId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.goalId,
                                referencedTable:
                                    $$GoalAccountLinksTableReferences
                                        ._goalIdTable(db),
                                referencedColumn:
                                    $$GoalAccountLinksTableReferences
                                        ._goalIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GoalAccountLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalAccountLinksTable,
      GoalAccountLink,
      $$GoalAccountLinksTableFilterComposer,
      $$GoalAccountLinksTableOrderingComposer,
      $$GoalAccountLinksTableAnnotationComposer,
      $$GoalAccountLinksTableCreateCompanionBuilder,
      $$GoalAccountLinksTableUpdateCompanionBuilder,
      (GoalAccountLink, $$GoalAccountLinksTableReferences),
      GoalAccountLink,
      PrefetchHooks Function({bool goalId})
    >;
typedef $$GoalDebtLinksTableCreateCompanionBuilder =
    GoalDebtLinksCompanion Function({
      required String goalId,
      required String linkedId,
      Value<int> rowid,
    });
typedef $$GoalDebtLinksTableUpdateCompanionBuilder =
    GoalDebtLinksCompanion Function({
      Value<String> goalId,
      Value<String> linkedId,
      Value<int> rowid,
    });

final class $$GoalDebtLinksTableReferences
    extends BaseReferences<_$AppDatabase, $GoalDebtLinksTable, GoalDebtLink> {
  $$GoalDebtLinksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $GoalsTable _goalIdTable(_$AppDatabase db) => db.goals.createAlias(
    $_aliasNameGenerator(db.goalDebtLinks.goalId, db.goals.id),
  );

  $$GoalsTableProcessedTableManager get goalId {
    final $_column = $_itemColumn<String>('goal_id')!;

    final manager = $$GoalsTableTableManager(
      $_db,
      $_db.goals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_goalIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GoalDebtLinksTableFilterComposer
    extends Composer<_$AppDatabase, $GoalDebtLinksTable> {
  $$GoalDebtLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get linkedId => $composableBuilder(
    column: $table.linkedId,
    builder: (column) => ColumnFilters(column),
  );

  $$GoalsTableFilterComposer get goalId {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalDebtLinksTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalDebtLinksTable> {
  $$GoalDebtLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get linkedId => $composableBuilder(
    column: $table.linkedId,
    builder: (column) => ColumnOrderings(column),
  );

  $$GoalsTableOrderingComposer get goalId {
    final $$GoalsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableOrderingComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalDebtLinksTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalDebtLinksTable> {
  $$GoalDebtLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get linkedId =>
      $composableBuilder(column: $table.linkedId, builder: (column) => column);

  $$GoalsTableAnnotationComposer get goalId {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.goalId,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalDebtLinksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalDebtLinksTable,
          GoalDebtLink,
          $$GoalDebtLinksTableFilterComposer,
          $$GoalDebtLinksTableOrderingComposer,
          $$GoalDebtLinksTableAnnotationComposer,
          $$GoalDebtLinksTableCreateCompanionBuilder,
          $$GoalDebtLinksTableUpdateCompanionBuilder,
          (GoalDebtLink, $$GoalDebtLinksTableReferences),
          GoalDebtLink,
          PrefetchHooks Function({bool goalId})
        > {
  $$GoalDebtLinksTableTableManager(_$AppDatabase db, $GoalDebtLinksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalDebtLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalDebtLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalDebtLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> goalId = const Value.absent(),
                Value<String> linkedId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalDebtLinksCompanion(
                goalId: goalId,
                linkedId: linkedId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String goalId,
                required String linkedId,
                Value<int> rowid = const Value.absent(),
              }) => GoalDebtLinksCompanion.insert(
                goalId: goalId,
                linkedId: linkedId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$GoalDebtLinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({goalId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (goalId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.goalId,
                                referencedTable: $$GoalDebtLinksTableReferences
                                    ._goalIdTable(db),
                                referencedColumn: $$GoalDebtLinksTableReferences
                                    ._goalIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GoalDebtLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalDebtLinksTable,
      GoalDebtLink,
      $$GoalDebtLinksTableFilterComposer,
      $$GoalDebtLinksTableOrderingComposer,
      $$GoalDebtLinksTableAnnotationComposer,
      $$GoalDebtLinksTableCreateCompanionBuilder,
      $$GoalDebtLinksTableUpdateCompanionBuilder,
      (GoalDebtLink, $$GoalDebtLinksTableReferences),
      GoalDebtLink,
      PrefetchHooks Function({bool goalId})
    >;
typedef $$TagsTableCreateCompanionBuilder =
    TagsCompanion Function({
      required String id,
      required String name,
      required String color,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TagsTableUpdateCompanionBuilder =
    TagsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> color,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

final class $$TagsTableReferences
    extends BaseReferences<_$AppDatabase, $TagsTable, Tag> {
  $$TagsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TransactionTagsTable, List<TransactionTag>>
  _transactionTagsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.transactionTags,
    aliasName: $_aliasNameGenerator(db.tags.id, db.transactionTags.tagId),
  );

  $$TransactionTagsTableProcessedTableManager get transactionTagsRefs {
    final manager = $$TransactionTagsTableTableManager(
      $_db,
      $_db.transactionTags,
    ).filter((f) => f.tagId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _transactionTagsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TagsTableFilterComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> transactionTagsRefs(
    Expression<bool> Function($$TransactionTagsTableFilterComposer f) f,
  ) {
    final $$TransactionTagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionTagsTableFilterComposer(
            $db: $db,
            $table: $db.transactionTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableOrderingComposer extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get color => $composableBuilder(
    column: $table.color,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagsTable> {
  $$TagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> transactionTagsRefs<T extends Object>(
    Expression<T> Function($$TransactionTagsTableAnnotationComposer a) f,
  ) {
    final $$TransactionTagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.transactionTags,
      getReferencedColumn: (t) => t.tagId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionTagsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactionTags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagsTable,
          Tag,
          $$TagsTableFilterComposer,
          $$TagsTableOrderingComposer,
          $$TagsTableAnnotationComposer,
          $$TagsTableCreateCompanionBuilder,
          $$TagsTableUpdateCompanionBuilder,
          (Tag, $$TagsTableReferences),
          Tag,
          PrefetchHooks Function({bool transactionTagsRefs})
        > {
  $$TagsTableTableManager(_$AppDatabase db, $TagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> color = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion(
                id: id,
                name: name,
                color: color,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String color,
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TagsCompanion.insert(
                id: id,
                name: name,
                color: color,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TagsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({transactionTagsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (transactionTagsRefs) db.transactionTags,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (transactionTagsRefs)
                    await $_getPrefetchedData<Tag, $TagsTable, TransactionTag>(
                      currentTable: table,
                      referencedTable: $$TagsTableReferences
                          ._transactionTagsRefsTable(db),
                      managerFromTypedResult: (p0) => $$TagsTableReferences(
                        db,
                        table,
                        p0,
                      ).transactionTagsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.tagId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagsTable,
      Tag,
      $$TagsTableFilterComposer,
      $$TagsTableOrderingComposer,
      $$TagsTableAnnotationComposer,
      $$TagsTableCreateCompanionBuilder,
      $$TagsTableUpdateCompanionBuilder,
      (Tag, $$TagsTableReferences),
      Tag,
      PrefetchHooks Function({bool transactionTagsRefs})
    >;
typedef $$TransactionTagsTableCreateCompanionBuilder =
    TransactionTagsCompanion Function({
      required String transactionId,
      required String tagId,
      Value<int> rowid,
    });
typedef $$TransactionTagsTableUpdateCompanionBuilder =
    TransactionTagsCompanion Function({
      Value<String> transactionId,
      Value<String> tagId,
      Value<int> rowid,
    });

final class $$TransactionTagsTableReferences
    extends
        BaseReferences<_$AppDatabase, $TransactionTagsTable, TransactionTag> {
  $$TransactionTagsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TransactionsTable _transactionIdTable(_$AppDatabase db) =>
      db.transactions.createAlias(
        $_aliasNameGenerator(
          db.transactionTags.transactionId,
          db.transactions.id,
        ),
      );

  $$TransactionsTableProcessedTableManager get transactionId {
    final $_column = $_itemColumn<String>('transaction_id')!;

    final manager = $$TransactionsTableTableManager(
      $_db,
      $_db.transactions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_transactionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TagsTable _tagIdTable(_$AppDatabase db) => db.tags.createAlias(
    $_aliasNameGenerator(db.transactionTags.tagId, db.tags.id),
  );

  $$TagsTableProcessedTableManager get tagId {
    final $_column = $_itemColumn<String>('tag_id')!;

    final manager = $$TagsTableTableManager(
      $_db,
      $_db.tags,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_tagIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TransactionTagsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TransactionsTableFilterComposer get transactionId {
    final $$TransactionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableFilterComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableFilterComposer get tagId {
    final $$TagsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableFilterComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionTagsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TransactionsTableOrderingComposer get transactionId {
    final $$TransactionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableOrderingComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableOrderingComposer get tagId {
    final $$TagsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableOrderingComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionTagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionTagsTable> {
  $$TransactionTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  $$TransactionsTableAnnotationComposer get transactionId {
    final $$TransactionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.transactionId,
      referencedTable: $db.transactions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TransactionsTableAnnotationComposer(
            $db: $db,
            $table: $db.transactions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TagsTableAnnotationComposer get tagId {
    final $$TagsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.tagId,
      referencedTable: $db.tags,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TagsTableAnnotationComposer(
            $db: $db,
            $table: $db.tags,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TransactionTagsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionTagsTable,
          TransactionTag,
          $$TransactionTagsTableFilterComposer,
          $$TransactionTagsTableOrderingComposer,
          $$TransactionTagsTableAnnotationComposer,
          $$TransactionTagsTableCreateCompanionBuilder,
          $$TransactionTagsTableUpdateCompanionBuilder,
          (TransactionTag, $$TransactionTagsTableReferences),
          TransactionTag,
          PrefetchHooks Function({bool transactionId, bool tagId})
        > {
  $$TransactionTagsTableTableManager(
    _$AppDatabase db,
    $TransactionTagsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> transactionId = const Value.absent(),
                Value<String> tagId = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionTagsCompanion(
                transactionId: transactionId,
                tagId: tagId,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String transactionId,
                required String tagId,
                Value<int> rowid = const Value.absent(),
              }) => TransactionTagsCompanion.insert(
                transactionId: transactionId,
                tagId: tagId,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TransactionTagsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({transactionId = false, tagId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (transactionId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.transactionId,
                                referencedTable:
                                    $$TransactionTagsTableReferences
                                        ._transactionIdTable(db),
                                referencedColumn:
                                    $$TransactionTagsTableReferences
                                        ._transactionIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (tagId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.tagId,
                                referencedTable:
                                    $$TransactionTagsTableReferences
                                        ._tagIdTable(db),
                                referencedColumn:
                                    $$TransactionTagsTableReferences
                                        ._tagIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TransactionTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionTagsTable,
      TransactionTag,
      $$TransactionTagsTableFilterComposer,
      $$TransactionTagsTableOrderingComposer,
      $$TransactionTagsTableAnnotationComposer,
      $$TransactionTagsTableCreateCompanionBuilder,
      $$TransactionTagsTableUpdateCompanionBuilder,
      (TransactionTag, $$TransactionTagsTableReferences),
      TransactionTag,
      PrefetchHooks Function({bool transactionId, bool tagId})
    >;
typedef $$TransactionTemplatesTableCreateCompanionBuilder =
    TransactionTemplatesCompanion Function({
      required String id,
      required String name,
      required String description,
      required int amountCents,
      required int direction,
      required String sourceAccountId,
      Value<String?> destinationAccountId,
      required int cycle,
      required int cycleDays,
      required int billingDay,
      required DateTime nextDate,
      required DateTime startDate,
      Value<DateTime?> endDate,
      required bool autoRecord,
      required bool paused,
      Value<String?> lastTransactionId,
      required String category,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$TransactionTemplatesTableUpdateCompanionBuilder =
    TransactionTemplatesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> description,
      Value<int> amountCents,
      Value<int> direction,
      Value<String> sourceAccountId,
      Value<String?> destinationAccountId,
      Value<int> cycle,
      Value<int> cycleDays,
      Value<int> billingDay,
      Value<DateTime> nextDate,
      Value<DateTime> startDate,
      Value<DateTime?> endDate,
      Value<bool> autoRecord,
      Value<bool> paused,
      Value<String?> lastTransactionId,
      Value<String> category,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$TransactionTemplatesTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionTemplatesTable> {
  $$TransactionTemplatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceAccountId => $composableBuilder(
    column: $table.sourceAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get destinationAccountId => $composableBuilder(
    column: $table.destinationAccountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cycle => $composableBuilder(
    column: $table.cycle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get cycleDays => $composableBuilder(
    column: $table.cycleDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoRecord => $composableBuilder(
    column: $table.autoRecord,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get paused => $composableBuilder(
    column: $table.paused,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastTransactionId => $composableBuilder(
    column: $table.lastTransactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TransactionTemplatesTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionTemplatesTable> {
  $$TransactionTemplatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get direction => $composableBuilder(
    column: $table.direction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceAccountId => $composableBuilder(
    column: $table.sourceAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get destinationAccountId => $composableBuilder(
    column: $table.destinationAccountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cycle => $composableBuilder(
    column: $table.cycle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get cycleDays => $composableBuilder(
    column: $table.cycleDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextDate => $composableBuilder(
    column: $table.nextDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoRecord => $composableBuilder(
    column: $table.autoRecord,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get paused => $composableBuilder(
    column: $table.paused,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastTransactionId => $composableBuilder(
    column: $table.lastTransactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TransactionTemplatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionTemplatesTable> {
  $$TransactionTemplatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get direction =>
      $composableBuilder(column: $table.direction, builder: (column) => column);

  GeneratedColumn<String> get sourceAccountId => $composableBuilder(
    column: $table.sourceAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get destinationAccountId => $composableBuilder(
    column: $table.destinationAccountId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get cycle =>
      $composableBuilder(column: $table.cycle, builder: (column) => column);

  GeneratedColumn<int> get cycleDays =>
      $composableBuilder(column: $table.cycleDays, builder: (column) => column);

  GeneratedColumn<int> get billingDay => $composableBuilder(
    column: $table.billingDay,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextDate =>
      $composableBuilder(column: $table.nextDate, builder: (column) => column);

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<bool> get autoRecord => $composableBuilder(
    column: $table.autoRecord,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get paused =>
      $composableBuilder(column: $table.paused, builder: (column) => column);

  GeneratedColumn<String> get lastTransactionId => $composableBuilder(
    column: $table.lastTransactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TransactionTemplatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TransactionTemplatesTable,
          TransactionTemplate,
          $$TransactionTemplatesTableFilterComposer,
          $$TransactionTemplatesTableOrderingComposer,
          $$TransactionTemplatesTableAnnotationComposer,
          $$TransactionTemplatesTableCreateCompanionBuilder,
          $$TransactionTemplatesTableUpdateCompanionBuilder,
          (
            TransactionTemplate,
            BaseReferences<
              _$AppDatabase,
              $TransactionTemplatesTable,
              TransactionTemplate
            >,
          ),
          TransactionTemplate,
          PrefetchHooks Function()
        > {
  $$TransactionTemplatesTableTableManager(
    _$AppDatabase db,
    $TransactionTemplatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionTemplatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionTemplatesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$TransactionTemplatesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<int> direction = const Value.absent(),
                Value<String> sourceAccountId = const Value.absent(),
                Value<String?> destinationAccountId = const Value.absent(),
                Value<int> cycle = const Value.absent(),
                Value<int> cycleDays = const Value.absent(),
                Value<int> billingDay = const Value.absent(),
                Value<DateTime> nextDate = const Value.absent(),
                Value<DateTime> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<bool> autoRecord = const Value.absent(),
                Value<bool> paused = const Value.absent(),
                Value<String?> lastTransactionId = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TransactionTemplatesCompanion(
                id: id,
                name: name,
                description: description,
                amountCents: amountCents,
                direction: direction,
                sourceAccountId: sourceAccountId,
                destinationAccountId: destinationAccountId,
                cycle: cycle,
                cycleDays: cycleDays,
                billingDay: billingDay,
                nextDate: nextDate,
                startDate: startDate,
                endDate: endDate,
                autoRecord: autoRecord,
                paused: paused,
                lastTransactionId: lastTransactionId,
                category: category,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String description,
                required int amountCents,
                required int direction,
                required String sourceAccountId,
                Value<String?> destinationAccountId = const Value.absent(),
                required int cycle,
                required int cycleDays,
                required int billingDay,
                required DateTime nextDate,
                required DateTime startDate,
                Value<DateTime?> endDate = const Value.absent(),
                required bool autoRecord,
                required bool paused,
                Value<String?> lastTransactionId = const Value.absent(),
                required String category,
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => TransactionTemplatesCompanion.insert(
                id: id,
                name: name,
                description: description,
                amountCents: amountCents,
                direction: direction,
                sourceAccountId: sourceAccountId,
                destinationAccountId: destinationAccountId,
                cycle: cycle,
                cycleDays: cycleDays,
                billingDay: billingDay,
                nextDate: nextDate,
                startDate: startDate,
                endDate: endDate,
                autoRecord: autoRecord,
                paused: paused,
                lastTransactionId: lastTransactionId,
                category: category,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TransactionTemplatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TransactionTemplatesTable,
      TransactionTemplate,
      $$TransactionTemplatesTableFilterComposer,
      $$TransactionTemplatesTableOrderingComposer,
      $$TransactionTemplatesTableAnnotationComposer,
      $$TransactionTemplatesTableCreateCompanionBuilder,
      $$TransactionTemplatesTableUpdateCompanionBuilder,
      (
        TransactionTemplate,
        BaseReferences<
          _$AppDatabase,
          $TransactionTemplatesTable,
          TransactionTemplate
        >,
      ),
      TransactionTemplate,
      PrefetchHooks Function()
    >;
typedef $$HoldingsTableCreateCompanionBuilder =
    HoldingsCompanion Function({
      required String id,
      required String accountId,
      required String securityId,
      required double quantity,
      required int avgCostCents,
      required int version,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$HoldingsTableUpdateCompanionBuilder =
    HoldingsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> securityId,
      Value<double> quantity,
      Value<int> avgCostCents,
      Value<int> version,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$HoldingsTableFilterComposer
    extends Composer<_$AppDatabase, $HoldingsTable> {
  $$HoldingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get avgCostCents => $composableBuilder(
    column: $table.avgCostCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HoldingsTableOrderingComposer
    extends Composer<_$AppDatabase, $HoldingsTable> {
  $$HoldingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get avgCostCents => $composableBuilder(
    column: $table.avgCostCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HoldingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HoldingsTable> {
  $$HoldingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get avgCostCents => $composableBuilder(
    column: $table.avgCostCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$HoldingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HoldingsTable,
          Holding,
          $$HoldingsTableFilterComposer,
          $$HoldingsTableOrderingComposer,
          $$HoldingsTableAnnotationComposer,
          $$HoldingsTableCreateCompanionBuilder,
          $$HoldingsTableUpdateCompanionBuilder,
          (Holding, BaseReferences<_$AppDatabase, $HoldingsTable, Holding>),
          Holding,
          PrefetchHooks Function()
        > {
  $$HoldingsTableTableManager(_$AppDatabase db, $HoldingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoldingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoldingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HoldingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> securityId = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<int> avgCostCents = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HoldingsCompanion(
                id: id,
                accountId: accountId,
                securityId: securityId,
                quantity: quantity,
                avgCostCents: avgCostCents,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String securityId,
                required double quantity,
                required int avgCostCents,
                required int version,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => HoldingsCompanion.insert(
                id: id,
                accountId: accountId,
                securityId: securityId,
                quantity: quantity,
                avgCostCents: avgCostCents,
                version: version,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HoldingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HoldingsTable,
      Holding,
      $$HoldingsTableFilterComposer,
      $$HoldingsTableOrderingComposer,
      $$HoldingsTableAnnotationComposer,
      $$HoldingsTableCreateCompanionBuilder,
      $$HoldingsTableUpdateCompanionBuilder,
      (Holding, BaseReferences<_$AppDatabase, $HoldingsTable, Holding>),
      Holding,
      PrefetchHooks Function()
    >;
typedef $$HoldingTransactionsTableCreateCompanionBuilder =
    HoldingTransactionsCompanion Function({
      required String id,
      required String accountId,
      required String securityId,
      required int tradeType,
      required double quantity,
      required int priceCents,
      required int amountCents,
      required int feeCents,
      required int realizedPnlCents,
      required DateTime tradeDate,
      Value<String?> transactionId,
      required String notes,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$HoldingTransactionsTableUpdateCompanionBuilder =
    HoldingTransactionsCompanion Function({
      Value<String> id,
      Value<String> accountId,
      Value<String> securityId,
      Value<int> tradeType,
      Value<double> quantity,
      Value<int> priceCents,
      Value<int> amountCents,
      Value<int> feeCents,
      Value<int> realizedPnlCents,
      Value<DateTime> tradeDate,
      Value<String?> transactionId,
      Value<String> notes,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$HoldingTransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $HoldingTransactionsTable> {
  $$HoldingTransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tradeType => $composableBuilder(
    column: $table.tradeType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get feeCents => $composableBuilder(
    column: $table.feeCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get realizedPnlCents => $composableBuilder(
    column: $table.realizedPnlCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get tradeDate => $composableBuilder(
    column: $table.tradeDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HoldingTransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $HoldingTransactionsTable> {
  $$HoldingTransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tradeType => $composableBuilder(
    column: $table.tradeType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get feeCents => $composableBuilder(
    column: $table.feeCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get realizedPnlCents => $composableBuilder(
    column: $table.realizedPnlCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get tradeDate => $composableBuilder(
    column: $table.tradeDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HoldingTransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HoldingTransactionsTable> {
  $$HoldingTransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get tradeType =>
      $composableBuilder(column: $table.tradeType, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get amountCents => $composableBuilder(
    column: $table.amountCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get feeCents =>
      $composableBuilder(column: $table.feeCents, builder: (column) => column);

  GeneratedColumn<int> get realizedPnlCents => $composableBuilder(
    column: $table.realizedPnlCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get tradeDate =>
      $composableBuilder(column: $table.tradeDate, builder: (column) => column);

  GeneratedColumn<String> get transactionId => $composableBuilder(
    column: $table.transactionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$HoldingTransactionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HoldingTransactionsTable,
          HoldingTransaction,
          $$HoldingTransactionsTableFilterComposer,
          $$HoldingTransactionsTableOrderingComposer,
          $$HoldingTransactionsTableAnnotationComposer,
          $$HoldingTransactionsTableCreateCompanionBuilder,
          $$HoldingTransactionsTableUpdateCompanionBuilder,
          (
            HoldingTransaction,
            BaseReferences<
              _$AppDatabase,
              $HoldingTransactionsTable,
              HoldingTransaction
            >,
          ),
          HoldingTransaction,
          PrefetchHooks Function()
        > {
  $$HoldingTransactionsTableTableManager(
    _$AppDatabase db,
    $HoldingTransactionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoldingTransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoldingTransactionsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$HoldingTransactionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<String> securityId = const Value.absent(),
                Value<int> tradeType = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<int> priceCents = const Value.absent(),
                Value<int> amountCents = const Value.absent(),
                Value<int> feeCents = const Value.absent(),
                Value<int> realizedPnlCents = const Value.absent(),
                Value<DateTime> tradeDate = const Value.absent(),
                Value<String?> transactionId = const Value.absent(),
                Value<String> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HoldingTransactionsCompanion(
                id: id,
                accountId: accountId,
                securityId: securityId,
                tradeType: tradeType,
                quantity: quantity,
                priceCents: priceCents,
                amountCents: amountCents,
                feeCents: feeCents,
                realizedPnlCents: realizedPnlCents,
                tradeDate: tradeDate,
                transactionId: transactionId,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String accountId,
                required String securityId,
                required int tradeType,
                required double quantity,
                required int priceCents,
                required int amountCents,
                required int feeCents,
                required int realizedPnlCents,
                required DateTime tradeDate,
                Value<String?> transactionId = const Value.absent(),
                required String notes,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => HoldingTransactionsCompanion.insert(
                id: id,
                accountId: accountId,
                securityId: securityId,
                tradeType: tradeType,
                quantity: quantity,
                priceCents: priceCents,
                amountCents: amountCents,
                feeCents: feeCents,
                realizedPnlCents: realizedPnlCents,
                tradeDate: tradeDate,
                transactionId: transactionId,
                notes: notes,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HoldingTransactionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HoldingTransactionsTable,
      HoldingTransaction,
      $$HoldingTransactionsTableFilterComposer,
      $$HoldingTransactionsTableOrderingComposer,
      $$HoldingTransactionsTableAnnotationComposer,
      $$HoldingTransactionsTableCreateCompanionBuilder,
      $$HoldingTransactionsTableUpdateCompanionBuilder,
      (
        HoldingTransaction,
        BaseReferences<
          _$AppDatabase,
          $HoldingTransactionsTable,
          HoldingTransaction
        >,
      ),
      HoldingTransaction,
      PrefetchHooks Function()
    >;
typedef $$CurrenciesTableCreateCompanionBuilder =
    CurrenciesCompanion Function({
      required String code,
      required String name,
      required String symbol,
      required double exchangeRate,
      required bool isActive,
      Value<int> rowid,
    });
typedef $$CurrenciesTableUpdateCompanionBuilder =
    CurrenciesCompanion Function({
      Value<String> code,
      Value<String> name,
      Value<String> symbol,
      Value<double> exchangeRate,
      Value<bool> isActive,
      Value<int> rowid,
    });

class $$CurrenciesTableFilterComposer
    extends Composer<_$AppDatabase, $CurrenciesTable> {
  $$CurrenciesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CurrenciesTableOrderingComposer
    extends Composer<_$AppDatabase, $CurrenciesTable> {
  $$CurrenciesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get code => $composableBuilder(
    column: $table.code,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CurrenciesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CurrenciesTable> {
  $$CurrenciesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get code =>
      $composableBuilder(column: $table.code, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<double> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);
}

class $$CurrenciesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CurrenciesTable,
          Currency,
          $$CurrenciesTableFilterComposer,
          $$CurrenciesTableOrderingComposer,
          $$CurrenciesTableAnnotationComposer,
          $$CurrenciesTableCreateCompanionBuilder,
          $$CurrenciesTableUpdateCompanionBuilder,
          (Currency, BaseReferences<_$AppDatabase, $CurrenciesTable, Currency>),
          Currency,
          PrefetchHooks Function()
        > {
  $$CurrenciesTableTableManager(_$AppDatabase db, $CurrenciesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CurrenciesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CurrenciesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CurrenciesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> code = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<double> exchangeRate = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CurrenciesCompanion(
                code: code,
                name: name,
                symbol: symbol,
                exchangeRate: exchangeRate,
                isActive: isActive,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String code,
                required String name,
                required String symbol,
                required double exchangeRate,
                required bool isActive,
                Value<int> rowid = const Value.absent(),
              }) => CurrenciesCompanion.insert(
                code: code,
                name: name,
                symbol: symbol,
                exchangeRate: exchangeRate,
                isActive: isActive,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CurrenciesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CurrenciesTable,
      Currency,
      $$CurrenciesTableFilterComposer,
      $$CurrenciesTableOrderingComposer,
      $$CurrenciesTableAnnotationComposer,
      $$CurrenciesTableCreateCompanionBuilder,
      $$CurrenciesTableUpdateCompanionBuilder,
      (Currency, BaseReferences<_$AppDatabase, $CurrenciesTable, Currency>),
      Currency,
      PrefetchHooks Function()
    >;
typedef $$RateHistoriesTableCreateCompanionBuilder =
    RateHistoriesCompanion Function({
      required String id,
      required String currencyCode,
      required DateTime rateDate,
      required double exchangeRate,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$RateHistoriesTableUpdateCompanionBuilder =
    RateHistoriesCompanion Function({
      Value<String> id,
      Value<String> currencyCode,
      Value<DateTime> rateDate,
      Value<double> exchangeRate,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$RateHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $RateHistoriesTable> {
  $$RateHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get rateDate => $composableBuilder(
    column: $table.rateDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RateHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $RateHistoriesTable> {
  $$RateHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get rateDate => $composableBuilder(
    column: $table.rateDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RateHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RateHistoriesTable> {
  $$RateHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get rateDate =>
      $composableBuilder(column: $table.rateDate, builder: (column) => column);

  GeneratedColumn<double> get exchangeRate => $composableBuilder(
    column: $table.exchangeRate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$RateHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RateHistoriesTable,
          RateHistory,
          $$RateHistoriesTableFilterComposer,
          $$RateHistoriesTableOrderingComposer,
          $$RateHistoriesTableAnnotationComposer,
          $$RateHistoriesTableCreateCompanionBuilder,
          $$RateHistoriesTableUpdateCompanionBuilder,
          (
            RateHistory,
            BaseReferences<_$AppDatabase, $RateHistoriesTable, RateHistory>,
          ),
          RateHistory,
          PrefetchHooks Function()
        > {
  $$RateHistoriesTableTableManager(_$AppDatabase db, $RateHistoriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RateHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RateHistoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RateHistoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<DateTime> rateDate = const Value.absent(),
                Value<double> exchangeRate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RateHistoriesCompanion(
                id: id,
                currencyCode: currencyCode,
                rateDate: rateDate,
                exchangeRate: exchangeRate,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String currencyCode,
                required DateTime rateDate,
                required double exchangeRate,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => RateHistoriesCompanion.insert(
                id: id,
                currencyCode: currencyCode,
                rateDate: rateDate,
                exchangeRate: exchangeRate,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RateHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RateHistoriesTable,
      RateHistory,
      $$RateHistoriesTableFilterComposer,
      $$RateHistoriesTableOrderingComposer,
      $$RateHistoriesTableAnnotationComposer,
      $$RateHistoriesTableCreateCompanionBuilder,
      $$RateHistoriesTableUpdateCompanionBuilder,
      (
        RateHistory,
        BaseReferences<_$AppDatabase, $RateHistoriesTable, RateHistory>,
      ),
      RateHistory,
      PrefetchHooks Function()
    >;
typedef $$SecuritiesTableCreateCompanionBuilder =
    SecuritiesCompanion Function({
      required String id,
      required String symbol,
      required String name,
      required String securityType,
      required String exchange,
      required String currencyCode,
      required int currentPriceCents,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SecuritiesTableUpdateCompanionBuilder =
    SecuritiesCompanion Function({
      Value<String> id,
      Value<String> symbol,
      Value<String> name,
      Value<String> securityType,
      Value<String> exchange,
      Value<String> currencyCode,
      Value<int> currentPriceCents,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SecuritiesTableFilterComposer
    extends Composer<_$AppDatabase, $SecuritiesTable> {
  $$SecuritiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get securityType => $composableBuilder(
    column: $table.securityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exchange => $composableBuilder(
    column: $table.exchange,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentPriceCents => $composableBuilder(
    column: $table.currentPriceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SecuritiesTableOrderingComposer
    extends Composer<_$AppDatabase, $SecuritiesTable> {
  $$SecuritiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symbol => $composableBuilder(
    column: $table.symbol,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get securityType => $composableBuilder(
    column: $table.securityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exchange => $composableBuilder(
    column: $table.exchange,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentPriceCents => $composableBuilder(
    column: $table.currentPriceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SecuritiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SecuritiesTable> {
  $$SecuritiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get symbol =>
      $composableBuilder(column: $table.symbol, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get securityType => $composableBuilder(
    column: $table.securityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get exchange =>
      $composableBuilder(column: $table.exchange, builder: (column) => column);

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentPriceCents => $composableBuilder(
    column: $table.currentPriceCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SecuritiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SecuritiesTable,
          Security,
          $$SecuritiesTableFilterComposer,
          $$SecuritiesTableOrderingComposer,
          $$SecuritiesTableAnnotationComposer,
          $$SecuritiesTableCreateCompanionBuilder,
          $$SecuritiesTableUpdateCompanionBuilder,
          (Security, BaseReferences<_$AppDatabase, $SecuritiesTable, Security>),
          Security,
          PrefetchHooks Function()
        > {
  $$SecuritiesTableTableManager(_$AppDatabase db, $SecuritiesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SecuritiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SecuritiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SecuritiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> symbol = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> securityType = const Value.absent(),
                Value<String> exchange = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<int> currentPriceCents = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SecuritiesCompanion(
                id: id,
                symbol: symbol,
                name: name,
                securityType: securityType,
                exchange: exchange,
                currencyCode: currencyCode,
                currentPriceCents: currentPriceCents,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String symbol,
                required String name,
                required String securityType,
                required String exchange,
                required String currencyCode,
                required int currentPriceCents,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SecuritiesCompanion.insert(
                id: id,
                symbol: symbol,
                name: name,
                securityType: securityType,
                exchange: exchange,
                currencyCode: currencyCode,
                currentPriceCents: currentPriceCents,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SecuritiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SecuritiesTable,
      Security,
      $$SecuritiesTableFilterComposer,
      $$SecuritiesTableOrderingComposer,
      $$SecuritiesTableAnnotationComposer,
      $$SecuritiesTableCreateCompanionBuilder,
      $$SecuritiesTableUpdateCompanionBuilder,
      (Security, BaseReferences<_$AppDatabase, $SecuritiesTable, Security>),
      Security,
      PrefetchHooks Function()
    >;
typedef $$SecurityPriceHistoriesTableCreateCompanionBuilder =
    SecurityPriceHistoriesCompanion Function({
      required String id,
      required String securityId,
      required DateTime priceDate,
      required int priceCents,
      required String currencyCode,
      required String source,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$SecurityPriceHistoriesTableUpdateCompanionBuilder =
    SecurityPriceHistoriesCompanion Function({
      Value<String> id,
      Value<String> securityId,
      Value<DateTime> priceDate,
      Value<int> priceCents,
      Value<String> currencyCode,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$SecurityPriceHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $SecurityPriceHistoriesTable> {
  $$SecurityPriceHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get priceDate => $composableBuilder(
    column: $table.priceDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SecurityPriceHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SecurityPriceHistoriesTable> {
  $$SecurityPriceHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get priceDate => $composableBuilder(
    column: $table.priceDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SecurityPriceHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SecurityPriceHistoriesTable> {
  $$SecurityPriceHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get priceDate =>
      $composableBuilder(column: $table.priceDate, builder: (column) => column);

  GeneratedColumn<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SecurityPriceHistoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SecurityPriceHistoriesTable,
          SecurityPriceHistory,
          $$SecurityPriceHistoriesTableFilterComposer,
          $$SecurityPriceHistoriesTableOrderingComposer,
          $$SecurityPriceHistoriesTableAnnotationComposer,
          $$SecurityPriceHistoriesTableCreateCompanionBuilder,
          $$SecurityPriceHistoriesTableUpdateCompanionBuilder,
          (
            SecurityPriceHistory,
            BaseReferences<
              _$AppDatabase,
              $SecurityPriceHistoriesTable,
              SecurityPriceHistory
            >,
          ),
          SecurityPriceHistory,
          PrefetchHooks Function()
        > {
  $$SecurityPriceHistoriesTableTableManager(
    _$AppDatabase db,
    $SecurityPriceHistoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SecurityPriceHistoriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SecurityPriceHistoriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SecurityPriceHistoriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> securityId = const Value.absent(),
                Value<DateTime> priceDate = const Value.absent(),
                Value<int> priceCents = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SecurityPriceHistoriesCompanion(
                id: id,
                securityId: securityId,
                priceDate: priceDate,
                priceCents: priceCents,
                currencyCode: currencyCode,
                source: source,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String securityId,
                required DateTime priceDate,
                required int priceCents,
                required String currencyCode,
                required String source,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SecurityPriceHistoriesCompanion.insert(
                id: id,
                securityId: securityId,
                priceDate: priceDate,
                priceCents: priceCents,
                currencyCode: currencyCode,
                source: source,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SecurityPriceHistoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SecurityPriceHistoriesTable,
      SecurityPriceHistory,
      $$SecurityPriceHistoriesTableFilterComposer,
      $$SecurityPriceHistoriesTableOrderingComposer,
      $$SecurityPriceHistoriesTableAnnotationComposer,
      $$SecurityPriceHistoriesTableCreateCompanionBuilder,
      $$SecurityPriceHistoriesTableUpdateCompanionBuilder,
      (
        SecurityPriceHistory,
        BaseReferences<
          _$AppDatabase,
          $SecurityPriceHistoriesTable,
          SecurityPriceHistory
        >,
      ),
      SecurityPriceHistory,
      PrefetchHooks Function()
    >;
typedef $$DebtProgressSnapshotsTableCreateCompanionBuilder =
    DebtProgressSnapshotsCompanion Function({
      required String id,
      required String debtId,
      required DateTime snapshotDate,
      required int totalPrincipalCents,
      required int remainingPrincipalCents,
      required int paidTotalCents,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$DebtProgressSnapshotsTableUpdateCompanionBuilder =
    DebtProgressSnapshotsCompanion Function({
      Value<String> id,
      Value<String> debtId,
      Value<DateTime> snapshotDate,
      Value<int> totalPrincipalCents,
      Value<int> remainingPrincipalCents,
      Value<int> paidTotalCents,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$DebtProgressSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $DebtProgressSnapshotsTable> {
  $$DebtProgressSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get debtId => $composableBuilder(
    column: $table.debtId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalPrincipalCents => $composableBuilder(
    column: $table.totalPrincipalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remainingPrincipalCents => $composableBuilder(
    column: $table.remainingPrincipalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get paidTotalCents => $composableBuilder(
    column: $table.paidTotalCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DebtProgressSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $DebtProgressSnapshotsTable> {
  $$DebtProgressSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get debtId => $composableBuilder(
    column: $table.debtId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalPrincipalCents => $composableBuilder(
    column: $table.totalPrincipalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remainingPrincipalCents => $composableBuilder(
    column: $table.remainingPrincipalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get paidTotalCents => $composableBuilder(
    column: $table.paidTotalCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DebtProgressSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DebtProgressSnapshotsTable> {
  $$DebtProgressSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get debtId =>
      $composableBuilder(column: $table.debtId, builder: (column) => column);

  GeneratedColumn<DateTime> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalPrincipalCents => $composableBuilder(
    column: $table.totalPrincipalCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remainingPrincipalCents => $composableBuilder(
    column: $table.remainingPrincipalCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get paidTotalCents => $composableBuilder(
    column: $table.paidTotalCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DebtProgressSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DebtProgressSnapshotsTable,
          DebtProgressSnapshot,
          $$DebtProgressSnapshotsTableFilterComposer,
          $$DebtProgressSnapshotsTableOrderingComposer,
          $$DebtProgressSnapshotsTableAnnotationComposer,
          $$DebtProgressSnapshotsTableCreateCompanionBuilder,
          $$DebtProgressSnapshotsTableUpdateCompanionBuilder,
          (
            DebtProgressSnapshot,
            BaseReferences<
              _$AppDatabase,
              $DebtProgressSnapshotsTable,
              DebtProgressSnapshot
            >,
          ),
          DebtProgressSnapshot,
          PrefetchHooks Function()
        > {
  $$DebtProgressSnapshotsTableTableManager(
    _$AppDatabase db,
    $DebtProgressSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DebtProgressSnapshotsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$DebtProgressSnapshotsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$DebtProgressSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> debtId = const Value.absent(),
                Value<DateTime> snapshotDate = const Value.absent(),
                Value<int> totalPrincipalCents = const Value.absent(),
                Value<int> remainingPrincipalCents = const Value.absent(),
                Value<int> paidTotalCents = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DebtProgressSnapshotsCompanion(
                id: id,
                debtId: debtId,
                snapshotDate: snapshotDate,
                totalPrincipalCents: totalPrincipalCents,
                remainingPrincipalCents: remainingPrincipalCents,
                paidTotalCents: paidTotalCents,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String debtId,
                required DateTime snapshotDate,
                required int totalPrincipalCents,
                required int remainingPrincipalCents,
                required int paidTotalCents,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => DebtProgressSnapshotsCompanion.insert(
                id: id,
                debtId: debtId,
                snapshotDate: snapshotDate,
                totalPrincipalCents: totalPrincipalCents,
                remainingPrincipalCents: remainingPrincipalCents,
                paidTotalCents: paidTotalCents,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DebtProgressSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DebtProgressSnapshotsTable,
      DebtProgressSnapshot,
      $$DebtProgressSnapshotsTableFilterComposer,
      $$DebtProgressSnapshotsTableOrderingComposer,
      $$DebtProgressSnapshotsTableAnnotationComposer,
      $$DebtProgressSnapshotsTableCreateCompanionBuilder,
      $$DebtProgressSnapshotsTableUpdateCompanionBuilder,
      (
        DebtProgressSnapshot,
        BaseReferences<
          _$AppDatabase,
          $DebtProgressSnapshotsTable,
          DebtProgressSnapshot
        >,
      ),
      DebtProgressSnapshot,
      PrefetchHooks Function()
    >;
typedef $$GoalProgressSnapshotsTableCreateCompanionBuilder =
    GoalProgressSnapshotsCompanion Function({
      required String id,
      required String goalId,
      required DateTime snapshotDate,
      required int currentAmountCents,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$GoalProgressSnapshotsTableUpdateCompanionBuilder =
    GoalProgressSnapshotsCompanion Function({
      Value<String> id,
      Value<String> goalId,
      Value<DateTime> snapshotDate,
      Value<int> currentAmountCents,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$GoalProgressSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $GoalProgressSnapshotsTable> {
  $$GoalProgressSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentAmountCents => $composableBuilder(
    column: $table.currentAmountCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GoalProgressSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalProgressSnapshotsTable> {
  $$GoalProgressSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentAmountCents => $composableBuilder(
    column: $table.currentAmountCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalProgressSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalProgressSnapshotsTable> {
  $$GoalProgressSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<DateTime> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentAmountCents => $composableBuilder(
    column: $table.currentAmountCents,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$GoalProgressSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalProgressSnapshotsTable,
          GoalProgressSnapshot,
          $$GoalProgressSnapshotsTableFilterComposer,
          $$GoalProgressSnapshotsTableOrderingComposer,
          $$GoalProgressSnapshotsTableAnnotationComposer,
          $$GoalProgressSnapshotsTableCreateCompanionBuilder,
          $$GoalProgressSnapshotsTableUpdateCompanionBuilder,
          (
            GoalProgressSnapshot,
            BaseReferences<
              _$AppDatabase,
              $GoalProgressSnapshotsTable,
              GoalProgressSnapshot
            >,
          ),
          GoalProgressSnapshot,
          PrefetchHooks Function()
        > {
  $$GoalProgressSnapshotsTableTableManager(
    _$AppDatabase db,
    $GoalProgressSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalProgressSnapshotsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$GoalProgressSnapshotsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GoalProgressSnapshotsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> goalId = const Value.absent(),
                Value<DateTime> snapshotDate = const Value.absent(),
                Value<int> currentAmountCents = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalProgressSnapshotsCompanion(
                id: id,
                goalId: goalId,
                snapshotDate: snapshotDate,
                currentAmountCents: currentAmountCents,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String goalId,
                required DateTime snapshotDate,
                required int currentAmountCents,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => GoalProgressSnapshotsCompanion.insert(
                id: id,
                goalId: goalId,
                snapshotDate: snapshotDate,
                currentAmountCents: currentAmountCents,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GoalProgressSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalProgressSnapshotsTable,
      GoalProgressSnapshot,
      $$GoalProgressSnapshotsTableFilterComposer,
      $$GoalProgressSnapshotsTableOrderingComposer,
      $$GoalProgressSnapshotsTableAnnotationComposer,
      $$GoalProgressSnapshotsTableCreateCompanionBuilder,
      $$GoalProgressSnapshotsTableUpdateCompanionBuilder,
      (
        GoalProgressSnapshot,
        BaseReferences<
          _$AppDatabase,
          $GoalProgressSnapshotsTable,
          GoalProgressSnapshot
        >,
      ),
      GoalProgressSnapshot,
      PrefetchHooks Function()
    >;
typedef $$HoldingSnapshotsTableCreateCompanionBuilder =
    HoldingSnapshotsCompanion Function({
      required String id,
      required String holdingId,
      required String securityId,
      required String accountId,
      required DateTime snapshotDate,
      required int marketValueCents,
      required int unrealizedPnlCents,
      required String currencyCode,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$HoldingSnapshotsTableUpdateCompanionBuilder =
    HoldingSnapshotsCompanion Function({
      Value<String> id,
      Value<String> holdingId,
      Value<String> securityId,
      Value<String> accountId,
      Value<DateTime> snapshotDate,
      Value<int> marketValueCents,
      Value<int> unrealizedPnlCents,
      Value<String> currencyCode,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$HoldingSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $HoldingSnapshotsTable> {
  $$HoldingSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holdingId => $composableBuilder(
    column: $table.holdingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get marketValueCents => $composableBuilder(
    column: $table.marketValueCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get unrealizedPnlCents => $composableBuilder(
    column: $table.unrealizedPnlCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HoldingSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $HoldingSnapshotsTable> {
  $$HoldingSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holdingId => $composableBuilder(
    column: $table.holdingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountId => $composableBuilder(
    column: $table.accountId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get marketValueCents => $composableBuilder(
    column: $table.marketValueCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get unrealizedPnlCents => $composableBuilder(
    column: $table.unrealizedPnlCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HoldingSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HoldingSnapshotsTable> {
  $$HoldingSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get holdingId =>
      $composableBuilder(column: $table.holdingId, builder: (column) => column);

  GeneratedColumn<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<DateTime> get snapshotDate => $composableBuilder(
    column: $table.snapshotDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get marketValueCents => $composableBuilder(
    column: $table.marketValueCents,
    builder: (column) => column,
  );

  GeneratedColumn<int> get unrealizedPnlCents => $composableBuilder(
    column: $table.unrealizedPnlCents,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currencyCode => $composableBuilder(
    column: $table.currencyCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$HoldingSnapshotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HoldingSnapshotsTable,
          HoldingSnapshot,
          $$HoldingSnapshotsTableFilterComposer,
          $$HoldingSnapshotsTableOrderingComposer,
          $$HoldingSnapshotsTableAnnotationComposer,
          $$HoldingSnapshotsTableCreateCompanionBuilder,
          $$HoldingSnapshotsTableUpdateCompanionBuilder,
          (
            HoldingSnapshot,
            BaseReferences<
              _$AppDatabase,
              $HoldingSnapshotsTable,
              HoldingSnapshot
            >,
          ),
          HoldingSnapshot,
          PrefetchHooks Function()
        > {
  $$HoldingSnapshotsTableTableManager(
    _$AppDatabase db,
    $HoldingSnapshotsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoldingSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoldingSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HoldingSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> holdingId = const Value.absent(),
                Value<String> securityId = const Value.absent(),
                Value<String> accountId = const Value.absent(),
                Value<DateTime> snapshotDate = const Value.absent(),
                Value<int> marketValueCents = const Value.absent(),
                Value<int> unrealizedPnlCents = const Value.absent(),
                Value<String> currencyCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HoldingSnapshotsCompanion(
                id: id,
                holdingId: holdingId,
                securityId: securityId,
                accountId: accountId,
                snapshotDate: snapshotDate,
                marketValueCents: marketValueCents,
                unrealizedPnlCents: unrealizedPnlCents,
                currencyCode: currencyCode,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String holdingId,
                required String securityId,
                required String accountId,
                required DateTime snapshotDate,
                required int marketValueCents,
                required int unrealizedPnlCents,
                required String currencyCode,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => HoldingSnapshotsCompanion.insert(
                id: id,
                holdingId: holdingId,
                securityId: securityId,
                accountId: accountId,
                snapshotDate: snapshotDate,
                marketValueCents: marketValueCents,
                unrealizedPnlCents: unrealizedPnlCents,
                currencyCode: currencyCode,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HoldingSnapshotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HoldingSnapshotsTable,
      HoldingSnapshot,
      $$HoldingSnapshotsTableFilterComposer,
      $$HoldingSnapshotsTableOrderingComposer,
      $$HoldingSnapshotsTableAnnotationComposer,
      $$HoldingSnapshotsTableCreateCompanionBuilder,
      $$HoldingSnapshotsTableUpdateCompanionBuilder,
      (
        HoldingSnapshot,
        BaseReferences<_$AppDatabase, $HoldingSnapshotsTable, HoldingSnapshot>,
      ),
      HoldingSnapshot,
      PrefetchHooks Function()
    >;
typedef $$HoldingLotsTableCreateCompanionBuilder =
    HoldingLotsCompanion Function({
      required String id,
      required String holdingId,
      required String securityId,
      required DateTime acquiredDate,
      required String acquiredTradeId,
      required int priceCents,
      required double quantity,
      required double remainingQuantity,
      Value<int> rowid,
    });
typedef $$HoldingLotsTableUpdateCompanionBuilder =
    HoldingLotsCompanion Function({
      Value<String> id,
      Value<String> holdingId,
      Value<String> securityId,
      Value<DateTime> acquiredDate,
      Value<String> acquiredTradeId,
      Value<int> priceCents,
      Value<double> quantity,
      Value<double> remainingQuantity,
      Value<int> rowid,
    });

class $$HoldingLotsTableFilterComposer
    extends Composer<_$AppDatabase, $HoldingLotsTable> {
  $$HoldingLotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get holdingId => $composableBuilder(
    column: $table.holdingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get acquiredDate => $composableBuilder(
    column: $table.acquiredDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get acquiredTradeId => $composableBuilder(
    column: $table.acquiredTradeId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get remainingQuantity => $composableBuilder(
    column: $table.remainingQuantity,
    builder: (column) => ColumnFilters(column),
  );
}

class $$HoldingLotsTableOrderingComposer
    extends Composer<_$AppDatabase, $HoldingLotsTable> {
  $$HoldingLotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get holdingId => $composableBuilder(
    column: $table.holdingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get acquiredDate => $composableBuilder(
    column: $table.acquiredDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get acquiredTradeId => $composableBuilder(
    column: $table.acquiredTradeId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get remainingQuantity => $composableBuilder(
    column: $table.remainingQuantity,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$HoldingLotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HoldingLotsTable> {
  $$HoldingLotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get holdingId =>
      $composableBuilder(column: $table.holdingId, builder: (column) => column);

  GeneratedColumn<String> get securityId => $composableBuilder(
    column: $table.securityId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get acquiredDate => $composableBuilder(
    column: $table.acquiredDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get acquiredTradeId => $composableBuilder(
    column: $table.acquiredTradeId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get priceCents => $composableBuilder(
    column: $table.priceCents,
    builder: (column) => column,
  );

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get remainingQuantity => $composableBuilder(
    column: $table.remainingQuantity,
    builder: (column) => column,
  );
}

class $$HoldingLotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $HoldingLotsTable,
          HoldingLot,
          $$HoldingLotsTableFilterComposer,
          $$HoldingLotsTableOrderingComposer,
          $$HoldingLotsTableAnnotationComposer,
          $$HoldingLotsTableCreateCompanionBuilder,
          $$HoldingLotsTableUpdateCompanionBuilder,
          (
            HoldingLot,
            BaseReferences<_$AppDatabase, $HoldingLotsTable, HoldingLot>,
          ),
          HoldingLot,
          PrefetchHooks Function()
        > {
  $$HoldingLotsTableTableManager(_$AppDatabase db, $HoldingLotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HoldingLotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HoldingLotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HoldingLotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> holdingId = const Value.absent(),
                Value<String> securityId = const Value.absent(),
                Value<DateTime> acquiredDate = const Value.absent(),
                Value<String> acquiredTradeId = const Value.absent(),
                Value<int> priceCents = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> remainingQuantity = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => HoldingLotsCompanion(
                id: id,
                holdingId: holdingId,
                securityId: securityId,
                acquiredDate: acquiredDate,
                acquiredTradeId: acquiredTradeId,
                priceCents: priceCents,
                quantity: quantity,
                remainingQuantity: remainingQuantity,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String holdingId,
                required String securityId,
                required DateTime acquiredDate,
                required String acquiredTradeId,
                required int priceCents,
                required double quantity,
                required double remainingQuantity,
                Value<int> rowid = const Value.absent(),
              }) => HoldingLotsCompanion.insert(
                id: id,
                holdingId: holdingId,
                securityId: securityId,
                acquiredDate: acquiredDate,
                acquiredTradeId: acquiredTradeId,
                priceCents: priceCents,
                quantity: quantity,
                remainingQuantity: remainingQuantity,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$HoldingLotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $HoldingLotsTable,
      HoldingLot,
      $$HoldingLotsTableFilterComposer,
      $$HoldingLotsTableOrderingComposer,
      $$HoldingLotsTableAnnotationComposer,
      $$HoldingLotsTableCreateCompanionBuilder,
      $$HoldingLotsTableUpdateCompanionBuilder,
      (
        HoldingLot,
        BaseReferences<_$AppDatabase, $HoldingLotsTable, HoldingLot>,
      ),
      HoldingLot,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$ChartOfAccountsTableTableManager get chartOfAccounts =>
      $$ChartOfAccountsTableTableManager(_db, _db.chartOfAccounts);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$TransactionEntriesTableTableManager get transactionEntries =>
      $$TransactionEntriesTableTableManager(_db, _db.transactionEntries);
  $$DebtsTableTableManager get debts =>
      $$DebtsTableTableManager(_db, _db.debts);
  $$PaymentScheduleEntriesTableTableManager get paymentScheduleEntries =>
      $$PaymentScheduleEntriesTableTableManager(
        _db,
        _db.paymentScheduleEntries,
      );
  $$ReminderLogsTableTableManager get reminderLogs =>
      $$ReminderLogsTableTableManager(_db, _db.reminderLogs);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$BudgetItemsTableTableManager get budgetItems =>
      $$BudgetItemsTableTableManager(_db, _db.budgetItems);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$GoalAccountLinksTableTableManager get goalAccountLinks =>
      $$GoalAccountLinksTableTableManager(_db, _db.goalAccountLinks);
  $$GoalDebtLinksTableTableManager get goalDebtLinks =>
      $$GoalDebtLinksTableTableManager(_db, _db.goalDebtLinks);
  $$TagsTableTableManager get tags => $$TagsTableTableManager(_db, _db.tags);
  $$TransactionTagsTableTableManager get transactionTags =>
      $$TransactionTagsTableTableManager(_db, _db.transactionTags);
  $$TransactionTemplatesTableTableManager get transactionTemplates =>
      $$TransactionTemplatesTableTableManager(_db, _db.transactionTemplates);
  $$HoldingsTableTableManager get holdings =>
      $$HoldingsTableTableManager(_db, _db.holdings);
  $$HoldingTransactionsTableTableManager get holdingTransactions =>
      $$HoldingTransactionsTableTableManager(_db, _db.holdingTransactions);
  $$CurrenciesTableTableManager get currencies =>
      $$CurrenciesTableTableManager(_db, _db.currencies);
  $$RateHistoriesTableTableManager get rateHistories =>
      $$RateHistoriesTableTableManager(_db, _db.rateHistories);
  $$SecuritiesTableTableManager get securities =>
      $$SecuritiesTableTableManager(_db, _db.securities);
  $$SecurityPriceHistoriesTableTableManager get securityPriceHistories =>
      $$SecurityPriceHistoriesTableTableManager(
        _db,
        _db.securityPriceHistories,
      );
  $$DebtProgressSnapshotsTableTableManager get debtProgressSnapshots =>
      $$DebtProgressSnapshotsTableTableManager(_db, _db.debtProgressSnapshots);
  $$GoalProgressSnapshotsTableTableManager get goalProgressSnapshots =>
      $$GoalProgressSnapshotsTableTableManager(_db, _db.goalProgressSnapshots);
  $$HoldingSnapshotsTableTableManager get holdingSnapshots =>
      $$HoldingSnapshotsTableTableManager(_db, _db.holdingSnapshots);
  $$HoldingLotsTableTableManager get holdingLots =>
      $$HoldingLotsTableTableManager(_db, _db.holdingLots);
}
