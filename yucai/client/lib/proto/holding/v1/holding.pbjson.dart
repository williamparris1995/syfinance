// This is a generated file - do not edit.
//
// Generated from holding/v1/holding.proto.

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

@$core.Deprecated('Use securityTypeDescriptor instead')
const SecurityType$json = {
  '1': 'SecurityType',
  '2': [
    {'1': 'SECURITY_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'SECURITY_TYPE_STOCK', '2': 1},
    {'1': 'SECURITY_TYPE_FUND', '2': 2},
    {'1': 'SECURITY_TYPE_ETF', '2': 3},
    {'1': 'SECURITY_TYPE_BOND', '2': 4},
    {'1': 'SECURITY_TYPE_GOLD', '2': 5},
    {'1': 'SECURITY_TYPE_OPTION', '2': 6},
    {'1': 'SECURITY_TYPE_OTHER', '2': 7},
  ],
};

/// Descriptor for `SecurityType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List securityTypeDescriptor = $convert.base64Decode(
    'CgxTZWN1cml0eVR5cGUSHQoZU0VDVVJJVFlfVFlQRV9VTlNQRUNJRklFRBAAEhcKE1NFQ1VSSV'
    'RZX1RZUEVfU1RPQ0sQARIWChJTRUNVUklUWV9UWVBFX0ZVTkQQAhIVChFTRUNVUklUWV9UWVBF'
    'X0VURhADEhYKElNFQ1VSSVRZX1RZUEVfQk9ORBAEEhYKElNFQ1VSSVRZX1RZUEVfR09MRBAFEh'
    'gKFFNFQ1VSSVRZX1RZUEVfT1BUSU9OEAYSFwoTU0VDVVJJVFlfVFlQRV9PVEhFUhAH');

@$core.Deprecated('Use tradeTypeDescriptor instead')
const TradeType$json = {
  '1': 'TradeType',
  '2': [
    {'1': 'TRADE_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'TRADE_TYPE_BUY', '2': 1},
    {'1': 'TRADE_TYPE_SELL', '2': 2},
    {'1': 'TRADE_TYPE_DIVIDEND', '2': 3},
    {'1': 'TRADE_TYPE_SPLIT', '2': 4},
  ],
};

/// Descriptor for `TradeType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List tradeTypeDescriptor = $convert.base64Decode(
    'CglUcmFkZVR5cGUSGgoWVFJBREVfVFlQRV9VTlNQRUNJRklFRBAAEhIKDlRSQURFX1RZUEVfQl'
    'VZEAESEwoPVFJBREVfVFlQRV9TRUxMEAISFwoTVFJBREVfVFlQRV9ESVZJREVORBADEhQKEFRS'
    'QURFX1RZUEVfU1BMSVQQBA==');

@$core.Deprecated('Use curveRangeDescriptor instead')
const CurveRange$json = {
  '1': 'CurveRange',
  '2': [
    {'1': 'CURVE_RANGE_UNSPECIFIED', '2': 0},
    {'1': 'CURVE_RANGE_DAY', '2': 1},
    {'1': 'CURVE_RANGE_MONTH', '2': 2},
    {'1': 'CURVE_RANGE_YEAR', '2': 3},
  ],
};

/// Descriptor for `CurveRange`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List curveRangeDescriptor = $convert.base64Decode(
    'CgpDdXJ2ZVJhbmdlEhsKF0NVUlZFX1JBTkdFX1VOU1BFQ0lGSUVEEAASEwoPQ1VSVkVfUkFOR0'
    'VfREFZEAESFQoRQ1VSVkVfUkFOR0VfTU9OVEgQAhIUChBDVVJWRV9SQU5HRV9ZRUFSEAM=');

@$core.Deprecated('Use securityDTODescriptor instead')
const SecurityDTO$json = {
  '1': 'SecurityDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'symbol', '3': 2, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'security_type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.yucai.holding.v1.SecurityType',
      '10': 'securityType'
    },
    {'1': 'exchange', '3': 5, '4': 1, '5': 9, '10': 'exchange'},
    {'1': 'currency_code', '3': 6, '4': 1, '5': 9, '10': 'currencyCode'},
    {
      '1': 'current_price_cents',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'currentPriceCents'
    },
    {
      '1': 'created_at',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
  ],
};

