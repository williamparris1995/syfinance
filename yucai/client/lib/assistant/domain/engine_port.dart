/// F66 引擎边车 —— 引擎管理 port(FR-1/FR-3;ADR-1/ADR-5)。
///
/// 消费面:F65(打开浮层即调 [ensureReady] 预热 = ADR-1,加载动效消费
/// starting 态)与 T3 LlmStreamClient 接线(请求前兜底 ensureReady + 从
/// Ready 态取端点)。响应式形态照 LlmSettings 家法:[state] 为
/// [ValueListenable] —— 当前态缓存 + 转移即通知,任意时刻订阅立即读到
/// 当前值、后续转移不漏(ADR-5 多播语义)。
library;

import 'package:flutter/foundation.dart';

import 'engine_state.dart';

/// llama-server 边车生命周期管理 port(实现 = T2 EngineManagerImpl;
/// 单测/冒烟经 fake 注入,NFR-2 注入缝)。
abstract class EngineManager {
  /// 确保引擎就绪(幂等):Stopped/Error → 走拉起流程(端口扫描→
  /// 启动→健康轮询);Starting → 等待既有启动 Future;Ready → 即返。
  /// 模型缺失 → EngineError(modelMissing),不起进程(FR-1/FR-2)。
  Future<void> ensureReady();

  /// 停止引擎并终结进程树(闲置回收与 app 退出钩子共用;ADR-3)。
  Future<void> shutdown();

  /// 请求开始标记(T5 自 impl 上提 port;FR-1 活跃计数):流开始时调,
  /// 顺延闲置回收窗口 —— 引擎不回收进行中的流。
  void beginActivity();

  /// 请求结束标记:流关闭(含异常路径)时调;活跃归零后闲置回收恢复
  /// 生效。实现须保证与 [beginActivity] 可安全配对(异常路径由调用方
  /// finally 兜底)。
  void endActivity();

  /// 引擎状态(当前态缓存 + 转移通知;F65 订阅渲染,FR-3)。
  ValueListenable<EngineState> get state;
}
