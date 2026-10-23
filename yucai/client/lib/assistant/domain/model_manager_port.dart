/// F67 端侧模型管理 —— 模型管理 port + 钉死清单(FR-1..4;ADR-2/ADR-4)。
///
/// 消费面:F65(订阅 [ModelManagerPort.state] 渲染下载进度卡/引导态)与
/// T2 ModelManagerImpl(`@LazySingleton(as: ModelStore)` 双面,ADR-2:
/// ModelStore port 形状不变,F66 简版实现退役)。响应式形态照
/// EngineManager 家法:[state] 为 [ValueListenable] —— 当前态缓存 +
/// 转移即通知,任意时刻订阅立即读到当前值(ADR-7 多播语义)。
library;

import 'package:flutter/foundation.dart';

import 'model_state.dart';

/// 端侧模型(.gguf)下载/生命周期管理 port(实现 = T2 ModelManagerImpl;
/// 单测/集成测经 fake 注入,NFR 注入缝)。
abstract class ModelManagerPort {
  /// 确保模型就绪(状态守卫,LLD):NotDownloaded/Error → 下载(官方源
  /// 一次回落镜像,ADR-4);Paused → .part 续传(Range 请求);
  /// Downloading/Ready → no-op。
  Future<void> download();

  /// 暂停当前下载:断开流、保 .part → [ModelPaused];非下载态 no-op。
  void pause();

  /// 取消当前下载:断流 + 删 .part → [ModelNotDownloaded];非下载态
  /// no-op。
  void cancel();

  /// 删除模型(.gguf 与 .part):在途下载先 cancel,await 引擎 shutdown
  /// 联动(ADR-5,shutdown 幂等)→ [ModelNotDownloaded]。
  Future<void> delete();

  /// 模型状态(当前态缓存 + 转移通知;F65 订阅渲染,FR-1..4)。
  ValueListenable<ModelState> get state;

  /// 模型磁盘占用字节(.gguf + .part 之和;占用展示/删除确认消费)。
  Future<int> diskUsageBytes();

  /// 四钉死清单(ADR-4 单点常量,[kModelManifest])。
  ModelManifest get manifest;
}

/// 模型四钉死清单:仓库/文件名/sha256/总字节数(fetch_engine.py 先例;
/// ADR-4:URL 模板 + 此清单 = 完整下载源,单点维护,镜像源同构同值)。
class ModelManifest {
  const ModelManifest({
    required this.repo,
    required this.file,
    required this.sha256,
    required this.totalBytes,
  });

  /// Hugging Face 仓库名(官方域名模板与 hf-mirror 同用,ADR-4)。
  final String repo;

  /// GGUF 文件名(resolve/main/<file>)。
  final String file;

  /// 期望 sha256(T2 流式校验基准;不符不落地,ADR-3)。
  final String sha256;

  /// 期望总字节数(Range 续传基数/进度分母)。
  final int totalBytes;

  @override
  bool operator ==(Object other) =>
      other is ModelManifest &&
      other.repo == repo &&
      other.file == file &&
      other.sha256 == sha256 &&
      other.totalBytes == totalBytes;

  @override
  int get hashCode =>
      Object.hash(ModelManifest, repo, file, sha256, totalBytes);

  @override
  String toString() =>
      'ModelManifest(repo=$repo, file=$file, sha256=$sha256, '
      'totalBytes=$totalBytes)';
}

/// 唯一分发模型的钉死清单(Qwen3-4B-Instruct-2507 Q4_K_M)。
///
/// 查证记录(2026-10-23,T1 执行期):
/// - 简报原定仓 `Qwen/Qwen3-4B-Instruct-2507-GGUF` 不存在(HTTP 404;
///   Qwen 官方组织未发布任何 2507 系列 GGUF,检索自
///   https://huggingface.co/api/models?author=Qwen&search=GGUF)。
///   按简报「执行期以官方仓实名为准」采用 base_model 指向
///   Qwen/Qwen3-4B-Instruct-2507 的权威量化仓 unsloth(Qwen 社区默认
///   分发点,修正 llama.cpp/Ollama 聊天模板)。
/// - file/sha256/totalBytes 取自 Hugging Face API LFS 元数据
///   https://huggingface.co/api/models/unsloth/Qwen3-4B-Instruct-2507-GGUF?blobs=true
///   (Qwen3-4B-Instruct-2507-Q4_K_M.gguf: size=2497281120,
///   lfs.sha256=3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597)
///   并经直链 HEAD 交叉验证(X-Linked-Size 与 CDN content-length 同为
///   2497281120;LFS ETag 即 sha256 同值):
///   https://huggingface.co/unsloth/Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen3-4B-Instruct-2507-Q4_K_M.gguf
const kModelManifest = ModelManifest(
  repo: 'unsloth/Qwen3-4B-Instruct-2507-GGUF',
  file: 'Qwen3-4B-Instruct-2507-Q4_K_M.gguf',
  // TODO(F67-T3): 发布前首下实测复核(流式 sha256 与此值一致性冒烟)。
  sha256: '3605803b982cb64aead44f6c1b2ae36e3acdb41d8e46c8a94c6533bc4c67e597',
  totalBytes: 2497281120,
);
