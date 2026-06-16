// This is a generated file - do not edit.
//
// Generated from backup/v1/backup.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class BackupProvider extends $pb.ProtobufEnum {
  static const BackupProvider BACKUP_PROVIDER_UNSPECIFIED =
      BackupProvider._(0, _omitEnumNames ? '' : 'BACKUP_PROVIDER_UNSPECIFIED');
  static const BackupProvider BACKUP_PROVIDER_LOCAL =
      BackupProvider._(1, _omitEnumNames ? '' : 'BACKUP_PROVIDER_LOCAL');
  static const BackupProvider BACKUP_PROVIDER_WEBDAV =
      BackupProvider._(2, _omitEnumNames ? '' : 'BACKUP_PROVIDER_WEBDAV');
  static const BackupProvider BACKUP_PROVIDER_DROPBOX =
      BackupProvider._(3, _omitEnumNames ? '' : 'BACKUP_PROVIDER_DROPBOX');
  static const BackupProvider BACKUP_PROVIDER_GOOGLE_DRIVE =
      BackupProvider._(4, _omitEnumNames ? '' : 'BACKUP_PROVIDER_GOOGLE_DRIVE');
  static const BackupProvider BACKUP_PROVIDER_ONE_DRIVE =
      BackupProvider._(5, _omitEnumNames ? '' : 'BACKUP_PROVIDER_ONE_DRIVE');

  static const $core.List<BackupProvider> values = <BackupProvider>[
    BACKUP_PROVIDER_UNSPECIFIED,
    BACKUP_PROVIDER_LOCAL,
    BACKUP_PROVIDER_WEBDAV,
    BACKUP_PROVIDER_DROPBOX,
    BACKUP_PROVIDER_GOOGLE_DRIVE,
    BACKUP_PROVIDER_ONE_DRIVE,
  ];

  static final $core.List<BackupProvider?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static BackupProvider? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const BackupProvider._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
