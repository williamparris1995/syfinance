// This is a generated file - do not edit.
//
// Generated from account/v1/account.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use accountTypeDescriptor instead')
const AccountType$json = {
  '1': 'AccountType',
  '2': [
    {'1': 'ACCOUNT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'ACCOUNT_TYPE_ASSET', '2': 1},
    {'1': 'ACCOUNT_TYPE_LIABILITY', '2': 2},
    {'1': 'ACCOUNT_TYPE_EQUITY', '2': 3},
    {'1': 'ACCOUNT_TYPE_INCOME', '2': 4},
    {'1': 'ACCOUNT_TYPE_EXPENSE', '2': 5},
  ],
};

/// Descriptor for `AccountType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List accountTypeDescriptor = $convert.base64Decode(
    'CgtBY2NvdW50VHlwZRIcChhBQ0NPVU5UX1RZUEVfVU5TUEVDSUZJRUQQABIWChJBQ0NPVU5UX1'
    'RZUEVfQVNTRVQQARIaChZBQ0NPVU5UX1RZUEVfTElBQklMSVRZEAISFwoTQUNDT1VOVF9UWVBF'
    'X0VRVUlUWRADEhcKE0FDQ09VTlRfVFlQRV9JTkNPTUUQBBIYChRBQ0NPVU5UX1RZUEVfRVhQRU'
    '5TRRAF');

@$core.Deprecated('Use ownershipDescriptor instead')
const Ownership$json = {
  '1': 'Ownership',
  '2': [
    {'1': 'OWNERSHIP_UNSPECIFIED', '2': 0},
    {'1': 'OWNERSHIP_PERSONAL', '2': 1},
    {'1': 'OWNERSHIP_JOINT', '2': 2},
  ],
};

/// Descriptor for `Ownership`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List ownershipDescriptor = $convert.base64Decode(
    'CglPd25lcnNoaXASGQoVT1dORVJTSElQX1VOU1BFQ0lGSUVEEAASFgoST1dORVJTSElQX1BFUl'
    'NPTkFMEAESEwoPT1dORVJTSElQX0pPSU5UEAI=');

@$core.Deprecated('Use accountStatusDescriptor instead')
const AccountStatus$json = {
  '1': 'AccountStatus',
  '2': [
    {'1': 'ACCOUNT_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'ACCOUNT_STATUS_ACTIVE', '2': 1},
    {'1': 'ACCOUNT_STATUS_ARCHIVED', '2': 2},
  ],
};

/// Descriptor for `AccountStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List accountStatusDescriptor = $convert.base64Decode(
    'Cg1BY2NvdW50U3RhdHVzEh4KGkFDQ09VTlRfU1RBVFVTX1VOU1BFQ0lGSUVEEAASGQoVQUNDT1'
    'VOVF9TVEFUVVNfQUNUSVZFEAESGwoXQUNDT1VOVF9TVEFUVVNfQVJDSElWRUQQAg==');

@$core.Deprecated('Use accountCategoryDescriptor instead')
const AccountCategory$json = {
  '1': 'AccountCategory',
  '2': [
    {'1': 'ACCOUNT_CATEGORY_UNSPECIFIED', '2': 0},
    {'1': 'ACCOUNT_CATEGORY_SAVINGS', '2': 1},
    {'1': 'ACCOUNT_CATEGORY_CREDIT_CARD', '2': 2},
    {'1': 'ACCOUNT_CATEGORY_INVESTMENT', '2': 3},
    {'1': 'ACCOUNT_CATEGORY_FIXED_DEPOSIT', '2': 4},
    {'1': 'ACCOUNT_CATEGORY_GOLD_FX', '2': 5},
    {'1': 'ACCOUNT_CATEGORY_REAL_ESTATE', '2': 6},
    {'1': 'ACCOUNT_CATEGORY_LOAN', '2': 7},
    {'1': 'ACCOUNT_CATEGORY_OTHER_ASSET', '2': 8},
    {'1': 'ACCOUNT_CATEGORY_OTHER_LIABILITY', '2': 9},
  ],
};

/// Descriptor for `AccountCategory`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List accountCategoryDescriptor = $convert.base64Decode(
    'Cg9BY2NvdW50Q2F0ZWdvcnkSIAocQUNDT1VOVF9DQVRFR09SWV9VTlNQRUNJRklFRBAAEhwKGE'
    'FDQ09VTlRfQ0FURUdPUllfU0FWSU5HUxABEiAKHEFDQ09VTlRfQ0FURUdPUllfQ1JFRElUX0NB'
    'UkQQAhIfChtBQ0NPVU5UX0NBVEVHT1JZX0lOVkVTVE1FTlQQAxIiCh5BQ0NPVU5UX0NBVEVHT1'
    'JZX0ZJWEVEX0RFUE9TSVQQBBIcChhBQ0NPVU5UX0NBVEVHT1JZX0dPTERfRlgQBRIgChxBQ0NP'
    'VU5UX0NBVEVHT1JZX1JFQUxfRVNUQVRFEAYSGQoVQUNDT1VOVF9DQVRFR09SWV9MT0FOEAcSIA'
    'ocQUNDT1VOVF9DQVRFR09SWV9PVEhFUl9BU1NFVBAIEiQKIEFDQ09VTlRfQ0FURUdPUllfT1RI'
    'RVJfTElBQklMSVRZEAk=');

