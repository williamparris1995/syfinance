// 交易 Sheet(统一 buy/sell/dividend/split form)。消费 Task 4 HoldingBloc。
//
// 对齐 A-od 设计源:trade-sheet-mobile.html(4 类型 segmented + from-account picker
// + 实时金额 + 余额 fail-fast 预览)。实现采用「统一单页 form」(非 5 步 wizard),
// 4 类型字段随 [TradeType] 切换显隐 —— 与 HTML 原型字段集合一致,布局更扁平。
//
// ⚠️ proto 对齐(以 proto 为准,plan 原文「dividend 用 income-account picker」是错的):
//   - buy/sell:accountId(持仓账户)/ securityId / **fromAccountId**(资金源,
//     buy:credit 现金- / sell:debit 现金+,双写必填)/ quantity / priceCents /
//     feeCents / tradeDate / notes → **只有 buy/sell 用 from-account picker**
//   - dividend:accountId / securityId / quantity / cashPerShareCents /
//     totalAmountCents / tradeDate / notes → **无 income/from-account picker**
//     (proto RecordDividendRequest 无 income_account_id)
//   - split:accountId / securityId / **ratio**(单一 double,非 from/to)/
//     splitDate / notes → **单一 ratio**
//
// from-account picker 照搬御财 receivable_form_page._loadSourceAccounts:
//   - 候选 = asset 且 category != otherAsset(流动资产:储蓄/投资/黄金/定投等,
//     排除应收/收藏品等其他资产)。
//   - 跨币种(security.currency != account.currencyCode)→ disabled(客户端
//     预校验防线,与 A-server 双写资金源币种一致性约束对齐)。
//   - 余额 fail-fast:buy 时 from 账户 currentBalanceCents 不足 → 红字提示
//     (参照 receivable_form 提交校验 + A-od m-mini-bal.fail 态)。
//
// 提交 → bloc.add(BuyRequested / SellRequested / RecordDividendRequested /
// RecordSplitRequested(params)),Params 对齐 proto(Buy/SellParams 含 fromAccountId;
// DividendParams 无 incomeAccountId;SplitParams.ratio)。
//
// AbsorbPointer(submitting) + spinner(HoldingSubmitting state)。无 i18n(中文硬编码,
// 御财惯例)。
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:yucai_client/account/domain/entities/account_entity.dart';
import 'package:yucai_client/account/domain/repositories/account_repository.dart';
import 'package:yucai_client/account/domain/value_objects.dart';
import 'package:yucai_client/core/theme/app_design.dart';
import 'package:yucai_client/core/widgets/app_toast.dart';
import 'package:yucai_client/currency/domain/currency_convert.dart';
import 'package:yucai_client/holding/domain/entities/holding_entity.dart';
import 'package:yucai_client/holding/domain/value_objects.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_bloc.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_event.dart';
import 'package:yucai_client/holding/presentation/bloc/holding_state.dart';
import 'package:yucai_client/holding/presentation/widgets/holding_pie_chart.dart';

// OD 类型色(design-output/holding/styles.css:524-527)。
// buy=金 / sell=红 / dividend=绿 / split=蓝灰;soft 为各色浅背景。
//
// F4-P2:三色走 context.yucai 语义令牌(暗色跟随);split 蓝灰 = holding
// 债券(bond)灰蓝同值 —— 复用 [holdingTypeColorOf] 类型序列色(暗板自动
// 提亮一档,原局部常量 #6B7A8F 的亮板值保留在 kHoldingTypeColors.bond 槽),
// 顶层函数无 context → 补形参穿线(调用点全量更新)。

/// 类型主色:seg selected 底色 + 金额数字色(对齐 OD amt-row.t-{type})。
Color _tradeTypeColor(BuildContext context, TradeType t) {
  switch (t) {
    case TradeType.buy:
      return context.yucai.accent; // 金(暗色=鎏金)
    case TradeType.sell:
      return context.yucai.negative; // 红
    case TradeType.dividend:
      return context.yucai.positive; // 绿
    case TradeType.split:
      return holdingTypeColorOf(context, SecurityType.bond); // 蓝灰(复用序列色)
  }
}

