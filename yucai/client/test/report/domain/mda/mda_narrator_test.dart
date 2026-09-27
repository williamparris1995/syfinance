import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_narrator.dart';

import 'mda_fixtures.dart';

/// F44 T1:narrative port(FR-5/ADR-5)——AI 预留接口。
///
/// NoopMdaNarrator 为默认绑定:返回空串(叙述章节归 F46,本期不渲染,
/// 避免 UI 空占位)。
void main() {
  test('NoopMdaNarrator 对任意输入返回空串(FR-5 默认绑定)', () async {
    const narrator = NoopMdaNarrator();
    final doc = mdaDoc(incomeCents: 1_000_000, expenseCents: 1_200_000);
    const findings = [
      MdaFinding(
        ruleId: 'R1',
        severity: MdaSeverity.risk,
        conclusion: '本期透支',
        advice: '压减支出',
      ),
    ];

    final text = await narrator.narrate(doc, findings);

    expect(text, '');
  });

  test('NoopMdaNarrator 是 MdaNarrator 的实现(注入缝类型契约)', () {
    const MdaNarrator narrator = NoopMdaNarrator();

    expect(narrator, isA<MdaNarrator>());
  });
}