@$core.Deprecated('Use accountDTODescriptor instead')
const AccountDTO$json = {
  '1': 'AccountDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'account_type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountType',
      '10': 'accountType'
    },
    {'1': 'currency_code', '3': 4, '4': 1, '5': 9, '10': 'currencyCode'},
    {
      '1': 'initial_balance_cents',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'initialBalanceCents'
    },
    {
      '1': 'current_balance_cents',
      '3': 6,
      '4': 1,
      '5': 3,
      '10': 'currentBalanceCents'
    },
    {
      '1': 'ownership',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.Ownership',
      '10': 'ownership'
    },
    {'1': 'icon', '3': 8, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'color', '3': 9, '4': 1, '5': 9, '10': 'color'},
    {'1': 'chart_code', '3': 10, '4': 1, '5': 9, '10': 'chartCode'},
    {'1': 'parent_id', '3': 11, '4': 1, '5': 9, '10': 'parentId'},
    {'1': 'institution', '3': 12, '4': 1, '5': 9, '10': 'institution'},
    {
      '1': 'credit_limit_cents',
      '3': 13,
      '4': 1,
      '5': 3,
      '10': 'creditLimitCents'
    },
    {
      '1': 'status',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountStatus',
      '10': 'status'
    },
    {'1': 'version', '3': 15, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'created_at',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
    {
      '1': 'category',
      '3': 18,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountCategory',
      '10': 'category'
    },
    {
      '1': 'card_number_tail',
      '3': 19,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'cardNumberTail',
      '17': true
    },
    {'1': 'notes', '3': 20, '4': 1, '5': 9, '9': 1, '10': 'notes', '17': true},
    {
      '1': 'opening_date',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'openingDate'
    },
    {
      '1': 'interest_rate',
      '3': 22,
      '4': 1,
      '5': 1,
      '9': 2,
      '10': 'interestRate',
      '17': true
    },
    {
      '1': 'credit_billing_day',
      '3': 23,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'creditBillingDay',
      '17': true
    },
    {
      '1': 'credit_repayment_day',
      '3': 24,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'creditRepaymentDay',
      '17': true
    },
    {
      '1': 'credit_annual_fee_cents',
      '3': 25,
      '4': 1,
      '5': 3,
      '9': 5,
      '10': 'creditAnnualFeeCents',
      '17': true
    },
    {
      '1': 'invest_cost_cents',
      '3': 26,
      '4': 1,
      '5': 3,
      '9': 6,
      '10': 'investCostCents',
      '17': true
    },
    {
      '1': 'invest_market_value_cents',
      '3': 27,
      '4': 1,
      '5': 3,
      '9': 7,
      '10': 'investMarketValueCents',
      '17': true
    },
    {
      '1': 'invest_return_ytd',
      '3': 28,
      '4': 1,
      '5': 1,
      '9': 8,
      '10': 'investReturnYtd',
      '17': true
    },
    {
      '1': 'fixed_principal_cents',
      '3': 29,
      '4': 1,
      '5': 3,
      '9': 9,
      '10': 'fixedPrincipalCents',
      '17': true
    },
    {
      '1': 'fixed_start_date',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'fixedStartDate'
    },
    {
      '1': 'fixed_maturity_date',
      '3': 31,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'fixedMaturityDate'
    },
    {
      '1': 'fixed_term_months',
      '3': 32,
      '4': 1,
      '5': 5,
      '9': 10,
      '10': 'fixedTermMonths',
      '17': true
    },
    {
      '1': 'gold_product_type',
      '3': 33,
      '4': 1,
      '5': 9,
      '9': 11,
      '10': 'goldProductType',
      '17': true
    },
    {
      '1': 'gold_quantity',
      '3': 34,
      '4': 1,
      '5': 1,
      '9': 12,
      '10': 'goldQuantity',
      '17': true
    },
    {
      '1': 'gold_buy_price_cents',
      '3': 35,
      '4': 1,
      '5': 3,
      '9': 13,
      '10': 'goldBuyPriceCents',
      '17': true
    },
    {
      '1': 'gold_current_price_cents',
      '3': 36,
      '4': 1,
      '5': 3,
      '9': 14,
      '10': 'goldCurrentPriceCents',
      '17': true
    },
    {
      '1': 'estate_purchase_price_cents',
      '3': 37,
      '4': 1,
      '5': 3,
      '9': 15,
      '10': 'estatePurchasePriceCents',
      '17': true
    },
    {
      '1': 'estate_current_value_cents',
      '3': 38,
      '4': 1,
      '5': 3,
      '9': 16,
      '10': 'estateCurrentValueCents',
      '17': true
    },
    {
      '1': 'estate_purchase_date',
      '3': 39,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'estatePurchaseDate'
    },
    {
      '1': 'estate_depreciation_rate',
      '3': 40,
      '4': 1,
      '5': 1,
      '9': 17,
      '10': 'estateDepreciationRate',
      '17': true
    },
    {
      '1': 'loan_original_cents',
      '3': 41,
      '4': 1,
      '5': 3,
      '9': 18,
      '10': 'loanOriginalCents',
      '17': true
    },
    {
      '1': 'loan_remaining_cents',
      '3': 42,
      '4': 1,
      '5': 3,
      '9': 19,
      '10': 'loanRemainingCents',
      '17': true
    },
    {
      '1': 'loan_monthly_cents',
      '3': 43,
      '4': 1,
      '5': 3,
      '9': 20,
      '10': 'loanMonthlyCents',
      '17': true
    },
    {
      '1': 'loan_next_payment_date',
      '3': 44,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'loanNextPaymentDate'
    },
    {'1': 'is_system', '3': 45, '4': 1, '5': 8, '10': 'isSystem'},
    {'1': 'sort_order', '3': 46, '4': 1, '5': 5, '10': 'sortOrder'},
  ],
  '8': [
    {'1': '_card_number_tail'},
    {'1': '_notes'},
    {'1': '_interest_rate'},
    {'1': '_credit_billing_day'},
    {'1': '_credit_repayment_day'},
    {'1': '_credit_annual_fee_cents'},
    {'1': '_invest_cost_cents'},
    {'1': '_invest_market_value_cents'},
    {'1': '_invest_return_ytd'},
    {'1': '_fixed_principal_cents'},
    {'1': '_fixed_term_months'},
    {'1': '_gold_product_type'},
    {'1': '_gold_quantity'},
    {'1': '_gold_buy_price_cents'},
    {'1': '_gold_current_price_cents'},
    {'1': '_estate_purchase_price_cents'},
    {'1': '_estate_current_value_cents'},
    {'1': '_estate_depreciation_rate'},
    {'1': '_loan_original_cents'},
    {'1': '_loan_remaining_cents'},
    {'1': '_loan_monthly_cents'},
  ],
};

