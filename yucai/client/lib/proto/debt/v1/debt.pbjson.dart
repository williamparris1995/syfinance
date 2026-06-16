// This is a generated file - do not edit.
//
// Generated from debt/v1/debt.proto.

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

@$core.Deprecated('Use amortizationMethodDescriptor instead')
const AmortizationMethod$json = {
  '1': 'AmortizationMethod',
  '2': [
    {'1': 'AMORTIZATION_UNSPECIFIED', '2': 0},
    {'1': 'AMORTIZATION_EQUAL_PRINCIPAL_INTEREST', '2': 1},
    {'1': 'AMORTIZATION_EQUAL_PRINCIPAL', '2': 2},
    {'1': 'AMORTIZATION_LUMP_SUM', '2': 3},
  ],
};

/// Descriptor for `AmortizationMethod`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List amortizationMethodDescriptor = $convert.base64Decode(
    'ChJBbW9ydGl6YXRpb25NZXRob2QSHAoYQU1PUlRJWkFUSU9OX1VOU1BFQ0lGSUVEEAASKQolQU'
    '1PUlRJWkFUSU9OX0VRVUFMX1BSSU5DSVBBTF9JTlRFUkVTVBABEiAKHEFNT1JUSVpBVElPTl9F'
    'UVVBTF9QUklOQ0lQQUwQAhIZChVBTU9SVElaQVRJT05fTFVNUF9TVU0QAw==');

@$core.Deprecated('Use debtDTODescriptor instead')
const DebtDTO$json = {
  '1': 'DebtDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'account_id', '3': 2, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'counterparty', '3': 3, '4': 1, '5': 9, '10': 'counterparty'},
    {'1': 'interest_rate', '3': 4, '4': 1, '5': 1, '10': 'interestRate'},
    {
      '1': 'amortization_method',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.yucai.debt.v1.AmortizationMethod',
      '10': 'amortizationMethod'
    },
    {'1': 'start_date', '3': 6, '4': 1, '5': 9, '10': 'startDate'},
    {'1': 'due_date', '3': 7, '4': 1, '5': 9, '10': 'dueDate'},
    {
      '1': 'total_principal_cents',
      '3': 8,
      '4': 1,
      '5': 3,
      '10': 'totalPrincipalCents'
    },
    {
      '1': 'remaining_principal_cents',
      '3': 9,
      '4': 1,
      '5': 3,
      '10': 'remainingPrincipalCents'
    },
    {'1': 'version', '3': 10, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'created_at',
      '3': 11,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 12,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
  ],
};

/// Descriptor for `DebtDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List debtDTODescriptor = $convert.base64Decode(
    'CgdEZWJ0RFRPEg4KAmlkGAEgASgJUgJpZBIdCgphY2NvdW50X2lkGAIgASgJUglhY2NvdW50SW'
    'QSIgoMY291bnRlcnBhcnR5GAMgASgJUgxjb3VudGVycGFydHkSIwoNaW50ZXJlc3RfcmF0ZRgE'
    'IAEoAVIMaW50ZXJlc3RSYXRlElIKE2Ftb3J0aXphdGlvbl9tZXRob2QYBSABKA4yIS55dWNhaS'
    '5kZWJ0LnYxLkFtb3J0aXphdGlvbk1ldGhvZFISYW1vcnRpemF0aW9uTWV0aG9kEh0KCnN0YXJ0'
    'X2RhdGUYBiABKAlSCXN0YXJ0RGF0ZRIZCghkdWVfZGF0ZRgHIAEoCVIHZHVlRGF0ZRIyChV0b3'
    'RhbF9wcmluY2lwYWxfY2VudHMYCCABKANSE3RvdGFsUHJpbmNpcGFsQ2VudHMSOgoZcmVtYWlu'
    'aW5nX3ByaW5jaXBhbF9jZW50cxgJIAEoA1IXcmVtYWluaW5nUHJpbmNpcGFsQ2VudHMSGAoHdm'
    'Vyc2lvbhgKIAEoA1IHdmVyc2lvbhI5CgpjcmVhdGVkX2F0GAsgASgLMhouZ29vZ2xlLnByb3Rv'
    'YnVmLlRpbWVzdGFtcFIJY3JlYXRlZEF0EjkKCnVwZGF0ZWRfYXQYDCABKAsyGi5nb29nbGUucH'
    'JvdG9idWYuVGltZXN0YW1wUgl1cGRhdGVkQXQ=');

