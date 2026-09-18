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

@$core.Deprecated('Use amortizationMethodDescriptor instead')
const AmortizationMethod$json = {
  '1': 'AmortizationMethod',
  '2': [
    {'1': 'AMORTIZATION_UNSPECIFIED', '2': 0},
    {'1': 'AMORTIZATION_EQUAL_PRINCIPAL_INTEREST', '2': 1},
    {'1': 'AMORTIZATION_EQUAL_PRINCIPAL', '2': 2},
    {'1': 'AMORTIZATION_LUMP_SUM', '2': 3},
    {'1': 'AMORTIZATION_INTEREST_FIRST', '2': 4},
  ],
};

/// Descriptor for `AmortizationMethod`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List amortizationMethodDescriptor = $convert.base64Decode(
    'ChJBbW9ydGl6YXRpb25NZXRob2QSHAoYQU1PUlRJWkFUSU9OX1VOU1BFQ0lGSUVEEAASKQolQU'
    '1PUlRJWkFUSU9OX0VRVUFMX1BSSU5DSVBBTF9JTlRFUkVTVBABEiAKHEFNT1JUSVpBVElPTl9F'
    'UVVBTF9QUklOQ0lQQUwQAhIZChVBTU9SVElaQVRJT05fTFVNUF9TVU0QAxIfChtBTU9SVElaQV'
    'RJT05fSU5URVJFU1RfRklSU1QQBA==');

