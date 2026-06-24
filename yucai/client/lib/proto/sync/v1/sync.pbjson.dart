// This is a generated file - do not edit.
//
// Generated from sync/v1/sync.proto.

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

@$core.Deprecated('Use syncOperationDescriptor instead')
const SyncOperation$json = {
  '1': 'SyncOperation',
  '2': [
    {'1': 'SYNC_OPERATION_UNSPECIFIED', '2': 0},
    {'1': 'SYNC_OPERATION_CREATE', '2': 1},
    {'1': 'SYNC_OPERATION_UPDATE', '2': 2},
    {'1': 'SYNC_OPERATION_DELETE', '2': 3},
  ],
};

/// Descriptor for `SyncOperation`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List syncOperationDescriptor = $convert.base64Decode(
    'Cg1TeW5jT3BlcmF0aW9uEh4KGlNZTkNfT1BFUkFUSU9OX1VOU1BFQ0lGSUVEEAASGQoVU1lOQ1'
    '9PUEVSQVRJT05fQ1JFQVRFEAESGQoVU1lOQ19PUEVSQVRJT05fVVBEQVRFEAISGQoVU1lOQ19P'
    'UEVSQVRJT05fREVMRVRFEAM=');

@$core.Deprecated('Use syncPayloadDescriptor instead')
const SyncPayload$json = {
  '1': 'SyncPayload',
  '2': [
    {'1': 'entity_type', '3': 1, '4': 1, '5': 9, '10': 'entityType'},
    {
      '1': 'operation',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.sync.v1.SyncOperation',
      '10': 'operation'
    },
    {'1': 'payload', '3': 3, '4': 1, '5': 12, '10': 'payload'},
    {'1': 'version', '3': 4, '4': 1, '5': 3, '10': 'version'},
    {'1': 'device_id', '3': 5, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'entity_id', '3': 6, '4': 1, '5': 9, '10': 'entityId'},
  ],
};

/// Descriptor for `SyncPayload`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncPayloadDescriptor = $convert.base64Decode(
    'CgtTeW5jUGF5bG9hZBIfCgtlbnRpdHlfdHlwZRgBIAEoCVIKZW50aXR5VHlwZRI6CglvcGVyYX'
    'Rpb24YAiABKA4yHC55dWNhaS5zeW5jLnYxLlN5bmNPcGVyYXRpb25SCW9wZXJhdGlvbhIYCgdw'
    'YXlsb2FkGAMgASgMUgdwYXlsb2FkEhgKB3ZlcnNpb24YBCABKANSB3ZlcnNpb24SGwoJZGV2aW'
    'NlX2lkGAUgASgJUghkZXZpY2VJZBIbCgllbnRpdHlfaWQYBiABKAlSCGVudGl0eUlk');

@$core.Deprecated('Use registerDeviceRequestDescriptor instead')
const RegisterDeviceRequest$json = {
  '1': 'RegisterDeviceRequest',
  '2': [
    {'1': 'device_name', '3': 1, '4': 1, '5': 9, '10': 'deviceName'},
  ],
};

/// Descriptor for `RegisterDeviceRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDeviceRequestDescriptor = $convert.base64Decode(
    'ChVSZWdpc3RlckRldmljZVJlcXVlc3QSHwoLZGV2aWNlX25hbWUYASABKAlSCmRldmljZU5hbW'
    'U=');

@$core.Deprecated('Use registerDeviceResponseDescriptor instead')
const RegisterDeviceResponse$json = {
  '1': 'RegisterDeviceResponse',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'last_sync_version', '3': 2, '4': 1, '5': 3, '10': 'lastSyncVersion'},
  ],
};

/// Descriptor for `RegisterDeviceResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerDeviceResponseDescriptor =
    $convert.base64Decode(
        'ChZSZWdpc3RlckRldmljZVJlc3BvbnNlEhsKCWRldmljZV9pZBgBIAEoCVIIZGV2aWNlSWQSKg'
        'oRbGFzdF9zeW5jX3ZlcnNpb24YAiABKANSD2xhc3RTeW5jVmVyc2lvbg==');

@$core.Deprecated('Use getSyncStatusRequestDescriptor instead')
const GetSyncStatusRequest$json = {
  '1': 'GetSyncStatusRequest',
};

/// Descriptor for `GetSyncStatusRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getSyncStatusRequestDescriptor =
    $convert.base64Decode('ChRHZXRTeW5jU3RhdHVzUmVxdWVzdA==');

