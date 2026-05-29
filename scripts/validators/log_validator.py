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
