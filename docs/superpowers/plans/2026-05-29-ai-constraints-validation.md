# AI Generation Constraints & Validation Tools — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the monolithic validation script into modular validators and add two new checks (English-only logs, const/i18n enforcement), plus document the 3 AI constraints in CLAUDE.md.

**Architecture:** Refactor `scripts/validate_code_quality.py` into a `scripts/validators/` package with a BaseValidator base class, migrate existing Rust checks into `rust_validator.py`, and add `log_validator.py` (CJK in logs) and `const_validator.py` (bare strings in JSX). The entry point `validate_code_quality.py` orchestrates all validators.

**Tech Stack:** Python 3 (no external dependencies — stdlib only)

**Spec:** `docs/superpowers/specs/2026-05-29-ai-constraints-validation-design.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `scripts/validators/__init__.py` | Create | Package init, exports all validator classes |
| `scripts/validators/base.py` | Create | BaseValidator with shared error/warning collection |
| `scripts/validators/rust_validator.py` | Create | Migrated Rust checks from existing script |
| `scripts/validators/log_validator.py` | Create | NEW: detect CJK characters in log statements |
| `scripts/validators/const_validator.py` | Create | NEW: detect bare string literals in JSX rendering |
| `scripts/validate_code_quality.py` | Modify | Refactored entry point using validators package |
| `CLAUDE.md` | Modify | Add "AI Generation Constraints" section |

---

### Task 1: Create `scripts/validators/base.py` and `__init__.py`

**Files:**
- Create: `scripts/validators/__init__.py`
- Create: `scripts/validators/base.py`

- [ ] **Step 1: Create `scripts/validators/` directory**

```bash
mkdir -p scripts/validators
```

- [ ] **Step 2: Write `scripts/validators/base.py`**

```python
"""Base validator class shared by all code quality validators."""

import re
from pathlib import Path
from typing import List, Tuple

# CJK Unicode ranges for detecting non-English text
CJK_PATTERN = re.compile(r'[一-鿿㐀-䶿豈-﫿]')

# File patterns that should be skipped during validation
SKIP_PATTERNS = [
    "tests",
    "_test.rs",
    "test_",
    "__tests__",
    ".test.",
    ".spec.",
    "target",
    "node_modules",
    "dist",
    ".d.ts",
]


class BaseValidator:
    """Base class for code quality validators."""

    def __init__(self, project_root: Path):
        self.project_root = project_root
        self.errors: List[Tuple[str, int, str]] = []
        self.warnings: List[Tuple[str, int, str]] = []

    def should_skip_file(self, file_path: Path) -> bool:
        """Skip test files, generated files, and build artifacts."""
        path_str = str(file_path).replace("\\", "/")
        return any(pattern in path_str for pattern in SKIP_PATTERNS)

    def add_error(self, file_path: str, line_num: int, message: str):
        self.errors.append((file_path, line_num, message))

    def add_warning(self, file_path: str, line_num: int, message: str):
        self.warnings.append((file_path, line_num, message))

    def validate(self) -> bool:
        """Run all checks. Returns True if no errors found."""
        raise NotImplementedError

    def print_results(self):
        """Print errors and warnings for this validator."""
        name = self.__class__.__name__
        if self.errors:
            print(f"\n  [{name}] {len(self.errors)} errors:")
            for fp, ln, msg in self.errors:
                print(f"    {fp}:{ln}")
                print(f"      {msg}")
        if self.warnings:
            print(f"\n  [{name}] {len(self.warnings)} warnings:")
            for fp, ln, msg in self.warnings:
                print(f"    {fp}:{ln}")
                print(f"      {msg}")
        if not self.errors and not self.warnings:
            print(f"  [{name}] All checks passed.")

    def has_cjk(self, text: str) -> bool:
        """Check if text contains CJK characters."""
        return bool(CJK_PATTERN.search(text))
```

- [ ] **Step 3: Write `scripts/validators/__init__.py`**

```python
from .base import BaseValidator
from .rust_validator import RustValidator
from .log_validator import LogValidator
from .const_validator import ConstValidator

