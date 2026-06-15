// This is a generated file - do not edit.
//
// Generated from account/v1/account.proto.

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

@$core.Deprecated('Use accountTypeDescriptor instead')
const AccountType$json = {
  '1': 'AccountType',
  '2': [
    {'1': 'ACCOUNT_TYPE_UNSPECIFIED', '2': 0},
    {'1': 'ACCOUNT_TYPE_ASSET', '2': 1},
    {'1': 'ACCOUNT_TYPE_LIABILITY', '2': 2},
    {'1': 'ACCOUNT_TYPE_EQUITY', '2': 3},
    {'1': 'ACCOUNT_TYPE_INCOME', '2': 4},
    {'1': 'ACCOUNT_TYPE_EXPENSE', '2': 5},
  ],
};

/// Descriptor for `AccountType`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List accountTypeDescriptor = $convert.base64Decode(
    'CgtBY2NvdW50VHlwZRIcChhBQ0NPVU5UX1RZUEVfVU5TUEVDSUZJRUQQABIWChJBQ0NPVU5UX1'
    'RZUEVfQVNTRVQQARIaChZBQ0NPVU5UX1RZUEVfTElBQklMSVRZEAISFwoTQUNDT1VOVF9UWVBF'
    'X0VRVUlUWRADEhcKE0FDQ09VTlRfVFlQRV9JTkNPTUUQBBIYChRBQ0NPVU5UX1RZUEVfRVhQRU'
    '5TRRAF');

@$core.Deprecated('Use ownershipDescriptor instead')
const Ownership$json = {
  '1': 'Ownership',
  '2': [
    {'1': 'OWNERSHIP_UNSPECIFIED', '2': 0},
    {'1': 'OWNERSHIP_PERSONAL', '2': 1},
    {'1': 'OWNERSHIP_JOINT', '2': 2},
  ],
};

/// Descriptor for `Ownership`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List ownershipDescriptor = $convert.base64Decode(
    'CglPd25lcnNoaXASGQoVT1dORVJTSElQX1VOU1BFQ0lGSUVEEAASFgoST1dORVJTSElQX1BFUl'
    'NPTkFMEAESEwoPT1dORVJTSElQX0pPSU5UEAI=');

@$core.Deprecated('Use accountStatusDescriptor instead')
const AccountStatus$json = {
  '1': 'AccountStatus',
  '2': [
    {'1': 'ACCOUNT_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'ACCOUNT_STATUS_ACTIVE', '2': 1},
    {'1': 'ACCOUNT_STATUS_ARCHIVED', '2': 2},
  ],
};

/// Descriptor for `AccountStatus`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List accountStatusDescriptor = $convert.base64Decode(
    'Cg1BY2NvdW50U3RhdHVzEh4KGkFDQ09VTlRfU1RBVFVTX1VOU1BFQ0lGSUVEEAASGQoVQUNDT1'
    'VOVF9TVEFUVVNfQUNUSVZFEAESGwoXQUNDT1VOVF9TVEFUVVNfQVJDSElWRUQQAg==');

@$core.Deprecated('Use accountCategoryDescriptor instead')
const AccountCategory$json = {
  '1': 'AccountCategory',
  '2': [
    {'1': 'ACCOUNT_CATEGORY_UNSPECIFIED', '2': 0},
    {'1': 'ACCOUNT_CATEGORY_SAVINGS', '2': 1},
    {'1': 'ACCOUNT_CATEGORY_CREDIT_CARD', '2': 2},
    {'1': 'ACCOUNT_CATEGORY_INVESTMENT', '2': 3},
    {'1': 'ACCOUNT_CATEGORY_FIXED_DEPOSIT', '2': 4},
    {'1': 'ACCOUNT_CATEGORY_GOLD_FX', '2': 5},
    {'1': 'ACCOUNT_CATEGORY_REAL_ESTATE', '2': 6},
    {'1': 'ACCOUNT_CATEGORY_LOAN', '2': 7},
    {'1': 'ACCOUNT_CATEGORY_OTHER_ASSET', '2': 8},
    {'1': 'ACCOUNT_CATEGORY_OTHER_LIABILITY', '2': 9},
  ],
};

