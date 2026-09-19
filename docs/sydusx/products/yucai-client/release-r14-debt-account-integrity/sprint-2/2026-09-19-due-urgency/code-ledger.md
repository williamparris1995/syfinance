# Code Ledger — F37 due-urgency

## 实现 — ✅ done(2026-09-19,inline TDD)

- 改动:debt_query.dart(DebtDueUrgency+debtDueUrgency 纯函数)/debt_list_widgets.dart(MetaKv valueColor/MetaItem color 可选参+_dueUrgencyDecor 后缀着色+三渲染点)/两测试文件(domain 6+widget 4)。
- fix-rounds:2(①kv/item 站点缩进与闭包作用域——color 泄漏外层具名参,改整件闭包返回;②后缀长度致 MetaItem 行溢出 11px——缩短为「(N天内)/(逾期N天)」+ellipsis)。
- 排序结论:默认序已是「未结清在前+到期升序」(F9 NFR-2),本票以显性测试钉死+视觉紧迫度补足用户感知。
- 评审:两轴 pass(存储口径零改动;色值全令牌;两页镜像自动同待遇)。
- 门:1884 全绿+analyze 437<438(顺修存量重复 import)。

## 用户追问扩展 — 下一期还款日紧迫度 ✅(2026-09-19)

- 用户问:着色只看合同到期日,下一期分期有没有特殊显示?→ 此前没有(仅已逾期红字),本扩展补齐。
- 改动:DebtCardFootCallout hasNext 分支——下一期 ≤15 天追加「 · N天内」着色 span(≤7 negative/8-15 warn),已逾期维持既有红字;债务+债权共享组件自动同待遇。
- TDD 2 新测(3 天内提示/20 天无);1886 全绿+analyze 438=基线+e2e 14/14。

## F38 附加修复 — 模板改周期后 next_date 锚定漂移 ✅(2026-09-19)

- 用户报告:房租模板(每 3 个月/第一天/start 8-01)下一次显示 12-01,应为 11-01。
- 取证:本地模板表实际存储 cycle=monthly/interval=3/billing_day=1/start=8-01/next_date=12-01;真函数穷举确认 interval=3 恒出 11-1,12-1 只能来自「从今天(9-19)重锚」。
- 根因(client+server 镜像同bug):模板 update 规则变化时 nextDate = NextAfter(max(start,today)-1) —— today 重锚使 interval>1 系列永久漂移(8/1+3k 系列丢失)。
- 修复:firstOnSeriesAfter(start, rule, after)(从 start 走锚定系列,首个 ≥ max(start,今天)),client next_after.dart/template_local_ds + server recurrence/template service 镜像同修;F38 测试 RED(12/1)→GREEN(11/1)。
- 用户数据校正:本地模板 next_date 12-01→11-01(直接 UPDATE,前后取证;与代码修复后的重算值一致)。
- 门:1888 全绿+go 全绿+vet 净。

## F38 附加修复 — 日期字段时区归一化 ✅(2026-09-19)

- 用户报告:编辑/复制时日期有 8 小时偏移(UTC+8 环境)。
- 诊断:日期字段三条链路混用 —— 选择器产「本地零点」、drift 文本存「UTC 零点(Z)」或「本地零点(无 Z)」、显示取 civil 日 —— 均不显示时刻,但入库/出库转换时同一 civil 日会横跨 8 小时。
- 修复(约定统一):日期字段选择器统一产出 **UTC 零点**(civil 日期不变,epoch 全链一致):DatePickerInput(账户表单,复制/编辑共用)/债务表单 _ODDateField/债务详情单期改日/债权表单/模板表单 _pickDate 五处;既有 server 同步值本就是 UTC 零点 ✓。
- 测试:date_picker_input_test 2 条(UTC 零点 epoch 判别/civil 显示)。
- 门:1890 全绿+analyze 基线持平(改动文件零新增)+e2e 14/14。
