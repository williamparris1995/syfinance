import 'package:injectable/injectable.dart';
import 'package:protobuf/well_known_types/google/protobuf/empty.pb.dart'
    as empty;

import 'package:yucai_client/backup/data/mappers/backup_mapper.dart';
import 'package:yucai_client/backup/data/mappers/backup_settings_mapper.dart';
import 'package:yucai_client/backup/domain/entities/backup_entity.dart';
import 'package:yucai_client/backup/domain/entities/backup_settings_entity.dart';
import 'package:yucai_client/core/network/auth_retry.dart';
import 'package:yucai_client/core/network/grpc_client.dart';
import 'package:yucai_client/proto/backup/v1/backup.pb.dart' as pb;
import 'package:yucai_client/proto/backup/v1/backup.pbgrpc.dart' as grpc;
import 'package:yucai_client/proto/common/v1/pagination.pb.dart' as common;

/// 封装生成的 BackupServiceClient。抛 GrpcError（由 repo 层 catch 映射）。
/// 对齐 DebtRemoteDataSource：每个 RPC 用 AuthRetryCaller 包装，401 时透明
/// 刷新 + 重试一次。
///
/// 6 个 RPC：list / create / restore / delete（本地备份）+
/// getCloudSettings / saveCloudSettings（P1 Task 5 自动备份配置）。
@LazySingleton()
class BackupRemoteDataSource {
  BackupRemoteDataSource(this._grpcClient, this._retry) {
    _client = grpc.BackupServiceClient(
      _grpcClient.channel,
      interceptors: [_grpcClient.authInterceptor],
    );
  }

  final GrpcClient _grpcClient;
  final AuthRetryCaller _retry;
  late final grpc.BackupServiceClient _client;

  /// ListBackups：只拉本地备份（provider=LOCAL，含手动 + server 自动）。
  /// pageSize 100（项目惯例，backup 少，不分页 UI）。
  Future<List<Backup>> list() async {
    return _retry.call(() async {
      final res = await _client.listBackups(pb.ListBackupsRequest(
        page: common.PageRequest(pageSize: 100),
        provider: pb.BackupProvider.BACKUP_PROVIDER_LOCAL,
      ));
      return res.backups.map(BackupMapper.toDomain).toList();
    });
  }

  /// CreateBackup：encrypted 由用户 dialog 选；加密时 password 必填。
  /// CreateBackupRequest{encrypted, password}：非加密传空串。
  Future<Backup> create({required bool encrypted, String password = ''}) async {
    return _retry.call(() async {
      final req = pb.CreateBackupRequest(encrypted: encrypted);
      if (password.isNotEmpty) req.password = password;
      final res = await _client.createBackup(req);
      return BackupMapper.toDomain(res.backup);
    });
  }

  /// RestoreBackup：加密备份需 password（用户输入），非加密传空串。
  Future<void> restore({required String id, required String password}) async {
    return _retry.call(() async {
      await _client.restoreBackup(
          pb.RestoreBackupRequest(backupId: id, password: password));
    });
  }

  /// UploadBackup (R6 feature G)：guest→server 一次性迁移，明文 envelope
  /// 经 TLS；server 以鉴权 tenant 覆盖 envelope 内 tenant_id。
  Future<void> uploadBackup(List<int> data) async {
    return _retry.call(() async {
      await _client
          .uploadBackup(pb.UploadBackupRequest(data: data, password: ''));
    });
  }

  /// DeleteBackup：按 id 删除。
  Future<void> delete(String id) async {
    return _retry.call(() async {
      await _client.deleteBackup(pb.DeleteBackupRequest(id: id));
    });
  }

  /// GetCloudSettings：拉 tenant 的 AutoBackup 配置（P1 Task 5）。
  /// 服务端在 tenant 无配置行时返回零值（autoBackup=false, interval=0），
  /// mapper 会把 interval=0 fallback 到 24h。
  Future<BackupSettings> getCloudSettings() async {
    return _retry.call(() async {
      final res = await _client.getCloudSettings(empty.Empty());
      return BackupSettingsMapper.toDomain(res.settings);
    });
  }

  /// SaveCloudSettings：保存 AutoBackup 配置（P1 Task 5）。
  /// mapper 填 AutoBackup + interval 两字段，server 持久化这两个字段
  /// （云备份 provider/webdav/oauth 字段已于 2026-07-25 从 proto 移除）。
  Future<void> saveCloudSettings(BackupSettings settings) async {
    return _retry.call(() async {
      await _client.saveCloudSettings(
        pb.SaveCloudSettingsRequest(
          settings: BackupSettingsMapper.toProto(settings),
        ),
      );
    });
  }
}
