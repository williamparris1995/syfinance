// Holding 模块 tab 导航(对齐 OD holding 模块侧栏:持仓列表/收益统计/Security 管理)。
//
// OD 原型把 holding 当独立模块(security/performance 页侧栏有 holding 模块导航
// 6 nav-item,分「持仓管理」「统计 & 目标」两组)。御财全局侧栏是模块级(资产/交易/…),
// holding 子界面导航放模块内部 —— 本组件即模块 tab,放各 holding 主页面顶部(顶栏下)。
//
// tab 项(主功能页):持仓列表 / 收益统计 / Security 管理。
// trade(操作 sheet)/ :id(详情)/ goals(关联)是从属操作,从列表/详情进,不入 tab。
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// Holding 模块顶部 tab 导航。点击 context.go 切换子界面,当前路由高亮。
class HoldingModuleNav extends StatelessWidget {
  const HoldingModuleNav({super.key});

  static const _items = <_NavTarget>[
    _NavTarget('持仓列表', LucideIcons.trendingUp, '/holdings'),
    _NavTarget('收益统计', LucideIcons.percent, '/holdings/performance'),
    _NavTarget('Security 管理', LucideIcons.layers, '/holdings/security'),
  ];

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).matchedLocation;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final it in _items)
              _NavTab(
                label: it.label,
                icon: it.icon,
                selected: current == it.route,
                onTap: () => context.go(it.route),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTarget {
  const _NavTarget(this.label, this.icon, this.route);
  final String label;
  final IconData icon;
  final String route;
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.muted;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 2,
                  color: selected ? AppColors.accent : Colors.transparent,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: color),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
