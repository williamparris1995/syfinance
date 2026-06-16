// This is a generated file - do not edit.
//
// Generated from budget/v1/budget.proto.

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

@$core.Deprecated('Use budgetDTODescriptor instead')
const BudgetDTO$json = {
  '1': 'BudgetDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'month', '3': 3, '4': 1, '5': 9, '10': 'month'},
    {
      '1': 'total_amount_cents',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'totalAmountCents'
    },
    {'1': 'currency_code', '3': 5, '4': 1, '5': 9, '10': 'currencyCode'},
    {'1': 'is_active', '3': 6, '4': 1, '5': 8, '10': 'isActive'},
    {'1': 'version', '3': 7, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'created_at',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 9,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
  ],
};

/// Descriptor for `BudgetDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List budgetDTODescriptor = $convert.base64Decode(
    'CglCdWRnZXREVE8SDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSFAoFbW9udG'
    'gYAyABKAlSBW1vbnRoEiwKEnRvdGFsX2Ftb3VudF9jZW50cxgEIAEoA1IQdG90YWxBbW91bnRD'
    'ZW50cxIjCg1jdXJyZW5jeV9jb2RlGAUgASgJUgxjdXJyZW5jeUNvZGUSGwoJaXNfYWN0aXZlGA'
    'YgASgIUghpc0FjdGl2ZRIYCgd2ZXJzaW9uGAcgASgDUgd2ZXJzaW9uEjkKCmNyZWF0ZWRfYXQY'
    'CCABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgljcmVhdGVkQXQSOQoKdXBkYXRlZF'
    '9hdBgJIAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCXVwZGF0ZWRBdA==');

@$core.Deprecated('Use budgetItemDTODescriptor instead')
const BudgetItemDTO$json = {
  '1': 'BudgetItemDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'budget_id', '3': 2, '4': 1, '5': 9, '10': 'budgetId'},
    {'1': 'account_id', '3': 3, '4': 1, '5': 9, '10': 'accountId'},
    {
      '1': 'planned_amount_cents',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'plannedAmountCents'
    },
    {
      '1': 'actual_amount_cents',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'actualAmountCents'
    },
    {'1': 'notes', '3': 6, '4': 1, '5': 9, '10': 'notes'},
  ],
};

/// Descriptor for `BudgetItemDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List budgetItemDTODescriptor = $convert.base64Decode(
    'Cg1CdWRnZXRJdGVtRFRPEg4KAmlkGAEgASgJUgJpZBIbCglidWRnZXRfaWQYAiABKAlSCGJ1ZG'
    'dldElkEh0KCmFjY291bnRfaWQYAyABKAlSCWFjY291bnRJZBIwChRwbGFubmVkX2Ftb3VudF9j'
    'ZW50cxgEIAEoA1IScGxhbm5lZEFtb3VudENlbnRzEi4KE2FjdHVhbF9hbW91bnRfY2VudHMYBS'
    'ABKANSEWFjdHVhbEFtb3VudENlbnRzEhQKBW5vdGVzGAYgASgJUgVub3Rlcw==');

@$core.Deprecated('Use budgetDetailDTODescriptor instead')
const BudgetDetailDTO$json = {
  '1': 'BudgetDetailDTO',
  '2': [
    {
      '1': 'budget',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.budget.v1.BudgetDTO',
      '10': 'budget'
    },
    {
      '1': 'items',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.yucai.budget.v1.BudgetItemDTO',
      '10': 'items'
    },
    {
      '1': 'total_actual_cents',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'totalActualCents'
    },
    {
      '1': 'total_remaining_cents',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'totalRemainingCents'
    },
    {'1': 'usage_pct', '3': 5, '4': 1, '5': 1, '10': 'usagePct'},
  ],
};

