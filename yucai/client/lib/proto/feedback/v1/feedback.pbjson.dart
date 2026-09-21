// This is a generated file - do not edit.
//
// Generated from feedback/v1/feedback.proto.

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

@$core.Deprecated('Use feedbackTypeDescriptor instead')
const FeedbackType$json = {
  '1': 'FeedbackType',
  '2': [
    {'1': 'FEEDBACK_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'ISSUE', '2': 1},
    {'1': 'IDEA', '2': 2},
    {'1': 'OTHER', '2': 3},
  ],
};

/// Descriptor for `FeedbackType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List feedbackTypeDescriptor = $convert.base64Decode(
    'CgxGZWVkYmFja1R5cGUSHQoZRkVFREJBQ0tfVFlQRV9VTlNQRUNJRklFRBAAEgkKBUlTU1VFEA'
    'ESCAoESURFQRACEgkKBU9USEVSEAM=');

@$core.Deprecated('Use feedbackDiagnosticsDescriptor instead')
const FeedbackDiagnostics$json = {
  '1': 'FeedbackDiagnostics',
  '2': [
    {'1': 'app_version', '3': 1, '4': 1, '5': 9, '10': 'appVersion'},
    {'1': 'platform', '3': 2, '4': 1, '5': 9, '10': 'platform'},
    {'1': 'account_mode', '3': 3, '4': 1, '5': 9, '10': 'accountMode'},
    {'1': 'theme_mode', '3': 4, '4': 1, '5': 9, '10': 'themeMode'},
  ],
};

/// Descriptor for `FeedbackDiagnostics`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List feedbackDiagnosticsDescriptor = $convert.base64Decode(
    'ChNGZWVkYmFja0RpYWdub3N0aWNzEh8KC2FwcF92ZXJzaW9uGAEgASgJUgphcHBWZXJzaW9uEh'
    'oKCHBsYXRmb3JtGAIgASgJUghwbGF0Zm9ybRIhCgxhY2NvdW50X21vZGUYAyABKAlSC2FjY291'
    'bnRNb2RlEh0KCnRoZW1lX21vZGUYBCABKAlSCXRoZW1lTW9kZQ==');

@$core.Deprecated('Use submitFeedbackRequestDescriptor instead')
const SubmitFeedbackRequest$json = {
  '1': 'SubmitFeedbackRequest',
  '2': [
    {
      '1': 'type',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.yucai.feedback.v1.FeedbackType',
      '10': 'type'
    },
    {'1': 'body', '3': 2, '4': 1, '5': 9, '10': 'body'},
    {'1': 'contact', '3': 3, '4': 1, '5': 9, '10': 'contact'},
    {
      '1': 'diagnostics',
      '3': 4,
      '4': 1,
      '5': 11,
      '6': '.yucai.feedback.v1.FeedbackDiagnostics',
      '10': 'diagnostics'
    },
  ],
};

/// Descriptor for `SubmitFeedbackRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitFeedbackRequestDescriptor = $convert.base64Decode(
    'ChVTdWJtaXRGZWVkYmFja1JlcXVlc3QSMwoEdHlwZRgBIAEoDjIfLnl1Y2FpLmZlZWRiYWNrLn'
    'YxLkZlZWRiYWNrVHlwZVIEdHlwZRISCgRib2R5GAIgASgJUgRib2R5EhgKB2NvbnRhY3QYAyAB'
    'KAlSB2NvbnRhY3QSSAoLZGlhZ25vc3RpY3MYBCABKAsyJi55dWNhaS5mZWVkYmFjay52MS5GZW'
    'VkYmFja0RpYWdub3N0aWNzUgtkaWFnbm9zdGljcw==');

@$core.Deprecated('Use submitFeedbackResponseDescriptor instead')
const SubmitFeedbackResponse$json = {
  '1': 'SubmitFeedbackResponse',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 3, '10': 'id'},
  ],
};

/// Descriptor for `SubmitFeedbackResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List submitFeedbackResponseDescriptor = $convert
    .base64Decode('ChZTdWJtaXRGZWVkYmFja1Jlc3BvbnNlEg4KAmlkGAEgASgDUgJpZA==');
