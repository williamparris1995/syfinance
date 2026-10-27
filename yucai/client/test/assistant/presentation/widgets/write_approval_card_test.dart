// F70-T3(2026-10-27):写操作确认卡 widget 测试(spec FR-5/FR-4;design
// ADR-7;视觉事实源 = prototype v20 ui/write-approval-cards.html 全页 ——
// V1 新增预览 / V2 前后对比 / V3 destructive 强确认 / V4 查无引导 /
// V5 替换作废 / V6 失败重试)。
//
// seam:静态渲染用手工 WriteApprovalMsg 直挂卡;交互用例走真 bloc
// (脚本化 _FakeLoop 出卡 + 计数型 fake WriteExecutor —— 按钮回调 =
// 真调 bloc 事件,断言 executor 调用与卡态流转);引导卡跳转 =
// 真 GoRouter 路由意图断言(照 ADR-5:跳 /accounts,无独立新建路由)。
// 零裸色守门(照 assistant_overlay_host_test 静态检查先例)。
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:yucai_client/assistant/domain/agent_loop.dart';
import 'package:yucai_client/assistant/domain/assistant_settings.dart';
import 'package:yucai_client/assistant/domain/assistant_tool.dart'
    show ToolGuideHint;
import 'package:yucai_client/assistant/domain/engine_state.dart';
import 'package:yucai_client/assistant/domain/model_state.dart';
import 'package:yucai_client/assistant/domain/write_action.dart';
import 'package:yucai_client/assistant/domain/write_executor.dart';
import 'package:yucai_client/assistant/presentation/assistant_panel/assistant_panel_bloc.dart';
import 'package:yucai_client/assistant/presentation/widgets/write_approval_card.dart';
import 'package:yucai_client/core/theme/app_design.dart';

