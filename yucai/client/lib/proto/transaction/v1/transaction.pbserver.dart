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

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;

import 'transaction.pb.dart' as $3;
import 'transaction.pbjson.dart';

export 'transaction.pb.dart';

abstract class TransactionServiceBase extends $pb.GeneratedService {
  $async.Future<$3.TransactionResponse> recordTransaction(
      $pb.ServerContext ctx, $3.RecordTransactionRequest request);
  $async.Future<$3.TransactionResponse> getTransaction(
      $pb.ServerContext ctx, $3.GetTransactionRequest request);
  $async.Future<$3.ListTransactionsResponse> listTransactions(
      $pb.ServerContext ctx, $3.ListTransactionsRequest request);
  $async.Future<$3.TransactionResponse> updateTransaction(
      $pb.ServerContext ctx, $3.UpdateTransactionRequest request);
  $async.Future<$2.Empty> deleteTransaction(
      $pb.ServerContext ctx, $3.DeleteTransactionRequest request);
  $async.Future<$3.TransactionResponse> simpleIncome(
      $pb.ServerContext ctx, $3.SimpleIncomeRequest request);
  $async.Future<$3.TransactionResponse> simpleExpense(
      $pb.ServerContext ctx, $3.SimpleExpenseRequest request);
  $async.Future<$3.TransactionResponse> simpleTransfer(
      $pb.ServerContext ctx, $3.SimpleTransferRequest request);
  $async.Future<$3.TransactionSummaryResponse> transactionSummary(
      $pb.ServerContext ctx, $3.TransactionSummaryRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'RecordTransaction':
        return $3.RecordTransactionRequest();
      case 'GetTransaction':
        return $3.GetTransactionRequest();
      case 'ListTransactions':
        return $3.ListTransactionsRequest();
      case 'UpdateTransaction':
        return $3.UpdateTransactionRequest();
      case 'DeleteTransaction':
        return $3.DeleteTransactionRequest();
      case 'SimpleIncome':
        return $3.SimpleIncomeRequest();
      case 'SimpleExpense':
        return $3.SimpleExpenseRequest();
      case 'SimpleTransfer':
        return $3.SimpleTransferRequest();
      case 'TransactionSummary':
        return $3.TransactionSummaryRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'RecordTransaction':
        return recordTransaction(ctx, request as $3.RecordTransactionRequest);
      case 'GetTransaction':
        return getTransaction(ctx, request as $3.GetTransactionRequest);
      case 'ListTransactions':
        return listTransactions(ctx, request as $3.ListTransactionsRequest);
      case 'UpdateTransaction':
        return updateTransaction(ctx, request as $3.UpdateTransactionRequest);
      case 'DeleteTransaction':
        return deleteTransaction(ctx, request as $3.DeleteTransactionRequest);
      case 'SimpleIncome':
        return simpleIncome(ctx, request as $3.SimpleIncomeRequest);
      case 'SimpleExpense':
        return simpleExpense(ctx, request as $3.SimpleExpenseRequest);
      case 'SimpleTransfer':
        return simpleTransfer(ctx, request as $3.SimpleTransferRequest);
      case 'TransactionSummary':
        return transactionSummary(ctx, request as $3.TransactionSummaryRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json =>
      TransactionServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => TransactionServiceBase$messageJson;
}
