/// F24 更新链 v2(2026-11-05,WinSparkle 退役 → app 自管):
///
/// 旧链(auto_updater 1.0.0 / WinSparkle 0.8.1)两硬伤,用户实测实锤:
/// 1. 下载落 %TEMP% 跑完即弃、零缓存 —— 安装失败(边车锁文件)后每次
///    重试都重下 33MB;
/// 2. 引擎 UI 全英文且流程不可控(下载完立即在 app 存活状态下拉起安装
///    器,叠加 app「关闭即最小化」→ 安装必败)。
///
/// 新链职责(app 全自管):
/// - [fetchLatest] 拉 appcast.xml(F24 既有 feed,格式不变)解析最新版;
/// - [isUpdateAvailable] 与 PackageInfo.version(缺省)比对;
/// - 缓存目录 `%APPDATA%/com.yucai/yucai_client/updates/`:`yucai-setup-
///   <ver>.exe`,**存在且字节长度与 appcast enclosure length 吻合 = 命中,
///   直接复用零下载**(下载只发生在每个版本第一次);
/// - [download] 带 .part 临时名写盘、长度校验、成功后落名并清旧版本;
/// - [install] 拉起安装器(detached)→ 走既有 [AppExitPort] 退出链
///   (托盘清理 + llama-server 边车树杀 + exit(0),见 F66 T3-H1)——
///   安装器 PrepareToInstall 的 taskkill 兜底(2026-11-05 iss 修复)双保险。
///
/// 完整性档位(相对旧链 DSA 验签的取舍,记录在案):传输 = HTTPS 直连
/// github.com,文件完整性 = 与同一 HTTPS appcast 的 enclosure length 逐
/// 字节核对。Sparkle DSA 验签属 WinSparkle 引擎内置能力,Dart 侧复刻需
/// 自拼 pointycastle 密码学链(违 F24 ADR-1「理财 app 不手写密码学」),
/// 暂不跟随;dsa_pub.pem 资源与 appcast 签名属性保留(回滚 WinSparkle
/// 零成本)。升级档位为后续事项。
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show ValueNotifier, immutable, visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:yucai_client/core/di/injection.dart' show getIt;
import 'package:yucai_client/core/notifications/app_exit_port.dart';

/// appcast 解析产物(单 item,字段即 enclosure 三要素)。
@immutable
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.url,
    required this.lengthBytes,
  });

  /// 形如 `1.2.1`(sparkle:version,与 pubspec 版本同源)。
  final String version;

  /// 安装包直链(GitHub Release 资产)。
  final String url;

  /// appcast enclosure length(字节;完整性核对基准 + 下载进度分母)。
  final int lengthBytes;

  /// 展示用大小(MB,一位小数)。
  String get sizeLabel =>
      '${(lengthBytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// 更新中心:检查 / 缓存 / 下载 / 安装单点(手动检查与后台周期检查共用)。
class UpdateCenter {
  UpdateCenter({http.Client? client, String? cacheDirPath})
      : _client = client ?? http.Client(),
        _cacheDir = cacheDirPath;

  /// F24 FR-2:latest release 资产恒指向最新,URL 稳定零基础设施。
  static const String feedUrl =
      'https://github.com/williamparris1995/syfinance/releases/latest/download/appcast.xml';

  /// 后台周期检查间隔(对齐旧 WinSparkle 引擎缺省 1 天,FR-5 行为不变)。
  static const Duration _recheckInterval = Duration(hours: 24);

  /// 启动静默检查延迟(避开启动争用,照托盘首扫 ADR-5 先例)。
  static const Duration _firstCheckDelay = Duration(seconds: 15);

  final http.Client _client;
  final String? _cacheDir;
  Timer? _timer;

  /// 后台周期检查产物(设置页「关于与更新」卡徽标数据源);null = 无新版
  /// 或尚未检查。ValueNotifier 而非 Bloc:纯展示旁路,无业务态可管。
  final ValueNotifier<UpdateInfo?> latest = ValueNotifier(null);

  /// FR-5:启动静默检查 + 每日重查(不弹任何 UI;手动入口见
  /// [showUpdateDialog] 调用方)。失败静默(latest 不动)。
  void start() {
    _timer?.cancel();
    Timer(_firstCheckDelay, _silentCheck);
    _timer = Timer.periodic(_recheckInterval, (_) => _silentCheck());
  }

