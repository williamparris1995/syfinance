/// F6 UI 链:启动接线自动补账(ui_boot_subscription;ADR-4,本任务核心)。
///
/// 链路:DS 预置 autoRecord 月度订阅模板(nextDate 早于真实 now)→ 复刻
/// main.dart 启动序列(configureDependencies[resetTestDb 已做] →
/// windowManager.ensureInitialized → bootstrapNotifications(db) → pump app)
/// → bootstrap 内部 TrayController 首扫(10 秒延迟 Timer)触发
/// AutoRecordScheduler.run(**DateTime.now()** 真实时钟)→ 断言:
///   ① DS 查交易已自动生成(description=模板名);
///   ② 模板 nextDate 已前移越过 now(补账游标推进);
///   ③ 订阅管理页(设置 → 周期模板)打开显示模板状态(名/下次日期/自动 chip)。
///
/// ⚠️ main.dart 启动序列变更需同步本文件(ADR-4 维护责任,design 风险表)。
/// 注:侧栏「订阅管理」当前指向 /accounts/templates(会被 /accounts/:id 捕获,
/// 生产缺口记报告不修生产),本测试经 设置 → 周期模板(/settings/templates)进入。
/// bootstrap 有 try/catch 降级(托盘/通知失败不影响调度);首扫为 10 秒延迟
/// Timer,故 pump app 后分段等真实时间(每步 pump(5s) 在 live binding 下
/// 真睡眠,3 步覆盖首扫窗口)。
///
/// ⚠️ LaunchAtStartup 副作用(fix round 1 review 新发现):真跑
/// bootstrapNotifications 会执行 LaunchAtStartup.instance.enable() —— 把
/// 开机自启注册项(appName 同为 yucai_client)覆写为**测试构建产物**路径
/// (build\windows\x64\runner\Debug\yucai_client.exe),用户真实安装版的自启
/// 注册被覆盖。tearDownAll 里 disable() 撤销:移除指向陈旧测试 exe 的注册
/// 比留着好;真实 app 下次启动会按默认(spec FR-3 自启开)重新注册,无持久损失。
///
/// Windows 桌面注意:请单独运行本文件(多集成文件同跑会有设备启动竞争,第二个文件 loading 失败)。
/// 运行:`flutter test integration_test/ui_boot_subscription_test.dart -d windows --dart-define=YUCAI_DB_FILE=yucai_test.db`
/// (属 `make client-e2e-ui` 入口 B,手动按需)。
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:window_manager/window_manager.dart';
import 'package:yucai_client/app/app.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/localdb/app_database.dart';
import 'package:yucai_client/core/notifications/notifications_bootstrap.dart';
import 'package:yucai_client/template/data/template_local_ds.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/transaction/data/balance_updater.dart';
import 'package:yucai_client/transaction/data/transaction_local_ds.dart';

