/// 订阅中心(v6 原型落码):模板模块的订阅视图。
///
/// 数据源 = TransactionTemplate(direction=Expense),零 proto 变更:
/// - 月度等价 = amountCents ÷ 周期月数(monthly=1、yearly=12、weekly=52/12、
///   custom=cycle_days×12/365.25),interval 每 N 周期再除 N;
/// - 下次续费 = next_date;30 天内到期 = next_date − 今天 ≤ 30;
/// - 操作:暂停/恢复 + 立即记账(既有 TemplateBloc 事件)。
/// 口径说明卡与原型一致:年付按月折算呈现,报表不失真(待摊摊销另立 spec)。
library;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';
import 'package:yucai_client/template/presentation/bloc/template_bloc.dart';
import 'package:yucai_client/template/presentation/bloc/template_event.dart';
import 'package:yucai_client/template/presentation/bloc/template_state.dart';

class SubscriptionCenterPage extends StatefulWidget {
  const SubscriptionCenterPage({super.key});

  @override
  State<SubscriptionCenterPage> createState() => _SubscriptionCenterPageState();
}

class _SubscriptionCenterPageState extends State<SubscriptionCenterPage> {
  @override
  void initState() {
    super.initState();
    context.read<TemplateBloc>().add(LoadTemplatesRequested());
  }

  /// 周期月数(月度等价的分母)。interval ≤0 视为 1(实体注释口径)。
  static double _monthsPerCycle(Template t) {
    final interval = t.interval <= 0 ? 1 : t.interval;
    switch (t.cycle) {
      case TemplateCycle.monthly:
        return 1.0 * interval;
      case TemplateCycle.yearly:
        return 12.0 * interval;
      case TemplateCycle.weekly:
        return 52 / 12 * interval;
      case TemplateCycle.custom:
        return (t.cycleDays <= 0 ? 30 : t.cycleDays) * 12 / 365.25 * interval;
      case TemplateCycle.unspecified:
        return 1.0;
    }
  }

  static int _monthlyEquivalentCents(Template t) =>
      (t.amountCents / _monthsPerCycle(t)).round();

  static String _cycleLabel(Template t) {
    final everyN = t.interval > 1 ? '每${t.interval}' : '';
    switch (t.cycle) {
      case TemplateCycle.monthly:
        return '${everyN}月付';
      case TemplateCycle.yearly:
        return '${everyN}年付';
      case TemplateCycle.weekly:
        return '${everyN}周付';
      case TemplateCycle.custom:
        return '每${t.cycleDays}天';
      case TemplateCycle.unspecified:
        return '周期';
    }
  }

  static int? _daysUntilNext(Template t) {
    final d = t.nextDate == null ? null : DateTime.tryParse(t.nextDate!);
    if (d == null) return null;
    final today = DateTime.now();
    final diff = DateTime(d.year, d.month, d.day)
        .difference(DateTime(today.year, today.month, today.day))
        .inDays;
    return diff;
  }

