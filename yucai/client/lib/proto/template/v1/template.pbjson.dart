// This is a generated file - do not edit.
//
// Generated from template/v1/template.proto.

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

@$core.Deprecated('Use templateDirectionDescriptor instead')
const TemplateDirection$json = {
  '1': 'TemplateDirection',
  '2': [
    {'1': 'DIRECTION_UNSPECIFIED', '2': 0},
    {'1': 'DIRECTION_EXPENSE', '2': 1},
    {'1': 'DIRECTION_INCOME', '2': 2},
    {'1': 'DIRECTION_TRANSFER', '2': 3},
  ],
};

/// Descriptor for `TemplateDirection`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List templateDirectionDescriptor = $convert.base64Decode(
    'ChFUZW1wbGF0ZURpcmVjdGlvbhIZChVESVJFQ1RJT05fVU5TUEVDSUZJRUQQABIVChFESVJFQ1'
    'RJT05fRVhQRU5TRRABEhQKEERJUkVDVElPTl9JTkNPTUUQAhIWChJESVJFQ1RJT05fVFJBTlNG'
    'RVIQAw==');

@$core.Deprecated('Use templateCycleDescriptor instead')
const TemplateCycle$json = {
  '1': 'TemplateCycle',
  '2': [
    {'1': 'CYCLE_UNSPECIFIED', '2': 0},
    {'1': 'CYCLE_WEEKLY', '2': 1},
    {'1': 'CYCLE_MONTHLY', '2': 2},
    {'1': 'CYCLE_YEARLY', '2': 3},
    {'1': 'CYCLE_CUSTOM', '2': 4},
  ],
};

/// Descriptor for `TemplateCycle`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List templateCycleDescriptor = $convert.base64Decode(
    'Cg1UZW1wbGF0ZUN5Y2xlEhUKEUNZQ0xFX1VOU1BFQ0lGSUVEEAASEAoMQ1lDTEVfV0VFS0xZEA'
    'ESEQoNQ1lDTEVfTU9OVEhMWRACEhAKDENZQ0xFX1lFQVJMWRADEhAKDENZQ0xFX0NVU1RPTRAE');

@$core.Deprecated('Use templateDTODescriptor instead')
const TemplateDTO$json = {
  '1': 'TemplateDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'amount_cents', '3': 4, '4': 1, '5': 3, '10': 'amountCents'},
    {
      '1': 'direction',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.yucai.template.v1.TemplateDirection',
      '10': 'direction'
    },
    {'1': 'source_account_id', '3': 6, '4': 1, '5': 9, '10': 'sourceAccountId'},
    {
      '1': 'destination_account_id',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'destinationAccountId'
    },
    {
      '1': 'cycle',
      '3': 8,
      '4': 1,
      '5': 14,
      '6': '.yucai.template.v1.TemplateCycle',
      '10': 'cycle'
    },
    {'1': 'cycle_days', '3': 9, '4': 1, '5': 5, '10': 'cycleDays'},
    {'1': 'billing_day', '3': 10, '4': 1, '5': 5, '10': 'billingDay'},
    {'1': 'next_date', '3': 11, '4': 1, '5': 9, '10': 'nextDate'},
    {'1': 'start_date', '3': 12, '4': 1, '5': 9, '10': 'startDate'},
    {'1': 'end_date', '3': 13, '4': 1, '5': 9, '10': 'endDate'},
    {'1': 'auto_record', '3': 14, '4': 1, '5': 8, '10': 'autoRecord'},
    {'1': 'paused', '3': 15, '4': 1, '5': 8, '10': 'paused'},
    {
      '1': 'last_transaction_id',
      '3': 16,
      '4': 1,
      '5': 9,
      '10': 'lastTransactionId'
    },
    {'1': 'category', '3': 17, '4': 1, '5': 9, '10': 'category'},
    {'1': 'version', '3': 18, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'created_at',
      '3': 19,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 20,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
  ],
};