/// Descriptor for `SecurityDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List securityDTODescriptor = $convert.base64Decode(
    'CgtTZWN1cml0eURUTxIOCgJpZBgBIAEoCVICaWQSFgoGc3ltYm9sGAIgASgJUgZzeW1ib2wSEg'
    'oEbmFtZRgDIAEoCVIEbmFtZRJDCg1zZWN1cml0eV90eXBlGAQgASgOMh4ueXVjYWkuaG9sZGlu'
    'Zy52MS5TZWN1cml0eVR5cGVSDHNlY3VyaXR5VHlwZRIaCghleGNoYW5nZRgFIAEoCVIIZXhjaG'
    'FuZ2USIwoNY3VycmVuY3lfY29kZRgGIAEoCVIMY3VycmVuY3lDb2RlEi4KE2N1cnJlbnRfcHJp'
    'Y2VfY2VudHMYByABKANSEWN1cnJlbnRQcmljZUNlbnRzEjkKCmNyZWF0ZWRfYXQYCCABKAsyGi'
    '5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgljcmVhdGVkQXQ=');

@$core.Deprecated('Use holdingDTODescriptor instead')
const HoldingDTO$json = {
  '1': 'HoldingDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'account_id', '3': 2, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'security_id', '3': 3, '4': 1, '5': 9, '10': 'securityId'},
    {'1': 'security_name', '3': 4, '4': 1, '5': 9, '10': 'securityName'},
    {'1': 'security_symbol', '3': 5, '4': 1, '5': 9, '10': 'securitySymbol'},
    {'1': 'quantity', '3': 6, '4': 1, '5': 1, '10': 'quantity'},
    {'1': 'avg_cost_cents', '3': 7, '4': 1, '5': 3, '10': 'avgCostCents'},
    {
      '1': 'market_value_cents',
      '3': 8,
      '4': 1,
      '5': 3,
      '10': 'marketValueCents'
    },
    {
      '1': 'unrealized_pnl_cents',
      '3': 9,
      '4': 1,
      '5': 3,
      '10': 'unrealizedPnlCents'
    },
    {'1': 'version', '3': 10, '4': 1, '5': 3, '10': 'version'},
  ],
};

/// Descriptor for `HoldingDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List holdingDTODescriptor = $convert.base64Decode(
    'CgpIb2xkaW5nRFRPEg4KAmlkGAEgASgJUgJpZBIdCgphY2NvdW50X2lkGAIgASgJUglhY2NvdW'
    '50SWQSHwoLc2VjdXJpdHlfaWQYAyABKAlSCnNlY3VyaXR5SWQSIwoNc2VjdXJpdHlfbmFtZRgE'
    'IAEoCVIMc2VjdXJpdHlOYW1lEicKD3NlY3VyaXR5X3N5bWJvbBgFIAEoCVIOc2VjdXJpdHlTeW'
    '1ib2wSGgoIcXVhbnRpdHkYBiABKAFSCHF1YW50aXR5EiQKDmF2Z19jb3N0X2NlbnRzGAcgASgD'
    'UgxhdmdDb3N0Q2VudHMSLAoSbWFya2V0X3ZhbHVlX2NlbnRzGAggASgDUhBtYXJrZXRWYWx1ZU'
    'NlbnRzEjAKFHVucmVhbGl6ZWRfcG5sX2NlbnRzGAkgASgDUhJ1bnJlYWxpemVkUG5sQ2VudHMS'
    'GAoHdmVyc2lvbhgKIAEoA1IHdmVyc2lvbg==');

@$core.Deprecated('Use holdingTransactionDTODescriptor instead')
const HoldingTransactionDTO$json = {
  '1': 'HoldingTransactionDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'account_id', '3': 2, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'security_id', '3': 3, '4': 1, '5': 9, '10': 'securityId'},
    {
      '1': 'trade_type',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.yucai.holding.v1.TradeType',
      '10': 'tradeType'
    },
    {'1': 'quantity', '3': 5, '4': 1, '5': 1, '10': 'quantity'},
    {'1': 'price_cents', '3': 6, '4': 1, '5': 3, '10': 'priceCents'},
    {'1': 'amount_cents', '3': 7, '4': 1, '5': 3, '10': 'amountCents'},
    {'1': 'fee_cents', '3': 8, '4': 1, '5': 3, '10': 'feeCents'},
    {'1': 'trade_date', '3': 9, '4': 1, '5': 9, '10': 'tradeDate'},
    {'1': 'notes', '3': 10, '4': 1, '5': 9, '10': 'notes'},
    {
      '1': 'created_at',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
  ],
};

