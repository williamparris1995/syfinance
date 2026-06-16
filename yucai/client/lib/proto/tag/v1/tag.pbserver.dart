// This is a generated file - do not edit.
//
// Generated from tag/v1/tag.proto.

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

import 'tag.pb.dart' as $3;
import 'tag.pbjson.dart';

export 'tag.pb.dart';

abstract class TagServiceBase extends $pb.GeneratedService {
  $async.Future<$3.TagResponse> createTag(
      $pb.ServerContext ctx, $3.CreateTagRequest request);
  $async.Future<$3.TagResponse> updateTag(
      $pb.ServerContext ctx, $3.UpdateTagRequest request);
  $async.Future<$2.Empty> deleteTag(
      $pb.ServerContext ctx, $3.DeleteTagRequest request);
  $async.Future<$3.ListTagsResponse> listTags(
      $pb.ServerContext ctx, $3.ListTagsRequest request);
  $async.Future<$2.Empty> addTagToTransaction(
      $pb.ServerContext ctx, $3.TagTransactionRequest request);
  $async.Future<$2.Empty> removeTagFromTransaction(
      $pb.ServerContext ctx, $3.TagTransactionRequest request);
  $async.Future<$3.ListTagsResponse> getTransactionTags(
      $pb.ServerContext ctx, $3.GetTransactionTagsRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'CreateTag':
        return $3.CreateTagRequest();
      case 'UpdateTag':
        return $3.UpdateTagRequest();
      case 'DeleteTag':
        return $3.DeleteTagRequest();
      case 'ListTags':
        return $3.ListTagsRequest();
      case 'AddTagToTransaction':
        return $3.TagTransactionRequest();
      case 'RemoveTagFromTransaction':
        return $3.TagTransactionRequest();
      case 'GetTransactionTags':
        return $3.GetTransactionTagsRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'CreateTag':
        return createTag(ctx, request as $3.CreateTagRequest);
      case 'UpdateTag':
        return updateTag(ctx, request as $3.UpdateTagRequest);
      case 'DeleteTag':
        return deleteTag(ctx, request as $3.DeleteTagRequest);
      case 'ListTags':
        return listTags(ctx, request as $3.ListTagsRequest);
      case 'AddTagToTransaction':
        return addTagToTransaction(ctx, request as $3.TagTransactionRequest);
      case 'RemoveTagFromTransaction':
        return removeTagFromTransaction(
            ctx, request as $3.TagTransactionRequest);
      case 'GetTransactionTags':
        return getTransactionTags(ctx, request as $3.GetTransactionTagsRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => TagServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => TagServiceBase$messageJson;
}