/// Descriptor for `AccountCategory`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List accountCategoryDescriptor = $convert.base64Decode(
    'Cg9BY2NvdW50Q2F0ZWdvcnkSIAocQUNDT1VOVF9DQVRFR09SWV9VTlNQRUNJRklFRBAAEhwKGE'
    'FDQ09VTlRfQ0FURUdPUllfU0FWSU5HUxABEiAKHEFDQ09VTlRfQ0FURUdPUllfQ1JFRElUX0NB'
    'UkQQAhIfChtBQ0NPVU5UX0NBVEVHT1JZX0lOVkVTVE1FTlQQAxIiCh5BQ0NPVU5UX0NBVEVHT1'
    'JZX0ZJWEVEX0RFUE9TSVQQBBIcChhBQ0NPVU5UX0NBVEVHT1JZX0dPTERfRlgQBRIgChxBQ0NP'
    'VU5UX0NBVEVHT1JZX1JFQUxfRVNUQVRFEAYSGQoVQUNDT1VOVF9DQVRFR09SWV9MT0FOEAcSIA'
    'ocQUNDT1VOVF9DQVRFR09SWV9PVEhFUl9BU1NFVBAIEiQKIEFDQ09VTlRfQ0FURUdPUllfT1RI'
    'RVJfTElBQklMSVRZEAk=');

@$core.Deprecated('Use accountDTODescriptor instead')
const AccountDTO$json = {
  '1': 'AccountDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'account_type',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountType',
      '10': 'accountType'
    },
    {'1': 'currency_code', '3': 4, '4': 1, '5': 9, '10': 'currencyCode'},
    {
      '1': 'initial_balance_cents',
      '3': 5,
      '4': 1,
      '5': 3,
      '10': 'initialBalanceCents'
    },
    {
      '1': 'current_balance_cents',
      '3': 6,
      '4': 1,
      '5': 3,
      '10': 'currentBalanceCents'
    },
    {
      '1': 'ownership',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.Ownership',
      '10': 'ownership'
    },
    {'1': 'icon', '3': 8, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'color', '3': 9, '4': 1, '5': 9, '10': 'color'},
    {'1': 'chart_code', '3': 10, '4': 1, '5': 9, '10': 'chartCode'},
    {'1': 'parent_id', '3': 11, '4': 1, '5': 9, '10': 'parentId'},
    {'1': 'institution', '3': 12, '4': 1, '5': 9, '10': 'institution'},
    {
      '1': 'credit_limit_cents',
      '3': 13,
      '4': 1,
      '5': 3,
      '10': 'creditLimitCents'
    },
    {
      '1': 'status',
      '3': 14,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountStatus',
      '10': 'status'
    },
    {'1': 'version', '3': 15, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'created_at',
      '3': 16,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 17,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
    {
      '1': 'category',
      '3': 18,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountCategory',
      '10': 'category'
    },
  ],
};

/// Descriptor for `AccountDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accountDTODescriptor = $convert.base64Decode(
    'CgpBY2NvdW50RFRPEg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEkAKDGFjY2'
    '91bnRfdHlwZRgDIAEoDjIdLnl1Y2FpLmFjY291bnQudjEuQWNjb3VudFR5cGVSC2FjY291bnRU'
    'eXBlEiMKDWN1cnJlbmN5X2NvZGUYBCABKAlSDGN1cnJlbmN5Q29kZRIyChVpbml0aWFsX2JhbG'
    'FuY2VfY2VudHMYBSABKANSE2luaXRpYWxCYWxhbmNlQ2VudHMSMgoVY3VycmVudF9iYWxhbmNl'
    'X2NlbnRzGAYgASgDUhNjdXJyZW50QmFsYW5jZUNlbnRzEjkKCW93bmVyc2hpcBgHIAEoDjIbLn'
    'l1Y2FpLmFjY291bnQudjEuT3duZXJzaGlwUglvd25lcnNoaXASEgoEaWNvbhgIIAEoCVIEaWNv'
    'bhIUCgVjb2xvchgJIAEoCVIFY29sb3ISHQoKY2hhcnRfY29kZRgKIAEoCVIJY2hhcnRDb2RlEh'
    'sKCXBhcmVudF9pZBgLIAEoCVIIcGFyZW50SWQSIAoLaW5zdGl0dXRpb24YDCABKAlSC2luc3Rp'
    'dHV0aW9uEiwKEmNyZWRpdF9saW1pdF9jZW50cxgNIAEoA1IQY3JlZGl0TGltaXRDZW50cxI3Cg'
    'ZzdGF0dXMYDiABKA4yHy55dWNhaS5hY2NvdW50LnYxLkFjY291bnRTdGF0dXNSBnN0YXR1cxIY'
    'Cgd2ZXJzaW9uGA8gASgDUgd2ZXJzaW9uEjkKCmNyZWF0ZWRfYXQYECABKAsyGi5nb29nbGUucH'
    'JvdG9idWYuVGltZXN0YW1wUgljcmVhdGVkQXQSOQoKdXBkYXRlZF9hdBgRIAEoCzIaLmdvb2ds'
    'ZS5wcm90b2J1Zi5UaW1lc3RhbXBSCXVwZGF0ZWRBdBI9CghjYXRlZ29yeRgSIAEoDjIhLnl1Y2'
    'FpLmFjY291bnQudjEuQWNjb3VudENhdGVnb3J5UghjYXRlZ29yeQ==');

