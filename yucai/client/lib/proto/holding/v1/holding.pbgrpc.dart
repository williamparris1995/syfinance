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

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import 'holding.pb.dart' as $0;

export 'holding.pb.dart';

@$pb.GrpcServiceName('yucai.holding.v1.HoldingService')
class HoldingServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  HoldingServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.SecurityResponse> createSecurity(
    $0.CreateSecurityRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createSecurity, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListSecuritiesResponse> listSecurities(
    $0.ListSecuritiesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listSecurities, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> updateSecurityPrice(
    $0.UpdatePriceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateSecurityPrice, request, options: options);
  }

  $grpc.ResponseFuture<$0.SearchSecuritiesResponse> searchSecurities(
    $0.SearchSecuritiesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$searchSecurities, request, options: options);
  }

  $grpc.ResponseFuture<$0.HoldingTransactionResponse> buyHolding(
    $0.HoldingTradeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$buyHolding, request, options: options);
  }

  $grpc.ResponseFuture<$0.HoldingTransactionResponse> sellHolding(
    $0.HoldingTradeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$sellHolding, request, options: options);
  }

  $grpc.ResponseFuture<$0.HoldingTransactionResponse> recordDividend(
    $0.RecordDividendRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$recordDividend, request, options: options);
  }

  $grpc.ResponseFuture<$0.HoldingTransactionResponse> recordSplit(
    $0.RecordSplitRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$recordSplit, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListHoldingsResponse> listHoldings(
    $0.ListHoldingsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listHoldings, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListTradesResponse> listHoldingTransactions(
    $0.ListTradesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listHoldingTransactions, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.SyncPricesResponse> syncPrices(
    $0.SyncPricesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$syncPrices, request, options: options);
  }

  $grpc.ResponseFuture<$0.PortfolioPerformanceResponse> getPortfolioPerformance(
    $0.GetPortfolioPerformanceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getPortfolioPerformance, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.HoldingPerformanceResponse> getHoldingPerformance(
    $0.GetHoldingPerformanceRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getHoldingPerformance, request, options: options);
  }

  $grpc.ResponseFuture<$0.BackfillPriceHistoryResponse> backfillPriceHistory(
    $0.BackfillPriceHistoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$backfillPriceHistory, request, options: options);
  }

  // method descriptors

  static final _$createSecurity =
      $grpc.ClientMethod<$0.CreateSecurityRequest, $0.SecurityResponse>(
          '/yucai.holding.v1.HoldingService/CreateSecurity',
          ($0.CreateSecurityRequest value) => value.writeToBuffer(),
          $0.SecurityResponse.fromBuffer);
  static final _$listSecurities =
      $grpc.ClientMethod<$0.ListSecuritiesRequest, $0.ListSecuritiesResponse>(
          '/yucai.holding.v1.HoldingService/ListSecurities',
          ($0.ListSecuritiesRequest value) => value.writeToBuffer(),
          $0.ListSecuritiesResponse.fromBuffer);
  static final _$updateSecurityPrice =
      $grpc.ClientMethod<$0.UpdatePriceRequest, $1.Empty>(
          '/yucai.holding.v1.HoldingService/UpdateSecurityPrice',
          ($0.UpdatePriceRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$searchSecurities = $grpc.ClientMethod<
          $0.SearchSecuritiesRequest, $0.SearchSecuritiesResponse>(
      '/yucai.holding.v1.HoldingService/SearchSecurities',
      ($0.SearchSecuritiesRequest value) => value.writeToBuffer(),
      $0.SearchSecuritiesResponse.fromBuffer);
  static final _$buyHolding =
      $grpc.ClientMethod<$0.HoldingTradeRequest, $0.HoldingTransactionResponse>(
          '/yucai.holding.v1.HoldingService/BuyHolding',
          ($0.HoldingTradeRequest value) => value.writeToBuffer(),
          $0.HoldingTransactionResponse.fromBuffer);
  static final _$sellHolding =
      $grpc.ClientMethod<$0.HoldingTradeRequest, $0.HoldingTransactionResponse>(
          '/yucai.holding.v1.HoldingService/SellHolding',
          ($0.HoldingTradeRequest value) => value.writeToBuffer(),
          $0.HoldingTransactionResponse.fromBuffer);
  static final _$recordDividend = $grpc.ClientMethod<$0.RecordDividendRequest,
          $0.HoldingTransactionResponse>(
      '/yucai.holding.v1.HoldingService/RecordDividend',
      ($0.RecordDividendRequest value) => value.writeToBuffer(),
      $0.HoldingTransactionResponse.fromBuffer);
  static final _$recordSplit =
      $grpc.ClientMethod<$0.RecordSplitRequest, $0.HoldingTransactionResponse>(
          '/yucai.holding.v1.HoldingService/RecordSplit',
          ($0.RecordSplitRequest value) => value.writeToBuffer(),
          $0.HoldingTransactionResponse.fromBuffer);
  static final _$listHoldings =
      $grpc.ClientMethod<$0.ListHoldingsRequest, $0.ListHoldingsResponse>(
          '/yucai.holding.v1.HoldingService/ListHoldings',
          ($0.ListHoldingsRequest value) => value.writeToBuffer(),
          $0.ListHoldingsResponse.fromBuffer);
  static final _$listHoldingTransactions =
      $grpc.ClientMethod<$0.ListTradesRequest, $0.ListTradesResponse>(
          '/yucai.holding.v1.HoldingService/ListHoldingTransactions',
          ($0.ListTradesRequest value) => value.writeToBuffer(),
          $0.ListTradesResponse.fromBuffer);
  static final _$syncPrices =
      $grpc.ClientMethod<$0.SyncPricesRequest, $0.SyncPricesResponse>(
          '/yucai.holding.v1.HoldingService/SyncPrices',
          ($0.SyncPricesRequest value) => value.writeToBuffer(),
          $0.SyncPricesResponse.fromBuffer);
  static final _$getPortfolioPerformance = $grpc.ClientMethod<
          $0.GetPortfolioPerformanceRequest, $0.PortfolioPerformanceResponse>(
      '/yucai.holding.v1.HoldingService/GetPortfolioPerformance',
      ($0.GetPortfolioPerformanceRequest value) => value.writeToBuffer(),
      $0.PortfolioPerformanceResponse.fromBuffer);
  static final _$getHoldingPerformance = $grpc.ClientMethod<
          $0.GetHoldingPerformanceRequest, $0.HoldingPerformanceResponse>(
      '/yucai.holding.v1.HoldingService/GetHoldingPerformance',
      ($0.GetHoldingPerformanceRequest value) => value.writeToBuffer(),
      $0.HoldingPerformanceResponse.fromBuffer);
  static final _$backfillPriceHistory = $grpc.ClientMethod<
          $0.BackfillPriceHistoryRequest, $0.BackfillPriceHistoryResponse>(
      '/yucai.holding.v1.HoldingService/BackfillPriceHistory',
      ($0.BackfillPriceHistoryRequest value) => value.writeToBuffer(),
      $0.BackfillPriceHistoryResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.holding.v1.HoldingService')
abstract class HoldingServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.holding.v1.HoldingService';

  HoldingServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.CreateSecurityRequest, $0.SecurityResponse>(
            'CreateSecurity',
            createSecurity_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CreateSecurityRequest.fromBuffer(value),
            ($0.SecurityResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListSecuritiesRequest,
            $0.ListSecuritiesResponse>(
        'ListSecurities',
        listSecurities_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListSecuritiesRequest.fromBuffer(value),
        ($0.ListSecuritiesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdatePriceRequest, $1.Empty>(
        'UpdateSecurityPrice',
        updateSecurityPrice_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdatePriceRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SearchSecuritiesRequest,
            $0.SearchSecuritiesResponse>(
        'SearchSecurities',
        searchSecurities_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SearchSecuritiesRequest.fromBuffer(value),
        ($0.SearchSecuritiesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.HoldingTradeRequest,
            $0.HoldingTransactionResponse>(
        'BuyHolding',
        buyHolding_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.HoldingTradeRequest.fromBuffer(value),
        ($0.HoldingTransactionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.HoldingTradeRequest,
            $0.HoldingTransactionResponse>(
        'SellHolding',
        sellHolding_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.HoldingTradeRequest.fromBuffer(value),
        ($0.HoldingTransactionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RecordDividendRequest,
            $0.HoldingTransactionResponse>(
        'RecordDividend',
        recordDividend_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RecordDividendRequest.fromBuffer(value),
        ($0.HoldingTransactionResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RecordSplitRequest,
            $0.HoldingTransactionResponse>(
        'RecordSplit',
        recordSplit_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RecordSplitRequest.fromBuffer(value),
        ($0.HoldingTransactionResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListHoldingsRequest, $0.ListHoldingsResponse>(
            'ListHoldings',
            listHoldings_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListHoldingsRequest.fromBuffer(value),
            ($0.ListHoldingsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListTradesRequest, $0.ListTradesResponse>(
        'ListHoldingTransactions',
        listHoldingTransactions_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListTradesRequest.fromBuffer(value),
        ($0.ListTradesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SyncPricesRequest, $0.SyncPricesResponse>(
        'SyncPrices',
        syncPrices_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.SyncPricesRequest.fromBuffer(value),
        ($0.SyncPricesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetPortfolioPerformanceRequest,
            $0.PortfolioPerformanceResponse>(
        'GetPortfolioPerformance',
        getPortfolioPerformance_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetPortfolioPerformanceRequest.fromBuffer(value),
        ($0.PortfolioPerformanceResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetHoldingPerformanceRequest,
            $0.HoldingPerformanceResponse>(
        'GetHoldingPerformance',
        getHoldingPerformance_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetHoldingPerformanceRequest.fromBuffer(value),
        ($0.HoldingPerformanceResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.BackfillPriceHistoryRequest,
            $0.BackfillPriceHistoryResponse>(
        'BackfillPriceHistory',
        backfillPriceHistory_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.BackfillPriceHistoryRequest.fromBuffer(value),
        ($0.BackfillPriceHistoryResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.SecurityResponse> createSecurity_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateSecurityRequest> $request) async {
    return createSecurity($call, await $request);
  }

  $async.Future<$0.SecurityResponse> createSecurity(
      $grpc.ServiceCall call, $0.CreateSecurityRequest request);

  $async.Future<$0.ListSecuritiesResponse> listSecurities_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListSecuritiesRequest> $request) async {
    return listSecurities($call, await $request);
  }

  $async.Future<$0.ListSecuritiesResponse> listSecurities(
      $grpc.ServiceCall call, $0.ListSecuritiesRequest request);

  $async.Future<$1.Empty> updateSecurityPrice_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdatePriceRequest> $request) async {
    return updateSecurityPrice($call, await $request);
  }

  $async.Future<$1.Empty> updateSecurityPrice(
      $grpc.ServiceCall call, $0.UpdatePriceRequest request);

  $async.Future<$0.SearchSecuritiesResponse> searchSecurities_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SearchSecuritiesRequest> $request) async {
    return searchSecurities($call, await $request);
  }

  $async.Future<$0.SearchSecuritiesResponse> searchSecurities(
      $grpc.ServiceCall call, $0.SearchSecuritiesRequest request);

  $async.Future<$0.HoldingTransactionResponse> buyHolding_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.HoldingTradeRequest> $request) async {
    return buyHolding($call, await $request);
  }

  $async.Future<$0.HoldingTransactionResponse> buyHolding(
      $grpc.ServiceCall call, $0.HoldingTradeRequest request);

  $async.Future<$0.HoldingTransactionResponse> sellHolding_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.HoldingTradeRequest> $request) async {
    return sellHolding($call, await $request);
  }

  $async.Future<$0.HoldingTransactionResponse> sellHolding(
      $grpc.ServiceCall call, $0.HoldingTradeRequest request);

  $async.Future<$0.HoldingTransactionResponse> recordDividend_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RecordDividendRequest> $request) async {
    return recordDividend($call, await $request);
  }

  $async.Future<$0.HoldingTransactionResponse> recordDividend(
      $grpc.ServiceCall call, $0.RecordDividendRequest request);

  $async.Future<$0.HoldingTransactionResponse> recordSplit_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.RecordSplitRequest> $request) async {
    return recordSplit($call, await $request);
  }

  $async.Future<$0.HoldingTransactionResponse> recordSplit(
      $grpc.ServiceCall call, $0.RecordSplitRequest request);

  $async.Future<$0.ListHoldingsResponse> listHoldings_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListHoldingsRequest> $request) async {
    return listHoldings($call, await $request);
  }

  $async.Future<$0.ListHoldingsResponse> listHoldings(
      $grpc.ServiceCall call, $0.ListHoldingsRequest request);

  $async.Future<$0.ListTradesResponse> listHoldingTransactions_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListTradesRequest> $request) async {
    return listHoldingTransactions($call, await $request);
  }

  $async.Future<$0.ListTradesResponse> listHoldingTransactions(
      $grpc.ServiceCall call, $0.ListTradesRequest request);

  $async.Future<$0.SyncPricesResponse> syncPrices_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SyncPricesRequest> $request) async {
    return syncPrices($call, await $request);
  }

  $async.Future<$0.SyncPricesResponse> syncPrices(
      $grpc.ServiceCall call, $0.SyncPricesRequest request);

  $async.Future<$0.PortfolioPerformanceResponse> getPortfolioPerformance_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetPortfolioPerformanceRequest> $request) async {
    return getPortfolioPerformance($call, await $request);
  }

  $async.Future<$0.PortfolioPerformanceResponse> getPortfolioPerformance(
      $grpc.ServiceCall call, $0.GetPortfolioPerformanceRequest request);

  $async.Future<$0.HoldingPerformanceResponse> getHoldingPerformance_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetHoldingPerformanceRequest> $request) async {
    return getHoldingPerformance($call, await $request);
  }

  $async.Future<$0.HoldingPerformanceResponse> getHoldingPerformance(
      $grpc.ServiceCall call, $0.GetHoldingPerformanceRequest request);

  $async.Future<$0.BackfillPriceHistoryResponse> backfillPriceHistory_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.BackfillPriceHistoryRequest> $request) async {
    return backfillPriceHistory($call, await $request);
  }

  $async.Future<$0.BackfillPriceHistoryResponse> backfillPriceHistory(
      $grpc.ServiceCall call, $0.BackfillPriceHistoryRequest request);
}