/// Descriptor for `AccountDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accountDTODescriptor = $convert.base64Decode(
    'CgpBY2NvdW50RFRPEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEkAKDGFjY2'
    '91bnRfdHlwZRgDIAEoDjIdLnl1Y2FpLmFjY291bnQudjEuQWNjb3VudFR5cGVSC2FjY291bnRU'
    'eXBlEiMKDWN1cnJlbmN5X2NvZGUYBCABKAlSDGN1cnJlbmN5Q29kZRIyChVpbml0aWFsX2JhbG'
    'FuY2VfY2VudHMYBSABKANSE2luaXRpYWxCYWxhbmNlQ2VudHMSMgoVY3VycmVudF9iYWxhbmNl'
    'X2NlbnRzGAYgASgDUhNjdXJyZW50QmFsYW5jZUNlbnRzEjkKCW93bmVyc2hpcBgHIAEoDjIbLn'
    'l1Y2FpLmFjY291bnQudjEuT3duZXJzaGlwUglvd25lcnNoaXASEgoEaWNvbhgIIAEoCVIEaWNv'
    'bhIUCgVjb2xvchgJIAEoCVIFY29sb3ISHQoKY2hhcnRfY29kZRgKIAEoCVIJY2hhcnRDb2RlEh'
    'sKCXBhcmVudF9pZBgLIAEoCVIIcGFyZW50SWQSIAoLaW5zdGl0dXRpb24YDCABKAlSC2luc3Rp'
    'dHV0aW9uEiwKEmNyZWRpdF9saW1pdF9jZW50cxgNIAEoA1IQY3JlZGl0TGltaXRDZW50cxI3Cg'
    'ZzdGF0dXMYDiABKA4yHy55dWNhaS5hY2NvdW50LnYxLkFjY291bnRTdGF0dXNSBnN0YXR1cxIY'
    'Cgd2ZXJzaW9uGA8gASgDUgd2ZXJzaW9uEjkKCmNyZWF0ZWRfYXQYECABKAsyGi5nb29nbGUucH'
    'JvdG9idWYuVGltZXN0YW1wUgljcmVhdGVkQXQSOQoKdXBkYXRlZF9hdBgRIAEoCzIaLmdvb2ds'
    'ZS5wcm90b2J1Zi5UaW1lc3RhbXBSCXVwZGF0ZWRBdBI9CghjYXRlZ29yeRgSIAEoDjIhLnl1Y2'
    'FpLmFjY291bnQudjEuQWNjb3VudENhdGVnb3J5UghjYXRlZ29yeRItChBjYXJkX251bWJlcl90'
    'YWlsGBMgASgJSABSDmNhcmROdW1iZXJUYWlsiAEBEhkKBW5vdGVzGBQgASgJSAFSBW5vdGVziA'
    'EBEj0KDG9wZW5pbmdfZGF0ZRgVIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSC29w'
    'ZW5pbmdEYXRlEigKDWludGVyZXN0X3JhdGUYFiABKAFIAlIMaW50ZXJlc3RSYXRliAEBEjEKEm'
    'NyZWRpdF9iaWxsaW5nX2RheRgXIAEoBUgDUhBjcmVkaXRCaWxsaW5nRGF5iAEBEjUKFGNyZWRp'
    'dF9yZXBheW1lbnRfZGF5GBggASgFSARSEmNyZWRpdFJlcGF5bWVudERheYgBARI6ChdjcmVkaX'
    'RfYW5udWFsX2ZlZV9jZW50cxgZIAEoA0gFUhRjcmVkaXRBbm51YWxGZWVDZW50c4gBARIvChFp'
    'bnZlc3RfY29zdF9jZW50cxgaIAEoA0gGUg9pbnZlc3RDb3N0Q2VudHOIAQESPgoZaW52ZXN0X2'
    '1hcmtldF92YWx1ZV9jZW50cxgbIAEoA0gHUhZpbnZlc3RNYXJrZXRWYWx1ZUNlbnRziAEBEi8K'
    'EWludmVzdF9yZXR1cm5feXRkGBwgASgBSAhSD2ludmVzdFJldHVybll0ZIgBARI3ChVmaXhlZF'
    '9wcmluY2lwYWxfY2VudHMYHSABKANICVITZml4ZWRQcmluY2lwYWxDZW50c4gBARJEChBmaXhl'
    'ZF9zdGFydF9kYXRlGB4gASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIOZml4ZWRTdG'
    'FydERhdGUSSgoTZml4ZWRfbWF0dXJpdHlfZGF0ZRgfIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5U'
    'aW1lc3RhbXBSEWZpeGVkTWF0dXJpdHlEYXRlEi8KEWZpeGVkX3Rlcm1fbW9udGhzGCAgASgFSA'
    'pSD2ZpeGVkVGVybU1vbnRoc4gBARIvChFnb2xkX3Byb2R1Y3RfdHlwZRghIAEoCUgLUg9nb2xk'
    'UHJvZHVjdFR5cGWIAQESKAoNZ29sZF9xdWFudGl0eRgiIAEoAUgMUgxnb2xkUXVhbnRpdHmIAQ'
    'ESNAoUZ29sZF9idXlfcHJpY2VfY2VudHMYIyABKANIDVIRZ29sZEJ1eVByaWNlQ2VudHOIAQES'
    'PAoYZ29sZF9jdXJyZW50X3ByaWNlX2NlbnRzGCQgASgDSA5SFWdvbGRDdXJyZW50UHJpY2VDZW'
    '50c4gBARJCChtlc3RhdGVfcHVyY2hhc2VfcHJpY2VfY2VudHMYJSABKANID1IYZXN0YXRlUHVy'
    'Y2hhc2VQcmljZUNlbnRziAEBEkAKGmVzdGF0ZV9jdXJyZW50X3ZhbHVlX2NlbnRzGCYgASgDSB'
    'BSF2VzdGF0ZUN1cnJlbnRWYWx1ZUNlbnRziAEBEkwKFGVzdGF0ZV9wdXJjaGFzZV9kYXRlGCcg'
    'ASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFISZXN0YXRlUHVyY2hhc2VEYXRlEj0KGG'
    'VzdGF0ZV9kZXByZWNpYXRpb25fcmF0ZRgoIAEoAUgRUhZlc3RhdGVEZXByZWNpYXRpb25SYXRl'
    'iAEBEjMKE2xvYW5fb3JpZ2luYWxfY2VudHMYKSABKANIElIRbG9hbk9yaWdpbmFsQ2VudHOIAQ'
    'ESNQoUbG9hbl9yZW1haW5pbmdfY2VudHMYKiABKANIE1ISbG9hblJlbWFpbmluZ0NlbnRziAEB'
    'EjEKEmxvYW5fbW9udGhseV9jZW50cxgrIAEoA0gUUhBsb2FuTW9udGhseUNlbnRziAEBEk8KFm'
    'xvYW5fbmV4dF9wYXltZW50X2RhdGUYLCABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1w'
    'UhNsb2FuTmV4dFBheW1lbnREYXRlEhsKCWlzX3N5c3RlbRgtIAEoCFIIaXNTeXN0ZW0SHQoKc2'
    '9ydF9vcmRlchguIAEoBVIJc29ydE9yZGVyQhMKEV9jYXJkX251bWJlcl90YWlsQggKBl9ub3Rl'
    'c0IQCg5faW50ZXJlc3RfcmF0ZUIVChNfY3JlZGl0X2JpbGxpbmdfZGF5QhcKFV9jcmVkaXRfcm'
    'VwYXltZW50X2RheUIaChhfY3JlZGl0X2FubnVhbF9mZWVfY2VudHNCFAoSX2ludmVzdF9jb3N0'
    'X2NlbnRzQhwKGl9pbnZlc3RfbWFya2V0X3ZhbHVlX2NlbnRzQhQKEl9pbnZlc3RfcmV0dXJuX3'
    'l0ZEIYChZfZml4ZWRfcHJpbmNpcGFsX2NlbnRzQhQKEl9maXhlZF90ZXJtX21vbnRoc0IUChJf'
    'Z29sZF9wcm9kdWN0X3R5cGVCEAoOX2dvbGRfcXVhbnRpdHlCFwoVX2dvbGRfYnV5X3ByaWNlX2'
    'NlbnRzQhsKGV9nb2xkX2N1cnJlbnRfcHJpY2VfY2VudHNCHgocX2VzdGF0ZV9wdXJjaGFzZV9w'
    'cmljZV9jZW50c0IdChtfZXN0YXRlX2N1cnJlbnRfdmFsdWVfY2VudHNCGwoZX2VzdGF0ZV9kZX'
    'ByZWNpYXRpb25fcmF0ZUIWChRfbG9hbl9vcmlnaW5hbF9jZW50c0IXChVfbG9hbl9yZW1haW5p'
    'bmdfY2VudHNCFQoTX2xvYW5fbW9udGhseV9jZW50cw==');

