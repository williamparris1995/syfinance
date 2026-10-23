/// F64 助手地基 —— LlmStreamClient 生产实现(FR-3/ADR-3)。
///
/// openai_dart 11.x 包装:openai_dart **仅在本文件出现**(port 隔离,
/// domain 零协议依赖,替换面=1 文件);每次 [chat] 经配置取值缝读当前
/// [AssistantConfig] 构造一次性 `OpenAIClient`(端点热切换即时生效)。
/// 实现主体为三个纯映射函数([messageFromMap]/[chunksFromOpenAi]/
/// [buildRequest])—— 可单测、零网络。
///
/// 流异常重抛为自解释格式(**错误类名+端点域名**,零 Key/零完整 body ——
/// 照 F46 红线,底层 message 可能携带 payload 被弃用);AssistantError
/// 事件语义转换在 T5 agent loop。
library;

import 'package:injectable/injectable.dart';
import 'package:openai_dart/openai_dart.dart' as openai;

import '../domain/agent_loop.dart';
import '../domain/assistant_settings.dart';

/// LlmStreamClient 生产绑定(ADR-3;mock 回放测试缝在 domain port 上)。
@LazySingleton(as: LlmStreamClient)
class LlmStreamClientImpl implements LlmStreamClient {
  /// [config] 配置取值缝:T6 接线时绑 AssistantSettings.value;本实现
  /// 不依赖设置存储的存在,单测直接传闭包。
  LlmStreamClientImpl(this._config);

  final AssistantConfig Function() _config;

  @override
  Stream<LlmChunk> chat(LlmChatRequest req) async* {
    final cfg = _config();
    final baseUrl = cfg.resolvedBaseUrl;
    if (baseUrl.trim().isEmpty) {
      // FR-4 兜底闸:not-ready 检查在上层(T5),此处保证零网络请求。
      throw StateError(
        'LlmStreamClient: assistant endpoint is not configured',
      );
    }
    // localhost 免 Key 端点(ADR-4)apiKey 可空 —— 传非空占位符:
    // 本地推理网关不校验 Authorization,且空串会破坏 Bearer 头形状。
    final apiKey =
        cfg.apiKey.trim().isNotEmpty ? cfg.apiKey.trim() : 'sk-noauth';
    final host = _hostOf(baseUrl);
    // 请求构造在 try 之前:非法消息形状(自解释 ArgumentError)在此直接
    // 上抛,不被网络异常包装吞掉语义(评审 L2)。
    final request = buildRequest(req);
    final client = openai.OpenAIClient.withApiKey(apiKey, baseUrl: baseUrl);
    try {
      final stream = client.chat.completions.createStream(request);
      await for (final event in stream) {
        for (final chunk in chunksFromOpenAi(event)) {
          yield chunk;
        }
      }
    } catch (e) {
      // F46 红线:只携带错误类名+端点域名(零 Key/零完整 body)。
      throw StateError('LLM stream failed: ${e.runtimeType}($host)');
    } finally {
      client.close();
    }
  }

  /// domain 消息 map(OpenAI 兼容原始形状)→ openai_dart typed 消息。
  ///
  /// role ∈ {system,user,assistant,tool};assistant 带 `tool_calls` 时
  /// 映射完整 ToolCall(id/type/function.{name,arguments});未知/非字符串
  /// role 抛自解释 [ArgumentError]。
  openai.ChatMessage messageFromMap(Map<String, Object> message) {
    final role = message['role'];
    if (role is! String) {
      throw ArgumentError.value(
        role,
        'role',
        'chat message role must be a String, got ${role.runtimeType}',
      );
    }
    return switch (role) {
      'system' => openai.ChatMessage.system(_stringOr(message['content'], '')),
      'user' => openai.ChatMessage.user(_stringOr(message['content'], '')),
      'assistant' => _assistantFromMap(message),
      'tool' => openai.ChatMessage.tool(
          toolCallId: _stringOr(message['tool_call_id'], ''),
          content: _stringOr(message['content'], ''),
        ),
      _ => throw ArgumentError.value(
          role,
          'role',
          'unknown chat message role: $role '
          '(expected system/user/assistant/tool)',
        ),
    };
  }

  /// openai_dart 流事件 → 规范化 LlmChunk 列表(取 choice[0],与
  /// n=1 请求形状一致):delta.content→[TextChunk];delta.tool_calls[i]→
  /// [ToolCallDelta](index/id/function.name/function.arguments 增量);
  /// finish_reason→[Finish](wire 字符串);usage-only(choices 为 null)
  /// 与空载荷分片忽略。
  List<LlmChunk> chunksFromOpenAi(openai.ChatStreamEvent event) {
    final chunks = <LlmChunk>[];
    final choice = event.firstChoice;
    if (choice == null) return chunks; // usage-only / provider 方言 chunk
    final delta = choice.delta;
    if (delta.content case final text?) {
      chunks.add(TextChunk(text));
    }
    if (delta.toolCalls case final calls?) {
      for (final call in calls) {
        final name = call.function?.name;
        final argsDelta = call.function?.arguments;
        // 无 id/无 name/无 args 的空分片(如仅 role 通告)不产出。
        if (call.id == null && name == null && argsDelta == null) continue;
        chunks.add(ToolCallDelta(
          call.index,
          id: call.id,
          name: name,
          argsDelta: argsDelta,
        ));
      }
    }
    if (choice.finishReason case final reason?) {
      chunks.add(Finish(reason.value));
    }
    return chunks;
  }

  /// domain 请求 → openai_dart 请求:model+messages 映射+tools(schema
  /// 已是 OpenAI 形状,typed 包装直传;空表→null,空数组会被 API 400)
  /// +streamOptions.includeUsage(终包 usage 供审计/统计)。
  openai.ChatCompletionCreateRequest buildRequest(LlmChatRequest req) =>
      openai.ChatCompletionCreateRequest(
        model: req.model,
        messages: [
          for (final message in req.messages) messageFromMap(message),
        ],
        tools: req.toolsSchema.isEmpty
            ? null
            : [
                for (final schema in req.toolsSchema)
                  openai.Tool.fromJson(schema),
              ],
        streamOptions: const openai.StreamOptions(includeUsage: true),
      );

  openai.AssistantMessage _assistantFromMap(Map<String, Object> message) {
    final rawCalls = message['tool_calls'];
    return openai.AssistantMessage(
      content: message['content'] is String
          ? message['content'] as String
          : null,
      toolCalls: rawCalls is List
          ? [for (final raw in rawCalls) _toolCallFromMap(raw)]
          : null,
    );
  }

  openai.ToolCall _toolCallFromMap(Object raw) {
    if (raw is! Map) {
      throw ArgumentError.value(
        raw,
        'tool_calls entry',
        'tool call entry must be a map, got ${raw.runtimeType}',
      );
    }
    final function = raw['function'];
    final fn = function is Map ? function : const <Object?, Object?>{};
    return openai.ToolCall(
      id: _stringOr(raw['id'], ''),
      type: _stringOr(raw['type'], 'function'),
      function: openai.FunctionCall(
        name: _stringOr(fn['name'], ''),
        arguments: _stringOr(fn['arguments'], '{}'),
      ),
    );
  }

  /// 端点域名(错误消息用;畸形 URL 不炸,给固定占位)。
  static String _hostOf(String baseUrl) {
    try {
      return Uri.parse(baseUrl).host;
    } on FormatException {
      return 'unparsed-endpoint';
    }
  }

  static String _stringOr(Object? value, String fallback) =>
      value is String ? value : fallback;
}
