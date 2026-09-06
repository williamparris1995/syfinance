# Sprint 4 — R8 生产疑点修复批

> Sprint Goal + feature roster。`/sydusx-portfolio`(2026-09-03)。来源:F6 测试暴露+多轮 review 累积的 defer 区生产疑点与测试债。

## Sprint Goal

清零 defer 区的可修生产疑点(#1 订阅管理路由真 bug/#2 endDate 永续语义/#3#4 列表不回拉)+ 测试债两件(goPage 重复/三套件删库迁移),回归门全绿。

## Feature roster

- [x] **feature F14** defect-batch — 生产疑点修复批+测试债收口 ✅ done(2026-09-03,merge `79726748`;#1 订阅管理路由真 bug/#2 endDate 永续语义[对齐 server+update 清空修正]/#3#4 表单回拉[附带修 TradeSheet 从不自动 pop 潜伏 bug]/goPage 12 文件收口/三套件 tearDown 迁移+守卫;TDD 14 新测,门全绿)

## defer

- 疑点 #5 typeFilter 粗分类(inferFlavour 架构级重做,ticket 16 线一并评估)
- 疑点 #6 账户下拉异步空窗(自愈,cosmetic)

## status: done(F14 ✅ 2026-09-03——sprint-4 收官,F6 defer 区可修项清零)
