// F49 grep 门(design ADR-1 / 单元4;spec FR-3)—— presentation 层账户
// 消费纪律的静态守护。
//
// 语义:lib/**/presentation/** 下任何消费账户列表/流(AccountsLoaded 状态、
// AccountRepository 直取、watchAccounts 流、AccountsChanged 事件、
// state.accounts 读取)的文件,若把账户渲染给用户(列表行/下拉选择器候选),
// 必须经 `AccountVisibility.userVisible`(展示层统一过滤入口)接线;否则
// 报错退出 1。金额计算、名称解析、镜像等刻意全量的场景走下方白名单,
// 逐条注释理由(白名单新增条目必须同步写理由——无理由的白名单条目视为
// 门缺口)。
//
// 用法:
//   dart run tool/f49_visibility_gate.dart          # 从包根(或任意 CWD)
//   flutter test test/tool/f49_visibility_gate_test.dart  # 全量 test 自带此门
//
// 输出(stdout,英文——遵守「无 CJK 的 log 串」约束)逐文件列出违规行号与
// 命中模式;全绿时打印 scanned/wired/whitelisted 计数与接线点清单。
//
// 边界(刻意不覆盖,review 兜底):
//   - 非 presentation 层(data/domain/bloc 状态定义)不在扫描面;
//   - 文件级启发:同一文件内既有接线又有新增全量直渲时,门只看文件级
//     标记(接线存在即过)——新增渲染点仍需 review 必查(design LLD 约定)。

import 'dart:io';

