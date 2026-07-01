// This is a generated file - do not edit.
//
// Generated from networth/v1/service.proto.

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

import 'service.pb.dart' as $0;

export 'service.pb.dart';

/// NetWorthService aggregates account balances + holding market value − debt
/// remaining for a tenant, 折算 to a configurable base currency via the CNY-base
/// rate_history cross rate.
@$pb.GrpcServiceName('yucai.networth.v1.NetWorthService')
class NetWorthServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  NetWorthServiceClient(super.channel, {super.options, super.interceptors});

  /// GetNetWorth returns the tenant's total assets, total liabilities and net
  /// worth (assets − liabilities), all converted to base_currency (empty/CNY →
  /// CNY). Best-effort: a failing source port is logged and skipped; the
  /// remaining sources still contribute.
  $grpc.ResponseFuture<$0.GetNetWorthResponse> getNetWorth(
    $0.GetNetWorthRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getNetWorth, request, options: options);
  }

  // method descriptors

  static final _$getNetWorth =
      $grpc.ClientMethod<$0.GetNetWorthRequest, $0.GetNetWorthResponse>(
          '/yucai.networth.v1.NetWorthService/GetNetWorth',
          ($0.GetNetWorthRequest value) => value.writeToBuffer(),
          $0.GetNetWorthResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.networth.v1.NetWorthService')
abstract class NetWorthServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.networth.v1.NetWorthService';

  NetWorthServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.GetNetWorthRequest, $0.GetNetWorthResponse>(
            'GetNetWorth',
            getNetWorth_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetNetWorthRequest.fromBuffer(value),
            ($0.GetNetWorthResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.GetNetWorthResponse> getNetWorth_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetNetWorthRequest> $request) async {
    return getNetWorth($call, await $request);
  }

  $async.Future<$0.GetNetWorthResponse> getNetWorth(
      $grpc.ServiceCall call, $0.GetNetWorthRequest request);
}
