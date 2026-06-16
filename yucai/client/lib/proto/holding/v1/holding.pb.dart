// This is a generated file - do not edit.
//
// Generated from holding/v1/holding.proto.

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
import 'holding.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'holding.pbenum.dart';

class SecurityDTO extends $pb.GeneratedMessage {
  factory SecurityDTO({
    $core.String? id,
    $core.String? symbol,
    $core.String? name,
    SecurityType? securityType,
    $core.String? exchange,
    $core.String? currencyCode,
    $fixnum.Int64? currentPriceCents,
    $0.Timestamp? createdAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (symbol != null) result.symbol = symbol;
    if (name != null) result.name = name;
    if (securityType != null) result.securityType = securityType;
    if (exchange != null) result.exchange = exchange;
    if (currencyCode != null) result.currencyCode = currencyCode;
    if (currentPriceCents != null) result.currentPriceCents = currentPriceCents;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  SecurityDTO._();

  factory SecurityDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SecurityDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SecurityDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'symbol')
    ..aOS(3, _omitFieldNames ? '' : 'name')
    ..aE<SecurityType>(4, _omitFieldNames ? '' : 'securityType',
        enumValues: SecurityType.values)
    ..aOS(5, _omitFieldNames ? '' : 'exchange')
    ..aOS(6, _omitFieldNames ? '' : 'currencyCode')
    ..aInt64(7, _omitFieldNames ? '' : 'currentPriceCents')
    ..aOM<$0.Timestamp>(8, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $0.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecurityDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecurityDTO copyWith(void Function(SecurityDTO) updates) =>
      super.copyWith((message) => updates(message as SecurityDTO))
          as SecurityDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SecurityDTO create() => SecurityDTO._();
  @$core.override
  SecurityDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SecurityDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SecurityDTO>(create);
  static SecurityDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get symbol => $_getSZ(1);
  @$pb.TagNumber(2)
  set symbol($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSymbol() => $_has(1);
  @$pb.TagNumber(2)
  void clearSymbol() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get name => $_getSZ(2);
  @$pb.TagNumber(3)
  set name($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasName() => $_has(2);
  @$pb.TagNumber(3)
  void clearName() => $_clearField(3);

  @$pb.TagNumber(4)
  SecurityType get securityType => $_getN(3);
  @$pb.TagNumber(4)
  set securityType(SecurityType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasSecurityType() => $_has(3);
  @$pb.TagNumber(4)
  void clearSecurityType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get exchange => $_getSZ(4);
  @$pb.TagNumber(5)
  set exchange($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasExchange() => $_has(4);
  @$pb.TagNumber(5)
  void clearExchange() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get currencyCode => $_getSZ(5);
  @$pb.TagNumber(6)
  set currencyCode($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCurrencyCode() => $_has(5);
  @$pb.TagNumber(6)
  void clearCurrencyCode() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get currentPriceCents => $_getI64(6);
  @$pb.TagNumber(7)
  set currentPriceCents($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasCurrentPriceCents() => $_has(6);
  @$pb.TagNumber(7)
  void clearCurrentPriceCents() => $_clearField(7);

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

class HoldingDTO extends $pb.GeneratedMessage {
  factory HoldingDTO({
    $core.String? id,
    $core.String? accountId,
    $core.String? securityId,
    $core.String? securityName,
    $core.String? securitySymbol,
    $core.double? quantity,
    $fixnum.Int64? avgCostCents,
    $fixnum.Int64? marketValueCents,
    $fixnum.Int64? unrealizedPnlCents,
    $fixnum.Int64? version,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (accountId != null) result.accountId = accountId;
    if (securityId != null) result.securityId = securityId;
    if (securityName != null) result.securityName = securityName;
    if (securitySymbol != null) result.securitySymbol = securitySymbol;
    if (quantity != null) result.quantity = quantity;
    if (avgCostCents != null) result.avgCostCents = avgCostCents;
    if (marketValueCents != null) result.marketValueCents = marketValueCents;
    if (unrealizedPnlCents != null)
      result.unrealizedPnlCents = unrealizedPnlCents;
    if (version != null) result.version = version;
    return result;
  }

  HoldingDTO._();

  factory HoldingDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HoldingDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HoldingDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'accountId')
    ..aOS(3, _omitFieldNames ? '' : 'securityId')
    ..aOS(4, _omitFieldNames ? '' : 'securityName')
    ..aOS(5, _omitFieldNames ? '' : 'securitySymbol')
    ..aD(6, _omitFieldNames ? '' : 'quantity')
    ..aInt64(7, _omitFieldNames ? '' : 'avgCostCents')
    ..aInt64(8, _omitFieldNames ? '' : 'marketValueCents')
    ..aInt64(9, _omitFieldNames ? '' : 'unrealizedPnlCents')
    ..aInt64(10, _omitFieldNames ? '' : 'version')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HoldingDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HoldingDTO copyWith(void Function(HoldingDTO) updates) =>
      super.copyWith((message) => updates(message as HoldingDTO)) as HoldingDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HoldingDTO create() => HoldingDTO._();
  @$core.override
  HoldingDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HoldingDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HoldingDTO>(create);
  static HoldingDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get accountId => $_getSZ(1);
  @$pb.TagNumber(2)
  set accountId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get securityId => $_getSZ(2);
  @$pb.TagNumber(3)
  set securityId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSecurityId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSecurityId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get securityName => $_getSZ(3);
  @$pb.TagNumber(4)
  set securityName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSecurityName() => $_has(3);
  @$pb.TagNumber(4)
  void clearSecurityName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get securitySymbol => $_getSZ(4);
  @$pb.TagNumber(5)
  set securitySymbol($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasSecuritySymbol() => $_has(4);
  @$pb.TagNumber(5)
  void clearSecuritySymbol() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get quantity => $_getN(5);
  @$pb.TagNumber(6)
  set quantity($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasQuantity() => $_has(5);
  @$pb.TagNumber(6)
  void clearQuantity() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get avgCostCents => $_getI64(6);
  @$pb.TagNumber(7)
  set avgCostCents($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAvgCostCents() => $_has(6);
  @$pb.TagNumber(7)
  void clearAvgCostCents() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get marketValueCents => $_getI64(7);
  @$pb.TagNumber(8)
  set marketValueCents($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMarketValueCents() => $_has(7);
  @$pb.TagNumber(8)
  void clearMarketValueCents() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get unrealizedPnlCents => $_getI64(8);
  @$pb.TagNumber(9)
  set unrealizedPnlCents($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUnrealizedPnlCents() => $_has(8);
  @$pb.TagNumber(9)
  void clearUnrealizedPnlCents() => $_clearField(9);

  @$pb.TagNumber(10)
  $fixnum.Int64 get version => $_getI64(9);
  @$pb.TagNumber(10)
  set version($fixnum.Int64 value) => $_setInt64(9, value);
  @$pb.TagNumber(10)
  $core.bool hasVersion() => $_has(9);
  @$pb.TagNumber(10)
  void clearVersion() => $_clearField(10);
}

class HoldingTransactionDTO extends $pb.GeneratedMessage {
  factory HoldingTransactionDTO({
    $core.String? id,
    $core.String? accountId,
    $core.String? securityId,
    TradeType? tradeType,
    $core.double? quantity,
    $fixnum.Int64? priceCents,
    $fixnum.Int64? amountCents,
    $fixnum.Int64? feeCents,
    $core.String? tradeDate,
    $core.String? notes,
    $0.Timestamp? createdAt,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (accountId != null) result.accountId = accountId;
    if (securityId != null) result.securityId = securityId;
    if (tradeType != null) result.tradeType = tradeType;
    if (quantity != null) result.quantity = quantity;
    if (priceCents != null) result.priceCents = priceCents;
    if (amountCents != null) result.amountCents = amountCents;
    if (feeCents != null) result.feeCents = feeCents;
    if (tradeDate != null) result.tradeDate = tradeDate;
    if (notes != null) result.notes = notes;
    if (createdAt != null) result.createdAt = createdAt;
    return result;
  }

  HoldingTransactionDTO._();

  factory HoldingTransactionDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HoldingTransactionDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HoldingTransactionDTO',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'accountId')
    ..aOS(3, _omitFieldNames ? '' : 'securityId')
    ..aE<TradeType>(4, _omitFieldNames ? '' : 'tradeType',
        enumValues: TradeType.values)
    ..aD(5, _omitFieldNames ? '' : 'quantity')
    ..aInt64(6, _omitFieldNames ? '' : 'priceCents')
    ..aInt64(7, _omitFieldNames ? '' : 'amountCents')
    ..aInt64(8, _omitFieldNames ? '' : 'feeCents')
    ..aOS(9, _omitFieldNames ? '' : 'tradeDate')
    ..aOS(10, _omitFieldNames ? '' : 'notes')
    ..aOM<$0.Timestamp>(11, _omitFieldNames ? '' : 'createdAt',
        subBuilder: $0.Timestamp.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HoldingTransactionDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HoldingTransactionDTO copyWith(
          void Function(HoldingTransactionDTO) updates) =>
      super.copyWith((message) => updates(message as HoldingTransactionDTO))
          as HoldingTransactionDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HoldingTransactionDTO create() => HoldingTransactionDTO._();
  @$core.override
  HoldingTransactionDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HoldingTransactionDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HoldingTransactionDTO>(create);
  static HoldingTransactionDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get accountId => $_getSZ(1);
  @$pb.TagNumber(2)
  set accountId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAccountId() => $_has(1);
  @$pb.TagNumber(2)
  void clearAccountId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get securityId => $_getSZ(2);
  @$pb.TagNumber(3)
  set securityId($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasSecurityId() => $_has(2);
  @$pb.TagNumber(3)
  void clearSecurityId() => $_clearField(3);

  @$pb.TagNumber(4)
  TradeType get tradeType => $_getN(3);
  @$pb.TagNumber(4)
  set tradeType(TradeType value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasTradeType() => $_has(3);
  @$pb.TagNumber(4)
  void clearTradeType() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get quantity => $_getN(4);
  @$pb.TagNumber(5)
  set quantity($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasQuantity() => $_has(4);
  @$pb.TagNumber(5)
  void clearQuantity() => $_clearField(5);

  @$pb.TagNumber(6)
  $fixnum.Int64 get priceCents => $_getI64(5);
  @$pb.TagNumber(6)
  set priceCents($fixnum.Int64 value) => $_setInt64(5, value);
  @$pb.TagNumber(6)
  $core.bool hasPriceCents() => $_has(5);
  @$pb.TagNumber(6)
  void clearPriceCents() => $_clearField(6);

  @$pb.TagNumber(7)
  $fixnum.Int64 get amountCents => $_getI64(6);
  @$pb.TagNumber(7)
  set amountCents($fixnum.Int64 value) => $_setInt64(6, value);
  @$pb.TagNumber(7)
  $core.bool hasAmountCents() => $_has(6);
  @$pb.TagNumber(7)
  void clearAmountCents() => $_clearField(7);

  @$pb.TagNumber(8)
  $fixnum.Int64 get feeCents => $_getI64(7);
  @$pb.TagNumber(8)
  set feeCents($fixnum.Int64 value) => $_setInt64(7, value);
  @$pb.TagNumber(8)
  $core.bool hasFeeCents() => $_has(7);
  @$pb.TagNumber(8)
  void clearFeeCents() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get tradeDate => $_getSZ(8);
  @$pb.TagNumber(9)
  set tradeDate($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTradeDate() => $_has(8);
  @$pb.TagNumber(9)
  void clearTradeDate() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get notes => $_getSZ(9);
  @$pb.TagNumber(10)
  set notes($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasNotes() => $_has(9);
  @$pb.TagNumber(10)
  void clearNotes() => $_clearField(10);

  @$pb.TagNumber(11)
  $0.Timestamp get createdAt => $_getN(10);
  @$pb.TagNumber(11)
  set createdAt($0.Timestamp value) => $_setField(11, value);
  @$pb.TagNumber(11)
  $core.bool hasCreatedAt() => $_has(10);
  @$pb.TagNumber(11)
  void clearCreatedAt() => $_clearField(11);
  @$pb.TagNumber(11)
  $0.Timestamp ensureCreatedAt() => $_ensure(10);
}

class CreateSecurityRequest extends $pb.GeneratedMessage {
  factory CreateSecurityRequest({
    $core.String? symbol,
    $core.String? name,
    SecurityType? securityType,
    $core.String? exchange,
    $core.String? currencyCode,
  }) {
    final result = create();
    if (symbol != null) result.symbol = symbol;
    if (name != null) result.name = name;
    if (securityType != null) result.securityType = securityType;
    if (exchange != null) result.exchange = exchange;
    if (currencyCode != null) result.currencyCode = currencyCode;
    return result;
  }

  CreateSecurityRequest._();

  factory CreateSecurityRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory CreateSecurityRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'CreateSecurityRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'symbol')
    ..aOS(2, _omitFieldNames ? '' : 'name')
    ..aE<SecurityType>(3, _omitFieldNames ? '' : 'securityType',
        enumValues: SecurityType.values)
    ..aOS(4, _omitFieldNames ? '' : 'exchange')
    ..aOS(5, _omitFieldNames ? '' : 'currencyCode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSecurityRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  CreateSecurityRequest copyWith(
          void Function(CreateSecurityRequest) updates) =>
      super.copyWith((message) => updates(message as CreateSecurityRequest))
          as CreateSecurityRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static CreateSecurityRequest create() => CreateSecurityRequest._();
  @$core.override
  CreateSecurityRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static CreateSecurityRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<CreateSecurityRequest>(create);
  static CreateSecurityRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get symbol => $_getSZ(0);
  @$pb.TagNumber(1)
  set symbol($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSymbol() => $_has(0);
  @$pb.TagNumber(1)
  void clearSymbol() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get name => $_getSZ(1);
  @$pb.TagNumber(2)
  set name($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasName() => $_has(1);
  @$pb.TagNumber(2)
  void clearName() => $_clearField(2);

  @$pb.TagNumber(3)
  SecurityType get securityType => $_getN(2);
  @$pb.TagNumber(3)
  set securityType(SecurityType value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasSecurityType() => $_has(2);
  @$pb.TagNumber(3)
  void clearSecurityType() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get exchange => $_getSZ(3);
  @$pb.TagNumber(4)
  set exchange($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasExchange() => $_has(3);
  @$pb.TagNumber(4)
  void clearExchange() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get currencyCode => $_getSZ(4);
  @$pb.TagNumber(5)
  set currencyCode($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasCurrencyCode() => $_has(4);
  @$pb.TagNumber(5)
  void clearCurrencyCode() => $_clearField(5);
}

class ListSecuritiesRequest extends $pb.GeneratedMessage {
  factory ListSecuritiesRequest({
    $1.PageRequest? page,
    SecurityType? securityType,
  }) {
    final result = create();
    if (page != null) result.page = page;
    if (securityType != null) result.securityType = securityType;
    return result;
  }

  ListSecuritiesRequest._();

  factory ListSecuritiesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListSecuritiesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSecuritiesRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOM<$1.PageRequest>(1, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageRequest.create)
    ..aE<SecurityType>(2, _omitFieldNames ? '' : 'securityType',
        enumValues: SecurityType.values)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSecuritiesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSecuritiesRequest copyWith(
          void Function(ListSecuritiesRequest) updates) =>
      super.copyWith((message) => updates(message as ListSecuritiesRequest))
          as ListSecuritiesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListSecuritiesRequest create() => ListSecuritiesRequest._();
  @$core.override
  ListSecuritiesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListSecuritiesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSecuritiesRequest>(create);
  static ListSecuritiesRequest? _defaultInstance;

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
  SecurityType get securityType => $_getN(1);
  @$pb.TagNumber(2)
  set securityType(SecurityType value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasSecurityType() => $_has(1);
  @$pb.TagNumber(2)
  void clearSecurityType() => $_clearField(2);
}

class UpdatePriceRequest extends $pb.GeneratedMessage {
  factory UpdatePriceRequest({
    $core.String? securityId,
    $fixnum.Int64? priceCents,
  }) {
    final result = create();
    if (securityId != null) result.securityId = securityId;
    if (priceCents != null) result.priceCents = priceCents;
    return result;
  }

  UpdatePriceRequest._();

  factory UpdatePriceRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePriceRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePriceRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'securityId')
    ..aInt64(2, _omitFieldNames ? '' : 'priceCents')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePriceRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePriceRequest copyWith(void Function(UpdatePriceRequest) updates) =>
      super.copyWith((message) => updates(message as UpdatePriceRequest))
          as UpdatePriceRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePriceRequest create() => UpdatePriceRequest._();
  @$core.override
  UpdatePriceRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePriceRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePriceRequest>(create);
  static UpdatePriceRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get securityId => $_getSZ(0);
  @$pb.TagNumber(1)
  set securityId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSecurityId() => $_has(0);
  @$pb.TagNumber(1)
  void clearSecurityId() => $_clearField(1);

  @$pb.TagNumber(2)
  $fixnum.Int64 get priceCents => $_getI64(1);
  @$pb.TagNumber(2)
  set priceCents($fixnum.Int64 value) => $_setInt64(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPriceCents() => $_has(1);
  @$pb.TagNumber(2)
  void clearPriceCents() => $_clearField(2);
}

class SearchSecuritiesRequest extends $pb.GeneratedMessage {
  factory SearchSecuritiesRequest({
    $core.String? query,
    $core.int? limit,
  }) {
    final result = create();
    if (query != null) result.query = query;
    if (limit != null) result.limit = limit;
    return result;
  }

  SearchSecuritiesRequest._();

  factory SearchSecuritiesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchSecuritiesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchSecuritiesRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'query')
    ..aI(2, _omitFieldNames ? '' : 'limit')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchSecuritiesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchSecuritiesRequest copyWith(
          void Function(SearchSecuritiesRequest) updates) =>
      super.copyWith((message) => updates(message as SearchSecuritiesRequest))
          as SearchSecuritiesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchSecuritiesRequest create() => SearchSecuritiesRequest._();
  @$core.override
  SearchSecuritiesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchSecuritiesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchSecuritiesRequest>(create);
  static SearchSecuritiesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get query => $_getSZ(0);
  @$pb.TagNumber(1)
  set query($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasQuery() => $_has(0);
  @$pb.TagNumber(1)
  void clearQuery() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get limit => $_getIZ(1);
  @$pb.TagNumber(2)
  set limit($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLimit() => $_has(1);
  @$pb.TagNumber(2)
  void clearLimit() => $_clearField(2);
}

class HoldingTradeRequest extends $pb.GeneratedMessage {
  factory HoldingTradeRequest({
    $core.String? accountId,
    $core.String? securityId,
    $core.double? quantity,
    $fixnum.Int64? priceCents,
    $fixnum.Int64? feeCents,
    $core.String? tradeDate,
    $core.String? notes,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (securityId != null) result.securityId = securityId;
    if (quantity != null) result.quantity = quantity;
    if (priceCents != null) result.priceCents = priceCents;
    if (feeCents != null) result.feeCents = feeCents;
    if (tradeDate != null) result.tradeDate = tradeDate;
    if (notes != null) result.notes = notes;
    return result;
  }

  HoldingTradeRequest._();

  factory HoldingTradeRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HoldingTradeRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HoldingTradeRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aOS(2, _omitFieldNames ? '' : 'securityId')
    ..aD(3, _omitFieldNames ? '' : 'quantity')
    ..aInt64(4, _omitFieldNames ? '' : 'priceCents')
    ..aInt64(5, _omitFieldNames ? '' : 'feeCents')
    ..aOS(6, _omitFieldNames ? '' : 'tradeDate')
    ..aOS(7, _omitFieldNames ? '' : 'notes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HoldingTradeRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HoldingTradeRequest copyWith(void Function(HoldingTradeRequest) updates) =>
      super.copyWith((message) => updates(message as HoldingTradeRequest))
          as HoldingTradeRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HoldingTradeRequest create() => HoldingTradeRequest._();
  @$core.override
  HoldingTradeRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HoldingTradeRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HoldingTradeRequest>(create);
  static HoldingTradeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get securityId => $_getSZ(1);
  @$pb.TagNumber(2)
  set securityId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSecurityId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSecurityId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get quantity => $_getN(2);
  @$pb.TagNumber(3)
  set quantity($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQuantity() => $_has(2);
  @$pb.TagNumber(3)
  void clearQuantity() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get priceCents => $_getI64(3);
  @$pb.TagNumber(4)
  set priceCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPriceCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearPriceCents() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get feeCents => $_getI64(4);
  @$pb.TagNumber(5)
  set feeCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasFeeCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearFeeCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get tradeDate => $_getSZ(5);
  @$pb.TagNumber(6)
  set tradeDate($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTradeDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearTradeDate() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get notes => $_getSZ(6);
  @$pb.TagNumber(7)
  set notes($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNotes() => $_has(6);
  @$pb.TagNumber(7)
  void clearNotes() => $_clearField(7);
}

class RecordDividendRequest extends $pb.GeneratedMessage {
  factory RecordDividendRequest({
    $core.String? accountId,
    $core.String? securityId,
    $core.double? quantity,
    $fixnum.Int64? cashPerShareCents,
    $fixnum.Int64? totalAmountCents,
    $core.String? tradeDate,
    $core.String? notes,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (securityId != null) result.securityId = securityId;
    if (quantity != null) result.quantity = quantity;
    if (cashPerShareCents != null) result.cashPerShareCents = cashPerShareCents;
    if (totalAmountCents != null) result.totalAmountCents = totalAmountCents;
    if (tradeDate != null) result.tradeDate = tradeDate;
    if (notes != null) result.notes = notes;
    return result;
  }

  RecordDividendRequest._();

  factory RecordDividendRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordDividendRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordDividendRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aOS(2, _omitFieldNames ? '' : 'securityId')
    ..aD(3, _omitFieldNames ? '' : 'quantity')
    ..aInt64(4, _omitFieldNames ? '' : 'cashPerShareCents')
    ..aInt64(5, _omitFieldNames ? '' : 'totalAmountCents')
    ..aOS(6, _omitFieldNames ? '' : 'tradeDate')
    ..aOS(7, _omitFieldNames ? '' : 'notes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordDividendRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordDividendRequest copyWith(
          void Function(RecordDividendRequest) updates) =>
      super.copyWith((message) => updates(message as RecordDividendRequest))
          as RecordDividendRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordDividendRequest create() => RecordDividendRequest._();
  @$core.override
  RecordDividendRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordDividendRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordDividendRequest>(create);
  static RecordDividendRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get securityId => $_getSZ(1);
  @$pb.TagNumber(2)
  set securityId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSecurityId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSecurityId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get quantity => $_getN(2);
  @$pb.TagNumber(3)
  set quantity($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasQuantity() => $_has(2);
  @$pb.TagNumber(3)
  void clearQuantity() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get cashPerShareCents => $_getI64(3);
  @$pb.TagNumber(4)
  set cashPerShareCents($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasCashPerShareCents() => $_has(3);
  @$pb.TagNumber(4)
  void clearCashPerShareCents() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get totalAmountCents => $_getI64(4);
  @$pb.TagNumber(5)
  set totalAmountCents($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTotalAmountCents() => $_has(4);
  @$pb.TagNumber(5)
  void clearTotalAmountCents() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get tradeDate => $_getSZ(5);
  @$pb.TagNumber(6)
  set tradeDate($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTradeDate() => $_has(5);
  @$pb.TagNumber(6)
  void clearTradeDate() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get notes => $_getSZ(6);
  @$pb.TagNumber(7)
  set notes($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasNotes() => $_has(6);
  @$pb.TagNumber(7)
  void clearNotes() => $_clearField(7);
}

class RecordSplitRequest extends $pb.GeneratedMessage {
  factory RecordSplitRequest({
    $core.String? accountId,
    $core.String? securityId,
    $core.double? ratio,
    $core.String? splitDate,
    $core.String? notes,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (securityId != null) result.securityId = securityId;
    if (ratio != null) result.ratio = ratio;
    if (splitDate != null) result.splitDate = splitDate;
    if (notes != null) result.notes = notes;
    return result;
  }

  RecordSplitRequest._();

  factory RecordSplitRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RecordSplitRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RecordSplitRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aOS(2, _omitFieldNames ? '' : 'securityId')
    ..aD(3, _omitFieldNames ? '' : 'ratio')
    ..aOS(4, _omitFieldNames ? '' : 'splitDate')
    ..aOS(5, _omitFieldNames ? '' : 'notes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordSplitRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RecordSplitRequest copyWith(void Function(RecordSplitRequest) updates) =>
      super.copyWith((message) => updates(message as RecordSplitRequest))
          as RecordSplitRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RecordSplitRequest create() => RecordSplitRequest._();
  @$core.override
  RecordSplitRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RecordSplitRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RecordSplitRequest>(create);
  static RecordSplitRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get securityId => $_getSZ(1);
  @$pb.TagNumber(2)
  set securityId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSecurityId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSecurityId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get ratio => $_getN(2);
  @$pb.TagNumber(3)
  set ratio($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasRatio() => $_has(2);
  @$pb.TagNumber(3)
  void clearRatio() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get splitDate => $_getSZ(3);
  @$pb.TagNumber(4)
  set splitDate($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasSplitDate() => $_has(3);
  @$pb.TagNumber(4)
  void clearSplitDate() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get notes => $_getSZ(4);
  @$pb.TagNumber(5)
  set notes($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasNotes() => $_has(4);
  @$pb.TagNumber(5)
  void clearNotes() => $_clearField(5);
}

class ListHoldingsRequest extends $pb.GeneratedMessage {
  factory ListHoldingsRequest({
    $core.String? accountId,
    $1.PageRequest? page,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (page != null) result.page = page;
    return result;
  }

  ListHoldingsRequest._();

  factory ListHoldingsRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListHoldingsRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListHoldingsRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aOM<$1.PageRequest>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListHoldingsRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListHoldingsRequest copyWith(void Function(ListHoldingsRequest) updates) =>
      super.copyWith((message) => updates(message as ListHoldingsRequest))
          as ListHoldingsRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListHoldingsRequest create() => ListHoldingsRequest._();
  @$core.override
  ListHoldingsRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListHoldingsRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListHoldingsRequest>(create);
  static ListHoldingsRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $1.PageRequest get page => $_getN(1);
  @$pb.TagNumber(2)
  set page($1.PageRequest value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasPage() => $_has(1);
  @$pb.TagNumber(2)
  void clearPage() => $_clearField(2);
  @$pb.TagNumber(2)
  $1.PageRequest ensurePage() => $_ensure(1);
}

class ListTradesRequest extends $pb.GeneratedMessage {
  factory ListTradesRequest({
    $core.String? accountId,
    $core.String? securityId,
    $1.PageRequest? page,
  }) {
    final result = create();
    if (accountId != null) result.accountId = accountId;
    if (securityId != null) result.securityId = securityId;
    if (page != null) result.page = page;
    return result;
  }

  ListTradesRequest._();

  factory ListTradesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListTradesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTradesRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accountId')
    ..aOS(2, _omitFieldNames ? '' : 'securityId')
    ..aOM<$1.PageRequest>(3, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageRequest.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTradesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTradesRequest copyWith(void Function(ListTradesRequest) updates) =>
      super.copyWith((message) => updates(message as ListTradesRequest))
          as ListTradesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTradesRequest create() => ListTradesRequest._();
  @$core.override
  ListTradesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListTradesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTradesRequest>(create);
  static ListTradesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accountId => $_getSZ(0);
  @$pb.TagNumber(1)
  set accountId($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccountId() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccountId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get securityId => $_getSZ(1);
  @$pb.TagNumber(2)
  set securityId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasSecurityId() => $_has(1);
  @$pb.TagNumber(2)
  void clearSecurityId() => $_clearField(2);

  @$pb.TagNumber(3)
  $1.PageRequest get page => $_getN(2);
  @$pb.TagNumber(3)
  set page($1.PageRequest value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasPage() => $_has(2);
  @$pb.TagNumber(3)
  void clearPage() => $_clearField(3);
  @$pb.TagNumber(3)
  $1.PageRequest ensurePage() => $_ensure(2);
}

class SecurityResponse extends $pb.GeneratedMessage {
  factory SecurityResponse({
    SecurityDTO? security,
  }) {
    final result = create();
    if (security != null) result.security = security;
    return result;
  }

  SecurityResponse._();

  factory SecurityResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SecurityResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SecurityResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOM<SecurityDTO>(1, _omitFieldNames ? '' : 'security',
        subBuilder: SecurityDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecurityResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SecurityResponse copyWith(void Function(SecurityResponse) updates) =>
      super.copyWith((message) => updates(message as SecurityResponse))
          as SecurityResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SecurityResponse create() => SecurityResponse._();
  @$core.override
  SecurityResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SecurityResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SecurityResponse>(create);
  static SecurityResponse? _defaultInstance;

  @$pb.TagNumber(1)
  SecurityDTO get security => $_getN(0);
  @$pb.TagNumber(1)
  set security(SecurityDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasSecurity() => $_has(0);
  @$pb.TagNumber(1)
  void clearSecurity() => $_clearField(1);
  @$pb.TagNumber(1)
  SecurityDTO ensureSecurity() => $_ensure(0);
}

class ListSecuritiesResponse extends $pb.GeneratedMessage {
  factory ListSecuritiesResponse({
    $core.Iterable<SecurityDTO>? securities,
    $1.PageResponse? page,
  }) {
    final result = create();
    if (securities != null) result.securities.addAll(securities);
    if (page != null) result.page = page;
    return result;
  }

  ListSecuritiesResponse._();

  factory ListSecuritiesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListSecuritiesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListSecuritiesResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..pPM<SecurityDTO>(1, _omitFieldNames ? '' : 'securities',
        subBuilder: SecurityDTO.create)
    ..aOM<$1.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSecuritiesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListSecuritiesResponse copyWith(
          void Function(ListSecuritiesResponse) updates) =>
      super.copyWith((message) => updates(message as ListSecuritiesResponse))
          as ListSecuritiesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListSecuritiesResponse create() => ListSecuritiesResponse._();
  @$core.override
  ListSecuritiesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListSecuritiesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListSecuritiesResponse>(create);
  static ListSecuritiesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SecurityDTO> get securities => $_getList(0);

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

class SearchSecuritiesResponse extends $pb.GeneratedMessage {
  factory SearchSecuritiesResponse({
    $core.Iterable<SecurityDTO>? securities,
  }) {
    final result = create();
    if (securities != null) result.securities.addAll(securities);
    return result;
  }

  SearchSecuritiesResponse._();

  factory SearchSecuritiesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SearchSecuritiesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SearchSecuritiesResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..pPM<SecurityDTO>(1, _omitFieldNames ? '' : 'securities',
        subBuilder: SecurityDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchSecuritiesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SearchSecuritiesResponse copyWith(
          void Function(SearchSecuritiesResponse) updates) =>
      super.copyWith((message) => updates(message as SearchSecuritiesResponse))
          as SearchSecuritiesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SearchSecuritiesResponse create() => SearchSecuritiesResponse._();
  @$core.override
  SearchSecuritiesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SearchSecuritiesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SearchSecuritiesResponse>(create);
  static SearchSecuritiesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<SecurityDTO> get securities => $_getList(0);
}

class HoldingTransactionResponse extends $pb.GeneratedMessage {
  factory HoldingTransactionResponse({
    HoldingTransactionDTO? transaction,
  }) {
    final result = create();
    if (transaction != null) result.transaction = transaction;
    return result;
  }

  HoldingTransactionResponse._();

  factory HoldingTransactionResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory HoldingTransactionResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'HoldingTransactionResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..aOM<HoldingTransactionDTO>(1, _omitFieldNames ? '' : 'transaction',
        subBuilder: HoldingTransactionDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HoldingTransactionResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  HoldingTransactionResponse copyWith(
          void Function(HoldingTransactionResponse) updates) =>
      super.copyWith(
              (message) => updates(message as HoldingTransactionResponse))
          as HoldingTransactionResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static HoldingTransactionResponse create() => HoldingTransactionResponse._();
  @$core.override
  HoldingTransactionResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static HoldingTransactionResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<HoldingTransactionResponse>(create);
  static HoldingTransactionResponse? _defaultInstance;

  @$pb.TagNumber(1)
  HoldingTransactionDTO get transaction => $_getN(0);
  @$pb.TagNumber(1)
  set transaction(HoldingTransactionDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasTransaction() => $_has(0);
  @$pb.TagNumber(1)
  void clearTransaction() => $_clearField(1);
  @$pb.TagNumber(1)
  HoldingTransactionDTO ensureTransaction() => $_ensure(0);
}

class ListHoldingsResponse extends $pb.GeneratedMessage {
  factory ListHoldingsResponse({
    $core.Iterable<HoldingDTO>? holdings,
    $1.PageResponse? page,
  }) {
    final result = create();
    if (holdings != null) result.holdings.addAll(holdings);
    if (page != null) result.page = page;
    return result;
  }

  ListHoldingsResponse._();

  factory ListHoldingsResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListHoldingsResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListHoldingsResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..pPM<HoldingDTO>(1, _omitFieldNames ? '' : 'holdings',
        subBuilder: HoldingDTO.create)
    ..aOM<$1.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListHoldingsResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListHoldingsResponse copyWith(void Function(ListHoldingsResponse) updates) =>
      super.copyWith((message) => updates(message as ListHoldingsResponse))
          as ListHoldingsResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListHoldingsResponse create() => ListHoldingsResponse._();
  @$core.override
  ListHoldingsResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListHoldingsResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListHoldingsResponse>(create);
  static ListHoldingsResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<HoldingDTO> get holdings => $_getList(0);

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

class ListTradesResponse extends $pb.GeneratedMessage {
  factory ListTradesResponse({
    $core.Iterable<HoldingTransactionDTO>? trades,
    $1.PageResponse? page,
  }) {
    final result = create();
    if (trades != null) result.trades.addAll(trades);
    if (page != null) result.page = page;
    return result;
  }

  ListTradesResponse._();

  factory ListTradesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ListTradesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ListTradesResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.holding.v1'),
      createEmptyInstance: create)
    ..pPM<HoldingTransactionDTO>(1, _omitFieldNames ? '' : 'trades',
        subBuilder: HoldingTransactionDTO.create)
    ..aOM<$1.PageResponse>(2, _omitFieldNames ? '' : 'page',
        subBuilder: $1.PageResponse.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTradesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ListTradesResponse copyWith(void Function(ListTradesResponse) updates) =>
      super.copyWith((message) => updates(message as ListTradesResponse))
          as ListTradesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ListTradesResponse create() => ListTradesResponse._();
  @$core.override
  ListTradesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ListTradesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ListTradesResponse>(create);
  static ListTradesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<HoldingTransactionDTO> get trades => $_getList(0);

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

class HoldingServiceApi {
  final $pb.RpcClient _client;

  HoldingServiceApi(this._client);

  $async.Future<SecurityResponse> createSecurity(
          $pb.ClientContext? ctx, CreateSecurityRequest request) =>
      _client.invoke<SecurityResponse>(
          ctx, 'HoldingService', 'CreateSecurity', request, SecurityResponse());
  $async.Future<ListSecuritiesResponse> listSecurities(
          $pb.ClientContext? ctx, ListSecuritiesRequest request) =>
      _client.invoke<ListSecuritiesResponse>(ctx, 'HoldingService',
          'ListSecurities', request, ListSecuritiesResponse());
  $async.Future<$2.Empty> updateSecurityPrice(
          $pb.ClientContext? ctx, UpdatePriceRequest request) =>
      _client.invoke<$2.Empty>(
          ctx, 'HoldingService', 'UpdateSecurityPrice', request, $2.Empty());
  $async.Future<SearchSecuritiesResponse> searchSecurities(
          $pb.ClientContext? ctx, SearchSecuritiesRequest request) =>
      _client.invoke<SearchSecuritiesResponse>(ctx, 'HoldingService',
          'SearchSecurities', request, SearchSecuritiesResponse());
  $async.Future<HoldingTransactionResponse> buyHolding(
          $pb.ClientContext? ctx, HoldingTradeRequest request) =>
      _client.invoke<HoldingTransactionResponse>(ctx, 'HoldingService',
          'BuyHolding', request, HoldingTransactionResponse());
  $async.Future<HoldingTransactionResponse> sellHolding(
          $pb.ClientContext? ctx, HoldingTradeRequest request) =>
      _client.invoke<HoldingTransactionResponse>(ctx, 'HoldingService',
          'SellHolding', request, HoldingTransactionResponse());
  $async.Future<HoldingTransactionResponse> recordDividend(
          $pb.ClientContext? ctx, RecordDividendRequest request) =>
      _client.invoke<HoldingTransactionResponse>(ctx, 'HoldingService',
          'RecordDividend', request, HoldingTransactionResponse());
  $async.Future<HoldingTransactionResponse> recordSplit(
          $pb.ClientContext? ctx, RecordSplitRequest request) =>
      _client.invoke<HoldingTransactionResponse>(ctx, 'HoldingService',
          'RecordSplit', request, HoldingTransactionResponse());
  $async.Future<ListHoldingsResponse> listHoldings(
          $pb.ClientContext? ctx, ListHoldingsRequest request) =>
      _client.invoke<ListHoldingsResponse>(ctx, 'HoldingService',
          'ListHoldings', request, ListHoldingsResponse());
  $async.Future<ListTradesResponse> listHoldingTransactions(
          $pb.ClientContext? ctx, ListTradesRequest request) =>
      _client.invoke<ListTradesResponse>(ctx, 'HoldingService',
          'ListHoldingTransactions', request, ListTradesResponse());
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