@$core.Deprecated('Use paymentEntryDTODescriptor instead')
const PaymentEntryDTO$json = {
  '1': 'PaymentEntryDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'payment_date', '3': 2, '4': 1, '5': 9, '10': 'paymentDate'},
    {'1': 'principal_cents', '3': 3, '4': 1, '5': 3, '10': 'principalCents'},
    {'1': 'interest_cents', '3': 4, '4': 1, '5': 3, '10': 'interestCents'},
    {'1': 'total_cents', '3': 5, '4': 1, '5': 3, '10': 'totalCents'},
    {'1': 'paid', '3': 6, '4': 1, '5': 8, '10': 'paid'},
    {'1': 'paid_cents', '3': 7, '4': 1, '5': 3, '10': 'paidCents'},
    {'1': 'transaction_id', '3': 8, '4': 1, '5': 9, '10': 'transactionId'},
  ],
};

/// Descriptor for `PaymentEntryDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paymentEntryDTODescriptor = $convert.base64Decode(
    'Cg9QYXltZW50RW50cnlEVE8SDgoCaWQYASABKAlSAmlkEiEKDHBheW1lbnRfZGF0ZRgCIAEoCV'
    'ILcGF5bWVudERhdGUSJwoPcHJpbmNpcGFsX2NlbnRzGAMgASgDUg5wcmluY2lwYWxDZW50cxIl'
    'Cg5pbnRlcmVzdF9jZW50cxgEIAEoA1INaW50ZXJlc3RDZW50cxIfCgt0b3RhbF9jZW50cxgFIA'
    'EoA1IKdG90YWxDZW50cxISCgRwYWlkGAYgASgIUgRwYWlkEh0KCnBhaWRfY2VudHMYByABKANS'
    'CXBhaWRDZW50cxIlCg50cmFuc2FjdGlvbl9pZBgIIAEoCVINdHJhbnNhY3Rpb25JZA==');

@$core.Deprecated('Use debtDetailDTODescriptor instead')
const DebtDetailDTO$json = {
  '1': 'DebtDetailDTO',
  '2': [
    {
      '1': 'debt',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.debt.v1.DebtDTO',
      '10': 'debt'
    },
    {
      '1': 'schedule',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.yucai.debt.v1.PaymentEntryDTO',
      '10': 'schedule'
    },
  ],
};

/// Descriptor for `DebtDetailDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List debtDetailDTODescriptor = $convert.base64Decode(
    'Cg1EZWJ0RGV0YWlsRFRPEioKBGRlYnQYASABKAsyFi55dWNhaS5kZWJ0LnYxLkRlYnREVE9SBG'
    'RlYnQSOgoIc2NoZWR1bGUYAiADKAsyHi55dWNhaS5kZWJ0LnYxLlBheW1lbnRFbnRyeURUT1II'
    'c2NoZWR1bGU=');

@$core.Deprecated('Use createDebtRequestDescriptor instead')
const CreateDebtRequest$json = {
  '1': 'CreateDebtRequest',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'counterparty', '3': 2, '4': 1, '5': 9, '10': 'counterparty'},
    {'1': 'interest_rate', '3': 3, '4': 1, '5': 1, '10': 'interestRate'},
    {
      '1': 'amortization_method',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.yucai.debt.v1.AmortizationMethod',
      '10': 'amortizationMethod'
    },
    {'1': 'start_date', '3': 5, '4': 1, '5': 9, '10': 'startDate'},
    {'1': 'due_date', '3': 6, '4': 1, '5': 9, '10': 'dueDate'},
    {
      '1': 'total_principal_cents',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'totalPrincipalCents'
    },
  ],
};

