// This is a generated file - do not edit.
//
// Generated from account/v1/account.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class AccountType extends $pb.ProtobufEnum {
  static const AccountType ACCOUNT_TYPE_UNSPECIFIED =
      AccountType._(0, _omitEnumNames ? '' : 'ACCOUNT_TYPE_UNSPECIFIED');
  static const AccountType ACCOUNT_TYPE_ASSET =
      AccountType._(1, _omitEnumNames ? '' : 'ACCOUNT_TYPE_ASSET');
  static const AccountType ACCOUNT_TYPE_LIABILITY =
      AccountType._(2, _omitEnumNames ? '' : 'ACCOUNT_TYPE_LIABILITY');
  static const AccountType ACCOUNT_TYPE_EQUITY =
      AccountType._(3, _omitEnumNames ? '' : 'ACCOUNT_TYPE_EQUITY');
  static const AccountType ACCOUNT_TYPE_INCOME =
      AccountType._(4, _omitEnumNames ? '' : 'ACCOUNT_TYPE_INCOME');
  static const AccountType ACCOUNT_TYPE_EXPENSE =
      AccountType._(5, _omitEnumNames ? '' : 'ACCOUNT_TYPE_EXPENSE');

  static const $core.List<AccountType> values = <AccountType>[
    ACCOUNT_TYPE_UNSPECIFIED,
    ACCOUNT_TYPE_ASSET,
    ACCOUNT_TYPE_LIABILITY,
    ACCOUNT_TYPE_EQUITY,
    ACCOUNT_TYPE_INCOME,
    ACCOUNT_TYPE_EXPENSE,
  ];

  static final $core.List<AccountType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 5);
  static AccountType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AccountType._(super.value, super.name);
}

class Ownership extends $pb.ProtobufEnum {
  static const Ownership OWNERSHIP_UNSPECIFIED =
      Ownership._(0, _omitEnumNames ? '' : 'OWNERSHIP_UNSPECIFIED');
  static const Ownership OWNERSHIP_PERSONAL =
      Ownership._(1, _omitEnumNames ? '' : 'OWNERSHIP_PERSONAL');
  static const Ownership OWNERSHIP_JOINT =
      Ownership._(2, _omitEnumNames ? '' : 'OWNERSHIP_JOINT');

  static const $core.List<Ownership> values = <Ownership>[
    OWNERSHIP_UNSPECIFIED,
    OWNERSHIP_PERSONAL,
    OWNERSHIP_JOINT,
  ];

  static final $core.List<Ownership?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static Ownership? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Ownership._(super.value, super.name);
}

class AccountStatus extends $pb.ProtobufEnum {
  static const AccountStatus ACCOUNT_STATUS_UNSPECIFIED =
      AccountStatus._(0, _omitEnumNames ? '' : 'ACCOUNT_STATUS_UNSPECIFIED');
  static const AccountStatus ACCOUNT_STATUS_ACTIVE =
      AccountStatus._(1, _omitEnumNames ? '' : 'ACCOUNT_STATUS_ACTIVE');
  static const AccountStatus ACCOUNT_STATUS_ARCHIVED =
      AccountStatus._(2, _omitEnumNames ? '' : 'ACCOUNT_STATUS_ARCHIVED');

  static const $core.List<AccountStatus> values = <AccountStatus>[
    ACCOUNT_STATUS_UNSPECIFIED,
    ACCOUNT_STATUS_ACTIVE,
    ACCOUNT_STATUS_ARCHIVED,
  ];

  static final $core.List<AccountStatus?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 2);
  static AccountStatus? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const AccountStatus._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
