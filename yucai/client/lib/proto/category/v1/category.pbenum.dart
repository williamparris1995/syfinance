// This is a generated file - do not edit.
//
// Generated from category/v1/category.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class CategoryType extends $pb.ProtobufEnum {
  static const CategoryType CATEGORY_TYPE_UNSPECIFIED =
      CategoryType._(0, _omitEnumNames ? '' : 'CATEGORY_TYPE_UNSPECIFIED');
  static const CategoryType CATEGORY_TYPE_INCOME =
      CategoryType._(1, _omitEnumNames ? '' : 'CATEGORY_TYPE_INCOME');
  static const CategoryType CATEGORY_TYPE_EXPENSE =
      CategoryType._(2, _omitEnumNames ? '' : 'CATEGORY_TYPE_EXPENSE');

  static const $core.List<CategoryType> values = <CategoryType>[
    CATEGORY_TYPE_UNSPECIFIED,
    CATEGORY_TYPE_INCOME,
    CATEGORY_TYPE_EXPENSE,
  ];

  static final $core.List<CategoryType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static CategoryType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const CategoryType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
