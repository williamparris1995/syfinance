# 个人财务管理系统 - 产品设计方案

## 目标用户
个人用户

## 核心价值主张
- 简单易用，无需会计知识
- 智能提醒，不错过任何还款日
- AI助手，自动记账和分析
- 全面管理：信用卡、贷款、投资、个税

---

## Phase 1: 核心数据模型（方案2实施）

### Account（用户账户）
```rust
pub struct Account {
    pub id: Uuid,
    pub name: String,              // "招商银行信用卡"
    pub account_type: AccountType, // Bank, CreditCard, Cash, Investment
    pub account_number: Option<String>, // 卡号（后4位）
    pub institution: Option<String>,    // 银行名称
    pub balance: Money,
    pub credit_limit: Option<Money>,    // 信用额度
    pub billing_day: Option<u8>,        // 账单日
    pub payment_due_day: Option<u8>,    // 还款日
    pub interest_rate: Option<Decimal>, // 利率
    // ❌ 移除 chart_of_account_code
}
```

### Category（分类）
```rust
pub struct Category {
    pub id: Uuid,
    pub name: String,              // "餐饮"
    pub icon: String,              // "🍔"
    pub color: String,             // "#FF5733"
    pub category_type: CategoryType, // Income, Expense
    pub chart_code: String,        // 自动映射到会计科目
    pub parent_id: Option<Uuid>,   // 支持子分类
}
```

### Transaction（交易）
```rust
pub struct Transaction {
    pub id: Uuid,
    pub date: NaiveDate,
    pub description: String,
    pub amount: Money,
    pub from_account_id: Option<Uuid>, // 来源账户
    pub to_account_id: Option<Uuid>,   // 目标账户
    pub category_id: Option<Uuid>,     // 分类
    pub tags: Vec<String>,             // 标签
    pub location: Option<String>,      // 地点
    pub receipt_url: Option<String>,   // 收据照片
    pub is_recurring: bool,            // 是否循环
}
```

### Reminder（提醒）
```rust
pub struct Reminder {
    pub id: Uuid,
    pub reminder_type: ReminderType,
    pub account_id: Option<Uuid>,
    pub amount: Option<Money>,
    pub due_date: NaiveDate,
    pub advance_days: u8,            // 提前几天提醒
    pub is_recurring: bool,
    pub recurrence_rule: Option<String>,
}

pub enum ReminderType {
    CreditCardPayment,    // 信用卡还款
    LoanPayment,          // 贷款还款
    BillDue,              // 账单到期
    BudgetAlert,          // 预算超支
    InvestmentAlert,      // 投资提醒
    RecurringTransaction, // 循环交易
}
```

---

## Phase 2: 重点功能设计

### 1. 💳 信用卡管理

**功能清单**：
- ✅ 自动计算账单日和还款日
- ✅ 还款提醒（提前3天、1天、当天）
- ✅ 可用额度实时显示
- ✅ 本期账单预览
- ✅ 分期付款管理
- ✅ 积分管理

**UI设计**：
```
┌─────────────────────────────────────┐
│ 💳 招商银行信用卡                    │
│                                     │
│ 可用额度  ¥8,440 / ¥20,000         │
│ ████████████░░░░░░░░ 42%           │
│                                     │
│ 本期账单  ¥11,560                   │
│ 还款日期  2026-05-25 (18天后)      │
│ [立即还款]  [查看明细]              │
│                                     │
│ 🔔 提醒已设置：提前3天通知           │
└─────────────────────────────────────┘
```

---

### 2. 🏦 贷款管理

**功能清单**：
- ✅ 贷款总额和剩余本金
- ✅ 还款计划表（等额本息/等额本金）
- ✅ 已还利息统计
- ✅ 提前还款计算器
- ✅ 还款提醒

**数据模型**：
```rust
pub struct Loan {
    pub id: Uuid,
    pub account_id: Uuid,
    pub loan_type: LoanType,      // Mortgage, PersonalLoan, CarLoan
    pub principal: Money,          // 贷款本金
    pub interest_rate: Decimal,    // 年利率
    pub term_months: u32,          // 贷款期限（月）
    pub payment_method: PaymentMethod, // 等额本息/等额本金
    pub start_date: NaiveDate,
    pub monthly_payment: Money,
}
```

---

### 3. 📊 投资管理

**功能清单**：
- ✅ 持仓总览
- ✅ 收益率计算
- ✅ 成本价追踪
- ✅ 分红记录
- ✅ 实时行情（可选）
- ✅ 投资组合分析

**数据模型**：
```rust
pub struct Investment {
    pub id: Uuid,
    pub investment_type: InvestmentType, // Stock, Fund, Option, Bond
    pub symbol: String,              // "600519.SH"
    pub name: String,                // "贵州茅台"
    pub quantity: Decimal,           // 持仓数量
    pub cost_basis: Money,           // 成本价
    pub current_price: Option<Money>, // 当前价
    pub account_id: Uuid,
}
```

---

### 4. 💰 个税计算

