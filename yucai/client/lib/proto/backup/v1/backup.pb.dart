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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $2;

import '../../common/v1/pagination.pb.dart' as $3;
import 'backup.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'backup.pbenum.dart';

class BackupDTO extends $pb.GeneratedMessage {
  factory BackupDTO({
    $core.String? id,
    BackupProvider? provider,
    $core.String? filename,
    $fixnum.Int64? sizeBytes,
    $core.String? checksum,
    $core.bool? encrypted,
    $core.bool? auto,
    $2.Timestamp? createdAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (provider != null) result.provider = provider;
    if (filename != null) result.filename = filename;
    if (sizeBytes != null) result.sizeBytes = sizeBytes;
    if (checksum != null) result.checksum = checksum;
    if (encrypted != null) result.encrypted = encrypted;
    if (auto != null) result.auto = auto;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  BackupDTO._();

  factory BackupDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aE<BackupProvider>(2, _omitFieldNames ? '' : 'provider',
        enumValues: BackupProvider.values)
    ..aOS(3, _omitFieldNames ? '' : 'filename')
    ..aInt64(4, _omitFieldNames ? '' : 'sizeBytes')
    ..aOS(5, _omitFieldNames ? '' : 'checksum')
    ..aOB(6, _omitFieldNames ? '' : 'encrypted')
    ..aOB(7, _omitFieldNames ? '' : 'auto')
    ..aOM<$2.Timestamp>(8, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupDTO copyWith(void Function(BackupDTO) updates) =>
      super.copyWith((message) => updates(message as BackupDTO)) as BackupDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupDTO create() => BackupDTO._();
  @$core.override
  BackupDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BackupDTO getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BackupDTO>(create);
  static BackupDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  BackupProvider get provider => $_getN(1);
  @$pb.TagNumber(2)
  set provider(BackupProvider value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProvider() => $_has(1);
  @$pb.TagNumber(2)
  void clearProvider() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get filename => $_getSZ(2);
  @$pb.TagNumber(3)
  set filename($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFilename() => $_has(2);
  @$pb.TagNumber(3)
  void clearFilename() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get sizeBytes => $_getI64(3);
  @$pb.TagNumber(4)
  set sizeBytes($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSizeBytes() => $_has(3);
  @$pb.TagNumber(4)
  void clearSizeBytes() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get checksum => $_getSZ(4);
  @$pb.TagNumber(5)
  set checksum($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasChecksum() => $_has(4);
  @$pb.TagNumber(5)
  void clearChecksum() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get encrypted => $_getBF(5);
  @$pb.TagNumber(6)
  set encrypted($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEncrypted() => $_has(5);
  @$pb.TagNumber(6)
  void clearEncrypted() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get auto => $_getBF(6);
  @$pb.TagNumber(7)
  set auto($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAuto() => $_has(6);
  @$pb.TagNumber(7)
  void clearAuto() => $_clearField(7);

  @$pb.TagNumber(8)
  $2.Timestamp get createdAt => $_getN(7);
  @$pb.TagNumber(8)
  set createdAt($2.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => $_clearField(8);
  @$pb.TagNumber(8)
  $2.Timestamp ensureCreatedAt() => $_ensure(7);
}

class CreateBackupRequest extends $pb.GeneratedMessage {
  factory CreateBackupRequest({
    $core.bool? encrypted,
    $core.String? password,
  }) {
    final result = create();
    if (encrypted != null) result.encrypted = encrypted;
    if (password != null) result.password = password;
    return result;
  }

  CreateBackupRequest._();

  factory CreateBackupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateBackupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateBackupRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'encrypted')
    ..aOS(2, _omitFieldNames ? '' : 'password')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateBackupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateBackupRequest copyWith(void Function(CreateBackupRequest) updates) =>
      super.copyWith((message) => updates(message as CreateBackupRequest))
          as CreateBackupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateBackupRequest create() => CreateBackupRequest._();
  @$core.override
  CreateBackupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateBackupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateBackupRequest>(create);
  static CreateBackupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get encrypted => $_getBF(0);
  @$pb.TagNumber(1)
  set encrypted($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEncrypted() => $_has(0);
  @$pb.TagNumber(1)
  void clearEncrypted() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get password => $_getSZ(1);
  @$pb.TagNumber(2)
  set password($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPassword() => $_has(1);
  @$pb.TagNumber(2)
  void clearPassword() => $_clearField(2);
}

class RestoreBackupRequest extends $pb.GeneratedMessage {
  factory RestoreBackupRequest({
    $core.String? backupId,
    $core.String? password,
  }) {
    final result = create();
    if (backupId != null) result.backupId = backupId;
    if (password != null) result.password = password;
    return result;
  }

  RestoreBackupRequest._();

  factory RestoreBackupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RestoreBackupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RestoreBackupRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'backupId')
    ..aOS(2, _omitFieldNames ? '' : 'password')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreBackupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RestoreBackupRequest copyWith(void Function(RestoreBackupRequest) updates) =>
      super.copyWith((message) => updates(message as RestoreBackupRequest))
          as RestoreBackupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RestoreBackupRequest create() => RestoreBackupRequest._();
  @$core.override
  RestoreBackupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RestoreBackupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RestoreBackupRequest>(create);
  static RestoreBackupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get backupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set backupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackupId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get password => $_getSZ(1);
  @$pb.TagNumber(2)
  set password($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPassword() => $_has(1);
  @$pb.TagNumber(2)
  void clearPassword() => $_clearField(2);
}

class ListBackupsRequest extends $pb.GeneratedMessage {
  factory ListBackupsRequest({
    $3.PageRequest? page,
    BackupProvider? provider,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (provider != null) result.provider = provider;
    return result;
  }

  ListBackupsRequest._();

  factory ListBackupsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListBackupsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListBackupsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOM<$3.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageRequest.create)
    ..aE<BackupProvider>(2, _omitFieldNames ? '' : 'provider',
        enumValues: BackupProvider.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBackupsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBackupsRequest copyWith(void Function(ListBackupsRequest) updates) =>
      super.copyWith((message) => updates(message as ListBackupsRequest))
          as ListBackupsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListBackupsRequest create() => ListBackupsRequest._();
  @$core.override
  ListBackupsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListBackupsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListBackupsRequest>(create);
  static ListBackupsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $3.PageRequest get page => $_getN(0);
  @$pb.TagNumber(1)
  set page($3.PageRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);
  @$pb.TagNumber(1)
  $3.PageRequest ensurePage() => $_ensure(0);

  @$pb.TagNumber(2)
  BackupProvider get provider => $_getN(1);
  @$pb.TagNumber(2)
  set provider(BackupProvider value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProvider() => $_has(1);
  @$pb.TagNumber(2)
  void clearProvider() => $_clearField(2);
}

class ListBackupsResponse extends $pb.GeneratedMessage {
  factory ListBackupsResponse({
    $core.Iterable<BackupDTO>? backups,
    $3.PageResponse? page,
  }) {
    final result = create();
    if (backups != null) result.backups.addAll(backups);
    if (page != null) result.page = page;
    return result;
  }

  ListBackupsResponse._();

  factory ListBackupsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListBackupsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListBackupsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..pPM<BackupDTO>(1, _omitFieldNames ? '' : 'backups',
        subBuilder: BackupDTO.create)
    ..aOM<$3.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBackupsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBackupsResponse copyWith(void Function(ListBackupsResponse) updates) =>
      super.copyWith((message) => updates(message as ListBackupsResponse))
          as ListBackupsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListBackupsResponse create() => ListBackupsResponse._();
  @$core.override
  ListBackupsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListBackupsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListBackupsResponse>(create);
  static ListBackupsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<BackupDTO> get backups => $_getList(0);

  @$pb.TagNumber(2)
  $3.PageResponse get page => $_getN(1);
  @$pb.TagNumber(2)
  set page($3.PageResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(2)
  void clearPage() => $_clearField(2);
  @$pb.TagNumber(2)
  $3.PageResponse ensurePage() => $_ensure(1);
}

class DeleteBackupRequest extends $pb.GeneratedMessage {
  factory DeleteBackupRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteBackupRequest._();

  factory DeleteBackupRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteBackupRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteBackupRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteBackupRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteBackupRequest copyWith(void Function(DeleteBackupRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteBackupRequest))
          as DeleteBackupRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteBackupRequest create() => DeleteBackupRequest._();
  @$core.override
  DeleteBackupRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteBackupRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteBackupRequest>(create);
  static DeleteBackupRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

/// CloudSettingsDTO carries per-tenant auto-backup preferences only. Cloud
/// backup fields (provider/webdav/oauth) were removed 2026-07-25; name kept.
class CloudSettingsDTO extends $pb.GeneratedMessage {
  factory CloudSettingsDTO({
    $core.bool? autoBackup,
    $core.int? autoBackupIntervalHours,
  }) {
    final result = create();
    if (autoBackup != null) result.autoBackup = autoBackup;
    if (autoBackupIntervalHours != null)
      result.autoBackupIntervalHours = autoBackupIntervalHours;
    return result;
  }

  CloudSettingsDTO._();

  factory CloudSettingsDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CloudSettingsDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloudSettingsDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'autoBackup')
    ..aI(2, _omitFieldNames ? '' : 'autoBackupIntervalHours')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloudSettingsDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloudSettingsDTO copyWith(void Function(CloudSettingsDTO) updates) =>
      super.copyWith((message) => updates(message as CloudSettingsDTO))
          as CloudSettingsDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CloudSettingsDTO create() => CloudSettingsDTO._();
  @$core.override
  CloudSettingsDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CloudSettingsDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CloudSettingsDTO>(create);
  static CloudSettingsDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get autoBackup => $_getBF(0);
  @$pb.TagNumber(1)
  set autoBackup($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAutoBackup() => $_has(0);
  @$pb.TagNumber(1)
  void clearAutoBackup() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get autoBackupIntervalHours => $_getIZ(1);
  @$pb.TagNumber(2)
  set autoBackupIntervalHours($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAutoBackupIntervalHours() => $_has(1);
  @$pb.TagNumber(2)
  void clearAutoBackupIntervalHours() => $_clearField(2);
}

class SaveCloudSettingsRequest extends $pb.GeneratedMessage {
  factory SaveCloudSettingsRequest({
    CloudSettingsDTO? settings,
  }) {
    final result = create();
    if (settings != null) result.settings = settings;
    return result;
  }

  SaveCloudSettingsRequest._();

  factory SaveCloudSettingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SaveCloudSettingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SaveCloudSettingsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOM<CloudSettingsDTO>(1, _omitFieldNames ? '' : 'settings',
        subBuilder: CloudSettingsDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveCloudSettingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SaveCloudSettingsRequest copyWith(
          void Function(SaveCloudSettingsRequest) updates) =>
      super.copyWith((message) => updates(message as SaveCloudSettingsRequest))
          as SaveCloudSettingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SaveCloudSettingsRequest create() => SaveCloudSettingsRequest._();
  @$core.override
  SaveCloudSettingsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SaveCloudSettingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SaveCloudSettingsRequest>(create);
  static SaveCloudSettingsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  CloudSettingsDTO get settings => $_getN(0);
  @$pb.TagNumber(1)
  set settings(CloudSettingsDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSettings() => $_has(0);
  @$pb.TagNumber(1)
  void clearSettings() => $_clearField(1);
  @$pb.TagNumber(1)
  CloudSettingsDTO ensureSettings() => $_ensure(0);
}

class CloudSettingsResponse extends $pb.GeneratedMessage {
  factory CloudSettingsResponse({
    CloudSettingsDTO? settings,
  }) {
    final result = create();
    if (settings != null) result.settings = settings;
    return result;
  }

  CloudSettingsResponse._();

  factory CloudSettingsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CloudSettingsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloudSettingsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOM<CloudSettingsDTO>(1, _omitFieldNames ? '' : 'settings',
        subBuilder: CloudSettingsDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloudSettingsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloudSettingsResponse copyWith(
          void Function(CloudSettingsResponse) updates) =>
      super.copyWith((message) => updates(message as CloudSettingsResponse))
          as CloudSettingsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CloudSettingsResponse create() => CloudSettingsResponse._();
  @$core.override
  CloudSettingsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CloudSettingsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CloudSettingsResponse>(create);
  static CloudSettingsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  CloudSettingsDTO get settings => $_getN(0);
  @$pb.TagNumber(1)
  set settings(CloudSettingsDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSettings() => $_has(0);
  @$pb.TagNumber(1)
  void clearSettings() => $_clearField(1);
  @$pb.TagNumber(1)
  CloudSettingsDTO ensureSettings() => $_ensure(0);
}

class BackupResponse extends $pb.GeneratedMessage {
  factory BackupResponse({
    BackupDTO? backup,
  }) {
    final result = create();
    if (backup != null) result.backup = backup;
    return result;
  }

  BackupResponse._();

  factory BackupResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BackupResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BackupResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOM<BackupDTO>(1, _omitFieldNames ? '' : 'backup',
        subBuilder: BackupDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BackupResponse copyWith(void Function(BackupResponse) updates) =>
      super.copyWith((message) => updates(message as BackupResponse))
          as BackupResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BackupResponse create() => BackupResponse._();
  @$core.override
  BackupResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BackupResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BackupResponse>(create);
  static BackupResponse? _defaultInstance;

  @$pb.TagNumber(1)
  BackupDTO get backup => $_getN(0);
  @$pb.TagNumber(1)
  set backup(BackupDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBackup() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackup() => $_clearField(1);
  @$pb.TagNumber(1)
  BackupDTO ensureBackup() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
