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

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;

import 'sync.pb.dart' as $3;
import 'sync.pbjson.dart';

export 'sync.pb.dart';

abstract class SyncServiceBase extends $pb.GeneratedService {
  $async.Future<$3.RegisterDeviceResponse> registerDevice(
      $pb.ServerContext ctx, $3.RegisterDeviceRequest request);
  $async.Future<$3.SyncStatusResponse> getSyncStatus(
      $pb.ServerContext ctx, $3.GetSyncStatusRequest request);
  $async.Future<$3.PushResponse> pushChanges(
      $pb.ServerContext ctx, $3.PushChangesRequest request);
  $async.Future<$3.PullChangesResponse> pullChanges(
      $pb.ServerContext ctx, $3.PullChangesRequest request);
  $async.Future<$2.Empty> resolveConflict(
      $pb.ServerContext ctx, $3.ResolveConflictRequest request);
  $async.Future<$3.ListConflictsResponse> listConflicts(
      $pb.ServerContext ctx, $3.ListConflictsRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'RegisterDevice':
        return $3.RegisterDeviceRequest();
      case 'GetSyncStatus':
        return $3.GetSyncStatusRequest();
      case 'PushChanges':
        return $3.PushChangesRequest();
      case 'PullChanges':
        return $3.PullChangesRequest();
      case 'ResolveConflict':
        return $3.ResolveConflictRequest();
      case 'ListConflicts':
        return $3.ListConflictsRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'RegisterDevice':
        return registerDevice(ctx, request as $3.RegisterDeviceRequest);
      case 'GetSyncStatus':
        return getSyncStatus(ctx, request as $3.GetSyncStatusRequest);
      case 'PushChanges':
        return pushChanges(ctx, request as $3.PushChangesRequest);
      case 'PullChanges':
        return pullChanges(ctx, request as $3.PullChangesRequest);
      case 'ResolveConflict':
        return resolveConflict(ctx, request as $3.ResolveConflictRequest);
      case 'ListConflicts':
        return listConflicts(ctx, request as $3.ListConflictsRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => SyncServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => SyncServiceBase$messageJson;
}
