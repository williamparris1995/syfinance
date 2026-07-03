// 目标表单页(创建 + 编辑)。消费 Task 11 GoalBloc + AccountRepository(账户
// picker)+ DebtRepository(债务 picker)。设计源:OD 原型
// design-output/goal/goal-form-*.html + budget BudgetFormPage 范式。
//
// type picker(savings/debtPayoff/investment)→ 动态关联字段:
//   · savings    → 选 1 savings/asset 账户(AccountType.asset,排除 investment 类别)
//   · investment → 选 1 investment 账户(AccountCategory.investment)
//   · debtPayoff → 选 1 债务(DebtRepository.list);目标额自动 = 剩余本金,只读
// 共通:name + target + deadline。
//
// **Phase 3 多选 picker**:选 N 账户 / N 债务,提交时 list = _linkedIds。
// GoalView 已多账户(Task 10 linkedAccountIds list)。
//
// - [goalId] == null:创建模式(dispatch CreateGoalRequested)。
// - [goalId] != null:编辑模式。dispatch LoadDetailRequested 拉现有 → 预填 →
//   提交 dispatch UpdateGoalRequested(增量字段更新,非 budget 的删旧+重建)。
//
// 无 i18n(中文硬编码,御财惯例;与 budget/holding/debt 表单页一致)。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/core/widgets/form_section.dart';
import 'package:yucai_client/debt/domain/entities/debt_entity.dart';
import 'package:yucai_client/debt/domain/repositories/debt_repository.dart';
import 'package:yucai_client/goal/domain/entities/goal_entity.dart';
import 'package:yucai_client/goal/domain/goal_template.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_bloc.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_event.dart';
import 'package:yucai_client/goal/presentation/bloc/goal_state.dart';

class GoalFormPage extends StatefulWidget {
  const GoalFormPage({
    super.key,
    this.goalId,
    this.initialDeadline,
  });

  /// 非 null = 编辑模式;null = 创建模式。
  final String? goalId;

  /// 创建模式默认 deadline(测试 seed 用,避免驱动 date picker)。默认当月起 +1 年。
  final DateTime? initialDeadline;

  @override
  State<GoalFormPage> createState() => _GoalFormPageState();
}

