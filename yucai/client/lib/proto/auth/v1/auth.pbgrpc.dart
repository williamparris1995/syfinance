// This is a generated file - do not edit.
//
// Generated from auth/v1/auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;

import 'auth.pb.dart' as $0;

export 'auth.pb.dart';

/// AuthService handles authentication, registration, and profile management.
@$pb.GrpcServiceName('yucai.auth.v1.AuthService')
class AuthServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AuthServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.RegisterResponse> register(
    $0.RegisterRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$register, request, options: options);
  }

  $grpc.ResponseFuture<$0.LoginResponse> login(
    $0.LoginRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$login, request, options: options);
  }

  $grpc.ResponseFuture<$0.RefreshTokenResponse> refreshToken(
    $0.RefreshTokenRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$refreshToken, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetProfileResponse> getProfile(
    $0.GetProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getProfile, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdateProfileResponse> updateProfile(
    $0.UpdateProfileRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateProfile, request, options: options);
  }

  $grpc.ResponseFuture<$0.GetPreferencesResponse> getPreferences(
    $0.GetPreferencesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPreferences, request, options: options);
  }

  $grpc.ResponseFuture<$0.UpdatePreferencesResponse> updatePreferences(
    $0.UpdatePreferencesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updatePreferences, request, options: options);
  }

  // method descriptors

  static final _$register =
      $grpc.ClientMethod<$0.RegisterRequest, $0.RegisterResponse>(
          '/yucai.auth.v1.AuthService/Register',
          ($0.RegisterRequest value) => value.writeToBuffer(),
          $0.RegisterResponse.fromBuffer);
  static final _$login = $grpc.ClientMethod<$0.LoginRequest, $0.LoginResponse>(
      '/yucai.auth.v1.AuthService/Login',
      ($0.LoginRequest value) => value.writeToBuffer(),
      $0.LoginResponse.fromBuffer);
  static final _$refreshToken =
      $grpc.ClientMethod<$0.RefreshTokenRequest, $0.RefreshTokenResponse>(
          '/yucai.auth.v1.AuthService/RefreshToken',
          ($0.RefreshTokenRequest value) => value.writeToBuffer(),
          $0.RefreshTokenResponse.fromBuffer);
  static final _$getProfile =
      $grpc.ClientMethod<$0.GetProfileRequest, $0.GetProfileResponse>(
          '/yucai.auth.v1.AuthService/GetProfile',
          ($0.GetProfileRequest value) => value.writeToBuffer(),
          $0.GetProfileResponse.fromBuffer);
  static final _$updateProfile =
      $grpc.ClientMethod<$0.UpdateProfileRequest, $0.UpdateProfileResponse>(
          '/yucai.auth.v1.AuthService/UpdateProfile',
          ($0.UpdateProfileRequest value) => value.writeToBuffer(),
          $0.UpdateProfileResponse.fromBuffer);
  static final _$getPreferences =
      $grpc.ClientMethod<$0.GetPreferencesRequest, $0.GetPreferencesResponse>(
          '/yucai.auth.v1.AuthService/GetPreferences',
          ($0.GetPreferencesRequest value) => value.writeToBuffer(),
          $0.GetPreferencesResponse.fromBuffer);
  static final _$updatePreferences = $grpc.ClientMethod<
          $0.UpdatePreferencesRequest, $0.UpdatePreferencesResponse>(
      '/yucai.auth.v1.AuthService/UpdatePreferences',
      ($0.UpdatePreferencesRequest value) => value.writeToBuffer(),
      $0.UpdatePreferencesResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.auth.v1.AuthService')
abstract class AuthServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.auth.v1.AuthService';

  AuthServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.RegisterRequest, $0.RegisterResponse>(
        'Register',
        register_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.RegisterRequest.fromBuffer(value),
        ($0.RegisterResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.LoginRequest, $0.LoginResponse>(
        'Login',
        login_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.LoginRequest.fromBuffer(value),
        ($0.LoginResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RefreshTokenRequest, $0.RefreshTokenResponse>(
            'RefreshToken',
            refreshToken_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RefreshTokenRequest.fromBuffer(value),
            ($0.RefreshTokenResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetProfileRequest, $0.GetProfileResponse>(
        'GetProfile',
        getProfile_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetProfileRequest.fromBuffer(value),
        ($0.GetProfileResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UpdateProfileRequest, $0.UpdateProfileResponse>(
            'UpdateProfile',
            updateProfile_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdateProfileRequest.fromBuffer(value),
            ($0.UpdateProfileResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPreferencesRequest,
            $0.GetPreferencesResponse>(
        'GetPreferences',
        getPreferences_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetPreferencesRequest.fromBuffer(value),
        ($0.GetPreferencesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdatePreferencesRequest,
            $0.UpdatePreferencesResponse>(
        'UpdatePreferences',
        updatePreferences_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdatePreferencesRequest.fromBuffer(value),
        ($0.UpdatePreferencesResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.RegisterResponse> register_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RegisterRequest> $request) async {
    return register($call, await $request);
  }

  $async.Future<$0.RegisterResponse> register(
      $grpc.ServiceCall call, $0.RegisterRequest request);

  $async.Future<$0.LoginResponse> login_Pre(
      $grpc.ServiceCall $call, $async.Future<$0.LoginRequest> $request) async {
    return login($call, await $request);
  }

  $async.Future<$0.LoginResponse> login(
      $grpc.ServiceCall call, $0.LoginRequest request);

  $async.Future<$0.RefreshTokenResponse> refreshToken_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RefreshTokenRequest> $request) async {
    return refreshToken($call, await $request);
  }

  $async.Future<$0.RefreshTokenResponse> refreshToken(
      $grpc.ServiceCall call, $0.RefreshTokenRequest request);

  $async.Future<$0.GetProfileResponse> getProfile_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetProfileRequest> $request) async {
    return getProfile($call, await $request);
  }

  $async.Future<$0.GetProfileResponse> getProfile(
      $grpc.ServiceCall call, $0.GetProfileRequest request);

  $async.Future<$0.UpdateProfileResponse> updateProfile_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateProfileRequest> $request) async {
    return updateProfile($call, await $request);
  }

  $async.Future<$0.UpdateProfileResponse> updateProfile(
      $grpc.ServiceCall call, $0.UpdateProfileRequest request);

  $async.Future<$0.GetPreferencesResponse> getPreferences_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetPreferencesRequest> $request) async {
    return getPreferences($call, await $request);
  }

  $async.Future<$0.GetPreferencesResponse> getPreferences(
      $grpc.ServiceCall call, $0.GetPreferencesRequest request);

  $async.Future<$0.UpdatePreferencesResponse> updatePreferences_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdatePreferencesRequest> $request) async {
    return updatePreferences($call, await $request);
  }

  $async.Future<$0.UpdatePreferencesResponse> updatePreferences(
      $grpc.ServiceCall call, $0.UpdatePreferencesRequest request);
}