/// Descriptor for `HoldingTransactionDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List holdingTransactionDTODescriptor = $convert.base64Decode(
    'ChVIb2xkaW5nVHJhbnNhY3Rpb25EVE8SDgoCaWQYASABKAlSAmlkEh0KCmFjY291bnRfaWQYAi'
    'ABKAlSCWFjY291bnRJZBIfCgtzZWN1cml0eV9pZBgDIAEoCVIKc2VjdXJpdHlJZBI6Cgp0cmFk'
    'ZV90eXBlGAQgASgOMhsueXVjYWkuaG9sZGluZy52MS5UcmFkZVR5cGVSCXRyYWRlVHlwZRIaCg'
    'hxdWFudGl0eRgFIAEoAVIIcXVhbnRpdHkSHwoLcHJpY2VfY2VudHMYBiABKANSCnByaWNlQ2Vu'
    'dHMSIQoMYW1vdW50X2NlbnRzGAcgASgDUgthbW91bnRDZW50cxIbCglmZWVfY2VudHMYCCABKA'
    'NSCGZlZUNlbnRzEh0KCnRyYWRlX2RhdGUYCSABKAlSCXRyYWRlRGF0ZRIUCgVub3RlcxgKIAEo'
    'CVIFbm90ZXMSOQoKY3JlYXRlZF9hdBgLIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbX'
    'BSCWNyZWF0ZWRBdA==');

@$core.Deprecated('Use createSecurityRequestDescriptor instead')
const CreateSecurityRequest$json = {
  '1': 'CreateSecurityRequest',
  '2': [
    {'1': 'symbol', '3': 1, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'security_type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.yucai.holding.v1.SecurityType',
      '10': 'securityType'
    },
    {'1': 'exchange', '3': 4, '4': 1, '5': 9, '10': 'exchange'},
    {'1': 'currency_code', '3': 5, '4': 1, '5': 9, '10': 'currencyCode'},
  ],
};

/// Descriptor for `CreateSecurityRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createSecurityRequestDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVTZWN1cml0eVJlcXVlc3QSFgoGc3ltYm9sGAEgASgJUgZzeW1ib2wSEgoEbmFtZR'
    'gCIAEoCVIEbmFtZRJDCg1zZWN1cml0eV90eXBlGAMgASgOMh4ueXVjYWkuaG9sZGluZy52MS5T'
    'ZWN1cml0eVR5cGVSDHNlY3VyaXR5VHlwZRIaCghleGNoYW5nZRgEIAEoCVIIZXhjaGFuZ2USIw'
    'oNY3VycmVuY3lfY29kZRgFIAEoCVIMY3VycmVuY3lDb2Rl');

@$core.Deprecated('Use listSecuritiesRequestDescriptor instead')
const ListSecuritiesRequest$json = {
  '1': 'ListSecuritiesRequest',
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
      '1': 'security_type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.holding.v1.SecurityType',
      '10': 'securityType'
    },
  ],
};

/// Descriptor for `ListSecuritiesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSecuritiesRequestDescriptor = $convert.base64Decode(
    'ChVMaXN0U2VjdXJpdGllc1JlcXVlc3QSMAoEcGFnZRgBIAEoCzIcLnl1Y2FpLmNvbW1vbi52MS'
    '5QYWdlUmVxdWVzdFIEcGFnZRJDCg1zZWN1cml0eV90eXBlGAIgASgOMh4ueXVjYWkuaG9sZGlu'
    'Zy52MS5TZWN1cml0eVR5cGVSDHNlY3VyaXR5VHlwZQ==');

@$core.Deprecated('Use updatePriceRequestDescriptor instead')
const UpdatePriceRequest$json = {
  '1': 'UpdatePriceRequest',
  '2': [
    {'1': 'security_id', '3': 1, '4': 1, '5': 9, '10': 'securityId'},
    {'1': 'price_cents', '3': 2, '4': 1, '5': 3, '10': 'priceCents'},
  ],
};

/// Descriptor for `UpdatePriceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePriceRequestDescriptor = $convert.base64Decode(
    'ChJVcGRhdGVQcmljZVJlcXVlc3QSHwoLc2VjdXJpdHlfaWQYASABKAlSCnNlY3VyaXR5SWQSHw'
    'oLcHJpY2VfY2VudHMYAiABKANSCnByaWNlQ2VudHM=');

@$core.Deprecated('Use searchSecuritiesRequestDescriptor instead')
const SearchSecuritiesRequest$json = {
  '1': 'SearchSecuritiesRequest',
  '2': [
    {'1': 'query', '3': 1, '4': 1, '5': 9, '10': 'query'},
    {'1': 'limit', '3': 2, '4': 1, '5': 5, '10': 'limit'},
  ],
};

/// Descriptor for `SearchSecuritiesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchSecuritiesRequestDescriptor =
    $convert.base64Decode(
        'ChdTZWFyY2hTZWN1cml0aWVzUmVxdWVzdBIUCgVxdWVyeRgBIAEoCVIFcXVlcnkSFAoFbGltaX'
        'QYAiABKAVSBWxpbWl0');

