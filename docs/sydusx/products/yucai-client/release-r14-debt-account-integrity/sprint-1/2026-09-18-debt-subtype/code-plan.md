# Code Plan — F33 债务 subtype 全链路可编辑 + 9 类扩展

> 依据:[spec.md](./spec.md)(FR-1~4/NFR-1~2) + [design.md](./design.md)(ADR-1~6/HLD/LLD) + prototype v3(CURRENT,用户确认原样式)。
> 复杂度:**cross-module**(proto→server→client data→presentation)→ SDD 模式;T1 高风险工具链操作由主控 inline,实现类任务派发 subagent(sydusx-tdd)+ per-task code-review。

## Tasks

- [ ] **T1 proto 契约 + regen(inline,高风险工具链)** — `yucai/proto/debt/v1/debt.proto` UpdateDebtRequest 追加 `string subtype = 19;`;`make gen-dart`(client dart 生成物)+ server go 生成;**F13 sync.pbjson 手工补丁重套(风险首控)**。验收:go build 绿 + flutter analyze 生成物零新增 error + 全量单测不回归(1825 基线)。
- [x] **T2 server 接线(dispatch)** — `debt_handler.go#UpdateDebt` 将 `req.GetSubtype()` 填入 update DTO(dto.Subtype 字段已有)→ repo `SetSubtype` 既有通路;server 集成测试:UpdateDebt 持久化 subtype(given 已有债,update subtype,读回一致)。验收:go test 新测绿。✅ done(勘误 2 条见 ledger:update DTO 原无字段/repo.Update 原无 SetSubtype,均最小接线;两轴评审 pass)
- [x] **T3 client domain 常量(dispatch,与 T2 并行)** — `lib/debt/domain/value_objects.dart`:`DebtSubtypes` 扩 4 类(credit_loan/cash_installment/consumption_loan/business_loan + all + labels)+ 新增 `DebtSubtypeAffinity`(compatible map/defaultSubtypeFor/isConflict,other 恒 false)。TDD:affinity 判定/默认值/other 特判单测。✅ done(port 裁决:String .name 传参,不新增跨模块 import;13 测;两轴 pass)
- [x] **T4 client data 更新链路(dispatch,与 T3 并行)** — `UpdateDebtParams(+subtype)` → `debt_repository_impl.update` 透传 → `debt_remote_ds.update`(req 字段 19)→ `debt_local_ds.update`(drift 行 subtype 列)→ mirror update envelope 核对补字段(`mirror_mappers.dart:108` read 路径已有)。TDD:repo/remote DS/local DS/envelope 单测(透传+落库+信封含 subtype)。✅ done(envelope 已有 Subtype 转契约钉;params 实际在 bloc 层;两轴 pass)
- [x] **T5 表单 chips 解禁 + 自动归位(dispatch,依赖 T3/T4)** — `debt_form_page.dart`:编辑模式 chips 启用 + 提交携带 subtype;`_subtypeTouched` 标志 + `_onAccountChanged` 创建模式归位(未触碰才联动,LLD ②状态机)。TDD:widget 测试(编辑切换+保存携带/创建归位联动/触碰后不联动)。✅ done(另落地 design 风险项:归位×信用卡过滤清空守卫;守卫变异实验验证;232/232 绿;两轴 pass)
- [x] **T6 警示条 + 9 类图标色(dispatch,依赖 T3)** — form 内 `.callout.warn` 对应 banner(design-v2 warn 令牌,非阻断,提交零校验改动;文案按 prototype v3)+ `_debtTypeIcon` 4 新类(handCoins/calendarClock/shoppingBag/briefcase,核对包内命名)+ `debt_list_widgets`/`debt_detail_page` 图标色 switch 漏项排查。TDD:widget 测试(conflict 显/兼容隐/保存不阻断)。✅ done(图标包内逐一核实;列表/详情确认无 subtype 级图标;两轴 pass)
- [x] **T7 e2e + 全量门(inline)** — integration_test:编辑改 subtype 持久化 + 创建归位场景;`make client-e2e` 全绿 + `flutter test` 全绿(≥1825 基线) + analyze 零新增(439 基线) + `go test ./...` 绿。✅ done(link_debt_subtype e2e 新增并注册 14 文件;门:go 全绿+flutter 1849 全绿+analyze 437≤439+e2e 管道结果见 ledger)

## 依赖与顺序

```
T1 ──→ T2(并行)──┐
  └──→ T3(并行)──┼─→ T5 ─┐
  └──→ T4(并行)──┘   T6 ─┴─→ T7
```
T1 inline;T2/T3/T4 在 T1 后同批派发(互相独立);T5/T6 随后;T7 收尾。

## 全局约定

- 架构:DDD 四层 + flutter_bloc + injectable;跨模块 port 模式;English 结构化日志(无 CJK log 串)。
- 单一事实源:分类/白名单只在 `value_objects.dart`(NFR-1,评审 grep 门)。
- analyze 基线 439 info:新增代码零新增;e2e 前强杀 yucai_client(make 配方自带)。
- UI 以 `prototype/CURRENT=v3` 为事实源(原样式,不自创)。

## Ledger

(任务完成后逐条登记 done/fix-rounds/rulings → code-ledger.md)
