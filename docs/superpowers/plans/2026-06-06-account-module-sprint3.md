# Account Module Sprint 3 — P3 Cleanups & Code Quality

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Clean up remaining P3 items from the account audit — remove dead code, improve type safety, and enable AccountStatus.

**Architecture:** Same stack as Sprint 1/2. These are smaller, independent tasks.

**Spec:** `docs/superpowers/specs/2026-06-05-account-modification-audit-design.md`

**Previous plans:**
- Sprint 1: `docs/superpowers/plans/2026-06-05-account-module-critical-fixes.md`
- Sprint 2: `docs/superpowers/plans/2026-06-05-account-module-sprint2.md`

---

### Task 1: Remove redundant UpdateAccountDto (P20)

Now that we have `PatchAccountDto`, the old `UpdateAccountDto` is only kept for backward compatibility. But since the frontend was fully updated in Sprint 1 to use `PatchAccountDto`, we can remove `UpdateAccountDto`.

**Files:**
- Modify: `src-tauri/src/application/dtos/account_dto.rs` — remove `UpdateAccountDto` struct and `From<UpdateAccountDto> for PatchAccountDto` impl
- Modify: `src-tauri/src/application/dtos/mod.rs` — remove `UpdateAccountDto` re-export if it still exists
- Modify: `src-tauri/src/application/services/account_service.rs` — remove any `UpdateAccountDto` references in tests
- Modify: `src/lib/tauri/account.ts` — remove `UpdateAccountDto` type (frontend now uses `PatchAccountDto`)

- [ ] **Step 1:** Search codebase for `UpdateAccountDto` references
- [ ] **Step 2:** Remove `UpdateAccountDto` struct from `account_dto.rs`
- [ ] **Step 3:** Remove `From<UpdateAccountDto> for PatchAccountDto` impl
- [ ] **Step 4:** Verify no remaining references
- [ ] **Step 5:** Run `cd src-tauri && cargo test account && pnpm type-check`
- [ ] **Step 6:** Commit: `refactor(accounts): remove redundant UpdateAccountDto, PatchAccountDto is the canonical type`

---

### Task 2: Enable AccountStatus — Active/Archived/Hidden (P12)

The `AccountStatus` enum exists in the domain but is never used. Enable it so users can archive/hide accounts.

**Files:**
- Modify: `src-tauri/src/domain/aggregates/account.rs` — add `update_status()` method
- Modify: `src-tauri/src/application/services/account_service.rs` — add `archive_account()` and `hide_account()` methods
- Modify: `src-tauri/src/application/dtos/account_dto.rs` — ensure `status` field is already there (was added in Sprint 1)
- Modify: `src-tauri/src/presentation/tauri_commands/account_commands.rs` — add `archive_account` and `hide_account` commands
- Modify: `src/lib/tauri/account.ts` — add `archiveAccount()` and `hideAccount()` functions
- Modify: `src/pages/AccountsPage.tsx` — add archive/hide options to account actions

- [ ] **Step 1:** Add `update_status()` method to `Account` aggregate
- [ ] **Step 2:** Add `archive_account()` and `hide_account()` to `AccountService`
- [ ] **Step 3:** Add tauri commands and frontend bindings
- [ ] **Step 4:** Add archive/hide buttons to AccountsPage (in the action dropdown)
- [ ] **Step 5:** Add i18n keys for archive/hide actions
- [ ] **Step 6:** Run tests and commit

---

### Task 3: Remove currency_code from PatchAccountDto (P20)

`PatchAccountDto` still has a `currency_code` field that was inherited from `UpdateAccountDto`, but currency is immutable. Remove it.

**Files:**
- Modify: `src-tauri/src/application/dtos/account_dto.rs` — remove `currency_code` from `PatchAccountDto`
- Modify: `src-tauri/src/application/services/account_service.rs` — remove any `dto.currency_code` references in `update_account`

- [ ] **Step 1:** Remove `currency_code` field from `PatchAccountDto`
- [ ] **Step 2:** Verify no references in service layer
- [ ] **Step 3:** Run tests
- [ ] **Step 4:** Commit: `refactor(accounts): remove immutable currency_code from PatchAccountDto`

---

### Task 4: Remove parent_id from PatchAccountDto (P22)

`parent_id` has no UI, no validation, and no circular reference protection. Remove it from the update DTO to avoid misuse until we implement it properly.

**Files:**
- Modify: `src-tauri/src/application/dtos/account_dto.rs` — remove `parent_id` from `PatchAccountDto`
- Modify: `src-tauri/src/application/services/account_service.rs` — remove `dto.parent_id` handling in `update_account`
- Modify: `src/components/AccountForm.tsx` — remove `parent_id` form field if present

- [ ] **Step 1:** Remove `parent_id` from `PatchAccountDto`
- [ ] **Step 2:** Remove `update_parent_id` handling in service
- [ ] **Step 3:** Remove `parent_id` form field from AccountForm (if any)
- [ ] **Step 4:** Run tests
- [ ] **Step 5:** Commit: `refactor(accounts): remove unused parent_id from PatchAccountDto`

---

This plan covers P3 code quality items. The remaining P3 UX items (edit page route, unified create entry, Decimal TEXT migration) are larger scoped and deferred to future work.