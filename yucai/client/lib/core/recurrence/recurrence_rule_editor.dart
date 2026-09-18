import 'package:flutter/material.dart';

import 'package:yucai_client/core/recurrence/recurrence_rule.dart';
import 'package:yucai_client/core/recurrence/recurrence_rule_text.dart';
import 'package:yucai_client/core/theme/app_design.dart';

/// 月度「按日期」模式的锚点语义:
/// - [billingDay]:订阅 —— 用户显式选账单日(1-31/月末);
/// - [startDate]:借贷 —— 与起始日对齐(短月钳月末),不暴露日期选择。
enum RecurrenceAnchor { billingDay, startDate }

/// 弹出周期规则编辑器(类 Google Calendar 重复规则;template 订阅与
/// debt 分期共用)。返回 null = 取消。
Future<RecurrenceRule?> showRecurrenceRuleEditor(
  BuildContext context, {
  required RecurrenceRule initial,
  RecurrenceAnchor anchor = RecurrenceAnchor.billingDay,
}) {
  return showDialog<RecurrenceRule>(
    context: context,
    builder: (_) => _RecurrenceRuleEditorDialog(initial: initial, anchor: anchor),
  );
}

class _RecurrenceRuleEditorDialog extends StatefulWidget {
  const _RecurrenceRuleEditorDialog({
    required this.initial,
    required this.anchor,
  });

  final RecurrenceRule initial;
  final RecurrenceAnchor anchor;

  @override
  State<_RecurrenceRuleEditorDialog> createState() =>
      _RecurrenceRuleEditorDialogState();
}

