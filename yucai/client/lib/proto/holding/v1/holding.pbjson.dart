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

import 'package:protobuf/well_known_types/google/protobuf/empty.pbjson.dart'
    as $2;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pbjson.dart'
    as $0;

import '../../common/v1/pagination.pbjson.dart' as $1;

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
  ],
};

/// Descriptor for `HoldingTradeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List holdingTradeRequestDescriptor = $convert.base64Decode(
    'ChNIb2xkaW5nVHJhZGVSZXF1ZXN0Eh0KCmFjY291bnRfaWQYASABKAlSCWFjY291bnRJZBIfCg'
    'tzZWN1cml0eV9pZBgCIAEoCVIKc2VjdXJpdHlJZBIaCghxdWFudGl0eRgDIAEoAVIIcXVhbnRp'
    'dHkSHwoLcHJpY2VfY2VudHMYBCABKANSCnByaWNlQ2VudHMSGwoJZmVlX2NlbnRzGAUgASgDUg'
    'hmZWVDZW50cxIdCgp0cmFkZV9kYXRlGAYgASgJUgl0cmFkZURhdGUSFAoFbm90ZXMYByABKAlS'
    'BW5vdGVz');

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

const $core.Map<$core.String, $core.dynamic> HoldingServiceBase$json = {
  '1': 'HoldingService',
  '2': [
    {
      '1': 'CreateSecurity',
      '2': '.yucai.holding.v1.CreateSecurityRequest',
      '3': '.yucai.holding.v1.SecurityResponse'
    },
    {
      '1': 'ListSecurities',
      '2': '.yucai.holding.v1.ListSecuritiesRequest',
      '3': '.yucai.holding.v1.ListSecuritiesResponse'
    },
    {
      '1': 'UpdateSecurityPrice',
      '2': '.yucai.holding.v1.UpdatePriceRequest',
      '3': '.google.protobuf.Empty'
    },
    {
      '1': 'SearchSecurities',
      '2': '.yucai.holding.v1.SearchSecuritiesRequest',
      '3': '.yucai.holding.v1.SearchSecuritiesResponse'
    },
    {
      '1': 'BuyHolding',
      '2': '.yucai.holding.v1.HoldingTradeRequest',
      '3': '.yucai.holding.v1.HoldingTransactionResponse'
    },
    {
      '1': 'SellHolding',
      '2': '.yucai.holding.v1.HoldingTradeRequest',
      '3': '.yucai.holding.v1.HoldingTransactionResponse'
    },
    {
      '1': 'RecordDividend',
      '2': '.yucai.holding.v1.RecordDividendRequest',
      '3': '.yucai.holding.v1.HoldingTransactionResponse'
    },
    {
      '1': 'RecordSplit',
      '2': '.yucai.holding.v1.RecordSplitRequest',
      '3': '.yucai.holding.v1.HoldingTransactionResponse'
    },
    {
      '1': 'ListHoldings',
      '2': '.yucai.holding.v1.ListHoldingsRequest',
      '3': '.yucai.holding.v1.ListHoldingsResponse'
    },
    {
      '1': 'ListHoldingTransactions',
      '2': '.yucai.holding.v1.ListTradesRequest',
      '3': '.yucai.holding.v1.ListTradesResponse'
    },
  ],
};

@$core.Deprecated('Use holdingServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    HoldingServiceBase$messageJson = {
  '.yucai.holding.v1.CreateSecurityRequest': CreateSecurityRequest$json,
  '.yucai.holding.v1.SecurityResponse': SecurityResponse$json,
  '.yucai.holding.v1.SecurityDTO': SecurityDTO$json,
  '.google.protobuf.Timestamp': $0.Timestamp$json,
  '.yucai.holding.v1.ListSecuritiesRequest': ListSecuritiesRequest$json,
  '.yucai.common.v1.PageRequest': $1.PageRequest$json,
  '.yucai.holding.v1.ListSecuritiesResponse': ListSecuritiesResponse$json,
  '.yucai.common.v1.PageResponse': $1.PageResponse$json,
  '.yucai.holding.v1.UpdatePriceRequest': UpdatePriceRequest$json,
  '.google.protobuf.Empty': $2.Empty$json,
  '.yucai.holding.v1.SearchSecuritiesRequest': SearchSecuritiesRequest$json,
  '.yucai.holding.v1.SearchSecuritiesResponse': SearchSecuritiesResponse$json,
  '.yucai.holding.v1.HoldingTradeRequest': HoldingTradeRequest$json,
  '.yucai.holding.v1.HoldingTransactionResponse':
      HoldingTransactionResponse$json,
  '.yucai.holding.v1.HoldingTransactionDTO': HoldingTransactionDTO$json,
  '.yucai.holding.v1.RecordDividendRequest': RecordDividendRequest$json,
  '.yucai.holding.v1.RecordSplitRequest': RecordSplitRequest$json,
  '.yucai.holding.v1.ListHoldingsRequest': ListHoldingsRequest$json,
  '.yucai.holding.v1.ListHoldingsResponse': ListHoldingsResponse$json,
  '.yucai.holding.v1.HoldingDTO': HoldingDTO$json,
  '.yucai.holding.v1.ListTradesRequest': ListTradesRequest$json,
  '.yucai.holding.v1.ListTradesResponse': ListTradesResponse$json,
};

