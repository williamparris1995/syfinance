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

import 'package:protobuf/protobuf.dart' as $pb;
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart' as $2;

import 'backup.pb.dart' as $3;
import 'backup.pbjson.dart';

export 'backup.pb.dart';

abstract class BackupServiceBase extends $pb.GeneratedService {
  $async.Future<$3.BackupResponse> createBackup(
      $pb.ServerContext ctx, $3.CreateBackupRequest request);
  $async.Future<$2.Empty> restoreBackup(
      $pb.ServerContext ctx, $3.RestoreBackupRequest request);
  $async.Future<$3.ListBackupsResponse> listBackups(
      $pb.ServerContext ctx, $3.ListBackupsRequest request);
  $async.Future<$2.Empty> deleteBackup(
      $pb.ServerContext ctx, $3.DeleteBackupRequest request);
  $async.Future<$2.Empty> saveCloudSettings(
      $pb.ServerContext ctx, $3.SaveCloudSettingsRequest request);
  $async.Future<$3.CloudSettingsResponse> getCloudSettings(
      $pb.ServerContext ctx, $2.Empty request);

  $pb.GeneratedMessage createRequest($core.String methodName) {
    switch (methodName) {
      case 'CreateBackup':
        return $3.CreateBackupRequest();
      case 'RestoreBackup':
        return $3.RestoreBackupRequest();
      case 'ListBackups':
        return $3.ListBackupsRequest();
      case 'DeleteBackup':
        return $3.DeleteBackupRequest();
      case 'SaveCloudSettings':
        return $3.SaveCloudSettingsRequest();
      case 'GetCloudSettings':
        return $2.Empty();
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $async.Future<$pb.GeneratedMessage> handleCall($pb.ServerContext ctx,
      $core.String methodName, $pb.GeneratedMessage request) {
    switch (methodName) {
      case 'CreateBackup':
        return createBackup(ctx, request as $3.CreateBackupRequest);
      case 'RestoreBackup':
        return restoreBackup(ctx, request as $3.RestoreBackupRequest);
      case 'ListBackups':
        return listBackups(ctx, request as $3.ListBackupsRequest);
      case 'DeleteBackup':
        return deleteBackup(ctx, request as $3.DeleteBackupRequest);
      case 'SaveCloudSettings':
        return saveCloudSettings(ctx, request as $3.SaveCloudSettingsRequest);
      case 'GetCloudSettings':
        return getCloudSettings(ctx, request as $2.Empty);
      default:
        throw $core.ArgumentError('Unknown method: $methodName');
    }
  }

  $core.Map<$core.String, $core.dynamic> get $json => BackupServiceBase$json;
  $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>>
      get $messageJson => BackupServiceBase$messageJson;
}