/// 类型浅背景色:容器 soft 底色(对齐 OD *-soft)。
Color _tradeTypeSoft(BuildContext context, TradeType t) {
  switch (t) {
    case TradeType.buy:
      return context.yucai.accentSoft;
    case TradeType.sell:
      return context.yucai.negative.withValues(alpha: 0.10);
    case TradeType.dividend:
      return context.yucai.positive.withValues(alpha: 0.10);
    case TradeType.split:
      // 原 #E7EAEF 亮板近白软底 → 主色 10% 派生,暗色下呈微亮底不刺眼。
      return holdingTypeColorOf(context, SecurityType.bond)
          .withValues(alpha: 0.10);
  }
}

/// 交易 Sheet(统一 buy/sell/dividend/split form)。
///
/// 4 类型 segmented(字段随 [TradeType] 切换)。security 选择从 HoldingBloc
/// 加载(LoadSecuritiesRequested → HoldingLoaded.securities);持仓账户
/// [TradeSheetPage.initialAccountId] 与 from-account picker 从 AccountRepository
/// 加载(参照 receivable_form `_loadSourceAccounts`)。
///
/// [initialType] / [initialSecurityId] / [initialAccountId] 供测试 seed 表单
/// 状态,避免在 widget test 里驱动 dropdown 交互。
class TradeSheetPage extends StatefulWidget {
  const TradeSheetPage({
    super.key,
    this.initialType = TradeType.buy,
    this.initialSecurityId,
    this.initialAccountId,
    this.initialFromAccountId,
  });

  final TradeType initialType;
  final String? initialSecurityId;
  final String? initialAccountId;
  /// 测试 seed:buy/sell 资金来源账户(仅创建模式,避免 dropdown 交互)。
  final String? initialFromAccountId;

  @override
  State<TradeSheetPage> createState() => _TradeSheetPageState();
}

