// This is a generated file - do not edit.
//
// Generated from template/v1/template.proto.

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
import '../../common/v1/recurrence.pbenum.dart' as $4;
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
    $2.Timestamp? createdAt,
    $2.Timestamp? updatedAt,
    $core.int? interval,
    $core.int? weekdayMask,
    $4.RecurrenceMonthlyMode? monthlyMode,
    $core.int? nth,
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
    if (interval != null) result.interval = interval;
    if (weekdayMask != null) result.weekdayMask = weekdayMask;
    if (monthlyMode != null) result.monthlyMode = monthlyMode;
    if (nth != null) result.nth = nth;
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
    ..aOM<$2.Timestamp>(19, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(20, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $2.Timestamp.create)
    ..aI(21, _omitFieldNames ? '' : 'interval')
    ..aI(22, _omitFieldNames ? '' : 'weekdayMask')
    ..aE<$4.RecurrenceMonthlyMode>(23, _omitFieldNames ? '' : 'monthlyMode',
        enumValues: $4.RecurrenceMonthlyMode.values)
    ..aI(24, _omitFieldNames ? '' : 'nth')
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
  $2.Timestamp get createdAt => $_getN(18);
  @$pb.TagNumber(19)
  set createdAt($2.Timestamp value) => $_setField(19, value);
  @$pb.TagNumber(19)
  $core.bool hasCreatedAt() => $_has(18);
  @$pb.TagNumber(19)
  void clearCreatedAt() => $_clearField(19);
  @$pb.TagNumber(19)
  $2.Timestamp ensureCreatedAt() => $_ensure(18);

  @$pb.TagNumber(20)
  $2.Timestamp get updatedAt => $_getN(19);
  @$pb.TagNumber(20)
  set updatedAt($2.Timestamp value) => $_setField(20, value);
  @$pb.TagNumber(20)
  $core.bool hasUpdatedAt() => $_has(19);
  @$pb.TagNumber(20)
  void clearUpdatedAt() => $_clearField(20);
  @$pb.TagNumber(20)
  $2.Timestamp ensureUpdatedAt() => $_ensure(19);

  /// Recurrence rule extensions (zero values = legacy behavior).
  @$pb.TagNumber(21)
  $core.int get interval => $_getIZ(20);
  @$pb.TagNumber(21)
  set interval($core.int value) => $_setSignedInt32(20, value);
  @$pb.TagNumber(21)
  $core.bool hasInterval() => $_has(20);
  @$pb.TagNumber(21)
  void clearInterval() => $_clearField(21);

  @$pb.TagNumber(22)
  $core.int get weekdayMask => $_getIZ(21);
  @$pb.TagNumber(22)
  set weekdayMask($core.int value) => $_setSignedInt32(21, value);
  @$pb.TagNumber(22)
  $core.bool hasWeekdayMask() => $_has(21);
  @$pb.TagNumber(22)
  void clearWeekdayMask() => $_clearField(22);

  @$pb.TagNumber(23)
  $4.RecurrenceMonthlyMode get monthlyMode => $_getN(22);
  @$pb.TagNumber(23)
  set monthlyMode($4.RecurrenceMonthlyMode value) => $_setField(23, value);
  @$pb.TagNumber(23)
  $core.bool hasMonthlyMode() => $_has(22);
  @$pb.TagNumber(23)
  void clearMonthlyMode() => $_clearField(23);

  @$pb.TagNumber(24)
  $core.int get nth => $_getIZ(23);
  @$pb.TagNumber(24)
  set nth($core.int value) => $_setSignedInt32(23, value);
  @$pb.TagNumber(24)
  $core.bool hasNth() => $_has(23);
  @$pb.TagNumber(24)
  void clearNth() => $_clearField(24);
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
    $core.int? interval,
    $core.int? weekdayMask,
    $4.RecurrenceMonthlyMode? monthlyMode,
    $core.int? nth,
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
    if (interval != null) result.interval = interval;
    if (weekdayMask != null) result.weekdayMask = weekdayMask;
    if (monthlyMode != null) result.monthlyMode = monthlyMode;
    if (nth != null) result.nth = nth;
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
    ..aI(14, _omitFieldNames ? '' : 'interval')
    ..aI(15, _omitFieldNames ? '' : 'weekdayMask')
    ..aE<$4.RecurrenceMonthlyMode>(16, _omitFieldNames ? '' : 'monthlyMode',
        enumValues: $4.RecurrenceMonthlyMode.values)
    ..aI(17, _omitFieldNames ? '' : 'nth')
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

  @$pb.TagNumber(14)
  $core.int get interval => $_getIZ(13);
  @$pb.TagNumber(14)
  set interval($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasInterval() => $_has(13);
  @$pb.TagNumber(14)
  void clearInterval() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.int get weekdayMask => $_getIZ(14);
  @$pb.TagNumber(15)
  set weekdayMask($core.int value) => $_setSignedInt32(14, value);
  @$pb.TagNumber(15)
  $core.bool hasWeekdayMask() => $_has(14);
  @$pb.TagNumber(15)
  void clearWeekdayMask() => $_clearField(15);

  @$pb.TagNumber(16)
  $4.RecurrenceMonthlyMode get monthlyMode => $_getN(15);
  @$pb.TagNumber(16)
  set monthlyMode($4.RecurrenceMonthlyMode value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasMonthlyMode() => $_has(15);
  @$pb.TagNumber(16)
  void clearMonthlyMode() => $_clearField(16);

  @$pb.TagNumber(17)
  $core.int get nth => $_getIZ(16);
  @$pb.TagNumber(17)
  set nth($core.int value) => $_setSignedInt32(16, value);
  @$pb.TagNumber(17)
  $core.bool hasNth() => $_has(16);
  @$pb.TagNumber(17)
  void clearNth() => $_clearField(17);
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
    $core.int? billingDay,
    $core.int? interval,
    $core.int? weekdayMask,
    $4.RecurrenceMonthlyMode? monthlyMode,
    $core.int? nth,
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
    if (billingDay != null) result.billingDay = billingDay;
    if (interval != null) result.interval = interval;
    if (weekdayMask != null) result.weekdayMask = weekdayMask;
    if (monthlyMode != null) result.monthlyMode = monthlyMode;
    if (nth != null) result.nth = nth;
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
    ..aI(10, _omitFieldNames ? '' : 'billingDay')
    ..aI(11, _omitFieldNames ? '' : 'interval')
    ..aI(12, _omitFieldNames ? '' : 'weekdayMask')
    ..aE<$4.RecurrenceMonthlyMode>(13, _omitFieldNames ? '' : 'monthlyMode',
        enumValues: $4.RecurrenceMonthlyMode.values)
    ..aI(14, _omitFieldNames ? '' : 'nth')
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

  /// Rule fields are editable on update; a rule change recomputes next_date
  /// as the first occurrence >= max(start_date, today).
  @$pb.TagNumber(10)
  $core.int get billingDay => $_getIZ(9);
  @$pb.TagNumber(10)
  set billingDay($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasBillingDay() => $_has(9);
  @$pb.TagNumber(10)
  void clearBillingDay() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get interval => $_getIZ(10);
  @$pb.TagNumber(11)
  set interval($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasInterval() => $_has(10);
  @$pb.TagNumber(11)
  void clearInterval() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.int get weekdayMask => $_getIZ(11);
  @$pb.TagNumber(12)
  set weekdayMask($core.int value) => $_setSignedInt32(11, value);
  @$pb.TagNumber(12)
  $core.bool hasWeekdayMask() => $_has(11);
  @$pb.TagNumber(12)
  void clearWeekdayMask() => $_clearField(12);

  @$pb.TagNumber(13)
  $4.RecurrenceMonthlyMode get monthlyMode => $_getN(12);
  @$pb.TagNumber(13)
  set monthlyMode($4.RecurrenceMonthlyMode value) => $_setField(13, value);
  @$pb.TagNumber(13)
  $core.bool hasMonthlyMode() => $_has(12);
  @$pb.TagNumber(13)
  void clearMonthlyMode() => $_clearField(13);

  @$pb.TagNumber(14)
  $core.int get nth => $_getIZ(13);
  @$pb.TagNumber(14)
  set nth($core.int value) => $_setSignedInt32(13, value);
  @$pb.TagNumber(14)
  $core.bool hasNth() => $_has(13);
  @$pb.TagNumber(14)
  void clearNth() => $_clearField(14);
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
    $3.PageRequest? page,
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
    ..aOM<$3.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageRequest.create)
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
    $3.PageResponse? page,
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
    ..aOM<$3.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageResponse.create)
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

class RecordTemplateRequest extends $pb.GeneratedMessage {
  factory RecordTemplateRequest({
    $core.String? templateId,
  }) {
    final result = create();
    if (templateId != null) result.templateId = templateId;
    return result;
  }

  RecordTemplateRequest._();

  factory RecordTemplateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordTemplateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordTemplateRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'templateId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordTemplateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordTemplateRequest copyWith(
          void Function(RecordTemplateRequest) updates) =>
      super.copyWith((message) => updates(message as RecordTemplateRequest))
          as RecordTemplateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordTemplateRequest create() => RecordTemplateRequest._();
  @$core.override
  RecordTemplateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordTemplateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordTemplateRequest>(create);
  static RecordTemplateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get templateId => $_getSZ(0);
  @$pb.TagNumber(1)
  set templateId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTemplateId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTemplateId() => $_clearField(1);
}

class RecordTransactionResponse extends $pb.GeneratedMessage {
  factory RecordTransactionResponse({
    $core.String? transactionId,
    $2.Timestamp? nextDate,
  }) {
    final result = create();
    if (transactionId != null) result.transactionId = transactionId;
    if (nextDate != null) result.nextDate = nextDate;
    return result;
  }

  RecordTransactionResponse._();

  factory RecordTransactionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordTransactionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordTransactionResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.template.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'transactionId')
    ..aOM<$2.Timestamp>(2, _omitFieldNames ? '' : 'nextDate',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordTransactionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordTransactionResponse copyWith(
          void Function(RecordTransactionResponse) updates) =>
      super.copyWith((message) => updates(message as RecordTransactionResponse))
          as RecordTransactionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordTransactionResponse create() => RecordTransactionResponse._();
  @$core.override
  RecordTransactionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordTransactionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordTransactionResponse>(create);
  static RecordTransactionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get transactionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set transactionId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTransactionId() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransactionId() => $_clearField(1);

  @$pb.TagNumber(2)
  $2.Timestamp get nextDate => $_getN(1);
  @$pb.TagNumber(2)
  set nextDate($2.Timestamp value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasNextDate() => $_has(1);
  @$pb.TagNumber(2)
  void clearNextDate() => $_clearField(2);
  @$pb.TagNumber(2)
  $2.Timestamp ensureNextDate() => $_ensure(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
