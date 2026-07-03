// This is a generated file - do not edit.
//
// Generated from debt/v1/debt.proto.

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

import 'debt.pb.dart' as $0;

export 'debt.pb.dart';

@$pb.GrpcServiceName('yucai.debt.v1.DebtService')
class DebtServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  DebtServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.DebtResponse> createDebt(
    $0.CreateDebtRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createDebt, request, options: options);
  }

  $grpc.ResponseFuture<$0.DebtResponse> updateDebt(
    $0.UpdateDebtRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateDebt, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteDebt(
    $0.DeleteDebtRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteDebt, request, options: options);
  }

  $grpc.ResponseFuture<$0.RecordPaymentResponse> recordPayment(
    $0.RecordPaymentRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$recordPayment, request, options: options);
  }

  $grpc.ResponseFuture<$0.DebtDetailResponse> getDebt(
    $0.GetDebtRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getDebt, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListDebtsResponse> listDebts(
    $0.ListDebtsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listDebts, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListDebtsResponse> getUpcomingPayments(
    $0.GetUpcomingPaymentsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getUpcomingPayments, request, options: options);
  }

  $grpc.ResponseFuture<$0.ReceivablesSummaryResponse> getReceivablesSummary(
    $0.GetReceivablesSummaryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getReceivablesSummary, request, options: options);
  }

  // method descriptors

  static final _$createDebt =
      $grpc.ClientMethod<$0.CreateDebtRequest, $0.DebtResponse>(
          '/yucai.debt.v1.DebtService/CreateDebt',
          ($0.CreateDebtRequest value) => value.writeToBuffer(),
          $0.DebtResponse.fromBuffer);
  static final _$updateDebt =
      $grpc.ClientMethod<$0.UpdateDebtRequest, $0.DebtResponse>(
          '/yucai.debt.v1.DebtService/UpdateDebt',
          ($0.UpdateDebtRequest value) => value.writeToBuffer(),
          $0.DebtResponse.fromBuffer);
  static final _$deleteDebt =
      $grpc.ClientMethod<$0.DeleteDebtRequest, $1.Empty>(
          '/yucai.debt.v1.DebtService/DeleteDebt',
          ($0.DeleteDebtRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$recordPayment =
      $grpc.ClientMethod<$0.RecordPaymentRequest, $0.RecordPaymentResponse>(
          '/yucai.debt.v1.DebtService/RecordPayment',
          ($0.RecordPaymentRequest value) => value.writeToBuffer(),
          $0.RecordPaymentResponse.fromBuffer);
  static final _$getDebt =
      $grpc.ClientMethod<$0.GetDebtRequest, $0.DebtDetailResponse>(
          '/yucai.debt.v1.DebtService/GetDebt',
          ($0.GetDebtRequest value) => value.writeToBuffer(),
          $0.DebtDetailResponse.fromBuffer);
  static final _$listDebts =
      $grpc.ClientMethod<$0.ListDebtsRequest, $0.ListDebtsResponse>(
          '/yucai.debt.v1.DebtService/ListDebts',
          ($0.ListDebtsRequest value) => value.writeToBuffer(),
          $0.ListDebtsResponse.fromBuffer);
  static final _$getUpcomingPayments =
      $grpc.ClientMethod<$0.GetUpcomingPaymentsRequest, $0.ListDebtsResponse>(
          '/yucai.debt.v1.DebtService/GetUpcomingPayments',
          ($0.GetUpcomingPaymentsRequest value) => value.writeToBuffer(),
          $0.ListDebtsResponse.fromBuffer);
  static final _$getReceivablesSummary = $grpc.ClientMethod<
          $0.GetReceivablesSummaryRequest, $0.ReceivablesSummaryResponse>(
      '/yucai.debt.v1.DebtService/GetReceivablesSummary',
      ($0.GetReceivablesSummaryRequest value) => value.writeToBuffer(),
      $0.ReceivablesSummaryResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.debt.v1.DebtService')
abstract class DebtServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.debt.v1.DebtService';

  DebtServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateDebtRequest, $0.DebtResponse>(
        'CreateDebt',
        createDebt_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateDebtRequest.fromBuffer(value),
        ($0.DebtResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateDebtRequest, $0.DebtResponse>(
        'UpdateDebt',
        updateDebt_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateDebtRequest.fromBuffer(value),
        ($0.DebtResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteDebtRequest, $1.Empty>(
        'DeleteDebt',
        deleteDebt_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DeleteDebtRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.RecordPaymentRequest, $0.RecordPaymentResponse>(
            'RecordPayment',
            recordPayment_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.RecordPaymentRequest.fromBuffer(value),
            ($0.RecordPaymentResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetDebtRequest, $0.DebtDetailResponse>(
        'GetDebt',
        getDebt_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetDebtRequest.fromBuffer(value),
        ($0.DebtDetailResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListDebtsRequest, $0.ListDebtsResponse>(
        'ListDebts',
        listDebts_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListDebtsRequest.fromBuffer(value),
        ($0.ListDebtsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetUpcomingPaymentsRequest,
            $0.ListDebtsResponse>(
        'GetUpcomingPayments',
        getUpcomingPayments_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetUpcomingPaymentsRequest.fromBuffer(value),
        ($0.ListDebtsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetReceivablesSummaryRequest,
            $0.ReceivablesSummaryResponse>(
        'GetReceivablesSummary',
        getReceivablesSummary_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetReceivablesSummaryRequest.fromBuffer(value),
        ($0.ReceivablesSummaryResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.DebtResponse> createDebt_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateDebtRequest> $request) async {
    return createDebt($call, await $request);
  }

  $async.Future<$0.DebtResponse> createDebt(
      $grpc.ServiceCall call, $0.CreateDebtRequest request);

  $async.Future<$0.DebtResponse> updateDebt_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateDebtRequest> $request) async {
    return updateDebt($call, await $request);
  }

  $async.Future<$0.DebtResponse> updateDebt(
      $grpc.ServiceCall call, $0.UpdateDebtRequest request);

  $async.Future<$1.Empty> deleteDebt_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteDebtRequest> $request) async {
    return deleteDebt($call, await $request);
  }

  $async.Future<$1.Empty> deleteDebt(
      $grpc.ServiceCall call, $0.DeleteDebtRequest request);

  $async.Future<$0.RecordPaymentResponse> recordPayment_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RecordPaymentRequest> $request) async {
    return recordPayment($call, await $request);
  }

  $async.Future<$0.RecordPaymentResponse> recordPayment(
      $grpc.ServiceCall call, $0.RecordPaymentRequest request);

  $async.Future<$0.DebtDetailResponse> getDebt_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetDebtRequest> $request) async {
    return getDebt($call, await $request);
  }

  $async.Future<$0.DebtDetailResponse> getDebt(
      $grpc.ServiceCall call, $0.GetDebtRequest request);

  $async.Future<$0.ListDebtsResponse> listDebts_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListDebtsRequest> $request) async {
    return listDebts($call, await $request);
  }

  $async.Future<$0.ListDebtsResponse> listDebts(
      $grpc.ServiceCall call, $0.ListDebtsRequest request);

  $async.Future<$0.ListDebtsResponse> getUpcomingPayments_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetUpcomingPaymentsRequest> $request) async {
    return getUpcomingPayments($call, await $request);
  }

  $async.Future<$0.ListDebtsResponse> getUpcomingPayments(
      $grpc.ServiceCall call, $0.GetUpcomingPaymentsRequest request);

  $async.Future<$0.ReceivablesSummaryResponse> getReceivablesSummary_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetReceivablesSummaryRequest> $request) async {
    return getReceivablesSummary($call, await $request);
  }

  $async.Future<$0.ReceivablesSummaryResponse> getReceivablesSummary(
      $grpc.ServiceCall call, $0.GetReceivablesSummaryRequest request);
}
