/// F66 引擎边车 —— 本地模型存储简版实现(FR-2;ADR-7)。
///
/// 固定路径存在性检查:`<应用数据目录>/yucai/models/<defaultModel>.gguf`;
/// 应用数据目录获取缝 [ModelStoreImpl.supportDirFn] 缺省 path_provider
/// getApplicationSupportDirectory(照 LocalSnapshotService.supportDirFn
/// 先例),单测注 temp 目录零真 AppData 触碰(NFR-2 注入缝)。F67 将把
/// 实现替换为下载管理(下载/校验/版本),port 形状不变 —— 消费方零改动
/// = ADR-7。
library;

import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/assistant_settings.dart';
import '../domain/model_store_port.dart';

/// ModelStore 简版生产绑定(ADR-7;DI 手工接线归 injection.dart 1m)。
@LazySingleton(as: ModelStore)
class ModelStoreImpl implements ModelStore {
  ModelStoreImpl({Future<Directory> Function()? supportDirFn})
      : _supportDir = supportDirFn ?? getApplicationSupportDirectory;

  /// 应用数据目录获取缝(缺省 path_provider;测试注入 temp 目录)。
  final Future<Directory> Function() _supportDir;

  /// 模型落位子路径(ADR-7 固定 `yucai/models/`;文件名单一事实源 =
  /// [AssistantConfig.defaultModel],F67 多模型在此扩展)。
  static const List<String> _segments = ['yucai', 'models'];

  @override
  Future<String?> modelPath() async {
    final root = await _supportDir();
    final file = File(
      [
        root.path,
        ..._segments,
        '${AssistantConfig.defaultModel}.gguf',
      ].join(Platform.pathSeparator),
    );
    // 存在性检查非下载:缺失 → null 且零副作用(不建目录;引擎侧据此判
    // modelMissing,FR-2),创建语义归 F67。
    return await file.exists() ? file.path : null;
  }

  @override
  Future<bool> isReady() async => await modelPath() != null;
}