__all__ = ["BaseValidator", "RustValidator", "LogValidator", "ConstValidator"]
```

Note: This will fail to import until Tasks 2-4 are complete. That is expected.

- [ ] **Step 4: Verify base.py loads standalone**

```bash
cd scripts && python3 -c "from validators.base import BaseValidator; print('OK')"
```

Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add scripts/validators/base.py scripts/validators/__init__.py
git commit -m "feat(validation): add BaseValidator class for modular code quality checks"
```

---

### Task 2: Create `scripts/validators/rust_validator.py`

Migrate the 5 existing Rust checks from `scripts/validate_code_quality.py` into a new `RustValidator` class.

**Files:**
- Create: `scripts/validators/rust_validator.py`

- [ ] **Step 1: Write `scripts/validators/rust_validator.py`**

```python
"""Rust code quality validator — migrated from validate_code_quality.py."""

import re
from pathlib import Path
from .base import BaseValidator


class RustValidator(BaseValidator):
    """Validates Rust source files against coding standards."""

    def __init__(self, project_root: Path):
        super().__init__(project_root)
        self.src_dir = project_root / "src-tauri" / "src"

    def validate(self) -> bool:
        if not self.src_dir.exists():
            return True

        rust_files = list(self.src_dir.rglob("*.rs"))
        for file_path in rust_files:
            if self.should_skip_file(file_path):
                continue
            self._validate_file(file_path)

        return len(self.errors) == 0

    def _validate_file(self, file_path: Path):
        try:
            content = file_path.read_text(encoding="utf-8")
            lines = content.split("\n")

            self._check_hardcoded_sql(file_path, content, lines)
            self._check_hardcoded_string_match(file_path, content, lines)
            self._check_println_usage(file_path, content, lines)
            self._check_log_usage(file_path, content, lines)
            self._check_enum_serde(file_path, content, lines)
        except Exception as e:
            self.warnings.append((str(file_path), 0, f"Cannot read file: {e}"))

    def _check_hardcoded_sql(self, file_path: Path, content: str, lines: list):
        """Ban sqlx::query! — must use SeaORM instead."""
        pattern = r"sqlx::query(?:_as)?!\s*\("
        for i, line in enumerate(lines, 1):
            if re.search(pattern, line):
                if "repositories" in str(file_path):
                    self.add_error(
                        str(file_path),
                        i,
                        "Forbidden: sqlx::query! hardcoded SQL. Use SeaORM instead.",
                    )

    def _check_hardcoded_string_match(self, file_path: Path, content: str, lines: list):
        """Ban hardcoded string matching in match arms — use serde rename_all."""
        in_match = False
        for i, line in enumerate(lines, 1):
            if re.search(r"match\s+\w+\s*\{", line):
                in_match = True
            if in_match and re.search(r'^\s*"[A-Z_]+"?\s*=>', line):
                if "#[cfg(test)]" not in content[: content.find(line)]:
                    self.add_error(
                        str(file_path),
                        i,
                        "Forbidden: hardcoded string match. Use serde rename_all.",
                    )
            if in_match and line.strip() == "}":
                in_match = False

    def _check_println_usage(self, file_path: Path, content: str, lines: list):
        """Ban println! — must use tracing macros."""
        for i, line in enumerate(lines, 1):
            if "println!" in line and not line.strip().startswith("//"):
                self.add_error(
                    str(file_path),
                    i,
                    "Forbidden: println! detected. Use tracing macros (info!, debug!, error!).",
                )

    def _check_log_usage(self, file_path: Path, content: str, lines: list):
        """Warn on log:: crate usage — prefer tracing."""
        log_macros = ["log::info!", "log::debug!", "log::warn!", "log::error!"]
        for i, line in enumerate(lines, 1):
            for macro in log_macros:
                if macro in line and not line.strip().startswith("//"):
                    replacement = macro.split("::")[1]
                    self.add_warning(
                        str(file_path),
                        i,
                        f"Prefer tracing over log crate: {macro} -> tracing::{replacement}",
                    )

    def _check_enum_serde(self, file_path: Path, content: str, lines: list):
        """Warn on public enums missing Serialize/Deserialize."""
        enum_pattern = r"pub\s+enum\s+(\w+)\s*\{"
        for i, line in enumerate(lines, 1):
            match = re.search(enum_pattern, line)
            if match:
                enum_name = match.group(1)
                check_lines = lines[max(0, i - 5) : i]
                has_serde = any(
                    "Serialize" in l and "Deserialize" in l for l in check_lines
                )
                if not has_serde and not any(
                    kw in enum_name for kw in ["Error", "Event"]
                ):
                    self.add_warning(
                        str(file_path),
                        i,
                        f"Enum {enum_name} may need #[derive(Serialize, Deserialize)]",
                    )
```

