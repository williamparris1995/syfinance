// This is a generated file - do not edit.
//
// Generated from auth/v1/auth.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports
// ignore_for_file: unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use registerRequestDescriptor instead')
const RegisterRequest$json = {
  '1': 'RegisterRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
    {'1': 'password', '3': 2, '4': 1, '5': 9, '10': 'password'},
    {'1': 'display_name', '3': 3, '4': 1, '5': 9, '10': 'displayName'},
  ],
};

/// Descriptor for `RegisterRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerRequestDescriptor = $convert.base64Decode(
    'Cg9SZWdpc3RlclJlcXVlc3QSFAoFZW1haWwYASABKAlSBWVtYWlsEhoKCHBhc3N3b3JkGAIgAS'
    'gJUghwYXNzd29yZBIhCgxkaXNwbGF5X25hbWUYAyABKAlSC2Rpc3BsYXlOYW1l');

@$core.Deprecated('Use registerResponseDescriptor instead')
const RegisterResponse$json = {
  '1': 'RegisterResponse',
  '2': [
    {'1': 'access_token', '3': 1, '4': 1, '5': 9, '10': 'accessToken'},
    {'1': 'refresh_token', '3': 2, '4': 1, '5': 9, '10': 'refreshToken'},
    {
      '1': 'user',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.yucai.auth.v1.UserDTO',
      '10': 'user'
    },
  ],
};

/// Descriptor for `RegisterResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List registerResponseDescriptor = $convert.base64Decode(
    'ChBSZWdpc3RlclJlc3BvbnNlEiEKDGFjY2Vzc190b2tlbhgBIAEoCVILYWNjZXNzVG9rZW4SIw'
    'oNcmVmcmVzaF90b2tlbhgCIAEoCVIMcmVmcmVzaFRva2VuEioKBHVzZXIYAyABKAsyFi55dWNh'
    'aS5hdXRoLnYxLlVzZXJEVE9SBHVzZXI=');

@$core.Deprecated('Use loginRequestDescriptor instead')
const LoginRequest$json = {
  '1': 'LoginRequest',
  '2': [
    {'1': 'email', '3': 1, '4': 1, '5': 9, '10': 'email'},
    {'1': 'password', '3': 2, '4': 1, '5': 9, '10': 'password'},
  ],
};

/// Descriptor for `LoginRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginRequestDescriptor = $convert.base64Decode(
    'CgxMb2dpblJlcXVlc3QSFAoFZW1haWwYASABKAlSBWVtYWlsEhoKCHBhc3N3b3JkGAIgASgJUg'
    'hwYXNzd29yZA==');

@$core.Deprecated('Use loginResponseDescriptor instead')
const LoginResponse$json = {
  '1': 'LoginResponse',
  '2': [
    {'1': 'access_token', '3': 1, '4': 1, '5': 9, '10': 'accessToken'},
    {'1': 'refresh_token', '3': 2, '4': 1, '5': 9, '10': 'refreshToken'},
    {
      '1': 'user',
      '3': 3,
      '4': 1,
      '5': 11,
      '6': '.yucai.auth.v1.UserDTO',
      '10': 'user'
    },
  ],
};

/// Descriptor for `LoginResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List loginResponseDescriptor = $convert.base64Decode(
    'Cg1Mb2dpblJlc3BvbnNlEiEKDGFjY2Vzc190b2tlbhgBIAEoCVILYWNjZXNzVG9rZW4SIwoNcm'
    'VmcmVzaF90b2tlbhgCIAEoCVIMcmVmcmVzaFRva2VuEioKBHVzZXIYAyABKAsyFi55dWNhaS5h'
    'dXRoLnYxLlVzZXJEVE9SBHVzZXI=');

@$core.Deprecated('Use refreshTokenRequestDescriptor instead')
const RefreshTokenRequest$json = {
  '1': 'RefreshTokenRequest',
  '2': [
    {'1': 'refresh_token', '3': 1, '4': 1, '5': 9, '10': 'refreshToken'},
  ],
};