@$core.Deprecated('Use holdingTradeRequestDescriptor instead')
const HoldingTradeRequest$json = {
  '1': 'HoldingTradeRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'security_id', '3': 2, '4': 1, '5': 9, '10': 'securityId'},
    {'1': 'quantity', '3': 3, '4': 1, '5': 1, '10': 'quantity'},
    {'1': 'price_cents', '3': 4, '4': 1, '5': 3, '10': 'priceCents'},
    {'1': 'fee_cents', '3': 5, '4': 1, '5': 3, '10': 'feeCents'},
    {'1': 'trade_date', '3': 6, '4': 1, '5': 9, '10': 'tradeDate'},
    {'1': 'notes', '3': 7, '4': 1, '5': 9, '10': 'notes'},
    {'1': 'from_account_id', '3': 8, '4': 1, '5': 9, '10': 'fromAccountId'},
  ],
};

/// Descriptor for `HoldingTradeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List holdingTradeRequestDescriptor = $convert.base64Decode(
    'ChNIb2xkaW5nVHJhZGVSZXF1ZXN0Eh0KCmFjY291bnRfaWQYASABKAlSCWFjY291bnRJZBIfCg'
    'tzZWN1cml0eV9pZBgCIAEoCVIKc2VjdXJpdHlJZBIaCghxdWFudGl0eRgDIAEoAVIIcXVhbnRp'
    'dHkSHwoLcHJpY2VfY2VudHMYBCABKANSCnByaWNlQ2VudHMSGwoJZmVlX2NlbnRzGAUgASgDUg'
    'hmZWVDZW50cxIdCgp0cmFkZV9kYXRlGAYgASgJUgl0cmFkZURhdGUSFAoFbm90ZXMYByABKAlS'
    'BW5vdGVzEiYKD2Zyb21fYWNjb3VudF9pZBgIIAEoCVINZnJvbUFjY291bnRJZA==');

@$core.Deprecated('Use recordDividendRequestDescriptor instead')
const RecordDividendRequest$json = {
  '1': 'RecordDividendRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'security_id', '3': 2, '4': 1, '5': 9, '10': 'securityId'},
    {'1': 'quantity', '3': 3, '4': 1, '5': 1, '10': 'quantity'},
    {
      '1': 'cash_per_share_cents',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'cashPerShareCents'
    },
    {
      '1': 'total_amount_cents',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'totalAmountCents'
    },
    {'1': 'trade_date', '3': 6, '4': 1, '5': 9, '10': 'tradeDate'},
    {'1': 'notes', '3': 7, '4': 1, '5': 9, '10': 'notes'},
  ],
};

/// Descriptor for `RecordDividendRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordDividendRequestDescriptor = $convert.base64Decode(
    'ChVSZWNvcmREaXZpZGVuZFJlcXVlc3QSHQoKYWNjb3VudF9pZBgBIAEoCVIJYWNjb3VudElkEh'
    '8KC3NlY3VyaXR5X2lkGAIgASgJUgpzZWN1cml0eUlkEhoKCHF1YW50aXR5GAMgASgBUghxdWFu'
    'dGl0eRIvChRjYXNoX3Blcl9zaGFyZV9jZW50cxgEIAEoA1IRY2FzaFBlclNoYXJlQ2VudHMSLA'
    'oSdG90YWxfYW1vdW50X2NlbnRzGAUgASgDUhB0b3RhbEFtb3VudENlbnRzEh0KCnRyYWRlX2Rh'
    'dGUYBiABKAlSCXRyYWRlRGF0ZRIUCgVub3RlcxgHIAEoCVIFbm90ZXM=');

@$core.Deprecated('Use recordSplitRequestDescriptor instead')
const RecordSplitRequest$json = {
  '1': 'RecordSplitRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'security_id', '3': 2, '4': 1, '5': 9, '10': 'securityId'},
    {'1': 'ratio', '3': 3, '4': 1, '5': 1, '10': 'ratio'},
    {'1': 'split_date', '3': 4, '4': 1, '5': 9, '10': 'splitDate'},
    {'1': 'notes', '3': 5, '4': 1, '5': 9, '10': 'notes'},
  ],
};

/// Descriptor for `RecordSplitRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordSplitRequestDescriptor = $convert.base64Decode(
    'ChJSZWNvcmRTcGxpdFJlcXVlc3QSHQoKYWNjb3VudF9pZBgBIAEoCVIJYWNjb3VudElkEh8KC3'
    'NlY3VyaXR5X2lkGAIgASgJUgpzZWN1cml0eUlkEhQKBXJhdGlvGAMgASgBUgVyYXRpbxIdCgpz'
    'cGxpdF9kYXRlGAQgASgJUglzcGxpdERhdGUSFAoFbm90ZXMYBSABKAlSBW5vdGVz');

