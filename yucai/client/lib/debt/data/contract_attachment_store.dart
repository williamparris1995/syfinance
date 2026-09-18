// 合同文件附件本地存储(2026-09 用户需求,v1)。
//
// 设计要点:
//  - **选中即暂存**:file_picker 返回的源路径可能是临时文件(选完对话框关闭
//    即失效),故表单选中时立刻复制一份到 `<appSupport>/contract_files/staged/`;
//    提交成功后再 `bind` 到债务 id(移动到 `debts/<debtId>/` + upsert 行)。
//  - **一债务一附件**:再选 = 替换(bind 先清旧行/旧文件)。
//  - **v1 不上行**:行与文件均为设备本地(guest/bound 一致),换设备不跟随;
//    服务端 blob 上行为后续票。行随债务 FK 级联删除,文件在 remove/bind 时清理。
import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;

/// 表单暂存中的合同文件(尚未绑定债务 id)。
class StagedContractFile {
  const StagedContractFile({
    required this.stagedPath,
    required this.originalName,
    required this.sizeBytes,
  });

  final String stagedPath;
  final String originalName;
  final int sizeBytes;
}

/// 已绑定债务的合同附件元数据(详情页展示用)。
class ContractAttachment {
  const ContractAttachment({
    required this.id,
    required this.debtId,
    required this.originalName,
    required this.storedName,
    required this.sizeBytes,
    required this.attachedAt,
  });

  final String id;
  final String debtId;
  final String originalName;
  final String storedName;
  final int sizeBytes;
  final DateTime attachedAt;
}

@LazySingleton()
class ContractAttachmentStore {
  ContractAttachmentStore(this._db, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase _db;
  final Uuid _uuid;

  /// 表单选中文件后立刻调用:复制源文件到暂存区,返回暂存描述。
  /// 源文件可能稍后失效,后续 bind 只用 [StagedContractFile.stagedPath]。
  Future<StagedContractFile> stage(String sourcePath, String originalName) async {
    final stagedDir = await _stagedDir();
    final stagedName = '${_uuid.v4()}${p.extension(originalName)}';
    final stagedPath = p.join(stagedDir.path, stagedName);
    await File(sourcePath).copy(stagedPath);
    return StagedContractFile(
      stagedPath: stagedPath,
      originalName: originalName,
      sizeBytes: await File(stagedPath).length(),
    );
  }

  /// 绑定到债务(创建成功/编辑提交后调用):暂存文件移动到
  /// `debts/<debtId>/` + upsert 行;已有附件(行+文件)被替换清理。
  /// staged == null 为 no-op(未选择文件)。
  Future<void> bind(String debtId, StagedContractFile? staged) async {
    if (staged == null) return;
    final dir = await _debtDir(debtId);
    final storedName = '${_uuid.v4()}${p.extension(staged.originalName)}';
    final storedPath = p.join(dir.path, storedName);
    try {
      await File(staged.stagedPath).rename(storedPath);
    } on FileSystemException {
      // rename 跨卷/被占用失败 → 回退 copy + 删源(同效果,慢一点)。
      await File(staged.stagedPath).copy(storedPath);
      try {
        await File(staged.stagedPath).delete();
      } catch (_) {}
    }
    // 先删旧附件(行 + 文件),再落新行。
    await _deleteRowAndFile(debtId);
    await _db
        .into(_db.contractAttachments)
        .insert(db.ContractAttachmentsCompanion.insert(
          id: _uuid.v4(),
          debtId: debtId,
          originalName: staged.originalName,
          storedName: storedName,
          sizeBytes: staged.sizeBytes,
          attachedAt: DateTime.now().toUtc(),
        ));
  }

  /// 移除债务的附件(行 + 文件)。无附件时 no-op。
  Future<void> remove(String debtId) => _deleteRowAndFile(debtId);

  /// 读取债务当前附件(详情页)。
  Future<ContractAttachment?> forDebt(String debtId) async {
    final row = await (_db.select(_db.contractAttachments)
          ..where((t) => t.debtId.equals(debtId)))
        .getSingleOrNull();
    if (row == null) return null;
    return ContractAttachment(
      id: row.id,
      debtId: row.debtId,
      originalName: row.originalName,
      storedName: row.storedName,
      sizeBytes: row.sizeBytes,
      attachedAt: row.attachedAt,
    );
  }

  /// 附件落盘绝对路径(打开文件用)。文件缺失时仍返回推导路径,调用方
  /// existsSync 判定后提示。
  Future<String> absolutePath(ContractAttachment a) async =>
      p.join((await _debtDir(a.debtId)).path, a.storedName);

  Future<Directory> _stagedDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, 'contract_files', 'staged'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> _debtDir(String debtId) async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(
        p.join(root.path, 'contract_files', 'debts', debtId));
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _deleteRowAndFile(String debtId) async {
    final row = await (_db.select(_db.contractAttachments)
          ..where((t) => t.debtId.equals(debtId)))
        .getSingleOrNull();
    if (row != null) {
      await (_db.delete(_db.contractAttachments)
            ..where((t) => t.id.equals(row.id)))
          .go();
      final file = File(p.join((await _debtDir(debtId)).path, row.storedName));
      if (await file.exists()) await file.delete();
    }
  }
}
