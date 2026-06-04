# 表单多币种支持实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除5个表单中的硬编码 `CNY`，改为账户驱动货币。

**Architecture:** 每个表单通过 `useMemo` 监听所选账户的 `currency_code`，动态计算当前货币符号。无独立货币选择器——货币由账户决定。

**Tech Stack:** React 18, TypeScript, Tailwind CSS, shadcn/ui, i18next

---

## 文件结构

| 文件 | 动作 | 责任 |
|------|------|------|
| `src/components/SimpleTransactionForm.tsx` | 修改 | 交易表单：金额符号跟随 ownAccountId / fromAccountId |
| `src/components/DebtForm.tsx` | 修改 | 债务表单：移除 hidden 货币字段，改为账户驱动 |
| `src/components/HoldingTradeForm.tsx` | 修改 | 投资组合表单：价格符号跟随 investment account |
| `src/components/TransactionTemplateForm.tsx` | 修改 | 模板表单：金额符号跟随 source_account_id |
| `src/components/TopUpDialog.tsx` | 修改 | 充值表单：金额符号跟随 target account |

---

## Task 1: SimpleTransactionForm — 交易表单

**Files:**
- Modify: `src/components/SimpleTransactionForm.tsx`

**Context:** 当前金额输入和提交按钮都硬编码 `getCurrencySymbol('CNY')`。Account 接口已有 `currency_code: string`。

- [ ] **Step 1: 添加动态货币计算**

在 `SimpleTransactionForm` 组件中（`selectedOwnAccount` 之后），添加 `useMemo` 计算交易货币：

```typescript
  // Dynamic currency based on selected account
  const transactionCurrency = useMemo(() => {
    if (type === 'transfer') {
      return accounts.find(a => a.id === fromAccountId)?.currency_code || 'CNY';
    }
    return accounts.find(a => a.id === ownAccountId)?.currency_code || 'CNY';
  }, [accounts, type, fromAccountId, ownAccountId]);
```

需要确保 `useMemo` 已导入（检查是否已有 `useMemo` import，如果没有添加）。

- [ ] **Step 2: 替换金额输入的硬编码 CNY**

找到金额输入区域（约第234行），将：

```tsx
<span className="text-3xl font-bold text-foreground/80">{getCurrencySymbol('CNY')}</span>
```

替换为：

```tsx
<span className="text-3xl font-bold text-foreground/80">{getCurrencySymbol(transactionCurrency)}</span>
```

- [ ] **Step 3: 替换提交按钮的硬编码 CNY**

找到提交按钮（约第387-390行），将：

```tsx
type === 'expense'
  ? `${t('transaction.recordExpense')} — ${getCurrencySymbol('CNY')}${amount || '0'}`
  : type === 'income'
    ? `${t('transaction.recordIncome')} — ${getCurrencySymbol('CNY')}${amount || '0'}`
    : `${t('transaction.recordTransfer')} — ${getCurrencySymbol('CNY')}${amount || '0'}`
```

替换为：

```tsx
type === 'expense'
  ? `${t('transaction.recordExpense')} — ${getCurrencySymbol(transactionCurrency)}${amount || '0'}`
  : type === 'income'
    ? `${t('transaction.recordIncome')} — ${getCurrencySymbol(transactionCurrency)}${amount || '0'}`
    : `${t('transaction.recordTransfer')} — ${getCurrencySymbol(transactionCurrency)}${amount || '0'}`
```

- [ ] **Step 4: 验证 TypeScript 编译**

Run: `pnpm type-check`
Expected: No errors in `SimpleTransactionForm.tsx`

- [ ] **Step 5: 提交**

```bash
git add src/components/SimpleTransactionForm.tsx
git commit -m "feat(forms): use account currency in SimpleTransactionForm

- Add transactionCurrency useMemo derived from selected account
- Replace hardcoded CNY with dynamic currency symbol
- Covers amount input and submit button

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: DebtForm — 债务表单

**Files:**
- Modify: `src/components/DebtForm.tsx`

**Context:** `currency_code` 是 hidden input（第309行），默认 `'CNY'`。债务账户选择后应自动同步货币。

- [ ] **Step 1: 添加账户货币同步 effect**

在 `DebtForm` 中，找到 `useEffect` 区域（在现有 account_id effect 之后），添加：

```typescript
  // Auto-sync currency_code from selected debt account
  useEffect(() => {
    if (!isEdit && !readOnly && account_id) {
      const selectedAccount = debtAccounts.find(a => a.id === account_id);
      if (selectedAccount?.currency_code) {
        form.setValue('currency_code', selectedAccount.currency_code);
      }
    }
  }, [account_id, debtAccounts, form, isEdit, readOnly]);