void main() {
  // —— fixture(v20 合成数据;金额千分位两位 = yuan() 口径)——

  final addAction = TransactionAdd(
    direction: WriteDirection.outflow,
    amountCents: 1234500,
    description: '午饭',
    accountId: 'acc-cmb',
    categoryId: 'acc-food',
    date: DateTime(2026, 10, 5),
  );
  const addPreview = {
    'direction': 'out',
    'amountCents': 1234500,
    'amountYuan': '12,345.00',
    'description': '午饭',
    'account': '招商银行(储蓄卡)',
    'category': '餐饮',
    'date': '2026-10-05',
  };

  final updateAction = TransactionUpdate(
    direction: WriteDirection.outflow,
    transactionId: 'txn-7',
    patch: TransactionPatch(amountCents: 4000),
  );
  const before = {
    'date': '2026-10-05',
    'description': '午饭',
    'direction': 'out',
    'amountCents': 3500,
    'amountYuan': '35.00',
    'account': '招商银行(储蓄卡)',
    'category': '餐饮',
  };
  const updatePreview = {
    'before': before,
    'after': {
      'date': '2026-10-05',
      'description': '午饭',
      'direction': 'out',
      'amountCents': 4000,
      'amountYuan': '40.00',
      'account': '招商银行(储蓄卡)',
      'category': '餐饮',
    },
  };

  const deleteAction = TransactionDelete(transactionId: 'txn-9');
  const deletePreview = {
    'destructive': true,
    'target': {
      'date': '2026-10-05',
      'description': '地铁通勤',
      'direction': 'out',
      'amountCents': 600,
      'amountYuan': '6.00',
      'account': '支付宝',
      'category': '交通出行',
    },
  };

  WriteApprovalMsg card(
    WriteAction action,
    Map<String, Object> preview, {
    WriteApprovalStatus status = WriteApprovalStatus.pending,
    String? failureReason,
    String key = 'k1',
  }) =>
      WriteApprovalMsg(
        idempotencyKey: key,
        action: action,
        preview: preview,
        status: status,
        failureReason: failureReason,
      );

  // —— harness ——

  /// 脚本化 loop(照 assistant_panel_bloc_test 范式;交互用例真发事件)。
  _FakeLoop loopOf(List<Stream<AssistantEvent>> rounds) => _FakeLoop(rounds);

  AssistantPanelBloc makeBloc(
    _FakeLoop loop,
    _FakeWriteExecutor executor,
  ) =>
      AssistantPanelBloc(
        loop: loop,
        config: ValueNotifier(const AssistantConfig(enabled: true)),
        modelState: ValueNotifier(const ModelReady()),
        engineState: ValueNotifier(EngineReady(Uri.parse('http://127.0.0.1:1/v1'))),
        writeExecutor: executor,
        frameInterval: Duration.zero,
      );

  /// 静态卡挂载:直挂单卡(渲染断言面;按钮不点,bloc 仅占位)。
  Widget staticHost(WriteApprovalMsg message) {
    final bloc = makeBloc(loopOf(const []), _FakeWriteExecutor(const []));
    return MaterialApp(
      theme: ThemeData.light().copyWith(extensions: [YucaiTheme.light()]),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 400,
            child: BlocProvider<AssistantPanelBloc>.value(
              value: bloc,
              child: ListView(children: [WriteApprovalCard(card: message)]),
            ),
          ),
        ),
      ),
    );
  }

  /// 活卡挂载:随 bloc 状态渲染确认卡/引导卡(交互用例 —— 按钮真调 bloc)。
  Widget liveHost(AssistantPanelBloc bloc) => MaterialApp(
        theme: ThemeData.light().copyWith(extensions: [YucaiTheme.light()]),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 400,
              child: BlocProvider<AssistantPanelBloc>.value(
                value: bloc,
                child: BlocBuilder<AssistantPanelBloc, AssistantPanelState>(
                  builder: (context, state) => ListView(
                    children: [
                      for (final message in state.messages)
                        if (message is WriteApprovalMsg)
                          WriteApprovalCard(card: message)
                        else if (message is GuidanceMsg)
                          GuidanceCard(
                            text: message.text,
                            route: message.route,
                            amountYuan: message.amountYuan,
                            accountName: message.accountName,
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  /// 出卡轮脚本(add 工具往返 + 提案 + 收口)。
  Stream<AssistantEvent> proposalRound() => Stream.fromIterable([
        const ToolCallStart('call_w1', 'transaction_add'),
        const ToolCallEnd('call_w1', true),
        WriteProposed('transaction_add', addAction, addPreview),
        const Done(),
      ]);

  group('V1 新增预览卡(pending add · 参数逐行)', () {
    testWidgets('卡头待确认+记一笔 chip;方向/金额千分位两位/账户/分类注记/日期;按钮取消+确认记账',
        (tester) async {
      await tester.pumpWidget(staticHost(card(addAction, addPreview)));
      await tester.pumpAndSettle();
      expect(find.text('待确认操作'), findsOneWidget);
      expect(find.text('记一笔'), findsOneWidget, reason: 'v20 chip 工具语境');
      expect(find.text('支出'), findsOneWidget, reason: '方向行');
      expect(find.text('¥12,345.00'), findsOneWidget,
          reason: '金额千分位两位(yuan() 口径)');
      expect(find.text('招商银行(储蓄卡)'), findsOneWidget, reason: '账户行');
      expect(find.text('餐饮'), findsOneWidget, reason: '分类行');
      expect(find.text('由描述推导'), findsOneWidget,
          reason: 'v20 sm-note 推导注记(数据面无 derived 标记,恒显)');
      expect(find.text('2026-10-05'), findsOneWidget,
          reason: '非今天日期显示 ISO 原文');
      expect(find.byKey(const ValueKey('writeApprovalCancel')), findsOneWidget);
      expect(find.byKey(const ValueKey('writeApprovalConfirm')), findsOneWidget);
      expect(find.text('确认记账'), findsOneWidget);
    });

    testWidgets('日期=今天 → 显示「今天」(v20 V1 日期行)', (tester) async {
      final now = DateTime.now();
      final todayAction = TransactionAdd(
        direction: WriteDirection.inflow,
        amountCents: 2200,
        description: '咖啡',
        accountId: 'acc-alipay',
        categoryId: 'acc-bonus',
        date: DateTime(now.year, now.month, now.day),
      );
      await tester.pumpWidget(staticHost(card(todayAction, {
        ...addPreview,
        'direction': 'in',
      })));
      await tester.pumpAndSettle();
      expect(find.text('今天'), findsOneWidget);
      expect(find.text('收入'), findsOneWidget, reason: '方向行 in → 收入');
    });
  });

  group('V2 修改前后对比卡(pending update · 旧值删除线+新值高亮)', () {
    testWidgets('目标交易行 + 金额 diff(¥35.00 删除线 muted → ¥40.00 高亮 accent);未变更账户/分类只读',
        (tester) async {
      await tester.pumpWidget(staticHost(card(updateAction, updatePreview)));
      await tester.pumpAndSettle();
      expect(find.text('待确认操作'), findsOneWidget);
      expect(find.text('改一笔'), findsOneWidget);
      expect(find.text('午饭 · 2026-10-05'), findsOneWidget,
          reason: '目标交易 = 描述 · 日期');
      final t = YucaiTheme.light();
      final old = tester.widget<Text>(find.text('¥35.00'));
      expect(old.style?.decoration, TextDecoration.lineThrough,
          reason: 'v20 .ap-old 删除线');
      expect(old.style?.color, t.muted);
      final arrow = tester.widget<Text>(find.text('→'));
      expect(arrow.style?.color, t.muted);
      final fresh = tester.widget<Text>(find.text('¥40.00'));
      expect(fresh.style?.color, t.accent, reason: 'v20 .ap-new 高亮');
      expect(fresh.style?.fontWeight, FontWeight.w800);
      expect(find.text('招商银行(储蓄卡)'), findsOneWidget,
          reason: '未变更字段只读列出');
      expect(find.text('餐饮'), findsOneWidget);
      expect(find.byKey(const ValueKey('writeApprovalConfirm')), findsOneWidget);
      expect(find.text('确认修改'), findsOneWidget);
    });

    testWidgets('描述/日期/账户/分类变更也走 diff 行;金额未变更只读', (tester) async {
      final action = TransactionUpdate(
        direction: WriteDirection.outflow,
        transactionId: 'txn-7',
        patch: TransactionPatch(
          description: '午饭加可颂',
          date: DateTime(2026, 10, 6),
          accountId: 'acc-alipay',
          categoryId: 'acc-food2',
        ),
      );
      const preview = {
        'before': before,
        'after': {
          'date': '2026-10-06',
          'description': '午饭加可颂',
          'direction': 'out',
          'amountCents': 3500,
          'amountYuan': '35.00',
          'account': '支付宝',
          'category': '外食',
        },
      };
      await tester.pumpWidget(staticHost(card(action, preview)));
      await tester.pumpAndSettle();
      // 描述 diff:目标交易行保留 before,另出「描述」diff 行。
      expect(find.text('午饭'), findsOneWidget, reason: '目标交易行 before 描述');
      final newDesc = tester.widget<Text>(find.text('午饭加可颂'));
      expect(newDesc.style?.color, YucaiTheme.light().accent);
      // 日期 diff(未变更日期不出行;变更后出 diff 行)。
      expect(find.text('2026-10-06'), findsOneWidget);
      // 账户 diff:旧删除线 + 新高亮。
      final newAccount = tester.widget<Text>(find.text('支付宝'));
      expect(newAccount.style?.color, YucaiTheme.light().accent);
      // 金额未变更:只读单值,无删除线。
      final amount = tester.widget<Text>(find.text('¥35.00'));
      expect(amount.style?.decoration, isNot(TextDecoration.lineThrough));
    });
  });

  group('V3 删除强确认卡(pending delete · 红警示条+按钮主位反转)', () {
    testWidgets('红警示条「删除后不可恢复」+ 摘要行(交易/分类/账户/金额)+ 删一笔 chip',
        (tester) async {
      await tester.pumpWidget(staticHost(card(deleteAction, deletePreview)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('writeApprovalDestructiveStrip')),
          findsOneWidget,
          reason: 'v20 .ap-strip 警示条');
      expect(find.text('删除后不可恢复'), findsOneWidget);
      expect(find.text('删一笔'), findsOneWidget);
      expect(find.text('地铁通勤 · 2026-10-05'), findsOneWidget);
      expect(find.text('交通出行'), findsOneWidget);
      expect(find.text('支付宝'), findsOneWidget);
      expect(find.text('¥6.00'), findsOneWidget);
    });

    testWidgets('按钮主位反转:确认删除(negative)在左,取消(accent 主视觉)在右',
        (tester) async {
      await tester.pumpWidget(staticHost(card(deleteAction, deletePreview)));
      await tester.pumpAndSettle();
      final t = YucaiTheme.light();
      final danger = tester.widget<FilledButton>(
          find.byKey(const ValueKey('writeApprovalConfirm')));
      expect(
        danger.style?.backgroundColor?.resolve(const {}),
        t.negative.withValues(alpha: 0.12),
        reason: 'destructive 走 negative 令牌(ErrorMsg 同族先例)',
      );
      expect(danger.style?.foregroundColor?.resolve(const {}), t.negative);
      expect(find.text('确认删除'), findsOneWidget);
      final cancel = tester.widget<FilledButton>(
          find.byKey(const ValueKey('writeApprovalCancel')));
      expect(
        cancel.style?.backgroundColor?.resolve(const {}),
        t.accent,
        reason: '取消升主视觉(v20 主位反转:btn-danger 在前,btn-primary 在后)',
      );
      final dangerLeft = tester.getTopLeft(
          find.byKey(const ValueKey('writeApprovalConfirm')));
      final cancelLeft = tester.getTopLeft(
          find.byKey(const ValueKey('writeApprovalCancel')));
      expect(dangerLeft.dx, lessThan(cancelLeft.dx),
          reason: '确认删除在前(危险操作需刻意越过一级)');
    });
  });

  group('五状态徽标(pending 无徽标;终态收起按钮区)', () {
    testWidgets('confirmed(add):已记账绿✓头 + 已完成 chip + 已记入落库条;收起按钮',
        (tester) async {
      await tester.pumpWidget(staticHost(
          card(addAction, addPreview, status: WriteApprovalStatus.confirmed)));
      await tester.pumpAndSettle();
      expect(find.text('已记账'), findsOneWidget);
      expect(find.text('已完成'), findsOneWidget);
      expect(find.byKey(const ValueKey('writeApprovalDoneStrip')), findsOneWidget);
      expect(find.text('已记入招商银行(储蓄卡)'), findsOneWidget,
          reason: 'v20 .ap-done 落库条(account;时钟时刻不落数据面)');
      expect(find.byKey(const ValueKey('writeApprovalConfirm')), findsNothing,
          reason: '终态收起按钮区');
      expect(find.byKey(const ValueKey('writeApprovalCancel')), findsNothing);
    });

    testWidgets('confirmed(update/delete):已修改/已删除头 + done 条同词汇',
        (tester) async {
      await tester.pumpWidget(staticHost(card(
          updateAction, updatePreview,
          status: WriteApprovalStatus.confirmed)));
      await tester.pumpAndSettle();
      expect(find.text('已修改'), findsOneWidget);
      expect(find.text('已改:午饭 ¥40.00'), findsOneWidget,
          reason: 'done 条与 bloc 本地确认消息同词汇(已改/已删)');
      await tester.pumpWidget(staticHost(card(
          deleteAction, deletePreview,
          status: WriteApprovalStatus.confirmed)));
      await tester.pumpAndSettle();
      expect(find.text('已删除'), findsOneWidget);
      expect(find.text('已删:地铁通勤 ¥6.00'), findsOneWidget);
    });

    testWidgets('cancelled:已取消 chip,灰化留档,无按钮', (tester) async {
      await tester.pumpWidget(staticHost(
          card(addAction, addPreview, status: WriteApprovalStatus.cancelled)));
      await tester.pumpAndSettle();
      expect(find.text('已取消'), findsOneWidget);
      expect(find.byKey(const ValueKey('writeApprovalConfirm')), findsNothing);
      final opacities = tester
          .widgetList<Opacity>(find.ancestor(
              of: find.byKey(const ValueKey('writeApprovalCard')),
              matching: find.byType(Opacity)))
          .map((o) => o.opacity);
      expect(opacities, contains(0.55), reason: 'v20 .ap.void 灰化留档');
    });

    testWidgets('superseded:已被新操作替换 chip,无按钮(v20 V5)', (tester) async {
      await tester.pumpWidget(staticHost(card(
          addAction, addPreview,
          status: WriteApprovalStatus.superseded)));
      await tester.pumpAndSettle();
      expect(find.text('已被新操作替换'), findsOneWidget);
      expect(find.byKey(const ValueKey('writeApprovalConfirm')), findsNothing);
    });

    testWidgets('voided:已作废 chip,无按钮(v20 V5;当前随新对话清空,分支为穷尽保留)',
        (tester) async {
      await tester.pumpWidget(staticHost(
          card(addAction, addPreview, status: WriteApprovalStatus.voided)));
      await tester.pumpAndSettle();
      expect(find.text('已作废'), findsOneWidget);
      expect(find.byKey(const ValueKey('writeApprovalConfirm')), findsNothing);
    });

    testWidgets('failed:记账失败头 + 执行失败 chip + 原因中文 + 重试钮 + 幂等小字(v20 V6;评审 T3-M1)',
        (tester) async {
      await tester.pumpWidget(staticHost(card(addAction, addPreview,
          status: WriteApprovalStatus.failed,
          failureReason: 'account deleted')));
      await tester.pumpAndSettle();
      final t = YucaiTheme.light();
      expect(find.text('记账失败'), findsOneWidget);
      final head = tester.widget<Text>(find.text('记账失败'));
      expect(head.style?.color, t.negative, reason: 'v20 .ap-head.fail');
      expect(find.text('执行失败'), findsOneWidget);
      expect(find.text('执行失败,请重试'), findsOneWidget,
          reason: '未知 reason(runtimeType 类名等)→ 通用中文文案');
      expect(find.text('account deleted'), findsNothing,
          reason: '英文 token 不裸出渲染面(executor 契约英文不动)');
      expect(find.byKey(const ValueKey('writeApprovalRetry')), findsOneWidget);
      expect(find.text('重试不会产生重复记录;也可以改用其他账户重新记账。'),
          findsOneWidget,
          reason: 'v20 .ap-note-line 幂等小字');
      expect(find.byKey(const ValueKey('writeApprovalConfirm')), findsNothing,
          reason: 'failed 无确认/取消钮(重试走失败盒)');
    });

    testWidgets('failed reason 中文映射逐字:versionConflict/transactionNotFound/其余',
        (tester) async {
      Future<void> pumpReason(String? reason) async {
        await tester.pumpWidget(staticHost(card(addAction, addPreview,
            status: WriteApprovalStatus.failed, failureReason: reason)));
        await tester.pumpAndSettle();
      }

      await pumpReason('versionConflict');
      expect(find.text('内容已被其他修改更新,请重试'), findsOneWidget,
          reason: '乐观锁冲突单行原因(与 executor 契约 token 对应)');
      await pumpReason('transactionNotFound');
      expect(find.text('这笔交易已不存在'), findsOneWidget,
          reason: '提案与确认之间实体消失');
      await pumpReason('NetworkFailure');
      expect(find.text('执行失败,请重试'), findsOneWidget,
          reason: '其余 runtimeType 类名 → 通用重试文案');
      await pumpReason(null);
      expect(find.text('执行失败,请重试'), findsOneWidget,
          reason: 'reason 缺省 → 通用重试文案(不空串)');
    });
  });

  group('按钮回调(真调 bloc 事件;executor 计数断言)', () {
    testWidgets('确认记账 → ConfirmWriteRequested:executor 恰一次携卡键,卡转 confirmed',
        (tester) async {
      final executor = _FakeWriteExecutor([const WriteExecuted('txn-1')]);
      final bloc = makeBloc(loopOf([proposalRound()]), executor);
      await tester.pumpWidget(liveHost(bloc));
      bloc.add(const SendRequested('记一笔午饭'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('writeApprovalConfirm')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('writeApprovalConfirm')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(executor.calls, hasLength(1));
      final key = (bloc.state.messages.whereType<WriteApprovalMsg>().single)
          .idempotencyKey;
      expect(executor.calls.single.$2, key, reason: '携卡幂等键');
      expect(
        bloc.state.messages.whereType<WriteApprovalMsg>().single.status,
        WriteApprovalStatus.confirmed,
        reason: '卡转 confirmed(done 条渲染)');
      expect(find.byKey(const ValueKey('writeApprovalDoneStrip')), findsOneWidget);
      bloc.close(); // testWidgets fake-async 不 await close(flutter_bloc 关闭链依赖真实定时器)
    });

    testWidgets('取消 → CancelWriteRequested:卡转 cancelled,零执行',
        (tester) async {
      final executor = _FakeWriteExecutor([const WriteExecuted('txn-1')]);
      final bloc = makeBloc(loopOf([proposalRound()]), executor);
      await tester.pumpWidget(liveHost(bloc));
      bloc.add(const SendRequested('记一笔午饭'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const ValueKey('writeApprovalCancel')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        bloc.state.messages.whereType<WriteApprovalMsg>().single.status,
        WriteApprovalStatus.cancelled,
      );
      expect(executor.calls, isEmpty, reason: '取消零执行');
      expect(find.byKey(const ValueKey('writeApprovalConfirm')), findsNothing,
          reason: '取消后收起按钮');
      bloc.close(); // testWidgets fake-async 不 await close(flutter_bloc 关闭链依赖真实定时器)
    });

    testWidgets('确认删除 → ConfirmWriteRequested(destructive 同门;取消为主视觉)',
        (tester) async {
      final loop = loopOf([
        Stream.fromIterable([
          const ToolCallStart('call_d1', 'transaction_delete'),
          const ToolCallEnd('call_d1', true),
          const WriteProposed('transaction_delete', deleteAction, deletePreview),
          const Done(),
        ]),
      ]);
      final executor = _FakeWriteExecutor([const WriteExecuted('txn-9')]);
      final bloc = makeBloc(loop, executor);
      await tester.pumpWidget(liveHost(bloc));
      bloc.add(const SendRequested('把那笔地铁删了'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const ValueKey('writeApprovalConfirm')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(executor.calls, hasLength(1), reason: '删除确认同走唯一写通道');
      expect(
        bloc.state.messages.whereType<WriteApprovalMsg>().single.status,
        WriteApprovalStatus.confirmed,
      );
      bloc.close(); // testWidgets fake-async 不 await close(flutter_bloc 关闭链依赖真实定时器)
    });

    testWidgets('失败→重试 → RetryWriteRequested:同幂等键复用,卡回 confirmed',
        (tester) async {
      final executor = _FakeWriteExecutor([
        const WriteFailed('version conflict'),
        const WriteExecuted('txn-1'),
      ]);
      final bloc = makeBloc(loopOf([proposalRound()]), executor);
      await tester.pumpWidget(liveHost(bloc));
      bloc.add(const SendRequested('记一笔午饭'));
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.byKey(const ValueKey('writeApprovalConfirm')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('writeApprovalRetry')), findsOneWidget,
          reason: '失败盒出重试钮');

      await tester.tap(find.byKey(const ValueKey('writeApprovalRetry')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(executor.calls, hasLength(2));
      expect(executor.calls[0].$2, executor.calls[1].$2,
          reason: '幂等键复用(失败不消耗键,ADR-3)');
      expect(
        bloc.state.messages.whereType<WriteApprovalMsg>().single.status,
        WriteApprovalStatus.confirmed,
      );
      bloc.close(); // testWidgets fake-async 不 await close(flutter_bloc 关闭链依赖真实定时器)
    });
  });

  group('键盘聚焦(浮层内卡片按钮可键盘聚焦)', () {
    testWidgets('确认/取消按钮可获焦点(Focus.of→requestFocus→hasPrimaryFocus)',
        (tester) async {
      await tester.pumpWidget(staticHost(card(addAction, addPreview)));
      await tester.pumpAndSettle();
      final confirmNode = Focus.of(tester.element(find.text('确认记账')));
      expect(confirmNode.canRequestFocus, isTrue);
      confirmNode.requestFocus();
      await tester.pump();
      expect(confirmNode.hasPrimaryFocus, isTrue,
          reason: 'v20 .ap button:focus-visible 键盘可达');
      final cancelNode = Focus.of(tester.element(find.text('取消')));
      cancelNode.requestFocus();
      await tester.pump();
      expect(cancelNode.hasPrimaryFocus, isTrue);
    });
  });

  group('引导卡 GuidanceCard(v20 V4 查无实体引导)', () {
    Widget guidanceHost(GoRouter? router, AssistantPanelBloc bloc,
        {String? amountYuan, String? accountName}) {
      final card = GuidanceCard(
        text: '没有找到『滴滴』这个账户,要新建吗?',
        route: '/accounts',
        amountYuan: amountYuan,
        accountName: accountName,
      );
      final body = BlocProvider<AssistantPanelBloc>.value(
        value: bloc,
        child: Scaffold(
            body: Center(child: SizedBox(width: 400, child: card))),
      );
      if (router == null) {
        return MaterialApp(
          theme: ThemeData.light().copyWith(extensions: [YucaiTheme.light()]),
          home: body,
        );
      }
      return MaterialApp.router(
        theme: ThemeData.light().copyWith(extensions: [YucaiTheme.light()]),
        routerConfig: router,
      );
    }

    testWidgets('卡头「需要补充信息」+ 待补充 chip + 澄清文本 + 双钮 + 提示行',
        (tester) async {
      await tester.pumpWidget(guidanceHost(
          null, makeBloc(loopOf(const []), _FakeWriteExecutor(const []))));
      await tester.pumpAndSettle();
      expect(find.text('需要补充信息'), findsOneWidget);
      expect(find.text('待补充'), findsOneWidget, reason: 'v20 chip warn');
      expect(find.text('没有找到『滴滴』这个账户,要新建吗?'), findsOneWidget);
      expect(find.byKey(const ValueKey('guidanceDismissButton')), findsOneWidget);
      expect(find.text('换个账户试试'), findsOneWidget);
      expect(find.byKey(const ValueKey('guidanceNewAccountButton')), findsOneWidget);
      expect(find.text('新建账户'), findsOneWidget);
      expect(find.text('也可以直接说用哪个现有账户,如「用支付宝记」。'), findsOneWidget,
          reason: 'v20 .ap-note-line');
    });

    testWidgets('参数行两行照 v20 V4(评审 T3-M2):金额 ¥12.00 / 账户 滴滴(未找到)',
        (tester) async {
      await tester.pumpWidget(guidanceHost(
        null,
        makeBloc(loopOf(const []), _FakeWriteExecutor(const [])),
        amountYuan: '12.00',
        accountName: '滴滴',
      ));
      await tester.pumpAndSettle();
      expect(find.text('金额'), findsOneWidget);
      expect(find.text('¥12.00'), findsOneWidget,
          reason: '请求金额先挂起不丢失(v20 V4 金额行)');
      expect(find.text('账户'), findsOneWidget);
      expect(find.text('滴滴'), findsOneWidget, reason: '零命中实体名');
      final note = tester.widget<Text>(find.text('未找到该账户'));
      expect(note.style?.color, YucaiTheme.light().negative,
          reason: 'v20 .sm-note.neg');
      expect(find.text('新建账户'), findsOneWidget, reason: '参数行不挤掉按钮');
    });

    testWidgets('amountYuan/accountName 缺省 → 参数行不出(向后兼容)',
        (tester) async {
      await tester.pumpWidget(guidanceHost(
          null, makeBloc(loopOf(const []), _FakeWriteExecutor(const []))));
      await tester.pumpAndSettle();
      expect(find.text('金额'), findsNothing);
      expect(find.text('账户'), findsNothing);
      expect(find.text('未找到该账户'), findsNothing);
    });

    testWidgets('新建账户 → GoRouter 跳 /accounts(路由意图断言,ADR-5)',
        (tester) async {
      final bloc = makeBloc(loopOf(const []), _FakeWriteExecutor(const []));
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => BlocProvider<AssistantPanelBloc>.value(
              value: bloc,
              child: const Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 400,
                    child: GuidanceCard(
                      text: '没有找到『滴滴』这个账户,要新建吗?',
                      route: '/accounts',
                    ),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/accounts',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('账户页桩'))),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('guidanceNewAccountButton')));
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/accounts',
        reason: 'T1 查证无 /accounts/new 独立路由 → 跳账户页(页面内建户)');
      expect(find.text('账户页桩'), findsOneWidget);
      bloc.close(); // testWidgets fake-async 不 await close(flutter_bloc 关闭链依赖真实定时器)
    });

    testWidgets('换个账户试试 → DismissGuidanceClicked:真 bloc 移除引导卡',
        (tester) async {
      final bloc = makeBloc(
        loopOf([
          Stream.fromIterable(const [
            ToolCallStart('call_g1', 'transaction_add'),
            ToolCallEnd('call_g1', false),
            ToolGuidance(ToolGuideHint.unknownAccount, '滴滴', '12.00'),
            Done(),
          ]),
        ]),
        _FakeWriteExecutor(const []),
      );
      await tester.pumpWidget(liveHost(bloc));
      bloc.add(const SendRequested('记一笔打车 12 块,滴滴账户'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('guidanceDismissButton')), findsOneWidget,
          reason: 'ToolGuidance 轮 → GuidanceMsg 出引导卡');
      expect(find.text('没有找到『滴滴』这个账户,要新建吗?'), findsOneWidget);
      expect(find.text('¥12.00'), findsOneWidget,
          reason: 'ToolGuidance.amountYuan → 卡参数行(评审 T3-M2 全链)');
      expect(find.text('滴滴'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('guidanceDismissButton')));
      await tester.pump(const Duration(milliseconds: 50));

      expect(bloc.state.messages.whereType<GuidanceMsg>(), isEmpty,
          reason: '「换个账户试试」仅关闭卡(bloc 真事件移除)');
      expect(find.byKey(const ValueKey('guidanceDismissButton')), findsNothing);
      bloc.close(); // testWidgets fake-async 不 await close(flutter_bloc 关闭链依赖真实定时器)
    });
  });

  group('守门(硬约束,零裸色)', () {
    test('源码静态检查:无裸色/无 AppColors(照 overlay 守门先例)', () {
      final src = File(
              'lib/assistant/presentation/widgets/write_approval_card.dart')
          .readAsStringSync();
      expect(src.contains('Color(0x'), isFalse, reason: '禁裸色:走 context.yucai');
      expect(src.contains('AppColors'), isFalse, reason: 'legacy 色禁用');
    });
  });
}

/// 计数型 fake WriteExecutor(照 assistant_panel_bloc_test 范式)。
class _FakeWriteExecutor implements WriteExecutor {
  _FakeWriteExecutor(this._outcomes);

  final List<WriteOutcome> _outcomes;
  final List<(WriteAction, String)> calls = [];
  int _next = 0;

  @override
  Future<WriteOutcome> execute(
      WriteAction action, String idempotencyKey) async {
    calls.add((action, idempotencyKey));
    return _next < _outcomes.length
        ? _outcomes[_next++]
        : const WriteExecuted('txn-fallback');
  }
}

/// 脚本化 AgentLoopService(照 assistant_panel_bloc_test 范式)。
class _FakeLoop implements AgentLoopService {
  _FakeLoop(this.rounds);

  final List<Stream<AssistantEvent>> rounds;
  final List<String> sentMessages = [];
  int resetCount = 0;
  int _next = 0;

  @override
  Stream<AssistantEvent> send(String userMessage) {
    sentMessages.add(userMessage);
    if (_next >= rounds.length) {
      throw StateError('no scripted round for send #${sentMessages.length}');
    }
    return rounds[_next++];
  }

  @override
  void resetConversation() => resetCount++;

  @override
  void appendToolOutcome(String note) {}
}
