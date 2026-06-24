// This is a generated file - do not edit.
//
// Generated from goal/v1/goal.proto.

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

@$core.Deprecated('Use goalTypeDescriptor instead')
const GoalType$json = {
  '1': 'GoalType',
  '2': [
    {'1': 'GOAL_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'GOAL_TYPE_SAVINGS', '2': 1},
    {'1': 'GOAL_TYPE_DEBT_PAYOFF', '2': 2},
    {'1': 'GOAL_TYPE_INVESTMENT', '2': 3},
  ],
};

/// Descriptor for `GoalType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List goalTypeDescriptor = $convert.base64Decode(
    'CghHb2FsVHlwZRIZChVHT0FMX1RZUEVfVU5TUEVDSUZJRUQQABIVChFHT0FMX1RZUEVfU0FWSU'
    '5HUxABEhkKFUdPQUxfVFlQRV9ERUJUX1BBWU9GRhACEhgKFEdPQUxfVFlQRV9JTlZFU1RNRU5U'
    'EAM=');

@$core.Deprecated('Use goalDTODescriptor instead')
const GoalDTO$json = {
  '1': 'GoalDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'goal_type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.yucai.goal.v1.GoalType',
      '10': 'goalType'
    },
    {
      '1': 'target_amount_cents',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'targetAmountCents'
    },
    {
      '1': 'current_amount_cents',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'currentAmountCents'
    },
    {'1': 'currency_code', '3': 6, '4': 1, '5': 9, '10': 'currencyCode'},
    {
      '1': 'deadline',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'deadline'
    },
    {'1': 'linked_account_id', '3': 8, '4': 1, '5': 9, '10': 'linkedAccountId'},
    {'1': 'notes', '3': 9, '4': 1, '5': 9, '10': 'notes'},
    {'1': 'is_completed', '3': 10, '4': 1, '5': 8, '10': 'isCompleted'},
    {
      '1': 'completed_at',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'completedAt'
    },
    {'1': 'progress_pct', '3': 12, '4': 1, '5': 1, '10': 'progressPct'},
    {'1': 'remaining_cents', '3': 13, '4': 1, '5': 3, '10': 'remainingCents'},
    {'1': 'version', '3': 14, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'created_at',
      '3': 15,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
  ],
};

/// Descriptor for `GoalDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List goalDTODescriptor = $convert.base64Decode(
    'CgdHb2FsRFRPEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEjQKCWdvYWxfdH'
    'lwZRgDIAEoDjIXLnl1Y2FpLmdvYWwudjEuR29hbFR5cGVSCGdvYWxUeXBlEi4KE3RhcmdldF9h'
    'bW91bnRfY2VudHMYBCABKANSEXRhcmdldEFtb3VudENlbnRzEjAKFGN1cnJlbnRfYW1vdW50X2'
    'NlbnRzGAUgASgDUhJjdXJyZW50QW1vdW50Q2VudHMSIwoNY3VycmVuY3lfY29kZRgGIAEoCVIM'
    'Y3VycmVuY3lDb2RlEjYKCGRlYWRsaW5lGAcgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdG'
    'FtcFIIZGVhZGxpbmUSKgoRbGlua2VkX2FjY291bnRfaWQYCCABKAlSD2xpbmtlZEFjY291bnRJ'
    'ZBIUCgVub3RlcxgJIAEoCVIFbm90ZXMSIQoMaXNfY29tcGxldGVkGAogASgIUgtpc0NvbXBsZX'
    'RlZBI9Cgxjb21wbGV0ZWRfYXQYCyABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgtj'
    'b21wbGV0ZWRBdBIhCgxwcm9ncmVzc19wY3QYDCABKAFSC3Byb2dyZXNzUGN0EicKD3JlbWFpbm'
    'luZ19jZW50cxgNIAEoA1IOcmVtYWluaW5nQ2VudHMSGAoHdmVyc2lvbhgOIAEoA1IHdmVyc2lv'
    'bhI5CgpjcmVhdGVkX2F0GA8gASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJY3JlYX'
    'RlZEF0EjkKCnVwZGF0ZWRfYXQYECABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgl1'
    'cGRhdGVkQXQ=');

@$core.Deprecated('Use createGoalRequestDescriptor instead')
const CreateGoalRequest$json = {
  '1': 'CreateGoalRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'goal_type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.goal.v1.GoalType',
      '10': 'goalType'
    },
    {
      '1': 'target_amount_cents',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'targetAmountCents'
    },
    {'1': 'currency_code', '3': 4, '4': 1, '5': 9, '10': 'currencyCode'},
    {'1': 'deadline', '3': 5, '4': 1, '5': 9, '10': 'deadline'},
    {'1': 'linked_account_id', '3': 6, '4': 1, '5': 9, '10': 'linkedAccountId'},
    {'1': 'notes', '3': 7, '4': 1, '5': 9, '10': 'notes'},
  ],
};

/// Descriptor for `CreateGoalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createGoalRequestDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVHb2FsUmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1lEjQKCWdvYWxfdHlwZRgCIA'
    'EoDjIXLnl1Y2FpLmdvYWwudjEuR29hbFR5cGVSCGdvYWxUeXBlEi4KE3RhcmdldF9hbW91bnRf'
    'Y2VudHMYAyABKANSEXRhcmdldEFtb3VudENlbnRzEiMKDWN1cnJlbmN5X2NvZGUYBCABKAlSDG'
    'N1cnJlbmN5Q29kZRIaCghkZWFkbGluZRgFIAEoCVIIZGVhZGxpbmUSKgoRbGlua2VkX2FjY291'
    'bnRfaWQYBiABKAlSD2xpbmtlZEFjY291bnRJZBIUCgVub3RlcxgHIAEoCVIFbm90ZXM=');

