# Account Filter: Split Own/External + Multi-Select — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single account filter dropdown in TransactionsPage with two independent checkbox-based multi-select dropdowns for own and external accounts.

**Architecture:** New reusable `MultiSelect` UI component built on `@base-ui/react` Popover + Checkbox. `TransactionsPage` replaces `accountFilter: string` with `ownAccountFilter: string[]` and `externalAccountFilter: string[]`. Filter logic uses OR across both arrays; empty array = no filter for that group.

**Tech Stack:** React 19, TypeScript, @base-ui/react (Popover + Checkbox), Tailwind CSS, react-i18next

---

### File Structure

| File | Action | Responsibility |
|---|---|---|
| `src/components/ui/multi-select.tsx` | Create | Reusable checkbox multi-select dropdown |
| `src/pages/TransactionsPage.tsx` | Modify | Replace filter state, logic, and layout |
| `src/i18n/locales/en.json` | Modify | Add `common.confirm`, `common.clear`, `common.selectAll` |
| `src/i18n/locales/zh.json` | Modify | Add `common.confirm`, `common.clear`, `common.selectAll` |

---

### Task 1: Add i18n Keys

**Files:**
- Modify: `src/i18n/locales/en.json:6-7`
- Modify: `src/i18n/locales/zh.json:6-7`

- [ ] **Step 1: Add `common.selectAll`, `common.confirm`, `common.clear` to en.json**

In `src/i18n/locales/en.json`, the `common` section starts around line 5. Add three keys after `common.saving`:

```json
"common": {
    "save": "Save",
    "saving": "Saving...",
    "selectAll": "Select All",
    "confirm": "Confirm",
    "clear": "Clear",
```

- [ ] **Step 2: Add corresponding keys to zh.json**

In `src/i18n/locales/zh.json`, add after `common.saving`:

```json
"common": {
    "save": "保存",
    "saving": "保存中...",
    "selectAll": "全选",
    "confirm": "确认",
    "clear": "清除",
```

- [ ] **Step 3: Verify TypeScript still compiles**

Run: `npx tsc --noEmit --pretty`
Expected: no output (no errors)

- [ ] **Step 4: Commit**

```bash
git add src/i18n/locales/en.json src/i18n/locales/zh.json
git commit -m "feat: add selectAll, confirm, clear i18n keys"
```

---

### Task 2: Create MultiSelect UI Component

**Files:**
- Create: `src/components/ui/multi-select.tsx`

- [ ] **Step 1: Create the MultiSelect component file**

Write `src/components/ui/multi-select.tsx`:

