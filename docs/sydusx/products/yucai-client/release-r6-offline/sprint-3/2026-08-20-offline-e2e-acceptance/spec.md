---
feature: 2026-08-20-offline-e2e-acceptance
status: drafted
---

# Spec — R6 三条成功判据 e2e 验收(release gate)

> R6 sprint-3 feature I(依赖 G,H)。**形式决策(analysis 裁定)**:普通 `flutter test` 内「判据命名集成组」——临时文件库(真实 drift)+ mock gRPC 层(repo/DS 接口级 mock)+ 串联各 feature 已交付组件;**不**用 `integration_test`(需设备挂载,CI 不可跑,且本项目测试基线全部在 `flutter test` 内)。另交付**人工验收清单**文档(真机断网场景,release gate 证据归档——自动化测不了「拔网线」)。

## ADDED Requirements

### Requirement: FR-1 e2e-①断网无账号全新安装全链路(重启持久)
- [ ] 集成测试 SHALL 以临时文件库串联:建现金/餐饮账户 → 记支出(联动余额)→ 买持仓(FIFO/复式)→ 建 8 月预算(actuals)→ 打标签 → **关闭并重开库** → 断言:账户余额/持仓+lot/交易条目/预算 actuals/标签 全部完好且一致(联动值与写入时相同);再跑 `integrityCheck()` 通过。

#### Scenario: 判据①串联
- GIVEN 全新临时文件库,零网络(guest local ds 直用,无远端依赖)
- WHEN 上述全链路 + 关库重开
- THEN 全部数据完好(逐面断言),integrityCheck ok

### Requirement: FR-2 e2e-②绑定上云
- [ ] 集成测试 SHALL 串联 G 全链路:本地造数据(账户+交易)→ BindingBloc(guard 三面 mock 空 → readyToUpload)→ 确认上传(exporter 导出 → **capture 上传字节**断言 envelope:8 模块键/条目数/关键实体 ID 与本地一致)→ 远端 list mock 返回上传数据 → success + markBound 调用断言。

#### Scenario: 判据②串联
- GIVEN 本地有账户+交易,远端账号空(mock)
- WHEN 绑定向导走完
- THEN 上传的 envelope 含本地全部数据(逐面计数比对),状态 success,标记已写

### Requirement: FR-3 e2e-③永不绑定(长期纯本地)
- [ ] 集成测试 SHALL 验证多次会话纯本地:e2e-① 的库重开 **3 次**,每轮追加记账,断言累计数据持续完好(第 3 轮含前两轮全部数据)——「不绑定永远本地」的持久性。

### Requirement: FR-4 e2e-④绑定期间记账→断网登出→全可见(H 完全体)
- [ ] 集成测试 SHALL 串联 H:本地库(guest 数据在位)→ mock 登入(Authenticated,tracker=false)→ 远端写一笔(mock repo 返回成功+新列表)→ mirror 刷新 → **mock 登出前终刷断网场景(list 抛异常→catch 降级)** → Guest 态读本地:guest 旧数据 + 绑定期镜像数据全部可见。

### Requirement: FR-5 人工验收清单(release gate 证据)
- [ ] feature 目录 SHALL 交付 `acceptance-checklist.md`:真机断网场景清单(①飞行模式全新安装记账 ②登录绑定上云后网页/另端可见 ③长期不绑定使用 ④绑定期断网登出)含操作步骤/预期/勾选栏;执行记录归档(勾选+日期+签名)作为 release gate 证据。

### Requirement: NFR-1 质量基线
- [ ] `flutter test` 基线不退化(≤ 4 fail / 3 文件);`flutter analyze` 不新增;测试全部在 `flutter test` 内(无 integration_test 目录)。

### Requirement: NFR-2 零 server 改动
- [ ] 本 feature SHALL NOT 改动 yucai/server;`go test ./...` 保持全绿。

## scope boundary

- **IN**:4 组判据命名集成测试(串联已交付组件,新组件仅测试脚手架)+人工清单文档。
- **OUT**:真机自动化(integration_test/设备农场——人工清单替代)/server 侧验证(mock 替代,真 server 联调归部署验收)/UI widget 级 e2e(页面测试已散布各 feature)。
- **依赖**:G/H/sprint-1/2 全部组件。

## 可行性

- **technical**:可行——全部组件已就位,串联即测试脚手架;mock 在 repo/DS 接口级(与既有单测同模式)。
- **economic**:最小——验收性质,无生产代码。
- **operational**:人工清单一次执行,release gate 归档。
