// This is a generated file - do not edit.
//
// Generated from holding/v1/holding.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class SecurityType extends $pb.ProtobufEnum {
  static const SecurityType SECURITY_TYPE_UNSPECIFIED =
      SecurityType._(0, _omitEnumNames ? '' : 'SECURITY_TYPE_UNSPECIFIED');
  static const SecurityType SECURITY_TYPE_STOCK =
      SecurityType._(1, _omitEnumNames ? '' : 'SECURITY_TYPE_STOCK');
  static const SecurityType SECURITY_TYPE_FUND =
      SecurityType._(2, _omitEnumNames ? '' : 'SECURITY_TYPE_FUND');
  static const SecurityType SECURITY_TYPE_ETF =
      SecurityType._(3, _omitEnumNames ? '' : 'SECURITY_TYPE_ETF');
  static const SecurityType SECURITY_TYPE_BOND =
      SecurityType._(4, _omitEnumNames ? '' : 'SECURITY_TYPE_BOND');
  static const SecurityType SECURITY_TYPE_GOLD =
      SecurityType._(5, _omitEnumNames ? '' : 'SECURITY_TYPE_GOLD');
  static const SecurityType SECURITY_TYPE_OPTION =
      SecurityType._(6, _omitEnumNames ? '' : 'SECURITY_TYPE_OPTION');
  static const SecurityType SECURITY_TYPE_OTHER =
      SecurityType._(7, _omitEnumNames ? '' : 'SECURITY_TYPE_OTHER');

  static const $core.List<SecurityType> values = <SecurityType>[
    SECURITY_TYPE_UNSPECIFIED,
    SECURITY_TYPE_STOCK,
    SECURITY_TYPE_FUND,
    SECURITY_TYPE_ETF,
    SECURITY_TYPE_BOND,
    SECURITY_TYPE_GOLD,
    SECURITY_TYPE_OPTION,
    SECURITY_TYPE_OTHER,
  ];

  static final $core.List<SecurityType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 7);
  static SecurityType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const SecurityType._(super.value, super.name);
}

class TradeType extends $pb.ProtobufEnum {
  static const TradeType TRADE_TYPE_UNSPECIFIED =
      TradeType._(0, _omitEnumNames ? '' : 'TRADE_TYPE_UNSPECIFIED');
  static const TradeType TRADE_TYPE_BUY =
      TradeType._(1, _omitEnumNames ? '' : 'TRADE_TYPE_BUY');
  static const TradeType TRADE_TYPE_SELL =
      TradeType._(2, _omitEnumNames ? '' : 'TRADE_TYPE_SELL');
  static const TradeType TRADE_TYPE_DIVIDEND =
      TradeType._(3, _omitEnumNames ? '' : 'TRADE_TYPE_DIVIDEND');
  static const TradeType TRADE_TYPE_SPLIT =
      TradeType._(4, _omitEnumNames ? '' : 'TRADE_TYPE_SPLIT');

  static const $core.List<TradeType> values = <TradeType>[
    TRADE_TYPE_UNSPECIFIED,
    TRADE_TYPE_BUY,
    TRADE_TYPE_SELL,
    TRADE_TYPE_DIVIDEND,
    TRADE_TYPE_SPLIT,
  ];

  static final $core.List<TradeType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static TradeType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TradeType._(super.value, super.name);
}

class CurveRange extends $pb.ProtobufEnum {
  static const CurveRange CURVE_RANGE_UNSPECIFIED =
      CurveRange._(0, _omitEnumNames ? '' : 'CURVE_RANGE_UNSPECIFIED');
  static const CurveRange CURVE_RANGE_DAY =
      CurveRange._(1, _omitEnumNames ? '' : 'CURVE_RANGE_DAY');
  static const CurveRange CURVE_RANGE_MONTH =
      CurveRange._(2, _omitEnumNames ? '' : 'CURVE_RANGE_MONTH');
  static const CurveRange CURVE_RANGE_YEAR =
      CurveRange._(3, _omitEnumNames ? '' : 'CURVE_RANGE_YEAR');

  static const $core.List<CurveRange> values = <CurveRange>[
    CURVE_RANGE_UNSPECIFIED,
    CURVE_RANGE_DAY,
    CURVE_RANGE_MONTH,
    CURVE_RANGE_YEAR,
  ];

  static final $core.List<CurveRange?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static CurveRange? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CurveRange._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
