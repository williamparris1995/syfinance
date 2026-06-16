// This is a generated file - do not edit.
//
// Generated from budget/v1/budget.proto.

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

import 'budget.pb.dart' as $3;
import 'budget.pbjson.dart';

export 'budget.pb.dart';

abstract class BudgetServiceBase extends $pb.GeneratedService {
  $async.Future<$3.BudgetResponse> createBudget(
      $pb.ServerContext ctx, $3.CreateBudgetRequest request);
  $async.Future<$3.BudgetDetailResponse> getBudget(
      $pb.ServerContext ctx, $3.GetBudgetRequest request);
  $async.Future<$3.BudgetDetailResponse> getBudgetByMonth(
      $pb.ServerContext ctx, $3.GetBudgetByMonthRequest request);
  $async.Future<$3.ListBudgetsResponse> listBudgets(
      $pb.ServerContext ctx, $3.ListBudgetsRequest request);
  $async.Future<$2.Empty> deleteBudget(
      $pb.ServerContext ctx, $3.DeleteBudgetRequest request);
  $async.Future<$3.BudgetResponse> addBudgetItem(
      $pb.ServerContext ctx, $3.AddBudgetItemRequest request);
  $async.Future<$3.BudgetResponse> removeBudgetItem(
      $pb.ServerContext ctx, $3.RemoveBudgetItemRequest request);
  $async.Future<$3.BudgetResponse> computeBudgetActuals(
      $pb.ServerContext ctx, $3.ComputeActualsRequest request);
  $async.Future<$3.BudgetResponse> cloneBudgetToMonth(
      $pb.ServerContext ctx, $3.CloneBudgetRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'CreateBudget':
        return $3.CreateBudgetRequest();
      case 'GetBudget':
        return $3.GetBudgetRequest();
      case 'GetBudgetByMonth':
        return $3.GetBudgetByMonthRequest();
      case 'ListBudgets':
        return $3.ListBudgetsRequest();
      case 'DeleteBudget':
        return $3.DeleteBudgetRequest();
      case 'AddBudgetItem':
        return $3.AddBudgetItemRequest();
      case 'RemoveBudgetItem':
        return $3.RemoveBudgetItemRequest();
      case 'ComputeBudgetActuals':
        return $3.ComputeActualsRequest();
      case 'CloneBudgetToMonth':
        return $3.CloneBudgetRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'CreateBudget':
        return createBudget(ctx, request as $3.CreateBudgetRequest);
      case 'GetBudget':
        return getBudget(ctx, request as $3.GetBudgetRequest);
      case 'GetBudgetByMonth':
        return getBudgetByMonth(ctx, request as $3.GetBudgetByMonthRequest);
      case 'ListBudgets':
        return listBudgets(ctx, request as $3.ListBudgetsRequest);
      case 'DeleteBudget':
        return deleteBudget(ctx, request as $3.DeleteBudgetRequest);
      case 'AddBudgetItem':
        return addBudgetItem(ctx, request as $3.AddBudgetItemRequest);
      case 'RemoveBudgetItem':
        return removeBudgetItem(ctx, request as $3.RemoveBudgetItemRequest);
      case 'ComputeBudgetActuals':
        return computeBudgetActuals(ctx, request as $3.ComputeActualsRequest);
      case 'CloneBudgetToMonth':
        return cloneBudgetToMonth(ctx, request as $3.CloneBudgetRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => BudgetServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => BudgetServiceBase$messageJson;
}
