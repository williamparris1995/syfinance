// F62 FR-1/ADR-1 —— ProductScenarioPicker(产品场景卡)单测。
// 契约源:prototype/v18 components.md(ProductScenarioPicker)+ design LLD
// `scenario→subtype` 映射与 `scenarioOf(subtype)` 编辑反选。
//
// 覆盖:
//   - 4 场景卡渲染(用户语言标题 + 角标露推导分类)+ tooltip
//   - 点卡推导 subtype(bank→credit_loan / cc→card_loan / mortgage→mortgage
//     二级选择 / family→family)
//   - 房贷·车贷二级选择(房贷/车贷 chips)
//   - 「更多类型」折叠入口(完整枚举保底:cash/consumption/business/
//     credit_card/other)
//   - 编辑态反选:存量 subtype 自动选中对应卡/入口(cardOf 纯函数 +
//     非映射类 → 更多类型展开)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';
import 'package:yucai_client/debt/presentation/widgets/product_scenario_picker.dart';

/// 有态宿主:捕获回调并回灌(选中态由父持有 —— 照 debt_form 集成形态)。
class _Host extends StatefulWidget {
  const _Host({super.key, required this.initialSubtype});
  final String initialSubtype;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  // initState 拷贝(而非 late 字段初始化):同树复泵时 State 保留,late
  // 初始化器只求值一次会残留首拍值 —— 测试多次 _pump 模拟不同编辑存量。
  late String _subtype;

  @override
  void initState() {
    super.initState();
    _subtype = widget.initialSubtype;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: ProductScenarioPicker(
          selectedSubtype: _subtype,
          onSubtypeSelected: (k) => setState(() => _subtype = k),
        ),
      ),
    );
  }
}

Future<void> _pump(WidgetTester t, String initialSubtype) async {
  // key 区分宿主:强制新建 State(同型复泵会复用旧状态)。
  await t.pumpWidget(
      _Host(key: ValueKey(initialSubtype), initialSubtype: initialSubtype));
  await t.pumpAndSettle();
}

/// 卡片选中态断言:选中卡 AnimatedContainer 描边 = accent(裸 MaterialApp
/// 回落亮色主题,与 YucaiTheme.light() 同源)。
bool _cardSelected(WidgetTester t, String id) {
  final card = find.byKey(ValueKey('scenarioCard-$id'));
  final box = t.widget<AnimatedContainer>(
    find.descendant(of: card, matching: find.byType(AnimatedContainer)),
  );
  final deco = box.decoration as BoxDecoration;
  return deco.border?.top.color == YucaiTheme.light().accent;
}

