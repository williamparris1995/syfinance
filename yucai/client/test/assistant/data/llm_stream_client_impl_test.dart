import 'package:flutter_test/flutter_test.dart';
import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:yucai_client/assistant/data/llm_stream_client_impl.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';

/// F64 T4:LlmStreamClientImpl 三个纯映射函数(ADR-3)——
/// messageFromMap / chunksFromOpenAi / buildRequest,零网络请求。
///
/// F66-T1 收窄适配:config 不再携带端点,Impl 无参构造、固定 localhost
/// 占位端点(127.0.0.1 关端口 —— 网络组用例仍零外网、就地失败);原
/// 「空端点快速失败」用例随字段退役删除(未就绪闸在 loop 层,T3 归引擎)。
void main() {
  LlmStreamClientImpl makeClient() => LlmStreamClientImpl();

  /// 造一颗流事件(单 choice 形状,OpenAI 流标准形态)。
  openai.ChatStreamEvent chunkEvent({
    String? content,
    List<openai.ToolCallDelta>? toolCalls,
    openai.FinishReason? finishReason,
  }) =>
      openai.ChatStreamEvent(
        choices: [
          openai.ChatStreamChoice(
            index: 0,
            delta: openai.ChatDelta(content: content, toolCalls: toolCalls),
            finishReason: finishReason,
          ),
        ],
      );

  group('messageFromMap', () {
    test('system message roundtrips', () {
      final client = makeClient();
      const raw = {'role': 'system', 'content': 'You are YuCai assistant.'};
      final msg = client.messageFromMap(raw);
      expect(msg, isA<openai.SystemMessage>());
      expect((msg as openai.SystemMessage).content, 'You are YuCai assistant.');
      expect(msg.toJson(), raw);
    });

    test('user message roundtrips, empty content preserved', () {
      final client = makeClient();
      const raw = {'role': 'user', 'content': 'How much do I owe?'};
      final msg = client.messageFromMap(raw);
      expect(msg, isA<openai.UserMessage>());
      expect((msg as openai.UserMessage).text, 'How much do I owe?');
      expect(msg.toJson(), raw);

      final empty = client.messageFromMap(const {
        'role': 'user',
        'content': '',
      });
      expect((empty as openai.UserMessage).text, '');
    });

    test('assistant plain content roundtrips, toolCalls null', () {
      final client = makeClient();
      const raw = {
        'role': 'assistant',
        'content': 'Your net worth is 10000.00 CNY.',
      };
      final msg = client.messageFromMap(raw);
      expect(msg, isA<openai.AssistantMessage>());
      final assistant = msg as openai.AssistantMessage;
      expect(assistant.content, 'Your net worth is 10000.00 CNY.');
      expect(assistant.toolCalls, isNull);
      expect(msg.toJson(), raw);
    });

    test('assistant with tool_calls maps to ToolCall list', () {
      final client = makeClient();
      final msg = client.messageFromMap({
        'role': 'assistant',
        'tool_calls': [
          {
            'id': 'call_001',
            'type': 'function',
            'function': {
              'name': 'networth_snapshot',
              'arguments': '{"base":"CNY"}',
            },
          },
        ],
      });
      final assistant = msg as openai.AssistantMessage;
      expect(assistant.content, isNull);
      expect(assistant.toolCalls, hasLength(1));
      final call = assistant.toolCalls!.single;
      expect(call.id, 'call_001');
      expect(call.type, 'function');
      expect(call.function.name, 'networth_snapshot');
      expect(call.function.arguments, '{"base":"CNY"}');
    });

    test('tool message maps tool_call_id + content', () {
      final client = makeClient();
      const raw = {
        'role': 'tool',
        'tool_call_id': 'call_001',
        'content': '{"netWorthCents":1000000}',
      };
      final msg = client.messageFromMap(raw);
      expect(msg, isA<openai.ToolMessage>());
      final tool = msg as openai.ToolMessage;
      expect(tool.toolCallId, 'call_001');
      expect(tool.content, '{"netWorthCents":1000000}');
      expect(msg.toJson(), raw);
    });

    test('unknown role throws self-explaining error', () {
      final client = makeClient();
      expect(
        () => client.messageFromMap(const {'role': 'wizard', 'content': 'x'}),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('wizard'),
          ),
        ),
      );
    });

    test('missing or non-string role throws self-explaining error', () {
      final client = makeClient();
      expect(
        () => client.messageFromMap(const {'content': 'x'}),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => client.messageFromMap(const {'role': 42, 'content': 'x'}),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('chunksFromOpenAi', () {
    test('content delta maps to TextChunk', () {
      final client = makeClient();
      final chunks = client.chunksFromOpenAi(
        chunkEvent(content: 'Hello'),
      );
      expect(chunks, hasLength(1));
      expect(chunks.single, isA<TextChunk>());
      expect((chunks.single as TextChunk).delta, 'Hello');
    });

    test('empty-string content delta maps to empty TextChunk', () {
      final client = makeClient();
      final chunks = client.chunksFromOpenAi(chunkEvent(content: ''));
      expect(chunks, hasLength(1));
      expect((chunks.single as TextChunk).delta, '');
    });

    test('role-only delta produces no chunks', () {
      final client = makeClient();
      expect(client.chunksFromOpenAi(chunkEvent()), isEmpty);
    });

    test('usage-only event (choices null) is ignored', () {
      final client = makeClient();
      expect(
        client.chunksFromOpenAi(const openai.ChatStreamEvent()),
        isEmpty,
      );
    });

    test('tool_call first fragment carries id + name at index', () {
      final client = makeClient();
      final chunks = client.chunksFromOpenAi(chunkEvent(
        toolCalls: const [
          openai.ToolCallDelta(
            index: 0,
            id: 'call_001',
            function: openai.FunctionCallDelta(name: 'networth_snapshot'),
          ),
        ],
      ));
      expect(chunks, hasLength(1));
      final delta = chunks.single as ToolCallDelta;
      expect(delta.index, 0);
      expect(delta.id, 'call_001');
      expect(delta.name, 'networth_snapshot');
      expect(delta.argsDelta, isNull);
    });

    test('tool_call arguments fragment carries argsDelta only', () {
      final client = makeClient();
      final chunks = client.chunksFromOpenAi(chunkEvent(
        toolCalls: const [
          openai.ToolCallDelta(
            index: 0,
            function: openai.FunctionCallDelta(arguments: '{"pa'),
          ),
        ],
      ));
      final delta = chunks.single as ToolCallDelta;
      expect(delta.index, 0);
      expect(delta.id, isNull);
      expect(delta.name, isNull);
      expect(delta.argsDelta, '{"pa');
    });

    test('parallel tool_calls in one event keep their indexes', () {
      final client = makeClient();
      final chunks = client.chunksFromOpenAi(chunkEvent(
        toolCalls: const [
          openai.ToolCallDelta(
            index: 0,
            id: 'call_a',
            function: openai.FunctionCallDelta(name: 'accounts_list'),
          ),
          openai.ToolCallDelta(
            index: 1,
            id: 'call_b',
            function: openai.FunctionCallDelta(name: 'debts_list'),
          ),
        ],
      ));
      expect(chunks, hasLength(2));
      expect((chunks[0] as ToolCallDelta).index, 0);
      expect((chunks[0] as ToolCallDelta).name, 'accounts_list');
      expect((chunks[1] as ToolCallDelta).index, 1);
      expect((chunks[1] as ToolCallDelta).name, 'debts_list');
    });

    test('bare tool_call fragment with no payload is skipped', () {
      final client = makeClient();
      expect(
        client.chunksFromOpenAi(chunkEvent(
          toolCalls: const [openai.ToolCallDelta(index: 0)],
        )),
        isEmpty,
      );
    });

    test('finish_reason maps to Finish with wire string', () {
      final client = makeClient();
      final stop = client
          .chunksFromOpenAi(chunkEvent(finishReason: openai.FinishReason.stop));
      expect((stop.single as Finish).reason, 'stop');
      final toolCallsFinish = client.chunksFromOpenAi(
        chunkEvent(finishReason: openai.FinishReason.toolCalls),
      );
      expect((toolCallsFinish.single as Finish).reason, 'tool_calls');
    });

    test('content + finish in one event keep order text-then-finish', () {
      final client = makeClient();
      final chunks = client.chunksFromOpenAi(chunkEvent(
        content: 'bye',
        finishReason: openai.FinishReason.stop,
      ));
      expect(chunks, hasLength(2));
      expect(chunks[0], isA<TextChunk>());
      expect(chunks[1], isA<Finish>());
    });
  });

  group('buildRequest', () {
    test('maps model + messages of every role', () {
      final client = makeClient();
      final request = client.buildRequest(const LlmChatRequest(
        model: 'glm-4-plus',
        messages: [
          {'role': 'system', 'content': 'sys'},
          {'role': 'user', 'content': 'hi'},
          {
            'role': 'assistant',
            'tool_calls': [
              {
                'id': 'c1',
                'type': 'function',
                'function': {'name': 'debts_list', 'arguments': '{}'},
              },
            ],
          },
          {'role': 'tool', 'tool_call_id': 'c1', 'content': '{}'},
        ],
        toolsSchema: [],
      ));
      expect(request.model, 'glm-4-plus');
      expect(request.messages, hasLength(4));
      expect(request.messages[0], isA<openai.SystemMessage>());
      expect(request.messages[1], isA<openai.UserMessage>());
      expect(request.messages[2], isA<openai.AssistantMessage>());
      expect((request.messages[2] as openai.AssistantMessage).toolCalls!.single
          .id, 'c1');
      expect(request.messages[3], isA<openai.ToolMessage>());
    });

    test('tools schema passes through as typed Tool list', () {
      final client = makeClient();
      const schema = [
        {
          'type': 'function',
          'function': {
            'name': 'networth_snapshot',
            'description': 'Latest net worth snapshot.',
            'parameters': {
              'type': 'object',
              'properties': <String, Object>{},
            },
          },
        },
      ];
      final request = client.buildRequest(const LlmChatRequest(
        model: 'm',
        messages: [
          {'role': 'user', 'content': 'q'},
        ],
        toolsSchema: schema,
      ));
      expect(request.tools, hasLength(1));
      expect(request.tools!.single.type, 'function');
      expect(request.tools!.single.function.name, 'networth_snapshot');
      // 序列化回 OpenAI 形状与输入 schema 等值(直传不变形)。
      expect(request.toJson()['tools'], schema);
    });

    test('empty tools schema maps to null tools (API rejects empty array)', () {
      final client = makeClient();
      final request = client.buildRequest(const LlmChatRequest(
        model: 'm',
        messages: [
          {'role': 'user', 'content': 'q'},
        ],
        toolsSchema: [],
      ));
      expect(request.tools, isNull);
    });

    test('requests usage in stream options', () {
      final client = makeClient();
      final request = client.buildRequest(const LlmChatRequest(
        model: 'm',
        messages: [
          {'role': 'user', 'content': 'q'},
        ],
        toolsSchema: [],
      ));
      expect(request.streamOptions?.includeUsage, isTrue);
    });
  });

  group('chat', () {
    test(
      'network failure rethrows as "LLM stream failed: <Type>(<host>)" '
      '(评审 L1;占位端点 127.0.0.1 已关端口,零外网)',
      () {
        final client = LlmStreamClientImpl();
        expectLater(
          client.chat(const LlmChatRequest(
            model: 'm',
            messages: [
              {'role': 'user', 'content': 'q'},
            ],
            toolsSchema: [],
          )),
          emitsError(isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              startsWith('LLM stream failed:'),
              contains('127.0.0.1'),
            ),
          )),
        );
      },
    );

    test(
      'illegal role throws self-explaining ArgumentError, not generic '
      'StateError (评审 L2:请求构造在 try 外,零网络)',
      () {
        final client = LlmStreamClientImpl();
        expectLater(
          client.chat(const LlmChatRequest(
            model: 'm',
            messages: [
              {'role': 'wizard', 'content': 'x'},
            ],
            toolsSchema: [],
          )),
          emitsError(isA<ArgumentError>().having(
            (e) => e.message.toString(),
            'message',
            contains('wizard'),
          )),
        );
      },
    );
  });
}