/// Descriptor for `TemplateDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List templateDTODescriptor = $convert.base64Decode(
    'CgtUZW1wbGF0ZURUTxIOCgJpZBgBIAEoCVICaWQSEgoEbmFtZRgCIAEoCVIEbmFtZRIgCgtkZX'
    'NjcmlwdGlvbhgDIAEoCVILZGVzY3JpcHRpb24SIQoMYW1vdW50X2NlbnRzGAQgASgDUgthbW91'
    'bnRDZW50cxJCCglkaXJlY3Rpb24YBSABKA4yJC55dWNhaS50ZW1wbGF0ZS52MS5UZW1wbGF0ZU'
    'RpcmVjdGlvblIJZGlyZWN0aW9uEioKEXNvdXJjZV9hY2NvdW50X2lkGAYgASgJUg9zb3VyY2VB'
    'Y2NvdW50SWQSNAoWZGVzdGluYXRpb25fYWNjb3VudF9pZBgHIAEoCVIUZGVzdGluYXRpb25BY2'
    'NvdW50SWQSNgoFY3ljbGUYCCABKA4yIC55dWNhaS50ZW1wbGF0ZS52MS5UZW1wbGF0ZUN5Y2xl'
    'UgVjeWNsZRIdCgpjeWNsZV9kYXlzGAkgASgFUgljeWNsZURheXMSHwoLYmlsbGluZ19kYXkYCi'
    'ABKAVSCmJpbGxpbmdEYXkSGwoJbmV4dF9kYXRlGAsgASgJUghuZXh0RGF0ZRIdCgpzdGFydF9k'
    'YXRlGAwgASgJUglzdGFydERhdGUSGQoIZW5kX2RhdGUYDSABKAlSB2VuZERhdGUSHwoLYXV0b1'
    '9yZWNvcmQYDiABKAhSCmF1dG9SZWNvcmQSFgoGcGF1c2VkGA8gASgIUgZwYXVzZWQSLgoTbGFz'
    'dF90cmFuc2FjdGlvbl9pZBgQIAEoCVIRbGFzdFRyYW5zYWN0aW9uSWQSGgoIY2F0ZWdvcnkYES'
    'ABKAlSCGNhdGVnb3J5EhgKB3ZlcnNpb24YEiABKANSB3ZlcnNpb24SOQoKY3JlYXRlZF9hdBgT'
    'IAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCWNyZWF0ZWRBdBI5Cgp1cGRhdGVkX2'
    'F0GBQgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJdXBkYXRlZEF0');

@$core.Deprecated('Use createTemplateRequestDescriptor instead')
const CreateTemplateRequest$json = {
  '1': 'CreateTemplateRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 2, '4': 1, '5': 9, '10': 'description'},
    {'1': 'amount_cents', '3': 3, '4': 1, '5': 3, '10': 'amountCents'},
    {
      '1': 'direction',
      '3': 4,
      '4': 1,
      '5': 14,
      '6': '.yucai.template.v1.TemplateDirection',
      '10': 'direction'
    },
    {'1': 'source_account_id', '3': 5, '4': 1, '5': 9, '10': 'sourceAccountId'},
    {
      '1': 'destination_account_id',
      '3': 6,
      '4': 1,
      '5': 9,
      '10': 'destinationAccountId'
    },
    {
      '1': 'cycle',
      '3': 7,
      '4': 1,
      '5': 14,
      '6': '.yucai.template.v1.TemplateCycle',
      '10': 'cycle'
    },
    {'1': 'cycle_days', '3': 8, '4': 1, '5': 5, '10': 'cycleDays'},
    {'1': 'billing_day', '3': 9, '4': 1, '5': 5, '10': 'billingDay'},
    {'1': 'start_date', '3': 10, '4': 1, '5': 9, '10': 'startDate'},
    {'1': 'end_date', '3': 11, '4': 1, '5': 9, '10': 'endDate'},
    {'1': 'auto_record', '3': 12, '4': 1, '5': 8, '10': 'autoRecord'},
    {'1': 'category', '3': 13, '4': 1, '5': 9, '10': 'category'},
  ],
};

/// Descriptor for `CreateTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTemplateRequestDescriptor = $convert.base64Decode(
    'ChVDcmVhdGVUZW1wbGF0ZVJlcXVlc3QSEgoEbmFtZRgBIAEoCVIEbmFtZRIgCgtkZXNjcmlwdG'
    'lvbhgCIAEoCVILZGVzY3JpcHRpb24SIQoMYW1vdW50X2NlbnRzGAMgASgDUgthbW91bnRDZW50'
    'cxJCCglkaXJlY3Rpb24YBCABKA4yJC55dWNhaS50ZW1wbGF0ZS52MS5UZW1wbGF0ZURpcmVjdG'
    'lvblIJZGlyZWN0aW9uEioKEXNvdXJjZV9hY2NvdW50X2lkGAUgASgJUg9zb3VyY2VBY2NvdW50'
    'SWQSNAoWZGVzdGluYXRpb25fYWNjb3VudF9pZBgGIAEoCVIUZGVzdGluYXRpb25BY2NvdW50SW'
    'QSNgoFY3ljbGUYByABKA4yIC55dWNhaS50ZW1wbGF0ZS52MS5UZW1wbGF0ZUN5Y2xlUgVjeWNs'
    'ZRIdCgpjeWNsZV9kYXlzGAggASgFUgljeWNsZURheXMSHwoLYmlsbGluZ19kYXkYCSABKAVSCm'
    'JpbGxpbmdEYXkSHQoKc3RhcnRfZGF0ZRgKIAEoCVIJc3RhcnREYXRlEhkKCGVuZF9kYXRlGAsg'
    'ASgJUgdlbmREYXRlEh8KC2F1dG9fcmVjb3JkGAwgASgIUgphdXRvUmVjb3JkEhoKCGNhdGVnb3'
    'J5GA0gASgJUghjYXRlZ29yeQ==');

