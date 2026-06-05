import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import {
  Landmark,
  ArrowLeft,
  Wallet,
  PiggyBank,
  CreditCard,
  TrendingUp,
  HandCoins,
  ArrowRightLeft,
  Banknote,
  Receipt,
  CircleDollarSign,
  Layers,
} from 'lucide-react';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Label } from './ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from './ui/select';
import { getUserFriendlyError } from '../lib/error-handler';
import { useCurrencies } from '../hooks/useCurrency';
import { createAccount } from '../lib/tauri/account';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import type { AccountType, Ownership } from '../lib/tauri/account';

type WizardStep = 1 | 2 | 3;
type AccountNature = 'asset' | 'liability' | 'income-expense';

const ASSET_TYPES: { type: AccountType; labelKey: string; icon: React.ReactNode }[] = [
  { type: 'Cash', labelKey: 'accountForm.cashWithChinese', icon: <Wallet className="h-5 w-5" /> },
  { type: 'Bank', labelKey: 'accountForm.bankWithChinese', icon: <Landmark className="h-5 w-5" /> },
  { type: 'Investment', labelKey: 'accountForm.investmentWithChinese', icon: <TrendingUp className="h-5 w-5" /> },
  { type: 'BorrowedOut', labelKey: 'accountForm.borrowedOutWithChinese', icon: <HandCoins className="h-5 w-5" /> },
  { type: 'Prepaid', labelKey: 'accountForm.prepaidWithChinese', icon: <PiggyBank className="h-5 w-5" /> },
  { type: 'Other', labelKey: 'accountForm.otherWithChinese', icon: <Layers className="h-5 w-5" /> },
];

const LIABILITY_TYPES: { type: AccountType; labelKey: string; icon: React.ReactNode }[] = [
  { type: 'CreditCard', labelKey: 'accountForm.creditCardWithChinese', icon: <CreditCard className="h-5 w-5" /> },
  { type: 'BorrowedIn', labelKey: 'accountForm.borrowedInWithChinese', icon: <ArrowRightLeft className="h-5 w-5" /> },
];

const INCOME_EXPENSE_TYPES: { type: AccountType; labelKey: string; icon: React.ReactNode }[] = [
  { type: 'Income', labelKey: 'accountForm.incomeWithChinese', icon: <Banknote className="h-5 w-5" /> },
  { type: 'Expense', labelKey: 'accountForm.expenseWithChinese', icon: <Receipt className="h-5 w-5" /> },
];

const TYPE_ICONS: Record<AccountType, string> = {
  Cash: '💵',
  Bank: '🏦',
  CreditCard: '💳',
  Investment: '📈',
  BorrowedOut: '🤝',
  BorrowedIn: '📝',
  Prepaid: '💳',
  Other: '📁',
  Income: '💰',
  Expense: '💸',
};

const TYPE_COLORS: Record<AccountType, string> = {
  Cash: '#10B981',
  Bank: '#3B82F6',
  CreditCard: '#EF4444',
  Investment: '#8B5CF6',
  BorrowedOut: '#F59E0B',
  BorrowedIn: '#06B6D4',
  Prepaid: '#EC4899',
  Other: '#6B7280',
  Income: '#10B981',
  Expense: '#F97316',
};

const DEFAULT_CHART_CODES: Partial<Record<AccountType, string>> = {
  Cash: '1001',
  Bank: '1002',
  Investment: '1101',
  BorrowedOut: '1221',
  BorrowedIn: '2001',
  Prepaid: '1123',
};

interface AccountWizardProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