@$core.Deprecated('Use syncStatusResponseDescriptor instead')
const SyncStatusResponse$json = {
  '1': 'SyncStatusResponse',
  '2': [
    {'1': 'device_id', '3': 1, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'last_sync_version', '3': 2, '4': 1, '5': 3, '10': 'lastSyncVersion'},
    {
      '1': 'last_sync_at',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'lastSyncAt'
    },
    {
      '1': 'pending_conflicts',
      '3': 4,
      '4': 1,
      '5': 5,
      '10': 'pendingConflicts'
    },
  ],
};

/// Descriptor for `SyncStatusResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List syncStatusResponseDescriptor = $convert.base64Decode(
    'ChJTeW5jU3RhdHVzUmVzcG9uc2USGwoJZGV2aWNlX2lkGAEgASgJUghkZXZpY2VJZBIqChFsYX'
    'N0X3N5bmNfdmVyc2lvbhgCIAEoA1IPbGFzdFN5bmNWZXJzaW9uEjwKDGxhc3Rfc3luY19hdBgD'
    'IAEoCzIaLmdvb2dsZS5wcm90b2J1Zi5UaW1lc3RhbXBSCmxhc3RTeW5jQXQSKwoRcGVuZGluZ1'
    '9jb25mbGljdHMYBCABKAVSEHBlbmRpbmdDb25mbGljdHM=');

@$core.Deprecated('Use pushChangesRequestDescriptor instead')
const PushChangesRequest$json = {
  '1': 'PushChangesRequest',
  '2': [
    {
      '1': 'changes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.sync.v1.SyncPayload',
      '10': 'changes'
    },
  ],
};

/// Descriptor for `PushChangesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pushChangesRequestDescriptor = $convert.base64Decode(
    'ChJQdXNoQ2hhbmdlc1JlcXVlc3QSNAoHY2hhbmdlcxgBIAMoCzIaLnl1Y2FpLnN5bmMudjEuU3'
    'luY1BheWxvYWRSB2NoYW5nZXM=');

@$core.Deprecated('Use pushResponseDescriptor instead')
const PushResponse$json = {
  '1': 'PushResponse',
  '2': [
    {'1': 'synced_version', '3': 1, '4': 1, '5': 3, '10': 'syncedVersion'},
    {
      '1': 'conflicts',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.yucai.sync.v1.ConflictDTO',
      '10': 'conflicts'
    },
  ],
};

/// Descriptor for `PushResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pushResponseDescriptor = $convert.base64Decode(
    'CgxQdXNoUmVzcG9uc2USJQoOc3luY2VkX3ZlcnNpb24YASABKANSDXN5bmNlZFZlcnNpb24SOA'
    'oJY29uZmxpY3RzGAIgAygLMhoueXVjYWkuc3luYy52MS5Db25mbGljdERUT1IJY29uZmxpY3Rz');

@$core.Deprecated('Use pullChangesRequestDescriptor instead')
const PullChangesRequest$json = {
  '1': 'PullChangesRequest',
  '2': [
    {'1': 'since_version', '3': 1, '4': 1, '5': 3, '10': 'sinceVersion'},
    {'1': 'entity_types', '3': 2, '4': 3, '5': 9, '10': 'entityTypes'},
    {'1': 'page_size', '3': 3, '4': 1, '5': 5, '10': 'pageSize'},
  ],
};

/// Descriptor for `PullChangesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullChangesRequestDescriptor = $convert.base64Decode(
    'ChJQdWxsQ2hhbmdlc1JlcXVlc3QSIwoNc2luY2VfdmVyc2lvbhgBIAEoA1IMc2luY2VWZXJzaW'
    '9uEiEKDGVudGl0eV90eXBlcxgCIAMoCVILZW50aXR5VHlwZXMSGwoJcGFnZV9zaXplGAMgASgF'
    'UghwYWdlU2l6ZQ==');

@$core.Deprecated('Use pullChangesResponseDescriptor instead')
const PullChangesResponse$json = {
  '1': 'PullChangesResponse',
  '2': [
    {
      '1': 'changes',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.sync.v1.SyncPayload',
      '10': 'changes'
    },
    {'1': 'latest_version', '3': 2, '4': 1, '5': 3, '10': 'latestVersion'},
    {'1': 'has_more', '3': 3, '4': 1, '5': 8, '10': 'hasMore'},
  ],
};