- [ ] **Step 2: Verify it loads**

```bash
cd scripts && python3 -c "from validators.rust_validator import RustValidator; print('OK')"
```

Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/validators/rust_validator.py
git commit -m "feat(validation): add RustValidator with migrated Rust code quality checks"
```

---

### Task 3: Create `scripts/validators/log_validator.py`

New validator that detects CJK characters in log output statements (both Rust tracing macros and TypeScript console methods).

**Files:**
- Create: `scripts/validators/log_validator.py`

- [ ] **Step 1: Write `scripts/validators/log_validator.py`**

```python
"""Log language validator — ensures all log messages use English."""

from pathlib import Path
from .base import BaseValidator

# Rust tracing macros
RUST_LOG_MACROS = ["info!", "error!", "warn!", "debug!", "trace!"]

# TypeScript console methods
TS_CONSOLE_METHODS = ["console.log", "console.warn", "console.error", "console.info"]


class LogValidator(BaseValidator):
    """Validates that log messages contain no CJK characters (must be English)."""

    def __init__(self, project_root: Path):
        super().__init__(project_root)

    def validate(self) -> bool:
        self._check_rust_logs()
        self._check_typescript_logs()
        return len(self.errors) == 0

    def _check_rust_logs(self):
        """Check Rust tracing macros for CJK characters."""
        rust_src = self.project_root / "src-tauri" / "src"
        if not rust_src.exists():
            return

        for file_path in rust_src.rglob("*.rs"):
            if self.should_skip_file(file_path):
                continue
            try:
                lines = file_path.read_text(encoding="utf-8").split("\n")
            except Exception:
                continue

            for i, line in enumerate(lines, 1):
                if line.strip().startswith("//"):
                    continue
                for macro in RUST_LOG_MACROS:
                    if macro in line and self.has_cjk(line):
                        self.add_error(
                            str(file_path),
                            i,
                            f"Log messages must use English, not CJK characters (found in {macro})",
                        )
                        break

    def _check_typescript_logs(self):
        """Check TypeScript console methods for CJK characters."""
        ts_src = self.project_root / "src"
        if not ts_src.exists():
            return

        for ext in ("*.ts", "*.tsx"):
            for file_path in ts_src.rglob(ext):
                if self.should_skip_file(file_path):
                    continue
                try:
                    lines = file_path.read_text(encoding="utf-8").split("\n")
                except Exception:
                    continue

                for i, line in enumerate(lines, 1):
                    if line.strip().startswith("//"):
                        continue
                    for method in TS_CONSOLE_METHODS:
                        if method in line and self.has_cjk(line):
                            self.add_error(
                                str(file_path),
                                i,
                                f"Console messages must use English, not CJK characters (found in {method})",
                            )
                            break
```

- [ ] **Step 2: Verify it loads**

```bash
cd scripts && python3 -c "from validators.log_validator import LogValidator; print('OK')"
```

Expected: `OK`

- [ ] **Step 3: Quick manual test — run against the codebase**

```bash
cd scripts && python3 -c "
from pathlib import Path
from validators.log_validator import LogValidator
v = LogValidator(Path('..').resolve())
result = v.validate()
v.print_results()
print('PASS' if result else 'FAIL')
"
```

Expected: `PASS` (all existing logs are already in English). Should print `[LogValidator] All checks passed.`

- [ ] **Step 4: Commit**

```bash
git add scripts/validators/log_validator.py
git commit -m "feat(validation): add LogValidator to enforce English-only log messages"
```

---

### Task 4: Create `scripts/validators/const_validator.py`

New validator that flags bare string literals used directly in JSX rendering context. `const` declarations and `t()` calls are allowed.

**Files:**
- Create: `scripts/validators/const_validator.py`

- [ ] **Step 1: Write `scripts/validators/const_validator.py`**

```python
"""Const/i18n validator — ensures JSX string literals use i18n or are const-defined."""

