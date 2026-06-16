// This is a generated file - do not edit.
//
// Generated from holding/v1/holding.proto.

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

import 'holding.pb.dart' as $3;
import 'holding.pbjson.dart';

export 'holding.pb.dart';

abstract class HoldingServiceBase extends $pb.GeneratedService {
  $async.Future<$3.SecurityResponse> createSecurity(
      $pb.ServerContext ctx, $3.CreateSecurityRequest request);
  $async.Future<$3.ListSecuritiesResponse> listSecurities(
      $pb.ServerContext ctx, $3.ListSecuritiesRequest request);
  $async.Future<$2.Empty> updateSecurityPrice(
      $pb.ServerContext ctx, $3.UpdatePriceRequest request);
  $async.Future<$3.SearchSecuritiesResponse> searchSecurities(
      $pb.ServerContext ctx, $3.SearchSecuritiesRequest request);
  $async.Future<$3.HoldingTransactionResponse> buyHolding(
      $pb.ServerContext ctx, $3.HoldingTradeRequest request);
  $async.Future<$3.HoldingTransactionResponse> sellHolding(
      $pb.ServerContext ctx, $3.HoldingTradeRequest request);
  $async.Future<$3.HoldingTransactionResponse> recordDividend(
      $pb.ServerContext ctx, $3.RecordDividendRequest request);
  $async.Future<$3.HoldingTransactionResponse> recordSplit(
      $pb.ServerContext ctx, $3.RecordSplitRequest request);
  $async.Future<$3.ListHoldingsResponse> listHoldings(
      $pb.ServerContext ctx, $3.ListHoldingsRequest request);
  $async.Future<$3.ListTradesResponse> listHoldingTransactions(
      $pb.ServerContext ctx, $3.ListTradesRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'CreateSecurity':
        return $3.CreateSecurityRequest();
      case 'ListSecurities':
        return $3.ListSecuritiesRequest();
      case 'UpdateSecurityPrice':
        return $3.UpdatePriceRequest();
      case 'SearchSecurities':
        return $3.SearchSecuritiesRequest();
      case 'BuyHolding':
        return $3.HoldingTradeRequest();
      case 'SellHolding':
        return $3.HoldingTradeRequest();
      case 'RecordDividend':
        return $3.RecordDividendRequest();
      case 'RecordSplit':
        return $3.RecordSplitRequest();
      case 'ListHoldings':
        return $3.ListHoldingsRequest();
      case 'ListHoldingTransactions':
        return $3.ListTradesRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'CreateSecurity':
        return createSecurity(ctx, request as $3.CreateSecurityRequest);
      case 'ListSecurities':
        return listSecurities(ctx, request as $3.ListSecuritiesRequest);
      case 'UpdateSecurityPrice':
        return updateSecurityPrice(ctx, request as $3.UpdatePriceRequest);
      case 'SearchSecurities':
        return searchSecurities(ctx, request as $3.SearchSecuritiesRequest);
      case 'BuyHolding':
        return buyHolding(ctx, request as $3.HoldingTradeRequest);
      case 'SellHolding':
        return sellHolding(ctx, request as $3.HoldingTradeRequest);
      case 'RecordDividend':
        return recordDividend(ctx, request as $3.RecordDividendRequest);
      case 'RecordSplit':
        return recordSplit(ctx, request as $3.RecordSplitRequest);
      case 'ListHoldings':
        return listHoldings(ctx, request as $3.ListHoldingsRequest);
      case 'ListHoldingTransactions':
        return listHoldingTransactions(ctx, request as $3.ListTradesRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => HoldingServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => HoldingServiceBase$messageJson;
}
