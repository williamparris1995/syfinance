// This is a generated file - do not edit.
//
// Generated from backup/v1/backup.proto.

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

@$core.Deprecated('Use backupProviderDescriptor instead')
const BackupProvider$json = {
  '1': 'BackupProvider',
  '2': [
    {'1': 'BACKUP_PROVIDER_UNSPECIFIED', '2': 0},
    {'1': 'BACKUP_PROVIDER_LOCAL', '2': 1},
    {'1': 'BACKUP_PROVIDER_WEBDAV', '2': 2},
    {'1': 'BACKUP_PROVIDER_DROPBOX', '2': 3},
    {'1': 'BACKUP_PROVIDER_GOOGLE_DRIVE', '2': 4},
    {'1': 'BACKUP_PROVIDER_ONE_DRIVE', '2': 5},
  ],
};

/// Descriptor for `BackupProvider`. Decode as a `google.protobuf.EnumDescriptorProto`.
final $typed_data.Uint8List backupProviderDescriptor = $convert.base64Decode(
    'Cg5CYWNrdXBQcm92aWRlchIfChtCQUNLVVBfUFJPVklERVJfVU5TUEVDSUZJRUQQABIZChVCQU'
    'NLVVBfUFJPVklERVJfTE9DQUwQARIaChZCQUNLVVBfUFJPVklERVJfV0VCREFWEAISGwoXQkFD'
    'S1VQX1BST1ZJREVSX0RST1BCT1gQAxIgChxCQUNLVVBfUFJPVklERVJfR09PR0xFX0RSSVZFEA'
    'QSHQoZQkFDS1VQX1BST1ZJREVSX09ORV9EUklWRRAF');

@$core.Deprecated('Use backupDTODescriptor instead')
const BackupDTO$json = {
  '1': 'BackupDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {
      '1': 'provider',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.backup.v1.BackupProvider',
      '10': 'provider'
    },
    {'1': 'filename', '3': 3, '4': 1, '5': 9, '10': 'filename'},
    {'1': 'size_bytes', '3': 4, '4': 1, '5': 3, '10': 'sizeBytes'},
    {'1': 'checksum', '3': 5, '4': 1, '5': 9, '10': 'checksum'},
    {'1': 'encrypted', '3': 6, '4': 1, '5': 8, '10': 'encrypted'},
    {'1': 'auto', '3': 7, '4': 1, '5': 8, '10': 'auto'},
    {
      '1': 'created_at',
      '3': 8,
      '4': 1,
      '5': 11,
      '6': '.google.protobuf.Timestamp',
      '10': 'createdAt'
    },
  ],
};

/// Descriptor for `BackupDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupDTODescriptor = $convert.base64Decode(
    'CglCYWNrdXBEVE8SDgoCaWQYASABKAlSAmlkEjsKCHByb3ZpZGVyGAIgASgOMh8ueXVjYWkuYm'
    'Fja3VwLnYxLkJhY2t1cFByb3ZpZGVyUghwcm92aWRlchIaCghmaWxlbmFtZRgDIAEoCVIIZmls'
    'ZW5hbWUSHQoKc2l6ZV9ieXRlcxgEIAEoA1IJc2l6ZUJ5dGVzEhoKCGNoZWNrc3VtGAUgASgJUg'
    'hjaGVja3N1bRIcCgllbmNyeXB0ZWQYBiABKAhSCWVuY3J5cHRlZBISCgRhdXRvGAcgASgIUgRh'
    'dXRvEjkKCmNyZWF0ZWRfYXQYCCABKAsyGi5nb29nbGUucHJvdG9idWYuVGltZXN0YW1wUgljcm'
    'VhdGVkQXQ=');

@$core.Deprecated('Use createBackupRequestDescriptor instead')
const CreateBackupRequest$json = {
  '1': 'CreateBackupRequest',
  '2': [
    {'1': 'encrypted', '3': 1, '4': 1, '5': 8, '10': 'encrypted'},
  ],
};

/// Descriptor for `CreateBackupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List createBackupRequestDescriptor =
    $convert.base64Decode(
        'ChNDcmVhdGVCYWNrdXBSZXF1ZXN0EhwKCWVuY3J5cHRlZBgBIAEoCFIJZW5jcnlwdGVk');

@$core.Deprecated('Use restoreBackupRequestDescriptor instead')
const RestoreBackupRequest$json = {
  '1': 'RestoreBackupRequest',
  '2': [
    {'1': 'backup_id', '3': 1, '4': 1, '5': 9, '10': 'backupId'},
    {'1': 'password', '3': 2, '4': 1, '5': 9, '10': 'password'},
  ],
};

