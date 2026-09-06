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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/timestamp.pb.dart'
    as $2;

import '../../common/v1/pagination.pb.dart' as $3;
import 'sync.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'sync.pbenum.dart';

class SyncPayload extends $pb.GeneratedMessage {
  factory SyncPayload({
    $core.String? entityType,
    SyncOperation? operation,
    $core.List<$core.int>? payload,
    $fixnum.Int64? version,
    $core.String? deviceId,
    $core.String? entityId,
  }) {
    final result = create();
    if (entityType != null) result.entityType = entityType;
    if (operation != null) result.operation = operation;
    if (payload != null) result.payload = payload;
    if (version != null) result.version = version;
    if (deviceId != null) result.deviceId = deviceId;
    if (entityId != null) result.entityId = entityId;
    return result;
  }

  SyncPayload._();

  factory SyncPayload.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncPayload.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncPayload',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'entityType')
    ..aE<SyncOperation>(2, _omitFieldNames ? '' : 'operation',
        enumValues: SyncOperation.values)
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'payload', $pb.PbFieldType.OY)
    ..aInt64(4, _omitFieldNames ? '' : 'version')
    ..aOS(5, _omitFieldNames ? '' : 'deviceId')
    ..aOS(6, _omitFieldNames ? '' : 'entityId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncPayload clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncPayload copyWith(void Function(SyncPayload) updates) =>
      super.copyWith((message) => updates(message as SyncPayload))
          as SyncPayload;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncPayload create() => SyncPayload._();
  @$core.override
  SyncPayload createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncPayload getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncPayload>(create);
  static SyncPayload? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get entityType => $_getSZ(0);
  @$pb.TagNumber(1)
  set entityType($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEntityType() => $_has(0);
  @$pb.TagNumber(1)
  void clearEntityType() => $_clearField(1);

  @$pb.TagNumber(2)
  SyncOperation get operation => $_getN(1);
  @$pb.TagNumber(2)
  set operation(SyncOperation value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasOperation() => $_has(1);
  @$pb.TagNumber(2)
  void clearOperation() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get payload => $_getN(2);
  @$pb.TagNumber(3)
  set payload($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPayload() => $_has(2);
  @$pb.TagNumber(3)
  void clearPayload() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get version => $_getI64(3);
  @$pb.TagNumber(4)
  set version($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasVersion() => $_has(3);
  @$pb.TagNumber(4)
  void clearVersion() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get deviceId => $_getSZ(4);
  @$pb.TagNumber(5)
  set deviceId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDeviceId() => $_has(4);
  @$pb.TagNumber(5)
  void clearDeviceId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get entityId => $_getSZ(5);
  @$pb.TagNumber(6)
  set entityId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasEntityId() => $_has(5);
  @$pb.TagNumber(6)
  void clearEntityId() => $_clearField(6);
}

class RegisterDeviceRequest extends $pb.GeneratedMessage {
  factory RegisterDeviceRequest({
    $core.String? deviceName,
    $core.String? deviceId,
  }) {
    final result = create();
    if (deviceName != null) result.deviceName = deviceName;
    if (deviceId != null) result.deviceId = deviceId;
    return result;
  }

  RegisterDeviceRequest._();

  factory RegisterDeviceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterDeviceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterDeviceRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceName')
    ..aOS(2, _omitFieldNames ? '' : 'deviceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceRequest copyWith(
          void Function(RegisterDeviceRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterDeviceRequest))
          as RegisterDeviceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceRequest create() => RegisterDeviceRequest._();
  @$core.override
  RegisterDeviceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterDeviceRequest>(create);
  static RegisterDeviceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceName => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceName() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceName() => $_clearField(1);

  /// F17(ADR-1)stable device identity on the wire. Verified before adding:
  /// the handler previously read device_name only and hardcoded uuid.Nil
  /// (fresh server-generated id per call), and it does NOT read the
  /// x-client-id metadata the client already sends on every RPC — so a
  /// request field is the only way to make registration idempotent by
  /// client identity. Empty keeps the legacy server-generated path.
  @$pb.TagNumber(2)
  $core.String get deviceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDeviceId() => $_has(1);
  @$pb.TagNumber(2)
  void clearDeviceId() => $_clearField(2);
}

class RegisterDeviceResponse extends $pb.GeneratedMessage {
  factory RegisterDeviceResponse({
    $core.String? deviceId,
    $fixnum.Int64? lastSyncVersion,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (lastSyncVersion != null) result.lastSyncVersion = lastSyncVersion;
    return result;
  }

  RegisterDeviceResponse._();

  factory RegisterDeviceResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterDeviceResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterDeviceResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aInt64(2, _omitFieldNames ? '' : 'lastSyncVersion')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterDeviceResponse copyWith(
          void Function(RegisterDeviceResponse) updates) =>
      super.copyWith((message) => updates(message as RegisterDeviceResponse))
          as RegisterDeviceResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterDeviceResponse create() => RegisterDeviceResponse._();
  @$core.override
  RegisterDeviceResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterDeviceResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterDeviceResponse>(create);
  static RegisterDeviceResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get lastSyncVersion => $_getI64(1);
  @$pb.TagNumber(2)
  set lastSyncVersion($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLastSyncVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearLastSyncVersion() => $_clearField(2);
}

/// device_id is optional (proto3 empty string = default): empty requests the
/// tenant-aggregate view (log frontier + pending conflicts, no device row);
/// a non-empty device_id scopes the status to that registered device (F16).
class GetSyncStatusRequest extends $pb.GeneratedMessage {
  factory GetSyncStatusRequest({
    $core.String? deviceId,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    return result;
  }

  GetSyncStatusRequest._();

  factory GetSyncStatusRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetSyncStatusRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetSyncStatusRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSyncStatusRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetSyncStatusRequest copyWith(void Function(GetSyncStatusRequest) updates) =>
      super.copyWith((message) => updates(message as GetSyncStatusRequest))
          as GetSyncStatusRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetSyncStatusRequest create() => GetSyncStatusRequest._();
  @$core.override
  GetSyncStatusRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetSyncStatusRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetSyncStatusRequest>(create);
  static GetSyncStatusRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);
}

class SyncStatusResponse extends $pb.GeneratedMessage {
  factory SyncStatusResponse({
    $core.String? deviceId,
    $fixnum.Int64? lastSyncVersion,
    $2.Timestamp? lastSyncAt,
    $core.int? pendingConflicts,
  }) {
    final result = create();
    if (deviceId != null) result.deviceId = deviceId;
    if (lastSyncVersion != null) result.lastSyncVersion = lastSyncVersion;
    if (lastSyncAt != null) result.lastSyncAt = lastSyncAt;
    if (pendingConflicts != null) result.pendingConflicts = pendingConflicts;
    return result;
  }

  SyncStatusResponse._();

  factory SyncStatusResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncStatusResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncStatusResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'deviceId')
    ..aInt64(2, _omitFieldNames ? '' : 'lastSyncVersion')
    ..aOM<$2.Timestamp>(3, _omitFieldNames ? '' : 'lastSyncAt',
        subBuilder: $2.Timestamp.create)
    ..aI(4, _omitFieldNames ? '' : 'pendingConflicts')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncStatusResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncStatusResponse copyWith(void Function(SyncStatusResponse) updates) =>
      super.copyWith((message) => updates(message as SyncStatusResponse))
          as SyncStatusResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncStatusResponse create() => SyncStatusResponse._();
  @$core.override
  SyncStatusResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncStatusResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncStatusResponse>(create);
  static SyncStatusResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get deviceId => $_getSZ(0);
  @$pb.TagNumber(1)
  set deviceId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDeviceId() => $_has(0);
  @$pb.TagNumber(1)
  void clearDeviceId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get lastSyncVersion => $_getI64(1);
  @$pb.TagNumber(2)
  set lastSyncVersion($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLastSyncVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearLastSyncVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $2.Timestamp get lastSyncAt => $_getN(2);
  @$pb.TagNumber(3)
  set lastSyncAt($2.Timestamp value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasLastSyncAt() => $_has(2);
  @$pb.TagNumber(3)
  void clearLastSyncAt() => $_clearField(3);
  @$pb.TagNumber(3)
  $2.Timestamp ensureLastSyncAt() => $_ensure(2);

  @$pb.TagNumber(4)
  $core.int get pendingConflicts => $_getIZ(3);
  @$pb.TagNumber(4)
  set pendingConflicts($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPendingConflicts() => $_has(3);
  @$pb.TagNumber(4)
  void clearPendingConflicts() => $_clearField(4);
}

class PushChangesRequest extends $pb.GeneratedMessage {
  factory PushChangesRequest({
    $core.Iterable<SyncPayload>? changes,
  }) {
    final result = create();
    if (changes != null) result.changes.addAll(changes);
    return result;
  }

  PushChangesRequest._();

  factory PushChangesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PushChangesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PushChangesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..pPM<SyncPayload>(1, _omitFieldNames ? '' : 'changes',
        subBuilder: SyncPayload.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushChangesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushChangesRequest copyWith(void Function(PushChangesRequest) updates) =>
      super.copyWith((message) => updates(message as PushChangesRequest))
          as PushChangesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PushChangesRequest create() => PushChangesRequest._();
  @$core.override
  PushChangesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PushChangesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PushChangesRequest>(create);
  static PushChangesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SyncPayload> get changes => $_getList(0);
}

class PushResponse extends $pb.GeneratedMessage {
  factory PushResponse({
    $fixnum.Int64? syncedVersion,
    $core.Iterable<ConflictDTO>? conflicts,
  }) {
    final result = create();
    if (syncedVersion != null) result.syncedVersion = syncedVersion;
    if (conflicts != null) result.conflicts.addAll(conflicts);
    return result;
  }

  PushResponse._();

  factory PushResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PushResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PushResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'syncedVersion')
    ..pPM<ConflictDTO>(2, _omitFieldNames ? '' : 'conflicts',
        subBuilder: ConflictDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PushResponse copyWith(void Function(PushResponse) updates) =>
      super.copyWith((message) => updates(message as PushResponse))
          as PushResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PushResponse create() => PushResponse._();
  @$core.override
  PushResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PushResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PushResponse>(create);
  static PushResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get syncedVersion => $_getI64(0);
  @$pb.TagNumber(1)
  set syncedVersion($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSyncedVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearSyncedVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ConflictDTO> get conflicts => $_getList(1);
}

class PullChangesRequest extends $pb.GeneratedMessage {
  factory PullChangesRequest({
    $fixnum.Int64? sinceVersion,
    $core.Iterable<$core.String>? entityTypes,
    $core.int? pageSize,
  }) {
    final result = create();
    if (sinceVersion != null) result.sinceVersion = sinceVersion;
    if (entityTypes != null) result.entityTypes.addAll(entityTypes);
    if (pageSize != null) result.pageSize = pageSize;
    return result;
  }

  PullChangesRequest._();

  factory PullChangesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PullChangesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullChangesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'sinceVersion')
    ..pPS(2, _omitFieldNames ? '' : 'entityTypes')
    ..aI(3, _omitFieldNames ? '' : 'pageSize')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullChangesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullChangesRequest copyWith(void Function(PullChangesRequest) updates) =>
      super.copyWith((message) => updates(message as PullChangesRequest))
          as PullChangesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PullChangesRequest create() => PullChangesRequest._();
  @$core.override
  PullChangesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PullChangesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PullChangesRequest>(create);
  static PullChangesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get sinceVersion => $_getI64(0);
  @$pb.TagNumber(1)
  set sinceVersion($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSinceVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearSinceVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.String> get entityTypes => $_getList(1);

  @$pb.TagNumber(3)
  $core.int get pageSize => $_getIZ(2);
  @$pb.TagNumber(3)
  set pageSize($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPageSize() => $_has(2);
  @$pb.TagNumber(3)
  void clearPageSize() => $_clearField(3);
}

class PullChangesResponse extends $pb.GeneratedMessage {
  factory PullChangesResponse({
    $core.Iterable<SyncPayload>? changes,
    $fixnum.Int64? latestVersion,
    $core.bool? hasMore,
  }) {
    final result = create();
    if (changes != null) result.changes.addAll(changes);
    if (latestVersion != null) result.latestVersion = latestVersion;
    if (hasMore != null) result.hasMore = hasMore;
    return result;
  }

  PullChangesResponse._();

  factory PullChangesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PullChangesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PullChangesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..pPM<SyncPayload>(1, _omitFieldNames ? '' : 'changes',
        subBuilder: SyncPayload.create)
    ..aInt64(2, _omitFieldNames ? '' : 'latestVersion')
    ..aOB(3, _omitFieldNames ? '' : 'hasMore')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullChangesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PullChangesResponse copyWith(void Function(PullChangesResponse) updates) =>
      super.copyWith((message) => updates(message as PullChangesResponse))
          as PullChangesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PullChangesResponse create() => PullChangesResponse._();
  @$core.override
  PullChangesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PullChangesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PullChangesResponse>(create);
  static PullChangesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SyncPayload> get changes => $_getList(0);

  @$pb.TagNumber(2)
  $fixnum.Int64 get latestVersion => $_getI64(1);
  @$pb.TagNumber(2)
  set latestVersion($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLatestVersion() => $_has(1);
  @$pb.TagNumber(2)
  void clearLatestVersion() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get hasMore => $_getBF(2);
  @$pb.TagNumber(3)
  set hasMore($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasHasMore() => $_has(2);
  @$pb.TagNumber(3)
  void clearHasMore() => $_clearField(3);
}

class ConflictDTO extends $pb.GeneratedMessage {
  factory ConflictDTO({
    $core.String? id,
    $core.String? entityType,
    $core.String? entityId,
    $core.List<$core.int>? serverPayload,
    $core.List<$core.int>? clientPayload,
    $core.String? resolution,
    $core.String? conflictType,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (entityType != null) result.entityType = entityType;
    if (entityId != null) result.entityId = entityId;
    if (serverPayload != null) result.serverPayload = serverPayload;
    if (clientPayload != null) result.clientPayload = clientPayload;
    if (resolution != null) result.resolution = resolution;
    if (conflictType != null) result.conflictType = conflictType;
    return result;
  }

  ConflictDTO._();

  factory ConflictDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ConflictDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ConflictDTO',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'entityType')
    ..aOS(3, _omitFieldNames ? '' : 'entityId')
    ..a<$core.List<$core.int>>(
        4, _omitFieldNames ? '' : 'serverPayload', $pb.PbFieldType.OY)
    ..a<$core.List<$core.int>>(
        5, _omitFieldNames ? '' : 'clientPayload', $pb.PbFieldType.OY)
    ..aOS(6, _omitFieldNames ? '' : 'resolution')
    ..aOS(7, _omitFieldNames ? '' : 'conflictType')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConflictDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ConflictDTO copyWith(void Function(ConflictDTO) updates) =>
      super.copyWith((message) => updates(message as ConflictDTO))
          as ConflictDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ConflictDTO create() => ConflictDTO._();
  @$core.override
  ConflictDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ConflictDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ConflictDTO>(create);
  static ConflictDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get entityType => $_getSZ(1);
  @$pb.TagNumber(2)
  set entityType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEntityType() => $_has(1);
  @$pb.TagNumber(2)
  void clearEntityType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get entityId => $_getSZ(2);
  @$pb.TagNumber(3)
  set entityId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEntityId() => $_has(2);
  @$pb.TagNumber(3)
  void clearEntityId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get serverPayload => $_getN(3);
  @$pb.TagNumber(4)
  set serverPayload($core.List<$core.int> value) => $_setBytes(3, value);
  @$pb.TagNumber(4)
  $core.bool hasServerPayload() => $_has(3);
  @$pb.TagNumber(4)
  void clearServerPayload() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get clientPayload => $_getN(4);
  @$pb.TagNumber(5)
  set clientPayload($core.List<$core.int> value) => $_setBytes(4, value);
  @$pb.TagNumber(5)
  $core.bool hasClientPayload() => $_has(4);
  @$pb.TagNumber(5)
  void clearClientPayload() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get resolution => $_getSZ(5);
  @$pb.TagNumber(6)
  set resolution($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasResolution() => $_has(5);
  @$pb.TagNumber(6)
  void clearResolution() => $_clearField(6);

  /// F16: conflict classification. Value domain today: "version_conflict"
  /// (an UPDATE whose payload version was not ahead of the server row);
  /// finer-grained classes arrive with F18. Non-breaking string field.
  @$pb.TagNumber(7)
  $core.String get conflictType => $_getSZ(6);
  @$pb.TagNumber(7)
  set conflictType($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasConflictType() => $_has(6);
  @$pb.TagNumber(7)
  void clearConflictType() => $_clearField(7);
}

class ResolveConflictRequest extends $pb.GeneratedMessage {
  factory ResolveConflictRequest({
    $core.String? conflictId,
    $core.String? resolution,
    $core.List<$core.int>? mergedPayload,
  }) {
    final result = create();
    if (conflictId != null) result.conflictId = conflictId;
    if (resolution != null) result.resolution = resolution;
    if (mergedPayload != null) result.mergedPayload = mergedPayload;
    return result;
  }

  ResolveConflictRequest._();

  factory ResolveConflictRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResolveConflictRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResolveConflictRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'conflictId')
    ..aOS(2, _omitFieldNames ? '' : 'resolution')
    ..a<$core.List<$core.int>>(
        3, _omitFieldNames ? '' : 'mergedPayload', $pb.PbFieldType.OY)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveConflictRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResolveConflictRequest copyWith(
          void Function(ResolveConflictRequest) updates) =>
      super.copyWith((message) => updates(message as ResolveConflictRequest))
          as ResolveConflictRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResolveConflictRequest create() => ResolveConflictRequest._();
  @$core.override
  ResolveConflictRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResolveConflictRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResolveConflictRequest>(create);
  static ResolveConflictRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get conflictId => $_getSZ(0);
  @$pb.TagNumber(1)
  set conflictId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasConflictId() => $_has(0);
  @$pb.TagNumber(1)
  void clearConflictId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get resolution => $_getSZ(1);
  @$pb.TagNumber(2)
  set resolution($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasResolution() => $_has(1);
  @$pb.TagNumber(2)
  void clearResolution() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get mergedPayload => $_getN(2);
  @$pb.TagNumber(3)
  set mergedPayload($core.List<$core.int> value) => $_setBytes(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMergedPayload() => $_has(2);
  @$pb.TagNumber(3)
  void clearMergedPayload() => $_clearField(3);
}

class ListConflictsRequest extends $pb.GeneratedMessage {
  factory ListConflictsRequest({
    $3.PageRequest? page,
  }) {
    final result = create();
    if (page != null) result.page = page;
    return result;
  }

  ListConflictsRequest._();

  factory ListConflictsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListConflictsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListConflictsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..aOM<$3.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListConflictsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListConflictsRequest copyWith(void Function(ListConflictsRequest) updates) =>
      super.copyWith((message) => updates(message as ListConflictsRequest))
          as ListConflictsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListConflictsRequest create() => ListConflictsRequest._();
  @$core.override
  ListConflictsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListConflictsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListConflictsRequest>(create);
  static ListConflictsRequest? _defaultInstance;

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
}

class ListConflictsResponse extends $pb.GeneratedMessage {
  factory ListConflictsResponse({
    $core.Iterable<ConflictDTO>? conflicts,
    $3.PageResponse? page,
  }) {
    final result = create();
    if (conflicts != null) result.conflicts.addAll(conflicts);
    if (page != null) result.page = page;
    return result;
  }

  ListConflictsResponse._();

  factory ListConflictsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListConflictsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListConflictsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.sync.v1'),
      createEmptyInstance: create)
    ..pPM<ConflictDTO>(1, _omitFieldNames ? '' : 'conflicts',
        subBuilder: ConflictDTO.create)
    ..aOM<$3.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListConflictsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListConflictsResponse copyWith(
          void Function(ListConflictsResponse) updates) =>
      super.copyWith((message) => updates(message as ListConflictsResponse))
          as ListConflictsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListConflictsResponse create() => ListConflictsResponse._();
  @$core.override
  ListConflictsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListConflictsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListConflictsResponse>(create);
  static ListConflictsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ConflictDTO> get conflicts => $_getList(0);

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

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
