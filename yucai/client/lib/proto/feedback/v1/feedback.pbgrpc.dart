// This is a generated file - do not edit.
//
// Generated from feedback/v1/feedback.proto.

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

import 'feedback.pb.dart' as $0;

export 'feedback.pb.dart';

/// FeedbackService collects in-app user feedback (issue / idea / other).
/// SubmitFeedback is an ANONYMOUS endpoint: no authorization metadata is
/// required (guest mode must be able to report problems), so the server's
/// auth interceptor explicitly allowlists this method. Abuse is bounded by a
/// per-IP rate limit enforced in the handler.
@$pb.GrpcServiceName('yucai.feedback.v1.FeedbackService')
class FeedbackServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  FeedbackServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.SubmitFeedbackResponse> submitFeedback(
    $0.SubmitFeedbackRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$submitFeedback, request, options: options);
  }

  // method descriptors

  static final _$submitFeedback =
      $grpc.ClientMethod<$0.SubmitFeedbackRequest, $0.SubmitFeedbackResponse>(
          '/yucai.feedback.v1.FeedbackService/SubmitFeedback',
          ($0.SubmitFeedbackRequest value) => value.writeToBuffer(),
          $0.SubmitFeedbackResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.feedback.v1.FeedbackService')
abstract class FeedbackServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.feedback.v1.FeedbackService';

  FeedbackServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.SubmitFeedbackRequest,
            $0.SubmitFeedbackResponse>(
        'SubmitFeedback',
        submitFeedback_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SubmitFeedbackRequest.fromBuffer(value),
        ($0.SubmitFeedbackResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.SubmitFeedbackResponse> submitFeedback_Pre(
      $grpc.ServiceCall $call,
      $async.Future<$0.SubmitFeedbackRequest> $request) async {
    return submitFeedback($call, await $request);
  }

  $async.Future<$0.SubmitFeedbackResponse> submitFeedback(
      $grpc.ServiceCall call, $0.SubmitFeedbackRequest request);
}
