// This is a generated file - do not edit.
//
// Generated from transaction/v1/transaction.proto.

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

@$core.Deprecated('Use scopeDescriptor instead')
const Scope$json = {
  '1': 'Scope',
  '2': [
    {'1': 'SCOPE_UNSPECIFIED', '2': 0},
    {'1': 'SCOPE_DAY', '2': 1},
    {'1': 'SCOPE_MONTH', '2': 2},
    {'1': 'SCOPE_YEAR', '2': 3},
  ],
};

/// Descriptor for `Scope`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List scopeDescriptor = $convert.base64Decode(
    'CgVTY29wZRIVChFTQ09QRV9VTlNQRUNJRklFRBAAEg0KCVNDT1BFX0RBWRABEg8KC1NDT1BFX0'
    '1PTlRIEAISDgoKU0NPUEVfWUVBUhAD');

@$core.Deprecated('Use transactionDTODescriptor instead')
const TransactionDTO$json = {
  '1': 'TransactionDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'transaction_date', '3': 2, '4': 1, '5': 9, '10': 'transactionDate'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'entries',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.yucai.transaction.v1.EntryDTO',
      '10': 'entries'
    },
    {'1': 'version', '3': 5, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'created_at',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 7,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
    {'1': 'transaction_time', '3': 8, '4': 1, '5': 9, '10': 'transactionTime'},
  ],
};

/// Descriptor for `TransactionDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transactionDTODescriptor = $convert.base64Decode(
    'Cg5UcmFuc2FjdGlvbkRUTxIOCgJpZBgBIAEoCVICaWQSKQoQdHJhbnNhY3Rpb25fZGF0ZRgCIA'
    'EoCVIPdHJhbnNhY3Rpb25EYXRlEiAKC2Rlc2NyaXB0aW9uGAMgASgJUgtkZXNjcmlwdGlvbhI4'
    'CgdlbnRyaWVzGAQgAygLMh4ueXVjYWkudHJhbnNhY3Rpb24udjEuRW50cnlEVE9SB2VudHJpZX'
    'MSGAoHdmVyc2lvbhgFIAEoA1IHdmVyc2lvbhI5CgpjcmVhdGVkX2F0GAYgASgLMhouZ29vZ2xl'
    'LnByb3RvYnVmLlRpbWVzdGFtcFIJY3JlYXRlZEF0EjkKCnVwZGF0ZWRfYXQYByABKAsyGi5nb2'
    '9nbGUucHJvdG9idWYuVGltZXN0YW1wUgl1cGRhdGVkQXQSKQoQdHJhbnNhY3Rpb25fdGltZRgI'
    'IAEoCVIPdHJhbnNhY3Rpb25UaW1l');

@$core.Deprecated('Use entryDTODescriptor instead')
const EntryDTO$json = {
  '1': 'EntryDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'account_id', '3': 2, '4': 1, '5': 9, '10': 'accountId'},
    {
      '1': 'chart_of_account_code',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'chartOfAccountCode'
    },
    {'1': 'debit_cents', '3': 4, '4': 1, '5': 3, '10': 'debitCents'},
    {'1': 'credit_cents', '3': 5, '4': 1, '5': 3, '10': 'creditCents'},
    {'1': 'note', '3': 6, '4': 1, '5': 9, '10': 'note'},
  ],
};

/// Descriptor for `EntryDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List entryDTODescriptor = $convert.base64Decode(
    'CghFbnRyeURUTxIOCgJpZBgBIAEoCVICaWQSHQoKYWNjb3VudF9pZBgCIAEoCVIJYWNjb3VudE'
    'lkEjEKFWNoYXJ0X29mX2FjY291bnRfY29kZRgDIAEoCVISY2hhcnRPZkFjY291bnRDb2RlEh8K'
    'C2RlYml0X2NlbnRzGAQgASgDUgpkZWJpdENlbnRzEiEKDGNyZWRpdF9jZW50cxgFIAEoA1ILY3'
    'JlZGl0Q2VudHMSEgoEbm90ZRgGIAEoCVIEbm90ZQ==');

