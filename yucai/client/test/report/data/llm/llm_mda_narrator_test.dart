import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:yucai_client/core/llm/llm_settings.dart';
import 'package:yucai_client/report/data/llm/llm_mda_narrator.dart';
import 'package:yucai_client/report/domain/mda/mda_models.dart';
import 'package:yucai_client/report/domain/mda/mda_narrator.dart';
import 'package:yucai_client/report/domain/report_document.dart';

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

/// F46 T1:LlmMdaNarrator(FR-3 调用管线 + FR-5 降级/隐私红线)。
///
/// - 未 ready → ''(Noop 语义内化,ADR-3)且零 HTTP;
/// - fake 缝成功 → choices[0].message.content;
/// - 非 200/超时/坏 JSON/缺 content → NarrationFailure,消息只含
///   状态码+端点域名+错误类(零 Key 零完整 payload)。
void main() {
  late _MockSecureStorage backend;
  late LlmSettings settings;

  const readyConfig = LlmConfig(
    enabled: true,
    provider: LlmProvider.zhipu,
    apiKey: 'sk-secret-key',
    model: 'glm-4-plus',
    cityTier: LlmCityTier.tier2,
  );

  setUp(() async {
    backend = _MockSecureStorage();
    settings = LlmSettings(storage: backend);
    registerFallbackValue('');
    when(
      () => backend.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    await settings.setConfig(readyConfig);
  });

  /// 最小报告夹具(含一条 R5 finding:交易描述必被脱敏层排除)。
  ReportDocument buildDoc() => ReportDocument(
        period: ReportPeriod.monthly(2026, 8),
        generatedAt: DateTime.utc(2026, 9, 1),
        overview: OverviewSection.create(
          netWorthStartCents: 100_000,
          netWorthEndCents: 120_000,
          incomeCents: 80_000,
          expenseCents: 50_000,
          cashDeltaCents: 10_000,
          notes: const [],
        ),
        balanceSheet: BalanceSheetSection.create(
          assets: const [],
          liabilities: const [],
          changes: const [],
        ),
        incomeStatement: const IncomeStatementSection(
          income: [],
          expense: [],
          dailyAvgCents: 0,
        ),
        cashFlow: const CashFlowSection(
          operating: ActivityFlow(inflowCents: 0, outflowCents: 0, netCents: 0),
          investing: ActivityFlow(inflowCents: 0, outflowCents: 0, netCents: 0),
          financing: ActivityFlow(inflowCents: 0, outflowCents: 0, netCents: 0),
          netDeltaCents: 0,
          reconciled: true,
        ),
        excludedSections: const [],
      );

  const findings = [
    MdaFinding(
      ruleId: 'R5',
      severity: MdaSeverity.info,
      conclusion: '单笔大额支出:8 月 15 日「和同事聚餐请客」¥3,200.00',
      advice: '确认该笔是否年付/预付类一次性支出',
    ),
    MdaFinding(
      ruleId: 'R1',
      severity: MdaSeverity.warn,
      conclusion: '储蓄率 37.5%,低于 20.0%',
      advice: '向 50/30/20 法则的储蓄 20% 目标靠拢',
    ),
  ];

  /// 录制型 fake 缝:捕获请求三要素,可编程响应/抛错。
  ({Uri url, Map<String, String> headers, String body})? request;
  Object? throwOnCall;
  String respondWith = '';

  Future<String> fakeHttp(
    Uri url,
    Map<String, String> headers,
    String body,
  ) async {
    request = (url: url, headers: headers, body: body);
    if (throwOnCall != null) throw throwOnCall!;
    return respondWith;
  }

  tearDown(() {
    request = null;
    throwOnCall = null;
    respondWith = '';
  });

  group('not ready (Noop semantics)', () {
    test('narrate returns empty string and never touches http when disabled',
        () async {
      await settings.setConfig(readyConfig.copyWith(enabled: false));

      final narrator = LlmMdaNarrator(settings, fakeHttp);
      final text = await narrator.narrate(buildDoc(), findings);

      expect(text, '');
      expect(request, isNull);
    });

    test('narrate returns empty string when config incomplete', () async {
      await settings.setConfig(readyConfig.copyWith(apiKey: ''));

      final narrator = LlmMdaNarrator(settings, fakeHttp);
      expect(await narrator.narrate(buildDoc(), findings), '');
      expect(request, isNull);
    });
  });

  group('happy path', () {
    test('narrate parses choices[0].message.content from the response',
        () async {
      respondWith = jsonEncode({
        'choices': [
          {
            'message': {
              'role': 'assistant',
              'content': '总体评价:本期储蓄率稳健。',
            },
          },
        ],
      });

      final narrator = LlmMdaNarrator(settings, fakeHttp);
      final text = await narrator.narrate(buildDoc(), findings);

      expect(text, '总体评价:本期储蓄率稳健。');
    });

    test('request hits {base}/chat/completions with bearer key and payload',
        () async {
      respondWith = jsonEncode({
        'choices': [
          {'message': {'content': 'ok'}}
        ],
      });

      await LlmMdaNarrator(settings, fakeHttp).narrate(buildDoc(), findings);

      // 端点 = 预设 base_url(智谱,含 /v4)+ /chat/completions
      expect(request!.url.toString(),
          'https://open.bigmodel.cn/api/paas/v4/chat/completions');
      // Bearer Key 走请求头(且只在这里出现)
      expect(request!.headers['Authorization'], 'Bearer sk-secret-key');
      expect(request!.headers['Content-Type'], 'application/json');

      final body = jsonDecode(request!.body) as Map<String, dynamic>;
      expect(body['model'], 'glm-4-plus');
      final messages = (body['messages'] as List).cast<Map<String, dynamic>>();
      expect(messages, hasLength(2));
      expect(messages[0]['role'], 'system');
      expect(messages[1]['role'], 'user');
      // user 消息 = 脱敏包 JSON:安全 finding 在,交易描述被排除
      final userText = messages[1]['content'] as String;
      expect(userText, contains('储蓄率 37.5%'));
      expect(userText, isNot(contains('和同事聚餐请客')));
      expect(userText, isNot(contains('acct-')));
    });
  });

  group('failure mapping (FR-5 privacy red line)', () {
    test('http NarrationFailure passes through untouched', () async {
      throwOnCall = const NarrationFailure('HTTP 401(open.bigmodel.cn)');

      final narrator = LlmMdaNarrator(settings, fakeHttp);
      await expectLater(
        narrator.narrate(buildDoc(), findings),
        throwsA(
          isA<NarrationFailure>()
              .having((e) => e.message, 'message', contains('401'))
              .having((e) => e.message, 'message', contains('open.bigmodel.cn'))
              .having((e) => e.message, 'message', isNot(contains('sk-'))),
        ),
      );
    });

    test('timeout wraps into NarrationFailure carrying class + host only',
        () async {
      throwOnCall = TimeoutException('after 0:00:30.000000', const Duration(seconds: 30));

      final narrator = LlmMdaNarrator(settings, fakeHttp);
      await expectLater(
        narrator.narrate(buildDoc(), findings),
        throwsA(
          isA<NarrationFailure>()
              .having((e) => e.message, 'message', contains('TimeoutException'))
              .having((e) => e.message, 'message', contains('open.bigmodel.cn'))
              // 零 Key:超时细节不带凭据
              .having((e) => e.message, 'message', isNot(contains('sk-'))),
        ),
      );
    });

    test('chatty transport errors are sanitized: no key, no payload',
        () async {
      // 模拟会把 Key 与请求体都塞进 message 的底层异常
      throwOnCall = Exception(
          'send failed token=sk-secret-key body={"period":"2026 年 8 月"}');

      final narrator = LlmMdaNarrator(settings, fakeHttp);
      await expectLater(
        narrator.narrate(buildDoc(), findings),
        throwsA(
          isA<NarrationFailure>()
              .having((e) => e.message, 'message', isNot(contains('sk-secret-key')))
              .having((e) => e.message, 'message', isNot(contains('period')))
              .having((e) => e.message, 'message', contains('open.bigmodel.cn')),
        ),
      );
    });

    test('malformed JSON response maps to NarrationFailure', () async {
      respondWith = 'not-json{{';

      final narrator = LlmMdaNarrator(settings, fakeHttp);
      await expectLater(
        narrator.narrate(buildDoc(), findings),
        throwsA(isA<NarrationFailure>()),
      );
    });

    test('malformed custom base_url fails as NarrationFailure, not bare '
        'FormatException (评审 R1)', () async {
      await settings.setConfig(readyConfig.copyWith(
        provider: LlmProvider.custom,
        baseUrl: 'ht!tp://[::1', // Uri.parse 抛 Illegal scheme character
      ));

      final narrator = LlmMdaNarrator(settings, fakeHttp);
      await expectLater(
        narrator.narrate(buildDoc(), findings),
        throwsA(
          isA<NarrationFailure>()
              .having(
                  (e) => e.message, 'message', contains('端点地址无效'))
              .having((e) => e.message, 'message', isNot(contains('sk-'))),
        ),
      );
      expect(request, isNull); // 未触网即失败
    });

    test('response missing choices/content maps to NarrationFailure',
        () async {
      respondWith = jsonEncode({'choices': []});

      final narrator = LlmMdaNarrator(settings, fakeHttp);
      await expectLater(
        narrator.narrate(buildDoc(), findings),
        throwsA(isA<NarrationFailure>()),
      );
    });
  });
}
