// ContractAttachmentStore 回归测试(2026-09-17「上传卡住」修复)。
// 核心场景:绑定**仅存在于服务端**的债务 id(bound 在线创建,本地镜像未及
// 回填)必须成功 —— v6 附件表对本地 debts 的 FK 会在此场景抛
// FOREIGN KEY constraint failed 并打断表单 pop,v7 已去 FK。
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:yucai_client/core/localdb/app_database.dart' as db;
import 'package:yucai_client/debt/data/contract_attachment_store.dart';

class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);
  final Directory root;
  @override
  Future<String?> getApplicationSupportPath() async => root.path;
}

void main() {
  late Directory root;
  late db.AppDatabase database;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('yucai_attach_store');
    PathProviderPlatform.instance = _FakePathProvider(root);
    database = db.AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
    root.deleteSync(recursive: true);
  });

  test('bind 到不在本地 debts 表的服务端 id 成功(修复核心)', () async {
    final store = ContractAttachmentStore(database);
    final src = File('${root.path}/src.txt')..writeAsStringSync('合同内容');
    final staged = await store.stage(src.path, '借条.txt');

    // debts 表为空 —— 模拟 bound 在线创建后镜像未回填。
    await store.bind('server-side-uuid-not-in-local-debts', staged);

    final bound = await store.forDebt('server-side-uuid-not-in-local-debts');
    expect(bound, isNotNull);
    expect(bound!.originalName, '借条.txt');
    expect(bound.sizeBytes,
        '合同内容'.codeUnits.length * 3); // 4 个 CJK × 3 UTF-8 字节。
    final path = await store.absolutePath(bound);
    expect(File(path).existsSync(), isTrue);
    expect(File(path).readAsStringSync(), '合同内容');
  });

  test('stage 后源文件失效不影响 bind(rename 回退 copy 路径常绿)', () async {
    final store = ContractAttachmentStore(database);
    final src = File('${root.path}/src2.txt')..writeAsStringSync('x');
    final staged = await store.stage(src.path, 'a.txt');
    await store.bind('d-local', staged);
    final bound = await store.forDebt('d-local');
    expect(bound, isNotNull);
  });

  test('重复 bind 替换旧附件(一债务一附件)', () async {
    final store = ContractAttachmentStore(database);
    final s1 = File('${root.path}/s1.txt')..writeAsStringSync('1');
    final s2 = File('${root.path}/s2.txt')..writeAsStringSync('2');
    await store.bind('d1', await store.stage(s1.path, '旧.txt'));
    final first = await store.forDebt('d1');
    await store.bind('d1', await store.stage(s2.path, '新.txt'));

    final rows = await database.select(database.contractAttachments).get();
    expect(rows, hasLength(1)); // 旧行被替换,不累积。
    final bound = await store.forDebt('d1');
    expect(bound!.originalName, '新.txt');
    // 旧文件已清理,新文件在。
    final oldPath = await store.absolutePath(first!);
    expect(File(oldPath).existsSync(), isFalse);
    final newPath = await store.absolutePath(bound);
    expect(File(newPath).existsSync(), isTrue);
  });

  test('remove 清行 + 清文件', () async {
    final store = ContractAttachmentStore(database);
    final src = File('${root.path}/s3.txt')..writeAsStringSync('3');
    await store.bind('d9', await store.stage(src.path, 'r.txt'));
    final bound = await store.forDebt('d9');
    final path = await store.absolutePath(bound!);
    await store.remove('d9');
    expect(await store.forDebt('d9'), isNull);
    expect(File(path).existsSync(), isFalse);
  });
}
