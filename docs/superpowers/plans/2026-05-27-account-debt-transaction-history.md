# Account & Debt Transaction History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add detail panels with associated transaction history to AccountsPage and DebtsPage, using a shared TransactionList component.

**Architecture:** Extract a reusable `TransactionList` presentational component that renders transaction records with debit/credit coloring. Create `AccountDetailPanel` and `DebtDetailPanel` Sheet components that each show entity summary info + payment schedule (debt only) + `<TransactionList>`. Wire them into existing pages via "View" button state. Refactor `PrepaidDetailPanel` to use `TransactionList` internally.

**Tech Stack:** React (TypeScript), TanStack Query, shadcn/ui (Sheet, Table, Badge, Separator), i18next

---

## File Structure

### New files

| File | Responsibility |
|------|---------------|
| `src/components/TransactionList.tsx` | Shared transaction list renderer with debit/credit coloring |

### Modified files

| File | Change |
|------|--------|
| `src/components/PrepaidDetailPanel.tsx` | Replace manual consumption table with `<TransactionList>` |
| `src/pages/AccountsPage.tsx` | Add View button for all accounts, wire up AccountDetailPanel Sheet |
| `src/pages/DebtsPage.tsx` | Change View button to open DebtDetailPanel Sheet |
| `src/i18n/locales/zh.json` | Add new i18n keys for panels |
| `src/i18n/locales/en.json` | Add new i18n keys for panels |

---

### Task 1: Create shared TransactionList component

**Files:**
- Create: `src/components/TransactionList.tsx`

- [ ] **Step 1: Create TransactionList.tsx**

Create `src/components/TransactionList.tsx`:

