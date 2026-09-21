// This is a generated file - do not edit.
//
// Generated from feedback/v1/feedback.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class FeedbackType extends $pb.ProtobufEnum {
  static const FeedbackType FEEDBACK_TYPE_UNSPECIFIED =
      FeedbackType._(0, _omitEnumNames ? '' : 'FEEDBACK_TYPE_UNSPECIFIED');
  static const FeedbackType ISSUE =
      FeedbackType._(1, _omitEnumNames ? '' : 'ISSUE');
  static const FeedbackType IDEA =
      FeedbackType._(2, _omitEnumNames ? '' : 'IDEA');
  static const FeedbackType OTHER =
      FeedbackType._(3, _omitEnumNames ? '' : 'OTHER');

  static const $core.List<FeedbackType> values = <FeedbackType>[
    FEEDBACK_TYPE_UNSPECIFIED,
    ISSUE,
    IDEA,
    OTHER,
  ];

  static final $core.List<FeedbackType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static FeedbackType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const FeedbackType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