export function AccountWizard({ open, onOpenChange }: AccountWizardProps) {
  const { t } = useTranslation();
  const { data: currencies = [] } = useCurrencies();
  const queryClient = useQueryClient();
  const createMutation = useMutation({
    mutationFn: createAccount,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['accounts'] });
    },
  });

  const [step, setStep] = useState<WizardStep>(1);
  const [nature, setNature] = useState<AccountNature | null>(null);
  const [accountType, setAccountType] = useState<AccountType | null>(null);

  // Step 3 form fields
  const [name, setName] = useState('');
  const [initialBalance, setInitialBalance] = useState('0.00');
  const [currencyCode, setCurrencyCode] = useState('CNY');
  const [icon, setIcon] = useState('💰');
  const [color, setColor] = useState('#10B981');
  const [chartCode, setChartCode] = useState('');
  const [accountNumber, setAccountNumber] = useState('');
  const [institution, setInstitution] = useState('');
  const [creditLimit, setCreditLimit] = useState('');
  const [billingDay, setBillingDay] = useState('');
  const [paymentDueDay, setPaymentDueDay] = useState('');
  const [interestRate, setInterestRate] = useState('');
  const [lowBalanceThreshold, setLowBalanceThreshold] = useState('');

  const resetWizard = () => {
    setStep(1);
    setNature(null);
    setAccountType(null);
    setName('');
    setInitialBalance('0.00');
    setCurrencyCode('CNY');
    setIcon('💰');
    setColor('#10B981');
    setChartCode('');
    setAccountNumber('');
    setInstitution('');
    setCreditLimit('');
    setBillingDay('');
    setPaymentDueDay('');
    setInterestRate('');
    setLowBalanceThreshold('');
  };

  const handleClose = () => {
    resetWizard();
    onOpenChange(false);
  };

  const handleSubmit = () => {
    if (!name.trim()) {
      toast.error(t('accountForm.nameRequired'));
      return;
    }
    if (!accountType) return;

    const ownership: Ownership =
      accountType === 'Income' || accountType === 'Expense' ? 'external'
        : accountType === 'CreditCard' || accountType === 'BorrowedIn' ? 'liability'
        : 'own';

    const dto = {
      name: name.trim(),
      account_type: accountType,
      ownership,
      currency_code: currencyCode,
      initial_balance: parseFloat(initialBalance) || 0,
      icon: icon || TYPE_ICONS[accountType],
      color: color || TYPE_COLORS[accountType],
      ...(accountNumber ? { account_number: accountNumber } : {}),
      ...(institution ? { institution } : {}),
      ...(creditLimit ? { credit_limit: parseFloat(creditLimit) } : {}),
      ...(billingDay ? { billing_day: parseInt(billingDay) } : {}),
      ...(paymentDueDay ? { payment_due_day: parseInt(paymentDueDay) } : {}),
      ...(interestRate ? { interest_rate: parseFloat(interestRate) } : {}),
      ...(lowBalanceThreshold ? { low_balance_threshold: parseFloat(lowBalanceThreshold) } : {}),
      ...(chartCode ? { chart_code: chartCode } : {}),
    };

    createMutation.mutate(dto, {
      onSuccess: () => {
        toast.success(t('accounts.accountCreated'));
        handleClose();
      },
      onError: (error) => toast.error(getUserFriendlyError(error)),
    });
  };

  const getAvailableTypes = () => {
    if (nature === 'asset') return ASSET_TYPES;
    if (nature === 'liability') return LIABILITY_TYPES;
    if (nature === 'income-expense') return INCOME_EXPENSE_TYPES;
    return [];
  };

  const getStepTitle = () => {
    switch (step) {
      case 1:
        return t('account.createWizard.step1Title');
      case 2:
        return t('account.createWizard.step2Title');
      case 3:
        return t('account.createWizard.step3Title');
    }
  };

  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex justify-end">
      {/* Backdrop */}
      <div
        className="absolute inset-0 bg-black/40"
        onClick={handleClose}
      />

      {/* Panel */}
      <div className="relative z-10 flex h-full w-full flex-col bg-background sm:max-w-lg border-l shadow-xl">
        {/* Header */}
        <div className="flex items-center gap-3 border-b px-6 py-4">
          {step > 1 && (
            <Button
              variant="ghost"
              size="sm"
              className="h-8 w-8 p-0"
              onClick={() => setStep((s) => (s - 1) as WizardStep)}
            >
              <ArrowLeft className="h-4 w-4" />
            </Button>
          )}
          <div className="flex-1">
            <h2 className="text-lg font-semibold">{getStepTitle()}</h2>
            <p className="text-xs text-muted-foreground">
              {t('account.createWizard.title')} · {t('common.pageInfo', { page: step, total: 3 })}
            </p>
          </div>
          <Button variant="ghost" size="sm" onClick={handleClose}>
            {t('common.cancel')}
          </Button>
        </div>

        {/* Content */}
        <div className="flex-1 overflow-y-auto px-6 py-6">
          {/* Step 1: Choose Account Nature */}
          {step === 1 && (
            <div className="space-y-4">
              <div
                className={`cursor-pointer rounded-xl border-2 p-5 transition-all hover:shadow-md ${
                  nature === 'asset'
                    ? 'border-emerald-500 bg-emerald-50/50 dark:bg-emerald-950/20'
                    : 'border-border hover:border-emerald-300'
                }`}
                onClick={() => {
                  setNature('asset');
                  setAccountType(null);
                  setStep(2);
                }}
              >
                <div className="flex items-start gap-4">
                  <div className="rounded-lg bg-emerald-100 p-3 text-emerald-700 dark:bg-emerald-900 dark:text-emerald-400">
                    <Landmark className="h-6 w-6" />
                  </div>
                  <div className="flex-1">
                    <h3 className="font-semibold">{t('account.createWizard.assetAccount')}</h3>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {t('account.createWizard.assetAccountDesc')}
                    </p>
                    <div className="mt-3 flex flex-wrap gap-2">
                      {ASSET_TYPES.map(({ type, icon }) => (
                        <span
                          key={type}
                          className="inline-flex items-center gap-1 rounded-full bg-emerald-100 px-2 py-0.5 text-xs text-emerald-700 dark:bg-emerald-900 dark:text-emerald-400"
                        >
                          <span className="h-3 w-3 [&>svg]:h-3 [&>svg]:w-3">{icon}</span> {t(`accountForm.${type.toLowerCase()}WithChinese`)}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
              </div>

              <div
                className={`cursor-pointer rounded-xl border-2 p-5 transition-all hover:shadow-md ${
                  nature === 'liability'
                    ? 'border-red-500 bg-red-50/50 dark:bg-red-950/20'
                    : 'border-border hover:border-red-300'
                }`}
                onClick={() => {
                  setNature('liability');
                  setAccountType(null);
                  setStep(2);
                }}
              >
                <div className="flex items-start gap-4">
                  <div className="rounded-lg bg-red-100 p-3 text-red-700 dark:bg-red-900 dark:text-red-400">
                    <CreditCard className="h-6 w-6" />
                  </div>
                  <div className="flex-1">
                    <h3 className="font-semibold">{t('account.createWizard.liabilityAccount')}</h3>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {t('account.createWizard.liabilityAccountDesc')}
                    </p>
                    <div className="mt-3 flex flex-wrap gap-2">
                      {LIABILITY_TYPES.map(({ type, icon }) => (
                        <span
                          key={type}
                          className="inline-flex items-center gap-1 rounded-full bg-red-100 px-2 py-0.5 text-xs text-red-700 dark:bg-red-900 dark:text-red-400"
                        >
                          <span className="h-3 w-3 [&>svg]:h-3 [&>svg]:w-3">{icon}</span> {t(`accountForm.${type.toLowerCase()}WithChinese`)}
                        </span>
                      ))}
                      </div>
                  </div>
                </div>
              </div>

              <div
                className={`cursor-pointer rounded-xl border-2 p-5 transition-all hover:shadow-md ${
                  nature === 'income-expense'
                    ? 'border-amber-500 bg-amber-50/50 dark:bg-amber-950/20'
                    : 'border-border hover:border-amber-300'
                }`}
                onClick={() => {
                  setNature('income-expense');
                  setAccountType(null);
                  setStep(2);
                }}
              >
                <div className="flex items-start gap-4">
                  <div className="rounded-lg bg-amber-100 p-3 text-amber-700 dark:bg-amber-900 dark:text-amber-400">
                    <CircleDollarSign className="h-6 w-6" />
                  </div>
                  <div className="flex-1">
                    <h3 className="font-semibold">{t('account.createWizard.incomeExpenseAccount')}</h3>
                    <p className="mt-1 text-sm text-muted-foreground">
                      {t('account.createWizard.incomeExpenseAccountDesc')}
                    </p>
                    <div className="mt-3 flex flex-wrap gap-2">
                      {INCOME_EXPENSE_TYPES.map(({ type, icon }) => (
                        <span
                          key={type}
                          className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 text-xs text-amber-700 dark:bg-amber-900 dark:text-amber-400"
                        >
                          <span className="h-3 w-3 [&>svg]:h-3 [&>svg]:w-3">{icon}</span> {t(`accountForm.${type.toLowerCase()}WithChinese`)}
                        </span>
                      ))}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Step 2: Choose Account Type */}
          {step === 2 && (
            <div className="space-y-4">
              <div className="grid grid-cols-1 gap-3">
                {getAvailableTypes().map((item) => (
                  <button
                    key={item.type}
                    className={`flex items-center gap-4 rounded-xl border-2 p-4 text-left transition-all hover:shadow-md ${
                      accountType === item.type
                        ? 'border-primary bg-primary/5'
                        : 'border-border hover:border-primary/50'
                    }`}
                    onClick={() => {
                      setAccountType(item.type);
                      setIcon(TYPE_ICONS[item.type]);
                      setColor(TYPE_COLORS[item.type]);
                      setChartCode(DEFAULT_CHART_CODES[item.type] ?? '');
                      setStep(3);
                    }}
                  >
                    <div className="rounded-lg bg-muted p-2.5">{item.icon}</div>
                    <div>
                      <div className="font-medium">{t(item.labelKey)}</div>
                      <div className="text-xs text-muted-foreground">{item.type}</div>
                    </div>
                  </button>
                ))}
              </div>
            </div>
          )}

          {/* Step 3: Fill in Details */}
          {step === 3 && accountType && (
            <div className="space-y-5">
              {/* Selected type summary */}
              <div className="flex items-center gap-3 rounded-lg border bg-muted/50 px-4 py-3">
                <span className="text-2xl">{icon}</span>
                <div>
                  <div className="text-sm font-medium">{t(`accountForm.${accountType.toLowerCase()}WithChinese`)}</div>
                  <div className="text-xs text-muted-foreground">
                    {nature === 'asset'
                      ? t('account.createWizard.assetAccount')
                      : nature === 'liability'
                        ? t('account.createWizard.liabilityAccount')
                        : t('account.createWizard.incomeExpenseAccount')}
                  </div>
                </div>
              </div>

              {/* Name */}
              <div className="space-y-2">
                <Label>
                  {t('accountForm.accountName')} <span className="text-red-500">*</span>
                </Label>
                <Input
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder={t('accountForm.accountNamePlaceholder')}
                />
              </div>

              {/* Icon & Color */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>{t('accountForm.iconLabel')}</Label>
                  <div className="flex items-center gap-2">
                    <Input
                      value={icon}
                      onChange={(e) => setIcon(e.target.value)}
                      className="w-16 text-center text-xl"
                    />
                    <span className="text-2xl">{icon}</span>
                  </div>
                </div>
                <div className="space-y-2">
                  <Label>{t('accountForm.colorLabel')}</Label>
                  <div className="flex items-center gap-2">
                    <input
                      type="color"
                      value={color}
                      onChange={(e) => setColor(e.target.value)}
                      className="h-9 w-9 rounded cursor-pointer"
                    />
                    <Input value={color} onChange={(e) => setColor(e.target.value)} />
                  </div>
                </div>
              </div>

              {/* Currency & Initial Balance */}
              <div className="grid grid-cols-2 gap-4">
                <div className="space-y-2">
                  <Label>
                    {t('accountForm.currency')} <span className="text-red-500">*</span>
                  </Label>
                  <Select value={currencyCode} onValueChange={(v) => setCurrencyCode(v ?? 'CNY')}>
                    <SelectTrigger>
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      {currencies.map((c) => (
                        <SelectItem key={c.code} value={c.code}>
                          {c.symbol} {c.name} ({c.code})
                        </SelectItem>
                      ))}
                    </SelectContent>
                  </Select>
                </div>
                <div className="space-y-2">
                  <Label>
                    {t('accountForm.initialBalance')} <span className="text-red-500">*</span>
                  </Label>
                  <Input
                    type="number"
                    step="0.01"
                    value={initialBalance}
                    onChange={(e) => setInitialBalance(e.target.value)}
                  />
                </div>
              </div>

              {/* Optional fields */}
              <div className="space-y-4 rounded-lg border p-4">
                <p className="text-xs font-medium uppercase tracking-wider text-muted-foreground">
                  {t('accountForm.advancedOptions')}
                </p>

                <div className="grid grid-cols-2 gap-4">
                  <div className="space-y-2">
                    <Label>{t('accountForm.accountNumber')}</Label>
                    <Input
                      value={accountNumber}
                      onChange={(e) => setAccountNumber(e.target.value)}
                      placeholder={t('accountForm.accountNumberPlaceholder')}
                    />
                  </div>
                  <div className="space-y-2">
                    <Label>{t('accountForm.institution')}</Label>
                    <Input
                      value={institution}
                      onChange={(e) => setInstitution(e.target.value)}
                      placeholder={t('accountForm.institutionPlaceholder')}
                    />
                  </div>
                </div>

                {/* Chart of Account Code */}
                <div className="space-y-2">
                  <Label>{t('chartOfAccounts.code')}</Label>
                  <div className="flex items-center gap-2">
                    <Input
                      value={chartCode}
                      onChange={(e) => setChartCode(e.target.value)}
                      placeholder="e.g. 1001"
                    />
                    {chartCode && DEFAULT_CHART_CODES[accountType] === chartCode && (
                      <span className="text-xs text-emerald-600 bg-emerald-50 px-2 py-1 rounded">
                        {t('category.system')}
                      </span>
                    )}
                  </div>
                  <p className="text-xs text-muted-foreground">
                    {t('chartOfAccounts.standard')}: {t('chartOfAccounts.chinaCAS')}
                  </p>
                </div>

                {/* CreditCard-specific */}
                {accountType === 'CreditCard' && (
                  <div className="space-y-4 rounded-lg bg-orange-50/50 p-3 dark:bg-orange-950/20">
                    <p className="text-xs font-medium text-orange-700 dark:text-orange-400">
                      {t('accountForm.creditCardDetails')}
                    </p>
                    <div className="grid grid-cols-3 gap-3">
                      <div className="space-y-2">
                        <Label>{t('accountForm.creditLimit')}</Label>
                        <Input
                          type="number"
                          value={creditLimit}
                          onChange={(e) => setCreditLimit(e.target.value)}
                        />
                      </div>
                      <div className="space-y-2">
                        <Label>{t('accountForm.billingDay')}</Label>
                        <Input
                          type="number"
                          min={1}
                          max={31}
                          value={billingDay}
                          onChange={(e) => setBillingDay(e.target.value)}
                        />
                      </div>
                      <div className="space-y-2">
                        <Label>{t('accountForm.paymentDueDay')}</Label>
                        <Input
                          type="number"
                          min={1}
                          max={31}
                          value={paymentDueDay}
                          onChange={(e) => setPaymentDueDay(e.target.value)}
                        />
                      </div>
                    </div>
                  </div>
                )}

                {/* BorrowedIn / BorrowedOut / Loan interest */}
                {(accountType === 'BorrowedIn' || accountType === 'BorrowedOut') && (
                  <div className="space-y-2">
                    <Label>{t('accountForm.interestRate')}</Label>
                    <Input
                      type="number"
                      step="0.01"
                      value={interestRate}
                      onChange={(e) => setInterestRate(e.target.value)}
                    />
                    <p className="text-xs text-muted-foreground">{t('accountForm.interestRateDesc')}</p>
                  </div>
                )}

                {/* Prepaid low balance */}
                {accountType === 'Prepaid' && (
                  <div className="space-y-2">
                    <Label>{t('accountForm.lowBalanceThreshold')}</Label>
                    <Input
                      type="number"
                      step="0.01"
                      value={lowBalanceThreshold}
                      onChange={(e) => setLowBalanceThreshold(e.target.value)}
                    />
                  </div>
                )}
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        {step === 3 && (
          <div className="border-t px-6 py-4">
            <div className="flex gap-3">
              <Button
                className="flex-1"
                onClick={handleSubmit}
                disabled={createMutation.isPending || !name.trim()}
              >
                {createMutation.isPending ? t('accountForm.creating') : t('accountForm.createAccount')}
              </Button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