/// Descriptor for `RefreshTokenRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshTokenRequestDescriptor = $convert.base64Decode(
    'ChNSZWZyZXNoVG9rZW5SZXF1ZXN0EiMKDXJlZnJlc2hfdG9rZW4YASABKAlSDHJlZnJlc2hUb2'
    'tlbg==');

@$core.Deprecated('Use refreshTokenResponseDescriptor instead')
const RefreshTokenResponse$json = {
  '1': 'RefreshTokenResponse',
  '2': [
    {'1': 'access_token', '3': 1, '4': 1, '5': 9, '10': 'accessToken'},
    {'1': 'refresh_token', '3': 2, '4': 1, '5': 9, '10': 'refreshToken'},
  ],
};

/// Descriptor for `RefreshTokenResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List refreshTokenResponseDescriptor = $convert.base64Decode(
    'ChRSZWZyZXNoVG9rZW5SZXNwb25zZRIhCgxhY2Nlc3NfdG9rZW4YASABKAlSC2FjY2Vzc1Rva2'
    'VuEiMKDXJlZnJlc2hfdG9rZW4YAiABKAlSDHJlZnJlc2hUb2tlbg==');

@$core.Deprecated('Use getProfileRequestDescriptor instead')
const GetProfileRequest$json = {
  '1': 'GetProfileRequest',
};

/// Descriptor for `GetProfileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProfileRequestDescriptor =
    $convert.base64Decode('ChFHZXRQcm9maWxlUmVxdWVzdA==');

@$core.Deprecated('Use getProfileResponseDescriptor instead')
const GetProfileResponse$json = {
  '1': 'GetProfileResponse',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.auth.v1.UserDTO',
      '10': 'user'
    },
  ],
};

/// Descriptor for `GetProfileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getProfileResponseDescriptor = $convert.base64Decode(
    'ChJHZXRQcm9maWxlUmVzcG9uc2USKgoEdXNlchgBIAEoCzIWLnl1Y2FpLmF1dGgudjEuVXNlck'
    'RUT1IEdXNlcg==');

@$core.Deprecated('Use updateProfileRequestDescriptor instead')
const UpdateProfileRequest$json = {
  '1': 'UpdateProfileRequest',
  '2': [
    {'1': 'display_name', '3': 2, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'avatar_url', '3': 3, '4': 1, '5': 9, '10': 'avatarUrl'},
  ],
};

/// Descriptor for `UpdateProfileRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateProfileRequestDescriptor = $convert.base64Decode(
    'ChRVcGRhdGVQcm9maWxlUmVxdWVzdBIhCgxkaXNwbGF5X25hbWUYAiABKAlSC2Rpc3BsYXlOYW'
    '1lEh0KCmF2YXRhcl91cmwYAyABKAlSCWF2YXRhclVybA==');

@$core.Deprecated('Use updateProfileResponseDescriptor instead')
const UpdateProfileResponse$json = {
  '1': 'UpdateProfileResponse',
  '2': [
    {
      '1': 'user',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.auth.v1.UserDTO',
      '10': 'user'
    },
  ],
};

/// Descriptor for `UpdateProfileResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updateProfileResponseDescriptor = $convert.base64Decode(
    'ChVVcGRhdGVQcm9maWxlUmVzcG9uc2USKgoEdXNlchgBIAEoCzIWLnl1Y2FpLmF1dGgudjEuVX'
    'NlckRUT1IEdXNlcg==');

@$core.Deprecated('Use userDTODescriptor instead')
const UserDTO$json = {
  '1': 'UserDTO',
  '2': [
    {'1': 'id', '3': 1, '4': 1, '5': 9, '10': 'id'},
    {'1': 'tenant_id', '3': 2, '4': 1, '5': 9, '10': 'tenantId'},
    {'1': 'email', '3': 3, '4': 1, '5': 9, '10': 'email'},
    {'1': 'display_name', '3': 4, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'avatar_url', '3': 5, '4': 1, '5': 9, '10': 'avatarUrl'},
    {'1': 'created_at', '3': 6, '4': 1, '5': 9, '10': 'createdAt'},
  ],
};

