# Spec — F45 报告导出(R16 sprint-2)

> analysis 2026-09-28。grill 决策①用户确认(格式/管线/字体,含轻决策②③并入);技术调查实证:printing.layoutHtml Windows 桌面缺位→HTML 管线否决;报告页零 fl_chart(全 Container/表格)→pdf 同构映射;保存/打开有成熟先例(settings_page.dart:574 备份导出/debt_detail_page.dart:70 打开附件)。

## 需求(FR)

### Requirement: FR-1 双格式导出入口
报告页 Loaded 态 SHALL 提供「导出」按钮(page-head),唤起 FilePicker.saveFile 原生保存对话框,支持格式切换(.pdf/.md);默认文件名「御财财务报告-{期标签文件安全化}」(如 御财财务报告-2026年08月.pdf);取消=零副作用零文件写入。
- [ ] FR-1
  #### Scenario:
  - GIVEN 报告已生成 WHEN 点导出并选 .pdf THEN 对话框默认名「御财财务报告-2026年08月.pdf」,确认后文件落盘
  - GIVEN 导出对话框取消 THEN 无任何文件写入、无状态变化

### Requirement: FR-2 PDF 渲染(pdf 包直绘)
导出器 SHALL 将 ReportDocument 渲染为 A4 分页 PDF:七章节+总览摘要+口径/未包含附注,内容与页面同源同序;章节构成以**表格/条形(pw.Container 同构)**呈现(不引 fl_chart);中文以 **bundle 全量 Noto Sans SC** 字体渲染(零 tofu);章节起始于新页或明确分节;页脚含报告期+页码。
- [ ] FR-2
  #### Scenario:
  - GIVEN 含 mda 章节的 ReportDocument WHEN 渲染 THEN PDF 含七章节标题与关键数字(文本抽取断言:净资产/勾稽脚注/诊断计数),数字取自 VO 字段零重算
  - GIVEN 任意期报告 THEN 全文字形可渲染(无 tofu;字体资产断言)

### Requirement: FR-3 Markdown 渲染
导出器 SHALL 将同一 ReportDocument 渲染为 Markdown(标题层级/表格/附注引用块),内容与 PDF 同源;F46 LLM 输入友好(纯 UTF-8 文本)。
- [ ] FR-3
  #### Scenario:
  - GIVEN 同一 ReportDocument WHEN 导出 .md THEN 含七章节标题与关键数字,与 PDF 数字逐项一致(共享 VO 断言)

### Requirement: FR-4 导出后行为
导出成功 SHALL 给出反馈(toast)+「打开」入口(launchUrl(Uri.file),exists 检查;失败 toast 兜底照 debt_detail 先例);导出与打开经函数注入缝(照 feedback_launcher LaunchUrlFn 范式)可测。
- [ ] FR-4
  #### Scenario:
  - GIVEN 导出成功 THEN toast 含「打开」动作,点击用系统默认程序打开文件
  - GIVEN 文件被移动/删除 THEN 打开失败 toast 兜底,无崩溃

### Requirement: FR-5 同源保证
导出器 SHALL 仅消费 ReportDocument(渲染层零计算铁律延伸):无第二数据输入,无数字二次计算;页面/导出数字一致性由同一 VO 构造保证(评审+测试断言导出器 import 面)。
- [ ] FR-5
  #### Scenario:
  - GIVEN 代码评审/静态检查 THEN 导出器仅 import report domain 模型,零 store/repo/basis 输入

### Requirement: NFR-1 依赖与资产
新增依赖 SHALL 仅 `pdf`(纯 Dart,版本钉死+理由注释照 pubspec 惯例)+ 字体资产(assets/fonts/NotoSansSC 全量,~10MB 一次性);不新增任何带原生/win32 约束的包。
- [ ] NFR-1
### Requirement: NFR-2 性能
典型报告 PDF 生成(含字体加载)SHALL ≤2s(测试环境计时)。
- [ ] NFR-2
### Requirement: NFR-3 门
flutter 全绿+analyze 基线零新增+client-e2e(入口可达性)+proto/server 零 diff。
- [ ] NFR-3

## Scope boundary(排除项:owner+已权衡理由)

| 排除 | owner/拍板 | 理由(成本已权衡) |
|---|---|---|
| HTML 导出/HTML+打印管线 | 用户 2026-09-28(按推荐含否决) | printing.layoutHtml Windows 桌面缺位(调查实证),退化成 pdf+WebView 纯增成本 |
| 物理打印对话框(printing) | 同上 | 无打印诉求前不加;需要时过 win32 约束筛再加 |
| share_plus 分享 | YAGNI | 桌面单用户场景=保存+打开已覆盖 |
| 字体子集化 | 用户 2026-09-28 | 用户数据动态字(科目名/描述)有 tofu 风险;全量 ~10MB 换零风险离线 |
| 导出历史/批量导出 | YAGNI | backlog |

## Feasibility(裁决)

- **Technical: 可行** — pdf 纯 Dart 零原生;页面全 Container/表格→pw 同构;保存/打开先例逐字可抄。
- **Economic: 可行** — 一个纯 Dart 依赖+~10MB 字体资产(用户知情拍板);工作量中等(七章节双渲染器)。
- **Operational: 可行** — 纯读+单文件写;回滚=移除按钮与渲染器注册。

## Grill record(2026-09-28)

1. **格式/管线/字体=PDF 直绘+Noto 全量+Markdown 双格式,HTML 否决** — 挑战:pdf 中文必须内嵌字体(子集 tofu 风险/系统 ttc 许可+解析坑/全量 +10MB 体积);HTML 管线桌面 printing 缺位;辩护:pdf 同构映射+离线零 tofu 值 10MB 一次性;Markdown 近乎免费且为 F46 铺地基;用户「按推荐」确认(含轻决策②③:入口在 page-head/文件名惯例/导出后通知+打开;pdf 内表格条形同构不引 fl_chart)。
