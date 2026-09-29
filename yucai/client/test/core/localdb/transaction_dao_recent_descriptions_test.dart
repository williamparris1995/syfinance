// 反馈⑦(表单历史填写票):TransactionDao.recentDistinctDescriptions ——
// 表单描述字段的「最近使用」建议数据口径。
//
// 契约:
//  - distinct:同一描述多笔只保留一条;
//  - 排序:按每组「最近一次记录时间」(MAX(created_at))倒序 —— 最近用过的
//    描述排最前;
//  - 空过滤:空串与纯空白描述不进入建议;
//  - limit 截断;缺省 200(全显口径的内存过滤数据面,封顶防极端库);
//  - 空库返回空表。
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:yucai_client/core/localdb/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  /// 按序插一行头表(description + createdAt 指定,createdAt 单调递增)。
  Future<void> seedRow(String id, String description, DateTime createdAt) =>
      db.transactionDao.insertTransaction(TransactionsCompanion.insert(
        id: id,
        transactionDate: createdAt,
        description: description,
        version: 1,
        createdAt: createdAt,
        updatedAt: createdAt,
      ));

  test('distinct + 最近记录时间倒序(重复描述按最新一笔排位)', () async {
    final t0 = DateTime.utc(2026, 9, 1);
    await seedRow('a', '午餐', t0);
    await seedRow('b', '地铁通勤', t0.add(const Duration(days: 1)));
    await seedRow('c', '午餐', t0.add(const Duration(days: 2)));
    await seedRow('d', '永辉超市', t0.add(const Duration(days: 3)));

    final result = await db.transactionDao.recentDistinctDescriptions(8);

    // 「午餐」两笔 → 一条,排位取 c(最新);永辉超市(d)最先。
    expect(result, ['永辉超市', '午餐', '地铁通勤']);
  });

  test('空串与纯空白描述被过滤(不产生空建议)', () async {
    final t0 = DateTime.utc(2026, 9, 1);
    await seedRow('a', '', t0);
    await seedRow('b', '   ', t0.add(const Duration(days: 1)));
    await seedRow('c', '\t\n', t0.add(const Duration(days: 2)));
    await seedRow('d', '餐饮', t0.add(const Duration(days: 3)));

    final result = await db.transactionDao.recentDistinctDescriptions(8);

    expect(result, ['餐饮']);
  });

  test('limit 截断最近 N 条', () async {
    final t0 = DateTime.utc(2026, 9, 1);
    for (var i = 0; i < 10; i++) {
      await seedRow('t$i', 'desc-$i', t0.add(Duration(days: i)));
    }

    final result = await db.transactionDao.recentDistinctDescriptions(5);

    // 取创建时间最近的 5 条(desc-9 … desc-5),倒序。
    expect(result, ['desc-9', 'desc-8', 'desc-7', 'desc-6', 'desc-5']);
  });

  test('缺省 limit = 200(全显口径数据面封顶,防极端库)', () async {
    final t0 = DateTime.utc(2026, 9, 1);
    for (var i = 0; i < 205; i++) {
      await seedRow('t$i', 'desc-$i', t0.add(Duration(minutes: i)));
    }

    // 无参调用走默认 200:205 行 distinct 描述封顶取 200,最新在前。
    final result = await db.transactionDao.recentDistinctDescriptions();
    expect(result.length, 200);
    expect(result.first, 'desc-204');
  });

  test('空库返回空表', () async {
    expect(await db.transactionDao.recentDistinctDescriptions(8), isEmpty);
    expect(await db.transactionDao.recentDistinctDescriptions(), isEmpty);
  });
}