```tsx
import * as React from "react"
import { Popover } from "@base-ui/react/popover"
import { Checkbox } from "@base-ui/react/checkbox"
import { cn } from "@/lib/utils"
import { ChevronDownIcon } from "lucide-react"

interface MultiSelectProps {
  options: { id: string; label: string }[]
  value: string[]
  onChange: (value: string[]) => void
  placeholder: string
  selectAllLabel: string
  className?: string
}

export function MultiSelect({
  options,
  value,
  onChange,
  placeholder,
  selectAllLabel,
  className,
}: MultiSelectProps) {
  const [open, setOpen] = React.useState(false)

  const allSelected = options.length > 0 && value.length === options.length

  const handleToggle = (id: string) => {
    if (id === "__all__") {
      if (allSelected) {
        onChange([])
      } else {
        onChange(options.map((o) => o.id))
      }
      return
    }
    if (value.includes(id)) {
      onChange(value.filter((v) => v !== id))
    } else {
      onChange([...value, id])
    }
  }

  const selectedLabels = value
    .map((id) => options.find((o) => o.id === id)?.label)
    .filter(Boolean)
    .join(", ")

  return (
    <Popover.Root open={open} onOpenChange={setOpen}>
      <Popover.Trigger
        className={cn(
          "flex h-7 w-fit items-center justify-between gap-1 rounded-lg border border-input bg-transparent py-1 pr-1.5 pl-2.5 text-xs whitespace-nowrap transition-colors outline-none select-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50 min-w-[120px] max-w-[180px]",
          className,
        )}
      >
        <span className="flex min-w-0 flex-1 items-center gap-1.5 text-left">
          {value.length > 0 ? (
            <>
              <span className="truncate">{selectedLabels}</span>
              <span className="inline-flex h-4 min-w-4 shrink-0 items-center justify-center rounded-full bg-primary px-1 text-[10px] font-medium text-primary-foreground">
                {value.length}
              </span>
            </>
          ) : (
            <span className="text-muted-foreground">{placeholder}</span>
          )}
        </span>
        <ChevronDownIcon className="size-3.5 shrink-0 text-muted-foreground" />
      </Popover.Trigger>
      <Popover.Portal>
        <Popover.Positioner
          side="bottom"
          sideOffset={4}
          align="start"
          className="z-50"
        >
          <Popover.Popup className="min-w-[160px] max-h-60 overflow-y-auto rounded-lg bg-popover p-1 text-popover-foreground shadow-md ring-1 ring-foreground/10 data-open:animate-in data-open:fade-in-0 data-open:zoom-in-95">
            {/* Select All */}
            <label className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 hover:bg-accent">
              <Checkbox.Root
                checked={allSelected}
                onCheckedChange={() => handleToggle("__all__")}
                className="flex size-4 shrink-0 items-center justify-center rounded border border-input data-[checked]:bg-primary data-[checked]:text-primary-foreground"
              >
                <Checkbox.Indicator className="flex items-center justify-center text-current">
                  <CheckIcon />
                </Checkbox.Indicator>
              </Checkbox.Root>
              <span className="text-sm">{selectAllLabel}</span>
            </label>
            {/* Divider */}
            <div className="mx-1 my-1 h-px bg-border" />
            {/* Options */}
            {options.map((option) => (
              <label
                key={option.id}
                className="flex cursor-pointer items-center gap-2 rounded-md px-2 py-1.5 hover:bg-accent"
              >
                <Checkbox.Root
                  checked={value.includes(option.id)}
                  onCheckedChange={() => handleToggle(option.id)}
                  className="flex size-4 shrink-0 items-center justify-center rounded border border-input data-[checked]:bg-primary data-[checked]:text-primary-foreground"
                >
                  <Checkbox.Indicator className="flex items-center justify-center text-current">
                    <CheckIcon />
                  </Checkbox.Indicator>
                </Checkbox.Root>
                <span className="truncate text-sm">{option.label}</span>
              </label>
            ))}
          </Popover.Popup>
        </Popover.Positioner>
      </Popover.Portal>
    </Popover.Root>
  )
}

function CheckIcon() {
  return (
    <svg width="10" height="10" viewBox="0 0 15 15" fill="currentColor" aria-hidden="true">
      <path
        d="M11.4669 3.72684C11.7558 3.91574 11.8369 4.30308 11.648 4.59198L7.39799 11.092C7.29783 11.2452 7.13556 11.3467 6.95402 11.3699C6.77247 11.3931 6.58989 11.3355 6.45446 11.2124L3.70446 8.71241C3.44905 8.48022 3.43023 8.08494 3.66242 7.82953C3.89461 7.57412 4.28989 7.55529 4.5453 7.78749L6.75292 9.79441L10.6018 3.90792C10.7907 3.61902 11.178 3.53795 11.4669 3.72684Z"
        clipRule="evenodd"
        fillRule="evenodd"
      />
    </svg>
  )
}
```

- [ ] **Step 2: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty`
Expected: no output (no errors)

- [ ] **Step 3: Commit**

```bash
git add src/components/ui/multi-select.tsx
git commit -m "feat: add MultiSelect UI component"
```

---

### Task 3: Update TransactionsPage — State and Logic

**Files:**
- Modify: `src/pages/TransactionsPage.tsx:59-62` (filter state)
- Modify: `src/pages/TransactionsPage.tsx:157-174` (filter logic)

- [ ] **Step 1: Replace `accountFilter` state with two arrays**

In `src/pages/TransactionsPage.tsx`, change lines 59-62 from:

```tsx
  // Filter state
  const [typeFilter, setTypeFilter] = useState<TransactionType_>('all');
  const [accountFilter, setAccountFilter] = useState<string>('all');
  const [searchQuery, setSearchQuery] = useState('');
```

To:

```tsx
  // Filter state
  const [typeFilter, setTypeFilter] = useState<TransactionType_>('all');
  const [ownAccountFilter, setOwnAccountFilter] = useState<string[]>([]);
  const [externalAccountFilter, setExternalAccountFilter] = useState<string[]>([]);
  const [searchQuery, setSearchQuery] = useState('');
```

- [ ] **Step 2: Add derived own accounts list**

After the `externalAccounts` query (line ~75), add:

```tsx
  const ownAccounts = useMemo(
    () => accounts.filter((a) => a.ownership === 'own'),
    [accounts],
  );
```

- [ ] **Step 3: Update the `filteredTransactions` useMemo**

Replace the `accountFilter` block in `filteredTransactions` (lines 162-165):

```tsx
    if (accountFilter !== 'all') {
      result = result.filter(tx =>
        tx.entries.some(e => e.account_id === accountFilter)
      );
    }
