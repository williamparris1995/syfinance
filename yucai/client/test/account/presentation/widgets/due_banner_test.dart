// DueBanner widget 测试(2026-09 到期常显提醒 T3,spec FR-1/2/3/7):
// 空态不渲染 / 聚合文案(无逾期与有逾期两形,逾期子句前置)/ 收起默认态 /
// 展开-收起切换 / 明细行内容与 F37 桶着色(与 debt_list_widgets._dueUrgencyDecor
// 同一批语义令牌:negative=逾期&≤7 天,warn=≤15 天)/ 行点击回调按 target 类型
// 分派 / 查看全部回调 / 宽窄屏同构。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/account/presentation/widgets/due_banner.dart';
import 'package:yucai_client/core/notifications/due_candidate_provider.dart';
import 'package:yucai_client/core/notifications/due_reminder_policy.dart';
import 'package:yucai_client/core/notifications/due_target.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/theme/app_theme.dart';

/// 直构候选视图(widget 纯展示,不经 provider)。
DueCandidateView _v(
  String entryKey,
  String title,
  int amountCents,
  int daysLeft,
  DueTarget target,
) =>
    DueCandidateView(
      entryKey: entryKey,
      title: title,
      amountCents: amountCents,
      dueDate: DateTime(2026, 9, 30),
      tier: daysLeft < 0 ? DueTier.overdue : DueTier.advance,
      daysLeft: daysLeft,
      target: target,
    );

class _Recorder {
  final cards = <String>[];
  final debts = <String>[];
  var viewAll = 0;
}

Widget _harness(List<DueCandidateView> candidates, _Recorder rec) =>
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: DueBanner(
              candidates: candidates,
              onOpenCard: (t) => rec.cards.add(t.accountId),
              onOpenDebt: (t) => rec.debts.add(t.debtId),
              onViewAll: () => rec.viewAll++,
            ),
          ),
        ),
      ),
    );

