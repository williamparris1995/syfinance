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

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import 'budget.pb.dart' as $0;

export 'budget.pb.dart';

@$pb.GrpcServiceName('yucai.budget.v1.BudgetService')
class BudgetServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  BudgetServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.BudgetResponse> createBudget(
    $0.CreateBudgetRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createBudget, request, options: options);
  }

  $grpc.ResponseFuture<$0.BudgetDetailResponse> getBudget(
    $0.GetBudgetRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getBudget, request, options: options);
  }

  $grpc.ResponseFuture<$0.BudgetDetailResponse> getBudgetByMonth(
    $0.GetBudgetByMonthRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getBudgetByMonth, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListBudgetsResponse> listBudgets(
    $0.ListBudgetsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listBudgets, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteBudget(
    $0.DeleteBudgetRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteBudget, request, options: options);
  }

  $grpc.ResponseFuture<$0.BudgetResponse> addBudgetItem(
    $0.AddBudgetItemRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addBudgetItem, request, options: options);
  }

  $grpc.ResponseFuture<$0.BudgetResponse> removeBudgetItem(
    $0.RemoveBudgetItemRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$removeBudgetItem, request, options: options);
  }

  $grpc.ResponseFuture<$0.BudgetResponse> computeBudgetActuals(
    $0.ComputeActualsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$computeBudgetActuals, request, options: options);
  }

  $grpc.ResponseFuture<$0.BudgetResponse> cloneBudgetToMonth(
    $0.CloneBudgetRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$cloneBudgetToMonth, request, options: options);
  }

  $grpc.ResponseFuture<$0.BudgetResponse> updateBudget(
    $0.UpdateBudgetRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateBudget, request, options: options);
  }

  // method descriptors

  static final _$createBudget =
      $grpc.ClientMethod<$0.CreateBudgetRequest, $0.BudgetResponse>(
          '/yucai.budget.v1.BudgetService/CreateBudget',
          ($0.CreateBudgetRequest value) => value.writeToBuffer(),
          $0.BudgetResponse.fromBuffer);
  static final _$getBudget =
      $grpc.ClientMethod<$0.GetBudgetRequest, $0.BudgetDetailResponse>(
          '/yucai.budget.v1.BudgetService/GetBudget',
          ($0.GetBudgetRequest value) => value.writeToBuffer(),
          $0.BudgetDetailResponse.fromBuffer);
  static final _$getBudgetByMonth =
      $grpc.ClientMethod<$0.GetBudgetByMonthRequest, $0.BudgetDetailResponse>(
          '/yucai.budget.v1.BudgetService/GetBudgetByMonth',
          ($0.GetBudgetByMonthRequest value) => value.writeToBuffer(),
          $0.BudgetDetailResponse.fromBuffer);
  static final _$listBudgets =
      $grpc.ClientMethod<$0.ListBudgetsRequest, $0.ListBudgetsResponse>(
          '/yucai.budget.v1.BudgetService/ListBudgets',
          ($0.ListBudgetsRequest value) => value.writeToBuffer(),
          $0.ListBudgetsResponse.fromBuffer);
  static final _$deleteBudget =
      $grpc.ClientMethod<$0.DeleteBudgetRequest, $1.Empty>(
          '/yucai.budget.v1.BudgetService/DeleteBudget',
          ($0.DeleteBudgetRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$addBudgetItem =
      $grpc.ClientMethod<$0.AddBudgetItemRequest, $0.BudgetResponse>(
          '/yucai.budget.v1.BudgetService/AddBudgetItem',
          ($0.AddBudgetItemRequest value) => value.writeToBuffer(),
          $0.BudgetResponse.fromBuffer);
  static final _$removeBudgetItem =
      $grpc.ClientMethod<$0.RemoveBudgetItemRequest, $0.BudgetResponse>(
          '/yucai.budget.v1.BudgetService/RemoveBudgetItem',
          ($0.RemoveBudgetItemRequest value) => value.writeToBuffer(),
          $0.BudgetResponse.fromBuffer);
  static final _$computeBudgetActuals =
      $grpc.ClientMethod<$0.ComputeActualsRequest, $0.BudgetResponse>(
          '/yucai.budget.v1.BudgetService/ComputeBudgetActuals',
          ($0.ComputeActualsRequest value) => value.writeToBuffer(),
          $0.BudgetResponse.fromBuffer);
  static final _$cloneBudgetToMonth =
      $grpc.ClientMethod<$0.CloneBudgetRequest, $0.BudgetResponse>(
          '/yucai.budget.v1.BudgetService/CloneBudgetToMonth',
          ($0.CloneBudgetRequest value) => value.writeToBuffer(),
          $0.BudgetResponse.fromBuffer);
  static final _$updateBudget =
      $grpc.ClientMethod<$0.UpdateBudgetRequest, $0.BudgetResponse>(
          '/yucai.budget.v1.BudgetService/UpdateBudget',
          ($0.UpdateBudgetRequest value) => value.writeToBuffer(),
          $0.BudgetResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.budget.v1.BudgetService')
abstract class BudgetServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.budget.v1.BudgetService';

  BudgetServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateBudgetRequest, $0.BudgetResponse>(
        'CreateBudget',
        createBudget_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateBudgetRequest.fromBuffer(value),
        ($0.BudgetResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetBudgetRequest, $0.BudgetDetailResponse>(
            'GetBudget',
            getBudget_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetBudgetRequest.fromBuffer(value),
            ($0.BudgetDetailResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetBudgetByMonthRequest,
            $0.BudgetDetailResponse>(
        'GetBudgetByMonth',
        getBudgetByMonth_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetBudgetByMonthRequest.fromBuffer(value),
        ($0.BudgetDetailResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListBudgetsRequest, $0.ListBudgetsResponse>(
            'ListBudgets',
            listBudgets_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListBudgetsRequest.fromBuffer(value),
            ($0.ListBudgetsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteBudgetRequest, $1.Empty>(
        'DeleteBudget',
        deleteBudget_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteBudgetRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AddBudgetItemRequest, $0.BudgetResponse>(
        'AddBudgetItem',
        addBudgetItem_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AddBudgetItemRequest.fromBuffer(value),
        ($0.BudgetResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RemoveBudgetItemRequest, $0.BudgetResponse>(
            'RemoveBudgetItem',
            removeBudgetItem_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RemoveBudgetItemRequest.fromBuffer(value),
            ($0.BudgetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ComputeActualsRequest, $0.BudgetResponse>(
        'ComputeBudgetActuals',
        computeBudgetActuals_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ComputeActualsRequest.fromBuffer(value),
        ($0.BudgetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.CloneBudgetRequest, $0.BudgetResponse>(
        'CloneBudgetToMonth',
        cloneBudgetToMonth_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CloneBudgetRequest.fromBuffer(value),
        ($0.BudgetResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateBudgetRequest, $0.BudgetResponse>(
        'UpdateBudget',
        updateBudget_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateBudgetRequest.fromBuffer(value),
        ($0.BudgetResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.BudgetResponse> createBudget_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateBudgetRequest> $request) async {
    return createBudget($call, await $request);
  }

  $async.Future<$0.BudgetResponse> createBudget(
      $grpc.ServiceCall call, $0.CreateBudgetRequest request);

  $async.Future<$0.BudgetDetailResponse> getBudget_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetBudgetRequest> $request) async {
    return getBudget($call, await $request);
  }

  $async.Future<$0.BudgetDetailResponse> getBudget(
      $grpc.ServiceCall call, $0.GetBudgetRequest request);

  $async.Future<$0.BudgetDetailResponse> getBudgetByMonth_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetBudgetByMonthRequest> $request) async {
    return getBudgetByMonth($call, await $request);
  }

  $async.Future<$0.BudgetDetailResponse> getBudgetByMonth(
      $grpc.ServiceCall call, $0.GetBudgetByMonthRequest request);

  $async.Future<$0.ListBudgetsResponse> listBudgets_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListBudgetsRequest> $request) async {
    return listBudgets($call, await $request);
  }

  $async.Future<$0.ListBudgetsResponse> listBudgets(
      $grpc.ServiceCall call, $0.ListBudgetsRequest request);

  $async.Future<$1.Empty> deleteBudget_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteBudgetRequest> $request) async {
    return deleteBudget($call, await $request);
  }

  $async.Future<$1.Empty> deleteBudget(
      $grpc.ServiceCall call, $0.DeleteBudgetRequest request);

  $async.Future<$0.BudgetResponse> addBudgetItem_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AddBudgetItemRequest> $request) async {
    return addBudgetItem($call, await $request);
  }

  $async.Future<$0.BudgetResponse> addBudgetItem(
      $grpc.ServiceCall call, $0.AddBudgetItemRequest request);

  $async.Future<$0.BudgetResponse> removeBudgetItem_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RemoveBudgetItemRequest> $request) async {
    return removeBudgetItem($call, await $request);
  }

  $async.Future<$0.BudgetResponse> removeBudgetItem(
      $grpc.ServiceCall call, $0.RemoveBudgetItemRequest request);

  $async.Future<$0.BudgetResponse> computeBudgetActuals_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ComputeActualsRequest> $request) async {
    return computeBudgetActuals($call, await $request);
  }

  $async.Future<$0.BudgetResponse> computeBudgetActuals(
      $grpc.ServiceCall call, $0.ComputeActualsRequest request);

  $async.Future<$0.BudgetResponse> cloneBudgetToMonth_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CloneBudgetRequest> $request) async {
    return cloneBudgetToMonth($call, await $request);
  }

  $async.Future<$0.BudgetResponse> cloneBudgetToMonth(
      $grpc.ServiceCall call, $0.CloneBudgetRequest request);

  $async.Future<$0.BudgetResponse> updateBudget_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateBudgetRequest> $request) async {
    return updateBudget($call, await $request);
  }

  $async.Future<$0.BudgetResponse> updateBudget(
      $grpc.ServiceCall call, $0.UpdateBudgetRequest request);
}