**功能清单**：
- ✅ 工资薪金个税计算
- ✅ 专项附加扣除（子女教育、房贷利息等）
- ✅ 年度汇算清缴
- ✅ 个税优化建议

**数据模型**：
```rust
pub struct TaxCalculation {
    pub monthly_income: Money,
    pub social_insurance: Money,     // 五险一金
    pub special_deductions: Vec<SpecialDeduction>,
    pub taxable_income: Money,
    pub tax_amount: Money,
    pub net_income: Money,
}

pub struct SpecialDeduction {
    pub deduction_type: DeductionType,
    pub amount: Money,
}

pub enum DeductionType {
    ChildEducation,      // 子女教育
    ContinuingEducation, // 继续教育
    MedicalExpenses,     // 大病医疗
    HousingLoanInterest, // 住房贷款利息
    HousingRent,         // 住房租金
    ElderCare,           // 赡养老人
}
```

---

### 5. 🔔 智能提醒系统

**提醒策略**：
- 提前7天、3天、1天、当天
- 推送通知 + 应用内通知
- 可自定义提醒时间

**实现**：
```rust
pub struct ReminderService {
    // 每日检查到期提醒
    pub fn check_due_reminders(&self) -> Vec<Reminder>;
    
    // 发送通知
    pub fn send_notification(&self, reminder: &Reminder);
    
    // 创建循环提醒
    pub fn create_recurring_reminder(&self, reminder: Reminder);
}
```

---

### 6. 🤖 AI Agent 集成

**AI功能**：

#### A. 智能记账助手
```
用户: "今天午餐花了35块"
AI: 已记录：
    - 金额：¥35
    - 分类：餐饮 🍔
    - 账户：招商银行卡
    - 时间：2026-05-07 12:30
    [确认] [修改]
```

#### B. 财务分析师
```
用户: "分析一下我这个月的支出"
AI: 📊 5月支出分析：
    
    总支出：¥8,500
    较上月：+15% ⚠️
    
    主要支出：
    1. 餐饮 ¥2,100 (25%) 📈 较上月+30%
    2. 交通 ¥1,500 (18%)
    3. 购物 ¥1,200 (14%)
    
    💡 建议：
    - 餐饮支出增长较快，建议控制外卖频率
    - 可设置餐饮预算 ¥1,800/月
```

#### C. 投资顾问
```
用户: "我的投资组合风险如何？"
AI: 📈 投资组合分析：
    
    风险等级：中等
    
    资产配置：
    - 股票 60% (偏高)
    - 基金 30%
    - 现金 10% (偏低)
    
    💡 建议：
    - 股票占比过高，建议降至50%
    - 增加债券或货币基金配置
    - 保持3-6个月应急资金
```

---

### 7. 📥 导入导出

**支持格式**：
- ✅ CSV（银行流水）
- ✅ Excel
- ✅ PDF（账单识别）
- ✅ JSON（完整数据）
- ✅ QIF/OFX（标准格式）

**智能导入流程**：
1. 上传银行CSV
2. AI自动识别列（日期、金额、描述）
3. AI自动分类交易
4. 用户确认后导入

---

### 8. 🧮 智能计算器

**计算器类型**：
- ✅ 贷款计算器（等额本息/等额本金）
- ✅ 提前还款计算器
- ✅ 投资收益计算器
- ✅ 个税计算器
- ✅ 汇率转换器
- ✅ 复利计算器

---

## Phase 3: UI/UX 设计原则

### 设计语言

**色彩系统**：
```
主色调：
- 收入：#10B981 (绿色)
- 支出：#EF4444 (红色)
- 中性：#6B7280 (灰色)
- 强调：#3B82F6 (蓝色)

分类图标：
- 餐饮 🍔 #FF6B6B
- 交通 🚗 #4ECDC4
- 购物 🛍️ #FFE66D
- 娱乐 🎮 #A8E6CF
```

**交互原则**：
1. **一键操作**：常用功能一键完成
2. **手势支持**：滑动删除、长按编辑
3. **即时反馈**：操作后立即显示结果
4. **智能建议**：AI主动提供建议

---

## 实施计划

### Week 1-2: 架构重构
- [ ] 重构Account模型（移除chart_of_account_code）
- [ ] 创建Category模型
- [ ] 修改Transaction模型
- [ ] 数据库迁移脚本
- [ ] 更新所有Service和Repository

### Week 3-4: 核心功能
- [ ] 信用卡管理
- [ ] 贷款管理
- [ ] 提醒系统
- [ ] 个税计算器

### Week 5-6: 投资功能
- [ ] 投资账户管理
- [ ] 持仓追踪
- [ ] 收益计算

### Week 7-8: AI集成
- [ ] AI记账助手
- [ ] 智能分析
- [ ] 自动分类

### Week 9-10: 导入导出
- [ ] CSV导入
- [ ] PDF识别
- [ ] 数据导出

### Week 11-12: UI优化
- [ ] 重新设计所有页面
- [ ] 添加动画和过渡
- [ ] 移动端适配
