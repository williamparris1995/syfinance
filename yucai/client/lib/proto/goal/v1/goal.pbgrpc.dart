// This is a generated file - do not edit.
//
// Generated from goal/v1/goal.proto.

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

import 'goal.pb.dart' as $0;

export 'goal.pb.dart';

@$pb.GrpcServiceName('yucai.goal.v1.GoalService')
class GoalServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  GoalServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.GoalResponse> createGoal(
    $0.CreateGoalRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createGoal, request, options: options);
  }

  $grpc.ResponseFuture<$0.GoalResponse> updateGoal(
    $0.UpdateGoalRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateGoal, request, options: options);
  }

  $grpc.ResponseFuture<$0.GoalResponse> updateGoalProgress(
    $0.UpdateProgressRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateGoalProgress, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> completeGoal(
    $0.CompleteGoalRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$completeGoal, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteGoal(
    $0.DeleteGoalRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteGoal, request, options: options);
  }

  $grpc.ResponseFuture<$0.GoalResponse> syncGoalProgress(
    $0.SyncGoalProgressRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$syncGoalProgress, request, options: options);
  }

  $grpc.ResponseFuture<$0.GoalDetailResponse> getGoal(
    $0.GetGoalRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getGoal, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListGoalsResponse> listGoals(
    $0.ListGoalsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listGoals, request, options: options);
  }

  $grpc.ResponseFuture<$0.SyncInvestmentGoalsResponse> syncInvestmentGoals(
    $0.SyncInvestmentGoalsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$syncInvestmentGoals, request, options: options);
  }

  // method descriptors

  static final _$createGoal =
      $grpc.ClientMethod<$0.CreateGoalRequest, $0.GoalResponse>(
          '/yucai.goal.v1.GoalService/CreateGoal',
          ($0.CreateGoalRequest value) => value.writeToBuffer(),
          $0.GoalResponse.fromBuffer);
  static final _$updateGoal =
      $grpc.ClientMethod<$0.UpdateGoalRequest, $0.GoalResponse>(
          '/yucai.goal.v1.GoalService/UpdateGoal',
          ($0.UpdateGoalRequest value) => value.writeToBuffer(),
          $0.GoalResponse.fromBuffer);
  static final _$updateGoalProgress =
      $grpc.ClientMethod<$0.UpdateProgressRequest, $0.GoalResponse>(
          '/yucai.goal.v1.GoalService/UpdateGoalProgress',
          ($0.UpdateProgressRequest value) => value.writeToBuffer(),
          $0.GoalResponse.fromBuffer);
  static final _$completeGoal =
      $grpc.ClientMethod<$0.CompleteGoalRequest, $1.Empty>(
          '/yucai.goal.v1.GoalService/CompleteGoal',
          ($0.CompleteGoalRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$deleteGoal =
      $grpc.ClientMethod<$0.DeleteGoalRequest, $1.Empty>(
          '/yucai.goal.v1.GoalService/DeleteGoal',
          ($0.DeleteGoalRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$syncGoalProgress =
      $grpc.ClientMethod<$0.SyncGoalProgressRequest, $0.GoalResponse>(
          '/yucai.goal.v1.GoalService/SyncGoalProgress',
          ($0.SyncGoalProgressRequest value) => value.writeToBuffer(),
          $0.GoalResponse.fromBuffer);
  static final _$getGoal =
      $grpc.ClientMethod<$0.GetGoalRequest, $0.GoalDetailResponse>(
          '/yucai.goal.v1.GoalService/GetGoal',
          ($0.GetGoalRequest value) => value.writeToBuffer(),
          $0.GoalDetailResponse.fromBuffer);
  static final _$listGoals =
      $grpc.ClientMethod<$0.ListGoalsRequest, $0.ListGoalsResponse>(
          '/yucai.goal.v1.GoalService/ListGoals',
          ($0.ListGoalsRequest value) => value.writeToBuffer(),
          $0.ListGoalsResponse.fromBuffer);
  static final _$syncInvestmentGoals = $grpc.ClientMethod<
          $0.SyncInvestmentGoalsRequest, $0.SyncInvestmentGoalsResponse>(
      '/yucai.goal.v1.GoalService/SyncInvestmentGoals',
      ($0.SyncInvestmentGoalsRequest value) => value.writeToBuffer(),
      $0.SyncInvestmentGoalsResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.goal.v1.GoalService')
abstract class GoalServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.goal.v1.GoalService';

  GoalServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateGoalRequest, $0.GoalResponse>(
        'CreateGoal',
        createGoal_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateGoalRequest.fromBuffer(value),
        ($0.GoalResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateGoalRequest, $0.GoalResponse>(
        'UpdateGoal',
        updateGoal_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateGoalRequest.fromBuffer(value),
        ($0.GoalResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateProgressRequest, $0.GoalResponse>(
        'UpdateGoalProgress',
        updateGoalProgress_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateProgressRequest.fromBuffer(value),
        ($0.GoalResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CompleteGoalRequest, $1.Empty>(
        'CompleteGoal',
        completeGoal_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CompleteGoalRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteGoalRequest, $1.Empty>(
        'DeleteGoal',
        deleteGoal_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DeleteGoalRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SyncGoalProgressRequest, $0.GoalResponse>(
        'SyncGoalProgress',
        syncGoalProgress_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SyncGoalProgressRequest.fromBuffer(value),
        ($0.GoalResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetGoalRequest, $0.GoalDetailResponse>(
        'GetGoal',
        getGoal_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetGoalRequest.fromBuffer(value),
        ($0.GoalDetailResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListGoalsRequest, $0.ListGoalsResponse>(
        'ListGoals',
        listGoals_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListGoalsRequest.fromBuffer(value),
        ($0.ListGoalsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SyncInvestmentGoalsRequest,
            $0.SyncInvestmentGoalsResponse>(
        'SyncInvestmentGoals',
        syncInvestmentGoals_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SyncInvestmentGoalsRequest.fromBuffer(value),
        ($0.SyncInvestmentGoalsResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.GoalResponse> createGoal_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateGoalRequest> $request) async {
    return createGoal($call, await $request);
  }

  $async.Future<$0.GoalResponse> createGoal(
      $grpc.ServiceCall call, $0.CreateGoalRequest request);

  $async.Future<$0.GoalResponse> updateGoal_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateGoalRequest> $request) async {
    return updateGoal($call, await $request);
  }

  $async.Future<$0.GoalResponse> updateGoal(
      $grpc.ServiceCall call, $0.UpdateGoalRequest request);

  $async.Future<$0.GoalResponse> updateGoalProgress_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateProgressRequest> $request) async {
    return updateGoalProgress($call, await $request);
  }

  $async.Future<$0.GoalResponse> updateGoalProgress(
      $grpc.ServiceCall call, $0.UpdateProgressRequest request);

  $async.Future<$1.Empty> completeGoal_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CompleteGoalRequest> $request) async {
    return completeGoal($call, await $request);
  }

  $async.Future<$1.Empty> completeGoal(
      $grpc.ServiceCall call, $0.CompleteGoalRequest request);

  $async.Future<$1.Empty> deleteGoal_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteGoalRequest> $request) async {
    return deleteGoal($call, await $request);
  }

  $async.Future<$1.Empty> deleteGoal(
      $grpc.ServiceCall call, $0.DeleteGoalRequest request);

  $async.Future<$0.GoalResponse> syncGoalProgress_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SyncGoalProgressRequest> $request) async {
    return syncGoalProgress($call, await $request);
  }

  $async.Future<$0.GoalResponse> syncGoalProgress(
      $grpc.ServiceCall call, $0.SyncGoalProgressRequest request);

  $async.Future<$0.GoalDetailResponse> getGoal_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetGoalRequest> $request) async {
    return getGoal($call, await $request);
  }

  $async.Future<$0.GoalDetailResponse> getGoal(
      $grpc.ServiceCall call, $0.GetGoalRequest request);

  $async.Future<$0.ListGoalsResponse> listGoals_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListGoalsRequest> $request) async {
    return listGoals($call, await $request);
  }

  $async.Future<$0.ListGoalsResponse> listGoals(
      $grpc.ServiceCall call, $0.ListGoalsRequest request);

  $async.Future<$0.SyncInvestmentGoalsResponse> syncInvestmentGoals_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SyncInvestmentGoalsRequest> $request) async {
    return syncInvestmentGoals($call, await $request);
  }

  $async.Future<$0.SyncInvestmentGoalsResponse> syncInvestmentGoals(
      $grpc.ServiceCall call, $0.SyncInvestmentGoalsRequest request);
}
