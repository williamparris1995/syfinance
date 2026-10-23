import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart';
import 'package:yucai_client/assistant/domain/tool_registry.dart';

/// 测试替身:固定元数据,execute 回放预设结果。
class _StubTool implements AssistantTool {
  _StubTool(this.name, {this.result = const ToolData({'ok': true})});

  @override
  final String name;

  @override
  String get description => 'stub tool for registry tests';

  @override
  Map<String, Object> get parametersSchema => const {
        'type': 'object',
        'properties': {
          'kind': {'type': 'string'},
        },
      };

  final ToolResult result;

  @override
  Future<ToolResult> execute(Map<String, Object> args) async => result;
}

/// F64 T1:工具注册表(FR-1)——注册/查找/OpenAI schema 序列化/重名与
/// 非法 name 防御;附带 ToolResult 两态构造契约(轻)。
void main() {
  group('register/find', () {
    test('registers and exposes tools via findByName/all', () {
      final registry = AssistantToolRegistry();
      final networth = _StubTool('networth_snapshot');
      final debts = _StubTool('debts_list');
      registry
        ..register(networth)
        ..register(debts);

      expect(registry.findByName('networth_snapshot'), same(networth));
      expect(registry.findByName('debts_list'), same(debts));
      expect(registry.findByName('missing_tool'), isNull);
      expect(registry.all, containsAll([networth, debts]));
      expect(registry.all, hasLength(2));
    });

    test('duplicate name throws self-explaining error, registry unchanged',
        () {
      final registry = AssistantToolRegistry();
      final first = _StubTool('networth_snapshot');
      final dup = _StubTool('networth_snapshot');
      registry.register(first);

      expect(() => registry.register(dup), throwsStateError);

      // 既有注册不受影响(spec FR-1 场景:重名注册拒绝)。
      expect(registry.findByName('networth_snapshot'), same(first));
      expect(registry.all, hasLength(1));
    });

    test('invalid tool name is rejected', () {
      final registry = AssistantToolRegistry();

      expect(() => registry.register(_StubTool('networth snapshot')),
          throwsStateError); // 空格
      expect(() => registry.register(_StubTool('净资产快照')),
          throwsStateError); // 非 ASCII
      expect(() => registry.register(_StubTool('')), throwsStateError); // 空
      expect(registry.all, isEmpty);
    });
  });

  group('toOpenAiToolsSchema', () {
    test('serializes each tool to OpenAI tools function shape', () {
      final registry = AssistantToolRegistry();
      registry.register(_StubTool('networth_snapshot'));

      final schema = registry.toOpenAiToolsSchema();

      expect(schema, hasLength(1));
      expect(schema.first, {
        'type': 'function',
        'function': {
          'name': 'networth_snapshot',
          'description': 'stub tool for registry tests',
          'parameters': {
            'type': 'object',
            'properties': {
              'kind': {'type': 'string'},
            },
          },
        },
      });
    });

    test('output is valid JSON (spec FR-1 序列化场景)', () {
      final registry = AssistantToolRegistry()
        ..register(_StubTool('networth_snapshot'))
        ..register(_StubTool('accounts_list'));

      // Map<String, Object> 树可整树 jsonEncode → 合法 JSON 数组。
      final encoded = jsonEncode(registry.toOpenAiToolsSchema());
      final decoded = jsonDecode(encoded) as List<dynamic>;

      expect(decoded, hasLength(2));
      expect((decoded.first as Map<String, dynamic>)['type'], 'function');
    });
  });

  group('ToolResult', () {
    test('ToolData carries json payload, ToolError carries message', () async {
      final data = await _StubTool('data_tool').execute({});
      switch (data) {
        case ToolData(:final json):
          expect(json, {'ok': true});
        case ToolError():
          fail('expected ToolData but got ToolError');
      }

      final error = await _StubTool(
        'error_tool',
        result: const ToolError('unknown account kind: foo'),
      ).execute({});
      switch (error) {
        case ToolData():
          fail('expected ToolError but got ToolData');
        case ToolError(:final message):
          expect(message, 'unknown account kind: foo');
      }
    });
  });
}
