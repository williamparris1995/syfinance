import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:yucai_client/assistant/data/llm_stream_client_impl.dart';
import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/engine_port.dart';
import 'package:yucai_client/assistant/domain/engine_state.dart';

/// F64 T4:LlmStreamClientImpl 三个纯映射函数(ADR-3)——
/// messageFromMap / chunksFromOpenAi / buildRequest,零网络请求。
///
/// F66-T3 引擎接线:构造注入 EngineManager(fake 三态);chat 前置
/// ensureReady 兜底 + Ready 端点作 baseUrl(ADR-1/ADR-8)—— ready 路径经
/// loopback SSE 服务端实测端点贯通,未就绪路径断言自解释 StateError。
void main() {
  /// 关端口端点(127.0.0.1:1)上的 Ready fake:映射组仅构造不调 chat;
  /// 网络失败组复用同端点(零外网、就地失败)。
  EngineReady closedPortReady() =>
      EngineReady(Uri.parse('http://127.0.0.1:1/v1'));

  LlmStreamClientImpl makeClient() =>
      LlmStreamClientImpl(_FakeEngineManager(closedPortReady()));

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

  group('chat(F66-T3 引擎接线,fake EngineManager 三态)', () {
    test(
      'ready:ensureReady 兜底被调,baseUrl 取 Ready 端点,流经该端点往返 '
      '(loopback SSE;ADR-1/ADR-8)',
      () async {
        // 本机随机端口 SSE 服务端:证明端点从 EngineManager Ready 态真实
        // 流入 OpenAIClient(非固定常量)。
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final paths = <String>[];
        final served = () async {
          await for (final request in server) {
            paths.add(request.uri.path);
            await request.drain<void>();
            const body = 'data: {"id":"c1","object":"chat.completion.chunk",'
                '"created":0,"model":"m","choices":[{"index":0,'
                '"delta":{"content":"hi"},"finish_reason":null}]}\n\n'
                'data: {"id":"c1","object":"chat.completion.chunk",'
                '"created":0,"model":"m","choices":[{"index":0,'
                '"delta":{},"finish_reason":"stop"}]}\n\n'
                'data: [DONE]\n\n';
            final response = request.response;
            response.statusCode = 200;
            response.headers.contentType =
                ContentType('text', 'event-stream', charset: 'utf-8');
            response.write(body);
            await response.close();
          }
        }();
        served.ignore();
        final engine = _FakeEngineManager(
          EngineReady(Uri.parse('http://127.0.0.1:${server.port}/v1')),
        );
        final client = LlmStreamClientImpl(engine);

        final events = await client.chat(const LlmChatRequest(
          model: 'm',
          messages: [
            {'role': 'user', 'content': 'q'},
          ],
          toolsSchema: [],
        )).toList();

        expect(events, hasLength(2));
        expect((events[0] as TextChunk).delta, 'hi');
        expect((events[1] as Finish).reason, 'stop');
        // 端点真实生效:请求打到 loopback 服务端的 /v1/chat/completions
        // (openai_dart 在 baseUrl 后追加 chat/completions)。
        expect(paths, ['/v1/chat/completions']);
        // ADR-1:请求前兜底预热被调(幂等语义归 port 契约)。
        expect(engine.ensureReadyCalls, 1);
        await server.close();
      },
    );

    test(
      '未就绪 Error(modelMissing):抛自解释 StateError,零网络(FR-4/FR-2)',
      () async {
        final engine = _FakeEngineManager(
          const EngineError(EngineFailureReason.modelMissing),
        );
        final client = LlmStreamClientImpl(engine);

        await expectLater(
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
            'engine not ready: modelMissing',
          )),
        );
        // 状态门在客户端构造之前 —— ensureReady 已调、请求未发出。
        expect(engine.ensureReadyCalls, 1);
      },
    );

    test('未就绪 Stopped(ensureReady 后仍未就绪):同路径自解释语义',
        () async {
      final engine = _FakeEngineManager(const EngineStopped());
      final client = LlmStreamClientImpl(engine);

      await expectLater(
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
          'engine not ready: stopped',
        )),
      );
      expect(engine.ensureReadyCalls, 1);
    });

    test(
      '网络失败重抛 "LLM stream failed: <Type>(<host>)"(评审 L1;Ready '
      '端点=关端口 127.0.0.1:1,零外网)',
      () async {
        final client =
            LlmStreamClientImpl(_FakeEngineManager(closedPortReady()));
        await expectLater(
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
      'T5 活跃包夹:流开始 begin、流关闭 end 成功路径配对(FR-1 闲置回收'
      '保护,loopback 往返)',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final served = () async {
          await for (final request in server) {
            await request.drain<void>();
            const body =
                'data: {"id":"c1","object":"chat.completion.chunk",'
                '"created":0,"model":"m","choices":[{"index":0,'
                '"delta":{"content":"ok"},"finish_reason":null}]}\n\n'
                'data: [DONE]\n\n';
            final response = request.response;
            response.statusCode = 200;
            response.headers.contentType =
                ContentType('text', 'event-stream', charset: 'utf-8');
            response.write(body);
            await response.close();
          }
        }();
        served.ignore();
        final engine = _FakeEngineManager(
          EngineReady(Uri.parse('http://127.0.0.1:${server.port}/v1')),
        );
        final client = LlmStreamClientImpl(engine);

        await client.chat(const LlmChatRequest(
          model: 'm',
          messages: [
            {'role': 'user', 'content': 'q'},
          ],
          toolsSchema: [],
        )).toList();

        // 包夹形状:begin 起手、end 收尾、各恰一次(进行中不回收)。
        expect(engine.activityLog.first, 'begin');
        expect(engine.activityLog.last, 'end');
        expect(engine.activityLog.where((e) => e == 'begin'), hasLength(1));
        expect(engine.activityLog.where((e) => e == 'end'), hasLength(1));
        expect(engine.ensureReadyCalls, 1); // 预热在 begin 之后仍被调
        await server.close();
      },
    );

    test('T5 活跃包夹:未就绪抛错路径 finally end 兜底配对', () async {
      final engine = _FakeEngineManager(const EngineStopped());
      final client = LlmStreamClientImpl(engine);

      await expectLater(
        client.chat(const LlmChatRequest(
          model: 'm',
          messages: [
            {'role': 'user', 'content': 'q'},
          ],
          toolsSchema: [],
        )),
        emitsError(isA<StateError>()),
      );

      // 抛错也配对:end 在错误冒出前已调(finally 兜底)。
      expect(engine.activityLog, ['begin', 'ensureReady', 'end']);
    });

    test(
      '非法 role 抛自解释 ArgumentError,非泛化 StateError(评审 L2:请求'
      '构造在引擎门之后、try 之外,零网络)',
      () async {
        final client =
            LlmStreamClientImpl(_FakeEngineManager(closedPortReady()));
        await expectLater(
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

/// F66-T3 接线 fake:初始态注入 + ensureReady/beginActivity/endActivity
/// 调用记录(state 恒为初始态;转移编排语义归 T2 EngineManagerImpl,
/// 此处只验接线消费面;activityLog 供 T5 活跃包夹断言)。
class _FakeEngineManager implements EngineManager {
  _FakeEngineManager(EngineState state)
      : _state = ValueNotifier<EngineState>(state);

  final ValueNotifier<EngineState> _state;
  int ensureReadyCalls = 0;
  final activityLog = <String>[];

  @override
  ValueListenable<EngineState> get state => _state;

  @override
  Future<void> ensureReady() async {
    activityLog.add('ensureReady');
    ensureReadyCalls++;
  }

  @override
  void beginActivity() => activityLog.add('begin');

  @override
  void endActivity() => activityLog.add('end');

  @override
  Future<void> shutdown() async {}
}
