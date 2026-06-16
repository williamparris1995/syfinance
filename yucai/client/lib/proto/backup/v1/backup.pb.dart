// This is a generated file - do not edit.
//
// Generated from backup/v1/backup.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $0;

import '../../common/v1/pagination.pb.dart' as $1;
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
    $0.Timestamp? createdAt,
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
    ..aOM<$0.Timestamp>(8, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $0.Timestamp.create)
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
  $0.Timestamp get createdAt => $_getN(7);
  @$pb.TagNumber(8)
  set createdAt($0.Timestamp value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCreatedAt() => $_has(7);
  @$pb.TagNumber(8)
  void clearCreatedAt() => $_clearField(8);
  @$pb.TagNumber(8)
  $0.Timestamp ensureCreatedAt() => $_ensure(7);
}

class CreateBackupRequest extends $pb.GeneratedMessage {
  factory CreateBackupRequest({
    $core.bool? encrypted,
  }) {
    final result = create();
    if (encrypted != null) result.encrypted = encrypted;
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
    $1.PageRequest? page,
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
    ..aOM<$1.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageRequest.create)
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
  $1.PageRequest get page => $_getN(0);
  @$pb.TagNumber(1)
  set page($1.PageRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);
  @$pb.TagNumber(1)
  $1.PageRequest ensurePage() => $_ensure(0);

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
    $1.PageResponse? page,
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
    ..aOM<$1.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageResponse.create)
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
  $1.PageResponse get page => $_getN(1);
  @$pb.TagNumber(2)
  set page($1.PageResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(2)
  void clearPage() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.PageResponse ensurePage() => $_ensure(1);
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

class CloudSettingsDTO extends $pb.GeneratedMessage {
  factory CloudSettingsDTO({
    BackupProvider? provider,
    $core.String? webdavUrl,
    $core.String? webdavUsername,
    $core.String? oauthToken,
    $core.bool? autoBackup,
    $core.int? autoBackupIntervalHours,
  }) {
    final result = create();
    if (provider != null) result.provider = provider;
    if (webdavUrl != null) result.webdavUrl = webdavUrl;
    if (webdavUsername != null) result.webdavUsername = webdavUsername;
    if (oauthToken != null) result.oauthToken = oauthToken;
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
    ..aE<BackupProvider>(1, _omitFieldNames ? '' : 'provider',
        enumValues: BackupProvider.values)
    ..aOS(2, _omitFieldNames ? '' : 'webdavUrl')
    ..aOS(3, _omitFieldNames ? '' : 'webdavUsername')
    ..aOS(4, _omitFieldNames ? '' : 'oauthToken')
    ..aOB(5, _omitFieldNames ? '' : 'autoBackup')
    ..aI(6, _omitFieldNames ? '' : 'autoBackupIntervalHours')
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
  BackupProvider get provider => $_getN(0);
  @$pb.TagNumber(1)
  set provider(BackupProvider value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProvider() => $_has(0);
  @$pb.TagNumber(1)
  void clearProvider() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get webdavUrl => $_getSZ(1);
  @$pb.TagNumber(2)
  set webdavUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasWebdavUrl() => $_has(1);
  @$pb.TagNumber(2)
  void clearWebdavUrl() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get webdavUsername => $_getSZ(2);
  @$pb.TagNumber(3)
  set webdavUsername($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasWebdavUsername() => $_has(2);
  @$pb.TagNumber(3)
  void clearWebdavUsername() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get oauthToken => $_getSZ(3);
  @$pb.TagNumber(4)
  set oauthToken($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasOauthToken() => $_has(3);
  @$pb.TagNumber(4)
  void clearOauthToken() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get autoBackup => $_getBF(4);
  @$pb.TagNumber(5)
  set autoBackup($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAutoBackup() => $_has(4);
  @$pb.TagNumber(5)
  void clearAutoBackup() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get autoBackupIntervalHours => $_getIZ(5);
  @$pb.TagNumber(6)
  set autoBackupIntervalHours($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasAutoBackupIntervalHours() => $_has(5);
  @$pb.TagNumber(6)
  void clearAutoBackupIntervalHours() => $_clearField(6);
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

class TestConnectionRequest extends $pb.GeneratedMessage {
  factory TestConnectionRequest({
    BackupProvider? provider,
  }) {
    final result = create();
    if (provider != null) result.provider = provider;
    return result;
  }

  TestConnectionRequest._();

  factory TestConnectionRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TestConnectionRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestConnectionRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aE<BackupProvider>(1, _omitFieldNames ? '' : 'provider',
        enumValues: BackupProvider.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestConnectionRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestConnectionRequest copyWith(
          void Function(TestConnectionRequest) updates) =>
      super.copyWith((message) => updates(message as TestConnectionRequest))
          as TestConnectionRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TestConnectionRequest create() => TestConnectionRequest._();
  @$core.override
  TestConnectionRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TestConnectionRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestConnectionRequest>(create);
  static TestConnectionRequest? _defaultInstance;

  @$pb.TagNumber(1)
  BackupProvider get provider => $_getN(0);
  @$pb.TagNumber(1)
  set provider(BackupProvider value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasProvider() => $_has(0);
  @$pb.TagNumber(1)
  void clearProvider() => $_clearField(1);
}

class TestConnectionResponse extends $pb.GeneratedMessage {
  factory TestConnectionResponse({
    $core.bool? success,
    $core.String? message,
  }) {
    final result = create();
    if (success != null) result.success = success;
    if (message != null) result.message = message;
    return result;
  }

  TestConnectionResponse._();

  factory TestConnectionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TestConnectionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TestConnectionResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOB(1, _omitFieldNames ? '' : 'success')
    ..aOS(2, _omitFieldNames ? '' : 'message')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestConnectionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TestConnectionResponse copyWith(
          void Function(TestConnectionResponse) updates) =>
      super.copyWith((message) => updates(message as TestConnectionResponse))
          as TestConnectionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TestConnectionResponse create() => TestConnectionResponse._();
  @$core.override
  TestConnectionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TestConnectionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TestConnectionResponse>(create);
  static TestConnectionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.bool get success => $_getBF(0);
  @$pb.TagNumber(1)
  set success($core.bool value) => $_setBool(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSuccess() => $_has(0);
  @$pb.TagNumber(1)
  void clearSuccess() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMessage() => $_has(1);
  @$pb.TagNumber(2)
  void clearMessage() => $_clearField(2);
}

class UploadRequest extends $pb.GeneratedMessage {
  factory UploadRequest({
    $core.String? backupId,
    BackupProvider? provider,
  }) {
    final result = create();
    if (backupId != null) result.backupId = backupId;
    if (provider != null) result.provider = provider;
    return result;
  }

  UploadRequest._();

  factory UploadRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UploadRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UploadRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.backup.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'backupId')
    ..aE<BackupProvider>(2, _omitFieldNames ? '' : 'provider',
        enumValues: BackupProvider.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UploadRequest copyWith(void Function(UploadRequest) updates) =>
      super.copyWith((message) => updates(message as UploadRequest))
          as UploadRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UploadRequest create() => UploadRequest._();
  @$core.override
  UploadRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UploadRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UploadRequest>(create);
  static UploadRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get backupId => $_getSZ(0);
  @$pb.TagNumber(1)
  set backupId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBackupId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBackupId() => $_clearField(1);

  @$pb.TagNumber(2)
  BackupProvider get provider => $_getN(1);
  @$pb.TagNumber(2)
  set provider(BackupProvider value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasProvider() => $_has(1);
  @$pb.TagNumber(2)
  void clearProvider() => $_clearField(2);
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

class BackupServiceApi {
  final $pb.RpcClient _client;

  BackupServiceApi(this._client);

  $async.Future<BackupResponse> createBackup(
          $pb.ClientContext? ctx, CreateBackupRequest request) =>
      _client.invoke<BackupResponse>(
          ctx, 'BackupService', 'CreateBackup', request, BackupResponse());
  $async.Future<$2.Empty> restoreBackup(
          $pb.ClientContext? ctx, RestoreBackupRequest request) =>
      _client.invoke<$2.Empty>(
          ctx, 'BackupService', 'RestoreBackup', request, $2.Empty());
  $async.Future<ListBackupsResponse> listBackups(
          $pb.ClientContext? ctx, ListBackupsRequest request) =>
      _client.invoke<ListBackupsResponse>(
          ctx, 'BackupService', 'ListBackups', request, ListBackupsResponse());
  $async.Future<$2.Empty> deleteBackup(
          $pb.ClientContext? ctx, DeleteBackupRequest request) =>
      _client.invoke<$2.Empty>(
          ctx, 'BackupService', 'DeleteBackup', request, $2.Empty());
  $async.Future<$2.Empty> saveCloudSettings(
          $pb.ClientContext? ctx, SaveCloudSettingsRequest request) =>
      _client.invoke<$2.Empty>(
          ctx, 'BackupService', 'SaveCloudSettings', request, $2.Empty());
  $async.Future<CloudSettingsResponse> getCloudSettings(
          $pb.ClientContext? ctx, $2.Empty request) =>
      _client.invoke<CloudSettingsResponse>(ctx, 'BackupService',
          'GetCloudSettings', request, CloudSettingsResponse());
  $async.Future<TestConnectionResponse> testCloudConnection(
          $pb.ClientContext? ctx, TestConnectionRequest request) =>
      _client.invoke<TestConnectionResponse>(ctx, 'BackupService',
          'TestCloudConnection', request, TestConnectionResponse());
  $async.Future<BackupResponse> uploadToCloud(
          $pb.ClientContext? ctx, UploadRequest request) =>
      _client.invoke<BackupResponse>(
          ctx, 'BackupService', 'UploadToCloud', request, BackupResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
