# 表单多币种支持设计文档

**日期:** 2026-06-04  
**状态:** 已批准  
**作者:** Claude Code  
**范围:** 交易、债务、投资组合、交易模板、充值表单

---

## 1. 背景与目标

### 1.1 当前问题

后端 `accounts` 表已支持 `currency_code`，且 `currencies` 表已存储多币种数据。但前端表单中所有金额显示和货币选择都硬编码为 `CNY`：

- `SimpleTransactionForm`：金额输入和提交按钮使用 `getCurrencySymbol('CNY')`
- `DebtForm`：`currency_code` 是 hidden 字段，默认 `'CNY'`，用户不可选
- `HoldingTradeForm`：创建证券时硬编码 `currency_code: 'CNY'`，价格输入无货币符号
- `TransactionTemplateForm`：金额输入硬编码 CNY
- `TopUpDialog`：金额输入和总额硬编码 CNY

### 1.2 设计目标

消除表单中的硬编码 `CNY`，改为**账户驱动货币**——表单货币由用户所选账户的 `currency_code` 决定。

### 1.3 核心原则

> **"钱在哪，货币就是哪"** —— 每个账户只有一种记账本位币，表单跟随账户货币。

---

## 2. 方案设计

### 2.1 架构决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 货币来源 | 账户的 `currency_code` | 符合复式记账原则，避免"美元交易记入人民币账户"的数据不一致 |
| 货币选择器 | 无独立选择器，只读展示 | 由账户决定，用户不可覆盖，保持数据一致性 |
| 默认值 | 跟随第一个选中账户 | 表单初始化时，根据默认选中账户显示对应货币 |

### 2.2 数据流

```
用户选择账户 → 读取 account.currency_code → 
更新表单货币状态 → 金额输入符号同步更新 → 
提交时货币代码随账户一并传递
```

---

## 3. 各表单修改详情

### 3.1 SimpleTransactionForm（交易表单）

**文件:** `src/components/SimpleTransactionForm.tsx`

**修改点:**
1. 金额区域：移除硬编码 `getCurrencySymbol('CNY')`，改为根据所选账户动态获取
   - 收入/支出：以 `ownAccountId` 对应的账户货币为准
   - 转账：以 `fromAccountId` 对应的账户货币为准
2. 提交按钮：移除硬编码 `getCurrencySymbol('CNY')`，使用动态货币
3. 无货币选择器：货币由账户决定，只读展示

**代码变更:**
```typescript
// 添加 derived currency code
const transactionCurrency = useMemo(() => {
  if (type === 'transfer') {
    return accounts.find(a => a.id === fromAccountId)?.currency_code || 'CNY';
  }
  return accounts.find(a => a.id === ownAccountId)?.currency_code || 'CNY';
}, [accounts, type, fromAccountId, ownAccountId]);

// 金额显示
<span>{getCurrencySymbol(transactionCurrency)}</span>
```

### 3.2 DebtForm（债务表单）

**文件:** `src/components/DebtForm.tsx`

**修改点:**
1. 移除隐藏的 `currency_code` input，改为从债务账户自动同步
2. 选择债务账户后，自动设置 `form.setValue('currency_code', account.currency_code)`
3. 本金、月供、总利息全部使用该货币
4. 在表单中展示当前货币代码（只读）

**代码变更:**
```typescript
useEffect(() => {
  if (account_id) {
    const account = debtAccounts.find(a => a.id === account_id);
    if (account) {
      form.setValue('currency_code', account.currency_code || 'CNY');
    }
  }
}, [account_id, debtAccounts]);
```

### 3.3 HoldingTradeForm（投资组合交易表单）

**文件:** `src/components/HoldingTradeForm.tsx`

**修改点:**
1. 选择投资账户后，价格输入显示该账户货币符号
2. 创建证券时的 `currency_code` 跟随投资账户货币
3. 预估金额显示账户货币

**代码变更:**
```typescript
const tradeCurrency = useMemo(() => {
  return investmentAccounts.find(a => a.id === watched.account_id)?.currency_code || 'CNY';
}, [investmentAccounts, watched.account_id]);

// 创建证券时
createSecurity({
  ...,
  currency_code: tradeCurrency,
});
```

### 3.4 TransactionTemplateForm（交易模板表单）

**文件:** `src/components/TransactionTemplateForm.tsx`

**修改点:**
1. 与 SimpleTransactionForm 保持一致
2. 选择源账户后，金额符号自动切换

### 3.5 TopUpDialog（充值对话框）

**文件:** `src/components/TopUpDialog.tsx`

**修改点:**
1. 选择充值目标账户后，金额符号跟随该账户货币
2. 总额显示使用该货币

---

## 4. 文件清单

| 文件 | 动作 | 说明 |
|------|------|------|
| `src/components/SimpleTransactionForm.tsx` | 修改 | 动态货币符号 |
| `src/components/DebtForm.tsx` | 修改 | 账户驱动货币，移除 hidden 字段 |
| `src/components/HoldingTradeForm.tsx` | 修改 | 账户驱动货币，价格显示符号 |
| `src/components/TransactionTemplateForm.tsx` | 修改 | 动态货币符号 |
| `src/components/TopUpDialog.tsx` | 修改 | 账户驱动货币 |

---

## 5. 测试策略

### 5.1 手动测试场景

1. 创建 CNY 账户和 USD 账户
2. 在交易表单中选择 USD 账户，确认金额显示 `$`
3. 在债务表单中选择 USD 债务账户，确认本金显示 `$`
4. 在投资组合交易表单中选择 USD 投资账户，确认价格显示 `$`

### 5.2 边界情况

- 无账户选中时：默认回退到 `CNY`
- 账户无 currency_code 时：回退到 `CNY`
- 转账时切换转出账户：货币符号应同步更新

---

## 6. 未来扩展（不在本次范围）

- 页面级货币显示：`HomePage`、`HoldingsPage`、`ReportsPage` 中的硬编码 CNY（需全局汇率转换支持）
- 货币转换交易：跨币种转账时的汇率处理
