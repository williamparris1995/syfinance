/// F6 UI 链:转账表单(ui_transfer_form)。
///
/// 链路:交易页顶栏「新增交易」→ 记一笔表单切「转账」(两资产账户互转,
/// 无分类)→ 金额 / 转出账户 / 转入账户 / 商户 / 提交 → 断言:
///   ① 落库复式(debit 转入 / credit 转出)+ 双账户余额联动(raw drift);
///   ② 交易记录列表出现转账条目(from → to 双账户标签,富文本感知)。
///
/// 列表显示断言放在下一个 testWidgets(pump 全新 app):顶栏创建路径
/// 表单 pop 后列表页不自动重拉(见 ui_record_form 文件头说明)。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_transfer_form_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口 B,手动按需)。
library;

import 'package:flutter/material.dart'
    show TextFormField, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late String fromId; // UI转出卡(初始 3,000.00)
  late String toId; // UI转入卡(初始 500.00)

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子;账户夹具经 DS 铺,UI 只测交互。
    await resetTestDb();
    db = getIt<AppDatabase>();
    fromId = await fundsAccount('UI转出卡', 300000);
    toId = await fundsAccount('UI转入卡', 50000);
  });

  tearDownAll(deleteTestDb);

  Future<void> pumpApp(WidgetTester t) async {
    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  testWidgets('转①转账提交:两账户填表 → 落库复式 + 余额双向联动', (t) async {
    final beforeFrom = await balanceOf(db, fromId); // 3,000.00
    final beforeTo = await balanceOf(db, toId); // 500.00

    await pumpApp(t);
    await goPage(t, '交易记录');
    await t.tap(find.text('新增交易').first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // 类型 tabs 切「转账」(表单页在顶层路由之上,列表页未挂载,无同名冲突)。
    await t.tap(find.text('转账'));
    await t.pumpAndSettle();

    await t.enterText(find.byKey(const ValueKey('hero_amount')), '800.88');
    await t.pumpAndSettle();

    // 转出账户(「钱从哪来」)/ 转入账户(「钱到哪去」)—— 转账模式专属 hint。
    await t.tap(find.text('钱从哪来').first);
    await t.pumpAndSettle();
    await t.tap(find.text('UI转出卡').last);
    await t.pumpAndSettle();

    await t.tap(find.text('钱到哪去').first);
    await t.pumpAndSettle();
    await t.tap(find.text('UI转入卡').last);
    await t.pumpAndSettle();

    await t.enterText(
        find.widgetWithText(TextFormField, '交易对象 / 商户'), 'UI链转账');
    await t.pumpAndSettle();

    await t.tap(find.text('保存').first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    // ---- 落库断言(raw drift):1 笔,debit 转入卡 / credit 转出卡 各 80,088 分。
    final rows = await (db.select(db.transactions)
          ..where((x) => x.description.equals('UI链转账')))
        .get();
    expect(rows, hasLength(1), reason: '转账交易落库');
    final entries = await (db.select(db.transactionEntries)
          ..where((e) => e.transactionId.equals(rows.single.id)))
        .get();
    expect(entries, hasLength(2), reason: '转账 = 2 腿复式');
    final debitLeg = entries.firstWhere((e) => e.debitCents > 0);
    final creditLeg = entries.firstWhere((e) => e.creditCents > 0);
    expect(debitLeg.accountId, toId, reason: '借方 = 转入账户');
    expect(creditLeg.accountId, fromId, reason: '贷方 = 转出账户');
    expect(debitLeg.debitCents, 80088, reason: '金额 = 800.88 元');

    // oracle:转出 −80,088 / 转入 +80,088(分)。
    expect(await balanceOf(db, fromId), beforeFrom - 80088,
        reason: '转出账户余额 −金额');
    expect(await balanceOf(db, toId), beforeTo + 80088,
        reason: '转入账户余额 +金额');
  });

  testWidgets('转②列表回看:转账条目入列(from → to 双账户标签)', (t) async {
    await pumpApp(t);
    await goPage(t, '交易记录');

    expect(textContainingRich('UI链转账'), findsWidgets, reason: '转账条目入列');
    // 转账行:账户列 from → to 双标签 + 副标题「UI转出卡 → UI转入卡」。
    expect(textContainingRich('UI转出卡'), findsWidgets, reason: '转出账户标签可见');
    expect(textContainingRich('UI转入卡'), findsWidgets, reason: '转入账户标签可见');
    // 金额列(列表 _formatCents 无千分位分组)。
    expect(textContainingRich('800.88'), findsWidgets, reason: '转账金额可见');
  });
}
