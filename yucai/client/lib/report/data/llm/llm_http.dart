/// F46 LLM 分析师 —— 生产 HTTP 缝实现(FR-3/ADR-4/NFR-1)。
///
/// **唯一平台文件**(report/data/llm 其余均纯 Dart):dart:io HttpClient
/// POST OpenAI 兼容 `{base}/chat/completions`,30s 超时上限(NFR-2);
/// 错误一律转 [NarrationFailure](状态码+端点域名+错误类,零 Key 零
/// 完整 payload,FR-5 红线)。
///
/// 单实例一次性 client:LLM 调用为低频手动触发(FR-4),不复用连接池;
/// finally 强关兜底(超时路径下悬挂连接立即释放)。
library;

import 'dart:convert';
import 'dart:io';

import 'package:yucai_client/report/data/llm/llm_mda_narrator.dart';
import 'package:yucai_client/report/domain/mda/mda_narrator.dart';

/// 单次调用超时上限(连接/发送/读响应各段共用,NFR-2:30 秒)。
const llmHttpTimeout = Duration(seconds: 30);

/// 生产 [LlmHttpFn]:POST → 200 返回响应体字符串;非 200/网络错误 →
/// [NarrationFailure](已按红线格式化,narrator 原样透传)。
Future<String> llmHttpPost(
  Uri url,
  Map<String, String> headers,
  String body,
) async {
  final client = HttpClient()..connectionTimeout = llmHttpTimeout;
  try {
    final request = await client.postUrl(url).timeout(llmHttpTimeout);
    headers.forEach(request.headers.set);
    request.write(body);
    final response = await request.close().timeout(llmHttpTimeout);
    final text =
        await response.transform(utf8.decoder).join().timeout(llmHttpTimeout);
    if (response.statusCode != 200) {
      // 只携带状态码 + 端点域名;响应体(可能回显 Key/错误详情)弃用。
      throw NarrationFailure('HTTP ${response.statusCode}(${url.host})');
    }
    return text;
  } on NarrationFailure {
    rethrow;
  } catch (e) {
    // 只携带错误类 + 端点域名(底层 message 可能含 Key/URL 细节,弃用)。
    throw NarrationFailure('HTTP 请求失败:${e.runtimeType}(${url.host})');
  } finally {
    client.close(force: true);
  }
}
