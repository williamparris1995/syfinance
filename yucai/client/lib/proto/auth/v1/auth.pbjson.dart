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

@$core.Deprecated('Use getOIDCConfigRequestDescriptor instead')
const GetOIDCConfigRequest$json = {
  '1': 'GetOIDCConfigRequest',
};

/// Descriptor for `GetOIDCConfigRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getOIDCConfigRequestDescriptor =
    $convert.base64Decode('ChRHZXRPSURDQ29uZmlnUmVxdWVzdA==');

@$core.Deprecated('Use oIDCProviderConfigDescriptor instead')
const OIDCProviderConfig$json = {
  '1': 'OIDCProviderConfig',
  '2': [
    {'1': 'name', '3': 1, '4': 1, '5': 9, '10': 'name'},
    {'1': 'display_name', '3': 2, '4': 1, '5': 9, '10': 'displayName'},
    {'1': 'issuer', '3': 3, '4': 1, '5': 9, '10': 'issuer'},
    {
      '1': 'authorization_endpoint',
      '3': 4,
      '4': 1,
      '5': 9,
      '10': 'authorizationEndpoint'
    },
    {'1': 'client_id', '3': 5, '4': 1, '5': 9, '10': 'clientId'},
    {'1': 'scopes', '3': 6, '4': 3, '5': 9, '10': 'scopes'},
  ],
};

/// Descriptor for `OIDCProviderConfig`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List oIDCProviderConfigDescriptor = $convert.base64Decode(
    'ChJPSURDUHJvdmlkZXJDb25maWcSEgoEbmFtZRgBIAEoCVIEbmFtZRIhCgxkaXNwbGF5X25hbW'
    'UYAiABKAlSC2Rpc3BsYXlOYW1lEhYKBmlzc3VlchgDIAEoCVIGaXNzdWVyEjUKFmF1dGhvcml6'
    'YXRpb25fZW5kcG9pbnQYBCABKAlSFWF1dGhvcml6YXRpb25FbmRwb2ludBIbCgljbGllbnRfaW'
    'QYBSABKAlSCGNsaWVudElkEhYKBnNjb3BlcxgGIAMoCVIGc2NvcGVz');

@$core.Deprecated('Use getOIDCConfigResponseDescriptor instead')
const GetOIDCConfigResponse$json = {
  '1': 'GetOIDCConfigResponse',
  '2': [
    {
      '1': 'providers',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.yucai.auth.v1.OIDCProviderConfig',
      '10': 'providers'
    },
  ],
};

/// Descriptor for `GetOIDCConfigResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getOIDCConfigResponseDescriptor = $convert.base64Decode(
    'ChVHZXRPSURDQ29uZmlnUmVzcG9uc2USPwoJcHJvdmlkZXJzGAEgAygLMiEueXVjYWkuYXV0aC'
    '52MS5PSURDUHJvdmlkZXJDb25maWdSCXByb3ZpZGVycw==');

@$core.Deprecated('Use oIDCExchangeRequestDescriptor instead')
const OIDCExchangeRequest$json = {
  '1': 'OIDCExchangeRequest',
  '2': [
    {'1': 'provider', '3': 1, '4': 1, '5': 9, '10': 'provider'},
    {'1': 'code', '3': 2, '4': 1, '5': 9, '10': 'code'},
    {'1': 'code_verifier', '3': 3, '4': 1, '5': 9, '10': 'codeVerifier'},
    {'1': 'redirect_uri', '3': 4, '4': 1, '5': 9, '10': 'redirectUri'},
  ],
};

/// Descriptor for `OIDCExchangeRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List oIDCExchangeRequestDescriptor = $convert.base64Decode(
    'ChNPSURDRXhjaGFuZ2VSZXF1ZXN0EhoKCHByb3ZpZGVyGAEgASgJUghwcm92aWRlchISCgRjb2'
    'RlGAIgASgJUgRjb2RlEiMKDWNvZGVfdmVyaWZpZXIYAyABKAlSDGNvZGVWZXJpZmllchIhCgxy'
    'ZWRpcmVjdF91cmkYBCABKAlSC3JlZGlyZWN0VXJp');

@$core.Deprecated('Use oIDCExchangeResponseDescriptor instead')
const OIDCExchangeResponse$json = {
  '1': 'OIDCExchangeResponse',
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

/// Descriptor for `OIDCExchangeResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List oIDCExchangeResponseDescriptor = $convert.base64Decode(
    'ChRPSURDRXhjaGFuZ2VSZXNwb25zZRIhCgxhY2Nlc3NfdG9rZW4YASABKAlSC2FjY2Vzc1Rva2'
    'VuEiMKDXJlZnJlc2hfdG9rZW4YAiABKAlSDHJlZnJlc2hUb2tlbhIqCgR1c2VyGAMgASgLMhYu'
    'eXVjYWkuYXV0aC52MS5Vc2VyRFRPUgR1c2Vy');

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
    {
      '1': 'preferred_currency',
      '3': 7,
      '4': 1,
      '5': 9,
      '10': 'preferredCurrency'
    },
  ],
};

