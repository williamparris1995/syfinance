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

import 'package:grpc/service_api.dart' as $grpc;
import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $1;

import 'tag.pb.dart' as $0;

export 'tag.pb.dart';

@$pb.GrpcServiceName('yucai.tag.v1.TagService')
class TagServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  TagServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.TagResponse> createTag(
    $0.CreateTagRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createTag, request, options: options);
  }

  $grpc.ResponseFuture<$0.TagResponse> updateTag(
    $0.UpdateTagRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateTag, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteTag(
    $0.DeleteTagRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteTag, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListTagsResponse> listTags(
    $0.ListTagsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listTags, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> addTagToTransaction(
    $0.TagTransactionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$addTagToTransaction, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> removeTagFromTransaction(
    $0.TagTransactionRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$removeTagFromTransaction, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.ListTagsResponse> getTransactionTags(
    $0.GetTransactionTagsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getTransactionTags, request, options: options);
  }

  // method descriptors

  static final _$createTag =
      $grpc.ClientMethod<$0.CreateTagRequest, $0.TagResponse>(
          '/yucai.tag.v1.TagService/CreateTag',
          ($0.CreateTagRequest value) => value.writeToBuffer(),
          $0.TagResponse.fromBuffer);
  static final _$updateTag =
      $grpc.ClientMethod<$0.UpdateTagRequest, $0.TagResponse>(
          '/yucai.tag.v1.TagService/UpdateTag',
          ($0.UpdateTagRequest value) => value.writeToBuffer(),
          $0.TagResponse.fromBuffer);
  static final _$deleteTag = $grpc.ClientMethod<$0.DeleteTagRequest, $1.Empty>(
      '/yucai.tag.v1.TagService/DeleteTag',
      ($0.DeleteTagRequest value) => value.writeToBuffer(),
      $1.Empty.fromBuffer);
  static final _$listTags =
      $grpc.ClientMethod<$0.ListTagsRequest, $0.ListTagsResponse>(
          '/yucai.tag.v1.TagService/ListTags',
          ($0.ListTagsRequest value) => value.writeToBuffer(),
          $0.ListTagsResponse.fromBuffer);
  static final _$addTagToTransaction =
      $grpc.ClientMethod<$0.TagTransactionRequest, $1.Empty>(
          '/yucai.tag.v1.TagService/AddTagToTransaction',
          ($0.TagTransactionRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$removeTagFromTransaction =
      $grpc.ClientMethod<$0.TagTransactionRequest, $1.Empty>(
          '/yucai.tag.v1.TagService/RemoveTagFromTransaction',
          ($0.TagTransactionRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$getTransactionTags =
      $grpc.ClientMethod<$0.GetTransactionTagsRequest, $0.ListTagsResponse>(
          '/yucai.tag.v1.TagService/GetTransactionTags',
          ($0.GetTransactionTagsRequest value) => value.writeToBuffer(),
          $0.ListTagsResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.tag.v1.TagService')
abstract class TagServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.tag.v1.TagService';

  TagServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateTagRequest, $0.TagResponse>(
        'CreateTag',
        createTag_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.CreateTagRequest.fromBuffer(value),
        ($0.TagResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UpdateTagRequest, $0.TagResponse>(
        'UpdateTag',
        updateTag_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.UpdateTagRequest.fromBuffer(value),
        ($0.TagResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteTagRequest, $1.Empty>(
        'DeleteTag',
        deleteTag_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.DeleteTagRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.ListTagsRequest, $0.ListTagsResponse>(
        'ListTags',
        listTags_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $0.ListTagsRequest.fromBuffer(value),
        ($0.ListTagsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TagTransactionRequest, $1.Empty>(
        'AddTagToTransaction',
        addTagToTransaction_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.TagTransactionRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.TagTransactionRequest, $1.Empty>(
        'RemoveTagFromTransaction',
        removeTagFromTransaction_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.TagTransactionRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.GetTransactionTagsRequest, $0.ListTagsResponse>(
            'GetTransactionTags',
            getTransactionTags_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.GetTransactionTagsRequest.fromBuffer(value),
            ($0.ListTagsResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.TagResponse> createTag_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateTagRequest> $request) async {
    return createTag($call, await $request);
  }

  $async.Future<$0.TagResponse> createTag(
      $grpc.ServiceCall call, $0.CreateTagRequest request);

  $async.Future<$0.TagResponse> updateTag_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UpdateTagRequest> $request) async {
    return updateTag($call, await $request);
  }

  $async.Future<$0.TagResponse> updateTag(
      $grpc.ServiceCall call, $0.UpdateTagRequest request);

  $async.Future<$1.Empty> deleteTag_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteTagRequest> $request) async {
    return deleteTag($call, await $request);
  }

  $async.Future<$1.Empty> deleteTag(
      $grpc.ServiceCall call, $0.DeleteTagRequest request);

  $async.Future<$0.ListTagsResponse> listTags_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListTagsRequest> $request) async {
    return listTags($call, await $request);
  }

  $async.Future<$0.ListTagsResponse> listTags(
      $grpc.ServiceCall call, $0.ListTagsRequest request);

  $async.Future<$1.Empty> addTagToTransaction_Pre($grpc.ServiceCall $call,
      $async.Future<$0.TagTransactionRequest> $request) async {
    return addTagToTransaction($call, await $request);
  }

  $async.Future<$1.Empty> addTagToTransaction(
      $grpc.ServiceCall call, $0.TagTransactionRequest request);

  $async.Future<$1.Empty> removeTagFromTransaction_Pre($grpc.ServiceCall $call,
      $async.Future<$0.TagTransactionRequest> $request) async {
    return removeTagFromTransaction($call, await $request);
  }

  $async.Future<$1.Empty> removeTagFromTransaction(
      $grpc.ServiceCall call, $0.TagTransactionRequest request);

  $async.Future<$0.ListTagsResponse> getTransactionTags_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetTransactionTagsRequest> $request) async {
    return getTransactionTags($call, await $request);
  }

  $async.Future<$0.ListTagsResponse> getTransactionTags(
      $grpc.ServiceCall call, $0.GetTransactionTagsRequest request);
}
