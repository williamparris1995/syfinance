import 'package:auto_updater/auto_updater.dart' show autoUpdater;

/// F24 客户端自动更新接入(spec FR-4/5 + design ADR-1/4)。
///
/// 引擎事实(auto_updater 1.0.0 源码核对,锁版本):
/// - `autoUpdater.setFeedURL(feedUrl)` 内部即 `win_sparkle_set_appcast_url`
///   + `win_sparkle_init()` —— init 后 WinSparkle 以默认 1 天间隔后台自动
///   检查(FR-5 启动后台自动检查即此,design Open Question 取默认);
/// - `checkForUpdates(inBackground: false)` = `win_sparkle_check_update_with_ui`
///   —— 引擎英文检查弹窗(grill 决策在案:「通用」可接受);
/// - **公钥不经 Dart API**:`setFeedURL` 仅收 URL,验签公钥由 WinSparkle
///   从 exe 资源读取(见下 [publicKeyIsPlaceholder] 注释)。
///
/// 引擎签名档位现实(spec FR-3 定档 DSA(WinSparkle 0.8.1 现实)后本占位为 DSA 钥——替换目标即配套 DSA 公钥(原 EdDSA 表述已过时,review 修),记录在案):auto_updater 1.0.0
/// 捆绑 WinSparkle 0.8.1,仅支持经典 DSA 验签(资源名 "DSAPub" 类型
/// "DSAPEM" 的 PEM 公钥 + appcast `sparkle:dsaSignature`);EdDSA
/// (`EdDSAPub EDDSA` 资源 / `sparkle:edSignature`)属 WinSparkle 0.9+,
/// 本引擎版本不可用。ADR-1 的本意是「不在理财 app 里手写密码学、引擎
/// 内置验签」,故跟随引擎现实取 DSA 档位;升级引擎或换档位为后续事项。
class AppUpdater {
  AppUpdater._();

  /// FR-2:appcast 订阅地址 —— latest release 资产恒指向最新 Release,
  /// URL 稳定零基础设施(gh-pages 备选已 grill 排除)。
  static const String feedUrl =
      'https://github.com/williamparris1995/syfinance/releases/latest/download/appcast.xml';

  /// FR-3:验签公钥**占位状态标记**。当前 true = 客户端烤入的是一次性
  /// 丢弃钥(占位,验签必不过 → 占位期任何更新都拒绝安装,fail-safe)。
  ///
  /// 真钥来源与替换流程(T1 密钥脚本产出后执行):
  /// 1. 跑 T1 的密钥脚本(ADR-3,tool/ 下)产 DSA 密钥对 —— 引擎档位
  ///    见类注释(WinSparkle 0.8.1 = DSA PEM,非 EdDSA);
  /// 2. 私钥仅入 GitHub Actions Secrets,不入库不入日志;
  /// 3. 公钥 PEM 覆盖 `windows/runner/dsa_pub.pem`(该文件经
  ///    `windows/runner/Runner.rc` 的 `DSAPub DSAPEM "dsa_pub.pem"` 资源
  ///    烤入 exe,WinSparkle 实际读取处);
  /// 4. 本标记翻 false(单测 [app_updater_test] 同步翻转,防演练带占位
  ///    密钥发版);
  /// 5. 重跑 `flutter build windows --release` 验证。
  static const bool publicKeyIsPlaceholder = true;

  /// FR-4:初始化 —— setFeedURL(feed 常量)+ 引擎默认 1 天调度。
  ///
  /// 异常向上抛,由 [bootstrapAppUpdater] 降级(附属功能不阻断启动)。
  static Future<void> initialize() => autoUpdater.setFeedURL(feedUrl);

  /// FR-5:手动检查入口(托盘「检查更新」菜单项)→ 引擎检查 UI。
  ///
  /// 引擎未初始化(bootstrap 降级路径)或平台缺失时抛错,由调用方
  /// (tray 菜单 case)catch 吞掉降级 —— 手动检查项恒可点、恒不炸。
  static Future<void> checkForUpdates() =>
      autoUpdater.checkForUpdates(inBackground: false);
}

/// ADR-4:bootstrap 末尾挂接的降级包装 —— 任一环节失败(网络/插件缺失/
/// 平台异常)仅 print 英文降级,不阻断 app 启动与既有功能(NFR-1;
/// 照 notifications_bootstrap 既有「附属功能降级」先例,英文日志约束)。
Future<void> bootstrapAppUpdater() async {
  try {
    await AppUpdater.initialize();
  } catch (e) {
    // ignore: avoid_print — 附属功能降级,不阻断主程序。
    print('app updater init degraded: $e');
  }
}
