// This is a generated file - do not edit.
//
// Generated from auth/v1/auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class RegisterRequest extends $pb.GeneratedMessage {
  factory RegisterRequest({
    $core.String? email,
    $core.String? password,
    $core.String? displayName,
  }) {
    final result = create();
    if (email != null) result.email = email;
    if (password != null) result.password = password;
    if (displayName != null) result.displayName = displayName;
    return result;
  }

  RegisterRequest._();

  factory RegisterRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..aOS(2, _omitFieldNames ? '' : 'password')
    ..aOS(3, _omitFieldNames ? '' : 'displayName')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterRequest copyWith(void Function(RegisterRequest) updates) =>
      super.copyWith((message) => updates(message as RegisterRequest))
          as RegisterRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterRequest create() => RegisterRequest._();
  @$core.override
  RegisterRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterRequest>(create);
  static RegisterRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get password => $_getSZ(1);
  @$pb.TagNumber(2)
  set password($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPassword() => $_has(1);
  @$pb.TagNumber(2)
  void clearPassword() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get displayName => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayName() => $_clearField(3);
}

class RegisterResponse extends $pb.GeneratedMessage {
  factory RegisterResponse({
    $core.String? accessToken,
    $core.String? refreshToken,
    UserDTO? user,
  }) {
    final result = create();
    if (accessToken != null) result.accessToken = accessToken;
    if (refreshToken != null) result.refreshToken = refreshToken;
    if (user != null) result.user = user;
    return result;
  }

  RegisterResponse._();

