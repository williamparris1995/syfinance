// F58 I-1(评审修复)— DetailTitleSync 组件单测。
//
// 钉死四个语义:
//  - 注入:build 期不同步 set(build 后、帧回调前 port 不变),帧回调 set(title);
//  - 幂等:同值重建不再 notify(回调内 port.value != title 才 set);
//  - null 不动:未加载/失败态不注入、也不清已注入值(清理归页面 dispose);
//  - guarded:port 未注册(stripped harness)静默跳过不崩。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:yucai_client/core/shell_detail_title.dart';
import 'package:yucai_client/core/widgets/detail_title_sync.dart';

Widget _host(String? title) =>
    MaterialApp(home: Scaffold(body: DetailTitleSync(title: title)));

void main() {
  tearDown(() {
    GetIt.instance.reset();
  });

  testWidgets('注入:帧回调 set(title),build 期不同步', (t) async {
    final port = ShellDetailTitle();
    addTearDown(port.dispose);
    GetIt.instance.registerLazySingleton<ShellDetailTitle>(() => port);

    await t.pumpWidget(_host('平安现金分期'));
    // build 刚完成、帧回调未跑:port 仍 null(不可 build 期同步 set ——
    // 会打 _TopBar 的 ValueListenableBuilder markNeedsBuild during build)。
    expect(port.value, isNull);
    await t.pump();
    expect(port.value, '平安现金分期');
  });

  testWidgets('幂等:同值重建不再 notify(零 churn)', (t) async {
    final port = ShellDetailTitle();
    addTearDown(port.dispose);
    GetIt.instance.registerLazySingleton<ShellDetailTitle>(() => port);
    var notified = 0;
    port.addListener(() => notified++);

    await t.pumpWidget(_host('A'));
    await t.pump();
    expect(port.value, 'A');
    expect(notified, 1, reason: '首注入恰好一次通知');

    // 同值重建(loaded 分支高频重建路径)+ 多帧推进。
    await t.pumpWidget(_host('A'));
    await t.pump();
    await t.pump();
    expect(port.value, 'A');
    expect(notified, 1, reason: '同值不重复 set/notify');
  });

  testWidgets('null 不动:不注入、不清已注入值', (t) async {
    final port = ShellDetailTitle();
    addTearDown(port.dispose);
    GetIt.instance.registerLazySingleton<ShellDetailTitle>(() => port);
    port.set('已就位标题');
    var notified = 0;
    port.addListener(() => notified++);

    // title null(未加载/失败)→ 组件不动 port。
    await t.pumpWidget(_host(null));
    await t.pump();
    await t.pump();
    expect(port.value, '已就位标题', reason: 'null 不清零(清理归页面 dispose)');
    expect(notified, 0);
  });

  testWidgets('值变更(编辑改名/didPopNext 重拉)→ 注入新值', (t) async {
    final port = ShellDetailTitle();
    addTearDown(port.dispose);
    GetIt.instance.registerLazySingleton<ShellDetailTitle>(() => port);

    await t.pumpWidget(_host('旧名'));
    await t.pump();
    expect(port.value, '旧名');

    await t.pumpWidget(_host('新名'));
    await t.pump();
    expect(port.value, '新名');
  });

  testWidgets('guarded:port 未注册(stripped harness)静默跳过不崩', (t) async {
    await t.pumpWidget(_host('A'));
    await t.pump();
    // 无注册无异常即通过(getIt 访问被 isRegistered 守卫)。
  });

  testWidgets('TickerMode 关闭(分支冻结/offstage)→ 不注入', (t) async {
    final port = ShellDetailTitle();
    addTearDown(port.dispose);
    GetIt.instance.registerLazySingleton<ShellDetailTitle>(() => port);
    var notified = 0;
    port.addListener(() => notified++);

    // 模拟 StatefulShellRoute 非活跃分支容器:Offstage(TickerMode(false))。
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Offstage(
          offstage: true,
          child: TickerMode(enabled: false, child: _host('冻结分支标题')),
        ),
      ),
    ));
    await t.pump();
    await t.pump();
    expect(port.value, isNull, reason: '非活跃分支不得回写标题');
    expect(notified, 0);

    // 活跃位翻转(分支回退)→ 重建 → 帧回调注入。
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Offstage(
          offstage: false,
          child: TickerMode(enabled: true, child: _host('冻结分支标题')),
        ),
      ),
    ));
    await t.pump();
    await t.pump();
    expect(port.value, '冻结分支标题',
        reason: '分支回退(TickerMode 翻转触发重建)→ 重注入');
  });
}
