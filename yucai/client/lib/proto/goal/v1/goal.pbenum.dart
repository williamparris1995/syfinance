// This is a generated file - do not edit.
//
// Generated from goal/v1/goal.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class GoalType extends $pb.ProtobufEnum {
  static const GoalType GOAL_TYPE_UNSPECIFIED =
      GoalType._(0, _omitEnumNames ? '' : 'GOAL_TYPE_UNSPECIFIED');
  static const GoalType GOAL_TYPE_SAVINGS =
      GoalType._(1, _omitEnumNames ? '' : 'GOAL_TYPE_SAVINGS');
  static const GoalType GOAL_TYPE_DEBT_PAYOFF =
      GoalType._(2, _omitEnumNames ? '' : 'GOAL_TYPE_DEBT_PAYOFF');
  static const GoalType GOAL_TYPE_INVESTMENT =
      GoalType._(3, _omitEnumNames ? '' : 'GOAL_TYPE_INVESTMENT');

  static const $core.List<GoalType> values = <GoalType>[
    GOAL_TYPE_UNSPECIFIED,
    GOAL_TYPE_SAVINGS,
    GOAL_TYPE_DEBT_PAYOFF,
    GOAL_TYPE_INVESTMENT,
  ];

  static final $core.List<GoalType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static GoalType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const GoalType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
