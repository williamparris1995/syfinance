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

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;

import 'category.pb.dart' as $3;
import 'category.pbjson.dart';

export 'category.pb.dart';

abstract class CategoryServiceBase extends $pb.GeneratedService {
  $async.Future<$3.CategoryResponse> createCategory(
      $pb.ServerContext ctx, $3.CreateCategoryRequest request);
  $async.Future<$3.CategoryResponse> updateCategory(
      $pb.ServerContext ctx, $3.UpdateCategoryRequest request);
  $async.Future<$2.Empty> deleteCategory(
      $pb.ServerContext ctx, $3.DeleteCategoryRequest request);
  $async.Future<$3.ListCategoriesResponse> listCategories(
      $pb.ServerContext ctx, $3.ListCategoriesRequest request);
  $async.Future<$3.CategoryResponse> getCategory(
      $pb.ServerContext ctx, $3.GetCategoryRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'CreateCategory':
        return $3.CreateCategoryRequest();
      case 'UpdateCategory':
        return $3.UpdateCategoryRequest();
      case 'DeleteCategory':
        return $3.DeleteCategoryRequest();
      case 'ListCategories':
        return $3.ListCategoriesRequest();
      case 'GetCategory':
        return $3.GetCategoryRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'CreateCategory':
        return createCategory(ctx, request as $3.CreateCategoryRequest);
      case 'UpdateCategory':
        return updateCategory(ctx, request as $3.UpdateCategoryRequest);
      case 'DeleteCategory':
        return deleteCategory(ctx, request as $3.DeleteCategoryRequest);
      case 'ListCategories':
        return listCategories(ctx, request as $3.ListCategoriesRequest);
      case 'GetCategory':
        return getCategory(ctx, request as $3.GetCategoryRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => CategoryServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => CategoryServiceBase$messageJson;
}
