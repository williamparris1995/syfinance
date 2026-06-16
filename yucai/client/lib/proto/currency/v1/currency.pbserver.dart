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

import 'package:protobuf/protobuf.dart' as $pb;

import 'currency.pb.dart' as $1;
import 'currency.pbjson.dart';

export 'currency.pb.dart';

abstract class CurrencyServiceBase extends $pb.GeneratedService {
  $async.Future<$1.ListCurrenciesResponse> listCurrencies(
      $pb.ServerContext ctx, $1.ListCurrenciesRequest request);
  $async.Future<$1.CurrencyResponse> addCurrency(
      $pb.ServerContext ctx, $1.AddCurrencyRequest request);
  $async.Future<$1.CurrencyResponse> updateExchangeRate(
      $pb.ServerContext ctx, $1.UpdateRateRequest request);
  $async.Future<$1.FetchRateResponse> fetchExchangeRate(
      $pb.ServerContext ctx, $1.FetchRateRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'ListCurrencies':
        return $1.ListCurrenciesRequest();
      case 'AddCurrency':
        return $1.AddCurrencyRequest();
      case 'UpdateExchangeRate':
        return $1.UpdateRateRequest();
      case 'FetchExchangeRate':
        return $1.FetchRateRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'ListCurrencies':
        return listCurrencies(ctx, request as $1.ListCurrenciesRequest);
      case 'AddCurrency':
        return addCurrency(ctx, request as $1.AddCurrencyRequest);
      case 'UpdateExchangeRate':
        return updateExchangeRate(ctx, request as $1.UpdateRateRequest);
      case 'FetchExchangeRate':
        return fetchExchangeRate(ctx, request as $1.FetchRateRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => CurrencyServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => CurrencyServiceBase$messageJson;
}