  factory RegisterResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RegisterResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RegisterResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accessToken')
    ..aOS(2, _omitFieldNames ? '' : 'refreshToken')
    ..aOM<UserDTO>(3, _omitFieldNames ? '' : 'user', subBuilder: UserDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RegisterResponse copyWith(void Function(RegisterResponse) updates) =>
      super.copyWith((message) => updates(message as RegisterResponse))
          as RegisterResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RegisterResponse create() => RegisterResponse._();
  @$core.override
  RegisterResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RegisterResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RegisterResponse>(create);
  static RegisterResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accessToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set accessToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccessToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccessToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get refreshToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set refreshToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRefreshToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearRefreshToken() => $_clearField(2);

  @$pb.TagNumber(3)
  UserDTO get user => $_getN(2);
  @$pb.TagNumber(3)
  set user(UserDTO value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUser() => $_has(2);
  @$pb.TagNumber(3)
  void clearUser() => $_clearField(3);
  @$pb.TagNumber(3)
  UserDTO ensureUser() => $_ensure(2);
}

class LoginRequest extends $pb.GeneratedMessage {
  factory LoginRequest({
    $core.String? email,
    $core.String? password,
  }) {
    final result = create();
    if (email != null) result.email = email;
    if (password != null) result.password = password;
    return result;
  }

  LoginRequest._();

  factory LoginRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoginRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'email')
    ..aOS(2, _omitFieldNames ? '' : 'password')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginRequest copyWith(void Function(LoginRequest) updates) =>
      super.copyWith((message) => updates(message as LoginRequest))
          as LoginRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginRequest create() => LoginRequest._();
  @$core.override
  LoginRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoginRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginRequest>(create);
  static LoginRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get email => $_getSZ(0);
  @$pb.TagNumber(1)
  set email($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasEmail() => $_has(0);
  @$pb.TagNumber(1)
  void clearEmail() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get password => $_getSZ(1);
  @$pb.TagNumber(2)
  set password($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasPassword() => $_has(1);
  @$pb.TagNumber(2)
  void clearPassword() => $_clearField(2);
}

class LoginResponse extends $pb.GeneratedMessage {
  factory LoginResponse({
    $core.String? accessToken,
    $core.String? refreshToken,
    UserDTO? user,
  }) {
    final result = create();
    if (accessToken != null) result.accessToken = accessToken;
    if (refreshToken != null) result.refreshToken = refreshToken;
    if (user != null) result.user = user;
    return result;
  }

  LoginResponse._();

  factory LoginResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory LoginResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'LoginResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accessToken')
    ..aOS(2, _omitFieldNames ? '' : 'refreshToken')
    ..aOM<UserDTO>(3, _omitFieldNames ? '' : 'user', subBuilder: UserDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  LoginResponse copyWith(void Function(LoginResponse) updates) =>
      super.copyWith((message) => updates(message as LoginResponse))
          as LoginResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static LoginResponse create() => LoginResponse._();
  @$core.override
  LoginResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static LoginResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<LoginResponse>(create);
  static LoginResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accessToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set accessToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccessToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccessToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get refreshToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set refreshToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRefreshToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearRefreshToken() => $_clearField(2);

  @$pb.TagNumber(3)
  UserDTO get user => $_getN(2);
  @$pb.TagNumber(3)
  set user(UserDTO value) => $_setField(3, value);
  @$pb.TagNumber(3)
  $core.bool hasUser() => $_has(2);
  @$pb.TagNumber(3)
  void clearUser() => $_clearField(3);
  @$pb.TagNumber(3)
  UserDTO ensureUser() => $_ensure(2);
}

class RefreshTokenRequest extends $pb.GeneratedMessage {
  factory RefreshTokenRequest({
    $core.String? refreshToken,
  }) {
    final result = create();
    if (refreshToken != null) result.refreshToken = refreshToken;
    return result;
  }

  RefreshTokenRequest._();

  factory RefreshTokenRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefreshTokenRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefreshTokenRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'refreshToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshTokenRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshTokenRequest copyWith(void Function(RefreshTokenRequest) updates) =>
      super.copyWith((message) => updates(message as RefreshTokenRequest))
          as RefreshTokenRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefreshTokenRequest create() => RefreshTokenRequest._();
  @$core.override
  RefreshTokenRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RefreshTokenRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefreshTokenRequest>(create);
  static RefreshTokenRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get refreshToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set refreshToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasRefreshToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearRefreshToken() => $_clearField(1);
}

class RefreshTokenResponse extends $pb.GeneratedMessage {
  factory RefreshTokenResponse({
    $core.String? accessToken,
    $core.String? refreshToken,
  }) {
    final result = create();
    if (accessToken != null) result.accessToken = accessToken;
    if (refreshToken != null) result.refreshToken = refreshToken;
    return result;
  }

  RefreshTokenResponse._();

  factory RefreshTokenResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory RefreshTokenResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'RefreshTokenResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'accessToken')
    ..aOS(2, _omitFieldNames ? '' : 'refreshToken')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshTokenResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  RefreshTokenResponse copyWith(void Function(RefreshTokenResponse) updates) =>
      super.copyWith((message) => updates(message as RefreshTokenResponse))
          as RefreshTokenResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static RefreshTokenResponse create() => RefreshTokenResponse._();
  @$core.override
  RefreshTokenResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static RefreshTokenResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<RefreshTokenResponse>(create);
  static RefreshTokenResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get accessToken => $_getSZ(0);
  @$pb.TagNumber(1)
  set accessToken($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasAccessToken() => $_has(0);
  @$pb.TagNumber(1)
  void clearAccessToken() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get refreshToken => $_getSZ(1);
  @$pb.TagNumber(2)
  set refreshToken($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRefreshToken() => $_has(1);
  @$pb.TagNumber(2)
  void clearRefreshToken() => $_clearField(2);
}

class GetProfileRequest extends $pb.GeneratedMessage {
  factory GetProfileRequest() => create();

  GetProfileRequest._();

  factory GetProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProfileRequest copyWith(void Function(GetProfileRequest) updates) =>
      super.copyWith((message) => updates(message as GetProfileRequest))
          as GetProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProfileRequest create() => GetProfileRequest._();
  @$core.override
  GetProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProfileRequest>(create);
  static GetProfileRequest? _defaultInstance;
}

class GetProfileResponse extends $pb.GeneratedMessage {
  factory GetProfileResponse({
    UserDTO? user,
  }) {
    final result = create();
    if (user != null) result.user = user;
    return result;
  }

  GetProfileResponse._();

  factory GetProfileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetProfileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetProfileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOM<UserDTO>(1, _omitFieldNames ? '' : 'user', subBuilder: UserDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProfileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetProfileResponse copyWith(void Function(GetProfileResponse) updates) =>
      super.copyWith((message) => updates(message as GetProfileResponse))
          as GetProfileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetProfileResponse create() => GetProfileResponse._();
  @$core.override
  GetProfileResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetProfileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetProfileResponse>(create);
  static GetProfileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  UserDTO get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(UserDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  UserDTO ensureUser() => $_ensure(0);
}

class UpdateProfileRequest extends $pb.GeneratedMessage {
  factory UpdateProfileRequest({
    $core.String? displayName,
    $core.String? avatarUrl,
  }) {
    final result = create();
    if (displayName != null) result.displayName = displayName;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    return result;
  }

  UpdateProfileRequest._();

  factory UpdateProfileRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateProfileRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateProfileRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOS(2, _omitFieldNames ? '' : 'displayName')
    ..aOS(3, _omitFieldNames ? '' : 'avatarUrl')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateProfileRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateProfileRequest copyWith(void Function(UpdateProfileRequest) updates) =>
      super.copyWith((message) => updates(message as UpdateProfileRequest))
          as UpdateProfileRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateProfileRequest create() => UpdateProfileRequest._();
  @$core.override
  UpdateProfileRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateProfileRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateProfileRequest>(create);
  static UpdateProfileRequest? _defaultInstance;

  @$pb.TagNumber(2)
  $core.String get displayName => $_getSZ(0);
  @$pb.TagNumber(2)
  set displayName($core.String value) => $_setString(0, value);
  @$pb.TagNumber(2)
  $core.bool hasDisplayName() => $_has(0);
  @$pb.TagNumber(2)
  void clearDisplayName() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get avatarUrl => $_getSZ(1);
  @$pb.TagNumber(3)
  set avatarUrl($core.String value) => $_setString(1, value);
  @$pb.TagNumber(3)
  $core.bool hasAvatarUrl() => $_has(1);
  @$pb.TagNumber(3)
  void clearAvatarUrl() => $_clearField(3);
}

class UpdateProfileResponse extends $pb.GeneratedMessage {
  factory UpdateProfileResponse({
    UserDTO? user,
  }) {
    final result = create();
    if (user != null) result.user = user;
    return result;
  }

  UpdateProfileResponse._();

  factory UpdateProfileResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdateProfileResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdateProfileResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOM<UserDTO>(1, _omitFieldNames ? '' : 'user', subBuilder: UserDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateProfileResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdateProfileResponse copyWith(
          void Function(UpdateProfileResponse) updates) =>
      super.copyWith((message) => updates(message as UpdateProfileResponse))
          as UpdateProfileResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdateProfileResponse create() => UpdateProfileResponse._();
  @$core.override
  UpdateProfileResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdateProfileResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdateProfileResponse>(create);
  static UpdateProfileResponse? _defaultInstance;

  @$pb.TagNumber(1)
  UserDTO get user => $_getN(0);
  @$pb.TagNumber(1)
  set user(UserDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasUser() => $_has(0);
  @$pb.TagNumber(1)
  void clearUser() => $_clearField(1);
  @$pb.TagNumber(1)
  UserDTO ensureUser() => $_ensure(0);
}

class UserDTO extends $pb.GeneratedMessage {
  factory UserDTO({
    $core.String? id,
    $core.String? tenantId,
    $core.String? email,
    $core.String? displayName,
    $core.String? avatarUrl,
    $core.String? createdAt,
    $core.String? preferredCurrency,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (tenantId != null) result.tenantId = tenantId;
    if (email != null) result.email = email;
    if (displayName != null) result.displayName = displayName;
    if (avatarUrl != null) result.avatarUrl = avatarUrl;
    if (createdAt != null) result.createdAt = createdAt;
    if (preferredCurrency != null) result.preferredCurrency = preferredCurrency;
    return result;
  }

  UserDTO._();

  factory UserDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UserDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UserDTO',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'id')
    ..aOS(2, _omitFieldNames ? '' : 'tenantId')
    ..aOS(3, _omitFieldNames ? '' : 'email')
    ..aOS(4, _omitFieldNames ? '' : 'displayName')
    ..aOS(5, _omitFieldNames ? '' : 'avatarUrl')
    ..aOS(6, _omitFieldNames ? '' : 'createdAt')
    ..aOS(7, _omitFieldNames ? '' : 'preferredCurrency')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UserDTO copyWith(void Function(UserDTO) updates) =>
      super.copyWith((message) => updates(message as UserDTO)) as UserDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UserDTO create() => UserDTO._();
  @$core.override
  UserDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UserDTO getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<UserDTO>(create);
  static UserDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get id => $_getSZ(0);
  @$pb.TagNumber(1)
  set id($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get tenantId => $_getSZ(1);
  @$pb.TagNumber(2)
  set tenantId($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasTenantId() => $_has(1);
  @$pb.TagNumber(2)
  void clearTenantId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get email => $_getSZ(2);
  @$pb.TagNumber(3)
  set email($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasEmail() => $_has(2);
  @$pb.TagNumber(3)
  void clearEmail() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get displayName => $_getSZ(3);
  @$pb.TagNumber(4)
  set displayName($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDisplayName() => $_has(3);
  @$pb.TagNumber(4)
  void clearDisplayName() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.String get avatarUrl => $_getSZ(4);
  @$pb.TagNumber(5)
  set avatarUrl($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasAvatarUrl() => $_has(4);
  @$pb.TagNumber(5)
  void clearAvatarUrl() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get createdAt => $_getSZ(5);
  @$pb.TagNumber(6)
  set createdAt($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCreatedAt() => $_has(5);
  @$pb.TagNumber(6)
  void clearCreatedAt() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get preferredCurrency => $_getSZ(6);
  @$pb.TagNumber(7)
  set preferredCurrency($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasPreferredCurrency() => $_has(6);
  @$pb.TagNumber(7)
  void clearPreferredCurrency() => $_clearField(7);
}

/// TenantPreferencesDTO carries the tenant-level display currency and rate-sync
/// interval. Embedded in UserDTO-free preference RPCs so the client can read and
/// edit tenant settings independently of the user profile.
class TenantPreferencesDTO extends $pb.GeneratedMessage {
  factory TenantPreferencesDTO({
    $core.String? preferredCurrency,
    $core.int? rateSyncIntervalHours,
  }) {
    final result = create();
    if (preferredCurrency != null) result.preferredCurrency = preferredCurrency;
    if (rateSyncIntervalHours != null)
      result.rateSyncIntervalHours = rateSyncIntervalHours;
    return result;
  }

  TenantPreferencesDTO._();

  factory TenantPreferencesDTO.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TenantPreferencesDTO.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TenantPreferencesDTO',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'preferredCurrency')
    ..aI(2, _omitFieldNames ? '' : 'rateSyncIntervalHours')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TenantPreferencesDTO clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TenantPreferencesDTO copyWith(void Function(TenantPreferencesDTO) updates) =>
      super.copyWith((message) => updates(message as TenantPreferencesDTO))
          as TenantPreferencesDTO;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TenantPreferencesDTO create() => TenantPreferencesDTO._();
  @$core.override
  TenantPreferencesDTO createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TenantPreferencesDTO getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TenantPreferencesDTO>(create);
  static TenantPreferencesDTO? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get preferredCurrency => $_getSZ(0);
  @$pb.TagNumber(1)
  set preferredCurrency($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPreferredCurrency() => $_has(0);
  @$pb.TagNumber(1)
  void clearPreferredCurrency() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get rateSyncIntervalHours => $_getIZ(1);
  @$pb.TagNumber(2)
  set rateSyncIntervalHours($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRateSyncIntervalHours() => $_has(1);
  @$pb.TagNumber(2)
  void clearRateSyncIntervalHours() => $_clearField(2);
}

class GetPreferencesRequest extends $pb.GeneratedMessage {
  factory GetPreferencesRequest() => create();

  GetPreferencesRequest._();

  factory GetPreferencesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPreferencesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPreferencesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPreferencesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPreferencesRequest copyWith(
          void Function(GetPreferencesRequest) updates) =>
      super.copyWith((message) => updates(message as GetPreferencesRequest))
          as GetPreferencesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPreferencesRequest create() => GetPreferencesRequest._();
  @$core.override
  GetPreferencesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPreferencesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPreferencesRequest>(create);
  static GetPreferencesRequest? _defaultInstance;
}

class GetPreferencesResponse extends $pb.GeneratedMessage {
  factory GetPreferencesResponse({
    TenantPreferencesDTO? preferences,
  }) {
    final result = create();
    if (preferences != null) result.preferences = preferences;
    return result;
  }

  GetPreferencesResponse._();

  factory GetPreferencesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory GetPreferencesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'GetPreferencesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOM<TenantPreferencesDTO>(1, _omitFieldNames ? '' : 'preferences',
        subBuilder: TenantPreferencesDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPreferencesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  GetPreferencesResponse copyWith(
          void Function(GetPreferencesResponse) updates) =>
      super.copyWith((message) => updates(message as GetPreferencesResponse))
          as GetPreferencesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static GetPreferencesResponse create() => GetPreferencesResponse._();
  @$core.override
  GetPreferencesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static GetPreferencesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<GetPreferencesResponse>(create);
  static GetPreferencesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  TenantPreferencesDTO get preferences => $_getN(0);
  @$pb.TagNumber(1)
  set preferences(TenantPreferencesDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPreferences() => $_has(0);
  @$pb.TagNumber(1)
  void clearPreferences() => $_clearField(1);
  @$pb.TagNumber(1)
  TenantPreferencesDTO ensurePreferences() => $_ensure(0);
}

class UpdatePreferencesRequest extends $pb.GeneratedMessage {
  factory UpdatePreferencesRequest({
    $core.String? preferredCurrency,
    $core.int? rateSyncIntervalHours,
  }) {
    final result = create();
    if (preferredCurrency != null) result.preferredCurrency = preferredCurrency;
    if (rateSyncIntervalHours != null)
      result.rateSyncIntervalHours = rateSyncIntervalHours;
    return result;
  }

  UpdatePreferencesRequest._();

  factory UpdatePreferencesRequest.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePreferencesRequest.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePreferencesRequest',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'preferredCurrency')
    ..aI(2, _omitFieldNames ? '' : 'rateSyncIntervalHours')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePreferencesRequest clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePreferencesRequest copyWith(
          void Function(UpdatePreferencesRequest) updates) =>
      super.copyWith((message) => updates(message as UpdatePreferencesRequest))
          as UpdatePreferencesRequest;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePreferencesRequest create() => UpdatePreferencesRequest._();
  @$core.override
  UpdatePreferencesRequest createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePreferencesRequest getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePreferencesRequest>(create);
  static UpdatePreferencesRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get preferredCurrency => $_getSZ(0);
  @$pb.TagNumber(1)
  set preferredCurrency($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasPreferredCurrency() => $_has(0);
  @$pb.TagNumber(1)
  void clearPreferredCurrency() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get rateSyncIntervalHours => $_getIZ(1);
  @$pb.TagNumber(2)
  set rateSyncIntervalHours($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasRateSyncIntervalHours() => $_has(1);
  @$pb.TagNumber(2)
  void clearRateSyncIntervalHours() => $_clearField(2);
}

class UpdatePreferencesResponse extends $pb.GeneratedMessage {
  factory UpdatePreferencesResponse({
    TenantPreferencesDTO? preferences,
  }) {
    final result = create();
    if (preferences != null) result.preferences = preferences;
    return result;
  }

  UpdatePreferencesResponse._();

  factory UpdatePreferencesResponse.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory UpdatePreferencesResponse.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'UpdatePreferencesResponse',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'yucai.auth.v1'),
      createEmptyInstance: create)
    ..aOM<TenantPreferencesDTO>(1, _omitFieldNames ? '' : 'preferences',
        subBuilder: TenantPreferencesDTO.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePreferencesResponse clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  UpdatePreferencesResponse copyWith(
          void Function(UpdatePreferencesResponse) updates) =>
      super.copyWith((message) => updates(message as UpdatePreferencesResponse))
          as UpdatePreferencesResponse;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static UpdatePreferencesResponse create() => UpdatePreferencesResponse._();
  @$core.override
  UpdatePreferencesResponse createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static UpdatePreferencesResponse getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<UpdatePreferencesResponse>(create);
  static UpdatePreferencesResponse? _defaultInstance;

  @$pb.TagNumber(1)
  TenantPreferencesDTO get preferences => $_getN(0);
  @$pb.TagNumber(1)
  set preferences(TenantPreferencesDTO value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasPreferences() => $_has(0);
  @$pb.TagNumber(1)
  void clearPreferences() => $_clearField(1);
  @$pb.TagNumber(1)
  TenantPreferencesDTO ensurePreferences() => $_ensure(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
