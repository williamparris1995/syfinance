/// F44 规则诊断引擎 —— 规则接口(FR-1,纯 domain port)。
library;

import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// MD&A 规则抽象:输入 = 报告快照 + 补充输入,输出 = 发现列表
/// (可为空 = 本规则未触发)。规则实现须无状态、纯函数式。
abstract class MdaRule {
  const MdaRule();

  /// 规则标识(如 'R1'),进 [MdaFinding.ruleId] 供渲染溯源。
  String get id;

  /// 对一份报告快照执行诊断。
  List<MdaFinding> evaluate(ReportDocument doc, MdaSupplement sup);
}
