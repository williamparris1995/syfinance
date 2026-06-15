// This is a generated file - do not edit.
//
// Generated from account/v1/account.proto.

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
import 'account.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'account.pbenum.dart';

class AccountDTO extends $pb.GeneratedMessage {
  factory AccountDTO({
    $core.String? id,
    $core.String? name,
    AccountType? accountType,
    $core.String? currencyCode,
    $fixnum.Int64? initialBalanceCents,
    $fixnum.Int64? currentBalanceCents,
    Ownership? ownership,
    $core.String? icon,
    $core.String? color,
    $core.String? chartCode,
    $core.String? parentId,
    $core.String? institution,
    $fixnum.Int64? creditLimitCents,
    AccountStatus? status,
    $fixnum.Int64? version,
    $2.Timestamp? createdAt,
    $2.Timestamp? updatedAt,
    AccountCategory? category,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (accountType != null) result.accountType = accountType;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (initialBalanceCents != null)
      result.initialBalanceCents = initialBalanceCents;
    if (currentBalanceCents != null)
      result.currentBalanceCents = currentBalanceCents;
    if (ownership != null) result.ownership = ownership;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (chartCode != null) result.chartCode = chartCode;
    if (parentId != null) result.parentId = parentId;
    if (institution != null) result.institution = institution;
    if (creditLimitCents != null) result.creditLimitCents = creditLimitCents;
    if (status != null) result.status = status;
    if (version != null) result.version = version;
    if (createdAt != null) result.createdAt = createdAt;
    if (updatedAt != null) result.updatedAt = updatedAt;
    if (category != null) result.category = category;
    return result;
  }

  AccountDTO._();

  factory AccountDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AccountDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccountDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<AccountType>(3, _omitFieldNames ? '' : 'accountType',
        enumValues: AccountType.values)
    ..aOS(4, _omitFieldNames ? '' : 'currencyCode')
    ..aInt64(5, _omitFieldNames ? '' : 'initialBalanceCents')
    ..aInt64(6, _omitFieldNames ? '' : 'currentBalanceCents')
    ..aE<Ownership>(7, _omitFieldNames ? '' : 'ownership',
        enumValues: Ownership.values)
    ..aOS(8, _omitFieldNames ? '' : 'icon')
    ..aOS(9, _omitFieldNames ? '' : 'color')
    ..aOS(10, _omitFieldNames ? '' : 'chartCode')
    ..aOS(11, _omitFieldNames ? '' : 'parentId')
    ..aOS(12, _omitFieldNames ? '' : 'institution')
    ..aInt64(13, _omitFieldNames ? '' : 'creditLimitCents')
    ..aE<AccountStatus>(14, _omitFieldNames ? '' : 'status',
        enumValues: AccountStatus.values)
    ..aInt64(15, _omitFieldNames ? '' : 'version')
    ..aOM<$2.Timestamp>(16, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $2.Timestamp.create)
    ..aOM<$2.Timestamp>(17, _omitFieldNames ? '' : 'updatedAt',
        subBuilder: $2.Timestamp.create)
    ..aE<AccountCategory>(18, _omitFieldNames ? '' : 'category',
        enumValues: AccountCategory.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountDTO copyWith(void Function(AccountDTO) updates) =>
      super.copyWith((message) => updates(message as AccountDTO)) as AccountDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AccountDTO create() => AccountDTO._();
  @$core.override
  AccountDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AccountDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AccountDTO>(create);
  static AccountDTO? _defaultInstance;

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
  AccountType get accountType => $_getN(2);
  @$pb.TagNumber(3)
  set accountType(AccountType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasAccountType() => $_has(2);
  @$pb.TagNumber(3)
  void clearAccountType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get currencyCode => $_getSZ(3);
  @$pb.TagNumber(4)
  set currencyCode($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrencyCode() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrencyCode() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get initialBalanceCents => $_getI64(4);
  @$pb.TagNumber(5)
  set initialBalanceCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInitialBalanceCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearInitialBalanceCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get currentBalanceCents => $_getI64(5);
  @$pb.TagNumber(6)
  set currentBalanceCents($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrentBalanceCents() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrentBalanceCents() => $_clearField(6);

  @$pb.TagNumber(7)
  Ownership get ownership => $_getN(6);
  @$pb.TagNumber(7)
  set ownership(Ownership value) => $_setField(7, value);
  @$pb.TagNumber(7)
  $core.bool hasOwnership() => $_has(6);
  @$pb.TagNumber(7)
  void clearOwnership() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get icon => $_getSZ(7);
  @$pb.TagNumber(8)
  set icon($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasIcon() => $_has(7);
  @$pb.TagNumber(8)
  void clearIcon() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get color => $_getSZ(8);
  @$pb.TagNumber(9)
  set color($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasColor() => $_has(8);
  @$pb.TagNumber(9)
  void clearColor() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get chartCode => $_getSZ(9);
  @$pb.TagNumber(10)
  set chartCode($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasChartCode() => $_has(9);
  @$pb.TagNumber(10)
  void clearChartCode() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.String get parentId => $_getSZ(10);
  @$pb.TagNumber(11)
  set parentId($core.String value) => $_setString(10, value);
  @$pb.TagNumber(11)
  $core.bool hasParentId() => $_has(10);
  @$pb.TagNumber(11)
  void clearParentId() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.String get institution => $_getSZ(11);
  @$pb.TagNumber(12)
  set institution($core.String value) => $_setString(11, value);
  @$pb.TagNumber(12)
  $core.bool hasInstitution() => $_has(11);
  @$pb.TagNumber(12)
  void clearInstitution() => $_clearField(12);

  @$pb.TagNumber(13)
  $fixnum.Int64 get creditLimitCents => $_getI64(12);
  @$pb.TagNumber(13)
  set creditLimitCents($fixnum.Int64 value) => $_setInt64(12, value);
  @$pb.TagNumber(13)
  $core.bool hasCreditLimitCents() => $_has(12);
  @$pb.TagNumber(13)
  void clearCreditLimitCents() => $_clearField(13);

  @$pb.TagNumber(14)
  AccountStatus get status => $_getN(13);
  @$pb.TagNumber(14)
  set status(AccountStatus value) => $_setField(14, value);
  @$pb.TagNumber(14)
  $core.bool hasStatus() => $_has(13);
  @$pb.TagNumber(14)
  void clearStatus() => $_clearField(14);

  @$pb.TagNumber(15)
  $fixnum.Int64 get version => $_getI64(14);
  @$pb.TagNumber(15)
  set version($fixnum.Int64 value) => $_setInt64(14, value);
  @$pb.TagNumber(15)
  $core.bool hasVersion() => $_has(14);
  @$pb.TagNumber(15)
  void clearVersion() => $_clearField(15);

  @$pb.TagNumber(16)
  $2.Timestamp get createdAt => $_getN(15);
  @$pb.TagNumber(16)
  set createdAt($2.Timestamp value) => $_setField(16, value);
  @$pb.TagNumber(16)
  $core.bool hasCreatedAt() => $_has(15);
  @$pb.TagNumber(16)
  void clearCreatedAt() => $_clearField(16);
  @$pb.TagNumber(16)
  $2.Timestamp ensureCreatedAt() => $_ensure(15);

  @$pb.TagNumber(17)
  $2.Timestamp get updatedAt => $_getN(16);
  @$pb.TagNumber(17)
  set updatedAt($2.Timestamp value) => $_setField(17, value);
  @$pb.TagNumber(17)
  $core.bool hasUpdatedAt() => $_has(16);
  @$pb.TagNumber(17)
  void clearUpdatedAt() => $_clearField(17);
  @$pb.TagNumber(17)
  $2.Timestamp ensureUpdatedAt() => $_ensure(16);

  @$pb.TagNumber(18)
  AccountCategory get category => $_getN(17);
  @$pb.TagNumber(18)
  set category(AccountCategory value) => $_setField(18, value);
  @$pb.TagNumber(18)
  $core.bool hasCategory() => $_has(17);
  @$pb.TagNumber(18)
  void clearCategory() => $_clearField(18);
}

class CreateAccountRequest extends $pb.GeneratedMessage {
  factory CreateAccountRequest({
    $core.String? name,
    AccountType? accountType,
    $core.String? currencyCode,
    $fixnum.Int64? initialBalanceCents,
    Ownership? ownership,
    $core.String? icon,
    $core.String? color,
    $core.String? chartCode,
    $core.String? parentId,
    $core.String? institution,
    $fixnum.Int64? creditLimitCents,
    AccountCategory? category,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (accountType != null) result.accountType = accountType;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (initialBalanceCents != null)
      result.initialBalanceCents = initialBalanceCents;
    if (ownership != null) result.ownership = ownership;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (chartCode != null) result.chartCode = chartCode;
    if (parentId != null) result.parentId = parentId;
    if (institution != null) result.institution = institution;
    if (creditLimitCents != null) result.creditLimitCents = creditLimitCents;
    if (category != null) result.category = category;
    return result;
  }

  CreateAccountRequest._();

  factory CreateAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateAccountRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'name')
    ..aE<AccountType>(2, _omitFieldNames ? '' : 'accountType',
        enumValues: AccountType.values)
    ..aOS(3, _omitFieldNames ? '' : 'currencyCode')
    ..aInt64(4, _omitFieldNames ? '' : 'initialBalanceCents')
    ..aE<Ownership>(5, _omitFieldNames ? '' : 'ownership',
        enumValues: Ownership.values)
    ..aOS(6, _omitFieldNames ? '' : 'icon')
    ..aOS(7, _omitFieldNames ? '' : 'color')
    ..aOS(8, _omitFieldNames ? '' : 'chartCode')
    ..aOS(9, _omitFieldNames ? '' : 'parentId')
    ..aOS(10, _omitFieldNames ? '' : 'institution')
    ..aInt64(11, _omitFieldNames ? '' : 'creditLimitCents')
    ..aE<AccountCategory>(12, _omitFieldNames ? '' : 'category',
        enumValues: AccountCategory.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateAccountRequest copyWith(void Function(CreateAccountRequest) updates) =>
      super.copyWith((message) => updates(message as CreateAccountRequest))
          as CreateAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateAccountRequest create() => CreateAccountRequest._();
  @$core.override
  CreateAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateAccountRequest>(create);
  static CreateAccountRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  AccountType get accountType => $_getN(1);
  @$pb.TagNumber(2)
  set accountType(AccountType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountType() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountType() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get currencyCode => $_getSZ(2);
  @$pb.TagNumber(3)
  set currencyCode($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCurrencyCode() => $_has(2);
  @$pb.TagNumber(3)
  void clearCurrencyCode() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get initialBalanceCents => $_getI64(3);
  @$pb.TagNumber(4)
  set initialBalanceCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasInitialBalanceCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearInitialBalanceCents() => $_clearField(4);

  @$pb.TagNumber(5)
  Ownership get ownership => $_getN(4);
  @$pb.TagNumber(5)
  set ownership(Ownership value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasOwnership() => $_has(4);
  @$pb.TagNumber(5)
  void clearOwnership() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get icon => $_getSZ(5);
  @$pb.TagNumber(6)
  set icon($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIcon() => $_has(5);
  @$pb.TagNumber(6)
  void clearIcon() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get color => $_getSZ(6);
  @$pb.TagNumber(7)
  set color($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasColor() => $_has(6);
  @$pb.TagNumber(7)
  void clearColor() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.String get chartCode => $_getSZ(7);
  @$pb.TagNumber(8)
  set chartCode($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasChartCode() => $_has(7);
  @$pb.TagNumber(8)
  void clearChartCode() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get parentId => $_getSZ(8);
  @$pb.TagNumber(9)
  set parentId($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasParentId() => $_has(8);
  @$pb.TagNumber(9)
  void clearParentId() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get institution => $_getSZ(9);
  @$pb.TagNumber(10)
  set institution($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasInstitution() => $_has(9);
  @$pb.TagNumber(10)
  void clearInstitution() => $_clearField(10);

  @$pb.TagNumber(11)
  $fixnum.Int64 get creditLimitCents => $_getI64(10);
  @$pb.TagNumber(11)
  set creditLimitCents($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasCreditLimitCents() => $_has(10);
  @$pb.TagNumber(11)
  void clearCreditLimitCents() => $_clearField(11);

  @$pb.TagNumber(12)
  AccountCategory get category => $_getN(11);
  @$pb.TagNumber(12)
  set category(AccountCategory value) => $_setField(12, value);
  @$pb.TagNumber(12)
  $core.bool hasCategory() => $_has(11);
  @$pb.TagNumber(12)
  void clearCategory() => $_clearField(12);
}

class GetAccountRequest extends $pb.GeneratedMessage {
  factory GetAccountRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  GetAccountRequest._();

  factory GetAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetAccountRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetAccountRequest copyWith(void Function(GetAccountRequest) updates) =>
      super.copyWith((message) => updates(message as GetAccountRequest))
          as GetAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetAccountRequest create() => GetAccountRequest._();
  @$core.override
  GetAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetAccountRequest>(create);
  static GetAccountRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class ListAccountsRequest extends $pb.GeneratedMessage {
  factory ListAccountsRequest({
    $3.PageRequest? page,
    AccountType? accountType,
    AccountStatus? status,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (accountType != null) result.accountType = accountType;
    if (status != null) result.status = status;
    return result;
  }

  ListAccountsRequest._();

  factory ListAccountsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListAccountsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListAccountsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOM<$3.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageRequest.create)
    ..aE<AccountType>(2, _omitFieldNames ? '' : 'accountType',
        enumValues: AccountType.values)
    ..aE<AccountStatus>(3, _omitFieldNames ? '' : 'status',
        enumValues: AccountStatus.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAccountsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAccountsRequest copyWith(void Function(ListAccountsRequest) updates) =>
      super.copyWith((message) => updates(message as ListAccountsRequest))
          as ListAccountsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListAccountsRequest create() => ListAccountsRequest._();
  @$core.override
  ListAccountsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListAccountsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListAccountsRequest>(create);
  static ListAccountsRequest? _defaultInstance;

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
  AccountType get accountType => $_getN(1);
  @$pb.TagNumber(2)
  set accountType(AccountType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountType() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountType() => $_clearField(2);

  @$pb.TagNumber(3)
  AccountStatus get status => $_getN(2);
  @$pb.TagNumber(3)
  set status(AccountStatus value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasStatus() => $_has(2);
  @$pb.TagNumber(3)
  void clearStatus() => $_clearField(3);
}

class ListAccountsResponse extends $pb.GeneratedMessage {
  factory ListAccountsResponse({
    $core.Iterable<AccountDTO>? accounts,
    $3.PageResponse? page,
  }) {
    final result = create();
    if (accounts != null) result.accounts.addAll(accounts);
    if (page != null) result.page = page;
    return result;
  }

  ListAccountsResponse._();

  factory ListAccountsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListAccountsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListAccountsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..pPM<AccountDTO>(1, _omitFieldNames ? '' : 'accounts',
        subBuilder: AccountDTO.create)
    ..aOM<$3.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $3.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAccountsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListAccountsResponse copyWith(void Function(ListAccountsResponse) updates) =>
      super.copyWith((message) => updates(message as ListAccountsResponse))
          as ListAccountsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListAccountsResponse create() => ListAccountsResponse._();
  @$core.override
  ListAccountsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListAccountsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListAccountsResponse>(create);
  static ListAccountsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<AccountDTO> get accounts => $_getList(0);

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

class UpdateAccountRequest extends $pb.GeneratedMessage {
  factory UpdateAccountRequest({
    $core.String? id,
    $core.String? name,
    $core.String? icon,
    $core.String? color,
    $core.String? chartCode,
    $core.String? institution,
    $fixnum.Int64? creditLimitCents,
    $fixnum.Int64? version,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (name != null) result.name = name;
    if (icon != null) result.icon = icon;
    if (color != null) result.color = color;
    if (chartCode != null) result.chartCode = chartCode;
    if (institution != null) result.institution = institution;
    if (creditLimitCents != null) result.creditLimitCents = creditLimitCents;
    if (version != null) result.version = version;
    return result;
  }

  UpdateAccountRequest._();

  factory UpdateAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateAccountRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'icon')
    ..aOS(4, _omitFieldNames ? '' : 'color')
    ..aOS(5, _omitFieldNames ? '' : 'chartCode')
    ..aOS(6, _omitFieldNames ? '' : 'institution')
    ..aInt64(7, _omitFieldNames ? '' : 'creditLimitCents')
    ..aInt64(8, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateAccountRequest copyWith(void Function(UpdateAccountRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateAccountRequest))
          as UpdateAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateAccountRequest create() => UpdateAccountRequest._();
  @$core.override
  UpdateAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateAccountRequest>(create);
  static UpdateAccountRequest? _defaultInstance;

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
  $core.String get chartCode => $_getSZ(4);
  @$pb.TagNumber(5)
  set chartCode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasChartCode() => $_has(4);
  @$pb.TagNumber(5)
  void clearChartCode() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get institution => $_getSZ(5);
  @$pb.TagNumber(6)
  set institution($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasInstitution() => $_has(5);
  @$pb.TagNumber(6)
  void clearInstitution() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get creditLimitCents => $_getI64(6);
  @$pb.TagNumber(7)
  set creditLimitCents($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCreditLimitCents() => $_has(6);
  @$pb.TagNumber(7)
  void clearCreditLimitCents() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get version => $_getI64(7);
  @$pb.TagNumber(8)
  set version($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasVersion() => $_has(7);
  @$pb.TagNumber(8)
  void clearVersion() => $_clearField(8);
}

class DeleteAccountRequest extends $pb.GeneratedMessage {
  factory DeleteAccountRequest({
    $core.String? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  DeleteAccountRequest._();

  factory DeleteAccountRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeleteAccountRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeleteAccountRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeleteAccountRequest copyWith(void Function(DeleteAccountRequest) updates) =>
      super.copyWith((message) => updates(message as DeleteAccountRequest))
          as DeleteAccountRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeleteAccountRequest create() => DeleteAccountRequest._();
  @$core.override
  DeleteAccountRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeleteAccountRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeleteAccountRequest>(create);
  static DeleteAccountRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

class AccountResponse extends $pb.GeneratedMessage {
  factory AccountResponse({
    AccountDTO? account,
  }) {
    final result = create();
    if (account != null) result.account = account;
    return result;
  }

  AccountResponse._();

  factory AccountResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AccountResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AccountResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.account.v1'),
      createEmptyInstance: create)
    ..aOM<AccountDTO>(1, _omitFieldNames ? '' : 'account',
        subBuilder: AccountDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AccountResponse copyWith(void Function(AccountResponse) updates) =>
      super.copyWith((message) => updates(message as AccountResponse))
          as AccountResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AccountResponse create() => AccountResponse._();
  @$core.override
  AccountResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AccountResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AccountResponse>(create);
  static AccountResponse? _defaultInstance;

  @$pb.TagNumber(1)
  AccountDTO get account => $_getN(0);
  @$pb.TagNumber(1)
  set account(AccountDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasAccount() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccount() => $_clearField(1);
  @$pb.TagNumber(1)
  AccountDTO ensureAccount() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