/// Descriptor for `BudgetDetailDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List budgetDetailDTODescriptor = $convert.base64Decode(
    'Cg9CdWRnZXREZXRhaWxEVE8SMgoGYnVkZ2V0GAEgASgLMhoueXVjYWkuYnVkZ2V0LnYxLkJ1ZG'
    'dldERUT1IGYnVkZ2V0EjQKBWl0ZW1zGAIgAygLMh4ueXVjYWkuYnVkZ2V0LnYxLkJ1ZGdldEl0'
    'ZW1EVE9SBWl0ZW1zEiwKEnRvdGFsX2FjdHVhbF9jZW50cxgDIAEoA1IQdG90YWxBY3R1YWxDZW'
    '50cxIyChV0b3RhbF9yZW1haW5pbmdfY2VudHMYBCABKANSE3RvdGFsUmVtYWluaW5nQ2VudHMS'
    'GwoJdXNhZ2VfcGN0GAUgASgBUgh1c2FnZVBjdA==');

@$core.Deprecated('Use createBudgetRequestDescriptor instead')
const CreateBudgetRequest$json = {
  '1': 'CreateBudgetRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'month', '3': 2, '4': 1, '5': 9, '10': 'month'},
    {'1': 'currency_code', '3': 3, '4': 1, '5': 9, '10': 'currencyCode'},
    {
      '1': 'items',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.yucai.budget.v1.BudgetItemInput',
      '10': 'items'
    },
  ],
};

/// Descriptor for `CreateBudgetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createBudgetRequestDescriptor = $convert.base64Decode(
    'ChNDcmVhdGVCdWRnZXRSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWUSFAoFbW9udGgYAiABKA'
    'lSBW1vbnRoEiMKDWN1cnJlbmN5X2NvZGUYAyABKAlSDGN1cnJlbmN5Q29kZRI2CgVpdGVtcxgE'
    'IAMoCzIgLnl1Y2FpLmJ1ZGdldC52MS5CdWRnZXRJdGVtSW5wdXRSBWl0ZW1z');

@$core.Deprecated('Use budgetItemInputDescriptor instead')
const BudgetItemInput$json = {
  '1': 'BudgetItemInput',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {
      '1': 'planned_amount_cents',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'plannedAmountCents'
    },
    {'1': 'notes', '3': 3, '4': 1, '5': 9, '10': 'notes'},
  ],
};

/// Descriptor for `BudgetItemInput`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List budgetItemInputDescriptor = $convert.base64Decode(
    'Cg9CdWRnZXRJdGVtSW5wdXQSHQoKYWNjb3VudF9pZBgBIAEoCVIJYWNjb3VudElkEjAKFHBsYW'
    '5uZWRfYW1vdW50X2NlbnRzGAIgASgDUhJwbGFubmVkQW1vdW50Q2VudHMSFAoFbm90ZXMYAyAB'
    'KAlSBW5vdGVz');