/// 白名单:相对路径(POSIX 风格)→ 逐条理由。
///
/// 三类(理由必须落在具体语义上,不接受「懒得滤」):
///  A. 命中仅为状态定义/事件定义/doc 注释/bloc 透传 —— 无渲染点;
///  B. 名称解析/金额计算/计数口径 —— spec FR-3「可见处过滤、计算处保留」
///     的刻意全量;
///  C. 选择器候选集结构性排除 —— 候选仅 asset/expense/income/savings 类,
///     载体户恒为 loan 类负债(card_loan 并入模式建户,T2),天然不在候选。
const Map<String, String> kWhitelist = {
  // ── A. 状态/事件定义与 bloc 透传(无渲染点)──────────────────────
  'lib/account/presentation/bloc/account_state.dart':
      'A: AccountsLoaded/AccountError 状态类定义(accounts 字段生产方),'
      '非渲染文件;渲染消费点在 pages。',
  'lib/transaction/presentation/bloc/transaction_bloc.dart':
      'A: doc 注释提及 AccountRepository(页面自行加载),bloc 本身只消费'
      ' TransactionRepository,无账户消费。',
  'lib/transaction/presentation/bloc/transaction_form_event.dart':
      'A: AccountsChanged 事件类定义(字段生产方),无渲染点。',
  'lib/transaction/presentation/bloc/transaction_form_state.dart':
      'A: 表单状态类携带 accounts 快照(字段生产方),无渲染点。',
  'lib/transaction/presentation/bloc/transaction_form_bloc.dart':
      'A: 状态机透传 accounts(Ready/Submitting 携带),渲染由'
      ' transaction_form_page 负责(该页在 C 类白名单)。',
  'lib/account/presentation/pages/account_form_page.dart':
      'A: 账户新建/编辑表单——BlocListener 监听提交后的 AccountsLoaded 迁移'
      '以 pop 返回,不渲染账户列表/选择器。',
  'lib/binding/presentation/bloc/binding_bloc.dart':
      'A: 绑定/镜像同步管线(NFR-1:镜像重建回写 isSystem=false、载体回可见'
      '为拍板的预期行为)——刻意全量,不滤。',

  // ── B. 名称解析 / 金额计算 / 计数口径(FR-3 计算处保留)──────────
  'lib/auth/presentation/pages/home_page.dart':
      'B: _assetBreakdown 资产三栏金额计算 + 「共 N 个账户」计数(T4 评审'
      '核可:既有口径含分类伪账户,单滤反而口径不一致)。',
  'lib/transaction/presentation/pages/transaction_detail_page.dart':
      'B: _accountNameOf 名称解析(id→name),非选择器。',
  'lib/goal/presentation/pages/goal_detail_page.dart':
      'B: accountMap 名称解析(id→name),非选择器。',
  'lib/debt/presentation/pages/debts_page.dart':
      'B: _loadAccountNames 卡贷「归到卡名下」分组头名称解析(FR-6 债务页'
      '分组依赖全量账户名,含载体名)。',
  'lib/template/presentation/pages/subscription_center_page.dart':
      'B: 订阅卡账户名解析(_accountNames map),非选择器。',
  'lib/settings/presentation/settings_page.dart':
      'B: 清空数据警示的规模计数(stats.accounts 为 DataResetController'
      ' 统计,非账户流消费)。',
  'lib/account/presentation/pages/account_detail_page.dart':
      'B+C: 单账户直达详情(路由直达非列表/选择器);_accountsMap 近期交易'
      '名称解析(B);repay/topup 对话框候选=储蓄/资产类结构性排除(C);'
      '还款计划/现金分期面板按挂接债渲染(FR-4b/FR-6,必须可见载体分期)。',

  // ── C. 选择器候选集结构性排除(候选非 loan 类,载体天然不在)──────
  'lib/transaction/presentation/pages/transaction_form_page.dart':
      'C: 交易表单候选=支付(asset∪creditCard)/分类(expense/income)型;'
      '载体=loan 负债天然不在任一下拉(T4 评审核证);_resolveDescription'
      '为名称解析(B)。',
  'lib/template/presentation/widgets/template_form.dart':
      'C: 模板下拉候选=asset/expense 型,载体(loan)结构性不在。',
  'lib/budget/presentation/pages/budget_form_page.dart':
      'C: 预算账户=expense 型(预算语义=支出分类),载体(loan)结构性不在。',
  'lib/goal/presentation/pages/goal_form_page.dart':
      'C: 目标关联=investment/savings(asset 非 investment),载体(loan)'
      '结构性不在。',
  'lib/debt/presentation/pages/receivable_form_page.dart':
      'C: 应收账户=otherAsset、来源=asset(非 otherAsset),载体(loan)'
      '结构性不在。',
  'lib/debt/presentation/pages/receivable_detail_page.dart':
      'C: 收款入账来源=asset 过滤,载体(loan)结构性不在。',
  'lib/debt/presentation/pages/debt_detail_page.dart':
      'C: 还款资金来源=asset+active 过滤(_accounts),载体(loan)结构性'
      '不在;_allAccounts 名称解析(B)。',
  'lib/holding/presentation/pages/trade_sheet_page.dart':
      'C: 交易资金来源=asset(非 otherAsset),载体(loan)结构性不在。',
  'lib/account/presentation/widgets/credit_card_repay_dialog.dart':
      'C: 储蓄卡候选=savings+active+同币种,载体(loan)结构性不在。',
  'lib/account/presentation/widgets/stored_value_topup_dialog.dart':
      'C: 充值付款候选=asset 类,载体(loan)结构性不在。',
};

/// 「消费账户列表/流」的文件级标记(任一命中即视为消费点)。
final List<RegExp> kConsumerPatterns = [
  RegExp(r'\bis\s+AccountsLoaded\b'), // bloc 状态解构(.accounts 读取)
  RegExp(r'\bAccountRepository\b'), // 仓储直取(list/watchAccounts)
  RegExp(r'\bAccountsChanged\b'), // 交易表单账户变更事件
  RegExp(r'\.watchAccounts\b'), // 流订阅
  RegExp(r'\b(?:state|s|st)\.accounts\b'), // state.accounts 字段读取
];

/// 「已接线」标记:调用 userVisible(只要文件内出现调用点即算)。
final RegExp kWiredPattern = RegExp(r'AccountVisibility\.userVisible\(');

