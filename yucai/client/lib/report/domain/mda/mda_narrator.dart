/// F44 规则诊断引擎 —— narrative port(FR-5/ADR-5,AI 预留接口)。
///
/// 输入 = 报告快照 + 发现列表,输出 = 叙述文本(MD&A 总评段);
/// F46(BYOK LLM 分析师)接真实现 [MdaNarrator] 主绑定 =
/// report/data/llm 的 LlmMdaNarrator(未启用/未配置 → 空串,降级语义
/// 内化);[NoopMdaNarrator] 类保留作测试替身/降级语义文档,注册由
/// build_runner regen 移除(ADR-3)。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// 叙事者抽象:把 Findings 综合成自然语言总评。
abstract class MdaNarrator {
  const MdaNarrator();

  /// 生成叙述文本;失败(网络/HTTP/解析)抛 [NarrationFailure]。
  Future<String> narrate(ReportDocument doc, List<MdaFinding> findings);
}

/// narrate 失败(F46 FR-3:超时/HTTP 错误/响应解析失败)。
///
/// 消息**只含状态码 + 端点域名 + 错误类**,零 API Key 零完整 payload
/// (FR-5 隐私红线);放在 domain port 侧 = 报告页(T2)按 domain 类型
/// 捕获,无需 import data 层。
class NarrationFailure implements Exception {
  const NarrationFailure(this.message);

  /// 已脱敏的人读消息(如「HTTP 401(open.bigmodel.cn)」)。
  final String message;

  @override
  String toString() => message;
}

/// 空实现(降级语义文档 + F44 测试替身):恒返回空串(渲染层据空串
/// 隐藏叙述段)。F46 起不再注册进 DI 图(主绑定 = LlmMdaNarrator)。
class NoopMdaNarrator implements MdaNarrator {
  const NoopMdaNarrator();

  @override
  Future<String> narrate(ReportDocument doc, List<MdaFinding> findings) async {
    return '';
  }
}