class _RecurrenceRuleEditorDialogState
    extends State<_RecurrenceRuleEditorDialog> {
  late RecurrenceRule _rule;
  late TextEditingController _countCtrl;
  String? _countError;

  /// 数量输入框的当前语义值(custom→cycleDays,其余→interval)。
  int get _count =>
      _rule.cycle == RecurrenceCycle.custom
          ? (_rule.cycleDays > 0 ? _rule.cycleDays : 1)
          : (_rule.interval > 0 ? _rule.interval : 1);

  @override
  void initState() {
    super.initState();
    _rule = widget.initial;
    _countCtrl = TextEditingController(text: _count.toString());
  }

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  // ───────────────────────── 预设 ─────────────────────────

  static const _presets = <(String, _Preset)>[
    ('每天', _Preset.daily),
    ('工作日(周一至周五)', _Preset.weekdays),
    ('每周', _Preset.weekly),
    ('每月', _Preset.monthly),
    ('每季度', _Preset.quarterly),
    ('每年', _Preset.yearly),
    ('自定义…', _Preset.custom),
  ];

  _Preset get _presetOf {
    final r = _rule;
    final interval = r.interval > 0 ? r.interval : 1;
    switch (r.cycle) {
      case RecurrenceCycle.custom:
        return (r.cycleDays <= 0 || r.cycleDays == 1) ? _Preset.daily : _Preset.custom;
      case RecurrenceCycle.weekly:
        if (interval == 1 && r.weekdayMask == RecurrenceRule.maskWeekdays) {
          return _Preset.weekdays;
        }
        return (interval == 1 && r.weekdayMask == 0) ? _Preset.weekly : _Preset.custom;
      case RecurrenceCycle.monthly:
        if (r.monthlyMode == RecurrenceMonthlyMode.byDate && r.billingDay <= 0) {
          if (interval == 1) return _Preset.monthly;
          if (interval == 3) return _Preset.quarterly;
        }
        return _Preset.custom;
      case RecurrenceCycle.yearly:
        return interval == 1 ? _Preset.yearly : _Preset.custom;
    }
  }

  void _applyPreset(_Preset p) {
    setState(() {
      switch (p) {
        case _Preset.daily:
          _rule = const RecurrenceRule(
              cycle: RecurrenceCycle.custom, cycleDays: 1);
        case _Preset.weekdays:
          _rule = const RecurrenceRule(
              cycle: RecurrenceCycle.weekly,
              weekdayMask: RecurrenceRule.maskWeekdays);
        case _Preset.weekly:
          _rule = _rule.cycle == RecurrenceCycle.weekly
              ? _rule.copyWith(interval: 1)
              : const RecurrenceRule(cycle: RecurrenceCycle.weekly);
        case _Preset.monthly:
          _rule = _rule.cycle == RecurrenceCycle.monthly
              ? _rule.copyWith(interval: 1)
              : const RecurrenceRule(cycle: RecurrenceCycle.monthly);
        case _Preset.quarterly:
          _rule = _rule.copyWith(
              cycle: RecurrenceCycle.monthly,
              interval: 3,
              monthlyMode: RecurrenceMonthlyMode.byDate,
              billingDay: 0,
              weekdayMask: 0,
              nth: 0);
        case _Preset.yearly:
          _rule = _rule.cycle == RecurrenceCycle.yearly
              ? _rule.copyWith(interval: 1)
              : const RecurrenceRule(cycle: RecurrenceCycle.yearly);
        case _Preset.custom:
          break; // 仅展开编辑控件,不改当前值
      }
      _countCtrl.text = _count.toString();
      _countError = null;
    });
  }

  // ───────────────────────── 编辑 ─────────────────────────

  void _updateCount(String text) {
    final v = int.tryParse(text.trim());
    setState(() {
      _countError = null;
      if (_rule.cycle == RecurrenceCycle.custom) {
        _rule = _rule.copyWith(cycleDays: v ?? 0);
      } else {
        _rule = _rule.copyWith(interval: v ?? 0);
      }
    });
  }

  void _switchUnit(String unit) {
    final cycle = switch (unit) {
      '天' => RecurrenceCycle.custom,
      '周' => RecurrenceCycle.weekly,
      '月' => RecurrenceCycle.monthly,
      _ => RecurrenceCycle.yearly,
    };
    if (cycle == _rule.cycle) return;
    setState(() {
      final count = _count;
      if (cycle == RecurrenceCycle.custom) {
        _rule = _rule.copyWith(cycle: cycle, cycleDays: count, interval: 0);
      } else {
        _rule = _rule.copyWith(cycle: cycle, interval: count, cycleDays: 0);
      }
    });
  }

  void _toggleWeekday(int bit) {
    setState(() {
      // byNthWeekday 单选语义;weekly 多选语义;全清 = 0(沿用起始日星期)。
      if (_rule.monthlyMode == RecurrenceMonthlyMode.byNthWeekday &&
          _rule.cycle == RecurrenceCycle.monthly) {
        _rule = _rule.copyWith(weekdayMask: 1 << bit);
      } else {
        _rule = _rule.copyWith(
            weekdayMask: _rule.weekdayMask ^ (1 << bit));
      }
    });
  }

  bool _submit() {
    final v = int.tryParse(_countCtrl.text.trim());
    if (_rule.cycle == RecurrenceCycle.custom) {
      if (v == null || v < 1 || v > 3650) {
        setState(() => _countError = '天数需在 1-3650 之间');
        return false;
      }
      _rule = _rule.copyWith(cycleDays: v);
    } else {
      if (v == null || v < 1 || v > 100) {
        setState(() => _countError = '间隔需在 1-100 之间');
        return false;
      }
      _rule = _rule.copyWith(interval: v);
    }
    // byNthWeekday 未选星期 → 默认周一,避免落库无效组合。
    if (_rule.cycle == RecurrenceCycle.monthly &&
        _rule.monthlyMode == RecurrenceMonthlyMode.byNthWeekday) {
      if (_rule.nth < 1 || _rule.nth > 5) {
        _rule = _rule.copyWith(nth: 1);
      }
      if (_rule.weekdayMask == 0 ||
          (_rule.weekdayMask & (_rule.weekdayMask - 1)) != 0) {
        _rule = _rule.copyWith(weekdayMask: 1 << 0);
      }
    }
    return true;
  }

  // ───────────────────────── 渲染 ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('重复规则'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _labeled('预设', _presetDropdown()),
              const SizedBox(height: AppSpacing.sm),
              _labeled('频率', _frequencyRow()),
              if (_rule.cycle == RecurrenceCycle.weekly) ...[
                const SizedBox(height: AppSpacing.sm),
                _labeled('重复于(星期)', _weekdayChips()),
              ],
              if (_rule.cycle == RecurrenceCycle.monthly) ...[
                const SizedBox(height: AppSpacing.sm),
                _labeled('每月方式', _monthlyModeButton()),
                const SizedBox(height: AppSpacing.sm),
                if (_rule.monthlyMode == RecurrenceMonthlyMode.byDate)
                  _labeled('日期', _monthlyDateField())
                else
                  _labeled('第几个', _nthRow()),
              ],
              const SizedBox(height: AppSpacing.md),
              _preview(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (_submit()) Navigator.of(context).pop(_rule);
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  Widget _labeled(String label, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: context.yucai.muted, fontSize: 12)),
          const SizedBox(height: AppSpacing.xs),
          child,
        ],
      );

  InputDecoration _deco({String? hint}) => InputDecoration(
        isDense: true,
        hintText: hint,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: context.yucai.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: context.yucai.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.smBorder,
          borderSide: BorderSide(color: context.yucai.accent),
        ),
        errorText: _countError,
      );

  Widget _presetDropdown() => DropdownButtonFormField<_Preset>(
        initialValue: _presetOf,
        isExpanded: true,
        decoration: _deco(),
        items: [
          for (final (label, value) in _presets)
            DropdownMenuItem(value: value, child: Text(label)),
        ],
        onChanged: (v) {
          if (v != null) _applyPreset(v);
        },
      );

  /// 「每 [N] [天/周/月/年]」一行。
  Widget _frequencyRow() {
    final unit = switch (_rule.cycle) {
      RecurrenceCycle.custom => '天',
      RecurrenceCycle.weekly => '周',
      RecurrenceCycle.monthly => '月',
      RecurrenceCycle.yearly => '年',
    };
    return Row(
      children: [
        Text('每',
            style: TextStyle(color: context.yucai.fg, fontSize: 13.5)),
        const SizedBox(width: AppSpacing.sm),
        SizedBox(
          width: 72,
          child: TextField(
            controller: _countCtrl,
            keyboardType: TextInputType.number,
            onChanged: _updateCount,
            decoration: _deco(),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: unit,
            isExpanded: true,
            decoration: _deco(),
            items: const [
              DropdownMenuItem(value: '天', child: Text('天')),
              DropdownMenuItem(value: '周', child: Text('周')),
              DropdownMenuItem(value: '月', child: Text('月')),
              DropdownMenuItem(value: '年', child: Text('年')),
            ],
            onChanged: (v) {
              if (v != null) _switchUnit(v);
            },
          ),
        ),
      ],
    );
  }

  Widget _weekdayChips() {
    final singleSelect = _rule.monthlyMode == RecurrenceMonthlyMode.byNthWeekday &&
        _rule.cycle == RecurrenceCycle.monthly;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var i = 0; i < 7; i++)
              FilterChip(
                label: Text(kWeekdayNames[i]),
                showCheckmark: false,
                selected: _rule.weekdayMask & (1 << i) != 0,
                onSelected: (_) => _toggleWeekday(i),
                selectedColor: context.yucai.accentSoft,
                backgroundColor: context.yucai.surfaceAlt,
                labelStyle: TextStyle(
                  fontSize: 12,
                  color: _rule.weekdayMask & (1 << i) != 0
                      ? context.yucai.fg
                      : context.yucai.muted,
                ),
              ),
          ],
        ),
        if (!singleSelect && _rule.weekdayMask == 0)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('不选则按起始日期的星期',
                style: TextStyle(color: context.yucai.muted, fontSize: 11.5)),
          ),
      ],
    );
  }

  Widget _monthlyModeButton() => SegmentedButton<RecurrenceMonthlyMode>(
        segments: const [
          ButtonSegment(
              value: RecurrenceMonthlyMode.byDate, label: Text('按日期')),
          ButtonSegment(
              value: RecurrenceMonthlyMode.byNthWeekday,
              label: Text('按第 N 个星期几')),
        ],
        selected: {_rule.monthlyMode},
        onSelectionChanged: (s) => setState(() {
          _rule = _rule.copyWith(monthlyMode: s.first);
        }),
      );

  Widget _monthlyDateField() {
    if (widget.anchor == RecurrenceAnchor.startDate) {
      return Text(
        '与起始日期对齐(起始日为 29/30/31 时,短月自动落于月末)',
        style: TextStyle(color: context.yucai.muted, fontSize: 12.5),
      );
    }
    return DropdownButtonFormField<int>(
      initialValue: _rule.billingDay.clamp(0, 31),
      isExpanded: true,
      decoration: _deco(),
      items: [
        const DropdownMenuItem(value: 0, child: Text('跟随起始日')),
        for (var d = 1; d <= 30; d++) DropdownMenuItem(value: d, child: Text('$d 日')),
        const DropdownMenuItem(value: 31, child: Text('月末(31,短月自动提前)')),
      ],
      onChanged: (v) => setState(() => _rule = _rule.copyWith(billingDay: v ?? 0)),
    );
  }

  Widget _nthRow() {
    final nth = _rule.nth >= 1 && _rule.nth <= 5 ? _rule.nth : 1;
    final weekdayBit = _singleBit(_rule.weekdayMask) ?? 0;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: nth,
            isExpanded: true,
            decoration: _deco(),
            items: const [
              DropdownMenuItem(value: 1, child: Text('第 1 个')),
              DropdownMenuItem(value: 2, child: Text('第 2 个')),
              DropdownMenuItem(value: 3, child: Text('第 3 个')),
              DropdownMenuItem(value: 4, child: Text('第 4 个')),
              DropdownMenuItem(value: 5, child: Text('最后一个')),
            ],
            onChanged: (v) => setState(() => _rule = _rule.copyWith(nth: v ?? 1)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: weekdayBit,
            isExpanded: true,
            decoration: _deco(),
            items: [
              for (var i = 0; i < 7; i++)
                DropdownMenuItem(value: i, child: Text(kWeekdayNames[i])),
            ],
            onChanged: (v) => setState(() {
              _rule = _rule.copyWith(weekdayMask: 1 << (v ?? 0));
            }),
          ),
        ),
      ],
    );
  }

  Widget _preview() => Container(
        key: const ValueKey('recurrencePreview'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.yucai.surfaceAlt,
          borderRadius: AppRadius.smBorder,
        ),
        child: Row(
          children: [
            Text('重复方式',
                style: TextStyle(color: context.yucai.muted, fontSize: 12)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                recurrenceRuleText(_rule),
                style: TextStyle(
                    color: context.yucai.fg,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
}

enum _Preset { daily, weekdays, weekly, monthly, quarterly, yearly, custom }

int? _singleBit(int mask) {
  if (mask == 0 || (mask & (mask - 1)) != 0) return null;
  var m = mask, i = 0;
  while (m & 1 == 0) {
    m >>= 1;
    i++;
  }
  return i;
}