@$core.Deprecated('Use recordTransactionRequestDescriptor instead')
const RecordTransactionRequest$json = {
  '1': 'RecordTransactionRequest',
  '2': [
    {'1': 'transaction_date', '3': 1, '4': 1, '5': 9, '10': 'transactionDate'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'entries',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.yucai.transaction.v1.EntryDTO',
      '10': 'entries'
    },
    {'1': 'transaction_time', '3': 4, '4': 1, '5': 9, '10': 'transactionTime'},
  ],
};

/// Descriptor for `RecordTransactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List recordTransactionRequestDescriptor = $convert.base64Decode(
    'ChhSZWNvcmRUcmFuc2FjdGlvblJlcXVlc3QSKQoQdHJhbnNhY3Rpb25fZGF0ZRgBIAEoCVIPdH'
    'JhbnNhY3Rpb25EYXRlEiAKC2Rlc2NyaXB0aW9uGAIgASgJUgtkZXNjcmlwdGlvbhI4CgdlbnRy'
    'aWVzGAMgAygLMh4ueXVjYWkudHJhbnNhY3Rpb24udjEuRW50cnlEVE9SB2VudHJpZXMSKQoQdH'
    'JhbnNhY3Rpb25fdGltZRgEIAEoCVIPdHJhbnNhY3Rpb25UaW1l');

@$core.Deprecated('Use getTransactionRequestDescriptor instead')
const GetTransactionRequest$json = {
  '1': 'GetTransactionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetTransactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTransactionRequestDescriptor = $convert
    .base64Decode('ChVHZXRUcmFuc2FjdGlvblJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use listTransactionsRequestDescriptor instead')
const ListTransactionsRequest$json = {
  '1': 'ListTransactionsRequest',
  '2': [
    {
      '1': 'page',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageRequest',
      '10': 'page'
    },
    {'1': 'account_id', '3': 2, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'date_from', '3': 3, '4': 1, '5': 9, '10': 'dateFrom'},
    {'1': 'date_to', '3': 4, '4': 1, '5': 9, '10': 'dateTo'},
  ],
};

/// Descriptor for `ListTransactionsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTransactionsRequestDescriptor = $convert.base64Decode(
    'ChdMaXN0VHJhbnNhY3Rpb25zUmVxdWVzdBIwCgRwYWdlGAEgASgLMhwueXVjYWkuY29tbW9uLn'
    'YxLlBhZ2VSZXF1ZXN0UgRwYWdlEh0KCmFjY291bnRfaWQYAiABKAlSCWFjY291bnRJZBIbCglk'
    'YXRlX2Zyb20YAyABKAlSCGRhdGVGcm9tEhcKB2RhdGVfdG8YBCABKAlSBmRhdGVUbw==');

@$core.Deprecated('Use listTransactionsResponseDescriptor instead')
const ListTransactionsResponse$json = {
  '1': 'ListTransactionsResponse',
  '2': [
    {
      '1': 'transactions',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.transaction.v1.TransactionDTO',
      '10': 'transactions'
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

/// Descriptor for `ListTransactionsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTransactionsResponseDescriptor = $convert.base64Decode(
    'ChhMaXN0VHJhbnNhY3Rpb25zUmVzcG9uc2USSAoMdHJhbnNhY3Rpb25zGAEgAygLMiQueXVjYW'
    'kudHJhbnNhY3Rpb24udjEuVHJhbnNhY3Rpb25EVE9SDHRyYW5zYWN0aW9ucxIxCgRwYWdlGAIg'
    'ASgLMh0ueXVjYWkuY29tbW9uLnYxLlBhZ2VSZXNwb25zZVIEcGFnZQ==');

@$core.Deprecated('Use updateTransactionRequestDescriptor instead')
const UpdateTransactionRequest$json = {
  '1': 'UpdateTransactionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'transaction_date', '3': 2, '4': 1, '5': 9, '10': 'transactionDate'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'entries',
      '3': 4,
      '4': 3,
      '5': 11,
      '6': '.yucai.transaction.v1.EntryDTO',
      '10': 'entries'
    },
    {'1': 'version', '3': 5, '4': 1, '5': 3, '10': 'version'},
  ],
};