```

With:

```tsx
    if (ownAccountFilter.length > 0 || externalAccountFilter.length > 0) {
      result = result.filter((tx) =>
        tx.entries.some(
          (e) =>
            (ownAccountFilter.length === 0 || ownAccountFilter.includes(e.account_id)) ||
            (externalAccountFilter.length === 0 || externalAccountFilter.includes(e.account_id)),
        ),
      );
    }
```

And update the dependency array from `[transactions, typeFilter, accountFilter, searchQuery]` to `[transactions, typeFilter, ownAccountFilter, externalAccountFilter, searchQuery]`.

- [ ] **Step 4: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty`
Expected: no output (no errors)

- [ ] **Step 5: Commit**

```bash
git add src/pages/TransactionsPage.tsx
git commit -m "feat: replace single account filter with dual multi-select filter state"
```

---

### Task 4: Update TransactionsPage — Filter Bar Layout

**Files:**
- Modify: `src/pages/TransactionsPage.tsx:8-14` (add MultiSelect import)
- Modify: `src/pages/TransactionsPage.tsx:458-467` (replace Select with MultiSelect components)

- [ ] **Step 1: Add MultiSelect import**

In the imports at the top of `src/pages/TransactionsPage.tsx`, add after the existing UI imports:

```tsx
import { MultiSelect } from '../components/ui/multi-select';
```

- [ ] **Step 2: Replace the account filter Select with two MultiSelects**

Replace the existing account filter `Select` block (the `<Select>` through `</Select>` at lines ~459-482):

```tsx
        <div className="flex items-center gap-2">
          <span className="text-[11px] text-muted-foreground hidden sm:inline">
            {t('transactions.ownAccounts')}
          </span>
          <MultiSelect
            options={ownAccounts.map((a) => ({ id: a.id, label: a.name }))}
            value={ownAccountFilter}
            onChange={setOwnAccountFilter}
            placeholder={t('transactions.ownAccounts')}
            selectAllLabel={t('common.selectAll')}
          />
        </div>
        <div className="flex items-center gap-2">
          <span className="text-[11px] text-muted-foreground hidden sm:inline">
            {t('transactions.externalAccounts')}
          </span>
          <MultiSelect
            options={externalAccounts.map((a) => ({ id: a.id, label: a.name }))}
            value={externalAccountFilter}
            onChange={setExternalAccountFilter}
            placeholder={t('transactions.externalAccounts')}
            selectAllLabel={t('common.selectAll')}
          />
        </div>
```

Place these between the type filter buttons and the search input, replacing the current Select. Keep the `<div className="w-px h-5 bg-border" />` separators.

The filter bar should look like:

```
[All|Expense|Income|Transfer] | 自己: [MultiSelect] 外部: [MultiSelect] | [Search...] | N results
```

Each group wraps the label and MultiSelect in a `<div className="flex items-center gap-2">`. Labels use `hidden sm:inline` for responsive behavior (hide on narrow screens).

- [ ] **Step 3: Remove now-unused Select imports**

Remove `SelectGroup`, `SelectItem`, `SelectLabel` from the `@/components/ui/select` import if they're no longer used elsewhere in the file. Keep `Select`, `SelectContent`, `SelectTrigger`, `SelectValue` since they may still be used.

Check: the `Select` component is only used for the account filter, so the entire `Select*` import can be removed.

Replace:
```tsx
import {
  Select,
  SelectContent,
  SelectGroup,
  SelectItem,
  SelectLabel,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
```

With: (remove the entire Select import block)

- [ ] **Step 4: Verify TypeScript compiles**

Run: `npx tsc --noEmit --pretty`
Expected: no output (no errors)

- [ ] **Step 5: Commit**

```bash
git add src/pages/TransactionsPage.tsx
git commit -m "feat: add dual MultiSelect account filters to TransactionsPage"
```

---

### Self-Review Checklist

1. **Spec coverage:**
   - MultiSelect component: Task 2 ✓
   - Filter state split into two arrays: Task 3 Step 1 ✓
   - Filter logic OR across both groups: Task 3 Step 3 ✓
   - Filter bar layout with labels: Task 4 Step 2 ✓
   - Responsive (flex-wrap, hidden sm:inline, min-w/max-w on trigger): Tasks 2, 4 ✓
   - i18n keys: Task 1 ✓

2. **Placeholder scan:** No TBD, TODO, or incomplete sections.

3. **Type consistency:**
   - `MultiSelectProps.value: string[]` matches `ownAccountFilter: string[]` and `externalAccountFilter: string[]` ✓
   - `MultiSelectProps.onChange: (value: string[]) => void` matches `setOwnAccountFilter` and `setExternalAccountFilter` ✓
   - `options: { id: string; label: string }[]` matches `.map((a) => ({ id: a.id, label: a.name }))` ✓
   - `AccountDto` has `id: string` and `name: string` ✓
