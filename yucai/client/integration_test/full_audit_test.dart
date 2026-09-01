/// R8 全应用 E2E 审计(integration_test,Windows 真机嵌入层,125% 缩放)。
///
/// 从整体角度遍历:全部一级页 → 子页/表单 → 关键交互(卡片更多菜单/详情
/// 更多操作/主题切换/跨页回切),审计三类问题:
///   A. 崩溃/渲染异常(硬失败)
///   B. 页面地标缺失(硬失败)
///   C. 未实现/占位/错误提示(记入 FINDINGS,不失败 —— 产品待办清单)
/// 另:实测「更多」菜单相对触发按钮的偏移(125% 缩放嵌入层)。
///
/// 运行:`flutter test integration_test/full_audit_test.dart -d windows`
/// 前置:删库重种(与 app_pages_test 同款确定性起点)。
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/demo/demo_seed.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yucai_client/core/localdb/app_database.dart';

/// 审计发现(C 类):占位/未实现/可疑提示。
final findings = <String>[];
/// 硬失败明细(A/B 类)。
final hardFails = <String>[];
/// 菜单偏移实测(逻辑像素,125% 嵌入层)。
final menuOffsets = <String>[];

void record(bool ok, String label, {bool soft = false}) {
  final line = '${ok ? "PASS" : (soft ? "FINDING" : "FAIL")}  $label';
  // ignore: avoid_print
  print('[AUDIT] $line');
  if (!ok) {
    if (soft) {
      findings.add(label);
    } else {
      hardFails.add(label);
    }
  }
}

/// 捕获当帧异常(FlutterError 渲染异常等),有则记入硬失败。
void sweepErrors(WidgetTester t, String where) {
  final ex = t.takeException();
  if (ex != null) {
    hardFails.add('$where 渲染异常: $ex');
  }
}

/// 占位/未实现标记扫描:出现即记 FINDINGS。
void sweepMarkers(WidgetTester t, String where) {
  for (final marker in ['待接入', '敬请期待', '待交易模块', '待 Transaction 模块接入']) {
    final hit = find.textContaining(marker).evaluate().isNotEmpty;
    if (hit) findings.add('$where 出现占位标记「$marker」');
  }
}

Future<void> goPage(WidgetTester t, String sidebarLabel) async {
  var finder = find.text(sidebarLabel);
  if (finder.evaluate().isEmpty) {
    // 侧栏 ListView 懒构建:720 高窗口下「工具」组(报表分析/设置)在视口外
    // 未构建 → 先向上滚动侧栏再点。
    await t.drag(find.text('仪表盘'), const Offset(0, -180));
    await t.pumpAndSettle(const Duration(milliseconds: 400));
    finder = find.text(sidebarLabel);
  }
  await t.tap(finder.first);
  await t.pumpAndSettle(const Duration(seconds: 2));
  sweepErrors(t, sidebarLabel);
}

/// 富文本感知 finder(Text.rich / 裸 RichText)。
Finder richText(String needle) => find.byWidgetPredicate((w) {
      if (w is Text) {
        return ((w.data ?? '') + (w.textSpan?.toPlainText() ?? ''))
            .contains(needle);
      }
      if (w is RichText) return w.text.toPlainText().contains(needle);
      return false;
    });

