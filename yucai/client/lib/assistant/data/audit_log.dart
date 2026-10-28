/// F64 助手地基 —— 审计日志(FR-5/ADR-5)。
///
/// 每次 LLM 请求与工具调用输出一行 English 结构化日志(工具名/参数摘要/
/// 结果状态/耗时),`AssistantLogFn` 注入缝(生产=debugPrint,测试=收集器)。
///
/// **ASCII 强制**:所有插值字段经 [_asciiOnly] 过滤(非可打印 ASCII 剔除),
/// 行构造后 assert 整行纯 ASCII(项目 grep 门禁,日志串无 CJK)。
///
/// **红线:任何参数值/API Key 不得进入 argsSummary** —— 本类不 inspect
/// 摘要内容,调用方负责只传脱敏短摘要(如 `kind=credit page=2`)。
library;

import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// 日志输出缝(生产=debugPrint;测试注入收集器断言)。
typedef AssistantLogFn = void Function(String line);

/// 生产默认输出(debugPrint 为可变顶层变量,不能作 const 默认值,经此转发)。
void _defaultLog(String line) => debugPrint(line);

/// 助手审计日志(v1 结构化日志;FR-5;durable 表随 sprint-4 写操作落)。
@LazySingleton()
class AssistantAuditLog {
  /// [log] 注入缝:默认 debugPrint(生产),测试传收集函数。
  ///
  /// 命名参数须公开且带默认值(注入缝形状),字段保持私有 —— 现场初始化
  /// 无法改为 initializing formal,故 targeted ignore。
  // ignore: prefer_initializing_formals
  AssistantAuditLog({AssistantLogFn log = _defaultLog}) : _log = log;

  final AssistantLogFn _log;

  /// 工具调用审计:`assistant tool=<name> status=<ok|error> ms=<n> args=<摘要>`。
  ///
  /// [argsSummary] 必须为脱敏摘要(见类文档红线),非 ASCII 字符会被剔除。
  void logToolCall({
    required String name,
    required bool ok,
    required int ms,
    String argsSummary = '',
  }) {
    _emit(
      'assistant tool=${_asciiOnly(name)} '
      'status=${ok ? 'ok' : 'error'} '
      'ms=$ms '
      'args=${_asciiOnly(argsSummary)}',
    );
  }

  /// LLM 请求审计:`assistant llm host=<domain> ms=<n> model=<model>`。
  ///
  /// host 只取域名(零 Key/零 path,照 F46 隐私红线口径)。
  void logLlm({required String host, required int ms, required String model}) {
    _emit(
      'assistant llm host=${_asciiOnly(host)} '
      'ms=$ms '
      'model=${_asciiOnly(model)}',
    );
  }

  /// 写操作执行审计(F70 NFR-3;F71 起 = `AgentAuditSinkImpl.record` 的
  /// 第一投,行形状零变;未注入 sink 的 F70 旧构造位经
  /// `_LogOnlyAuditSink` 回退本方法直调):
  /// `assistant write tool=<name> status=<ok|error> entity=<id> payload=<摘要>`。
  ///
  /// [entityId] 空串 = 尚无实体(失败常见);[payloadSummary] 必须为脱敏
  /// 摘要(方向/金额/定位计数类字段,零完整 payload,红线同
  /// [logToolCall])。
  void logWrite({
    required String tool,
    required String payloadSummary,
    required String entityId,
    required bool ok,
  }) {
    _emit(
      'assistant write tool=${_asciiOnly(tool)} '
      'status=${ok ? 'ok' : 'error'} '
      'entity=${_asciiOnly(entityId)} '
      'payload=${_asciiOnly(payloadSummary)}',
    );
  }

  /// 剔除非可打印 ASCII(0x20..0x7E)字符 —— CJK/控制符(含换行)出局,
  /// 保证单行纯 ASCII(含用户可配的 model/host 等自由文本字段)。
  static String _asciiOnly(String value) => String.fromCharCodes(
        value.codeUnits.where((c) => c >= 0x20 && c <= 0x7E),
      );

  void _emit(String line) {
    assert(
      line.codeUnits.every((c) => c >= 0x20 && c <= 0x7E),
      'audit log line must be printable ASCII: interpolations must go '
      'through _asciiOnly',
    );
    _log(line);
  }
}
