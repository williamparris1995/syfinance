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

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;

import 'account.pb.dart' as $3;
import 'account.pbjson.dart';

export 'account.pb.dart';

abstract class AccountServiceBase extends $pb.GeneratedService {
  $async.Future<$3.AccountResponse> createAccount(
      $pb.ServerContext ctx, $3.CreateAccountRequest request);
  $async.Future<$3.AccountResponse> getAccount(
      $pb.ServerContext ctx, $3.GetAccountRequest request);
  $async.Future<$3.ListAccountsResponse> listAccounts(
      $pb.ServerContext ctx, $3.ListAccountsRequest request);
  $async.Future<$3.AccountResponse> updateAccount(
      $pb.ServerContext ctx, $3.UpdateAccountRequest request);
  $async.Future<$2.Empty> deleteAccount(
      $pb.ServerContext ctx, $3.DeleteAccountRequest request);
  $async.Future<$3.FindByAccountTypeResponse> findByAccountType(
      $pb.ServerContext ctx, $3.FindByAccountTypeRequest request);
  $async.Future<$3.AccountResponse> createCategory(
      $pb.ServerContext ctx, $3.CreateCategoryRequest request);
  $async.Future<$3.AccountResponse> updateCategory(
      $pb.ServerContext ctx, $3.UpdateCategoryRequest request);
  $async.Future<$2.Empty> deleteCategory(
      $pb.ServerContext ctx, $3.DeleteCategoryRequest request);
  $async.Future<$2.Empty> reorderCategories(
      $pb.ServerContext ctx, $3.ReorderCategoriesRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'CreateAccount':
        return $3.CreateAccountRequest();
      case 'GetAccount':
        return $3.GetAccountRequest();
      case 'ListAccounts':
        return $3.ListAccountsRequest();
      case 'UpdateAccount':
        return $3.UpdateAccountRequest();
      case 'DeleteAccount':
        return $3.DeleteAccountRequest();
      case 'FindByAccountType':
        return $3.FindByAccountTypeRequest();
      case 'CreateCategory':
        return $3.CreateCategoryRequest();
      case 'UpdateCategory':
        return $3.UpdateCategoryRequest();
      case 'DeleteCategory':
        return $3.DeleteCategoryRequest();
      case 'ReorderCategories':
        return $3.ReorderCategoriesRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'CreateAccount':
        return createAccount(ctx, request as $3.CreateAccountRequest);
      case 'GetAccount':
        return getAccount(ctx, request as $3.GetAccountRequest);
      case 'ListAccounts':
        return listAccounts(ctx, request as $3.ListAccountsRequest);
      case 'UpdateAccount':
        return updateAccount(ctx, request as $3.UpdateAccountRequest);
      case 'DeleteAccount':
        return deleteAccount(ctx, request as $3.DeleteAccountRequest);
      case 'FindByAccountType':
        return findByAccountType(ctx, request as $3.FindByAccountTypeRequest);
      case 'CreateCategory':
        return createCategory(ctx, request as $3.CreateCategoryRequest);
      case 'UpdateCategory':
        return updateCategory(ctx, request as $3.UpdateCategoryRequest);
      case 'DeleteCategory':
        return deleteCategory(ctx, request as $3.DeleteCategoryRequest);
      case 'ReorderCategories':
        return reorderCategories(ctx, request as $3.ReorderCategoriesRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => AccountServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => AccountServiceBase$messageJson;
}
