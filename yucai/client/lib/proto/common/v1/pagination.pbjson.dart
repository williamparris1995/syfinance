// This is a generated file - do not edit.
//
// Generated from common/v1/pagination.proto.

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

@$core.Deprecated('Use pageRequestDescriptor instead')
const PageRequest$json = {
  '1': 'PageRequest',
  '2': [
    {'1': 'page_size', '3': 1, '4': 1, '5': 5, '10': 'pageSize'},
    {'1': 'page_token', '3': 2, '4': 1, '5': 9, '10': 'pageToken'},
  ],
};

/// Descriptor for `PageRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageRequestDescriptor = $convert.base64Decode(
    'CgtQYWdlUmVxdWVzdBIbCglwYWdlX3NpemUYASABKAVSCHBhZ2VTaXplEh0KCnBhZ2VfdG9rZW'
    '4YAiABKAlSCXBhZ2VUb2tlbg==');

@$core.Deprecated('Use pageResponseDescriptor instead')
const PageResponse$json = {
  '1': 'PageResponse',
  '2': [
    {'1': 'next_page_token', '3': 1, '4': 1, '5': 9, '10': 'nextPageToken'},
    {'1': 'total_count', '3': 2, '4': 1, '5': 5, '10': 'totalCount'},
  ],
};

/// Descriptor for `PageResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pageResponseDescriptor = $convert.base64Decode(
    'CgxQYWdlUmVzcG9uc2USJgoPbmV4dF9wYWdlX3Rva2VuGAEgASgJUg1uZXh0UGFnZVRva2VuEh'
    '8KC3RvdGFsX2NvdW50GAIgASgFUgp0b3RhbENvdW50');
