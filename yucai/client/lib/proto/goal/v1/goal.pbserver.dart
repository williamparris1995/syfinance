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

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;

import 'goal.pb.dart' as $3;
import 'goal.pbjson.dart';

export 'goal.pb.dart';

abstract class GoalServiceBase extends $pb.GeneratedService {
  $async.Future<$3.GoalResponse> createGoal(
      $pb.ServerContext ctx, $3.CreateGoalRequest request);
  $async.Future<$3.GoalResponse> updateGoal(
      $pb.ServerContext ctx, $3.UpdateGoalRequest request);
  $async.Future<$3.GoalResponse> updateGoalProgress(
      $pb.ServerContext ctx, $3.UpdateProgressRequest request);
  $async.Future<$2.Empty> completeGoal(
      $pb.ServerContext ctx, $3.CompleteGoalRequest request);
  $async.Future<$2.Empty> deleteGoal(
      $pb.ServerContext ctx, $3.DeleteGoalRequest request);
  $async.Future<$3.GoalResponse> syncGoalProgress(
      $pb.ServerContext ctx, $3.SyncGoalProgressRequest request);
  $async.Future<$3.GoalDetailResponse> getGoal(
      $pb.ServerContext ctx, $3.GetGoalRequest request);
  $async.Future<$3.ListGoalsResponse> listGoals(
      $pb.ServerContext ctx, $3.ListGoalsRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'CreateGoal':
        return $3.CreateGoalRequest();
      case 'UpdateGoal':
        return $3.UpdateGoalRequest();
      case 'UpdateGoalProgress':
        return $3.UpdateProgressRequest();
      case 'CompleteGoal':
        return $3.CompleteGoalRequest();
      case 'DeleteGoal':
        return $3.DeleteGoalRequest();
      case 'SyncGoalProgress':
        return $3.SyncGoalProgressRequest();
      case 'GetGoal':
        return $3.GetGoalRequest();
      case 'ListGoals':
        return $3.ListGoalsRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'CreateGoal':
        return createGoal(ctx, request as $3.CreateGoalRequest);
      case 'UpdateGoal':
        return updateGoal(ctx, request as $3.UpdateGoalRequest);
      case 'UpdateGoalProgress':
        return updateGoalProgress(ctx, request as $3.UpdateProgressRequest);
      case 'CompleteGoal':
        return completeGoal(ctx, request as $3.CompleteGoalRequest);
      case 'DeleteGoal':
        return deleteGoal(ctx, request as $3.DeleteGoalRequest);
      case 'SyncGoalProgress':
        return syncGoalProgress(ctx, request as $3.SyncGoalProgressRequest);
      case 'GetGoal':
        return getGoal(ctx, request as $3.GetGoalRequest);
      case 'ListGoals':
        return listGoals(ctx, request as $3.ListGoalsRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => GoalServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => GoalServiceBase$messageJson;
}
