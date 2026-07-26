# 13 · 功能 gap · 数据进出(导出 + 搜索 + PDF + 导入)

Type: grilling
Status: open
Blocked by: —

## Question

行业底线功能缺失,家庭数据所有权与查账刚需(详见 `findings.md` G1/G5/G6/G7):

- **[G1 P0]** 数据导出 CSV/Excel/PDF:行业 100% 标配,真缺(backup 仅内部 JSON,不可移植)。家庭数据所有权底线(去世/迁移/给会计师/审计)。
- **[G5 P0]** 全局搜索 + 高级筛选:真缺(Phase4 规划未做)。家庭查账刚需("上个月孩子补习班花了多少"、"那笔 5000 家电是几号")。
- **[G6 P0]** 报表 PDF 导出 / 现金流表:真缺(report 有图表 monthly_comparison/category_breakdown/asset_allocation,无输出)。复盘/报税/给会计。
- **[G7 P1]** 银行流水导入 CSV/OFX/QFX/Excel + 规则自动分类:真缺,迁移成本高(从挖财/随手记/Excel 搬全靠手敲 = 劝退)。

**决策点:**
1. 导出优先级与格式:CSV(交易流水)先行 / Excel / PDF(报表)?复用 backup exporter 序列化?
2. 全局搜索:server query DSL(金额区间/备注 contains/商户/标签/日期组合)+ client search bar?
3. 报表 PDF:正式 Cash Flow Statement / Balance Sheet 格式 + 打印?
4. 导入:CSV/Excel + 规则映射(分类/商户/标签自动匹配)优先(国内 OFX/QFX 意义低)?
5. UI 是否走 prototype(OD)先定型(报表/搜索/导入向导 UI)?
