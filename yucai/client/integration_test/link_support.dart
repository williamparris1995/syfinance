/// F6 E2E 共享测试 helper(仅测试代码,零生产改动)。
///
/// 集中管道链 / UI 链测试的公共设施(design HLD「共享设施」):
/// - [resetTestDb]:删测试库 → 重建 DI → 幂等演示种子(照 linked_transactions_test 的 setUpAll);
/// - [fundsAccount]:CNY 储蓄资产账户工厂(管道链夹具的资金腿);
/// - [balanceOf]:raw drift 直读余额(独立于被测 DS,避免自证,ADR-3);
/// - [fixedToday]:冻结"今天",全部相对日期夹具与调度器入参的基准(ADR-4);
/// - [textContainingRich]:富文本感知 finder(自 app_pages_test 提取);
/// - [goPage]:侧栏导航 helper(自 12 个 ui_*_test 逐字重复副本收口);
/// - [deleteTestDb]:tearDownAll 删库收尾。
///
/// 约定:测试库固定 yucai_test.db(与 --dart-define=YUCAI_DB_FILE=yucai_test.db 配套),
/// 用户真实库(yucai.db)永不被触碰。
library;

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yucai_client/account/data/account_local_ds.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/demo/demo_seed.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';

/// 冻结"今天"(2026-09-02):全部相对日期夹具与调度器入参的基准 ——
/// 「今天 −3 个月」这类夹具在任意真实运行日期下都确定(ADR-4)。
/// 注:DateTime 无 const 构造,用 final 顶层常量(仅日期锚点,不涉时区语义)。
final DateTime fixedToday = DateTime(2026, 9, 2);

/// 确定性起点:删 yucai_test.db(含旧种子/夹具)→ 重建 DI → 幂等演示种子。
/// 照 linked_transactions_test 的 setUpAll;夹具独立于演示数据,零耦合。
Future<void> resetTestDb() async {
  // NFR-1 硬守卫(单一 choke point,所有 link_* 文件都经此函数):
  // 不带 --dart-define 裸跑时,YUCAI_DB_FILE 缺省为用户真实库 yucai.db,
  // 种子/夹具会写进真实库 —— 这里直接拒绝执行,真实库永不被测试触碰。
  const dbFile = String.fromEnvironment('YUCAI_DB_FILE');
  if (dbFile != 'yucai_test.db') {
    throw StateError('refusing: run with --dart-define=YUCAI_DB_FILE='
        'yucai_test.db (real db must never be touched)');
  }
  final support = await getApplicationSupportDirectory();
  final testDbFile = File('${support.path}/yucai_test.db');
  if (await testDbFile.exists()) await testDbFile.delete();
  await configureDependencies();
  await seedDemoData(getIt<AppDatabase>()); // 幂等种子
}

/// 测试数据生命周期收尾:删独立测试库(种子+夹具全清,用户真实库不动)。
/// Windows 下 sqlite 文件被占用时删除会失败 —— 先关掉 getIt 持有的
/// AppDatabase 连接再删;两步各自失败静默(库可能已被删 / DI 未初始化)。
Future<void> deleteTestDb() async {
  // NFR-1 硬守卫(与 resetTestDb 同款):裸跑时 YUCAI_DB_FILE 缺省为用户
  // 真实库 yucai.db —— 虽然本函数删的是固定 yucai_test.db 路径,仍统一
  // 拒绝执行,真实库永不被测试触碰。
  const dbFile = String.fromEnvironment('YUCAI_DB_FILE');
  if (dbFile != 'yucai_test.db') {
    throw StateError('refusing: run with --dart-define=YUCAI_DB_FILE='
        'yucai_test.db (real db must never be touched)');
  }
  try {
    await getIt<AppDatabase>().close();
  } catch (_) {}
  try {
    final support = await getApplicationSupportDirectory();
    final f = File('${support.path}/yucai_test.db');
    if (await f.exists()) await f.delete();
  } catch (_) {}
}

