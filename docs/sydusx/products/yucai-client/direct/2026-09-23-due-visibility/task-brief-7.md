# Task T8(fix+feature)— 账单日下拉预填修复 + 信用卡账单周期面板

用户 dev 验收两点:①编辑信用卡账户,原账单日/还款日没自动带入(表单 bug);②信用卡
账户应显示「上期账单/本期账单/上期已还/上期剩余」字段(银行 App 账单周期面板)。

项目:御财 Flutter 客户端 `yucai/client/`(design-v2 语义令牌零裸色;中文注释)。

## 已核事实

- **表单 bug 根因**:`account/presentation/widgets/category_fields.dart:170-179`
  `_dayPicker` 为 `DropdownButtonFormField<int>`,**未设 `value`**——只在 onChanged 写
  controller,从不回读显示;编辑态 controller 预填了 `"5"`(account_form_page:62-65
  已赋)但下拉显示空。数据不丢(提交读 controller),纯展示缺陷。proto 响应映射
  (mappers/account_mapper.dart:32-34)无恙,勿动。
- **账单口径现成**:`core/notifications/credit_card_statement.dart`
  `CreditCardStatementDue.compute`(T7):D=≤今天最近账单日;Δ=账单日后正向变动和
  (消费 S);应还(上期剩余)= max(0, current−S);还款分录为负不进 Δ(R 需另累计)。

## 交付物

### A. 下拉预填修复(小)
`_dayPicker` 增 `value: int.tryParse(ctrl.text)`(空串→null→显示 label,不炸);
修复后编辑态两下拉正确显示「N日」。补 widget 测:预填 5 → 显示「5日」;空 → 无选中。

### B. 账单周期推导扩展
`CreditCardStatementDue` 增值对象 + `breakdown()`:
```
CreditCardStatementBreakdown {
  DateTime billingDate;      // D(最近已过账单日)
  int statementCents;        // 上期账单 = current − S + R
  int repaidSinceCents;      // 上期已还 R = Σ|负向变动|(账单日后还款)
  int cycleNewCents;         // 本期账单(未出账)S = Σ正向变动
  int remainingCents;        // 上期剩余 = max(0, current − S)(=compute 现值)
}
```
- `compute()` 改为 `breakdown().remainingCents` 委托(既有消费方零改动);
- 不变式测试:current == remaining + cycleNew(钳零前;剩余钳 0 时列边界测);
- R 累计与 S 同一查询(一次 join,两个累加器)。

### C. 信用卡详情页面板
`account_detail_page.dart` 信用卡区(还款按钮/欠款显示附近,先读页面结构择位)加
「账单周期」面板(语义令牌,照页面既有面板/卡片范式):
- 四行:**上期账单** / **上期已还** / **上期剩余**(强调色——= 还款日应还,与催办/
  还款对话框同数)/ **本期账单(未出账)**;金额用库内 money 格式工具;
- 副标注一行:「账单日 D 日 · 还款日 M 日」(取卡字段);
- **账单日未设**:不渲染四行,降级一行 muted 提示「设置账单日后可查看账单周期明细」;
- 数据:经 B 的 breakdown(组合根/页面注入 db 计算皆可,照页面既有取数习惯);
  候选变化刷新面不必监听(详情页进出重拉,余额变更 RouteAware 既有)。

## TDD(强制)
A 预填两形;B breakdown 四值+不变式+边界(全还款/全消费/钳零)+compute 委托等价;
C 面板四行值与降级态+强调断言。修既有测试仅当口径扩展所致并注明。

## 完成门
1. `flutter test` 全量绿;2. `flutter analyze` 净增 0;
3. 最终回复:文件清单、测试数字、面板放置位置说明、偏离裁决。