@$core.Deprecated('Use createAccountRequestDescriptor instead')
const CreateAccountRequest$json = {
  '1': 'CreateAccountRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {
      '1': 'account_type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountType',
      '10': 'accountType'
    },
    {'1': 'currency_code', '3': 3, '4': 1, '5': 9, '10': 'currencyCode'},
    {
      '1': 'initial_balance_cents',
      '3': 4,
      '4': 1,
      '5': 3,
      '10': 'initialBalanceCents'
    },
    {
      '1': 'ownership',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.Ownership',
      '10': 'ownership'
    },
    {'1': 'icon', '3': 6, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'color', '3': 7, '4': 1, '5': 9, '10': 'color'},
    {'1': 'chart_code', '3': 8, '4': 1, '5': 9, '10': 'chartCode'},
    {'1': 'parent_id', '3': 9, '4': 1, '5': 9, '10': 'parentId'},
    {'1': 'institution', '3': 10, '4': 1, '5': 9, '10': 'institution'},
    {
      '1': 'credit_limit_cents',
      '3': 11,
      '4': 1,
      '5': 3,
      '10': 'creditLimitCents'
    },
    {
      '1': 'category',
      '3': 12,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountCategory',
      '10': 'category'
    },
  ],
};

/// Descriptor for `CreateAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createAccountRequestDescriptor = $convert.base64Decode(
    'ChRDcmVhdGVBY2NvdW50UmVxdWVzdBISCgRuYW1lGAEgASgJUgRuYW1lEkAKDGFjY291bnRfdH'
    'lwZRgCIAEoDjIdLnl1Y2FpLmFjY291bnQudjEuQWNjb3VudFR5cGVSC2FjY291bnRUeXBlEiMK'
    'DWN1cnJlbmN5X2NvZGUYAyABKAlSDGN1cnJlbmN5Q29kZRIyChVpbml0aWFsX2JhbGFuY2VfY2'
    'VudHMYBCABKANSE2luaXRpYWxCYWxhbmNlQ2VudHMSOQoJb3duZXJzaGlwGAUgASgOMhsueXVj'
    'YWkuYWNjb3VudC52MS5Pd25lcnNoaXBSCW93bmVyc2hpcBISCgRpY29uGAYgASgJUgRpY29uEh'
    'QKBWNvbG9yGAcgASgJUgVjb2xvchIdCgpjaGFydF9jb2RlGAggASgJUgljaGFydENvZGUSGwoJ'
    'cGFyZW50X2lkGAkgASgJUghwYXJlbnRJZBIgCgtpbnN0aXR1dGlvbhgKIAEoCVILaW5zdGl0dX'
    'Rpb24SLAoSY3JlZGl0X2xpbWl0X2NlbnRzGAsgASgDUhBjcmVkaXRMaW1pdENlbnRzEj0KCGNh'
    'dGVnb3J5GAwgASgOMiEueXVjYWkuYWNjb3VudC52MS5BY2NvdW50Q2F0ZWdvcnlSCGNhdGVnb3'
    'J5');

