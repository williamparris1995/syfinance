import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/template_tables.dart';

part 'template_dao.g.dart';

@DriftAccessor(tables: [TransactionTemplates])
class TemplateDao extends DatabaseAccessor<AppDatabase>
    with _$TemplateDaoMixin {
  TemplateDao(super.db);

  Future<void> insertTemplate(TransactionTemplatesCompanion entry) =>
      into(transactionTemplates).insert(entry);

  Future<TransactionTemplate?> getTemplateById(String id) =>
      (select(transactionTemplates)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  Stream<List<TransactionTemplate>> watchAllTemplates() =>
      select(transactionTemplates).watch();

  Future<int> updateTemplate(TransactionTemplatesCompanion entry) =>
      (update(transactionTemplates)
            ..where((t) => t.id.equals(entry.id.value)))
          .write(entry);


  Future<int> deleteAllTemplates() => delete(transactionTemplates).go();
  Future<int> deleteTemplateById(String id) =>
      (delete(transactionTemplates)..where((t) => t.id.equals(id))).go();
}
