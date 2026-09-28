import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/report/data/llm/llm_http.dart';
import 'package:yucai_client/report/domain/mda/mda_narrator.dart';

/// F46 T1:生产 HTTP 缝(dart:io HttpClient,唯一平台文件,ADR-4)。
///
/// 用本地回环 HttpServer 实测:POST 形状/Bearer 头/200 返回体/
/// 非 200 → NarrationFailure(状态码+域名,零 Key)。
void main() {
  test('timeout is capped at 30 seconds (NFR-2)', () {
    expect(llmHttpTimeout, const Duration(seconds: 30));
  });

  test('posts body with headers and returns the 200 response body', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    late HttpRequest received;
    late String receivedBody;
    server.listen((request) async {
      received = request;
      receivedBody = await utf8.decoder.bind(request).join();
      request.response.statusCode = 200;
      request.response.write('{"choices":[{"message":{"content":"ok"}}]}');
      await request.response.close();
    });

    final url =
        Uri.parse('http://127.0.0.1:${server.port}/chat/completions');
    final out = await llmHttpPost(
      url,
      {
        'Authorization': 'Bearer sk-loopback',
        'Content-Type': 'application/json',
      },
      '{"model":"glm-4-plus"}',
    );

    expect(out, '{"choices":[{"message":{"content":"ok"}}]}');
    expect(received.method, 'POST');
    expect(received.uri.path, '/chat/completions');
    expect(receivedBody, '{"model":"glm-4-plus"}');
    expect(received.headers.value(HttpHeaders.authorizationHeader),
        'Bearer sk-loopback');
  });

  test('non-200 maps to NarrationFailure carrying status + host, no key',
      () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));

    server.listen((request) async {
      request.response.statusCode = 401;
      request.response.write('{"error":{"message":"bad key sk-loopback"}}');
      await request.response.close();
    });

    final url =
        Uri.parse('http://127.0.0.1:${server.port}/chat/completions');
    await expectLater(
      llmHttpPost(url, {'Authorization': 'Bearer sk-loopback'}, '{}'),
      throwsA(
        isA<NarrationFailure>()
            .having((e) => e.message, 'message', contains('401'))
            .having((e) => e.message, 'message', contains('127.0.0.1'))
            .having(
                (e) => e.message, 'message', isNot(contains('sk-loopback'))),
      ),
    );
  });

  test('connection refusal maps to NarrationFailure with error class only',
      () async {
    // 绑一个端口随即关掉,制造 connection refused。
    final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = probe.port;
    await probe.close();
    final url = Uri.parse('http://127.0.0.1:$port/chat/completions');

    await expectLater(
      llmHttpPost(url, {'Authorization': 'Bearer sk-loopback'}, '{}'),
      throwsA(
        isA<NarrationFailure>()
            .having((e) => e.message, 'message', contains('127.0.0.1'))
            .having(
                (e) => e.message, 'message', isNot(contains('sk-loopback'))),
      ),
    );
  });
}