@$core.Deprecated('Use createAccountRequestDescriptor instead')
const CreateAccountRequest$json = {
  '1': 'CreateAccountRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'account_type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountType',
      '10': 'accountType'
    },
    {'1': 'currency_code', '3': 3, '4': 1, '5': 9, '10': 'currencyCode'},
    {
      '1': 'initial_balance_cents',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'initialBalanceCents'
    },
    {
      '1': 'ownership',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.Ownership',
      '10': 'ownership'
    },
    {'1': 'icon', '3': 6, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'color', '3': 7, '4': 1, '5': 9, '10': 'color'},
    {'1': 'chart_code', '3': 8, '4': 1, '5': 9, '10': 'chartCode'},
    {'1': 'parent_id', '3': 9, '4': 1, '5': 9, '10': 'parentId'},
    {'1': 'institution', '3': 10, '4': 1, '5': 9, '10': 'institution'},
    {
      '1': 'credit_limit_cents',
      '3': 11,
      '4': 1,
      '5': 3,
      '10': 'creditLimitCents'
    },
    {
      '1': 'category',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountCategory',
      '10': 'category'
    },
    {
      '1': 'card_number_tail',
      '3': 13,
      '4': 1,
      '5': 9,
      '9': 0,
      '10': 'cardNumberTail',
      '17': true
    },
    {'1': 'notes', '3': 14, '4': 1, '5': 9, '9': 1, '10': 'notes', '17': true},
    {
      '1': 'opening_date',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'openingDate'
    },
    {
      '1': 'interest_rate',
      '3': 16,
      '4': 1,
      '5': 1,
      '9': 2,
      '10': 'interestRate',
      '17': true
    },
    {
      '1': 'credit_billing_day',
      '3': 17,
      '4': 1,
      '5': 5,
      '9': 3,
      '10': 'creditBillingDay',
      '17': true
    },
    {
      '1': 'credit_repayment_day',
      '3': 18,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'creditRepaymentDay',
      '17': true
    },
    {
      '1': 'credit_annual_fee_cents',
      '3': 19,
      '4': 1,
      '5': 3,
      '9': 5,
      '10': 'creditAnnualFeeCents',
      '17': true
    },
    {
      '1': 'invest_cost_cents',
      '3': 20,
      '4': 1,
      '5': 3,
      '9': 6,
      '10': 'investCostCents',
      '17': true
    },
    {
      '1': 'invest_market_value_cents',
      '3': 21,
      '4': 1,
      '5': 3,
      '9': 7,
      '10': 'investMarketValueCents',
      '17': true
    },
    {
      '1': 'invest_return_ytd',
      '3': 22,
      '4': 1,
      '5': 1,
      '9': 8,
      '10': 'investReturnYtd',
      '17': true
    },
    {
      '1': 'fixed_principal_cents',
      '3': 23,
      '4': 1,
      '5': 3,
      '9': 9,
      '10': 'fixedPrincipalCents',
      '17': true
    },
    {
      '1': 'fixed_start_date',
      '3': 24,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'fixedStartDate'
    },
    {
      '1': 'fixed_maturity_date',
      '3': 25,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'fixedMaturityDate'
    },
    {
      '1': 'fixed_term_months',
      '3': 26,
      '4': 1,
      '5': 5,
      '9': 10,
      '10': 'fixedTermMonths',
      '17': true
    },
    {
      '1': 'gold_product_type',
      '3': 27,
      '4': 1,
      '5': 9,
      '9': 11,
      '10': 'goldProductType',
      '17': true
    },
    {
      '1': 'gold_quantity',
      '3': 28,
      '4': 1,
      '5': 1,
      '9': 12,
      '10': 'goldQuantity',
      '17': true
    },
    {
      '1': 'gold_buy_price_cents',
      '3': 29,
      '4': 1,
      '5': 3,
      '9': 13,
      '10': 'goldBuyPriceCents',
      '17': true
    },
    {
      '1': 'gold_current_price_cents',
      '3': 30,
      '4': 1,
      '5': 3,
      '9': 14,
      '10': 'goldCurrentPriceCents',
      '17': true
    },
    {
      '1': 'estate_purchase_price_cents',
      '3': 31,
      '4': 1,
      '5': 3,
      '9': 15,
      '10': 'estatePurchasePriceCents',
      '17': true
    },
    {
      '1': 'estate_current_value_cents',
      '3': 32,
      '4': 1,
      '5': 3,
      '9': 16,
      '10': 'estateCurrentValueCents',
      '17': true
    },
    {
      '1': 'estate_purchase_date',
      '3': 33,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'estatePurchaseDate'
    },
    {
      '1': 'estate_depreciation_rate',
      '3': 34,
      '4': 1,
      '5': 1,
      '9': 17,
      '10': 'estateDepreciationRate',
      '17': true
    },
    {
      '1': 'loan_original_cents',
      '3': 35,
      '4': 1,
      '5': 3,
      '9': 18,
      '10': 'loanOriginalCents',
      '17': true
    },
    {
      '1': 'loan_remaining_cents',
      '3': 36,
      '4': 1,
      '5': 3,
      '9': 19,
      '10': 'loanRemainingCents',
      '17': true
    },
    {
      '1': 'loan_monthly_cents',
      '3': 37,
      '4': 1,
      '5': 3,
      '9': 20,
      '10': 'loanMonthlyCents',
      '17': true
    },
    {
      '1': 'loan_next_payment_date',
      '3': 38,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'loanNextPaymentDate'
    },
  ],
  '8': [
    {'1': '_card_number_tail'},
    {'1': '_notes'},
    {'1': '_interest_rate'},
    {'1': '_credit_billing_day'},
    {'1': '_credit_repayment_day'},
    {'1': '_credit_annual_fee_cents'},
    {'1': '_invest_cost_cents'},
    {'1': '_invest_market_value_cents'},
    {'1': '_invest_return_ytd'},
    {'1': '_fixed_principal_cents'},
    {'1': '_fixed_term_months'},
    {'1': '_gold_product_type'},
    {'1': '_gold_quantity'},
    {'1': '_gold_buy_price_cents'},
    {'1': '_gold_current_price_cents'},
    {'1': '_estate_purchase_price_cents'},
    {'1': '_estate_current_value_cents'},
    {'1': '_estate_depreciation_rate'},
    {'1': '_loan_original_cents'},
    {'1': '_loan_remaining_cents'},
    {'1': '_loan_monthly_cents'},
  ],
};