/// Descriptor for `RestoreBackupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List restoreBackupRequestDescriptor = $convert.base64Decode(
    'ChRSZXN0b3JlQmFja3VwUmVxdWVzdBIbCgliYWNrdXBfaWQYASABKAlSCGJhY2t1cElkEhoKCH'
    'Bhc3N3b3JkGAIgASgJUghwYXNzd29yZA==');

@$core.Deprecated('Use listBackupsRequestDescriptor instead')
const ListBackupsRequest$json = {
  '1': 'ListBackupsRequest',
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
      '1': 'provider',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.backup.v1.BackupProvider',
      '10': 'provider'
    },
  ],
};

/// Descriptor for `ListBackupsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBackupsRequestDescriptor = $convert.base64Decode(
    'ChJMaXN0QmFja3Vwc1JlcXVlc3QSMAoEcGFnZRgBIAEoCzIcLnl1Y2FpLmNvbW1vbi52MS5QYW'
    'dlUmVxdWVzdFIEcGFnZRI7Cghwcm92aWRlchgCIAEoDjIfLnl1Y2FpLmJhY2t1cC52MS5CYWNr'
    'dXBQcm92aWRlclIIcHJvdmlkZXI=');

@$core.Deprecated('Use listBackupsResponseDescriptor instead')
const ListBackupsResponse$json = {
  '1': 'ListBackupsResponse',
  '2': [
    {
      '1': 'backups',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.backup.v1.BackupDTO',
      '10': 'backups'
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

/// Descriptor for `ListBackupsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List listBackupsResponseDescriptor = $convert.base64Decode(
    'ChNMaXN0QmFja3Vwc1Jlc3BvbnNlEjQKB2JhY2t1cHMYASADKAsyGi55dWNhaS5iYWNrdXAudj'
    'EuQmFja3VwRFRPUgdiYWNrdXBzEjEKBHBhZ2UYAiABKAsyHS55dWNhaS5jb21tb24udjEuUGFn'
    'ZVJlc3BvbnNlUgRwYWdl');

@$core.Deprecated('Use deleteBackupRequestDescriptor instead')
const DeleteBackupRequest$json = {
  '1': 'DeleteBackupRequest',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
  ],
};

/// Descriptor for `DeleteBackupRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List deleteBackupRequestDescriptor = $convert
    .base64Decode('ChNEZWxldGVCYWNrdXBSZXF1ZXN0Eg4KAmlkGAEgASgJUgJpZA==');

@$core.Deprecated('Use cloudSettingsDTODescriptor instead')
const CloudSettingsDTO$json = {
  '1': 'CloudSettingsDTO',
  '2': [
    {
      '1': 'provider',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.yucai.backup.v1.BackupProvider',
      '10': 'provider'
    },
    {'1': 'webdav_url', '3': 2, '4': 1, '5': 9, '10': 'webdavUrl'},
    {'1': 'webdav_username', '3': 3, '4': 1, '5': 9, '10': 'webdavUsername'},
    {'1': 'oauth_token', '3': 4, '4': 1, '5': 9, '10': 'oauthToken'},
    {'1': 'auto_backup', '3': 5, '4': 1, '5': 8, '10': 'autoBackup'},
    {
      '1': 'auto_backup_interval_hours',
      '3': 6,
      '4': 1,
      '5': 5,
      '10': 'autoBackupIntervalHours'
    },
  ],
};

/// Descriptor for `CloudSettingsDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cloudSettingsDTODescriptor = $convert.base64Decode(
    'ChBDbG91ZFNldHRpbmdzRFRPEjsKCHByb3ZpZGVyGAEgASgOMh8ueXVjYWkuYmFja3VwLnYxLk'
    'JhY2t1cFByb3ZpZGVyUghwcm92aWRlchIdCgp3ZWJkYXZfdXJsGAIgASgJUgl3ZWJkYXZVcmwS'
    'JwoPd2ViZGF2X3VzZXJuYW1lGAMgASgJUg53ZWJkYXZVc2VybmFtZRIfCgtvYXV0aF90b2tlbh'
    'gEIAEoCVIKb2F1dGhUb2tlbhIfCgthdXRvX2JhY2t1cBgFIAEoCFIKYXV0b0JhY2t1cBI7Chph'
    'dXRvX2JhY2t1cF9pbnRlcnZhbF9ob3VycxgGIAEoBVIXYXV0b0JhY2t1cEludGVydmFsSG91cn'
    'M=');

