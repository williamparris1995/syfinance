// This is a generated file - do not edit.
//
// Generated from sync/v1/sync.proto.

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
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import 'sync.pb.dart' as $0;

export 'sync.pb.dart';

@$pb.GrpcServiceName('yucai.sync.v1.SyncService')
class SyncServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  SyncServiceClient(super.channel, {super.options, super.interceptors});

  /// Device registration + status
  $grpc.ResponseFuture<$0.RegisterDeviceResponse> registerDevice(
    $0.RegisterDeviceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$registerDevice, request, options: options);
  }

  $grpc.ResponseFuture<$0.SyncStatusResponse> getSyncStatus(
    $0.GetSyncStatusRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getSyncStatus, request, options: options);
  }

  /// Push/pull per entity batch
  $grpc.ResponseFuture<$0.PushResponse> pushChanges(
    $0.PushChangesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$pushChanges, request, options: options);
  }

  $grpc.ResponseFuture<$0.PullChangesResponse> pullChanges(
    $0.PullChangesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$pullChanges, request, options: options);
  }

  /// Conflict resolution
  $grpc.ResponseFuture<$1.Empty> resolveConflict(
    $0.ResolveConflictRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$resolveConflict, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListConflictsResponse> listConflicts(
    $0.ListConflictsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listConflicts, request, options: options);
  }

  // method descriptors

  static final _$registerDevice =
      $grpc.ClientMethod<$0.RegisterDeviceRequest, $0.RegisterDeviceResponse>(
          '/yucai.sync.v1.SyncService/RegisterDevice',
          ($0.RegisterDeviceRequest value) => value.writeToBuffer(),
          $0.RegisterDeviceResponse.fromBuffer);
  static final _$getSyncStatus =
      $grpc.ClientMethod<$0.GetSyncStatusRequest, $0.SyncStatusResponse>(
          '/yucai.sync.v1.SyncService/GetSyncStatus',
          ($0.GetSyncStatusRequest value) => value.writeToBuffer(),
          $0.SyncStatusResponse.fromBuffer);
  static final _$pushChanges =
      $grpc.ClientMethod<$0.PushChangesRequest, $0.PushResponse>(
          '/yucai.sync.v1.SyncService/PushChanges',
          ($0.PushChangesRequest value) => value.writeToBuffer(),
          $0.PushResponse.fromBuffer);
  static final _$pullChanges =
      $grpc.ClientMethod<$0.PullChangesRequest, $0.PullChangesResponse>(
          '/yucai.sync.v1.SyncService/PullChanges',
          ($0.PullChangesRequest value) => value.writeToBuffer(),
          $0.PullChangesResponse.fromBuffer);
  static final _$resolveConflict =
      $grpc.ClientMethod<$0.ResolveConflictRequest, $1.Empty>(
          '/yucai.sync.v1.SyncService/ResolveConflict',
          ($0.ResolveConflictRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$listConflicts =
      $grpc.ClientMethod<$0.ListConflictsRequest, $0.ListConflictsResponse>(
          '/yucai.sync.v1.SyncService/ListConflicts',
          ($0.ListConflictsRequest value) => value.writeToBuffer(),
          $0.ListConflictsResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.sync.v1.SyncService')
abstract class SyncServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.sync.v1.SyncService';

  SyncServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.RegisterDeviceRequest,
            $0.RegisterDeviceResponse>(
        'RegisterDevice',
        registerDevice_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RegisterDeviceRequest.fromBuffer(value),
        ($0.RegisterDeviceResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetSyncStatusRequest, $0.SyncStatusResponse>(
            'GetSyncStatus',
            getSyncStatus_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetSyncStatusRequest.fromBuffer(value),
            ($0.SyncStatusResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.PushChangesRequest, $0.PushResponse>(
        'PushChanges',
        pushChanges_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.PushChangesRequest.fromBuffer(value),
        ($0.PushResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.PullChangesRequest, $0.PullChangesResponse>(
            'PullChanges',
            pullChanges_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.PullChangesRequest.fromBuffer(value),
            ($0.PullChangesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ResolveConflictRequest, $1.Empty>(
        'ResolveConflict',
        resolveConflict_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ResolveConflictRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListConflictsRequest, $0.ListConflictsResponse>(
            'ListConflicts',
            listConflicts_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListConflictsRequest.fromBuffer(value),
            ($0.ListConflictsResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.RegisterDeviceResponse> registerDevice_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RegisterDeviceRequest> $request) async {
    return registerDevice($call, await $request);
  }

  $async.Future<$0.RegisterDeviceResponse> registerDevice(
      $grpc.ServiceCall call, $0.RegisterDeviceRequest request);

  $async.Future<$0.SyncStatusResponse> getSyncStatus_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetSyncStatusRequest> $request) async {
    return getSyncStatus($call, await $request);
  }

  $async.Future<$0.SyncStatusResponse> getSyncStatus(
      $grpc.ServiceCall call, $0.GetSyncStatusRequest request);

  $async.Future<$0.PushResponse> pushChanges_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PushChangesRequest> $request) async {
    return pushChanges($call, await $request);
  }

  $async.Future<$0.PushResponse> pushChanges(
      $grpc.ServiceCall call, $0.PushChangesRequest request);

  $async.Future<$0.PullChangesResponse> pullChanges_Pre($grpc.ServiceCall $call,
      $async.Future<$0.PullChangesRequest> $request) async {
    return pullChanges($call, await $request);
  }

  $async.Future<$0.PullChangesResponse> pullChanges(
      $grpc.ServiceCall call, $0.PullChangesRequest request);

  $async.Future<$1.Empty> resolveConflict_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ResolveConflictRequest> $request) async {
    return resolveConflict($call, await $request);
  }

  $async.Future<$1.Empty> resolveConflict(
      $grpc.ServiceCall call, $0.ResolveConflictRequest request);

  $async.Future<$0.ListConflictsResponse> listConflicts_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListConflictsRequest> $request) async {
    return listConflicts($call, await $request);
  }

  $async.Future<$0.ListConflictsResponse> listConflicts(
      $grpc.ServiceCall call, $0.ListConflictsRequest request);
}
