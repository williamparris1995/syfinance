# Sprint 6: Code Quality Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate all i18n violations (66 hardcoded strings), remove dead code (legacy debt.rs, global suppressions), and enforce DDD architecture (create GoalService, refactor BudgetService).

**Architecture:** Three independent tasks executed sequentially. Task 21 (i18n) touches 8 frontend files + 2 locale files. Task 22 (dead code) touches 7 Rust files. Task 23 (DDD refactor) creates 1 new Rust service and modifies 3 existing Rust files. Each task ends with a commit.

**Tech Stack:** React + i18next (frontend), Rust + Tauri + SQLx (backend)

---

## Task 21: i18n — Replace Hardcoded Strings with Translation Keys

**Files:**
- Modify: `src/i18n/locales/en.json`
- Modify: `src/i18n/locales/zh.json`
- Modify: `src/hooks/useGoal.ts`
- Modify: `src/hooks/useBudget.ts`
- Modify: `src/hooks/useCurrency.ts`
- Modify: `src/hooks/useTag.ts`
- Modify: `src/hooks/useTransactionTemplate.ts`
- Modify: `src/hooks/useReminder.ts`
- Modify: `src/pages/GoalsPage.tsx`
- Modify: `src/components/SimpleTransactionForm.tsx`

### Step 1: Add i18n keys to en.json

Add the following keys inside `en.json`. Place them under the appropriate existing namespaces:

Under `"goals"` namespace, add after `"amountRequired"`:
```json
"goalCreated": "Goal created",
"goalUpdated": "Goal updated",
"goalProgressUpdated": "Progress updated",
"goalCompleted": "Goal completed!",
"goalDeleted": "Goal deleted",
"goalProgressSynced": "Progress synced",
"goalCreateFailed": "Failed to create goal: {{error}}",
"goalUpdateFailed": "Failed to update goal: {{error}}",
"goalProgressFailed": "Failed to update progress: {{error}}",
"goalCompleteFailed": "Failed to complete goal: {{error}}",
"goalDeleteFailed": "Failed to delete goal: {{error}}",
"goalProgressSyncFailed": "Failed to sync progress: {{error}}",
"validAmountRequired": "Please enter a valid amount"
```

Under `"budget"` namespace, add after `"cloneError"`:
```json
"budgetCreated": "Budget created",
"budgetItemAdded": "Budget item added",
"budgetDeleted": "Budget deleted",
"budgetItemRemoved": "Budget item removed",
"budgetCloned": "Budget copied",
"budgetCreateFailed": "Failed to create budget: {{error}}",
"budgetItemAddFailed": "Failed to add budget item: {{error}}",
"budgetDeleteFailed": "Failed to delete budget: {{error}}",
"budgetItemRemoveFailed": "Failed to remove budget item: {{error}}",
"budgetCloneFailed": "Failed to copy budget: {{error}}"
```

Under `"settings"` namespace, add after `"fetchError"`:
```json
"currencyAdded": "Currency added",
"rateUpdated": "Exchange rate updated",
"currencyDeleted": "Currency deleted",
"currencyAddFailed": "Failed to add currency: {{error}}",
"rateUpdateFailed": "Failed to update rate: {{error}}",
"currencyDeleteFailed": "Failed to delete currency: {{error}}"
```

Under `"tags"` namespace, add after `"managementDesc"`:
```json
"tagSoftDeleted": "Tag deleted",
"tagAdded": "Tag added",
"tagRemoved": "Tag removed",
"tagCreateFailed": "Failed to create tag: {{error}}",
"tagDeleteFailed": "Failed to delete tag: {{error}}",
"tagUpdateFailed": "Failed to update tag: {{error}}",
"tagSoftDeleteFailed": "Failed to delete tag: {{error}}",
"tagAddFailed": "Failed to add tag: {{error}}",
"tagRemoveFailed": "Failed to remove tag: {{error}}"
```

Under `"transactionTemplate"` namespace, add after `"noAccounts"`:
```json
"templatePaused": "Template paused",
"templateResumed": "Template resumed"
```

Under `"reminders"` namespace, add after `"remindAtRequired"`:
```json
"createFailed": "Failed to create reminder: {{error}}",
"updateFailed": "Failed to update reminder: {{error}}",
"deleteFailed": "Failed to delete reminder: {{error}}",
"completeFailed": "Failed to complete reminder: {{error}}"
```

Under `"transaction"` namespace, add after `"recordWithAmount"`:
```json
"selectOwnAccount": "Please select an own account",
"selectExternalAccount": "Please select an external account",
"createFailed": "Failed to create transaction: {{error}}"
```

- [ ] **Step 1 complete**

### Step 2: Add i18n keys to zh.json

Add the same keys under the same namespaces in `zh.json` with Chinese translations:

Under `"goals"`:
```json
"goalCreated": "目标创建成功",
"goalUpdated": "目标更新成功",
"goalProgressUpdated": "进度更新成功",
"goalCompleted": "目标已完成！",
"goalDeleted": "目标删除成功",
"goalProgressSynced": "进度同步成功",
"goalCreateFailed": "创建目标失败: {{error}}",
"goalUpdateFailed": "更新目标失败: {{error}}",
"goalProgressFailed": "更新进度失败: {{error}}",
"goalCompleteFailed": "完成目标失败: {{error}}",
"goalDeleteFailed": "删除目标失败: {{error}}",
"goalProgressSyncFailed": "同步进度失败: {{error}}",
"validAmountRequired": "请输入有效的金额"
```

Under `"budget"`:
```json
"budgetCreated": "预算创建成功",
"budgetItemAdded": "预算项添加成功",
"budgetDeleted": "预算删除成功",
"budgetItemRemoved": "预算项删除成功",
"budgetCloned": "预算复制成功",
"budgetCreateFailed": "创建预算失败: {{error}}",
"budgetItemAddFailed": "添加预算项失败: {{error}}",
"budgetDeleteFailed": "删除预算失败: {{error}}",
"budgetItemRemoveFailed": "删除预算项失败: {{error}}",
"budgetCloneFailed": "复制预算失败: {{error}}"
```

Under `"settings"`:
```json
"currencyAdded": "货币添加成功",
"rateUpdated": "汇率更新成功",
"currencyDeleted": "货币删除成功",
"currencyAddFailed": "添加货币失败: {{error}}",
"rateUpdateFailed": "更新汇率失败: {{error}}",
"currencyDeleteFailed": "删除货币失败: {{error}}"
```

Under `"tags"`:
```json
"tagSoftDeleted": "标签已删除",
"tagAdded": "标签已添加",
"tagRemoved": "标签已移除",
"tagCreateFailed": "创建标签失败: {{error}}",
"tagDeleteFailed": "删除标签失败: {{error}}",
"tagUpdateFailed": "更新标签失败: {{error}}",
"tagSoftDeleteFailed": "删除标签失败: {{error}}",
"tagAddFailed": "添加标签失败: {{error}}",
"tagRemoveFailed": "移除标签失败: {{error}}"
```

Under `"transactionTemplate"`:
```json
"templatePaused": "模板已暂停",
"templateResumed": "模板已恢复"
```

Under `"reminders"`:
```json
"createFailed": "创建提醒失败: {{error}}",
"updateFailed": "更新提醒失败: {{error}}",
"deleteFailed": "删除提醒失败: {{error}}",
"completeFailed": "完成提醒失败: {{error}}"
```

Under `"transaction"`:
```json
"selectOwnAccount": "请选择自己账户",
"selectExternalAccount": "请选择外部账户",
"createFailed": "创建交易失败: {{error}}"
```

