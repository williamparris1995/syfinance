/// F46 LLM 分析师 —— 生产 HTTP 缝实现(FR-3/ADR-4/NFR-1)。
///
/// **唯一平台文件**(report/data/llm 其余均纯 Dart):dart:io HttpClient
/// POST OpenAI 兼容 `{base}/chat/completions`;错误一律转
/// [NarrationFailure](状态码+端点域名+错误类,零 Key 零完整 payload,
/// FR-5 红线)。
///
/// 超时 = **整体 deadline**(评审 R1):[timeout] 预算从调用起始时刻一次
/// 拍定,连接/发送/读响应各段共用剩余时间——最坏全链 = 30s,而非分段
/// 叠加(NFR-2 上限语义)。单实例一次性 client:LLM 调用为低频手动触发
/// (FR-4),不复用连接池;finally 强关兜底(超时路径下悬挂连接立即释放)。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:yucai_client/report/data/llm/llm_mda_narrator.dart';
import 'package:yucai_client/report/domain/mda/mda_narrator.dart';

/// 单次调用整体超时预算(NFR-2:30 秒,全链上限)。
const llmHttpTimeout = Duration(seconds: 30);

/// 生产 [LlmHttpFn]:POST → 200 返回响应体字符串;非 200/超时/网络错误
/// → [NarrationFailure](已按红线格式化,narrator 原样透传)。
///
/// [timeout] 仅供测试注入短预算(生产默认 [llmHttpTimeout]);可选命名
/// 参数带默认值,不破坏 LlmHttpFn 三参赋值。
Future<String> llmHttpPost(
  Uri url,
  Map<String, String> headers,
  String body, {
  Duration timeout = llmHttpTimeout,
}) async {
  final client = HttpClient()..connectionTimeout = timeout;
  // 整体 deadline:起始时刻 + 预算;剩余 ≤ 0 时 .timeout 立即触发。
  final deadline = DateTime.now().add(timeout);
  Duration remaining() => deadline.difference(DateTime.now());

  try {
    final request = await client.postUrl(url).timeout(remaining());
    headers.forEach(request.headers.set);
    request.write(body);
    final response = await request.close().timeout(remaining());
    final text =
        await response.transform(utf8.decoder).join().timeout(remaining());
    if (response.statusCode != 200) {
      // 只携带状态码 + 端点域名;响应体(可能回显 Key/错误详情)弃用。
      throw NarrationFailure('HTTP ${response.statusCode}(${url.host})');
    }
    return text;
  } on NarrationFailure {
    rethrow;
  } on TimeoutException {
    throw NarrationFailure('HTTP 请求超时(${url.host})');
  } catch (e) {
    // 只携带错误类 + 端点域名(底层 message 可能含 Key/URL 细节,弃用)。
    throw NarrationFailure('HTTP 请求失败:${e.runtimeType}(${url.host})');
  } finally {
    client.close(force: true);
  }
}