/// Descriptor for `CreateAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createAccountRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVBY2NvdW50UmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1lEkAKDGFjY291bnRfdH'
    'lwZRgCIAEoDjIdLnl1Y2FpLmFjY291bnQudjEuQWNjb3VudFR5cGVSC2FjY291bnRUeXBlEiMK'
    'DWN1cnJlbmN5X2NvZGUYAyABKAlSDGN1cnJlbmN5Q29kZRIyChVpbml0aWFsX2JhbGFuY2VfY2'
    'VudHMYBCABKANSE2luaXRpYWxCYWxhbmNlQ2VudHMSOQoJb3duZXJzaGlwGAUgASgOMhsueXVj'
    'YWkuYWNjb3VudC52MS5Pd25lcnNoaXBSCW93bmVyc2hpcBISCgRpY29uGAYgASgJUgRpY29uEh'
    'QKBWNvbG9yGAcgASgJUgVjb2xvchIdCgpjaGFydF9jb2RlGAggASgJUgljaGFydENvZGUSGwoJ'
    'cGFyZW50X2lkGAkgASgJUghwYXJlbnRJZBIgCgtpbnN0aXR1dGlvbhgKIAEoCVILaW5zdGl0dX'
    'Rpb24SLAoSY3JlZGl0X2xpbWl0X2NlbnRzGAsgASgDUhBjcmVkaXRMaW1pdENlbnRzEj0KCGNh'
    'dGVnb3J5GAwgASgOMiEueXVjYWkuYWNjb3VudC52MS5BY2NvdW50Q2F0ZWdvcnlSCGNhdGVnb3'
    'J5Ei0KEGNhcmRfbnVtYmVyX3RhaWwYDSABKAlIAFIOY2FyZE51bWJlclRhaWyIAQESGQoFbm90'
    'ZXMYDiABKAlIAVIFbm90ZXOIAQESPQoMb3BlbmluZ19kYXRlGA8gASgLMhouZ29vZ2xlLnByb3'
    'RvYnVmLlRpbWVzdGFtcFILb3BlbmluZ0RhdGUSKAoNaW50ZXJlc3RfcmF0ZRgQIAEoAUgCUgxp'
    'bnRlcmVzdFJhdGWIAQESMQoSY3JlZGl0X2JpbGxpbmdfZGF5GBEgASgFSANSEGNyZWRpdEJpbG'
    'xpbmdEYXmIAQESNQoUY3JlZGl0X3JlcGF5bWVudF9kYXkYEiABKAVIBFISY3JlZGl0UmVwYXlt'
    'ZW50RGF5iAEBEjoKF2NyZWRpdF9hbm51YWxfZmVlX2NlbnRzGBMgASgDSAVSFGNyZWRpdEFubn'
    'VhbEZlZUNlbnRziAEBEi8KEWludmVzdF9jb3N0X2NlbnRzGBQgASgDSAZSD2ludmVzdENvc3RD'
    'ZW50c4gBARI+ChlpbnZlc3RfbWFya2V0X3ZhbHVlX2NlbnRzGBUgASgDSAdSFmludmVzdE1hcm'
    'tldFZhbHVlQ2VudHOIAQESLwoRaW52ZXN0X3JldHVybl95dGQYFiABKAFICFIPaW52ZXN0UmV0'
    'dXJuWXRkiAEBEjcKFWZpeGVkX3ByaW5jaXBhbF9jZW50cxgXIAEoA0gJUhNmaXhlZFByaW5jaX'
    'BhbENlbnRziAEBEkQKEGZpeGVkX3N0YXJ0X2RhdGUYGCABKAsyGi5nb29nbGUucHJvdG9idWYu'
    'VGltZXN0YW1wUg5maXhlZFN0YXJ0RGF0ZRJKChNmaXhlZF9tYXR1cml0eV9kYXRlGBkgASgLMh'
    'ouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIRZml4ZWRNYXR1cml0eURhdGUSLwoRZml4ZWRf'
    'dGVybV9tb250aHMYGiABKAVIClIPZml4ZWRUZXJtTW9udGhziAEBEi8KEWdvbGRfcHJvZHVjdF'
    '90eXBlGBsgASgJSAtSD2dvbGRQcm9kdWN0VHlwZYgBARIoCg1nb2xkX3F1YW50aXR5GBwgASgB'
    'SAxSDGdvbGRRdWFudGl0eYgBARI0ChRnb2xkX2J1eV9wcmljZV9jZW50cxgdIAEoA0gNUhFnb2'
    'xkQnV5UHJpY2VDZW50c4gBARI8Chhnb2xkX2N1cnJlbnRfcHJpY2VfY2VudHMYHiABKANIDlIV'
    'Z29sZEN1cnJlbnRQcmljZUNlbnRziAEBEkIKG2VzdGF0ZV9wdXJjaGFzZV9wcmljZV9jZW50cx'
    'gfIAEoA0gPUhhlc3RhdGVQdXJjaGFzZVByaWNlQ2VudHOIAQESQAoaZXN0YXRlX2N1cnJlbnRf'
    'dmFsdWVfY2VudHMYICABKANIEFIXZXN0YXRlQ3VycmVudFZhbHVlQ2VudHOIAQESTAoUZXN0YX'
    'RlX3B1cmNoYXNlX2RhdGUYISABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUhJlc3Rh'
    'dGVQdXJjaGFzZURhdGUSPQoYZXN0YXRlX2RlcHJlY2lhdGlvbl9yYXRlGCIgASgBSBFSFmVzdG'
    'F0ZURlcHJlY2lhdGlvblJhdGWIAQESMwoTbG9hbl9vcmlnaW5hbF9jZW50cxgjIAEoA0gSUhFs'
    'b2FuT3JpZ2luYWxDZW50c4gBARI1ChRsb2FuX3JlbWFpbmluZ19jZW50cxgkIAEoA0gTUhJsb2'
    'FuUmVtYWluaW5nQ2VudHOIAQESMQoSbG9hbl9tb250aGx5X2NlbnRzGCUgASgDSBRSEGxvYW5N'
    'b250aGx5Q2VudHOIAQESTwoWbG9hbl9uZXh0X3BheW1lbnRfZGF0ZRgmIAEoCzIaLmdvb2dsZS'
    '5wcm90b2J1Zi5UaW1lc3RhbXBSE2xvYW5OZXh0UGF5bWVudERhdGVCEwoRX2NhcmRfbnVtYmVy'
    'X3RhaWxCCAoGX25vdGVzQhAKDl9pbnRlcmVzdF9yYXRlQhUKE19jcmVkaXRfYmlsbGluZ19kYX'
    'lCFwoVX2NyZWRpdF9yZXBheW1lbnRfZGF5QhoKGF9jcmVkaXRfYW5udWFsX2ZlZV9jZW50c0IU'
    'ChJfaW52ZXN0X2Nvc3RfY2VudHNCHAoaX2ludmVzdF9tYXJrZXRfdmFsdWVfY2VudHNCFAoSX2'
    'ludmVzdF9yZXR1cm5feXRkQhgKFl9maXhlZF9wcmluY2lwYWxfY2VudHNCFAoSX2ZpeGVkX3Rl'
    'cm1fbW9udGhzQhQKEl9nb2xkX3Byb2R1Y3RfdHlwZUIQCg5fZ29sZF9xdWFudGl0eUIXChVfZ2'
    '9sZF9idXlfcHJpY2VfY2VudHNCGwoZX2dvbGRfY3VycmVudF9wcmljZV9jZW50c0IeChxfZXN0'
    'YXRlX3B1cmNoYXNlX3ByaWNlX2NlbnRzQh0KG19lc3RhdGVfY3VycmVudF92YWx1ZV9jZW50c0'
    'IbChlfZXN0YXRlX2RlcHJlY2lhdGlvbl9yYXRlQhYKFF9sb2FuX29yaWdpbmFsX2NlbnRzQhcK'
    'FV9sb2FuX3JlbWFpbmluZ19jZW50c0IVChNfbG9hbl9tb250aGx5X2NlbnRz');

