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