@$core.Deprecated('Use debtTypeDescriptor instead')
const DebtType$json = {
  '1': 'DebtType',
  '2': [
    {'1': 'DEBT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'DEBT_TYPE_BORROWED_IN', '2': 1},
    {'1': 'DEBT_TYPE_BORROWED_OUT', '2': 2},
  ],
};

/// Descriptor for `DebtType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List debtTypeDescriptor = $convert.base64Decode(
    'CghEZWJ0VHlwZRIZChVERUJUX1RZUEVfVU5TUEVDSUZJRUQQABIZChVERUJUX1RZUEVfQk9SUk'
    '9XRURfSU4QARIaChZERUJUX1RZUEVfQk9SUk9XRURfT1VUEAI=');

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
    {
      '1': 'debt_type',
      '3': 13,
      '4': 1,
      '5': 14,
      '6': '.yucai.debt.v1.DebtType',
      '10': 'debtType'
    },
    {'1': 'subtype', '3': 14, '4': 1, '5': 9, '10': 'subtype'},
    {'1': 'contact', '3': 15, '4': 1, '5': 9, '10': 'contact'},
    {'1': 'contract_ref', '3': 16, '4': 1, '5': 9, '10': 'contractRef'},
    {
      '1': 'collection_account_id',
      '3': 17,
      '4': 1,
      '5': 9,
      '10': 'collectionAccountId'
    },
    {
      '1': 'next_payment_date',
      '3': 18,
      '4': 1,
      '5': 9,
      '10': 'nextPaymentDate'
    },
    {
      '1': 'next_payment_amount_cents',
      '3': 19,
      '4': 1,
      '5': 3,
      '10': 'nextPaymentAmountCents'
    },
    {
      '1': 'next_payment_period_no',
      '3': 20,
      '4': 1,
      '5': 5,
      '10': 'nextPaymentPeriodNo'
    },
    {
      '1': 'remaining_trend_cents',
      '3': 21,
      '4': 1,
      '5': 3,
      '10': 'remainingTrendCents'
    },
    {
      '1': 'cycle',
      '3': 22,
      '4': 1,
      '5': 14,
      '6': '.yucai.common.v1.RecurrenceCycle',
      '10': 'cycle'
    },
    {'1': 'interval', '3': 23, '4': 1, '5': 5, '10': 'interval'},
    {'1': 'weekday_mask', '3': 24, '4': 1, '5': 5, '10': 'weekdayMask'},
    {
      '1': 'monthly_mode',
      '3': 25,
      '4': 1,
      '5': 14,
      '6': '.yucai.common.v1.RecurrenceMonthlyMode',
      '10': 'monthlyMode'
    },
    {'1': 'nth', '3': 26, '4': 1, '5': 5, '10': 'nth'},
    {'1': 'guarantor_name', '3': 27, '4': 1, '5': 9, '10': 'guarantorName'},
    {
      '1': 'guarantor_contact',
      '3': 28,
      '4': 1,
      '5': 9,
      '10': 'guarantorContact'
    },
    {
      '1': 'interest_waived_cents',
      '3': 29,
      '4': 1,
      '5': 3,
      '10': 'interestWaivedCents'
    },
    {
      '1': 'remaining_interest_cents',
      '3': 30,
      '4': 1,
      '5': 3,
      '10': 'remainingInterestCents'
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
    'JvdG9idWYuVGltZXN0YW1wUgl1cGRhdGVkQXQSNAoJZGVidF90eXBlGA0gASgOMhcueXVjYWku'
    'ZGVidC52MS5EZWJ0VHlwZVIIZGVidFR5cGUSGAoHc3VidHlwZRgOIAEoCVIHc3VidHlwZRIYCg'
    'djb250YWN0GA8gASgJUgdjb250YWN0EiEKDGNvbnRyYWN0X3JlZhgQIAEoCVILY29udHJhY3RS'
    'ZWYSMgoVY29sbGVjdGlvbl9hY2NvdW50X2lkGBEgASgJUhNjb2xsZWN0aW9uQWNjb3VudElkEi'
    'oKEW5leHRfcGF5bWVudF9kYXRlGBIgASgJUg9uZXh0UGF5bWVudERhdGUSOQoZbmV4dF9wYXlt'
    'ZW50X2Ftb3VudF9jZW50cxgTIAEoA1IWbmV4dFBheW1lbnRBbW91bnRDZW50cxIzChZuZXh0X3'
    'BheW1lbnRfcGVyaW9kX25vGBQgASgFUhNuZXh0UGF5bWVudFBlcmlvZE5vEjIKFXJlbWFpbmlu'
    'Z190cmVuZF9jZW50cxgVIAEoA1ITcmVtYWluaW5nVHJlbmRDZW50cxI2CgVjeWNsZRgWIAEoDj'
    'IgLnl1Y2FpLmNvbW1vbi52MS5SZWN1cnJlbmNlQ3ljbGVSBWN5Y2xlEhoKCGludGVydmFsGBcg'
    'ASgFUghpbnRlcnZhbBIhCgx3ZWVrZGF5X21hc2sYGCABKAVSC3dlZWtkYXlNYXNrEkkKDG1vbn'
    'RobHlfbW9kZRgZIAEoDjImLnl1Y2FpLmNvbW1vbi52MS5SZWN1cnJlbmNlTW9udGhseU1vZGVS'
    'C21vbnRobHlNb2RlEhAKA250aBgaIAEoBVIDbnRoEiUKDmd1YXJhbnRvcl9uYW1lGBsgASgJUg'
    '1ndWFyYW50b3JOYW1lEisKEWd1YXJhbnRvcl9jb250YWN0GBwgASgJUhBndWFyYW50b3JDb250'
    'YWN0EjIKFWludGVyZXN0X3dhaXZlZF9jZW50cxgdIAEoA1ITaW50ZXJlc3RXYWl2ZWRDZW50cx'
    'I4ChhyZW1haW5pbmdfaW50ZXJlc3RfY2VudHMYHiABKANSFnJlbWFpbmluZ0ludGVyZXN0Q2Vu'
    'dHM=');

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
    {
      '1': 'debt_type',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.yucai.debt.v1.DebtType',
      '10': 'debtType'
    },
    {'1': 'subtype', '3': 9, '4': 1, '5': 9, '10': 'subtype'},
    {
      '1': 'source_account_id',
      '3': 10,
      '4': 1,
      '5': 9,
      '10': 'sourceAccountId'
    },
    {'1': 'contact', '3': 11, '4': 1, '5': 9, '10': 'contact'},
    {'1': 'contract_ref', '3': 12, '4': 1, '5': 9, '10': 'contractRef'},
    {
      '1': 'collection_account_id',
      '3': 13,
      '4': 1,
      '5': 9,
      '10': 'collectionAccountId'
    },
    {
      '1': 'cycle',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.yucai.common.v1.RecurrenceCycle',
      '10': 'cycle'
    },
    {'1': 'interval', '3': 15, '4': 1, '5': 5, '10': 'interval'},
    {'1': 'weekday_mask', '3': 16, '4': 1, '5': 5, '10': 'weekdayMask'},
    {
      '1': 'monthly_mode',
      '3': 17,
      '4': 1,
      '5': 14,
      '6': '.yucai.common.v1.RecurrenceMonthlyMode',
      '10': 'monthlyMode'
    },
    {'1': 'nth', '3': 18, '4': 1, '5': 5, '10': 'nth'},
    {'1': 'term_periods', '3': 19, '4': 1, '5': 5, '10': 'termPeriods'},
    {'1': 'guarantor_name', '3': 20, '4': 1, '5': 9, '10': 'guarantorName'},
    {
      '1': 'guarantor_contact',
      '3': 21,
      '4': 1,
      '5': 9,
      '10': 'guarantorContact'
    },
    {
      '1': 'interest_waived_cents',
      '3': 22,
      '4': 1,
      '5': 3,
      '10': 'interestWaivedCents'
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
    'luY2lwYWxfY2VudHMYByABKANSE3RvdGFsUHJpbmNpcGFsQ2VudHMSNAoJZGVidF90eXBlGAgg'
    'ASgOMhcueXVjYWkuZGVidC52MS5EZWJ0VHlwZVIIZGVidFR5cGUSGAoHc3VidHlwZRgJIAEoCV'
    'IHc3VidHlwZRIqChFzb3VyY2VfYWNjb3VudF9pZBgKIAEoCVIPc291cmNlQWNjb3VudElkEhgK'
    'B2NvbnRhY3QYCyABKAlSB2NvbnRhY3QSIQoMY29udHJhY3RfcmVmGAwgASgJUgtjb250cmFjdF'
    'JlZhIyChVjb2xsZWN0aW9uX2FjY291bnRfaWQYDSABKAlSE2NvbGxlY3Rpb25BY2NvdW50SWQS'
    'NgoFY3ljbGUYDiABKA4yIC55dWNhaS5jb21tb24udjEuUmVjdXJyZW5jZUN5Y2xlUgVjeWNsZR'
    'IaCghpbnRlcnZhbBgPIAEoBVIIaW50ZXJ2YWwSIQoMd2Vla2RheV9tYXNrGBAgASgFUgt3ZWVr'
    'ZGF5TWFzaxJJCgxtb250aGx5X21vZGUYESABKA4yJi55dWNhaS5jb21tb24udjEuUmVjdXJyZW'
    '5jZU1vbnRobHlNb2RlUgttb250aGx5TW9kZRIQCgNudGgYEiABKAVSA250aBIhCgx0ZXJtX3Bl'
    'cmlvZHMYEyABKAVSC3Rlcm1QZXJpb2RzEiUKDmd1YXJhbnRvcl9uYW1lGBQgASgJUg1ndWFyYW'
    '50b3JOYW1lEisKEWd1YXJhbnRvcl9jb250YWN0GBUgASgJUhBndWFyYW50b3JDb250YWN0EjIK'
    'FWludGVyZXN0X3dhaXZlZF9jZW50cxgWIAEoA1ITaW50ZXJlc3RXYWl2ZWRDZW50cw==');