/// Descriptor for `UserDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDTODescriptor = $convert.base64Decode(
    'CgdVc2VyRFRPEg4KAmlkGAEgASgJUgJpZBIbCgl0ZW5hbnRfaWQYAiABKAlSCHRlbmFudElkEh'
    'QKBWVtYWlsGAMgASgJUgVlbWFpbBIhCgxkaXNwbGF5X25hbWUYBCABKAlSC2Rpc3BsYXlOYW1l'
    'Eh0KCmF2YXRhcl91cmwYBSABKAlSCWF2YXRhclVybBIdCgpjcmVhdGVkX2F0GAYgASgJUgljcm'
    'VhdGVkQXQ=');

const $core.Map<$core.String, $core.dynamic> AuthServiceBase$json = {
  '1': 'AuthService',
  '2': [
    {
      '1': 'Register',
      '2': '.yucai.auth.v1.RegisterRequest',
      '3': '.yucai.auth.v1.RegisterResponse'
    },
    {
      '1': 'Login',
      '2': '.yucai.auth.v1.LoginRequest',
      '3': '.yucai.auth.v1.LoginResponse'
    },
    {
      '1': 'RefreshToken',
      '2': '.yucai.auth.v1.RefreshTokenRequest',
      '3': '.yucai.auth.v1.RefreshTokenResponse'
    },
    {
      '1': 'GetProfile',
      '2': '.yucai.auth.v1.GetProfileRequest',
      '3': '.yucai.auth.v1.GetProfileResponse'
    },
    {
      '1': 'UpdateProfile',
      '2': '.yucai.auth.v1.UpdateProfileRequest',
      '3': '.yucai.auth.v1.UpdateProfileResponse'
    },
  ],
};

@$core.Deprecated('Use authServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
    AuthServiceBase$messageJson = {
  '.yucai.auth.v1.RegisterRequest': RegisterRequest$json,
  '.yucai.auth.v1.RegisterResponse': RegisterResponse$json,
  '.yucai.auth.v1.UserDTO': UserDTO$json,
  '.yucai.auth.v1.LoginRequest': LoginRequest$json,
  '.yucai.auth.v1.LoginResponse': LoginResponse$json,
  '.yucai.auth.v1.RefreshTokenRequest': RefreshTokenRequest$json,
  '.yucai.auth.v1.RefreshTokenResponse': RefreshTokenResponse$json,
  '.yucai.auth.v1.GetProfileRequest': GetProfileRequest$json,
  '.yucai.auth.v1.GetProfileResponse': GetProfileResponse$json,
  '.yucai.auth.v1.UpdateProfileRequest': UpdateProfileRequest$json,
  '.yucai.auth.v1.UpdateProfileResponse': UpdateProfileResponse$json,
};

/// Descriptor for `AuthService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List authServiceDescriptor = $convert.base64Decode(
    'CgtBdXRoU2VydmljZRJLCghSZWdpc3RlchIeLnl1Y2FpLmF1dGgudjEuUmVnaXN0ZXJSZXF1ZX'
    'N0Gh8ueXVjYWkuYXV0aC52MS5SZWdpc3RlclJlc3BvbnNlEkIKBUxvZ2luEhsueXVjYWkuYXV0'
    'aC52MS5Mb2dpblJlcXVlc3QaHC55dWNhaS5hdXRoLnYxLkxvZ2luUmVzcG9uc2USVwoMUmVmcm'
    'VzaFRva2VuEiIueXVjYWkuYXV0aC52MS5SZWZyZXNoVG9rZW5SZXF1ZXN0GiMueXVjYWkuYXV0'
    'aC52MS5SZWZyZXNoVG9rZW5SZXNwb25zZRJRCgpHZXRQcm9maWxlEiAueXVjYWkuYXV0aC52MS'
    '5HZXRQcm9maWxlUmVxdWVzdBohLnl1Y2FpLmF1dGgudjEuR2V0UHJvZmlsZVJlc3BvbnNlEloK'
    'DVVwZGF0ZVByb2ZpbGUSIy55dWNhaS5hdXRoLnYxLlVwZGF0ZVByb2ZpbGVSZXF1ZXN0GiQueX'
    'VjYWkuYXV0aC52MS5VcGRhdGVQcm9maWxlUmVzcG9uc2U=');