/// 展开明细(点收起条)。
Future<void> _expand(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('dueBannerSummaryRow')));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('空态:候选空 → SizedBox.shrink 不渲染不占位', (t) async {
    await t.pumpWidget(_harness(const [], _Recorder()));
    expect(find.byKey(const ValueKey('dueBanner')), findsNothing);
    // 唯一子树是零尺寸 SizedBox(shrink 语义:hero 回到顶部原位)。
    expect(t.getSize(find.byType(SizedBox)), Size.zero);
  });

  testWidgets('无逾期聚合文案:「⏰ N 笔待还 · 最近 X 天后」(X=最小到期日差)', (t) async {
    await t.pumpWidget(_harness([
      _v('cc:a1:2026-09', '招行卡', 5000, 3, const AccountTarget('a1')),
      _v('e1', '房贷', 100000, 5, const DebtTarget('d1')),
    ], _Recorder()));
    expect(find.text('⏰ 2 笔待还 · 最近 3 天后'), findsOneWidget);
    // 收起默认态:明细行不可见。
    expect(find.byKey(const ValueKey('dueBannerRow-e1')), findsNothing);
  });

  testWidgets('逾期优先:逾期子句前置 + 反映最近到期(N=最大逾期天数)', (t) async {
    await t.pumpWidget(_harness([
      _v('e2', '车贷', 300000, -4, const DebtTarget('d2')), // 逾期 4 天
      _v('cc:a1:2026-09', '招行卡', 5000, 3, const AccountTarget('a1')),
    ], _Recorder()));
    expect(
      find.text('⏰ 1 笔已逾期 4 天 · 共 2 笔待还 · 最近 3 天后'),
      findsOneWidget,
    );
  });

  testWidgets('全部逾期:无未来条目时无最近子句;N=最大逾期天数', (t) async {
    await t.pumpWidget(_harness([
      _v('e1', '车贷', 300000, -2, const DebtTarget('d1')),
      _v('e2', '房贷', 100000, -5, const DebtTarget('d2')),
    ], _Recorder()));
    expect(find.text('⏰ 2 笔已逾期 5 天 · 共 2 笔待还'), findsOneWidget);
  });

  testWidgets('当日到期:最近子句为「今日到期」', (t) async {
    await t.pumpWidget(
        _harness([_v('e1', '房贷', 100000, 0, const DebtTarget('d1'))], _Recorder()));
    expect(find.text('⏰ 1 笔待还 · 今日到期'), findsOneWidget);
  });

  group('F37 桶着色(收起条按最紧条目档;与 debt_list_widgets 同源令牌)', () {
    /// 左侧色条色(子 Container,4px)。
    Color sideBarColor(WidgetTester t) =>
        t.widget<Container>(find.byKey(const ValueKey('dueBannerSideBar')))
            .color!;


    testWidgets('含逾期 → negative(红)', (t) async {
      await t.pumpWidget(_harness([
        _v('e1', '车贷', 300000, -4, const DebtTarget('d1')),
        _v('cc:a1', '招行卡', 5000, 12, const AccountTarget('a1')),
      ], _Recorder()));
      expect(sideBarColor(t), YucaiTheme.light().negative);
    });

    testWidgets('全部 ≤7 天 → negative(红)', (t) async {
      await t.pumpWidget(_harness([
        _v('e1', '房贷', 100000, 3, const DebtTarget('d1')),
        _v('e2', '车贷', 300000, 7, const DebtTarget('d2')),
      ], _Recorder()));
      expect(sideBarColor(t), YucaiTheme.light().negative);
    });

    testWidgets('全部 8..15 天 → warn(黄)', (t) async {
      await t.pumpWidget(_harness([
        _v('e1', '房贷', 100000, 12, const DebtTarget('d1')),
        _v('e2', '车贷', 300000, 15, const DebtTarget('d2')),
      ], _Recorder()));
      expect(sideBarColor(t), YucaiTheme.light().warn);
    });
  });

  testWidgets('展开切换:点收起条展开 → 再点收起', (t) async {
    final rec = _Recorder();
    await t.pumpWidget(_harness([
      _v('e1', '房贷', 100000, 5, const DebtTarget('d1')),
    ], rec));
    expect(find.byKey(const ValueKey('dueBannerRow-e1')), findsNothing);
    await _expand(t);
    expect(find.byKey(const ValueKey('dueBannerRow-e1')), findsOneWidget);
    expect(find.byKey(const ValueKey('dueBannerViewAll')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('dueBannerSummaryRow')));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('dueBannerRow-e1')), findsNothing);
    expect(find.byKey(const ValueKey('dueBannerViewAll')), findsNothing);
  });

  testWidgets('明细行:名称 · ¥金额(千分位两位)/ 到期措辞 · 按桶着色',
      (tester) async {
    await tester.pumpWidget(_harness([
      _v('e1', '车贷', 300000, -4, const DebtTarget('d1')), // 逾期 → 红
      _v('cc:a1:2026-09', '招行卡', 5000, 3, const AccountTarget('a1')), // ≤7 → 红
      _v('e2', '房贷', 1000000, 12, const DebtTarget('d2')), // ≤15 → 黄
    ], _Recorder()));
    await _expand(tester);

    /// 行内三段 span:(名称 / 金额 / 到期措辞),返回文本与可选色。
    /// Text.rich 外层有 DefaultTextStyle 包裹 span(text=null),先展平取叶。
    (String, Color?) spanAt(String rowKey, int i) {
      final rich = tester.widget<RichText>(find.descendant(
        of: find.byKey(ValueKey(rowKey)),
        matching: find.byType(RichText),
      ));
      final leaves = <TextSpan>[];
      void walk(InlineSpan s) {
        if (s is TextSpan) {
          if (s.text != null) {
            leaves.add(s);
          } else {
            for (final c in s.children ?? const <InlineSpan>[]) {
              walk(c);
            }
          }
        }
      }

      walk(rich.text as TextSpan);
      final span = leaves[i];
      return (span.text!, span.style?.color);
    }

    // 名称 · ¥金额(千分位两位小数,money 工具同源)。
    expect(spanAt('dueBannerRow-e1', 0), ('车贷', null));
    expect(spanAt('dueBannerRow-e1', 1).$1, ' · ¥3,000.00');
    expect(spanAt('dueBannerRow-cc:a1:2026-09', 1).$1, ' · ¥50.00');
    expect(spanAt('dueBannerRow-e2', 1).$1, ' · ¥10,000.00');

    // 到期措辞 + F37 桶着色:逾期/≤7 → negative;≤15 → warn(同源令牌)。
    expect(spanAt('dueBannerRow-e1', 2), (' · 逾期 4 天', YucaiTheme.light().negative));
    expect(spanAt('dueBannerRow-cc:a1:2026-09', 2),
        (' · 3 天后到期', YucaiTheme.light().negative));
    expect(spanAt('dueBannerRow-e2', 2), (' · 12 天后到期', YucaiTheme.light().warn));
  });

  testWidgets('行点击:按 target 类型分派(Account→onOpenCard / Debt→onOpenDebt)',
      (t) async {
    final rec = _Recorder();
    await t.pumpWidget(_harness([
      _v('cc:a1:2026-09', '招行卡', 5000, 3, const AccountTarget('a1')),
      _v('e1', '房贷', 100000, 5, const DebtTarget('d1')),
    ], rec));
    await _expand(t);
    await t.tap(find.byKey(const ValueKey('dueBannerRow-cc:a1:2026-09')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('dueBannerRow-e1')));
    await t.pump();
    expect(rec.cards, ['a1']);
    expect(rec.debts, ['d1']);
    expect(rec.viewAll, 0);
  });

  testWidgets('查看全部:尾部文字钮 → onViewAll', (t) async {
    final rec = _Recorder();
    await t.pumpWidget(_harness([
      _v('e1', '房贷', 100000, 5, const DebtTarget('d1')),
    ], rec));
    await _expand(t);
    await t.tap(find.byKey(const ValueKey('dueBannerViewAll')));
    await t.pump();
    expect(rec.viewAll, 1);
    expect(rec.cards, isEmpty);
    expect(rec.debts, isEmpty);
  });

  testWidgets('宽窄屏同构:390 窄屏聚合条与明细均正常渲染', (t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.resetPhysicalSize);
    final rec = _Recorder();
    await t.pumpWidget(_harness([
      _v('e1', '车贷', 300000, -4, const DebtTarget('d1')),
      _v('cc:a1:2026-09', '招行卡', 5000, 3, const AccountTarget('a1')),
    ], rec));
    expect(find.text('⏰ 1 笔已逾期 4 天 · 共 2 笔待还 · 最近 3 天后'),
        findsOneWidget);
    await _expand(t);
    expect(find.byKey(const ValueKey('dueBannerRow-e1')), findsOneWidget);
    expect(t.takeException(), isNull); // 无溢出异常
  });
}
