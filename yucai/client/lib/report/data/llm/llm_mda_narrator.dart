/// F46 LLM 分析师 —— MdaNarrator 真实现(FR-3/ADR-3/ADR-4)。
///
/// 管线:narrate(doc, findings) → !ready → ''(Noop 语义内化,入口隐藏
/// 的页面级兜底)→ 脱敏包([sanitizedPayload])→ 消息对([buildMessages])
/// → [LlmHttpFn] 缝 → 解析 `choices[0].message.content`(jsonDecode
/// 全程防御)。
///
/// 失败二态(spec FR-3):未配置 = 空串(页面隐藏);已配置调用失败 =
/// [NarrationFailure](页面错误态可重试)。异常消息**只含状态码+端点域名
/// +错误类**(零 Key 零完整 payload,FR-5 红线)——包装时只取
/// `runtimeType` 与 host,绝不搬运底层 message。
library;

import 'dart:convert';

import 'package:injectable/injectable.dart';
import 'package:yucai_client/core/llm/llm_settings.dart';
import 'package:yucai_client/report/data/llm/llm_payload.dart';
import 'package:yucai_client/report/data/llm/llm_prompt.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_narrator.dart';
import 'package:yucai_client/report/domain/report_document.dart';

/// OpenAI 兼容 POST 缝(Uri/headers/body → 响应体字符串;非 200 由实现
/// 抛 [NarrationFailure],生产 = llm_http.dart 的 dart:io HttpClient)。
typedef LlmHttpFn = Future<String> Function(
  Uri url,
  Map<String, String> headers,
  String body,
);

/// MdaNarrator 主绑定(ADR-3:唯一注册,Noop 退役出 DI 图)。
@LazySingleton(as: MdaNarrator)
class LlmMdaNarrator implements MdaNarrator {
  LlmMdaNarrator(this._settings, this._httpFn);

  final LlmSettings _settings;
  final LlmHttpFn _httpFn;

  @override
  Future<String> narrate(ReportDocument doc, List<MdaFinding> findings) async {
    final cfg = _settings.value;
    if (!cfg.ready) return '';

    final mda = MdaSection.create(findings: findings);
    final payloadJson = jsonEncode(sanitizedPayload(doc, mda, cfg));
    final messages = buildMessages(payloadJson, cfg.cityTier);

    // 端点 = resolvedBaseUrl(预设钉死/custom 用户填)去尾斜杠 + 固定路径;
    // 畸形 base_url(评审 R1)预包防御 → NarrationFailure,不逃裸
    // FormatException(消息不含用户串,零 Key)。
    final base = cfg.resolvedBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final Uri url;
    try {
      url = Uri.parse('$base/chat/completions');
    } on FormatException {
      throw const NarrationFailure('LLM 端点地址无效');
    }
    final body = jsonEncode({'model': cfg.model, 'messages': messages});

    try {
      final raw = await _httpFn(url, {
        'Authorization': 'Bearer ${cfg.apiKey}',
        'Content-Type': 'application/json',
      }, body);
      return _parseContent(raw, url);
    } on NarrationFailure {
      rethrow; // llm_http 已按红线格式化
    } catch (e) {
      // 只携带错误类 + 端点域名(底层 message 可能含 Key/payload,弃用)。
      throw NarrationFailure('LLM 调用失败:${e.runtimeType}(${url.host})');
    }
  }

  /// 解析响应体 → choices[0].message.content(逐级防御,缺级即失败)。
  String _parseContent(String raw, Uri url) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw NarrationFailure(
          'LLM 响应解析失败:${e.runtimeType}(${url.host})');
    }
    if (decoded is! Map) {
      throw NarrationFailure('LLM 响应缺少正文(${url.host})');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      throw NarrationFailure('LLM 响应缺少正文(${url.host})');
    }
    final first = choices[0];
    final message = first is Map ? first['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String) {
      throw NarrationFailure('LLM 响应缺少正文(${url.host})');
    }
    return content;
  }
}
