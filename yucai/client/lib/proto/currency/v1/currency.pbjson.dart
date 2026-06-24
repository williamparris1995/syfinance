// This is a generated file - do not edit.
//
// Generated from currency/v1/currency.proto.

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

@$core.Deprecated('Use currencyDTODescriptor instead')
const CurrencyDTO$json = {
  '1': 'CurrencyDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'code', '3': 2, '4': 1, '5': 9, '10': 'code'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
    {'1': 'symbol', '3': 4, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'exchange_rate', '3': 5, '4': 1, '5': 1, '10': 'exchangeRate'},
    {'1': 'is_active', '3': 6, '4': 1, '5': 8, '10': 'isActive'},
  ],
};

/// Descriptor for `CurrencyDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List currencyDTODescriptor = $convert.base64Decode(
    'CgtDdXJyZW5jeURUTxIOCgJpZBgBIAEoCVICaWQSEgoEY29kZRgCIAEoCVIEY29kZRISCgRuYW'
    '1lGAMgASgJUgRuYW1lEhYKBnN5bWJvbBgEIAEoCVIGc3ltYm9sEiMKDWV4Y2hhbmdlX3JhdGUY'
    'BSABKAFSDGV4Y2hhbmdlUmF0ZRIbCglpc19hY3RpdmUYBiABKAhSCGlzQWN0aXZl');

@$core.Deprecated('Use addCurrencyRequestDescriptor instead')
const AddCurrencyRequest$json = {
  '1': 'AddCurrencyRequest',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'symbol', '3': 3, '4': 1, '5': 9, '10': 'symbol'},
    {'1': 'exchange_rate', '3': 4, '4': 1, '5': 1, '10': 'exchangeRate'},
  ],
};

/// Descriptor for `AddCurrencyRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addCurrencyRequestDescriptor = $convert.base64Decode(
    'ChJBZGRDdXJyZW5jeVJlcXVlc3QSEgoEY29kZRgBIAEoCVIEY29kZRISCgRuYW1lGAIgASgJUg'
    'RuYW1lEhYKBnN5bWJvbBgDIAEoCVIGc3ltYm9sEiMKDWV4Y2hhbmdlX3JhdGUYBCABKAFSDGV4'
    'Y2hhbmdlUmF0ZQ==');

@$core.Deprecated('Use updateRateRequestDescriptor instead')
const UpdateRateRequest$json = {
  '1': 'UpdateRateRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'exchange_rate', '3': 2, '4': 1, '5': 1, '10': 'exchangeRate'},
  ],
};

/// Descriptor for `UpdateRateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateRateRequestDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVSYXRlUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSIwoNZXhjaGFuZ2VfcmF0ZRgCIA'
    'EoAVIMZXhjaGFuZ2VSYXRl');

@$core.Deprecated('Use fetchRateRequestDescriptor instead')
const FetchRateRequest$json = {
  '1': 'FetchRateRequest',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
  ],
};

/// Descriptor for `FetchRateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchRateRequestDescriptor = $convert
    .base64Decode('ChBGZXRjaFJhdGVSZXF1ZXN0EhIKBGNvZGUYASABKAlSBGNvZGU=');

@$core.Deprecated('Use fetchRateResponseDescriptor instead')
const FetchRateResponse$json = {
  '1': 'FetchRateResponse',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'exchange_rate', '3': 2, '4': 1, '5': 1, '10': 'exchangeRate'},
  ],
};

/// Descriptor for `FetchRateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fetchRateResponseDescriptor = $convert.base64Decode(
    'ChFGZXRjaFJhdGVSZXNwb25zZRISCgRjb2RlGAEgASgJUgRjb2RlEiMKDWV4Y2hhbmdlX3JhdG'
    'UYAiABKAFSDGV4Y2hhbmdlUmF0ZQ==');

@$core.Deprecated('Use listCurrenciesRequestDescriptor instead')
const ListCurrenciesRequest$json = {
  '1': 'ListCurrenciesRequest',
  '2': [
    {
      '1': 'page',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageRequest',
      '10': 'page'
    },
    {'1': 'active_only', '3': 2, '4': 1, '5': 8, '10': 'activeOnly'},
  ],
};

/// Descriptor for `ListCurrenciesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listCurrenciesRequestDescriptor = $convert.base64Decode(
    'ChVMaXN0Q3VycmVuY2llc1JlcXVlc3QSMAoEcGFnZRgBIAEoCzIcLnl1Y2FpLmNvbW1vbi52MS'
    '5QYWdlUmVxdWVzdFIEcGFnZRIfCgthY3RpdmVfb25seRgCIAEoCFIKYWN0aXZlT25seQ==');

@$core.Deprecated('Use listCurrenciesResponseDescriptor instead')
const ListCurrenciesResponse$json = {
  '1': 'ListCurrenciesResponse',
  '2': [
    {
      '1': 'currencies',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.currency.v1.CurrencyDTO',
      '10': 'currencies'
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

/// Descriptor for `ListCurrenciesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listCurrenciesResponseDescriptor = $convert.base64Decode(
    'ChZMaXN0Q3VycmVuY2llc1Jlc3BvbnNlEj4KCmN1cnJlbmNpZXMYASADKAsyHi55dWNhaS5jdX'
    'JyZW5jeS52MS5DdXJyZW5jeURUT1IKY3VycmVuY2llcxIxCgRwYWdlGAIgASgLMh0ueXVjYWku'
    'Y29tbW9uLnYxLlBhZ2VSZXNwb25zZVIEcGFnZQ==');

@$core.Deprecated('Use currencyResponseDescriptor instead')
const CurrencyResponse$json = {
  '1': 'CurrencyResponse',
  '2': [
    {
      '1': 'currency',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.currency.v1.CurrencyDTO',
      '10': 'currency'
    },
  ],
};

/// Descriptor for `CurrencyResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List currencyResponseDescriptor = $convert.base64Decode(
    'ChBDdXJyZW5jeVJlc3BvbnNlEjoKCGN1cnJlbmN5GAEgASgLMh4ueXVjYWkuY3VycmVuY3kudj'
    'EuQ3VycmVuY3lEVE9SCGN1cnJlbmN5');