@$core.Deprecated('Use updateTemplateRequestDescriptor instead')
const UpdateTemplateRequest$json = {
  '1': 'UpdateTemplateRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 1, '5': 9, '10': 'description'},
    {'1': 'amount_cents', '3': 4, '4': 1, '5': 3, '10': 'amountCents'},
    {
      '1': 'cycle',
      '3': 5,
      '4': 1,
      '5': 14,
      '6': '.yucai.template.v1.TemplateCycle',
      '10': 'cycle'
    },
    {'1': 'cycle_days', '3': 6, '4': 1, '5': 5, '10': 'cycleDays'},
    {'1': 'end_date', '3': 7, '4': 1, '5': 9, '10': 'endDate'},
    {'1': 'auto_record', '3': 8, '4': 1, '5': 8, '10': 'autoRecord'},
    {'1': 'version', '3': 9, '4': 1, '5': 3, '10': 'version'},
  ],
};

/// Descriptor for `UpdateTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTemplateRequestDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVUZW1wbGF0ZVJlcXVlc3QSDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG'
    '5hbWUSIAoLZGVzY3JpcHRpb24YAyABKAlSC2Rlc2NyaXB0aW9uEiEKDGFtb3VudF9jZW50cxgE'
    'IAEoA1ILYW1vdW50Q2VudHMSNgoFY3ljbGUYBSABKA4yIC55dWNhaS50ZW1wbGF0ZS52MS5UZW'
    '1wbGF0ZUN5Y2xlUgVjeWNsZRIdCgpjeWNsZV9kYXlzGAYgASgFUgljeWNsZURheXMSGQoIZW5k'
    'X2RhdGUYByABKAlSB2VuZERhdGUSHwoLYXV0b19yZWNvcmQYCCABKAhSCmF1dG9SZWNvcmQSGA'
    'oHdmVyc2lvbhgJIAEoA1IHdmVyc2lvbg==');

@$core.Deprecated('Use deleteTemplateRequestDescriptor instead')
const DeleteTemplateRequest$json = {
  '1': 'DeleteTemplateRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTemplateRequestDescriptor = $convert
    .base64Decode('ChVEZWxldGVUZW1wbGF0ZVJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use pauseTemplateRequestDescriptor instead')
const PauseTemplateRequest$json = {
  '1': 'PauseTemplateRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `PauseTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pauseTemplateRequestDescriptor = $convert
    .base64Decode('ChRQYXVzZVRlbXBsYXRlUmVxdWVzdBIOCgJpZBgBIAEoCVICaWQ=');

@$core.Deprecated('Use resumeTemplateRequestDescriptor instead')
const ResumeTemplateRequest$json = {
  '1': 'ResumeTemplateRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `ResumeTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resumeTemplateRequestDescriptor = $convert
    .base64Decode('ChVSZXN1bWVUZW1wbGF0ZVJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use getTemplateRequestDescriptor instead')
const GetTemplateRequest$json = {
  '1': 'GetTemplateRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `GetTemplateRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTemplateRequestDescriptor =
    $convert.base64Decode('ChJHZXRUZW1wbGF0ZVJlcXVlc3QSDgoCaWQYASABKAlSAmlk');

@$core.Deprecated('Use listTemplatesRequestDescriptor instead')
const ListTemplatesRequest$json = {
  '1': 'ListTemplatesRequest',
  '2': [
    {
      '1': 'page',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageRequest',
      '10': 'page'
    },
    {'1': 'paused', '3': 2, '4': 1, '5': 8, '10': 'paused'},
  ],
};

/// Descriptor for `ListTemplatesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTemplatesRequestDescriptor = $convert.base64Decode(
    'ChRMaXN0VGVtcGxhdGVzUmVxdWVzdBIwCgRwYWdlGAEgASgLMhwueXVjYWkuY29tbW9uLnYxLl'
    'BhZ2VSZXF1ZXN0UgRwYWdlEhYKBnBhdXNlZBgCIAEoCFIGcGF1c2Vk');

@$core.Deprecated('Use listTemplatesResponseDescriptor instead')
const ListTemplatesResponse$json = {
  '1': 'ListTemplatesResponse',
  '2': [
    {
      '1': 'templates',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.template.v1.TemplateDTO',
      '10': 'templates'
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

/// Descriptor for `ListTemplatesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTemplatesResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0VGVtcGxhdGVzUmVzcG9uc2USPAoJdGVtcGxhdGVzGAEgAygLMh4ueXVjYWkudGVtcG'
    'xhdGUudjEuVGVtcGxhdGVEVE9SCXRlbXBsYXRlcxIxCgRwYWdlGAIgASgLMh0ueXVjYWkuY29t'
    'bW9uLnYxLlBhZ2VSZXNwb25zZVIEcGFnZQ==');

@$core.Deprecated('Use templateResponseDescriptor instead')
const TemplateResponse$json = {
  '1': 'TemplateResponse',
  '2': [
    {
      '1': 'template',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.template.v1.TemplateDTO',
      '10': 'template'
    },
  ],
};

/// Descriptor for `TemplateResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List templateResponseDescriptor = $convert.base64Decode(
    'ChBUZW1wbGF0ZVJlc3BvbnNlEjoKCHRlbXBsYXRlGAEgASgLMh4ueXVjYWkudGVtcGxhdGUudj'
    'EuVGVtcGxhdGVEVE9SCHRlbXBsYXRl');
