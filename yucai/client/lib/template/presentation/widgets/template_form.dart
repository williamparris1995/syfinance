import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/di/injection.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/utils/date_format.dart';
import 'package:yucai_client/template/domain/entities/template_entity.dart';

/// 表单收集结果(创建/编辑共用)。Dialog 提交时回调给宿主页派发对应 Bloc event。
class TemplateFormResult {
  const TemplateFormResult({
    required this.name,
    required this.description,
    required this.amountCents,
    required this.direction,
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.cycle,
    required this.cycleDays,
    required this.billingDay,
    required this.startDate,
    required this.endDate,
    required this.autoRecord,
    required this.category,
  });

  final String name;
  final String description;
  final int amountCents;
  final TemplateDirection direction;
  final String? sourceAccountId;
  final String? destinationAccountId;
  final TemplateCycle cycle;
  final int cycleDays;
  final int billingDay;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool autoRecord;
  final String? category;
}

/// 周期模板全字段表单(Dialog)。对齐 transaction_form_page 的账户下拉 + 金额格式,
/// 但作为 Dialog 呈现(非独立页面)。create 模式全字段可编辑;edit 模式禁用服务端
/// update 不支持的字段(direction / 账户 / billingDay / startDate / category)。
///
/// 账户列表通过 [getIt<AccountRepository>] 加载(失败降级空列表)。提交校验通过后
/// 回调 [onSubmit];宿主页据此派发 Create/UpdateTemplateRequested。
class TemplateForm extends StatefulWidget {
  const TemplateForm({
    super.key,
    this.existing,
    required this.onSubmit,
  });

  final Template? existing;
  final void Function(TemplateFormResult result) onSubmit;

  @override
  State<TemplateForm> createState() => _TemplateFormState();
}