- [ ] **Step 2 complete**

### Step 3: Fix useGoal.ts

Replace the entire file with i18n-ized version. Add `import { useTranslation } from 'react-i18next';` and `const { t } = useTranslation();` to each mutation hook.

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listGoals,
  getGoal,
  createGoal,
  updateGoal,
  updateGoalProgress,
  completeGoal,
  deleteGoal,
  syncGoalProgress,
  CreateGoalDto,
  UpdateGoalDto,
} from '../lib/tauri/goal';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';

export function useGoals() {
  return useQuery({ queryKey: ['goals'], queryFn: listGoals });
}

export function useGoal(id: string) {
  return useQuery({
    queryKey: ['goal', id],
    queryFn: () => getGoal(id),
    enabled: !!id,
  });
}

export function useCreateGoal() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (dto: CreateGoalDto) => createGoal(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalCreated'));
    },
    onError: (error) => {
      toast.error(t('goals.goalCreateFailed', { error: String(error) }));
    },
  });
}

export function useUpdateGoal() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: UpdateGoalDto }) =>
      updateGoal(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalUpdated'));
    },
    onError: (error) => {
      toast.error(t('goals.goalUpdateFailed', { error: String(error) }));
    },
  });
}

export function useUpdateGoalProgress() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ id, amount }: { id: string; amount: string }) =>
      updateGoalProgress(id, amount),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalProgressUpdated'));
    },
    onError: (error) => {
      toast.error(t('goals.goalProgressFailed', { error: String(error) }));
    },
  });
}

export function useCompleteGoal() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => completeGoal(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalCompleted'));
    },
    onError: (error) => {
      toast.error(t('goals.goalCompleteFailed', { error: String(error) }));
    },
  });
}

export function useDeleteGoal() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => deleteGoal(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalDeleted'));
    },
    onError: (error) => {
      toast.error(t('goals.goalDeleteFailed', { error: String(error) }));
    },
  });
}

export function useSyncGoalProgress() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (goalId: string) => syncGoalProgress(goalId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['goals'] });
      toast.success(t('goals.goalProgressSynced'));
    },
    onError: (error) => {
      toast.error(t('goals.goalProgressSyncFailed', { error: String(error) }));
    },
  });
}
```

- [ ] **Step 3 complete**

### Step 4: Fix useBudget.ts

Replace the entire file:

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listBudgets,
  getBudget,
  getBudgetByMonth,
  createBudget,
  addBudgetItem,
  deleteBudget,
  removeBudgetItem,
  computeBudgetActuals,
  cloneBudgetToMonth,
  CreateBudgetDto,
  AddBudgetItemDto,
} from '../lib/tauri/budget';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';

export function useBudgets() {
  return useQuery({
    queryKey: ['budgets'],
    queryFn: listBudgets,
  });
}

export function useBudget(id: string) {
  return useQuery({
    queryKey: ['budget', id],
    queryFn: () => getBudget(id),
    enabled: !!id,
  });
}

export function useBudgetByMonth(month: string) {
  return useQuery({
    queryKey: ['budget', 'month', month],
    queryFn: () => getBudgetByMonth(month),
    enabled: !!month,
  });
}

export function useCreateBudget() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: (dto: CreateBudgetDto) => createBudget(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      toast.success(t('budget.budgetCreated'));
    },
    onError: (error) => {
      toast.error(t('budget.budgetCreateFailed', { error: String(error) }));
    },
  });
}

export function useAddBudgetItem() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: ({ budgetId, dto }: { budgetId: string; dto: AddBudgetItemDto }) =>
      addBudgetItem(budgetId, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      toast.success(t('budget.budgetItemAdded'));
    },
    onError: (error) => {
      toast.error(t('budget.budgetItemAddFailed', { error: String(error) }));
    },
  });
}

export function useDeleteBudget() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: (id: string) => deleteBudget(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      toast.success(t('budget.budgetDeleted'));
    },
    onError: (error) => {
      toast.error(t('budget.budgetDeleteFailed', { error: String(error) }));
    },
  });
}

export function useRemoveBudgetItem() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: ({ budgetId, itemId }: { budgetId: string; itemId: string }) =>
      removeBudgetItem(budgetId, itemId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      toast.success(t('budget.budgetItemRemoved'));
    },
    onError: (error) => {
      toast.error(t('budget.budgetItemRemoveFailed', { error: String(error) }));
    },
  });
}

export function useComputeBudgetActuals() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (budgetId: string) => computeBudgetActuals(budgetId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
    },
  });
}

export function useCloneBudgetToMonth() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: ({ sourceBudgetId, targetMonth }: { sourceBudgetId: string; targetMonth: string }) =>
      cloneBudgetToMonth(sourceBudgetId, targetMonth),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['budgets'] });
      queryClient.invalidateQueries({ queryKey: ['budget'] });
      toast.success(t('budget.budgetCloned'));
    },
    onError: (error) => {
      toast.error(t('budget.budgetCloneFailed', { error: String(error) }));
    },
  });
}
```

- [ ] **Step 4 complete**

### Step 5: Fix useCurrency.ts

Replace the entire file (extends `useTranslation` to all mutations, not just `useFetchExchangeRates`):

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listCurrencies,
  getCurrency,
  addCurrency,
  updateCurrencyRate,
  deleteCurrency,
  convertCurrency,
  fetchExchangeRates,
  CreateCurrencyDto,
} from '../lib/tauri/currency';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';

export function useCurrencies() {
  return useQuery({
    queryKey: ['currencies'],
    queryFn: listCurrencies,
    staleTime: 1000 * 60 * 60,
  });
}

export function useCurrency(code: string) {
  return useQuery({
    queryKey: ['currency', code],
    queryFn: () => getCurrency(code),
    enabled: !!code,
  });
}

export function useAddCurrency() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: (dto: CreateCurrencyDto) => addCurrency(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      toast.success(t('settings.currencyAdded'));
    },
    onError: (error) => {
      toast.error(t('settings.currencyAddFailed', { error: String(error) }));
    },
  });
}

export function useUpdateCurrencyRate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: ({ code, exchangeRate }: { code: string; exchangeRate: string }) =>
      updateCurrencyRate(code, exchangeRate),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      toast.success(t('settings.rateUpdated'));
    },
    onError: (error) => {
      toast.error(t('settings.rateUpdateFailed', { error: String(error) }));
    },
  });
}

export function useDeleteCurrency() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: (code: string) => deleteCurrency(code),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      toast.success(t('settings.currencyDeleted'));
    },
    onError: (error) => {
      toast.error(t('settings.currencyDeleteFailed', { error: String(error) }));
    },
  });
}

export function useConvertCurrency() {
  return useMutation({
    mutationFn: ({
      amount,
      fromCode,
      toCode,
    }: {
      amount: number;
      fromCode: string;
      toCode: string;
    }) => convertCurrency(amount, fromCode, toCode),
  });
}