/// Descriptor for `PullChangesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List pullChangesResponseDescriptor = $convert.base64Decode(
    'ChNQdWxsQ2hhbmdlc1Jlc3BvbnNlEjQKB2NoYW5nZXMYASADKAsyGi55dWNhaS5zeW5jLnYxLl'
    'N5bmNQYXlsb2FkUgdjaGFuZ2VzEiUKDmxhdGVzdF92ZXJzaW9uGAIgASgDUg1sYXRlc3RWZXJz'
    'aW9uEhkKCGhhc19tb3JlGAMgASgIUgdoYXNNb3Jl');

@$core.Deprecated('Use conflictDTODescriptor instead')
const ConflictDTO$json = {
  '1': 'ConflictDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'entity_type', '3': 2, '4': 1, '5': 9, '10': 'entityType'},
    {'1': 'entity_id', '3': 3, '4': 1, '5': 9, '10': 'entityId'},
    {'1': 'server_payload', '3': 4, '4': 1, '5': 12, '10': 'serverPayload'},
    {'1': 'client_payload', '3': 5, '4': 1, '5': 12, '10': 'clientPayload'},
    {'1': 'resolution', '3': 6, '4': 1, '5': 9, '10': 'resolution'},
  ],
};

/// Descriptor for `ConflictDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List conflictDTODescriptor = $convert.base64Decode(
    'CgtDb25mbGljdERUTxIOCgJpZBgBIAEoCVICaWQSHwoLZW50aXR5X3R5cGUYAiABKAlSCmVudG'
    'l0eVR5cGUSGwoJZW50aXR5X2lkGAMgASgJUghlbnRpdHlJZBIlCg5zZXJ2ZXJfcGF5bG9hZBgE'
    'IAEoDFINc2VydmVyUGF5bG9hZBIlCg5jbGllbnRfcGF5bG9hZBgFIAEoDFINY2xpZW50UGF5bG'
    '9hZBIeCgpyZXNvbHV0aW9uGAYgASgJUgpyZXNvbHV0aW9u');

@$core.Deprecated('Use resolveConflictRequestDescriptor instead')
const ResolveConflictRequest$json = {
  '1': 'ResolveConflictRequest',
  '2': [
    {'1': 'conflict_id', '3': 1, '4': 1, '5': 9, '10': 'conflictId'},
    {'1': 'resolution', '3': 2, '4': 1, '5': 9, '10': 'resolution'},
    {'1': 'merged_payload', '3': 3, '4': 1, '5': 12, '10': 'mergedPayload'},
  ],
};

/// Descriptor for `ResolveConflictRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List resolveConflictRequestDescriptor = $convert.base64Decode(
    'ChZSZXNvbHZlQ29uZmxpY3RSZXF1ZXN0Eh8KC2NvbmZsaWN0X2lkGAEgASgJUgpjb25mbGljdE'
    'lkEh4KCnJlc29sdXRpb24YAiABKAlSCnJlc29sdXRpb24SJQoObWVyZ2VkX3BheWxvYWQYAyAB'
    'KAxSDW1lcmdlZFBheWxvYWQ=');

@$core.Deprecated('Use listConflictsRequestDescriptor instead')
const ListConflictsRequest$json = {
  '1': 'ListConflictsRequest',
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

/// Descriptor for `ListConflictsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listConflictsRequestDescriptor = $convert.base64Decode(
    'ChRMaXN0Q29uZmxpY3RzUmVxdWVzdBIwCgRwYWdlGAEgASgLMhwueXVjYWkuY29tbW9uLnYxLl'
    'BhZ2VSZXF1ZXN0UgRwYWdl');

@$core.Deprecated('Use listConflictsResponseDescriptor instead')
const ListConflictsResponse$json = {
  '1': 'ListConflictsResponse',
  '2': [
    {
      '1': 'conflicts',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.sync.v1.ConflictDTO',
      '10': 'conflicts'
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

/// Descriptor for `ListConflictsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listConflictsResponseDescriptor = $convert.base64Decode(
    'ChVMaXN0Q29uZmxpY3RzUmVzcG9uc2USOAoJY29uZmxpY3RzGAEgAygLMhoueXVjYWkuc3luYy'
    '52MS5Db25mbGljdERUT1IJY29uZmxpY3RzEjEKBHBhZ2UYAiABKAsyHS55dWNhaS5jb21tb24u'
    'djEuUGFnZVJlc3BvbnNlUgRwYWdl');
