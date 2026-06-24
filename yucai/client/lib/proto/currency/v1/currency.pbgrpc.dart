// This is a generated file - do not edit.
//
// Generated from currency/v1/currency.proto.

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

import 'currency.pb.dart' as $0;

export 'currency.pb.dart';

@$pb.GrpcServiceName('yucai.currency.v1.CurrencyService')
class CurrencyServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  CurrencyServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.ListCurrenciesResponse> listCurrencies(
    $0.ListCurrenciesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listCurrencies, request, options: options);
  }

  $grpc.ResponseFuture<$0.CurrencyResponse> addCurrency(
    $0.AddCurrencyRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addCurrency, request, options: options);
  }

  $grpc.ResponseFuture<$0.CurrencyResponse> updateExchangeRate(
    $0.UpdateRateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateExchangeRate, request, options: options);
  }

  $grpc.ResponseFuture<$0.FetchRateResponse> fetchExchangeRate(
    $0.FetchRateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$fetchExchangeRate, request, options: options);
  }

  // method descriptors

  static final _$listCurrencies =
      $grpc.ClientMethod<$0.ListCurrenciesRequest, $0.ListCurrenciesResponse>(
          '/yucai.currency.v1.CurrencyService/ListCurrencies',
          ($0.ListCurrenciesRequest value) => value.writeToBuffer(),
          $0.ListCurrenciesResponse.fromBuffer);
  static final _$addCurrency =
      $grpc.ClientMethod<$0.AddCurrencyRequest, $0.CurrencyResponse>(
          '/yucai.currency.v1.CurrencyService/AddCurrency',
          ($0.AddCurrencyRequest value) => value.writeToBuffer(),
          $0.CurrencyResponse.fromBuffer);
  static final _$updateExchangeRate =
      $grpc.ClientMethod<$0.UpdateRateRequest, $0.CurrencyResponse>(
          '/yucai.currency.v1.CurrencyService/UpdateExchangeRate',
          ($0.UpdateRateRequest value) => value.writeToBuffer(),
          $0.CurrencyResponse.fromBuffer);
  static final _$fetchExchangeRate =
      $grpc.ClientMethod<$0.FetchRateRequest, $0.FetchRateResponse>(
          '/yucai.currency.v1.CurrencyService/FetchExchangeRate',
          ($0.FetchRateRequest value) => value.writeToBuffer(),
          $0.FetchRateResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.currency.v1.CurrencyService')
abstract class CurrencyServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.currency.v1.CurrencyService';

  CurrencyServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ListCurrenciesRequest,
            $0.ListCurrenciesResponse>(
        'ListCurrencies',
        listCurrencies_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListCurrenciesRequest.fromBuffer(value),
        ($0.ListCurrenciesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.AddCurrencyRequest, $0.CurrencyResponse>(
        'AddCurrency',
        addCurrency_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.AddCurrencyRequest.fromBuffer(value),
        ($0.CurrencyResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateRateRequest, $0.CurrencyResponse>(
        'UpdateExchangeRate',
        updateExchangeRate_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateRateRequest.fromBuffer(value),
        ($0.CurrencyResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.FetchRateRequest, $0.FetchRateResponse>(
        'FetchExchangeRate',
        fetchExchangeRate_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.FetchRateRequest.fromBuffer(value),
        ($0.FetchRateResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.ListCurrenciesResponse> listCurrencies_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListCurrenciesRequest> $request) async {
    return listCurrencies($call, await $request);
  }

  $async.Future<$0.ListCurrenciesResponse> listCurrencies(
      $grpc.ServiceCall call, $0.ListCurrenciesRequest request);

  $async.Future<$0.CurrencyResponse> addCurrency_Pre($grpc.ServiceCall $call,
      $async.Future<$0.AddCurrencyRequest> $request) async {
    return addCurrency($call, await $request);
  }

  $async.Future<$0.CurrencyResponse> addCurrency(
      $grpc.ServiceCall call, $0.AddCurrencyRequest request);

  $async.Future<$0.CurrencyResponse> updateExchangeRate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateRateRequest> $request) async {
    return updateExchangeRate($call, await $request);
  }

  $async.Future<$0.CurrencyResponse> updateExchangeRate(
      $grpc.ServiceCall call, $0.UpdateRateRequest request);

  $async.Future<$0.FetchRateResponse> fetchExchangeRate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.FetchRateRequest> $request) async {
    return fetchExchangeRate($call, await $request);
  }

  $async.Future<$0.FetchRateResponse> fetchExchangeRate(
      $grpc.ServiceCall call, $0.FetchRateRequest request);
}
