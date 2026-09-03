# Task Brief F9-T4 — e2e 扩展 + 全量回归门

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f9`,客户端 `yucai/client/`。T1-T3 已就绪(共享件/账户详情套件/三模块查询)。

## 先读(必读)

1. `docs/.../2026-09-03-list-unify/spec.md` FR-6 + NFR-1/2
2. `yucai/client/integration_test/full_audit_test.dart` A3(账户详情——**其断言可能因近期交易区 UI 变化受影响,重点核**)
3. `yucai/client/integration_test/link_holding_buy_test.dart`(持仓夹具模式)
4. F6/F7 既有 e2e:`link_mutation_cascade_test.dart`(管道断言风格)、`ui_list_filter_test.dart`(UI 交互风格)

## 交付物

### 1. e2e 扩展(照既有文件模式,中文注释+oracle 手算)

**管道层**(DS 直调,加入既有合适文件或新文件 `link_list_unify_test.dart`,自包含前缀 `统链*`):
- 持仓 `listPaged`:搜索(symbol/name 忽略大小写)+ 市值降序全序 + pageSize=2 分页 token 语义(拼接=全量/越界空页)。
- 债务 `list(searchText/sortKey/sortDir)`:counterparty 搜索 + 金额/到期四态 + 默认(无参)=插入序零变化断言。
- (账户搜索为页面层,无 DS 断言——管道侧免)。

**UI 层**(加入 `ui_list_filter_test.dart` 或新文件 `ui_list_unify_test.dart`):
- 账户详情:进入第一张卡详情 → 近期交易区:默认近期交易可见;搜索收窄;翻页夹具(若不足 100 条则断言单页分页条隐藏,取舍注释)。
- 持仓页:搜索收窄 + PagerBar 可见性(夹具 <20 只则断言单页隐藏)。
- 债务页:搜索 + 排序切换断言(顺序变化)。
- 账户管理页:搜索收窄。

**A3 兼容核查**:跑 full_audit 全文件,若 A3 因近期交易区变化红——修 e2e 断言适配新 UI(不改生产),并在断言处注释 F9 变更说明。

### 2. 全量回归门(最终验收,你来跑)

1. `cd yucai && make client-e2e`(10 文件全绿;若新增管道文件需先 Makefile E2E_FILES 尾追加)
2. UI 扩展文件单跑绿(若新文件,Makefile E2E_UI_FILES 尾追加 + `make client-e2e-ui F=<新文件>` 绿;既有文件扩展则整文件绿)
3. `cd client && flutter test`(全量 ≥1277 绿)+ `flutter analyze`(基线,新文件 0 条)

## 约束

生产代码零改动;Makefile 只做尾追加;杀残留/测后删库确认;registrant 最后还原;不 commit。完成后报告:扩展点+各门证据。