@$core.Deprecated('Use listHoldingsRequestDescriptor instead')
const ListHoldingsRequest$json = {
  '1': 'ListHoldingsRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {
      '1': 'page',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageRequest',
      '10': 'page'
    },
  ],
};

/// Descriptor for `ListHoldingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listHoldingsRequestDescriptor = $convert.base64Decode(
    'ChNMaXN0SG9sZGluZ3NSZXF1ZXN0Eh0KCmFjY291bnRfaWQYASABKAlSCWFjY291bnRJZBIwCg'
    'RwYWdlGAIgASgLMhwueXVjYWkuY29tbW9uLnYxLlBhZ2VSZXF1ZXN0UgRwYWdl');

@$core.Deprecated('Use listTradesRequestDescriptor instead')
const ListTradesRequest$json = {
  '1': 'ListTradesRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'security_id', '3': 2, '4': 1, '5': 9, '10': 'securityId'},
    {
      '1': 'page',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageRequest',
      '10': 'page'
    },
  ],
};

/// Descriptor for `ListTradesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTradesRequestDescriptor = $convert.base64Decode(
    'ChFMaXN0VHJhZGVzUmVxdWVzdBIdCgphY2NvdW50X2lkGAEgASgJUglhY2NvdW50SWQSHwoLc2'
    'VjdXJpdHlfaWQYAiABKAlSCnNlY3VyaXR5SWQSMAoEcGFnZRgDIAEoCzIcLnl1Y2FpLmNvbW1v'
    'bi52MS5QYWdlUmVxdWVzdFIEcGFnZQ==');

@$core.Deprecated('Use securityResponseDescriptor instead')
const SecurityResponse$json = {
  '1': 'SecurityResponse',
  '2': [
    {
      '1': 'security',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.holding.v1.SecurityDTO',
      '10': 'security'
    },
  ],
};

/// Descriptor for `SecurityResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List securityResponseDescriptor = $convert.base64Decode(
    'ChBTZWN1cml0eVJlc3BvbnNlEjkKCHNlY3VyaXR5GAEgASgLMh0ueXVjYWkuaG9sZGluZy52MS'
    '5TZWN1cml0eURUT1IIc2VjdXJpdHk=');

