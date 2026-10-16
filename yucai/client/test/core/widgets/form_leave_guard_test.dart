// F58 T2(ADR-3)— FormLeaveGuard widget 测。
//
// FR-7 守卫机制钉死(存量表单页接线归 F59,此处以 harness 表单页代打):
// - 非 dirty:系统返回直放,零弹框(干净态零摩擦);
// - dirty:系统返回(PopScope 兜底)弹「放弃修改/继续编辑」确认,继续编辑
//   留在页、放弃修改放行;
// - veto 通道(gate.mayLeave,面包屑 page 级 onTap 路径)与 pop 路径同一
//   确认对话框;
// - dispose 必须 unregister:残留 veto 在页面销毁后仍会把 mayLeave 拦成
//   false(死 context),此场景断言直接 true 即证无残留。
//
// 坑位:get_it 测试 reset 是 async —— tearDown 里 await 完再放行,防注册
// 串扰下一用例;对话框断言均在弹框存活期完成,不提前 dispose 宿主页面。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:yucai_client/core/form_leave_gate.dart';
import 'package:yucai_client/core/widgets/form_leave_guard.dart';

/// 宿主页:按钮 push 守卫表单页(home 路由常驻,是 pop 断言的「回来」锚点)。
class _Harness extends StatelessWidget {
  const _Harness();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          // Builder 取 MaterialApp 之下的 context(harness 自身 context
          // 在 Navigator 之上,Navigator.of 会抛)。
          child: Builder(
            builder: (bctx) => FilledButton(
              onPressed: () => Navigator.of(bctx).push(
                MaterialPageRoute<void>(builder: (_) => const _FormPage()),
              ),
              child: const Text('open form'),
            ),
          ),
        ),
      ),
    );
  }
}

/// 表单页替身:dirty 自持于 State,setState 重建守卫(PopScope.canPop 随
/// dirty 双向随动 —— 置脏拦截、复净回落)。isDirty 闭包捕获 State 字段 ——
/// 页面 dispose 后闭包仍读到 true,恰好用于钉死「dispose 后 gate 无残留
/// 注册」(残留 veto 会以 false 拦截 mayLeave)。
class _FormPage extends StatefulWidget {
  const _FormPage();

