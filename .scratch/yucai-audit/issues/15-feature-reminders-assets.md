# 15 · 功能 gap · 提醒与资产(账单提醒 + 大件资产 + 拆单/附件/对账)

Type: grilling
Status: open
Blocked by: —

## Question

家庭场景特性 gap(详见 `findings.md` G4/G15 + G8/G9/G10/G11):

- **[G4 P0]** 账单到期提醒 + 日历视图:真缺。template autoRecord 引擎已建(只在到期日自动记账),缺"提前 N 天通知 + 即将到期日历"。家庭防漏账(信用卡还款日/水电煤/贷款月供)价值大。
- **[G15 P1]** 大件资产(房产/车辆/收藏品)净值追踪:真缺。家庭净值最大头(中国家庭房产占资产 70%+),holding(金融)与 account 都不适合存放。
- **[G8 P1]** 拆单 split transaction(一笔跨多类别):真缺(account-as-category 单分类)。超市一笔跨多类高频。
- **[G9 P1]** 凭证/发票/合同附件:真缺(本地路径挂接低成本)。
- **[G10 P1]** 对账 reconcile:真缺(无 cleared/reconciled flag)。私域桌面无银行同步,错误靠对账发现。
- **[G11 P1]** 预算超支提醒 + pace tracking + 滚动预算:已有 UI 缺智能提醒。

**决策点:**
1. 账单提醒:reminder 模块(到期前 N 天系统/UI 通知)+ 即将到期日历视图(颜色编码)?template 引擎复用。
2. 大件资产:新 `asset` 实体(估值 + 手动更新 + 历史曲线)进净值?与 holding 区分?
3. 拆单:多 entry 支持一笔跨多 category(复式记账天然支持)?account-as-category 适配?
4. 附件:本地文件路径挂接(不存图,低成本)vs 完整上传?
5. 对账:transaction 加 cleared/reconciled flag + reconcile workflow?
6. 是否走 prototype(OD)定型提醒日历 + 资产估值 UI?
