// This is a generated file - do not edit.
//
// Generated from budget/v1/budget.proto.

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

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class BudgetDTO extends $pb.GeneratedMessage {
  factory BudgetDTO({
    $core.String? id,
    $core.String? name,
    $core.String? month,
    $fixnum.Int64? totalAmountCents,
    $core.String? currencyCode,
    $core.bool? isActive,
    $fixnum.Int64? version,
    $2.Timestamp? createdAt,
    $2.Timestamp? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (month != null) result.month = month;
    if (totalAmountCents != null) result.totalAmountCents = totalAmountCents;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (isActive != null) result.isActive = isActive;
    if (version != null) result.version = version;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  BudgetDTO._();

  factory BudgetDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BudgetDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BudgetDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'month')
    ..aInt64(4, _omitFieldNames ? '' : 'totalAmountCents')
    ..aOS(5, _omitFieldNames ? '' : 'currencyCode')
    ..aOB(6, _omitFieldNames ? '' : 'isActive')
    ..aInt64(7, _omitFieldNames ? '' : 'version')
    ..aOM<$2.Timestamp>(8, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(9, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetDTO copyWith(void Function(BudgetDTO) updates) =>
      super.copyWith((message) => updates(message as BudgetDTO)) as BudgetDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BudgetDTO create() => BudgetDTO._();
  @$core.override
  BudgetDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BudgetDTO getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<BudgetDTO>(create);
  static BudgetDTO? _defaultInstance;

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
  $core.String get month => $_getSZ(2);
  @$pb.TagNumber(3)
  set month($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMonth() => $_has(2);
  @$pb.TagNumber(3)
  void clearMonth() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get totalAmountCents => $_getI64(3);
  @$pb.TagNumber(4)
  set totalAmountCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalAmountCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalAmountCents() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get currencyCode => $_getSZ(4);
  @$pb.TagNumber(5)
  set currencyCode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCurrencyCode() => $_has(4);
  @$pb.TagNumber(5)
  void clearCurrencyCode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isActive => $_getBF(5);
  @$pb.TagNumber(6)
  set isActive($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsActive() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsActive() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get version => $_getI64(6);
  @$pb.TagNumber(7)
  set version($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasVersion() => $_has(6);
  @$pb.TagNumber(7)
  void clearVersion() => $_clearField(7);

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

  @$pb.TagNumber(9)
  $2.Timestamp get updatedAt => $_getN(8);
  @$pb.TagNumber(9)
  set updatedAt($2.Timestamp value) => $_setField(9, value);
  @$pb.TagNumber(9)
  $core.bool hasUpdatedAt() => $_has(8);
  @$pb.TagNumber(9)
  void clearUpdatedAt() => $_clearField(9);
  @$pb.TagNumber(9)
  $2.Timestamp ensureUpdatedAt() => $_ensure(8);
}

class BudgetItemDTO extends $pb.GeneratedMessage {
  factory BudgetItemDTO({
    $core.String? id,
    $core.String? budgetId,
    $core.String? accountId,
    $fixnum.Int64? plannedAmountCents,
    $fixnum.Int64? actualAmountCents,
    $core.String? notes,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (budgetId != null) result.budgetId = budgetId;
    if (accountId != null) result.accountId = accountId;
    if (plannedAmountCents != null)
      result.plannedAmountCents = plannedAmountCents;
    if (actualAmountCents != null) result.actualAmountCents = actualAmountCents;
    if (notes != null) result.notes = notes;
    return result;
  }

  BudgetItemDTO._();

  factory BudgetItemDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BudgetItemDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BudgetItemDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'budgetId')
    ..aOS(3, _omitFieldNames ? '' : 'accountId')
    ..aInt64(4, _omitFieldNames ? '' : 'plannedAmountCents')
    ..aInt64(5, _omitFieldNames ? '' : 'actualAmountCents')
    ..aOS(6, _omitFieldNames ? '' : 'notes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetItemDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetItemDTO copyWith(void Function(BudgetItemDTO) updates) =>
      super.copyWith((message) => updates(message as BudgetItemDTO))
          as BudgetItemDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BudgetItemDTO create() => BudgetItemDTO._();
  @$core.override
  BudgetItemDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BudgetItemDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BudgetItemDTO>(create);
  static BudgetItemDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get budgetId => $_getSZ(1);
  @$pb.TagNumber(2)
  set budgetId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBudgetId() => $_has(1);
  @$pb.TagNumber(2)
  void clearBudgetId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get accountId => $_getSZ(2);
  @$pb.TagNumber(3)
  set accountId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAccountId() => $_has(2);
  @$pb.TagNumber(3)
  void clearAccountId() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get plannedAmountCents => $_getI64(3);
  @$pb.TagNumber(4)
  set plannedAmountCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPlannedAmountCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearPlannedAmountCents() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get actualAmountCents => $_getI64(4);
  @$pb.TagNumber(5)
  set actualAmountCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasActualAmountCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearActualAmountCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get notes => $_getSZ(5);
  @$pb.TagNumber(6)
  set notes($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasNotes() => $_has(5);
  @$pb.TagNumber(6)
  void clearNotes() => $_clearField(6);
}

class BudgetDetailDTO extends $pb.GeneratedMessage {
  factory BudgetDetailDTO({
    BudgetDTO? budget,
    $core.Iterable<BudgetItemDTO>? items,
    $fixnum.Int64? totalActualCents,
    $fixnum.Int64? totalRemainingCents,
    $core.double? usagePct,
  }) {
    final result = create();
    if (budget != null) result.budget = budget;
    if (items != null) result.items.addAll(items);
    if (totalActualCents != null) result.totalActualCents = totalActualCents;
    if (totalRemainingCents != null)
      result.totalRemainingCents = totalRemainingCents;
    if (usagePct != null) result.usagePct = usagePct;
    return result;
  }

  BudgetDetailDTO._();

  factory BudgetDetailDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BudgetDetailDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BudgetDetailDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOM<BudgetDTO>(1, _omitFieldNames ? '' : 'budget',
        subBuilder: BudgetDTO.create)
    ..pPM<BudgetItemDTO>(2, _omitFieldNames ? '' : 'items',
        subBuilder: BudgetItemDTO.create)
    ..aInt64(3, _omitFieldNames ? '' : 'totalActualCents')
    ..aInt64(4, _omitFieldNames ? '' : 'totalRemainingCents')
    ..aD(5, _omitFieldNames ? '' : 'usagePct')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetDetailDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetDetailDTO copyWith(void Function(BudgetDetailDTO) updates) =>
      super.copyWith((message) => updates(message as BudgetDetailDTO))
          as BudgetDetailDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BudgetDetailDTO create() => BudgetDetailDTO._();
  @$core.override
  BudgetDetailDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BudgetDetailDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BudgetDetailDTO>(create);
  static BudgetDetailDTO? _defaultInstance;

  @$pb.TagNumber(1)
  BudgetDTO get budget => $_getN(0);
  @$pb.TagNumber(1)
  set budget(BudgetDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBudget() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudget() => $_clearField(1);
  @$pb.TagNumber(1)
  BudgetDTO ensureBudget() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<BudgetItemDTO> get items => $_getList(1);

  @$pb.TagNumber(3)
  $fixnum.Int64 get totalActualCents => $_getI64(2);
  @$pb.TagNumber(3)
  set totalActualCents($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTotalActualCents() => $_has(2);
  @$pb.TagNumber(3)
  void clearTotalActualCents() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get totalRemainingCents => $_getI64(3);
  @$pb.TagNumber(4)
  set totalRemainingCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasTotalRemainingCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearTotalRemainingCents() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get usagePct => $_getN(4);
  @$pb.TagNumber(5)
  set usagePct($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasUsagePct() => $_has(4);
  @$pb.TagNumber(5)
  void clearUsagePct() => $_clearField(5);
}

class CreateBudgetRequest extends $pb.GeneratedMessage {
  factory CreateBudgetRequest({
    $core.String? name,
    $core.String? month,
    $core.String? currencyCode,
    $core.Iterable<BudgetItemInput>? items,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (month != null) result.month = month;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (items != null) result.items.addAll(items);
    return result;
  }

  CreateBudgetRequest._();

  factory CreateBudgetRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateBudgetRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateBudgetRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aOS(2, _omitFieldNames ? '' : 'month')
    ..aOS(3, _omitFieldNames ? '' : 'currencyCode')
    ..pPM<BudgetItemInput>(4, _omitFieldNames ? '' : 'items',
        subBuilder: BudgetItemInput.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateBudgetRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateBudgetRequest copyWith(void Function(CreateBudgetRequest) updates) =>
      super.copyWith((message) => updates(message as CreateBudgetRequest))
          as CreateBudgetRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateBudgetRequest create() => CreateBudgetRequest._();
  @$core.override
  CreateBudgetRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateBudgetRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateBudgetRequest>(create);
  static CreateBudgetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get month => $_getSZ(1);
  @$pb.TagNumber(2)
  set month($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMonth() => $_has(1);
  @$pb.TagNumber(2)
  void clearMonth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get currencyCode => $_getSZ(2);
  @$pb.TagNumber(3)
  set currencyCode($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCurrencyCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearCurrencyCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<BudgetItemInput> get items => $_getList(3);
}

class BudgetItemInput extends $pb.GeneratedMessage {
  factory BudgetItemInput({
    $core.String? accountId,
    $fixnum.Int64? plannedAmountCents,
    $core.String? notes,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (plannedAmountCents != null)
      result.plannedAmountCents = plannedAmountCents;
    if (notes != null) result.notes = notes;
    return result;
  }

  BudgetItemInput._();

  factory BudgetItemInput.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BudgetItemInput.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BudgetItemInput',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aInt64(2, _omitFieldNames ? '' : 'plannedAmountCents')
    ..aOS(3, _omitFieldNames ? '' : 'notes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetItemInput clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetItemInput copyWith(void Function(BudgetItemInput) updates) =>
      super.copyWith((message) => updates(message as BudgetItemInput))
          as BudgetItemInput;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BudgetItemInput create() => BudgetItemInput._();
  @$core.override
  BudgetItemInput createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BudgetItemInput getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BudgetItemInput>(create);
  static BudgetItemInput? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get plannedAmountCents => $_getI64(1);
  @$pb.TagNumber(2)
  set plannedAmountCents($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlannedAmountCents() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlannedAmountCents() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get notes => $_getSZ(2);
  @$pb.TagNumber(3)
  set notes($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNotes() => $_has(2);
  @$pb.TagNumber(3)
  void clearNotes() => $_clearField(3);
}

class GetBudgetRequest extends $pb.GeneratedMessage {
  factory GetBudgetRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetBudgetRequest._();

  factory GetBudgetRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetBudgetRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetBudgetRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetBudgetRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetBudgetRequest copyWith(void Function(GetBudgetRequest) updates) =>
      super.copyWith((message) => updates(message as GetBudgetRequest))
          as GetBudgetRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetBudgetRequest create() => GetBudgetRequest._();
  @$core.override
  GetBudgetRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetBudgetRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetBudgetRequest>(create);
  static GetBudgetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class GetBudgetByMonthRequest extends $pb.GeneratedMessage {
  factory GetBudgetByMonthRequest({
    $core.String? month,
  }) {
    final result = create();
    if (month != null) result.month = month;
    return result;
  }

  GetBudgetByMonthRequest._();

  factory GetBudgetByMonthRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetBudgetByMonthRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetBudgetByMonthRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'month')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetBudgetByMonthRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetBudgetByMonthRequest copyWith(
          void Function(GetBudgetByMonthRequest) updates) =>
      super.copyWith((message) => updates(message as GetBudgetByMonthRequest))
          as GetBudgetByMonthRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetBudgetByMonthRequest create() => GetBudgetByMonthRequest._();
  @$core.override
  GetBudgetByMonthRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetBudgetByMonthRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetBudgetByMonthRequest>(create);
  static GetBudgetByMonthRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get month => $_getSZ(0);
  @$pb.TagNumber(1)
  set month($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMonth() => $_has(0);
  @$pb.TagNumber(1)
  void clearMonth() => $_clearField(1);
}

class ListBudgetsRequest extends $pb.GeneratedMessage {
  factory ListBudgetsRequest({
    $3.PageRequest? page,
    $core.bool? activeOnly,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (activeOnly != null) result.activeOnly = activeOnly;
    return result;
  }

  ListBudgetsRequest._();

  factory ListBudgetsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListBudgetsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListBudgetsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOM<$3.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageRequest.create)
    ..aOB(2, _omitFieldNames ? '' : 'activeOnly')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBudgetsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBudgetsRequest copyWith(void Function(ListBudgetsRequest) updates) =>
      super.copyWith((message) => updates(message as ListBudgetsRequest))
          as ListBudgetsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListBudgetsRequest create() => ListBudgetsRequest._();
  @$core.override
  ListBudgetsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListBudgetsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListBudgetsRequest>(create);
  static ListBudgetsRequest? _defaultInstance;

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
  $core.bool get activeOnly => $_getBF(1);
  @$pb.TagNumber(2)
  set activeOnly($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActiveOnly() => $_has(1);
  @$pb.TagNumber(2)
  void clearActiveOnly() => $_clearField(2);
}

class ListBudgetsResponse extends $pb.GeneratedMessage {
  factory ListBudgetsResponse({
    $core.Iterable<BudgetDTO>? budgets,
    $3.PageResponse? page,
  }) {
    final result = create();
    if (budgets != null) result.budgets.addAll(budgets);
    if (page != null) result.page = page;
    return result;
  }

  ListBudgetsResponse._();

  factory ListBudgetsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListBudgetsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListBudgetsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..pPM<BudgetDTO>(1, _omitFieldNames ? '' : 'budgets',
        subBuilder: BudgetDTO.create)
    ..aOM<$3.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBudgetsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListBudgetsResponse copyWith(void Function(ListBudgetsResponse) updates) =>
      super.copyWith((message) => updates(message as ListBudgetsResponse))
          as ListBudgetsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListBudgetsResponse create() => ListBudgetsResponse._();
  @$core.override
  ListBudgetsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListBudgetsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListBudgetsResponse>(create);
  static ListBudgetsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<BudgetDTO> get budgets => $_getList(0);

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

class DeleteBudgetRequest extends $pb.GeneratedMessage {
  factory DeleteBudgetRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteBudgetRequest._();

  factory DeleteBudgetRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteBudgetRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteBudgetRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteBudgetRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteBudgetRequest copyWith(void Function(DeleteBudgetRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteBudgetRequest))
          as DeleteBudgetRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteBudgetRequest create() => DeleteBudgetRequest._();
  @$core.override
  DeleteBudgetRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteBudgetRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteBudgetRequest>(create);
  static DeleteBudgetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class AddBudgetItemRequest extends $pb.GeneratedMessage {
  factory AddBudgetItemRequest({
    $core.String? budgetId,
    $core.String? accountId,
    $fixnum.Int64? plannedAmountCents,
    $core.String? notes,
  }) {
    final result = create();
    if (budgetId != null) result.budgetId = budgetId;
    if (accountId != null) result.accountId = accountId;
    if (plannedAmountCents != null)
      result.plannedAmountCents = plannedAmountCents;
    if (notes != null) result.notes = notes;
    return result;
  }

  AddBudgetItemRequest._();

  factory AddBudgetItemRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddBudgetItemRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddBudgetItemRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'budgetId')
    ..aOS(2, _omitFieldNames ? '' : 'accountId')
    ..aInt64(3, _omitFieldNames ? '' : 'plannedAmountCents')
    ..aOS(4, _omitFieldNames ? '' : 'notes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddBudgetItemRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddBudgetItemRequest copyWith(void Function(AddBudgetItemRequest) updates) =>
      super.copyWith((message) => updates(message as AddBudgetItemRequest))
          as AddBudgetItemRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddBudgetItemRequest create() => AddBudgetItemRequest._();
  @$core.override
  AddBudgetItemRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddBudgetItemRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddBudgetItemRequest>(create);
  static AddBudgetItemRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get budgetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set budgetId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBudgetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudgetId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get accountId => $_getSZ(1);
  @$pb.TagNumber(2)
  set accountId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountId() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get plannedAmountCents => $_getI64(2);
  @$pb.TagNumber(3)
  set plannedAmountCents($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPlannedAmountCents() => $_has(2);
  @$pb.TagNumber(3)
  void clearPlannedAmountCents() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get notes => $_getSZ(3);
  @$pb.TagNumber(4)
  set notes($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasNotes() => $_has(3);
  @$pb.TagNumber(4)
  void clearNotes() => $_clearField(4);
}

class RemoveBudgetItemRequest extends $pb.GeneratedMessage {
  factory RemoveBudgetItemRequest({
    $core.String? budgetId,
    $core.String? itemId,
  }) {
    final result = create();
    if (budgetId != null) result.budgetId = budgetId;
    if (itemId != null) result.itemId = itemId;
    return result;
  }

  RemoveBudgetItemRequest._();

  factory RemoveBudgetItemRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RemoveBudgetItemRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RemoveBudgetItemRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'budgetId')
    ..aOS(2, _omitFieldNames ? '' : 'itemId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveBudgetItemRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RemoveBudgetItemRequest copyWith(
          void Function(RemoveBudgetItemRequest) updates) =>
      super.copyWith((message) => updates(message as RemoveBudgetItemRequest))
          as RemoveBudgetItemRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RemoveBudgetItemRequest create() => RemoveBudgetItemRequest._();
  @$core.override
  RemoveBudgetItemRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RemoveBudgetItemRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RemoveBudgetItemRequest>(create);
  static RemoveBudgetItemRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get budgetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set budgetId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBudgetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudgetId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get itemId => $_getSZ(1);
  @$pb.TagNumber(2)
  set itemId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasItemId() => $_has(1);
  @$pb.TagNumber(2)
  void clearItemId() => $_clearField(2);
}

class ComputeActualsRequest extends $pb.GeneratedMessage {
  factory ComputeActualsRequest({
    $core.String? budgetId,
  }) {
    final result = create();
    if (budgetId != null) result.budgetId = budgetId;
    return result;
  }

  ComputeActualsRequest._();

  factory ComputeActualsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ComputeActualsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ComputeActualsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'budgetId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeActualsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ComputeActualsRequest copyWith(
          void Function(ComputeActualsRequest) updates) =>
      super.copyWith((message) => updates(message as ComputeActualsRequest))
          as ComputeActualsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ComputeActualsRequest create() => ComputeActualsRequest._();
  @$core.override
  ComputeActualsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ComputeActualsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ComputeActualsRequest>(create);
  static ComputeActualsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get budgetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set budgetId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBudgetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudgetId() => $_clearField(1);
}

class CloneBudgetRequest extends $pb.GeneratedMessage {
  factory CloneBudgetRequest({
    $core.String? sourceBudgetId,
    $core.String? targetMonth,
    $core.String? name,
  }) {
    final result = create();
    if (sourceBudgetId != null) result.sourceBudgetId = sourceBudgetId;
    if (targetMonth != null) result.targetMonth = targetMonth;
    if (name != null) result.name = name;
    return result;
  }

  CloneBudgetRequest._();

  factory CloneBudgetRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CloneBudgetRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CloneBudgetRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'sourceBudgetId')
    ..aOS(2, _omitFieldNames ? '' : 'targetMonth')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloneBudgetRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CloneBudgetRequest copyWith(void Function(CloneBudgetRequest) updates) =>
      super.copyWith((message) => updates(message as CloneBudgetRequest))
          as CloneBudgetRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CloneBudgetRequest create() => CloneBudgetRequest._();
  @$core.override
  CloneBudgetRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CloneBudgetRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CloneBudgetRequest>(create);
  static CloneBudgetRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get sourceBudgetId => $_getSZ(0);
  @$pb.TagNumber(1)
  set sourceBudgetId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSourceBudgetId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSourceBudgetId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get targetMonth => $_getSZ(1);
  @$pb.TagNumber(2)
  set targetMonth($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTargetMonth() => $_has(1);
  @$pb.TagNumber(2)
  void clearTargetMonth() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);
}

class BudgetResponse extends $pb.GeneratedMessage {
  factory BudgetResponse({
    BudgetDTO? budget,
  }) {
    final result = create();
    if (budget != null) result.budget = budget;
    return result;
  }

  BudgetResponse._();

  factory BudgetResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BudgetResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BudgetResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOM<BudgetDTO>(1, _omitFieldNames ? '' : 'budget',
        subBuilder: BudgetDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetResponse copyWith(void Function(BudgetResponse) updates) =>
      super.copyWith((message) => updates(message as BudgetResponse))
          as BudgetResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BudgetResponse create() => BudgetResponse._();
  @$core.override
  BudgetResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BudgetResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BudgetResponse>(create);
  static BudgetResponse? _defaultInstance;

  @$pb.TagNumber(1)
  BudgetDTO get budget => $_getN(0);
  @$pb.TagNumber(1)
  set budget(BudgetDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBudget() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudget() => $_clearField(1);
  @$pb.TagNumber(1)
  BudgetDTO ensureBudget() => $_ensure(0);
}

class BudgetDetailResponse extends $pb.GeneratedMessage {
  factory BudgetDetailResponse({
    BudgetDetailDTO? budget,
  }) {
    final result = create();
    if (budget != null) result.budget = budget;
    return result;
  }

  BudgetDetailResponse._();

  factory BudgetDetailResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory BudgetDetailResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'BudgetDetailResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.budget.v1'),
      createEmptyInstance: create)
    ..aOM<BudgetDetailDTO>(1, _omitFieldNames ? '' : 'budget',
        subBuilder: BudgetDetailDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetDetailResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  BudgetDetailResponse copyWith(void Function(BudgetDetailResponse) updates) =>
      super.copyWith((message) => updates(message as BudgetDetailResponse))
          as BudgetDetailResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static BudgetDetailResponse create() => BudgetDetailResponse._();
  @$core.override
  BudgetDetailResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static BudgetDetailResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<BudgetDetailResponse>(create);
  static BudgetDetailResponse? _defaultInstance;

  @$pb.TagNumber(1)
  BudgetDetailDTO get budget => $_getN(0);
  @$pb.TagNumber(1)
  set budget(BudgetDetailDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasBudget() => $_has(0);
  @$pb.TagNumber(1)
  void clearBudget() => $_clearField(1);
  @$pb.TagNumber(1)
  BudgetDetailDTO ensureBudget() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