@$core.Deprecated('Use listSecuritiesResponseDescriptor instead')
const ListSecuritiesResponse$json = {
  '1': 'ListSecuritiesResponse',
  '2': [
    {
      '1': 'securities',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.holding.v1.SecurityDTO',
      '10': 'securities'
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

/// Descriptor for `ListSecuritiesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listSecuritiesResponseDescriptor = $convert.base64Decode(
    'ChZMaXN0U2VjdXJpdGllc1Jlc3BvbnNlEj0KCnNlY3VyaXRpZXMYASADKAsyHS55dWNhaS5ob2'
    'xkaW5nLnYxLlNlY3VyaXR5RFRPUgpzZWN1cml0aWVzEjEKBHBhZ2UYAiABKAsyHS55dWNhaS5j'
    'b21tb24udjEuUGFnZVJlc3BvbnNlUgRwYWdl');

@$core.Deprecated('Use searchSecuritiesResponseDescriptor instead')
const SearchSecuritiesResponse$json = {
  '1': 'SearchSecuritiesResponse',
  '2': [
    {
      '1': 'securities',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.holding.v1.SecurityDTO',
      '10': 'securities'
    },
  ],
};

/// Descriptor for `SearchSecuritiesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List searchSecuritiesResponseDescriptor =
    $convert.base64Decode(
        'ChhTZWFyY2hTZWN1cml0aWVzUmVzcG9uc2USPQoKc2VjdXJpdGllcxgBIAMoCzIdLnl1Y2FpLm'
        'hvbGRpbmcudjEuU2VjdXJpdHlEVE9SCnNlY3VyaXRpZXM=');

@$core.Deprecated('Use holdingTransactionResponseDescriptor instead')
const HoldingTransactionResponse$json = {
  '1': 'HoldingTransactionResponse',
  '2': [
    {
      '1': 'transaction',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.holding.v1.HoldingTransactionDTO',
      '10': 'transaction'
    },
  ],
};

/// Descriptor for `HoldingTransactionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List holdingTransactionResponseDescriptor =
    $convert.base64Decode(
        'ChpIb2xkaW5nVHJhbnNhY3Rpb25SZXNwb25zZRJJCgt0cmFuc2FjdGlvbhgBIAEoCzInLnl1Y2'
        'FpLmhvbGRpbmcudjEuSG9sZGluZ1RyYW5zYWN0aW9uRFRPUgt0cmFuc2FjdGlvbg==');

@$core.Deprecated('Use listHoldingsResponseDescriptor instead')
const ListHoldingsResponse$json = {
  '1': 'ListHoldingsResponse',
  '2': [
    {
      '1': 'holdings',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.holding.v1.HoldingDTO',
      '10': 'holdings'
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

/// Descriptor for `ListHoldingsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listHoldingsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0SG9sZGluZ3NSZXNwb25zZRI4Cghob2xkaW5ncxgBIAMoCzIcLnl1Y2FpLmhvbGRpbm'
    'cudjEuSG9sZGluZ0RUT1IIaG9sZGluZ3MSMQoEcGFnZRgCIAEoCzIdLnl1Y2FpLmNvbW1vbi52'
    'MS5QYWdlUmVzcG9uc2VSBHBhZ2U=');

@$core.Deprecated('Use listTradesResponseDescriptor instead')
const ListTradesResponse$json = {
  '1': 'ListTradesResponse',
  '2': [
    {
      '1': 'trades',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.holding.v1.HoldingTransactionDTO',
      '10': 'trades'
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

/// Descriptor for `ListTradesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTradesResponseDescriptor = $convert.base64Decode(
    'ChJMaXN0VHJhZGVzUmVzcG9uc2USPwoGdHJhZGVzGAEgAygLMicueXVjYWkuaG9sZGluZy52MS'
    '5Ib2xkaW5nVHJhbnNhY3Rpb25EVE9SBnRyYWRlcxIxCgRwYWdlGAIgASgLMh0ueXVjYWkuY29t'
    'bW9uLnYxLlBhZ2VSZXNwb25zZVIEcGFnZQ==');

@$core.Deprecated('Use syncPricesRequestDescriptor instead')
const SyncPricesRequest$json = {
  '1': 'SyncPricesRequest',
};

/// Descriptor for `SyncPricesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncPricesRequestDescriptor =
    $convert.base64Decode('ChFTeW5jUHJpY2VzUmVxdWVzdA==');

@$core.Deprecated('Use syncPricesResponseDescriptor instead')
const SyncPricesResponse$json = {
  '1': 'SyncPricesResponse',
  '2': [
    {'1': 'synced_count', '3': 1, '4': 1, '5': 5, '10': 'syncedCount'},
    {
      '1': 'synced_at',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'syncedAt'
    },
  ],
};

/// Descriptor for `SyncPricesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncPricesResponseDescriptor = $convert.base64Decode(
    'ChJTeW5jUHJpY2VzUmVzcG9uc2USIQoMc3luY2VkX2NvdW50GAEgASgFUgtzeW5jZWRDb3VudB'
    'I3CglzeW5jZWRfYXQYAiABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUghzeW5jZWRB'
    'dA==');

@$core.Deprecated('Use curvePointDescriptor instead')
const CurvePoint$json = {
  '1': 'CurvePoint',
  '2': [
    {
      '1': 'time',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'time'
    },
    {'1': 'value', '3': 2, '4': 1, '5': 1, '10': 'value'},
  ],
};

/// Descriptor for `CurvePoint`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List curvePointDescriptor = $convert.base64Decode(
    'CgpDdXJ2ZVBvaW50Ei4KBHRpbWUYASABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUg'
    'R0aW1lEhQKBXZhbHVlGAIgASgBUgV2YWx1ZQ==');

@$core.Deprecated('Use getPortfolioPerformanceRequestDescriptor instead')
const GetPortfolioPerformanceRequest$json = {
  '1': 'GetPortfolioPerformanceRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {
      '1': 'range',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.holding.v1.CurveRange',
      '10': 'range'
    },
    {
      '1': 'include_benchmark',
      '3': 3,
      '4': 1,
      '5': 8,
      '10': 'includeBenchmark'
    },
    {'1': 'base_currency', '3': 4, '4': 1, '5': 9, '10': 'baseCurrency'},
  ],
};

/// Descriptor for `GetPortfolioPerformanceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPortfolioPerformanceRequestDescriptor =
    $convert.base64Decode(
        'Ch5HZXRQb3J0Zm9saW9QZXJmb3JtYW5jZVJlcXVlc3QSHQoKYWNjb3VudF9pZBgBIAEoCVIJYW'
        'Njb3VudElkEjIKBXJhbmdlGAIgASgOMhwueXVjYWkuaG9sZGluZy52MS5DdXJ2ZVJhbmdlUgVy'
        'YW5nZRIrChFpbmNsdWRlX2JlbmNobWFyaxgDIAEoCFIQaW5jbHVkZUJlbmNobWFyaxIjCg1iYX'
        'NlX2N1cnJlbmN5GAQgASgJUgxiYXNlQ3VycmVuY3k=');

@$core.Deprecated('Use portfolioPerformanceResponseDescriptor instead')
const PortfolioPerformanceResponse$json = {
  '1': 'PortfolioPerformanceResponse',
  '2': [
    {
      '1': 'portfolio_points',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.holding.v1.CurvePoint',
      '10': 'portfolioPoints'
    },
    {
      '1': 'benchmark_points',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.yucai.holding.v1.CurvePoint',
      '10': 'benchmarkPoints'
    },
    {'1': 'benchmark_name', '3': 3, '4': 1, '5': 9, '10': 'benchmarkName'},
    {'1': 'realized_cents', '3': 4, '4': 1, '5': 3, '10': 'realizedCents'},
    {'1': 'unrealized_cents', '3': 5, '4': 1, '5': 3, '10': 'unrealizedCents'},
    {'1': 'total_cents', '3': 6, '4': 1, '5': 3, '10': 'totalCents'},
    {
      '1': 'annualized_pct',
      '3': 7,
      '4': 1,
      '5': 1,
      '9': 0,
      '10': 'annualizedPct',
      '17': true
    },
    {'1': 'total_pct', '3': 8, '4': 1, '5': 1, '10': 'totalPct'},
    {'1': 'currency', '3': 9, '4': 1, '5': 9, '10': 'currency'},
    {
      '1': 'range_annualized_pct',
      '3': 10,
      '4': 1,
      '5': 1,
      '9': 1,
      '10': 'rangeAnnualizedPct',
      '17': true
    },
  ],
  '8': [
    {'1': '_annualized_pct'},
    {'1': '_range_annualized_pct'},
  ],
};

/// Descriptor for `PortfolioPerformanceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List portfolioPerformanceResponseDescriptor = $convert.base64Decode(
    'ChxQb3J0Zm9saW9QZXJmb3JtYW5jZVJlc3BvbnNlEkcKEHBvcnRmb2xpb19wb2ludHMYASADKA'
    'syHC55dWNhaS5ob2xkaW5nLnYxLkN1cnZlUG9pbnRSD3BvcnRmb2xpb1BvaW50cxJHChBiZW5j'
    'aG1hcmtfcG9pbnRzGAIgAygLMhwueXVjYWkuaG9sZGluZy52MS5DdXJ2ZVBvaW50Ug9iZW5jaG'
    '1hcmtQb2ludHMSJQoOYmVuY2htYXJrX25hbWUYAyABKAlSDWJlbmNobWFya05hbWUSJQoOcmVh'
    'bGl6ZWRfY2VudHMYBCABKANSDXJlYWxpemVkQ2VudHMSKQoQdW5yZWFsaXplZF9jZW50cxgFIA'
    'EoA1IPdW5yZWFsaXplZENlbnRzEh8KC3RvdGFsX2NlbnRzGAYgASgDUgp0b3RhbENlbnRzEioK'
    'DmFubnVhbGl6ZWRfcGN0GAcgASgBSABSDWFubnVhbGl6ZWRQY3SIAQESGwoJdG90YWxfcGN0GA'
    'ggASgBUgh0b3RhbFBjdBIaCghjdXJyZW5jeRgJIAEoCVIIY3VycmVuY3kSNQoUcmFuZ2VfYW5u'
    'dWFsaXplZF9wY3QYCiABKAFIAVIScmFuZ2VBbm51YWxpemVkUGN0iAEBQhEKD19hbm51YWxpem'
    'VkX3BjdEIXChVfcmFuZ2VfYW5udWFsaXplZF9wY3Q=');

@$core.Deprecated('Use getHoldingPerformanceRequestDescriptor instead')
const GetHoldingPerformanceRequest$json = {
  '1': 'GetHoldingPerformanceRequest',
  '2': [
    {'1': 'holding_id', '3': 1, '4': 1, '5': 9, '10': 'holdingId'},
    {
      '1': 'range',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.holding.v1.CurveRange',
      '10': 'range'
    },
    {'1': 'base_currency', '3': 3, '4': 1, '5': 9, '10': 'baseCurrency'},
  ],
};

/// Descriptor for `GetHoldingPerformanceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getHoldingPerformanceRequestDescriptor =
    $convert.base64Decode(
        'ChxHZXRIb2xkaW5nUGVyZm9ybWFuY2VSZXF1ZXN0Eh0KCmhvbGRpbmdfaWQYASABKAlSCWhvbG'
        'RpbmdJZBIyCgVyYW5nZRgCIAEoDjIcLnl1Y2FpLmhvbGRpbmcudjEuQ3VydmVSYW5nZVIFcmFu'
        'Z2USIwoNYmFzZV9jdXJyZW5jeRgDIAEoCVIMYmFzZUN1cnJlbmN5');

@$core.Deprecated('Use holdingPerformanceResponseDescriptor instead')
const HoldingPerformanceResponse$json = {
  '1': 'HoldingPerformanceResponse',
  '2': [
    {
      '1': 'price_points',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.holding.v1.CurvePoint',
      '10': 'pricePoints'
    },
    {'1': 'realized_cents', '3': 2, '4': 1, '5': 3, '10': 'realizedCents'},
    {'1': 'unrealized_cents', '3': 3, '4': 1, '5': 3, '10': 'unrealizedCents'},
    {'1': 'total_cents', '3': 4, '4': 1, '5': 3, '10': 'totalCents'},
    {'1': 'currency', '3': 5, '4': 1, '5': 9, '10': 'currency'},
    {
      '1': 'annualized_pct',
      '3': 6,
      '4': 1,
      '5': 1,
      '9': 0,
      '10': 'annualizedPct',
      '17': true
    },
    {
      '1': 'range_annualized_pct',
      '3': 7,
      '4': 1,
      '5': 1,
      '9': 1,
      '10': 'rangeAnnualizedPct',
      '17': true
    },
  ],
  '8': [
    {'1': '_annualized_pct'},
    {'1': '_range_annualized_pct'},
  ],
};

/// Descriptor for `HoldingPerformanceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List holdingPerformanceResponseDescriptor = $convert.base64Decode(
    'ChpIb2xkaW5nUGVyZm9ybWFuY2VSZXNwb25zZRI/CgxwcmljZV9wb2ludHMYASADKAsyHC55dW'
    'NhaS5ob2xkaW5nLnYxLkN1cnZlUG9pbnRSC3ByaWNlUG9pbnRzEiUKDnJlYWxpemVkX2NlbnRz'
    'GAIgASgDUg1yZWFsaXplZENlbnRzEikKEHVucmVhbGl6ZWRfY2VudHMYAyABKANSD3VucmVhbG'
    'l6ZWRDZW50cxIfCgt0b3RhbF9jZW50cxgEIAEoA1IKdG90YWxDZW50cxIaCghjdXJyZW5jeRgF'
    'IAEoCVIIY3VycmVuY3kSKgoOYW5udWFsaXplZF9wY3QYBiABKAFIAFINYW5udWFsaXplZFBjdI'
    'gBARI1ChRyYW5nZV9hbm51YWxpemVkX3BjdBgHIAEoAUgBUhJyYW5nZUFubnVhbGl6ZWRQY3SI'
    'AQFCEQoPX2FubnVhbGl6ZWRfcGN0QhcKFV9yYW5nZV9hbm51YWxpemVkX3BjdA==');