@$core.Deprecated('Use updateGoalRequestDescriptor instead')
const UpdateGoalRequest$json = {
  '1': 'UpdateGoalRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'target_amount_cents',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'targetAmountCents'
    },
    {'1': 'deadline', '3': 4, '4': 1, '5': 9, '10': 'deadline'},
    {'1': 'notes', '3': 5, '4': 1, '5': 9, '10': 'notes'},
    {'1': 'version', '3': 6, '4': 1, '5': 3, '10': 'version'},
  ],
};

/// Descriptor for `UpdateGoalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateGoalRequestDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVHb2FsUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZR'
    'IuChN0YXJnZXRfYW1vdW50X2NlbnRzGAMgASgDUhF0YXJnZXRBbW91bnRDZW50cxIaCghkZWFk'
    'bGluZRgEIAEoCVIIZGVhZGxpbmUSFAoFbm90ZXMYBSABKAlSBW5vdGVzEhgKB3ZlcnNpb24YBi'
    'ABKANSB3ZlcnNpb24=');

@$core.Deprecated('Use updateProgressRequestDescriptor instead')
const UpdateProgressRequest$json = {
  '1': 'UpdateProgressRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'amount_cents', '3': 2, '4': 1, '5': 3, '10': 'amountCents'},
  ],
};

/// Descriptor for `UpdateProgressRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateProgressRequestDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVQcm9ncmVzc1JlcXVlc3QSDgoCaWQYASABKAlSAmlkEiEKDGFtb3VudF9jZW50cx'
    'gCIAEoA1ILYW1vdW50Q2VudHM=');

@$core.Deprecated('Use completeGoalRequestDescriptor instead')
const CompleteGoalRequest$json = {
  '1': 'CompleteGoalRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `CompleteGoalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List completeGoalRequestDescriptor = $convert
    .base64Decode('ChNDb21wbGV0ZUdvYWxSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use deleteGoalRequestDescriptor instead')
const DeleteGoalRequest$json = {
  '1': 'DeleteGoalRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteGoalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteGoalRequestDescriptor =
    $convert.base64Decode('ChFEZWxldGVHb2FsUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use syncGoalProgressRequestDescriptor instead')
const SyncGoalProgressRequest$json = {
  '1': 'SyncGoalProgressRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `SyncGoalProgressRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncGoalProgressRequestDescriptor = $convert
    .base64Decode('ChdTeW5jR29hbFByb2dyZXNzUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use getGoalRequestDescriptor instead')
const GetGoalRequest$json = {
  '1': 'GetGoalRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetGoalRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getGoalRequestDescriptor =
    $convert.base64Decode('Cg5HZXRHb2FsUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use listGoalsRequestDescriptor instead')
const ListGoalsRequest$json = {
  '1': 'ListGoalsRequest',
  '2': [
    {
      '1': 'page',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageRequest',
      '10': 'page'
    },
    {'1': 'completed', '3': 2, '4': 1, '5': 8, '10': 'completed'},
  ],
};

/// Descriptor for `ListGoalsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGoalsRequestDescriptor = $convert.base64Decode(
    'ChBMaXN0R29hbHNSZXF1ZXN0EjAKBHBhZ2UYASABKAsyHC55dWNhaS5jb21tb24udjEuUGFnZV'
    'JlcXVlc3RSBHBhZ2USHAoJY29tcGxldGVkGAIgASgIUgljb21wbGV0ZWQ=');

@$core.Deprecated('Use listGoalsResponseDescriptor instead')
const ListGoalsResponse$json = {
  '1': 'ListGoalsResponse',
  '2': [
    {
      '1': 'goals',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.goal.v1.GoalDTO',
      '10': 'goals'
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

/// Descriptor for `ListGoalsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listGoalsResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0R29hbHNSZXNwb25zZRIsCgVnb2FscxgBIAMoCzIWLnl1Y2FpLmdvYWwudjEuR29hbE'
    'RUT1IFZ29hbHMSMQoEcGFnZRgCIAEoCzIdLnl1Y2FpLmNvbW1vbi52MS5QYWdlUmVzcG9uc2VS'
    'BHBhZ2U=');

@$core.Deprecated('Use goalResponseDescriptor instead')
const GoalResponse$json = {
  '1': 'GoalResponse',
  '2': [
    {
      '1': 'goal',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.goal.v1.GoalDTO',
      '10': 'goal'
    },
  ],
};

/// Descriptor for `GoalResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List goalResponseDescriptor = $convert.base64Decode(
    'CgxHb2FsUmVzcG9uc2USKgoEZ29hbBgBIAEoCzIWLnl1Y2FpLmdvYWwudjEuR29hbERUT1IEZ2'
    '9hbA==');

@$core.Deprecated('Use goalDetailResponseDescriptor instead')
const GoalDetailResponse$json = {
  '1': 'GoalDetailResponse',
  '2': [
    {
      '1': 'goal',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.goal.v1.GoalDTO',
      '10': 'goal'
    },
  ],
};

/// Descriptor for `GoalDetailResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List goalDetailResponseDescriptor = $convert.base64Decode(
    'ChJHb2FsRGV0YWlsUmVzcG9uc2USKgoEZ29hbBgBIAEoCzIWLnl1Y2FpLmdvYWwudjEuR29hbE'
    'RUT1IEZ29hbA==');