  Future<void> _silentCheck() async {
    try {
      final info = await fetchLatest();
      // 拉取失败(null)保持既有值:网络瞬断不抹掉已知新版徽标。
      if (info == null) return;
      final current = (await PackageInfo.fromPlatform()).version;
      latest.value =
          compareVersions(info.version, current) > 0 ? info : null;
    } catch (_) {
      // 后台检查失败静默(附属功能降级先例);手动入口自会给出错误态。
    }
  }

  /// 拉取并解析 appcast;任一环节失败返回 null(不抛,调用方免 try/catch)。
  Future<UpdateInfo?> fetchLatest() async {
    try {
      final res = await _client
          .get(Uri.parse(feedUrl))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;
      return parseAppcast(res.body);
    } catch (_) {
      return null;
    }
  }

  /// 解析 appcast.xml(自产格式,tool/gen_appcast.py 单源):取首个
  /// `<item>` 的 `<sparkle:version>` 与 `<enclosure>` url/length。
  /// 正则而非 xml 库:格式自产冻结、单 item,免引入 xml 直接依赖
  /// (pdf 的传递依赖不入耦合面)。
  @visibleForTesting
  static UpdateInfo? parseAppcast(String xml) {
    final item =
        RegExp(r'<item>([\s\S]*?)</item>').firstMatch(xml)?.group(1);
    if (item == null) return null;
    final version = RegExp(r'<sparkle:version>\s*([^<]+?)\s*</sparkle:version>')
            .firstMatch(item)
            ?.group(1) ??
        RegExp(r'sparkle:shortVersionString="([^"]+)"')
            .firstMatch(item)
            ?.group(1);
    final enclosure = RegExp(r'<enclosure\s+([^>]*?)/?>').firstMatch(item)
        ?.group(1);
    final url =
        RegExp(r'url="([^"]+)"').firstMatch(enclosure ?? '')?.group(1);
    final length =
        RegExp(r'length="(\d+)"').firstMatch(enclosure ?? '')?.group(1);
    if (version == null || url == null || length == null) return null;
    final lengthBytes = int.tryParse(length);
    if (lengthBytes == null || lengthBytes <= 0) return null;
    return UpdateInfo(
        version: version, url: url, lengthBytes: lengthBytes);
  }

  /// 语义化三段比较(X.Y.Z;段缺省 0 补齐,非数字段按 0 处理)。
  /// 返回:<0 a 旧 / 0 同 / >0 a 新。
  @visibleForTesting
  static int compareVersions(String a, String b) {
    int seg(String s, int i) {
      final parts = s.trim().split(RegExp(r'[.+]'));
      return i < parts.length ? (int.tryParse(parts[i]) ?? 0) : 0;
    }

    for (var i = 0; i < 3; i++) {
      final d = seg(a, i) - seg(b, i);
      if (d != 0) return d;
    }
    return 0;
  }

  /// [currentVersion] 注入缝(测试);缺省取 PackageInfo(pubspec 单源)。
  /// [latestVersion] 缺省自取 [fetchLatest]。
  Future<bool> isUpdateAvailable(
      {String? currentVersion, UpdateInfo? latestVersion}) async {
    final info = latestVersion ?? await fetchLatest();
    if (info == null) return false;
    final current =
        currentVersion ?? (await PackageInfo.fromPlatform()).version;
    return compareVersions(info.version, current) > 0;
  }

  /// 缓存目录(`updates/`,与 yucai.db 同根;测试经构造注入覆盖)。
  Future<Directory> cacheDir() async {
    if (_cacheDir != null) {
      final d = Directory(_cacheDir);
      await d.create(recursive: true);
      return d;
    }
    final appData = await getApplicationSupportDirectory();
    final d = Directory('${appData.path}${Platform.pathSeparator}updates');
    await d.create(recursive: true);
    return d;
  }

  /// 版本对应缓存文件名(与 CI 产物 `yucai-setup-<ver>.exe` 同名,
  /// 回显直觉一致)。
  @visibleForTesting
  static String cacheFileName(String version) =>
      'yucai-setup-$version.exe';

