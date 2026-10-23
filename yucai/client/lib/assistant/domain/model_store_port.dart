/// F66 引擎边车 —— 本地模型存储 port(FR-2;ADR-7)。
///
/// v1 简版契约:模型文件路径 + 在位检查(实现 = 固定路径存在性,T3)。
/// F67 将把实现替换为下载管理(下载/校验/版本),本 port 形状不变 ——
/// 消费方(EngineManager 前置检查 / F65 引导态)零改动 = ADR-7。
library;

/// 本地推理模型(.gguf)位置契约。
abstract class ModelStore {
  /// 模型文件绝对路径;缺失/不可用 → null(引擎侧据此判 modelMissing,
  /// FR-2 场景:ready=false 且 EngineState 发 error(modelMissing))。
  Future<String?> modelPath();

  /// 模型就绪(文件在位;F67 起含下载完成语义)。
  Future<bool> isReady();
}