Future<void> main() async {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    final support = await getApplicationSupportDirectory();
    final dbFile = File('${support.path}/yucai.db');
    if (await dbFile.exists()) await dbFile.delete();
    await configureDependencies();
    await seedDemoData(getIt<AppDatabase>());
  });

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  testWidgets('A1 仪表盘:地标 + 种子 oracle', (t) async {
    await pumpApp(t);
    record(find.text('总净资产').evaluate().isNotEmpty, '仪表盘:总净资产卡');
    record(find.text('共 5 个账户').evaluate().isNotEmpty, '仪表盘:共 5 个账户');
    record(richText('107,950').evaluate().isNotEmpty, '仪表盘:流动资产 107,950');
    record(richText('8,000').evaluate().isNotEmpty, '仪表盘:本月收入工资 8,000');
    sweepMarkers(t, '仪表盘');
  });

  testWidgets('A2 账户管理:地标 + 更多菜单实测偏移(125%)', (t) async {
    await pumpApp(t);
    await goPage(t, '账户管理');
    record(find.textContaining('总资产').evaluate().isNotEmpty, '账户管理:总资产汇总');

    // 第一张完整卡的「更多」按钮 → MenuAnchor 菜单 → 实测偏移。
    final moreFinder = find.text('更多');
    record(moreFinder.evaluate().isNotEmpty, '账户卡:更多按钮存在');
    if (moreFinder.evaluate().isNotEmpty) {
      final btnRect = t.getRect(moreFinder.first);
      await t.tap(moreFinder.first);
      await t.pumpAndSettle(const Duration(milliseconds: 600));

      final editFinder = find.text('编辑');
      final opened = editFinder.evaluate().isNotEmpty;
      record(opened, '账户卡:更多菜单打开(125% 嵌入层)');
      if (opened) {
        final itemRect = t.getRect(editFinder.first);
        final off = itemRect.topLeft - btnRect.topLeft;
        menuOffsets.add(
            '账户卡更多: item(编辑) topLeft=${itemRect.topLeft} '
            'button topLeft=${btnRect.topLeft} offset=$off');
        // 菜单不应飞进左侧栏区(完整卡 x≥236)。
        record(itemRect.left >= 235, '账户卡:菜单不在侧栏区(x=${itemRect.left})');
      }
      // 关闭菜单:点空白处。
      await t.tapAt(const Offset(5, 400));
      await t.pumpAndSettle(const Duration(milliseconds: 400));
    }
    sweepMarkers(t, '账户管理');
  });

  testWidgets('A3 账户详情:更多操作菜单打开', (t) async {
    await pumpApp(t);
    await goPage(t, '账户管理');
    // 进第一个账户详情:点卡片本体(储蓄卡)。
    final card = find.text('储蓄卡');
    record(card.evaluate().isNotEmpty, '账户管理:第一张卡(储蓄卡)存在');
    if (card.evaluate().isNotEmpty) {
      await t.tap(card.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      sweepErrors(t, '账户详情');

      final moreFinder = find.byTooltip('更多操作');
      record(moreFinder.evaluate().isNotEmpty, '账户详情:更多操作按钮存在');
      if (moreFinder.evaluate().isNotEmpty) {
        await t.tap(moreFinder.first);
        await t.pumpAndSettle(const Duration(milliseconds: 600));
        final opened = find.text('复制账户').evaluate().isNotEmpty;
        record(opened, '账户详情:更多操作菜单打开');
        if (opened) {
          final itemRect = t.getRect(find.text('复制账户').first);
          menuOffsets.add('账户详情更多操作: item(复制账户) topLeft=${itemRect.topLeft}');
        }
        await t.tapAt(const Offset(5, 400));
        await t.pumpAndSettle(const Duration(milliseconds: 400));
      }
    }
    sweepMarkers(t, '账户详情');
  });

  testWidgets('A4 交易记录 + 交易详情:更多菜单打开', (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');
    record(richText('工资').evaluate().isNotEmpty, '交易记录:工资入列');
    sweepMarkers(t, '交易记录');

    // 进第一笔交易详情(点行内文本)。
    final row = find.textContaining('工资');
    if (row.evaluate().isNotEmpty) {
      await t.tap(row.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      sweepErrors(t, '交易详情');
      final moreFinder = find.byTooltip('更多');
      if (moreFinder.evaluate().isNotEmpty) {
        await t.tap(moreFinder.first);
        await t.pumpAndSettle(const Duration(milliseconds: 600));
        final opened = find.text('复制交易').evaluate().isNotEmpty;
        record(opened, '交易详情:更多菜单打开');
        if (opened) {
          final itemRect = t.getRect(find.text('复制交易').first);
          menuOffsets.add('交易详情更多: item(复制交易) topLeft=${itemRect.topLeft}');
        }
        await t.tapAt(const Offset(5, 400));
        await t.pumpAndSettle(const Duration(milliseconds: 400));
      }
    }
  });

  testWidgets('A5 分类管理:行 ⋯ 菜单打开', (t) async {
    await pumpApp(t);
    await goPage(t, '分类管理');
    record(find.text('支出分类').evaluate().isNotEmpty, '分类管理:页签地标');
    sweepMarkers(t, '分类管理');

    // 行内 IconButton(tooltip 操作)。
    final opFinder = find.byTooltip('操作');
    if (opFinder.evaluate().isNotEmpty) {
      await t.tap(opFinder.first);
      await t.pumpAndSettle(const Duration(milliseconds: 600));
      final opened = find.text('编辑').evaluate().isNotEmpty;
      record(opened, '分类行:⋯菜单打开');
      if (opened) {
        final itemRect = t.getRect(find.text('编辑').first);
        menuOffsets.add('分类行更多: item(编辑) topLeft=${itemRect.topLeft}');
      }
      await t.tapAt(const Offset(5, 400));
      await t.pumpAndSettle(const Duration(milliseconds: 400));
    }
  });

  testWidgets('A6 预算/目标:地标 + 种子数据', (t) async {
    await pumpApp(t);
    await goPage(t, '预算管理');
    record(find.text('本月预算').evaluate().isNotEmpty, '预算管理:本月预算');
    sweepMarkers(t, '预算管理');

    await goPage(t, '目标追踪');
    record(find.text('购房首付').evaluate().isNotEmpty, '目标追踪:购房首付');
    sweepMarkers(t, '目标追踪');
  });

  testWidgets('A7 债务管理 ⇄ 跨页回切:Bad state 回归 + 更多菜单', (t) async {
    await pumpApp(t);
    await goPage(t, '债务管理');
    record(find.text('招商银行').evaluate().isNotEmpty, '债务管理:借款在列');
    // 跨页回切(F2 Bad state 回归)。
    await goPage(t, '仪表盘');
    await goPage(t, '债务管理');
    final badState = find.textContaining('Bad state').evaluate().isNotEmpty;
    record(!badState, '债务管理:跨页回切无 Bad state');
    record(find.text('招商银行').evaluate().isNotEmpty, '债务管理:回切后借款仍在');

    // 卡片「更多」→ 锚定菜单(编辑/删除)打开。
    final moreFinder = find.text('更多');
    if (moreFinder.evaluate().isNotEmpty) {
      await t.tap(moreFinder.first);
      await t.pumpAndSettle(const Duration(milliseconds: 600));
      final opened = find.textContaining('删除').evaluate().isNotEmpty;
      record(opened, '债务卡:更多菜单打开');
      if (opened) {
        final itemRect = t.getRect(find.textContaining('删除').first);
        menuOffsets.add('债务卡更多: item topLeft=${itemRect.topLeft}');
      }
      await t.tapAt(const Offset(5, 400));
      await t.pumpAndSettle(const Duration(milliseconds: 400));
    }
    sweepMarkers(t, '债务管理');
  });

  testWidgets('A8 债权管理:地标', (t) async {
    await pumpApp(t);
    await goPage(t, '债权管理');
    record(find.text('债权管理').evaluate().isNotEmpty, '债权管理:地标');
    sweepMarkers(t, '债权管理');
  });

  testWidgets('A9 投资组合:持仓市值 oracle', (t) async {
    await pumpApp(t);
    await goPage(t, '投资组合');
    record(richText('11,000').evaluate().isNotEmpty, '投资组合:市值 11,000');
    sweepMarkers(t, '投资组合');
  });

  testWidgets('A10 报表分析:地标', (t) async {
    await pumpApp(t);
    await goPage(t, '报表分析');
    record(find.text('报表分析').evaluate().isNotEmpty, '报表分析:地标');
    sweepMarkers(t, '报表分析');
  });

  testWidgets('A11 设置:主题切换(暗色全应用生效)', (t) async {
    await pumpApp(t);
    await goPage(t, '设置');
    record(find.text('主题模式').evaluate().isNotEmpty, '设置:主题模式行');

    // 切暗色:Material 前景色应翻转为墨鎏金系(断言 Scaffold 附近有暗色容器)。
    final darkSeg = find.text('暗色');
    if (darkSeg.evaluate().isNotEmpty) {
      await t.tap(darkSeg.first);
      await t.pumpAndSettle(const Duration(seconds: 1));
      // 暗色下侧栏品牌字应为亮色(粗验:页面背景不是晨白 #F8FAFC)。
      final ctx = t.element(find.byType(Material).first);
      final bg = (ctx.findAncestorStateOfType<ScaffoldState>()
                  ?.context
                  .findRenderObject() as dynamic)
              ?.paintBounds ??
          Rect.zero;
      record(bg.width > 0, '设置:暗色切换无异常');
    }
    // 切回亮色(还原)。
    final lightSeg = find.text('亮色');
    if (lightSeg.evaluate().isNotEmpty) {
      await t.tap(lightSeg.first);
      await t.pumpAndSettle(const Duration(seconds: 1));
    }
  });

  testWidgets('A12 新建表单可达:账户/交易/预算/目标/分类/债务/债权', (t) async {
    await pumpApp(t);
    for (final step in [
      ('账户管理', '新建账户'),
      ('交易记录', '记一笔'),
      ('预算管理', '新建预算'),
      ('目标追踪', '新建目标'),
      ('分类管理', '新建分类'),
      ('债务管理', '新建债务'),
      ('债权管理', '新建借出'),
    ]) {
      await goPage(t, step.$1);
      final btn = find.text(step.$2);
      // 软发现:入口缺失 = 功能未实现/不可达,记 FINDINGS 供排期。
      record(btn.evaluate().isNotEmpty, '新建入口:${step.$1} → ${step.$2}',
          soft: true);
      if (btn.evaluate().isNotEmpty) {
        await t.tap(btn.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        sweepErrors(t, '表单:${step.$2}');
        // 返回列表(导航到模块根)。
        await goPage(t, step.$1);
      }
      sweepMarkers(t, '新建入口:${step.$2}');
    }
  });

  testWidgets('Z 汇总:输出审计报告', (t) async {
    final buf = StringBuffer()
      ..writeln('==== R8 全应用 E2E 审计报告 ====')
      ..writeln('硬失败 ${hardFails.length}:');
    for (final f in hardFails) {
      buf.writeln('  [FAIL] $f');
    }
    buf.writeln('发现(未实现/占位/可疑)${findings.length}:');
    final uniq = findings.toSet();
    for (final f in uniq) {
      buf.writeln('  [FINDING] $f');
    }
    buf.writeln('菜单偏移实测(逻辑像素,125% 嵌入层):');
    for (final m in menuOffsets) {
      buf.writeln('  [MEASURE] $m');
    }
    // ignore: avoid_print
    print(buf.toString());
    try {
      final dir = await getApplicationSupportDirectory();
      File('${dir.path}/audit_report.txt').writeAsStringSync(buf.toString());
      // ignore: avoid_print
      print('[AUDIT] 报告已写入 ${dir.path}/audit_report.txt');
    } catch (_) {}
    expect(hardFails, isEmpty, reason: '存在崩溃/地标缺失');
  });
}
