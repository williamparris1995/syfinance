/// F67 端侧模型管理 —— 模型下载 HTTP 缝 + dart:io 生产实现(ADR-1)。
///
/// [ModelHttpClient] 为 NFR-1 注入缝:单测 mock 零真网络;生产绑定
/// [IoModelHttpClient](手写 dart:io HttpClient,F46 llm_http/F66 健康探测
/// 同款惯例,零新依赖)。只服务模型直链下载两种请求形状:普通 GET 与
/// `Range: bytes=<n>-` 续传(FR-1);>399 状态抛自解释 English 异常
/// [ModelHttpException](带码,供管理器判源回落,ADR-4)。
library;

import 'dart:io';

import 'package:injectable/injectable.dart';

/// 模型下载响应(单段语义,字段语义保真):
/// - [statusCode]:HTTP 状态码(206 = Range 生效;200 = 全量,含服务器
///   忽略 Range 的情形 —— 管理器据此决定续写或从零重写);
/// - [contentLength]:本响应当前段字节长(chunked 未知 → null);
/// - [totalLength]:完整文件字节长(Content-Range 尾值;Range 响应仍 =
///   原始全长;未知 → null,管理器回落钉死清单值);
/// - [body]:响应体字节流。
class ModelHttpResponse {
  const ModelHttpResponse({
    required this.statusCode,
    required this.body,
    this.contentLength,
    this.totalLength,
  });

  /// HTTP 状态码(2xx/3xx 由 impl 放行,>399 在 impl 抛出)。
  final int statusCode;

  /// 本响应当前段字节长(未知/chunked → null)。
  final int? contentLength;

  /// 完整文件字节长(Range 响应仍为原始全长;未知 → null)。
  final int? totalLength;

  /// 响应体字节流。
  final Stream<List<int>> body;
}

/// 模型下载 HTTP 状态失败(>399):自解释 English + 状态码。
class ModelHttpException implements Exception {
  ModelHttpException({required this.statusCode, required this.url});

  /// HTTP 状态码(404/416 等供管理器判「换下一源」,ADR-4)。
  final int statusCode;

  /// 请求 URL(host 进异常文案,零 path 零 query)。
  final Uri url;

  @override
  String toString() => 'model http status=$statusCode host=${url.host}';
}

/// 模型下载 HTTP 缝(NFR-1:单测零真网络;生产 = [IoModelHttpClient])。
abstract class ModelHttpClient {
  /// GET [url];[rangeFrom] 非空 → 附 `Range: bytes=<rangeFrom>-` 续传请求。
  ///
  /// 抛错语义:连接错/超时原样透传;状态 >399 抛 [ModelHttpException]。
  /// 管理器对两种抛错一律「换下一源」(ADR-4),响应体流的中途错误由
  /// 管理器按 network error 处理(.part 保留可续传)。
  Future<ModelHttpResponse> get(Uri url, {int? rangeFrom});
}

/// dart:io 生产实现:普通 GET + Range 续传;连接超时 30s(本票参数,
/// design Open Questions 执行期定)。
///
/// 每次 [get] 独立 [HttpClient],响应体流读完(或取消)后关闭 ——
/// body 由 [_closingBody] 包装,消费端无需关心连接归还。
@LazySingleton(as: ModelHttpClient)
class IoModelHttpClient implements ModelHttpClient {
  IoModelHttpClient({this.connectTimeout = defaultConnectTimeout});

  /// 连接超时(design Risks:官方源 SLF 慢启动,失败判定带超时)。
  static const Duration defaultConnectTimeout = Duration(seconds: 30);

  final Duration connectTimeout;

  @override
  Future<ModelHttpResponse> get(Uri url, {int? rangeFrom}) async {
    final client = HttpClient()..connectionTimeout = connectTimeout;
    try {
      final request = await client.getUrl(url);
      if (rangeFrom != null) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$rangeFrom-');
      }
      final response = await request.close();
      final status = response.statusCode;
      if (status > 399) {
        throw ModelHttpException(statusCode: status, url: url);
      }
      return ModelHttpResponse(
        statusCode: status,
        contentLength:
            response.contentLength >= 0 ? response.contentLength : null,
        totalLength: _totalLengthOf(response),
        body: _closingBody(response, client),
      );
    } catch (_) {
      client.close(force: true); // idempotent; body path closes itself
      rethrow;
    }
  }

  /// 完整文件长:Range 响应取 `Content-Range: bytes s-e/<total>` 尾值,
  /// 否则 contentLength(未知 → null)。
  static int? _totalLengthOf(HttpClientResponse response) {
    final contentRange =
        response.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null) {
      final slash = contentRange.lastIndexOf('/');
      if (slash >= 0 && slash + 1 < contentRange.length) {
        return int.tryParse(contentRange.substring(slash + 1));
      }
    }
    final length = response.contentLength;
    return length >= 0 ? length : null;
  }

  /// 流结束(正常/异常/取消)即关 client(async* 的 finally 覆盖全部路径)。
  static Stream<List<int>> _closingBody(
    HttpClientResponse response,
    HttpClient client,
  ) async* {
    try {
      await for (final chunk in response) {
        yield chunk;
      }
    } finally {
      client.close(force: true);
    }
  }
}