@$core.Deprecated('Use updateDebtRequestDescriptor instead')
const UpdateDebtRequest$json = {
  '1': 'UpdateDebtRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'counterparty', '3': 2, '4': 1, '5': 9, '10': 'counterparty'},
    {'1': 'interest_rate', '3': 3, '4': 1, '5': 1, '10': 'interestRate'},
    {'1': 'version', '3': 4, '4': 1, '5': 3, '10': 'version'},
    {'1': 'contact', '3': 5, '4': 1, '5': 9, '10': 'contact'},
    {'1': 'contract_ref', '3': 6, '4': 1, '5': 9, '10': 'contractRef'},
    {
      '1': 'collection_account_id',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'collectionAccountId'
    },
    {
      '1': 'amortization_method',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.yucai.debt.v1.AmortizationMethod',
      '10': 'amortizationMethod'
    },
    {'1': 'due_date', '3': 9, '4': 1, '5': 9, '10': 'dueDate'},
    {'1': 'term_periods', '3': 10, '4': 1, '5': 5, '10': 'termPeriods'},
    {
      '1': 'cycle',
      '3': 11,
      '4': 1,
      '5': 14,
      '6': '.yucai.common.v1.RecurrenceCycle',
      '10': 'cycle'
    },
    {'1': 'interval', '3': 12, '4': 1, '5': 5, '10': 'interval'},
    {'1': 'weekday_mask', '3': 13, '4': 1, '5': 5, '10': 'weekdayMask'},
    {
      '1': 'monthly_mode',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.yucai.common.v1.RecurrenceMonthlyMode',
      '10': 'monthlyMode'
    },
    {'1': 'nth', '3': 15, '4': 1, '5': 5, '10': 'nth'},
    {'1': 'guarantor_name', '3': 16, '4': 1, '5': 9, '10': 'guarantorName'},
    {
      '1': 'guarantor_contact',
      '3': 17,
      '4': 1,
      '5': 9,
      '10': 'guarantorContact'
    },
    {
      '1': 'interest_waived_cents',
      '3': 18,
      '4': 1,
      '5': 3,
      '9': 0,
      '10': 'interestWaivedCents',
      '17': true
    },
  ],
  '8': [
    {'1': '_interest_waived_cents'},
  ],
};

