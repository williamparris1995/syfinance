// This is a generated file - do not edit.
//
// Generated from template/v1/template.proto.

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

import 'template.pb.dart' as $0;

export 'template.pb.dart';

@$pb.GrpcServiceName('yucai.template.v1.TransactionTemplateService')
class TransactionTemplateServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  TransactionTemplateServiceClient(super.channel,
      {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.TemplateResponse> createTransactionTemplate(
    $0.CreateTemplateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createTransactionTemplate, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.TemplateResponse> updateTransactionTemplate(
    $0.UpdateTemplateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$updateTransactionTemplate, request,
        options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteTransactionTemplate(
    $0.DeleteTemplateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteTransactionTemplate, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.TemplateResponse> pauseTransactionTemplate(
    $0.PauseTemplateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$pauseTransactionTemplate, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.TemplateResponse> resumeTransactionTemplate(
    $0.ResumeTemplateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$resumeTransactionTemplate, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.TemplateResponse> getTransactionTemplate(
    $0.GetTemplateRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getTransactionTemplate, request,
        options: options);
  }

  $grpc.ResponseFuture<$0.ListTemplatesResponse> listTransactionTemplates(
    $0.ListTemplatesRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listTransactionTemplates, request,
        options: options);
  }

  // method descriptors

  static final _$createTransactionTemplate = $grpc.ClientMethod<
          $0.CreateTemplateRequest, $0.TemplateResponse>(
      '/yucai.template.v1.TransactionTemplateService/CreateTransactionTemplate',
      ($0.CreateTemplateRequest value) => value.writeToBuffer(),
      $0.TemplateResponse.fromBuffer);
  static final _$updateTransactionTemplate = $grpc.ClientMethod<
          $0.UpdateTemplateRequest, $0.TemplateResponse>(
      '/yucai.template.v1.TransactionTemplateService/UpdateTransactionTemplate',
      ($0.UpdateTemplateRequest value) => value.writeToBuffer(),
      $0.TemplateResponse.fromBuffer);
  static final _$deleteTransactionTemplate = $grpc.ClientMethod<
          $0.DeleteTemplateRequest, $1.Empty>(
      '/yucai.template.v1.TransactionTemplateService/DeleteTransactionTemplate',
      ($0.DeleteTemplateRequest value) => value.writeToBuffer(),
      $1.Empty.fromBuffer);
  static final _$pauseTransactionTemplate = $grpc.ClientMethod<
          $0.PauseTemplateRequest, $0.TemplateResponse>(
      '/yucai.template.v1.TransactionTemplateService/PauseTransactionTemplate',
      ($0.PauseTemplateRequest value) => value.writeToBuffer(),
      $0.TemplateResponse.fromBuffer);
  static final _$resumeTransactionTemplate = $grpc.ClientMethod<
          $0.ResumeTemplateRequest, $0.TemplateResponse>(
      '/yucai.template.v1.TransactionTemplateService/ResumeTransactionTemplate',
      ($0.ResumeTemplateRequest value) => value.writeToBuffer(),
      $0.TemplateResponse.fromBuffer);
  static final _$getTransactionTemplate = $grpc.ClientMethod<
          $0.GetTemplateRequest, $0.TemplateResponse>(
      '/yucai.template.v1.TransactionTemplateService/GetTransactionTemplate',
      ($0.GetTemplateRequest value) => value.writeToBuffer(),
      $0.TemplateResponse.fromBuffer);
  static final _$listTransactionTemplates = $grpc.ClientMethod<
          $0.ListTemplatesRequest, $0.ListTemplatesResponse>(
      '/yucai.template.v1.TransactionTemplateService/ListTransactionTemplates',
      ($0.ListTemplatesRequest value) => value.writeToBuffer(),
      $0.ListTemplatesResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.template.v1.TransactionTemplateService')
abstract class TransactionTemplateServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.template.v1.TransactionTemplateService';

  TransactionTemplateServiceBase() {
    $addMethod(
        $grpc.ServiceMethod<$0.CreateTemplateRequest, $0.TemplateResponse>(
            'CreateTransactionTemplate',
            createTransactionTemplate_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.CreateTemplateRequest.fromBuffer(value),
            ($0.TemplateResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.UpdateTemplateRequest, $0.TemplateResponse>(
            'UpdateTransactionTemplate',
            updateTransactionTemplate_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.UpdateTemplateRequest.fromBuffer(value),
            ($0.TemplateResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteTemplateRequest, $1.Empty>(
        'DeleteTransactionTemplate',
        deleteTransactionTemplate_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteTemplateRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.PauseTemplateRequest, $0.TemplateResponse>(
            'PauseTransactionTemplate',
            pauseTransactionTemplate_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.PauseTemplateRequest.fromBuffer(value),
            ($0.TemplateResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ResumeTemplateRequest, $0.TemplateResponse>(
            'ResumeTransactionTemplate',
            resumeTransactionTemplate_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ResumeTemplateRequest.fromBuffer(value),
            ($0.TemplateResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.GetTemplateRequest, $0.TemplateResponse>(
        'GetTransactionTemplate',
        getTransactionTemplate_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.GetTemplateRequest.fromBuffer(value),
        ($0.TemplateResponse value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListTemplatesRequest, $0.ListTemplatesResponse>(
            'ListTransactionTemplates',
            listTransactionTemplates_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListTemplatesRequest.fromBuffer(value),
            ($0.ListTemplatesResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.TemplateResponse> createTransactionTemplate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.CreateTemplateRequest> $request) async {
    return createTransactionTemplate($call, await $request);
  }

  $async.Future<$0.TemplateResponse> createTransactionTemplate(
      $grpc.ServiceCall call, $0.CreateTemplateRequest request);

  $async.Future<$0.TemplateResponse> updateTransactionTemplate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.UpdateTemplateRequest> $request) async {
    return updateTransactionTemplate($call, await $request);
  }

  $async.Future<$0.TemplateResponse> updateTransactionTemplate(
      $grpc.ServiceCall call, $0.UpdateTemplateRequest request);

  $async.Future<$1.Empty> deleteTransactionTemplate_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteTemplateRequest> $request) async {
    return deleteTransactionTemplate($call, await $request);
  }

  $async.Future<$1.Empty> deleteTransactionTemplate(
      $grpc.ServiceCall call, $0.DeleteTemplateRequest request);

  $async.Future<$0.TemplateResponse> pauseTransactionTemplate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.PauseTemplateRequest> $request) async {
    return pauseTransactionTemplate($call, await $request);
  }

  $async.Future<$0.TemplateResponse> pauseTransactionTemplate(
      $grpc.ServiceCall call, $0.PauseTemplateRequest request);

  $async.Future<$0.TemplateResponse> resumeTransactionTemplate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ResumeTemplateRequest> $request) async {
    return resumeTransactionTemplate($call, await $request);
  }

  $async.Future<$0.TemplateResponse> resumeTransactionTemplate(
      $grpc.ServiceCall call, $0.ResumeTemplateRequest request);

  $async.Future<$0.TemplateResponse> getTransactionTemplate_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.GetTemplateRequest> $request) async {
    return getTransactionTemplate($call, await $request);
  }

  $async.Future<$0.TemplateResponse> getTransactionTemplate(
      $grpc.ServiceCall call, $0.GetTemplateRequest request);

  $async.Future<$0.ListTemplatesResponse> listTransactionTemplates_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.ListTemplatesRequest> $request) async {
    return listTransactionTemplates($call, await $request);
  }

  $async.Future<$0.ListTemplatesResponse> listTransactionTemplates(
      $grpc.ServiceCall call, $0.ListTemplatesRequest request);
}
