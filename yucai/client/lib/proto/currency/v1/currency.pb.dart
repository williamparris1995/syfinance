// This is a generated file - do not edit.
//
// Generated from currency/v1/currency.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../../common/v1/pagination.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class CurrencyDTO extends $pb.GeneratedMessage {
  factory CurrencyDTO({
    $core.String? id,
    $core.String? code,
    $core.String? name,
    $core.String? symbol,
    $core.double? exchangeRate,
    $core.bool? isActive,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (code != null) result.code = code;
    if (name != null) result.name = name;
    if (symbol != null) result.symbol = symbol;
    if (exchangeRate != null) result.exchangeRate = exchangeRate;
    if (isActive != null) result.isActive = isActive;
    return result;
  }

  CurrencyDTO._();

  factory CurrencyDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CurrencyDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CurrencyDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.currency.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'code')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aOS(4, _omitFieldNames ? '' : 'symbol')
    ..aD(5, _omitFieldNames ? '' : 'exchangeRate')
    ..aOB(6, _omitFieldNames ? '' : 'isActive')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CurrencyDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CurrencyDTO copyWith(void Function(CurrencyDTO) updates) =>
      super.copyWith((message) => updates(message as CurrencyDTO))
          as CurrencyDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CurrencyDTO create() => CurrencyDTO._();
  @$core.override
  CurrencyDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CurrencyDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CurrencyDTO>(create);
  static CurrencyDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get code => $_getSZ(1);
  @$pb.TagNumber(2)
  set code($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCode() => $_has(1);
  @$pb.TagNumber(2)
  void clearCode() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get symbol => $_getSZ(3);
  @$pb.TagNumber(4)
  set symbol($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSymbol() => $_has(3);
  @$pb.TagNumber(4)
  void clearSymbol() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get exchangeRate => $_getN(4);
  @$pb.TagNumber(5)
  set exchangeRate($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExchangeRate() => $_has(4);
  @$pb.TagNumber(5)
  void clearExchangeRate() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get isActive => $_getBF(5);
  @$pb.TagNumber(6)
  set isActive($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasIsActive() => $_has(5);
  @$pb.TagNumber(6)
  void clearIsActive() => $_clearField(6);
}

class AddCurrencyRequest extends $pb.GeneratedMessage {
  factory AddCurrencyRequest({
    $core.String? code,
    $core.String? name,
    $core.String? symbol,
    $core.double? exchangeRate,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (name != null) result.name = name;
    if (symbol != null) result.symbol = symbol;
    if (exchangeRate != null) result.exchangeRate = exchangeRate;
    return result;
  }

  AddCurrencyRequest._();

  factory AddCurrencyRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory AddCurrencyRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'AddCurrencyRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.currency.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aOS(3, _omitFieldNames ? '' : 'symbol')
    ..aD(4, _omitFieldNames ? '' : 'exchangeRate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddCurrencyRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  AddCurrencyRequest copyWith(void Function(AddCurrencyRequest) updates) =>
      super.copyWith((message) => updates(message as AddCurrencyRequest))
          as AddCurrencyRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static AddCurrencyRequest create() => AddCurrencyRequest._();
  @$core.override
  AddCurrencyRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static AddCurrencyRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<AddCurrencyRequest>(create);
  static AddCurrencyRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get symbol => $_getSZ(2);
  @$pb.TagNumber(3)
  set symbol($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSymbol() => $_has(2);
  @$pb.TagNumber(3)
  void clearSymbol() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get exchangeRate => $_getN(3);
  @$pb.TagNumber(4)
  set exchangeRate($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExchangeRate() => $_has(3);
  @$pb.TagNumber(4)
  void clearExchangeRate() => $_clearField(4);
}

class UpdateRateRequest extends $pb.GeneratedMessage {
  factory UpdateRateRequest({
    $core.String? id,
    $core.double? exchangeRate,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (exchangeRate != null) result.exchangeRate = exchangeRate;
    return result;
  }

  UpdateRateRequest._();

  factory UpdateRateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateRateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateRateRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.currency.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aD(2, _omitFieldNames ? '' : 'exchangeRate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateRateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateRateRequest copyWith(void Function(UpdateRateRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateRateRequest))
          as UpdateRateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateRateRequest create() => UpdateRateRequest._();
  @$core.override
  UpdateRateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateRateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateRateRequest>(create);
  static UpdateRateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get exchangeRate => $_getN(1);
  @$pb.TagNumber(2)
  set exchangeRate($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExchangeRate() => $_has(1);
  @$pb.TagNumber(2)
  void clearExchangeRate() => $_clearField(2);
}

class FetchRateRequest extends $pb.GeneratedMessage {
  factory FetchRateRequest({
    $core.String? code,
  }) {
    final result = create();
    if (code != null) result.code = code;
    return result;
  }

  FetchRateRequest._();

  factory FetchRateRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FetchRateRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FetchRateRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.currency.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchRateRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchRateRequest copyWith(void Function(FetchRateRequest) updates) =>
      super.copyWith((message) => updates(message as FetchRateRequest))
          as FetchRateRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FetchRateRequest create() => FetchRateRequest._();
  @$core.override
  FetchRateRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FetchRateRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FetchRateRequest>(create);
  static FetchRateRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);
}

class FetchRateResponse extends $pb.GeneratedMessage {
  factory FetchRateResponse({
    $core.String? code,
    $core.double? exchangeRate,
  }) {
    final result = create();
    if (code != null) result.code = code;
    if (exchangeRate != null) result.exchangeRate = exchangeRate;
    return result;
  }

  FetchRateResponse._();

  factory FetchRateResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FetchRateResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FetchRateResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.currency.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'code')
    ..aD(2, _omitFieldNames ? '' : 'exchangeRate')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchRateResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FetchRateResponse copyWith(void Function(FetchRateResponse) updates) =>
      super.copyWith((message) => updates(message as FetchRateResponse))
          as FetchRateResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FetchRateResponse create() => FetchRateResponse._();
  @$core.override
  FetchRateResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FetchRateResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FetchRateResponse>(create);
  static FetchRateResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get code => $_getSZ(0);
  @$pb.TagNumber(1)
  set code($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasCode() => $_has(0);
  @$pb.TagNumber(1)
  void clearCode() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get exchangeRate => $_getN(1);
  @$pb.TagNumber(2)
  set exchangeRate($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasExchangeRate() => $_has(1);
  @$pb.TagNumber(2)
  void clearExchangeRate() => $_clearField(2);
}

class ListCurrenciesRequest extends $pb.GeneratedMessage {
  factory ListCurrenciesRequest({
    $0.PageRequest? page,
    $core.bool? activeOnly,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (activeOnly != null) result.activeOnly = activeOnly;
    return result;
  }

  ListCurrenciesRequest._();

  factory ListCurrenciesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListCurrenciesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListCurrenciesRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.currency.v1'),
      createEmptyInstance: create)
    ..aOM<$0.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $0.PageRequest.create)
    ..aOB(2, _omitFieldNames ? '' : 'activeOnly')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCurrenciesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCurrenciesRequest copyWith(
          void Function(ListCurrenciesRequest) updates) =>
      super.copyWith((message) => updates(message as ListCurrenciesRequest))
          as ListCurrenciesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListCurrenciesRequest create() => ListCurrenciesRequest._();
  @$core.override
  ListCurrenciesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListCurrenciesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListCurrenciesRequest>(create);
  static ListCurrenciesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $0.PageRequest get page => $_getN(0);
  @$pb.TagNumber(1)
  set page($0.PageRequest value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPage() => $_has(0);
  @$pb.TagNumber(1)
  void clearPage() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.PageRequest ensurePage() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.bool get activeOnly => $_getBF(1);
  @$pb.TagNumber(2)
  set activeOnly($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasActiveOnly() => $_has(1);
  @$pb.TagNumber(2)
  void clearActiveOnly() => $_clearField(2);
}

class ListCurrenciesResponse extends $pb.GeneratedMessage {
  factory ListCurrenciesResponse({
    $core.Iterable<CurrencyDTO>? currencies,
    $0.PageResponse? page,
  }) {
    final result = create();
    if (currencies != null) result.currencies.addAll(currencies);
    if (page != null) result.page = page;
    return result;
  }

  ListCurrenciesResponse._();

  factory ListCurrenciesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListCurrenciesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListCurrenciesResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.currency.v1'),
      createEmptyInstance: create)
    ..pPM<CurrencyDTO>(1, _omitFieldNames ? '' : 'currencies',
        subBuilder: CurrencyDTO.create)
    ..aOM<$0.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $0.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCurrenciesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListCurrenciesResponse copyWith(
          void Function(ListCurrenciesResponse) updates) =>
      super.copyWith((message) => updates(message as ListCurrenciesResponse))
          as ListCurrenciesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListCurrenciesResponse create() => ListCurrenciesResponse._();
  @$core.override
  ListCurrenciesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListCurrenciesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListCurrenciesResponse>(create);
  static ListCurrenciesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<CurrencyDTO> get currencies => $_getList(0);

  @$pb.TagNumber(2)
  $0.PageResponse get page => $_getN(1);
  @$pb.TagNumber(2)
  set page($0.PageResponse value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(2)
  void clearPage() => $_clearField(2);
  @$pb.TagNumber(2)
  $0.PageResponse ensurePage() => $_ensure(1);
}

class CurrencyResponse extends $pb.GeneratedMessage {
  factory CurrencyResponse({
    CurrencyDTO? currency,
  }) {
    final result = create();
    if (currency != null) result.currency = currency;
    return result;
  }

  CurrencyResponse._();

  factory CurrencyResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CurrencyResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CurrencyResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.currency.v1'),
      createEmptyInstance: create)
    ..aOM<CurrencyDTO>(1, _omitFieldNames ? '' : 'currency',
        subBuilder: CurrencyDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CurrencyResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CurrencyResponse copyWith(void Function(CurrencyResponse) updates) =>
      super.copyWith((message) => updates(message as CurrencyResponse))
          as CurrencyResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CurrencyResponse create() => CurrencyResponse._();
  @$core.override
  CurrencyResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CurrencyResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CurrencyResponse>(create);
  static CurrencyResponse? _defaultInstance;

  @$pb.TagNumber(1)
  CurrencyDTO get currency => $_getN(0);
  @$pb.TagNumber(1)
  set currency(CurrencyDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasCurrency() => $_has(0);
  @$pb.TagNumber(1)
  void clearCurrency() => $_clearField(1);
  @$pb.TagNumber(1)
  CurrencyDTO ensureCurrency() => $_ensure(0);
}

class CurrencyServiceApi {
  final $pb.RpcClient _client;

  CurrencyServiceApi(this._client);

  $async.Future<ListCurrenciesResponse> listCurrencies(
          $pb.ClientContext? ctx, ListCurrenciesRequest request) =>
      _client.invoke<ListCurrenciesResponse>(ctx, 'CurrencyService',
          'ListCurrencies', request, ListCurrenciesResponse());
  $async.Future<CurrencyResponse> addCurrency(
          $pb.ClientContext? ctx, AddCurrencyRequest request) =>
      _client.invoke<CurrencyResponse>(
          ctx, 'CurrencyService', 'AddCurrency', request, CurrencyResponse());
  $async.Future<CurrencyResponse> updateExchangeRate(
          $pb.ClientContext? ctx, UpdateRateRequest request) =>
      _client.invoke<CurrencyResponse>(ctx, 'CurrencyService',
          'UpdateExchangeRate', request, CurrencyResponse());
  $async.Future<FetchRateResponse> fetchExchangeRate(
          $pb.ClientContext? ctx, FetchRateRequest request) =>
      _client.invoke<FetchRateResponse>(ctx, 'CurrencyService',
          'FetchExchangeRate', request, FetchRateResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