/// Descriptor for `UpdateDebtRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateDebtRequestDescriptor = $convert.base64Decode(
    'ChFVcGRhdGVEZWJ0UmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSIgoMY291bnRlcnBhcnR5GAIgAS'
    'gJUgxjb3VudGVycGFydHkSIwoNaW50ZXJlc3RfcmF0ZRgDIAEoAVIMaW50ZXJlc3RSYXRlEhgK'
    'B3ZlcnNpb24YBCABKANSB3ZlcnNpb24SGAoHY29udGFjdBgFIAEoCVIHY29udGFjdBIhCgxjb2'
    '50cmFjdF9yZWYYBiABKAlSC2NvbnRyYWN0UmVmEjIKFWNvbGxlY3Rpb25fYWNjb3VudF9pZBgH'
    'IAEoCVITY29sbGVjdGlvbkFjY291bnRJZBJSChNhbW9ydGl6YXRpb25fbWV0aG9kGAggASgOMi'
    'EueXVjYWkuZGVidC52MS5BbW9ydGl6YXRpb25NZXRob2RSEmFtb3J0aXphdGlvbk1ldGhvZBIZ'
    'CghkdWVfZGF0ZRgJIAEoCVIHZHVlRGF0ZRIhCgx0ZXJtX3BlcmlvZHMYCiABKAVSC3Rlcm1QZX'
    'Jpb2RzEjYKBWN5Y2xlGAsgASgOMiAueXVjYWkuY29tbW9uLnYxLlJlY3VycmVuY2VDeWNsZVIF'
    'Y3ljbGUSGgoIaW50ZXJ2YWwYDCABKAVSCGludGVydmFsEiEKDHdlZWtkYXlfbWFzaxgNIAEoBV'
    'ILd2Vla2RheU1hc2sSSQoMbW9udGhseV9tb2RlGA4gASgOMiYueXVjYWkuY29tbW9uLnYxLlJl'
    'Y3VycmVuY2VNb250aGx5TW9kZVILbW9udGhseU1vZGUSEAoDbnRoGA8gASgFUgNudGgSJQoOZ3'
    'VhcmFudG9yX25hbWUYECABKAlSDWd1YXJhbnRvck5hbWUSKwoRZ3VhcmFudG9yX2NvbnRhY3QY'
    'ESABKAlSEGd1YXJhbnRvckNvbnRhY3QSNwoVaW50ZXJlc3Rfd2FpdmVkX2NlbnRzGBIgASgDSA'
    'BSE2ludGVyZXN0V2FpdmVkQ2VudHOIAQFCGAoWX2ludGVyZXN0X3dhaXZlZF9jZW50cw==');

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

@$core.Deprecated('Use setPaymentDateRequestDescriptor instead')
const SetPaymentDateRequest$json = {
  '1': 'SetPaymentDateRequest',
  '2': [
    {'1': 'debt_id', '3': 1, '4': 1, '5': 9, '10': 'debtId'},
    {'1': 'entry_id', '3': 2, '4': 1, '5': 9, '10': 'entryId'},
    {'1': 'payment_date', '3': 3, '4': 1, '5': 9, '10': 'paymentDate'},
  ],
};