class _TemplateFormState extends State<TemplateForm> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _cycleDaysCtrl;

  late TemplateDirection _direction;
  String? _sourceAccountId;
  String? _destinationAccountId;
  late TemplateCycle _cycle;
  late int _billingDay;
  DateTime? _startDate;
  DateTime? _endDate;
  late bool _autoRecord;
  String? _category;

  List<Account> _accounts = const [];
  bool _loadingAccounts = true;

  bool get _isEdit => widget.existing != null;
  TemplateDirection get _effectiveDirection => widget.existing?.direction ?? _direction;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    _amountCtrl = TextEditingController(
      text: e == null ? '' : (e.amountCents / 100).toStringAsFixed(2),
    );
    _cycleDaysCtrl = TextEditingController(
      text: (e == null ? 30 : (e.cycleDays > 0 ? e.cycleDays : 30)).toString(),
    );
    _direction = e?.direction ?? TemplateDirection.expense;
    _sourceAccountId = e?.sourceAccountId;
    _destinationAccountId = e?.destinationAccountId;
    _cycle = e?.cycle ?? TemplateCycle.monthly;
    _billingDay = (e == null || e.billingDay <= 0) ? 1 : e.billingDay;
    _startDate = _parseDate(e?.startDate);
    _endDate = _parseDate(e?.endDate);
    _autoRecord = e?.autoRecord ?? false;
    _category = e?.category;
    _loadAccounts();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _cycleDaysCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final result = await getIt<AccountRepository>().list();
      result.fold((_) {}, (list) {
        if (mounted) setState(() => _accounts = list);
      });
    } catch (_) {
      // 静默降级:空账户列表(下拉无可选项,用户可取消)。
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  int get _amountCents =>
      ((double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0) * 100)
          .round();

  int get _cycleDays =>
      int.tryParse(_cycleDaysCtrl.text.trim()) ?? 0;

  List<Account> get _assetAccounts =>
      _accounts.where((a) => a.accountType == AccountType.asset).toList();

  List<Account> get _expenseAccounts =>
      _accounts.where((a) => a.accountType == AccountType.expense).toList();

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _toast('名称不能为空');
      return;
    }
    if (_amountCents <= 0) {
      _toast('金额必须大于 0');
      return;
    }
    if (!_isEdit) {
      final dir = _effectiveDirection;
      if (_sourceAccountId == null) {
        _toast('请选择资金账户');
        return;
      }
      if (dir == TemplateDirection.transfer &&
          (_destinationAccountId == null ||
              _destinationAccountId == _sourceAccountId)) {
        _toast('请选择不同的转入账户');
        return;
      }
      if (_cycle == TemplateCycle.custom && _cycleDays <= 0) {
        _toast('自定义周期天数必须大于 0');
        return;
      }
    }
    widget.onSubmit(TemplateFormResult(
      name: name,
      description: _descCtrl.text.trim(),
      amountCents: _amountCents,
      direction: _effectiveDirection,
      sourceAccountId: _sourceAccountId,
      destinationAccountId: _destinationAccountId,
      cycle: _cycle,
      cycleDays: _cycle == TemplateCycle.custom ? _cycleDays : 0,
      billingDay: _cycle == TemplateCycle.monthly ? _billingDay : 0,
      startDate: _startDate,
      endDate: _endDate,
      autoRecord: _autoRecord,
      category: _category,
    ));
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? _startDate : (_endDate ?? _startDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? '编辑模板' : '新建模板'),
      contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _labeledField(label: '名称', child: _nameField()),
              const SizedBox(height: AppSpacing.sm),
              _labeledField(label: '备注', child: _descField()),
              const SizedBox(height: AppSpacing.sm),
              _labeledField(label: '金额(元)', child: _amountField()),
              const SizedBox(height: AppSpacing.sm),
              _labeledField(
                label: '方向',
                child: _dropdown<TemplateDirection>(
                  value: _effectiveDirection,
                  enabled: !_isEdit,
                  items: const [
                    (TemplateDirection.expense, '支出'),
                    (TemplateDirection.income, '收入'),
                    (TemplateDirection.transfer, '转账'),
                  ],
                  onChanged: (v) => setState(() => _direction = v),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _labeledField(
                label: '资金账户',
                child: _accountDropdown(
                  value: _sourceAccountId,
                  accounts: _assetAccounts,
                  hint: _loadingAccounts ? '加载中…' : '选择账户',
                  enabled: !_isEdit,
                  onChanged: (v) => setState(() => _sourceAccountId = v),
                ),
              ),
              if (_effectiveDirection == TemplateDirection.transfer) ...[
                const SizedBox(height: AppSpacing.sm),
                _labeledField(
                  label: '转入账户',
                  child: _accountDropdown(
                    value: _destinationAccountId,
                    accounts: _assetAccounts
                        .where((a) => a.id != _sourceAccountId)
                        .toList(),
                    hint: '选择转入账户',
                    enabled: !_isEdit,
                    onChanged: (v) => setState(() => _destinationAccountId = v),
                  ),
                ),
              ],
              if (_effectiveDirection == TemplateDirection.expense &&
                  _expenseAccounts.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _labeledField(
                  label: '分类(可选)',
                  child: _accountDropdown(
                    value: _category,
                    accounts: _expenseAccounts,
                    hint: '选择支出分类',
                    enabled: !_isEdit,
                    onChanged: (v) => setState(() => _category = v),
                    allowClear: true,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              _labeledField(
                label: '周期',
                child: _dropdown<TemplateCycle>(
                  value: _cycle,
                  enabled: true,
                  items: const [
                    (TemplateCycle.weekly, '每周'),
                    (TemplateCycle.monthly, '每月'),
                    (TemplateCycle.yearly, '每年'),
                    (TemplateCycle.custom, '自定义'),
                  ],
                  onChanged: (v) => setState(() => _cycle = v),
                ),
              ),
              if (_cycle == TemplateCycle.monthly) ...[
                const SizedBox(height: AppSpacing.sm),
                _labeledField(
                  label: '账单日(1-28)',
                  child: _dropdown<int>(
                    value: _billingDay,
                    enabled: !_isEdit,
                    items: [
                      for (var d = 1; d <= 28; d++) (d, '$d 日'),
                    ],
                    onChanged: (v) => setState(() => _billingDay = v),
                  ),
                ),
              ],
              if (_cycle == TemplateCycle.custom) ...[
                const SizedBox(height: AppSpacing.sm),
                _labeledField(
                  label: '周期天数',
                  child: TextField(
                    controller: _cycleDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco(hint: '如 30'),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _labeledField(
                      label: '起始日期',
                      child: _dateField(_startDate, () => _pickDate(true),
                          disabled: _isEdit),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _labeledField(
                      label: '结束日期(可选)',
                      child: _dateField(_endDate, () => _pickDate(false),
                          disabled: false, clearable: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text('自动记账',
                    style:
                        TextStyle(color: context.yucai.fg, fontSize: 13.5)),
                subtitle: Text('到周期时由系统自动生成交易',
                    style: TextStyle(
                        color: context.yucai.muted, fontSize: 11.5)),
                value: _autoRecord,
                activeThumbColor: context.yucai.accent,
                onChanged: (v) => setState(() => _autoRecord = v),
              ),
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
          onPressed: _submit,
          child: Text(_isEdit ? '保存' : '创建'),
        ),
      ],
    );
  }

  // ───────────────────────── 字段构件 ─────────────────────────

  Widget _labeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style:
                TextStyle(color: context.yucai.muted, fontSize: 12)),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }

  Widget _nameField() => TextField(
        controller: _nameCtrl,
        decoration: _inputDeco(hint: '如:房租 / 工资'),
        textInputAction: TextInputAction.next,
      );

  Widget _descField() => TextField(
        controller: _descCtrl,
        decoration: _inputDeco(hint: '补充说明(可选)'),
      );

  Widget _amountField() => TextField(
        controller: _amountCtrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: _inputDeco(hint: '0.00', prefixText: '¥'),
      );

  Widget _accountDropdown({
    required String? value,
    required List<Account> accounts,
    required String hint,
    required bool enabled,
    required ValueChanged<String?> onChanged,
    bool allowClear = false,
  }) {
    final hasValue = value != null && accounts.any((a) => a.id == value);
    return DropdownButtonFormField<String>(
      initialValue: hasValue ? value : null,
      isExpanded: true,
      decoration: _inputDeco(hint: hint),
      items: accounts
          .map((a) => DropdownMenuItem(value: a.id, child: Text(a.name)))
          .toList(),
      onChanged: enabled ? onChanged : null,
      icon: allowClear && hasValue
          ? IconButton(
              tooltip: '清除',
              icon: Icon(LucideIcons.x, size: 16, color: context.yucai.muted),
              onPressed: () => onChanged(null),
            )
          : null,
    );
  }

  Widget _dateField(
    DateTime? value,
    VoidCallback onTap, {
    required bool disabled,
    bool clearable = false,
  }) {
    return InkWell(
      onTap: disabled ? null : onTap,
      child: InputDecorator(
        decoration: _inputDeco(
          suffix: clearable && value != null
              ? IconButton(
                  tooltip: '清除',
                  icon: Icon(LucideIcons.x,
                      size: 16, color: context.yucai.muted),
                  onPressed: () => setState(() {
                    if (value == _endDate) {
                      _endDate = null;
                    } else {
                      _startDate = null;
                    }
                  }),
                )
              : Icon(LucideIcons.calendar,
                  size: 16, color: context.yucai.muted),
        ),
        child: Text(
          value == null ? '选择日期' : formatDate(value),
          style: TextStyle(
            color:
                value == null ? context.yucai.muted : context.yucai.fg,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required bool enabled,
    required List<(T, String)> items,
    required ValueChanged<T> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: _inputDeco(),
      items: items
          .map((i) => DropdownMenuItem(value: i.$1, child: Text(i.$2)))
          .toList(),
      onChanged: enabled ? (v) => onChanged(v as T) : null,
    );
  }

  /// F4-P2:输入框装饰令牌化(const 因令牌化失效去 const),暗色跟随主题。
  InputDecoration _inputDeco({String? hint, String? prefixText, Widget? suffix}) {
    return InputDecoration(
      isDense: true,
      hintText: hint,
      prefixText: prefixText,
      suffixIcon: suffix,
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
    );
  }
}
