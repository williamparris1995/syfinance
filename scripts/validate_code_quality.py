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