@$core.Deprecated('Use getBudgetRequestDescriptor instead')
const GetBudgetRequest$json = {
  '1': 'GetBudgetRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetBudgetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBudgetRequestDescriptor =
    $convert.base64Decode('ChBHZXRCdWRnZXRSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use getBudgetByMonthRequestDescriptor instead')
const GetBudgetByMonthRequest$json = {
  '1': 'GetBudgetByMonthRequest',
  '2': [
    {'1': 'month', '3': 1, '4': 1, '5': 9, '10': 'month'},
  ],
};

/// Descriptor for `GetBudgetByMonthRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getBudgetByMonthRequestDescriptor =
    $convert.base64Decode(
        'ChdHZXRCdWRnZXRCeU1vbnRoUmVxdWVzdBIUCgVtb250aBgBIAEoCVIFbW9udGg=');

@$core.Deprecated('Use listBudgetsRequestDescriptor instead')
const ListBudgetsRequest$json = {
  '1': 'ListBudgetsRequest',
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

/// Descriptor for `ListBudgetsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBudgetsRequestDescriptor = $convert.base64Decode(
    'ChJMaXN0QnVkZ2V0c1JlcXVlc3QSMAoEcGFnZRgBIAEoCzIcLnl1Y2FpLmNvbW1vbi52MS5QYW'
    'dlUmVxdWVzdFIEcGFnZRIfCgthY3RpdmVfb25seRgCIAEoCFIKYWN0aXZlT25seQ==');

@$core.Deprecated('Use listBudgetsResponseDescriptor instead')
const ListBudgetsResponse$json = {
  '1': 'ListBudgetsResponse',
  '2': [
    {
      '1': 'budgets',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.budget.v1.BudgetDTO',
      '10': 'budgets'
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

/// Descriptor for `ListBudgetsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBudgetsResponseDescriptor = $convert.base64Decode(
    'ChNMaXN0QnVkZ2V0c1Jlc3BvbnNlEjQKB2J1ZGdldHMYASADKAsyGi55dWNhaS5idWRnZXQudj'
    'EuQnVkZ2V0RFRPUgdidWRnZXRzEjEKBHBhZ2UYAiABKAsyHS55dWNhaS5jb21tb24udjEuUGFn'
    'ZVJlc3BvbnNlUgRwYWdl');

@$core.Deprecated('Use deleteBudgetRequestDescriptor instead')
const DeleteBudgetRequest$json = {
  '1': 'DeleteBudgetRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteBudgetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteBudgetRequestDescriptor = $convert
    .base64Decode('ChNEZWxldGVCdWRnZXRSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use addBudgetItemRequestDescriptor instead')
const AddBudgetItemRequest$json = {
  '1': 'AddBudgetItemRequest',
  '2': [
    {'1': 'budget_id', '3': 1, '4': 1, '5': 9, '10': 'budgetId'},
    {'1': 'account_id', '3': 2, '4': 1, '5': 9, '10': 'accountId'},
    {
      '1': 'planned_amount_cents',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'plannedAmountCents'
    },
    {'1': 'notes', '3': 4, '4': 1, '5': 9, '10': 'notes'},
  ],
};

/// Descriptor for `AddBudgetItemRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List addBudgetItemRequestDescriptor = $convert.base64Decode(
    'ChRBZGRCdWRnZXRJdGVtUmVxdWVzdBIbCglidWRnZXRfaWQYASABKAlSCGJ1ZGdldElkEh0KCm'
    'FjY291bnRfaWQYAiABKAlSCWFjY291bnRJZBIwChRwbGFubmVkX2Ftb3VudF9jZW50cxgDIAEo'
    'A1IScGxhbm5lZEFtb3VudENlbnRzEhQKBW5vdGVzGAQgASgJUgVub3Rlcw==');

@$core.Deprecated('Use removeBudgetItemRequestDescriptor instead')
const RemoveBudgetItemRequest$json = {
  '1': 'RemoveBudgetItemRequest',
  '2': [
    {'1': 'budget_id', '3': 1, '4': 1, '5': 9, '10': 'budgetId'},
    {'1': 'item_id', '3': 2, '4': 1, '5': 9, '10': 'itemId'},
  ],
};

/// Descriptor for `RemoveBudgetItemRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List removeBudgetItemRequestDescriptor =
    $convert.base64Decode(
        'ChdSZW1vdmVCdWRnZXRJdGVtUmVxdWVzdBIbCglidWRnZXRfaWQYASABKAlSCGJ1ZGdldElkEh'
        'cKB2l0ZW1faWQYAiABKAlSBml0ZW1JZA==');

@$core.Deprecated('Use computeActualsRequestDescriptor instead')
const ComputeActualsRequest$json = {
  '1': 'ComputeActualsRequest',
  '2': [
    {'1': 'budget_id', '3': 1, '4': 1, '5': 9, '10': 'budgetId'},
  ],
};

/// Descriptor for `ComputeActualsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List computeActualsRequestDescriptor = $convert.base64Decode(
    'ChVDb21wdXRlQWN0dWFsc1JlcXVlc3QSGwoJYnVkZ2V0X2lkGAEgASgJUghidWRnZXRJZA==');

@$core.Deprecated('Use cloneBudgetRequestDescriptor instead')
const CloneBudgetRequest$json = {
  '1': 'CloneBudgetRequest',
  '2': [
    {'1': 'source_budget_id', '3': 1, '4': 1, '5': 9, '10': 'sourceBudgetId'},
    {'1': 'target_month', '3': 2, '4': 1, '5': 9, '10': 'targetMonth'},
    {'1': 'name', '3': 3, '4': 1, '5': 9, '10': 'name'},
  ],
};

/// Descriptor for `CloneBudgetRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cloneBudgetRequestDescriptor = $convert.base64Decode(
    'ChJDbG9uZUJ1ZGdldFJlcXVlc3QSKAoQc291cmNlX2J1ZGdldF9pZBgBIAEoCVIOc291cmNlQn'
    'VkZ2V0SWQSIQoMdGFyZ2V0X21vbnRoGAIgASgJUgt0YXJnZXRNb250aBISCgRuYW1lGAMgASgJ'
    'UgRuYW1l');

@$core.Deprecated('Use budgetResponseDescriptor instead')
const BudgetResponse$json = {
  '1': 'BudgetResponse',
  '2': [
    {
      '1': 'budget',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.budget.v1.BudgetDTO',
      '10': 'budget'
    },
  ],
};

/// Descriptor for `BudgetResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List budgetResponseDescriptor = $convert.base64Decode(
    'Cg5CdWRnZXRSZXNwb25zZRIyCgZidWRnZXQYASABKAsyGi55dWNhaS5idWRnZXQudjEuQnVkZ2'
    'V0RFRPUgZidWRnZXQ=');

