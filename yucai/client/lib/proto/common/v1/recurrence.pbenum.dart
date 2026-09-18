// This is a generated file - do not edit.
//
// Generated from common/v1/recurrence.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

/// Calendar-style recurrence cycle shared by template (subscription) and
/// debt (installment schedule). Values 1-4 align with TemplateCycle.
class RecurrenceCycle extends $pb.ProtobufEnum {
  static const RecurrenceCycle RECURRENCE_CYCLE_UNSPECIFIED = RecurrenceCycle._(
      0, _omitEnumNames ? '' : 'RECURRENCE_CYCLE_UNSPECIFIED');
  static const RecurrenceCycle RECURRENCE_CYCLE_WEEKLY =
      RecurrenceCycle._(1, _omitEnumNames ? '' : 'RECURRENCE_CYCLE_WEEKLY');
  static const RecurrenceCycle RECURRENCE_CYCLE_MONTHLY =
      RecurrenceCycle._(2, _omitEnumNames ? '' : 'RECURRENCE_CYCLE_MONTHLY');
  static const RecurrenceCycle RECURRENCE_CYCLE_YEARLY =
      RecurrenceCycle._(3, _omitEnumNames ? '' : 'RECURRENCE_CYCLE_YEARLY');
  static const RecurrenceCycle RECURRENCE_CYCLE_CUSTOM =
      RecurrenceCycle._(4, _omitEnumNames ? '' : 'RECURRENCE_CYCLE_CUSTOM');

  static const $core.List<RecurrenceCycle> values = <RecurrenceCycle>[
    RECURRENCE_CYCLE_UNSPECIFIED,
    RECURRENCE_CYCLE_WEEKLY,
    RECURRENCE_CYCLE_MONTHLY,
    RECURRENCE_CYCLE_YEARLY,
    RECURRENCE_CYCLE_CUSTOM,
  ];

  static final $core.List<RecurrenceCycle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static RecurrenceCycle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RecurrenceCycle._(super.value, super.name);
}

/// How a monthly recurrence picks its day of the month.
class RecurrenceMonthlyMode extends $pb.ProtobufEnum {
  /// Anchor a fixed day (billing_day for templates / the start date for
  /// debts), clamped to the target month's last day.
  static const RecurrenceMonthlyMode MONTHLY_MODE_BY_DATE =
      RecurrenceMonthlyMode._(0, _omitEnumNames ? '' : 'MONTHLY_MODE_BY_DATE');

  /// Anchor the Nth weekday of the month (nth=5 means the last one).
  static const RecurrenceMonthlyMode MONTHLY_MODE_BY_NTH_WEEKDAY =
      RecurrenceMonthlyMode._(
          1, _omitEnumNames ? '' : 'MONTHLY_MODE_BY_NTH_WEEKDAY');

  static const $core.List<RecurrenceMonthlyMode> values =
      <RecurrenceMonthlyMode>[
    MONTHLY_MODE_BY_DATE,
    MONTHLY_MODE_BY_NTH_WEEKDAY,
  ];

  static final $core.List<RecurrenceMonthlyMode?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 1);
  static RecurrenceMonthlyMode? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const RecurrenceMonthlyMode._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