/// Descriptor for `UpdateTransactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTransactionRequestDescriptor = $convert.base64Decode(
    'ChhVcGRhdGVUcmFuc2FjdGlvblJlcXVlc3QSDgoCaWQYASABKAlSAmlkEikKEHRyYW5zYWN0aW'
    '9uX2RhdGUYAiABKAlSD3RyYW5zYWN0aW9uRGF0ZRIgCgtkZXNjcmlwdGlvbhgDIAEoCVILZGVz'
    'Y3JpcHRpb24SOAoHZW50cmllcxgEIAMoCzIeLnl1Y2FpLnRyYW5zYWN0aW9uLnYxLkVudHJ5RF'
    'RPUgdlbnRyaWVzEhgKB3ZlcnNpb24YBSABKANSB3ZlcnNpb24=');

@$core.Deprecated('Use deleteTransactionRequestDescriptor instead')
const DeleteTransactionRequest$json = {
  '1': 'DeleteTransactionRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteTransactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTransactionRequestDescriptor = $convert
    .base64Decode('ChhEZWxldGVUcmFuc2FjdGlvblJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use simpleIncomeRequestDescriptor instead')
const SimpleIncomeRequest$json = {
  '1': 'SimpleIncomeRequest',
  '2': [
    {'1': 'transaction_date', '3': 1, '4': 1, '5': 9, '10': 'transactionDate'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'asset_account_id', '3': 3, '4': 1, '5': 9, '10': 'assetAccountId'},
    {'1': 'income_account_id', '3': 4, '4': 1, '5': 9, '10': 'incomeAccountId'},
    {'1': 'amount_cents', '3': 5, '4': 1, '5': 3, '10': 'amountCents'},
    {'1': 'note', '3': 6, '4': 1, '5': 9, '10': 'note'},
    {'1': 'transaction_time', '3': 7, '4': 1, '5': 9, '10': 'transactionTime'},
  ],
};

/// Descriptor for `SimpleIncomeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List simpleIncomeRequestDescriptor = $convert.base64Decode(
    'ChNTaW1wbGVJbmNvbWVSZXF1ZXN0EikKEHRyYW5zYWN0aW9uX2RhdGUYASABKAlSD3RyYW5zYW'
    'N0aW9uRGF0ZRIgCgtkZXNjcmlwdGlvbhgCIAEoCVILZGVzY3JpcHRpb24SKAoQYXNzZXRfYWNj'
    'b3VudF9pZBgDIAEoCVIOYXNzZXRBY2NvdW50SWQSKgoRaW5jb21lX2FjY291bnRfaWQYBCABKA'
    'lSD2luY29tZUFjY291bnRJZBIhCgxhbW91bnRfY2VudHMYBSABKANSC2Ftb3VudENlbnRzEhIK'
    'BG5vdGUYBiABKAlSBG5vdGUSKQoQdHJhbnNhY3Rpb25fdGltZRgHIAEoCVIPdHJhbnNhY3Rpb2'
    '5UaW1l');

@$core.Deprecated('Use simpleExpenseRequestDescriptor instead')
const SimpleExpenseRequest$json = {
  '1': 'SimpleExpenseRequest',
  '2': [
    {'1': 'transaction_date', '3': 1, '4': 1, '5': 9, '10': 'transactionDate'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {
      '1': 'expense_account_id',
      '3': 3,
      '4': 1,
      '5': 9,
      '10': 'expenseAccountId'
    },
    {'1': 'asset_account_id', '3': 4, '4': 1, '5': 9, '10': 'assetAccountId'},
    {'1': 'amount_cents', '3': 5, '4': 1, '5': 3, '10': 'amountCents'},
    {'1': 'note', '3': 6, '4': 1, '5': 9, '10': 'note'},
    {'1': 'transaction_time', '3': 7, '4': 1, '5': 9, '10': 'transactionTime'},
  ],
};

/// Descriptor for `SimpleExpenseRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List simpleExpenseRequestDescriptor = $convert.base64Decode(
    'ChRTaW1wbGVFeHBlbnNlUmVxdWVzdBIpChB0cmFuc2FjdGlvbl9kYXRlGAEgASgJUg90cmFuc2'
    'FjdGlvbkRhdGUSIAoLZGVzY3JpcHRpb24YAiABKAlSC2Rlc2NyaXB0aW9uEiwKEmV4cGVuc2Vf'
    'YWNjb3VudF9pZBgDIAEoCVIQZXhwZW5zZUFjY291bnRJZBIoChBhc3NldF9hY2NvdW50X2lkGA'
    'QgASgJUg5hc3NldEFjY291bnRJZBIhCgxhbW91bnRfY2VudHMYBSABKANSC2Ftb3VudENlbnRz'
    'EhIKBG5vdGUYBiABKAlSBG5vdGUSKQoQdHJhbnNhY3Rpb25fdGltZRgHIAEoCVIPdHJhbnNhY3'
    'Rpb25UaW1l');

