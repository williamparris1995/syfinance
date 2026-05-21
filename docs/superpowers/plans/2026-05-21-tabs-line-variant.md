# Tabs Line Variant Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Switch SimpleTransactionForm TabsList from `variant="default"` (gray pill buttons) to `variant="line"` (underline indicator, full-width).

**Architecture:** Single-file CSS class change in `SimpleTransactionForm.tsx`. No logic, no new components, no API changes.

**Tech Stack:** React 19, @base-ui/react/tabs, Tailwind CSS

---

### Task 1: Apply TabsList variant and spacing fixes

**Files:**
- Modify: `src/components/SimpleTransactionForm.tsx:180,186,238,290`

- [ ] **Step 1: Change TabsList to line variant with full width**

Edit `src/components/SimpleTransactionForm.tsx` line 180.

Replace:
```tsx
        <TabsList className="grid w-full grid-cols-3">
```

With:
```tsx
        <TabsList variant="line" className="w-full">
```

- [ ] **Step 2: Remove `mt-4` from all three TabsContent**

Edit `src/components/SimpleTransactionForm.tsx` lines 186, 238, 290.

Replace:
```tsx
<TabsContent value="expense" className="space-y-4 mt-4">
```
With:
```tsx
<TabsContent value="expense" className="space-y-4">
```

Replace:
```tsx
<TabsContent value="income" className="space-y-4 mt-4">
```
With:
```tsx
<TabsContent value="income" className="space-y-4">
```

Replace:
```tsx
<TabsContent value="transfer" className="space-y-4 mt-4">
```
With:
```tsx
<TabsContent value="transfer" className="space-y-4">
```

- [ ] **Step 3: Verify TypeScript compilation**

Run: `npx tsc --noEmit`
Expected: No errors.

- [ ] **Step 4: Verify visually in the app**

Run the app and confirm:
- Tabs show underline indicator on active tab (not gray pill background)
- TabsList spans full width above form content
- Switching tabs works correctly (expense / income / transfer)
- Spacing between tabs and content is correct (no excess gap)

- [ ] **Step 5: Commit**

```bash
git add src/components/SimpleTransactionForm.tsx
git commit -m "fix(ui): switch SimpleTransactionForm tabs to line variant

- Replace variant=default + grid-cols-3 with variant=line + w-full
- Remove manual mt-4 spacing on TabsContent

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```
