// This is a generated file - do not edit.
//
// Generated from networth/v1/service.proto.

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

@$core.Deprecated('Use getNetWorthRequestDescriptor instead')
const GetNetWorthRequest$json = {
  '1': 'GetNetWorthRequest',
  '2': [
    {'1': 'base_currency', '3': 1, '4': 1, '5': 9, '10': 'baseCurrency'},
  ],
};

/// Descriptor for `GetNetWorthRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getNetWorthRequestDescriptor = $convert.base64Decode(
    'ChJHZXROZXRXb3J0aFJlcXVlc3QSIwoNYmFzZV9jdXJyZW5jeRgBIAEoCVIMYmFzZUN1cnJlbm'
    'N5');

@$core.Deprecated('Use getNetWorthResponseDescriptor instead')
const GetNetWorthResponse$json = {
  '1': 'GetNetWorthResponse',
  '2': [
    {
      '1': 'total_assets_cents',
      '3': 1,
      '4': 1,
      '5': 3,
      '10': 'totalAssetsCents'
    },
    {
      '1': 'total_liabilities_cents',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'totalLiabilitiesCents'
    },
    {'1': 'net_worth_cents', '3': 3, '4': 1, '5': 3, '10': 'netWorthCents'},
    {'1': 'currency', '3': 4, '4': 1, '5': 9, '10': 'currency'},
  ],
};

/// Descriptor for `GetNetWorthResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getNetWorthResponseDescriptor = $convert.base64Decode(
    'ChNHZXROZXRXb3J0aFJlc3BvbnNlEiwKEnRvdGFsX2Fzc2V0c19jZW50cxgBIAEoA1IQdG90YW'
    'xBc3NldHNDZW50cxI2Chd0b3RhbF9saWFiaWxpdGllc19jZW50cxgCIAEoA1IVdG90YWxMaWFi'
    'aWxpdGllc0NlbnRzEiYKD25ldF93b3J0aF9jZW50cxgDIAEoA1INbmV0V29ydGhDZW50cxIaCg'
    'hjdXJyZW5jeRgEIAEoCVIIY3VycmVuY3k=');
