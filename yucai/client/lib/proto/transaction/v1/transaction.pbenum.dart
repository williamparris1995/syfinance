// This is a generated file - do not edit.
//
// Generated from transaction/v1/transaction.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Scope selects the aggregation period for TransactionSummary. UNSPECIFIED is
/// treated as MONTH by the server for backward compatibility. DAY requires day
/// to be set; YEAR ignores month/day.
class Scope extends $pb.ProtobufEnum {
  static const Scope SCOPE_UNSPECIFIED =
      Scope._(0, _omitEnumNames ? '' : 'SCOPE_UNSPECIFIED');
  static const Scope SCOPE_DAY = Scope._(1, _omitEnumNames ? '' : 'SCOPE_DAY');
  static const Scope SCOPE_MONTH =
      Scope._(2, _omitEnumNames ? '' : 'SCOPE_MONTH');
  static const Scope SCOPE_YEAR =
      Scope._(3, _omitEnumNames ? '' : 'SCOPE_YEAR');

  static const $core.List<Scope> values = <Scope>[
    SCOPE_UNSPECIFIED,
    SCOPE_DAY,
    SCOPE_MONTH,
    SCOPE_YEAR,
  ];

  static final $core.List<Scope?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Scope? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Scope._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