@$core.Deprecated('Use getAccountRequestDescriptor instead')
const GetAccountRequest$json = {
  '1': 'GetAccountRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAccountRequestDescriptor =
    $convert.base64Decode('ChFHZXRBY2NvdW50UmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use listAccountsRequestDescriptor instead')
const ListAccountsRequest$json = {
  '1': 'ListAccountsRequest',
  '2': [
    {
      '1': 'page',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageRequest',
      '10': 'page'
    },
    {
      '1': 'account_type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountType',
      '10': 'accountType'
    },
    {
      '1': 'status',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountStatus',
      '10': 'status'
    },
  ],
};

/// Descriptor for `ListAccountsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAccountsRequestDescriptor = $convert.base64Decode(
    'ChNMaXN0QWNjb3VudHNSZXF1ZXN0EjAKBHBhZ2UYASABKAsyHC55dWNhaS5jb21tb24udjEuUG'
    'FnZVJlcXVlc3RSBHBhZ2USQAoMYWNjb3VudF90eXBlGAIgASgOMh0ueXVjYWkuYWNjb3VudC52'
    'MS5BY2NvdW50VHlwZVILYWNjb3VudFR5cGUSNwoGc3RhdHVzGAMgASgOMh8ueXVjYWkuYWNjb3'
    'VudC52MS5BY2NvdW50U3RhdHVzUgZzdGF0dXM=');

@$core.Deprecated('Use listAccountsResponseDescriptor instead')
const ListAccountsResponse$json = {
  '1': 'ListAccountsResponse',
  '2': [
    {
      '1': 'accounts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.account.v1.AccountDTO',
      '10': 'accounts'
    },
    {
      '1': 'page',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageResponse',
      '10': 'page'
    },
  ],
};

/// Descriptor for `ListAccountsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAccountsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0QWNjb3VudHNSZXNwb25zZRI4CghhY2NvdW50cxgBIAMoCzIcLnl1Y2FpLmFjY291bn'
    'QudjEuQWNjb3VudERUT1IIYWNjb3VudHMSMQoEcGFnZRgCIAEoCzIdLnl1Y2FpLmNvbW1vbi52'
    'MS5QYWdlUmVzcG9uc2VSBHBhZ2U=');

@$core.Deprecated('Use updateAccountRequestDescriptor instead')
const UpdateAccountRequest$json = {
  '1': 'UpdateAccountRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'color', '3': 4, '4': 1, '5': 9, '10': 'color'},
    {'1': 'chart_code', '3': 5, '4': 1, '5': 9, '10': 'chartCode'},
    {'1': 'institution', '3': 6, '4': 1, '5': 9, '10': 'institution'},
    {
      '1': 'credit_limit_cents',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'creditLimitCents'
    },
    {'1': 'version', '3': 8, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'status',
      '3': 9,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountStatus',
      '9': 0,
      '10': 'status',
      '17': true
    },
    {
      '1': 'card_number_tail',
      '3': 10,
      '4': 1,
      '5': 9,
      '9': 1,
      '10': 'cardNumberTail',
      '17': true
    },
    {'1': 'notes', '3': 11, '4': 1, '5': 9, '9': 2, '10': 'notes', '17': true},
    {
      '1': 'opening_date',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'openingDate'
    },
    {
      '1': 'interest_rate',
      '3': 13,
      '4': 1,
      '5': 1,
      '9': 3,
      '10': 'interestRate',
      '17': true
    },
    {
      '1': 'credit_billing_day',
      '3': 14,
      '4': 1,
      '5': 5,
      '9': 4,
      '10': 'creditBillingDay',
      '17': true
    },
    {
      '1': 'credit_repayment_day',
      '3': 15,
      '4': 1,
      '5': 5,
      '9': 5,
      '10': 'creditRepaymentDay',
      '17': true
    },
    {
      '1': 'credit_annual_fee_cents',
      '3': 16,
      '4': 1,
      '5': 3,
      '9': 6,
      '10': 'creditAnnualFeeCents',
      '17': true
    },
    {
      '1': 'invest_cost_cents',
      '3': 17,
      '4': 1,
      '5': 3,
      '9': 7,
      '10': 'investCostCents',
      '17': true
    },
    {
      '1': 'invest_market_value_cents',
      '3': 18,
      '4': 1,
      '5': 3,
      '9': 8,
      '10': 'investMarketValueCents',
      '17': true
    },
    {
      '1': 'invest_return_ytd',
      '3': 19,
      '4': 1,
      '5': 1,
      '9': 9,
      '10': 'investReturnYtd',
      '17': true
    },
    {
      '1': 'fixed_principal_cents',
      '3': 20,
      '4': 1,
      '5': 3,
      '9': 10,
      '10': 'fixedPrincipalCents',
      '17': true
    },
    {
      '1': 'fixed_start_date',
      '3': 21,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'fixedStartDate'
    },
    {
      '1': 'fixed_maturity_date',
      '3': 22,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'fixedMaturityDate'
    },
    {
      '1': 'fixed_term_months',
      '3': 23,
      '4': 1,
      '5': 5,
      '9': 11,
      '10': 'fixedTermMonths',
      '17': true
    },
    {
      '1': 'gold_product_type',
      '3': 24,
      '4': 1,
      '5': 9,
      '9': 12,
      '10': 'goldProductType',
      '17': true
    },
    {
      '1': 'gold_quantity',
      '3': 25,
      '4': 1,
      '5': 1,
      '9': 13,
      '10': 'goldQuantity',
      '17': true
    },
    {
      '1': 'gold_buy_price_cents',
      '3': 26,
      '4': 1,
      '5': 3,
      '9': 14,
      '10': 'goldBuyPriceCents',
      '17': true
    },
    {
      '1': 'gold_current_price_cents',
      '3': 27,
      '4': 1,
      '5': 3,
      '9': 15,
      '10': 'goldCurrentPriceCents',
      '17': true
    },
    {
      '1': 'estate_purchase_price_cents',
      '3': 28,
      '4': 1,
      '5': 3,
      '9': 16,
      '10': 'estatePurchasePriceCents',
      '17': true
    },
    {
      '1': 'estate_current_value_cents',
      '3': 29,
      '4': 1,
      '5': 3,
      '9': 17,
      '10': 'estateCurrentValueCents',
      '17': true
    },
    {
      '1': 'estate_purchase_date',
      '3': 30,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'estatePurchaseDate'
    },
    {
      '1': 'estate_depreciation_rate',
      '3': 31,
      '4': 1,
      '5': 1,
      '9': 18,
      '10': 'estateDepreciationRate',
      '17': true
    },
    {
      '1': 'loan_original_cents',
      '3': 32,
      '4': 1,
      '5': 3,
      '9': 19,
      '10': 'loanOriginalCents',
      '17': true
    },
    {
      '1': 'loan_remaining_cents',
      '3': 33,
      '4': 1,
      '5': 3,
      '9': 20,
      '10': 'loanRemainingCents',
      '17': true
    },
    {
      '1': 'loan_monthly_cents',
      '3': 34,
      '4': 1,
      '5': 3,
      '9': 21,
      '10': 'loanMonthlyCents',
      '17': true
    },
    {
      '1': 'loan_next_payment_date',
      '3': 35,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'loanNextPaymentDate'
    },
    {
      '1': 'parent_id',
      '3': 36,
      '4': 1,
      '5': 9,
      '9': 22,
      '10': 'parentId',
      '17': true
    },
    {
      '1': 'current_balance_cents',
      '3': 37,
      '4': 1,
      '5': 3,
      '9': 23,
      '10': 'currentBalanceCents',
      '17': true
    },
  ],
  '8': [
    {'1': '_status'},
    {'1': '_card_number_tail'},
    {'1': '_notes'},
    {'1': '_interest_rate'},
    {'1': '_credit_billing_day'},
    {'1': '_credit_repayment_day'},
    {'1': '_credit_annual_fee_cents'},
    {'1': '_invest_cost_cents'},
    {'1': '_invest_market_value_cents'},
    {'1': '_invest_return_ytd'},
    {'1': '_fixed_principal_cents'},
    {'1': '_fixed_term_months'},
    {'1': '_gold_product_type'},
    {'1': '_gold_quantity'},
    {'1': '_gold_buy_price_cents'},
    {'1': '_gold_current_price_cents'},
    {'1': '_estate_purchase_price_cents'},
    {'1': '_estate_current_value_cents'},
    {'1': '_estate_depreciation_rate'},
    {'1': '_loan_original_cents'},
    {'1': '_loan_remaining_cents'},
    {'1': '_loan_monthly_cents'},
    {'1': '_parent_id'},
    {'1': '_current_balance_cents'},
  ],
};