/// 建 CNY 储蓄资产账户(ownership personal),返回账户 id —— 管道链夹具的资金腿。
Future<String> fundsAccount(String name, int initialBalanceCents) async {
  final accounts = AccountLocalDataSource(getIt<AppDatabase>());
  final acct = await accounts.create(CreateAccountParams(
    name: name,
    accountType: AccountType.asset,
    category: AccountCategory.savings,
    currencyCode: 'CNY',
    initialBalanceCents: initialBalanceCents,
    ownership: Ownership.personal,
  ));
  return acct.id;
}

/// raw drift 直读 accounts.currentBalanceCents(不经被测 DS,避免自证)。
Future<int> balanceOf(AppDatabase db, String accountId) async {
  final row = await (db.select(db.accounts)
        ..where((a) => a.id.equals(accountId)))
      .getSingle();
  return row.currentBalanceCents;
}

/// 富文本感知 finder:Text.rich(StyledSpan)的 data 为 null,
/// find.textContaining 看不见 —— 这里匹配 data + textSpan 明文。
Finder textContainingRich(String needle) =>
    find.byWidgetPredicate((w) {
      if (w is Text) {
        return ((w.data ?? '') + (w.textSpan?.toPlainText() ?? ''))
            .contains(needle);
      }
      // _ProgAmt 等组件直接用裸 RichText(¥ + 整数 + 小数分段渲染),
      // 默认 finder 看不见 —— 拼接其整树明文匹配。
      if (w is RichText) {
        return w.text.toPlainText().contains(needle);
      }
      return false;
    });

/// 侧栏分组标题(⑨导航增强 A 折叠感知用;与 app_shell._navGroups 同源
/// 维护 —— 组名变更时同步此表)。
const kNavGroupTitles = ['概览', '资产', '交易', '规划', '借贷', '工具'];

/// ⑨导航增强 A:展开所有折叠组。侧栏分组可折叠且折叠态经 NavSettings
/// 持久化(secure storage)—— 开发机真实存储可能残留折叠态(与主题偏好
/// 同泄漏面,见 full_audit NFR-1 注),折叠组体不构建 → find.text 不可达。
/// 组头 key 后缀 -collapsed 即折叠态(app_shell 态后缀 key 契约);无
/// 折叠时本函数为 no-op。
Future<void> expandCollapsedNavGroups(WidgetTester t) async {
  for (final title in kNavGroupTitles) {
    final head = find.byKey(ValueKey('navGroupHead-$title-collapsed'));
    if (head.evaluate().isNotEmpty) {
      await t.tap(head.first);
      await t.pumpAndSettle(const Duration(milliseconds: 400));
    }
  }
}

/// 侧栏导航 helper:目标项在视口外时先滚侧栏露出再点,点后 settle。
/// 来源:自 12 个 ui_*_test.dart 的逐字重复副本收口(F14-T2)——祖源
/// full_audit_test.goPage 的严格断言变体,F6 UI 链 11 文件首次复制,
/// F9 code-ledger 首次记为测试债(~200 行),F10/F8 新增文件同款沿用;
/// 全部副本 diff 逐位相同,无漂移,故单一共享版、签名与行为逐位不变
/// (scrollUntilVisible 80px/步、150ms/步长、tap 后 pumpAndSettle 2s)。
/// ⑨A 增补:找不到时先展开折叠组(持久化残留);滚动双向 —— 先向下
/// (新目标在折叠线下方),再向上(浅组项位于已下滚列表的上方;懒构建
/// 下滚出 cacheExtent 即离树,默认方向够不着,需负 delta 反向找)。
Future<void> goPage(WidgetTester t, String sidebarLabel) async {
  var finder = find.text(sidebarLabel);
  if (finder.evaluate().isEmpty) {
    await expandCollapsedNavGroups(t);
    finder = find.text(sidebarLabel);
  }
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
  if (finder.evaluate().isEmpty) {
    try {
      await t.scrollUntilVisible(
        finder,
        -80,
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