@$core.Deprecated('Use budgetDetailResponseDescriptor instead')
const BudgetDetailResponse$json = {
  '1': 'BudgetDetailResponse',
  '2': [
    {
      '1': 'budget',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.budget.v1.BudgetDetailDTO',
      '10': 'budget'
    },
  ],
};

/// Descriptor for `BudgetDetailResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List budgetDetailResponseDescriptor = $convert.base64Decode(
    'ChRCdWRnZXREZXRhaWxSZXNwb25zZRI4CgZidWRnZXQYASABKAsyIC55dWNhaS5idWRnZXQudj'
    'EuQnVkZ2V0RGV0YWlsRFRPUgZidWRnZXQ=');

const $core.Map<$core.String, $core.dynamic> BudgetServiceBase$json = {
  '1': 'BudgetService',
  '2': [
    {
      '1': 'CreateBudget',
      '2': '.yucai.budget.v1.CreateBudgetRequest',
      '3': '.yucai.budget.v1.BudgetResponse'
    },
    {
      '1': 'GetBudget',
      '2': '.yucai.budget.v1.GetBudgetRequest',
      '3': '.yucai.budget.v1.BudgetDetailResponse'
    },
    {
      '1': 'GetBudgetByMonth',
      '2': '.yucai.budget.v1.GetBudgetByMonthRequest',
      '3': '.yucai.budget.v1.BudgetDetailResponse'
    },
    {
      '1': 'ListBudgets',
      '2': '.yucai.budget.v1.ListBudgetsRequest',
      '3': '.yucai.budget.v1.ListBudgetsResponse'
    },
    {
      '1': 'DeleteBudget',
      '2': '.yucai.budget.v1.DeleteBudgetRequest',
      '3': '.google.protobuf.Empty'
    },
    {
      '1': 'AddBudgetItem',
      '2': '.yucai.budget.v1.AddBudgetItemRequest',
      '3': '.yucai.budget.v1.BudgetResponse'
    },
    {
      '1': 'RemoveBudgetItem',
      '2': '.yucai.budget.v1.RemoveBudgetItemRequest',
      '3': '.yucai.budget.v1.BudgetResponse'
    },
    {
      '1': 'ComputeBudgetActuals',
      '2': '.yucai.budget.v1.ComputeActualsRequest',
      '3': '.yucai.budget.v1.BudgetResponse'
    },
    {
      '1': 'CloneBudgetToMonth',
      '2': '.yucai.budget.v1.CloneBudgetRequest',
      '3': '.yucai.budget.v1.BudgetResponse'
    },
  ],
};

