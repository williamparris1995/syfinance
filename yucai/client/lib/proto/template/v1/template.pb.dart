// This is a generated file - do not edit.
//
// Generated from template/v1/template.proto.

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
import 'template.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'template.pbenum.dart';

class TemplateDTO extends $pb.GeneratedMessage {
  factory TemplateDTO({
    $core.String? id,
    $core.String? name,
    $core.String? description,
    $fixnum.Int64? amountCents,
    TemplateDirection? direction,
    $core.String? sourceAccountId,
    $core.String? destinationAccountId,
    TemplateCycle? cycle,
    $core.int? cycleDays,
    $core.int? billingDay,
    $core.String? nextDate,
    $core.String? startDate,
    $core.String? endDate,
    $core.bool? autoRecord,
    $core.bool? paused,
    $core.String? lastTransactionId,
    $core.String? category,
    $fixnum.Int64? version,
    $0.Timestamp? createdAt,
    $0.Timestamp? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (amountCents != null) result.amountCents = amountCents;
    if (direction != null) result.direction = direction;
    if (sourceAccountId != null) result.sourceAccountId = sourceAccountId;
    if (destinationAccountId != null)
      result.destinationAccountId = destinationAccountId;
    if (cycle != null) result.cycle = cycle;
    if (cycleDays != null) result.cycleDays = cycleDays;
    if (billingDay != null) result.billingDay = billingDay;
    if (nextDate != null) result.nextDate = nextDate;
    if (startDate != null) result.startDate = startDate;
    if (endDate != null) result.endDate = endDate;
    if (autoRecord != null) result.autoRecord = autoRecord;
    if (paused != null) result.paused = paused;
    if (lastTransactionId != null) result.lastTransactionId = lastTransactionId;
    if (category != null) result.category = category;
    if (version != null) result.version = version;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  TemplateDTO._();

  factory TemplateDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TemplateDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TemplateDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aInt64(4, _omitFieldNames ? '' : 'amountCents')
    ..aE<TemplateDirection>(5, _omitFieldNames ? '' : 'direction',
        enumValues: TemplateDirection.values)
    ..aOS(6, _omitFieldNames ? '' : 'sourceAccountId')
    ..aOS(7, _omitFieldNames ? '' : 'destinationAccountId')
    ..aE<TemplateCycle>(8, _omitFieldNames ? '' : 'cycle',
        enumValues: TemplateCycle.values)
    ..aI(9, _omitFieldNames ? '' : 'cycleDays')
    ..aI(10, _omitFieldNames ? '' : 'billingDay')
    ..aOS(11, _omitFieldNames ? '' : 'nextDate')
    ..aOS(12, _omitFieldNames ? '' : 'startDate')
    ..aOS(13, _omitFieldNames ? '' : 'endDate')
    ..aOB(14, _omitFieldNames ? '' : 'autoRecord')
    ..aOB(15, _omitFieldNames ? '' : 'paused')
    ..aOS(16, _omitFieldNames ? '' : 'lastTransactionId')
    ..aOS(17, _omitFieldNames ? '' : 'category')
    ..aInt64(18, _omitFieldNames ? '' : 'version')
    ..aOM<$0.Timestamp>(19, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $0.Timestamp.create)
    ..aOM<$0.Timestamp>(20, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $0.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TemplateDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TemplateDTO copyWith(void Function(TemplateDTO) updates) =>
      super.copyWith((message) => updates(message as TemplateDTO))
          as TemplateDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TemplateDTO create() => TemplateDTO._();
  @$core.override
  TemplateDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TemplateDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TemplateDTO>(create);
  static TemplateDTO? _defaultInstance;

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
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get amountCents => $_getI64(3);
  @$pb.TagNumber(4)
  set amountCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAmountCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmountCents() => $_clearField(4);

  @$pb.TagNumber(5)
  TemplateDirection get direction => $_getN(4);
  @$pb.TagNumber(5)
  set direction(TemplateDirection value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDirection() => $_has(4);
  @$pb.TagNumber(5)
  void clearDirection() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get sourceAccountId => $_getSZ(5);
  @$pb.TagNumber(6)
  set sourceAccountId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSourceAccountId() => $_has(5);
  @$pb.TagNumber(6)
  void clearSourceAccountId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get destinationAccountId => $_getSZ(6);
  @$pb.TagNumber(7)
  set destinationAccountId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasDestinationAccountId() => $_has(6);
  @$pb.TagNumber(7)
  void clearDestinationAccountId() => $_clearField(7);

  @$pb.TagNumber(8)
  TemplateCycle get cycle => $_getN(7);
  @$pb.TagNumber(8)
  set cycle(TemplateCycle value) => $_setField(8, value);
  @$pb.TagNumber(8)
  $core.bool hasCycle() => $_has(7);
  @$pb.TagNumber(8)
  void clearCycle() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get cycleDays => $_getIZ(8);
  @$pb.TagNumber(9)
  set cycleDays($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasCycleDays() => $_has(8);
  @$pb.TagNumber(9)
  void clearCycleDays() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get billingDay => $_getIZ(9);
  @$pb.TagNumber(10)
  set billingDay($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasBillingDay() => $_has(9);
  @$pb.TagNumber(10)
  void clearBillingDay() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get nextDate => $_getSZ(10);
  @$pb.TagNumber(11)
  set nextDate($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasNextDate() => $_has(10);
  @$pb.TagNumber(11)
  void clearNextDate() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get startDate => $_getSZ(11);
  @$pb.TagNumber(12)
  set startDate($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasStartDate() => $_has(11);
  @$pb.TagNumber(12)
  void clearStartDate() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get endDate => $_getSZ(12);
  @$pb.TagNumber(13)
  set endDate($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasEndDate() => $_has(12);
  @$pb.TagNumber(13)
  void clearEndDate() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.bool get autoRecord => $_getBF(13);
  @$pb.TagNumber(14)
  set autoRecord($core.bool value) => $_setBool(13, value);
  @$pb.TagNumber(14)
  $core.bool hasAutoRecord() => $_has(13);
  @$pb.TagNumber(14)
  void clearAutoRecord() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.bool get paused => $_getBF(14);
  @$pb.TagNumber(15)
  set paused($core.bool value) => $_setBool(14, value);
  @$pb.TagNumber(15)
  $core.bool hasPaused() => $_has(14);
  @$pb.TagNumber(15)
  void clearPaused() => $_clearField(15);

  @$pb.TagNumber(16)
  $core.String get lastTransactionId => $_getSZ(15);
  @$pb.TagNumber(16)
  set lastTransactionId($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasLastTransactionId() => $_has(15);
  @$pb.TagNumber(16)
  void clearLastTransactionId() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.String get category => $_getSZ(16);
  @$pb.TagNumber(17)
  set category($core.String value) => $_setString(16, value);
  @$pb.TagNumber(17)
  $core.bool hasCategory() => $_has(16);
  @$pb.TagNumber(17)
  void clearCategory() => $_clearField(17);

  @$pb.TagNumber(18)
  $fixnum.Int64 get version => $_getI64(17);
  @$pb.TagNumber(18)
  set version($fixnum.Int64 value) => $_setInt64(17, value);
  @$pb.TagNumber(18)
  $core.bool hasVersion() => $_has(17);
  @$pb.TagNumber(18)
  void clearVersion() => $_clearField(18);

  @$pb.TagNumber(19)
  $0.Timestamp get createdAt => $_getN(18);
  @$pb.TagNumber(19)
  set createdAt($0.Timestamp value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasCreatedAt() => $_has(18);
  @$pb.TagNumber(19)
  void clearCreatedAt() => $_clearField(19);
  @$pb.TagNumber(19)
  $0.Timestamp ensureCreatedAt() => $_ensure(18);

  @$pb.TagNumber(20)
  $0.Timestamp get updatedAt => $_getN(19);
  @$pb.TagNumber(20)
  set updatedAt($0.Timestamp value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasUpdatedAt() => $_has(19);
  @$pb.TagNumber(20)
  void clearUpdatedAt() => $_clearField(20);
  @$pb.TagNumber(20)
  $0.Timestamp ensureUpdatedAt() => $_ensure(19);
}

class CreateTemplateRequest extends $pb.GeneratedMessage {
  factory CreateTemplateRequest({
    $core.String? name,
    $core.String? description,
    $fixnum.Int64? amountCents,
    TemplateDirection? direction,
    $core.String? sourceAccountId,
    $core.String? destinationAccountId,
    TemplateCycle? cycle,
    $core.int? cycleDays,
    $core.int? billingDay,
    $core.String? startDate,
    $core.String? endDate,
    $core.bool? autoRecord,
    $core.String? category,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (amountCents != null) result.amountCents = amountCents;
    if (direction != null) result.direction = direction;
    if (sourceAccountId != null) result.sourceAccountId = sourceAccountId;
    if (destinationAccountId != null)
      result.destinationAccountId = destinationAccountId;
    if (cycle != null) result.cycle = cycle;
    if (cycleDays != null) result.cycleDays = cycleDays;
    if (billingDay != null) result.billingDay = billingDay;
    if (startDate != null) result.startDate = startDate;
    if (endDate != null) result.endDate = endDate;
    if (autoRecord != null) result.autoRecord = autoRecord;
    if (category != null) result.category = category;
    return result;
  }

  CreateTemplateRequest._();

  factory CreateTemplateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateTemplateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateTemplateRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'description')
    ..aInt64(3, _omitFieldNames ? '' : 'amountCents')
    ..aE<TemplateDirection>(4, _omitFieldNames ? '' : 'direction',
        enumValues: TemplateDirection.values)
    ..aOS(5, _omitFieldNames ? '' : 'sourceAccountId')
    ..aOS(6, _omitFieldNames ? '' : 'destinationAccountId')
    ..aE<TemplateCycle>(7, _omitFieldNames ? '' : 'cycle',
        enumValues: TemplateCycle.values)
    ..aI(8, _omitFieldNames ? '' : 'cycleDays')
    ..aI(9, _omitFieldNames ? '' : 'billingDay')
    ..aOS(10, _omitFieldNames ? '' : 'startDate')
    ..aOS(11, _omitFieldNames ? '' : 'endDate')
    ..aOB(12, _omitFieldNames ? '' : 'autoRecord')
    ..aOS(13, _omitFieldNames ? '' : 'category')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTemplateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateTemplateRequest copyWith(
          void Function(CreateTemplateRequest) updates) =>
      super.copyWith((message) => updates(message as CreateTemplateRequest))
          as CreateTemplateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateTemplateRequest create() => CreateTemplateRequest._();
  @$core.override
  CreateTemplateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateTemplateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateTemplateRequest>(create);
  static CreateTemplateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get description => $_getSZ(1);
  @$pb.TagNumber(2)
  set description($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDescription() => $_has(1);
  @$pb.TagNumber(2)
  void clearDescription() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get amountCents => $_getI64(2);
  @$pb.TagNumber(3)
  set amountCents($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAmountCents() => $_has(2);
  @$pb.TagNumber(3)
  void clearAmountCents() => $_clearField(3);

  @$pb.TagNumber(4)
  TemplateDirection get direction => $_getN(3);
  @$pb.TagNumber(4)
  set direction(TemplateDirection value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasDirection() => $_has(3);
  @$pb.TagNumber(4)
  void clearDirection() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get sourceAccountId => $_getSZ(4);
  @$pb.TagNumber(5)
  set sourceAccountId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSourceAccountId() => $_has(4);
  @$pb.TagNumber(5)
  void clearSourceAccountId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get destinationAccountId => $_getSZ(5);
  @$pb.TagNumber(6)
  set destinationAccountId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDestinationAccountId() => $_has(5);
  @$pb.TagNumber(6)
  void clearDestinationAccountId() => $_clearField(6);

  @$pb.TagNumber(7)
  TemplateCycle get cycle => $_getN(6);
  @$pb.TagNumber(7)
  set cycle(TemplateCycle value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasCycle() => $_has(6);
  @$pb.TagNumber(7)
  void clearCycle() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get cycleDays => $_getIZ(7);
  @$pb.TagNumber(8)
  set cycleDays($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasCycleDays() => $_has(7);
  @$pb.TagNumber(8)
  void clearCycleDays() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get billingDay => $_getIZ(8);
  @$pb.TagNumber(9)
  set billingDay($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasBillingDay() => $_has(8);
  @$pb.TagNumber(9)
  void clearBillingDay() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get startDate => $_getSZ(9);
  @$pb.TagNumber(10)
  set startDate($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasStartDate() => $_has(9);
  @$pb.TagNumber(10)
  void clearStartDate() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get endDate => $_getSZ(10);
  @$pb.TagNumber(11)
  set endDate($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasEndDate() => $_has(10);
  @$pb.TagNumber(11)
  void clearEndDate() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get autoRecord => $_getBF(11);
  @$pb.TagNumber(12)
  set autoRecord($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasAutoRecord() => $_has(11);
  @$pb.TagNumber(12)
  void clearAutoRecord() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get category => $_getSZ(12);
  @$pb.TagNumber(13)
  set category($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCategory() => $_has(12);
  @$pb.TagNumber(13)
  void clearCategory() => $_clearField(13);
}

class UpdateTemplateRequest extends $pb.GeneratedMessage {
  factory UpdateTemplateRequest({
    $core.String? id,
    $core.String? name,
    $core.String? description,
    $fixnum.Int64? amountCents,
    TemplateCycle? cycle,
    $core.int? cycleDays,
    $core.String? endDate,
    $core.bool? autoRecord,
    $fixnum.Int64? version,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (description != null) result.description = description;
    if (amountCents != null) result.amountCents = amountCents;
    if (cycle != null) result.cycle = cycle;
    if (cycleDays != null) result.cycleDays = cycleDays;
    if (endDate != null) result.endDate = endDate;
    if (autoRecord != null) result.autoRecord = autoRecord;
    if (version != null) result.version = version;
    return result;
  }

  UpdateTemplateRequest._();

  factory UpdateTemplateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateTemplateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateTemplateRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'description')
    ..aInt64(4, _omitFieldNames ? '' : 'amountCents')
    ..aE<TemplateCycle>(5, _omitFieldNames ? '' : 'cycle',
        enumValues: TemplateCycle.values)
    ..aI(6, _omitFieldNames ? '' : 'cycleDays')
    ..aOS(7, _omitFieldNames ? '' : 'endDate')
    ..aOB(8, _omitFieldNames ? '' : 'autoRecord')
    ..aInt64(9, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTemplateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateTemplateRequest copyWith(
          void Function(UpdateTemplateRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateTemplateRequest))
          as UpdateTemplateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateTemplateRequest create() => UpdateTemplateRequest._();
  @$core.override
  UpdateTemplateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateTemplateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateTemplateRequest>(create);
  static UpdateTemplateRequest? _defaultInstance;

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
  $core.String get description => $_getSZ(2);
  @$pb.TagNumber(3)
  set description($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDescription() => $_has(2);
  @$pb.TagNumber(3)
  void clearDescription() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get amountCents => $_getI64(3);
  @$pb.TagNumber(4)
  set amountCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAmountCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearAmountCents() => $_clearField(4);

  @$pb.TagNumber(5)
  TemplateCycle get cycle => $_getN(4);
  @$pb.TagNumber(5)
  set cycle(TemplateCycle value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasCycle() => $_has(4);
  @$pb.TagNumber(5)
  void clearCycle() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get cycleDays => $_getIZ(5);
  @$pb.TagNumber(6)
  set cycleDays($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCycleDays() => $_has(5);
  @$pb.TagNumber(6)
  void clearCycleDays() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get endDate => $_getSZ(6);
  @$pb.TagNumber(7)
  set endDate($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasEndDate() => $_has(6);
  @$pb.TagNumber(7)
  void clearEndDate() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get autoRecord => $_getBF(7);
  @$pb.TagNumber(8)
  set autoRecord($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasAutoRecord() => $_has(7);
  @$pb.TagNumber(8)
  void clearAutoRecord() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get version => $_getI64(8);
  @$pb.TagNumber(9)
  set version($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasVersion() => $_has(8);
  @$pb.TagNumber(9)
  void clearVersion() => $_clearField(9);
}

class DeleteTemplateRequest extends $pb.GeneratedMessage {
  factory DeleteTemplateRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteTemplateRequest._();

  factory DeleteTemplateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteTemplateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteTemplateRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTemplateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteTemplateRequest copyWith(
          void Function(DeleteTemplateRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteTemplateRequest))
          as DeleteTemplateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteTemplateRequest create() => DeleteTemplateRequest._();
  @$core.override
  DeleteTemplateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteTemplateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteTemplateRequest>(create);
  static DeleteTemplateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class PauseTemplateRequest extends $pb.GeneratedMessage {
  factory PauseTemplateRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  PauseTemplateRequest._();

  factory PauseTemplateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PauseTemplateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PauseTemplateRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PauseTemplateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PauseTemplateRequest copyWith(void Function(PauseTemplateRequest) updates) =>
      super.copyWith((message) => updates(message as PauseTemplateRequest))
          as PauseTemplateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PauseTemplateRequest create() => PauseTemplateRequest._();
  @$core.override
  PauseTemplateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PauseTemplateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PauseTemplateRequest>(create);
  static PauseTemplateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class ResumeTemplateRequest extends $pb.GeneratedMessage {
  factory ResumeTemplateRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  ResumeTemplateRequest._();

  factory ResumeTemplateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ResumeTemplateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ResumeTemplateRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResumeTemplateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ResumeTemplateRequest copyWith(
          void Function(ResumeTemplateRequest) updates) =>
      super.copyWith((message) => updates(message as ResumeTemplateRequest))
          as ResumeTemplateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ResumeTemplateRequest create() => ResumeTemplateRequest._();
  @$core.override
  ResumeTemplateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ResumeTemplateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ResumeTemplateRequest>(create);
  static ResumeTemplateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class GetTemplateRequest extends $pb.GeneratedMessage {
  factory GetTemplateRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetTemplateRequest._();

  factory GetTemplateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetTemplateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetTemplateRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTemplateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetTemplateRequest copyWith(void Function(GetTemplateRequest) updates) =>
      super.copyWith((message) => updates(message as GetTemplateRequest))
          as GetTemplateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetTemplateRequest create() => GetTemplateRequest._();
  @$core.override
  GetTemplateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetTemplateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetTemplateRequest>(create);
  static GetTemplateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class ListTemplatesRequest extends $pb.GeneratedMessage {
  factory ListTemplatesRequest({
    $1.PageRequest? page,
    $core.bool? paused,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (paused != null) result.paused = paused;
    return result;
  }

  ListTemplatesRequest._();

  factory ListTemplatesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListTemplatesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTemplatesRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOM<$1.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageRequest.create)
    ..aOB(2, _omitFieldNames ? '' : 'paused')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTemplatesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTemplatesRequest copyWith(void Function(ListTemplatesRequest) updates) =>
      super.copyWith((message) => updates(message as ListTemplatesRequest))
          as ListTemplatesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTemplatesRequest create() => ListTemplatesRequest._();
  @$core.override
  ListTemplatesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListTemplatesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTemplatesRequest>(create);
  static ListTemplatesRequest? _defaultInstance;

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
  $core.bool get paused => $_getBF(1);
  @$pb.TagNumber(2)
  set paused($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPaused() => $_has(1);
  @$pb.TagNumber(2)
  void clearPaused() => $_clearField(2);
}

class ListTemplatesResponse extends $pb.GeneratedMessage {
  factory ListTemplatesResponse({
    $core.Iterable<TemplateDTO>? templates,
    $1.PageResponse? page,
  }) {
    final result = create();
    if (templates != null) result.templates.addAll(templates);
    if (page != null) result.page = page;
    return result;
  }

  ListTemplatesResponse._();

  factory ListTemplatesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListTemplatesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTemplatesResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..pPM<TemplateDTO>(1, _omitFieldNames ? '' : 'templates',
        subBuilder: TemplateDTO.create)
    ..aOM<$1.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTemplatesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTemplatesResponse copyWith(
          void Function(ListTemplatesResponse) updates) =>
      super.copyWith((message) => updates(message as ListTemplatesResponse))
          as ListTemplatesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTemplatesResponse create() => ListTemplatesResponse._();
  @$core.override
  ListTemplatesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListTemplatesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTemplatesResponse>(create);
  static ListTemplatesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TemplateDTO> get templates => $_getList(0);

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

class TemplateResponse extends $pb.GeneratedMessage {
  factory TemplateResponse({
    TemplateDTO? template,
  }) {
    final result = create();
    if (template != null) result.template = template;
    return result;
  }

  TemplateResponse._();

  factory TemplateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TemplateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TemplateResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOM<TemplateDTO>(1, _omitFieldNames ? '' : 'template',
        subBuilder: TemplateDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TemplateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TemplateResponse copyWith(void Function(TemplateResponse) updates) =>
      super.copyWith((message) => updates(message as TemplateResponse))
          as TemplateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TemplateResponse create() => TemplateResponse._();
  @$core.override
  TemplateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TemplateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TemplateResponse>(create);
  static TemplateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  TemplateDTO get template => $_getN(0);
  @$pb.TagNumber(1)
  set template(TemplateDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTemplate() => $_has(0);
  @$pb.TagNumber(1)
  void clearTemplate() => $_clearField(1);
  @$pb.TagNumber(1)
  TemplateDTO ensureTemplate() => $_ensure(0);
}

class TransactionTemplateServiceApi {
  final $pb.RpcClient _client;

  TransactionTemplateServiceApi(this._client);

  $async.Future<TemplateResponse> createTransactionTemplate(
          $pb.ClientContext? ctx, CreateTemplateRequest request) =>
      _client.invoke<TemplateResponse>(ctx, 'TransactionTemplateService',
          'CreateTransactionTemplate', request, TemplateResponse());
  $async.Future<TemplateResponse> updateTransactionTemplate(
          $pb.ClientContext? ctx, UpdateTemplateRequest request) =>
      _client.invoke<TemplateResponse>(ctx, 'TransactionTemplateService',
          'UpdateTransactionTemplate', request, TemplateResponse());
  $async.Future<$2.Empty> deleteTransactionTemplate(
          $pb.ClientContext? ctx, DeleteTemplateRequest request) =>
      _client.invoke<$2.Empty>(ctx, 'TransactionTemplateService',
          'DeleteTransactionTemplate', request, $2.Empty());
  $async.Future<TemplateResponse> pauseTransactionTemplate(
          $pb.ClientContext? ctx, PauseTemplateRequest request) =>
      _client.invoke<TemplateResponse>(ctx, 'TransactionTemplateService',
          'PauseTransactionTemplate', request, TemplateResponse());
  $async.Future<TemplateResponse> resumeTransactionTemplate(
          $pb.ClientContext? ctx, ResumeTemplateRequest request) =>
      _client.invoke<TemplateResponse>(ctx, 'TransactionTemplateService',
          'ResumeTransactionTemplate', request, TemplateResponse());
  $async.Future<TemplateResponse> getTransactionTemplate(
          $pb.ClientContext? ctx, GetTemplateRequest request) =>
      _client.invoke<TemplateResponse>(ctx, 'TransactionTemplateService',
          'GetTransactionTemplate', request, TemplateResponse());
  $async.Future<ListTemplatesResponse> listTransactionTemplates(
          $pb.ClientContext? ctx, ListTemplatesRequest request) =>
      _client.invoke<ListTemplatesResponse>(ctx, 'TransactionTemplateService',
          'ListTransactionTemplates', request, ListTemplatesResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
