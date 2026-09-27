/// F44 规则诊断引擎 —— narrative port(FR-5/ADR-5,AI 预留接口)。
///
/// 输入 = 报告快照 + 发现列表,输出 = 叙述文本(MD&A 总评段);
/// 真实现归 F46(BYOK LLM 分析师,sprint-2),本期只留注入缝 +
/// [NoopMdaNarrator] 默认绑定——报告页不渲染 narrative(避免空占位)。
library;

import 'package:injectable/injectable.dart';

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// 叙事者抽象:把 Findings 综合成自然语言总评。
abstract class MdaNarrator {
  const MdaNarrator();

  /// 生成叙述文本(F46 真实现为 LLM 调用,故 Future)。
  Future<String> narrate(ReportDocument doc, List<MdaFinding> findings);
}

/// 默认空实现:恒返回空串(渲染层据空串隐藏叙述段)。
@LazySingleton(as: MdaNarrator)
class NoopMdaNarrator implements MdaNarrator {
  const NoopMdaNarrator();

  @override
  Future<String> narrate(ReportDocument doc, List<MdaFinding> findings) async {
    return '';
  }
}