/// Descriptor for `UpdateAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateAccountRequestDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVBY2NvdW50UmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbm'
    'FtZRISCgRpY29uGAMgASgJUgRpY29uEhQKBWNvbG9yGAQgASgJUgVjb2xvchIdCgpjaGFydF9j'
    'b2RlGAUgASgJUgljaGFydENvZGUSIAoLaW5zdGl0dXRpb24YBiABKAlSC2luc3RpdHV0aW9uEi'
    'wKEmNyZWRpdF9saW1pdF9jZW50cxgHIAEoA1IQY3JlZGl0TGltaXRDZW50cxIYCgd2ZXJzaW9u'
    'GAggASgDUgd2ZXJzaW9uEjwKBnN0YXR1cxgJIAEoDjIfLnl1Y2FpLmFjY291bnQudjEuQWNjb3'
    'VudFN0YXR1c0gAUgZzdGF0dXOIAQESLQoQY2FyZF9udW1iZXJfdGFpbBgKIAEoCUgBUg5jYXJk'
    'TnVtYmVyVGFpbIgBARIZCgVub3RlcxgLIAEoCUgCUgVub3Rlc4gBARI9CgxvcGVuaW5nX2RhdG'
    'UYDCABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgtvcGVuaW5nRGF0ZRIoCg1pbnRl'
    'cmVzdF9yYXRlGA0gASgBSANSDGludGVyZXN0UmF0ZYgBARIxChJjcmVkaXRfYmlsbGluZ19kYX'
    'kYDiABKAVIBFIQY3JlZGl0QmlsbGluZ0RheYgBARI1ChRjcmVkaXRfcmVwYXltZW50X2RheRgP'
    'IAEoBUgFUhJjcmVkaXRSZXBheW1lbnREYXmIAQESOgoXY3JlZGl0X2FubnVhbF9mZWVfY2VudH'
    'MYECABKANIBlIUY3JlZGl0QW5udWFsRmVlQ2VudHOIAQESLwoRaW52ZXN0X2Nvc3RfY2VudHMY'
    'ESABKANIB1IPaW52ZXN0Q29zdENlbnRziAEBEj4KGWludmVzdF9tYXJrZXRfdmFsdWVfY2VudH'
    'MYEiABKANICFIWaW52ZXN0TWFya2V0VmFsdWVDZW50c4gBARIvChFpbnZlc3RfcmV0dXJuX3l0'
    'ZBgTIAEoAUgJUg9pbnZlc3RSZXR1cm5ZdGSIAQESNwoVZml4ZWRfcHJpbmNpcGFsX2NlbnRzGB'
    'QgASgDSApSE2ZpeGVkUHJpbmNpcGFsQ2VudHOIAQESRAoQZml4ZWRfc3RhcnRfZGF0ZRgVIAEo'
    'CzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSDmZpeGVkU3RhcnREYXRlEkoKE2ZpeGVkX2'
    '1hdHVyaXR5X2RhdGUYFiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUhFmaXhlZE1h'
    'dHVyaXR5RGF0ZRIvChFmaXhlZF90ZXJtX21vbnRocxgXIAEoBUgLUg9maXhlZFRlcm1Nb250aH'
    'OIAQESLwoRZ29sZF9wcm9kdWN0X3R5cGUYGCABKAlIDFIPZ29sZFByb2R1Y3RUeXBliAEBEigK'
    'DWdvbGRfcXVhbnRpdHkYGSABKAFIDVIMZ29sZFF1YW50aXR5iAEBEjQKFGdvbGRfYnV5X3ByaW'
    'NlX2NlbnRzGBogASgDSA5SEWdvbGRCdXlQcmljZUNlbnRziAEBEjwKGGdvbGRfY3VycmVudF9w'
    'cmljZV9jZW50cxgbIAEoA0gPUhVnb2xkQ3VycmVudFByaWNlQ2VudHOIAQESQgobZXN0YXRlX3'
    'B1cmNoYXNlX3ByaWNlX2NlbnRzGBwgASgDSBBSGGVzdGF0ZVB1cmNoYXNlUHJpY2VDZW50c4gB'
    'ARJAChplc3RhdGVfY3VycmVudF92YWx1ZV9jZW50cxgdIAEoA0gRUhdlc3RhdGVDdXJyZW50Vm'
    'FsdWVDZW50c4gBARJMChRlc3RhdGVfcHVyY2hhc2VfZGF0ZRgeIAEoCzIaLmdvb2dsZS5wcm90'
    'b2J1Zi5UaW1lc3RhbXBSEmVzdGF0ZVB1cmNoYXNlRGF0ZRI9Chhlc3RhdGVfZGVwcmVjaWF0aW'
    '9uX3JhdGUYHyABKAFIElIWZXN0YXRlRGVwcmVjaWF0aW9uUmF0ZYgBARIzChNsb2FuX29yaWdp'
    'bmFsX2NlbnRzGCAgASgDSBNSEWxvYW5PcmlnaW5hbENlbnRziAEBEjUKFGxvYW5fcmVtYWluaW'
    '5nX2NlbnRzGCEgASgDSBRSEmxvYW5SZW1haW5pbmdDZW50c4gBARIxChJsb2FuX21vbnRobHlf'
    'Y2VudHMYIiABKANIFVIQbG9hbk1vbnRobHlDZW50c4gBARJPChZsb2FuX25leHRfcGF5bWVudF'
    '9kYXRlGCMgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFITbG9hbk5leHRQYXltZW50'
    'RGF0ZRIgCglwYXJlbnRfaWQYJCABKAlIFlIIcGFyZW50SWSIAQESNwoVY3VycmVudF9iYWxhbm'
    'NlX2NlbnRzGCUgASgDSBdSE2N1cnJlbnRCYWxhbmNlQ2VudHOIAQFCCQoHX3N0YXR1c0ITChFf'
    'Y2FyZF9udW1iZXJfdGFpbEIICgZfbm90ZXNCEAoOX2ludGVyZXN0X3JhdGVCFQoTX2NyZWRpdF'
    '9iaWxsaW5nX2RheUIXChVfY3JlZGl0X3JlcGF5bWVudF9kYXlCGgoYX2NyZWRpdF9hbm51YWxf'
    'ZmVlX2NlbnRzQhQKEl9pbnZlc3RfY29zdF9jZW50c0IcChpfaW52ZXN0X21hcmtldF92YWx1ZV'
    '9jZW50c0IUChJfaW52ZXN0X3JldHVybl95dGRCGAoWX2ZpeGVkX3ByaW5jaXBhbF9jZW50c0IU'
    'ChJfZml4ZWRfdGVybV9tb250aHNCFAoSX2dvbGRfcHJvZHVjdF90eXBlQhAKDl9nb2xkX3F1YW'
    '50aXR5QhcKFV9nb2xkX2J1eV9wcmljZV9jZW50c0IbChlfZ29sZF9jdXJyZW50X3ByaWNlX2Nl'
    'bnRzQh4KHF9lc3RhdGVfcHVyY2hhc2VfcHJpY2VfY2VudHNCHQobX2VzdGF0ZV9jdXJyZW50X3'
    'ZhbHVlX2NlbnRzQhsKGV9lc3RhdGVfZGVwcmVjaWF0aW9uX3JhdGVCFgoUX2xvYW5fb3JpZ2lu'
    'YWxfY2VudHNCFwoVX2xvYW5fcmVtYWluaW5nX2NlbnRzQhUKE19sb2FuX21vbnRobHlfY2VudH'
    'NCDAoKX3BhcmVudF9pZEIYChZfY3VycmVudF9iYWxhbmNlX2NlbnRz');

