// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_audit_dao.dart';

// ignore_for_file: type=lint
mixin _$AgentAuditDaoMixin on DatabaseAccessor<AppDatabase> {
  $AgentAuditsTable get agentAudits => attachedDatabase.agentAudits;
  AgentAuditDaoManager get managers => AgentAuditDaoManager(this);
}

class AgentAuditDaoManager {
  final _$AgentAuditDaoMixin _db;
  AgentAuditDaoManager(this._db);
  $$AgentAuditsTableTableManager get agentAudits =>
      $$AgentAuditsTableTableManager(_db.attachedDatabase, _db.agentAudits);
}
