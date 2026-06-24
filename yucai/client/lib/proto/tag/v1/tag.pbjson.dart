// This is a generated file - do not edit.
//
// Generated from tag/v1/tag.proto.

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

@$core.Deprecated('Use tagDTODescriptor instead')
const TagDTO$json = {
  '1': 'TagDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'color', '3': 3, '4': 1, '5': 9, '10': 'color'},
    {'1': 'version', '3': 4, '4': 1, '5': 3, '10': 'version'},
    {
      '1': 'created_at',
      '3': 5,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
    {
      '1': 'updated_at',
      '3': 6,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'updatedAt'
    },
  ],
};

/// Descriptor for `TagDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tagDTODescriptor = $convert.base64Decode(
    'CgZUYWdEVE8SDgoCaWQYASABKAlSAmlkEhIKBG5hbWUYAiABKAlSBG5hbWUSFAoFY29sb3IYAy'
    'ABKAlSBWNvbG9yEhgKB3ZlcnNpb24YBCABKANSB3ZlcnNpb24SOQoKY3JlYXRlZF9hdBgFIAEo'
    'CzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCWNyZWF0ZWRBdBI5Cgp1cGRhdGVkX2F0GA'
    'YgASgLMhouZ29vZ2xlLnByb3RvYnVmLlRpbWVzdGFtcFIJdXBkYXRlZEF0');

@$core.Deprecated('Use createTagRequestDescriptor instead')
const CreateTagRequest$json = {
  '1': 'CreateTagRequest',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'color', '3': 2, '4': 1, '5': 9, '10': 'color'},
  ],
};

/// Descriptor for `CreateTagRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createTagRequestDescriptor = $convert.base64Decode(
    'ChBDcmVhdGVUYWdSZXF1ZXN0EhIKBG5hbWUYASABKAlSBG5hbWUSFAoFY29sb3IYAiABKAlSBW'
    'NvbG9y');

@$core.Deprecated('Use updateTagRequestDescriptor instead')
const UpdateTagRequest$json = {
  '1': 'UpdateTagRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 1, '5': 9, '10': 'name'},
    {'1': 'color', '3': 3, '4': 1, '5': 9, '10': 'color'},
    {'1': 'version', '3': 4, '4': 1, '5': 3, '10': 'version'},
  ],
};

/// Descriptor for `UpdateTagRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateTagRequestDescriptor = $convert.base64Decode(
    'ChBVcGRhdGVUYWdSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZBISCgRuYW1lGAIgASgJUgRuYW1lEh'
    'QKBWNvbG9yGAMgASgJUgVjb2xvchIYCgd2ZXJzaW9uGAQgASgDUgd2ZXJzaW9u');

@$core.Deprecated('Use deleteTagRequestDescriptor instead')
const DeleteTagRequest$json = {
  '1': 'DeleteTagRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteTagRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteTagRequestDescriptor =
    $convert.base64Decode('ChBEZWxldGVUYWdSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use listTagsRequestDescriptor instead')
const ListTagsRequest$json = {
  '1': 'ListTagsRequest',
  '2': [
    {
      '1': 'page',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.common.v1.PageRequest',
      '10': 'page'
    },
    {'1': 'search', '3': 2, '4': 1, '5': 9, '10': 'search'},
  ],
};

/// Descriptor for `ListTagsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTagsRequestDescriptor = $convert.base64Decode(
    'Cg9MaXN0VGFnc1JlcXVlc3QSMAoEcGFnZRgBIAEoCzIcLnl1Y2FpLmNvbW1vbi52MS5QYWdlUm'
    'VxdWVzdFIEcGFnZRIWCgZzZWFyY2gYAiABKAlSBnNlYXJjaA==');

@$core.Deprecated('Use listTagsResponseDescriptor instead')
const ListTagsResponse$json = {
  '1': 'ListTagsResponse',
  '2': [
    {
      '1': 'tags',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.tag.v1.TagDTO',
      '10': 'tags'
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

/// Descriptor for `ListTagsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listTagsResponseDescriptor = $convert.base64Decode(
    'ChBMaXN0VGFnc1Jlc3BvbnNlEigKBHRhZ3MYASADKAsyFC55dWNhaS50YWcudjEuVGFnRFRPUg'
    'R0YWdzEjEKBHBhZ2UYAiABKAsyHS55dWNhaS5jb21tb24udjEuUGFnZVJlc3BvbnNlUgRwYWdl');

@$core.Deprecated('Use tagTransactionRequestDescriptor instead')
const TagTransactionRequest$json = {
  '1': 'TagTransactionRequest',
  '2': [
    {'1': 'tag_id', '3': 1, '4': 1, '5': 9, '10': 'tagId'},
    {'1': 'transaction_id', '3': 2, '4': 1, '5': 9, '10': 'transactionId'},
  ],
};

/// Descriptor for `TagTransactionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tagTransactionRequestDescriptor = $convert.base64Decode(
    'ChVUYWdUcmFuc2FjdGlvblJlcXVlc3QSFQoGdGFnX2lkGAEgASgJUgV0YWdJZBIlCg50cmFuc2'
    'FjdGlvbl9pZBgCIAEoCVINdHJhbnNhY3Rpb25JZA==');

@$core.Deprecated('Use getTransactionTagsRequestDescriptor instead')
const GetTransactionTagsRequest$json = {
  '1': 'GetTransactionTagsRequest',
  '2': [
    {'1': 'transaction_id', '3': 1, '4': 1, '5': 9, '10': 'transactionId'},
  ],
};

/// Descriptor for `GetTransactionTagsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getTransactionTagsRequestDescriptor =
    $convert.base64Decode(
        'ChlHZXRUcmFuc2FjdGlvblRhZ3NSZXF1ZXN0EiUKDnRyYW5zYWN0aW9uX2lkGAEgASgJUg10cm'
        'Fuc2FjdGlvbklk');

@$core.Deprecated('Use tagResponseDescriptor instead')
const TagResponse$json = {
  '1': 'TagResponse',
  '2': [
    {
      '1': 'tag',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.tag.v1.TagDTO',
      '10': 'tag'
    },
  ],
};

/// Descriptor for `TagResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tagResponseDescriptor = $convert.base64Decode(
    'CgtUYWdSZXNwb25zZRImCgN0YWcYASABKAsyFC55dWNhaS50YWcudjEuVGFnRFRPUgN0YWc=');