/// Descriptor for `CreateDebtRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createDebtRequestDescriptor = $convert.base64Decode(
    'ChFDcmVhdGVEZWJ0UmVxdWVzdBIdCgphY2NvdW50X2lkGAEgASgJUglhY2NvdW50SWQSIgoMY2'
    '91bnRlcnBhcnR5GAIgASgJUgxjb3VudGVycGFydHkSIwoNaW50ZXJlc3RfcmF0ZRgDIAEoAVIM'
    'aW50ZXJlc3RSYXRlElIKE2Ftb3J0aXphdGlvbl9tZXRob2QYBCABKA4yIS55dWNhaS5kZWJ0Ln'
    'YxLkFtb3J0aXphdGlvbk1ldGhvZFISYW1vcnRpemF0aW9uTWV0aG9kEh0KCnN0YXJ0X2RhdGUY'
    'BSABKAlSCXN0YXJ0RGF0ZRIZCghkdWVfZGF0ZRgGIAEoCVIHZHVlRGF0ZRIyChV0b3RhbF9wcm'
    'luY2lwYWxfY2VudHMYByABKANSE3RvdGFsUHJpbmNpcGFsQ2VudHM=');

@$core.Deprecated('Use updateDebtRequestDescriptor instead')
const UpdateDebtRequest$json = {
  '1': 'UpdateDebtRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'counterparty', '3': 2, '4': 1, '5': 9, '10': 'counterparty'},
    {'1': 'interest_rate', '3': 3, '4': 1, '5': 1, '10': 'interestRate'},
    {'1': 'version', '3': 4, '4': 1, '5': 3, '10': 'version'},
  ],
};

/// Descriptor for `UpdateDebtRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateDebtRequestDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVEZWJ0UmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSIgoMY291bnRlcnBhcnR5GAIgAS'
    'gJUgxjb3VudGVycGFydHkSIwoNaW50ZXJlc3RfcmF0ZRgDIAEoAVIMaW50ZXJlc3RSYXRlEhgK'
    'B3ZlcnNpb24YBCABKANSB3ZlcnNpb24=');

@$core.Deprecated('Use deleteDebtRequestDescriptor instead')
const DeleteDebtRequest$json = {
  '1': 'DeleteDebtRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteDebtRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteDebtRequestDescriptor =
    $convert.base64Decode('ChFEZWxldGVEZWJ0UmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use recordPaymentRequestDescriptor instead')
const RecordPaymentRequest$json = {
  '1': 'RecordPaymentRequest',
  '2': [
    {'1': 'debt_id', '3': 1, '4': 1, '5': 9, '10': 'debtId'},
    {'1': 'schedule_entry_id', '3': 2, '4': 1, '5': 9, '10': 'scheduleEntryId'},
    {'1': 'from_account_id', '3': 3, '4': 1, '5': 9, '10': 'fromAccountId'},
  ],
};

/// Descriptor for `RecordPaymentRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordPaymentRequestDescriptor = $convert.base64Decode(
    'ChRSZWNvcmRQYXltZW50UmVxdWVzdBIXCgdkZWJ0X2lkGAEgASgJUgZkZWJ0SWQSKgoRc2NoZW'
    'R1bGVfZW50cnlfaWQYAiABKAlSD3NjaGVkdWxlRW50cnlJZBImCg9mcm9tX2FjY291bnRfaWQY'
    'AyABKAlSDWZyb21BY2NvdW50SWQ=');

@$core.Deprecated('Use recordPaymentResponseDescriptor instead')
const RecordPaymentResponse$json = {
  '1': 'RecordPaymentResponse',
  '2': [
    {'1': 'transaction_id', '3': 1, '4': 1, '5': 9, '10': 'transactionId'},
    {
      '1': 'entry',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.yucai.debt.v1.PaymentEntryDTO',
      '10': 'entry'
    },
  ],
};

/// Descriptor for `RecordPaymentResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordPaymentResponseDescriptor = $convert.base64Decode(
    'ChVSZWNvcmRQYXltZW50UmVzcG9uc2USJQoOdHJhbnNhY3Rpb25faWQYASABKAlSDXRyYW5zYW'
    'N0aW9uSWQSNAoFZW50cnkYAiABKAsyHi55dWNhaS5kZWJ0LnYxLlBheW1lbnRFbnRyeURUT1IF'
    'ZW50cnk=');

