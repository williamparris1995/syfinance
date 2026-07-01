import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_bloc.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/form_section.dart';

/// 预算表单页(创建 + 编辑)。复用 AccountRepository list 拉账户,客户端
/// filter `accountType == expense` —— account-as-category 模型下,expense
/// 账户即「支出分类」(餐饮/交通...),其余(asset/investment/wallet)不可预算。
///
/// - [budgetId] == null:创建模式(dispatch CreateBudgetRequested)。
/// - [budgetId] != null:编辑模式。MVP 简化 = 加载现有预算 → 预填 → 提交时
///   先 delete 旧预算(DeleteBudgetRequested)再 create 新预算
///   (CreateBudgetRequested)。增量 AddItem/RemoveItem 留待后续(对齐 task
///   brief 的「MVP 简化: 编辑 = 删旧 + 重建 defer 增量」决策)。
///
/// 可选 [initialMonth] 供测试 seed 月份(默认当月),避免驱动 picker。
class BudgetFormPage extends StatefulWidget {
  const BudgetFormPage({
    super.key,
    this.budgetId,
    this.initialMonth,
    this.initialCurrencyCode = 'CNY',
  });

  /// 非 null = 编辑模式;null = 创建模式。
  final String? budgetId;
  final String? initialMonth;
  final String initialCurrencyCode;

  @override
  State<BudgetFormPage> createState() => _BudgetFormPageState();
}

/// 单条 item 编辑行的 mutable state(不暴露给 widget tree)。
class _ItemRow {
  _ItemRow({this.accountId, String plannedAmount = ''})
      : plannedAmountCtrl = TextEditingController(text: plannedAmount);

  String? accountId;
  final TextEditingController plannedAmountCtrl;

  void dispose() => plannedAmountCtrl.dispose();
}

