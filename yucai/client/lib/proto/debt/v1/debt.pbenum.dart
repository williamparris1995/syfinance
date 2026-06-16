// This is a generated file - do not edit.
//
// Generated from debt/v1/debt.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class AmortizationMethod extends $pb.ProtobufEnum {
  static const AmortizationMethod AMORTIZATION_UNSPECIFIED =
      AmortizationMethod._(0, _omitEnumNames ? '' : 'AMORTIZATION_UNSPECIFIED');
  static const AmortizationMethod AMORTIZATION_EQUAL_PRINCIPAL_INTEREST =
      AmortizationMethod._(
          1, _omitEnumNames ? '' : 'AMORTIZATION_EQUAL_PRINCIPAL_INTEREST');
  static const AmortizationMethod AMORTIZATION_EQUAL_PRINCIPAL =
      AmortizationMethod._(
          2, _omitEnumNames ? '' : 'AMORTIZATION_EQUAL_PRINCIPAL');
  static const AmortizationMethod AMORTIZATION_LUMP_SUM =
      AmortizationMethod._(3, _omitEnumNames ? '' : 'AMORTIZATION_LUMP_SUM');

  static const $core.List<AmortizationMethod> values = <AmortizationMethod>[
    AMORTIZATION_UNSPECIFIED,
    AMORTIZATION_EQUAL_PRINCIPAL_INTEREST,
    AMORTIZATION_EQUAL_PRINCIPAL,
    AMORTIZATION_LUMP_SUM,
  ];

  static final $core.List<AmortizationMethod?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static AmortizationMethod? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AmortizationMethod._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
