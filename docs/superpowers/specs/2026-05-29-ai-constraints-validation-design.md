# AI Generation Constraints & Validation Tools

**Date**: 2026-05-29
**Status**: Approved

## Problem

AI-generated code occasionally violates project conventions that automated tooling doesn't catch:
- Non-modular code that duplicates existing functionality
- Log messages in Chinese instead of English structured format
- Hardcoded strings in UI components instead of i18n, or const strings flagged incorrectly

## Constraints

Three rules for AI code generation, with corresponding validation tooling:

### Rule 1 — Modular Design, Reuse First (SHOULD)

AI must use modular and component-oriented design. Before creating new modules, check existing ones for reuse:
- Frontend: `src/lib/tauri/`, `src/components/ui/`, `src/hooks/`
- Backend: `src-tauri/src/application/services/`, `src-tauri/src/domain/`
- Follow DDD layer boundaries

**Validation**: No automated check. Enforced via CLAUDE.md documentation. AI reads constraints before generating code.

### Rule 2 — English Structured Logs (SHOULD)

All log output must use English structured format via tracing (Rust) or console (TypeScript).

Rust:
```rust
info!(account_id = %id, "Creating account");
error!(operation = "delete_transaction", error = %e, "Failed to delete");
```

TypeScript:
```typescript
console.log("[AccountService] Creating account", { id });
console.error("[TransactionService] Failed to delete", error);
```

**Validation**: `log_validator.py` detects CJK characters in log macro calls (Rust) and console calls (TypeScript).

### Rule 3 — i18n for UI, const for Non-UI (FORBIDDEN to hardcode in UI)

- **User-visible JSX**: Must use `t('key')` i18n — no hardcoded strings
- **Non-display constants**: `const FOO = "bar"` is acceptable (error codes, config values, API paths)
- **Avoid circular references**: const strings must not create reference loops with i18n keys

**Validation**: Existing ESLint `i18next/no-literal-string` rule covers TypeScript. `const_validator.py` provides additional checking for const definitions misused in JSX rendering paths.

## Architecture

### Validation Script Structure

Split existing monolithic `scripts/validate_code_quality.py` into modular validators:

```
scripts/
  validators/
    __init__.py           # Package init, exports validator classes
    base.py               # BaseValidator: shared error/warning collection + file iteration
    rust_validator.py     # Existing Rust rules (SQL, println, serde, string match)
    log_validator.py      # NEW: English-only log messages (Rust tracing + TS console)
    const_validator.py    # NEW: Verify const strings not leaking into JSX rendering
  validate_code_quality.py  # Entry point: instantiates and runs all validators
```

### base.py — Shared Infrastructure

```python
class BaseValidator:
    project_root: Path
    errors: List[Tuple[str, int, str]]
    warnings: List[Tuple[str, int, str]]

    def should_skip_file(self, file_path: Path) -> bool  # Skip tests, generated files
    def add_error(self, file_path, line, message)
    def add_warning(self, file_path, line, message)
```

### rust_validator.py — Existing Checks (Migrated)

Migrated from current `validate_code_quality.py`:
- `check_hardcoded_sql` — ban `sqlx::query!`
- `check_hardcoded_string_match` — ban `"STRING" =>` match arms
- `check_println_usage` — ban `println!`
- `check_log_usage` — warn on `log::` macros
- `check_enum_serde` — warn on enums missing Serialize/Deserialize

### log_validator.py — NEW

Scans for non-English characters (CJK Unicode ranges) inside log statements.

Rust detection:
- Matches `info!(`, `error!(`, `warn!(`, `debug!(` macro calls
- Checks string content for CJK characters (U+4E00-U+9FFF, U+3400-U+4DBF)
- Skips test files

TypeScript detection:
- Matches `console.log(`, `console.warn(`, `console.error(`
- Same CJK character check
- Scans `src/` directory

### const_validator.py — NEW

Checks that string literals in `.tsx` files either:
1. Come from `t('key')` i18n calls, or
2. Are assigned to `const` declarations (acceptable for non-display constants)

Flags bare string literals used directly in JSX rendering context (inside JSX elements, not in variable declarations).

### validate_code_quality.py — Entry Point

```python
def main():
    validators = [
        RustValidator(project_root),
        LogValidator(project_root),
        ConstValidator(project_root),
    ]
    all_pass = True
    for v in validators:
        if not v.validate():
            all_pass = False
    sys.exit(0 if all_pass else 1)
```

### CLAUDE.md Addition

New section "AI Generation Constraints" appended to CLAUDE.md with the 3 rules, examples, and references to validation tools.

### Makefile

No changes needed. `make check-quality` already calls `python3 scripts/validate_code_quality.py`.

### ESLint Config

No changes needed. Existing `i18next/no-literal-string` config already covers the TypeScript side.

## Scope

- Files modified: `CLAUDE.md`, `scripts/validate_code_quality.py` (refactored entry point)
- Files created: `scripts/validators/__init__.py`, `scripts/validators/base.py`, `scripts/validators/rust_validator.py`, `scripts/validators/log_validator.py`, `scripts/validators/const_validator.py`
- Files unchanged: `Makefile`, `eslint.config.js`, `clippy.toml`, `docs/CODING_STANDARDS.md`