@$core.Deprecated('Use getDebtRequestDescriptor instead')
const GetDebtRequest$json = {
  '1': 'GetDebtRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetDebtRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getDebtRequestDescriptor =
    $convert.base64Decode('Cg5HZXREZWJ0UmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use listDebtsRequestDescriptor instead')
const ListDebtsRequest$json = {
  '1': 'ListDebtsRequest',
  '2': [
    {
      '1': 'page',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageRequest',
      '10': 'page'
    },
  ],
};

/// Descriptor for `ListDebtsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDebtsRequestDescriptor = $convert.base64Decode(
    'ChBMaXN0RGVidHNSZXF1ZXN0EjAKBHBhZ2UYASABKAsyHC55dWNhaS5jb21tb24udjEuUGFnZV'
    'JlcXVlc3RSBHBhZ2U=');

@$core.Deprecated('Use listDebtsResponseDescriptor instead')
const ListDebtsResponse$json = {
  '1': 'ListDebtsResponse',
  '2': [
    {
      '1': 'debts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.debt.v1.DebtDTO',
      '10': 'debts'
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

/// Descriptor for `ListDebtsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDebtsResponseDescriptor = $convert.base64Decode(
    'ChFMaXN0RGVidHNSZXNwb25zZRIsCgVkZWJ0cxgBIAMoCzIWLnl1Y2FpLmRlYnQudjEuRGVidE'
    'RUT1IFZGVidHMSMQoEcGFnZRgCIAEoCzIdLnl1Y2FpLmNvbW1vbi52MS5QYWdlUmVzcG9uc2VS'
    'BHBhZ2U=');

@$core.Deprecated('Use getUpcomingPaymentsRequestDescriptor instead')
const GetUpcomingPaymentsRequest$json = {
  '1': 'GetUpcomingPaymentsRequest',
  '2': [
    {'1': 'days_ahead', '3': 1, '4': 1, '5': 5, '10': 'daysAhead'},
  ],
};

/// Descriptor for `GetUpcomingPaymentsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getUpcomingPaymentsRequestDescriptor =
    $convert.base64Decode(
        'ChpHZXRVcGNvbWluZ1BheW1lbnRzUmVxdWVzdBIdCgpkYXlzX2FoZWFkGAEgASgFUglkYXlzQW'
        'hlYWQ=');

@$core.Deprecated('Use debtResponseDescriptor instead')
const DebtResponse$json = {
  '1': 'DebtResponse',
  '2': [
    {
      '1': 'debt',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.debt.v1.DebtDTO',
      '10': 'debt'
    },
  ],
};

/// Descriptor for `DebtResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List debtResponseDescriptor = $convert.base64Decode(
    'CgxEZWJ0UmVzcG9uc2USKgoEZGVidBgBIAEoCzIWLnl1Y2FpLmRlYnQudjEuRGVidERUT1IEZG'
    'VidA==');

@$core.Deprecated('Use debtDetailResponseDescriptor instead')
const DebtDetailResponse$json = {
  '1': 'DebtDetailResponse',
  '2': [
    {
      '1': 'debt',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.debt.v1.DebtDetailDTO',
      '10': 'debt'
    },
  ],
};

/// Descriptor for `DebtDetailResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List debtDetailResponseDescriptor = $convert.base64Decode(
    'ChJEZWJ0RGV0YWlsUmVzcG9uc2USMAoEZGVidBgBIAEoCzIcLnl1Y2FpLmRlYnQudjEuRGVidE'
    'RldGFpbERUT1IEZGVidA==');

const $core.Map<$core.String, $core.dynamic> DebtServiceBase$json = {
  '1': 'DebtService',
  '2': [
    {
      '1': 'CreateDebt',
      '2': '.yucai.debt.v1.CreateDebtRequest',
      '3': '.yucai.debt.v1.DebtResponse'
    },
    {
      '1': 'UpdateDebt',
      '2': '.yucai.debt.v1.UpdateDebtRequest',
      '3': '.yucai.debt.v1.DebtResponse'
    },
    {
      '1': 'DeleteDebt',
      '2': '.yucai.debt.v1.DeleteDebtRequest',
      '3': '.google.protobuf.Empty'
    },
    {
      '1': 'RecordPayment',
      '2': '.yucai.debt.v1.RecordPaymentRequest',
      '3': '.yucai.debt.v1.RecordPaymentResponse'
    },
    {
      '1': 'GetDebt',
      '2': '.yucai.debt.v1.GetDebtRequest',
      '3': '.yucai.debt.v1.DebtDetailResponse'
    },
    {
      '1': 'ListDebts',
      '2': '.yucai.debt.v1.ListDebtsRequest',
      '3': '.yucai.debt.v1.ListDebtsResponse'
    },
    {
      '1': 'GetUpcomingPayments',
      '2': '.yucai.debt.v1.GetUpcomingPaymentsRequest',
      '3': '.yucai.debt.v1.ListDebtsResponse'
    },
  ],
};

