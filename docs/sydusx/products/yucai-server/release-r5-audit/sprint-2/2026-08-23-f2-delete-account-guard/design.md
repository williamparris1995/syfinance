# Design — F2 delete-account-guard

## ADR-1 port 方向:account/domain 定义,消费方 repo 结构化实现

镜像 goal 的 `AccountBalanceSource`(消费方 domain 定义接口、生产方 Service 结构化实现、setter 注入),方向反转:account 需要**消费**各模块的引用计数,故接口放 `account/domain`(`ports.go`),六消费模块 repo 提供同签名方法(不 import account,Go 结构化匹配在 wire 处收口)。备选(否决):account 直接 import 六模块 internal——违反 CLAUDE.md port 约束;或 gRPC 自调——单进程内荒谬。

```go
// internal/account/domain/ports.go
type AccountReferenceSource interface {
    CountAccountReferences(ctx context.Context, tenantID, accountID uuid.UUID) (int64, error)
    AccountReferenceSourceName() string
}
```

计数语义 = 非软删**父记录**数(错误信息说"被 N 笔交易引用"而非"N 条 entry")。

## ADR-2 查询形态:能 edge 就 HasXxxWith,无 edge 直查子表

- transaction:`Transaction.Query().Where(TenantID, DeletedAtIsNil, HasEntriesWith(entry.AccountID(id))).Count` —— E 的 edge 立即回本。
- budget:同构(`HasItemsWith`)。
- debt:`DebtDetails.Query().Where(TenantID, Or(AccountID, CollectionAccountID)).Count`。
- holding:`Holding.Query().Where(TenantID, AccountID).Count` + `HoldingTransaction.Query().Where(TenantID, AccountID).Count` 求和(HoldingTransaction 无 edge,E 排除项)。
- goal:`Goal.Query().Where(TenantID, Or(LinkedAccountID, HasAccountLinksWith(link.AccountID))).Count`?——goal_account_links **无 edge**(E 排除项),直查两表求和。
- template:`TransactionTemplate.Query().Where(TenantID, Or(SourceAccountID, DestinationAccountID)).Count`。

## ADR-3 fail-closed 三层

1. `len(sources)==0` → 错误 `account reference sources not configured`(接线丢失立刻炸,不静默回退 orphan 行为;先例:C-feature 写守卫 fail-open→closed 修复)。
2. 单源 count err → 包装返错(带 source 名)。
3. count>0 → 业务错误(可判别,客户端可提示)。

已知代价:account Service 既有单测需注入 stub(至少 1 个返回 0 的 source)。

## ADR-4 wiring 手编(wire CLI 坏,CLAUDE.md)

`provideAccountService` 增参 `refSources []accountdomain.AccountReferenceSource`,providers.go 里**显式构造切片**(六个 repo 已有 provider;顺序固定 transaction→budget→debt→holding→goal→template,错误信息确定性)。wire_gen.go 手编对应调用。端到端验证:grep 注入点→NewService→handler 全链(教训:接线必须反查全程)。

## 测试设计

- 每 repo:`schema_integrity` 风格新文件或并入现有:seed 引用/非引用/软删父三态断言 count。
- account application:stub source 表(0/正数/error 三态)× DeleteAccount/DeleteCategory。
- tests/ 集成:记账→拒删→删交易→可删;DeleteByTenant 冒烟。