@$core.Deprecated('Use simpleTransferRequestDescriptor instead')
const SimpleTransferRequest$json = {
  '1': 'SimpleTransferRequest',
  '2': [
    {'1': 'transaction_date', '3': 1, '4': 1, '5': 9, '10': 'transactionDate'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'from_account_id', '3': 3, '4': 1, '5': 9, '10': 'fromAccountId'},
    {'1': 'to_account_id', '3': 4, '4': 1, '5': 9, '10': 'toAccountId'},
    {'1': 'amount_cents', '3': 5, '4': 1, '5': 3, '10': 'amountCents'},
    {'1': 'note', '3': 6, '4': 1, '5': 9, '10': 'note'},
    {'1': 'transaction_time', '3': 7, '4': 1, '5': 9, '10': 'transactionTime'},
  ],
};

/// Descriptor for `SimpleTransferRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List simpleTransferRequestDescriptor = $convert.base64Decode(
    'ChVTaW1wbGVUcmFuc2ZlclJlcXVlc3QSKQoQdHJhbnNhY3Rpb25fZGF0ZRgBIAEoCVIPdHJhbn'
    'NhY3Rpb25EYXRlEiAKC2Rlc2NyaXB0aW9uGAIgASgJUgtkZXNjcmlwdGlvbhImCg9mcm9tX2Fj'
    'Y291bnRfaWQYAyABKAlSDWZyb21BY2NvdW50SWQSIgoNdG9fYWNjb3VudF9pZBgEIAEoCVILdG'
    '9BY2NvdW50SWQSIQoMYW1vdW50X2NlbnRzGAUgASgDUgthbW91bnRDZW50cxISCgRub3RlGAYg'
    'ASgJUgRub3RlEikKEHRyYW5zYWN0aW9uX3RpbWUYByABKAlSD3RyYW5zYWN0aW9uVGltZQ==');

@$core.Deprecated('Use transactionResponseDescriptor instead')
const TransactionResponse$json = {
  '1': 'TransactionResponse',
  '2': [
    {
      '1': 'transaction',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.transaction.v1.TransactionDTO',
      '10': 'transaction'
    },
  ],
};

/// Descriptor for `TransactionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transactionResponseDescriptor = $convert.base64Decode(
    'ChNUcmFuc2FjdGlvblJlc3BvbnNlEkYKC3RyYW5zYWN0aW9uGAEgASgLMiQueXVjYWkudHJhbn'
    'NhY3Rpb24udjEuVHJhbnNhY3Rpb25EVE9SC3RyYW5zYWN0aW9u');

@$core.Deprecated('Use transactionSummaryRequestDescriptor instead')
const TransactionSummaryRequest$json = {
  '1': 'TransactionSummaryRequest',
  '2': [
    {'1': 'year', '3': 1, '4': 1, '5': 5, '10': 'year'},
    {'1': 'month', '3': 2, '4': 1, '5': 5, '10': 'month'},
    {'1': 'account_id', '3': 3, '4': 1, '5': 9, '10': 'accountId'},
    {
      '1': 'scope',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.yucai.transaction.v1.Scope',
      '10': 'scope'
    },
    {'1': 'day', '3': 5, '4': 1, '5': 5, '10': 'day'},
  ],
};