/// Descriptor for `SetPaymentDateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List setPaymentDateRequestDescriptor = $convert.base64Decode(
    'ChVTZXRQYXltZW50RGF0ZVJlcXVlc3QSFwoHZGVidF9pZBgBIAEoCVIGZGVidElkEhkKCGVudH'
    'J5X2lkGAIgASgJUgdlbnRyeUlkEiEKDHBheW1lbnRfZGF0ZRgDIAEoCVILcGF5bWVudERhdGU=');

@$core.Deprecated('Use paymentEntryResponseDescriptor instead')
const PaymentEntryResponse$json = {
  '1': 'PaymentEntryResponse',
  '2': [
    {
      '1': 'entry',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.debt.v1.PaymentEntryDTO',
      '10': 'entry'
    },
  ],
};

/// Descriptor for `PaymentEntryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List paymentEntryResponseDescriptor = $convert.base64Decode(
    'ChRQYXltZW50RW50cnlSZXNwb25zZRI0CgVlbnRyeRgBIAEoCzIeLnl1Y2FpLmRlYnQudjEuUG'
    'F5bWVudEVudHJ5RFRPUgVlbnRyeQ==');

@$core.Deprecated('Use markEntryPaidRequestDescriptor instead')
const MarkEntryPaidRequest$json = {
  '1': 'MarkEntryPaidRequest',
  '2': [
    {'1': 'debt_id', '3': 1, '4': 1, '5': 9, '10': 'debtId'},
    {'1': 'entry_id', '3': 2, '4': 1, '5': 9, '10': 'entryId'},
  ],
};

/// Descriptor for `MarkEntryPaidRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List markEntryPaidRequestDescriptor = $convert.base64Decode(
    'ChRNYXJrRW50cnlQYWlkUmVxdWVzdBIXCgdkZWJ0X2lkGAEgASgJUgZkZWJ0SWQSGQoIZW50cn'
    'lfaWQYAiABKAlSB2VudHJ5SWQ=');

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
    {
      '1': 'type_filter',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.debt.v1.DebtType',
      '10': 'typeFilter'
    },
  ],
};

/// Descriptor for `ListDebtsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listDebtsRequestDescriptor = $convert.base64Decode(
    'ChBMaXN0RGVidHNSZXF1ZXN0EjAKBHBhZ2UYASABKAsyHC55dWNhaS5jb21tb24udjEuUGFnZV'
    'JlcXVlc3RSBHBhZ2USOAoLdHlwZV9maWx0ZXIYAiABKA4yFy55dWNhaS5kZWJ0LnYxLkRlYnRU'
    'eXBlUgp0eXBlRmlsdGVy');

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

@$core.Deprecated('Use getReceivablesSummaryRequestDescriptor instead')
const GetReceivablesSummaryRequest$json = {
  '1': 'GetReceivablesSummaryRequest',
};

/// Descriptor for `GetReceivablesSummaryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getReceivablesSummaryRequestDescriptor =
    $convert.base64Decode('ChxHZXRSZWNlaXZhYmxlc1N1bW1hcnlSZXF1ZXN0');

@$core.Deprecated('Use receivablesSummaryDTODescriptor instead')
const ReceivablesSummaryDTO$json = {
  '1': 'ReceivablesSummaryDTO',
  '2': [
    {
      '1': 'total_principal_cents',
      '3': 1,
      '4': 1,
      '5': 3,
      '10': 'totalPrincipalCents'
    },
    {
      '1': 'total_remaining_cents',
      '3': 2,
      '4': 1,
      '5': 3,
      '10': 'totalRemainingCents'
    },
    {
      '1': 'total_collected_cents',
      '3': 3,
      '4': 1,
      '5': 3,
      '10': 'totalCollectedCents'
    },
    {
      '1': 'pending_interest_cents',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'pendingInterestCents'
    },
    {'1': 'count', '3': 5, '4': 1, '5': 5, '10': 'count'},
    {'1': 'overdue_count', '3': 6, '4': 1, '5': 5, '10': 'overdueCount'},
    {
      '1': 'overdue_amount_cents',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'overdueAmountCents'
    },
    {
      '1': 'principal_trend_cents',
      '3': 8,
      '4': 1,
      '5': 3,
      '10': 'principalTrendCents'
    },
    {
      '1': 'remaining_trend_cents',
      '3': 9,
      '4': 1,
      '5': 3,
      '10': 'remainingTrendCents'
    },
    {
      '1': 'next_payment_date',
      '3': 10,
      '4': 1,
      '5': 9,
      '10': 'nextPaymentDate'
    },
    {
      '1': 'next_payment_amount_cents',
      '3': 11,
      '4': 1,
      '5': 3,
      '10': 'nextPaymentAmountCents'
    },
    {
      '1': 'next_payment_counterparty',
      '3': 12,
      '4': 1,
      '5': 9,
      '10': 'nextPaymentCounterparty'
    },
    {
      '1': 'next_payment_period_no',
      '3': 13,
      '4': 1,
      '5': 5,
      '10': 'nextPaymentPeriodNo'
    },
    {
      '1': 'new_count_this_month',
      '3': 14,
      '4': 1,
      '5': 5,
      '10': 'newCountThisMonth'
    },
  ],
};

