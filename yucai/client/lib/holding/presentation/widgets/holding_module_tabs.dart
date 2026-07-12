// holding 模块页内 tab 导航(4 格金下划线,替代二级侧栏)。
// 对齐 OD 原型(open-design yucai-holding-ui-redesign-f494/holdings-desktop.html .tabs):
// 4 格(持仓列表/Security 管理/收益统计/投资目标),当前路由 active 金下划线。
// 放各 holding 页顶部(page-head 下)。横向 4 格,窄屏横滚。
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:yucai_client/core/theme/app_design.dart';

const _tabs = <_Tab>[
  _Tab('持仓列表', '/holdings'),
  _Tab('Security 管理', '/holdings/security'),
  _Tab('收益统计', '/holdings/performance'),
  _Tab('投资目标', '/holdings/goals'),
];

class _Tab {
  const _Tab(this.label, this.route);
  final String label;
  final String route;
}

class HoldingModuleTabs extends StatelessWidget {
  const HoldingModuleTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final current = GoRouterState.of(context).matchedLocation;
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final t in _tabs)
              _TabItem(
                label: t.label,
                active: current == t.route,
                onTap: () => context.go(t.route),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.fg : AppColors.muted;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 2,
                color: active ? AppColors.accent : Colors.transparent,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
