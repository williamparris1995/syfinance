// This is a generated file - do not edit.
//
// Generated from sync/v1/sync.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class SyncOperation extends $pb.ProtobufEnum {
  static const SyncOperation SYNC_OPERATION_UNSPECIFIED =
      SyncOperation._(0, _omitEnumNames ? '' : 'SYNC_OPERATION_UNSPECIFIED');
  static const SyncOperation SYNC_OPERATION_CREATE =
      SyncOperation._(1, _omitEnumNames ? '' : 'SYNC_OPERATION_CREATE');
  static const SyncOperation SYNC_OPERATION_UPDATE =
      SyncOperation._(2, _omitEnumNames ? '' : 'SYNC_OPERATION_UPDATE');
  static const SyncOperation SYNC_OPERATION_DELETE =
      SyncOperation._(3, _omitEnumNames ? '' : 'SYNC_OPERATION_DELETE');

  static const $core.List<SyncOperation> values = <SyncOperation>[
    SYNC_OPERATION_UNSPECIFIED,
    SYNC_OPERATION_CREATE,
    SYNC_OPERATION_UPDATE,
    SYNC_OPERATION_DELETE,
  ];

  static final $core.List<SyncOperation?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static SyncOperation? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SyncOperation._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