  String _fmt(int cents) {
    final neg = cents < 0;
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    final s = yuan.toString().replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
    return '${neg ? '-' : ''}$s.$fen';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      appBar: AppBar(
        title: const Text('订阅中心'),
        actions: [
          IconButton(
            tooltip: '模板管理',
            icon: const Icon(LucideIcons.layers, size: 18),
            onPressed: () => context.go('/accounts/templates'),
          ),
        ],
      ),
      body: BlocBuilder<TemplateBloc, TemplateState>(
        builder: (context, state) {
          if (state is TemplateLoading || state is TemplateInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is TemplateError) {
            return Center(child: Text('加载失败:${state.message}'));
          }
          final subs = (state is TemplatesLoaded ? state.templates : const <Template>[])
              .where((t) => t.direction == TemplateDirection.expense)
              .toList();
          return RefreshIndicator(
            onRefresh: () async {
              context.read<TemplateBloc>().add(LoadTemplatesRequested());
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _hero(context, subs),
                const SizedBox(height: 16),
                for (final t in subs) ...[
                  _subCard(context, t),
                  const SizedBox(height: 12),
                ],
                if (subs.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(LucideIcons.repeat,
                              size: 32, color: context.yucai.muted),
                          const SizedBox(height: 8),
                          Text('还没有周期支出订阅',
                              style:
                                  TextStyle(color: context.yucai.muted)),
                          const SizedBox(height: 4),
                          Text('在「模板管理」创建周期记账模板后,这里按订阅视角呈现',
                              style: TextStyle(
                                  fontSize: 12, color: context.yucai.muted)),
                        ],
                      ),
                    ),
                  ),
                _caliberCard(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero(BuildContext context, List<Template> subs) {
    final active = subs.where((t) => !t.paused).toList();
    final monthlyTotal =
        active.fold<int>(0, (s, t) => s + _monthlyEquivalentCents(t));
    final dueSoon =
        active.where((t) => (_daysUntilNext(t) ?? 999) <= 30).length;
    final linked = subs.where((t) => t.autoRecord).length;
    Widget stat(String label, String value) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 12, color: context.yucai.muted)),
            ],
          ),
        );
    return Card(
      color: context.yucai.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('月度等价成本 · ${active.length} 个活跃订阅',
                style: TextStyle(fontSize: 12, color: context.yucai.muted)),
            const SizedBox(height: 4),
            Text('¥${_fmt(monthlyTotal)}',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Row(
              children: [
                stat('年化合计', '¥${_fmt(monthlyTotal * 12)}'),
                stat('30 天内到期', '$dueSoon'),
                stat('自动记账', '$linked/${subs.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _subCard(BuildContext context, Template t) {
    final due = _daysUntilNext(t);
    final dueSoon = due != null && due <= 30;
    return Card(
      color: context.yucai.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Text(t.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      _chip(context, _cycleLabel(t), context.yucai.accent),
                      if (t.paused)
                        _chip(context, '已暂停', context.yucai.negative),
                      if (dueSoon && !t.paused)
                        _chip(context, '$due 天后续费', context.yucai.negative),
                      if (t.autoRecord && !t.paused)
                        _chip(context, '自动记账', context.yucai.positive),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreHorizontal, size: 18),
                  onSelected: (v) {
                    final bloc = context.read<TemplateBloc>();
                    if (v == 'toggle') {
                      bloc.add(t.paused
                          ? ResumeTemplateRequested(t.id)
                          : PauseTemplateRequested(t.id));
                    } else if (v == 'record') {
                      bloc.add(RecordTemplateRequested(t.id));
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(t.paused ? '恢复扣款' : '暂停扣款'),
                    ),
                    const PopupMenuItem(
                      value: 'record',
                      child: Text('立即记一笔'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('¥${_fmt(_monthlyEquivalentCents(t))}/月',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              '每期 ¥${_fmt(t.amountCents)}'
              '${t.category != null && t.category!.isNotEmpty ? ' · ${t.category}' : ''}'
              ' · 下次 ${t.nextDate ?? '-'}${due != null && due >= 0 ? '($due 天)' : ''}',
              style: TextStyle(fontSize: 12, color: context.yucai.muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: color)),
    );
  }

  Widget _caliberCard(BuildContext context) {
    return Card(
      color: context.yucai.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(LucideIcons.info, size: 16, color: context.yucai.muted),
              const SizedBox(width: 6),
              Text('口径说明',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Text(
              '年付订阅按月折算呈现(如 ¥258/年 → ¥21.50/月),报表按月度等价口径,'
              '避免支付月支出爆炸;月付订阅当月直接计费用。'
              '年付待摊(支付时挂预付资产、按月转费用)后续迭代。',
              style: TextStyle(fontSize: 12, color: context.yucai.muted),
            ),
          ],
        ),
      ),
    );
  }
}
