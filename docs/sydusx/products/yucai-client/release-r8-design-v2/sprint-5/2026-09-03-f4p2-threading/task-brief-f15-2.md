# Task Brief F15-T2 — 模块页迁移 + 调色板常量裁决

> 工作目录:`C:\Users\BuHiYo-001\Desktop\projects\desktop\syfinance\.claude\worktrees\r8-f15`,客户端 `yucai/client/`。T1(core/widgets 清零)已就绪。

## 范围
`grep -rln "AppColors\." lib/ | grep -v app_design` 的全部剩余文件(account/auth/backup/debt/holding/goal/report/tag/template/currency 等模块页+widgets,约 280 处)+ 顶层调色板常量。

## 迁移规则(照 T1/F4 惯例)
- AppColors→context.yucai(accentHover→accentDeep 等值映射照 T1);裸 Color(0x 按 T1 豁免标准裁决(固定深色面/黑阴影豁免+注释;其余迁)。
- **顶层调色板常量**:kHoldingTypeColors/kCategoryColors 等(先 grep 全集)——数据可视化序列色:亮板保原值,暗板提亮适配(照 T1 kRingGoldGradient 双板模式:常量→context 感知 accessor 或 YucaiTheme 加序列色组——落点自选注释理由);非序列色的静态常量直接语义令牌化。
- context 穿线照 T1;const 失效去 const;调用点全更新。

## T1 review 遗留顺手项(一并做)
1. debt_detail_widgets.dart 文件头豁免清单补黑阴影条目;amortization_preview.dart 清单补 0x17000000。
2. 范围外 4 文件裸色:app_toast(0xFFCF9B3A 金裁决:近 v2 accentDeep 亮值则映射,固定深面则豁免注释)/form_section/data_card/yucai_menu(黑阴影类复用论证)。
3. ringGoldGradientOf/_kRingGoldGradientDark 为前瞻 API 零消费方——勿删,注释保留。

## 验证
1. `flutter test` 全量(≥1463;静态色断言只许改令牌断言不许删)
2. `flutter analyze` 0 新增
3. `grep -rn "AppColors\." lib/ | grep -v app_design | wc -l` 代码引用=0(纯注释豁免行除外,汇总最终豁免总清单写进 feature.md ledger)
4. theme-follow 探针 +1 条(选一个迁移后模块页组件的暗色断言)
5. `make client-e2e F=integration_test/app_pages_test.dart` 抽验

## 约束
不动 core/widgets 已迁件(除豁免注释补);中文注释;不 commit。完成后报告(含豁免总清单/调色板裁决)。