@$core.Deprecated('Use budgetServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    BudgetServiceBase$messageJson = {
  '.yucai.budget.v1.CreateBudgetRequest': CreateBudgetRequest$json,
  '.yucai.budget.v1.BudgetItemInput': BudgetItemInput$json,
  '.yucai.budget.v1.BudgetResponse': BudgetResponse$json,
  '.yucai.budget.v1.BudgetDTO': BudgetDTO$json,
  '.google.protobuf.Timestamp': $0.Timestamp$json,
  '.yucai.budget.v1.GetBudgetRequest': GetBudgetRequest$json,
  '.yucai.budget.v1.BudgetDetailResponse': BudgetDetailResponse$json,
  '.yucai.budget.v1.BudgetDetailDTO': BudgetDetailDTO$json,
  '.yucai.budget.v1.BudgetItemDTO': BudgetItemDTO$json,
  '.yucai.budget.v1.GetBudgetByMonthRequest': GetBudgetByMonthRequest$json,
  '.yucai.budget.v1.ListBudgetsRequest': ListBudgetsRequest$json,
  '.yucai.common.v1.PageRequest': $1.PageRequest$json,
  '.yucai.budget.v1.ListBudgetsResponse': ListBudgetsResponse$json,
  '.yucai.common.v1.PageResponse': $1.PageResponse$json,
  '.yucai.budget.v1.DeleteBudgetRequest': DeleteBudgetRequest$json,
  '.google.protobuf.Empty': $2.Empty$json,
  '.yucai.budget.v1.AddBudgetItemRequest': AddBudgetItemRequest$json,
  '.yucai.budget.v1.RemoveBudgetItemRequest': RemoveBudgetItemRequest$json,
  '.yucai.budget.v1.ComputeActualsRequest': ComputeActualsRequest$json,
  '.yucai.budget.v1.CloneBudgetRequest': CloneBudgetRequest$json,
};

/// Descriptor for `BudgetService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List budgetServiceDescriptor = $convert.base64Decode(
    'Cg1CdWRnZXRTZXJ2aWNlElUKDENyZWF0ZUJ1ZGdldBIkLnl1Y2FpLmJ1ZGdldC52MS5DcmVhdG'
    'VCdWRnZXRSZXF1ZXN0Gh8ueXVjYWkuYnVkZ2V0LnYxLkJ1ZGdldFJlc3BvbnNlElUKCUdldEJ1'
    'ZGdldBIhLnl1Y2FpLmJ1ZGdldC52MS5HZXRCdWRnZXRSZXF1ZXN0GiUueXVjYWkuYnVkZ2V0Ln'
    'YxLkJ1ZGdldERldGFpbFJlc3BvbnNlEmMKEEdldEJ1ZGdldEJ5TW9udGgSKC55dWNhaS5idWRn'
    'ZXQudjEuR2V0QnVkZ2V0QnlNb250aFJlcXVlc3QaJS55dWNhaS5idWRnZXQudjEuQnVkZ2V0RG'
    'V0YWlsUmVzcG9uc2USWAoLTGlzdEJ1ZGdldHMSIy55dWNhaS5idWRnZXQudjEuTGlzdEJ1ZGdl'
    'dHNSZXF1ZXN0GiQueXVjYWkuYnVkZ2V0LnYxLkxpc3RCdWRnZXRzUmVzcG9uc2USTAoMRGVsZX'
    'RlQnVkZ2V0EiQueXVjYWkuYnVkZ2V0LnYxLkRlbGV0ZUJ1ZGdldFJlcXVlc3QaFi5nb29nbGUu'
    'cHJvdG9idWYuRW1wdHkSVwoNQWRkQnVkZ2V0SXRlbRIlLnl1Y2FpLmJ1ZGdldC52MS5BZGRCdW'
    'RnZXRJdGVtUmVxdWVzdBofLnl1Y2FpLmJ1ZGdldC52MS5CdWRnZXRSZXNwb25zZRJdChBSZW1v'
    'dmVCdWRnZXRJdGVtEigueXVjYWkuYnVkZ2V0LnYxLlJlbW92ZUJ1ZGdldEl0ZW1SZXF1ZXN0Gh'
    '8ueXVjYWkuYnVkZ2V0LnYxLkJ1ZGdldFJlc3BvbnNlEl8KFENvbXB1dGVCdWRnZXRBY3R1YWxz'
    'EiYueXVjYWkuYnVkZ2V0LnYxLkNvbXB1dGVBY3R1YWxzUmVxdWVzdBofLnl1Y2FpLmJ1ZGdldC'
    '52MS5CdWRnZXRSZXNwb25zZRJaChJDbG9uZUJ1ZGdldFRvTW9udGgSIy55dWNhaS5idWRnZXQu'
    'djEuQ2xvbmVCdWRnZXRSZXF1ZXN0Gh8ueXVjYWkuYnVkZ2V0LnYxLkJ1ZGdldFJlc3BvbnNl');