import 'link_support.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late TemplateLocalDataSource templatesDs;
  late String subId; // 启UI订阅(autoRecord 月度订阅,启动补账主夹具)

  // date-only 字符串夹具帮手(模板 create 的 startDate 契约)。
  String iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  setUpAll(() async {
    // 确定性起点:删测试库 → 重建 DI → 幂等种子(照 link_* 管道链)。
    await resetTestDb();
    db = getIt<AppDatabase>();
    templatesDs =
        TemplateLocalDataSource(db, TransactionLocalDataSource(db, BalanceLocalUpdater(db)));

    // ---- 自包含夹具(启UI* 前缀,与演示数据零耦合) ----
    // 演示种子的两个模板均 autoRecord=false → 到期名单只含本夹具模板。
    final fundsId = await fundsAccount('启UI资金', 500000); // 5,000.00
    // nextDate 必须早于真实 now:bootstrap 内部是 run(DateTime.now()) 真实时钟,
    // 不能用 fixedToday。startDate = 真实 now −2 个月 → create 时 nextDate =
    // start + 1 个月 ≈ now −1 个月(已到期,含月末天数钳位的月算术容差,
    // 断言用 ≥1 笔 + nextDate 越过 now,不押精确期数)。
    // ⚠️ endDate 必须显式给未来值:DS create 对 endDate=null 兜底为「UTC 今天」
    // (template_local_ds._parseDate(null)→_nowDate()),会把补账截在今天
    // ——生产语义缺口,记报告不修生产,测试里显式传 +1 年绕开。
    final now = DateTime.now();
    subId = (await templatesDs.create(
      name: '启UI订阅',
      amountCents: 1500, // 15.00
      direction: TemplateDirection.expense,
      sourceAccountId: fundsId,
      cycle: TemplateCycle.monthly,
      billingDay: 0, // ≤0 取发生日
      startDate: iso(DateTime(now.year, now.month - 2, now.day)),
      endDate: iso(DateTime(now.year + 1, now.month, now.day)),
      autoRecord: true,
    ))
        .id;
  });

  tearDownAll(() async {
    // 撤销 LaunchAtStartup 注册(见文件头警示):enable 已把用户真实自启注册
    // 覆盖为测试构建产物路径,disable 移除指向陈旧测试 exe 的注册比留着好;
    // 真实 app 下次启动会按默认(自启开)重新注册。失败静默 —— 自启子系
    // 降级不阻断删库收尾(与 bootstrap 的 try/catch 降级哲学一致)。
    try {
      await LaunchAtStartup.instance.disable();
    } catch (_) {}
    await deleteTestDb();
  });

  testWidgets('启动接线:bootstrap 首扫自动补账 + nextDate 前移 + 模板页状态', (t) async {
    // ---- 复刻 main.dart 启动序列(ADR-4;main.dart 变更需同步) ----
    // main 里的 acquireSingleInstance 略过:测试进程是本机唯一实例
    // (make 入口每文件前已杀 yucai_client 残留),单实例守卫必过。
    // windowManager.ensureInitialized 必要:TrayController.start 在自身 try
    // 之前调 windowManager.addListener/setPreventClose,未初始化会抛 →
    // bootstrap 顶层 catch 降级 → 首扫 Timer 根本不会挂上(接线就测不到了)。
    await windowManager.ensureInitialized();
    await bootstrapNotifications(getIt<AppDatabase>());

    await t.pumpWidget(const YuCaiApp());
    await t.pumpAndSettle(const Duration(seconds: 3));

    // 首扫是 TrayController.start 里的 Timer(10s, design ADR-5 不阻塞首帧)。
    // live binding 下 pump(5s) 真睡眠并各画一帧 → 3 步覆盖 10 秒首扫窗口,
    // 首扫回调(autoRecord + 到期扫描)在其中一步真实执行。
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(seconds: 5));
    }
    await t.pumpAndSettle(const Duration(seconds: 2));

    // ---- ① DS 查交易已自动生成(description=模板名;raw drift 独立读) ----
    final rows = await (db.select(db.transactions)
          ..where((x) => x.description.equals('启UI订阅')))
        .get();
    expect(rows, isNotEmpty, reason: '启动接线:autoRecord 模板已自动补账(≥1 笔)');

    // ---- ② 模板 nextDate 已前移越过 now(补账游标推进,下轮不再补) ----
    final after = await templatesDs.get(subId);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final nextStr = after.nextDate;
    expect(nextStr, isNotNull, reason: '补账后 nextDate 应有值');
    final next = DateTime.parse(nextStr!);
    expect(next.isAfter(today), isTrue,
        reason: '启动补账后 nextDate=$nextStr 应越过今天($today)');
    expect(after.autoRecord, isTrue, reason: '模板仍为自动记账态');

    // ---- ③ 订阅管理页打开显示模板状态 ----
    // 经 设置 → 周期模板(/settings/templates;侧栏「订阅管理」路由为生产缺口,见文件头注释)。
    await goPage(t, '设置');
    expect(find.text('偏好设置'), findsWidgets, reason: '设置页地标');
    final tplEntry = find.text('周期模板');
    expect(tplEntry.evaluate(), isNotEmpty, reason: '设置页周期模板入口可达');
    await t.ensureVisible(tplEntry.first);
    await t.pumpAndSettle();
    await t.tap(tplEntry.first);
    await t.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('周期模板'), findsWidgets, reason: '周期模板页地标');
    expect(find.text('启UI订阅'), findsWidgets, reason: '模板卡显示模板名');
    expect(textContainingRich('下次 '), findsWidgets,
        reason: '模板卡显示下次日期(nextDate 前移后的值)');
    expect(find.text('自动'), findsWidgets, reason: '模板卡显示「自动」状态 chip');
  });
}
