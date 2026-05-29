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
