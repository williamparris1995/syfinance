// This is a generated file - do not edit.
//
// Generated from category/v1/category.proto.

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
import 'category.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'category.pbenum.dart';

class CategoryDTO extends $pb.GeneratedMessage {
  factory CategoryDTO({
    $core.String? id,
    $core.String? name,
    CategoryType? categoryType,
    $core.String? icon,
    $core.String? color,
    $core.String? parentId,
    $core.bool? isSystem,
    $core.int? sortOrder,
    $fixnum.Int64? version,
    $2.Timestamp? createdAt,
    $2.Timestamp? updatedAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (categoryType != null) result.categoryType = categoryType;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (parentId != null) result.parentId = parentId;
    if (isSystem != null) result.isSystem = isSystem;
    if (sortOrder != null) result.sortOrder = sortOrder;
    if (version != null) result.version = version;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    return result;
  }

  CategoryDTO._();

  factory CategoryDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CategoryDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CategoryDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.category.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<CategoryType>(3, _omitFieldNames ? '' : 'categoryType',
        enumValues: CategoryType.values)
    ..aOS(4, _omitFieldNames ? '' : 'icon')
    ..aOS(5, _omitFieldNames ? '' : 'color')
    ..aOS(6, _omitFieldNames ? '' : 'parentId')
    ..aOB(7, _omitFieldNames ? '' : 'isSystem')
    ..aI(8, _omitFieldNames ? '' : 'sortOrder')
    ..aInt64(9, _omitFieldNames ? '' : 'version')
    ..aOM<$2.Timestamp>(10, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(11, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $2.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CategoryDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CategoryDTO copyWith(void Function(CategoryDTO) updates) =>
      super.copyWith((message) => updates(message as CategoryDTO))
          as CategoryDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryDTO create() => CategoryDTO._();
  @$core.override
  CategoryDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CategoryDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CategoryDTO>(create);
  static CategoryDTO? _defaultInstance;

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
  CategoryType get categoryType => $_getN(2);
  @$pb.TagNumber(3)
  set categoryType(CategoryType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasCategoryType() => $_has(2);
  @$pb.TagNumber(3)
  void clearCategoryType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get icon => $_getSZ(3);
  @$pb.TagNumber(4)
  set icon($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasIcon() => $_has(3);
  @$pb.TagNumber(4)
  void clearIcon() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get color => $_getSZ(4);
  @$pb.TagNumber(5)
  set color($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasColor() => $_has(4);
  @$pb.TagNumber(5)
  void clearColor() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get parentId => $_getSZ(5);
  @$pb.TagNumber(6)
  set parentId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasParentId() => $_has(5);
  @$pb.TagNumber(6)
  void clearParentId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.bool get isSystem => $_getBF(6);
  @$pb.TagNumber(7)
  set isSystem($core.bool value) => $_setBool(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIsSystem() => $_has(6);
  @$pb.TagNumber(7)
  void clearIsSystem() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.int get sortOrder => $_getIZ(7);
  @$pb.TagNumber(8)
  set sortOrder($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasSortOrder() => $_has(7);
  @$pb.TagNumber(8)
  void clearSortOrder() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get version => $_getI64(8);
  @$pb.TagNumber(9)
  set version($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasVersion() => $_has(8);
  @$pb.TagNumber(9)
  void clearVersion() => $_clearField(9);

  @$pb.TagNumber(10)
  $2.Timestamp get createdAt => $_getN(9);
  @$pb.TagNumber(10)
  set createdAt($2.Timestamp value) => $_setField(10, value);
  @$pb.TagNumber(10)
  $core.bool hasCreatedAt() => $_has(9);
  @$pb.TagNumber(10)
  void clearCreatedAt() => $_clearField(10);
  @$pb.TagNumber(10)
  $2.Timestamp ensureCreatedAt() => $_ensure(9);

  @$pb.TagNumber(11)
  $2.Timestamp get updatedAt => $_getN(10);
  @$pb.TagNumber(11)
  set updatedAt($2.Timestamp value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasUpdatedAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearUpdatedAt() => $_clearField(11);
  @$pb.TagNumber(11)
  $2.Timestamp ensureUpdatedAt() => $_ensure(10);
}

class CreateCategoryRequest extends $pb.GeneratedMessage {
  factory CreateCategoryRequest({
    $core.String? name,
    CategoryType? categoryType,
    $core.String? icon,
    $core.String? color,
    $core.String? parentId,
    $core.int? sortOrder,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (categoryType != null) result.categoryType = categoryType;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (parentId != null) result.parentId = parentId;
    if (sortOrder != null) result.sortOrder = sortOrder;
    return result;
  }

  CreateCategoryRequest._();

  factory CreateCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateCategoryRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.category.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aE<CategoryType>(2, _omitFieldNames ? '' : 'categoryType',
        enumValues: CategoryType.values)
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aOS(4, _omitFieldNames ? '' : 'color')
    ..aOS(5, _omitFieldNames ? '' : 'parentId')
    ..aI(6, _omitFieldNames ? '' : 'sortOrder')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateCategoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateCategoryRequest copyWith(
          void Function(CreateCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as CreateCategoryRequest))
          as CreateCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateCategoryRequest create() => CreateCategoryRequest._();
  @$core.override
  CreateCategoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateCategoryRequest>(create);
  static CreateCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  CategoryType get categoryType => $_getN(1);
  @$pb.TagNumber(2)
  set categoryType(CategoryType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCategoryType() => $_has(1);
  @$pb.TagNumber(2)
  void clearCategoryType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get color => $_getSZ(3);
  @$pb.TagNumber(4)
  set color($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearColor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get parentId => $_getSZ(4);
  @$pb.TagNumber(5)
  set parentId($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasParentId() => $_has(4);
  @$pb.TagNumber(5)
  void clearParentId() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get sortOrder => $_getIZ(5);
  @$pb.TagNumber(6)
  set sortOrder($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasSortOrder() => $_has(5);
  @$pb.TagNumber(6)
  void clearSortOrder() => $_clearField(6);
}

class UpdateCategoryRequest extends $pb.GeneratedMessage {
  factory UpdateCategoryRequest({
    $core.String? id,
    $core.String? name,
    $core.String? icon,
    $core.String? color,
    $core.int? sortOrder,
    $fixnum.Int64? version,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (sortOrder != null) result.sortOrder = sortOrder;
    if (version != null) result.version = version;
    return result;
  }

  UpdateCategoryRequest._();

  factory UpdateCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateCategoryRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.category.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aOS(4, _omitFieldNames ? '' : 'color')
    ..aI(5, _omitFieldNames ? '' : 'sortOrder')
    ..aInt64(6, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateCategoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateCategoryRequest copyWith(
          void Function(UpdateCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateCategoryRequest))
          as UpdateCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateCategoryRequest create() => UpdateCategoryRequest._();
  @$core.override
  UpdateCategoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateCategoryRequest>(create);
  static UpdateCategoryRequest? _defaultInstance;

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
  $core.String get icon => $_getSZ(2);
  @$pb.TagNumber(3)
  set icon($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIcon() => $_has(2);
  @$pb.TagNumber(3)
  void clearIcon() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get color => $_getSZ(3);
  @$pb.TagNumber(4)
  set color($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasColor() => $_has(3);
  @$pb.TagNumber(4)
  void clearColor() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get sortOrder => $_getIZ(4);
  @$pb.TagNumber(5)
  set sortOrder($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSortOrder() => $_has(4);
  @$pb.TagNumber(5)
  void clearSortOrder() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get version => $_getI64(5);
  @$pb.TagNumber(6)
  set version($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasVersion() => $_has(5);
  @$pb.TagNumber(6)
  void clearVersion() => $_clearField(6);
}

class DeleteCategoryRequest extends $pb.GeneratedMessage {
  factory DeleteCategoryRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteCategoryRequest._();

  factory DeleteCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteCategoryRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.category.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCategoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteCategoryRequest copyWith(
          void Function(DeleteCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteCategoryRequest))
          as DeleteCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteCategoryRequest create() => DeleteCategoryRequest._();
  @$core.override
  DeleteCategoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteCategoryRequest>(create);
  static DeleteCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class GetCategoryRequest extends $pb.GeneratedMessage {
  factory GetCategoryRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetCategoryRequest._();

  factory GetCategoryRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetCategoryRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetCategoryRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.category.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCategoryRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetCategoryRequest copyWith(void Function(GetCategoryRequest) updates) =>
      super.copyWith((message) => updates(message as GetCategoryRequest))
          as GetCategoryRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetCategoryRequest create() => GetCategoryRequest._();
  @$core.override
  GetCategoryRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetCategoryRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetCategoryRequest>(create);
  static GetCategoryRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class ListCategoriesRequest extends $pb.GeneratedMessage {
  factory ListCategoriesRequest({
    $3.PageRequest? page,
    CategoryType? categoryType,
    $core.String? search,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (categoryType != null) result.categoryType = categoryType;
    if (search != null) result.search = search;
    return result;
  }

  ListCategoriesRequest._();

  factory ListCategoriesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListCategoriesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListCategoriesRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.category.v1'),
      createEmptyInstance: create)
    ..aOM<$3.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageRequest.create)
    ..aE<CategoryType>(2, _omitFieldNames ? '' : 'categoryType',
        enumValues: CategoryType.values)
    ..aOS(3, _omitFieldNames ? '' : 'search')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCategoriesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCategoriesRequest copyWith(
          void Function(ListCategoriesRequest) updates) =>
      super.copyWith((message) => updates(message as ListCategoriesRequest))
          as ListCategoriesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListCategoriesRequest create() => ListCategoriesRequest._();
  @$core.override
  ListCategoriesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListCategoriesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListCategoriesRequest>(create);
  static ListCategoriesRequest? _defaultInstance;

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
  CategoryType get categoryType => $_getN(1);
  @$pb.TagNumber(2)
  set categoryType(CategoryType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasCategoryType() => $_has(1);
  @$pb.TagNumber(2)
  void clearCategoryType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get search => $_getSZ(2);
  @$pb.TagNumber(3)
  set search($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSearch() => $_has(2);
  @$pb.TagNumber(3)
  void clearSearch() => $_clearField(3);
}

class ListCategoriesResponse extends $pb.GeneratedMessage {
  factory ListCategoriesResponse({
    $core.Iterable<CategoryDTO>? categories,
    $3.PageResponse? page,
  }) {
    final result = create();
    if (categories != null) result.categories.addAll(categories);
    if (page != null) result.page = page;
    return result;
  }

  ListCategoriesResponse._();

  factory ListCategoriesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListCategoriesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListCategoriesResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.category.v1'),
      createEmptyInstance: create)
    ..pPM<CategoryDTO>(1, _omitFieldNames ? '' : 'categories',
        subBuilder: CategoryDTO.create)
    ..aOM<$3.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCategoriesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCategoriesResponse copyWith(
          void Function(ListCategoriesResponse) updates) =>
      super.copyWith((message) => updates(message as ListCategoriesResponse))
          as ListCategoriesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListCategoriesResponse create() => ListCategoriesResponse._();
  @$core.override
  ListCategoriesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListCategoriesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListCategoriesResponse>(create);
  static ListCategoriesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CategoryDTO> get categories => $_getList(0);

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

class CategoryResponse extends $pb.GeneratedMessage {
  factory CategoryResponse({
    CategoryDTO? category,
  }) {
    final result = create();
    if (category != null) result.category = category;
    return result;
  }

  CategoryResponse._();

  factory CategoryResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CategoryResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CategoryResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.category.v1'),
      createEmptyInstance: create)
    ..aOM<CategoryDTO>(1, _omitFieldNames ? '' : 'category',
        subBuilder: CategoryDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CategoryResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CategoryResponse copyWith(void Function(CategoryResponse) updates) =>
      super.copyWith((message) => updates(message as CategoryResponse))
          as CategoryResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CategoryResponse create() => CategoryResponse._();
  @$core.override
  CategoryResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CategoryResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CategoryResponse>(create);
  static CategoryResponse? _defaultInstance;

  @$pb.TagNumber(1)
  CategoryDTO get category => $_getN(0);
  @$pb.TagNumber(1)
  set category(CategoryDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCategory() => $_has(0);
  @$pb.TagNumber(1)
  void clearCategory() => $_clearField(1);
  @$pb.TagNumber(1)
  CategoryDTO ensureCategory() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