@$core.Deprecated('Use backfillPriceHistoryRequestDescriptor instead')
const BackfillPriceHistoryRequest$json = {
  '1': 'BackfillPriceHistoryRequest',
  '2': [
    {
      '1': 'range',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.yucai.holding.v1.CurveRange',
      '10': 'range'
    },
  ],
};

/// Descriptor for `BackfillPriceHistoryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backfillPriceHistoryRequestDescriptor =
    $convert.base64Decode(
        'ChtCYWNrZmlsbFByaWNlSGlzdG9yeVJlcXVlc3QSMgoFcmFuZ2UYASABKA4yHC55dWNhaS5ob2'
        'xkaW5nLnYxLkN1cnZlUmFuZ2VSBXJhbmdl');

@$core.Deprecated('Use backfillPriceHistoryResponseDescriptor instead')
const BackfillPriceHistoryResponse$json = {
  '1': 'BackfillPriceHistoryResponse',
  '2': [
    {'1': 'backfilled_count', '3': 1, '4': 1, '5': 5, '10': 'backfilledCount'},
  ],
};

/// Descriptor for `BackfillPriceHistoryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backfillPriceHistoryResponseDescriptor =
    $convert.base64Decode(
        'ChxCYWNrZmlsbFByaWNlSGlzdG9yeVJlc3BvbnNlEikKEGJhY2tmaWxsZWRfY291bnQYASABKA'
        'VSD2JhY2tmaWxsZWRDb3VudA==');