export function useFetchExchangeRates() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: fetchExchangeRates,
    onSuccess: (updated) => {
      queryClient.invalidateQueries({ queryKey: ['currencies'] });
      toast.success(t('settings.fetchSuccess', { count: updated }));
    },
    onError: () => {
      toast.error(t('settings.fetchError'));
    },
  });
}
```

- [ ] **Step 5 complete**

### Step 6: Fix useTag.ts

Replace the entire file:

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listTags,
  createTag,
  deleteTag,
  updateTag,
  softDeleteTag,
  addTagToTransaction,
  removeTagFromTransaction,
  getTransactionTags,
  CreateTagDto,
} from '../lib/tauri/tag';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';

export function useTags() {
  return useQuery({ queryKey: ['tags'], queryFn: listTags });
}

export function useCreateTag() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (dto: CreateTagDto) => createTag(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success(t('tags.tagCreated'));
    },
    onError: (error) => {
      toast.error(t('tags.tagCreateFailed', { error: String(error) }));
    },
  });
}

export function useDeleteTag() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => deleteTag(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success(t('tags.tagDeleted'));
    },
    onError: (error) => {
      toast.error(t('tags.tagDeleteFailed', { error: String(error) }));
    },
  });
}

export function useUpdateTag() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ id, name, color }: { id: string; name?: string; color?: string }) =>
      updateTag(id, name, color),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success(t('tags.tagUpdated'));
    },
    onError: (error) => {
      toast.error(t('tags.tagUpdateFailed', { error: String(error) }));
    },
  });
}

export function useSoftDeleteTag() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => softDeleteTag(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tags'] });
      toast.success(t('tags.tagSoftDeleted'));
    },
    onError: (error) => {
      toast.error(t('tags.tagSoftDeleteFailed', { error: String(error) }));
    },
  });
}

export function useTransactionTags(transactionId: string) {
  return useQuery({
    queryKey: ['transaction-tags', transactionId],
    queryFn: () => getTransactionTags(transactionId),
    enabled: !!transactionId,
  });
}

export function useAddTagToTransaction() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ transactionId, tagId }: { transactionId: string; tagId: string }) =>
      addTagToTransaction(transactionId, tagId),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['transaction-tags', variables.transactionId] });
      toast.success(t('tags.tagAdded'));
    },
    onError: (error) => {
      toast.error(t('tags.tagAddFailed', { error: String(error) }));
    },
  });
}

export function useRemoveTagFromTransaction() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ transactionId, tagId }: { transactionId: string; tagId: string }) =>
      removeTagFromTransaction(transactionId, tagId),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['transaction-tags', variables.transactionId] });
      toast.success(t('tags.tagRemoved'));
    },
    onError: (error) => {
      toast.error(t('tags.tagRemoveFailed', { error: String(error) }));
    },
  });
}
```

- [ ] **Step 6 complete**

### Step 7: Fix useTransactionTemplate.ts

Replace the entire file:

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { toast } from 'sonner';
import {
  listTransactionTemplates,
  getTransactionTemplate,
  createTransactionTemplate,
  updateTransactionTemplate,
  deleteTransactionTemplate,
  pauseTransactionTemplate,
  resumeTransactionTemplate,
} from '../lib/tauri/transactionTemplate';
import { getUserFriendlyError } from '../lib/error-handler';
import { useTranslation } from 'react-i18next';

export function useTransactionTemplates() {
  return useQuery({
    queryKey: ['transactionTemplates'],
    queryFn: listTransactionTemplates,
  });
}

export function useTransactionTemplate(id: string) {
  return useQuery({
    queryKey: ['transactionTemplate', id],
    queryFn: () => getTransactionTemplate(id),
    enabled: !!id,
  });
}

