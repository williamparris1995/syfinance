// This is a generated file - do not edit.
//
// Generated from template/v1/template.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class TemplateDirection extends $pb.ProtobufEnum {
  static const TemplateDirection DIRECTION_UNSPECIFIED =
      TemplateDirection._(0, _omitEnumNames ? '' : 'DIRECTION_UNSPECIFIED');
  static const TemplateDirection DIRECTION_EXPENSE =
      TemplateDirection._(1, _omitEnumNames ? '' : 'DIRECTION_EXPENSE');
  static const TemplateDirection DIRECTION_INCOME =
      TemplateDirection._(2, _omitEnumNames ? '' : 'DIRECTION_INCOME');
  static const TemplateDirection DIRECTION_TRANSFER =
      TemplateDirection._(3, _omitEnumNames ? '' : 'DIRECTION_TRANSFER');

  static const $core.List<TemplateDirection> values = <TemplateDirection>[
    DIRECTION_UNSPECIFIED,
    DIRECTION_EXPENSE,
    DIRECTION_INCOME,
    DIRECTION_TRANSFER,
  ];

  static final $core.List<TemplateDirection?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static TemplateDirection? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TemplateDirection._(super.value, super.name);
}

class TemplateCycle extends $pb.ProtobufEnum {
  static const TemplateCycle CYCLE_UNSPECIFIED =
      TemplateCycle._(0, _omitEnumNames ? '' : 'CYCLE_UNSPECIFIED');
  static const TemplateCycle CYCLE_WEEKLY =
      TemplateCycle._(1, _omitEnumNames ? '' : 'CYCLE_WEEKLY');
  static const TemplateCycle CYCLE_MONTHLY =
      TemplateCycle._(2, _omitEnumNames ? '' : 'CYCLE_MONTHLY');
  static const TemplateCycle CYCLE_YEARLY =
      TemplateCycle._(3, _omitEnumNames ? '' : 'CYCLE_YEARLY');
  static const TemplateCycle CYCLE_CUSTOM =
      TemplateCycle._(4, _omitEnumNames ? '' : 'CYCLE_CUSTOM');

  static const $core.List<TemplateCycle> values = <TemplateCycle>[
    CYCLE_UNSPECIFIED,
    CYCLE_WEEKLY,
    CYCLE_MONTHLY,
    CYCLE_YEARLY,
    CYCLE_CUSTOM,
  ];

  static final $core.List<TemplateCycle?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 4);
  static TemplateCycle? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const TemplateCycle._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