import re
from pathlib import Path
from .base import BaseValidator

# JSX attributes that accept non-i18n string values
JSX_STRING_ATTRS = {"className", "style", "type", "id", "name", "to", "key", "variant", "size", "side", "as", "role", "dir", "lang", "slot", "action", "method", "target", "rel", "href", "src", "alt", "placeholder"}

# Pattern matching string literals: "..." or '...'
STRING_LITERAL_RE = re.compile(r"""(?<!\\)(["'])(?:(?!\1).){1,}\1""")


class ConstValidator(BaseValidator):
    """Validates that string literals in TSX files use i18n or are const-defined."""

    def __init__(self, project_root: Path):
        super().__init__(project_root)

    def validate(self) -> bool:
        ts_src = self.project_root / "src"
        if not ts_src.exists():
            return True

        for file_path in ts_src.rglob("*.tsx"):
            if self.should_skip_file(file_path):
                continue
            try:
                lines = file_path.read_text(encoding="utf-8").split("\n")
            except Exception:
                continue

            for i, line in enumerate(lines, 1):
                self._check_line(file_path, i, line)

        return len(self.errors) == 0

    def _check_line(self, file_path: Path, line_num: int, line: str):
        stripped = line.strip()

        # Skip comments
        if stripped.startswith("//") or stripped.startswith("*"):
            return

        # Skip import statements
        if stripped.startswith("import "):
            return

        # Skip type/interface declarations
        if re.match(r"^\s*(export\s+)?(type|interface)\s+", line):
            return

        # Skip lines using t() i18n calls
        if re.search(r'\bt\s*\(', line):
            return

        # Skip const/let/var declarations (non-display constants are OK)
        if re.match(r"^\s*(const|let|var)\s+", line):
            return

        # Skip lines with function signatures, return types
        if re.match(r"^\s*(async\s+)?function\s+", line):
            return
        if re.match(r"^\s*(export\s+)?(default\s+)?function", line):
            return

        # Only check lines that look like JSX (contain < and >)
        if "<" not in line:
            return

        # Find string literals in the line
        for match in STRING_LITERAL_RE.finditer(line):
            literal = match.group(0)
            value = literal[1:-1]

            # Skip empty or very short strings
            if len(value) <= 1:
                continue

            # Skip strings that look like codes/keys (all caps, dots, slashes, hyphens)
            if re.match(r"^[A-Z_a-z0-9./:_-]+$", value):
                continue

            # Check if this string is inside a known JSX attribute
            prefix = line[: match.start()]
            # Match attribute name before the string: attr="value" or attr = "value"
            attr_match = re.search(r"(\w+)\s*=\s*$", prefix)
            if attr_match:
                attr_name = attr_match.group(1)
                if attr_name in JSX_STRING_ATTRS:
                    continue

            # This is a bare string literal in JSX that should use t()
            self.add_error(
                str(file_path),
                line_num,
                f'Bare string literal {literal} in JSX must use t() for i18n',
            )
