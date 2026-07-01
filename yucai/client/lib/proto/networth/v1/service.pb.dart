// This is a generated file - do not edit.
//
// Generated from networth/v1/service.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class GetNetWorthRequest extends $pb.GeneratedMessage {
  factory GetNetWorthRequest({
    $core.String? baseCurrency,
  }) {
    final result = create();
    if (baseCurrency != null) result.baseCurrency = baseCurrency;
    return result;
  }

  GetNetWorthRequest._();

  factory GetNetWorthRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetNetWorthRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetNetWorthRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.networth.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'baseCurrency')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetNetWorthRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetNetWorthRequest copyWith(void Function(GetNetWorthRequest) updates) =>
      super.copyWith((message) => updates(message as GetNetWorthRequest))
          as GetNetWorthRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetNetWorthRequest create() => GetNetWorthRequest._();
  @$core.override
  GetNetWorthRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetNetWorthRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetNetWorthRequest>(create);
  static GetNetWorthRequest? _defaultInstance;

  /// base_currency is the target currency to 折算 into. Empty (or "CNY") means
  /// no conversion — sources sum raw. Users may set their preferred base (e.g.
  /// "USD"); the server resolves the CNY→base cross rate server-side.
  @$pb.TagNumber(1)
  $core.String get baseCurrency => $_getSZ(0);
  @$pb.TagNumber(1)
  set baseCurrency($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBaseCurrency() => $_has(0);
  @$pb.TagNumber(1)
  void clearBaseCurrency() => $_clearField(1);
}

class GetNetWorthResponse extends $pb.GeneratedMessage {
  factory GetNetWorthResponse({
    $fixnum.Int64? totalAssetsCents,
    $fixnum.Int64? totalLiabilitiesCents,
    $fixnum.Int64? netWorthCents,
    $core.String? currency,
  }) {
    final result = create();
    if (totalAssetsCents != null) result.totalAssetsCents = totalAssetsCents;
    if (totalLiabilitiesCents != null)
      result.totalLiabilitiesCents = totalLiabilitiesCents;
    if (netWorthCents != null) result.netWorthCents = netWorthCents;
    if (currency != null) result.currency = currency;
    return result;
  }

  GetNetWorthResponse._();

  factory GetNetWorthResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetNetWorthResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetNetWorthResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.networth.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'totalAssetsCents')
    ..aInt64(2, _omitFieldNames ? '' : 'totalLiabilitiesCents')
    ..aInt64(3, _omitFieldNames ? '' : 'netWorthCents')
    ..aOS(4, _omitFieldNames ? '' : 'currency')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetNetWorthResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetNetWorthResponse copyWith(void Function(GetNetWorthResponse) updates) =>
      super.copyWith((message) => updates(message as GetNetWorthResponse))
          as GetNetWorthResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetNetWorthResponse create() => GetNetWorthResponse._();
  @$core.override
  GetNetWorthResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetNetWorthResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetNetWorthResponse>(create);
  static GetNetWorthResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get totalAssetsCents => $_getI64(0);
  @$pb.TagNumber(1)
  set totalAssetsCents($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasTotalAssetsCents() => $_has(0);
  @$pb.TagNumber(1)
  void clearTotalAssetsCents() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get totalLiabilitiesCents => $_getI64(1);
  @$pb.TagNumber(2)
  set totalLiabilitiesCents($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTotalLiabilitiesCents() => $_has(1);
  @$pb.TagNumber(2)
  void clearTotalLiabilitiesCents() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get netWorthCents => $_getI64(2);
  @$pb.TagNumber(3)
  set netWorthCents($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasNetWorthCents() => $_has(2);
  @$pb.TagNumber(3)
  void clearNetWorthCents() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get currency => $_getSZ(3);
  @$pb.TagNumber(4)
  set currency($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCurrency() => $_has(3);
  @$pb.TagNumber(4)
  void clearCurrency() => $_clearField(4);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