@$core.Deprecated('Use deleteAccountRequestDescriptor instead')
const DeleteAccountRequest$json = {
  '1': 'DeleteAccountRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAccountRequestDescriptor = $convert
    .base64Decode('ChREZWxldGVBY2NvdW50UmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use accountResponseDescriptor instead')
const AccountResponse$json = {
  '1': 'AccountResponse',
  '2': [
    {
      '1': 'account',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.account.v1.AccountDTO',
      '10': 'account'
    },
  ],
};

/// Descriptor for `AccountResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accountResponseDescriptor = $convert.base64Decode(
    'Cg9BY2NvdW50UmVzcG9uc2USNgoHYWNjb3VudBgBIAEoCzIcLnl1Y2FpLmFjY291bnQudjEuQW'
    'Njb3VudERUT1IHYWNjb3VudA==');

@$core.Deprecated('Use findByAccountTypeRequestDescriptor instead')
const FindByAccountTypeRequest$json = {
  '1': 'FindByAccountTypeRequest',
  '2': [
    {
      '1': 'account_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountType',
      '10': 'accountType'
    },
  ],
};

/// Descriptor for `FindByAccountTypeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findByAccountTypeRequestDescriptor =
    $convert.base64Decode(
        'ChhGaW5kQnlBY2NvdW50VHlwZVJlcXVlc3QSQAoMYWNjb3VudF90eXBlGAEgASgOMh0ueXVjYW'
        'kuYWNjb3VudC52MS5BY2NvdW50VHlwZVILYWNjb3VudFR5cGU=');

@$core.Deprecated('Use findByAccountTypeResponseDescriptor instead')
const FindByAccountTypeResponse$json = {
  '1': 'FindByAccountTypeResponse',
  '2': [
    {
      '1': 'accounts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.account.v1.AccountDTO',
      '10': 'accounts'
    },
  ],
};

/// Descriptor for `FindByAccountTypeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List findByAccountTypeResponseDescriptor =
    $convert.base64Decode(
        'ChlGaW5kQnlBY2NvdW50VHlwZVJlc3BvbnNlEjgKCGFjY291bnRzGAEgAygLMhwueXVjYWkuYW'
        'Njb3VudC52MS5BY2NvdW50RFRPUghhY2NvdW50cw==');

@$core.Deprecated('Use createCategoryRequestDescriptor instead')
const CreateCategoryRequest$json = {
  '1': 'CreateCategoryRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'account_type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountType',
      '10': 'accountType'
    },
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'color', '3': 4, '4': 1, '5': 9, '10': 'color'},
    {'1': 'parent_id', '3': 5, '4': 1, '5': 9, '10': 'parentId'},
  ],
};

/// Descriptor for `CreateCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createCategoryRequestDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVDYXRlZ29yeVJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZRJACgxhY2NvdW50X3'
    'R5cGUYAiABKA4yHS55dWNhaS5hY2NvdW50LnYxLkFjY291bnRUeXBlUgthY2NvdW50VHlwZRIS'
    'CgRpY29uGAMgASgJUgRpY29uEhQKBWNvbG9yGAQgASgJUgVjb2xvchIbCglwYXJlbnRfaWQYBS'
    'ABKAlSCHBhcmVudElk');

@$core.Deprecated('Use updateCategoryRequestDescriptor instead')
const UpdateCategoryRequest$json = {
  '1': 'UpdateCategoryRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '9': 0, '10': 'name', '17': true},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '9': 1, '10': 'icon', '17': true},
    {'1': 'color', '3': 4, '4': 1, '5': 9, '9': 2, '10': 'color', '17': true},
    {
      '1': 'parent_id',
      '3': 5,
      '4': 1,
      '5': 9,
      '9': 3,
      '10': 'parentId',
      '17': true
    },
    {'1': 'version', '3': 6, '4': 1, '5': 3, '10': 'version'},
  ],
  '8': [
    {'1': '_name'},
    {'1': '_icon'},
    {'1': '_color'},
    {'1': '_parent_id'},
  ],
};

/// Descriptor for `UpdateCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateCategoryRequestDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVDYXRlZ29yeVJlcXVlc3QSDgoCaWQYASABKAlSAmlkEhcKBG5hbWUYAiABKAlIAF'
    'IEbmFtZYgBARIXCgRpY29uGAMgASgJSAFSBGljb26IAQESGQoFY29sb3IYBCABKAlIAlIFY29s'
    'b3KIAQESIAoJcGFyZW50X2lkGAUgASgJSANSCHBhcmVudElkiAEBEhgKB3ZlcnNpb24YBiABKA'
    'NSB3ZlcnNpb25CBwoFX25hbWVCBwoFX2ljb25CCAoGX2NvbG9yQgwKCl9wYXJlbnRfaWQ=');

@$core.Deprecated('Use reorderCategoriesRequestDescriptor instead')
const ReorderCategoriesRequest$json = {
  '1': 'ReorderCategoriesRequest',
  '2': [
    {
      '1': 'account_type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountType',
      '10': 'accountType'
    },
    {'1': 'ordered_ids', '3': 2, '4': 3, '5': 9, '10': 'orderedIds'},
  ],
};

/// Descriptor for `ReorderCategoriesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List reorderCategoriesRequestDescriptor = $convert.base64Decode(
    'ChhSZW9yZGVyQ2F0ZWdvcmllc1JlcXVlc3QSQAoMYWNjb3VudF90eXBlGAEgASgOMh0ueXVjYW'
    'kuYWNjb3VudC52MS5BY2NvdW50VHlwZVILYWNjb3VudFR5cGUSHwoLb3JkZXJlZF9pZHMYAiAD'
    'KAlSCm9yZGVyZWRJZHM=');

@$core.Deprecated('Use deleteCategoryRequestDescriptor instead')
const DeleteCategoryRequest$json = {
  '1': 'DeleteCategoryRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteCategoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteCategoryRequestDescriptor = $convert
    .base64Decode('ChVEZWxldGVDYXRlZ29yeVJlcXVlc3QSDgoCaWQYASABKAlSAmlk');