/// Descriptor for `ReceivablesSummaryDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List receivablesSummaryDTODescriptor = $convert.base64Decode(
    'ChVSZWNlaXZhYmxlc1N1bW1hcnlEVE8SMgoVdG90YWxfcHJpbmNpcGFsX2NlbnRzGAEgASgDUh'
    'N0b3RhbFByaW5jaXBhbENlbnRzEjIKFXRvdGFsX3JlbWFpbmluZ19jZW50cxgCIAEoA1ITdG90'
    'YWxSZW1haW5pbmdDZW50cxIyChV0b3RhbF9jb2xsZWN0ZWRfY2VudHMYAyABKANSE3RvdGFsQ2'
    '9sbGVjdGVkQ2VudHMSNAoWcGVuZGluZ19pbnRlcmVzdF9jZW50cxgEIAEoA1IUcGVuZGluZ0lu'
    'dGVyZXN0Q2VudHMSFAoFY291bnQYBSABKAVSBWNvdW50EiMKDW92ZXJkdWVfY291bnQYBiABKA'
    'VSDG92ZXJkdWVDb3VudBIwChRvdmVyZHVlX2Ftb3VudF9jZW50cxgHIAEoA1ISb3ZlcmR1ZUFt'
    'b3VudENlbnRzEjIKFXByaW5jaXBhbF90cmVuZF9jZW50cxgIIAEoA1ITcHJpbmNpcGFsVHJlbm'
    'RDZW50cxIyChVyZW1haW5pbmdfdHJlbmRfY2VudHMYCSABKANSE3JlbWFpbmluZ1RyZW5kQ2Vu'
    'dHMSKgoRbmV4dF9wYXltZW50X2RhdGUYCiABKAlSD25leHRQYXltZW50RGF0ZRI5ChluZXh0X3'
    'BheW1lbnRfYW1vdW50X2NlbnRzGAsgASgDUhZuZXh0UGF5bWVudEFtb3VudENlbnRzEjoKGW5l'
    'eHRfcGF5bWVudF9jb3VudGVycGFydHkYDCABKAlSF25leHRQYXltZW50Q291bnRlcnBhcnR5Ej'
    'MKFm5leHRfcGF5bWVudF9wZXJpb2Rfbm8YDSABKAVSE25leHRQYXltZW50UGVyaW9kTm8SLwoU'
    'bmV3X2NvdW50X3RoaXNfbW9udGgYDiABKAVSEW5ld0NvdW50VGhpc01vbnRo');

@$core.Deprecated('Use receivablesSummaryResponseDescriptor instead')
const ReceivablesSummaryResponse$json = {
  '1': 'ReceivablesSummaryResponse',
  '2': [
    {
      '1': 'summary',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.debt.v1.ReceivablesSummaryDTO',
      '10': 'summary'
    },
  ],
};

/// Descriptor for `ReceivablesSummaryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List receivablesSummaryResponseDescriptor =
    $convert.base64Decode(
        'ChpSZWNlaXZhYmxlc1N1bW1hcnlSZXNwb25zZRI+CgdzdW1tYXJ5GAEgASgLMiQueXVjYWkuZG'
        'VidC52MS5SZWNlaXZhYmxlc1N1bW1hcnlEVE9SB3N1bW1hcnk=');
