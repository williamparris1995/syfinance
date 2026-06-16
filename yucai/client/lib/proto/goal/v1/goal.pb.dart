// This is a generated file - do not edit.
//
// Generated from goal/v1/goal.proto.

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
import 'goal.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'goal.pbenum.dart';

class GoalDTO extends $pb.GeneratedMessage {
  factory GoalDTO({
    $core.String? id,
    $core.String? name,
    GoalType? goalType,
    $fixnum.Int64? targetAmountCents,
    $fixnum.Int64? currentAmountCents,
    $core.String? currencyCode,
    $0.Timestamp? deadline,
    $core.String? linkedAccountId,
    $core.String? notes,
    $core.bool? isCompleted,
    $0.Timestamp? completedAt,
    $core.double? progressPct,
    $fixnum.Int64? remainingCents,
    $fixnum.Int64? version,
    $0.Timestamp? createdAt,
    $0.Timestamp? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (goalType != null) result.goalType = goalType;
    if (targetAmountCents != null) result.targetAmountCents = targetAmountCents;
    if (currentAmountCents != null)
      result.currentAmountCents = currentAmountCents;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (deadline != null) result.deadline = deadline;
    if (linkedAccountId != null) result.linkedAccountId = linkedAccountId;
    if (notes != null) result.notes = notes;
    if (isCompleted != null) result.isCompleted = isCompleted;
    if (completedAt != null) result.completedAt = completedAt;
    if (progressPct != null) result.progressPct = progressPct;
    if (remainingCents != null) result.remainingCents = remainingCents;
    if (version != null) result.version = version;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  GoalDTO._();

  factory GoalDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GoalDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GoalDTO',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<GoalType>(3, _omitFieldNames ? '' : 'goalType',
        enumValues: GoalType.values)
    ..aInt64(4, _omitFieldNames ? '' : 'targetAmountCents')
    ..aInt64(5, _omitFieldNames ? '' : 'currentAmountCents')
    ..aOS(6, _omitFieldNames ? '' : 'currencyCode')
    ..aOM<$0.Timestamp>(7, _omitFieldNames ? '' : 'deadline',
        subBuilder: $0.Timestamp.create)
    ..aOS(8, _omitFieldNames ? '' : 'linkedAccountId')
    ..aOS(9, _omitFieldNames ? '' : 'notes')
    ..aOB(10, _omitFieldNames ? '' : 'isCompleted')
    ..aOM<$0.Timestamp>(11, _omitFieldNames ? '' : 'completedAt',
        subBuilder: $0.Timestamp.create)
    ..aD(12, _omitFieldNames ? '' : 'progressPct')
    ..aInt64(13, _omitFieldNames ? '' : 'remainingCents')
    ..aInt64(14, _omitFieldNames ? '' : 'version')
    ..aOM<$0.Timestamp>(15, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $0.Timestamp.create)
    ..aOM<$0.Timestamp>(16, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $0.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoalDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoalDTO copyWith(void Function(GoalDTO) updates) =>
      super.copyWith((message) => updates(message as GoalDTO)) as GoalDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GoalDTO create() => GoalDTO._();
  @$core.override
  GoalDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GoalDTO getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<GoalDTO>(create);
  static GoalDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  GoalType get goalType => $_getN(2);
  @$pb.TagNumber(3)
  set goalType(GoalType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasGoalType() => $_has(2);
  @$pb.TagNumber(3)
  void clearGoalType() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get targetAmountCents => $_getI64(3);
  @$pb.TagNumber(4)
  set targetAmountCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTargetAmountCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearTargetAmountCents() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get currentAmountCents => $_getI64(4);
  @$pb.TagNumber(5)
  set currentAmountCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCurrentAmountCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearCurrentAmountCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get currencyCode => $_getSZ(5);
  @$pb.TagNumber(6)
  set currencyCode($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrencyCode() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrencyCode() => $_clearField(6);

  @$pb.TagNumber(7)
  $0.Timestamp get deadline => $_getN(6);
  @$pb.TagNumber(7)
  set deadline($0.Timestamp value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasDeadline() => $_has(6);
  @$pb.TagNumber(7)
  void clearDeadline() => $_clearField(7);
  @$pb.TagNumber(7)
  $0.Timestamp ensureDeadline() => $_ensure(6);

  @$pb.TagNumber(8)
  $core.String get linkedAccountId => $_getSZ(7);
  @$pb.TagNumber(8)
  set linkedAccountId($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasLinkedAccountId() => $_has(7);
  @$pb.TagNumber(8)
  void clearLinkedAccountId() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get notes => $_getSZ(8);
  @$pb.TagNumber(9)
  set notes($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasNotes() => $_has(8);
  @$pb.TagNumber(9)
  void clearNotes() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get isCompleted => $_getBF(9);
  @$pb.TagNumber(10)
  set isCompleted($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasIsCompleted() => $_has(9);
  @$pb.TagNumber(10)
  void clearIsCompleted() => $_clearField(10);

  @$pb.TagNumber(11)
  $0.Timestamp get completedAt => $_getN(10);
  @$pb.TagNumber(11)
  set completedAt($0.Timestamp value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCompletedAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearCompletedAt() => $_clearField(11);
  @$pb.TagNumber(11)
  $0.Timestamp ensureCompletedAt() => $_ensure(10);

  @$pb.TagNumber(12)
  $core.double get progressPct => $_getN(11);
  @$pb.TagNumber(12)
  set progressPct($core.double value) => $_setDouble(11, value);
  @$pb.TagNumber(12)
  $core.bool hasProgressPct() => $_has(11);
  @$pb.TagNumber(12)
  void clearProgressPct() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get remainingCents => $_getI64(12);
  @$pb.TagNumber(13)
  set remainingCents($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasRemainingCents() => $_has(12);
  @$pb.TagNumber(13)
  void clearRemainingCents() => $_clearField(13);

  @$pb.TagNumber(14)
  $fixnum.Int64 get version => $_getI64(13);
  @$pb.TagNumber(14)
  set version($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasVersion() => $_has(13);
  @$pb.TagNumber(14)
  void clearVersion() => $_clearField(14);

  @$pb.TagNumber(15)
  $0.Timestamp get createdAt => $_getN(14);
  @$pb.TagNumber(15)
  set createdAt($0.Timestamp value) => $_setField(15, value);
  @$pb.TagNumber(15)
  $core.bool hasCreatedAt() => $_has(14);
  @$pb.TagNumber(15)
  void clearCreatedAt() => $_clearField(15);
  @$pb.TagNumber(15)
  $0.Timestamp ensureCreatedAt() => $_ensure(14);

  @$pb.TagNumber(16)
  $0.Timestamp get updatedAt => $_getN(15);
  @$pb.TagNumber(16)
  set updatedAt($0.Timestamp value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasUpdatedAt() => $_has(15);
  @$pb.TagNumber(16)
  void clearUpdatedAt() => $_clearField(16);
  @$pb.TagNumber(16)
  $0.Timestamp ensureUpdatedAt() => $_ensure(15);
}

class CreateGoalRequest extends $pb.GeneratedMessage {
  factory CreateGoalRequest({
    $core.String? name,
    GoalType? goalType,
    $fixnum.Int64? targetAmountCents,
    $core.String? currencyCode,
    $core.String? deadline,
    $core.String? linkedAccountId,
    $core.String? notes,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (goalType != null) result.goalType = goalType;
    if (targetAmountCents != null) result.targetAmountCents = targetAmountCents;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (deadline != null) result.deadline = deadline;
    if (linkedAccountId != null) result.linkedAccountId = linkedAccountId;
    if (notes != null) result.notes = notes;
    return result;
  }

  CreateGoalRequest._();

  factory CreateGoalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateGoalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateGoalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aE<GoalType>(2, _omitFieldNames ? '' : 'goalType',
        enumValues: GoalType.values)
    ..aInt64(3, _omitFieldNames ? '' : 'targetAmountCents')
    ..aOS(4, _omitFieldNames ? '' : 'currencyCode')
    ..aOS(5, _omitFieldNames ? '' : 'deadline')
    ..aOS(6, _omitFieldNames ? '' : 'linkedAccountId')
    ..aOS(7, _omitFieldNames ? '' : 'notes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateGoalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateGoalRequest copyWith(void Function(CreateGoalRequest) updates) =>
      super.copyWith((message) => updates(message as CreateGoalRequest))
          as CreateGoalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateGoalRequest create() => CreateGoalRequest._();
  @$core.override
  CreateGoalRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateGoalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateGoalRequest>(create);
  static CreateGoalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  GoalType get goalType => $_getN(1);
  @$pb.TagNumber(2)
  set goalType(GoalType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasGoalType() => $_has(1);
  @$pb.TagNumber(2)
  void clearGoalType() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get targetAmountCents => $_getI64(2);
  @$pb.TagNumber(3)
  set targetAmountCents($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTargetAmountCents() => $_has(2);
  @$pb.TagNumber(3)
  void clearTargetAmountCents() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get currencyCode => $_getSZ(3);
  @$pb.TagNumber(4)
  set currencyCode($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrencyCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrencyCode() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get deadline => $_getSZ(4);
  @$pb.TagNumber(5)
  set deadline($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDeadline() => $_has(4);
  @$pb.TagNumber(5)
  void clearDeadline() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get linkedAccountId => $_getSZ(5);
  @$pb.TagNumber(6)
  set linkedAccountId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLinkedAccountId() => $_has(5);
  @$pb.TagNumber(6)
  void clearLinkedAccountId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get notes => $_getSZ(6);
  @$pb.TagNumber(7)
  set notes($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNotes() => $_has(6);
  @$pb.TagNumber(7)
  void clearNotes() => $_clearField(7);
}

class UpdateGoalRequest extends $pb.GeneratedMessage {
  factory UpdateGoalRequest({
    $core.String? id,
    $core.String? name,
    $fixnum.Int64? targetAmountCents,
    $core.String? deadline,
    $core.String? notes,
    $fixnum.Int64? version,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (targetAmountCents != null) result.targetAmountCents = targetAmountCents;
    if (deadline != null) result.deadline = deadline;
    if (notes != null) result.notes = notes;
    if (version != null) result.version = version;
    return result;
  }

  UpdateGoalRequest._();

  factory UpdateGoalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateGoalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateGoalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aInt64(3, _omitFieldNames ? '' : 'targetAmountCents')
    ..aOS(4, _omitFieldNames ? '' : 'deadline')
    ..aOS(5, _omitFieldNames ? '' : 'notes')
    ..aInt64(6, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateGoalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateGoalRequest copyWith(void Function(UpdateGoalRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateGoalRequest))
          as UpdateGoalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateGoalRequest create() => UpdateGoalRequest._();
  @$core.override
  UpdateGoalRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateGoalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateGoalRequest>(create);
  static UpdateGoalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get targetAmountCents => $_getI64(2);
  @$pb.TagNumber(3)
  set targetAmountCents($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTargetAmountCents() => $_has(2);
  @$pb.TagNumber(3)
  void clearTargetAmountCents() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get deadline => $_getSZ(3);
  @$pb.TagNumber(4)
  set deadline($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDeadline() => $_has(3);
  @$pb.TagNumber(4)
  void clearDeadline() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get notes => $_getSZ(4);
  @$pb.TagNumber(5)
  set notes($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNotes() => $_has(4);
  @$pb.TagNumber(5)
  void clearNotes() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get version => $_getI64(5);
  @$pb.TagNumber(6)
  set version($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearVersion() => $_clearField(6);
}

class UpdateProgressRequest extends $pb.GeneratedMessage {
  factory UpdateProgressRequest({
    $core.String? id,
    $fixnum.Int64? amountCents,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (amountCents != null) result.amountCents = amountCents;
    return result;
  }

  UpdateProgressRequest._();

  factory UpdateProgressRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateProgressRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateProgressRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aInt64(2, _omitFieldNames ? '' : 'amountCents')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateProgressRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateProgressRequest copyWith(
          void Function(UpdateProgressRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateProgressRequest))
          as UpdateProgressRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateProgressRequest create() => UpdateProgressRequest._();
  @$core.override
  UpdateProgressRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateProgressRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateProgressRequest>(create);
  static UpdateProgressRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get amountCents => $_getI64(1);
  @$pb.TagNumber(2)
  set amountCents($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAmountCents() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmountCents() => $_clearField(2);
}

class CompleteGoalRequest extends $pb.GeneratedMessage {
  factory CompleteGoalRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  CompleteGoalRequest._();

  factory CompleteGoalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CompleteGoalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CompleteGoalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteGoalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CompleteGoalRequest copyWith(void Function(CompleteGoalRequest) updates) =>
      super.copyWith((message) => updates(message as CompleteGoalRequest))
          as CompleteGoalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CompleteGoalRequest create() => CompleteGoalRequest._();
  @$core.override
  CompleteGoalRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CompleteGoalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CompleteGoalRequest>(create);
  static CompleteGoalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class DeleteGoalRequest extends $pb.GeneratedMessage {
  factory DeleteGoalRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteGoalRequest._();

  factory DeleteGoalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteGoalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteGoalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteGoalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteGoalRequest copyWith(void Function(DeleteGoalRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteGoalRequest))
          as DeleteGoalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteGoalRequest create() => DeleteGoalRequest._();
  @$core.override
  DeleteGoalRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteGoalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteGoalRequest>(create);
  static DeleteGoalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class SyncGoalProgressRequest extends $pb.GeneratedMessage {
  factory SyncGoalProgressRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  SyncGoalProgressRequest._();

  factory SyncGoalProgressRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SyncGoalProgressRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SyncGoalProgressRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncGoalProgressRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SyncGoalProgressRequest copyWith(
          void Function(SyncGoalProgressRequest) updates) =>
      super.copyWith((message) => updates(message as SyncGoalProgressRequest))
          as SyncGoalProgressRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SyncGoalProgressRequest create() => SyncGoalProgressRequest._();
  @$core.override
  SyncGoalProgressRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SyncGoalProgressRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SyncGoalProgressRequest>(create);
  static SyncGoalProgressRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class GetGoalRequest extends $pb.GeneratedMessage {
  factory GetGoalRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetGoalRequest._();

  factory GetGoalRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetGoalRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetGoalRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGoalRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetGoalRequest copyWith(void Function(GetGoalRequest) updates) =>
      super.copyWith((message) => updates(message as GetGoalRequest))
          as GetGoalRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetGoalRequest create() => GetGoalRequest._();
  @$core.override
  GetGoalRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetGoalRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetGoalRequest>(create);
  static GetGoalRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class ListGoalsRequest extends $pb.GeneratedMessage {
  factory ListGoalsRequest({
    $1.PageRequest? page,
    $core.bool? completed,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (completed != null) result.completed = completed;
    return result;
  }

  ListGoalsRequest._();

  factory ListGoalsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListGoalsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGoalsRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOM<$1.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageRequest.create)
    ..aOB(2, _omitFieldNames ? '' : 'completed')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGoalsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGoalsRequest copyWith(void Function(ListGoalsRequest) updates) =>
      super.copyWith((message) => updates(message as ListGoalsRequest))
          as ListGoalsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListGoalsRequest create() => ListGoalsRequest._();
  @$core.override
  ListGoalsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListGoalsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListGoalsRequest>(create);
  static ListGoalsRequest? _defaultInstance;

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
  $core.bool get completed => $_getBF(1);
  @$pb.TagNumber(2)
  set completed($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCompleted() => $_has(1);
  @$pb.TagNumber(2)
  void clearCompleted() => $_clearField(2);
}

class ListGoalsResponse extends $pb.GeneratedMessage {
  factory ListGoalsResponse({
    $core.Iterable<GoalDTO>? goals,
    $1.PageResponse? page,
  }) {
    final result = create();
    if (goals != null) result.goals.addAll(goals);
    if (page != null) result.page = page;
    return result;
  }

  ListGoalsResponse._();

  factory ListGoalsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListGoalsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListGoalsResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..pPM<GoalDTO>(1, _omitFieldNames ? '' : 'goals',
        subBuilder: GoalDTO.create)
    ..aOM<$1.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGoalsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListGoalsResponse copyWith(void Function(ListGoalsResponse) updates) =>
      super.copyWith((message) => updates(message as ListGoalsResponse))
          as ListGoalsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListGoalsResponse create() => ListGoalsResponse._();
  @$core.override
  ListGoalsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListGoalsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListGoalsResponse>(create);
  static ListGoalsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<GoalDTO> get goals => $_getList(0);

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

class GoalResponse extends $pb.GeneratedMessage {
  factory GoalResponse({
    GoalDTO? goal,
  }) {
    final result = create();
    if (goal != null) result.goal = goal;
    return result;
  }

  GoalResponse._();

  factory GoalResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GoalResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GoalResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOM<GoalDTO>(1, _omitFieldNames ? '' : 'goal', subBuilder: GoalDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoalResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoalResponse copyWith(void Function(GoalResponse) updates) =>
      super.copyWith((message) => updates(message as GoalResponse))
          as GoalResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GoalResponse create() => GoalResponse._();
  @$core.override
  GoalResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GoalResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GoalResponse>(create);
  static GoalResponse? _defaultInstance;

  @$pb.TagNumber(1)
  GoalDTO get goal => $_getN(0);
  @$pb.TagNumber(1)
  set goal(GoalDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasGoal() => $_has(0);
  @$pb.TagNumber(1)
  void clearGoal() => $_clearField(1);
  @$pb.TagNumber(1)
  GoalDTO ensureGoal() => $_ensure(0);
}

class GoalDetailResponse extends $pb.GeneratedMessage {
  factory GoalDetailResponse({
    GoalDTO? goal,
  }) {
    final result = create();
    if (goal != null) result.goal = goal;
    return result;
  }

  GoalDetailResponse._();

  factory GoalDetailResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GoalDetailResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GoalDetailResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.goal.v1'),
      createEmptyInstance: create)
    ..aOM<GoalDTO>(1, _omitFieldNames ? '' : 'goal', subBuilder: GoalDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoalDetailResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GoalDetailResponse copyWith(void Function(GoalDetailResponse) updates) =>
      super.copyWith((message) => updates(message as GoalDetailResponse))
          as GoalDetailResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GoalDetailResponse create() => GoalDetailResponse._();
  @$core.override
  GoalDetailResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GoalDetailResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GoalDetailResponse>(create);
  static GoalDetailResponse? _defaultInstance;

  @$pb.TagNumber(1)
  GoalDTO get goal => $_getN(0);
  @$pb.TagNumber(1)
  set goal(GoalDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasGoal() => $_has(0);
  @$pb.TagNumber(1)
  void clearGoal() => $_clearField(1);
  @$pb.TagNumber(1)
  GoalDTO ensureGoal() => $_ensure(0);
}

class GoalServiceApi {
  final $pb.RpcClient _client;

  GoalServiceApi(this._client);

  $async.Future<GoalResponse> createGoal(
          $pb.ClientContext? ctx, CreateGoalRequest request) =>
      _client.invoke<GoalResponse>(
          ctx, 'GoalService', 'CreateGoal', request, GoalResponse());
  $async.Future<GoalResponse> updateGoal(
          $pb.ClientContext? ctx, UpdateGoalRequest request) =>
      _client.invoke<GoalResponse>(
          ctx, 'GoalService', 'UpdateGoal', request, GoalResponse());
  $async.Future<GoalResponse> updateGoalProgress(
          $pb.ClientContext? ctx, UpdateProgressRequest request) =>
      _client.invoke<GoalResponse>(
          ctx, 'GoalService', 'UpdateGoalProgress', request, GoalResponse());
  $async.Future<$2.Empty> completeGoal(
          $pb.ClientContext? ctx, CompleteGoalRequest request) =>
      _client.invoke<$2.Empty>(
          ctx, 'GoalService', 'CompleteGoal', request, $2.Empty());
  $async.Future<$2.Empty> deleteGoal(
          $pb.ClientContext? ctx, DeleteGoalRequest request) =>
      _client.invoke<$2.Empty>(
          ctx, 'GoalService', 'DeleteGoal', request, $2.Empty());
  $async.Future<GoalResponse> syncGoalProgress(
          $pb.ClientContext? ctx, SyncGoalProgressRequest request) =>
      _client.invoke<GoalResponse>(
          ctx, 'GoalService', 'SyncGoalProgress', request, GoalResponse());
  $async.Future<GoalDetailResponse> getGoal(
          $pb.ClientContext? ctx, GetGoalRequest request) =>
      _client.invoke<GoalDetailResponse>(
          ctx, 'GoalService', 'GetGoal', request, GoalDetailResponse());
  $async.Future<ListGoalsResponse> listGoals(
          $pb.ClientContext? ctx, ListGoalsRequest request) =>
      _client.invoke<ListGoalsResponse>(
          ctx, 'GoalService', 'ListGoals', request, ListGoalsResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
