// This is a generated file - do not edit.
//
// Generated from transaction/v1/transaction.proto.

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

import 'transaction.pb.dart' as $0;

export 'transaction.pb.dart';

/// TransactionService manages double-entry bookkeeping transactions.
@$pb.GrpcServiceName('yucai.transaction.v1.TransactionService')
class TransactionServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  TransactionServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.TransactionResponse> recordTransaction(
    $0.RecordTransactionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$recordTransaction, request, options: options);
  }

  $grpc.ResponseFuture<$0.TransactionResponse> getTransaction(
    $0.GetTransactionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getTransaction, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListTransactionsResponse> listTransactions(
    $0.ListTransactionsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listTransactions, request, options: options);
  }

  $grpc.ResponseFuture<$0.TransactionResponse> updateTransaction(
    $0.UpdateTransactionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateTransaction, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteTransaction(
    $0.DeleteTransactionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteTransaction, request, options: options);
  }

  $grpc.ResponseFuture<$0.TransactionResponse> simpleIncome(
    $0.SimpleIncomeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$simpleIncome, request, options: options);
  }

  $grpc.ResponseFuture<$0.TransactionResponse> simpleExpense(
    $0.SimpleExpenseRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$simpleExpense, request, options: options);
  }

  $grpc.ResponseFuture<$0.TransactionResponse> simpleTransfer(
    $0.SimpleTransferRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$simpleTransfer, request, options: options);
  }

  // method descriptors

  static final _$recordTransaction =
      $grpc.ClientMethod<$0.RecordTransactionRequest, $0.TransactionResponse>(
          '/yucai.transaction.v1.TransactionService/RecordTransaction',
          ($0.RecordTransactionRequest value) => value.writeToBuffer(),
          $0.TransactionResponse.fromBuffer);
  static final _$getTransaction =
      $grpc.ClientMethod<$0.GetTransactionRequest, $0.TransactionResponse>(
          '/yucai.transaction.v1.TransactionService/GetTransaction',
          ($0.GetTransactionRequest value) => value.writeToBuffer(),
          $0.TransactionResponse.fromBuffer);
  static final _$listTransactions = $grpc.ClientMethod<
          $0.ListTransactionsRequest, $0.ListTransactionsResponse>(
      '/yucai.transaction.v1.TransactionService/ListTransactions',
      ($0.ListTransactionsRequest value) => value.writeToBuffer(),
      $0.ListTransactionsResponse.fromBuffer);
  static final _$updateTransaction =
      $grpc.ClientMethod<$0.UpdateTransactionRequest, $0.TransactionResponse>(
          '/yucai.transaction.v1.TransactionService/UpdateTransaction',
          ($0.UpdateTransactionRequest value) => value.writeToBuffer(),
          $0.TransactionResponse.fromBuffer);
  static final _$deleteTransaction =
      $grpc.ClientMethod<$0.DeleteTransactionRequest, $1.Empty>(
          '/yucai.transaction.v1.TransactionService/DeleteTransaction',
          ($0.DeleteTransactionRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$simpleIncome =
      $grpc.ClientMethod<$0.SimpleIncomeRequest, $0.TransactionResponse>(
          '/yucai.transaction.v1.TransactionService/SimpleIncome',
          ($0.SimpleIncomeRequest value) => value.writeToBuffer(),
          $0.TransactionResponse.fromBuffer);
  static final _$simpleExpense =
      $grpc.ClientMethod<$0.SimpleExpenseRequest, $0.TransactionResponse>(
          '/yucai.transaction.v1.TransactionService/SimpleExpense',
          ($0.SimpleExpenseRequest value) => value.writeToBuffer(),
          $0.TransactionResponse.fromBuffer);
  static final _$simpleTransfer =
      $grpc.ClientMethod<$0.SimpleTransferRequest, $0.TransactionResponse>(
          '/yucai.transaction.v1.TransactionService/SimpleTransfer',
          ($0.SimpleTransferRequest value) => value.writeToBuffer(),
          $0.TransactionResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.transaction.v1.TransactionService')
abstract class TransactionServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.transaction.v1.TransactionService';

  TransactionServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.RecordTransactionRequest,
            $0.TransactionResponse>(
        'RecordTransaction',
        recordTransaction_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RecordTransactionRequest.fromBuffer(value),
        ($0.TransactionResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetTransactionRequest, $0.TransactionResponse>(
            'GetTransaction',
            getTransaction_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetTransactionRequest.fromBuffer(value),
            ($0.TransactionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListTransactionsRequest,
            $0.ListTransactionsResponse>(
        'ListTransactions',
        listTransactions_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListTransactionsRequest.fromBuffer(value),
        ($0.ListTransactionsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateTransactionRequest,
            $0.TransactionResponse>(
        'UpdateTransaction',
        updateTransaction_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateTransactionRequest.fromBuffer(value),
        ($0.TransactionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteTransactionRequest, $1.Empty>(
        'DeleteTransaction',
        deleteTransaction_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteTransactionRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SimpleIncomeRequest, $0.TransactionResponse>(
            'SimpleIncome',
            simpleIncome_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SimpleIncomeRequest.fromBuffer(value),
            ($0.TransactionResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SimpleExpenseRequest, $0.TransactionResponse>(
            'SimpleExpense',
            simpleExpense_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SimpleExpenseRequest.fromBuffer(value),
            ($0.TransactionResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.SimpleTransferRequest, $0.TransactionResponse>(
            'SimpleTransfer',
            simpleTransfer_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.SimpleTransferRequest.fromBuffer(value),
            ($0.TransactionResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.TransactionResponse> recordTransaction_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RecordTransactionRequest> $request) async {
    return recordTransaction($call, await $request);
  }

  $async.Future<$0.TransactionResponse> recordTransaction(
      $grpc.ServiceCall call, $0.RecordTransactionRequest request);

  $async.Future<$0.TransactionResponse> getTransaction_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetTransactionRequest> $request) async {
    return getTransaction($call, await $request);
  }

  $async.Future<$0.TransactionResponse> getTransaction(
      $grpc.ServiceCall call, $0.GetTransactionRequest request);

  $async.Future<$0.ListTransactionsResponse> listTransactions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListTransactionsRequest> $request) async {
    return listTransactions($call, await $request);
  }

  $async.Future<$0.ListTransactionsResponse> listTransactions(
      $grpc.ServiceCall call, $0.ListTransactionsRequest request);

  $async.Future<$0.TransactionResponse> updateTransaction_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateTransactionRequest> $request) async {
    return updateTransaction($call, await $request);
  }

  $async.Future<$0.TransactionResponse> updateTransaction(
      $grpc.ServiceCall call, $0.UpdateTransactionRequest request);

  $async.Future<$1.Empty> deleteTransaction_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteTransactionRequest> $request) async {
    return deleteTransaction($call, await $request);
  }

  $async.Future<$1.Empty> deleteTransaction(
      $grpc.ServiceCall call, $0.DeleteTransactionRequest request);

  $async.Future<$0.TransactionResponse> simpleIncome_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SimpleIncomeRequest> $request) async {
    return simpleIncome($call, await $request);
  }

  $async.Future<$0.TransactionResponse> simpleIncome(
      $grpc.ServiceCall call, $0.SimpleIncomeRequest request);

  $async.Future<$0.TransactionResponse> simpleExpense_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SimpleExpenseRequest> $request) async {
    return simpleExpense($call, await $request);
  }

  $async.Future<$0.TransactionResponse> simpleExpense(
      $grpc.ServiceCall call, $0.SimpleExpenseRequest request);

  $async.Future<$0.TransactionResponse> simpleTransfer_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SimpleTransferRequest> $request) async {
    return simpleTransfer($call, await $request);
  }

  $async.Future<$0.TransactionResponse> simpleTransfer(
      $grpc.ServiceCall call, $0.SimpleTransferRequest request);
}