@$core.Deprecated('Use saveCloudSettingsRequestDescriptor instead')
const SaveCloudSettingsRequest$json = {
  '1': 'SaveCloudSettingsRequest',
  '2': [
    {
      '1': 'settings',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.backup.v1.CloudSettingsDTO',
      '10': 'settings'
    },
  ],
};

/// Descriptor for `SaveCloudSettingsRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List saveCloudSettingsRequestDescriptor =
    $convert.base64Decode(
        'ChhTYXZlQ2xvdWRTZXR0aW5nc1JlcXVlc3QSPQoIc2V0dGluZ3MYASABKAsyIS55dWNhaS5iYW'
        'NrdXAudjEuQ2xvdWRTZXR0aW5nc0RUT1IIc2V0dGluZ3M=');

@$core.Deprecated('Use cloudSettingsResponseDescriptor instead')
const CloudSettingsResponse$json = {
  '1': 'CloudSettingsResponse',
  '2': [
    {
      '1': 'settings',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.backup.v1.CloudSettingsDTO',
      '10': 'settings'
    },
  ],
};

/// Descriptor for `CloudSettingsResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List cloudSettingsResponseDescriptor = $convert.base64Decode(
    'ChVDbG91ZFNldHRpbmdzUmVzcG9uc2USPQoIc2V0dGluZ3MYASABKAsyIS55dWNhaS5iYWNrdX'
    'AudjEuQ2xvdWRTZXR0aW5nc0RUT1IIc2V0dGluZ3M=');

@$core.Deprecated('Use testConnectionRequestDescriptor instead')
const TestConnectionRequest$json = {
  '1': 'TestConnectionRequest',
  '2': [
    {
      '1': 'provider',
      '3': 1,
      '4': 1,
      '5': 14,
      '6': '.yucai.backup.v1.BackupProvider',
      '10': 'provider'
    },
  ],
};

/// Descriptor for `TestConnectionRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testConnectionRequestDescriptor = $convert.base64Decode(
    'ChVUZXN0Q29ubmVjdGlvblJlcXVlc3QSOwoIcHJvdmlkZXIYASABKA4yHy55dWNhaS5iYWNrdX'
    'AudjEuQmFja3VwUHJvdmlkZXJSCHByb3ZpZGVy');

@$core.Deprecated('Use testConnectionResponseDescriptor instead')
const TestConnectionResponse$json = {
  '1': 'TestConnectionResponse',
  '2': [
    {'1': 'success', '3': 1, '4': 1, '5': 8, '10': 'success'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
  ],
};

/// Descriptor for `TestConnectionResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List testConnectionResponseDescriptor =
    $convert.base64Decode(
        'ChZUZXN0Q29ubmVjdGlvblJlc3BvbnNlEhgKB3N1Y2Nlc3MYASABKAhSB3N1Y2Nlc3MSGAoHbW'
        'Vzc2FnZRgCIAEoCVIHbWVzc2FnZQ==');

@$core.Deprecated('Use uploadRequestDescriptor instead')
const UploadRequest$json = {
  '1': 'UploadRequest',
  '2': [
    {'1': 'backup_id', '3': 1, '4': 1, '5': 9, '10': 'backupId'},
    {
      '1': 'provider',
      '3': 2,
      '4': 1,
      '5': 14,
      '6': '.yucai.backup.v1.BackupProvider',
      '10': 'provider'
    },
  ],
};

/// Descriptor for `UploadRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List uploadRequestDescriptor = $convert.base64Decode(
    'Cg1VcGxvYWRSZXF1ZXN0EhsKCWJhY2t1cF9pZBgBIAEoCVIIYmFja3VwSWQSOwoIcHJvdmlkZX'
    'IYAiABKA4yHy55dWNhaS5iYWNrdXAudjEuQmFja3VwUHJvdmlkZXJSCHByb3ZpZGVy');

@$core.Deprecated('Use backupResponseDescriptor instead')
const BackupResponse$json = {
  '1': 'BackupResponse',
  '2': [
    {
      '1': 'backup',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.backup.v1.BackupDTO',
      '10': 'backup'
    },
  ],
};

/// Descriptor for `BackupResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List backupResponseDescriptor = $convert.base64Decode(
    'Cg5CYWNrdXBSZXNwb25zZRIyCgZiYWNrdXAYASABKAsyGi55dWNhaS5iYWNrdXAudjEuQmFja3'
    'VwRFRPUgZiYWNrdXA=');