class _BudgetFormPageState extends State<BudgetFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  /// 月份(yyyy-MM)。默认当月。
  late String _month;
  late String _currencyCode;

  /// 全部 expense 账户(account-as-category 模型下 = 支出分类)。
  List<Account> _expenseAccounts = const [];
  bool _accountsLoading = true;

  /// item 编辑行列表。≥1 行(domain 强制)。
  final List<_ItemRow> _rows = [];

  bool _submitted = false;

  /// 编辑模式加载到的现有预算(null = 创建 / 加载中)。
  BudgetView? _existingBudget;

  bool get _isEdit => widget.budgetId != null;

  /// 默认货币下拉选项(MVP 简单:常见币种)。
  static const _currencies = <String>['CNY', 'USD', 'HKD', 'EUR', 'JPY'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = widget.initialMonth ??
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _currencyCode = widget.initialCurrencyCode;
    _loadAccounts();
    if (_isEdit) {
      _loadExisting();
    } else {
      // 创建模式:预置一行空 item(至少 1 行)。
      _rows.add(_ItemRow());
    }
    _nameCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    // 对齐 debt_form_page._loadAccounts:GetIt<AccountRepository>().list(),
    // 客户端 filter `accountType == expense`(KEY —— 排除 asset/investment/wallet)。
    try {
      final repo = GetIt.instance<AccountRepository>();
      final result = await repo.list();
      final list = result.fold((_) => const <Account>[], (l) => l);
      if (!mounted) return;
      setState(() {
        _expenseAccounts =
            list.where((a) => a.accountType == AccountType.expense).toList();
        _accountsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _accountsLoading = false);
    }
  }

  Future<void> _loadExisting() async {
    // 编辑模式:dispatch LoadDetailRequested 拉取现有预算 → 预填表单。
    if (widget.budgetId == null) return;
    if (!mounted) return;
    context.read<BudgetBloc>().add(LoadDetailRequested(widget.budgetId!));
  }

  void _onBudgetStateChanged(BuildContext context, BudgetState state) {
    // 编辑模式:加载完成 → 预填 name/month/currency/items。
    if (state is BudgetDetailLoaded && _existingBudget == null) {
      final b = state.budget;
      _existingBudget = b;
      _nameCtrl.text = b.name;
      _month = b.month;
      _currencyCode = b.currencyCode;
      _rows.clear();
      for (final it in b.items) {
        _rows.add(_ItemRow(
          accountId: it.accountId,
          plannedAmount: (it.plannedAmountCents / 100).toStringAsFixed(2),
        ));
      }
      if (_rows.isEmpty) _rows.add(_ItemRow());
      setState(() {});
      return;
    }
    // 提交成功:BudgetListLoaded 是 create/delete 成功后的刷新信号。
    // 编辑模式 delete→recreate 会触发 2 次 BudgetListLoaded(delete 一次,
    // create 一次);用 _editCreateCount 等到第 2 次才 pop,避免 delete 后误 pop。
    if (_submitted && state is BudgetListLoaded) {
      if (_isEdit) {
        _editCreateCount++;
        if (_editCreateCount >= 2) {
          _submitted = false;
          Navigator.of(context).pop(true);
        }
      } else {
        _submitted = false;
        Navigator.of(context).pop(true);
      }
    }
  }

  /// 编辑模式 delete→recreate 的 BudgetListLoaded 计数(2 次 = delete + create)。
  int _editCreateCount = 0;

  void _addItemRow() => setState(() => _rows.add(_ItemRow()));

  void _removeItemRow(int i) {
    // 至少保留 0 行?domain 要求 ≥1,但 UI 允许全删以禁用提交(由 _canSubmit 兜底)。
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
    });
  }

  Future<void> _pickMonth() async {
    // 简单 YYYY-MM picker:复用 showDatePicker 取一个日期,转 yyyy-MM(日忽略)。
    final parts = _month.split('-');
    final initial = DateTime(
      int.tryParse(parts.first) ?? DateTime.now().year,
      parts.length > 1 ? (int.tryParse(parts[1]) ?? 1) : 1,
      1,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择预算月份',
    );
    if (picked != null) {
      setState(() {
        _month =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      AppToast.show(context, '请填写预算名称', type: ToastType.warning);
      return;
    }
    if (_rows.isEmpty) {
      AppToast.show(context, '请至少添加一个预算项', type: ToastType.warning);
      return;
    }
    for (var i = 0; i < _rows.length; i++) {
      final r = _rows[i];
      if (r.accountId == null || r.accountId!.isEmpty) {
        AppToast.show(context, '第 ${i + 1} 项未选择分类', type: ToastType.warning);
        return;
      }
      final amt = double.tryParse(r.plannedAmountCtrl.text);
      if (amt == null || amt < 0) {
        AppToast.show(context, '第 ${i + 1} 项计划金额无效', type: ToastType.warning);
        return;
      }
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();
    _submitted = true;

    final items = _rows
        .map((r) => (
              accountId: r.accountId!,
              plannedAmountCents:
                  ((double.tryParse(r.plannedAmountCtrl.text) ?? 0) * 100)
                      .round(),
              notes: null as String?,
            ))
        .toList();

    // 在 await / dispatch 前捕获 bloc(避免跨 async gap 用 BuildContext)。
    final bloc = context.read<BudgetBloc>();
    // 编辑模式 MVP:删旧 + 重建(对齐 brief 决策)。delete 与 create 顺序入队,
    // 两次 BudgetListLoaded 后才 pop(_onBudgetStateChanged 用计数兜底)。
    if (_isEdit) {
      bloc.add(DeleteBudgetRequested(widget.budgetId!));
    }
    bloc.add(CreateBudgetRequested(
      name: _nameCtrl.text.trim(),
      month: _month,
      currencyCode: _currencyCode,
      items: items,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(_isEdit ? '编辑预算' : '新建预算'),
      ),
      body: BlocConsumer<BudgetBloc, BudgetState>(
        listenWhen: (prev, curr) =>
            curr is BudgetDetailLoaded || curr is BudgetListLoaded,
        listener: _onBudgetStateChanged,
        builder: (context, state) {
          final submitting = state is BudgetLoading;
          // 编辑模式未加载完(_existingBudget == null)→ 显示 loading。
          if (_isEdit && _existingBudget == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return AbsorbPointer(
            absorbing: submitting,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FormSection(
                          title: '1 · 基本信息',
                          children: _basicInfoFields(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FormSection(
                          title: '2 · 预算项(按支出分类)',
                          children: _itemsEditor(submitting),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        FormActions(
                          submitLabel: _isEdit ? '保存修改' : '确认创建',
                          submitting: submitting,
                          onSubmit: _submit,
                          onCancel: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ----- 基本信息:Name + Month + Currency -----
  List<Widget> _basicInfoFields() {
    return [
      TextFormField(
        key: const ValueKey('nameField'),
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: '预算名称',
          hintText: '如 7 月家庭预算',
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? '请输入预算名称' : null,
      ),
      const SizedBox(height: AppSpacing.md),
      FormRow(children: [
        // 月份 picker(点击弹 showDatePicker,取 yyyy-MM)。
        InkWell(
          key: const ValueKey('monthPicker'),
          onTap: _pickMonth,
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: '预算月份',
              suffixIcon:
                  Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(
              _month,
              style: TextStyle(
                color: _month.isEmpty ? AppColors.muted : AppColors.fg,
              ),
            ),
          ),
        ),
        // 货币下拉(MVP 简单:常驻币种)。
        DropdownButtonFormField<String>(
          key: const ValueKey('currencyDropdown'),
          decoration: const InputDecoration(labelText: '货币'),
          value: _currencyCode,
          items: [
            for (final c in _currencies)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => _currencyCode = v);
          },
        ),
      ]),
    ];
  }

  // ----- Items 编辑器(account dropdown 只列 expense 账户) -----
  List<Widget> _itemsEditor(bool submitting) {
    return [
      for (var i = 0; i < _rows.length; i++)
        Padding(
          key: ValueKey('itemRow-$i'),
          padding: EdgeInsets.only(bottom: i < _rows.length - 1 ? AppSpacing.md : 0),
          child: FormRow(children: [
            // account dropdown —— 只列 expense 账户(KEY)。
            DropdownButtonFormField<String>(
              key: ValueKey('itemAccount-$i'),
              decoration: const InputDecoration(labelText: '支出分类'),
              value: _rows[i].accountId,
              items: [
                for (final a in _expenseAccounts)
                  DropdownMenuItem(value: a.id, child: Text(a.name)),
              ],
              hint: Text(_accountsLoading ? '加载中…' : '选择分类'),
              onChanged: submitting
                  ? null
                  : (v) => setState(() => _rows[i].accountId = v),
            ),
            TextFormField(
              key: ValueKey('itemAmount-$i'),
              controller: _rows[i].plannedAmountCtrl,
              decoration: const InputDecoration(
                labelText: '计划金额',
                prefixText: '¥ ',
                hintText: '0.00',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
            // 删除按钮。
            IconButton(
              key: ValueKey('itemRemove-$i'),
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              tooltip: '删除此预算项',
              onPressed: submitting ? null : () => _removeItemRow(i),
            ),
          ]),
        ),
      const SizedBox(height: AppSpacing.sm),
      // + 加项
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const ValueKey('addItemButton'),
          onPressed: submitting ? null : _addItemRow,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('加项'),
        ),
      ),
    ];
  }
}