```tsx
import { useTranslation } from 'react-i18next';
import { Receipt } from 'lucide-react';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from './ui/table';
import type { TransactionDto } from '@/lib/tauri/transaction';

interface TransactionListProps {
  transactions: TransactionDto[];
  accountId?: string;
  currencyCode?: string;
  isLoading?: boolean;
}

function formatAmount(amount: string | number, currencyCode?: string) {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount;
  if (isNaN(num)) return '-';
  const symbols: Record<string, string> = { CNY: '¥', USD: '$', EUR: '€' };
  const symbol = currencyCode ? (symbols[currencyCode] || currencyCode) : '';
  return `${symbol}${num.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

export function TransactionList({ transactions, accountId, currencyCode, isLoading }: TransactionListProps) {
  const { t } = useTranslation();

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-8">
        <div className="text-muted-foreground">{t('common.loading')}</div>
      </div>
    );
  }

  if (transactions.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center py-8 text-center">
        <Receipt className="h-8 w-8 text-muted-foreground/50 mb-2" />
        <p className="text-sm text-muted-foreground">{t('accounts.noTransactions') || t('prepaid.noConsumptionRecords')}</p>
      </div>
    );
  }

  const sorted = [...transactions].sort(
    (a, b) => b.transaction_date.localeCompare(a.transaction_date)
  );

  return (
    <div className="border rounded-lg">
      <Table>
        <TableHeader>
          <TableRow>
            <TableHead className="w-[100px]">{t('common.date')}</TableHead>
            <TableHead>{t('common.description')}</TableHead>
            <TableHead className="text-right w-[120px]">{t('common.amount')}</TableHead>
          </TableRow>
        </TableHeader>
        <TableBody>
          {sorted.map((tx) => {
            let amount = '';
            let isDebit = false;

            if (accountId) {
              const entry = tx.entries.find((e) => e.account_id === accountId);
              if (entry) {
                if (entry.debit_amount && parseFloat(entry.debit_amount) > 0) {
                  amount = entry.debit_amount;
                  isDebit = true;
                } else if (entry.credit_amount && parseFloat(entry.credit_amount) > 0) {
                  amount = entry.credit_amount;
                  isDebit = false;
                }
              }
            } else {
              // No accountId: show first debit entry amount
              const debitEntry = tx.entries.find(
                (e) => e.debit_amount && parseFloat(e.debit_amount) > 0
              );
              const creditEntry = tx.entries.find(
                (e) => e.credit_amount && parseFloat(e.credit_amount) > 0
              );
              if (debitEntry) {
                amount = debitEntry.debit_amount!;
                isDebit = true;
              } else if (creditEntry) {
                amount = creditEntry.credit_amount!;
                isDebit = false;
              }
            }

            return (
              <TableRow key={tx.id}>
                <TableCell className="text-xs text-muted-foreground">
                  {tx.transaction_date}
                </TableCell>
                <TableCell className="text-xs">
                  {tx.description || '-'}
                </TableCell>
                <TableCell className={`text-xs text-right font-medium ${isDebit ? 'text-red-600' : 'text-emerald-600'}`}>
                  {amount ? `${isDebit ? '-' : '+'}${formatAmount(amount, currencyCode)}` : '-'}
                </TableCell>
              </TableRow>
            );
          })}
        </TableBody>
      </Table>
    </div>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/TransactionList.tsx
git commit -m "feat: add shared TransactionList component"
```

---

### Task 2: Add i18n keys

**Files:**
- Modify: `src/i18n/locales/zh.json`
- Modify: `src/i18n/locales/en.json`

- [ ] **Step 1: Add Chinese i18n keys**

In `src/i18n/locales/zh.json`, add the following keys to the `"accounts"` section (after the existing keys, before the closing `}`):

```json
"noTransactions": "暂无交易记录",
"detailTitle": "账户详情",
"accountTransactions": "交易记录",
"initialBalance": "初始余额",
"currentBalance": "当前余额"
```

In the `"debts"` section, add:

```json
"transactionHistory": "交易记录",
"noTransactions": "暂无交易记录",
"scheduledDate": "计划还款日",
"scheduledAmount": "计划还款额",
"actualPaymentDate": "实际还款日期",
"actualPaymentAmount": "实际还款金额"
```

- [ ] **Step 2: Add English i18n keys**

In `src/i18n/locales/en.json`, add to `"accounts"` section:

```json
"noTransactions": "No transactions yet",
"detailTitle": "Account Details",
"accountTransactions": "Transactions",
"initialBalance": "Initial Balance",
"currentBalance": "Current Balance"
```

In `"debts"` section:

```json
"transactionHistory": "Transaction History",
"noTransactions": "No transactions yet",
"scheduledDate": "Scheduled Date",
"scheduledAmount": "Scheduled Amount",
"actualPaymentDate": "Actual Payment Date",
"actualPaymentAmount": "Actual Payment Amount"
```

- [ ] **Step 3: Verify TypeScript compiles**

Run: `npx tsc --noEmit`
Expected: SUCCESS

- [ ] **Step 4: Commit**

```bash
git add src/i18n/locales/zh.json src/i18n/locales/en.json
git commit -m "feat: add i18n keys for account and debt detail panels"
```

---

### Task 3: Refactor PrepaidDetailPanel to use TransactionList

**Files:**
- Modify: `src/components/PrepaidDetailPanel.tsx`

- [ ] **Step 1: Replace manual consumption table with TransactionList**

In `src/components/PrepaidDetailPanel.tsx`:

1. Add import at the top:
```tsx
import { TransactionList } from './TransactionList';
```

2. Remove the `consumptionRecords` useMemo block (lines 61-85 — the one that manually filters and maps transactions into records).

3. Replace the entire `activeTab === 'consumption'` section (lines 207-236) with:
```tsx
{activeTab === 'consumption' && (
  <div className="mt-4">
    <TransactionList
      transactions={transactions}
      accountId={accountId}
      currencyCode={detail?.currency_code}
      isLoading={false}
    />
  </div>
)}
```

This replaces the manual Table/TableHeader/TableBody consumption rendering with the shared `TransactionList` component. The `accountId` prop ensures it shows only amounts relevant to this prepaid account.

- [ ] **Step 2: Verify TypeScript compiles**

Run: `npx tsc --noEmit`
Expected: SUCCESS

- [ ] **Step 3: Commit**

```bash
git add src/components/PrepaidDetailPanel.tsx
git commit -m "refactor: use shared TransactionList in PrepaidDetailPanel"
```

---

### Task 4: Create AccountDetailPanel

**Files:**
- Create: `src/components/AccountDetailPanel.tsx`

- [ ] **Step 1: Create AccountDetailPanel.tsx**

Create `src/components/AccountDetailPanel.tsx`:

```tsx
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { Badge } from './ui/badge';
import { Separator } from './ui/separator';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from './ui/sheet';
import { TransactionList } from './TransactionList';
import { getTransactionsByAccount } from '@/lib/tauri/transaction';
import type { AccountDto } from '@/lib/tauri/account';

