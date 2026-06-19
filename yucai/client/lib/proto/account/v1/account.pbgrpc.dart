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

  /// FindByAccountType returns all non-deleted accounts of a given type for the
  /// caller's tenant. Used by the transaction-form category dropdown
  /// (account-as-category): expense transactions list Expense accounts, income
  /// transactions list Income accounts.
  $grpc.ResponseFuture<$0.FindByAccountTypeResponse> findByAccountType(
    $0.FindByAccountTypeRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$findByAccountType, request, options: options);
  }

  /// Category CRUD (account-as-category model: a category is an Account whose
  /// AccountType is Expense or Income). Powers the category-manager UI.
  $grpc.ResponseFuture<$0.AccountResponse> createCategory(
    $0.CreateCategoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createCategory, request, options: options);
  }

  $grpc.ResponseFuture<$0.AccountResponse> updateCategory(
    $0.UpdateCategoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateCategory, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteCategory(
    $0.DeleteCategoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteCategory, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> reorderCategories(
    $0.ReorderCategoriesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$reorderCategories, request, options: options);
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
  static final _$findByAccountType = $grpc.ClientMethod<
          $0.FindByAccountTypeRequest, $0.FindByAccountTypeResponse>(
      '/yucai.account.v1.AccountService/FindByAccountType',
      ($0.FindByAccountTypeRequest value) => value.writeToBuffer(),
      $0.FindByAccountTypeResponse.fromBuffer);
  static final _$createCategory =
      $grpc.ClientMethod<$0.CreateCategoryRequest, $0.AccountResponse>(
          '/yucai.account.v1.AccountService/CreateCategory',
          ($0.CreateCategoryRequest value) => value.writeToBuffer(),
          $0.AccountResponse.fromBuffer);
  static final _$updateCategory =
      $grpc.ClientMethod<$0.UpdateCategoryRequest, $0.AccountResponse>(
          '/yucai.account.v1.AccountService/UpdateCategory',
          ($0.UpdateCategoryRequest value) => value.writeToBuffer(),
          $0.AccountResponse.fromBuffer);
  static final _$deleteCategory =
      $grpc.ClientMethod<$0.DeleteCategoryRequest, $1.Empty>(
          '/yucai.account.v1.AccountService/DeleteCategory',
          ($0.DeleteCategoryRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$reorderCategories =
      $grpc.ClientMethod<$0.ReorderCategoriesRequest, $1.Empty>(
          '/yucai.account.v1.AccountService/ReorderCategories',
          ($0.ReorderCategoriesRequest value) => value.writeToBuffer(),
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
    $addMethod($grpc.ServiceMethod<$0.FindByAccountTypeRequest,
            $0.FindByAccountTypeResponse>(
        'FindByAccountType',
        findByAccountType_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.FindByAccountTypeRequest.fromBuffer(value),
        ($0.FindByAccountTypeResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.CreateCategoryRequest, $0.AccountResponse>(
            'CreateCategory',
            createCategory_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CreateCategoryRequest.fromBuffer(value),
            ($0.AccountResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UpdateCategoryRequest, $0.AccountResponse>(
            'UpdateCategory',
            updateCategory_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdateCategoryRequest.fromBuffer(value),
            ($0.AccountResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteCategoryRequest, $1.Empty>(
        'DeleteCategory',
        deleteCategory_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteCategoryRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ReorderCategoriesRequest, $1.Empty>(
        'ReorderCategories',
        reorderCategories_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ReorderCategoriesRequest.fromBuffer(value),
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

  $async.Future<$0.FindByAccountTypeResponse> findByAccountType_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.FindByAccountTypeRequest> $request) async {
    return findByAccountType($call, await $request);
  }

  $async.Future<$0.FindByAccountTypeResponse> findByAccountType(
      $grpc.ServiceCall call, $0.FindByAccountTypeRequest request);

  $async.Future<$0.AccountResponse> createCategory_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateCategoryRequest> $request) async {
    return createCategory($call, await $request);
  }

  $async.Future<$0.AccountResponse> createCategory(
      $grpc.ServiceCall call, $0.CreateCategoryRequest request);

  $async.Future<$0.AccountResponse> updateCategory_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateCategoryRequest> $request) async {
    return updateCategory($call, await $request);
  }

  $async.Future<$0.AccountResponse> updateCategory(
      $grpc.ServiceCall call, $0.UpdateCategoryRequest request);

  $async.Future<$1.Empty> deleteCategory_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteCategoryRequest> $request) async {
    return deleteCategory($call, await $request);
  }

  $async.Future<$1.Empty> deleteCategory(
      $grpc.ServiceCall call, $0.DeleteCategoryRequest request);

  $async.Future<$1.Empty> reorderCategories_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ReorderCategoriesRequest> $request) async {
    return reorderCategories($call, await $request);
  }

  $async.Future<$1.Empty> reorderCategories(
      $grpc.ServiceCall call, $0.ReorderCategoriesRequest request);
}