/// Descriptor for `HoldingService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List holdingServiceDescriptor = $convert.base64Decode(
    'Cg5Ib2xkaW5nU2VydmljZRJdCg5DcmVhdGVTZWN1cml0eRInLnl1Y2FpLmhvbGRpbmcudjEuQ3'
    'JlYXRlU2VjdXJpdHlSZXF1ZXN0GiIueXVjYWkuaG9sZGluZy52MS5TZWN1cml0eVJlc3BvbnNl'
    'EmMKDkxpc3RTZWN1cml0aWVzEicueXVjYWkuaG9sZGluZy52MS5MaXN0U2VjdXJpdGllc1JlcX'
    'Vlc3QaKC55dWNhaS5ob2xkaW5nLnYxLkxpc3RTZWN1cml0aWVzUmVzcG9uc2USUwoTVXBkYXRl'
    'U2VjdXJpdHlQcmljZRIkLnl1Y2FpLmhvbGRpbmcudjEuVXBkYXRlUHJpY2VSZXF1ZXN0GhYuZ2'
    '9vZ2xlLnByb3RvYnVmLkVtcHR5EmkKEFNlYXJjaFNlY3VyaXRpZXMSKS55dWNhaS5ob2xkaW5n'
    'LnYxLlNlYXJjaFNlY3VyaXRpZXNSZXF1ZXN0GioueXVjYWkuaG9sZGluZy52MS5TZWFyY2hTZW'
    'N1cml0aWVzUmVzcG9uc2USYQoKQnV5SG9sZGluZxIlLnl1Y2FpLmhvbGRpbmcudjEuSG9sZGlu'
    'Z1RyYWRlUmVxdWVzdBosLnl1Y2FpLmhvbGRpbmcudjEuSG9sZGluZ1RyYW5zYWN0aW9uUmVzcG'
    '9uc2USYgoLU2VsbEhvbGRpbmcSJS55dWNhaS5ob2xkaW5nLnYxLkhvbGRpbmdUcmFkZVJlcXVl'
    'c3QaLC55dWNhaS5ob2xkaW5nLnYxLkhvbGRpbmdUcmFuc2FjdGlvblJlc3BvbnNlEmcKDlJlY2'
    '9yZERpdmlkZW5kEicueXVjYWkuaG9sZGluZy52MS5SZWNvcmREaXZpZGVuZFJlcXVlc3QaLC55'
    'dWNhaS5ob2xkaW5nLnYxLkhvbGRpbmdUcmFuc2FjdGlvblJlc3BvbnNlEmEKC1JlY29yZFNwbG'
    'l0EiQueXVjYWkuaG9sZGluZy52MS5SZWNvcmRTcGxpdFJlcXVlc3QaLC55dWNhaS5ob2xkaW5n'
    'LnYxLkhvbGRpbmdUcmFuc2FjdGlvblJlc3BvbnNlEl0KDExpc3RIb2xkaW5ncxIlLnl1Y2FpLm'
    'hvbGRpbmcudjEuTGlzdEhvbGRpbmdzUmVxdWVzdBomLnl1Y2FpLmhvbGRpbmcudjEuTGlzdEhv'
    'bGRpbmdzUmVzcG9uc2USZAoXTGlzdEhvbGRpbmdUcmFuc2FjdGlvbnMSIy55dWNhaS5ob2xkaW'
    '5nLnYxLkxpc3RUcmFkZXNSZXF1ZXN0GiQueXVjYWkuaG9sZGluZy52MS5MaXN0VHJhZGVzUmVz'
    'cG9uc2U=');