interface AccountDetailPanelProps {
  account: AccountDto;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

function formatBalance(amount: number | string, currencyCode: string) {
  const num = typeof amount === 'string' ? parseFloat(amount) : amount;
  const symbols: Record<string, string> = { CNY: '¥', USD: '$', EUR: '€' };
  const symbol = symbols[currencyCode] || currencyCode;
  return `${symbol}${num.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

const typeColors: Record<string, string> = {
  Cash: 'bg-gray-100 text-gray-800',
  Bank: 'bg-blue-100 text-blue-800',
  CreditCard: 'bg-orange-100 text-orange-800',
  Investment: 'bg-purple-100 text-purple-800',
  BorrowedOut: 'bg-amber-100 text-amber-800',
  BorrowedIn: 'bg-red-100 text-red-800',
  Prepaid: 'bg-teal-100 text-teal-800',
  Income: 'bg-green-100 text-green-800',
  Expense: 'bg-pink-100 text-pink-800',
  Other: 'bg-gray-100 text-gray-800',
};

export function AccountDetailPanel({ account, open, onOpenChange }: AccountDetailPanelProps) {
  const { t } = useTranslation();

  const { data: transactions = [], isLoading: isLoadingTx } = useQuery({
    queryKey: ['account-transactions', account.id],
    queryFn: () => getTransactionsByAccount(account.id),
    enabled: open && !!account.id,
  });

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle className="flex items-center gap-2">
            {account.name}
            <Badge className={typeColors[account.account_type] || typeColors.Other}>
              {account.account_type}
            </Badge>
          </SheetTitle>
        </SheetHeader>
        <div className="flex-1 overflow-y-auto -mx-4 px-4">
          <div className="space-y-4 px-5 pt-4">
            {/* Summary */}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('common.currency')}</div>
                <div className="text-sm font-medium">{account.currency_code}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('accounts.initialBalance')}</div>
                <div className="text-sm font-medium">{formatBalance(account.initial_balance, account.currency_code)}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('accounts.currentBalance')}</div>
                <div className="text-sm font-bold">{formatBalance(account.current_balance, account.currency_code)}</div>
              </div>
              {account.account_number && (
                <div>
                  <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('accountForm.accountNumber')}</div>
                  <div className="text-sm font-medium">{account.account_number}</div>
                </div>
              )}
              {account.institution && (
                <div>
                  <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('accountForm.institution')}</div>
                  <div className="text-sm font-medium">{account.institution}</div>
                </div>
              )}
            </div>

            <Separator />

            {/* Transaction History */}
            <div>
              <h3 className="text-sm font-medium mb-2">{t('accounts.accountTransactions')}</h3>
              <TransactionList
                transactions={transactions}
                accountId={account.id}
                currencyCode={account.currency_code}
                isLoading={isLoadingTx}
              />
            </div>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/AccountDetailPanel.tsx
git commit -m "feat: add AccountDetailPanel with transaction history"
```

---

### Task 5: Wire AccountDetailPanel into AccountsPage

**Files:**
- Modify: `src/pages/AccountsPage.tsx`

- [ ] **Step 1: Add import**

At the top of `src/pages/AccountsPage.tsx`, add after the existing imports:

```tsx
import { AccountDetailPanel } from '../components/AccountDetailPanel';
```

- [ ] **Step 2: Add detailAccount state**

After the existing `const [detailAccountId, setDetailAccountId]` line (line ~68), add:

```tsx
const [detailAccount, setDetailAccount] = useState<AccountDto | null>(null);
```

- [ ] **Step 3: Add View button for all non-prepaid accounts**

In the table row actions cell (lines 358-401), **after** the closing `</>` of the prepaid section (line 378) and **before** the Copy button, add a View button for non-prepaid accounts:

Change the actions cell from:
```tsx
<TableCell>
  {account.account_type === 'Prepaid' && (
    <>
      <Button
        variant="ghost"
        size="sm"
        onClick={() => setTopUpAccountId(account.id)}
        title={t('prepaid.topUpTitle')}
      >
        <Wallet className="h-4 w-4 text-emerald-500" />
      </Button>
      <Button
        variant="ghost"
        size="sm"
        onClick={() => setDetailAccountId(account.id)}
        title={t('prepaid.detailTitle')}
      >
        <Eye className="h-4 w-4 text-purple-500" />
      </Button>
    </>
  )}
```

To:
```tsx
<TableCell>
  {account.account_type === 'Prepaid' && (
    <>
      <Button
        variant="ghost"
        size="sm"
        onClick={() => setTopUpAccountId(account.id)}
        title={t('prepaid.topUpTitle')}
      >
        <Wallet className="h-4 w-4 text-emerald-500" />
      </Button>
      <Button
        variant="ghost"
        size="sm"
        onClick={() => setDetailAccountId(account.id)}
        title={t('prepaid.detailTitle')}
      >
        <Eye className="h-4 w-4 text-purple-500" />
      </Button>
    </>
  )}
  {account.account_type !== 'Prepaid' && (
    <Button
      variant="ghost"
      size="sm"
      onClick={() => setDetailAccount(account)}
      title={t('debts.view')}
    >
      <Eye className="h-4 w-4 text-purple-500" />
    </Button>
  )}
```

- [ ] **Step 4: Add AccountDetailPanel Sheet at the bottom**

After the existing `{/* Prepaid: Detail Panel */}` block (lines 478-485), add:

```tsx
{/* Account Detail Panel */}
{detailAccount && (
  <AccountDetailPanel
    account={detailAccount}
    open={!!detailAccount}
    onOpenChange={(open) => { if (!open) setDetailAccount(null); }}
  />
)}
```

- [ ] **Step 5: Verify TypeScript compiles**

Run: `npx tsc --noEmit`
Expected: SUCCESS

- [ ] **Step 6: Commit**

```bash
git add src/pages/AccountsPage.tsx
git commit -m "feat: add View button and AccountDetailPanel to AccountsPage"
```

---

### Task 6: Create DebtDetailPanel

**Files:**
- Create: `src/components/DebtDetailPanel.tsx`

- [ ] **Step 1: Create DebtDetailPanel.tsx**

Create `src/components/DebtDetailPanel.tsx`:

```tsx
import { useQuery } from '@tanstack/react-query';
import { useTranslation } from 'react-i18next';
import { CheckCircle2 } from 'lucide-react';
import { Badge } from './ui/badge';
import { Separator } from './ui/separator';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
} from './ui/sheet';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from './ui/table';
import { TransactionList } from './TransactionList';
import { getTransactionsByAccount } from '@/lib/tauri/transaction';
import type { DebtDto } from '@/lib/tauri/debt';

interface DebtDetailPanelProps {
  debt: DebtDto;
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

function formatCurrency(amount: string, currencyCode: string) {
  const num = parseFloat(amount);
  const symbols: Record<string, string> = { CNY: '¥', USD: '$', EUR: '€' };
  const symbol = symbols[currencyCode] || currencyCode;
  return `${symbol}${num.toLocaleString('en-US', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })}`;
}

function debtTypeBadge(type: string) {
  const map: Record<string, string> = {
    BorrowedIn: 'bg-red-100 text-red-800',
    BorrowedOut: 'bg-amber-100 text-amber-800',
    CreditCard: 'bg-orange-100 text-orange-800',
  };
  return map[type] || 'bg-gray-100 text-gray-800';
}

function amortizationLabel(method: string, t: (key: string) => string) {
  const map: Record<string, string> = {
    EqualPrincipalInterest: t('debtForm.equalPI'),
    EqualPrincipal: t('debtForm.equalPrincipal'),
    LumpSum: t('debtForm.lumpSum'),
  };
  return map[method] || method;
}

export function DebtDetailPanel({ debt, open, onOpenChange }: DebtDetailPanelProps) {
  const { t } = useTranslation();

  const { data: transactions = [], isLoading: isLoadingTx } = useQuery({
    queryKey: ['account-transactions', debt.account_id],
    queryFn: () => getTransactionsByAccount(debt.account_id),
    enabled: open && !!debt.account_id,
  });

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="right" className="w-full sm:max-w-2xl">
        <SheetHeader>
          <SheetTitle className="flex items-center gap-2">
            {debt.account_name}
            <Badge className={debtTypeBadge(debt.account_type)}>
              {debt.account_type === 'BorrowedIn' ? t('debtForm.borrowedIn')
                : debt.account_type === 'BorrowedOut' ? t('debtForm.borrowedOut')
                : t('debtForm.creditCard')}
            </Badge>
          </SheetTitle>
        </SheetHeader>
        <div className="flex-1 overflow-y-auto -mx-4 px-4">
          <div className="space-y-4 px-5 pt-4">
            {/* Summary */}
            <div className="grid grid-cols-2 gap-3">
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.counterparty')}</div>
                <div className="text-sm font-medium">{debt.counterparty}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.principal')}</div>
                <div className="text-sm font-medium">{formatCurrency(debt.principal_amount, debt.currency_code)}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.remainingBalance')}</div>
                <div className="text-sm font-bold">{formatCurrency(debt.remaining_principal, debt.currency_code)}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.interestRate')}</div>
                <div className="text-sm font-medium">{debt.interest_rate}%{t('debts.perYear')}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.startDate')}</div>
                <div className="text-sm font-medium">{debt.start_date}</div>
              </div>
              <div>
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debts.dueDate')}</div>
                <div className="text-sm font-medium">{debt.due_date}</div>
              </div>
              <div className="col-span-2">
                <div className="text-xs uppercase tracking-wider text-muted-foreground">{t('debtForm.amortizationMethod')}</div>
                <div className="text-sm font-medium">{amortizationLabel(debt.amortization_method, t)}</div>
              </div>
            </div>

            <Separator />

            {/* Payment Schedule */}
            {debt.payment_schedule && debt.payment_schedule.length > 0 && (
              <>
                <div>
                  <h3 className="text-sm font-medium mb-2">{t('debts.paymentSchedule')}</h3>
                  <div className="border rounded-lg">
                    <Table>
                      <TableHeader>
                        <TableRow>
                          <TableHead className="w-[50px]">#</TableHead>
                          <TableHead>{t('common.date')}</TableHead>
                          <TableHead className="text-right">{t('debts.principal')}</TableHead>
                          <TableHead className="text-right">{t('debts.interest')}</TableHead>
                          <TableHead className="text-right">{t('debts.total')}</TableHead>
                          <TableHead className="w-[50px]">{t('debts.status')}</TableHead>
                        </TableRow>
                      </TableHeader>
                      <TableBody>
                        {debt.payment_schedule.map((p, i) => (
                          <TableRow key={i} className={p.paid ? 'opacity-50' : ''}>
                            <TableCell className="text-xs text-muted-foreground">{i + 1}</TableCell>
                            <TableCell className="text-xs">{p.payment_date}</TableCell>
                            <TableCell className="text-xs text-right">{formatCurrency(p.principal_amount, debt.currency_code)}</TableCell>
                            <TableCell className="text-xs text-right">{formatCurrency(p.interest_amount, debt.currency_code)}</TableCell>
                            <TableCell className="text-xs text-right font-medium">{formatCurrency(p.total_amount, debt.currency_code)}</TableCell>
                            <TableCell>
                              {p.paid ? (
                                <CheckCircle2 className="h-4 w-4 text-emerald-600" />
                              ) : (
                                <span className="text-xs text-muted-foreground">{t('debts.unpaid')}</span>
                              )}
                            </TableCell>
                          </TableRow>
                        ))}
                      </TableBody>
                    </Table>
                  </div>
                </div>
                <Separator />
              </>
            )}

            {/* Transaction History */}
            <div>
              <h3 className="text-sm font-medium mb-2">{t('debts.transactionHistory')}</h3>
              <TransactionList
                transactions={transactions}
                accountId={debt.account_id}
                currencyCode={debt.currency_code}
                isLoading={isLoadingTx}
              />
            </div>
          </div>
        </div>
      </SheetContent>
    </Sheet>
  );
}
```

- [ ] **Step 2: Commit**

```bash
git add src/components/DebtDetailPanel.tsx
git commit -m "feat: add DebtDetailPanel with payment schedule and transaction history"
```

---

### Task 7: Wire DebtDetailPanel into DebtsPage

**Files:**
- Modify: `src/pages/DebtsPage.tsx`

- [ ] **Step 1: Add import**

At the top of `src/pages/DebtsPage.tsx`, add after the existing imports (after `import { DebtForm }`):

```tsx
import { DebtDetailPanel } from '../components/DebtDetailPanel';
```

- [ ] **Step 2: Replace View Sheet with DebtDetailPanel**

In `src/pages/DebtsPage.tsx`, replace the existing View Sheet section (lines 545-562):

```tsx
{/* View Sheet (read-only, reuses DebtForm layout) */}
<Sheet open={!!viewingDebt} onOpenChange={() => setViewingDebt(null)}>
  <SheetContent side="right" className="w-full sm:max-w-lg">
    <SheetHeader>
      <SheetTitle>{t('debts.debtDetails')}</SheetTitle>
    </SheetHeader>
    <div className="flex-1 overflow-y-auto -mx-4 px-4">
      {viewingDebt && (
        <DebtForm
          onSubmit={() => {}}
          onCancel={() => setViewingDebt(null)}
          initialData={viewingDebt}
          mode="view"
        />
      )}
    </div>
  </SheetContent>
</Sheet>
```

With:

```tsx
{/* View Sheet (DebtDetailPanel with schedule + transactions) */}
{viewingDebt && (
  <DebtDetailPanel
    debt={viewingDebt}
    open={!!viewingDebt}
    onOpenChange={(open) => { if (!open) setViewingDebt(null); }}
  />
)}
```

- [ ] **Step 3: Verify TypeScript compiles**

Run: `npx tsc --noEmit`
Expected: SUCCESS

- [ ] **Step 4: Commit**

```bash
git add src/pages/DebtsPage.tsx
git commit -m "feat: wire DebtDetailPanel into DebtsPage view action"
```

---

### Task 8: Verification

- [ ] **Step 1: Build frontend**

Run: `npx tsc --noEmit`
Expected: SUCCESS

- [ ] **Step 2: Launch app**

Run: `npm run tauri dev`

- [ ] **Step 3: Test AccountDetailPanel**

Go to Accounts page, click the Eye icon on a non-prepaid account. Verify:
- Sheet opens on the right
- Shows account summary (name, type, balances)
- Shows transaction list with dates, descriptions, and colored amounts

- [ ] **Step 4: Test PrepaidDetailPanel still works**

Click the Eye icon on a Prepaid account. Verify the existing PrepaidDetailPanel opens with tabs for Top Up and Consumption, and the Consumption tab uses the shared TransactionList styling.

- [ ] **Step 5: Test DebtDetailPanel**

Go to Debts page, click the Eye icon on a debt. Verify:
- Sheet opens on the right
- Shows debt summary (counterparty, principal, remaining, interest rate, dates)
- Shows payment schedule table with per-period interest, paid/unpaid status
- Shows transaction history list
