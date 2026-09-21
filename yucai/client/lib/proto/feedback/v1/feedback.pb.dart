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

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

import 'feedback.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'feedback.pbenum.dart';

/// FeedbackDiagnostics carries the client environment snapshot that makes a
/// report actionable without a back-and-forth. All fields are optional free
/// strings supplied by the client.
class FeedbackDiagnostics extends $pb.GeneratedMessage {
  factory FeedbackDiagnostics({
    $core.String? appVersion,
    $core.String? platform,
    $core.String? accountMode,
    $core.String? themeMode,
  }) {
    final result = create();
    if (appVersion != null) result.appVersion = appVersion;
    if (platform != null) result.platform = platform;
    if (accountMode != null) result.accountMode = accountMode;
    if (themeMode != null) result.themeMode = themeMode;
    return result;
  }

  FeedbackDiagnostics._();

  factory FeedbackDiagnostics.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory FeedbackDiagnostics.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'FeedbackDiagnostics',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.feedback.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'appVersion')
    ..aOS(2, _omitFieldNames ? '' : 'platform')
    ..aOS(3, _omitFieldNames ? '' : 'accountMode')
    ..aOS(4, _omitFieldNames ? '' : 'themeMode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeedbackDiagnostics clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  FeedbackDiagnostics copyWith(void Function(FeedbackDiagnostics) updates) =>
      super.copyWith((message) => updates(message as FeedbackDiagnostics))
          as FeedbackDiagnostics;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static FeedbackDiagnostics create() => FeedbackDiagnostics._();
  @$core.override
  FeedbackDiagnostics createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static FeedbackDiagnostics getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<FeedbackDiagnostics>(create);
  static FeedbackDiagnostics? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get appVersion => $_getSZ(0);
  @$pb.TagNumber(1)
  set appVersion($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAppVersion() => $_has(0);
  @$pb.TagNumber(1)
  void clearAppVersion() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get platform => $_getSZ(1);
  @$pb.TagNumber(2)
  set platform($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPlatform() => $_has(1);
  @$pb.TagNumber(2)
  void clearPlatform() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get accountMode => $_getSZ(2);
  @$pb.TagNumber(3)
  set accountMode($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAccountMode() => $_has(2);
  @$pb.TagNumber(3)
  void clearAccountMode() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get themeMode => $_getSZ(3);
  @$pb.TagNumber(4)
  set themeMode($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasThemeMode() => $_has(3);
  @$pb.TagNumber(4)
  void clearThemeMode() => $_clearField(4);
}

class SubmitFeedbackRequest extends $pb.GeneratedMessage {
  factory SubmitFeedbackRequest({
    FeedbackType? type,
    $core.String? body,
    $core.String? contact,
    FeedbackDiagnostics? diagnostics,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (body != null) result.body = body;
    if (contact != null) result.contact = contact;
    if (diagnostics != null) result.diagnostics = diagnostics;
    return result;
  }

  SubmitFeedbackRequest._();

  factory SubmitFeedbackRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubmitFeedbackRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitFeedbackRequest',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.feedback.v1'),
      createEmptyInstance: create)
    ..aE<FeedbackType>(1, _omitFieldNames ? '' : 'type',
        enumValues: FeedbackType.values)
    ..aOS(2, _omitFieldNames ? '' : 'body')
    ..aOS(3, _omitFieldNames ? '' : 'contact')
    ..aOM<FeedbackDiagnostics>(4, _omitFieldNames ? '' : 'diagnostics',
        subBuilder: FeedbackDiagnostics.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitFeedbackRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitFeedbackRequest copyWith(
          void Function(SubmitFeedbackRequest) updates) =>
      super.copyWith((message) => updates(message as SubmitFeedbackRequest))
          as SubmitFeedbackRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubmitFeedbackRequest create() => SubmitFeedbackRequest._();
  @$core.override
  SubmitFeedbackRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubmitFeedbackRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitFeedbackRequest>(create);
  static SubmitFeedbackRequest? _defaultInstance;

  @$pb.TagNumber(1)
  FeedbackType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(FeedbackType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get body => $_getSZ(1);
  @$pb.TagNumber(2)
  set body($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasBody() => $_has(1);
  @$pb.TagNumber(2)
  void clearBody() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get contact => $_getSZ(2);
  @$pb.TagNumber(3)
  set contact($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasContact() => $_has(2);
  @$pb.TagNumber(3)
  void clearContact() => $_clearField(3);

  @$pb.TagNumber(4)
  FeedbackDiagnostics get diagnostics => $_getN(3);
  @$pb.TagNumber(4)
  set diagnostics(FeedbackDiagnostics value) => $_setField(4, value);
  @$pb.TagNumber(4)
  $core.bool hasDiagnostics() => $_has(3);
  @$pb.TagNumber(4)
  void clearDiagnostics() => $_clearField(4);
  @$pb.TagNumber(4)
  FeedbackDiagnostics ensureDiagnostics() => $_ensure(3);
}

class SubmitFeedbackResponse extends $pb.GeneratedMessage {
  factory SubmitFeedbackResponse({
    $fixnum.Int64? id,
  }) {
    final result = create();
    if (id != null) result.id = id;
    return result;
  }

  SubmitFeedbackResponse._();

  factory SubmitFeedbackResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory SubmitFeedbackResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'SubmitFeedbackResponse',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'yucai.feedback.v1'),
      createEmptyInstance: create)
    ..aInt64(1, _omitFieldNames ? '' : 'id')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitFeedbackResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  SubmitFeedbackResponse copyWith(
          void Function(SubmitFeedbackResponse) updates) =>
      super.copyWith((message) => updates(message as SubmitFeedbackResponse))
          as SubmitFeedbackResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static SubmitFeedbackResponse create() => SubmitFeedbackResponse._();
  @$core.override
  SubmitFeedbackResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static SubmitFeedbackResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<SubmitFeedbackResponse>(create);
  static SubmitFeedbackResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get id => $_getI64(0);
  @$pb.TagNumber(1)
  set id($fixnum.Int64 value) => $_setInt64(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
