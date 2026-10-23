import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/data/audit_log.dart';

/// F64 T4:审计日志(FR-5)——行格式 + ASCII 门(日志串无 CJK,grep 门禁)。
void main() {
  // 收集缝:注入 list 收集器替代 debugPrint,断言不依赖控制台。
  final lines = <String>[];
  late final AssistantAuditLog audit =
      AssistantAuditLog(log: lines.add);

  setUp(lines.clear);

  group('logToolCall', () {
    test('ok line format with args summary', () {
      audit.logToolCall(
        name: 'networth_snapshot',
        ok: true,
        ms: 42,
        argsSummary: 'base=CNY',
      );
      expect(lines.single, 'assistant tool=networth_snapshot status=ok '
          'ms=42 args=base=CNY');
    });

    test('error line format, args defaults to empty', () {
      audit.logToolCall(name: 'debts_list', ok: false, ms: 7);
      expect(
        lines.single,
        'assistant tool=debts_list status=error ms=7 args=',
      );
    });

    test('bool maps to ok/error wording', () {
      audit.logToolCall(name: 'a', ok: true, ms: 1);
      audit.logToolCall(name: 'b', ok: false, ms: 2);
      expect(lines[0], contains(' status=ok '));
      expect(lines[1], contains(' status=error '));
    });
  });

  group('logLlm', () {
    test('llm line format', () {
      audit.logLlm(host: 'open.bigmodel.cn', ms: 1203, model: 'glm-4-plus');
      expect(
        lines.single,
        'assistant llm host=open.bigmodel.cn ms=1203 model=glm-4-plus',
      );
    });
  });

  group('ASCII gate', () {
    test('CJK chars in argsSummary are stripped', () {
      audit.logToolCall(
        name: 'accounts_list',
        ok: true,
        ms: 5,
        argsSummary: 'kind=credit note=中文备注 page=2',
      );
      // 非 ASCII(中文)剔除,ASCII 骨架保留;整行仍纯 ASCII 可 grep。
      expect(lines.single, 'assistant tool=accounts_list status=ok '
          "ms=5 args=kind=credit note= page=2");
    });

    test('CJK model name is stripped (model is user input)', () {
      audit.logLlm(host: 'localhost', ms: 3, model: '模型abc');
      expect(lines.single, 'assistant llm host=localhost ms=3 model=abc');
    });

    test('newline in argsSummary cannot break the single-line format', () {
      audit.logToolCall(
        name: 't',
        ok: true,
        ms: 1,
        argsSummary: 'a=1\nb=2',
      );
      expect(lines.single, 'assistant tool=t status=ok ms=1 args=a=1b=2');
    });

    test('every emitted line is pure printable ASCII', () {
      audit.logToolCall(
        name: 'networth_snapshot',
        ok: true,
        ms: 9,
        argsSummary: 'x=中文y',
      );
      audit.logLlm(host: '本地host', ms: 1, model: 'glm');
      for (final line in lines) {
        expect(
          line.codeUnits.every((c) => c >= 0x20 && c <= 0x7E),
          isTrue,
          reason: 'line must be printable ASCII: $line',
        );
      }
    });
  });
}
