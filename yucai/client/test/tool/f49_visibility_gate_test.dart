// F49 T9 — grep 门的门测试(design ADR-1/单元4)。
//
// 三断言:
//  1. 真实仓库全绿(runGate 无违规)—— 全量 flutter test 每次跑都带此门,
//     CI 无需单独配置(design LLD「静态 grep 脚本进 CI 可后置」的落地形态);
//  2. 白名单条目 100% 存在且未接线(防腐化:路径漂移/接线后忘删白名单
//     都会被抓);
//  3. 负向自证:临时目录构造「presentation 消费 accounts 未接线」样本 →
//     门必须报违规;同文件加 userVisible 接线后 → 违规消失(证明门不是
//     恒真断言)。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/f49_visibility_gate.dart' as gate;

String get _pkgRoot => Directory.current.path;

void main() {
  test('F49 gate: real repo is green (no unfiltered account rendering)', () {
    final violations = gate.runGate(_pkgRoot);
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('F49 gate: whitelist entries exist and stay unwired (anti-rot)', () {
    final wired = gate.wiredFiles(_pkgRoot).toSet();
    final libDir = Directory('$_pkgRoot/lib');
    expect(libDir.existsSync(), isTrue, reason: 'run from client package root');
    for (final entry in gate.kWhitelist.keys) {
      final p = '$_pkgRoot/lib/${entry.substring('lib/'.length)}';
      expect(File(p).existsSync(), isTrue,
          reason: 'stale whitelist entry (file moved/deleted): $entry');
      expect(wired, isNot(contains(entry)),
          reason: '$entry is wired via userVisible — remove it from kWhitelist');
    }
    // 接线点清单非空 = T1 评审遗留的显式核对(FR-3 生产调用点)。
    expect(wired, isNotEmpty,
        reason: 'AccountVisibility.userVisible must have production call sites');
    expect(
      wired,
      containsAll([
        'lib/account/presentation/pages/accounts_page.dart',
        'lib/transaction/presentation/pages/transactions_page.dart',
        'lib/debt/presentation/pages/debt_form_page.dart',
      ]),
      reason: 'T4/T10 wired call sites must stay wired',
    );
  });

  test('F49 gate: catches unfiltered consumer and clears once wired', () {
    final tmp = Directory.systemTemp.createTempSync('f49_gate_selftest');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final dir = Directory('${tmp.path}/lib/foo/presentation/pages')
      ..createSync(recursive: true);

    // ① 未接线的消费点 → 必须报违规。(tmp 根必然带本仓库白名单的 stale
    // 噪声,断言时滤掉 stale 行只看文件违规。)
    final f = File('${dir.path}/selector_page.dart');
    f.writeAsStringSync('''
final s = state is AccountsLoaded ? state.accounts : const [];
''');
    var violations = gate
        .runGate(tmp.path)
        .where((v) => !v.startsWith('stale whitelist'))
        .toList();
    expect(violations, isNotEmpty);
    expect(violations.first, contains('selector_page.dart'));
    expect(violations.first, contains('AccountsLoaded'));

    // ② 同文件接线 userVisible → 文件违规消失(仅剩 stale 噪声)。
    f.writeAsStringSync('''
final s = state is AccountsLoaded ? state.accounts : const [];
final scoped = AccountVisibility.userVisible(s);
''');
    expect(
      gate
          .runGate(tmp.path)
          .where((v) => !v.startsWith('stale whitelist'))
          .toList(),
      isEmpty,
    );

    // ③ 非.presentation 目录的同型文件不报(扫描面外)。
    final dataDir = Directory('${tmp.path}/lib/foo/data')
      ..createSync(recursive: true);
    f.renameSync('${dataDir.path}/selector_repo.dart');
    Directory('${tmp.path}/lib/foo/presentation').deleteSync(recursive: true);
    expect(
      gate
          .runGate(tmp.path)
          .where((v) => !v.startsWith('stale whitelist'))
          .toList(),
      isEmpty,
      reason: 'files outside presentation/** are out of gate scope',
    );

    // ④ 白名单条目指向不存在文件 → stale 报错(防腐化路径)。
    File('${tmp.path}/lib/foo/presentation/pages/keep.dart')
        .createSync(recursive: true);
    // runGate 用本仓库 kWhitelist;stale 检测对 tmp 根必然全报 → 证明
    // 防腐化分支可达(真实仓库由断言 2 兜底零 stale)。
    final stale = gate.runGate(tmp.path);
    expect(stale, isNotEmpty);
    expect(stale.first, contains('stale whitelist entry'));
  });
}
