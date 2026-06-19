// This is a generated file - do not edit.
//
// Generated from category/v1/category.proto.

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

import 'category.pb.dart' as $0;

export 'category.pb.dart';

@$pb.GrpcServiceName('yucai.category.v1.CategoryService')
class CategoryServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  CategoryServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.CategoryResponse> createCategory(
    $0.CreateCategoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createCategory, request, options: options);
  }

  $grpc.ResponseFuture<$0.CategoryResponse> updateCategory(
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

  $grpc.ResponseFuture<$0.ListCategoriesResponse> listCategories(
    $0.ListCategoriesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listCategories, request, options: options);
  }

  $grpc.ResponseFuture<$0.CategoryResponse> getCategory(
    $0.GetCategoryRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getCategory, request, options: options);
  }

  // method descriptors

  static final _$createCategory =
      $grpc.ClientMethod<$0.CreateCategoryRequest, $0.CategoryResponse>(
          '/yucai.category.v1.CategoryService/CreateCategory',
          ($0.CreateCategoryRequest value) => value.writeToBuffer(),
          $0.CategoryResponse.fromBuffer);
  static final _$updateCategory =
      $grpc.ClientMethod<$0.UpdateCategoryRequest, $0.CategoryResponse>(
          '/yucai.category.v1.CategoryService/UpdateCategory',
          ($0.UpdateCategoryRequest value) => value.writeToBuffer(),
          $0.CategoryResponse.fromBuffer);
  static final _$deleteCategory =
      $grpc.ClientMethod<$0.DeleteCategoryRequest, $1.Empty>(
          '/yucai.category.v1.CategoryService/DeleteCategory',
          ($0.DeleteCategoryRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$listCategories =
      $grpc.ClientMethod<$0.ListCategoriesRequest, $0.ListCategoriesResponse>(
          '/yucai.category.v1.CategoryService/ListCategories',
          ($0.ListCategoriesRequest value) => value.writeToBuffer(),
          $0.ListCategoriesResponse.fromBuffer);
  static final _$getCategory =
      $grpc.ClientMethod<$0.GetCategoryRequest, $0.CategoryResponse>(
          '/yucai.category.v1.CategoryService/GetCategory',
          ($0.GetCategoryRequest value) => value.writeToBuffer(),
          $0.CategoryResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.category.v1.CategoryService')
abstract class CategoryServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.category.v1.CategoryService';

  CategoryServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.CreateCategoryRequest, $0.CategoryResponse>(
            'CreateCategory',
            createCategory_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CreateCategoryRequest.fromBuffer(value),
            ($0.CategoryResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UpdateCategoryRequest, $0.CategoryResponse>(
            'UpdateCategory',
            updateCategory_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdateCategoryRequest.fromBuffer(value),
            ($0.CategoryResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteCategoryRequest, $1.Empty>(
        'DeleteCategory',
        deleteCategory_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteCategoryRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListCategoriesRequest,
            $0.ListCategoriesResponse>(
        'ListCategories',
        listCategories_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.ListCategoriesRequest.fromBuffer(value),
        ($0.ListCategoriesResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetCategoryRequest, $0.CategoryResponse>(
        'GetCategory',
        getCategory_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetCategoryRequest.fromBuffer(value),
        ($0.CategoryResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.CategoryResponse> createCategory_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateCategoryRequest> $request) async {
    return createCategory($call, await $request);
  }

  $async.Future<$0.CategoryResponse> createCategory(
      $grpc.ServiceCall call, $0.CreateCategoryRequest request);

  $async.Future<$0.CategoryResponse> updateCategory_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateCategoryRequest> $request) async {
    return updateCategory($call, await $request);
  }

  $async.Future<$0.CategoryResponse> updateCategory(
      $grpc.ServiceCall call, $0.UpdateCategoryRequest request);

  $async.Future<$1.Empty> deleteCategory_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteCategoryRequest> $request) async {
    return deleteCategory($call, await $request);
  }

  $async.Future<$1.Empty> deleteCategory(
      $grpc.ServiceCall call, $0.DeleteCategoryRequest request);

  $async.Future<$0.ListCategoriesResponse> listCategories_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListCategoriesRequest> $request) async {
    return listCategories($call, await $request);
  }

  $async.Future<$0.ListCategoriesResponse> listCategories(
      $grpc.ServiceCall call, $0.ListCategoriesRequest request);

  $async.Future<$0.CategoryResponse> getCategory_Pre($grpc.ServiceCall $call,
      $async.Future<$0.GetCategoryRequest> $request) async {
    return getCategory($call, await $request);
  }

  $async.Future<$0.CategoryResponse> getCategory(
      $grpc.ServiceCall call, $0.GetCategoryRequest request);
}
