import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/debt/domain/value_objects.dart';

/// F62 FR-1/ADR-1 —— 产品场景卡(债务表单首问)。
///
/// 用户语言 4 卡推导债务分类,角标露出映射术语;「更多类型」折叠入口展开
/// 完整分类枚举保底(消费贷/经营贷/现金分期/信用卡/其他)。编辑态按存量
/// subtype 自动反选([DebtScenarioCard.cardOf];非映射类 → initState 展开
/// 更多枚举并选中 chip),零迁移。
///
/// 契约源:prototype/v18 ui/debt-form-ux.html 区块二 + components.md
/// (ProductScenarioPicker)。选中态视觉对齐表单既有 _RadioCard 金描边范式;
/// 键盘可达 = InkWell(可聚焦,Enter/Space 激活)+ Tooltip(NFR-1)。
///
/// key 约定(测试钉):
///  - 卡:`scenarioCard-{bank|cc|mortgage|family}` + 角标 `scenarioBadge-*`
///  - 房贷·车贷二级 chips:`debtType-mortgage` / `debtType-auto_loan`
///    (沿用既有 subtype chip key 命名,迁移测试零重学)
///  - 更多入口:`scenarioMoreToggle` / 面板 `scenarioMorePanel`,面板内
///    chips `debtType-$key`(icon `debtTypeIcon-$key`)。
abstract final class DebtScenarioCard {
  static const bank = 'bank';
  static const creditCardInstallment = 'cc';
  static const mortgageAuto = 'mortgage';
  static const family = 'family';

  /// 反向映射(scenarioOf):存量 subtype → 场景卡 id;null = 非映射类
  /// (走「更多类型」枚举)。
  static String? cardOf(String subtypeKey) => switch (subtypeKey) {
        DebtSubtypes.creditLoan => bank,
        DebtSubtypes.cardLoan => creditCardInstallment,
        DebtSubtypes.mortgage || DebtSubtypes.autoLoan => mortgageAuto,
        DebtSubtypes.family => family,
        _ => null,
      };

  /// 更多类型枚举 = 全分类 − 卡内 subtype(保底:任何存量/新类型可达)。
  static const moreSubtypes = [
    DebtSubtypes.cashInstallment,
    DebtSubtypes.consumptionLoan,
    DebtSubtypes.businessLoan,
    DebtSubtypes.creditCard,
    DebtSubtypes.other,
  ];
}

/// 债务 subtype icon(表单 debtTypeIcon-* key 的单一事实源;自
/// debt_form_page 迁入 —— 场景卡/二级/更多枚举共用)。
IconData debtSubtypeIcon(String key) {
  switch (key) {
    case DebtSubtypes.mortgage:
      return LucideIcons.home;
    case DebtSubtypes.autoLoan:
      return LucideIcons.car;
    case DebtSubtypes.creditLoan:
      return LucideIcons.handCoins;
    case DebtSubtypes.cashInstallment:
      return LucideIcons.calendarClock;
    case DebtSubtypes.consumptionLoan:
      return LucideIcons.shoppingBag;
    case DebtSubtypes.businessLoan:
      return LucideIcons.briefcase;
    case DebtSubtypes.creditCard:
      return LucideIcons.creditCard;
    case DebtSubtypes.cardLoan:
      return LucideIcons.calendarClock;
    case DebtSubtypes.family:
      return LucideIcons.users;
    case DebtSubtypes.other:
    default:
      return LucideIcons.helpCircle;
  }
}

