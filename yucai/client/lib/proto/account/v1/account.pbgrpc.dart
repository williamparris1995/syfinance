// This is a generated file - do not edit.
//
// Generated from account/v1/account.proto.

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

import 'account.pb.dart' as $0;

export 'account.pb.dart';

/// AccountService manages chart of accounts and account CRUD operations.
@$pb.GrpcServiceName('yucai.account.v1.AccountService')
class AccountServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  AccountServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.AccountResponse> createAccount(
    $0.CreateAccountRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createAccount, request, options: options);
  }

  $grpc.ResponseFuture<$0.AccountResponse> getAccount(
    $0.GetAccountRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getAccount, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListAccountsResponse> listAccounts(
    $0.ListAccountsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listAccounts, request, options: options);
  }

  $grpc.ResponseFuture<$0.AccountResponse> updateAccount(
    $0.UpdateAccountRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateAccount, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteAccount(
    $0.DeleteAccountRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteAccount, request, options: options);
  }

  // method descriptors

  static final _$createAccount =
      $grpc.ClientMethod<$0.CreateAccountRequest, $0.AccountResponse>(
          '/yucai.account.v1.AccountService/CreateAccount',
          ($0.CreateAccountRequest value) => value.writeToBuffer(),
          $0.AccountResponse.fromBuffer);
  static final _$getAccount =
      $grpc.ClientMethod<$0.GetAccountRequest, $0.AccountResponse>(
          '/yucai.account.v1.AccountService/GetAccount',
          ($0.GetAccountRequest value) => value.writeToBuffer(),
          $0.AccountResponse.fromBuffer);
  static final _$listAccounts =
      $grpc.ClientMethod<$0.ListAccountsRequest, $0.ListAccountsResponse>(
          '/yucai.account.v1.AccountService/ListAccounts',
          ($0.ListAccountsRequest value) => value.writeToBuffer(),
          $0.ListAccountsResponse.fromBuffer);
  static final _$updateAccount =
      $grpc.ClientMethod<$0.UpdateAccountRequest, $0.AccountResponse>(
          '/yucai.account.v1.AccountService/UpdateAccount',
          ($0.UpdateAccountRequest value) => value.writeToBuffer(),
          $0.AccountResponse.fromBuffer);
  static final _$deleteAccount =
      $grpc.ClientMethod<$0.DeleteAccountRequest, $1.Empty>(
          '/yucai.account.v1.AccountService/DeleteAccount',
          ($0.DeleteAccountRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
}

@$pb.GrpcServiceName('yucai.account.v1.AccountService')
abstract class AccountServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.account.v1.AccountService';

  AccountServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateAccountRequest, $0.AccountResponse>(
        'CreateAccount',
        createAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateAccountRequest.fromBuffer(value),
        ($0.AccountResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetAccountRequest, $0.AccountResponse>(
        'GetAccount',
        getAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.GetAccountRequest.fromBuffer(value),
        ($0.AccountResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListAccountsRequest, $0.ListAccountsResponse>(
            'ListAccounts',
            listAccounts_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListAccountsRequest.fromBuffer(value),
            ($0.ListAccountsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateAccountRequest, $0.AccountResponse>(
        'UpdateAccount',
        updateAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UpdateAccountRequest.fromBuffer(value),
        ($0.AccountResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteAccountRequest, $1.Empty>(
        'DeleteAccount',
        deleteAccount_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteAccountRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
  }

  $async.Future<$0.AccountResponse> createAccount_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateAccountRequest> $request) async {
    return createAccount($call, await $request);
  }

  $async.Future<$0.AccountResponse> createAccount(
      $grpc.ServiceCall call, $0.CreateAccountRequest request);

  $async.Future<$0.AccountResponse> getAccount_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetAccountRequest> $request) async {
    return getAccount($call, await $request);
  }

  $async.Future<$0.AccountResponse> getAccount(
      $grpc.ServiceCall call, $0.GetAccountRequest request);

  $async.Future<$0.ListAccountsResponse> listAccounts_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListAccountsRequest> $request) async {
    return listAccounts($call, await $request);
  }

  $async.Future<$0.ListAccountsResponse> listAccounts(
      $grpc.ServiceCall call, $0.ListAccountsRequest request);

  $async.Future<$0.AccountResponse> updateAccount_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateAccountRequest> $request) async {
    return updateAccount($call, await $request);
  }

  $async.Future<$0.AccountResponse> updateAccount(
      $grpc.ServiceCall call, $0.UpdateAccountRequest request);

  $async.Future<$1.Empty> deleteAccount_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteAccountRequest> $request) async {
    return deleteAccount($call, await $request);
  }

  $async.Future<$1.Empty> deleteAccount(
      $grpc.ServiceCall call, $0.DeleteAccountRequest request);
}
