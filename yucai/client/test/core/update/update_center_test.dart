// F24 更新链 v2(2026-11-05):UpdateCenter 单测 —— appcast 解析 / 版本
// 比较 / 缓存命中判定 / MockClient 下载与长度校验 / 旧版本缓存清理。
// install()(Process + exitApp)为薄组装层,照旧 app_updater 先例不做单测
// (真进程冒烟由发版验收承接)。
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:yucai_client/core/update/update_center.dart';

const _appcastV121 = '''
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>御财</title>
    <item>
      <title>御财 1.2.1</title>
      <description><![CDATA[chore(release): v1.2.1]]></description>
      <sparkle:version>1.2.1</sparkle:version>
      <enclosure url="https://github.com/williamparris1995/syfinance/releases/download/v1.2.1/yucai-setup-1.2.1.exe" sparkle:version="1.2.1" sparkle:shortVersionString="1.2.1" sparkle:dsaSignature="sig==" length="34615421" type="application/octet-stream"/>
    </item>
  </channel>
</rss>
''';

UpdateCenter _center({
  required Directory tmp,
  http.Client? client,
}) =>
    UpdateCenter(client: client, cacheDirPath: tmp.path);

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('update_center_test');
  });
  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  group('compareVersions', () {
    test('三段数值比较 + 段缺省补零 + 构建号忽略', () {
      expect(UpdateCenter.compareVersions('1.2.1', '1.2.0'), greaterThan(0));
      expect(UpdateCenter.compareVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(UpdateCenter.compareVersions('2.0', '1.99.99'), greaterThan(0));
      expect(UpdateCenter.compareVersions('1.2.0', '1.2.0'), 0);
      expect(UpdateCenter.compareVersions('1.2.0+15', '1.2.0'), 0,
          reason: '+N 构建号不进比较(tag/pubspec 同源口径)');
      expect(UpdateCenter.compareVersions('1.2.0', '1.2.1'), lessThan(0));
    });
  });

  group('parseAppcast', () {
    test('解析首 item:version/url/length(v1.2.1 实形)', () {
      final info = UpdateCenter.parseAppcast(_appcastV121)!;
      expect(info.version, '1.2.1');
      expect(info.url, contains('yucai-setup-1.2.1.exe'));
      expect(info.lengthBytes, 34615421);
      expect(info.sizeLabel, '33.0 MB');
    });

    test('无 item / 缺 length / 非数字 length → null', () {
      expect(UpdateCenter.parseAppcast('<rss></rss>'), isNull);
      expect(
          UpdateCenter.parseAppcast(
              '<item><sparkle:version>1.0.0</sparkle:version>'
              '<enclosure url="u" length="0"/></item>'),
          isNull);
      expect(
          UpdateCenter.parseAppcast(
              '<item><sparkle:version>1.0.0</sparkle:version>'
              '<enclosure url="u" length="abc"/></item>'),
          isNull);
    });
  });

  group('fetchLatest', () {
    test('200 → 解析;500 / 网络异常 → null(不抛)', () async {
      // content-type 带 charset=utf-8:Response 缺省按 latin1 编码 body,
      // 中文实形串会炸 handler(真实源恒带 charset,口径一致)。
      final ok = _center(
          tmp: tmp,
          client: MockClient((_) async => http.Response(_appcastV121, 200,
              headers: {'content-type': 'text/xml; charset=utf-8'})));
      expect((await ok.fetchLatest())?.version, '1.2.1');

      final serverErr = _center(
          tmp: tmp, client: MockClient((_) async => http.Response('x', 500)));
      expect(await serverErr.fetchLatest(), isNull);

      final dead = _center(
          tmp: tmp,
          client: MockClient((_) async => throw const SocketException('net')));
      expect(await dead.fetchLatest(), isNull);
    });
  });

  group('isUpdateAvailable', () {
    test('currentVersion 注入:高版本真 / 平版本假', () async {
      final c = _center(
          tmp: tmp,
          client: MockClient((_) async => http.Response(_appcastV121, 200,
              headers: {'content-type': 'text/xml; charset=utf-8'})));
      expect(
          await c.isUpdateAvailable(
              currentVersion: '1.2.0', latestVersion: null),
          isTrue);
      final info = UpdateCenter.parseAppcast(_appcastV121)!;
      expect(await c.isUpdateAvailable(currentVersion: '1.2.1', latestVersion: info),
          isFalse);
    });
  });

  group('缓存命中与下载', () {
    test('命中 = 存在且字节长度吻合;长度不吻合 = 未命中', () async {
      final c = _center(tmp: tmp);
      final info = UpdateCenter.parseAppcast(
          _appcastV121.replaceFirst('34615421', '10'))!; // length=10

      expect(await c.isCached(info), isFalse, reason: '文件不存在');

      final f = await c.cacheFileFor(info);
      await f.writeAsBytes(List.filled(5, 1));
      expect(await c.isCached(info), isFalse, reason: '半包(5≠10)');

      await f.writeAsBytes(List.filled(10, 1));
      expect(await c.isCached(info), isTrue);
    });

    test('下载:.part 落名 + 进度回调 + 长度吻合成功', () async {
      final payload = utf8.encode('0123456789'); // 10 bytes
      final info = UpdateCenter.parseAppcast(
          _appcastV121.replaceFirst('34615421', '10'))!;
      final c = _center(
        tmp: tmp,
        client: MockClient.streaming(
          (req, body) async => http.StreamedResponse(
              Stream.value(payload), 200,
              contentLength: payload.length),
        ),
      );

      final progress = <int>[];
      final f = await c.download(info, onProgress: (r, t) => progress.add(r));
      expect(await f.exists(), isTrue);
      expect(await f.length(), 10);
      expect(progress.last, 10, reason: '末次回调 = 总长');
      expect(
          await File('${f.path}.part').exists(), isFalse, reason: '.part 已落名');
    });

    test('长度不吻合:抛错 + 目标/.part 双清(不留假缓存)', () async {
      final payload = utf8.encode('0123456789'); // 10 bytes,声明 11
      final info = UpdateCenter.parseAppcast(
          _appcastV121.replaceFirst('34615421', '11'))!;
      final c = _center(
        tmp: tmp,
        client: MockClient.streaming(
          (req, body) async => http.StreamedResponse(
              Stream.value(payload), 200,
              contentLength: payload.length),
        ),
      );

      await expectLater(c.download(info), throwsA(isA<HttpException>()));
      final target = await c.cacheFileFor(info);
      expect(await target.exists(), isFalse);
      expect(await File('${target.path}.part').exists(), isFalse);
    });

    test('下载成功清旧版本缓存(只留当前)', () async {
      final stale = File(
          '${tmp.path}${Platform.pathSeparator}yucai-setup-1.0.0.exe');
      await stale.writeAsBytes(List.filled(4, 0));
      final keepGuard = File(
          '${tmp.path}${Platform.pathSeparator}notes.txt');
      await keepGuard.writeAsBytes(List.filled(2, 0));

      final payload = utf8.encode('abcdefghij');
      final info = UpdateCenter.parseAppcast(
          _appcastV121.replaceFirst('34615421', '10'))!;
      final c = _center(
        tmp: tmp,
        client: MockClient.streaming(
          (req, body) async => http.StreamedResponse(Stream.value(payload), 200),
        ),
      );
      await c.download(info);

      expect(await stale.exists(), isFalse, reason: '旧版本安装包清除');
      expect(await keepGuard.exists(), isTrue, reason: '非安装包文件不动');
      expect(
          (await c.cacheFileFor(info)).existsSync(), isTrue,
          reason: '当前版本保留');
    });
  });
}
