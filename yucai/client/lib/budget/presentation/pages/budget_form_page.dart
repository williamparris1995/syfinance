// 预算表单页(创建 + 编辑)。消费 BudgetBloc + AccountRepository。
//
// 设计源(OD 原型):design-output/budget/budget-form-{desktop,tablet,mobile}.html
//  + styles.css + mock-data.js。**大 UI 对齐原型**(2026-07,照 budget list/detail
//  对齐范式):
//   - topbar:title「新建预算」/「编辑预算」+ sub + 返回 icon-btn + 取消 ghost +
//     btn-gold 提交(替底部 ElevatedButton,原型顶部 + 底部都有,Flutter 取 topbar)。
//   - 基本信息:Name TextField + Month picker(yyyy-MM,点击弹 showDatePicker)+
//     Currency(只读显示 CNY,原型 disabled input,单预算单货币)。
//   - Items 编辑:每 item = expense account picker chips 化(替 DropdownButton,
//     只列 AccountType.expense 账户=category)+ PlannedAmount TextField + 删按钮。
//     "+ 加项"按钮(≥1 item)。对齐原型 item-row 布局(account select + ¥amt + trash)。
//   - 空校验:name 空 / items 0 / planned ≤0 → 禁用 btn-gold 提交。
//
// - [budgetId] == null:创建模式(dispatch CreateBudgetRequested)。
// - [budgetId] != null:编辑模式。加载现有 → 预填 → 提交 UpdateBudgetRequested
//   (整体原地更新 name+currency+items,budget ID 不变;month 锁,budget 身份)。
//   成功后 bloc 重拉 detail → BudgetDetailLoaded → form pop 返回详情页。
//
// 御财设计语言(已语义令牌化(F15)/AppTypography/lucide + 本地 _GoldButton,与
//  budget_list_page 一致):御财金 #b08d57 btn-gold。
//
// 无 i18n(中文硬编码,御财惯例;与 budget/holding/goal 表单页一致)。
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/budget/domain/entities/budget_entity.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_bloc.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_event.dart';
import 'package:yucai_client/budget/presentation/bloc/budget_state.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/detail_title_sync.dart';
import 'package:yucai_client/core/widgets/form_leave_guard.dart';

