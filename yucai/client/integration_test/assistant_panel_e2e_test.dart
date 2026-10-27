/// F65-T5 E2E:助手浮层引导态全链(真壳形态;spec FR-1 场景二 +
/// FR-3 设置卡渲染)。
///
/// 链路:真壳 pump app(真 DI/真路由/真 AssistantOverlayHost 挂载)→
/// ① 右下助手 FAB(assistantFab)可点 → ② 400px 浮层出现(空态引导 +
/// 示例问题 chips,v19 state-1)→ ③ 点示例问题即发送 → 助手未启用
/// (setUpAll 钉 disabled)→ GuideMsg 未启用引导卡(「AI 助手未启用」/
/// 「在设置中开启…」/「去设置」),**零 LLM 调用**(bloc 三重守卫在
/// loop.send 之前拦截;引擎侧 ensureReady 对 disabled 直接 return,
/// 不拉边车进程)→ ④ 「去设置」跳 /settings → 「AI 助手」端侧模型
/// 管理卡渲染(未下载态:启用开关 + 「未下载」chip + 下载按钮)→
/// ⑤ 收起浮层(FAB 常驻,会话跨开合保留 —— 关闭仅收 UI)。
///
/// 全程无需引擎/模型(引导态即验收面);验收面 = FR-1 未就绪引导 +
/// FR-3 卡未下载态,零 LLM 零进程零网络。
///
/// 夹具:resetTestDb 幂等演示种子(真壳需要的 DI/库),另把
/// AssistantSettings 钉回缺省关闭态 —— secure storage 是开发机真实
/// 存储(与 NavSettings 折叠态同泄漏面),残留 enabled=true 会把引导
/// 卡换成 modelNotReady 且触发引擎拉起;写入值 = 缺省关闭态,对
/// 本机真实 app 零可感差异(助手功能未随任何 tag 发版)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑有设备启动竞争)。
/// 运行:`flutter test integration_test/assistant_panel_e2e_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口,F= 单文件精准重跑)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/assistant/data/assistant_settings_store.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/core/di/injection.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(照 link_*/ui_* 惯例)。
    await resetTestDb();
    // 引导态锚定:钉回缺省关闭态(见文件头「夹具」注 —— 防开发机
    // secure storage 残留 enabled=true 换型引导卡 + 误拉引擎)。
    await getIt<AssistantSettings>().setConfig(const AssistantConfig());
  });
  tearDownAll(deleteTestDb);

  testWidgets('FAB→浮层空态→未启用引导(零 LLM)→去设置卡(未下载)→收起',
      (t) async {
    // 真机桌面形态(≥1100 宽 → AppShell desktop 分支;照
    // text_selection_drag_e2e 同款 1440x900 @2x)。
    t.view.physicalSize = const Size(2880, 1800);
    t.view.devicePixelRatio = 2.0;
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));

    // ---- ① 右下助手 FAB 常驻(shell 全域挂载) ----
    final fab = find.byKey(const ValueKey('assistantFab'));
    expect(fab.evaluate(), isNotEmpty, reason: '助手 FAB 应在 app shell 常驻');
    await t.tap(fab);
    await t.pumpAndSettle(const Duration(seconds: 1));

    // ---- ② 浮层出现:头部地标 + 空态引导 + 示例问题 chips(v19 state-1)----
    expect(
        find.byKey(const ValueKey('assistantPanel')).evaluate(), isNotEmpty,
        reason: '点 FAB 后 400px 聊天浮层应出现');
    expect(find.text('御财助手'), findsOneWidget, reason: '浮层头部标题');
    expect(find.text('本机运行'), findsOneWidget, reason: '头部「本机运行」chip');
    expect(find.text('我是御财助手,数据都在本机'), findsOneWidget,
        reason: '空态引导文案(v19 state-1)');
    final chip = find.text('这个月花了多少');
    expect(chip.evaluate(), isNotEmpty, reason: '示例问题 chip 在列');

    // ---- ③ 示例问题即发送 → 未启用引导态(零 LLM 调用)----
    await t.tap(chip);
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('AI 助手未启用'), findsOneWidget,
        reason: '未启用引导卡标题(FR-1 场景二:未就绪引导态)');
    expect(find.text('在设置中开启「AI 助手」后即可使用'), findsOneWidget,
        reason: '未启用引导卡说明');
    // 用户气泡保留(历史输入不丢);零 LLM 面:无助手气泡/工具条/错误条
    // —— 三重守卫在 loop.send 之前拦截(FR-1:不发起任何 LLM 调用)。
    expect(
        find.byKey(const ValueKey('assistantUserBubble')).evaluate(), isNotEmpty,
        reason: '用户消息气泡在列');
    expect(find.byKey(const ValueKey('assistantBotBubble')).evaluate(), isEmpty,
        reason: '零 LLM 调用 → 无助手回复气泡');
    expect(find.byKey(const ValueKey('assistantToolPill')).evaluate(), isEmpty,
        reason: '零 LLM 调用 → 无工具状态条');
    expect(find.byKey(const ValueKey('assistantErrorMsg')).evaluate(), isEmpty,
        reason: '引导态非错误:无错误条');

    // ---- ④ 「去设置」跳 /settings,AI 助手卡渲染(未下载态)----
    await t.tap(find.byKey(const ValueKey('assistantGoSettingsButton')));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('偏好设置'), findsWidgets, reason: '已跳设置页(地标)');
    expect(find.text('AI 助手'), findsWidgets,
        reason: '「AI 助手」端侧模型管理卡渲染(FR-3,与 F46 卡并列)');
    expect(find.text('启用 AI 助手'), findsOneWidget, reason: '启用开关行');
    expect(find.byKey(const ValueKey('assistantEnableSwitch')).evaluate(),
        isNotEmpty,
        reason: '启用开关控件');
    // 模型行状态随真机模型库实查(与文件头 secure storage 泄漏同面的环境
    // 依赖,真壳 DI 不打桩):干净机 =「未下载」+ 下载按钮;开发机模型已在
    // 库(AppData .../yucai/models/*.gguf)=「已就绪」+ 删除钮。两分支都
    // 验模型行按态渲染正确 affordance(F65 热修时适配:原单钉「未下载」在
    // 模型已下载的开发机必红 —— 与打字指示改动无关,引导态不经 streaming)。
    if (find.text('未下载').evaluate().isNotEmpty) {
      expect(
          find.byKey(const ValueKey('assistantDownloadButton')).evaluate(),
          isNotEmpty,
          reason: '未下载态给「下载模型」按钮(首次启用引导下载入口)');
    } else {
      expect(find.text('已就绪').evaluate(), isNotEmpty,
          reason: '模型已在库:就绪态 chip(环境分支,见上注)');
      expect(
          find.byKey(const ValueKey('assistantDeleteModelButton')).evaluate(),
          isNotEmpty,
          reason: '就绪态给删除模型入口');
    }
    // 浮层仍开(去设置不收浮层 —— 全局宿主,会话跨导航保留)。
    expect(find.byKey(const ValueKey('assistantPanel')).evaluate(), isNotEmpty,
        reason: '去设置后浮层仍开(全局宿主不随路由销毁)');

    // ---- ⑤ 收起浮层:FAB 仍在,浮层消失 ----
    await t.tap(find.byKey(const ValueKey('assistantCloseButton')));
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(
        find.byKey(const ValueKey('assistantPanel')).evaluate(), isEmpty,
        reason: '收起后浮层消失');
    expect(find.byKey(const ValueKey('assistantFab')).evaluate(), isNotEmpty,
        reason: 'FAB 常驻可再开');
  });
}
