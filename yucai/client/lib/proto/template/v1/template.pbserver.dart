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

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;

import 'template.pb.dart' as $3;
import 'template.pbjson.dart';

export 'template.pb.dart';

abstract class TransactionTemplateServiceBase extends $pb.GeneratedService {
  $async.Future<$3.TemplateResponse> createTransactionTemplate(
      $pb.ServerContext ctx, $3.CreateTemplateRequest request);
  $async.Future<$3.TemplateResponse> updateTransactionTemplate(
      $pb.ServerContext ctx, $3.UpdateTemplateRequest request);
  $async.Future<$2.Empty> deleteTransactionTemplate(
      $pb.ServerContext ctx, $3.DeleteTemplateRequest request);
  $async.Future<$3.TemplateResponse> pauseTransactionTemplate(
      $pb.ServerContext ctx, $3.PauseTemplateRequest request);
  $async.Future<$3.TemplateResponse> resumeTransactionTemplate(
      $pb.ServerContext ctx, $3.ResumeTemplateRequest request);
  $async.Future<$3.TemplateResponse> getTransactionTemplate(
      $pb.ServerContext ctx, $3.GetTemplateRequest request);
  $async.Future<$3.ListTemplatesResponse> listTransactionTemplates(
      $pb.ServerContext ctx, $3.ListTemplatesRequest request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'CreateTransactionTemplate':
        return $3.CreateTemplateRequest();
      case 'UpdateTransactionTemplate':
        return $3.UpdateTemplateRequest();
      case 'DeleteTransactionTemplate':
        return $3.DeleteTemplateRequest();
      case 'PauseTransactionTemplate':
        return $3.PauseTemplateRequest();
      case 'ResumeTransactionTemplate':
        return $3.ResumeTemplateRequest();
      case 'GetTransactionTemplate':
        return $3.GetTemplateRequest();
      case 'ListTransactionTemplates':
        return $3.ListTemplatesRequest();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'CreateTransactionTemplate':
        return createTransactionTemplate(
            ctx, request as $3.CreateTemplateRequest);
      case 'UpdateTransactionTemplate':
        return updateTransactionTemplate(
            ctx, request as $3.UpdateTemplateRequest);
      case 'DeleteTransactionTemplate':
        return deleteTransactionTemplate(
            ctx, request as $3.DeleteTemplateRequest);
      case 'PauseTransactionTemplate':
        return pauseTransactionTemplate(
            ctx, request as $3.PauseTemplateRequest);
      case 'ResumeTransactionTemplate':
        return resumeTransactionTemplate(
            ctx, request as $3.ResumeTemplateRequest);
      case 'GetTransactionTemplate':
        return getTransactionTemplate(ctx, request as $3.GetTemplateRequest);
      case 'ListTransactionTemplates':
        return listTransactionTemplates(
            ctx, request as $3.ListTemplatesRequest);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json =>
      TransactionTemplateServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => TransactionTemplateServiceBase$messageJson;
}