```

- [ ] **Step 2: 将 hidden 字段改为只读展示**

找到隐藏的 currency_code 字段（第309行）：

```tsx
<input type="hidden" {...form.register('currency_code')} />
```

替换为可见的只读货币展示（放在"对手方"字段之后）：

```tsx
            <FormItem>
              <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">
                {t('common.currency')}
              </FormLabel>
              <div className="flex items-center rounded-lg border overflow-hidden h-9 bg-muted/30">
                <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol(selectedCurrencyCode || 'CNY')}</span>
                <span className="flex-1 px-2.5 text-sm text-muted-foreground">{selectedCurrencyCode || 'CNY'}</span>
              </div>
            </FormItem>
```

- [ ] **Step 3: 验证 TypeScript 编译**

Run: `pnpm type-check`
Expected: No errors in `DebtForm.tsx`

- [ ] **Step 4: 提交**

```bash
git add src/components/DebtForm.tsx
git commit -m "feat(forms): account-driven currency in DebtForm

- Auto-sync currency_code from selected debt account
- Replace hidden currency field with read-only display
- Amount display uses account currency

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: HoldingTradeForm — 投资组合交易表单

**Files:**
- Modify: `src/components/HoldingTradeForm.tsx`

**Context:** 创建证券时硬编码 `currency_code: 'CNY'`（第134行）。价格输入无货币符号。

- [ ] **Step 1: 添加动态货币计算**

在 `HoldingTradeForm` 组件中，在 `accountNameMap` 之后添加：

```typescript
  const tradeCurrency = useMemo(() => {
    return investmentAccounts.find(a => a.id === watched.account_id)?.currency_code || 'CNY';
  }, [investmentAccounts, watched.account_id]);
```

- [ ] **Step 2: 修改创建证券时的货币**

找到 `handleCreateSecurity` 中（第134行），将：

```typescript
currency_code: 'CNY',
```

替换为：

```typescript
currency_code: tradeCurrency,
```

- [ ] **Step 3: 在价格输入旁添加货币符号**

找到价格输入区域（约第298行），将：

```tsx
<FormField name="price" render={({ field }) => (
  <FormItem>
    <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.price')} <span className="text-red-500">*</span></FormLabel>
    <FormControl><Input type="number" step="any" className="h-9" {...field} /></FormControl>
    <FormMessage />
  </FormItem>
)} />
```

替换为：

```tsx
<FormField name="price" render={({ field }) => (
  <FormItem>
    <FormLabel className="text-xs uppercase tracking-wider text-muted-foreground">{t('holding.price')} <span className="text-red-500">*</span></FormLabel>
    <FormControl>
      <div className="flex items-center rounded-lg border overflow-hidden h-9">
        <span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol(tradeCurrency)}</span>
        <input type="number" step="any" className="flex-1 border-0 bg-transparent px-2.5 text-sm outline-none" {...field} />
      </div>
    </FormControl>
    <FormMessage />
  </FormItem>
)} />
```

- [ ] **Step 4: 在预估金额旁添加货币符号**

找到预估金额展示（约第324行），将：

```tsx
<div className="text-xs text-muted-foreground">{t('holding.estimatedAmountDisplay', { value: estimatedAmount.toLocaleString('en-US', { minimumFractionDigits: 2 }) })}</div>
```

替换为：

```tsx
<div className="text-xs text-muted-foreground">{t('holding.estimatedAmountDisplay', { value: estimatedAmount.toLocaleString('en-US', { minimumFractionDigits: 2 }), currency: getCurrencySymbol(tradeCurrency) })}</div>
```

> **Note:** 如果 `estimatedAmountDisplay` i18n key 不支持 `currency` 参数，只替换 `value` 部分，保持原有结构。

- [ ] **Step 5: 验证 TypeScript 编译**

Run: `pnpm type-check`
Expected: No errors in `HoldingTradeForm.tsx`

- [ ] **Step 6: 提交**