export function useCreateTransactionTemplate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: createTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      toast.success(t('transactionTemplate.createSuccess'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function useUpdateTransactionTemplate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: updateTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      toast.success(t('transactionTemplate.updateSuccess'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function useDeleteTransactionTemplate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: deleteTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
      queryClient.invalidateQueries({ queryKey: ['transactions'] });
      toast.success(t('transactionTemplate.deleteSuccess'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function usePauseTransactionTemplate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: pauseTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      toast.success(t('transactionTemplate.templatePaused'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}

export function useResumeTransactionTemplate() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();

  return useMutation({
    mutationFn: resumeTransactionTemplate,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['transactionTemplates'] });
      toast.success(t('transactionTemplate.templateResumed'));
    },
    onError: (error) => {
      toast.error(getUserFriendlyError(error));
    },
  });
}
```

- [ ] **Step 7 complete**

### Step 8: Fix useReminder.ts

Replace the entire file:

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  listReminders,
  getReminder,
  createReminder,
  updateReminder,
  deleteReminder,
  completeReminder,
  type CreateReminderDto,
  type UpdateReminderDto,
} from '../lib/tauri/reminder';
import { toast } from 'sonner';
import { useTranslation } from 'react-i18next';

export function useReminders() {
  return useQuery({
    queryKey: ['reminders'],
    queryFn: listReminders,
    staleTime: 5 * 60 * 1000,
  });
}

export function useReminder(id: string) {
  return useQuery({
    queryKey: ['reminder', id],
    queryFn: () => getReminder(id),
    enabled: !!id,
  });
}

export function useCreateReminder() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (dto: CreateReminderDto) => createReminder(dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success(t('reminders.createSuccess'));
    },
    onError: (error) => {
      toast.error(t('reminders.createFailed', { error: String(error) }));
    },
  });
}

export function useUpdateReminder() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: ({ id, dto }: { id: string; dto: UpdateReminderDto }) =>
      updateReminder(id, dto),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success(t('reminders.updateSuccess'));
    },
    onError: (error) => {
      toast.error(t('reminders.updateFailed', { error: String(error) }));
    },
  });
}

export function useDeleteReminder() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => deleteReminder(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success(t('reminders.deleteSuccess'));
    },
    onError: (error) => {
      toast.error(t('reminders.deleteFailed', { error: String(error) }));
    },
  });
}

export function useCompleteReminder() {
  const queryClient = useQueryClient();
  const { t } = useTranslation();
  return useMutation({
    mutationFn: (id: string) => completeReminder(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['reminders'] });
      toast.success(t('reminders.completeSuccess'));
    },
    onError: (error) => {
      toast.error(t('reminders.completeFailed', { error: String(error) }));
    },
  });
}
```

- [ ] **Step 8 complete**

### Step 9: Fix GoalsPage.tsx

Replace 3 hardcoded strings at lines 155, 159, 186 in `src/pages/GoalsPage.tsx`:

In `handleCreateGoal`, replace:
```typescript
toast.error('请输入目标名称');
```
with:
```typescript
toast.error(t('goals.nameRequired'));
```

Replace:
```typescript
toast.error('请输入有效的目标金额');
```
with:
```typescript
toast.error(t('goals.amountRequired'));
```

In `handleUpdateProgress`, replace:
```typescript
toast.error('请输入有效的金额');
```
with:
```typescript
toast.error(t('goals.validAmountRequired'));
```

- [ ] **Step 9 complete**

### Step 10: Fix SimpleTransactionForm.tsx

In `src/components/SimpleTransactionForm.tsx`, make these replacements:

At line ~119, replace:
```typescript
toast.error('请选择自己账户');
```
with:
```typescript
toast.error(t('transaction.selectOwnAccount'));
```

At line ~123, replace:
```typescript
toast.error('请选择外部账户');
```
with:
```typescript
toast.error(t('transaction.selectExternalAccount'));
```

At line ~213-214, replace:
```typescript
console.error('Failed to create transaction:', error);
toast.error(`Failed to create transaction: ${error}`);
```
with:
```typescript
console.error('[SimpleTransactionForm] Failed to create transaction:', error);
toast.error(t('transaction.createFailed', { error: String(error) }));
```

At line ~279, replace:
```typescript
{type === 'expense' ? '贷方 (自己账户)' : '借方 (自己账户)'}
```
with:
```typescript
{type === 'expense' ? t('transaction.creditOwnAccount') : t('transaction.debitOwnAccount')}
```

At line ~286, replace:
```typescript
: '选择账户'}
```
with:
```typescript
: t('transaction.selectAccount')}
```

At line ~304, replace:
```typescript
{type === 'expense' ? '借方 (外部账户)' : '贷方 (外部账户)'}
```
with:
```typescript
{type === 'expense' ? t('transaction.debitExternalAccount') : t('transaction.creditExternalAccount')}
```

At line ~311, replace:
```typescript
: '选择外部账户'}
```
with:
```typescript
: t('transaction.selectExternalAccount')}
```

- [ ] **Step 10 complete**

### Step 11: Verify i18n fixes

Run:
```bash
pnpm type-check && pnpm lint
```

Expected: No TypeScript errors, no `i18next/no-literal-string` violations.

- [ ] **Step 11 complete**

### Step 12: Commit Task 21

```bash
git add -A
git commit -m "feat(i18n): replace all hardcoded toast strings with translation keys

Replaces 66 hardcoded Chinese/English strings across 8 files with t() calls.
Adds toast and validation keys to both en.json and zh.json locales.
Adds useTranslation import to 6 hooks that were missing it.

Task 21 of Sprint 6 — Code Quality."
```

- [ ] **Step 12 complete**

---

## Task 22: Dead Code Cleanup

**Files:**
- Delete: `src-tauri/src/domain/aggregates/debt.rs`
- Modify: `src-tauri/src/domain/aggregates/mod.rs`
- Modify: `src-tauri/src/lib.rs`
- Modify: `src-tauri/src/main.rs`
- Modify: `src-tauri/src/infrastructure/mod.rs`
- Delete: `src-tauri/src/infrastructure/database/mod.rs`
- Modify: `src-tauri/src/domain/repositories/goal_repository.rs`
- Modify: `src-tauri/src/infrastructure/repositories/goal_repository.rs`

### Step 1: Delete legacy debt.rs

```bash
rm src-tauri/src/domain/aggregates/debt.rs
```

- [ ] **Step 1 complete**

### Step 2: Remove debt module from aggregates/mod.rs

In `src-tauri/src/domain/aggregates/mod.rs`, remove line 4:
```rust
pub mod debt;
```

Remove line 19:
```rust
pub use debt::{AmortizationMethod, Debt, DebtError, DebtType, PaymentSchedule};
```

The file should become:
```rust
pub mod account;
pub mod budget;
pub mod chart_of_accounts;
pub mod debt_details;
pub mod goal;
pub mod holding;
pub mod reminder;
pub mod security;
pub mod subscription;
pub mod tag;
pub mod transaction;
pub mod transaction_template;

pub use account::{Account, AccountError, AccountType, Ownership};
pub use chart_of_accounts::{
    AccountType as ChartOfAccountsType, BalanceDirection, ChartOfAccounts, ChartOfAccountsError,
};
pub use holding::{Holding, HoldingTransaction, HoldingTransactionType};
pub use reminder::{Reminder, ReminderError, ReminderType, RepeatPattern};
pub use subscription::{Subscription, SubscriptionCycle, SubscriptionDirection};
pub use tag::Tag;
pub use transaction_template::{TemplateCycle, TemplateDirection, TransactionTemplate};
pub use transaction::{Transaction, TransactionError, TransactionEvent};
```

- [ ] **Step 2 complete**

### Step 3: Remove global allow(dead_code) from lib.rs

In `src-tauri/src/lib.rs`, remove lines 1-3:
```rust
// Allow unused code during development - many components are not yet integrated
#![allow(dead_code)]
#![allow(unused_imports)]
```

The file should become:
```rust
pub mod application;
pub mod domain;
pub mod infrastructure;
pub mod presentation;
```

- [ ] **Step 3 complete**

### Step 4: Remove global allow(dead_code) from main.rs

In `src-tauri/src/main.rs`, remove lines 1-3:
```rust
// Allow unused code during development - many components are not yet integrated
#![allow(dead_code)]
#![allow(unused_imports)]
```

- [ ] **Step 4 complete**

### Step 5: Delete infrastructure/database placeholder

```bash
rm -rf src-tauri/src/infrastructure/database/
```

In `src-tauri/src/infrastructure/mod.rs`, remove line 3:
```rust
pub mod database;
```

The file should become:
```rust
pub mod backup;
pub mod currency_rate_fetcher;
pub mod encryption;
pub mod notifications;
pub mod reminders;
pub mod repositories;
pub mod sync;
```

- [ ] **Step 5 complete**

### Step 6: Remove dead GoalRepository methods

In `src-tauri/src/domain/repositories/goal_repository.rs`, remove the `dead_code` from the allow attribute and remove the two unused methods. The file should become:

```rust
use crate::domain::aggregates::goal::Goal;
use rust_decimal::Decimal;

#[allow(async_fn_in_trait)]
pub trait GoalRepository: Send + Sync {
    async fn create(&self, goal: &Goal) -> sqlx::Result<()>;
    async fn find_by_id(&self, id: &str) -> sqlx::Result<Option<Goal>>;
    async fn find_all(&self) -> sqlx::Result<Vec<Goal>>;
    async fn update(&self, goal: &Goal) -> sqlx::Result<()>;
    async fn delete(&self, id: &str) -> sqlx::Result<()>;
    async fn add_progress(&self, id: &str, amount: Decimal) -> sqlx::Result<()>;
}
```

Then in `src-tauri/src/infrastructure/repositories/goal_repository.rs`, remove the `find_active` and `find_completed` method implementations and any tests that test only those methods. Keep all other methods.

- [ ] **Step 6 complete**

### Step 7: Run cargo check and triage warnings

Run:
```bash
cd src-tauri && cargo check 2>&1 | head -100
```

Expected: Many dead_code warnings will surface that were previously suppressed. For each warning:

- **If genuinely unused**: delete it
- **If planned for future use** (PostgreSQL repos, ChartOfAccounts, field-level encryption): add targeted `#[allow(dead_code)]` with a comment like `// TODO: will be used when X is implemented`

Key items expected to need targeted `#[allow(dead_code)]`:
- `chart_of_accounts.rs` — entire module (not wired yet)
- PostgreSQL repository files — `*_repository_postgres.rs` (future sync)
- `encrypt_field`/`decrypt_field` in encryption service (future field-level encryption)

- [ ] **Step 7 complete**

### Step 8: Verify cargo check passes

Run:
```bash
cd src-tauri && cargo check
```

Expected: Compiles with zero errors (warnings are acceptable if targeted).

- [ ] **Step 8 complete**

### Step 9: Commit Task 22

```bash
git add -A
git commit -m "refactor: remove dead code and global allow(dead_code) suppressions

- Delete legacy debt.rs aggregate (replaced by debt_details.rs)
- Remove global #![allow(dead_code)] from lib.rs and main.rs
- Delete infrastructure/database placeholder module
- Remove unused find_active/find_completed from GoalRepository
- Add targeted #[allow(dead_code)] for planned future features

Task 22 of Sprint 6 — Code Quality."
```

- [ ] **Step 9 complete**

---

## Task 23: DDD Architecture — Create GoalService and Refactor BudgetService

**Files:**
- Create: `src-tauri/src/application/services/goal_service.rs`
- Modify: `src-tauri/src/application/services/mod.rs`
- Modify: `src-tauri/src/application/services/budget_service.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/budget_commands.rs`
- Modify: `src-tauri/src/presentation/tauri_commands/goal_commands.rs`
- Modify: `src-tauri/src/main.rs` (update state initialization)

### Step 1: Create goal_service.rs

Create `src-tauri/src/application/services/goal_service.rs` following the `DebtService` pattern:

```rust
use crate::domain::aggregates::goal::{Goal, GoalType};
use crate::domain::repositories::GoalRepository;
use crate::infrastructure::repositories::{SqliteAccountRepository, SqliteGoalRepository};
use chrono::NaiveDate;
use rust_decimal::Decimal;
use sqlx::SqlitePool;
use std::str::FromStr;
use std::sync::Arc;
use tracing::info;

pub struct GoalService {
    goal_repo: Arc<SqliteGoalRepository>,
    account_repo: Arc<SqliteAccountRepository>,
    pool: SqlitePool,
}

#[derive(Debug)]
pub enum GoalServiceError {
    NotFound(String),
    ValidationError(String),
    RepositoryError(String),
}

impl std::fmt::Display for GoalServiceError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::NotFound(id) => write!(f, "goal not found: {id}"),
            Self::ValidationError(msg) => write!(f, "validation error: {msg}"),
            Self::RepositoryError(msg) => write!(f, "repository error: {msg}"),
        }
    }
}

impl std::error::Error for GoalServiceError {}

impl From<sqlx::Error> for GoalServiceError {
    fn from(err: sqlx::Error) -> Self {
        Self::RepositoryError(err.to_string())
    }
}

impl GoalService {
    pub fn new(
        goal_repo: Arc<SqliteGoalRepository>,
        account_repo: Arc<SqliteAccountRepository>,
        pool: SqlitePool,
    ) -> Self {
        Self {
            goal_repo,
            account_repo,
            pool,
        }
    }

    pub async fn list_goals(&self) -> Result<Vec<Goal>, GoalServiceError> {
        self.goal_repo.find_all().await.map_err(GoalServiceError::from)
    }

    pub async fn get_goal(&self, id: &str) -> Result<Option<Goal>, GoalServiceError> {
        self.goal_repo.find_by_id(id).await.map_err(GoalServiceError::from)
    }

    pub async fn create_goal(
        &self,
        name: String,
        goal_type_str: String,
        target_amount_str: String,
        currency_code: String,
        deadline: Option<String>,
        linked_account_id: Option<String>,
        notes: Option<String>,
    ) -> Result<Goal, GoalServiceError> {
        let id = uuid::Uuid::new_v4().to_string();
        let target_amount = Decimal::from_str(&target_amount_str)
            .map_err(|_| GoalServiceError::ValidationError("Invalid target amount".to_string()))?;
        let goal_type = GoalType::from_str(&goal_type_str);

        let mut goal = Goal::new(id, name, goal_type, target_amount, currency_code);

        if let Some(deadline_str) = deadline {
            let deadline_date = NaiveDate::parse_from_str(&deadline_str, "%Y-%m-%d")
                .map_err(|_| GoalServiceError::ValidationError("Invalid deadline date".to_string()))?;
            goal.set_deadline(deadline_date);
        }

        if let Some(account_id) = linked_account_id {
            goal.link_account(account_id);
        }

        goal.notes = notes;

        self.goal_repo
            .create(&goal)
            .await
            .map_err(GoalServiceError::from)?;

        info!(goal_id = %goal.id, "Goal created");
        Ok(goal)
    }

    pub async fn update_goal(
        &self,
        id: &str,
        name: Option<String>,
        goal_type_str: Option<String>,
        target_amount_str: Option<String>,
        currency_code: Option<String>,
        deadline: Option<String>,
        linked_account_id: Option<String>,
        notes: Option<String>,
    ) -> Result<Goal, GoalServiceError> {
        let mut goal = self
            .goal_repo
            .find_by_id(id)
            .await
            .map_err(GoalServiceError::from)?
            .ok_or_else(|| GoalServiceError::NotFound(id.to_string()))?;

        if let Some(name) = name {
            goal.name = name;
        }
        if let Some(gt) = goal_type_str {
            goal.goal_type = GoalType::from_str(&gt);
        }
        if let Some(ta) = target_amount_str {
            goal.target_amount = Decimal::from_str(&ta)
                .map_err(|_| GoalServiceError::ValidationError("Invalid target amount".to_string()))?;
        }
        if let Some(cc) = currency_code {
            goal.currency_code = cc;
        }
        if let Some(deadline_str) = deadline {
            if deadline_str.is_empty() {
                goal.deadline = None;
            } else {
                let deadline_date = NaiveDate::parse_from_str(&deadline_str, "%Y-%m-%d")
                    .map_err(|_| {
                        GoalServiceError::ValidationError("Invalid deadline date".to_string())
                    })?;
                goal.deadline = Some(deadline_date);
            }
        }
        if let Some(account_id) = linked_account_id {
            if account_id.is_empty() {
                goal.linked_account_id = None;
            } else {
                goal.linked_account_id = Some(account_id);
            }
        }
        if let Some(notes) = notes {
            goal.notes = if notes.is_empty() { None } else { Some(notes) };
        }

        self.goal_repo
            .update(&goal)
            .await
            .map_err(GoalServiceError::from)?;

        info!(goal_id = id, "Goal updated");
        Ok(goal)
    }

    pub async fn update_goal_progress(
        &self,
        id: &str,
        amount_str: String,
    ) -> Result<Goal, GoalServiceError> {
        let amount = Decimal::from_str(&amount_str)
            .map_err(|_| GoalServiceError::ValidationError("Invalid amount".to_string()))?;

        self.goal_repo
            .add_progress(id, amount)
            .await
            .map_err(GoalServiceError::from)?;

        let goal = self
            .goal_repo
            .find_by_id(id)
            .await
            .map_err(GoalServiceError::from)?
            .ok_or_else(|| GoalServiceError::NotFound(id.to_string()))?;

        // Auto-complete if target reached
        if !goal.is_completed && goal.current_amount >= goal.target_amount {
            let mut goal = goal;
            goal.mark_completed();
            self.goal_repo
                .update(&goal)
                .await
                .map_err(GoalServiceError::from)?;
            info!(goal_id = id, "Goal auto-completed");
            return Ok(goal);
        }

        info!(goal_id = id, "Goal progress updated");
        Ok(goal)
    }

    pub async fn complete_goal(&self, id: &str) -> Result<Goal, GoalServiceError> {
        let mut goal = self
            .goal_repo
            .find_by_id(id)
            .await
            .map_err(GoalServiceError::from)?
            .ok_or_else(|| GoalServiceError::NotFound(id.to_string()))?;

        goal.mark_completed();

        self.goal_repo
            .update(&goal)
            .await
            .map_err(GoalServiceError::from)?;

        info!(goal_id = id, "Goal marked as completed");
        Ok(goal)
    }

    pub async fn delete_goal(&self, id: &str) -> Result<(), GoalServiceError> {
        self.goal_repo
            .delete(id)
            .await
            .map_err(GoalServiceError::from)?;

        info!(goal_id = id, "Goal deleted");
        Ok(())
    }

    pub async fn sync_goal_progress(&self, goal_id: &str) -> Result<Goal, GoalServiceError> {
        info!(goal_id = goal_id, "Syncing goal progress from linked account");

        let goal = self
            .goal_repo
            .find_by_id(goal_id)
            .await
            .map_err(GoalServiceError::from)?
            .ok_or_else(|| GoalServiceError::NotFound(goal_id.to_string()))?;

        let account_id = goal
            .linked_account_id
            .ok_or_else(|| GoalServiceError::ValidationError("Goal has no linked account".to_string()))?;

        // Get account initial balance
        let initial_balance: (String,) = sqlx::query_as(
            "SELECT CAST(initial_balance AS TEXT) FROM accounts WHERE id = ?",
        )
        .bind(&account_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| GoalServiceError::RepositoryError(format!("Linked account not found: {}", e)))?;

        let initial = initial_balance.0.parse::<Decimal>().unwrap_or(Decimal::ZERO);

        // Compute net change from transactions
        let net_change: (String,) = sqlx::query_as(
            "SELECT CAST(COALESCE(SUM(CASE WHEN e.debit_amount IS NOT NULL THEN e.debit_amount ELSE 0 END \
             - CASE WHEN e.credit_amount IS NOT NULL THEN e.credit_amount ELSE 0 END), 0) AS TEXT) \
             FROM transaction_entries e \
             JOIN transactions t ON e.transaction_id = t.id \
             WHERE e.deleted_at IS NULL AND t.deleted_at IS NULL AND e.account_id = ?",
        )
        .bind(&account_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| GoalServiceError::RepositoryError(format!("Failed to compute balance: {}", e)))?;

        let change = net_change.0.parse::<Decimal>().unwrap_or(Decimal::ZERO);
        let current_balance = initial + change;

        self.goal_repo
            .add_progress(goal_id, current_balance)
            .await
            .map_err(GoalServiceError::from)?;

        let updated = self
            .goal_repo
            .find_by_id(goal_id)
            .await
            .map_err(GoalServiceError::from)?
            .ok_or_else(|| GoalServiceError::NotFound(goal_id.to_string()))?;

        info!(
            goal_id = goal_id,
            account_id = account_id,
            balance = %current_balance,
            "Goal progress synced from account balance"
        );

        Ok(updated)
    }
}
```

- [ ] **Step 1 complete**

### Step 2: Register GoalService in mod.rs

In `src-tauri/src/application/services/mod.rs`, add after line 4:
```rust
pub mod goal_service;
```

Add after line 12 (the `pub use budget_service` line):
```rust
pub use goal_service::{GoalService, GoalServiceError};
```

- [ ] **Step 2 complete**

### Step 3: Refactor BudgetService — add CRUD methods

In `src-tauri/src/application/services/budget_service.rs`, add CRUD methods while keeping existing `compute_budget_actuals` and `clone_budget_to_month`. The full replacement:

```rust
use crate::domain::aggregates::budget::Budget;
use crate::domain::repositories::BudgetRepository;
use crate::domain::value_objects::budget_item::BudgetItem;
use crate::infrastructure::repositories::SqliteBudgetRepository;
use rust_decimal::Decimal;
use sqlx::SqlitePool;
use std::str::FromStr;
use std::sync::Arc;
use tracing::info;

pub struct BudgetService {
    repo: Arc<SqliteBudgetRepository>,
    pool: SqlitePool,
}

impl BudgetService {
    pub fn new(repo: Arc<SqliteBudgetRepository>, pool: SqlitePool) -> Self {
        Self { repo, pool }
    }

    pub async fn list_budgets(&self) -> Result<Vec<Budget>, String> {
        self.repo
            .find_all()
            .await
            .map_err(|e| format!("Failed to list budgets: {}", e))
    }

    pub async fn get_budget(&self, id: &str) -> Result<Option<Budget>, String> {
        self.repo
            .find_by_id(id)
            .await
            .map_err(|e| format!("Failed to get budget: {}", e))
    }

    pub async fn get_budget_by_month(&self, month: &str) -> Result<Option<Budget>, String> {
        self.repo
            .find_by_month(month)
            .await
            .map_err(|e| format!("Failed to get budget: {}", e))
    }

    pub async fn create_budget(
        &self,
        name: String,
        month: String,
        currency_code: String,
    ) -> Result<Budget, String> {
        let id = uuid::Uuid::new_v4().to_string();
        let budget = Budget::new(id, name, month, currency_code);

        self.repo
            .create(&budget)
            .await
            .map_err(|e| format!("Failed to create budget: {}", e))?;

        info!(budget_id = %budget.id, "Budget created");
        Ok(budget)
    }

    pub async fn add_budget_item(
        &self,
        budget_id: String,
        category_account_id: String,
        planned_amount_str: String,
        notes: Option<String>,
    ) -> Result<Budget, String> {
        let planned_amount = Decimal::from_str(&planned_amount_str)
            .map_err(|_| "Invalid planned amount".to_string())?;

        let item_id = uuid::Uuid::new_v4().to_string();
        let item = BudgetItem::new(
            item_id,
            budget_id.clone(),
            category_account_id,
            planned_amount,
            notes,
        );

        self.repo
            .add_item(&budget_id, &item)
            .await
            .map_err(|e| format!("Failed to add budget item: {}", e))?;

        self.repo
            .find_by_id(&budget_id)
            .await
            .map_err(|e| format!("Failed to get budget: {}", e))?
            .ok_or_else(|| "Budget not found".to_string())
    }

    pub async fn delete_budget(&self, id: &str) -> Result<(), String> {
        self.repo
            .delete(id)
            .await
            .map_err(|e| format!("Failed to delete budget: {}", e))
    }

    pub async fn remove_budget_item(
        &self,
        budget_id: &str,
        item_id: &str,
    ) -> Result<Budget, String> {
        self.repo
            .remove_item(item_id)
            .await
            .map_err(|e| format!("Failed to remove budget item: {}", e))?;

        self.repo
            .find_by_id(budget_id)
            .await
            .map_err(|e| format!("Failed to get budget: {}", e))?
            .ok_or_else(|| "Budget not found".to_string())
    }

    /// Compute actual spending for each budget item from transaction entries.
    pub async fn compute_budget_actuals(&self, budget_id: &str) -> Result<(), String> {
        info!(budget_id = budget_id, "Computing budget actuals");

        let budget_month: (String,) =
            sqlx::query_as("SELECT month FROM budgets WHERE id = ?")
                .bind(budget_id)
                .fetch_one(&self.pool)
                .await
                .map_err(|e| format!("Budget not found: {}", e))?;

        let month = &budget_month.0;

        let items: Vec<(String, String)> = sqlx::query_as(
            "SELECT id, category_account_id FROM budget_items WHERE budget_id = ?",
        )
        .bind(budget_id)
        .fetch_all(&self.pool)
        .await
        .map_err(|e| format!("Failed to fetch budget items: {}", e))?;

        if items.is_empty() {
            return Ok(());
        }

        let start_date = format!("{}-01", month);
        let end_date = format!("{}-{}", month, last_day_of_month(month));

        for (item_id, category_account_id) in &items {
            let actual: (String,) = sqlx::query_as(
                "SELECT CAST(COALESCE(SUM(COALESCE(e.debit_amount, 0)), 0) AS TEXT) \
                 FROM transaction_entries e \
                 JOIN transactions t ON e.transaction_id = t.id \
                 WHERE e.deleted_at IS NULL \
                 AND t.deleted_at IS NULL \
                 AND e.account_id = ? \
                 AND t.transaction_date >= ? \
                 AND t.transaction_date <= ?",
            )
            .bind(category_account_id)
            .bind(&start_date)
            .bind(&end_date)
            .fetch_one(&self.pool)
            .await
            .map_err(|e| format!("Failed to compute actual for item {}: {}", item_id, e))?;

            let amount = actual.0.parse::<Decimal>().unwrap_or(Decimal::ZERO);

            sqlx::query("UPDATE budget_items SET actual_amount = ? WHERE id = ?")
                .bind(amount.to_string())
                .bind(item_id)
                .execute(&self.pool)
                .await
                .map_err(|e| format!("Failed to update actual: {}", e))?;

            info!(
                item_id = item_id,
                category_account_id = category_account_id,
                actual = %amount,
                "Updated budget item actual"
            );
        }

        Ok(())
    }

    /// Clone a budget to another month.
    pub async fn clone_budget_to_month(
        &self,
        source_budget_id: &str,
        target_month: &str,
    ) -> Result<String, String> {
        info!(source_id = source_budget_id, target_month = target_month, "Cloning budget");

        let _source: (String, String) = sqlx::query_as(
            "SELECT name, currency_code FROM budgets WHERE id = ?",
        )
        .bind(source_budget_id)
        .fetch_one(&self.pool)
        .await
        .map_err(|e| format!("Source budget not found: {}", e))?;

        let exists: Option<(String,)> = sqlx::query_as(
            "SELECT id FROM budgets WHERE month = ?",
        )
        .bind(target_month)
        .fetch_optional(&self.pool)
        .await
        .map_err(|e| format!("Check failed: {}", e))?;

        if exists.is_some() {
            return Err(format!("Budget already exists for {}", target_month));
        }

        let new_id = uuid::Uuid::new_v4().to_string();
        sqlx::query(
            "INSERT INTO budgets (id, name, month, total_amount, currency_code, is_active, created_at, updated_at) \
             SELECT ?, name, ?, total_amount, currency_code, 1, datetime('now'), datetime('now') \
             FROM budgets WHERE id = ?",
        )
        .bind(&new_id)
        .bind(target_month)
        .bind(source_budget_id)
        .execute(&self.pool)
        .await
        .map_err(|e| format!("Failed to clone budget: {}", e))?;

        sqlx::query(
            "INSERT INTO budget_items (id, budget_id, category_account_id, planned_amount, actual_amount, notes, created_at, updated_at) \
             SELECT LOWER(HEX(RANDOMBLOB(16))), ?, category_account_id, planned_amount, '0', notes, datetime('now'), datetime('now') \
             FROM budget_items WHERE budget_id = ?",
        )
        .bind(&new_id)
        .bind(source_budget_id)
        .execute(&self.pool)
        .await
        .map_err(|e| format!("Failed to clone budget items: {}", e))?;

        info!(new_id = new_id, "Budget cloned successfully");
        Ok(new_id)
    }
}

fn last_day_of_month(month: &str) -> String {
    let parts: Vec<&str> = month.split('-').collect();
    if parts.len() < 2 {
        return "31".to_string();
    }
    let year: i32 = parts[0].parse().unwrap_or(2026);
    let month_num: u32 = parts[1].parse().unwrap_or(1);
    let days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    let mut d = days[(month_num - 1) as usize];
    if month_num == 2 && (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) {
        d = 29;
    }
    format!("{:02}", d)
}
```

- [ ] **Step 3 complete**

### Step 4: Refactor budget_commands.rs — thin wrapper over BudgetService

Replace `src-tauri/src/presentation/tauri_commands/budget_commands.rs` entirely. The DTOs stay the same. `BudgetCommandState` now holds a `BudgetService` instead of raw repo+pool:

```rust
use crate::application::services::budget_service::BudgetService;
use crate::domain::aggregates::budget::Budget;
use crate::domain::repositories::BudgetRepository;
use crate::domain::value_objects::budget_item::BudgetItem;
use crate::infrastructure::repositories::SqliteBudgetRepository;
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;

// --- DTOs (unchanged) ---

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetDto {
    pub id: String,
    pub name: String,
    pub month: String,
    pub total_amount: String,
    pub total_actual: String,
    pub total_remaining: String,
    pub usage_percentage: f64,
    pub currency_code: String,
    pub is_active: bool,
    pub items: Vec<BudgetItemDto>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetItemDto {
    pub id: String,
    pub category_account_id: String,
    pub planned_amount: String,
    pub actual_amount: String,
    pub remaining: String,
    pub usage_percentage: f64,
    pub is_over_budget: bool,
    pub notes: Option<String>,
}

impl From<Budget> for BudgetDto {
    fn from(budget: Budget) -> Self {
        let total_actual = budget.total_actual();
        let total_remaining = budget.total_remaining();
        let usage_percentage = budget.overall_usage_percentage();

        let items: Vec<BudgetItemDto> = budget
            .items
            .iter()
            .map(|item| BudgetItemDto {
                id: item.id.clone(),
                category_account_id: item.category_account_id.clone(),
                planned_amount: item.planned_amount.to_string(),
                actual_amount: item.actual_amount.to_string(),
                remaining: item.remaining().to_string(),
                usage_percentage: item.usage_percentage(),
                is_over_budget: item.is_over_budget(),
                notes: item.notes.clone(),
            })
            .collect();

        Self {
            id: budget.id,
            name: budget.name,
            month: budget.month,
            total_amount: budget.total_amount.to_string(),
            total_actual: total_actual.to_string(),
            total_remaining: total_remaining.to_string(),
            usage_percentage,
            currency_code: budget.currency_code,
            is_active: budget.is_active,
            items,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateBudgetDto {
    pub name: String,
    pub month: String,
    pub currency_code: String,
}

#[derive(Debug, Deserialize)]
pub struct AddBudgetItemDto {
    pub category_account_id: String,
    pub planned_amount: String,
    pub notes: Option<String>,
}

// --- State ---

pub struct BudgetCommandState {
    service: Arc<BudgetService>,
}

impl BudgetCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let repo = Arc::new(SqliteBudgetRepository::new(pool.clone()));
        let service = Arc::new(BudgetService::new(repo, pool));
        Self { service }
    }

    pub fn service(&self) -> &BudgetService {
        self.service.as_ref()
    }
}

pub async fn create_default_state_from_pool(pool: SqlitePool) -> sqlx::Result<BudgetCommandState> {
    Ok(BudgetCommandState::from_pool(pool))
}

// --- Commands (thin wrappers) ---

#[tauri::command]
pub async fn list_budgets(state: State<'_, BudgetCommandState>) -> Result<Vec<BudgetDto>, String> {
    state
        .service()
        .list_budgets()
        .await
        .map(|budgets| budgets.into_iter().map(BudgetDto::from).collect())
}

#[tauri::command]
pub async fn get_budget(
    state: State<'_, BudgetCommandState>,
    id: String,
) -> Result<Option<BudgetDto>, String> {
    state
        .service()
        .get_budget(&id)
        .await
        .map(|opt| opt.map(BudgetDto::from))
}

#[tauri::command]
pub async fn get_budget_by_month(
    state: State<'_, BudgetCommandState>,
    month: String,
) -> Result<Option<BudgetDto>, String> {
    state
        .service()
        .get_budget_by_month(&month)
        .await
        .map(|opt| opt.map(BudgetDto::from))
}

#[tauri::command]
pub async fn create_budget(
    state: State<'_, BudgetCommandState>,
    dto: CreateBudgetDto,
) -> Result<BudgetDto, String> {
    state
        .service()
        .create_budget(dto.name, dto.month, dto.currency_code)
        .await
        .map(BudgetDto::from)
}

#[tauri::command]
pub async fn add_budget_item(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
    dto: AddBudgetItemDto,
) -> Result<BudgetDto, String> {
    state
        .service()
        .add_budget_item(budget_id, dto.category_account_id, dto.planned_amount, dto.notes)
        .await
        .map(BudgetDto::from)
}

#[tauri::command]
pub async fn delete_budget(state: State<'_, BudgetCommandState>, id: String) -> Result<(), String> {
    state.service().delete_budget(&id).await
}

#[tauri::command]
pub async fn remove_budget_item(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
    item_id: String,
) -> Result<BudgetDto, String> {
    state
        .service()
        .remove_budget_item(&budget_id, &item_id)
        .await
        .map(BudgetDto::from)
}

#[tauri::command]
pub async fn compute_budget_actuals(
    state: State<'_, BudgetCommandState>,
    budget_id: String,
) -> Result<(), String> {
    state.service().compute_budget_actuals(&budget_id).await
}

#[tauri::command]
pub async fn clone_budget_to_month(
    state: State<'_, BudgetCommandState>,
    source_budget_id: String,
    target_month: String,
) -> Result<String, String> {
    state
        .service()
        .clone_budget_to_month(&source_budget_id, &target_month)
        .await
}
```

- [ ] **Step 4 complete**

### Step 5: Refactor goal_commands.rs — thin wrapper over GoalService

Replace `src-tauri/src/presentation/tauri_commands/goal_commands.rs` entirely. DTOs stay the same. `GoalCommandState` now holds a `GoalService`:

```rust
use crate::application::services::goal_service::GoalService;
use crate::domain::aggregates::goal::Goal;
use crate::infrastructure::repositories::{SqliteAccountRepository, SqliteGoalRepository};
use serde::{Deserialize, Serialize};
use sqlx::sqlite::SqlitePool;
use std::sync::Arc;
use tauri::State;

// --- DTOs (unchanged) ---

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GoalDto {
    pub id: String,
    pub name: String,
    pub goal_type: String,
    pub target_amount: String,
    pub current_amount: String,
    pub progress_percentage: f64,
    pub remaining_amount: String,
    pub currency_code: String,
    pub deadline: Option<String>,
    pub linked_account_id: Option<String>,
    pub notes: Option<String>,
    pub is_completed: bool,
    pub is_overdue: bool,
    pub completed_at: Option<String>,
}

impl From<Goal> for GoalDto {
    fn from(goal: Goal) -> Self {
        let progress_percentage = goal.progress_percentage();
        let remaining_amount = goal.remaining_amount().to_string();
        let is_overdue = goal.is_overdue();

        Self {
            id: goal.id,
            name: goal.name,
            goal_type: goal.goal_type.as_str().to_string(),
            target_amount: goal.target_amount.to_string(),
            current_amount: goal.current_amount.to_string(),
            progress_percentage,
            remaining_amount,
            currency_code: goal.currency_code,
            deadline: goal.deadline.map(|d| d.to_string()),
            linked_account_id: goal.linked_account_id,
            notes: goal.notes,
            is_completed: goal.is_completed,
            is_overdue,
            completed_at: goal.completed_at,
        }
    }
}

#[derive(Debug, Deserialize)]
pub struct CreateGoalDto {
    pub name: String,
    pub goal_type: String,
    pub target_amount: String,
    pub currency_code: String,
    pub deadline: Option<String>,
    pub linked_account_id: Option<String>,
    pub notes: Option<String>,
}

#[derive(Debug, Deserialize)]
pub struct UpdateGoalDto {
    pub name: Option<String>,
    pub goal_type: Option<String>,
    pub target_amount: Option<String>,
    pub currency_code: Option<String>,
    pub deadline: Option<String>,
    pub linked_account_id: Option<String>,
    pub notes: Option<String>,
}

// --- State ---

pub struct GoalCommandState {
    service: Arc<GoalService>,
}

impl GoalCommandState {
    pub fn from_pool(pool: SqlitePool) -> Self {
        let goal_repo = Arc::new(SqliteGoalRepository::new(pool.clone()));
        let account_repo = Arc::new(SqliteAccountRepository::new(pool.clone()));
        let service = Arc::new(GoalService::new(goal_repo, account_repo, pool));
        Self { service }
    }

    pub fn service(&self) -> &GoalService {
        self.service.as_ref()
    }
}

pub async fn create_default_state_from_pool(pool: SqlitePool) -> sqlx::Result<GoalCommandState> {
    Ok(GoalCommandState::from_pool(pool))
}

// --- Commands (thin wrappers) ---

#[tauri::command]
pub async fn list_goals(state: State<'_, GoalCommandState>) -> Result<Vec<GoalDto>, String> {
    state
        .service()
        .list_goals()
        .await
        .map(|goals| goals.into_iter().map(GoalDto::from).collect())
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn get_goal(
    state: State<'_, GoalCommandState>,
    id: String,
) -> Result<Option<GoalDto>, String> {
    state
        .service()
        .get_goal(&id)
        .await
        .map(|opt| opt.map(GoalDto::from))
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn create_goal(
    state: State<'_, GoalCommandState>,
    dto: CreateGoalDto,
) -> Result<GoalDto, String> {
    state
        .service()
        .create_goal(
            dto.name,
            dto.goal_type,
            dto.target_amount,
            dto.currency_code,
            dto.deadline,
            dto.linked_account_id,
            dto.notes,
        )
        .await
        .map(GoalDto::from)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_goal(
    state: State<'_, GoalCommandState>,
    id: String,
    dto: UpdateGoalDto,
) -> Result<GoalDto, String> {
    state
        .service()
        .update_goal(
            &id,
            dto.name,
            dto.goal_type,
            dto.target_amount,
            dto.currency_code,
            dto.deadline,
            dto.linked_account_id,
            dto.notes,
        )
        .await
        .map(GoalDto::from)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn update_goal_progress(
    state: State<'_, GoalCommandState>,
    id: String,
    amount: String,
) -> Result<GoalDto, String> {
    state
        .service()
        .update_goal_progress(&id, amount)
        .await
        .map(GoalDto::from)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn complete_goal(
    state: State<'_, GoalCommandState>,
    id: String,
) -> Result<GoalDto, String> {
    state
        .service()
        .complete_goal(&id)
        .await
        .map(GoalDto::from)
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn delete_goal(state: State<'_, GoalCommandState>, id: String) -> Result<(), String> {
    state
        .service()
        .delete_goal(&id)
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn sync_goal_progress(
    state: State<'_, GoalCommandState>,
    goal_id: String,
) -> Result<GoalDto, String> {
    state
        .service()
        .sync_goal_progress(&goal_id)
        .await
        .map(GoalDto::from)
        .map_err(|e| e.to_string())
}
```

- [ ] **Step 5 complete**

### Step 6: Update main.rs — remove direct repository imports

In `src-tauri/src/main.rs`, the `goal_commands` imports currently include `create_default_state_from_pool as create_goal_default_state_from_pool` which still works. But verify the import path no longer pulls in `SqliteGoalRepository` directly. No changes should be needed in `main.rs` since `GoalCommandState::from_pool()` is unchanged in its API.

- [ ] **Step 6 complete** (verification only — may need no code changes)

### Step 7: Verify everything compiles

```bash
cd src-tauri && cargo check
```

Expected: Compiles with no errors.

Then run full check:
```bash
make check
```

- [ ] **Step 7 complete**

### Step 8: Commit Task 23

```bash
git add -A
git commit -m "refactor: add GoalService and refactor BudgetService for DDD consistency

- Create GoalService with all 8 methods (CRUD + sync + progress)
- Refactor BudgetService to accept Arc<SqliteBudgetRepository> and add CRUD
- Slim down budget_commands.rs and goal_commands.rs to thin wrappers
- All business logic now lives in the application service layer
- Follows established DebtService/HoldingService patterns

Task 23 of Sprint 6 — Code Quality."
```

- [ ] **Step 8 complete**

---

## Final Verification

After all three tasks are complete:

```bash
# Frontend
pnpm type-check
pnpm lint

# Backend
make check
make test

# Full build
make build
```

All should pass with zero errors.