/// 预算表单页(创建 + 编辑)。
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

  // ---- F59 FR-5(ADR-3):脏态追踪(首改即脏粗粒度)+ 三级面包屑注入串 ----

  /// 首改即脏:任一字段首次用户编辑置位;净态离开(系统返回/面包屑)零摩擦,
  /// 脏态经 FormLeaveGuard 弹「未保存的修改」确认。提交成功的程序化 pop
  /// 不经 canPop 判定,不受守卫影响。
  bool _dirty = false;

  /// 程序化回填抑制窗:编辑态预填(bloc 加载完成写入 name/month/rows)期间
  /// controller listener 触发不置脏 —— 预填非用户编辑。
  bool _prefilling = false;

  /// 置脏(首改即脏):翻转时 setState 重建 FormLeaveGuard(PopScope 的
  /// canPop 随动)。抑制窗内/已脏直接返回。
  void _markDirty() {
    if (_prefilling || _dirty) return;
    setState(() => _dirty = true);
  }

  /// 三级面包屑注入串:创建 =「新建预算」;编辑加载中 =「编辑预算」占位,
  /// 加载完成 =「编辑 · {预算名}」。
  String get _crumbTitle => !_isEdit
      ? '新建预算'
      : (_existingBudget == null
          ? '编辑预算'
          : '编辑 · ${_existingBudget!.name}');

  /// 行编辑控制器接脏监听(行动态增删,创建时接线)。
  _ItemRow _wireRow(_ItemRow r) {
    r.plannedAmountCtrl.addListener(_markDirty);
    return r;
  }

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
      _rows.add(_wireRow(_ItemRow()));
    }
    // F59 FR-5:文本字段首改即脏;既有 setState 监听(canSubmit 重算)保留。
    _nameCtrl.addListener(() {
      _markDirty();
      setState(() {});
    });
  }

  @override
  void dispose() {
    // F59 FR-5:离开表单清注入标题(guarded getIt:测试 harness 未注册时跳过)。
    scheduleDetailTitleClear();
    _nameCtrl.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    // GetIt<AccountRepository>().list(),客户端 filter `accountType == expense`
    // (KEY —— 排除 asset/investment/wallet,account-as-category 模型下 expense
    // 账户即「支出分类」:餐饮/交通...)。
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
    if (widget.budgetId == null) return;
    if (!mounted) return;
    context.read<BudgetBloc>().add(LoadDetailRequested(widget.budgetId!));
  }

  void _onBudgetStateChanged(BuildContext context, BudgetState state) {
    // 编辑模式:加载完成 → 预填 name/month/currency/items。
    if (state is BudgetDetailLoaded && _existingBudget == null) {
      final b = state.budget;
      _prefilling = true; // F59 FR-5:预填不置脏
      try {
        _existingBudget = b;
        _nameCtrl.text = b.name;
        _month = b.month;
        _currencyCode = b.currencyCode;
        _rows.clear();
        for (final it in b.items) {
          _rows.add(_wireRow(_ItemRow(
            accountId: it.accountId,
            plannedAmount: (it.plannedAmountCents / 100).toStringAsFixed(2),
          )));
        }
        if (_rows.isEmpty) _rows.add(_wireRow(_ItemRow()));
      } finally {
        _prefilling = false;
      }
      setState(() {});
      return;
    }
    // 提交成功:edit → BudgetDetailLoaded(update 后重拉);create → BudgetListLoaded。
    // (旧 delete+recreate 触发 2 次 BudgetListLoaded + _editCreateCount 计数 —— 已删。)
    if (_submitted && _isEdit && state is BudgetDetailLoaded) {
      _submitted = false;
      Navigator.of(context).pop(true);
      return;
    }
    if (_submitted && !_isEdit && state is BudgetListLoaded) {
      _submitted = false;
      Navigator.of(context).pop(true);
    }
  }

  void _addItemRow() => setState(() {
        _markDirty(); // F59 FR-5:加项 = 用户编辑
        _rows.add(_wireRow(_ItemRow()));
      });

  void _removeItemRow(int i) {
    // UI 允许全删以禁用提交(由 _canSubmit 兜底)。
    setState(() {
      _markDirty(); // F59 FR-5:删项 = 用户编辑
      _rows[i].dispose();
      _rows.removeAt(i);
    });
  }

  Future<void> _pickMonth() async {
    // YYYY-MM picker:复用 showDatePicker 取一个日期,转 yyyy-MM(日忽略)。
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
        _markDirty(); // F59 FR-5:改月份 = 用户编辑
        _month = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
      });
    }
  }

  // ───────────────────────── 校验 / 提交 ─────────────────────────

  bool get _canSubmit {
    if (_nameCtrl.text.trim().isEmpty) return false;
    if (_rows.isEmpty) return false;
    for (final r in _rows) {
      if (r.accountId == null || r.accountId!.isEmpty) return false;
      final amt = double.tryParse(r.plannedAmountCtrl.text);
      if (amt == null || amt <= 0) return false;
    }
    return true;
  }

  void _submit() {
    if (!_canSubmit) {
      // 友好提示:逐项诊断。
      if (_nameCtrl.text.trim().isEmpty) {
        AppToast.show(context, '请填写预算名称', type: ToastType.warning);
      } else if (_rows.isEmpty) {
        AppToast.show(context, '请至少添加一个预算项', type: ToastType.warning);
      } else {
        for (var i = 0; i < _rows.length; i++) {
          final r = _rows[i];
          if (r.accountId == null || r.accountId!.isEmpty) {
            AppToast.show(context, '第 ${i + 1} 项未选择分类', type: ToastType.warning);
            return;
          }
          final amt = double.tryParse(r.plannedAmountCtrl.text);
          if (amt == null || amt <= 0) {
            AppToast.show(context, '第 ${i + 1} 项计划金额需大于 0',
                type: ToastType.warning);
            return;
          }
        }
      }
      return;
    }
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

    // 在 dispatch 前捕获 bloc(避免跨 async gap 用 BuildContext)。
    final bloc = context.read<BudgetBloc>();
    if (_isEdit) {
      // 编辑模式:原地 UpdateBudget(不再 delete+recreate —— budget ID 不变、
      // 原子、无 _editCreateCount 竞态 hack)。
      bloc.add(UpdateBudgetRequested(
        budgetId: widget.budgetId!,
        name: _nameCtrl.text.trim(),
        currencyCode: _currencyCode,
        items: items,
      ));
    } else {
      bloc.add(CreateBudgetRequested(
        name: _nameCtrl.text.trim(),
        month: _month,
        currencyCode: _currencyCode,
        items: items,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      // F59 FR-5:自带返回条退役(回退统一走顶栏面包屑 page 级 + 系统返回,
      // 均经守卫);body 包 FormLeaveGuard(脏态弹确认,净态直走;提交成功的
      // 程序化 pop 不经 canPop 判定不受影响)+ DetailTitleSync 注入三级
      // 面包屑串(放滚动容器外)。
      body: FormLeaveGuard(
        isDirty: () => _dirty,
        child: Stack(
          children: [
            BlocConsumer<BudgetBloc, BudgetState>(
              listenWhen: (prev, curr) =>
                  curr is BudgetDetailLoaded || curr is BudgetListLoaded,
              listener: _onBudgetStateChanged,
              builder: (context, state) {
          final submitting = state is BudgetLoading;
          // 编辑模式未加载完(_existingBudget == null)→ loading。
          if (_isEdit && _existingBudget == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final canSubmit = _canSubmit;
          return Column(
            children: [
              _topbar(submitting, canSubmit),
              Expanded(
                child: AbsorbPointer(
                  absorbing: submitting,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg,
                        AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _basicInfoSection(),
                            const SizedBox(height: AppSpacing.lg),
                            _itemsSectionHeader(),
                            const SizedBox(height: AppSpacing.sm),
                            _itemsEditor(submitting),
                            const SizedBox(height: AppSpacing.sm),
                            _addItemButton(submitting),
                            const SizedBox(height: AppSpacing.xl),
                            _bottomActions(submitting, canSubmit),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
            ),
            // 三级面包屑注入串(新建/编辑两态);非定位子级,放滚动容器外。
            DetailTitleSync(title: _crumbTitle),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── topbar(对齐原型 topbar-d) ─────────────────────────

  Widget _topbar(bool submitting, bool canSubmit) {
    return Material(
      color: context.yucai.bg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // left:title + sub。F59 FR-5:返回 icon-btn 退役(回退走顶栏
                // 面包屑/系统返回,经守卫);标题降为内容头。
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEdit ? '编辑预算' : '新建预算',
                        key: const ValueKey('budgetFormTitle'),
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppTypography.displayFamily,
                            fontFamilyFallback:
                                AppTypography.displayFallback),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '设定月度预算 · 选择分类账户 + 计划金额 · 保存后自动计算 actuals',
                        key: const ValueKey('budgetFormSub'),
                        style: TextStyle(
                            fontSize: 12.5, color: context.yucai.muted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // actions:取消 ghost + btn-gold 提交。
                if (!submitting)
                  TextButton(
                    key: const ValueKey('budgetFormCancel'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                const SizedBox(width: AppSpacing.xs),
                _GoldButton(
                  key: const ValueKey('budgetFormSubmit'),
                  icon: LucideIcons.check,
                  label: _isEdit ? '保存修改' : '保存预算',
                  onPressed: _submit,
                  disabled: submitting || !canSubmit,
                  loading: submitting,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 基本信息(对齐原型 form-section) ─────────────────────────

  Widget _basicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('基本信息', LucideIcons.info),
        const SizedBox(height: AppSpacing.sm),
        // Name + Month 横排。
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            SizedBox(
              width: 320,
              child: TextField(
                key: const ValueKey('nameField'),
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: '预算名称 *',
                  hintText: '例如：日常开销预算',
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: AbsorbPointer(
                // edit 时 month 不可改(budget 身份 —— 不可逆,改月=换预算)。
                absorbing: _isEdit,
                child: Opacity(
                  opacity: _isEdit ? 0.5 : 1.0,
                  child: InkWell(
                    key: const ValueKey('monthPicker'),
                    onTap: _pickMonth,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '月份 *',
                        suffixIcon:
                            Icon(LucideIcons.calendar, size: 18),
                      ),
                      child: Text(
                        _month,
                        style: TextStyle(
                          color:
                              _month.isEmpty ? context.yucai.muted : context.yucai.fg,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        // 货币(只读显示,原型 disabled input,单预算单货币)。
        SizedBox(
          width: 320,
          child: TextField(
            key: const ValueKey('currencyField'),
            controller: TextEditingController(text: '$_currencyCode (人民币)'),
            readOnly: true,
            enabled: false,
            decoration: const InputDecoration(
              labelText: '货币',
              helperText: '单预算单货币,与账户货币一致',
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Items 编辑器 ─────────────────────────

  Widget _sectionTitle(String text, IconData icon) => Row(
        children: [
          Icon(icon, size: 16, color: context.yucai.accent),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.yucai.fg,
                  fontFamily: AppTypography.displayFamily,
                  fontFamilyFallback: AppTypography.displayFallback)),
        ],
      );

  Widget _itemsSectionHeader() {
    return Row(
      children: [
        Icon(LucideIcons.listChecks, size: 16, color: context.yucai.accent),
        const SizedBox(width: 6),
        Text('预算条目(分类账户 + 计划金额)',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: context.yucai.fg)),
        const SizedBox(width: 6),
        Text('至少 1 项',
            style: TextStyle(fontSize: 12, color: context.yucai.negative)),
      ],
    );
  }

  Widget _itemsEditor(bool submitting) {
    if (_rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text('暂无条目，点击下方「添加条目」开始',
            style: TextStyle(color: context.yucai.muted, fontSize: 13)),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < _rows.length; i++)
          Padding(
            key: ValueKey('itemRow-$i'),
            padding: EdgeInsets.only(
                bottom: i < _rows.length - 1 ? AppSpacing.md : 0),
            child: _itemRowCard(i, submitting),
          ),
      ],
    );
  }

  Widget _itemRowCard(int i, bool submitting) {
    final row = _rows[i];
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        borderRadius: AppRadius.lgBorder,
        border: Border.all(color: context.yucai.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // account picker chips(替 DropdownButton,对齐原型 chips)。
          _accountChips(i, row, submitting),
          const SizedBox(height: AppSpacing.md),
          // 计划金额 + 删除按钮。
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: ValueKey('itemAmount-$i'),
                  controller: row.plannedAmountCtrl,
                  decoration: const InputDecoration(
                    labelText: '计划金额',
                    prefixText: '¥ ',
                    hintText: '0.00',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                key: ValueKey('itemRemove-$i'),
                icon: const Icon(LucideIcons.trash2, size: 18),
                color: context.yucai.negative,
                tooltip: '移除条目',
                onPressed: submitting ? null : () => _removeItemRow(i),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// expense account picker chips(替 DropdownButton)。每 account 一 chip,
  /// 选中 = accent 金底;只列 expense 账户(_expenseAccounts 已 filter)。
  Widget _accountChips(int i, _ItemRow row, bool submitting) {
    if (_accountsLoading) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text('加载分类中…',
            style: TextStyle(color: context.yucai.muted, fontSize: 12)),
      );
    }
    if (_expenseAccounts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Text('暂无支出分类账户(需先创建 expense 账户)',
            style: TextStyle(color: context.yucai.muted, fontSize: 12)),
      );
    }
    return Wrap(
      key: ValueKey('itemAccount-$i'),
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final a in _expenseAccounts) _accountChip(a, row, submitting),
      ],
    );
  }

  Widget _accountChip(Account a, _ItemRow row, bool submitting) {
    final selected = row.accountId == a.id;
    return ChoiceChip(
      key: ValueKey('itemAccountChip_${a.id}'),
      label: Text(a.name),
      selected: selected,
      selectedColor: context.yucai.accent.withValues(alpha: 0.15),
      backgroundColor: context.yucai.surface,
      side: BorderSide(
          color: selected ? context.yucai.accent : context.yucai.border, width: 1),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        color: selected ? context.yucai.accent : context.yucai.fg,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999)),
      onSelected: submitting
          ? null
          : (_) => setState(() {
                _markDirty(); // F59 FR-5:选分类 = 用户编辑
                row.accountId = selected ? null : a.id;
              }),
    );
  }

  Widget _addItemButton(bool submitting) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        key: const ValueKey('addItemButton'),
        onPressed: submitting ? null : _addItemRow,
        icon: const Icon(LucideIcons.plus, size: 16),
        label: const Text('添加条目'),
      ),
    );
  }

  Widget _bottomActions(bool submitting, bool canSubmit) {
    // 底部也放一组操作(对齐原型 action-row,与 topbar btn-gold 双入口)。
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          key: const ValueKey('budgetFormCancelBottom'),
          onPressed: submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        const SizedBox(width: AppSpacing.sm),
        _GoldButton(
          key: const ValueKey('budgetFormSubmitBottom'),
          icon: LucideIcons.check,
          label: _isEdit ? '保存修改' : '保存预算',
          onPressed: _submit,
          disabled: submitting || !canSubmit,
          loading: submitting,
        ),
      ],
    );
  }
}

// ───────────────────────── btn-gold(对齐原型 .btn-gold) ─────────────────────────

/// accent 背景按钮(对齐 OD 原型 .btn-gold;F27:前景迁 onAccent,暗=金底深墨)。
/// 本地 copy,与 budget_list_page._GoldButton 同款(提取共享 widget 留待后续,避免本次 form
/// 对齐 PR 扩散到 list/detail)。
class _GoldButton extends StatelessWidget {
  const _GoldButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.disabled = false,
    this.loading = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool disabled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    // F27 FR-1①:btn-gold 为 accent 面主按钮 —— spinner/icon/label/前景全部
    // onAccent(暗=金底深墨 #1A1408,亮=绿底白);disabled 档按 0.7 透明度派生。
    return ElevatedButton.icon(
      onPressed: disabled ? null : onPressed,
      icon: loading
          ? SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: context.yucai.onAccent))
          : Icon(icon, size: 16, color: context.yucai.onAccent),
      label: Text(label,
          key: ValueKey('goldBtnLabel_$label'),
          style: TextStyle(color: context.yucai.onAccent, fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: context.yucai.accent,
        foregroundColor: context.yucai.onAccent,
        disabledBackgroundColor: context.yucai.accent.withValues(alpha: 0.4),
        disabledForegroundColor:
            context.yucai.onAccent.withValues(alpha: 0.7),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.smBorder),
      ),
    );
  }
}