@$core.Deprecated('Use debtServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    DebtServiceBase$messageJson = {
  '.yucai.debt.v1.CreateDebtRequest': CreateDebtRequest$json,
  '.yucai.debt.v1.DebtResponse': DebtResponse$json,
  '.yucai.debt.v1.DebtDTO': DebtDTO$json,
  '.google.protobuf.Timestamp': $0.Timestamp$json,
  '.yucai.debt.v1.UpdateDebtRequest': UpdateDebtRequest$json,
  '.yucai.debt.v1.DeleteDebtRequest': DeleteDebtRequest$json,
  '.google.protobuf.Empty': $2.Empty$json,
  '.yucai.debt.v1.RecordPaymentRequest': RecordPaymentRequest$json,
  '.yucai.debt.v1.RecordPaymentResponse': RecordPaymentResponse$json,
  '.yucai.debt.v1.PaymentEntryDTO': PaymentEntryDTO$json,
  '.yucai.debt.v1.GetDebtRequest': GetDebtRequest$json,
  '.yucai.debt.v1.DebtDetailResponse': DebtDetailResponse$json,
  '.yucai.debt.v1.DebtDetailDTO': DebtDetailDTO$json,
  '.yucai.debt.v1.ListDebtsRequest': ListDebtsRequest$json,
  '.yucai.common.v1.PageRequest': $1.PageRequest$json,
  '.yucai.debt.v1.ListDebtsResponse': ListDebtsResponse$json,
  '.yucai.common.v1.PageResponse': $1.PageResponse$json,
  '.yucai.debt.v1.GetUpcomingPaymentsRequest': GetUpcomingPaymentsRequest$json,
};

/// Descriptor for `DebtService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List debtServiceDescriptor = $convert.base64Decode(
    'CgtEZWJ0U2VydmljZRJLCgpDcmVhdGVEZWJ0EiAueXVjYWkuZGVidC52MS5DcmVhdGVEZWJ0Um'
    'VxdWVzdBobLnl1Y2FpLmRlYnQudjEuRGVidFJlc3BvbnNlEksKClVwZGF0ZURlYnQSIC55dWNh'
    'aS5kZWJ0LnYxLlVwZGF0ZURlYnRSZXF1ZXN0GhsueXVjYWkuZGVidC52MS5EZWJ0UmVzcG9uc2'
    'USRgoKRGVsZXRlRGVidBIgLnl1Y2FpLmRlYnQudjEuRGVsZXRlRGVidFJlcXVlc3QaFi5nb29n'
    'bGUucHJvdG9idWYuRW1wdHkSWgoNUmVjb3JkUGF5bWVudBIjLnl1Y2FpLmRlYnQudjEuUmVjb3'
    'JkUGF5bWVudFJlcXVlc3QaJC55dWNhaS5kZWJ0LnYxLlJlY29yZFBheW1lbnRSZXNwb25zZRJL'
    'CgdHZXREZWJ0Eh0ueXVjYWkuZGVidC52MS5HZXREZWJ0UmVxdWVzdBohLnl1Y2FpLmRlYnQudj'
    'EuRGVidERldGFpbFJlc3BvbnNlEk4KCUxpc3REZWJ0cxIfLnl1Y2FpLmRlYnQudjEuTGlzdERl'
    'YnRzUmVxdWVzdBogLnl1Y2FpLmRlYnQudjEuTGlzdERlYnRzUmVzcG9uc2USYgoTR2V0VXBjb2'
    '1pbmdQYXltZW50cxIpLnl1Y2FpLmRlYnQudjEuR2V0VXBjb21pbmdQYXltZW50c1JlcXVlc3Qa'
    'IC55dWNhaS5kZWJ0LnYxLkxpc3REZWJ0c1Jlc3BvbnNl');