  @override
  State<_FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<_FormPage> {
  bool dirty = false;

  @override
  Widget build(BuildContext context) {
    return FormLeaveGuard(
      isDirty: () => dirty,
      child: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('form page'),
              FilledButton(
                onPressed: () => setState(() => dirty = true),
                child: const Text('mark dirty'),
              ),
              OutlinedButton(
                onPressed: () => setState(() => dirty = false),
                child: const Text('mark clean'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  late FormLeaveGate gate;

  setUp(() {
    // FormLeaveGuard 经 getIt 解析 gate(生产 = injection.dart lazySingleton);
    // 测试照 hero_theme_follow_test 口径注册实例替身。
    gate = FormLeaveGate();
    GetIt.instance.registerSingleton<FormLeaveGate>(gate);
  });

  tearDown(() async {
    // get_it 的 reset 返回 Future(async 坑):await 完再进下一用例。
    await GetIt.instance.reset();
  });

  Future<void> openForm(WidgetTester t) async {
    await t.pumpWidget(const _Harness());
    await t.tap(find.text('open form'));
    await t.pumpAndSettle();
    expect(find.text('form page'), findsOneWidget);
  }

  testWidgets('非 dirty:系统返回直放,无确认框', (t) async {
    await openForm(t);

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();

    expect(find.text('form page'), findsNothing, reason: '干净态应直接放行');
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('open form'), findsOneWidget);
  });

  testWidgets('dirty:系统返回弹确认 ——「继续编辑」留在页,「放弃修改」放行', (t) async {
    await openForm(t);
    await t.tap(find.text('mark dirty'));
    await t.pumpAndSettle();

    // 第一次拦截:选「继续编辑」。
    await t.binding.handlePopRoute();
    await t.pump(); // 对话框路由入栈(断言在弹框存活期做,勿提前 dispose)
    expect(find.text('未保存的修改'), findsOneWidget);
    expect(find.text('form page'), findsOneWidget);
    await t.tap(find.text('继续编辑'));
    await t.pumpAndSettle();
    expect(find.text('form page'), findsOneWidget, reason: '「继续编辑」应留在页面');

    // 第二次拦截:选「放弃修改」。
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.text('未保存的修改'), findsOneWidget);
    await t.tap(find.text('放弃修改'));
    await t.pumpAndSettle();
    expect(find.text('form page'), findsNothing, reason: '「放弃修改」应放行离开');
    expect(find.text('open form'), findsOneWidget);
  });

  testWidgets('veto 通道:非 dirty mayLeave=true 零弹框;dirty 弹框随「放弃」true', (t) async {
    await openForm(t);

    expect(await gate.mayLeave(), isTrue);
    expect(find.byType(AlertDialog), findsNothing);

    await t.tap(find.text('mark dirty'));
    await t.pumpAndSettle();

    // 面包屑 page 级 onTap 的统一问询入口(gate.mayLeave):同样走确认框。
    final leave = gate.mayLeave();
    await t.pump();
    expect(find.text('未保存的修改'), findsOneWidget);
    await t.tap(find.text('放弃修改'));
    await t.pumpAndSettle();
    expect(await leave, isTrue);
    // mayLeave 只问询不导航:表单页仍在树里,离开动作由调用方执行。
    expect(find.text('form page'), findsOneWidget);
  });

  testWidgets('dirty 复净:canPop 随宿主重建回落,系统返回直放零弹框', (t) async {
    await openForm(t);
    await t.tap(find.text('mark dirty'));
    await t.pumpAndSettle();

    // 宿主 setState 复净 → 守卫重建,canPop 应回落 true(拦截只跟脏态走)。
    await t.tap(find.text('mark clean'));
    await t.pumpAndSettle();

    await t.binding.handlePopRoute();
    await t.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing, reason: '复净后不应再弹确认');
    expect(find.text('form page'), findsNothing, reason: '干净态应直接放行');
    expect(find.text('open form'), findsOneWidget);
  });

  testWidgets('dispose 后 gate 无残留注册(页面销毁即注销 veto)', (t) async {
    await openForm(t);
    await t.tap(find.text('mark dirty'));
    await t.pumpAndSettle();

    // 经确认离开 → 表单页 dispose(此路径下 guard 必须 unregister)。
    await t.binding.handlePopRoute();
    await t.pump();
    await t.tap(find.text('放弃修改'));
    await t.pumpAndSettle();
    expect(find.text('form page'), findsNothing);

    // dirty 闭包在页面外仍读 true:若 veto 残留,mayLeave 会被拦成 false;
    // 直接 true 且零弹框 = 无残留注册。
    expect(await gate.mayLeave(), isTrue, reason: 'dispose 应注销 veto');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('F61 走查:冻结分支(TickerMode 禁用)veto 直接放行零弹框', (t) async {
    // 走查根因:其他分支悬挂的脏表单守卫参与全局问询 → 跨分支无限弹框
    // (放弃不清脏)。冻结分支放行;切回活跃(TickerMode 翻真)恢复拦截。
    var frozenDirty = true;
    await t.pumpWidget(TickerMode(
      enabled: false,
      child: MaterialApp(
        home: FormLeaveGuard(
          isDirty: () => frozenDirty,
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    ));
    expect(await gate.mayLeave(), isTrue,
        reason: '冻结分支守卫不参与拦截(防跨分支无限弹框)');
    expect(find.byType(AlertDialog), findsNothing);
    await t.pumpWidget(TickerMode(
      enabled: true,
      child: MaterialApp(
        home: FormLeaveGuard(
          isDirty: () => frozenDirty,
          child: const Scaffold(body: SizedBox()),
        ),
      ),
    ));
    final f = gate.mayLeave();
    await t.pump();
    expect(find.text('未保存的修改'), findsOneWidget, reason: '活跃分支恢复拦截');
    await t.tap(find.text('继续编辑'));
    await t.pump();
    expect(await f, isFalse);
  });
}
