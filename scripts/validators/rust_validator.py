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
        """Ban hardcoded string matching in match arms for enum construction — use serde rename_all."""
        in_match = False
        for i, line in enumerate(lines, 1):
            if re.search(r"match\s+\w+\s*\{", line):
                in_match = True
            if in_match and re.search(r'^\s*"[A-Z_]+"?\s*=>', line):
                # Skip string-to-string mappings (display symbols, external API parsing)
                # Only flag string-to-enum conversions where serde should be used
                if re.search(r'=>\s*"', line):
                    continue
                if "#[cfg(test)]" not in content[: content.find(line)]:
                    self.add_error(
                        str(file_path),
                        i,
                        "Forbidden: hardcoded string match for enum. Use serde rename_all.",
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
