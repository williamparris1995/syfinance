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

import 'package:protobuf/protobuf.dart' as $pb;

import 'auth.pb.dart' as $0;
import 'auth.pbjson.dart';

export 'auth.pb.dart';

abstract class AuthServiceBase extends $pb.GeneratedService {
  $async.Future<$0.RegisterResponse> register(
      $pb.ServerContext ctx, $0.RegisterRequest request);
  $async.Future<$0.LoginResponse> login(
      $pb.ServerContext ctx, $0.LoginRequest request);
  $async.Future<$0.RefreshTokenResponse> refreshToken(
      $pb.ServerContext ctx, $0.RefreshTokenRequest request);
  $async.Future<$0.GetProfileResponse> getProfile(
      $pb.ServerContext ctx, $0.GetProfileRequest request);
  $async.Future<$0.UpdateProfileResponse> updateProfile(
      $pb.ServerContext ctx, $0.UpdateProfileRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'Register':
        return $0.RegisterRequest();
      case 'Login':
        return $0.LoginRequest();
      case 'RefreshToken':
        return $0.RefreshTokenRequest();
      case 'GetProfile':
        return $0.GetProfileRequest();
      case 'UpdateProfile':
        return $0.UpdateProfileRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'Register':
        return register(ctx, request as $0.RegisterRequest);
      case 'Login':
        return login(ctx, request as $0.LoginRequest);
      case 'RefreshToken':
        return refreshToken(ctx, request as $0.RefreshTokenRequest);
      case 'GetProfile':
        return getProfile(ctx, request as $0.GetProfileRequest);
      case 'UpdateProfile':
        return updateProfile(ctx, request as $0.UpdateProfileRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => AuthServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => AuthServiceBase$messageJson;
}