```

- [ ] **Step 2: Verify it loads**

```bash
cd scripts && python3 -c "from validators.const_validator import ConstValidator; print('OK')"
```

Expected: `OK`

- [ ] **Step 3: Quick manual test — run against the codebase**

```bash
cd scripts && python3 -c "
from pathlib import Path
from validators.const_validator import ConstValidator
v = ConstValidator(Path('..').resolve())
result = v.validate()
v.print_results()
print('PASS' if result else 'FAIL')
"
```

Expected: May report some findings (this is supplementary to ESLint). Note the results.

- [ ] **Step 4: Commit**

```bash
git add scripts/validators/const_validator.py
git commit -m "feat(validation): add ConstValidator for JSX bare string literal detection"
```

---

### Task 5: Update `scripts/validate_code_quality.py` — New entry point

Replace the monolithic `CodeValidator` class with a thin entry point that instantiates and runs all validators from the `validators` package.

**Files:**
- Modify: `scripts/validate_code_quality.py` (full rewrite)

- [ ] **Step 1: Rewrite `scripts/validate_code_quality.py`**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Code quality validation entry point.
Runs all validators from the validators package.
"""

import sys
import io
from pathlib import Path

# Set Windows console to UTF-8
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

# Add scripts directory to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from validators import RustValidator, LogValidator, ConstValidator


def main():
    project_root = Path(__file__).parent.parent

    validators = [
        RustValidator(project_root),
        LogValidator(project_root),
        ConstValidator(project_root),
    ]

    print("Starting code quality checks...\n")

    all_pass = True
    total_errors = 0
    total_warnings = 0

    for validator in validators:
        passed = validator.validate()
        validator.print_results()
        total_errors += len(validator.errors)
        total_warnings += len(validator.warnings)
        if not passed:
            all_pass = False

    # Summary
    print("\n" + "=" * 60)
    print(f"Total errors:   {total_errors}")
    print(f"Total warnings: {total_warnings}")
    if all_pass:
        print("\nAll checks passed.")
    else:
        print(f"\n{total_errors} check(s) failed.")
    print("=" * 60)

    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Run the full validation pipeline**

```bash
cd scripts && python3 validate_code_quality.py
```

Expected: Prints results from all 3 validators. Exit code 0 if no errors.

- [ ] **Step 3: Also verify via Makefile**

```bash
make check-quality
```

Expected: Same output. Exit 0.

- [ ] **Step 4: Commit**

```bash
git add scripts/validate_code_quality.py
git commit -m "refactor(validation): replace monolithic validator with modular validators package"
```

---

### Task 6: Update `CLAUDE.md` — Add AI Generation Constraints section

Append a new section documenting the 3 AI generation constraint rules.

**Files:**
- Modify: `CLAUDE.md` (append after "Incomplete Features" section)

- [ ] **Step 1: Append AI Generation Constraints section to CLAUDE.md**

Add the following at the end of the file:

```markdown
## AI Generation Constraints

Three rules enforced by validation tooling (`make check-quality`) and ESLint.

### 1. Modular Design, Reuse First (SHOULD)

Before creating new modules, check existing ones for reuse:
- Frontend: `src/lib/tauri/`, `src/components/ui/`, `src/hooks/`
- Backend: `src-tauri/src/application/services/`, `src-tauri/src/domain/`
- Follow DDD layer boundaries (domain → application → infrastructure → presentation)

### 2. English Structured Logs (SHOULD)

All log output must use English structured format. CJK characters in log statements are flagged by `log_validator.py`.

Rust:
```rust
info!(account_id = %id, "Creating account");
error!(operation = "delete_transaction", error = %e, "Failed to delete");
```

TypeScript:
```typescript
console.error("[AccountService] Failed to create account", error);
```

### 3. i18n for UI, const for Non-UI (FORBIDDEN to hardcode in UI)

- **User-visible JSX text**: Must use `t('key')` — no hardcoded strings (enforced by ESLint `i18next/no-literal-string` + `const_validator.py`)
- **Non-display constants**: `const STATUS = "active"` is acceptable for error codes, config values, API paths
- **Avoid circular references**: const strings must not create reference loops with i18n keys

Validation: `pnpm lint` (ESLint) + `make check-quality` (Python validators)
```

- [ ] **Step 2: Verify CLAUDE.md renders correctly**

```bash
head -150 CLAUDE.md | tail -60
```

Expected: The new section is visible and properly formatted.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: add AI generation constraints section to CLAUDE.md"
```

---

### Task 7: Final verification

- [ ] **Step 1: Run the complete quality check pipeline**

```bash
make check-quality
```

Expected: All validators pass (exit 0).

- [ ] **Step 2: Run ESLint to confirm no conflict with existing checks**

```bash
pnpm lint
```

Expected: No new errors or warnings compared to before this change.

- [ ] **Step 3: Verify the validators package imports cleanly**

```bash
python3 -c "from scripts.validators import RustValidator, LogValidator, ConstValidator; print('All validators importable')"
```

Expected: `All validators importable`

- [ ] **Step 4: Final commit (if any lint fixes needed)**

```bash
git add -A
git commit -m "chore: final cleanup for AI constraints validation tools"
```