/// 对 [pkgRoot](yucai/client 包根)跑门,返回违规清单(空 = 全绿)。
///
/// 每条违规 = 'path:line: <pattern source>' 的人类可读串;另有白名单
/// 防腐化自检:白名单条目文件不存在时以 'stale whitelist entry' 报出。
List<String> runGate(String pkgRoot) {
  final violations = <String>[];
  final libDir = Directory('$pkgRoot/lib');
  if (!libDir.existsSync()) {
    return ['gate error: $pkgRoot/lib not found (run from client package)'];
  }

  // 1. 收集 lib/**/presentation/**.dart(任意深度的 presentation 目录)。
  //    嵌套 presentation 子目录(pages/widgets/bloc 等)会被祖先目录的
  //    recursive 遍历再次覆盖 → 按 path 去重。
  final files = _presentationFiles(pkgRoot);

  // 2. 白名单防腐化:条目文件必须真实存在(路径漂移即报,防静默失效)。
  final normalizedWhitelist = <String, String>{};
  for (final entry in kWhitelist.entries) {
    final p = entry.key.replaceAll('/', Platform.pathSeparator);
    if (!File('$pkgRoot${Platform.pathSeparator}$p').existsSync()) {
      violations.add('stale whitelist entry: ${entry.key} does not exist');
    }
    normalizedWhitelist[entry.key] = entry.value;
  }

  // 3. 逐文件:命中消费标记 && 未接线 && 不在白名单 → 违规(报告行号)。
  for (final f in files) {
    final rel = _relPath(pkgRoot, f);
    final lines = f.readAsLinesSync();
    final hits = <(int, RegExp)>[];
    for (var i = 0; i < lines.length; i++) {
      for (final p in kConsumerPatterns) {
        if (p.hasMatch(lines[i])) hits.add((i + 1, p));
      }
    }
    if (hits.isEmpty) continue;
    final wired = lines.any(kWiredPattern.hasMatch);
    if (wired || normalizedWhitelist.containsKey(rel)) continue;
    for (final (line, p) in hits) {
      violations.add(
          '$rel:$line: consumes accounts via /${p.pattern}/ but no '
          'AccountVisibility.userVisible and not whitelisted');
    }
  }
  return violations;
}

/// 已接线文件清单(相对路径,供报告/测试核对)。
List<String> wiredFiles(String pkgRoot) {
  final out = <String>[];
  for (final f in _presentationFiles(pkgRoot)) {
    if (f.readAsLinesSync().any(kWiredPattern.hasMatch)) {
      out.add(_relPath(pkgRoot, f));
    }
  }
  return out;
}

List<File> _presentationFiles(String pkgRoot) {
  final seen = <String>{};
  final libDir = Directory('$pkgRoot/lib');
  if (!libDir.existsSync()) return const [];
  for (final e in libDir.listSync(recursive: true)) {
    if (e is! Directory) continue;
    if (!e.uri.pathSegments.contains('presentation')) continue;
    for (final f in e.listSync(recursive: true).whereType<File>().toList()) {
      if (f.path.endsWith('.dart')) seen.add(f.absolute.path);
    }
  }
  final files = [for (final p in seen.toList()..sort()) File(p)];
  return files;
}

String _relPath(String pkgRoot, File f) {
  var p = f.path.substring(
      Directory(pkgRoot).absolute.path.length + Platform.pathSeparator.length);
  return p.replaceAll(Platform.pathSeparator, '/');
}

void main(List<String> args) {
  // 包根推断:脚本位于 <pkg>/tool/ → 根 = 脚本父目录的父目录;
  // 显式参数优先(测试/CI 可传别的根)。
  final pkgRoot = args.isNotEmpty
      ? args.first
      : File.fromUri(Platform.script).parent.parent.path;
  final violations = runGate(pkgRoot);
  final scanned = _presentationFiles(pkgRoot).length;
  final wired = wiredFiles(pkgRoot);
  final whitelisted = kWhitelist.length;
  stdout.writeln('f49 visibility gate: scanned=$scanned presentation files, '
      'wired=${wired.length}, whitelist=$whitelisted entries');
  for (final w in wired) {
    stdout.writeln('  wired: $w');
  }
  if (violations.isNotEmpty) {
    stdout.writeln('VIOLATIONS (${violations.length}):');
    for (final v in violations) {
      stdout.writeln('  $v');
    }
    stdout.writeln(
        'Fix: wrap the account list with AccountVisibility.userVisible(...) '
        'at the scope entry, or add a whitelisted path WITH a reason to '
        'kWhitelist in tool/f49_visibility_gate.dart.');
    exitCode = 1;
  } else {
    stdout.writeln('f49 visibility gate: PASS');
  }
}
