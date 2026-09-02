# Code Ledger — F6

> task done / fix-rounds / rulings 记账(execute 阶段)。

| task | 状态 | fix-rounds | 记事 |
|---|---|---|---|
| T1 基础设施+收回链 | ✅ done | 1(round 1:NFR-1 裸跑守卫 + 还原 registrant 行尾抖动) | review 全 PASS;实现者三处有据偏差:fixedToday 用 final(DateTime 无 const 构造)/deleteTestDb 先 close 再删(Windows 句柄)/期次额以 entry.totalCents 差值断言;R7 既有测试的删库在 Windows 实际删不掉(close 缺失),新 helper 已修正——backlog:既有三套件的 tearDownAll 可迁到本 helper |
| T2 记录/聚合三文件 | ✅ done | 1(round 1:isCompleted 照实断言 + 注释文件名笔误 ×5) | review 全 PASS,oracle 全部手工复算一致;三处语义出入有据(调度含当日→夹具改 −3 月;recordContribution 不自动置完成态→照实断言钉死;demo 预算落在真实运行当月→deleteBudget 删固定月演示预算+summary accountId 作用域,任意日历日无时间炸弹,grep 0 处 DateTime.now) |
| T3 资产/级联/备份三文件 | ✅ done | 1(round 1:3 处注释/下限数字修正——买入 oracle 10 倍笔误/purge 15 张表口径/备链 4 账户) | review 断言零错误;备份走真实 ArchiveCodec 加密往返(scrypt+AES-GCM+gzip),覆盖非追加以标记实体消失证明;importAll=内建全量 wipe(14 deleteAll×15 表),清库测试文件内置末位;照实断言三处契约现状(标签 junction 不保全/契约外本地表原样/孤儿 entries);遗留疑点已注测:buy 现金腿不含 fee 是否产品意图 + 标签关联不入备份 → ticket 化评估 |
| T4 UI 链十文件 | ✅ done(11 文件) | 2(round 1[接力]:record_form analyze 警告+ensureVisible;round 1[review 后]:补 ui_template_record FR-12 悬空枚举 + LaunchAtStartup 副作用撤销) | 首任超时挂起,接力代理验证(9/10 首跑绿);review 1 轻 FAIL(模板一键按钮 design 翻译滑落)→补链修复;**生产疑点 6 处只记不修**:①侧栏订阅管理被 /accounts/:id 捕获(router 无静态子路由,真 bug)②模板 endDate=null 兜底截到今天③交易列表顶栏创建 pop 不重拉④持仓 TradeSheet pop 不重拉⑤typeFilter 粗分类收支不分(照实钉死)⑥账户下拉 FutureBuilder 异步空窗;boot 测试 LaunchAtStartup.enable 副作用经注册表实证→tearDownAll disable 撤销 |
| T5 全量回归门 | pending | | |

## rulings(审查裁决记录)

- T1 review 非阻断跟进:①NFR-1 守卫 → **已做**(round 1);②design HLD 共享设施清单缺 textContainingRich/deleteTestDb → **已补**(T4 等待期);③基线 linked_transactions_test.dart:218 的 amortizationIndex 注释错误(0=等额本息非 lumpSum)→ backlog 顺手修,不阻塞。
- T2 review 非阻断:LLD-7"月对比 6 窗口锚月"由标链③ 两个月窗口间接覆盖同一 summary API;6 窗口装配是报表页代码,T4 UI 链可选显式覆盖——记 backlog,不阻塞。
- spec 勘误待办(T5 顺手):FR-6 场景 1 措辞 → **已改**(T4 等待期:"进度 100%/remaining 0;isCompleted 为显式 completeGoal 语义,照实断言")。
