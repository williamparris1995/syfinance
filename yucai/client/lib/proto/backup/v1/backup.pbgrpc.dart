// This is a generated file - do not edit.
//
// Generated from backup/v1/backup.proto.

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

import 'backup.pb.dart' as $0;

export 'backup.pb.dart';

@$pb.GrpcServiceName('yucai.backup.v1.BackupService')
class BackupServiceClient extends $grpc.Client {
  /// The hostname for this service.
  static const $core.String defaultHost = '';

  /// OAuth scopes needed for the client.
  static const $core.List<$core.String> oauthScopes = [
    '',
  ];

  BackupServiceClient(super.channel, {super.options, super.interceptors});

  $grpc.ResponseFuture<$0.BackupResponse> createBackup(
    $0.CreateBackupRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$createBackup, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> restoreBackup(
    $0.RestoreBackupRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$restoreBackup, request, options: options);
  }

  /// UploadBackup imports an externally-produced BackupEnvelope (R6 offline
  /// first: one-way guest → server migration on account binding). The data is
  /// a plaintext envelope JSON; the authenticated tenant OVERRIDES the
  /// envelope's tenant_id, and the import reuses the hardened purge+import
  /// path (R5 D6) with a pre-upload safety backup.
  $grpc.ResponseFuture<$1.Empty> uploadBackup(
    $0.UploadBackupRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$uploadBackup, request, options: options);
  }

  $grpc.ResponseFuture<$0.ListBackupsResponse> listBackups(
    $0.ListBackupsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$listBackups, request, options: options);
  }

  $grpc.ResponseFuture<$1.Empty> deleteBackup(
    $0.DeleteBackupRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$deleteBackup, request, options: options);
  }

  /// SaveCloudSettings / GetCloudSettings persist per-tenant auto-backup
  /// preferences. Despite the legacy "Cloud" name, only auto-backup fields are
  /// stored — cloud backup (WebDAV/providers) was removed 2026-07-25. Name kept
  /// to minimize churn.
  $grpc.ResponseFuture<$1.Empty> saveCloudSettings(
    $0.SaveCloudSettingsRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$saveCloudSettings, request, options: options);
  }

  $grpc.ResponseFuture<$0.CloudSettingsResponse> getCloudSettings(
    $1.Empty request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$getCloudSettings, request, options: options);
  }

  // method descriptors

  static final _$createBackup =
      $grpc.ClientMethod<$0.CreateBackupRequest, $0.BackupResponse>(
          '/yucai.backup.v1.BackupService/CreateBackup',
          ($0.CreateBackupRequest value) => value.writeToBuffer(),
          $0.BackupResponse.fromBuffer);
  static final _$restoreBackup =
      $grpc.ClientMethod<$0.RestoreBackupRequest, $1.Empty>(
          '/yucai.backup.v1.BackupService/RestoreBackup',
          ($0.RestoreBackupRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$uploadBackup =
      $grpc.ClientMethod<$0.UploadBackupRequest, $1.Empty>(
          '/yucai.backup.v1.BackupService/UploadBackup',
          ($0.UploadBackupRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$listBackups =
      $grpc.ClientMethod<$0.ListBackupsRequest, $0.ListBackupsResponse>(
          '/yucai.backup.v1.BackupService/ListBackups',
          ($0.ListBackupsRequest value) => value.writeToBuffer(),
          $0.ListBackupsResponse.fromBuffer);
  static final _$deleteBackup =
      $grpc.ClientMethod<$0.DeleteBackupRequest, $1.Empty>(
          '/yucai.backup.v1.BackupService/DeleteBackup',
          ($0.DeleteBackupRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$saveCloudSettings =
      $grpc.ClientMethod<$0.SaveCloudSettingsRequest, $1.Empty>(
          '/yucai.backup.v1.BackupService/SaveCloudSettings',
          ($0.SaveCloudSettingsRequest value) => value.writeToBuffer(),
          $1.Empty.fromBuffer);
  static final _$getCloudSettings =
      $grpc.ClientMethod<$1.Empty, $0.CloudSettingsResponse>(
          '/yucai.backup.v1.BackupService/GetCloudSettings',
          ($1.Empty value) => value.writeToBuffer(),
          $0.CloudSettingsResponse.fromBuffer);
}

@$pb.GrpcServiceName('yucai.backup.v1.BackupService')
abstract class BackupServiceBase extends $grpc.Service {
  $core.String get $name => 'yucai.backup.v1.BackupService';

  BackupServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.CreateBackupRequest, $0.BackupResponse>(
        'CreateBackup',
        createBackup_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.CreateBackupRequest.fromBuffer(value),
        ($0.BackupResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.RestoreBackupRequest, $1.Empty>(
        'RestoreBackup',
        restoreBackup_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.RestoreBackupRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.UploadBackupRequest, $1.Empty>(
        'UploadBackup',
        uploadBackup_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.UploadBackupRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod(
        $grpc.ServiceMethod<$0.ListBackupsRequest, $0.ListBackupsResponse>(
            'ListBackups',
            listBackups_Pre,
            false,
            false,
            ($core.List<$core.int> value) =>
                $0.ListBackupsRequest.fromBuffer(value),
            ($0.ListBackupsResponse value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.DeleteBackupRequest, $1.Empty>(
        'DeleteBackup',
        deleteBackup_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.DeleteBackupRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$0.SaveCloudSettingsRequest, $1.Empty>(
        'SaveCloudSettings',
        saveCloudSettings_Pre,
        false,
        false,
        ($core.List<$core.int> value) =>
            $0.SaveCloudSettingsRequest.fromBuffer(value),
        ($1.Empty value) => value.writeToBuffer()));
    $addMethod($grpc.ServiceMethod<$1.Empty, $0.CloudSettingsResponse>(
        'GetCloudSettings',
        getCloudSettings_Pre,
        false,
        false,
        ($core.List<$core.int> value) => $1.Empty.fromBuffer(value),
        ($0.CloudSettingsResponse value) => value.writeToBuffer()));
  }

  $async.Future<$0.BackupResponse> createBackup_Pre($grpc.ServiceCall $call,
      $async.Future<$0.CreateBackupRequest> $request) async {
    return createBackup($call, await $request);
  }

  $async.Future<$0.BackupResponse> createBackup(
      $grpc.ServiceCall call, $0.CreateBackupRequest request);

  $async.Future<$1.Empty> restoreBackup_Pre($grpc.ServiceCall $call,
      $async.Future<$0.RestoreBackupRequest> $request) async {
    return restoreBackup($call, await $request);
  }

  $async.Future<$1.Empty> restoreBackup(
      $grpc.ServiceCall call, $0.RestoreBackupRequest request);

  $async.Future<$1.Empty> uploadBackup_Pre($grpc.ServiceCall $call,
      $async.Future<$0.UploadBackupRequest> $request) async {
    return uploadBackup($call, await $request);
  }

  $async.Future<$1.Empty> uploadBackup(
      $grpc.ServiceCall call, $0.UploadBackupRequest request);

  $async.Future<$0.ListBackupsResponse> listBackups_Pre($grpc.ServiceCall $call,
      $async.Future<$0.ListBackupsRequest> $request) async {
    return listBackups($call, await $request);
  }

  $async.Future<$0.ListBackupsResponse> listBackups(
      $grpc.ServiceCall call, $0.ListBackupsRequest request);

  $async.Future<$1.Empty> deleteBackup_Pre($grpc.ServiceCall $call,
      $async.Future<$0.DeleteBackupRequest> $request) async {
    return deleteBackup($call, await $request);
  }

  $async.Future<$1.Empty> deleteBackup(
      $grpc.ServiceCall call, $0.DeleteBackupRequest request);

  $async.Future<$1.Empty> saveCloudSettings_Pre($grpc.ServiceCall $call,
      $async.Future<$0.SaveCloudSettingsRequest> $request) async {
    return saveCloudSettings($call, await $request);
  }

  $async.Future<$1.Empty> saveCloudSettings(
      $grpc.ServiceCall call, $0.SaveCloudSettingsRequest request);

  $async.Future<$0.CloudSettingsResponse> getCloudSettings_Pre(
      $grpc.ServiceCall $call, $async.Future<$1.Empty> $request) async {
    return getCloudSettings($call, await $request);
  }

  $async.Future<$0.CloudSettingsResponse> getCloudSettings(
      $grpc.ServiceCall call, $1.Empty request);
}