```bash
git add src/components/HoldingTradeForm.tsx
git commit -m "feat(forms): account-driven currency in HoldingTradeForm

- Trade currency derived from selected investment account
- Security creation uses account currency instead of hardcoded CNY
- Price input shows account currency symbol

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: TransactionTemplateForm — 交易模板表单

**Files:**
- Modify: `src/components/TransactionTemplateForm.tsx`

**Context:** 金额输入硬编码 `getCurrencySymbol('CNY')`（第234行）。模板有 `source_account_id` 字段决定货币。

- [ ] **Step 1: 添加动态货币计算**

在 `TransactionTemplateForm` 组件中，在 `watchedDirection` 之后添加：

```typescript
  const watchedSourceAccount = form.watch('source_account_id');

  const templateCurrency = useMemo(() => {
    return accounts.find(a => a.id === watchedSourceAccount)?.currency_code || 'CNY';
  }, [accounts, watchedSourceAccount]);
```

- [ ] **Step 2: 替换金额输入的硬编码 CNY**

找到金额输入区域（约第233行），将：

```tsx
<span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">
  {getCurrencySymbol('CNY')}
</span>
```

替换为：

```tsx
<span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">
  {getCurrencySymbol(templateCurrency)}
</span>
```

- [ ] **Step 3: 验证 TypeScript 编译**

Run: `pnpm type-check`
Expected: No errors in `TransactionTemplateForm.tsx`

- [ ] **Step 4: 提交**

```bash
git add src/components/TransactionTemplateForm.tsx
git commit -m "feat(forms): account-driven currency in TransactionTemplateForm

- Template currency derived from selected source account
- Replace hardcoded CNY in amount input

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: TopUpDialog — 充值表单

**Files:**
- Modify: `src/components/TopUpDialog.tsx`

**Context:** `paid_amount` 和 `bonus_amount` 都硬编码 `getCurrencySymbol('CNY')`。`formatCurrency(totalCredited, 'CNY')` 也硬编码。组件接收 `accountId` prop，可以查询目标账户货币。

- [ ] **Step 1: 获取目标账户货币**

在 `TopUpDialog` 组件中，在 `accounts` query 之后添加：

```typescript
  const targetAccount = useMemo(() => {
    return accounts.find(a => a.id === accountId);
  }, [accounts, accountId]);

  const topUpCurrency = targetAccount?.currency_code || 'CNY';
```

- [ ] **Step 2: 替换 paid_amount 的硬编码 CNY**

找到 `paid_amount` 输入（约第174行），将：

```tsx
<span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol('CNY')}</span>
```

替换为：

```tsx
<span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol(topUpCurrency)}</span>
```

- [ ] **Step 3: 替换 bonus_amount 的硬编码 CNY**

找到 `bonus_amount` 输入（约第200行），将：

```tsx
<span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol('CNY')}</span>
```

替换为：

```tsx
<span className="px-2.5 text-sm text-muted-foreground bg-muted/50 border-r">{getCurrencySymbol(topUpCurrency)}</span>
```

- [ ] **Step 4: 替换 totalCredited 的硬编码 CNY**

找到总额展示（约第222行），将：

```tsx
{formatCurrency(totalCredited, 'CNY')}
```

替换为：

```tsx
{formatCurrency(totalCredited, topUpCurrency)}
```

- [ ] **Step 5: 验证 TypeScript 编译**

Run: `pnpm type-check`
Expected: No errors in `TopUpDialog.tsx`

- [ ] **Step 6: 提交**

```bash
git add src/components/TopUpDialog.tsx
git commit -m "feat(forms): account-driven currency in TopUpDialog

- Top-up currency derived from target account (accountId prop)
- Replace hardcoded CNY in paid_amount, bonus_amount, and total display

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

### Spec Coverage

| Spec Section | 实现任务 |
|-------------|---------|
| SimpleTransactionForm 动态货币 | Task 1 |
| DebtForm 账户驱动货币 | Task 2 |
| HoldingTradeForm 账户驱动货币 | Task 3 |
| TransactionTemplateForm 动态货币 | Task 4 |
| TopUpDialog 账户驱动货币 | Task 5 |

### Placeholder Scan

- ✅ 无 "TBD", "TODO", "implement later"
- ✅ 每个步骤包含实际代码
- ✅ 每个步骤包含运行命令和预期输出
- ✅ 无 "Similar to Task N"

### Type Consistency

- ✅ `transactionCurrency`、`templateCurrency`、`tradeCurrency`、`topUpCurrency` 均为 `string`
- ✅ `getCurrencySymbol()` 参数类型一致为 `string`
- ✅ `formatCurrency()` 参数类型一致为 `(number, string)`
- ✅ `currency_code` 在 AccountDto 中为 `string`

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-04-multi-currency-forms.md`.**

**Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