  Future<File> cacheFileFor(UpdateInfo info) async =>
      File((await cacheDir()).uri
          .resolve(cacheFileName(info.version))
          .toFilePath());

  /// 命中 = 文件存在 **且** 字节长度与 appcast length 吻合(半包/损坏
  /// 一律视为未命中,重下)。
  Future<bool> isCached(UpdateInfo info) async {
    final f = await cacheFileFor(info);
    if (!await f.exists()) return false;
    return await f.length() == info.lengthBytes;
  }

  /// 下载安装包入缓存(.part 写盘 → 长度核对 → 落名;不吻合删件抛错,
  /// 不留假缓存)。[onProgress](received, total) 供进度 UI。
  Future<File> download(
      UpdateInfo info, {void Function(int received, int total)? onProgress}) async {
    final dir = await cacheDir();
    final target = File(
        dir.uri.resolve(cacheFileName(info.version)).toFilePath());
    final part = File('${target.path}.part');
    try {
      final res = await _client
          .send(http.Request('GET', Uri.parse(info.url)))
          .timeout(const Duration(minutes: 30));
      if (res.statusCode != 200) {
        throw HttpException('download status ${res.statusCode}');
      }
      final sink = part.openWrite();
      var received = 0;
      await for (final chunk in res.stream) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, info.lengthBytes);
      }
      await sink.flush();
      await sink.close();
      if (received != info.lengthBytes) {
        throw HttpException(
            'length mismatch: got $received want ${info.lengthBytes}');
      }
      await part.rename(target.path);
      await _pruneOtherVersions(info.version);
      return target;
    } catch (_) {
      // 失败清理:.part 半包与(长度不吻合时的)目标名假缓存都不留。
      if (await part.exists()) await part.delete();
      rethrow;
    }
  }

  /// 安装:确保缓存(命中零下载,未命中先下)→ 拉起安装器(detached)→
  /// 走 [AppExitPort] 退出链(托盘 + 边车树杀 + exit)。安装器
  /// PrepareToInstall 的 taskkill 对残存进程兜底(双保险)。
  Future<void> install(
      UpdateInfo info, {void Function(int received, int total)? onProgress}) async {
    if (!await isCached(info)) {
      await download(info, onProgress: onProgress);
    }
    final file = await cacheFileFor(info);
    await Process.start(file.path, const [],
        mode: ProcessStartMode.detached);
    await getIt<AppExitPort>().exitApp();
  }

  /// 清掉非当前版本缓存(下载成功后调用;历史版本安装包无复用价值)。
  /// 只认 `yucai-setup-*.exe` 命名面 —— 缓存目录里其他文件(手工放置等)
  /// 一律不动;.part 半包亦非本口径(失败路径自清)。
  Future<void> _pruneOtherVersions(String keepVersion) async {
    final dir = await cacheDir();
    final keep = cacheFileName(keepVersion);
    await for (final e in dir.list()) {
      final name = e.uri.pathSegments.last;
      if (e is File &&
          name.startsWith('yucai-setup-') &&
          name.endsWith('.exe') &&
          name != keep) {
        try {
          await e.delete();
        } catch (_) {}
      }
    }
  }

  /// 测试/进程退出前的定时器清理(生产进程 exit 自然回收)。
  @visibleForTesting
  void dispose() {
    _timer?.cancel();
    _timer = null;
    latest.dispose();
  }
}

/// F24 FR-4/5 + ADR-4(2026-11-05 v2):更新中心 bootstrap —— 注册 getIt
/// 单例(手动注册,照 injection.dart 1m 手工先例;设置页/托盘经
/// showUpdateDialog 解析)+ 启动静默检查与每日重查。附属降级:失败仅
/// print 英文不阻断启动(NFR-1;手动检查入口恒可用 —— 未注册时对话框
/// 给「组件未就绪」态)。
Future<void> bootstrapUpdateCenter() async {
  try {
    final center = UpdateCenter();
    getIt.registerSingleton<UpdateCenter>(center);
    center.start();
  } catch (e) {
    // ignore: avoid_print — 附属功能降级,不阻断主程序。
    print('update center bootstrap degraded: $e');
  }
}