/// Descriptor for `TransactionSummaryRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transactionSummaryRequestDescriptor = $convert.base64Decode(
    'ChlUcmFuc2FjdGlvblN1bW1hcnlSZXF1ZXN0EhIKBHllYXIYASABKAVSBHllYXISFAoFbW9udG'
    'gYAiABKAVSBW1vbnRoEh0KCmFjY291bnRfaWQYAyABKAlSCWFjY291bnRJZBIxCgVzY29wZRgE'
    'IAEoDjIbLnl1Y2FpLnRyYW5zYWN0aW9uLnYxLlNjb3BlUgVzY29wZRIQCgNkYXkYBSABKAVSA2'
    'RheQ==');

@$core.Deprecated('Use transactionSummaryResponseDescriptor instead')
const TransactionSummaryResponse$json = {
  '1': 'TransactionSummaryResponse',
  '2': [
    {
      '1': 'summary',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.transaction.v1.MonthlySummary',
      '10': 'summary'
    },
  ],
};

/// Descriptor for `TransactionSummaryResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List transactionSummaryResponseDescriptor =
    $convert.base64Decode(
        'ChpUcmFuc2FjdGlvblN1bW1hcnlSZXNwb25zZRI+CgdzdW1tYXJ5GAEgASgLMiQueXVjYWkudH'
        'JhbnNhY3Rpb24udjEuTW9udGhseVN1bW1hcnlSB3N1bW1hcnk=');

@$core.Deprecated('Use monthlySummaryDescriptor instead')
const MonthlySummary$json = {
  '1': 'MonthlySummary',
  '2': [
    {'1': 'income_cents', '3': 1, '4': 1, '5': 3, '10': 'incomeCents'},
    {'1': 'expense_cents', '3': 2, '4': 1, '5': 3, '10': 'expenseCents'},
    {'1': 'net_cents', '3': 3, '4': 1, '5': 3, '10': 'netCents'},
    {'1': 'daily_avg_cents', '3': 4, '4': 1, '5': 3, '10': 'dailyAvgCents'},
    {
      '1': 'by_day',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.yucai.transaction.v1.DailyItem',
      '10': 'byDay'
    },
  ],
};

/// Descriptor for `MonthlySummary`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List monthlySummaryDescriptor = $convert.base64Decode(
    'Cg5Nb250aGx5U3VtbWFyeRIhCgxpbmNvbWVfY2VudHMYASABKANSC2luY29tZUNlbnRzEiMKDW'
    'V4cGVuc2VfY2VudHMYAiABKANSDGV4cGVuc2VDZW50cxIbCgluZXRfY2VudHMYAyABKANSCG5l'
    'dENlbnRzEiYKD2RhaWx5X2F2Z19jZW50cxgEIAEoA1INZGFpbHlBdmdDZW50cxI2CgZieV9kYX'
    'kYBSADKAsyHy55dWNhaS50cmFuc2FjdGlvbi52MS5EYWlseUl0ZW1SBWJ5RGF5');

@$core.Deprecated('Use dailyItemDescriptor instead')
const DailyItem$json = {
  '1': 'DailyItem',
  '2': [
    {'1': 'date', '3': 1, '4': 1, '5': 9, '10': 'date'},
    {'1': 'total_income', '3': 2, '4': 1, '5': 3, '10': 'totalIncome'},
    {
      '1': 'by_category',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.yucai.transaction.v1.CategoryItem',
      '10': 'byCategory'
    },
  ],
};

/// Descriptor for `DailyItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dailyItemDescriptor = $convert.base64Decode(
    'CglEYWlseUl0ZW0SEgoEZGF0ZRgBIAEoCVIEZGF0ZRIhCgx0b3RhbF9pbmNvbWUYAiABKANSC3'
    'RvdGFsSW5jb21lEkMKC2J5X2NhdGVnb3J5GAMgAygLMiIueXVjYWkudHJhbnNhY3Rpb24udjEu'
    'Q2F0ZWdvcnlJdGVtUgpieUNhdGVnb3J5');

