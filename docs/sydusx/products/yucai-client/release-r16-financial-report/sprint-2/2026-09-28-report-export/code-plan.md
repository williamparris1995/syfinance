# Code Plan — F45 报告导出

> execute 2026-09-28。依据 spec(FR-1..5/NFR-1..3)+design(ADR-1..5)。零 proto/server;新依赖仅 pdf+字体资产。

## 任务分解

- [ ] **T1 export 域+资产**(S1/S2 核心):pubspec +pdf(钉死注释)+assets/fonts/NotoSansSC-Regular.ttf(**static 实例,首步字形冒烟校验**);`lib/report/export/` 四文件(布局树 build/两渲染器/service);布局树全章节手算 oracle 单测+Markdown 字符串断言+PDF smoke(非空/页数/字体)。
- [ ] **T2 presentation 接线**(S3 前半):报告页「导出」按钮(Loaded 态,page-head 形态)+handler(FileSavePickerFn/launchUrlFn 注入缝,照 settings/feedback 先例)+toast+打开;widget 测试(按钮态/文件名/缝替换)。
- [ ] **T3 门与收尾**(S4):NFR-2 计时测试;e2e 入口可达断言;全门五项证据(全量/analyze stash 对比/e2e/proto 零 diff/build_runner 幂等——本票无 injectable 变更则跳过 regen 项)。

## 依赖

T1→T2→T3 串行;每 task 两轴评审+修复回路。

## 验收映射

FR-1→T2;FR-2/FR-3→T1;FR-4→T2;FR-5→T1(布局树单源)+评审;NFR-1→T1;NFR-2/3→T3。