/// 场景卡(用户语言标题 + 副题 + 角标露推导分类)。选中 = 金描边 +
/// accentSoft 底(对齐表单 _RadioCard 选中范式,prototype .scn.on)。
class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.id,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.selected,
    required this.onTap,
  });

  final String id;
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cardBorder = selected ? context.yucai.accent : context.yucai.border;
    return Tooltip(
      message: '$title · 分类为「$badge」',
      child: InkWell(
        key: ValueKey('scenarioCard-$id'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? context.yucai.accentSoft : context.yucai.surface,
            border: Border.all(color: cardBorder, width: selected ? 1.4 : 1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 17,
                      color: selected
                          ? context.yucai.accentDeep
                          : context.yucai.accent),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: selected
                                ? context.yucai.accentDeep
                                : context.yucai.fg,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.yucai.muted,
                      fontSize: 10.5,
                      height: 1.3)),
              const SizedBox(height: 6),
              // 角标:推导分类术语的唯一露出位(用户全程用生活语言作答)。
              Container(
                key: ValueKey('scenarioBadge-$id'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected ? context.yucai.surface : null,
                  border: Border.all(
                      color: selected
                          ? context.yucai.accent
                          : context.yucai.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(badge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: selected
                            ? context.yucai.accentDeep
                            : context.yucai.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 枚举 chip(二级 房贷/车贷 + 更多类型面板共用;对齐 _RadioCard 紧凑版)。
class _ScenarioChip extends StatelessWidget {
  const _ScenarioChip({
    required this.subtypeKey,
    required this.selected,
    required this.onTap,
  });

  final String subtypeKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '分类为「${DebtSubtypes.labels[subtypeKey] ?? subtypeKey}」',
      child: InkWell(
        key: ValueKey('debtType-$subtypeKey'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          decoration: BoxDecoration(
            color:
                selected ? context.yucai.accentSoft : context.yucai.surface,
            border: Border.all(
                color:
                    selected ? context.yucai.accent : context.yucai.border,
                width: selected ? 1.4 : 1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(debtSubtypeIcon(subtypeKey),
                  key: ValueKey('debtTypeIcon-$subtypeKey'),
                  size: 14,
                  color: selected
                      ? context.yucai.accentDeep
                      : context.yucai.accent),
              const SizedBox(width: 6),
              Text(DebtSubtypes.labels[subtypeKey] ?? subtypeKey,
                  style: TextStyle(
                      color: selected ? context.yucai.accentDeep : context.yucai.fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 产品场景卡选择器(表单内 Stateful 组件 —— ADR-1:非独立页,避免多一跳)。
///
/// 选中态由父持有([selectedSubtype] + [onSubtypeSelected] 回灌),组件内部
/// 仅持有「更多类型」展开态;编辑反选经 initState 探测 [DebtScenarioCard.
/// cardOf] 为 null 时自动展开(零迁移,FR-1)。
class ProductScenarioPicker extends StatefulWidget {
  const ProductScenarioPicker({
    super.key,
    required this.selectedSubtype,
    required this.onSubtypeSelected,
  });

  final String selectedSubtype;
  final ValueChanged<String> onSubtypeSelected;

  @override
  State<ProductScenarioPicker> createState() => _ProductScenarioPickerState();
}

class _ProductScenarioPickerState extends State<ProductScenarioPicker> {
  late bool _moreOpen =
      DebtScenarioCard.cardOf(widget.selectedSubtype) == null;

  void _select(String key) => widget.onSubtypeSelected(key);

  @override
  Widget build(BuildContext context) {
    final s = widget.selectedSubtype;
    final mortgageSelected =
        DebtScenarioCard.cardOf(s) == DebtScenarioCard.mortgageAuto;
    // 房贷·车贷角标:未选 = 「房贷 / 车贷」(双类);选中 = 实际推导类。
    final mortgageBadge = !mortgageSelected
        ? '房贷 / 车贷'
        : (DebtSubtypes.labels[s] ?? '房贷 / 车贷');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 4 场景卡(2×2;mobile 自然换行)。Wrap 保持窄幅可用。
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            SizedBox(
              width: 210,
              child: _ScenarioCard(
                id: DebtScenarioCard.bank,
                icon: LucideIcons.landmark,
                title: '借钱到银行卡',
                subtitle: '银行 / 消费金融放款',
                badge: '信用贷款',
                selected:
                    DebtScenarioCard.cardOf(s) == DebtScenarioCard.bank,
                onTap: () => _select(DebtSubtypes.creditLoan),
              ),
            ),
            SizedBox(
              width: 210,
              child: _ScenarioCard(
                id: DebtScenarioCard.creditCardInstallment,
                icon: LucideIcons.creditCard,
                title: '信用卡里的分期',
                subtitle: '账单分期 · 现金分期',
                badge: '信用卡分期',
                selected: DebtScenarioCard.cardOf(s) ==
                    DebtScenarioCard.creditCardInstallment,
                onTap: () => _select(DebtSubtypes.cardLoan),
              ),
            ),
            SizedBox(
              width: 210,
              child: _ScenarioCard(
                id: DebtScenarioCard.mortgageAuto,
                icon: LucideIcons.home,
                title: '房贷 · 车贷',
                subtitle: '大额长期按揭',
                badge: mortgageBadge,
                selected: mortgageSelected,
                // 点卡默认落房贷(创建默认 subtype 语义延续),二级 chips
                // 随卡展开可切车贷;已选中时点卡不重置二级选择。
                onTap: () => _select(mortgageSelected
                    ? s
                    : DebtSubtypes.mortgage),
              ),
            ),
            SizedBox(
              width: 210,
              child: _ScenarioCard(
                id: DebtScenarioCard.family,
                icon: LucideIcons.users,
                title: '亲友借款',
                subtitle: '无利息 · 口头约定也可记',
                badge: '亲友借款',
                selected:
                    DebtScenarioCard.cardOf(s) == DebtScenarioCard.family,
                onTap: () => _select(DebtSubtypes.family),
              ),
            ),
          ],
        ),
        // 房贷·车贷二级选择(仅该卡选中时渲染)。
        if (mortgageSelected)
          Padding(
            key: const ValueKey('scenarioSecondary'),
            padding: const EdgeInsets.only(top: 9),
            child: Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                _ScenarioChip(
                  subtypeKey: DebtSubtypes.mortgage,
                  selected: s == DebtSubtypes.mortgage,
                  onTap: () => _select(DebtSubtypes.mortgage),
                ),
                _ScenarioChip(
                  subtypeKey: DebtSubtypes.autoLoan,
                  selected: s == DebtSubtypes.autoLoan,
                  onTap: () => _select(DebtSubtypes.autoLoan),
                ),
              ],
            ),
          ),
        // 「更多类型」折叠入口:折叠头显分类计数(防漏);展开 = 完整枚举
        // 保底(非主流类型不经术语考试也可达)。
        const SizedBox(height: 9),
        Tooltip(
          message: '展开完整债务分类枚举(${DebtScenarioCard.moreSubtypes.length} 类)',
          child: InkWell(
            key: const ValueKey('scenarioMoreToggle'),
            onTap: () => setState(() => _moreOpen = !_moreOpen),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: context.yucai.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _moreOpen
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 14,
                    color: context.yucai.muted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '更多类型 · ${DebtScenarioCard.moreSubtypes.length} 类',
                    style: TextStyle(
                        color: context.yucai.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_moreOpen)
          Padding(
            key: const ValueKey('scenarioMorePanel'),
            padding: const EdgeInsets.only(top: 9),
            child: Wrap(
              spacing: 9,
              runSpacing: 9,
              children: [
                for (final k in DebtScenarioCard.moreSubtypes)
                  _ScenarioChip(
                    subtypeKey: k,
                    selected: s == k,
                    onTap: () => _select(k),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
