/// F6 UI 链:标签页 CRUD(ui_tag_page)。
///
/// 链路:设置 → 标签管理(/settings/tags)→「新建标签」dialog(名称 + 颜色)→
/// 创建 → 行菜单(tooltip 编辑/删除)重命名 → 删除确认 dialog → 列表变化断言。
/// (FR-4 改形后的 UI 面:标签 CRUD;按标签反查交易为 backlog,不在本链。)
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_tag_page_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口 B,手动按需)。
library;

import 'package:flutter/material.dart' show AlertDialog, Scrollable, TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/widgets/data_card.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(演示种子含 必要支出/投资 两标签);
    // 本链全程 UI 交互建标签,无 DS 夹具。
    await resetTestDb();
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  // 侧栏导航 helper(照 full_audit_test.goPage)。
  Future<void> goPage(WidgetTester t, String sidebarLabel) async {
    var finder = find.text(sidebarLabel);
    if (finder.evaluate().isEmpty) {
      try {
        await t.scrollUntilVisible(
          finder,
          80,
          scrollable: find.byType(Scrollable).first,
          duration: const Duration(milliseconds: 150),
        );
      } catch (_) {}
      await t.pumpAndSettle();
      finder = find.text(sidebarLabel);
    }
    expect(finder.evaluate(), isNotEmpty, reason: '侧栏项「$sidebarLabel」可达');
    await t.tap(finder.first);
    await t.pumpAndSettle(const Duration(seconds: 2));
  }

  testWidgets('签①标签 CRUD:新建 → 重命名 → 删除(行菜单交互)', (t) async {
    await pumpApp(t);
    await goPage(t, '设置');
    expect(find.text('偏好设置'), findsWidgets, reason: '设置页地标');

    // 设置页「标签管理」导航行(可能需滚动露出)。
    final navRow = find.text('标签管理');
    await t.ensureVisible(navRow.first);
    await t.pumpAndSettle();
    await t.tap(navRow.first);
    await t.pumpAndSettle(const Duration(seconds: 2));
    // 标签页地标(栈下设置页同名词仍在,findsWidgets 不计件数)。
    expect(find.text('新建标签'), findsWidgets, reason: '标签管理页 + 新建入口');

    // ---- 新建 ----
    await t.tap(find.text('新建标签').last);
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('新建标签'), findsWidgets, reason: '新建标签 dialog 标题');
    // 顶栏搜索框也是 TextField → 用 dialog 范围限定到名称输入框。
    final dialogField =
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await t.enterText(dialogField, 'UI签生活');
    await t.tap(find.text('创建'));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('UI签生活'), findsWidgets, reason: '新标签卡入列');

    // ---- 重命名(行菜单:该卡上的「编辑」IconButton) ----
    final card1 = find.ancestor(
        of: find.text('UI签生活'), matching: find.byType(DataCard));
    await t.ensureVisible(find.text('UI签生活'));
    await t.pumpAndSettle();
    await t.tap(find.descendant(of: card1, matching: find.byTooltip('编辑')).first);
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('编辑标签'), findsWidgets, reason: '编辑 dialog 打开(标题)');
    // dialog 仅一个名称 TextField(顶栏搜索框也是 TextField → dialog 范围限定)。
    await t.enterText(
        find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'UI签改名');
    await t.tap(find.text('保存'));
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('UI签改名'), findsWidgets, reason: '重命名后入列');
    expect(find.text('UI签生活'), findsNothing, reason: '旧名不再出现');

    // ---- 删除(行菜单「删除」→ 确认 dialog) ----
    final card2 = find.ancestor(
        of: find.text('UI签改名'), matching: find.byType(DataCard));
    await t.tap(find.descendant(of: card2, matching: find.byTooltip('删除')).first);
    await t.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('删除标签'), findsWidgets, reason: '删除确认 dialog 打开');
    await t.tap(find.text('删除').last);
    await t.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('UI签改名'), findsNothing, reason: '删除后离列');

    // 演示种子标签不受影响。
    expect(find.text('必要支出'), findsWidgets, reason: '种子标签仍在');
    expect(find.text('投资'), findsWidgets, reason: '种子标签仍在');
  });
}