@$core.Deprecated('Use getAccountRequestDescriptor instead')
const GetAccountRequest$json = {
  '1': 'GetAccountRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getAccountRequestDescriptor =
    $convert.base64Decode('ChFHZXRBY2NvdW50UmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use listAccountsRequestDescriptor instead')
const ListAccountsRequest$json = {
  '1': 'ListAccountsRequest',
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
      '1': 'account_type',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountType',
      '10': 'accountType'
    },
    {
      '1': 'status',
      '3': 3,
      '4': 1,
      '5': 14,
      '6': '.yucai.account.v1.AccountStatus',
      '10': 'status'
    },
  ],
};

/// Descriptor for `ListAccountsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAccountsRequestDescriptor = $convert.base64Decode(
    'ChNMaXN0QWNjb3VudHNSZXF1ZXN0EjAKBHBhZ2UYASABKAsyHC55dWNhaS5jb21tb24udjEuUG'
    'FnZVJlcXVlc3RSBHBhZ2USQAoMYWNjb3VudF90eXBlGAIgASgOMh0ueXVjYWkuYWNjb3VudC52'
    'MS5BY2NvdW50VHlwZVILYWNjb3VudFR5cGUSNwoGc3RhdHVzGAMgASgOMh8ueXVjYWkuYWNjb3'
    'VudC52MS5BY2NvdW50U3RhdHVzUgZzdGF0dXM=');

@$core.Deprecated('Use listAccountsResponseDescriptor instead')
const ListAccountsResponse$json = {
  '1': 'ListAccountsResponse',
  '2': [
    {
      '1': 'accounts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.account.v1.AccountDTO',
      '10': 'accounts'
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

/// Descriptor for `ListAccountsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listAccountsResponseDescriptor = $convert.base64Decode(
    'ChRMaXN0QWNjb3VudHNSZXNwb25zZRI4CghhY2NvdW50cxgBIAMoCzIcLnl1Y2FpLmFjY291bn'
    'QudjEuQWNjb3VudERUT1IIYWNjb3VudHMSMQoEcGFnZRgCIAEoCzIdLnl1Y2FpLmNvbW1vbi52'
    'MS5QYWdlUmVzcG9uc2VSBHBhZ2U=');

@$core.Deprecated('Use updateAccountRequestDescriptor instead')
const UpdateAccountRequest$json = {
  '1': 'UpdateAccountRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'icon', '3': 3, '4': 1, '5': 9, '10': 'icon'},
    {'1': 'color', '3': 4, '4': 1, '5': 9, '10': 'color'},
    {'1': 'chart_code', '3': 5, '4': 1, '5': 9, '10': 'chartCode'},
    {'1': 'institution', '3': 6, '4': 1, '5': 9, '10': 'institution'},
    {
      '1': 'credit_limit_cents',
      '3': 7,
      '4': 1,
      '5': 3,
      '10': 'creditLimitCents'
    },
    {'1': 'version', '3': 8, '4': 1, '5': 3, '10': 'version'},
  ],
};

/// Descriptor for `UpdateAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateAccountRequestDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVBY2NvdW50UmVxdWVzdBIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbm'
    'FtZRISCgRpY29uGAMgASgJUgRpY29uEhQKBWNvbG9yGAQgASgJUgVjb2xvchIdCgpjaGFydF9j'
    'b2RlGAUgASgJUgljaGFydENvZGUSIAoLaW5zdGl0dXRpb24YBiABKAlSC2luc3RpdHV0aW9uEi'
    'wKEmNyZWRpdF9saW1pdF9jZW50cxgHIAEoA1IQY3JlZGl0TGltaXRDZW50cxIYCgd2ZXJzaW9u'
    'GAggASgDUgd2ZXJzaW9u');

@$core.Deprecated('Use deleteAccountRequestDescriptor instead')
const DeleteAccountRequest$json = {
  '1': 'DeleteAccountRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteAccountRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteAccountRequestDescriptor = $convert
    .base64Decode('ChREZWxldGVBY2NvdW50UmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use accountResponseDescriptor instead')
const AccountResponse$json = {
  '1': 'AccountResponse',
  '2': [
    {
      '1': 'account',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.account.v1.AccountDTO',
      '10': 'account'
    },
  ],
};

/// Descriptor for `AccountResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List accountResponseDescriptor = $convert.base64Decode(
    'Cg9BY2NvdW50UmVzcG9uc2USNgoHYWNjb3VudBgBIAEoCzIcLnl1Y2FpLmFjY291bnQudjEuQW'
    'Njb3VudERUT1IHYWNjb3VudA==');