@$core.Deprecated('Use categoryItemDescriptor instead')
const CategoryItem$json = {
  '1': 'CategoryItem',
  '2': [
    {'1': 'account_id', '3': 1, '4': 1, '5': 9, '10': 'accountId'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'account_type', '3': 3, '4': 1, '5': 9, '10': 'accountType'},
    {'1': 'amount', '3': 4, '4': 1, '5': 3, '10': 'amount'},
  ],
};

/// Descriptor for `CategoryItem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List categoryItemDescriptor = $convert.base64Decode(
    'CgxDYXRlZ29yeUl0ZW0SHQoKYWNjb3VudF9pZBgBIAEoCVIJYWNjb3VudElkEhIKBG5hbWUYAi'
    'ABKAlSBG5hbWUSIQoMYWNjb3VudF90eXBlGAMgASgJUgthY2NvdW50VHlwZRIWCgZhbW91bnQY'
    'BCABKANSBmFtb3VudA==');

const $core.Map<$core.String, $core.dynamic> TransactionServiceBase$json = {
  '1': 'TransactionService',
  '2': [
    {
      '1': 'RecordTransaction',
      '2': '.yucai.transaction.v1.RecordTransactionRequest',
      '3': '.yucai.transaction.v1.TransactionResponse'
    },
    {
      '1': 'GetTransaction',
      '2': '.yucai.transaction.v1.GetTransactionRequest',
      '3': '.yucai.transaction.v1.TransactionResponse'
    },
    {
      '1': 'ListTransactions',
      '2': '.yucai.transaction.v1.ListTransactionsRequest',
      '3': '.yucai.transaction.v1.ListTransactionsResponse'
    },
    {
      '1': 'UpdateTransaction',
      '2': '.yucai.transaction.v1.UpdateTransactionRequest',
      '3': '.yucai.transaction.v1.TransactionResponse'
    },
    {
      '1': 'DeleteTransaction',
      '2': '.yucai.transaction.v1.DeleteTransactionRequest',
      '3': '.google.protobuf.Empty'
    },
    {
      '1': 'SimpleIncome',
      '2': '.yucai.transaction.v1.SimpleIncomeRequest',
      '3': '.yucai.transaction.v1.TransactionResponse'
    },
    {
      '1': 'SimpleExpense',
      '2': '.yucai.transaction.v1.SimpleExpenseRequest',
      '3': '.yucai.transaction.v1.TransactionResponse'
    },
    {
      '1': 'SimpleTransfer',
      '2': '.yucai.transaction.v1.SimpleTransferRequest',
      '3': '.yucai.transaction.v1.TransactionResponse'
    },
    {
      '1': 'TransactionSummary',
      '2': '.yucai.transaction.v1.TransactionSummaryRequest',
      '3': '.yucai.transaction.v1.TransactionSummaryResponse'
    },
  ],
};

@$core.Deprecated('Use transactionServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    TransactionServiceBase$messageJson = {
  '.yucai.transaction.v1.RecordTransactionRequest':
      RecordTransactionRequest$json,
  '.yucai.transaction.v1.EntryDTO': EntryDTO$json,
  '.yucai.transaction.v1.TransactionResponse': TransactionResponse$json,
  '.yucai.transaction.v1.TransactionDTO': TransactionDTO$json,
  '.google.protobuf.Timestamp': $0.Timestamp$json,
  '.yucai.transaction.v1.GetTransactionRequest': GetTransactionRequest$json,
  '.yucai.transaction.v1.ListTransactionsRequest': ListTransactionsRequest$json,
  '.yucai.common.v1.PageRequest': $1.PageRequest$json,
  '.yucai.transaction.v1.ListTransactionsResponse':
      ListTransactionsResponse$json,
  '.yucai.common.v1.PageResponse': $1.PageResponse$json,
  '.yucai.transaction.v1.UpdateTransactionRequest':
      UpdateTransactionRequest$json,
  '.yucai.transaction.v1.DeleteTransactionRequest':
      DeleteTransactionRequest$json,
  '.google.protobuf.Empty': $2.Empty$json,
  '.yucai.transaction.v1.SimpleIncomeRequest': SimpleIncomeRequest$json,
  '.yucai.transaction.v1.SimpleExpenseRequest': SimpleExpenseRequest$json,
  '.yucai.transaction.v1.SimpleTransferRequest': SimpleTransferRequest$json,
  '.yucai.transaction.v1.TransactionSummaryRequest':
      TransactionSummaryRequest$json,
  '.yucai.transaction.v1.TransactionSummaryResponse':
      TransactionSummaryResponse$json,
  '.yucai.transaction.v1.MonthlySummary': MonthlySummary$json,
  '.yucai.transaction.v1.DailyItem': DailyItem$json,
  '.yucai.transaction.v1.CategoryItem': CategoryItem$json,
};

