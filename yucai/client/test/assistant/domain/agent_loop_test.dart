import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';

/// F64 T1:事件流五态 + LLM 流缝 chunk/请求形状(轻量构造契约)。
/// 循环编排行为(工具往返/自纠上限)属 T2 data 层 mock 回放测试范围。
void main() {
  group('AssistantEvent', () {
    test('TextDelta carries delta string', () {
      const event = TextDelta('你好');
      expect(event.delta, '你好');
    });

    test('ToolCallStart carries id and name', () {
      const event = ToolCallStart('call_001', 'networth_snapshot');
      expect(event.id, 'call_001');
      expect(event.name, 'networth_snapshot');
    });

    test('ToolCallEnd carries id and ok flag', () {
      const ok = ToolCallEnd('call_001', true);
      const failed = ToolCallEnd('call_002', false);
      expect(ok.ok, isTrue);
      expect(failed.ok, isFalse);
      expect(failed.id, 'call_002');
    });

    test('Done is a value, AssistantError carries message', () {
      const done = Done();
      const error = AssistantError('assistant endpoint not configured');
      expect(done, isA<Done>());
      expect(error.message, 'assistant endpoint not configured');
    });

    test('sealed hierarchy covers exactly the seven states', () {
      // 穷尽 switch 可编译即穷尽性证明(新增态会编译失败钉住契约)。
      // F70-T2:六态 = 五态 + WriteProposed(写提案,确认门数据面)。
      // F70-T3:七态 = 六态 + ToolGuidance(查无实体引导,v20 V4)。
      String describe(AssistantEvent event) => switch (event) {
            TextDelta(:final delta) => 'text:$delta',
            ToolCallStart(:final id, :final name) => 'start:$id:$name',
            ToolCallEnd(:final id, :final ok) => 'end:$id:$ok',
            WriteProposed(:final toolName) => 'proposed:$toolName',
            ToolGuidance(:final hint) => 'guidance:$hint',
            Done() => 'done',
            AssistantError(:final message) => 'error:$message',
          };

      expect(describe(const TextDelta('hi')), 'text:hi');
      expect(describe(const Done()), 'done');
      expect(
        describe(const AssistantError('boom')),
        'error:boom',
      );
      expect(
        describe(const WriteProposed('transaction_add',
            TransactionDelete(transactionId: 't'), <String, Object>{})),
        'proposed:transaction_add',
      );
    });
  });

  group('LlmChunk', () {
    test('TextChunk carries delta', () {
      const chunk = TextChunk('world');
      expect(chunk.delta, 'world');
    });

    test('ToolCallDelta carries index with optional fragments', () {
      const head = ToolCallDelta(0, id: 'call_001', name: 'networth_snapshot');
      expect(head.index, 0);
      expect(head.id, 'call_001');
      expect(head.name, 'networth_snapshot');
      expect(head.argsDelta, isNull);

      const body = ToolCallDelta(0, argsDelta: '{"base');
      expect(body.id, isNull);
      expect(body.argsDelta, '{"base');
    });

    test('Finish carries reason', () {
      const chunk = Finish('tool_calls');
      expect(chunk.reason, 'tool_calls');
    });

    test('sealed hierarchy covers exactly the three chunks', () {
      String describe(LlmChunk chunk) => switch (chunk) {
            TextChunk(:final delta) => 't:$delta',
            ToolCallDelta(:final index) => 'c:$index',
            Finish(:final reason) => 'f:$reason',
          };

      expect(describe(const TextChunk('a')), 't:a');
      expect(describe(const ToolCallDelta(1)), 'c:1');
      expect(describe(const Finish('stop')), 'f:stop');
    });
  });

  group('LlmChatRequest / LlmStreamClient port', () {
    test('request carries model, messages and tools schema', () {
      const request = LlmChatRequest(
        model: 'glm-4-plus',
        messages: [
          {'role': 'user', 'content': 'hi'},
        ],
        toolsSchema: [],
      );
      expect(request.model, 'glm-4-plus');
      expect(request.messages.single['role'], 'user');
      expect(request.toolsSchema, isEmpty);
    });

    test('fake stream client satisfies the port (mock seam, NFR-4)', () async {
      final chunks = Stream<LlmChunk>.fromIterable([
        const ToolCallDelta(0, id: 'call_1', name: 'networth_snapshot'),
        const ToolCallDelta(0, argsDelta: '{}'),
        const Finish('tool_calls'),
      ]);
      final client = _FakeStreamClient(chunks);

      final emitted = await client.chat(const LlmChatRequest(
        model: 'm',
        messages: [],
        toolsSchema: [],
      )).toList();

      expect(emitted, hasLength(3));
      expect(emitted.last, isA<Finish>());
    });
  });
}

/// 最小 fake(仅证明 port 可实现、可回放;T2 mock 回放测试另做)。
class _FakeStreamClient implements LlmStreamClient {
  _FakeStreamClient(this._chunks);

  final Stream<LlmChunk> _chunks;

  @override
  Stream<LlmChunk> chat(LlmChatRequest req) => _chunks;
}
