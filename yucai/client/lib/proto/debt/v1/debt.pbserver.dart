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

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;

import 'debt.pb.dart' as $3;
import 'debt.pbjson.dart';

export 'debt.pb.dart';

abstract class DebtServiceBase extends $pb.GeneratedService {
  $async.Future<$3.DebtResponse> createDebt(
      $pb.ServerContext ctx, $3.CreateDebtRequest request);
  $async.Future<$3.DebtResponse> updateDebt(
      $pb.ServerContext ctx, $3.UpdateDebtRequest request);
  $async.Future<$2.Empty> deleteDebt(
      $pb.ServerContext ctx, $3.DeleteDebtRequest request);
  $async.Future<$3.RecordPaymentResponse> recordPayment(
      $pb.ServerContext ctx, $3.RecordPaymentRequest request);
  $async.Future<$3.DebtDetailResponse> getDebt(
      $pb.ServerContext ctx, $3.GetDebtRequest request);
  $async.Future<$3.ListDebtsResponse> listDebts(
      $pb.ServerContext ctx, $3.ListDebtsRequest request);
  $async.Future<$3.ListDebtsResponse> getUpcomingPayments(
      $pb.ServerContext ctx, $3.GetUpcomingPaymentsRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'CreateDebt':
        return $3.CreateDebtRequest();
      case 'UpdateDebt':
        return $3.UpdateDebtRequest();
      case 'DeleteDebt':
        return $3.DeleteDebtRequest();
      case 'RecordPayment':
        return $3.RecordPaymentRequest();
      case 'GetDebt':
        return $3.GetDebtRequest();
      case 'ListDebts':
        return $3.ListDebtsRequest();
      case 'GetUpcomingPayments':
        return $3.GetUpcomingPaymentsRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'CreateDebt':
        return createDebt(ctx, request as $3.CreateDebtRequest);
      case 'UpdateDebt':
        return updateDebt(ctx, request as $3.UpdateDebtRequest);
      case 'DeleteDebt':
        return deleteDebt(ctx, request as $3.DeleteDebtRequest);
      case 'RecordPayment':
        return recordPayment(ctx, request as $3.RecordPaymentRequest);
      case 'GetDebt':
        return getDebt(ctx, request as $3.GetDebtRequest);
      case 'ListDebts':
        return listDebts(ctx, request as $3.ListDebtsRequest);
      case 'GetUpcomingPayments':
        return getUpcomingPayments(
            ctx, request as $3.GetUpcomingPaymentsRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => DebtServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => DebtServiceBase$messageJson;
}
