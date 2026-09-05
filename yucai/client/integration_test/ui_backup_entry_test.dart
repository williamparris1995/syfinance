/// F6 UI 链:设置页归档区入口可达(ui_backup_entry)。
///
/// 断言范围(design 决策 3:到入口可达为止):
///   设置页「导出存档 / 导入存档」区块 + 「本地备份 / 自动备份」导航行可见。
///
/// ⚠️ **绝不点击**「导出存档 / 导入存档」等会触发 FilePicker 原生对话框的
/// 按钮 —— 无头测试环境打不开也关不掉原生文件对话框,点了测试会永久挂死
/// (design ADR-5 查证;备份往返的数据层链路由 link_backup_roundtrip 覆盖)。
/// 同因,「本地备份」子页(/settings/backup)是 bind-only 路由(guest 会被
/// 重定向 /login,router kDefaultBindOnlyPrefixes),guest 模式下也只验入口
/// 存在,不导航。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_backup_entry_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口 B,手动按需)。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/app/app.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子;本链只读设置页,无夹具。
    await resetTestDb();
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  testWidgets('备①归档区入口可达:导出/导入存档 + 本地备份导航行可见(不点击)', (t) async {
    await pumpApp(t);
    await goPage(t, '设置');
    expect(find.text('偏好设置'), findsWidgets, reason: '设置页地标');

    // 归档区(加密备份区块):两行入口均在(只断言可见,绝不点击 —— FilePicker)。
    final export = find.text('导出存档');
    final import = find.text('导入存档');
    await t.ensureVisible(export.first);
    await t.pumpAndSettle();
    expect(export.evaluate(), isNotEmpty, reason: '「导出存档」入口可见');
    expect(find.text('加密备份到任意位置（U盘/云盘）'), findsWidgets,
        reason: '导出存档说明文案');
    await t.ensureVisible(import.first);
    await t.pumpAndSettle();
    expect(import.evaluate(), isNotEmpty, reason: '「导入存档」入口可见');
    expect(find.text('从存档文件恢复（覆盖本地数据）'), findsWidgets,
        reason: '导入存档说明文案');

    // 备份导航区:本地备份 / 自动备份 行可见(guest 下为 bind-only 路由,
    // 点击会被重定向登录页 —— 本链到入口可达为止,不导航)。
    final local = find.text('本地备份');
    await t.ensureVisible(local.first);
    await t.pumpAndSettle();
    expect(local.evaluate(), isNotEmpty, reason: '「本地备份」导航行可见');
    expect(find.text('自动备份'), findsWidgets, reason: '「自动备份」导航行可见');
  });
}