/// Descriptor for `TransactionService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List transactionServiceDescriptor = $convert.base64Decode(
    'ChJUcmFuc2FjdGlvblNlcnZpY2USbgoRUmVjb3JkVHJhbnNhY3Rpb24SLi55dWNhaS50cmFuc2'
    'FjdGlvbi52MS5SZWNvcmRUcmFuc2FjdGlvblJlcXVlc3QaKS55dWNhaS50cmFuc2FjdGlvbi52'
    'MS5UcmFuc2FjdGlvblJlc3BvbnNlEmgKDkdldFRyYW5zYWN0aW9uEisueXVjYWkudHJhbnNhY3'
    'Rpb24udjEuR2V0VHJhbnNhY3Rpb25SZXF1ZXN0GikueXVjYWkudHJhbnNhY3Rpb24udjEuVHJh'
    'bnNhY3Rpb25SZXNwb25zZRJxChBMaXN0VHJhbnNhY3Rpb25zEi0ueXVjYWkudHJhbnNhY3Rpb2'
    '4udjEuTGlzdFRyYW5zYWN0aW9uc1JlcXVlc3QaLi55dWNhaS50cmFuc2FjdGlvbi52MS5MaXN0'
    'VHJhbnNhY3Rpb25zUmVzcG9uc2USbgoRVXBkYXRlVHJhbnNhY3Rpb24SLi55dWNhaS50cmFuc2'
    'FjdGlvbi52MS5VcGRhdGVUcmFuc2FjdGlvblJlcXVlc3QaKS55dWNhaS50cmFuc2FjdGlvbi52'
    'MS5UcmFuc2FjdGlvblJlc3BvbnNlElsKEURlbGV0ZVRyYW5zYWN0aW9uEi4ueXVjYWkudHJhbn'
    'NhY3Rpb24udjEuRGVsZXRlVHJhbnNhY3Rpb25SZXF1ZXN0GhYuZ29vZ2xlLnByb3RvYnVmLkVt'
    'cHR5EmQKDFNpbXBsZUluY29tZRIpLnl1Y2FpLnRyYW5zYWN0aW9uLnYxLlNpbXBsZUluY29tZV'
    'JlcXVlc3QaKS55dWNhaS50cmFuc2FjdGlvbi52MS5UcmFuc2FjdGlvblJlc3BvbnNlEmYKDVNp'
    'bXBsZUV4cGVuc2USKi55dWNhaS50cmFuc2FjdGlvbi52MS5TaW1wbGVFeHBlbnNlUmVxdWVzdB'
    'opLnl1Y2FpLnRyYW5zYWN0aW9uLnYxLlRyYW5zYWN0aW9uUmVzcG9uc2USaAoOU2ltcGxlVHJh'
    'bnNmZXISKy55dWNhaS50cmFuc2FjdGlvbi52MS5TaW1wbGVUcmFuc2ZlclJlcXVlc3QaKS55dW'
    'NhaS50cmFuc2FjdGlvbi52MS5UcmFuc2FjdGlvblJlc3BvbnNlEncKElRyYW5zYWN0aW9uU3Vt'
    'bWFyeRIvLnl1Y2FpLnRyYW5zYWN0aW9uLnYxLlRyYW5zYWN0aW9uU3VtbWFyeVJlcXVlc3QaMC'
    '55dWNhaS50cmFuc2FjdGlvbi52MS5UcmFuc2FjdGlvblN1bW1hcnlSZXNwb25zZQ==');