class _TradeSheetPageState extends State<TradeSheetPage> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _perShareCtrl = TextEditingController();
  final _ratioCtrl = TextEditingController(text: '2');
  final _notesCtrl = TextEditingController();

  late TradeType _type;
  String? _securityId;
  String? _accountId;
  String? _fromAccountId;
  DateTime _date = DateTime.now();

  /// 资金源账户候选(asset 非 otherAsset,照搬 receivable_form._loadSourceAccounts)。
  List<Account> _sourceAccounts = const [];
  bool _accountsLoading = true;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // seed 初始状态(从 widget 参数,测试用;initializer 不能访问 widget)。
    _type = widget.initialType;
    _securityId = widget.initialSecurityId;
    _accountId = widget.initialAccountId;
    _fromAccountId = widget.initialFromAccountId;
    // 拉取证券主数据(表单选择器用);持仓账户/资金源账户从 AccountRepository 加载。
    context.read<HoldingBloc>().add(const LoadSecuritiesRequested());
    _loadSourceAccounts();
    _qtyCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
    _feeCtrl.addListener(() => setState(() {}));
    _perShareCtrl.addListener(() => setState(() {}));
    _ratioCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _priceCtrl.dispose();
    _feeCtrl.dispose();
    _perShareCtrl.dispose();
    _ratioCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// 资金源账户 = 流动资产(asset 且 category != otherAsset),照搬
  /// receivable_form._loadSourceAccounts。排除应收/收藏品等其他资产 ——
  /// 它们不应作为 buy/sell 的资金来源。
  Future<void> _loadSourceAccounts() async {
    try {
      final repo = GetIt.instance<AccountRepository>();
      final result = await repo.list();
      final list = result.fold((_) => const <Account>[], (l) => l);
      if (!mounted) return;
      setState(() {
        _sourceAccounts = list
            .where((a) =>
                a.accountType == AccountType.asset &&
                a.category != AccountCategory.otherAsset)
            .toList();
        _accountsLoading = false;
      });
    } catch (_) {
      // 加载失败静默(_sourceAccounts 保持空,提交时校验会拦截)。
      if (!mounted) return;
      setState(() => _accountsLoading = false);
    }
  }

  /// 从 HoldingBloc state 取 securities(从 last 恢复背景)。
  List<Security> _securitiesOf(HoldingState state) {
    HoldingState? probe = state;
    while (true) {
      if (probe is HoldingLoaded) return probe.securities;
      if (probe is HoldingError) {
        probe = probe.last;
      } else if (probe is HoldingSubmitting) {
        probe = probe.last;
      } else {
        return const [];
      }
      if (probe == null) return const [];
    }
  }

  Security? get _selectedSecurity {
    final sec = _securityId;
    if (sec == null) return null;
    final list = _securitiesOf(context.read<HoldingBloc>().state);
    for (final s in list) {
      if (s.id == sec) return s;
    }
    return null;
  }

  /// 证券币种(缺省 CNY)。
  String get _securityCurrency => _selectedSecurity?.currency ?? 'CNY';

  /// 货币符号(对齐 A-od $/¥ 切换)。
  String get _curSym => currencySymbol(_securityCurrency);

  // ===================== 实时金额 / 余额 fail-fast 预览 =====================

  /// buy 金额(含费用)= qty*price + fee;sell 净额(扣费用)= qty*price - fee。
  /// 对齐 A-od recalc():amt = type==='buy' ? (qty*price+fee) : (qty*price-fee)。
  double get _tradeAmount {
    if (_type != TradeType.buy && _type != TradeType.sell) return 0;
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final fee = double.tryParse(_feeCtrl.text) ?? 0;
    return _type == TradeType.buy
        ? qty * price + fee
        : qty * price - fee;
  }

  /// dividend 总额 = perShare * qty。
  double get _dividendAmount {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final per = double.tryParse(_perShareCtrl.text) ?? 0;
    return per * qty;
  }

  /// from 账户余额(buy 余额 fail-fast 用)。
  int get _fromBalanceCents {
    final id = _fromAccountId;
    if (id == null) return 0;
    for (final a in _sourceAccounts) {
      if (a.id == id) return a.currentBalanceCents;
    }
    return 0;
  }

  /// buy 余额不足 fail-fast。
  bool get _balanceInsufficient {
    if (_type != TradeType.buy) return false;
    final amtCents = (_tradeAmount * 100).round();
    return amtCents > _fromBalanceCents;
  }

  // ===================== 提交 =====================

  void _submit() {
    // 显式校验必要字段(对齐 receivable_form._submit toast 模式)。
    if (_securityId == null) {
      AppToast.show(context, '请选择证券', type: ToastType.warning);
      return;
    }
    if (_accountId == null) {
      AppToast.show(context, '请选择持仓账户', type: ToastType.warning);
      return;
    }
    final dateStr = _isoDate(_date);

    switch (_type) {
      case TradeType.buy:
      case TradeType.sell:
        if (_fromAccountId == null) {
          AppToast.show(context, '请选择资金账户', type: ToastType.warning);
          return;
        }
        final qty = double.tryParse(_qtyCtrl.text) ?? 0;
        if (_qtyCtrl.text.isEmpty || qty <= 0) {
          AppToast.show(context, '请输入数量', type: ToastType.warning);
          return;
        }
        final price = double.tryParse(_priceCtrl.text) ?? -1;
        if (_priceCtrl.text.isEmpty || price < 0) {
          AppToast.show(context, '请输入价格', type: ToastType.warning);
          return;
        }
        final fee = double.tryParse(_feeCtrl.text) ?? 0;
        if (_balanceInsufficient) {
          AppToast.show(context, '资金账户余额不足', type: ToastType.warning);
          return;
        }
        final priceCents = (price * 100).round();
        final feeCents = (fee * 100).round();
        if (_type == TradeType.buy) {
          context.read<HoldingBloc>().add(BuyRequested(BuyParams(
                accountId: _accountId!,
                securityId: _securityId!,
                fromAccountId: _fromAccountId!,
                quantity: qty,
                priceCents: priceCents,
                feeCents: feeCents,
                tradeDate: dateStr,
                notes: _notesCtrl.text.trim().isEmpty
                    ? null
                    : _notesCtrl.text.trim(),
              )));
        } else {
          context.read<HoldingBloc>().add(SellRequested(SellParams(
                accountId: _accountId!,
                securityId: _securityId!,
                fromAccountId: _fromAccountId!,
                quantity: qty,
                priceCents: priceCents,
                feeCents: feeCents,
                tradeDate: dateStr,
                notes: _notesCtrl.text.trim().isEmpty
                    ? null
                    : _notesCtrl.text.trim(),
              )));
        }
        break;
      case TradeType.dividend:
        final qty = double.tryParse(_qtyCtrl.text) ?? 0;
        if (_qtyCtrl.text.isEmpty || qty <= 0) {
          AppToast.show(context, '请输入数量', type: ToastType.warning);
          return;
        }
        final per = double.tryParse(_perShareCtrl.text) ?? -1;
        if (_perShareCtrl.text.isEmpty || per < 0) {
          AppToast.show(context, '请输入每股股息', type: ToastType.warning);
          return;
        }
        final perCents = (per * 100).round();
        final totalCents = (_dividendAmount * 100).round();
        context.read<HoldingBloc>().add(RecordDividendRequested(DividendParams(
              accountId: _accountId!,
              securityId: _securityId!,
              quantity: qty,
              cashPerShareCents: perCents,
              totalAmountCents: totalCents,
              tradeDate: dateStr,
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            )));
        break;
      case TradeType.split:
        final ratio = double.tryParse(_ratioCtrl.text) ?? 0;
        if (_ratioCtrl.text.isEmpty || ratio <= 0) {
          AppToast.show(context, '请输入拆分比例', type: ToastType.warning);
          return;
        }
        context.read<HoldingBloc>().add(RecordSplitRequested(SplitParams(
              accountId: _accountId!,
              securityId: _securityId!,
              ratio: ratio,
              splitDate: dateStr,
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            )));
        break;
    }
    _submitted = true;
  }

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ===================== build =====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.yucai.bg,
      appBar: AppBar(
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
        title: const Text('记录交易'),
      ),
      body: BlocListener<HoldingBloc, HoldingState>(
        // 业务事件成功后 bloc 自刷新 → HoldingLoaded。F14 #4 修正:成功链实际
        // 是 Submitting → Loading(自刷新 _onLoadHoldings 先发 Loading)→
        // Loaded,旧的 `prev is HoldingSubmitting` 条件永远不成立 → 提交成功
        // 从不自动 pop(用户只能手动返回)。放宽为「提交后见 Loaded 即 pop」。
        listenWhen: (prev, curr) {
          // fail-closed 补齐(F14 review fix-round-1):提交失败(HoldingError)
          // 即复位 _submitted —— 否则失败后用户未重提,后续任何路径(价格刷新/
          // 列表回拉等)发出的 HoldingLoaded 会被「见 Loaded 即 pop」误判成
          // 提交成功,sheet 意外关闭丢表单。
          if (curr is HoldingError) {
            _submitted = false;
            return false;
          }
          return _submitted && curr is HoldingLoaded;
        },
        listener: (context, state) {
          _submitted = false;
          Navigator.of(context).pop(true);
        },
        child: BlocBuilder<HoldingBloc, HoldingState>(
          builder: (context, state) {
            final submitting = state is HoldingSubmitting;
            final securities = _securitiesOf(state);
            return AbsorbPointer(
              absorbing: submitting,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TypeSegmented(
                            current: _type,
                            onSelect: (t) => setState(() {
                              _type = t;
                              // 切类型清掉跨类型无关字段,避免脏值提交。
                              _fromAccountId = null;
                            }),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _securityField(securities),
                          const SizedBox(height: AppSpacing.md),
                          _accountField(),
                          // buy/sell 才有 from-account picker(dividend/split 无)。
                          if (_type == TradeType.buy ||
                              _type == TradeType.sell) ...[
                            const SizedBox(height: AppSpacing.md),
                            _fromAccountField(),
                          ],
                          const SizedBox(height: AppSpacing.md),
                          ..._typeSpecificFields(),
                          const SizedBox(height: AppSpacing.md),
                          _dateField(),
                          const SizedBox(height: AppSpacing.md),
                          _notesField(),
                          const SizedBox(height: AppSpacing.lg),
                          _livePreview(),
                          const SizedBox(height: AppSpacing.lg),
                          _submitButton(submitting),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ───────────────────────── 字段 ─────────────────────────

  Widget _securityField(List<Security> securities) {
    return DropdownButtonFormField<String>(
      key: const ValueKey('securityDropdown'),
      decoration: const InputDecoration(labelText: '选择证券'),
      value: _securityId,
      items: [
        for (final s in securities)
          DropdownMenuItem(
            value: s.id,
            child: Text('${s.symbol} · ${s.name}'),
          ),
      ],
      hint: Text(securities.isEmpty ? '加载中…' : '选择证券'),
      onChanged: (v) => setState(() => _securityId = v),
      validator: (v) => v == null || v.isEmpty ? '请选择证券' : null,
    );
  }

  /// 持仓账户选择(accountId,从 _sourceAccounts 复用候选 —— 投资账户属 asset)。
  Widget _accountField() {
    return DropdownButtonFormField<String>(
      key: const ValueKey('accountDropdown'),
      decoration: const InputDecoration(labelText: '持仓账户'),
      value: _accountId,
      items: [
        for (final a in _sourceAccounts)
          DropdownMenuItem(value: a.id, child: Text(a.name)),
      ],
      hint: Text(_accountsLoading ? '加载中…' : '选择持仓账户'),
      onChanged: (v) => setState(() => _accountId = v),
      validator: (v) => v == null || v.isEmpty ? '请选择持仓账户' : null,
    );
  }

  /// 资金账户(buy/sell fromAccountId)。照搬 receivable_form 模式:
  /// 候选 = asset 非 otherAsset;跨币种(security vs account)→ disabled 项。
  /// 余额 fail-fast 由 [_livePreview] 红字提示 + 提交校验拦截。
  Widget _fromAccountField() {
    final secCur = _securityCurrency;
    return DropdownButtonFormField<String>(
      key: const ValueKey('fromAccountDropdown'),
      decoration: const InputDecoration(
        labelText: '资金账户',
        helperText: '币种一致 · 跨币种 disabled',
      ),
      value: _fromAccountId,
      items: [
        for (final a in _sourceAccounts)
          DropdownMenuItem(
            value: a.id,
            enabled: a.currencyCode == secCur, // 跨币种 disabled(客户端预校验防线)
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  a.name,
                  style: TextStyle(
                    color: a.currencyCode == secCur
                        ? context.yucai.fg
                        : context.yucai.muted,
                  ),
                ),
                if (a.currencyCode != secCur)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Text('${a.currencyCode}(跨币种)',
                        style:
                            TextStyle(fontSize: 10, color: context.yucai.muted)),
                  ),
              ],
            ),
          ),
      ],
      hint: Text(_accountsLoading ? '加载中…' : '选择资金账户'),
      onChanged: (v) => setState(() => _fromAccountId = v),
      validator: (v) => v == null || v.isEmpty ? '请选择资金账户' : null,
    );
  }

  /// 类型相关字段:buy/sell = qty/price/fee;dividend = qty/perShare;split = ratio。
  List<Widget> _typeSpecificFields() {
    switch (_type) {
      case TradeType.buy:
      case TradeType.sell:
        return [
          TextFormField(
            key: const ValueKey('qtyField'),
            controller: _qtyCtrl,
            decoration: const InputDecoration(
              labelText: '数量',
              suffixText: '股',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '请输入数量' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey('priceField'),
            controller: _priceCtrl,
            decoration: InputDecoration(
              labelText: '价格',
              prefixText: '$_curSym ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '请输入价格' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey('feeField'),
            controller: _feeCtrl,
            decoration: InputDecoration(
              labelText: '交易费用',
              prefixText: '$_curSym ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ];
      case TradeType.dividend:
        return [
          TextFormField(
            key: const ValueKey('qtyField'),
            controller: _qtyCtrl,
            decoration: const InputDecoration(
              labelText: '数量',
              suffixText: '股',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '请输入数量' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            key: const ValueKey('perShareField'),
            controller: _perShareCtrl,
            decoration: InputDecoration(
              labelText: '每股股息',
              prefixText: '$_curSym ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '请输入每股股息' : null,
          ),
        ];
      case TradeType.split:
        return [
          TextFormField(
            key: const ValueKey('ratioField'),
            controller: _ratioCtrl,
            decoration: const InputDecoration(
              labelText: '拆分比例',
              helperText: '例如：2 = 1 股拆为 2 股;0.5 = 2 股合为 1 股', // F31:按 F28 规范统一「例如：」
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? '请输入拆分比例' : null,
          ),
        ];
    }
  }

  Widget _dateField() {
    return InputDecorator(
      key: const ValueKey('dateField'),
      decoration: const InputDecoration(
        labelText: '交易日期',
        suffixIcon: Icon(LucideIcons.calendar, size: 18),
      ),
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _date,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (picked != null) setState(() => _date = picked);
        },
        child: Text(
          _isoDate(_date),
          style: TextStyle(color: context.yucai.fg),
        ),
      ),
    );
  }

  Widget _notesField() {
    return TextFormField(
      key: const ValueKey('notesField'),
      controller: _notesCtrl,
      decoration: const InputDecoration(labelText: '备注'),
      maxLines: 2,
    );
  }

  // ───────────────────────── 实时预览 ─────────────────────────

  /// 实时金额 + 余额 fail-fast 预览(对齐 A-od m-mini-preview)。
  Widget _livePreview() {
    if (_type == TradeType.split) {
      // split 无现金流,仅提示。
      return Container(
        key: const ValueKey('splitPreview'),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: _tradeTypeSoft(context, TradeType.split),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.info, size: 16,
                color: holdingTypeColorOf(context, SecurityType.bond)),
            SizedBox(width: 8),
            Expanded(
              child: Text('无现金流 · 仅调整持有量与成本',
                  style: TextStyle(fontSize: 12, color: context.yucai.muted)),
            ),
          ],
        ),
      );
    }

    final amt = _type == TradeType.dividend ? _dividendAmount : _tradeAmount;
    final amtLabel = _type == TradeType.buy
        ? '买入金额(含费用)'
        : _type == TradeType.sell
            ? '卖出净额(扣费用)'
            : '分红总额';
    // amtColor:类型色(对齐 OD amt-row.t-{type},资金流向语义让位类型色)。
    final amtColor = _tradeTypeColor(context, _type);

    return Container(
      key: const ValueKey('livePreview'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.yucai.surface,
        border: Border.all(color: context.yucai.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(amtLabel,
                  style:
                      TextStyle(fontSize: 12, color: context.yucai.muted)),
              Text(
                _fmtAmt(amt),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: amtColor,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ],
          ),
          // buy/sell 显示 from 账户余额流向(对齐 A-od m-mini-bal)。
          if (_type == TradeType.buy || _type == TradeType.sell) ...[
            const SizedBox(height: 8),
            _balanceRow(),
          ],
        ],
      ),
    );
  }

  Widget _balanceRow() {
    final bal = _fromBalanceCents;
    final after = _type == TradeType.buy
        ? bal - (_tradeAmount * 100).round()
        : bal + (_tradeAmount * 100).round();
    final fail = _balanceInsufficient;
    return Container(
      key: ValueKey('balanceRow-${fail ? 'fail' : 'ok'}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fail
            ? context.yucai.negative.withValues(alpha: 0.10)
            : context.yucai.positive.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('资金账户余额',
                  style: TextStyle(fontSize: 12, color: context.yucai.muted)),
              const Spacer(),
              Text(
                '${_fmtCents(bal)} → ${_fmtCents(after)}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: fail ? context.yucai.negative : context.yucai.positive,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
            ],
          ),
          if (fail) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(LucideIcons.alertTriangle,
                    size: 13, color: context.yucai.negative),
                SizedBox(width: 4),
                Text('余额不足 · fail-fast 预览',
                    style:
                        TextStyle(fontSize: 11, color: context.yucai.negative)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _submitButton(bool submitting) {
    return FilledButton(
      key: const ValueKey('submitButton'),
      onPressed: submitting ? null : _submit,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: submitting
          ? SizedBox(
              height: 18,
              width: 18,
              // FilledButton 底 = accent(暗=鎏金),spinner 用 onAccent 反色。
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: context.yucai.onAccent),
            )
          : Text(_submitLabel),
    );
  }

  String get _submitLabel {
    switch (_type) {
      case TradeType.buy:
        return '确认买入';
      case TradeType.sell:
        return '确认卖出';
      case TradeType.dividend:
        return '记录分红';
      case TradeType.split:
        return '记录拆分';
    }
  }

  // ───────────────────────── 格式化 helpers ─────────────────────────

  /// 元(double)→ 货币符号 + 千分位 + 2 位小数。
  String _fmtAmt(double v) => _fmtCents((v * 100).round());

  String _fmtCents(int cents) {
    final sign = cents < 0 ? '-' : '';
    final abs = cents.abs();
    final yuan = abs ~/ 100;
    final fen = (abs % 100).toString().padLeft(2, '0');
    final s = yuan.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return '$sign$_curSym$buf.$fen';
  }
}

// ───────────────────────── 私有 widgets ─────────────────────────

/// 4 类型 segmented(buy/sell/dividend/split)。对齐 A-od type-cards。
/// selected 底色按 [_tradeTypeColor] 上色(buy=金/sell=红/dividend=绿/split=蓝灰)。
class _TypeSegmented extends StatelessWidget {
  const _TypeSegmented({required this.current, required this.onSelect});
  final TradeType current;
  final ValueChanged<TradeType> onSelect;

  @override
  Widget build(BuildContext context) {
    const labels = <TradeType, (String, IconData)>{
      TradeType.buy: ('买入', LucideIcons.arrowDownCircle),
      TradeType.sell: ('卖出', LucideIcons.arrowUpCircle),
      TradeType.dividend: ('分红', LucideIcons.coins),
      TradeType.split: ('拆分', LucideIcons.gitMerge),
    };
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final t in TradeType.values)
          _TypeChip(
            key: ValueKey('typeChip-${t.name}'),
            type: t,
            label: labels[t]!.$1,
            icon: labels[t]!.$2,
            selected: t == current,
            onTap: () => onSelect(t),
          ),
      ],
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    super.key,
    required this.type,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final TradeType type;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _tradeTypeColor(context, type);
    final bg = selected ? color : context.yucai.surface;
    // 选中字色 = bg 反色(亮=近白同原观感 / 暗=墨黑):暗色类型色为提亮档,
    // 硬白字在鎏金/亮红上对比不足,bg 反色两板均可辨识。
    final fg = selected ? context.yucai.bg : context.yucai.muted;
    final border = selected ? color : context.yucai.border;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
