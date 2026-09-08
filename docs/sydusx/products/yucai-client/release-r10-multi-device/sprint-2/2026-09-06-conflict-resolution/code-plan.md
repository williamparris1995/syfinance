# Code Plan — F18 冲突解决

## Tasks

- [ ] **T1 server 触达+解决落库**:检测统一(存在性+同 payload 短路+版本规则)/ResolveConflict 落库(client/merged Upsert+log)/FindPending 修缮/conflict.go 删除/proto created_at+regen Go;TDD(触达矩阵/短路语义更新/落库 log/分页修复)。
- [ ] **T2 client 触达+确认+applier**:port 区分 CREATE/UPDATE+listConflicts/resolveConflict 扩展+DTO 扩展;coordinator 确认标记+完整列表;applier 版本感知+per-change;TDD。
- [ ] **T3 面板 UI+e2e**:ConflictListBloc+ConflictPanelPage+FieldFormatter+badge 扩展+路由;fake 三能力+双设备冲突全链 e2e;全量门(flutter/go/e2e 双门)+提交。

## 执行方式

T1→T2→T3 串行派发,每任务两轴 review,修复循环 ≤5。
