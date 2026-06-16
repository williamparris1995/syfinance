// This is a generated file - do not edit.
//
// Generated from common/v1/error.proto.

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

@$core.Deprecated('Use errorDetailDescriptor instead')
const ErrorDetail$json = {
  '1': 'ErrorDetail',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 9, '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {
      '1': 'metadata',
      '3': 3,
      '4': 3,
      '5': 11,
      '6': '.yucai.common.v1.ErrorDetail.MetadataEntry',
      '10': 'metadata'
    },
  ],
  '3': [ErrorDetail_MetadataEntry$json],
};

@$core.Deprecated('Use errorDetailDescriptor instead')
const ErrorDetail_MetadataEntry$json = {
  '1': 'MetadataEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 9, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 9, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ErrorDetail`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List errorDetailDescriptor = $convert.base64Decode(
    'CgtFcnJvckRldGFpbBISCgRjb2RlGAEgASgJUgRjb2RlEhgKB21lc3NhZ2UYAiABKAlSB21lc3'
    'NhZ2USRgoIbWV0YWRhdGEYAyADKAsyKi55dWNhaS5jb21tb24udjEuRXJyb3JEZXRhaWwuTWV0'
    'YWRhdGFFbnRyeVIIbWV0YWRhdGEaOwoNTWV0YWRhdGFFbnRyeRIQCgNrZXkYASABKAlSA2tleR'
    'IUCgV2YWx1ZRgCIAEoCVIFdmFsdWU6AjgB');

@$core.Deprecated('Use syncPayloadDescriptor instead')
const SyncPayload$json = {
  '1': 'SyncPayload',
  '2': [
    {'1': 'entity_type', '3': 1, '4': 1, '5': 9, '10': 'entityType'},
    {'1': 'operation', '3': 2, '4': 1, '5': 9, '10': 'operation'},
    {'1': 'payload', '3': 3, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'version', '3': 4, '4': 1, '5': 3, '10': 'version'},
    {'1': 'device_id', '3': 5, '4': 1, '5': 9, '10': 'deviceId'},
  ],
};

/// Descriptor for `SyncPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncPayloadDescriptor = $convert.base64Decode(
    'CgtTeW5jUGF5bG9hZBIfCgtlbnRpdHlfdHlwZRgBIAEoCVIKZW50aXR5VHlwZRIcCglvcGVyYX'
    'Rpb24YAiABKAlSCW9wZXJhdGlvbhIYCgdwYXlsb2FkGAMgASgMUgdwYXlsb2FkEhgKB3ZlcnNp'
    'b24YBCABKANSB3ZlcnNpb24SGwoJZGV2aWNlX2lkGAUgASgJUghkZXZpY2VJZA==');
