#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import re

# 读取文件
with open('src/components/TransactionForm.tsx', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. 添加useTranslation导入
if 'useTranslation' not in content:
    content = content.replace(
        "import { z } from 'zod';",
        "import { useTranslation } from 'react-i18next';\nimport { z } from 'zod';"
    )

# 2. 在组件开始处添加useTranslation hook和移动schema到组件内
old_component_start = '''export function TransactionForm({ onSubmit, onCancel, isLoading }: TransactionFormProps) {
  const { data: accounts = [] } = useQuery({'''

new_component_start = '''export function TransactionForm({ onSubmit, onCancel, isLoading }: TransactionFormProps) {
  const { t } = useTranslation();
  
  const transactionEntrySchema = z
    .object({
      account_id: z.string().min(1, t('transactionForm.accountRequired')),
      chart_of_account_code: z.string().min(1, t('transactionForm.chartCodeRequired')),
      debit_amount: z.string().nullable(),
      credit_amount: z.string().nullable(),
      memo: z.string().nullable(),
      category_id: z.string().optional(),
    })
    .refine(
      (data) => {
        const hasDebit = data.debit_amount && data.debit_amount !== '' && parseFloat(data.debit_amount) !== 0;
        const hasCredit = data.credit_amount && data.credit_amount !== '' && parseFloat(data.credit_amount) !== 0;
        return (hasDebit && !hasCredit) || (!hasDebit && hasCredit);
      },
      {
        message: t('transactionForm.entryAmountRequired'),
        path: ['debit_amount'],
      }
    );

  const transactionFormSchema = z.object({
    transaction_date: z.string().min(1, t('transactionForm.dateRequired')),
    description: z.string().min(1, t('transactionForm.descriptionRequired')),
    entries: z.array(transactionEntrySchema).min(2, t('transactionForm.minEntries')),
  });
  
  const { data: accounts = [] } = useQuery({'''

if 'const { t } = useTranslation();' not in content:
    content = content.replace(old_component_start, new_component_start)

# 3. 删除旧的schema定义
content = re.sub(
    r'const transactionEntrySchema = z[\s\S]*?path: \[\'debit_amount\'\],\s*\}\s*\);',
    '',
    content,
    count=1
)
content = re.sub(
    r'const transactionFormSchema = z\.object\(\{[\s\S]*?entries: z\.array\(transactionEntrySchema\)\.min\(2, \'[^\']+\'\),\s*\}\);',
    '',
    content,
    count=1
)

# 4. 替换JSX中的硬编码字符串
replacements = [
    (r'<FormLabel>Transaction Date</FormLabel>', '<FormLabel>{t("transactionForm.transactionDate")}</FormLabel>'),
    (r'<FormLabel>Description</FormLabel>', '<FormLabel>{t("transactionForm.description")}</FormLabel>'),
    (r'placeholder="e\.g\., Salary payment"', 'placeholder={t("transactionForm.descriptionPlaceholder")}'),
    (r'<FormLabel>Entries</FormLabel>', '<FormLabel>{t("transactionForm.entries")}</FormLabel>'),
    (r'>Add Entry<', '>{t("transactionForm.addEntry")}<'),
    (r'<span className="text-sm font-medium">Entry \{index \+ 1\}</span>', '<span className="text-sm font-medium">{t("transactionForm.entry")} {index + 1}</span>'),
    (r'<FormLabel>Account</FormLabel>', '<FormLabel>{t("transactionForm.account")}</FormLabel>'),
    (r'<SelectValue placeholder="Select account" />', '<SelectValue placeholder={t("transactionForm.selectAccount")} />'),
    (r'<FormLabel>Debit Amount</FormLabel>', '<FormLabel>{t("transactionForm.debitAmount")}</FormLabel>'),
    (r'<FormLabel>Credit Amount</FormLabel>', '<FormLabel>{t("transactionForm.creditAmount")}</FormLabel>'),
    (r'<FormLabel>Memo \(Optional\)</FormLabel>', '<FormLabel>{t("transactionForm.memo")}</FormLabel>'),
    (r'placeholder="Additional notes"', 'placeholder={t("transactionForm.memoPlaceholder")}'),
    (r'<FormLabel>Category \(Optional\)</FormLabel>', '<FormLabel>{t("transactionForm.category")}</FormLabel>'),
    (r'<SelectValue placeholder="Select category" />', '<SelectValue placeholder={t("transactionForm.selectCategory")} />'),
    (r'<SelectItem value="">None</SelectItem>', '<SelectItem value="">{t("transactionForm.none")}</SelectItem>'),
    (r'<span className="text-sm font-medium">Balance:</span>', '<span className="text-sm font-medium">{t("transactionForm.balance")}:</span>'),
    (r'>✓ Balanced<', '>{t("transactionForm.balanced")}<'),
    (r'Unbalanced: \$\{balance\.toFixed\(2\)\} CNY', '{t("transactionForm.unbalanced")}: ${balance.toFixed(2)} CNY'),
    (r'>Cancel<', '>{t("common.cancel")}<'),
    (r'\{isLoading \? \'Creating\.\.\.\' : \'Create Transaction\'\}', '{isLoading ? t("transactionForm.creating") : t("transactionForm.createTransaction")}'),
    (r"'Transaction must be balanced \(total debits = total credits\)'", 't("transactionForm.mustBeBalanced")'),
]

for pattern, replacement in replacements:
    content = re.sub(pattern, replacement, content)

# 保存文件
with open('src/components/TransactionForm.tsx', 'w', encoding='utf-8') as f:
    f.write(content)

print('TransactionForm.tsx has been updated successfully!')