class _GoalFormPageState extends State<GoalFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();

  /// 当前选中的目标类型。null = 创建模式尚未选(编辑模式从 loaded goal 预填)。
  GoalType? _type;

  /// 多选关联 id Set。Investment/Savings 存 accountIds;DebtPayoff 存 debtIds。
  /// 提交时:list = _linkedIds.toList() (Phase 3 多选)。
  final Set<String> _linkedIds = {};

  /// deadline。默认当月起 +1 年(对齐 OD 原型 6-12 个月紧急备用金场景)。
  late DateTime _deadline;

  /// 全部账户(未过滤)—— 按 type 切换时客户端 filter。
  List<Account> _allAccounts = const [];
  List<Debt> _allDebts = const [];
  bool _pickersLoading = true;

  bool _submitted = false;

  /// 编辑模式加载到的现有目标(null = 创建 / 加载中)。
  GoalView? _existing;

  bool get _isEdit => widget.goalId != null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _deadline = widget.initialDeadline ?? DateTime(now.year + 1, now.month, now.day);
    _loadPickers();
    if (_isEdit) {
      _loadExisting();
    }
    _nameCtrl.addListener(() => setState(() {}));
    _targetCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPickers() async {
    // 对齐 budget_form_page._loadAccounts:GetIt<...>.list()。
    // 一次拉全量 accounts + debts,按 type 切换时客户端 filter(避免重复 IO)。
    try {
      final accountRepo = GetIt.instance<AccountRepository>();
      final debtRepo = GetIt.instance<DebtRepository>();
      final accountsResult = await accountRepo.list();
      final debtsResult = await debtRepo.list();
      if (!mounted) return;
      setState(() {
        _allAccounts = accountsResult.fold((_) => const <Account>[], (l) => l);
        _allDebts = debtsResult.fold((_) => const <Debt>[], (l) => l);
        _pickersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _pickersLoading = false);
    }
  }

  Future<void> _loadExisting() async {
    if (widget.goalId == null) return;
    if (!mounted) return;
    context.read<GoalBloc>().add(LoadDetailRequested(widget.goalId!));
  }

  void _onGoalStateChanged(BuildContext context, GoalState state) {
    // 编辑模式:加载完成 → 预填。
    if (state is GoalDetailLoaded && _existing == null && !_submitted) {
      final g = state.goal;
      _existing = g;
      _type = g.type;
      _nameCtrl.text = g.name;
      _targetCtrl.text = (g.targetAmountCents / 100).toStringAsFixed(2);
      _deadline = g.deadline ?? _deadline;
      // 多选预填:回填全 list(不只 first)。Phase 3 多选契约。
      if (g.type == GoalType.debtPayoff) {
        _linkedIds.addAll(g.linkedDebtIds);
      } else {
        _linkedIds.addAll(g.linkedAccountIds);
      }
      // DebtPayoff 目标额应 = 债务剩余本金合计(只读)。多债务场景下取合计;
      // 单债务时 = 该债务剩余本金(向后兼容 Phase 1 测试)。
      if (g.type == GoalType.debtPayoff && _linkedIds.isNotEmpty) {
        final selected = _allDebts.where((x) => _linkedIds.contains(x.id));
        if (selected.isNotEmpty) {
          final sum = selected.fold<int>(0, (a, d) => a + d.remainingPrincipalCents);
          _targetCtrl.text = (sum / 100).toStringAsFixed(2);
        }
      }
      setState(() {});
      return;
    }
    // 提交成功信号:
    //   - 创建:_onCreate 成功后 add(LoadListRequested) → GoalListLoaded。
    //   - 更新:_onUpdate 成功后 emit(GoalDetailLoaded(goal))。
    //   两种路径都 pop(true)。_submitted guard 防止编辑模式加载阶段的
    //   GoalDetailLoaded(上面那个分支)误触发 pop。
    if (_submitted &&
        (state is GoalListLoaded || state is GoalDetailLoaded)) {
      _submitted = false;
      Navigator.of(context).pop(true);
    }
  }

  // ───────────────────────── 模板预填 ─────────────────────────

  /// 模板 tap → 预填 type/name/target/deadline(关联账户/债务仍手选)。
  /// deadline = 今天 + deadlineMonths(月对齐;clamp 到月末避免溢出,例如 1/31 +1 月 → 2/28)。
  void _applyTemplate(GoalTemplate t) {
    final now = DateTime.now();
    // 月对齐:day 先 clamp,避免月底溢出(DateTime 构造溢出会抛异常)。
    final targetMonth = now.month + t.deadlineMonths;
    final year = now.year + (targetMonth - 1) ~/ 12;
    final month = ((targetMonth - 1) % 12) + 1;
    // 当月最大天数 clamp(处理 31 号 + N 月 落在 30/28 月的情况)。
    final maxDay = DateTime(year, month + 1, 0).day;
    final day = now.day > maxDay ? maxDay : now.day;
    setState(() {
      _type = t.goalType;
      _linkedIds.clear(); // 切 type 清关联(对齐 _selectType 行为)。
      _nameCtrl.text = t.name;
      _targetCtrl.text = (t.targetAmountCents / 100).toStringAsFixed(2);
      _deadline = DateTime(year, month, day);
    });
  }

  // ───────────────────────── type 切换 ─────────────────────────

  void _selectType(GoalType t) {
    setState(() {
      _type = t;
      // 切 type → 清空关联 + 重置 target(DebtPayoff 的 target 由债务选择驱动)。
      _linkedIds.clear();
      if (t == GoalType.debtPayoff) {
        _targetCtrl.clear();
      }
    });
  }

  /// Investment 筛选:AccountCategory.investment(用户面向「投资」类别)。
  /// 注:AccountType 仅 5 类会计(asset/liability/...),投资账户的会计类型是
  /// asset,需用 AccountCategory 区分投资 vs 其他资产(储蓄/定期/黄金/房产)。
  bool _isInvestmentAccount(Account a) => a.category == AccountCategory.investment;

  /// Savings 筛选:资产类账户(asset),排除 investment(避免与 investment type
  /// 重叠)。包含储蓄/定期/黄金/房产等可作储蓄 backing 的资产。
  bool _isSavingsAccount(Account a) =>
      a.accountType == AccountType.asset && a.category != AccountCategory.investment;

  List<Account> get _filteredAccounts {
    if (_type == GoalType.investment) {
      return _allAccounts.where(_isInvestmentAccount).toList();
    }
    if (_type == GoalType.savings) {
      return _allAccounts.where(_isSavingsAccount).toList();
    }
    return const [];
  }

  // ───────────────────────── 校验 / 提交 ─────────────────────────

  bool get _canSubmit {
    if (_nameCtrl.text.trim().isEmpty) return false;
    final amt = double.tryParse(_targetCtrl.text);
    if (amt == null || amt <= 0) return false;
    if (_linkedIds.isEmpty) return false;
    return true;
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
      lastDate: DateTime(2100),
      helpText: '选择截止日期',
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  void _submit() {
    if (!_canSubmit) {
      if (_nameCtrl.text.trim().isEmpty) {
        AppToast.show(context, '请填写目标名称', type: ToastType.warning);
      } else if (double.tryParse(_targetCtrl.text) == null ||
          (double.tryParse(_targetCtrl.text) ?? 0) <= 0) {
        AppToast.show(context, '目标金额需大于 0', type: ToastType.warning);
      } else if (_linkedIds.isEmpty) {
        AppToast.show(
          context,
          _type == GoalType.debtPayoff ? '请选择关联债务' : '请选择关联账户',
          type: ToastType.warning,
        );
      }
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState?.save();
    _submitted = true;

    final bloc = context.read<GoalBloc>();
    final targetCents = ((double.tryParse(_targetCtrl.text) ?? 0) * 100).round();
    final deadlineIso =
        '${_deadline.year}-${_deadline.month.toString().padLeft(2, '0')}-${_deadline.day.toString().padLeft(2, '0')}';
    // Phase 3 多选:list = _linkedIds。account(debtPayoff 时空)/ debt(其他时空)。
    final accountIds = _type == GoalType.debtPayoff
        ? <String>[]
        : _linkedIds.toList();
    final debtIds = _type == GoalType.debtPayoff ? _linkedIds.toList() : <String>[];

    if (_isEdit) {
      bloc.add(UpdateGoalRequested(
        id: widget.goalId!,
        name: _nameCtrl.text.trim(),
        target: targetCents,
        deadline: deadlineIso,
        linkedAccountIds: accountIds,
        linkedDebtIds: debtIds,
      ));
    } else {
      bloc.add(CreateGoalRequested(
        name: _nameCtrl.text.trim(),
        type: _type!,
        target: targetCents,
        deadline: deadlineIso,
        linkedAccountIds: accountIds,
        linkedDebtIds: debtIds,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: Text(_isEdit ? '编辑目标' : '新建目标'),
      ),
      body: BlocConsumer<GoalBloc, GoalState>(
        listenWhen: (prev, curr) =>
            curr is GoalDetailLoaded || curr is GoalListLoaded,
        listener: _onGoalStateChanged,
        builder: (context, state) {
          final submitting = state is GoalLoading;
          // 编辑模式未加载完 → loading。
          if (_isEdit && _existing == null) {
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
                        // 创建模式 + type 未选 → 显模板快捷区(对齐 spec §11 ④)。
                        if (!_isEdit && _type == null) ...[
                          _templateSection(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        FormSection(
                          title: '1 · 选择类型',
                          children: [_typePicker(submitting)],
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        // 动态字段区:type 未选 → 占位提示。
                        FormSection(
                          title: '2 · 填写详情',
                          children: _type == null
                              ? [_placeholder('请先选择目标类型')]
                              : _detailFields(submitting),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        // 对齐 OD 原型 .btn-gold:金色提交 + 取消 ghost。
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: submitting
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              child: const Text('取消'),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            ElevatedButton.icon(
                              key: const ValueKey('goalFormSubmit'),
                              onPressed: submitting ? null : _submit,
                              icon: submitting
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white))
                                  : const Icon(LucideIcons.check,
                                      size: 16, color: Colors.white),
                              label: Text(
                                _isEdit ? '保存修改' : '确认创建',
                                key: ValueKey(
                                    'goalFormSubmitLabel_${_isEdit ? 'edit' : 'create'}'),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: const RoundedRectangleBorder(
                                    borderRadius: AppRadius.smBorder),
                              ),
                            ),
                          ],
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

  // ───────────────────────── type picker ─────────────────────────

  Widget _typePicker(bool submitting) {
    // 对齐 OD 原型 .type-picker:3 卡片(savings 金 piggyBank / debtPayoff 红
    // creditCard / investment 绿 trendingUp)+ 大图标方块 + 名称 + 描述。
    // Phase 1 简化为单选卡(无 step 跳转)。
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        for (final t in GoalType.values) _typeOption(t, submitting),
      ],
    );
  }

  // ───────────────────────── 模板区 ─────────────────────────

  Widget _templateSection() {
    return FormSection(
      title: '从模板开始',
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: AppSpacing.sm),
          child: Text(
            '选择常用目标模板,快速预填(关联账户/债务仍需手选)',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final t in kGoalTemplates) _templateChip(t),
          ],
        ),
      ],
    );
  }

  /// 模板 chip:御财金边框 + lucide icon + name + description。
  Widget _templateChip(GoalTemplate t) {
    return InkWell(
      key: ValueKey('goalTemplate_${t.name}'),
      onTap: () => _applyTemplate(t),
      borderRadius: AppRadius.smBorder,
      child: Container(
        width: 230,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.accentSoft.withValues(alpha: 0.5),
          borderRadius: AppRadius.smBorder,
          border: Border.all(color: AppColors.accent, width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: AppRadius.smBorder,
              ),
              child: Icon(t.icon, size: 18, color: AppColors.accent),
            ),
            const SizedBox(width: AppSpacing.xs + 2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          fontFamily: AppTypography.displayFamily,
                          fontFamilyFallback: AppTypography.displayFallback,
                          color: AppColors.fg)),
                  const SizedBox(height: 2),
                  Text(t.description,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeOption(GoalType t, bool submitting) {
    final meta = _typeMeta(t);
    final selected = _type == t;
    return InkWell(
      key: ValueKey('typeOption_${meta.key}'),
      onTap: (submitting || _isEdit) ? null : () => _selectType(t),
      borderRadius: AppRadius.lgBorder,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: selected ? meta.color.withValues(alpha: 0.08) : AppColors.surface,
          borderRadius: AppRadius.lgBorder,
          border: Border.all(
            color: selected ? meta.color : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 大图标方块(对齐原型 .to-icon 带色底)。
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: meta.color.withValues(alpha: 0.12),
                borderRadius: AppRadius.smBorder,
              ),
              child: Icon(meta.icon, size: 22, color: meta.color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(meta.label,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: AppTypography.displayFamily,
                    fontFamilyFallback: AppTypography.displayFallback,
                    color: selected ? meta.color : AppColors.fg)),
            const SizedBox(height: 4),
            Text(meta.desc,
                style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── 动态详情字段 ─────────────────────────

  List<Widget> _detailFields(bool submitting) {
    final fields = <Widget>[
      TextFormField(
        key: const ValueKey('nameField'),
        controller: _nameCtrl,
        decoration: const InputDecoration(
          labelText: '目标名称',
          hintText: '如 紧急备用金',
        ),
        validator: (v) => (v == null || v.trim().isEmpty) ? '请输入目标名称' : null,
      ),
    ];

    // 关联 picker(动态):account(investment/savings)或 debt(debtPayoff)。
    if (_type == GoalType.debtPayoff) {
      fields.add(_debtPicker(submitting));
      // 目标额只读(= 债务剩余本金),对齐 OD 原型。
      fields.add(TextFormField(
        key: const ValueKey('targetField'),
        controller: _targetCtrl,
        readOnly: true,
        decoration: const InputDecoration(
          labelText: '目标金额',
          prefixText: '¥ ',
          hintText: '选择债务后自动填充',
          helperText: '债务清偿目标 = 剩余本金,不可改',
        ),
      ));
    } else {
      // Investment / Savings:目标额可编辑 + account picker。
      fields.add(TextFormField(
        key: const ValueKey('targetField'),
        controller: _targetCtrl,
        decoration: InputDecoration(
          labelText: '目标金额',
          prefixText: '¥ ',
          hintText: _type == GoalType.investment ? '200000' : '60000',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (v) {
          final amt = double.tryParse(v ?? '');
          if (amt == null || amt <= 0) return '目标金额需大于 0';
          return null;
        },
      ));
      fields.add(_accountPicker(submitting));
    }

    fields.add(
      InkWell(
        key: const ValueKey('deadlinePicker'),
        onTap: submitting ? null : _pickDeadline,
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: '截止日期',
            suffixIcon: Icon(LucideIcons.calendar, size: 18),
          ),
          child: Text(
            '${_deadline.year}-${_deadline.month.toString().padLeft(2, '0')}-${_deadline.day.toString().padLeft(2, '0')}',
            style: const TextStyle(color: AppColors.fg),
          ),
        ),
      ),
    );

    return fields;
  }

  Widget _accountPicker(bool submitting) {
    // Phase 3 多选:CheckboxListTile(对齐 brief Step 2)。tap → toggle _linkedIds。
    final accounts = _filteredAccounts;
    return InputDecorator(
      key: const ValueKey('accountPicker'),
      decoration: InputDecoration(
        labelText: _type == GoalType.investment ? '关联投资账户' : '关联储蓄账户',
        hintText: _pickersLoading
            ? '加载中…'
            : accounts.isEmpty
                ? '无可用账户'
                : '选择账户(可多选)',
      ),
      child: Column(
        children: [
          for (final a in accounts)
            CheckboxListTile(
              key: ValueKey('accountOption_${a.id}'),
              value: _linkedIds.contains(a.id),
              onChanged: submitting
                  ? null
                  : (v) => setState(() =>
                      v! ? _linkedIds.add(a.id) : _linkedIds.remove(a.id)),
              title: Text(a.name),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
    );
  }

  Widget _debtPicker(bool submitting) {
    // Phase 3 多选:CheckboxListTile。选债务 → target = 剩余本金合计(只读)。
    void toggleDebt(String id, bool add) {
      setState(() {
        if (add) {
          _linkedIds.add(id);
        } else {
          _linkedIds.remove(id);
        }
        // 自动填 target = 已选债务剩余本金合计(只读,对齐 OD 原型)。
        if (_linkedIds.isEmpty) {
          _targetCtrl.clear();
        } else {
          final sum = _allDebts
              .where((x) => _linkedIds.contains(x.id))
              .fold<int>(0, (a, d) => a + d.remainingPrincipalCents);
          _targetCtrl.text = (sum / 100).toStringAsFixed(2);
        }
      });
    }

    return InputDecorator(
      key: const ValueKey('debtPicker'),
      decoration: InputDecoration(
        labelText: '关联债务',
        hintText: _pickersLoading
            ? '加载中…'
            : _allDebts.isEmpty
                ? '无可用债务'
                : '选择债务(可多选)',
      ),
      child: Column(
        children: [
          for (final d in _allDebts)
            CheckboxListTile(
              key: ValueKey('debtOption_${d.id}'),
              value: _linkedIds.contains(d.id),
              onChanged: submitting ? null : (v) => toggleDebt(d.id, v!),
              title: Text(d.counterparty),
              dense: true,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
        ],
      ),
    );
  }

  // ───────────────────────── helpers ─────────────────────────

  Widget _placeholder(String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
      );
}

// ───────────────────────── 类型元数据 ─────────────────────────

class _TypeMeta {
  const _TypeMeta({
    required this.key,
    required this.label,
    required this.desc,
    required this.icon,
    required this.color,
  });
  final String key;
  final String label;
  final String desc;
  final IconData icon;
  final Color color;
}

/// 类型 → 元数据。对齐 OD 原型 mock-data.js GOAL_TYPES + goal_list_page._typeMeta:
/// savings(金)/ debtPayoff(红)/ investment(绿)。
_TypeMeta _typeMeta(GoalType type) {
  switch (type) {
    case GoalType.savings:
      return const _TypeMeta(
        key: 'savings',
        label: '储蓄目标',
        desc: '为购房、教育、备用金等攒钱',
        icon: LucideIcons.piggyBank,
        color: AppColors.accent,
      );
    case GoalType.debtPayoff:
      return const _TypeMeta(
        key: 'debtPayoff',
        label: '债务清偿',
        desc: '清偿贷款、信用卡等负债',
        icon: LucideIcons.creditCard,
        color: AppColors.negative,
      );
    case GoalType.investment:
      return const _TypeMeta(
        key: 'investment',
        label: '投资目标',
        desc: '为投资组合设定市值目标',
        icon: LucideIcons.trendingUp,
        color: AppColors.positive,
      );
  }
}
