# Task Brief T1 — Account.isSystem 地基 + AccountVisibility 助手

## 上下文
- 工作目录(worktree,一切操作在此):`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r17-f49`
- 先读:`docs/sydusx/products/yucai-client/release-r17-account-extensibility/sprint-1/f49-carrier-hide/spec.md`(FR-1/FR-3)与 `design.md`(单元1/LLD)
- F49 概要:卡贷「并入模式」自动建的贷款负债户是账务载体,要激活 drift 既有 `is_system` 列使其可被展示层过滤;独立账单模式账户是真实账户,永不隐藏。

## 任务(TDD,红-绿-重构)
1. `yucai/client/lib/account/domain/entities/account_entity.dart`:Account 增 `final bool isSystem;`(缺省 false 的可选参,copyWith 支持 equality/toString 照既有字段风格)。
2. 新文件 `yucai/client/lib/account/domain/account_visibility.dart`:`abstract final class AccountVisibility { static List<Account> userVisible(Iterable<Account> xs) => xs.where((a) => !a.isSystem).toList(); }`(domain 纯函数,零 import 依赖)。
3. 透传:
   - `repositories/account_repository.dart` 的 `CreateAccountParams` 增可选 `isSystem = false`;
   - `data/account_local_ds.dart` create/update 落库读写 `isSystem`(现 create 硬编码 `isSystem: false` 于第 63 行附近,改为读参数;update 若有同列照读);
   - `data/mappers/account_mapper.dart` 与 `data/account_remote_ds.dart`:DTO↔entity 映射带上 isSystem(proto Account 有 field 45,server 恒 false;CreateRequest 不发,维持现状)。
4. 测试(先写红):
   - entity:copyWith/相等性含 isSystem;
   - mapper 往返:drift row isSystem=true → entity true → 回写 true;
   - `AccountVisibility.userVisible`:true 被滤/false 保留/空列表/顺序稳定;
   - local_ds create 透传(照该文件既有测试范式)。
   测试文件放 `yucai/client/test/account/...` 对应位置,照既有命名。

## 约束
- 只动上述文件;**禁止**碰 accounts_page/account_detail/debt 模块/repairs(其他任务负责)。
- DDD 边界:domain 零 flutter 依赖;跨模块不 import 生产方。
- 注释中文、只写代码自身说不清的约束。
- 每步验证:改一个单元 → `cd yucai/client && flutter analyze`(增量)→ 单测文件立即跑 → account 相关 suite 绿。

## 完成判据
新增/修改测试全绿;`flutter analyze` 无新增 error(基线 20 全在 *.pbserver.dart);列出改动文件清单与测试输出摘要。
