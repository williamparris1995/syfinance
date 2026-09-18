// This is a generated file - do not edit.
//
// Generated from common/v1/recurrence.proto.

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

@$core.Deprecated('Use recurrenceCycleDescriptor instead')
const RecurrenceCycle$json = {
  '1': 'RecurrenceCycle',
  '2': [
    {'1': 'RECURRENCE_CYCLE_UNSPECIFIED', '2': 0},
    {'1': 'RECURRENCE_CYCLE_WEEKLY', '2': 1},
    {'1': 'RECURRENCE_CYCLE_MONTHLY', '2': 2},
    {'1': 'RECURRENCE_CYCLE_YEARLY', '2': 3},
    {'1': 'RECURRENCE_CYCLE_CUSTOM', '2': 4},
  ],
};

/// Descriptor for `RecurrenceCycle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List recurrenceCycleDescriptor = $convert.base64Decode(
    'Cg9SZWN1cnJlbmNlQ3ljbGUSIAocUkVDVVJSRU5DRV9DWUNMRV9VTlNQRUNJRklFRBAAEhsKF1'
    'JFQ1VSUkVOQ0VfQ1lDTEVfV0VFS0xZEAESHAoYUkVDVVJSRU5DRV9DWUNMRV9NT05USExZEAIS'
    'GwoXUkVDVVJSRU5DRV9DWUNMRV9ZRUFSTFkQAxIbChdSRUNVUlJFTkNFX0NZQ0xFX0NVU1RPTR'
    'AE');

@$core.Deprecated('Use recurrenceMonthlyModeDescriptor instead')
const RecurrenceMonthlyMode$json = {
  '1': 'RecurrenceMonthlyMode',
  '2': [
    {'1': 'MONTHLY_MODE_BY_DATE', '2': 0},
    {'1': 'MONTHLY_MODE_BY_NTH_WEEKDAY', '2': 1},
  ],
};

/// Descriptor for `RecurrenceMonthlyMode`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List recurrenceMonthlyModeDescriptor = $convert.base64Decode(
    'ChVSZWN1cnJlbmNlTW9udGhseU1vZGUSGAoUTU9OVEhMWV9NT0RFX0JZX0RBVEUQABIfChtNT0'
    '5USExZX01PREVfQllfTlRIX1dFRUtEQVkQAQ==');