void main() {
  group('cardOf 纯映射(设计 LLD:scenario↔subtype 双向)', () {
    test('4 卡覆盖 5 个映射 subtype,余 5 类走「更多类型」', () {
      expect(DebtScenarioCard.cardOf(DebtSubtypes.creditLoan),
          DebtScenarioCard.bank);
      expect(DebtScenarioCard.cardOf(DebtSubtypes.cardLoan),
          DebtScenarioCard.creditCardInstallment);
      expect(DebtScenarioCard.cardOf(DebtSubtypes.mortgage),
          DebtScenarioCard.mortgageAuto);
      expect(DebtScenarioCard.cardOf(DebtSubtypes.autoLoan),
          DebtScenarioCard.mortgageAuto);
      expect(DebtScenarioCard.cardOf(DebtSubtypes.family),
          DebtScenarioCard.family);
      // 非映射类(更多类型枚举)→ null。
      for (final k in [
        DebtSubtypes.cashInstallment,
        DebtSubtypes.consumptionLoan,
        DebtSubtypes.businessLoan,
        DebtSubtypes.creditCard,
        DebtSubtypes.other,
      ]) {
        expect(DebtScenarioCard.cardOf(k), isNull,
            reason: '$k 应走「更多类型」入口');
      }
    });

    test('更多类型枚举 = DebtSubtypes.all 中非卡内 5 类(保底全类型可达)', () {
      const more = DebtScenarioCard.moreSubtypes;
      expect(more, containsAll([
        DebtSubtypes.cashInstallment,
        DebtSubtypes.consumptionLoan,
        DebtSubtypes.businessLoan,
        DebtSubtypes.creditCard,
        DebtSubtypes.other,
      ]));
      // 卡内 subtype 不得重复出现在更多枚举(单一选择路径)。
      for (final k in [
        DebtSubtypes.creditLoan,
        DebtSubtypes.cardLoan,
        DebtSubtypes.mortgage,
        DebtSubtypes.autoLoan,
        DebtSubtypes.family,
      ]) {
        expect(more, isNot(contains(k)));
      }
      // 全类型可达:卡内 + 更多 = all(防漏,设计风险缓解条款)。
      expect(
        {
          ...more,
          DebtSubtypes.creditLoan,
          DebtSubtypes.cardLoan,
          DebtSubtypes.mortgage,
          DebtSubtypes.autoLoan,
          DebtSubtypes.family,
        }.toSet(),
        DebtSubtypes.all.toSet(),
      );
    });
  });

  group('4 场景卡渲染(用户语言 + 角标推导)', () {
    testWidgets('renders 4 cards with titles + derived badges + tooltips',
        (t) async {
      await _pump(t, DebtSubtypes.creditLoan);
      // 亲友借款 = 卡标题 + 角标各一处(badge 亦显推导名)。
      expect(find.text('借钱到银行卡'), findsOneWidget);
      expect(find.text('信用卡里的分期'), findsOneWidget);
      expect(find.text('房贷 · 车贷'), findsOneWidget);
      expect(find.text('亲友借款'), findsNWidgets(2));
      // 角标显推导分类(FR-1:角标可见)。
      expect(find.byKey(const ValueKey('scenarioBadge-bank')), findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('scenarioBadge-bank')),
              matching: find.text('信用贷款')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('scenarioBadge-cc')),
              matching: find.text('信用卡分期')),
          findsOneWidget);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('scenarioBadge-family')),
              matching: find.text('亲友借款')),
          findsOneWidget);
      // NFR-1 tooltip 覆盖。
      expect(find.byTooltip('借钱到银行卡 · 分类为「信用贷款」'), findsOneWidget);
      expect(find.byTooltip('信用卡里的分期 · 分类为「信用卡分期」'), findsOneWidget);
      expect(find.byTooltip('亲友借款 · 分类为「亲友借款」'), findsOneWidget);
    });

    testWidgets('tapping bank card selects it and derives credit_loan',
        (t) async {
      await _pump(t, DebtSubtypes.creditLoan);
      expect(_cardSelected(t, 'bank'), isTrue);
      // 切走再切回:点 family → bank 失选;再点 bank → 选中恢复。
      await t.tap(find.byKey(const ValueKey('scenarioCard-family')));
      await t.pumpAndSettle();
      expect(_cardSelected(t, 'bank'), isFalse);
      expect(_cardSelected(t, 'family'), isTrue);
      await t.tap(find.byKey(const ValueKey('scenarioCard-bank')));
      await t.pumpAndSettle();
      expect(_cardSelected(t, 'bank'), isTrue);
    });
  });

  group('点卡推导 subtype(回调契约)', () {
    testWidgets('bank → credit_loan;cc → card_loan;family → family',
        (t) async {
      await _pump(t, DebtSubtypes.creditLoan);
      // family 卡:点选 → subtype=family,角标跟随。
      await t.tap(find.byKey(const ValueKey('scenarioCard-family')));
      await t.pumpAndSettle();
      expect(_cardSelected(t, 'family'), isTrue);
      // cc 卡:点选 → subtype=card_loan。
      await t.tap(find.byKey(const ValueKey('scenarioCard-cc')));
      await t.pumpAndSettle();
      expect(_cardSelected(t, 'cc'), isTrue);
      // bank 卡:点选 → subtype=credit_loan。
      await t.tap(find.byKey(const ValueKey('scenarioCard-bank')));
      await t.pumpAndSettle();
      expect(_cardSelected(t, 'bank'), isTrue);
      expect(_cardSelected(t, 'cc'), isFalse);
    });

    testWidgets('mortgage 卡 → 二级选择(默认房贷,可切车贷)', (t) async {
      await _pump(t, DebtSubtypes.creditLoan);
      await t.tap(find.byKey(const ValueKey('scenarioCard-mortgage')));
      await t.pumpAndSettle();
      // 卡选中 + 二级行出现(房贷/车贷 chips,key 沿用 debtType-* 命名)。
      expect(_cardSelected(t, 'mortgage'), isTrue);
      expect(find.byKey(const ValueKey('scenarioSecondary')), findsOneWidget);
      expect(find.byKey(const ValueKey('debtType-mortgage')), findsOneWidget);
      expect(find.byKey(const ValueKey('debtType-auto_loan')), findsOneWidget);
      // 默认选房贷(点卡即落 mortgage,角标显「房贷」)。
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('scenarioBadge-mortgage')),
              matching: find.text('房贷')),
          findsOneWidget);
      // 切「车贷」chip → subtype=auto_loan,角标翻「车贷」。
      await t.tap(find.byKey(const ValueKey('debtType-auto_loan')));
      await t.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('scenarioBadge-mortgage')),
              matching: find.text('车贷')),
          findsOneWidget);
      // 二级行随卡失选消失。
      await t.tap(find.byKey(const ValueKey('scenarioCard-bank')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('scenarioSecondary')), findsNothing);
    });
  });

  group('「更多类型」折叠入口(完整枚举保底)', () {
    testWidgets('collapsed by default; expand → 5 chips; pick 消费贷',
        (t) async {
      await _pump(t, DebtSubtypes.creditLoan);
      // 默认折叠:枚举 chips 不渲染。
      expect(find.byKey(const ValueKey('scenarioMorePanel')), findsNothing);
      // 折叠头显分类计数(防漏)。
      expect(find.byKey(const ValueKey('scenarioMoreToggle')), findsOneWidget);
      expect(find.textContaining('5'), findsOneWidget);
      await t.tap(find.byKey(const ValueKey('scenarioMoreToggle')));
      await t.pumpAndSettle();
      expect(find.byKey(const ValueKey('scenarioMorePanel')), findsOneWidget);
      for (final k in DebtScenarioCard.moreSubtypes) {
        expect(find.byKey(ValueKey('debtType-$k')), findsOneWidget,
            reason: 'debtType-$k 缺失(完整枚举保底)');
        expect(find.byKey(ValueKey('debtTypeIcon-$k')), findsOneWidget,
            reason: 'debtTypeIcon-$k 缺失');
      }
      // 点「消费贷」→ chip 选中 + bank 卡失选。
      await t.tap(find.byKey(
          const ValueKey('debtType-${DebtSubtypes.consumptionLoan}')));
      await t.pumpAndSettle();
      expect(_cardSelected(t, 'bank'), isFalse);
      expect(
          find.descendant(
              of: find.byKey(
                  const ValueKey('debtType-${DebtSubtypes.consumptionLoan}')),
              matching: find.text('消费贷')),
          findsOneWidget);
    });
  });

  group('编辑态反选(scenarioOf:零迁移)', () {
    testWidgets('credit_loan → bank 卡选中', (t) async {
      await _pump(t, DebtSubtypes.creditLoan);
      expect(_cardSelected(t, 'bank'), isTrue);
    });

    testWidgets('card_loan → cc 卡选中', (t) async {
      await _pump(t, DebtSubtypes.cardLoan);
      expect(_cardSelected(t, 'cc'), isTrue);
      expect(find.byKey(const ValueKey('scenarioMorePanel')), findsNothing,
          reason: '映射类不展开更多枚举');
    });

    testWidgets('mortgage / auto_loan → mortgage 卡 + 二级行反选', (t) async {
      await _pump(t, DebtSubtypes.mortgage);
      expect(_cardSelected(t, 'mortgage'), isTrue);
      expect(find.byKey(const ValueKey('scenarioSecondary')), findsOneWidget);
      await _pump(t, DebtSubtypes.autoLoan);
      expect(_cardSelected(t, 'mortgage'), isTrue);
      expect(
          find.descendant(
              of: find.byKey(const ValueKey('scenarioBadge-mortgage')),
              matching: find.text('车贷')),
          findsOneWidget);
    });

    testWidgets('family → family 卡选中', (t) async {
      await _pump(t, DebtSubtypes.family);
      expect(_cardSelected(t, 'family'), isTrue);
    });

    testWidgets('非映射类(消费贷)→ 更多类型展开 + chip 选中', (t) async {
      await _pump(t, DebtSubtypes.consumptionLoan);
      // initState 反选:更多面板自动展开,消费贷 chip 选中,bank 卡不选。
      expect(find.byKey(const ValueKey('scenarioMorePanel')), findsOneWidget,
          reason: '非映射类编辑反选应展开完整枚举');
      expect(_cardSelected(t, 'bank'), isFalse);
      // 切回 bank 卡 → 更多面板不自动收起(用户可继续看枚举),bank 选中。
      await t.tap(find.byKey(const ValueKey('scenarioCard-bank')));
      await t.pumpAndSettle();
      expect(_cardSelected(t, 'bank'), isTrue);
    });
  });
}