/// Descriptor for `UserDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List userDTODescriptor = $convert.base64Decode(
    'CgdVc2VyRFRPEg4KAmlkGAEgASgJUgJpZBIbCgl0ZW5hbnRfaWQYAiABKAlSCHRlbmFudElkEh'
    'QKBWVtYWlsGAMgASgJUgVlbWFpbBIhCgxkaXNwbGF5X25hbWUYBCABKAlSC2Rpc3BsYXlOYW1l'
    'Eh0KCmF2YXRhcl91cmwYBSABKAlSCWF2YXRhclVybBIdCgpjcmVhdGVkX2F0GAYgASgJUgljcm'
    'VhdGVkQXQSLQoScHJlZmVycmVkX2N1cnJlbmN5GAcgASgJUhFwcmVmZXJyZWRDdXJyZW5jeQ==');

@$core.Deprecated('Use tenantPreferencesDTODescriptor instead')
const TenantPreferencesDTO$json = {
  '1': 'TenantPreferencesDTO',
  '2': [
    {
      '1': 'preferred_currency',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'preferredCurrency'
    },
    {
      '1': 'rate_sync_interval_hours',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'rateSyncIntervalHours'
    },
  ],
};

/// Descriptor for `TenantPreferencesDTO`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List tenantPreferencesDTODescriptor = $convert.base64Decode(
    'ChRUZW5hbnRQcmVmZXJlbmNlc0RUTxItChJwcmVmZXJyZWRfY3VycmVuY3kYASABKAlSEXByZW'
    'ZlcnJlZEN1cnJlbmN5EjcKGHJhdGVfc3luY19pbnRlcnZhbF9ob3VycxgCIAEoBVIVcmF0ZVN5'
    'bmNJbnRlcnZhbEhvdXJz');

@$core.Deprecated('Use getPreferencesRequestDescriptor instead')
const GetPreferencesRequest$json = {
  '1': 'GetPreferencesRequest',
};

/// Descriptor for `GetPreferencesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPreferencesRequestDescriptor =
    $convert.base64Decode('ChVHZXRQcmVmZXJlbmNlc1JlcXVlc3Q=');

@$core.Deprecated('Use getPreferencesResponseDescriptor instead')
const GetPreferencesResponse$json = {
  '1': 'GetPreferencesResponse',
  '2': [
    {
      '1': 'preferences',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.auth.v1.TenantPreferencesDTO',
      '10': 'preferences'
    },
  ],
};

/// Descriptor for `GetPreferencesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List getPreferencesResponseDescriptor =
    $convert.base64Decode(
        'ChZHZXRQcmVmZXJlbmNlc1Jlc3BvbnNlEkUKC3ByZWZlcmVuY2VzGAEgASgLMiMueXVjYWkuYX'
        'V0aC52MS5UZW5hbnRQcmVmZXJlbmNlc0RUT1ILcHJlZmVyZW5jZXM=');

@$core.Deprecated('Use updatePreferencesRequestDescriptor instead')
const UpdatePreferencesRequest$json = {
  '1': 'UpdatePreferencesRequest',
  '2': [
    {
      '1': 'preferred_currency',
      '3': 1,
      '4': 1,
      '5': 9,
      '10': 'preferredCurrency'
    },
    {
      '1': 'rate_sync_interval_hours',
      '3': 2,
      '4': 1,
      '5': 5,
      '10': 'rateSyncIntervalHours'
    },
  ],
};

/// Descriptor for `UpdatePreferencesRequest`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePreferencesRequestDescriptor = $convert.base64Decode(
    'ChhVcGRhdGVQcmVmZXJlbmNlc1JlcXVlc3QSLQoScHJlZmVycmVkX2N1cnJlbmN5GAEgASgJUh'
    'FwcmVmZXJyZWRDdXJyZW5jeRI3ChhyYXRlX3N5bmNfaW50ZXJ2YWxfaG91cnMYAiABKAVSFXJh'
    'dGVTeW5jSW50ZXJ2YWxIb3Vycw==');

@$core.Deprecated('Use updatePreferencesResponseDescriptor instead')
const UpdatePreferencesResponse$json = {
  '1': 'UpdatePreferencesResponse',
  '2': [
    {
      '1': 'preferences',
      '3': 1,
      '4': 1,
      '5': 11,
      '6': '.yucai.auth.v1.TenantPreferencesDTO',
      '10': 'preferences'
    },
  ],
};

/// Descriptor for `UpdatePreferencesResponse`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List updatePreferencesResponseDescriptor =
    $convert.base64Decode(
        'ChlVcGRhdGVQcmVmZXJlbmNlc1Jlc3BvbnNlEkUKC3ByZWZlcmVuY2VzGAEgASgLMiMueXVjYW'
        'kuYXV0aC52MS5UZW5hbnRQcmVmZXJlbmNlc0RUT1ILcHJlZmVyZW5jZXM=');
