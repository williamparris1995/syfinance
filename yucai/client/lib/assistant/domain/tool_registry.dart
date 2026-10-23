/// F64 助手地基 —— 进程内工具注册表(FR-1/ADR-1)。
///
/// 注册 → 查找 → 整体序列化为 OpenAI tools JSON Schema 数组;
/// 重名 / 非法 name 注册即拒(自解释 StateError),既有注册不受影响。
library;

import 'assistant_tool.dart';

/// OpenAI function name 合法字符集(`[A-Za-z0-9_-]`,非空)。
final RegExp _namePattern = RegExp(r'^[A-Za-z0-9_-]+$');

/// 工具注册表(启动期装配,DI 单例;运行期只读消费)。
class AssistantToolRegistry {
  final Map<String, AssistantTool> _tools = {};

  /// 注册一个工具。
  ///
  /// name 非法(非 `[A-Za-z0-9_-]`)或与既有工具重名 → 抛自解释
  /// [StateError],本次注册不生效。
  void register(AssistantTool tool) {
    final name = tool.name;
    if (!_namePattern.hasMatch(name)) {
      throw StateError(
        'invalid assistant tool name: "$name" '
        '(must match [A-Za-z0-9_-])',
      );
    }
    if (_tools.containsKey(name)) {
      throw StateError('assistant tool already registered: $name');
    }
    _tools[name] = tool;
  }

  /// 按名查找(未注册 → null)。
  AssistantTool? findByName(String name) => _tools[name];

  /// 全部已注册工具(注册序,不可变视图)。
  List<AssistantTool> get all => List.unmodifiable(_tools.values);

  /// 序列化为 OpenAI chat tools 数组:每项
  /// `{type: function, function: {name, description, parameters}}`,
  /// 树内各 map 可整树 jsonEncode(FR-1 序列化场景)。
  List<Map<String, Object>> toOpenAiToolsSchema() => [
        for (final tool in _tools.values)
          {
            'type': 'function',
            'function': {
              'name': tool.name,
              'description': tool.description,
              'parameters': tool.parametersSchema,
            },
          },
      ];
}
